"""A-047: precision paths verified against independent Float64 references.

Every reference in this file is computed in-test with Float64 scalar
loops over the EXACT stored inputs (the F16 values actually in the
tensors, the BF16 bit patterns actually in storage) -- never by calling
the path under test or its retained scalar oracle. Bounds asserted here
are the filed bounds in docs/bench/A047_PRECISION_BOUNDS.md (measured
maxima from tests/bench_precision_a047.mojo, filed with headroom).

Paths covered:
- F32 accumulation: gemm_f16_direct on dyadic inputs must reproduce
  the Float64 reference rounded once to F16, bit-exact (every product
  and partial sum is exact in F32 by construction).
- F16: gemm_f16_direct vs Float64 reference.
- BF16: gemm_bf16 vs Float64 reference; bf16_bits_to_f32 widening
  checked arithmetically over all 65536 patterns; F32->F16 roundtrip
  (the cast every path exits through) bounded by half a F16 ULP.
- F32 internal math: rmsnorm (F32 sumsq / sqrt / scale) vs Float64.
"""

from std.math import sqrt

from core.mimir_well import (
    MimirWell,
    RuneTensor,
    bf16_bits_to_f32,
    convert_bf16_to_f16,
    f16,
)


from core.compute import gemm_bf16, gemm_f16_direct, rmsnorm


struct _Lcg:
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next(mut self) -> UInt64:
        self.state = (
            self.state * 6364136223846793005 + 1442695040888963407
        )
        return self.state >> 11

    def unit(mut self) -> Float64:
        # Uniform in [0, 1) from the top 53 bits.
        return Float64(self.next() % 9007199254740992) / 9007199254740992.0


def _fill_f16(
    mut lcg: _Lcg, ptr: Pointer[Scalar[f16], MutUntrackedOrigin], n: Int
):
    for i in range(n):
        var v = Float32(lcg.unit() * 2.0 - 1.0)
        ptr.unsafe_store(i, v.cast[f16]())


def _gemm_ref_f64(
    a: Pointer[Scalar[f16], MutUntrackedOrigin],
    b: Pointer[Scalar[f16], MutUntrackedOrigin],
    m: Int,
    k: Int,
    n: Int,
    row: Int,
    col: Int,
) -> Float64:
    var acc: Float64 = 0.0
    for inner in range(k):
        acc += Float64(a.unsafe_load(row * k + inner).cast[DType.float32]()) * Float64(
            b.unsafe_load(col * k + inner).cast[DType.float32]()
        )
    return acc


def test_precision_f32_accumulation_dyadic_exact() raises:
    """Dyadic inputs (multiples of 1/8 in [-2, 2], K=256): every F32
    product and partial sum in gemm_f16_direct is exact, so the output
    must equal the Float64 reference rounded once to F16, bit-exact."""
    var m = 4
    var k = 256
    var n = 8
    var well = MimirWell(65536)
    var a = well.allocate(m * k)
    var b = well.allocate(n * k)
    var c = well.allocate(m * n)
    var lcg = _Lcg(0xA047)
    for i in range(m * k):
        var q = Int(lcg.next() % 33) - 16
        a.unsafe_store(i, (Float32(q) * Float32(0.125)).cast[f16]())
    for i in range(n * k):
        var q = Int(lcg.next() % 33) - 16
        b.unsafe_store(i, (Float32(q) * Float32(0.125)).cast[f16]())
    var A = RuneTensor[f16](m, k, a, False)
    var B = RuneTensor[f16](n, k, b, False)
    var C = RuneTensor[f16](m, n, c, False)
    gemm_f16_direct(A, B, C)
    for row in range(m):
        for col in range(n):
            var refv = _gemm_ref_f64(a, b, m, k, n, row, col)
            var expected = Float32(refv).cast[f16]()
            var got = c.unsafe_load(row * n + col)
            if got != expected:
                raise Error("precision.f32_accumulation_dyadic_exact: mismatch")


