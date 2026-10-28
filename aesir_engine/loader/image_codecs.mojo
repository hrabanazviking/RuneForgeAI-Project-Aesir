"""PNG/JPEG decoding for the vision prep path (edge FFI module).

The decode itself lives in aesir_engine/image_decode.c (system
libpng/libjpeg), built by scripts/build_image_shim.sh into
libaesir_image.so. This module binds its two entry points as
link-time symbols - the same pattern as the Hailo bridge - so it is
imported only by drivers, tests, and CLI surfaces that stage the
library (-Xlinker -L<dir> -laesir_image, plus rpath or
LD_LIBRARY_PATH), never by loader/core modules: a dlopen binding
(std.ffi) cannot coexist in one binary with the engine's raw
external_call FFI declarations (core/cuda_gate.mojo and kin), and
link-time binding is the codebase's proven alternative.

loader/image_prep stays FFI-free (PPM). load_any below feeds every
supported format into the same RgbImage prep path (resize,
normalize, patchify), which is what "the same prep path" means for
the encoder: identical pixels in, identical patches out.
"""
from std.ffi import external_call
from std.memory import Pointer
from hailbru.syscall import os_host_architecture, read_file_bytes
from loader.image_prep import RgbImage, parse_ppm


def decode_image_file(path: String) raises -> RgbImage:
    """Decodes a PNG or JPEG file to RGB8 through the shim.
    Fail-closed: a nonzero shim return (missing/corrupt/unsupported
    file) raises; the shim itself sniffs magic bytes, so a PPM or
    text file routed here by mistake also raises."""
    var owned_path = path
    var cpath = owned_path.as_c_string_slice()
    var w = Int32(0)
    var h = Int32(0)
    var rgb_addr = Int(0)
    var rc = external_call["aesir_image_decode", Int32](
        cpath.unsafe_ptr(), Pointer(to=w), Pointer(to=h), Pointer(to=rgb_addr)
    )
    if rc != 0 or rgb_addr == 0:
        raise Error("image_codecs: PNG/JPEG decode failed for " + path)
    var rgb = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=rgb_addr)
    var count = Int(w) * Int(h) * 3
    var pixels = List[UInt8]()
    pixels.reserve(count)
    for i in range(count):
        pixels.append(rgb.unsafe_load(i))
    _ = external_call["aesir_image_free", Int32](rgb)
    var image = RgbImage(Int(w), Int(h), pixels)
    image.validate()
    return image^


def load_any(path: String) raises -> RgbImage:
    """Loads an image in any supported format, dispatched by magic
    bytes: PPM (P6) via loader/image_prep, PNG/JPEG via the shim."""
    var data = read_file_bytes(os_host_architecture(), path, 268435456)
    if len(data) >= 2 and data[0] == UInt8(80) and data[1] == UInt8(54):
        return parse_ppm(data)
    if (
        len(data) >= 4
        and data[0] == UInt8(137)
        and data[1] == UInt8(80)
        and data[2] == UInt8(78)
        and data[3] == UInt8(71)
    ):
        return decode_image_file(path)
    if len(data) >= 2 and data[0] == UInt8(255) and data[1] == UInt8(216):
        return decode_image_file(path)
    raise Error("image_codecs: unsupported image format (magic bytes not PPM/PNG/JPEG)")
