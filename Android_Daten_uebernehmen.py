#!/usr/bin/python3
"""Offline Android 16 -> 17 copy; source disks are only opened read-only by qemu-img."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
import uuid

PROFILE = 'Pixelkoje_Android17_mit_Daten'


def checked(path, roots, directory=False):
    path = Path(os.path.abspath(path))
    if path.resolve() != path or not any(path == root or root in path.parents for root in roots):
        raise RuntimeError('Verknüpfung oder fremder Datenpfad: ' + str(path))
    info = path.stat()
    if not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)):
        raise RuntimeError('Unerwarteter Dateityp: ' + str(path))
    if not directory and info.st_nlink != 1:
        raise RuntimeError('Gemeinsam verknüpfte Datei wird nicht übernommen: ' + str(path))
    return path


def validate_storage(root, identifier):
    checked(root, [root], directory=True)
    if checked(root / '.openguest-storage-id', [root]).read_text() != identifier:
        raise RuntimeError('Gewählter Datenträger fehlt oder wurde gewechselt.')


def stopped():
    result = subprocess.run(['/usr/bin/pgrep', '-f', '/emulator/qemu/|sdk/emulator/emulator'],
                            stdout=subprocess.DEVNULL)
    if result.returncode != 1:
        raise RuntimeError('Zuerst alle Android-Emulatoren vollständig beenden.')


def run(args):
    result = subprocess.run([str(x) for x in args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stdout[-2500:] or 'qemu-img meldet einen Fehler.')
    return result.stdout


def file_format(path):
    with path.open('rb') as stream:
        return 'qcow2' if stream.read(4) == b'QFI\xfb' else 'raw'


def image_chain(tool, top, roots):
    current, seen, paths, first = top, set(), [], None
    while True:
        current = checked(current, roots)
        if current in seen or len(seen) >= 16:
            raise RuntimeError('Ungültige Android-Abbildkette.')
        seen.add(current); paths.append(current)
        info = json.loads(run([tool, 'info', '-f', file_format(current), '--output=json', current]))
        first = first or info
        extra = info.get('format-specific', {}).get('data', {})
        if extra.get('data-file') or extra.get('encrypt'):
            raise RuntimeError('Zusatzdatei oder QCOW-Verschlüsselung wird nicht unterstützt.')
        backing = info.get('backing-filename')
        if not backing:
            return first, paths
        if ':' in backing or info.get('backing-filename-format', 'raw') not in ('qcow2', 'raw'):
            raise RuntimeError('Nicht unterstützte Android-Abbildkette.')
        current = Path(backing) if Path(backing).is_absolute() else current.parent / backing


def signature(path):
    info = path.stat()
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''): result.update(block)
    return result.digest()


def read_ini(path):
    return dict(line.split('=', 1) for line in path.read_text().splitlines()
                if '=' in line and not line.startswith('#'))


def transfer(root, identifier, source_name, tool, ensure_stopped=stopped):
    root = Path(os.path.abspath(root))
    validate_storage(root, identifier); ensure_stopped()
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', source_name) or source_name in ('.', '..'):
        raise RuntimeError('Ungültiger Android-Profilname.')
    avd = checked(root / 'Android/avd', [root], directory=True)
    source = checked(avd / (source_name + '.avd'), [avd], directory=True)
    config_file = checked(source / 'config.ini', [source])
    config = read_ini(config_file)
    image_parts = Path(config.get('image.sysdir.1', '')).parts
    if not all(x in image_parts for x in ('android-36', 'google_apis_playstore', 'arm64-v8a')):
        raise RuntimeError('Als Quelle wird Android 16 mit Google Play für ARM64 benötigt.')
    source_system = checked(root / 'Android/sdk/system-images/android-36/google_apis_playstore/arm64-v8a', [root], directory=True)
    target_system = checked(root / 'Android/sdk/system-images/android-37.0/google_apis_playstore/arm64-v8a', [root], directory=True)
    checked(target_system / 'system.img', [target_system])
    destination, locator = avd / (PROFILE + '.avd'), avd / (PROFILE + '.ini')
    if os.path.lexists(destination) or os.path.lexists(locator):
        raise RuntimeError('Die Android-17-Datenkopie existiert bereits. Sie wird nicht überschrieben; im Hauptfenster auswählen.')
    source_locator = avd / (source_name + '.ini')
    if os.path.lexists(source_locator):
        values = read_ini(checked(source_locator, [avd]))
        if values.get('path') and Path(values['path']) != source:
            raise RuntimeError('Der Quellverweis passt nicht zum Android-Profil.')
    permitted_paths = {'disk.dataPartition.path': 'userdata-qemu.img',
                       'disk.encryptionKeyPartition.path': 'encryptionkey.img', 'sdcard.path': 'sdcard.img'}
    for key, filename in permitted_paths.items():
        value = config.get(key, '')
        # Emulator hardware-properties.ini uses <temp> as its default data-path
        # sentinel. It is not a custom filename: persistent AVD data is still
        # discovered and validated below, including its encryption metadata.
        if key == 'disk.dataPartition.path' and value == '<temp>':
            continue
        if value and Path(value) not in (Path(filename), source / filename):
            raise RuntimeError('Benutzerdefinierter Datenpfad muss zuerst geprüft werden: ' + key)
    roots, plan = [source, source_system], []
    watched = {config_file: signature(config_file)}
    for base in ('userdata-qemu.img', 'encryptionkey.img', 'metadata.img', 'sdcard.img'):
        top = source / (base + '.qcow2')
        if not os.path.lexists(top): top = source / base
        if not os.path.lexists(top):
            if base in ('userdata-qemu.img', 'encryptionkey.img'):
                raise RuntimeError('Android-Daten oder Verschlüsselungsmetadaten fehlen: ' + base)
            continue
        info, chain = image_chain(tool, top, roots)
        if int(info['virtual-size']) <= 0: raise RuntimeError('Leeres Datenabbild: ' + base)
        plan.append((top, base, file_format(top), int(info['virtual-size'])))
        watched.update({p: signature(p) for p in chain})
    if shutil.disk_usage(avd).free < sum(item[3] for item in plan) + 2 * 1024**3:
        raise RuntimeError('Auf dem gewählten Datenträger fehlt Platz für die unabhängige Datenkopie.')
    stage = Path(tempfile.mkdtemp(prefix='.android17-daten-', dir=avd))
    moved, wrote_locator = False, False
    try:
        os.chmod(stage, 0o700)
        for top, base, fmt, _ in plan:
            validate_storage(root, identifier); ensure_stopped()
            print('Kopiere und prüfe ' + base + ' …', flush=True)
            output = stage / base
            run([tool, 'convert', '-f', fmt, '-O', 'raw', top, output])
            os.chmod(output, 0o600)
            run([tool, 'compare', '-f', fmt, '-F', 'raw', top, output])
        # Old system/vendor overlays and RAM snapshots must not survive an OS version change.
        for child in source.iterdir():
            if child.name in ('config.ini', 'hardware-qemu.ini', 'emulator-user.ini', 'quickbootChoice.ini',
                              'emu-launch-params.txt', 'default.dtb', 'version_num.cache'):
                continue
            if child.suffix in ('.img', '.qcow2', '.lock') or child.name.startswith('.'): continue
            if child.is_symlink(): raise RuntimeError('Verknüpfte Profildatei: ' + child.name)
            if child.is_dir():
                if child.name in ('snapshots', 'data', 'tmpAdbCmds', 'modem_simulator'): continue
                raise RuntimeError('Unbekannter Profil-Unterordner muss geprüft werden: ' + child.name)
            checked(child, [source]); watched[child] = signature(child)
            shutil.copy2(child, stage / child.name); os.chmod(stage / child.name, 0o600)
            if digest(child) != digest(stage / child.name): raise RuntimeError('Profildatei stimmt nicht mit der Quelle überein.')
        config = {key: value for key, value in config.items()
                  if not key.startswith(('disk.system', 'disk.vendor', 'fastboot.', 'skin.path'))
                  and key not in (*permitted_paths, 'disk.dataPartition.initPath', 'disk.snapStorage.path')}
        config.update({'AvdId': PROFILE, 'avd.ini.displayname': 'Android 17 · Daten aus Android 16',
                       'image.sysdir.1': 'system-images/android-37.0/google_apis_playstore/arm64-v8a/',
                       'target': 'android-37.0', 'abi.type': 'arm64-v8a', 'hw.cpu.arch': 'arm64',
                       'tag.id': 'google_apis_playstore', 'tag.display': 'Google Play',
                       'fastboot.forceColdBoot': 'yes', 'fastboot.forceFastBoot': 'no', 'fastboot.forceChosenSnapshotBoot': 'no'})
        if any(str(source) in value or 'android-36/' in value for value in config.values()):
            raise RuntimeError('Ein alter Profilpfad muss vor der Übernahme geprüft werden.')
        (stage / 'config.ini').write_text(''.join(key + '=' + value + '\n' for key, value in config.items()))
        receipt = {'version': 1, 'sourceProfile': source_name, 'sourceAndroid': 16, 'targetAndroid': 17,
                   'copyID': str(uuid.uuid4()), 'bootCompatibilityVerified': False,
                   'note': 'Unabhängige Kopie; keine spätere Synchronisierung.'}
        (stage / 'Stratovo-Datenuebernahme.json').write_text(json.dumps(receipt, ensure_ascii=False))
        ensure_stopped(); validate_storage(root, identifier)
        if any(signature(path) != before for path, before in watched.items()):
            raise RuntimeError('Quelldaten wurden während der Übernahme verändert. Kopie verworfen.')
        if os.path.lexists(destination) or os.path.lexists(locator):
            raise RuntimeError('Das Ziel wurde inzwischen angelegt. Nichts wird überschrieben.')
        os.rename(stage, destination); moved = True
        with locator.open('x') as stream:
            wrote_locator = True
            stream.write('avd.ini.encoding=UTF-8\npath=' + str(destination) + '\ntarget=android-37.0\n')
        os.chmod(locator, 0o600)
    except BaseException:
        if wrote_locator: locator.unlink()
        if moved: shutil.rmtree(destination)
        raise
    finally:
        if stage.exists(): shutil.rmtree(stage)
    print('Android-17-Datenkopie vorbereitet. Android 16 bleibt erhalten. Beim ersten Kaltstart Kompatibilität prüfen.', flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True); parser.add_argument('--qemu-img', required=True)
    args = parser.parse_args()
    storage = json.loads((Path.home() / 'Library/Application Support/OpenGuest/storage.json').read_text())
    root = Path(os.path.abspath(storage['root']))
    validate_storage(root, storage['id'])
    checked(root / 'Android', [root], directory=True)
    lock = root / 'Android/.data-transfer.lock'
    fd = os.open(lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with contextlib.ExitStack() as stack:
        stack.callback(os.close, fd)
        try: fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: raise RuntimeError('Eine Android-Datenübernahme läuft bereits.')
        transfer(root, storage['id'], args.source, args.qemu_img)


if __name__ == '__main__':
    try: main()
    except Exception as error:
        print('Datenübernahme angehalten: ' + str(error), flush=True)
        raise SystemExit(1)
