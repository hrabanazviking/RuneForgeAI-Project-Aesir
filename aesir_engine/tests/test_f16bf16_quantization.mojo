"""S-089: known-value regressions for the precision tier — F16 direct
GEMM (gemm_f16_direct, the named dense path) and BF16 (the generalized
at-load conversion primitives + gemm_bf16, the direct BF16 GEMM with no
dequant detour), walking raw storage only.

BF16 fixtures are raw bit patterns checked against values computed by
hand from the BF16 format definition (sign / 8-bit exponent / 7-bit
mantissa; BF16 -> F32 is the exact <<16 widening ggml uses). GEMM
fixtures use only multiples of 0.5 in [-3, 3], so every product is a
multiple of 0.25 and every partial sum is exactly representable in
F32 at these magnitudes — fast (SIMD-chunked) and scalar (serial)
accumulation are therefore exact in any order and must agree bit-for-
bit, and both must equal the hand-computed sums.
"""

from core.mimir_well import (
    MimirWell,
    RuneTensor,
    bf16_bits_to_f16,
    bf16_bits_to_f32,
    convert_bf16_to_f16,
    f16,
)
from core.compute import gemm_bf16, gemm_bf16_scalar, gemm_f16, gemm_f16_direct
from loader.gguf import GGMLType
from std.math import isinf
from std.memory import Pointer, bitcast
from std.memory.alloc import alloc


def _vals_f32() -> List[Float32]:
    return [
        Float32(-2.0), Float32(-1.5), Float32(-1.0), Float32(-0.5),
        Float32(0.0), Float32(0.5), Float32(1.0), Float32(1.5),
        Float32(2.0), Float32(3.0),
    ]


def _vals_bf16() -> List[UInt16]:
    return [
        UInt16(0xC000), UInt16(0xBFC0), UInt16(0xBF80), UInt16(0xBF00),
        UInt16(0x0000), UInt16(0x3F00), UInt16(0x3F80), UInt16(0x3FC0),
        UInt16(0x4000), UInt16(0x4040),
    ]


def test_bf16_conversion() raises:
    # Hand-computed spots: bits -> f32 value (exact widening).
    if bf16_bits_to_f32(UInt16(0x0000)) != Float32(0.0):
        raise Error("BF16 0x0000 must widen to 0.0")
    if bf16_bits_to_f32(UInt16(0x3F80)) != Float32(1.0):
        raise Error("BF16 0x3F80 must widen to 1.0")
    if bf16_bits_to_f32(UInt16(0xBF80)) != Float32(-1.0):
        raise Error("BF16 0xBF80 must widen to -1.0")
    if bf16_bits_to_f32(UInt16(0x4000)) != Float32(2.0):
        raise Error("BF16 0x4000 must widen to 2.0")
    if bf16_bits_to_f32(UInt16(0x4049)) != Float32(3.140625):
        raise Error("BF16 0x4049 must widen to 3.140625")
    if bf16_bits_to_f32(UInt16(0x3D00)) != Float32(0.03125):
        raise Error("BF16 0x3D00 must widen to 0.03125")
    # Subnormal BF16 0x0001 = 2^-133; as F32 bits that is 0x00010000.
    if bitcast[DType.uint32](bf16_bits_to_f32(UInt16(0x0001))) != UInt32(0x00010000):
        raise Error("BF16 subnormal 0x0001 must widen to 2^-133")
    if not isinf(bf16_bits_to_f32(UInt16(0x7F80))):
        raise Error("BF16 0x7F80 must widen to +inf")
    if not isinf(bf16_bits_to_f32(UInt16(0xFF80))):
        raise Error("BF16 0xFF80 must widen to -inf")
    # F16 conversion: every in-range BF16 value is exact in F16
    # (7-bit mantissa is a subset of F16's 10-bit mantissa).
    if bf16_bits_to_f16(UInt16(0x4049)) != Scalar[f16](3.140625):
        raise Error("BF16 0x4049 must convert to f16 3.140625 exactly")
    if bf16_bits_to_f16(UInt16(0x3D00)) != Scalar[f16](0.03125):
        raise Error("BF16 0x3D00 must convert to f16 0.03125 exactly")
    # Range edges: 0x4780 = 65536 overflows F16 to +inf; the BF16
    # minimum normal 0x0080 = 2^-126 underflows F16 to zero.
    if not isinf(bf16_bits_to_f16(UInt16(0x4780)).cast[DType.float32]()):
        raise Error("BF16 0x4780 (65536) must convert to f16 +inf")
    if bf16_bits_to_f16(UInt16(0x0080)) != Scalar[f16](0.0):
        raise Error("BF16 0x0080 (2^-126) must convert to f16 zero")
    # Whole-buffer conversion == per-element reference on all lanes,
    # over a pattern that walks every fixture class.
    var n = 256
    var src = alloc[UInt16](n)
    var dst = alloc[Scalar[f16]](n)
    var pats = [
        UInt16(0x0000), UInt16(0x3F80), UInt16(0xBF80), UInt16(0x4000),
        UInt16(0xC000), UInt16(0x3F00), UInt16(0x4049), UInt16(0x3D00),
        UInt16(0x0001), UInt16(0x7F80), UInt16(0x4780), UInt16(0x0080),
        UInt16(0x3FC0), UInt16(0x4040), UInt16(0xBFC0), UInt16(0xBF00),
    ]
    for i in range(n):
        src.unsafe_store(i, pats[i % 16])
    convert_bf16_to_f16(src, dst, n)
    for i in range(n):
        if dst.unsafe_load(i) != bf16_bits_to_f16(src.unsafe_load(i)):
            raise Error("BF16 whole-buffer conversion vs per-element mismatch")
    src.unsafe_free()
    dst.unsafe_free()
    print("BF16 conversion (spots, subnormal, inf, range edges, buffer==scalar): PASS")


