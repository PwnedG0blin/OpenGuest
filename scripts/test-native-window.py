#!/usr/bin/env python3
"""Compile and run the real native layout/boot adapter with AppKit on macOS.
This exercises windows and layers, not a booted guest or GPU scanout.
"""
from pathlib import Path
import json,subprocess,tempfile
root=Path(__file__).resolve().parents[1]/'Packaging/GraphicsLab'
head=r'''
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#define CONFIG_OPENGL 1
#define USE_METAL 1
#define PIXMAN_x8r8g8b8 1
#define PIXMAN_a8r8g8b8 2
typedef struct DisplaySurface { int w,h; uint8_t *pixels; } DisplaySurface;
static int surface_width(DisplaySurface *s) { return s->w; }
static int surface_height(DisplaySurface *s) { return s->h; }
static int surface_stride(DisplaySurface *s) { return s->w*4; }
static int surface_bytes_per_pixel(DisplaySurface *s) { return 4; }
static int surface_format(DisplaySurface *s) { return PIXMAN_x8r8g8b8; }
static uint8_t *surface_data(DisplaySurface *s) { return s->pixels; }
'''
view=r'''
typedef NS_ENUM(NSInteger,QemuCocoaViewScanout) { QemuCocoaViewScanoutNone, QemuCocoaViewScanoutGL, QemuCocoaViewScanoutMetal };
@interface QemuCocoaView:NSView { @public struct { int width,height; } screen; }
@property(nonatomic,retain) CALayer *glLayer;
@property(nonatomic,retain) CAMetalLayer *metalLayer;
@property(nonatomic,assign) QemuCocoaViewScanout scanout;
- (NSRect)stratovoViewport;
- (void)stratovoLayout;
- (void)stratovoBootLogo:(NSRect)rect;
- (void)stratovoBootFinished;
@end
@implementation QemuCocoaView
'''
exercise=r'''
@end
int main(int argc,char **argv) { @autoreleasepool {
    setenv("STRATOVO_NATIVE_PLAYER","1",1);
    setenv("STRATOVO_BOOT_ARTWORK",argv[1],1);
    [NSApplication sharedApplication];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,800,600)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO;
    QemuCocoaView *view=[[QemuCocoaView alloc] initWithFrame:NSMakeRect(0,0,800,600)];
    view.wantsLayer=YES; view.glLayer=[CALayer layer];view.metalLayer=[CAMetalLayer layer];
    [view.layer addSublayer:view.glLayer]; [view.layer addSublayer:view.metalLayer];
    [window setContentView:view];
    view->screen.width=1920;view->screen.height=1080;
    view.metalLayer.drawableSize=CGSizeMake(1920,1080);
    NSSize sizes[]={ {1100,760},{1920,1080},{480,900},{3440,1440} };
    for(int i=0;i<4;i++) {
        [window setContentSize:sizes[i]]; [view stratovoLayout];
        NSRect fit=[view stratovoViewport];
        assert(NSEqualRects(view.glLayer.frame,fit));
        assert(NSEqualRects(view.metalLayer.frame,fit));
        assert(CGSizeEqualToSize(view.metalLayer.drawableSize,CGSizeMake(1920,1080)));
        assert(fabs(view.bounds.size.width-sizes[i].width)<1);
    }
    uint8_t pixels[128*128*4]={0},original[sizeof(pixels)];
    for(int y=0;y<40;y++)for(int x=0;x<64;x++) {
        size_t i=((44+y)*128+32+x)*4;
        pixels[i]=40; pixels[i+1]=80;pixels[i+2]=x<32 ? 200:20;
    }
    memcpy(original,pixels,sizeof(pixels)); DisplaySurface surface={128,128,pixels};
    NSRect logo=stratovo_boot_match(&surface);
    assert(NSEqualRects(logo,NSMakeRect(32,44,64,40)));
    view->screen.width=128;view->screen.height=128;
    view.scanout=QemuCocoaViewScanoutNone;[view stratovoBootLogo:logo];
    assert(!stratovo_boot_layer.hidden && stratovo_boot_hint.hidden);
    assert(NSEqualRects(stratovo_boot_layer.frame,view.bounds));
    assert(!memcmp(original,pixels,sizeof(pixels))); /* Source firmware framebuffer unchanged. */
    memset(pixels,255,sizeof(pixels));
    assert(NSEqualRects(stratovo_boot_match(&surface),NSZeroRect));
    [view stratovoBootLogo:NSZeroRect];assert(!stratovo_boot_layer.hidden);
    view.scanout=QemuCocoaViewScanoutMetal;[view stratovoBootLogo:logo];
    assert(!stratovo_boot_layer.hidden); /* Cover survives until the first completed frame. */
    [view stratovoBootFinished];assert(stratovo_boot_layer.hidden);
    [view stratovoBootLogo:logo];assert(stratovo_boot_layer.hidden); /* Never cover a GPU desktop. */
    [window close];
    return 0;
} }
'''
with tempfile.TemporaryDirectory(prefix='stratovo-native-test-') as tmp:
    tmp=Path(tmp);source=tmp/'native.m';binary=tmp/'native';fingerprint=tmp/'artwork.json'
    points=[{'x':x,'y':y,'red':200 if x<32 else 20,'green':80,'blue':40}
            for y in range(0,40,5) for x in range(0,64,8)]
    fingerprint.write_text(json.dumps({'width':64,'height':40,'samples':points}))
    source.write_text(head+(root/'native_geometry.h.inc').read_text()+(root/'native_view.m.inc').read_text()+view+(root/'native_methods.m.inc').read_text()+exercise)
    subprocess.run(['/usr/bin/xcrun','--sdk','macosx','clang','-x','objective-c','-fblocks',
        '-Werror=implicit-function-declaration','-Werror=incompatible-pointer-types',
        '-mmacosx-version-min=14.0',str(source),'-framework','Cocoa','-framework','QuartzCore','-framework','Metal','-o',str(binary)],check=True)
    subprocess.run([str(binary),str(fingerprint)],check=True)
print('PASS: actual AppKit adapter resizes GL/Metal layers, preserves drawable size, masks only known boot artwork and leaves guest pixels untouched.')
