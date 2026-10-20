/* Stratovo embedded display, GPL-2.0-or-later, PwnedG0blin.
 * A bounded asynchronous Metal readback publishes the guest framebuffer to
 * QEMU's local VNC listener. No screen recording or video encoding is used.
 * Only one GPU read is in flight; newer frames coalesce through gl_dirty.
 */
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
    int width = frame->read->size.width;
    int height = frame->read->size.height;
    QemuConsole *con = qemu_console_lookup_by_index(0);
    if (frame->completed && con) {
        DisplaySurface *out = qemu_console_surface(con);
        if (surface_width(out) != width || surface_height(out) != height) {
            qemu_console_resize(con, width, height);
            out = qemu_console_surface(con);
        }
        if (surface_bytes_per_pixel(out) == 4) {
            uint8_t *dst = surface_data(out);
            const uint8_t *src = [frame->bytes contents];
            for (int y = 0; y < height; y++) {
                uint8_t *row = dst + y * surface_stride(out);
                const uint8_t *input = src + y * frame->stride;
                memcpy(row, input, width * 4);
                if (frame->rgba) {
                    for (int x = 0; x < width; x++) {
                        uint8_t red = row[x * 4];
                        row[x * 4] = row[x * 4 + 2];
                        row[x * 4 + 2] = red;
                    }
                }
            }
            dpy_gfx_update(con, 0, 0, width, height);
        }
    } else if (!frame->completed) {
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
        error_report("Stratovo: unsupported Metal pixel format %lu", (unsigned long)format);
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
    [command addCompletedHandler:^(id<MTLCommandBuffer> finished) {
        frame->completed = finished.status == MTLCommandBufferStatusCompleted;
        aio_bh_schedule_oneshot(qemu_get_aio_context(), stratovo_frame_done, frame);
    }];
    [command commit];
}
