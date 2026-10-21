import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
def load(name):
    spec = importlib.util.spec_from_file_location('beta2_'+name, ROOT/'Packaging/GraphicsLab'/f'{name}.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module
ubuntu = load('ubuntu_vm')
lab = load('lab')
embedded = load('embedded_display')

class Beta2Tests(unittest.TestCase):
    def test_ubuntu_launch_is_independent_and_uses_existing_player(self):
        root = Path('/ChosenSSD/Stratovo/Ubuntu')
        config = {'qemu':'/qemu','firmware':'/firmware','memoryMiB':6144,'cores':4}
        args = ubuntu.launch_arguments(config, root, Path('/tmp/og-test/qmp.sock'), True)
        self.assertIn('none', args)
        self.assertIn('unix:/tmp/og-test/display.sock', args)
        self.assertIn('virtio-gpu-pci', args)
        self.assertNotIn('cocoa', args)
        self.assertNotIn('windows.qcow2', ' '.join(args))
        self.assertNotIn('Android', ' '.join(args))
        normal = ubuntu.launch_arguments(config, root, Path('/tmp/og-test/qmp.sock'), False)
        self.assertNotIn(ubuntu.ISO_NAME, ' '.join(normal))

    def test_ubuntu_prepare_preserves_other_guests_and_existing_data(self):
        image = os.environ.get('PK_TEST_QEMU_IMG') or shutil.which('qemu-img')
        if not image: self.skipTest('qemu-img not installed')
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp).resolve(); root = base/'Ubuntu';root.mkdir()
            windows=base/'Windows';windows.mkdir();(windows/'keep').write_bytes(b'accounts and files')
            android=base/'Android';android.mkdir();(android/'keep').write_bytes(b'game save')
            template=base/'template.fd';template.write_bytes(b'firmware variables')
            config={'qemuImg':image,'variablesTemplate':str(template)}
            with mock.patch.object(ubuntu.shutil,'disk_usage',return_value=SimpleNamespace(free=100*1024**3)):
                ubuntu.prepare_disk(config, root)
            before=(root/'ubuntu.qcow2').read_bytes()
            (root/'uefi-vars.fd').write_bytes(b'installed boot entry')
            ubuntu.prepare_disk(config, root)
            self.assertEqual((root/'ubuntu.qcow2').read_bytes(),before)
            self.assertEqual((root/'uefi-vars.fd').read_bytes(),b'installed boot entry')
            self.assertEqual((windows/'keep').read_bytes(),b'accounts and files')
            self.assertEqual((android/'keep').read_bytes(),b'game save')

    def test_download_checksum_failure_never_installs_or_keeps_partial_iso(self):
        import io
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)
            source=io.BytesIO(b'incomplete image');source.headers={'Content-Length':'16'}
            with mock.patch.object(ubuntu.urllib.request,'urlopen',return_value=source):
                with self.assertRaisesRegex(RuntimeError,'SHA-256'): ubuntu.download(folder)
            self.assertEqual(list(folder.iterdir()),[])

    def test_unknown_qemu_source_aborts_before_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);(folder/'ui').mkdir();source=folder/'ui/cocoa.m';source.write_text('unrecognized source')
            with self.assertRaises(RuntimeError): embedded.patch(folder)
            self.assertEqual(source.read_text(),'unrecognized source')

    def test_existing_runtime_upgrade_only_rebuilds_qemu(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp).resolve();(root/'Sources/qemu/ui').mkdir(parents=True)
            (root/'Sources/qemu/ui/cocoa.m').write_text('fixture')
            (root/'Runtime/bin').mkdir(parents=True)
            (root/'Runtime/bin/qemu-system-aarch64').write_bytes(b'existing engine')
            (root/'runtime-ready.json').write_text('{"version":1}')
            commands=[]
            with mock.patch.object(lab,'prepare_embedded_player') as patch, \
                 mock.patch.object(lab,'run',return_value='pinned'), \
                 mock.patch.object(lab,'run_logged',side_effect=lambda args,*a,**k:commands.append(args)):
                lab.upgrade_embedded_player(root,{'qemu':{'commit':'pinned'}},{'PATH':'/usr/bin'})
            self.assertEqual(commands,[['make','-j4','install']])
            self.assertEqual(json.loads((root/'runtime-ready.json').read_text())['embeddedPlayer'],1)
            patch.assert_called_once()
            backup=root/('PlayerBackup-before-v'+str(lab.RUNTIME_POLICY['embeddedRevision']))
            self.assertEqual((backup/'qemu-system-aarch64').read_bytes(),b'existing engine')
