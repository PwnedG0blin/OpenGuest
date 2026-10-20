#!/usr/bin/env python3
"""Preview narrowly recognized old packages, then use the macOS Trash API."""
from pathlib import Path
import datetime
import json
import os
import plistlib
import re
import subprocess
import sys

CURRENT = '1.0.0-beta.5'
BUNDLE = 'org.pwnedg0blin.openguest'
PROTECTED = {'Android', 'Windows', 'GraphicsLab', 'Ubuntu', 'Runtime',
             'Installationsmedien', 'Backups', 'Austausch', 'Temp', 'Updates'}

def plain(path):
    return path.exists() and not path.is_symlink() and path.absolute() == path.resolve()

def older(name):
    # Recognized pre-1.0 private installers, including duplicate download names.
    stem = re.sub(r'(?:\.zip|\.dmg)$', '', name, flags=re.I)
    stem = re.sub(r'(?: \(\d+\)| \d+)$', '', stem)
    if re.fullmatch(r'(?:Pixelkoje|OpenGuest|Stratovo)_0\.\d+\.\d+_Privat(?:_AppleSilicon)?', stem):
        return True
    match = re.fullmatch(r'Stratovo_1\.0_Beta(\d+)_Privat(?:_AppleSilicon)?', stem)
    if not match:
        match = re.fullmatch(r'Stratovo_1\.0\.0-beta\.(\d+)_AppleSilicon', stem)
    return bool(match and int(match[1]) < 5)

def old_build(name):
    if re.fullmatch(r'(?:Pixelkoje|OpenGuest|Stratovo)-0\.\d+\.\d+-Privat(?:\.[A-Za-z0-9]+)?', name):
        return True
    match = re.fullmatch(r'Stratovo-1\.0-Beta(\d+)-Privat(?:\.[A-Za-z0-9]+)?', name)
    return bool(match and int(match[1]) < 5)

def candidates(root, downloads, package):
    """No recursive scan of guest data; look only in known package locations."""
    found = set()
    for folder in {root.parent, downloads}:
        if not plain(folder):
            continue
        for item in folder.iterdir():
            if older(item.name) and plain(item):
                found.add(item)
    for folder in {root / 'Builds', root.parent / 'OpenGuest/Builds', root.parent / 'Stratovo/Builds'}:
        if not plain(folder):
            continue
        for item in folder.iterdir():
            if item.is_dir() and plain(item) and old_build(item.name):
                found.add(item)
    protected = [root / name for name in PROTECTED]
    return sorted((p for p in found if p != root and p != package and p not in package.parents
                   and not any(p == keep or keep in p.parents or p in keep.parents for keep in protected)), key=str)

def check_install(app=Path('/Applications/Stratovo.app')):
    if not plain(app):
        raise RuntimeError('Zuerst die neue Stratovo-App in Programme installieren und testen.')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != BUNDLE or info.get('StratovoReleaseVersion') != CURRENT:
        raise RuntimeError('Zuerst Stratovo 1.0 Beta 5 in Programme installieren und testen.')

def running():
    lines = subprocess.check_output(['/bin/ps', '-axo', 'comm='], text=True).splitlines()
    names = {'Stratovo', 'Pixelkoje', 'OpenGuest', 'qemu-system-aarch64', 'qemu-aarch64', 'emulator'}
    return any(Path(line.strip()).name in names for line in lines)

def main():
    if sys.platform != 'darwin':
        raise RuntimeError('Diese Aktion ist nur für macOS vorgesehen.')
    pointer = Path.home() / 'Library/Application Support/OpenGuest/storage.json'
    data = json.loads(pointer.read_text())
    root = Path(data['root'])
    if not plain(root) or not (root / '.openguest-storage-id').is_file() or (root / '.openguest-storage-id').read_text() != data['id']:
        raise RuntimeError('Den bisherigen Datenträger anschließen und den Speicherort in Stratovo prüfen.')
    check_install()
    if running():
        input('Alle Gäste herunterfahren, Stratovo und alte App-Fenster schließen; danach Enter drücken: ')
        if running():
            raise RuntimeError('Es läuft noch eine App oder ein Gast. Nichts geändert.')
    package = Path(__file__).resolve().parents[1]
    items = candidates(root, Path.home() / 'Downloads', package)
    print('BEHALTEN: aktuelle App, aktuelles Paket, alle VM-Daten und die gesamte GraphicsLab-Laufzeit.')
    print('VORSCHAU – diese alten Pakete werden nur in den Papierkorb verschoben:')
    for item in items:
        subprocess.run(['/usr/bin/du', '-sh', str(item)], check=True)
    if not items:
        print('Keine passenden alten Pakete gefunden. Nichts geändert.')
        return
    print('\nEigene Quellcodeänderungen vorher sichern. Zuerst Beta 5 mit deinen Gästen testen.')
    print('Rückkehr: im Papierkorb „Zurücklegen“. Den Papierkorb erst nach weiteren erfolgreichen Starts leeren.')
    if input('Nach erfolgreichem Test zum Fortfahren BETA5 GETESTET eingeben; sonst Enter: ').strip() != 'BETA5 GETESTET':
        print('Abgebrochen. Nichts verschoben.')
        return
    check_install()
    if running() or items != candidates(root, Path.home() / 'Downloads', package):
        raise RuntimeError('App oder Dateiliste hat sich geändert. Bitte erneut mit Vorschau starten.')
    backups = root / 'Backups'
    if backups.is_symlink() or (backups.exists() and not plain(backups)):
        raise RuntimeError('Sicherungsordner bitte prüfen.')
    backups.mkdir(exist_ok=True)
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    manifest = backups / ('Aufraeumen-' + stamp + '.json')
    manifest.write_text(json.dumps({'planned': [str(p) for p in items]}, ensure_ascii=False, indent=2))
    result = subprocess.run(['/usr/bin/xcrun', 'swift', str(Path(__file__).with_name('trash-packages.swift')),
                             *map(str, items)], text=True, capture_output=True, check=True)
    moved = json.loads(result.stdout)
    manifest.write_text(json.dumps({'results': moved}, ensure_ascii=False, indent=2))
    for entry in moved:
        print(('Papierkorb: ' if entry['status'] == 'moved' else 'Nicht verschoben: ') + entry['source'])
        if entry.get('error'):
            print(entry['error'])
    print('Protokoll: ' + str(manifest))
    print('VM-Daten und aktuelle Version behalten. Der Papierkorb wurde nicht geleert.')

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('Aufräumen angehalten: ' + str(exc), file=sys.stderr)
        raise SystemExit(1)
