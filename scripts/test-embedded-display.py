#!/usr/bin/env python3
"""Compile the exact embedded Metal adapter against the selected macOS SDK."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
stubs = r'''
#import <Metal/Metal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
typedef struct { id<MTLTexture> texture; MTLOrigin origin; MTLSize size; } CocoaGLRead;
typedef struct QemuConsole QemuConsole;
typedef struct DisplaySurface DisplaySurface;
extern QemuConsole *qemu_console_lookup_by_index(int);
extern DisplaySurface *qemu_console_surface(QemuConsole *);
extern int surface_width(DisplaySurface *);
extern int surface_height(DisplaySurface *);
extern int surface_stride(DisplaySurface *);
extern int surface_bytes_per_pixel(DisplaySurface *);
extern uint8_t *surface_data(DisplaySurface *);
extern void qemu_console_resize(QemuConsole *, int, int);
extern void dpy_gfx_update(QemuConsole *, int, int, int, int);
extern void error_report(const char *, ...);
extern void cocoa_gl_read_done_bh(void *);
extern void cocoa_gl_read_done(CocoaGLRead *);
extern void *qemu_get_aio_context(void);
extern void aio_bh_schedule_oneshot(void *, void (*)(void *), void *);
#define g_new0(type, n) ((type *)calloc((n), sizeof(type)))
#define g_free free
'''
with tempfile.TemporaryDirectory(prefix='stratovo-metal-check-') as tmp:
    file = Path(tmp)/'embedded.m'
    file.write_text(stubs+(root/'Packaging/GraphicsLab/embedded_bridge.m.inc').read_text())
    subprocess.run(['/usr/bin/xcrun','--sdk','macosx','clang','-x','objective-c','-fblocks',
                    '-fsyntax-only','-Werror=implicit-function-declaration','-Werror=incompatible-pointer-types',
                    '-mmacosx-version-min=14.0',str(file)],check=True)
print('Embedded Metal adapter compiled against macOS SDK (syntax check; no live VM).')
