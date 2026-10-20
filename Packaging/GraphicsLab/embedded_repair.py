"""Exact-source repair for the Beta 2 embedded player; no guest disk access."""
from pathlib import Path
import subprocess

PIN = 'ae92cdc41fb0b0dab36c6ac724e1729ffc47ef18'
HERE = Path(__file__).resolve().parent


def replace_once(source, before, after):
    if source.count(before) != 1:
        raise RuntimeError('Unbekannte Anzeigequelle: ' + before[:75])
    return source.replace(before, after)


def v1_source(base):
    fragment = (HERE/'legacy_embedded_bridge.m.inc').read_text()
    replacements = [
        ('static void cocoa_gl_read_dispatch(void)\n{', fragment+'\nstatic void cocoa_gl_read_dispatch(void)\n{'),
        ('        [cocoaView drawFrame:read];', '        if (getenv("STRATOVO_EMBEDDED_V1")) { stratovo_read_frame(read); }\n        else { [cocoaView drawFrame:read]; }'),
        ('    return dcl->ops == &dcl_gl_ops;', '    return dcl->ops == &dcl_gl_ops ||\n        (getenv("STRATOVO_EMBEDDED_V1") && !dcl->ops->dpy_gl_update);'),
        ('        [window makeKeyAndOrderFront:self];', '        if (!getenv("STRATOVO_EMBEDDED_V1")) { [window makeKeyAndOrderFront:self]; }'),
        ('    TransformProcessType(&psn, kProcessTransformToForegroundApplication);', '    if (!getenv("STRATOVO_EMBEDDED_V1")) { TransformProcessType(&psn, kProcessTransformToForegroundApplication); }'),
        ('        surface_gl_update_texture(dgc.gls, surface, x, y, w, h);', '        if (getenv("STRATOVO_EMBEDDED_V1") && gl_scanout_src) { return; }\n        surface_gl_update_texture(dgc.gls, surface, x, y, w, h);'),
    ]
    for before, after in replacements:
        base = replace_once(base, before, after)
    return base


def bridge_cocoa(base, legacy_v2=False):
    source = v1_source(base)
    shared = (HERE/'shared_frame.m.inc').read_text()
    source = replace_once(source, '#ifdef USE_METAL\n/*\n * The Metal scanout',
                          shared+'\n#ifdef USE_METAL\n/*\n * The Metal scanout')
    source = replace_once(source, (HERE/'legacy_embedded_bridge.m.inc').read_text(),
                          (HERE/'metal_frame.m.inc').read_text())
    anchor = 'static void cocoa_gl_update(DisplayChangeListener *dcl,\n                            int x, int y, int w, int h)\n{'
    gl_fragment = 'legacy_v2_gl_frame.m.inc' if legacy_v2 else 'gl_frame.m.inc'
    source = replace_once(source, anchor, (HERE/gl_fragment).read_text()+'\n'+anchor)
    source = replace_once(source, '    gl_scanout_y0_top = backing_y_0_top;',
        '    gl_scanout_y0_top = backing_y_0_top;\n'
        '    stratovo_gl_x = x; stratovo_gl_y = y;\n'
        '    stratovo_gl_w = w; stratovo_gl_h = h;')
    source = replace_once(source, '        if (cocoaView.scanout == QemuCocoaViewScanoutMetal) {',
        '        if (gl_scanout_src && (getenv("STRATOVO_EMBEDDED_V1") ||\n'
        '            cocoaView.scanout == QemuCocoaViewScanoutMetal)) {')
    source = replace_once(source, '        if (egl_surface) {\n            with_gl_view_ctx(^{',
        '        if (getenv("STRATOVO_EMBEDDED_V1") && gl_scanout_id) {\n'
        '            stratovo_read_gl_frame();\n'
        '            return;\n'
        '        } else\n'
        '        if (egl_surface) {\n            with_gl_view_ctx(^{')
    source = replace_once(source, '    {\n        dispatch_async(dispatch_get_main_queue(), ^{\n            CGFloat scale = cocoaView.window.backingScaleFactor;',
        '    {\n#ifdef USE_METAL\n'
        '        cocoa_gl_scanout_set(nil, MTLOriginMake(0, 0, 0), MTLSizeMake(0, 0, 0));\n'
        '#endif\n'
        '        dispatch_async(dispatch_get_main_queue(), ^{\n            CGFloat scale = cocoaView.window.backingScaleFactor;')
    before = '        return;\n    }\n#endif\n    qatomic_set(&gl_dirty, true);\n}\n\nstatic const DisplayChangeListenerOps dcl_gl_ops'
    source = replace_once(source, before,
        '        return;\n    }\n#endif\n    qatomic_set(&gl_dirty, true);\n'
        '    if (getenv("STRATOVO_EMBEDDED_V1") && gl_scanout_id &&\n'
        '        qatomic_xchg(&gl_dirty, false)) {\n'
        '        stratovo_read_gl_frame();\n'
        '    }\n}\n\nstatic const DisplayChangeListenerOps dcl_gl_ops')
    return source


def repaired_cocoa(base, legacy_v2=False, legacy_v3=False):
    source = bridge_cocoa(base, legacy_v2=legacy_v2)
    if legacy_v2 or legacy_v3: return source
    import importlib.util
    spec = importlib.util.spec_from_file_location('stratovo_native_display', HERE/'native_display.py')
    native = importlib.util.module_from_spec(spec);spec.loader.exec_module(native)
    return native.patch(source)


def repaired_vnc(base):
    anchor = 'void vnc_display_init(const char *id, Error **errp)\n{'
    return replace_once(base, anchor, (HERE/'vnc_frame.c.inc').read_text()+'\n'+anchor)


def plan(qemu):
    qemu = Path(qemu)
    if qemu.resolve() != qemu.absolute():
        raise RuntimeError("Die QEMU-Quelle darf keine Verknüpfung sein.")
    commit = subprocess.check_output(['/usr/bin/git','rev-parse','HEAD'],cwd=qemu,text=True,stderr=subprocess.PIPE).strip()
    if commit != PIN:
        raise RuntimeError('Die QEMU-Quelle hat eine andere Version; es wurde nichts geändert.')
    updates = []
    for relative, transform in [('ui/cocoa.m', repaired_cocoa), ('ui/vnc.c', repaired_vnc)]:
        path = qemu/relative
        if path.is_symlink() or not path.is_file():
            raise RuntimeError('Anzeigequelle fehlt oder ist verknüpft: '+str(path))
        base = subprocess.check_output(['/usr/bin/git','show','HEAD:'+relative],cwd=qemu,text=True,stderr=subprocess.PIPE)
        desired = transform(base)
        actual = path.read_text()
        allowed = [base, desired]
        if relative == 'ui/cocoa.m':
            allowed.extend([v1_source(base), repaired_cocoa(base, legacy_v2=True), repaired_cocoa(base, legacy_v3=True)])
        if actual not in allowed:
            raise RuntimeError('Andere Änderungen in '+relative+'; nichts wurde überschrieben.')
        if actual != desired:
            updates.append((path, desired))
    return updates
