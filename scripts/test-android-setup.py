#!/usr/bin/env python3
"""Exercise the production setup script with local SDK/Java mocks; no downloads."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]

class AndroidSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='pixelkoje-setup-')
        self.root = Path(self.temp.name).resolve() / 'External disk' / 'Stratovo'
        self.tools = self.root / 'Android/sdk/cmdline-tools/latest/bin'
        self.tools.mkdir(parents=True)
        (self.root / '.openguest-storage-id').write_text('fixture-id')
        self.log = Path(self.temp.name) / 'calls.jsonl'
        mock = '#!' + sys.executable + '\n' + '''import json, os, pathlib, sys
r=pathlib.Path(os.environ['TEST_ROOT'])
with open(os.environ['TEST_LOG'], 'a') as f: f.write(json.dumps([pathlib.Path(sys.argv[0]).name, *sys.argv[1:]])+'\\n')
if pathlib.Path(sys.argv[0]).name == 'avdmanager':
 args=sys.argv[1:]; d=pathlib.Path(args[args.index('-p')+1]); d.mkdir()
 (d/'config.ini').write_text('disk.dataPartition.size=10G\\nhw.lcd.width=1080\\nuntouched=yes\\n')
 (d.parent/(d.stem+'.ini')).write_text('path='+str(d)+'\\n')
'''
        for name in ['sdkmanager', 'avdmanager']:
            target = self.tools / name
            target.write_text(mock)
            target.chmod(0o755)
        script = (PROJECT / 'Android_System_verwalten.command').read_text()
        script = script.replace('[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || exit 1', ':')
        script = script.replace('root="$(/usr/bin/plutil -extract root raw -o - "$config")"', 'root="$TEST_ROOT"')
        script = script.replace('id="$(/usr/bin/plutil -extract id raw -o - "$config")"', 'id="fixture-id"')
        # Running emulators are tested through the actual early-exit branch separately.
        script = script.replace('/usr/bin/pgrep', '/usr/bin/false')
        self.script = Path(self.temp.name) / 'setup.command'
        self.script.write_text(script)
        self.env = dict(os.environ, TEST_ROOT=str(self.root), TEST_LOG=str(self.log))
    def tearDown(self):
        self.temp.cleanup()
    def run_setup(self, *args):
        return subprocess.run(['bash', str(self.script), *args], env=self.env, text=True, capture_output=True, timeout=10)
    def calls(self):
        return [json.loads(x) for x in self.log.read_text().splitlines()]
    def test_existing_working_android16_is_not_overwritten(self):
        avd = self.root / 'Android/avd/CustomWorking16.avd'
        avd.mkdir(parents=True)
        config='image.sysdir.1=system-images/android-36/google_apis_playstore/arm64-v8a/\ndisk.dataPartition.size=64G\n'
        (avd/'config.ini').write_text(config)
        (avd/'userdata-qemu.img').write_bytes(b'precious game saves')
        result=self.run_setup('16', 'install', '0', 'CustomWorking16')
        self.assertEqual(result.returncode, 0, result.stderr+result.stdout)
        self.assertEqual((avd/'userdata-qemu.img').read_bytes(), b'precious game saves')
        self.assertEqual((avd/'config.ini').read_text(), config)
        self.assertFalse(any(x[0]=='avdmanager' for x in self.calls()))
    def test_android17_gets_its_own_64gb_profile_and_channel(self):
        result=self.run_setup('17', 'install', '1')
        self.assertEqual(result.returncode, 0, result.stderr+result.stdout)
        config=(self.root/'Android/avd/Pixelkoje_Android17_64GB.avd/config.ini').read_text()
        self.assertEqual(config.count('disk.dataPartition.size='), 1)
        self.assertIn('disk.dataPartition.size=64G', config)
        self.assertIn('untouched=yes', config)
        self.assertIn('--channel=1', self.calls()[0])
        self.assertIn('system-images;android-37.0;google_apis_playstore;arm64-v8a', self.calls()[0])
    def test_check_does_not_install_or_create_profile(self):
        result=self.run_setup('16', 'check', '3')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls=self.calls()
        self.assertEqual(len(calls), 1)
        self.assertIn('--list', calls[0])
        self.assertIn('--newer', calls[0])
        self.assertFalse(any(x.startswith('system-images;') for x in calls[0]))
    def test_update_is_scoped_to_selected_system_image(self):
        pkg=self.root/'Android/sdk/system-images/android-36/google_apis_playstore/arm64-v8a'
        pkg.mkdir(parents=True); (pkg/'package.xml').write_text('present')
        result=self.run_setup('16', 'update', '0')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls=self.calls()
        self.assertEqual(len(calls), 1)
        self.assertNotIn('--update', calls[0])
        self.assertNotIn('emulator', calls[0])
        self.assertIn('system-images;android-36;google_apis_playstore;arm64-v8a', calls[0])
    def test_foreign_symlink_aborts_before_sdk_mutation(self):
        external=Path(self.temp.name)/'foreign'; external.mkdir()
        (self.root/'Android/avd').symlink_to(external, target_is_directory=True)
        result=self.run_setup('16', 'install', '0')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.log.exists())
    def test_unknown_inputs_are_rejected(self):
        self.assertNotEqual(self.run_setup('15', 'install', '0').returncode, 0)
        self.assertNotEqual(self.run_setup('16', 'wipe', '0').returncode, 0)
        self.assertNotEqual(self.run_setup('16', 'install', '9').returncode, 0)

if __name__ == '__main__': unittest.main()
