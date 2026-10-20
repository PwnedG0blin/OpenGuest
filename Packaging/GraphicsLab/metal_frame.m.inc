/* Stratovo embedded Metal readback, GPL-2.0-or-later, PwnedG0blin. */
typedef struct StratovoMetalFrame {
    CocoaGLRead *read;
    id<MTLBuffer> bytes;
    NSUInteger stride;
    bool rgba;
    bool completed;
} StratovoMetalFrame;

static void stratovo_frame_done(void *opaque)
{
    StratovoMetalFrame *frame = opaque;
    if (frame->completed) {
        stratovo_publish_pixels([frame->bytes contents], frame->stride,
            frame->read->size.width, frame->read->size.height, frame->rgba, false);
    } else {
        error_report("Stratovo: Metal framebuffer readback failed");
    }
    [frame->bytes release];
    cocoa_gl_read_done_bh(frame->read);
    g_free(frame);
}

static void stratovo_read_frame(CocoaGLRead *read)
{
    MTLPixelFormat format = [read->texture pixelFormat];
    bool rgba = format == MTLPixelFormatRGBA8Unorm || format == MTLPixelFormatRGBA8Unorm_sRGB;
    if (!rgba && format != MTLPixelFormatBGRA8Unorm && format != MTLPixelFormatBGRA8Unorm_sRGB) {
        static MTLPixelFormat last_format = MTLPixelFormatInvalid;
        if (format != last_format) {
            error_report("Stratovo: unsupported Metal pixel format %lu", (unsigned long)format);
            last_format = format;
        }
        cocoa_gl_read_done(read);
        return;
    }
    static id<MTLCommandQueue> queue;
    if (!queue) {
        queue = [[read->texture device] newCommandQueue];
    }
    NSUInteger stride = (read->size.width * 4 + 255) & ~(NSUInteger)255;
    id<MTLBuffer> bytes = [[read->texture device] newBufferWithLength:stride * read->size.height
                                                           options:MTLResourceStorageModeShared];
    id<MTLCommandBuffer> command = [queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [command blitCommandEncoder];
    if (!bytes || !command || !blit) {
        [bytes release];
        cocoa_gl_read_done(read);
        return;
    }
    [blit copyFromTexture:read->texture sourceSlice:0 sourceLevel:0
            sourceOrigin:read->origin sourceSize:read->size toBuffer:bytes
        destinationOffset:0 destinationBytesPerRow:stride
     destinationBytesPerImage:stride * read->size.height];
    [blit endEncoding];
    StratovoMetalFrame *frame = g_new0(StratovoMetalFrame, 1);
    frame->read = read;
    frame->bytes = bytes;
    frame->stride = stride;
    frame->rgba = rgba;
    static bool announced;
    if (!announced) {
        error_report("Stratovo embedded V2: Metal frame %lux%lu", (unsigned long)read->size.width,
                     (unsigned long)read->size.height);
        announced = true;
    }
    [command addCompletedHandler:^(id<MTLCommandBuffer> finished) {
        frame->completed = finished.status == MTLCommandBufferStatusCompleted;
        aio_bh_schedule_oneshot(qemu_get_aio_context(), stratovo_frame_done, frame);
    }];
    [command commit];
}
