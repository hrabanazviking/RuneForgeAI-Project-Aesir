"""Image preprocessing for the vision path: decode, resize, normalize, patchify.

Turns an RGB image into the patch vectors the vision encoder consumes:
resized to the tower's ``image_size`` square, scaled per channel by the
mmproj's ``image_mean``/``image_std``, then cut into patches in exactly the
element order of ``v.patch_embd.weight`` (dims [patch, patch, 3, embedding],
innermost first): patch raster order, then row, then column, then channel.

Format scope for this slice: binary PPM (P6, maxval 255) is the admitted
input. PNG/JPEG decoding is NOT implemented here and is not claimed; it is
a separate slice (docs/VISION_MMPROJ_DEVELOPMENT.md, Slice 2 boundary).

Resize is bilinear with half-pixel centres
(``src = (dst + 0.5) * scale - 0.5``, clamped) — the documented convention
this implementation is proven against. Numerical parity with any external
reference preprocessor's resampling filter is NOT proven here; if encoder
outputs are ever compared against a reference implementation, resampling
is a named suspect variable.
"""
from loader.mmproj import VisionTowerSpec
from hailbru.syscall import os_host_architecture, read_file_bytes


struct RgbImage(Copyable):
    """Interleaved RGB8 pixels, row-major, 3 bytes per pixel."""

    var width: Int
    var height: Int
    var pixels: List[UInt8]

    def __init__(out self, width: Int, height: Int, pixels: List[UInt8]):
        self.width = width
        self.height = height
        self.pixels = pixels.copy()

    def __copyinit__(out self, existing: Self):
        self.width = existing.width
        self.height = existing.height
        self.pixels = existing.pixels.copy()

    def validate(self) raises:
        if self.width <= 0 or self.height <= 0:
            raise Error("image: dimensions must be positive")
        if len(self.pixels) != self.width * self.height * 3:
            raise Error("image: pixel buffer does not match dimensions")


def _ppm_token(data: List[UInt8], cursor: Int) raises -> Tuple[String, Int]:
    """Reads one whitespace-delimited header token, skipping comments."""
    var i = cursor
    while i < len(data):
        var b = data[i]
        if b == 35:  # '#': comment runs to end of line
            while i < len(data) and data[i] != 10:
                i += 1
        elif b == 32 or b == 9 or b == 10 or b == 13:
            i += 1
        else:
            break
    var start = i
    while i < len(data):
        var b = data[i]
        if b == 32 or b == 9 or b == 10 or b == 13:
            break
        i += 1
    if start == i:
        raise Error("image: truncated PPM header")
    var token = String("")
    for j in range(start, i):
        token += chr(Int(data[j]))
    return (token, i)


def _ppm_positive_int(token: String, field: String) raises -> Int:
    if token.byte_length() == 0:
        raise Error("image: empty PPM " + field)
    var value = 0
    for byte in token.as_bytes():
        if byte < 48 or byte > 57:
            raise Error("image: PPM " + field + " is not a positive integer")
        value = value * 10 + Int(byte - 48)
        if value > 1048576:
            raise Error("image: PPM " + field + " is unreasonably large")
    if value <= 0:
        raise Error("image: PPM " + field + " must be positive")
    return value


def parse_ppm(data: List[UInt8]) raises -> RgbImage:
    """Parses a binary PPM (P6, maxval 255) from memory, bounds-checked."""
    if len(data) < 2 or data[0] != 80 or data[1] != 54:  # 'P', '6'
        raise Error("image: not a binary PPM (P6) file")
    var magic = _ppm_token(data, 0)
    if magic[0] != "P6":
        raise Error("image: not a binary PPM (P6) file")
    var width_token = _ppm_token(data, magic[1])
    var height_token = _ppm_token(data, width_token[1])
    var maxval_token = _ppm_token(data, height_token[1])
    var width = _ppm_positive_int(width_token[0], "width")
    var height = _ppm_positive_int(height_token[0], "height")
    var maxval = _ppm_positive_int(maxval_token[0], "maxval")
    if maxval != 255:
        raise Error("image: only PPM maxval 255 is supported")
    # Exactly one whitespace byte separates the header from the raster.
    var raster_start = maxval_token[1] + 1
    var expected = width * height * 3
    if raster_start > len(data) or expected > len(data) - raster_start:
        raise Error("image: PPM raster is truncated")
    var pixels = List[UInt8]()
    pixels.reserve(expected)
    for i in range(expected):
        pixels.append(data[raster_start + i])
    var image = RgbImage(width, height, pixels)
    image.validate()
    return image^


