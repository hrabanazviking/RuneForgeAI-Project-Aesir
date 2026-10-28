"""Opt-in PNG/JPEG decode tests (loader/image_codecs.mojo).

Not part of run_all: the suite binds libaesir_image at link time.
Build and run from the checkout root:

  scripts/build_image_shim.sh /tmp/aesir_image_shim
  mojo run -I . -I aesir_engine \\
    -Xlinker -L/tmp/aesir_image_shim -Xlinker -laesir_image \\
    -Xlinker -rpath -Xlinker /tmp/aesir_image_shim \\
    aesir_engine/tests/test_image_codecs.mojo

Fixtures /tmp/aesir_img_fx.{ppm,png,jpg} hold the same smooth 6x4
gradient (regenerate with PIL: pixel (x, y) = (x*40, y*60,
(x+y)*20); PNG lossless; JPEG quality 95, subsampling 0). PNG must
equal the PPM route pixel for pixel; JPEG is lossy and must stay
within a few LSBs on this smooth fixture.
"""
from loader.image_codecs import load_any
from loader.image_prep import load_ppm_file


def _expect(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def test_png_matches_ppm() raises:
    var via_dispatch = load_any("/tmp/aesir_img_fx.png")
    var reference = load_ppm_file("/tmp/aesir_img_fx.ppm")
    _expect(via_dispatch.width == reference.width, "png width matches ppm")
    _expect(via_dispatch.height == reference.height, "png height matches ppm")
    for i in range(len(reference.pixels)):
        _expect(
            via_dispatch.pixels[i] == reference.pixels[i],
            "png pixel " + String(i) + " exact",
        )
    print("image png decode: PASS")


def test_jpeg_close_to_ppm() raises:
    var via_dispatch = load_any("/tmp/aesir_img_fx.jpg")
    var reference = load_ppm_file("/tmp/aesir_img_fx.ppm")
    _expect(via_dispatch.width == reference.width, "jpeg width matches ppm")
    _expect(via_dispatch.height == reference.height, "jpeg height matches ppm")
    var worst = 0
    for i in range(len(reference.pixels)):
        var d = Int(via_dispatch.pixels[i]) - Int(reference.pixels[i])
        if d < 0:
            d = -d
        if d > worst:
            worst = d
    _expect(worst <= 6, "jpeg max channel diff " + String(worst) + " <= 6")
    print("image jpeg decode: PASS (max diff", worst, ")")


def test_image_codecs() raises:
    test_png_matches_ppm()
    test_jpeg_close_to_ppm()


def main() raises:
    test_image_codecs()
    print("test_image_codecs: PASS")
