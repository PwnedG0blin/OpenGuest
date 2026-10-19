import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import contextlib
import tempfile
import unittest
from unittest import mock
import io
import tarfile
from types import SimpleNamespace
import zipfile

source = Path(__file__).resolve().parents[2] / 'Packaging/GraphicsLab/lab.py'
spec = importlib.util.spec_from_file_location('graphics_lab', source)
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)

class GraphicsLabTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
    def tearDown(self):
        self.tmp.cleanup()
    def test_symlinked_data_or_lock_cannot_touch_other_files(self):
        outside = self.root / 'outside'; outside.mkdir()
        (outside/'keep').write_text('preserve')
        linked = self.root/'linked'; linked.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(RuntimeError): lab.directory(linked/'nested')
        lock = self.root/'session.lock'; lock.symlink_to(outside/'keep')
        with self.assertRaises(OSError):
            with lab.locked(lock): pass
        self.assertEqual((outside/'keep').read_text(),'preserve')
        self.assertFalse((outside/'nested').exists())
    def test_concurrent_session_is_rejected(self):
        with lab.locked(self.root/'session.lock'):
            with self.assertRaises(RuntimeError):
                with lab.locked(self.root/'session.lock'): pass
    def test_driver_archive_path_traversal_and_links_are_rejected(self):
        for name, symlink in [('../outside', False), ('drivers/link', True)]:
            archive = self.root/'drivers.zip'
            with zipfile.ZipFile(archive,'w') as z:
                item = zipfile.ZipInfo(name)
                if symlink: item.external_attr = 0o120777 << 16
                z.writestr(item,b'payload')
            with self.assertRaises(RuntimeError): lab.extract_zip(archive,self.root/'out')
        self.assertFalse((self.root/'outside').exists())
    def test_launch_uses_only_standalone_test_disk_and_metal_dxmt_path(self):
        vm = self.root/'TestVM'; vm.mkdir()
        args = lab.launch_arguments(self.root,vm,Path('/tmp/pk-gpu-test/tpm.sock'),Path('/tmp/pk-gpu-test/qmp.sock'))
        blocks = [json.loads(args[i+1]) for i,a in enumerate(args) if a=='-blockdev']
        self.assertEqual(next(a for a in blocks if a['node-name']=='system')['file']['filename'],str(vm/'windows.qcow2'))
        self.assertIn('cocoa,gl=es',args)
        self.assertIn('virtio-ramfb-gl,hostmem=8G,blob=true,venus=false,neptune=true',args)
        self.assertNotIn('-vnc',args)
        self.assertEqual(lab.runtime_env(self.root,{})['NPT_BACKEND'],'dxmt')
        self.assertFalse(any('testsigned' in a.lower() for a in args))
    def test_preflight_reports_metal_before_starting_a_vm(self):
        failed = SimpleNamespace(returncode=1, stdout='Xcode unavailable')
        with mock.patch.object(lab.subprocess, 'run', return_value=failed), \
             mock.patch.object(lab.shutil, 'which', return_value=None), \
             mock.patch.object(lab.Path, 'is_file', return_value=True), \
             mock.patch.object(lab.shutil, 'disk_usage', return_value=SimpleNamespace(free=40*1024**3)):
            with self.assertRaisesRegex(RuntimeError, 'Vollständiges Xcode'):
                lab.prerequisites(self.root, {'PATH':'/usr/bin:/bin'})
        self.assertFalse((self.root/'TestVM').exists())
    def test_missing_pkg_config_is_recoverable_when_mac_dependencies_exist(self):
        ok = SimpleNamespace(returncode=0, stdout='/Applications/Xcode.app/metal')
        with mock.patch.object(lab.subprocess, 'run', return_value=ok), \
             mock.patch.object(lab.shutil, 'which', return_value=None), \
             mock.patch.object(lab.Path, 'is_file', return_value=True), \
             mock.patch.object(lab.shutil, 'disk_usage', return_value=SimpleNamespace(free=40*1024**3)):
            lab.prerequisites(self.root, {'PATH':'/usr/bin:/bin'})
        self.assertFalse((self.root/"TestVM").exists())
        self.assertFalse((self.root/"Runtime").exists())
    def test_source_extraction_rejects_links_and_keeps_tool_executable(self):
        archive = self.root/'source.tar'
        for name, link in [('pkg/tool',False), ('../outside',False), ('pkg/link',True)]:
            with tarfile.open(archive,'w') as tar:
                item=tarfile.TarInfo(name);item.mode=0o755
                if link: item.type=tarfile.SYMTYPE;item.linkname='/outside'
                else: item.size=4
                tar.addfile(item, None if link else io.BytesIO(b'test'))
            if name=='pkg/tool':
                folder=lab.extract_source(archive,self.root/'sources','pkg')
                self.assertTrue(os.access(folder/'tool',os.X_OK))
            else:
                with self.assertRaises(RuntimeError): lab.extract_source(archive,self.root/'sources','pkg')
        self.assertFalse((self.root.parent/'outside').exists())
    def test_receipt_alone_never_allows_a_test_windows_launch(self):
        (self.root/'runtime-ready.json').write_text('{}')
        self.assertFalse(lab.runtime_ready(self.root))
        for name in ('Runtime/bin/qemu-system-aarch64','Runtime/libexec/virgl_render_server','Runtime/lib/libdxmt-native.dylib','GraphicsDrivers.iso'):
            p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'fixture')
        self.assertTrue(lab.runtime_ready(self.root))
        (self.root/'GraphicsDrivers.iso').unlink()
        self.assertFalse(lab.runtime_ready(self.root))
    def test_noninteractive_failure_exits_even_with_open_stdin(self):
        process = subprocess.Popen([sys.executable, str(source), '--config', str(self.root/'missing.json'), 'check'],
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            code = process.wait(timeout=4)
            out, err = process.communicate()
            self.assertNotEqual(code, 0)
            self.assertNotIn('Enter zum Schließen', (out+err).decode())
        finally:
            if process.poll() is None:
                process.kill(); process.communicate()
    def test_compiler_error_is_kept_after_a_long_build_summary(self):
        log = self.root/'Logs/ANGLE-Build.log'
        script = "print('shader.metal:42: error: specific shader error');print('summary\\n'*2000);raise SystemExit(65)"
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, 'specific shader error'):
                lab.run_logged([sys.executable,'-c',script], log)
        self.assertIn('summary',log.read_text())
        last=(log.parent/'Letzter-Fehler.log').read_text()
        self.assertIn('specific shader error',last)
        self.assertLess(len(last),4096)
    def test_metal_probe_tests_compile_and_link_in_external_temp_only(self):
        calls=[]
        def compiler(args, **kwargs):
            calls.append(args)
            out=Path(args[-1]);self.assertIn(self.root/'Temp',out.parents)
            out.write_bytes(b'compiled fixture')
            return SimpleNamespace(returncode=0,stdout='')
        with mock.patch.object(lab.subprocess,'run',side_effect=compiler):
            lab.metal_probe(self.root,dict(os.environ))
        self.assertEqual(len(calls),2)
        self.assertIn('metal',calls[0]);self.assertIn('metallib',calls[1])
        self.assertEqual(list((self.root/'Temp').iterdir()),[])
    def test_metal_stub_failure_is_reported_before_angle_downloads(self):
        with mock.patch.object(lab.subprocess,'run',return_value=SimpleNamespace(returncode=1,stdout="error: cannot execute tool metal due to missing Metal Toolchain")):
            with self.assertRaisesRegex(RuntimeError,'missing Metal Toolchain'):
                lab.metal_probe(self.root,dict(os.environ))
        self.assertIn('missing Metal Toolchain',(self.root/'Logs/Letzter-Fehler.log').read_text())
        self.assertFalse((self.root/'TestVM').exists())
    def test_modern_libcpp_mode_is_selected_with_checks_enabled(self):
        with mock.patch.object(lab.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='')) as compiler:
            setting = lab.libcpp_assertion_setting(self.root, {})
        self.assertEqual(setting, 'WK_LIBCPP_ASSERTIONS_CFLAGS=-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE')
        self.assertEqual(compiler.call_count, 1)
        self.assertIn('hardening mode not selected', compiler.call_args.kwargs['input'])

    def test_older_sdk_can_retain_legacy_assertions_after_modern_probe_fails(self):
        with mock.patch.object(lab.subprocess, 'run', side_effect=[
                SimpleNamespace(returncode=1, stdout='error: hardening mode unavailable'),
                SimpleNamespace(returncode=0, stdout='')]) as compiler:
            setting = lab.libcpp_assertion_setting(self.root, {})
        self.assertEqual(setting, 'WK_LIBCPP_ASSERTIONS_CFLAGS=-D_LIBCPP_ENABLE_ASSERTIONS=1')
        self.assertEqual(compiler.call_count, 2)

    def test_broken_cpp_sdk_stops_without_disabling_assertions_or_starting_vm(self):
        with mock.patch.object(lab.subprocess, 'run', return_value=SimpleNamespace(returncode=1, stdout='error: SDK cannot compile')):
            with self.assertRaisesRegex(RuntimeError, 'weder den modernen'):
                lab.libcpp_assertion_setting(self.root, {})
        self.assertFalse((self.root/'TestVM').exists())
        self.assertIn('SDK cannot compile', (self.root/'Logs/Letzter-Fehler.log').read_text())

    def test_terminal_keeps_foreground_process_group_but_app_can_manage_its_own(self):
        base=self.root/'Data';base.mkdir()
        (base/'Windows').mkdir()
        (base/'.openguest-storage-id').write_text('fixture')
        config=self.root/'config.json';config.write_text(json.dumps({'root':str(base),'storageID':'fixture'}))
        for managed in [False,True]:
            argv=['lab.py','--config',str(config)] + (['--managed-process-group'] if managed else []) + ['check']
            with mock.patch.object(sys,'argv',argv), mock.patch.object(lab.platform,'system',return_value='Darwin'), \
                 mock.patch.object(lab.platform,'machine',return_value='arm64'), mock.patch.object(lab,'prerequisites'), \
                 mock.patch.object(lab.os,'getpgrp',return_value=1),mock.patch.object(lab.os,'getpid',return_value=2), \
                 mock.patch.object(lab.os,'setsid') as setsid:
                lab.main()
                self.assertEqual(setsid.call_count,1 if managed else 0)
    def test_clone_converts_to_independent_disk_and_preserves_source(self):
        image = os.environ.get('PK_TEST_QEMU_IMG') or shutil.which('qemu-img')
        if not image: self.skipTest('qemu-img not installed')
        base = self.root/'Data'; original=base/'Windows'; original.mkdir(parents=True)
        root = base/'GraphicsLab'; root.mkdir()
        disk = original/'windows.qcow2'
        raw = original/'seed.raw'
        with raw.open('wb') as f:
            f.write(b'Persistent Windows data' * 180)
            f.seek(8 * 1024 * 1024)
            f.write(b'Second nonzero extent' * 200)
            f.truncate(32 * 1024 * 1024)
        subprocess.run([image,'convert','-f','raw','-O','qcow2',str(raw),str(disk)],check=True,stdout=subprocess.DEVNULL)
        raw.unlink()
        (original/'uefi-vars.fd').write_bytes(b'original NVRAM')
        firmware=base/'firmware.fd'; firmware.write_bytes(b'firmware')
        tpm=original/'TPM';tpm.mkdir();(tpm/'tpm2-00.permall').write_bytes(b'persistent TPM state')
        before=hashlib.sha256(disk.read_bytes()).hexdigest()
        config={'root':str(base),'firmware':str(firmware),'qemuImg':image}
        with lab.locked(original/'session.lock'):
            cloned=lab.clone_vm(config,root,dict(os.environ))
        info=json.loads(subprocess.check_output([image,'info','--output=json',str(cloned/'windows.qcow2')],text=True))
        self.assertNotIn('backing-filename',info)
        self.assertEqual(hashlib.sha256(disk.read_bytes()).hexdigest(),before)
        self.assertEqual((cloned/'uefi-vars.fd').read_bytes(),b'original NVRAM')
        (cloned/'TPM/tpm2-00.permall').write_bytes(b'test changes')
        self.assertEqual((tpm/'tpm2-00.permall').read_bytes(),b'persistent TPM state')
        self.assertEqual(lab.clone_vm(config,root,dict(os.environ)),cloned)

if __name__ == '__main__': unittest.main()