def test_precision_f16_gemm_f64_reference() raises:
    """gemm_f16_direct vs Float64 reference, K=1024 non-dyadic data.
    Filed bound: max abs err <= 1.6e-2, max rel err <= 4e-3 (rel guard
    |ref| >= 1). Dominated by the single F16 output rounding."""
    var m = 8
    var k = 1024
    var n = 32
    var well = MimirWell(262144)
    var a = well.allocate(m * k)
    var b = well.allocate(n * k)
    var c = well.allocate(m * n)
    var lcg = _Lcg(0xF16)
    _fill_f16(lcg, a, m * k)
    _fill_f16(lcg, b, n * k)
    var A = RuneTensor[f16](m, k, a, False)
    var B = RuneTensor[f16](n, k, b, False)
    var C = RuneTensor[f16](m, n, c, False)
    gemm_f16_direct(A, B, C)
    var max_abs: Float64 = 0.0
    var max_rel: Float64 = 0.0
    for row in range(m):
        for col in range(n):
            var refv = _gemm_ref_f64(a, b, m, k, n, row, col)
            var got = Float64(c.unsafe_load(row * n + col).cast[DType.float32]())
            var err = got - refv
            if err < 0:
                err = -err
            if err > max_abs:
                max_abs = err
            var mag = refv
            if mag < 0:
                mag = -mag
            if mag >= 1.0 and err / mag > max_rel:
                max_rel = err / mag
    if max_abs > 0.016 or max_rel > 0.004:
        raise Error("precision.f16_gemm_f64_reference: bound exceeded")


def test_precision_bf16_gemm_f64_reference() raises:
    """gemm_bf16 vs Float64 reference over the exact BF16 values in
    storage (decoded arithmetically in Float64 here, not via the
    engine widening). Filed bound: same envelope as the F16 path --
    BF16 storage rounding is an input property, already inside the
    exact stored values the reference uses."""
    var m = 8
    var k = 1024
    var n = 32
    var well = MimirWell(262144)
    var a = well.allocate(m * k)
    var b = well.allocate(n * k)
    var c = well.allocate(m * n)
    var lcg = _Lcg(0xBF16)
    _fill_f16(lcg, a, m * k)
    var bbits = b.unsafe_bitcast[UInt16]()
    for i in range(n * k):
        # Random BF16 patterns with bounded exponent (values in ~[-2, 2]).
        var sign = UInt16(lcg.next() % 2) << 15
        var exp = UInt16(126 + Int(lcg.next() % 3)) << 7
        var mant = UInt16(lcg.next() % 128)
        bbits.unsafe_store(i, sign | exp | mant)
    var A = RuneTensor[f16](m, k, a, False)
    var B = RuneTensor[f16](n, k, b, False)
    var C = RuneTensor[f16](m, n, c, False)
    gemm_bf16(A, B, C)
    var max_abs: Float64 = 0.0
    var max_rel: Float64 = 0.0
    for row in range(m):
        for col in range(n):
            var refv: Float64 = 0.0
            for inner in range(k):
                var bits = bbits.unsafe_load(col * k + inner)
                # Arithmetic Float64 decode of the BF16 pattern
                # (independent of the engine widening under test).
                var bexp = Int((bits >> 7) & 0xFF)
                var bmant = Int(bits & 0x7F)
                var bv: Float64 = 1.0 + Float64(bmant) / 128.0
                var be = bexp - 127
                while be > 0:
                    bv *= 2.0
                    be -= 1
                while be < 0:
                    bv /= 2.0
                    be += 1
                if (bits >> 15) == 1:
                    bv = -bv
                refv += Float64(a.unsafe_load(row * k + inner).cast[DType.float32]()) * bv
            var got = Float64(c.unsafe_load(row * n + col).cast[DType.float32]())
            var err = got - refv
            if err < 0:
                err = -err
            if err > max_abs:
                max_abs = err
            var mag = refv
            if mag < 0:
                mag = -mag
            if mag >= 1.0 and err / mag > max_rel:
                max_rel = err / mag
    if max_abs > 0.0625 or max_rel > 0.004:
        raise Error("precision.bf16_gemm_f64_reference: bound exceeded")


