/* GPL-2.0-or-later, PwnedG0blin. Pixel-free native presentation geometry. */
typedef struct StratovoRect { double x, y, width, height; } StratovoRect;
static StratovoRect stratovo_fit(double vw, double vh, double gw, double gh)
{
    if (!isfinite(vw) || !isfinite(vh) || !isfinite(gw) || !isfinite(gh) ||
        vw <= 0 || vh <= 0 || gw <= 0 || gh <= 0) {
        return (StratovoRect){0};
    }
    double scale = fmin(vw / gw, vh / gh);
    double w = gw * scale, h = gh * scale;
    return (StratovoRect){(vw-w)/2, (vh-h)/2, w, h};
}
static bool stratovo_point(StratovoRect rect, double x, double y,
                           int gw, int gh, int *gx, int *gy)
{
    if (rect.width <= 0 || rect.height <= 0 || gw <= 0 || gh <= 0 ||
        !isfinite(x) || !isfinite(y)) { return false; }
    *gx = (int)lround(fmax(0, fmin(gw-1, (x-rect.x) * gw / rect.width)));
    *gy = (int)lround(fmax(0, fmin(gh-1, gh - (y-rect.y) * gh / rect.height)));
    return true;
}
