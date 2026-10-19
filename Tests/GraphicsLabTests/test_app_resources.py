"""Exercise the exact resource copied by the app, not a separate terminal patch."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('app_lab', ROOT/'Packaging/GraphicsLab/lab.py')
lab = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lab)

class AppResourceTests(unittest.TestCase):
    def test_launch_has_tpm_without_unsupported_ppi_and_keeps_3d(self):
        root=Path('/Volumes/ChosenSSD/Stratovo/GraphicsLab')
        args=lab.launch_arguments(root,root/'TestVM',Path('/tmp/tpm.sock'),Path('/tmp/qmp.sock'))
        self.assertIn('tpm-tis-device,tpmdev=tpm0',args)
        self.assertFalse(any('ppi=' in a for a in args))
        self.assertIn('virtio-ramfb-gl,hostmem=8G,blob=true,venus=false,neptune=true',args)
        self.assertTrue(any('/Volumes/ChosenSSD/' in a for a in args))
        self.assertFalse(any('/Volumes/Extern/' in a for a in args))

    def test_actual_build_command_uses_fixed_dependencies_and_options(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            llvm=root/'Toolchains/llvm/bin';llvm.mkdir(parents=True)
            (llvm/'llvm-config').write_text('fixture')
            # Stop at the QEMU invocation after collecting actual generated commands.
            commands=[]
            def run(args,**kwargs):
                args=list(map(str,args));commands.append(args)
                return '15.0.7' if '--version' in args else ''
            def checkout(info,target,env,**kwargs):
                target.mkdir(parents=True,exist_ok=True)
                return target
            with mock.patch.object(lab,'prerequisites'), mock.patch.object(lab,'libcpp_assertion_setting',return_value='WK_LIBCPP_ASSERTIONS_CFLAGS=probe'), mock.patch.object(lab,'ensure_pkg_config'), mock.patch.object(lab,'checkout',side_effect=checkout), mock.patch.object(lab,'run',side_effect=run), mock.patch.object(lab,'run_logged',side_effect=lambda args,*a,**kw:commands.append(list(map(str,args)))), mock.patch.object(lab.Path,'is_file',return_value=True), mock.patch.object(lab,'download',side_effect=RuntimeError('stop after build')):
                with self.assertRaisesRegex(RuntimeError,'stop after build'):
                    lab.build(root,{'angle':{},'libepoxy':{},'dxmt':{},'virglrenderer':{},'qemu':{},'drivers':{'assets':[{'name':'viogpu3d-arm64x-signed.zip','browser_download_url':'https://example.org','size':1,'digest':'sha256:a'}]}},{},{'PATH':'/usr/bin'})
            qemu=next(c for c in commands if c[0].endswith('/qemu/configure'))
            for flag in ['--disable-pvg','--enable-gnutls','--disable-nettle','--disable-gcrypt','--enable-virglrenderer','--enable-hvf']:
                self.assertIn(flag,qemu)
            pip=next(c for c in commands if 'pip' in c)
            self.assertIn('PyYAML',pip);self.assertIn('tomli',pip)
            angle=next(c for c in commands if c[0]=='/usr/bin/xcodebuild')
            self.assertTrue(any('-Wno-error=nontrivial-memcall' in a and '-Wno-error=unnecessary-virtual-specifier' in a for a in angle))
            self.assertNotIn('GCC_TREAT_WARNINGS_AS_ERRORS=NO',angle)

    def test_app_overwrites_working_copy_with_correct_bundled_resource(self):
        controller=(ROOT/'Sources/Stratovo/WindowsGraphicsLabView.swift').read_text()
        builder=(ROOT/'scripts/build-app.sh').read_text()
        self.assertIn('resources.appendingPathComponent(name)',controller)
        self.assertIn('Packaging/GraphicsLab',builder)
        self.assertIn('Contents/Resources/GraphicsLab',builder)
        self.assertIn('/opt/homebrew/opt/zlib/lib/pkgconfig',lab.graphics_pkg_config_path(Path('/chosen')))
