# H031 — Quantization primitives: FP32->FP16, FP16->Q8_0, Q8_0->FP16.
#
# Q8_0 BLOCK FORMAT (byte-exact, 34 bytes per 32-value block):
#   bytes [0:2]  : scale, IEEE-754 binary16, little-endian
#   bytes [2:34] : 32 x int8, q[i] = round_half_away(x[i] / scale),
#                  clamped to [-128, 127]
#   scale = max_abs(block) / 127   (max_abs == 0 -> scale = 1.0, all q = 0)
#   dequant: x[i] = float(q[i]) * scale   (fp32, rounded to fp16 on store)
#
# fp16 bit handling: Mojo 1.1.0 scalars have no bitcast, so the scale's
# bit pattern is produced/consumed by exact arithmetic decomposition
# (fp16_bits_of / fp16_from_bits below). Exact for all normal values;
# subnormals flush to zero (documented; block scales are block maxima and
# are never subnormal in practice).
#
# SÓLRÚN RE-SCOPE (2026-10-10): the roadmap's contract numbers
# (max <= 0.02, RMS <= 0.005 on uniform[-6,6]) are mathematically
# infeasible for symmetric int8: max err <= max_abs/254 = 0.0236 and
# RMS = scale/sqrt(12) <= 0.0136 for max_abs = 6. The contract recorded
# in data/armvegr/quant_contract.json uses the derivable bounds:
# max <= 0.024, RMS <= 0.014, with this derivation.

from std.math import exp2
from std.memory import Pointer
from std.origin import MutUntrackedOrigin


def fp16_bits_of(f: Float32) -> UInt16:
    # Exact IEEE-754 binary16 bit pattern of f (f finite, |f| <= 65504).
    # Round-half-even on the 10-bit mantissa.
    if f == Float32(0):
        return UInt16(0)
    var sign = UInt16(0)
    var af = f
    if af < Float32(0):
        sign = UInt16(0x8000)
        af = -af
    var e = 0
    while af >= Float32(2):
        af = af / Float32(2)
        e += 1
    while af < Float32(1):
        af = af * Float32(2)
        e -= 1
    var m10 = af * Float32(1024)
    var lo = Int(m10)
    var frac = m10 - Float32(lo)
    if frac > Float32(0.5) or (frac == Float32(0.5) and lo % 2 == 1):
        lo += 1
    if lo == 2048:
        lo = 1024
        e += 1
    var eb = e + 15
    if eb >= 31:
        return sign | UInt16(0x7BFF)
    if eb <= 0:
        return sign  # subnormal flush (documented; not hit by scales)
    return sign | UInt16(eb << 10) | UInt16(lo - 1024)


def fp16_from_bits(w: UInt16) -> Float32:
    # Inverse of fp16_bits_of. Handles normals, subnormals, and zero.
    var eb = Int((w >> 10) & UInt16(0x1F))
    var mant = Int(w & UInt16(0x3FF))
    var v: Float32
    if eb == 0:
        if mant == 0:
            v = Float32(0.0)
        else:
            # Subnormal: (mant/1024) * 2^-14
            v = Float32(mant) / Float32(1024.0) / Float32(16384.0)
    elif eb == 31:
        # Inf/NaN: return large value (should not occur in weights)
        v = Float32(3.4028235e38)
        if mant != 0:
            v = Float32(0.0)  # NaN -> 0 (fail-safe)
    else:
        v = Float32(1024 + mant) / Float32(1024)
        var e = eb - 15
        if e >= 0:
            for _ in range(e):
                v *= Float32(2)
        else:
            for _ in range(-e):
                v /= Float32(2)
    if (w & UInt16(0x8000)) != UInt16(0):
        v = -v
    return v


def write_u16_le(buf: Pointer[Int8, MutUntrackedOrigin], off: Int, w: UInt16):
    # Scale bytes wrap through Int8 (bit-preserving); read back with UInt8().
    buf[unsafe_offset=off] = Int8(UInt8(w & UInt16(0xFF)))
    buf[unsafe_offset=off + 1] = Int8(UInt8((w >> 8) & UInt16(0xFF)))


def read_u16_le(buf: Pointer[Int8, MutUntrackedOrigin], off: Int) -> UInt16:
    return UInt16(UInt8(buf[unsafe_offset=off])) | (
        UInt16(UInt8(buf[unsafe_offset=off + 1])) << 8
    )


def round_half_away(x: Float32) -> Int:
    if x >= Float32(0):
        return Int(x + Float32(0.5))
    return Int(x - Float32(0.5))