def test_gemm_bf16() raises:
    var well = MimirWell(1024 * 1024)
    var vals = _vals_f32()
    var vbits = _vals_bf16()
    # Hand-computed fixture: A 2x40, B 3x40 (period-10 patterns).
    # Expected C (row-major [2][3]) computed exactly:
    # [-4, 47, 8, -24, -4, 47].
    var a_ptr = well.allocate(2 * 40 * 2)
    for r in range(2):
        for k in range(40):
            a_ptr.unsafe_store(r * 40 + k, Scalar[f16](vals[(r * 7 + k * 3) % 10]))
    var b_ptr = well.allocate(3 * 40 * 2)
    var b_bits = b_ptr.unsafe_bitcast[UInt16]()
    for o in range(3):
        for k in range(40):
            b_bits.unsafe_store(o * 40 + k, vbits[(o * 3 + k * 7 + 1) % 10])
    var input = RuneTensor[f16](2, 40, a_ptr, False)
    var weights = RuneTensor[f16](3, 40, b_ptr, False)
    var expected = [
        Float32(-4.0), Float32(47.0), Float32(8.0),
        Float32(-24.0), Float32(-4.0), Float32(47.0),
    ]
    var out_fast = RuneTensor[f16](2, 3, well.allocate(2 * 3 * 2), False)
    gemm_bf16(input, weights, out_fast)
    var out_scalar = RuneTensor[f16](2, 3, well.allocate(2 * 3 * 2), False)
    gemm_bf16_scalar(input, weights, out_scalar)
    for i in range(6):
        if out_fast.data.unsafe_load(i) != Scalar[f16](expected[i]):
            raise Error("BF16 fast GEMM disagrees with hand-computed sums")
        if out_scalar.data.unsafe_load(i) != out_fast.data.unsafe_load(i):
            raise Error("BF16 fast GEMM vs scalar GEMM mismatch")
    # Larger pattern: fast == scalar on all outputs (exactness argument
    # in the module docstring), K = 64, 4 outputs.
    var a2_ptr = well.allocate(2 * 64 * 2)
    for i in range(2 * 64):
        a2_ptr.unsafe_store(i, Scalar[f16](vals[(i * 37 + 11) % 10]))
    var b2_ptr = well.allocate(4 * 64 * 2)
    var b2_bits = b2_ptr.unsafe_bitcast[UInt16]()
    for i in range(4 * 64):
        b2_bits.unsafe_store(i, vbits[(i * 53 + 7) % 10])
    var input2 = RuneTensor[f16](2, 64, a2_ptr, False)
    var weights2 = RuneTensor[f16](4, 64, b2_ptr, False)
    var out2_fast = RuneTensor[f16](2, 4, well.allocate(2 * 4 * 2), False)
    gemm_bf16(input2, weights2, out2_fast)
    var out2_scalar = RuneTensor[f16](2, 4, well.allocate(2 * 4 * 2), False)
    gemm_bf16_scalar(input2, weights2, out2_scalar)
    for i in range(8):
        if out2_fast.data.unsafe_load(i) != out2_scalar.data.unsafe_load(i):
            raise Error("BF16 fast GEMM vs scalar GEMM mismatch (large fixture)")
    # Shape rejection mutates nothing.
    var bad_out = RuneTensor[f16](2, 2, well.allocate(2 * 2 * 2), False)
    for i in range(4):
        bad_out.data.unsafe_store(i, Scalar[f16](99.0))
    var rejected = False
    try:
        gemm_bf16(input, weights, bad_out)
    except:
        rejected = True
    if not rejected:
        raise Error("BF16 GEMM accepted a mismatched output shape")
    for i in range(4):
        if bad_out.data.unsafe_load(i) != Scalar[f16](99.0):
            raise Error("BF16 GEMM shape rejection mutated output")
    print("BF16 direct GEMM (hand sums, fast==scalar, rejection): PASS")


