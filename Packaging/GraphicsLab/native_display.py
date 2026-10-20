"""Add native window layout to the exact pinned Cocoa implementation."""
from pathlib import Path
HERE = Path(__file__).resolve().parent

def patch(source, legacy_v4=False, legacy_v5=False, legacy_v6=False):
    def replace(before, after):
        nonlocal source
        if source.count(before) != 1:
            raise RuntimeError('Unbekannte native Fensterquelle: '+before[:90])
        source = source.replace(before,after)
    view_fragment = 'legacy_v4_native_view.m.inc' if legacy_v4 else 'native_view.m.inc'
    methods_fragment = 'legacy_v4_native_methods.m.inc' if legacy_v4 else 'native_methods.m.inc'
    code = '#include <math.h>\n'+(HERE/'native_geometry.h.inc').read_text()+'\n'+(HERE/view_fragment).read_text()
    if not legacy_v4:
        code += '\n'+(HERE/'display_rate.h.inc').read_text()
    replace('typedef NS_ENUM(NSInteger, QemuCocoaViewScanout)', code+'\ntypedef NS_ENUM(NSInteger, QemuCocoaViewScanout)')
    replace('- (void) setScanout:(QemuCocoaViewScanout)scanout;', '- (void) setScanout:(QemuCocoaViewScanout)scanout;\n- (NSRect)stratovoViewport;\n- (void)stratovoLayout;\n- (void)stratovoBootLogo:(NSRect)rect;')
    replace('- (void)updateCursorLayout\n{', (HERE/methods_fragment).read_text()+'\n- (void)updateCursorLayout\n{')
    replace('    [[self window] setContentAspectRatio:NSMakeSize(screen.width, screen.height)];', '''    if (stratovo_native()) {
        [[self window] setStyleMask:[[self window] styleMask] | NSWindowStyleMaskResizable];
        [[self window] setContentMinSize:NSMakeSize(480, 320)];
        /* The user owns window dimensions; a guest mode change never resizes it. */
        isSelfResizing = NO;
        return;
    }
    [[self window] setContentAspectRatio:NSMakeSize(screen.width, screen.height)];''')
    replace('- (void) updateScale\n{', '''- (void) updateScale
{
    if (stratovo_native()) {
        [self stratovoLayout];
        [self updateCursorLayout];
        return;
    }''')
    replace('        position.y = (screen.height - mouseY) * scale;', '''        position.y = (screen.height - mouseY) * scale;
        if (stratovo_native()) {
            NSRect viewport = [self stratovoViewport];
            scale = viewport.size.width / screen.width;
            position.x = viewport.origin.x + mouseX * scale;
            position.y = viewport.origin.y + (screen.height - mouseY) * scale;
        }''')
    replace('''            /* Note that the origin for Cocoa mouse coords is bottom left, not top left. */
            qemu_input_queue_abs(dcl.con, INPUT_AXIS_X, p.x * d, 0, screen.width);
            qemu_input_queue_abs(dcl.con, INPUT_AXIS_Y, screen.height - p.y * d, 0, screen.height);''', '''            /* Cocoa coordinates are bottom-left; guest coordinates are top-left. */
            if (stratovo_native()) {
                NSRect r = [self stratovoViewport];
                p = [self convertPoint:p fromView:nil];
                int gx, gy;
                if (stratovo_point((StratovoRect){r.origin.x,r.origin.y,r.size.width,r.size.height},
                                   p.x,p.y,screen.width,screen.height,&gx,&gy)) {
                    qemu_input_queue_abs(dcl.con, INPUT_AXIS_X, gx, 0, screen.width);
                    qemu_input_queue_abs(dcl.con, INPUT_AXIS_Y, gy, 0, screen.height);
                }
            } else {
                qemu_input_queue_abs(dcl.con, INPUT_AXIS_X, p.x * d, 0, screen.width);
                qemu_input_queue_abs(dcl.con, INPUT_AXIS_Y, screen.height - p.y * d, 0, screen.height);
            }''')
    replace('''    NSSize size = [cocoaView convertSizeToBacking:[cocoaView frame].size];''', '''    NSSize size = [cocoaView convertSizeToBacking:stratovo_native() ? cocoaView.glLayer.bounds.size : [cocoaView frame].size];''')
    replace('''        CGRect frame = CGRectMake(0, 0, size.width / scale, size.height / scale);''', '''        CGRect frame = stratovo_native() ? [self stratovoViewport] : CGRectMake(0, 0, size.width / scale, size.height / scale);''')
    replace('''            cocoaView.glLayer.frame = CGRectMake(0, 0, w / scale, h / scale);''', '''            cocoaView.glLayer.frame = stratovo_native() ? [cocoaView stratovoViewport] : CGRectMake(0, 0, w / scale, h / scale);''')
    replace('''        _scanout = scanout;
        [self.cursorLayer removeFromSuperlayer];''', '''        _scanout = scanout;
        if (scanout != QemuCocoaViewScanoutNone) { [self stratovoBootLogo:NSZeroRect]; }
        [self.cursorLayer removeFromSuperlayer];''')
    replace('''        surface_gl_update_texture(dgc.gls, surface, x, y, w, h);''', '''        surface_gl_update_texture(dgc.gls, surface, x, y, w, h);
        if (stratovo_native()) {
            NSRect logo = stratovo_boot_match(surface);
            dispatch_async(dispatch_get_main_queue(), ^{ [cocoaView stratovoBootLogo:logo]; });
        }''')
    replace('''        NSRect frame = NSMakeRect(0.0, 0.0, 640.0, 480.0);''', '''        NSRect frame = NSMakeRect(0.0, 0.0, 640.0, 480.0);
        if (stratovo_native()) {
            NSSize available = [[NSScreen mainScreen] visibleFrame].size;
            frame.size = NSMakeSize(fmin(1100,available.width),fmin(760,available.height));
        }''')
    # The resizing choice must not turn off free window resizing in native mode.
    replace('''NSWindowStyleMask styleMask = [[cocoaView window] styleMask] ^ NSWindowStyleMaskResizable;''', '''NSWindowStyleMask styleMask = stratovo_native()
        ? [[cocoaView window] styleMask] | NSWindowStyleMaskResizable
        : [[cocoaView window] styleMask] ^ NSWindowStyleMaskResizable;''')
    replace('''    if (![cocoaView isSelfResizing]) {
        [cocoaView updateUIInfo];
    }
}''', '''    if (![cocoaView isSelfResizing] && !(stratovo_native() && cocoaView.inLiveResize)) {
        [cocoaView updateUIInfo];
    }
}
- (void)windowDidEndLiveResize:(NSNotification *)notification
{
    if (stratovo_native()) { [cocoaView updateUIInfo]; }
}''')
    # All window titles, including transitions on mouse capture, keep the app name.
    source = source.replace('''[window setTitle:qemu_name ? [NSString stringWithFormat:@"QEMU %s", qemu_name] : @"QEMU"];''', '''[window setTitle:stratovo_native() ? @"Windows Arm · Stratovo — Esc: UEFI / BIOS" : (qemu_name ? [NSString stringWithFormat:@"QEMU %s", qemu_name] : @"QEMU")];''')
    replace('''    if (qemu_name)
        [[self window] setTitle:[NSString stringWithFormat:@"QEMU %s - (Press  "''', '''    if (stratovo_native())
        [[self window] setTitle:@"Windows Arm · Stratovo — Ctrl + Option + G: Maus freigeben"];
    else if (qemu_name)
        [[self window] setTitle:[NSString stringWithFormat:@"QEMU %s - (Press  "''')
    replace('''    if (qemu_name)
        [[self window] setTitle:[NSString stringWithFormat:@"QEMU %s", qemu_name]];''', '''    if (stratovo_native())
        [[self window] setTitle:@"Windows Arm · Stratovo — Esc: UEFI / BIOS"];
    else if (qemu_name)
        [[self window] setTitle:[NSString stringWithFormat:@"QEMU %s", qemu_name]];''')
    for old,new in [('About QEMU','About Stratovo Windows Player'),('Hide QEMU','Hide Windows Arm'),('Quit QEMU','Quit Windows Arm')]:
        source=source.replace('initWithTitle:@"'+old+'"','initWithTitle:(stratovo_native() ? @"'+new+'" : @"'+old+'")')
        source=source.replace('addItemWithTitle:@"'+old+'"','addItemWithTitle:(stratovo_native() ? @"'+new+'" : @"'+old+'")')
    if not legacy_v4:
        source = source.replace('@"Windows Arm · Stratovo — Esc: UEFI / BIOS"', '@"Windows Arm · Stratovo"')
        replace('''- (void)applicationDidFinishLaunching: (NSNotification *) note
{''', '''- (void)applicationDidFinishLaunching: (NSNotification *) note
{
    if (stratovo_native()) {
        [[NSProcessInfo processInfo] setProcessName:@"Stratovo Windows"];
        const char *iconPath = getenv("STRATOVO_APP_ICON");
        if (iconPath) {
            NSImage *icon = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:iconPath]];
            if (icon) { [NSApp setApplicationIconImage:icon]; [icon release]; }
        }
    }''')
        replace('- (void)stratovoBootLogo:(NSRect)rect;', '- (void)stratovoBootLogo:(NSRect)rect;\n- (void)stratovoBootFinished;')
        replace('''        if (scanout != QemuCocoaViewScanoutNone) { [self stratovoBootLogo:NSZeroRect]; }''', '''        /* Retain the startup cover until a real GPU frame has completed. */
        [self stratovoBootLogo:NSZeroRect];''')
        replace('''            cocoa_gl_read_done(read);
        }];''', '''            if (cb.status == MTLCommandBufferStatusCompleted && stratovo_native()) {
                dispatch_async(dispatch_get_main_queue(), ^{ [self stratovoBootFinished]; });
            }
            cocoa_gl_read_done(read);
        }];''')
        replace('''- (bool) handleEvent:(NSEvent *)event
{''', '''- (bool) handleEvent:(NSEvent *)event
{
    /* Esc exposes the real firmware UI immediately, before forwarding the key. */
    if (stratovo_native() && event.type == NSEventTypeKeyDown && event.keyCode == 53) {
        [self stratovoBootFinished];
    }''')
        replace('''                eglSwapBuffers(qemu_egl_display, egl_surface);''', '''                eglSwapBuffers(qemu_egl_display, egl_surface);
                if (gl_scanout_id && stratovo_native()) {
                    dispatch_async(dispatch_get_main_queue(), ^{ [cocoaView stratovoBootFinished]; });
                }''')
        replace('''        info.width_mm = frameSize.width / screenSize.width * screenPhysicalSize.width;''', '''        /* The signed guest driver uses this EDID rate for every resolution.
         * Keep monitor timing independent of the game's own FPS limiter. */
        int stratovoHz = stratovo_refresh_hz(getenv("STRATOVO_DISPLAY_HZ"));
        if (stratovoHz) {
            update_displaychangelistener(&dcl, 1000 / stratovoHz);
            info.refresh_rate = (int64_t)stratovoHz * 1000;
        }
        info.width_mm = frameSize.width / screenSize.width * screenPhysicalSize.width;''')
    if not legacy_v4 and not legacy_v5:
        replace('typedef NS_ENUM(NSInteger, QemuCocoaViewScanout)',
                (HERE/'window_state.m.inc').read_text()+'\n'
                +'typedef NS_ENUM(NSInteger, QemuCocoaViewScanout)')
        replace('        [window center];\n        [window setDelegate: self];',
                '        [window center];\n'
                '        if (stratovo_native()) { stratovo_restore_window(window); }\n'
                '        [window setDelegate: self];')
        replace('- (void)windowDidResize:(NSNotification *)notification\n{',
                '- (void)windowDidResize:(NSNotification *)notification\n{\n'
                '    if (stratovo_native()) { stratovo_save_window(window); }')
        replace('    if (stratovo_native()) { [cocoaView updateUIInfo]; }\n}',
                '    if (stratovo_native()) {\n'
                '        [cocoaView updateUIInfo];\n'
                '        stratovo_save_window(window);\n'
                '    }\n}\n'
                '- (void)windowDidMove:(NSNotification *)notification\n{\n'
                '    if (stratovo_native()) { stratovo_save_window(window); }\n}')
    if not legacy_v4 and not legacy_v5 and not legacy_v6:
        old_callbacks = """- (void)windowDidResize:(NSNotification *)notification
{
    if (stratovo_native()) { stratovo_save_window(window); }
    [cocoaView updateScale];
    if (![cocoaView isSelfResizing] && !(stratovo_native() && cocoaView.inLiveResize)) {
        [cocoaView updateUIInfo];
    }
}
- (void)windowDidEndLiveResize:(NSNotification *)notification
{
    if (stratovo_native()) {
        [cocoaView updateUIInfo];
        stratovo_save_window(window);
    }
}
- (void)windowDidMove:(NSNotification *)notification
{
    if (stratovo_native()) { stratovo_save_window(window); }
}"""
        replace(old_callbacks, (HERE/'window_callbacks.m.inc').read_text().rstrip())
    return source
