#!/usr/bin/env python3
"""Execute the same strict refresh-rate parser compiled into QEMU."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='stratovo-hz-') as folder:
    source = Path(folder) / 'rate.c'
    binary = Path(folder) / 'rate'
    source.write_text('#include <stdlib.h>\n#include <string.h>\n#include <assert.h>\n' +
        (root / 'Packaging/GraphicsLab/display_rate.h.inc').read_text() + r'''
int main(void) {
    int rates[] = {30,60,90,120,144,165,240};
    const char *strings[] = {"30","60","90","120","144","165","240"};
    for (int i=0;i<7;i++) assert(stratovo_refresh_hz(strings[i]) == rates[i]);
    const char *invalid[] = {"", "0", "-1", "999", "60junk", " 60", "60\n", "060"};
    for (int i=0;i<8;i++) assert(stratovo_refresh_hz(invalid[i]) == 0);
    assert(stratovo_refresh_hz(NULL) == 0);
    return 0;
}
''')
    subprocess.run([shutil.which('cc') or 'clang', '-Wall', '-Wextra', '-Werror', str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
print('PASS: guest refresh-rate parser accepts supported rates and rejects malformed values.')
