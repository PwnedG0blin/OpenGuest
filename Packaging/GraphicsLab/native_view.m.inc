/* GPL-2.0-or-later, PwnedG0blin. Native GPU layout, not a frame-copy bridge. */
static bool stratovo_native(void) { return getenv("STRATOVO_NATIVE_PLAYER") != NULL; }
static CALayer *stratovo_boot_layer;
static CATextLayer *stratovo_boot_hint;
static NSRect stratovo_logo_rect;

/* Read only a small fingerprint generated from the selected firmware. */
static NSRect stratovo_boot_match(DisplaySurface *source)
{
    static NSDictionary *artwork;
    static bool loaded;
    if (!loaded) {
        loaded = true;
        const char *path = getenv("STRATOVO_BOOT_ARTWORK");
        if (path) {
            NSString *file = [NSString stringWithUTF8String:path];
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:file error:NULL];
            if ([attributes fileSize] <= 65536) {
                NSData *bytes = [NSData dataWithContentsOfFile:file];
                id object = bytes ? [NSJSONSerialization JSONObjectWithData:bytes options:0 error:NULL] : nil;
                if ([object isKindOfClass:[NSDictionary class]]) { artwork = [object retain]; }
            }
        }
    }
    if (!artwork || surface_bytes_per_pixel(source) != 4 ||
        (surface_format(source) != PIXMAN_x8r8g8b8 && surface_format(source) != PIXMAN_a8r8g8b8)) {
        return NSZeroRect;
    }
    int w = [artwork[@"width"] intValue], h = [artwork[@"height"] intValue];
    int fw = surface_width(source), fh = surface_height(source);
    NSArray *points = artwork[@"samples"];
    if (w < 64 || h < 40 || w > 1024 || h > 1024 || w > fw || h > fh ||
        ![points isKindOfClass:[NSArray class]] || points.count < 32 || points.count > 256) { return NSZeroRect; }
    int left = (fw-w)/2, candidates[] = {(fh-h)/2, (int)(fh*0.382)-h/2};
    const uint8_t *pixels = surface_data(source);
    for (unsigned i=0; i<2; i++) {
        int top = candidates[i]; bool matches = top >= 0 && top+h <= fh;
        if (!matches) { continue; }
        for (id point in points) {
            if (![point isKindOfClass:[NSDictionary class]]) { matches=false;break; }
            int x=[point[@"x"] intValue], y=[point[@"y"] intValue];
            int r=[point[@"red"] intValue], g=[point[@"green"] intValue], b=[point[@"blue"] intValue];
            if (x<0 || y<0 || x>=w || y>=h || r<0 || r>255 || g<0 || g>255 || b<0 || b>255) { matches=false;break; }
            const uint8_t *p = pixels + (top+y)*surface_stride(source) + (left+x)*4;
            if (abs(p[0]-b)>6 || abs(p[1]-g)>6 || abs(p[2]-r)>6) { matches=false;break; }
        }
        if (matches) { return NSMakeRect(left, fh-top-h, w, h); }
    }
    return NSZeroRect;
}
