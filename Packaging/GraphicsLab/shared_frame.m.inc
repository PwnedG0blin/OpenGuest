/* Stratovo CPU presentation surface, GPL-2.0-or-later, PwnedG0blin. */
/* This surface belongs to VNC only. Never replace or resize the GPU scanout. */
extern void stratovo_vnc_publish_frame(QemuConsole *, DisplaySurface *);
static DisplaySurface *stratovo_cpu_surface;

static bool stratovo_publish_pixels(const uint8_t *source, size_t stride,
                                   int width, int height, bool rgba, bool flip)
{
    if (!source || width <= 0 || height <= 0 || width > 8192 || height > 8192 ||
        stride < (size_t)width * 4) {
        return false;
    }
    QemuConsole *con = dcl.con;
    if (!con) {
        return false;
    }
    DisplaySurface *old = stratovo_cpu_surface;
    DisplaySurface *out = old;
    if (!out || surface_width(out) != width || surface_height(out) != height) {
        out = qemu_create_displaysurface(width, height);
    }
    uint8_t *target = surface_data(out);
    for (int y = 0; y < height; y++) {
        const uint8_t *input = source + (flip ? height - 1 - y : y) * stride;
        uint8_t *row = target + y * surface_stride(out);
        memcpy(row, input, (size_t)width * 4);
        if (rgba) {
            for (int x = 0; x < width; x++) {
                uint8_t red = row[x * 4];
                row[x * 4] = row[x * 4 + 2];
                row[x * 4 + 2] = red;
            }
        }
    }
    stratovo_cpu_surface = out;
    stratovo_vnc_publish_frame(con, out);
    if (old && old != out) {
        qemu_free_displaysurface(old);
    }
    return true;
}
