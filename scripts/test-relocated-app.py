#!/usr/bin/env python3
"""Launch the packaged app with SwiftPM's original resource bundle hidden."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid

app, binary_dir = map(lambda p: Path(p).resolve(), sys.argv[1:])
original = binary_dir / 'Stratovo_StratovoCore.bundle'
hidden = binary_dir / ('Stratovo_StratovoCore.bundle.hidden-' + uuid.uuid4().hex)
assert original.is_dir() and not original.is_symlink()
packaged = app / 'Contents/Resources/Stratovo_StratovoCore.bundle'
assert packaged.is_dir(), 'Packaged localization bundle is missing'

with tempfile.TemporaryDirectory(prefix='stratovo-relocated-') as directory:
    directory = Path(directory)
    moved = directory / 'Stratovo.app'
    shutil.copytree(app, moved, symlinks=True)
    process = None
    original.rename(hidden)
    try:
        with (directory / 'launch.log').open('wb') as log:
            process = subprocess.Popen([str(moved / 'Contents/MacOS/Stratovo')],
                                       cwd=directory, stdout=log, stderr=log)
            try:
                code = process.wait(timeout=6)
            except subprocess.TimeoutExpired:
                print('PASS: relocated packaged app stays running without the SwiftPM build resources.')
            else:
                print((directory / 'launch.log').read_text(errors='replace'))
                raise RuntimeError('Relocated app exited during startup: ' + str(code))
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        hidden.rename(original)
