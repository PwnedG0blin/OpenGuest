import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest

RESOURCE = Path(__file__).resolve().parents[2] / 'Packaging/GraphicsLab/runtime_dependencies.py'
spec = importlib.util.spec_from_file_location('runtime_dependencies_test', RESOURCE)
dependencies = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dependencies)


class RuntimeDependenciesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.runtime = self.root / 'Runtime/lib'
        self.runtime.mkdir(parents=True)
        (self.runtime / 'libdxmt-native.dylib').write_bytes(b'dxmt')
        self.source = self.root / 'Toolchains' / dependencies.LLVM_DIRECTORY / 'lib'
        self.source.mkdir(parents=True)
        for name in dependencies.NAMES:
            (self.source / name).write_bytes(name.encode())
        self.commands = []

    def command(self, args, **kwargs):
        self.commands.append(args)
        return SimpleNamespace(returncode=0, stdout='', stderr='')

    def test_missing_libraries_are_copied_and_manual_links_become_durable(self):
        (self.runtime / dependencies.NAMES[0]).symlink_to(self.source / dependencies.NAMES[0])
        dependencies.prepare(self.root, run=self.command)
        for name in dependencies.NAMES:
            self.assertFalse((self.runtime / name).is_symlink())
            self.assertEqual((self.runtime / name).read_bytes(), name.encode())
        self.assertEqual(sum(c[0] == '/usr/bin/lipo' for c in self.commands), 3)
        self.commands.clear()
        dependencies.prepare(self.root, run=self.command)
        self.assertEqual(len(self.commands), 1)  # Existing copies still get a real load probe.

    def test_missing_companion_or_wrong_architecture_never_installs_partial_set(self):
        (self.source / dependencies.NAMES[-1]).unlink()
        with self.assertRaises(RuntimeError):
            dependencies.prepare(self.root, run=self.command)
        self.assertEqual(len(list(self.runtime.iterdir())), 1)
        (self.source / dependencies.NAMES[-1]).write_bytes(b'unwind')
        def rejected(args, **kwargs):
            raise subprocess.CalledProcessError(1, args)
        with self.assertRaises(subprocess.CalledProcessError):
            dependencies.prepare(self.root, run=rejected)
        self.assertEqual(len(list(self.runtime.iterdir())), 1)

    def test_unrelated_link_is_not_overwritten_and_load_error_is_reported(self):
        outside = self.root / 'unrelated'
        outside.write_bytes(b'keep')
        target = self.runtime / dependencies.NAMES[0]
        target.symlink_to(outside)
        with self.assertRaisesRegex(RuntimeError, 'Unbekannte'):
            dependencies.prepare(self.root, run=self.command)
        self.assertEqual(outside.read_bytes(), b'keep')
        target.unlink()
        def fail_probe(args, **kwargs):
            if args[0] == '/usr/bin/lipo':
                return self.command(args, **kwargs)
            return SimpleNamespace(returncode=1, stdout='', stderr='Library not loaded: example')
        with self.assertRaisesRegex(RuntimeError, 'Library not loaded: example'):
            dependencies.prepare(self.root, run=fail_probe)

    @unittest.skipUnless(sys.platform == 'darwin', 'Requires the macOS dynamic loader')
    def test_actual_macos_loader_resolves_staged_rpath_companions(self):
        pieces = [
            ('libunwind.1.dylib', 'int stratovo_unwind(void) { return 1; }', []),
            ('libc++abi.1.dylib', 'extern int stratovo_unwind(void); int stratovo_abi(void) { return stratovo_unwind(); }', ['libunwind.1.dylib']),
            ('libc++.1.dylib', 'extern int stratovo_abi(void); int stratovo_cpp(void) { return stratovo_abi(); }', ['libc++abi.1.dylib']),
            ('libdxmt-native.dylib', 'extern int stratovo_cpp(void); int stratovo_dxmt(void) { return stratovo_cpp(); }', ['libc++.1.dylib']),
        ]
        for name, code, linked in pieces:
            c = self.root / (name + '.c')
            c.write_text(code)
            output = self.runtime / name if name == 'libdxmt-native.dylib' else self.source / name
            subprocess.run(['/usr/bin/xcrun', 'clang', '-arch', 'arm64', '-dynamiclib', str(c),
                            '-Wl,-install_name,@rpath/' + name, '-Wl,-rpath,' + str(self.runtime),
                            *[str(self.source / n) for n in linked], '-o', str(output)], check=True)
        dependencies.prepare(self.root)
        for name in dependencies.NAMES:
            self.assertTrue((self.runtime / name).is_file())
