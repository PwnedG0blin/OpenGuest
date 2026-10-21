"""Small, exact-source backports for the pinned VM runtime. No guest disk access."""
from pathlib import Path
HERE = Path(__file__).resolve().parent

def replace(source, before, after):
    if source.count(before) != 1:
        raise RuntimeError('Unbekannte Laufzeitquelle: ' + before[:90])
    return source.replace(before, after)

def hvf(source):
    anchor = 'static void hvf_raise_exception(CPUState *cpu, uint32_t excp,'
    source = replace(source, anchor, (HERE/'isv_memory.h.inc').read_text() + '\n' +
                     (HERE/'hvf_isv.c.inc').read_text() + '\n' + anchor)
    return replace(source, '        assert(isv);', '''        if (!isv) {
            if (!s1ptw && stratovo_hvf_isv(cpu, iswrite)) {
                advance_pc = true;
            } else {
                /* The pinned HVF implementation virtualizes EL0/EL1 only.
                 * Deliver a real guest abort for unsupported accesses; never
                 * skip an instruction or report a successful shutdown. */
                env->exception.vaddress = hvf_exit->exception.virtual_address;
                hvf_raise_exception(cpu, EXCP_DATA_ABORT,
                    syn_data_abort_no_iss(arm_current_el(env) == 1, 1, 0, 0,
                                          s1ptw, iswrite, 0x10));
            }
            break;
        }''')

def cocoa(source):
    source = replace(source, 'static bool gl_read_inflight;',
        'static bool gl_read_inflight;\n' + (HERE/'scanout_snapshot.m.inc').read_text())
    source = replace(source, '''    read->texture = [gl_scanout_src retain];
    read->origin = gl_scanout_origin;
    read->size = gl_scanout_size;''', '''    read->texture = [(stratovo_native() ? stratovo_scanout_snapshot : gl_scanout_src) retain];
    read->origin = stratovo_native() ? MTLOriginMake(0,0,0) : gl_scanout_origin;
    read->size = stratovo_native() ? stratovo_snapshot_size : gl_scanout_size;
    if (!read->texture) { g_free(read); return; }''')
    source = replace(source, '''    if (gl_scanout_src && !gl_read_inflight) {
        qatomic_set(&gl_dirty, false);''', '''    if (stratovo_native() && gl_scanout_src) {
        if (!stratovo_capture_scanout(gl_scanout_src, gl_scanout_origin, gl_scanout_size)) {
            error_report("Stratovo: scanout snapshot failed; retaining previous complete frame");
            return;
        }
    }
    if (gl_scanout_src && !gl_read_inflight) {
        qatomic_set(&gl_dirty, false);''')
    source = replace(source, '''    [gl_scanout_src release];
    gl_scanout_src = [texture retain];''', '''    if (!texture) {
        [stratovo_scanout_snapshot release]; stratovo_scanout_snapshot = nil;
    }
    [gl_scanout_src release];
    gl_scanout_src = [texture retain];''')
    return source
