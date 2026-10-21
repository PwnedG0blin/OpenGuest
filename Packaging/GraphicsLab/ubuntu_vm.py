#!/usr/bin/env python3
"""Independent Ubuntu ARM VM on the user's selected data volume."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import urllib.request

ISO_NAME = 'ubuntu-26.04.1-desktop-arm64.iso'
ISO_URL = 'https://cdimage.ubuntu.com/ubuntu/releases/26.04/release/'+ISO_NAME
ISO_SHA = 'c54d196489d3c867975fb3bbb72ca52ec2e137456e305481f81096304e4d2517'


def regular(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file():
        raise RuntimeError('Datei fehlt oder ist verknüpft: '+str(path))
    return path


def directory(path):
    path = Path(path).absolute()
    if any(p.is_symlink() for p in [path]+list(path.parents)):
        raise RuntimeError('Ubuntu-Ordner darf keine Verknüpfung sein.')
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    return path


def digest(path):
    value = hashlib.sha256()
    with regular(path).open('rb') as source:
        for block in iter(lambda: source.read(1024*1024), b''):
            value.update(block)
    return value.hexdigest()


def download(folder):
    target = folder/ISO_NAME
    if target.exists() and digest(target) == ISO_SHA:
        print('Ubuntu-ISO vorhanden und geprüft.', flush=True)
        return target
    if target.exists():
        raise RuntimeError('Vorhandene ISO hat eine andere Prüfsumme. Sie wurde nicht überschrieben.')
    if shutil.disk_usage(folder).free < 6*1024**3:
        raise RuntimeError('Für die Ubuntu-ISO mindestens 6 GiB freien Speicher bereitstellen.')
    fd, temporary = tempfile.mkstemp(prefix='.ubuntu-download-', dir=folder)
    try:
        with os.fdopen(fd, 'wb') as out, urllib.request.urlopen(ISO_URL, timeout=60) as source:
            total = int(source.headers.get('Content-Length', '0'))
            done, last = 0, -1
            while True:
                block = source.read(1024*1024)
                if not block:
                    break
                out.write(block)
                done += len(block)
                progress = done*100//total if total else done//1024**2
                if progress != last:
                    print('Ubuntu laden:', str(progress)+('%' if total else ' MiB'), flush=True)
                    last = progress
        if digest(temporary) != ISO_SHA:
            raise RuntimeError('Ubuntu-Download hat eine falsche SHA-256-Prüfsumme.')
        os.replace(temporary, target)
        print('Ubuntu 26.04.1 LTS ARM64 geladen und geprüft.', flush=True)
        return target
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def launch_arguments(config, folder, socket, installing):
    def block(name, fmt, path, readonly=False):
        return json.dumps({'driver':fmt,'node-name':name,'read-only':readonly,
                           'file':{'driver':'file','filename':str(path)}})
    ram, cores = int(config.get('memoryMiB', 6144)), int(config.get('cores', 4))
    if not 6144 <= ram <= 8192 or not 2 <= cores <= 8:
        raise RuntimeError('Für Ubuntu 6–8 GiB RAM und 2–8 CPU-Kerne wählen.')
    args = [config['qemu'], '-name','Ubuntu ARM','-nodefaults',
            '-machine','virt,pflash0=code,pflash1=vars','-accel','hvf','-cpu','host',
            '-m',str(ram),'-smp',str(cores),'-boot','menu=on,splash-time=3000',
            '-blockdev',block('code','raw',config['firmware'],True),
            '-blockdev',block('vars','raw',folder/'uefi-vars.fd'),
            '-blockdev',block('system','qcow2',folder/'ubuntu.qcow2'),
            '-device','nvme,drive=system,serial=StratovoUbuntu,bootindex=2',
            '-device','virtio-gpu-pci','-display','none','-vnc','unix:'+str(Path(socket).parent/'display.sock'),
            '-device','qemu-xhci,id=usb','-device','usb-kbd,bus=usb.0','-device','usb-tablet,bus=usb.0',
            '-audiodev','coreaudio,id=stratovo-audio',
            '-device','usb-audio,id=stratovo-sound,bus=usb.0,audiodev=stratovo-audio',
            '-netdev','user,id=net0','-device','virtio-net-pci,netdev=net0',
            '-device','virtio-rng-pci','-qmp','unix:'+str(socket)+',server=on,wait=off',
            '-serial','none','-monitor','none']
    if installing:
        args += ['-blockdev',block('installer','raw',folder/ISO_NAME,True),
                 '-device','usb-bot,id=dvd,bus=usb.0',
                 '-device','scsi-cd,drive=installer,bus=dvd.0,bootindex=1']
    return args


def prepare_disk(config, folder):
    disk = folder/'ubuntu.qcow2'
    if disk.exists() or disk.is_symlink():
        result = subprocess.run([config['qemuImg'],'info','--output=json',str(regular(disk))],
                                check=True,capture_output=True,text=True)
        info = json.loads(result.stdout)
        if info.get('format') != 'qcow2' or info.get('backing-filename'):
            raise RuntimeError('Ubuntu benötigt eine eigenständige QCOW2-Festplatte.')
    else:
        if shutil.disk_usage(folder).free < 40*1024**3:
            raise RuntimeError('Vor der Ubuntu-Installation mindestens 40 GiB freien Speicher bereitstellen.')
        stage = folder/('.disk-'+str(os.getpid())+'.qcow2')
        try:
            subprocess.run([config['qemuImg'],'create','-f','qcow2',str(stage),'64G'],check=True,stdout=subprocess.DEVNULL)
            os.replace(stage,disk)
        finally:
            stage.unlink(missing_ok=True)
    variables = folder/'uefi-vars.fd'
    if not variables.exists() and not variables.is_symlink():
        source = Path(config['variablesTemplate']).resolve(strict=True)
        fd, temporary = tempfile.mkstemp(prefix='.vars-',dir=folder)
        try:
            with os.fdopen(fd,'wb') as out, regular(source).open('rb') as original:
                shutil.copyfileobj(original,out)
            os.replace(temporary,variables)
        finally:
            if os.path.exists(temporary): os.unlink(temporary)
    regular(variables)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', required=True)
    parser.add_argument('action', choices=['download','install','start','plan-install','plan-start'])
    args = parser.parse_args()
    config = json.loads(regular(args.config).read_text())
    base = Path(config['root']).absolute()
    if regular(base/'.openguest-storage-id').read_text() != config['storageID']:
        raise RuntimeError('Das ausgewählte Datenlaufwerk fehlt oder wurde ausgetauscht.')
    folder = directory(base/'Ubuntu')
    if args.action.startswith('plan-'):
        installing = args.action == 'plan-install'
        if installing and digest(folder/ISO_NAME) != ISO_SHA:
            raise RuntimeError('Zuerst die geprüfte Ubuntu-ISO herunterladen.')
        if not installing and not (folder/'ubuntu.qcow2').is_file():
            raise RuntimeError('Ubuntu zuerst installieren.')
        prepare_disk(config, folder)
        socket = Path(config['socketDirectory'])/'qmp.sock'
        print(json.dumps(launch_arguments(config, folder, socket, installing)[1:]))
        return
    fd = os.open(str(folder/'session.lock'),os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
    try:
        fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if args.action == 'download':
            download(folder)
            return
        installing = args.action == 'install'
        if installing and digest(folder/ISO_NAME) != ISO_SHA:
            raise RuntimeError('Zuerst die geprüfte Ubuntu-ISO herunterladen.')
        if not installing and not (folder/'ubuntu.qcow2').exists():
            raise RuntimeError('Ubuntu wurde noch nicht installiert. Zuerst Ubuntu installieren wählen.')
        prepare_disk(config,folder)
        with tempfile.TemporaryDirectory(prefix='stratovo-ubuntu-',dir='/tmp') as sockets:
            qmp = Path(sockets)/'qmp.sock'
            running = folder/'running.json'
            running.write_text(json.dumps({'qmp':str(qmp)}))
            try:
                print('Ubuntu startet im eigenen Fenster. Während der Installation nur die virtuelle 64-GiB-Festplatte auswählen.',flush=True)
                subprocess.run(launch_arguments(config,folder,qmp,installing),check=True)
            finally:
                running.unlink(missing_ok=True)
    finally:
        os.close(fd)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Ubuntu angehalten: '+str(error))
