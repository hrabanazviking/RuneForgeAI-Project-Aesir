"""Unit tests for loader/image_prep.mojo (vision Slice 2).

Oracle values for the bilinear case were computed by an independent
Python implementation of the documented half-pixel-centre formula.
"""
from loader.image_prep import (
    RgbImage,
    parse_ppm,
    patchify,
    resize_normalize,
)


def _expect(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def _close(actual: Float32, expected: Float32, message: String) raises:
    var diff = actual - expected
    if diff < 0.0:
        diff = -diff
    if diff > 0.00001:
        raise Error(
            message + ": got " + String(actual) + ", expected " + String(expected)
        )


def _ppm_bytes(width: Int, height: Int, pixels: List[UInt8]) -> List[UInt8]:
    var header = "P6\n" + String(width) + " " + String(height) + "\n255\n"
    var data = List[UInt8]()
    for byte in header.as_bytes():
        data.append(byte)
    for i in range(len(pixels)):
        data.append(pixels[i])
    return data^


def _zero_mean_unit_std() -> Tuple[List[Float32], List[Float32]]:
    var mean = List[Float32]()
    var std = List[Float32]()
    for _ in range(3):
        mean.append(0.0)
        std.append(1.0)
    return (mean^, std^)


def test_parse_ppm() raises:
    var pixels = List[UInt8]()
    for i in range(12):
        pixels.append(UInt8(i * 20))
    var image = parse_ppm(_ppm_bytes(2, 2, pixels))
    _expect(image.width == 2 and image.height == 2, "PPM dimensions parsed")
    _expect(image.pixels[5] == 100, "PPM raster bytes preserved in order")
    var raised = False
    try:
        var bad = List[UInt8]()
        bad.append(80)  # 'P'
        bad.append(51)  # '3' — ASCII PPM is not admitted
        _ = parse_ppm(bad)
    except:
        raised = True
    _expect(raised, "non-P6 input is rejected")
    print("image_prep parse_ppm: PASS")


def test_resize_identity() raises:
    var pixels = List[UInt8]()
    # 2x2: red, green, blue, white
    var raw: List[Int] = [255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255]
    for i in range(len(raw)):
        pixels.append(UInt8(raw[i]))
    var image = RgbImage(2, 2, pixels)
    var norm = _zero_mean_unit_std()
    var out = resize_normalize(image, 2, norm[0], norm[1])
    _expect(len(out) == 12, "identity resize keeps 2x2x3 values")
    _close(out[0], 1.0, "red channel of pixel (0,0)")
    _close(out[4], 1.0, "green channel of pixel (1,0)")
    _close(out[8], 1.0, "blue channel of pixel (0,1)")
    _close(out[11], 1.0, "white pixel (1,1)")
    print("image_prep resize identity: PASS")


def test_resize_bilinear_oracle() raises:
    # 2x2 grayscale ramp [[0,100],[200,255]] upscaled to 4x4.
    # Expected R values from the independent Python oracle:
    # row0: 0.0, 0.098039, 0.294118, 0.392157
    # row1: 0.196078, 0.283088, 0.457108, 0.544118
    # row3: 0.784314, 0.838235, 0.946078, 1.0
    var pixels = List[UInt8]()
    var gray: List[Int] = [0, 100, 200, 255]
    for i in range(4):
        for _ in range(3):
            pixels.append(UInt8(gray[i]))
    var image = RgbImage(2, 2, pixels)
    var norm = _zero_mean_unit_std()
    var out = resize_normalize(image, 4, norm[0], norm[1])
    _expect(len(out) == 48, "upscale produces 4x4x3 values")
    _close(out[0 * 12 + 0 * 3], 0.0, "bilinear (0,0)")
    _close(out[0 * 12 + 1 * 3], 0.098039, "bilinear (1,0)")
    _close(out[0 * 12 + 3 * 3], 0.392157, "bilinear (3,0)")
    _close(out[1 * 12 + 2 * 3], 0.457108, "bilinear (2,1)")
    _close(out[3 * 12 + 0 * 3], 0.784314, "bilinear (0,3)")
    _close(out[3 * 12 + 3 * 3], 1.0, "bilinear (3,3)")
    print("image_prep resize bilinear oracle: PASS")


def test_patchify_order() raises:
    # image_size 4, patch 2; normalized value = y*4+x in every channel.
    # Patch order: (0,0),(1,0),(0,1),(1,1) in grid raster order; inside a
    # patch: rows then columns. Patch (1,0) covers x=2..3, y=0..1, so its
    # first values are pixels (2,0)=2 and (3,0)=3, then (2,1)=6, (3,1)=7.
    var normalized = List[Float32]()
    for y in range(4):
        for x in range(4):
            for _ in range(3):
                normalized.append(Float32(y * 4 + x))
    var patches = patchify(normalized, 4, 2)
    _expect(len(patches) == 48, "patchify keeps all values")
    _close(patches[0], 0.0, "patch (0,0) first pixel")
    _close(patches[3], 1.0, "patch (0,0) second pixel, channel-major inside pixel")
    _close(patches[12], 2.0, "patch (1,0) first pixel")
    _close(patches[15], 3.0, "patch (1,0) second pixel")
    _close(patches[18], 6.0, "patch (1,0) second row first pixel")
    _close(patches[24], 8.0, "patch (0,1) first pixel")
    _close(patches[47], 15.0, "last patch last value")
    print("image_prep patchify order: PASS")


def test_preprocess_mean_std() raises:
    var pixels = List[UInt8]()
    for _ in range(4):
        pixels.append(255)
        pixels.append(0)
        pixels.append(128)
    var image = RgbImage(2, 2, pixels)
    var mean = List[Float32]()
    var std = List[Float32]()
    mean.append(0.5)
    mean.append(0.0)
    mean.append(0.5)
    std.append(0.5)
    std.append(1.0)
    std.append(0.5)
    var out = resize_normalize(image, 2, mean, std)
    _close(out[0], 1.0, "(1.0-0.5)/0.5 for the red channel")
    _close(out[1], 0.0, "green channel stays 0")
    _close(out[2], 0.00392157, "(128/255-0.5)/0.5 for the blue channel")
    print("image_prep mean/std: PASS")


def test_image_prep() raises:
    """Aggregate entry point; run_all registration lands with the ledger
    entry so the counted totals stay synchronized (see design doc)."""
    test_parse_ppm()
    test_resize_identity()
    test_resize_bilinear_oracle()
    test_patchify_order()
    test_preprocess_mean_std()


def main() raises:
    test_image_prep()
