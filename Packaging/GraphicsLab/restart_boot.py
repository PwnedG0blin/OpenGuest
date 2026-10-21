"""Rearm the native startup cover for each real firmware boot, not window layout."""

def once(source, before, after):
    if source.count(before) != 1:
        raise RuntimeError('Unbekannte Neustart-Anzeigequelle: '+before[:80])
    return source.replace(before, after)


def presentation(source):
    source = once(source, 'static CFTimeInterval stratovo_boot_started;',
        'static CFTimeInterval stratovo_boot_started;\n'
        'static uint64_t stratovo_boot_generation;\n'
        'static bool stratovo_boot_logo_seen;')
    source = once(source, '- (void)stratovoBootFinished;',
        '- (void)stratovoBootFinished;\n'
        '- (void)stratovoBootDetected:(NSRect)rect;\n'
        '- (void)stratovoBootGPUFinished;')
    source = once(source, '            /* A failed guest must never be hidden behind an endless logo. */',
        '            uint64_t generation = ++stratovo_boot_generation;\n'
        '            /* A failed guest must never be hidden behind an endless logo. */')
    source = once(source, '                [self stratovoBootFinished];\n            });',
        '                if (generation == stratovo_boot_generation) { [self stratovoBootFinished]; }\n'
        '            });')
    source = once(source, '    stratovo_boot_complete = true;\n    [self stratovoBootLogo:NSZeroRect];',
        '    stratovo_boot_complete = true;\n'
        '    ++stratovo_boot_generation;\n'
        '    [self stratovoBootLogo:NSZeroRect];')
    source += '''
/* Called only from a newly inspected CPU firmware surface. A layout pass or
 * the old saved logo rectangle must never cover an already running desktop. */
- (void)stratovoBootDetected:(NSRect)rect
{
    if (!stratovo_native()) { return; }
    bool matched = rect.size.width > 0 && rect.size.height > 0;
    bool edge = matched && !stratovo_boot_logo_seen;
    stratovo_boot_logo_seen = matched;
    if (edge && self.scanout != QemuCocoaViewScanoutMetal) {
        stratovo_boot_complete = false;
        stratovo_boot_started = 0;
        ++stratovo_boot_generation;
    }
    [self stratovoBootLogo:rect];
}
- (void)stratovoBootGPUFinished
{
    /* A genuine GPU frame completes this boot and arms the next firmware edge.
     * Escape/timeout intentionally leave the current logo edge dismissed. */
    stratovo_boot_logo_seen = false;
    [self stratovoBootFinished];
}
'''
    return source


def patch(source):
    # Methods must remain inside @implementation, so transform that fragment
    # in place rather than appending methods after the complete QEMU source.
    start = source.index('/* Main-thread AppKit methods; resizing changes layer geometry only. */')
    end = source.index('- (void)updateCursorLayout\n{', start)
    fragment = source[start:end]
    # presentation transforms global fields/declarations as well as methods.
    fields = 'static CFTimeInterval stratovo_boot_started;'
    declaration = '- (void)stratovoBootFinished;'
    combined = fields+'\n'+declaration+'\n'+fragment
    updated = presentation(combined)
    prefix, methods = updated.split('/* Main-thread AppKit methods; resizing changes layer geometry only. */', 1)
    new_fields, new_declaration = prefix.split('- (void)stratovoBootFinished;', 1)
    source = once(source, fields, new_fields.strip())
    source = once(source, declaration, declaration+new_declaration.rstrip())
    source = once(source, fragment, '/* Main-thread AppKit methods; resizing changes layer geometry only. */'+methods)
    source = once(source, '[cocoaView stratovoBootLogo:logo];', '[cocoaView stratovoBootDetected:logo];')
    for receiver in ('self', 'cocoaView'):
        source = once(source,
            'dispatch_async(dispatch_get_main_queue(), ^{ ['+receiver+' stratovoBootFinished]; });',
            'dispatch_async(dispatch_get_main_queue(), ^{ ['+receiver+' stratovoBootGPUFinished]; });')
    return source
