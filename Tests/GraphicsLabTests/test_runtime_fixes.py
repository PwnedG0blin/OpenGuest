"""Apply the production upgrade to the exact pinned sources and prior patches."""
from pathlib import Path
import importlib.util, subprocess, tempfile, unittest, zipfile
from unittest import mock

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('runtime_repair',ROOT/'Packaging/GraphicsLab/embedded_repair.py')
repair=importlib.util.module_from_spec(spec);spec.loader.exec_module(repair)

class RuntimeFixTests(unittest.TestCase):
    def fixture(self,folder):
        with zipfile.ZipFile(ROOT/'Tests/Fixtures/PinnedQEMU.zip') as z:z.extractall(folder)
        (folder/'meson.build').write_text((ROOT/'Tests/Fixtures/PinnedQEMUCocoaDependency.meson').read_text())
        subprocess.run(['git','init','-q',folder],check=True)
        subprocess.run(['git','add','.'],cwd=folder,check=True)
        subprocess.run(['git','-c','user.name=Fixture','-c','user.email=fixture@example.invalid',
                        'commit','-qm','Exact QEMU ae92cdc source fixture'],cwd=folder,check=True)

    def plan(self,folder):
        original=subprocess.check_output
        def git(args,**kwargs):
            return repair.PIN+'\n' if args[1:]==['rev-parse','HEAD'] else original(args,**kwargs)
        with mock.patch.object(repair.subprocess,'check_output',side_effect=git):return repair.plan(folder)

    def test_upgrade_previous_player_and_idempotency(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp).resolve();self.fixture(folder)
            cocoa=folder/'ui/cocoa.m';base=cocoa.read_text()
            cocoa.write_text(repair.repaired_cocoa(base,legacy_v7=True))
            changes=self.plan(folder)
            self.assertEqual({str(p.relative_to(folder)) for p,s in changes},
                             {'ui/cocoa.m','ui/vnc.c','target/arm/hvf/hvf.c','meson.build'})
            for p,s in changes:p.write_text(s)
            self.assertEqual(self.plan(folder),[])
            s=cocoa.read_text()
            self.assertIn('stratovo_capture_scanout(gl_scanout_src',s)
            self.assertIn('stratovo_scanout_snapshot : gl_scanout_src',s)
            self.assertIn('stratovo_save_window([cocoaView window])',s)
            self.assertNotIn('assert(isv)',(folder/'target/arm/hvf/hvf.c').read_text())
            self.assertIn("'QuartzCore', 'Metal'",(folder/'meson.build').read_text())

    def test_revision_nine_upgrade_changes_only_cocoa_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp).resolve();self.fixture(folder)
            for relative, transform in [('ui/cocoa.m',lambda b: repair.repaired_cocoa(b,legacy_v9=True)),
                                        ('ui/vnc.c',repair.repaired_vnc),
                                        ('target/arm/hvf/hvf.c',repair.repaired_hvf),
                                        ('meson.build',repair.repaired_meson)]:
                p=folder/relative;p.write_text(transform(p.read_text()))
            changes=self.plan(folder)
            self.assertEqual([str(p.relative_to(folder)) for p,s in changes],['ui/cocoa.m'])
            for p,s in changes:p.write_text(s)
            self.assertEqual(self.plan(folder),[])
            self.assertIn('stratovoBootDetected:logo', (folder/'ui/cocoa.m').read_text())

    def test_revision_eight_upgrade_adds_restart_cover_and_missing_link_dependency(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp).resolve();self.fixture(folder)
            # Revision 8 already has the snapshot and HVF repairs but no Metal
            # dependency. Upgrade must also recover a failed revision-8 build.
            for relative, transform in [('ui/cocoa.m',lambda base: repair.repaired_cocoa(base,legacy_v9=True)),
                                        ('ui/vnc.c',repair.repaired_vnc),
                                        ('target/arm/hvf/hvf.c',repair.repaired_hvf)]:
                p=folder/relative;p.write_text(transform(p.read_text()))
            changes=self.plan(folder)
            self.assertEqual([str(p.relative_to(folder)) for p,s in changes],['ui/cocoa.m','meson.build'])
            for p,s in changes:p.write_text(s)
            self.assertEqual(self.plan(folder),[])

    def test_unrelated_source_edit_stops_before_any_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp).resolve();self.fixture(folder)
            p=folder/'target/arm/hvf/hvf.c';p.write_text(p.read_text()+'\n/* independent edit */\n')
            cocoa=folder/'ui/cocoa.m';before=cocoa.read_text()
            with self.assertRaisesRegex(RuntimeError,'Andere Änderungen'):self.plan(folder)
            self.assertEqual(cocoa.read_text(),before)
