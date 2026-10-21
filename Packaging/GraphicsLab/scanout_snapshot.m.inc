/* QEMU main-loop state. Snapshot each flush before the guest can reuse its
 * flip buffer; never ask the AppKit queue to read a guest-owned texture. */
static id<MTLTexture> stratovo_scanout_snapshot;
static MTLSize stratovo_snapshot_size;
static id<MTLCommandQueue> stratovo_snapshot_queue;
static bool stratovo_capture_scanout(id<MTLTexture> source, MTLOrigin origin, MTLSize size)
{
    @autoreleasepool {
        if (!source || !size.width || !size.height ||
            origin.x > source.width || origin.y > source.height ||
            size.width > source.width - origin.x || size.height > source.height - origin.y) {
            return false;
        }
        id<MTLDevice> device = source.device;
        MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:source.pixelFormat
                                      width:size.width height:size.height mipmapped:NO];
        desc.storageMode = MTLStorageModePrivate;
        id<MTLTexture> snapshot = [device newTextureWithDescriptor:desc];
        if (stratovo_snapshot_queue.device != device) {
            [stratovo_snapshot_queue release];
            stratovo_snapshot_queue = [device newCommandQueue];
        }
        id<MTLCommandQueue> queue = stratovo_snapshot_queue;
        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLBlitCommandEncoder> blit = [command blitCommandEncoder];
        if (!snapshot || !queue || !command || !blit) {
            [blit endEncoding]; [snapshot release];
            return false;
        }
        [blit copyFromTexture:source sourceSlice:0 sourceLevel:0 sourceOrigin:origin sourceSize:size
              toTexture:snapshot destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0,0,0)];
        [blit endEncoding];
        [command commit];
        [command waitUntilCompleted];
        bool ok = command.status == MTLCommandBufferStatusCompleted;
        if (ok) {
            [stratovo_scanout_snapshot release];
            stratovo_scanout_snapshot = snapshot;
            stratovo_snapshot_size = size;
        } else { [snapshot release]; }
        return ok;
    }
}