def test_precision_bf16_widening_exact() raises:
    """bf16_bits_to_f32 over ALL 65536 patterns: for normal patterns
    the widened value must equal the arithmetic Float64 value
    sign * (1 + mant/128) * 2^(exp-127) exactly; zero patterns widen
    to zero; convert_bf16_to_f16 of a BF16-representable-in-F16 value
    is exact."""
    for bits32 in range(65536):
        var bits = UInt16(bits32)
        var exp = Int((bits >> 7) & 0xFF)
        var mant = Int(bits & 0x7F)
        if exp == 0 or exp == 255:
            continue
        var mag: Float64 = 1.0 + Float64(mant) / 128.0
        var e = exp - 127
        while e > 0:
            mag *= 2.0
            e -= 1
        while e < 0:
            mag /= 2.0
            e += 1
        if (bits >> 15) == 1:
            mag = -mag
        var got = Float64(bf16_bits_to_f32(bits))
        if got != mag:
            raise Error("precision.bf16_widening_exact: mismatch")
    if bf16_bits_to_f32(UInt16(0)) != Float32(0.0):
        raise Error("precision.bf16_widening_exact: zero")
    if bf16_bits_to_f32(UInt16(0x8000)) != Float32(0.0):
        raise Error("precision.bf16_widening_exact: negative zero value")
    # BF16 -> F16 at-load conversion: 1.5 and -0.25 are exact in both.
    var well = MimirWell(64)
    var src = well.allocate(2).unsafe_bitcast[UInt16]()
    var dst = well.allocate(2)
    src.unsafe_store(0, UInt16(0x3FC0))
    src.unsafe_store(1, UInt16(0xBE80))
    convert_bf16_to_f16(src, dst, 2)
    if dst.unsafe_load(0) != Float16(1.5) or dst.unsafe_load(1) != Float16(-0.25):
        raise Error("precision.bf16_widening_exact: conversion")


def test_precision_f16_roundtrip_bound() raises:
    """F32 -> F16 -> F32 roundtrip over 200k LCG values in [-4, 4]:
    max relative error must stay within half a F16 ULP (2^-11) --
    the rounding every F16-output path pays exactly once."""
    var lcg = _Lcg(0x047)
    var max_rel: Float64 = 0.0
    for _ in range(200000):
        var v = Float32(lcg.unit() * 8.0 - 4.0)
        if v > Float32(-0.01) and v < Float32(0.01):
            # Subnormal / near-zero band: relative error there is
            # spacing-dominated (filed separately in the bounds doc
            # as an absolute bound); the half-ULP relative bound is
            # a statement about normal-range values.
            continue
        var back = v.cast[f16]().cast[DType.float32]()
        var err = Float64(back - v)
        if err < 0:
            err = -err
        var av = v
        if av < 0:
            av = -av
        var rel = err / Float64(av)
        if rel > max_rel:
            max_rel = rel
    if max_rel > 0.00049:
        raise Error("precision.f16_roundtrip_bound: bound exceeded")


def test_precision_rmsnorm_f32_f64_reference() raises:
    """rmsnorm (F32 internal sumsq/sqrt/scale, F16 in/out) vs Float64
    reference, 4 rows x 257 cols (SIMD body + scalar tail). Filed
    bound: max abs err <= 4e-3, max rel err <= 4e-3 (|ref| >= 0.1)."""
    var rows = 4
    var cols = 257
    var well = MimirWell(65536)
    var t = well.allocate(rows * cols)
    var w = well.allocate(cols)
    var orig = well.allocate(rows * cols)
    var lcg = _Lcg(0xBEEF)
    _fill_f16(lcg, t, rows * cols)
    _fill_f16(lcg, w, cols)
    for i in range(rows * cols):
        orig.unsafe_store(i, t.unsafe_load(i))
    var T = RuneTensor[f16](rows, cols, t, False)
    var W = RuneTensor[f16](1, cols, w, False)
    rmsnorm(T, W)
    var max_abs: Float64 = 0.0
    var max_rel: Float64 = 0.0
    for r in range(rows):
        var ss: Float64 = 0.0
        for cidx in range(cols):
            var x = Float64(orig.unsafe_load(r * cols + cidx).cast[DType.float32]())
            ss += x * x
        var inv = 1.0 / sqrt(ss / Float64(cols) + 0.00001)
        for cidx in range(cols):
            var x = Float64(orig.unsafe_load(r * cols + cidx).cast[DType.float32]())
            var wv = Float64(w.unsafe_load(cidx).cast[DType.float32]())
            var refv = x * inv * wv
            var got = Float64(t.unsafe_load(r * cols + cidx).cast[DType.float32]())
            var err = got - refv
            if err < 0:
                err = -err
            if err > max_abs:
                max_abs = err
            var mag = refv
            if mag < 0:
                mag = -mag
            if mag >= 0.1 and err / mag > max_rel:
                max_rel = err / mag
    if max_abs > 0.004 or max_rel > 0.004:
        raise Error("precision.rmsnorm_f32_f64_reference: bound exceeded")
