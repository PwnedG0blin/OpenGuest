- (void)windowDidResize:(NSNotification *)notification
{
    if (stratovo_native()) { stratovo_save_window([cocoaView window]); }
    [cocoaView updateScale];
    if (![cocoaView isSelfResizing] && !(stratovo_native() && cocoaView.inLiveResize)) {
        [cocoaView updateUIInfo];
    }
}
- (void)windowDidEndLiveResize:(NSNotification *)notification
{
    if (stratovo_native()) {
        [cocoaView updateUIInfo];
        stratovo_save_window([cocoaView window]);
    }
}
- (void)windowDidMove:(NSNotification *)notification
{
    if (stratovo_native()) { stratovo_save_window([cocoaView window]); }
}
