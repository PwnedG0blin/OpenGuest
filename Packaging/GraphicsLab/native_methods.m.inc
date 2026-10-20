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
    if (rect.size.width > 0 && rect.size.height > 0 && !stratovo_boot_complete) {
        stratovo_logo_rect = rect;
        if (!stratovo_boot_started) {
            stratovo_boot_started = CACurrentMediaTime();
            /* A failed guest must never be hidden behind an endless logo. */
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self stratovoBootFinished];
            });
        }
    }
    bool visible = !stratovo_boot_complete && stratovo_boot_started > 0;
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
        stratovo_boot_hint.string = @"";
        stratovo_boot_hint.fontSize = 14;
        stratovo_boot_hint.alignmentMode = kCAAlignmentCenter;
        stratovo_boot_hint.foregroundColor = CGColorGetConstantColor(kCGColorWhite);
        stratovo_boot_hint.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
        [self.layer addSublayer:stratovo_boot_hint];
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    stratovo_boot_layer.hidden = !visible; stratovo_boot_hint.hidden = YES;
    if (visible) {
        /* One full opaque cover avoids source-logo edges and firmware text.
         * It also bridges RAMFB -> 3D without showing QEMU's placeholder. */
        stratovo_boot_layer.frame = self.bounds;
        stratovo_boot_layer.zPosition = 1000;
        CGFloat side = fmin(self.bounds.size.width,self.bounds.size.height)*0.12;
        CGFloat x=(self.bounds.size.width-side)/2, y=(self.bounds.size.height-side)/2, gap=fmax(1,side/24);
        CGFloat pixel = fmax(1,self.window.backingScaleFactor);
        for (int i=0;i<4;i++) {
            stratovo_boot_layer.sublayers[i].frame = CGRectMake(round((x+(i%2)*(side/2+gap/2))*pixel)/pixel,
                round((y+(i/2)*(side/2+gap/2))*pixel)/pixel,
                round((side/2-gap/2)*pixel)/pixel, round((side/2-gap/2)*pixel)/pixel);
        }
        stratovo_boot_hint.frame = CGRectMake(0, 12, self.bounds.size.width, 22);
        stratovo_boot_hint.contentsScale = self.window.backingScaleFactor;
    }
    [CATransaction commit];
}
- (void)stratovoBootFinished
{
    if (!stratovo_native()) { return; }
    stratovo_boot_complete = true;
    [self stratovoBootLogo:NSZeroRect];
}
