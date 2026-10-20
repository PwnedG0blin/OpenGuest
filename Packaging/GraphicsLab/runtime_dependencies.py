#!/usr/bin/env python3
"""Stage LLVM's matching C++ runtime and probe DXMT in an isolated process."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

NAMES = ('libc++.1.dylib', 'libc++abi.1.dylib', 'libunwind.1.dylib')
LLVM_DIRECTORY = 'clang+llvm-15.0.7-arm64-apple-darwin22.0'


def prepare(root, run=subprocess.run):
    root = Path(root).absolute()
    runtime = root / 'Runtime/lib'
    if root.resolve() != root or runtime.resolve() != runtime or not runtime.is_dir():
        raise RuntimeError('Der Grafik-Laufzeitordner fehlt oder ist verknüpft.')
    dxmt = runtime / 'libdxmt-native.dylib'
    if dxmt.is_symlink() or not dxmt.is_file():
        raise RuntimeError('Die DXMT-Grafikbibliothek fehlt oder ist verknüpft.')
    choices = [root / 'Toolchains' / LLVM_DIRECTORY / 'lib', Path('/opt/homebrew/opt/llvm@15/lib/c++'),
               Path('/opt/homebrew/opt/llvm@15/lib')]
    # All companions must come from the same LLVM installation, never a mix.
    source = next((p.resolve() for p in choices if all((p / n).is_file() for n in NAMES)), None)
    planned = []
    for name in NAMES:
        target = runtime / name
        if target.is_symlink():
            # Migrate only the exact manual links used for the earlier repair.
            if source is None or target.resolve() != (source / name).resolve():
                raise RuntimeError('Unbekannte Bibliotheksverknüpfung wird nicht ersetzt: ' + str(target))
        elif target.exists():
            if not target.is_file():
                raise RuntimeError('Keine Bibliotheksdatei: ' + str(target))
            continue
        if source is None:
            raise RuntimeError('LLVM-15-Laufzeitbibliotheken fehlen. Grafikvorbereitung erneut ausführen.')
        original = (source / name).resolve()
        if original.parent != source:
            raise RuntimeError('LLVM-Bibliothek verweist außerhalb ihres Bibliotheksordners: ' + name)
        run(['/usr/bin/lipo', '-verify_arch', 'arm64', str(original)], check=True, capture_output=True)
        planned.append((original, target))
    for original, target in planned:
        fd, temporary = tempfile.mkstemp(prefix='.stratovo-lib-', dir=runtime)
        os.close(fd)
        try:
            shutil.copy2(original, temporary)
            os.replace(temporary, target)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        print('Grafikbibliothek bereitgestellt: ' + target.name, flush=True)
    environment = dict(os.environ)
    environment['DYLD_FALLBACK_LIBRARY_PATH'] = str(runtime) + ':' + str(root / 'ANGLE.xcarchive/Products/usr/local/lib')
    probe_code = ('import ctypes,sys; from pathlib import Path; p=Path(sys.argv[1]); '
                  '[ctypes.CDLL(str(p.parent/n), mode=ctypes.RTLD_GLOBAL) for n in '
                  '("libunwind.1.dylib","libc++abi.1.dylib","libc++.1.dylib")]; ctypes.CDLL(str(p))')
    probe = run([sys.executable, '-c', probe_code, str(dxmt)],
                env=environment, text=True, capture_output=True, timeout=20)
    if probe.returncode:
        raise RuntimeError('DXMT konnte auf diesem Mac nicht geladen werden:\n' + (probe.stderr or probe.stdout)[-4000:])
    print('DXMT und C++-Laufzeit erfolgreich geladen.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    args = parser.parse_args()
    try:
        prepare(args.root)
    except Exception as error:
        print('Grafikprüfung angehalten: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
