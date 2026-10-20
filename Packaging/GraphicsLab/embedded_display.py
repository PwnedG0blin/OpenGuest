"""Upgrade the pinned QEMU display adapter, preserving unrelated source edits."""
from pathlib import Path
import importlib.util
import os
import subprocess
import tempfile

def patch(qemu):
    helper_path=Path(__file__).with_name('embedded_repair.py')
    spec=importlib.util.spec_from_file_location('stratovo_embedded_repair',helper_path)
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    try:
        changes=helper.plan(qemu)
    except subprocess.CalledProcessError as error:
        raise RuntimeError('QEMU-Anzeigequelle konnte nicht gegen die festgelegte Version geprüft werden.') from error
    for path,source in changes:
        fd,temp=tempfile.mkstemp(prefix='.stratovo-player-',dir=path.parent)
        try:
            with os.fdopen(fd,'w') as out:out.write(source)
            os.replace(temp,path)
        finally:
            if os.path.exists(temp):os.unlink(temp)
