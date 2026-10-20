/* Stratovo OpenGL readback, GPL-2.0-or-later, PwnedG0blin. */
static uint32_t stratovo_gl_x, stratovo_gl_y, stratovo_gl_w, stratovo_gl_h;
static uint8_t *stratovo_gl_pixels;
static size_t stratovo_gl_capacity;
static int64_t stratovo_gl_last_read;

static void stratovo_read_gl_frame(void)
{
    if (!gl_scanout_id || !stratovo_gl_w || !stratovo_gl_h ||
        stratovo_gl_w > 8192 || stratovo_gl_h > 8192) {
        return;
    }
    int64_t now = g_get_monotonic_time();
    if (now - stratovo_gl_last_read < 16667) {
        qatomic_set(&gl_dirty, true);
        return;
    }
    stratovo_gl_last_read = now;
    size_t needed = (size_t)stratovo_gl_w * stratovo_gl_h * 4;
    if (needed > stratovo_gl_capacity) {
        g_free(stratovo_gl_pixels);
        stratovo_gl_pixels = g_malloc(needed);
        stratovo_gl_capacity = needed;
    }
    __block bool complete = false;
    with_gl_view_ctx(^{
        GLint previous_read, previous_draw, previous_pack, previous_alignment;
        GLint previous_row_length, previous_skip_rows, previous_skip_pixels;
        GLuint framebuffer;
        glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &previous_read);
        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &previous_draw);
        glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &previous_pack);
        glGetIntegerv(GL_PACK_ALIGNMENT, &previous_alignment);
        glGetIntegerv(GL_PACK_ROW_LENGTH, &previous_row_length);
        glGetIntegerv(GL_PACK_SKIP_ROWS, &previous_skip_rows);
        glGetIntegerv(GL_PACK_SKIP_PIXELS, &previous_skip_pixels);
        glGenFramebuffers(1, &framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D, gl_scanout_id, 0);
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) {
            glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
            glPixelStorei(GL_PACK_ALIGNMENT, 4);
            glPixelStorei(GL_PACK_ROW_LENGTH, 0);
            glPixelStorei(GL_PACK_SKIP_ROWS, 0);
            glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
            /* Discard preceding GL errors; only classify this readback. */
            for (int i = 0; i < 16 && glGetError() != GL_NO_ERROR; i++) {}
            glReadPixels(stratovo_gl_x, stratovo_gl_y, stratovo_gl_w,
                         stratovo_gl_h, GL_RGBA, GL_UNSIGNED_BYTE, stratovo_gl_pixels);
            complete = glGetError() == GL_NO_ERROR;
        }
        glBindBuffer(GL_PIXEL_PACK_BUFFER, previous_pack);
        glPixelStorei(GL_PACK_ALIGNMENT, previous_alignment);
        glPixelStorei(GL_PACK_ROW_LENGTH, previous_row_length);
        glPixelStorei(GL_PACK_SKIP_ROWS, previous_skip_rows);
        glPixelStorei(GL_PACK_SKIP_PIXELS, previous_skip_pixels);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, previous_read);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, previous_draw);
        glDeleteFramebuffers(1, &framebuffer);
    });
    static bool announced;
    if (complete) {
        stratovo_publish_pixels(stratovo_gl_pixels, (size_t)stratovo_gl_w * 4,
            stratovo_gl_w, stratovo_gl_h, true, !gl_scanout_y0_top);
        if (!announced) {
            error_report("Stratovo embedded V2: OpenGL frame %ux%u", stratovo_gl_w, stratovo_gl_h);
        }
    } else if (!announced) {
        error_report("Stratovo embedded V2: OpenGL framebuffer readback failed");
    }
    if (!complete) {
        qatomic_set(&gl_dirty, true);
    }
    announced = true;
}