def test_gemm_f16_direct() raises:
    var well = MimirWell(1024 * 1024)
    var vals = _vals_f32()
    # Same hand-computed fixture as the BF16 case, F16 storage:
    # expected [-4, 47, 8, -24, -4, 47].
    var a_ptr = well.allocate(2 * 40 * 2)
    for r in range(2):
        for k in range(40):
            a_ptr.unsafe_store(r * 40 + k, Scalar[f16](vals[(r * 7 + k * 3) % 10]))
    var b_ptr = well.allocate(3 * 40 * 2)
    for o in range(3):
        for k in range(40):
            b_ptr.unsafe_store(o * 40 + k, Scalar[f16](vals[(o * 3 + k * 7 + 1) % 10]))
    var input = RuneTensor[f16](2, 40, a_ptr, False)
    var weights = RuneTensor[f16](3, 40, b_ptr, False)
    var expected = [
        Float32(-4.0), Float32(47.0), Float32(8.0),
        Float32(-24.0), Float32(-4.0), Float32(47.0),
    ]
    var out_direct = RuneTensor[f16](2, 3, well.allocate(2 * 3 * 2), False)
    gemm_f16_direct(input, weights, out_direct)
    var out_dispatch = RuneTensor[f16](2, 3, well.allocate(2 * 3 * 2), False)
    gemm_f16(input, weights, out_dispatch)
    for i in range(6):
        if out_direct.data.unsafe_load(i) != Scalar[f16](expected[i]):
            raise Error("F16 direct GEMM disagrees with hand-computed sums")
        if out_dispatch.data.unsafe_load(i) != out_direct.data.unsafe_load(i):
            raise Error("F16 gemm_f16 fallthrough vs gemm_f16_direct mismatch")
    # Inner-dimension rejection.
    var bad_in = RuneTensor[f16](2, 32, well.allocate(2 * 32 * 2), False)
    var rejected = False
    try:
        gemm_f16_direct(bad_in, weights, out_direct)
    except:
        rejected = True
    if not rejected:
        raise Error("F16 direct GEMM accepted an inner-dimension mismatch")
    print("F16 direct GEMM (hand sums, direct==dispatch, rejection): PASS")


def test_dispatch_boundary() raises:
    # Dense precision types are NOT compressed formats: the loader
    # handles F16 plainly and BF16 by at-load conversion, and
    # to_compressed_format must keep rejecting both (the counted
    # quantization.enum case pins the same invariant for F32).
    var rejected_f16 = False
    try:
        _ = GGMLType.to_compressed_format(GGMLType.F16)
    except error:
        rejected_f16 = "unsupported GGML tensor type" in String(error)
    if not rejected_f16:
        raise Error("F16 was silently mapped to a compressed format")
    var rejected_bf16 = False
    try:
        _ = GGMLType.to_compressed_format(GGMLType.BF16)
    except error:
        rejected_bf16 = "unsupported GGML tensor type" in String(error)
    if not rejected_bf16:
        raise Error("BF16 was silently mapped to a compressed format")
    print("Precision-tier dispatch boundary (F16/BF16 not compressed formats): PASS")


def main() raises:
    test_bf16_conversion()
    test_gemm_bf16()
    test_gemm_f16_direct()
    test_dispatch_boundary()
    print("F16/BF16 tests: ALL PASS")
