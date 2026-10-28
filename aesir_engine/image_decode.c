/* libaesir_image: minimal image decode shim for Aesir's vision
 * preprocessing (loader/image_prep.mojo loads it lazily via dlopen).
 *
 * One entry point decodes PNG (libpng) or JPEG (libjpeg) from a file
 * path into a freshly malloc'd RGB888 buffer the caller frees with
 * aesir_image_free. Returns 0 on success, nonzero on any failure
 * (unknown format, truncated file, decoder error). No exceptions
 * cross the boundary; libpng/libjpeg errors are caught with
 * setjmp/longjmp guards as their APIs require.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#include <png.h>
#include <jpeglib.h>

static int decode_png(FILE *fp, int *w, int *h, unsigned char **rgb) {
    unsigned char header[8];
    if (fread(header, 1, 8, fp) != 8) return 1;
    if (png_sig_cmp(header, 0, 8)) return 1;
    png_structp png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png_ptr) return 1;
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (!info_ptr) { png_destroy_read_struct(&png_ptr, NULL, NULL); return 1; }
    if (setjmp(png_jmpbuf(png_ptr))) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 1;
    }
    png_init_io(png_ptr, fp);
    png_set_sig_bytes(png_ptr, 8);
    png_read_png(png_ptr, info_ptr, PNG_TRANSFORM_STRIP_16 |
                 PNG_TRANSFORM_STRIP_ALPHA | PNG_TRANSFORM_PACKING |
                 PNG_TRANSFORM_EXPAND, NULL);
    png_uint_32 width, height;
    int bit_depth, color_type;
    png_get_IHDR(png_ptr, info_ptr, &width, &height, &bit_depth, &color_type, NULL, NULL, NULL);
    if (color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_GRAY_ALPHA) {
        /* read_png with EXPAND already yields RGB for gray in most
         * builds; verify row layout by bytes-per-pixel below. */
    }
    png_bytepp rows = png_get_rows(png_ptr, info_ptr);
    if (!rows) { png_destroy_read_struct(&png_ptr, &info_ptr, NULL); return 1; }
    /* After EXPAND+STRIP_ALPHA+PACKING, pixels are 8-bit; channels are
     * 3 for colour/palette and 1 for gray. Normalise gray to RGB. */
    int channels = (color_type == PNG_COLOR_TYPE_GRAY ||
                    color_type == PNG_COLOR_TYPE_GRAY_ALPHA) ? 1 : 3;
    unsigned char *out = (unsigned char *)malloc((size_t)width * height * 3);
    if (!out) { png_destroy_read_struct(&png_ptr, &info_ptr, NULL); return 1; }
    for (png_uint_32 y = 0; y < height; y++) {
        for (png_uint_32 x = 0; x < width; x++) {
            unsigned char *dst = out + ((size_t)y * width + x) * 3;
            if (channels == 1) {
                dst[0] = dst[1] = dst[2] = rows[y][x];
            } else {
                memcpy(dst, rows[y] + (size_t)x * 3, 3);
            }
        }
    }
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    *w = (int)width; *h = (int)height; *rgb = out;
    return 0;
}

struct aesir_jpeg_error {
    struct jpeg_error_mgr pub;
    jmp_buf jb;
};
static void aesir_jpeg_fail(j_common_ptr cinfo) {
    struct aesir_jpeg_error *err = (struct aesir_jpeg_error *)cinfo->err;
    longjmp(err->jb, 1);
}

static int decode_jpeg(FILE *fp, int *w, int *h, unsigned char **rgb) {
    struct jpeg_decompress_struct cinfo;
    struct aesir_jpeg_error err;
    cinfo.err = jpeg_std_error(&err.pub);
    err.pub.error_exit = aesir_jpeg_fail;
    if (setjmp(err.jb)) {
        jpeg_destroy_decompress(&cinfo);
        return 1;
    }
    jpeg_create_decompress(&cinfo);
    jpeg_stdio_src(&cinfo, fp);
    jpeg_read_header(&cinfo, TRUE);
    cinfo.out_color_space = JCS_RGB;
    jpeg_start_decompress(&cinfo);
    int width = (int)cinfo.output_width;
    int height = (int)cinfo.output_height;
    if (cinfo.output_components != 3) {
        jpeg_finish_decompress(&cinfo);
        jpeg_destroy_decompress(&cinfo);
        return 1;
    }
    unsigned char *out = (unsigned char *)malloc((size_t)width * height * 3);
    if (!out) { jpeg_destroy_decompress(&cinfo); return 1; }
    while ((int)cinfo.output_scanline < height) {
        JSAMPROW row = out + (size_t)cinfo.output_scanline * width * 3;
        jpeg_read_scanlines(&cinfo, &row, 1);
    }
    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);
    *w = width; *h = height; *rgb = out;
    return 0;
}

/* Format is chosen by magic bytes, mirroring load_image_file's
 * dispatch in loader/image_prep.mojo: PNG signature vs JPEG SOI. */
int aesir_image_decode(const char *path, int *out_w, int *out_h, unsigned char **out_rgb) {
    if (!path || !out_w || !out_h || !out_rgb) return 1;
    *out_rgb = NULL;
    FILE *fp = fopen(path, "rb");
    if (!fp) return 1;
    unsigned char magic[2];
    if (fread(magic, 1, 2, fp) != 2) { fclose(fp); return 1; }
    rewind(fp);
    int rc;
    if (magic[0] == 0xFF && magic[1] == 0xD8) {
        rc = decode_jpeg(fp, out_w, out_h, out_rgb);
    } else {
        rc = decode_png(fp, out_w, out_h, out_rgb);
    }
    fclose(fp);
    return rc;
}

void aesir_image_free(unsigned char *rgb) {
    free(rgb);
}
