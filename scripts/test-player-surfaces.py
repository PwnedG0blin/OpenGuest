#!/usr/bin/env python3
"""Exercise the actual CPU-frame and VNC adapter under address/UB sanitizers."""
from pathlib import Path
import os
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]/'Packaging/GraphicsLab'
stubs=r'''
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
typedef struct DisplaySurface { int w,h; uint8_t *bytes; } DisplaySurface;
typedef struct QemuConsole { DisplaySurface *surface; } QemuConsole;
typedef struct DisplayChangeListener { QemuConsole *con; } DisplayChangeListener;
typedef struct VncDisplay { DisplayChangeListener dcl; DisplaySurface *ds; struct VncDisplay *next; int switches,updates; } VncDisplay;
static struct { VncDisplay *first; } vnc_displays;
#define QTAILQ_FOREACH(v, head, field) for ((v)=(head)->first; (v); (v)=(v)->field)
static DisplayChangeListener dcl;
static int surface_width(DisplaySurface *s) { return s->w; }
static int surface_height(DisplaySurface *s) { return s->h; }
static int surface_stride(DisplaySurface *s) { return s->w*4; }
static uint8_t *surface_data(DisplaySurface *s) { return s->bytes; }
static DisplaySurface *qemu_create_displaysurface(int w,int h) { DisplaySurface *s=malloc(sizeof(*s));s->w=w;s->h=h;s->bytes=calloc((size_t)w*h,4);return s; }
static void qemu_free_displaysurface(DisplaySurface *s) { VncDisplay *v;QTAILQ_FOREACH(v,&vnc_displays,next){assert(v->ds!=s);}free(s->bytes);free(s); }
static void vnc_dpy_switch(DisplayChangeListener *listener,DisplaySurface *surface) { VncDisplay *v=(VncDisplay *)listener;v->ds=surface;v->switches++; }
static void vnc_dpy_update(DisplayChangeListener *listener,int x,int y,int w,int h) { VncDisplay *v=(VncDisplay *)listener;assert(w==v->ds->w && h==v->ds->h);v->updates++; }
'''
# Run the actual GL readback with a synthetic texture. Only the Objective-C
# block wrapper is removed here; the production function and its orientation
# selection are unchanged. The macOS job separately compiles the original block.
gl_stubs=r"""
typedef int GLint;
typedef unsigned GLuint;
enum { GL_READ_FRAMEBUFFER_BINDING, GL_DRAW_FRAMEBUFFER_BINDING,
 GL_PIXEL_PACK_BUFFER_BINDING, GL_PACK_ALIGNMENT, GL_PACK_ROW_LENGTH,
 GL_PACK_SKIP_ROWS, GL_PACK_SKIP_PIXELS, GL_FRAMEBUFFER,
 GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, GL_FRAMEBUFFER_COMPLETE,
 GL_PIXEL_PACK_BUFFER, GL_NO_ERROR, GL_RGBA, GL_UNSIGNED_BYTE,
 GL_READ_FRAMEBUFFER, GL_DRAW_FRAMEBUFFER };
static uint32_t gl_scanout_id=1;
static bool gl_scanout_y0_top, gl_dirty;
static const uint8_t *test_gl_source;
static int64_t g_get_monotonic_time(void) { static int64_t now;return now+=20000; }
static void glGetIntegerv(int name,GLint *v) { *v=0; }
static void glGenFramebuffers(int n,GLuint *v) { *v=1; }
#define glBindFramebuffer(...) ((void)0)
#define glFramebufferTexture2D(...) ((void)0)
#define glCheckFramebufferStatus(...) GL_FRAMEBUFFER_COMPLETE
#define glBindBuffer(...) ((void)0)
#define glPixelStorei(...) ((void)0)
#define glGetError(...) GL_NO_ERROR
#define glDeleteFramebuffers(...) ((void)0)
#define error_report(...) ((void)0)
#define qatomic_set(p,v) (*(p)=(v))
#define g_free free
#define g_malloc malloc
static void glReadPixels(int x,int y,int w,int h,int format,int type,void *pixels) {
    assert(x==0 && y==0 && w==2 && h==3);
    memcpy(pixels,test_gl_source,(size_t)w*h*4);
}
"""
gl_source=(root/'gl_frame.m.inc').read_text().replace('__block ', '').replace('with_gl_view_ctx(^{', '{').replace('    });\n', '    }\n')
exercise=r'''
int main(void) {
    DisplaySurface *gpu=qemu_create_displaysurface(640,480);
    memset(gpu->bytes,0x5a,(size_t)640*480*4);
    QemuConsole main_con={gpu},other_con={gpu}; dcl.con=&main_con;
    VncDisplay other={.dcl={&other_con},.ds=gpu};
    VncDisplay viewer={.dcl={&main_con},.ds=gpu,.next=&other};vnc_displays.first=&viewer;
    int sizes[][2]={{1920,1080},{31,17},{127,65},{1,1}};
    for (unsigned i=0;i<sizeof(sizes)/sizeof(sizes[0]);i++) {
        int w=sizes[i][0],h=sizes[i][1];size_t stride=(size_t)w*4+16;
        uint8_t *pixels=malloc(stride*h);
        for(size_t n=0;n<stride*h;n++)pixels[n]=(uint8_t)n;
        assert(stratovo_publish_pixels(pixels,stride,w,h,true,true));
        assert(viewer.ds->w==w && viewer.ds->h==h);
        assert(viewer.ds!=gpu && main_con.surface==gpu);
        assert(viewer.ds->bytes[0]==pixels[(h-1)*stride+2]);
        assert(viewer.ds->bytes[2]==pixels[(h-1)*stride]);
        assert(viewer.ds->bytes[(h-1)*w*4+1]==pixels[1]);
        int switches=viewer.switches;
        assert(stratovo_publish_pixels(pixels,stride,w,h,false,false));
        assert(viewer.switches==switches);
        assert(!memcmp(viewer.ds->bytes,pixels,(size_t)w*4));
        viewer.ds=gpu; /* A listener reconnects / receives a guest surface switch. */
        assert(stratovo_publish_pixels(pixels,stride,w,h,false,false));
        assert(viewer.ds!=gpu && viewer.switches==switches+1);
        free(pixels);
    }
    /* Match QEMU egl-headless's framebuffer-blit convention for BOTH flags.
       Distinct rows and columns catch vertical inversion and horizontal mirroring. */
    const uint8_t top_down[24]={1,2,3,255, 4,5,6,255,
                              11,12,13,255, 14,15,16,255,
                              21,22,23,255, 24,25,26,255};
    uint8_t bottom_up[24];
    for(int y=0;y<3;y++)memcpy(bottom_up+y*8,top_down+(2-y)*8,8);
    stratovo_gl_x=0;stratovo_gl_y=0;stratovo_gl_w=2;stratovo_gl_h=3;
    for(int flag=0;flag<2;flag++) {
        gl_scanout_y0_top=flag;
        test_gl_source=flag ? bottom_up : top_down;
        stratovo_read_gl_frame();
        for(int i=0;i<6;i++) {
            assert(viewer.ds->bytes[i*4]==top_down[i*4+2]);
            assert(viewer.ds->bytes[i*4+1]==top_down[i*4+1]);
            assert(viewer.ds->bytes[i*4+2]==top_down[i*4]);
        }
    }
    free(stratovo_gl_pixels);
    assert(other.updates==0 && other.switches==0 && other.ds==gpu);
    for(size_t n=0;n<(size_t)640*480*4;n++)assert(gpu->bytes[n]==0x5a);
    uint8_t pixel[4]={1,2,3,4};int updates=viewer.updates;
    assert(!stratovo_publish_pixels(pixel,4,8193,1,false,false));
    assert(!stratovo_publish_pixels(pixel,1,1,1,false,false));
    assert(viewer.updates==updates);
    vnc_displays.first=NULL;
    qemu_free_displaysurface(stratovo_cpu_surface);qemu_free_displaysurface(gpu);
    return 0;
}
'''
with tempfile.TemporaryDirectory(prefix='stratovo-surface-test-') as tmp:
    path=Path(tmp)/'surfaces.c';binary=Path(tmp)/'surfaces'
    path.write_text(stubs+(root/'vnc_frame.c.inc').read_text()+(root/'shared_frame.m.inc').read_text()+gl_stubs+gl_source+exercise)
    subprocess.run(['cc','-std=c11','-g','-fsanitize=address,undefined','-fno-omit-frame-pointer',str(path),'-o',str(binary)],check=True)
    # LeakSanitizer cannot enumerate threads in the container; ASan/UBSan stay on.
    subprocess.run([str(binary)],check=True,env=dict(os.environ,ASAN_OPTIONS='detect_leaks=0'))
print('PASS: real frame adapters preserve GPU buffers, resize, swizzle/flip, both GL row origins and reconnect under ASan/UBSan.')
