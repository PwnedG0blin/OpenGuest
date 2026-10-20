"""Apply the embedded-player adapter to the pinned UTM QEMU Cocoa source."""
from pathlib import Path


def patch(qemu):
    path = Path(qemu)/'ui/cocoa.m'
    source = path.read_text()
    if 'STRATOVO_EMBEDDED_V1' in source:
        return
    fragment = Path(__file__).with_name('embedded_bridge.m.inc').read_text()
    anchor = 'static void cocoa_gl_read_dispatch(void)\n{'
    replacements = [
        (anchor, fragment+'\n'+anchor),
        ('        [cocoaView drawFrame:read];',
         '        if (getenv("STRATOVO_EMBEDDED_V1")) { stratovo_read_frame(read); }\n'
         '        else { [cocoaView drawFrame:read]; }'),
        ('    return dcl->ops == &dcl_gl_ops;',
         '    return dcl->ops == &dcl_gl_ops ||\n'
         '        (getenv("STRATOVO_EMBEDDED_V1") && !dcl->ops->dpy_gl_update);'),
        ('        [window makeKeyAndOrderFront:self];',
         '        if (!getenv("STRATOVO_EMBEDDED_V1")) { [window makeKeyAndOrderFront:self]; }'),
        ('    TransformProcessType(&psn, kProcessTransformToForegroundApplication);',
         '    if (!getenv("STRATOVO_EMBEDDED_V1")) { TransformProcessType(&psn, kProcessTransformToForegroundApplication); }'),
        ('        surface_gl_update_texture(dgc.gls, surface, x, y, w, h);',
         '        if (getenv("STRATOVO_EMBEDDED_V1") && gl_scanout_src) { return; }\n'
         '        surface_gl_update_texture(dgc.gls, surface, x, y, w, h);'),
    ]
    for before, after in replacements:
        if source.count(before) != 1:
            raise RuntimeError('QEMU-Anzeigequelle passt nicht zum eingebetteten Player: '+before[:80])
        source = source.replace(before, after)
    path.write_text(source)
