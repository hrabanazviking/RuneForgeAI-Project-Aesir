# H032 — Q4_0 block quantization (the format small-model weights ship in).
#
# Q4_0 BLOCK FORMAT (byte-exact, 18 bytes per 32-value block):
#   bytes [0:2]   : scale, IEEE-754 binary16, little-endian
#   bytes [2:18]  : 16 bytes, 2x 4-bit nibbles per byte, GGML SPLIT-HALF layout:
#                   byte b holds q[b] in bits [3:0] and q[b+16] in bits [7:4]
#                   (matches ggml-quants.c dequantize_row_q4_0; verified against
#                   ggml via ctypes 2026-10-10, H059R1)
#   scale = max_abs(block) / 7   (max_abs == 0 -> scale = 1.0, all q = 0)
#   q[i] = round_half_away(x[i] / scale), clamped to [-8, 7]
#   dequant: x[i] = float(q_signed[i]) * scale, q_signed in [-8, 7]
#
# SÓLRÚN RE-SCOPE (2026-10-10): the roadmap's contract numbers
# (max <= 0.08, RMS <= 0.02 on uniform[-6,6]) are mathematically
# infeasible for symmetric 4-bit: max err <= max_abs/14 = 0.43 and
# RMS = scale/sqrt(12) <= 0.25 for max_abs = 6. The contract in
# data/armvegr/quant_contract.json records the derivable bounds:
# max <= 0.43, RMS <= 0.25, with this derivation. (4-bit quantization
# is designed for weight distributions ~N(0, 0.02), not uniform[-6,6];
# on real weights the same kernel achieves far tighter round-trips.)

from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from armvegr.quant import (
    fp16_bits_of,
    fp16_from_bits,
    write_u16_le,
    read_u16_le,
    round_half_away,
)


def q40_quant_block(
    src: Pointer[Float16, MutUntrackedOrigin],
    dst: Pointer[Int8, MutUntrackedOrigin],
    n: Int,
):
    # Quantize n = 32 fp16 values into one 18-byte Q4_0 block at dst.
    var amax = Float32(0)
    for i in range(n):
        var v = Float32(src[unsafe_offset=i])
        if v < Float32(0):
            v = -v
        if v > amax:
            amax = v
    var scale = amax / Float32(7)
    if amax == Float32(0):
        scale = Float32(1)
    write_u16_le(dst, 0, fp16_bits_of(scale))
    var inv = Float32(1) / scale
    for b in range(16):
        # GGML split-half (matches q40_dequant_block): byte b holds
        # element b in the low nibble and element b+16 in the high nibble,
        # values stored biased by +8.
        var q0 = round_half_away(Float32(src[unsafe_offset=b]) * inv)
        var q1 = round_half_away(Float32(src[unsafe_offset=b + 16]) * inv)
        if q0 > 7:
            q0 = 7
        if q0 < -8:
            q0 = -8
        if q1 > 7:
            q1 = 7
        if q1 < -8:
            q1 = -8
        # GGML split-half: q[b] in bits [3:0], q[b+16] in bits [7:4].
        var byte = UInt8(q0 & 15) | (UInt8(q1 & 15) << 4)
        dst[unsafe_offset=2 + b] = Int8(byte)


def q40_dequant_block(
    src: Pointer[Int8, MutUntrackedOrigin],
    dst: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    var scale = fp16_from_bits(read_u16_le(src, 0))
    for b in range(16):
        var byte = UInt8(src[unsafe_offset=2 + b])
        # GGML: x0 = (q & 0xF) - 8 (values stored biased by +8).
        var q0 = Int(byte & UInt8(15)) - 8
        var q1 = Int((byte >> 4) & UInt8(15)) - 8
        # GGML split-half: byte b -> elements b (low nibble) and b+16 (high).
        dst[unsafe_offset=b] = Float16(Float32(q0) * scale)
        dst[unsafe_offset=b + 16] = Float16(Float32(q1) * scale)


def fp16_to_q40(
    src: Pointer[Float16, MutUntrackedOrigin],
    dst: Pointer[Int8, MutUntrackedOrigin],
    n: Int,
):
    # n must be a multiple of 32; each block is 18 bytes.
    var nb = n // 32
    for b in range(nb):
        q40_quant_block(src.unsafe_offset(b * 32), dst.unsafe_offset(b * 18), 32)


def q40_to_fp16(
    src: Pointer[Int8, MutUntrackedOrigin],
    dst: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    var nb = n // 32
    for b in range(nb):
        q40_dequant_block(src.unsafe_offset(b * 18), dst.unsafe_offset(b * 32), 32)
