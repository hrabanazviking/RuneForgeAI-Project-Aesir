# tests/h044_bf16_exhaust.mojo
# H044 — exhaustive BF16->FP16 RNE check (TEST-ONLY driver, not shipped).
#
# Converts all 65536 BF16 bit patterns with armvegr/safetensors.mojo's
# bf16_to_fp16_rne and writes the resulting FP16 values' raw bytes to
# <outfile> (131072 bytes, LE). The independent Python reference
# (prof/armvegr/check_bf16_rne.py) computes the expected bytes with
# integer arithmetic; the files must be byte-identical.
#
# Usage: h044_bf16_exhaust <outfile>

from std.sys import argv
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.safetensors import bf16_to_fp16_rne


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: h044_bf16_exhaust <outfile>")
    var n = 65536
    var src = unsafe_alloc[UInt16](n)
    var dst = unsafe_alloc[Float16](n)
    for i in range(n):
        src[unsafe_offset=i] = UInt16(i)
    bf16_to_fp16_rne(src, dst, n)
    var path_bytes = List[Int8]()
    var source = args[1].as_bytes()
    for i in range(len(source)):
        path_bytes.append(Int8(source[i]))
    path_bytes.append(0)
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(577), Int32(416)
    )
    _ = path_bytes
    if fd < 0:
        raise Error("h044: cannot open output")
    var bp = dst.unsafe_bitcast[UInt8]()
    var total = 2 * n
    var written = 0
    while written < total:
        var w = external_call["write", Int](Int(fd), bp.unsafe_offset(written), total - written)
        if w <= 0:
            raise Error("h044: write failed")
        written += Int(w)
    _ = external_call["close", Int32](fd)
    src.unsafe_free()
    dst.unsafe_free()
    print("H044-EXHAUST-DONE")
