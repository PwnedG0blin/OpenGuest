/* GPL-2.0-or-later, PwnedG0blin. Called on the QEMU main loop. */
void stratovo_vnc_publish_frame(QemuConsole *con, DisplaySurface *frame);
void stratovo_vnc_publish_frame(QemuConsole *con, DisplaySurface *frame)
{
    VncDisplay *vd;
    QTAILQ_FOREACH(vd, &vnc_displays, next) {
        if (vd->dcl.con != con) {
            continue;
        }
        /* A guest surface switch or VNC reconnect can change vd->ds. */
        if (vd->ds != frame) {
            vnc_dpy_switch(&vd->dcl, frame);
        }
        vnc_dpy_update(&vd->dcl, 0, 0,
                       surface_width(frame), surface_height(frame));
    }
}