def fp32_to_fp16(
    src: Pointer[Float32, MutUntrackedOrigin],
    dst: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    var i = 0
    while i + 8 <= n:
        var v = src.unsafe_offset(i).unsafe_load[8]()
        dst.unsafe_store(i, v.cast[DType.float16]())
        i += 8
    for kk in range(i, n):
        dst[unsafe_offset=kk] = Float16(src[unsafe_offset=kk])


def q80_quant_block(
    src: Pointer[Float16, MutUntrackedOrigin],
    dst: Pointer[Int8, MutUntrackedOrigin],
    n: Int,
):
    # Quantize n = 32 fp16 values into one 34-byte Q8_0 block at dst.
    var amax = Float32(0)
    for i in range(n):
        var v = Float32(src[unsafe_offset=i])
        if v < Float32(0):
            v = -v
        if v > amax:
            amax = v
    var scale = amax / Float32(127)
    if amax == Float32(0):
        scale = Float32(1)
    write_u16_le(dst, 0, fp16_bits_of(scale))
    var inv = Float32(1) / scale
    for i in range(n):
        var q = round_half_away(Float32(src[unsafe_offset=i]) * inv)
        if q > 127:
            q = 127
        if q < -128:
            q = -128
        dst[unsafe_offset=2 + i] = Int8(q)


def q80_dequant_block(
    src: Pointer[Int8, MutUntrackedOrigin],
    dst: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    var scale = fp16_from_bits(read_u16_le(src, 0))
    for i in range(n):
        var q = Int(src[unsafe_offset=2 + i])
        dst[unsafe_offset=i] = Float16(Float32(q) * scale)


def q80_block_scale(src: Pointer[Int8, MutUntrackedOrigin], bo: Int) -> Float32:
    return fp16_from_bits(read_u16_le(src, bo))


def q80_block_scale_fast(
    src: Pointer[Int8, MutUntrackedOrigin], bo: Int
) -> Float32:
    # Branchless fp16->fp32 for block scales (always positive normal
    # fp16 values). value = (1 + mant/1024) * 2^(eb-15), with the
    # power of two via exp2 (exact for integer exponents). The general
    # fp16_from_bits uses up to 15 fp divisions in a loop; this is a
    # handful of instructions. Used by qgemm's hot loop only.
    var w = read_u16_le(src, bo)
    var eb = Int((w >> 10) & UInt16(0x1F))
    var mant = Int(w & UInt16(0x3FF))
    var v = Float32(1024 + mant) / Float32(1024)
    return v * exp2(SIMD[DType.float32, 1](Float32(eb - 15)))[0]


def fp16_to_q80(
    src: Pointer[Float16, MutUntrackedOrigin],
    dst: Pointer[Int8, MutUntrackedOrigin],
    n: Int,
):
    # n must be a multiple of 32; each block is 34 bytes.
    var nb = n // 32
    for b in range(nb):
        q80_quant_block(
            src.unsafe_offset(b * 32), dst.unsafe_offset(b * 34), 32
        )


def q80_to_fp16(
    src: Pointer[Int8, MutUntrackedOrigin],
    dst: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    var nb = n // 32
    for b in range(nb):
        q80_dequant_block(
            src.unsafe_offset(b * 34), dst.unsafe_offset(b * 32), 32
        )


def q6k_to_fp16(
    src: Pointer[Int8, MutUntrackedOrigin],
    dst: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    """Dequantize Q6_K to FP16. 210 bytes per 256 elements.
    Layout (matches ggml-quants.c dequantize_row_q6_K; verified against ggml
    via ctypes 2026-10-10, H059R1): ql[128] (lower 4 bits), qh[64] (upper
    2 bits), scales[16] (int8), d (fp16). For j in {0,128}, l in 0..31:
      y[j+l]    = d*sc[j/16+l/16]  *(ql[j/2+l]&0xF    | ((qh[j/4+l]&3)<<4)   - 32)
      y[j+l+32] = d*sc[j/16+l/16+2]*((ql[j/2+l+32]&0xF | (((qh[j/4+l]>>2)&3)<<4)) - 32)
      y[j+l+64] = d*sc[j/16+l/16+4]*(((ql[j/2+l]>>4)&0xF|(((qh[j/4+l]>>4)&3)<<4)) - 32)
      y[j+l+96] = d*sc[j/16+l/16+6]*(((ql[j/2+l+32]>>4)&0xF|(((qh[j/4+l]>>6)&3)<<4)) - 32)
    """
    var nb = n // 256
    for b in range(nb):
        var base = b * 210
        var d = fp16_from_bits(read_u16_le(src, base + 208))
        for j in range(0, 256, 128):
            var ql_o = base + j // 2
            var qh_o = base + 128 + j // 4
            var sc_o = base + 192 + j // 16
            for l in range(32):
                var is_ = l // 16
                var b0 = Int(src.unsafe_offset(ql_o + l).unsafe_load()) & 0xFF
                var b1 = Int(src.unsafe_offset(ql_o + l + 32).unsafe_load()) & 0xFF
                var hb = Int(src.unsafe_offset(qh_o + l).unsafe_load()) & 0xFF
                var sc0 = Float32(
                    Int(src.unsafe_offset(sc_o + is_).unsafe_load())
                )
                var sc1 = Float32(
                    Int(src.unsafe_offset(sc_o + is_ + 2).unsafe_load())
                )
                var sc2 = Float32(
                    Int(src.unsafe_offset(sc_o + is_ + 4).unsafe_load())
                )
                var sc3 = Float32(
                    Int(src.unsafe_offset(sc_o + is_ + 6).unsafe_load())
                )
                var q1 = (b0 & 0xF) | ((hb & 0x3) << 4)
                var q2 = (b1 & 0xF) | (((hb >> 2) & 0x3) << 4)
                var q3 = ((b0 >> 4) & 0xF) | (((hb >> 4) & 0x3) << 4)
                var q4 = ((b1 >> 4) & 0xF) | (((hb >> 6) & 0x3) << 4)
                var o = b * 256 + j
                dst.unsafe_offset(o + l).unsafe_store(
                    Float16(d * sc0 * Float32(q1 - 32))
                )
                dst.unsafe_offset(o + l + 32).unsafe_store(
                    Float16(d * sc1 * Float32(q2 - 32))
                )
                dst.unsafe_offset(o + l + 64).unsafe_store(
                    Float16(d * sc2 * Float32(q3 - 32))
                )
                dst.unsafe_offset(o + l + 96).unsafe_store(
                    Float16(d * sc3 * Float32(q4 - 32))
                )
