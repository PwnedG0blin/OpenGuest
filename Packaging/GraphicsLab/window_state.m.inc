/* Use a stable preferences suite: the QEMU executable and bundle may change. */
static NSUserDefaults *stratovo_window_defaults(void)
{
    return [[[NSUserDefaults alloc] initWithSuiteName:@"org.stratovo.WindowsPlayer"] autorelease];
}

static void stratovo_save_window(NSWindow *window)
{
    if (!window || [window inLiveResize] || [window isMiniaturized] ||
        ([window styleMask] & NSWindowStyleMaskFullScreen)) { return; }
    NSRect frame = [window frame];
    if (frame.size.width < 480 || frame.size.height < 320) { return; }
    NSUserDefaults *defaults = stratovo_window_defaults();
    [defaults setObject:NSStringFromRect(frame) forKey:@"NormalWindowFrame.v1"];
    /* The VM process can exit independently of NSApplication termination. */
    [defaults synchronize];
}

static void stratovo_restore_window(NSWindow *window)
{
    id value = [stratovo_window_defaults() objectForKey:@"NormalWindowFrame.v1"];
    if (![value isKindOfClass:[NSString class]]) { return; }
    NSRect frame = NSRectFromString(value);
    if (!isfinite(frame.origin.x) || !isfinite(frame.origin.y) ||
        !isfinite(frame.size.width) || !isfinite(frame.size.height) ||
        frame.size.width < 480 || frame.size.height < 320) { return; }
    /* Select the screen with most overlap; recover disconnected monitors. */
    NSScreen *target = [NSScreen mainScreen];
    CGFloat bestArea = 0;
    for (NSScreen *screen in [NSScreen screens]) {
        NSRect overlap = NSIntersectionRect(frame, [screen visibleFrame]);
        CGFloat area = overlap.size.width * overlap.size.height;
        if (area > bestArea) { bestArea = area; target = screen; }
    }
    if (!target) { return; }
    NSRect available = [target visibleFrame];
    frame.size.width = fmin(frame.size.width, available.size.width);
    frame.size.height = fmin(frame.size.height, available.size.height);
    frame.origin.x = fmax(NSMinX(available), fmin(frame.origin.x, NSMaxX(available) - frame.size.width));
    frame.origin.y = fmax(NSMinY(available), fmin(frame.origin.y, NSMaxY(available) - frame.size.height));
    [window setFrame:frame display:NO];
}
