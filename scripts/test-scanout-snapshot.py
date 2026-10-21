#!/usr/bin/env python3
"""Compile production snapshot code and test reuse/cropping on real Metal."""
from pathlib import Path
import ast, importlib.util, re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('snapshot_repair',root/'Packaging/GraphicsLab/embedded_repair.py')
repair=importlib.util.module_from_spec(spec);spec.loader.exec_module(repair)
# Use the production-patched Cocoa dependency list, not an independent list
# that could hide a missing QEMU framework (as the old test did).
base=(root/'Tests/Fixtures/PinnedQEMUCocoaDependency.meson').read_text()
meson=repair.repaired_meson(base)
frameworks=ast.literal_eval(re.search(r'modules:\s*(\[[^\]]+\])',meson)[1])
link_args=[arg for framework in frameworks for arg in ['-framework',framework]]
source=r'''
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdbool.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
FRAGMENT
static void pixels(id<MTLTexture> texture, uint8_t *out, NSUInteger width, NSUInteger height) {
    id<MTLCommandQueue> q=[texture.device newCommandQueue];
    id<MTLBuffer> b=[texture.device newBufferWithLength:256*height options:MTLResourceStorageModeShared];
    id<MTLCommandBuffer> cb=[q commandBuffer];id<MTLBlitCommandEncoder> blit=[cb blitCommandEncoder];
    [blit copyFromTexture:texture sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0)
        sourceSize:MTLSizeMake(width,height,1) toBuffer:b destinationOffset:0
        destinationBytesPerRow:256 destinationBytesPerImage:256*height];
    [blit endEncoding];[cb commit];[cb waitUntilCompleted];
    assert(cb.status==MTLCommandBufferStatusCompleted);
    for(NSUInteger y=0;y<height;y++)memcpy(out+y*width*4,(uint8_t*)b.contents+y*256,width*4);
    [b release];[q release];
}
int main(void) { @autoreleasepool {
    id<MTLDevice> device=MTLCreateSystemDefaultDevice();
    if(!device){puts("SKIP: no Metal GPU; production snapshot compiled against SDK");return 0;}
    MTLTextureDescriptor *d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
        width:32 height:16 mipmapped:NO];d.storageMode=MTLStorageModeShared;
    id<MTLTexture> guest=[device newTextureWithDescriptor:d];assert(guest);
    uint8_t input[32*16*4],out[32*16*4];
    for(unsigned i=0;i<sizeof(input);i++)input[i]=(i*13)%251;
    [guest replaceRegion:MTLRegionMake2D(0,0,32,16) mipmapLevel:0 withBytes:input bytesPerRow:128];
    assert(stratovo_capture_scanout(guest,MTLOriginMake(0,0,0),MTLSizeMake(32,16,1)));
    id<MTLTexture> displayed=[stratovo_scanout_snapshot retain];
    /* Guest reuses the source immediately, before AppKit gets to read. */
    uint8_t reused[sizeof(input)];memset(reused,0xa5,sizeof(reused));
    [guest replaceRegion:MTLRegionMake2D(0,0,32,16) mipmapLevel:0 withBytes:reused bytesPerRow:128];
    pixels(displayed,out,32,16);assert(!memcmp(out,input,sizeof(input)));
    /* Coalesce a second completed snapshot without changing the displayed one. */
    assert(stratovo_capture_scanout(guest,MTLOriginMake(4,3,0),MTLSizeMake(12,8,1)));
    pixels(stratovo_scanout_snapshot,out,12,8);
    for(unsigned i=0;i<12*8*4;i++)assert(out[i]==0xa5);
    pixels(displayed,out,32,16);assert(!memcmp(out,input,sizeof(input)));
    assert(!stratovo_capture_scanout(guest,MTLOriginMake(31,0,0),MTLSizeMake(12,8,1)));
    [displayed release];[guest release];[stratovo_scanout_snapshot release];[stratovo_snapshot_queue release];
    puts("PASS: Metal snapshot survives guest buffer reuse, coalescing and cropped scanout");
} }
'''.replace('FRAGMENT',(root/'Packaging/GraphicsLab/scanout_snapshot.m.inc').read_text())
with tempfile.TemporaryDirectory() as tmp:
    src=Path(tmp)/'snapshot.m';src.write_text(source);exe=Path(tmp)/'snapshot'
    old_frameworks=ast.literal_eval(re.search(r'modules:\s*(\[[^\]]+\])',base)[1])
    old_args=[arg for framework in old_frameworks for arg in ['-framework',framework]]
    failed=subprocess.run(['xcrun','clang','-fblocks','-Werror','-mmacosx-version-min=14.0',
                           str(src),*old_args,'-o',str(exe)],capture_output=True,text=True)
    assert failed.returncode != 0 and '_OBJC_CLASS_$_MTLTextureDescriptor' in failed.stderr, \
        'Unpatched Cocoa dependencies must reproduce the missing Metal class: '+failed.stderr
    subprocess.run(['xcrun','clang','-fblocks','-Werror','-mmacosx-version-min=14.0',
                    str(src),*link_args,'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
