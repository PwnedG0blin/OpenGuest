import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

source = Path(__file__).resolve().parents[2] / 'Android_Daten_uebernehmen.py'
spec = importlib.util.spec_from_file_location('android_data', source)
data = importlib.util.module_from_spec(spec)
spec.loader.exec_module(data)
TOOL = os.environ.get('PK_TEST_QEMU_IMG') or shutil.which('qemu-img')
IO = str(Path(TOOL).with_name('qemu-io')) if TOOL else None
HAS_IO = IO is not None and Path(IO).is_file()


class AndroidDataTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        (self.root / '.openguest-storage-id').write_text('test-storage')
        self.avd = self.root / 'Android/avd'
        self.original = self.avd / 'Android16.avd'; self.original.mkdir(parents=True)
        self.old_image = self.root / 'Android/sdk/system-images/android-36/google_apis_playstore/arm64-v8a'
        self.old_image.mkdir(parents=True)
        new_image = self.root / 'Android/sdk/system-images/android-37.0/google_apis_playstore/arm64-v8a'
        new_image.mkdir(parents=True); (new_image / 'system.img').write_bytes(b'new system')
        (self.original / 'config.ini').write_text(
            'image.sysdir.1=system-images/android-36/google_apis_playstore/arm64-v8a/\n'
            'disk.dataPartition.size=64G\nhw.lcd.width=1440\nhw.lcd.height=3120\nhw.lcd.density=500\n')
        (self.original / 'userdata-qemu.img').write_bytes(b'user-data' * 4096)
        (self.original / 'encryptionkey.img').write_bytes(b'metadata-key' * 4096)
        self.destination = self.avd / (data.PROFILE + '.avd')

    def transfer(self, guard=lambda: None):
        data.transfer(self.root, 'test-storage', 'Android16', TOOL, ensure_stopped=guard)

    def fingerprints(self):
        return {str(p.relative_to(self.original)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.original.rglob('*') if p.is_file()}

    @unittest.skipUnless(TOOL, 'qemu-img not installed')
    def test_real_independent_copy_keeps_crypto_and_never_copies_old_system_or_snapshots(self):
        snapshots = self.original / 'snapshots'; snapshots.mkdir()
        (snapshots / 'old').write_bytes(b'Android16 memory snapshot')
        (self.original / 'system.img.qcow2').write_bytes(b'old system overlay')
        before = self.fingerprints(); self.transfer()
        self.assertEqual(self.fingerprints(), before)
        for name in ('userdata-qemu.img', 'encryptionkey.img'):
            self.assertEqual((self.destination / name).read_bytes(), (self.original / name).read_bytes())
        (self.destination / 'userdata-qemu.img').write_bytes(b'new writes in Android17')
        self.assertEqual(self.fingerprints(), before)
        self.assertFalse((self.destination / 'snapshots').exists())
        self.assertFalse((self.destination / 'system.img.qcow2').exists())
        config = data.read_ini(self.destination / 'config.ini')
        self.assertIn('android-37.0/', config['image.sysdir.1'])
        self.assertEqual(config['hw.lcd.density'], '500')
        self.assertEqual(config['fastboot.forceColdBoot'], 'yes')
        self.assertEqual(data.read_ini(self.avd / (data.PROFILE + '.ini'))['path'], str(self.destination))
        self.assertFalse(json.loads((self.destination / 'Stratovo-Datenuebernahme.json').read_text())['bootCompatibilityVerified'])

    @unittest.skipUnless(TOOL and HAS_IO, 'qemu-img/qemu-io not installed')
    def test_real_qcow2_data_and_encryption_chains_are_flattened_and_compared(self):
        for filename in ('userdata-qemu.img', 'encryptionkey.img'):
            overlay = self.original / (filename + '.qcow2')
            backing = filename if filename == 'userdata-qemu.img' else str(self.original / filename)
            subprocess.run([TOOL, 'create', '-f', 'qcow2', '-F', 'raw', '-b', backing, str(overlay)],
                           cwd=self.original, check=True, stdout=subprocess.DEVNULL)
            subprocess.run([IO, '-f', 'qcow2', '-c', 'write -P 0x41 0 4096', str(overlay)],
                           check=True, stdout=subprocess.DEVNULL)
        before = self.fingerprints(); self.transfer()
        for filename in ('userdata-qemu.img', 'encryptionkey.img'):
            self.assertEqual((self.destination / filename).read_bytes(), b'A' * 4096 + (self.original / filename).read_bytes()[4096:])
            self.assertFalse((self.destination / (filename + '.qcow2')).exists())
        self.assertEqual(self.fingerprints(), before)

    @unittest.skipUnless(TOOL, 'qemu-img not installed')
    def test_emulator_default_temp_sentinel_uses_verified_existing_avd_data(self):
        with (self.original / 'config.ini').open('a') as stream:
            stream.write('disk.dataPartition.path=<temp>\n')
        before = self.fingerprints()
        self.transfer()
        self.assertEqual(self.fingerprints(), before)
        self.assertEqual((self.destination / 'userdata-qemu.img').read_bytes(),
                         (self.original / 'userdata-qemu.img').read_bytes())
        self.assertNotIn('disk.dataPartition.path', data.read_ini(self.destination / 'config.ini'))
        self.assertFalse((self.original / '<temp>').exists())
        self.assertFalse((self.destination / '<temp>').exists())

    @unittest.skipUnless(TOOL, 'qemu-img not installed')
    def test_temp_sentinel_does_not_allow_a_missing_userdata_or_a_wrong_key_path(self):
        config = self.original / 'config.ini'
        original = config.read_text()
        config.write_text(original + 'disk.dataPartition.path=<temp>\n')
        (self.original / 'userdata-qemu.img').unlink()
        with self.assertRaisesRegex(RuntimeError, 'Android-Daten'): self.transfer()
        self.assertFalse(self.destination.exists())
        config.write_text(original + 'disk.dataPartition.path=<temp>\ndisk.encryptionKeyPartition.path=<temp>\n')
        with self.assertRaisesRegex(RuntimeError, 'Benutzerdefinierter Datenpfad'): self.transfer()
        self.assertFalse(self.destination.exists())

    def test_running_emulator_rejected_before_writing(self):
        def running(): raise RuntimeError('Android is running')
        with self.assertRaisesRegex(RuntimeError, 'running'): self.transfer(running)
        self.assertFalse(self.destination.exists())

    def test_existing_android17_never_overwritten(self):
        self.destination.mkdir(); (self.destination / 'keep').write_bytes(b'do not replace')
        with self.assertRaisesRegex(RuntimeError, 'bereits'): self.transfer()
        self.assertEqual((self.destination / 'keep').read_bytes(), b'do not replace')

    def test_custom_source_path_rejected_before_writing(self):
        with (self.original / 'config.ini').open('a') as stream:
            stream.write('disk.dataPartition.path=/other/important.img\n')
        with self.assertRaisesRegex(RuntimeError, 'Datenpfad'): self.transfer()
        self.assertFalse(self.destination.exists())

    @unittest.skipUnless(TOOL, 'qemu-img not installed')
    def test_symlink_and_missing_crypto_metadata_do_not_create_profile(self):
        key = self.original / 'encryptionkey.img'; key.unlink()
        outside = self.root / 'outside'; outside.write_bytes(b'secret'); key.symlink_to(outside)
        with self.assertRaisesRegex(RuntimeError, 'Verknüpfung'): self.transfer()
        self.assertEqual(outside.read_bytes(), b'secret'); key.unlink()
        with self.assertRaisesRegex(RuntimeError, 'Verschlüsselungsmetadaten'): self.transfer()
        self.assertFalse(self.destination.exists())

    @unittest.skipUnless(TOOL, 'qemu-img not installed')
    def test_external_backing_path_rejected_without_conversion(self):
        outside = self.root / 'outside.img'; outside.write_bytes(b'outside' * 4096)
        subprocess.run([TOOL, 'create', '-f', 'qcow2', '-F', 'raw', '-b', str(outside),
                        str(self.original / 'userdata-qemu.img.qcow2')], check=True, stdout=subprocess.DEVNULL)
        before = outside.read_bytes()
        with self.assertRaisesRegex(RuntimeError, 'fremder Datenpfad'): self.transfer()
        self.assertEqual(outside.read_bytes(), before); self.assertFalse(self.destination.exists())

    @unittest.skipUnless(TOOL, 'qemu-img not installed')
    def test_changed_source_discards_entire_unregistered_target(self):
        calls = 0
        def guard():
            nonlocal calls
            calls += 1
            if calls == 4:
                with (self.original / 'userdata-qemu.img').open('ab') as stream: stream.write(b'changed')
        with self.assertRaisesRegex(RuntimeError, 'verändert'): self.transfer(guard)
        self.assertFalse(self.destination.exists())
        self.assertFalse((self.avd / (data.PROFILE + '.ini')).exists())
        self.assertEqual(list(self.avd.glob('.android17-daten-*')), [])

    @unittest.skipUnless(TOOL, 'qemu-img not installed')
    def test_failure_during_final_registration_rolls_back_only_new_files(self):
        before = self.fingerprints()
        original_chmod = data.os.chmod
        def fail_locator(path, mode):
            if str(path).endswith(data.PROFILE + '.ini'): raise OSError('simulated registration failure')
            return original_chmod(path, mode)
        with mock.patch.object(data.os, 'chmod', side_effect=fail_locator):
            with self.assertRaisesRegex(OSError, 'simulated'): self.transfer()
        self.assertEqual(self.fingerprints(), before)
        self.assertFalse(self.destination.exists())
        self.assertFalse((self.avd / (data.PROFILE + '.ini')).exists())


if __name__ == '__main__': unittest.main()
