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
static struct { QemuConsole *con; } dcl;
extern DisplaySurface *qemu_create_displaysurface(int, int);
extern void qemu_free_displaysurface(DisplaySurface *);
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
    file.write_text(stubs+(root/'Packaging/GraphicsLab/shared_frame.m.inc').read_text()+(root/'Packaging/GraphicsLab/metal_frame.m.inc').read_text())
    subprocess.run(['/usr/bin/xcrun','--sdk','macosx','clang','-x','objective-c','-fblocks',
                    '-fsyntax-only','-Werror=implicit-function-declaration','-Werror=incompatible-pointer-types',
                    '-mmacosx-version-min=14.0',str(file)],check=True)
print('Embedded Metal adapter compiled against macOS SDK (syntax check; no live VM).')

# Compile the exact OpenGL path with the SDK's actual GL declarations as well.
gl_stubs = r"""
#define GL_SILENCE_DEPRECATION
#import <OpenGL/gl3.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
static uint32_t gl_scanout_id;
static bool gl_scanout_y0_top, gl_dirty;
extern void with_gl_view_ctx(void (^block)(void));
extern int64_t g_get_monotonic_time(void);
extern void error_report(const char *, ...);
extern bool stratovo_publish_pixels(const uint8_t *, size_t, int, int, bool, bool);
#define qatomic_set(pointer, value) (*(pointer)=(value))
#define g_malloc malloc
#define g_free free
"""
with tempfile.TemporaryDirectory(prefix='stratovo-gl-check-') as tmp:
    file=Path(tmp)/'embedded-gl.m'
    file.write_text(gl_stubs+(root/'Packaging/GraphicsLab/gl_frame.m.inc').read_text())
    subprocess.run(['/usr/bin/xcrun','--sdk','macosx','clang','-x','objective-c','-fblocks',
                    '-fsyntax-only','-Werror=implicit-function-declaration','-Werror=incompatible-pointer-types',
                    '-mmacosx-version-min=14.0',str(file)],check=True)
print('Embedded OpenGL adapter compiled against macOS SDK (syntax check; no live VM).')
