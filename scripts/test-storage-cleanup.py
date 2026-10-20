#!/usr/bin/env python3
"""Check package selection and the native recoverable move, using fixtures only."""
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('cleanup', HERE / 'storage-cleanup.py')
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)

class CleanupTests(unittest.TestCase):
    def test_only_known_older_versions_are_selected(self):
        for name in ['Pixelkoje_0.3.20_Privat.zip', 'Stratovo_0.3.28_Privat (1).zip',
                     'Stratovo_1.0_Beta3_Privat 2', 'Stratovo_1.0.0-beta.4_AppleSilicon.dmg']:
            self.assertTrue(cleanup.older(name), name)
        for name in ['Stratovo_1.0_Beta5_Privat.zip', 'Stratovo_1.0_Beta6_Privat.zip',
                     'Stratovo_MeineDateien.zip', 'Familienfotos.zip', 'Windows', 'GraphicsLab']:
            self.assertFalse(cleanup.older(name), name)

    def test_guest_data_current_package_and_symlinks_are_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp).resolve()
            root = base / 'OpenGuest'; root.mkdir()
            downloads = base / 'Downloads'; downloads.mkdir()
            package = downloads / 'Stratovo_1.0_Beta5_Privat'; package.mkdir()
            builds = root / 'Builds'; builds.mkdir()
            old = builds / 'Stratovo-1.0-Beta3-Privat'; old.mkdir()
            (builds / 'Stratovo-1.0-Beta5-Privat').mkdir()
            (builds / 'Stratovo-1.0-Beta6-Privat').mkdir()
            for name in cleanup.PROTECTED:
                folder = root / name; folder.mkdir()
                (folder / 'Stratovo_1.0_Beta2_Privat.zip').write_text('guest data')
            archive = base / 'Pixelkoje_0.3.20_Privat.zip'; archive.write_text('old installer')
            linked = downloads / 'Stratovo_0.3.28_Privat.zip'; linked.symlink_to(archive)
            personal = downloads / 'my-source.zip'; personal.write_text('personal')
            self.assertEqual(cleanup.candidates(root, downloads, package), sorted([old, archive], key=str))
            # The executable package and any enclosing old build are excluded.
            self.assertNotIn(old, cleanup.candidates(root, downloads, old / 'Quellcode'))
            self.assertEqual(personal.read_text(), 'personal')
            self.assertEqual(archive.read_text(), 'old installer')  # Planning never moves.

    def test_cleanup_requires_current_installed_app(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp).resolve() / 'Stratovo.app'
            (app / 'Contents').mkdir(parents=True)
            info = app / 'Contents/Info.plist'
            info.write_bytes(plistlib.dumps({'CFBundleIdentifier': cleanup.BUNDLE, 'StratovoReleaseVersion': '1.0.0-beta.4'}))
            with self.assertRaises(RuntimeError): cleanup.check_install(app)
            info.write_bytes(plistlib.dumps({'CFBundleIdentifier': cleanup.BUNDLE, 'StratovoReleaseVersion': cleanup.CURRENT}))
            cleanup.check_install(app)

    @unittest.skipUnless(sys.platform == 'darwin', 'Native Trash API needs macOS')
    def test_native_trash_move_can_be_restored_without_data_loss(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp).resolve() / 'stratovo-cleanup-fixture.txt'
            source.write_bytes(b'recoverable fixture')
            result = subprocess.run(['/usr/bin/xcrun', 'swift', str(HERE / 'trash-packages.swift'), str(source)],
                                    text=True, capture_output=True, check=True)
            records = json.loads(result.stdout)
            self.assertEqual(records[0]['status'], 'moved', records)
            trashed = Path(records[0]['trash'])
            try:
                self.assertFalse(source.exists())
                self.assertEqual(trashed.read_bytes(), b'recoverable fixture')
            finally:
                if trashed.exists(): trashed.rename(source)
            self.assertEqual(source.read_bytes(), b'recoverable fixture')

if __name__ == '__main__':
    unittest.main()
