# SMIÐR vector-add configuration generator (H104).
#
# Deterministic, seeded generator emitting host-side test vectors:
#   vecadd_a.bin, vecadd_b.bin      — 64 fp16 (LE) inputs
#   vecadd_expected.bin             — 64 fp16 (LE) expected outputs (a+b)
#   vecadd_config.json              — manifest describing the config
#
# This is SMIÐR-CFG v1, a HOST-SIDE test configuration format documented
# as a new manifest line in docs/plunder/H019_HEF_SURFACE_ANALYSIS.md.
# It is NOT a HEF and NOT a chip-executable program (L3, L5): chip
# executability is honestly UNPROVEN (H105 will test). Every byte is
# accounted for: .bin files are raw fp16 payloads (no header, no magic);
# the JSON carries only documented fields.
#
# Determinism: xorshift64 PRNG; values are multiples of 0.125 in
# [-125, 125], exactly representable in fp16, so a+b is also exact —
# no rounding ambiguity between the Mojo emitter and the independent
# Python validator (which reimplements the PRNG and fp16 mapping).

from hailbru.errors import herror
from smidr.descriptor import ByteBuf
from std.memory import bitcast


def CFG_FORMAT() -> String:
    return String("SMIDR-CFG")


def CFG_VERSION() -> Int:
    return 1


def VECADD_NELEMS() -> Int:
    return 64


struct XorShift64:
    var state: UInt64

    def __init__(out self, seed: UInt64):
        if seed == UInt64(0):
            self.state = UInt64(0x9E3779B97F4A7C15)
        else:
            self.state = seed

    def next(mut self) -> UInt64:
        var x = self.state
        x ^= x << UInt64(13)
        x ^= x >> UInt64(7)
        x ^= x << UInt64(17)
        self.state = x
        return x


def _gen_value(mut rng: XorShift64) -> Float32:
    # Multiple of 0.125 in [-125, 125]; exact in fp16.
    var i = Int(rng.next() % UInt64(2001)) - 1000
    return Float32(i) / Float32(8.0)


def f32_to_f16_bits(x: Float32) -> UInt16:
    # Round-to-nearest-even f32 -> f16 bit pattern.
    var u = bitcast[DType.uint32](x)
    var sign = UInt16((u >> UInt32(16)) & UInt32(0x8000))
    var exp32 = Int((u >> UInt32(23)) & UInt32(0xFF))
    var mant32 = u & UInt32(0x7FFFFF)
    if exp32 == 0:
        # Zero / f32 subnormal -> f16 zero (sign-preserving).
        return sign
    if exp32 == 255:
        # Inf / NaN -> f16 inf / quiet NaN.
        if mant32 == UInt32(0):
            return sign | UInt16(0x7C00)
        return sign | UInt16(0x7E00)
    var exp16 = exp32 - 112  # 127 - 15
    if exp16 >= 31:
        return sign | UInt16(0x7C00)  # overflow -> inf
    if exp16 <= 0:
        # Subnormal in f16 (or underflow to zero).
        if exp16 < -10:
            return sign
        var mant = mant32 | UInt32(0x800000)
        var shift = UInt32(14 - exp16)
        var sub = mant >> shift
        # Round to nearest even on the dropped bits.
        var dropped = mant & ((UInt32(1) << shift) - UInt32(1))
        var halfbit = UInt32(1) << (shift - UInt32(1))
        if dropped > halfbit or (
            dropped == halfbit and (sub & UInt32(1)) == UInt32(1)
        ):
            sub += UInt32(1)
        return sign | UInt16(sub)
    # Normal range: round the 23-bit mantissa to 10 bits.
    var half = UInt16((mant32 >> UInt32(13)) & UInt32(0x3FF))
    var dropped = mant32 & UInt32(0x1FFF)
    if dropped > UInt32(0x1000) or (
        dropped == UInt32(0x1000) and (half & UInt16(1)) == UInt16(1)
    ):
        half += UInt16(1)
        if half == UInt16(0x400):  # mantissa overflow -> bump exponent
            half = UInt16(0)
            exp16 += 1
            if exp16 >= 31:
                return sign | UInt16(0x7C00)
    return sign | (UInt16(exp16) << UInt16(10)) | half


def gen_vecadd(
    seed: UInt64,
    mut a_bin: List[UInt8],
    mut b_bin: List[UInt8],
    mut e_bin: List[UInt8],
):
    # Fills the three raw LE fp16 payloads (128 bytes each).
    var rng = XorShift64(seed)
    var ab = ByteBuf()
    var bb = ByteBuf()
    var eb = ByteBuf()
    for _ in range(VECADD_NELEMS()):
        var av = _gen_value(rng)
        var bv = _gen_value(rng)
        ab.put_u16(f32_to_f16_bits(av))
        bb.put_u16(f32_to_f16_bits(bv))
        eb.put_u16(f32_to_f16_bits(av + bv))
    a_bin = ab.take()
    b_bin = bb.take()
    e_bin = eb.take()


def config_json(seed: UInt64) -> String:
    var js = String("{\n")
    js += "  \"format\": \"" + CFG_FORMAT() + "\",\n"
    js += "  \"version\": " + String(CFG_VERSION()) + ",\n"
    js += "  \"op\": \"vecadd\",\n"
    js += "  \"seed\": " + String(seed) + ",\n"
    js += "  \"dtype\": \"fp16\",\n"
    js += "  \"nelems\": " + String(VECADD_NELEMS()) + ",\n"
    js += "  \"layout\": \"contiguous-1d\",\n"
    js += "  \"files\": [\"vecadd_a.bin\", \"vecadd_b.bin\", \"vecadd_expected.bin\"],\n"
    js += "  \"notes\": \"SMIDR-CFG v1 host-side test config (see H019 manifest). NOT a HEF. Chip executability UNPROVEN.\"\n"
    js += "}\n"
    return js
