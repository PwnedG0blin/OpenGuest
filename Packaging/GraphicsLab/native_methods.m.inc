/* Main-thread AppKit methods; resizing changes layer geometry only. */
- (NSRect)stratovoViewport
{
    StratovoRect r = stratovo_fit(self.bounds.size.width, self.bounds.size.height, screen.width, screen.height);
    return NSMakeRect(r.x, r.y, r.width, r.height);
}
- (void)stratovoLayout
{
    if (!stratovo_native()) { return; }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    NSRect viewport = [self stratovoViewport];
    CGFloat scale = self.window.backingScaleFactor;
    self.layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
#ifdef CONFIG_OPENGL
    self.glLayer.frame = viewport;
    self.glLayer.contentsScale = scale;
#ifdef USE_METAL
    self.metalLayer.frame = viewport;
    self.metalLayer.contentsScale = scale;
    /* drawableSize stays at guest resolution: Metal copies never overrun it.
       Core Animation scales the layer on the GPU to the chosen window size. */
#endif
#endif
    [self stratovoBootLogo:stratovo_logo_rect];
    [CATransaction commit];
}
- (void)stratovoBootLogo:(NSRect)rect
{
    if (!stratovo_native()) { return; }
    stratovo_logo_rect = rect;
    bool visible = self.scanout == QemuCocoaViewScanoutNone && rect.size.width > 0 && rect.size.height > 0;
    if (!stratovo_boot_layer && visible) {
        stratovo_boot_layer = [[CALayer alloc] init];
        stratovo_boot_layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
        for (int i=0;i<4;i++) {
            CALayer *tile = [CALayer layer];
            tile.backgroundColor = [[NSColor colorWithSRGBRed:0.12 green:0.67 blue:0.94 alpha:1] CGColor];
            [stratovo_boot_layer addSublayer:tile];
        }
        [self.layer addSublayer:stratovo_boot_layer];
        stratovo_boot_hint = [[CATextLayer alloc] init];
        stratovo_boot_hint.string = @"Esc beim Einschalten: UEFI / BIOS";
        stratovo_boot_hint.fontSize = 14;
        stratovo_boot_hint.alignmentMode = kCAAlignmentCenter;
        stratovo_boot_hint.foregroundColor = CGColorGetConstantColor(kCGColorWhite);
        stratovo_boot_hint.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
        [self.layer addSublayer:stratovo_boot_hint];
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    stratovo_boot_layer.hidden = !visible; stratovo_boot_hint.hidden = !visible;
    if (visible) {
        NSRect image = [self stratovoViewport];
        double scale = image.size.width / screen.width;
        stratovo_boot_layer.frame = CGRectMake(image.origin.x + rect.origin.x*scale,
            image.origin.y + rect.origin.y*scale, rect.size.width*scale, rect.size.height*scale);
        CGFloat side = fmin(rect.size.width,rect.size.height)*scale*0.5;
        CGFloat x=(rect.size.width*scale-side)/2, y=(rect.size.height*scale-side)/2, gap=fmax(1,side/24);
        for (int i=0;i<4;i++) {
            stratovo_boot_layer.sublayers[i].frame = CGRectMake(x+(i%2)*(side/2+gap/2),
                y+(i/2)*(side/2+gap/2), side/2-gap/2, side/2-gap/2);
        }
        stratovo_boot_hint.frame = CGRectMake(0, 12, self.bounds.size.width, 22);
        stratovo_boot_hint.contentsScale = self.window.backingScaleFactor;
    }
    [CATransaction commit];
}
