# TEMPORARY diagnostic probe (removed before final commit).
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc
from armvegr.quant import (
    fp16_bits_of,
    fp16_from_bits,
    fp16_to_q80,
    q80_to_fp16,
    read_u16_le,
    write_u16_le,
)


def main():
    # P1: signed/unsigned byte conversion semantics.
    var neg = Int8(-5)
    print("UInt8(Int8(-5)) =", UInt8(neg))
    print("Int(UInt8(Int8(-5))) =", Int(UInt8(neg)))
    # P2: scale byte roundtrip for a realistic scale.
    var buf = unsafe_alloc[Int8](34)
    var scale = Float32(6.0) / Float32(127)
    var bits = fp16_bits_of(scale)
    print("scale =", scale, "bits =", bits)
    write_u16_le(buf, 0, bits)
    print("byte0 =", Int(buf[unsafe_offset=0]), "byte1 =", Int(buf[unsafe_offset=1]))
    var back = read_u16_le(buf, 0)
    print("read back bits =", back, "scale =", fp16_from_bits(back))
    # P3: full block roundtrip on constant 1.0.
    var x = unsafe_alloc[Float16](32)
    var y = unsafe_alloc[Float16](32)
    for i in range(32):
        x[unsafe_offset=i] = Float16(1.0)
    fp16_to_q80(x, buf, 32)
    print("q block scale bits =", read_u16_le(buf, 0))
    print("q[0] =", Int(buf[unsafe_offset=2]))
    q80_to_fp16(buf, y, 32)
    print("y[0] =", y[unsafe_offset=0], "y[31] =", y[unsafe_offset=31])