def load_ppm_file(path: String) raises -> RgbImage:
    """Reads and parses a PPM file from disk (bounded to 256 MiB)."""
    var data = read_file_bytes(os_host_architecture(), path, 268435456)
    return parse_ppm(data)


def resize_normalize(
    image: RgbImage,
    target_size: Int,
    mean: List[Float32],
    std: List[Float32],
) raises -> List[Float32]:
    """Bilinear-resizes to target_size x target_size and normalizes.

    Returns interleaved RGB floats in row-major pixel order, each channel
    mapped by (pixel/255 - mean) / std. Half-pixel-centre sampling.
    """
    image.validate()
    if target_size <= 0:
        raise Error("image: target size must be positive")
    if len(mean) != 3 or len(std) != 3:
        raise Error("image: mean/std must have exactly 3 channels")
    for c in range(3):
        if std[c] == 0.0:
            raise Error("image: std channel must be nonzero")
    var out = List[Float32]()
    out.reserve(target_size * target_size * 3)
    var scale_x = Float32(image.width) / Float32(target_size)
    var scale_y = Float32(image.height) / Float32(target_size)
    for dy in range(target_size):
        var src_y = (Float32(dy) + 0.5) * scale_y - 0.5
        if src_y < 0.0:
            src_y = 0.0
        if src_y > Float32(image.height - 1):
            src_y = Float32(image.height - 1)
        var y0 = Int(src_y)
        var y1 = y0 + 1
        if y1 > image.height - 1:
            y1 = image.height - 1
        var fy = src_y - Float32(y0)
        for dx in range(target_size):
            var src_x = (Float32(dx) + 0.5) * scale_x - 0.5
            if src_x < 0.0:
                src_x = 0.0
            if src_x > Float32(image.width - 1):
                src_x = Float32(image.width - 1)
            var x0 = Int(src_x)
            var x1 = x0 + 1
            if x1 > image.width - 1:
                x1 = image.width - 1
            var fx = src_x - Float32(x0)
            for c in range(3):
                var p00 = Float32(image.pixels[(y0 * image.width + x0) * 3 + c])
                var p01 = Float32(image.pixels[(y0 * image.width + x1) * 3 + c])
                var p10 = Float32(image.pixels[(y1 * image.width + x0) * 3 + c])
                var p11 = Float32(image.pixels[(y1 * image.width + x1) * 3 + c])
                var top = p00 + (p01 - p00) * fx
                var bottom = p10 + (p11 - p10) * fx
                var value = top + (bottom - top) * fy
                out.append((value / 255.0 - mean[c]) / std[c])
    return out^


def patchify(normalized: List[Float32], image_size: Int, patch_size: Int) raises -> List[Float32]:
    """Cuts a normalized square image into patch vectors.

    Output layout per patch (raster order over the patch grid):
    [row in patch][column in patch][channel], matching the flattened
    patch-embedding weight layout exactly.
    """
    if image_size <= 0 or patch_size <= 0 or image_size % patch_size != 0:
        raise Error("image: patch geometry is invalid")
    if len(normalized) != image_size * image_size * 3:
        raise Error("image: normalized buffer does not match image geometry")
    var grid = image_size // patch_size
    var patch_values = patch_size * patch_size * 3
    var out = List[Float32]()
    out.reserve(grid * grid * patch_values)
    for py in range(grid):
        for px in range(grid):
            for row in range(patch_size):
                for col in range(patch_size):
                    var y = py * patch_size + row
                    var x = px * patch_size + col
                    var base = (y * image_size + x) * 3
                    for c in range(3):
                        out.append(normalized[base + c])
    return out^


def preprocess_image(image: RgbImage, spec: VisionTowerSpec) raises -> List[Float32]:
    """Full Slice 2 path: image -> normalized patch vectors for the tower."""
    if not spec.present:
        raise Error("image: vision tower spec is not present")
    var normalized = resize_normalize(
        image, spec.image_size, spec.image_mean, spec.image_std
    )
    return patchify(normalized, spec.image_size, spec.patch_size)
