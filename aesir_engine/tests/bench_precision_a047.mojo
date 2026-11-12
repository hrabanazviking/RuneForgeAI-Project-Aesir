"""A-047 measurement probe: per-precision error maxima vs Float64.

Standalone (not part of run_all). Prints one line per measurement so
the filed bounds in docs/bench/A047_PRECISION_BOUNDS.md trace to this
log. References are Float64 scalar loops over the exact stored inputs,
computed in this file -- never via the path under test.
"""

from std.math import sqrt

from core.mimir_well import (
    MimirWell,
    RuneTensor,
    bf16_bits_to_f32,
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
        return Float64(self.next() % 9007199254740992) / 9007199254740992.0


def _fill_f16(
    mut lcg: _Lcg, ptr: Pointer[Scalar[f16], MutUntrackedOrigin], n: Int
):
    for i in range(n):
        var v = Float32(lcg.unit() * 2.0 - 1.0)
        ptr.unsafe_store(i, v.cast[f16]())


def _report(name: String, max_abs: Float64, max_rel: Float64):
    print(name, "max_abs=", max_abs, " max_rel=", max_rel)


def main() raises:
    # --- F16 GEMM, K=1024 ---
    var m = 8
    var k = 1024
    var n = 32
    var well = MimirWell(1048576)
    var a = well.allocate(m * k)
    var b = well.allocate(n * k)
    var c = well.allocate(m * n)
    var lcg = _Lcg(0xF16)
    _fill_f16(lcg, a, m * k)
    _fill_f16(lcg, b, n * k)
    var A1 = RuneTensor[f16](m, k, a, False)
    var B1 = RuneTensor[f16](n, k, b, False)
    var C1 = RuneTensor[f16](m, n, c, False)
    gemm_f16_direct(A1, B1, C1)
    var max_abs: Float64 = 0.0
    var max_rel: Float64 = 0.0
    for row in range(m):
        for col in range(n):
            var refv: Float64 = 0.0
            for inner in range(k):
                refv += Float64(a.unsafe_load(row * k + inner).cast[DType.float32]()) * Float64(
                    b.unsafe_load(col * k + inner).cast[DType.float32]()
                )
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
    _report("F16_GEMM_K1024", max_abs, max_rel)

    # --- BF16 GEMM, K=1024 (arithmetic Float64 decode of patterns) ---
    var bbits = b.unsafe_bitcast[UInt16]()
    var lcg2 = _Lcg(0xBF16)
    for i in range(n * k):
        var sign = UInt16(lcg2.next() % 2) << 15
        var exp = UInt16(126 + Int(lcg2.next() % 3)) << 7
        var mant = UInt16(lcg2.next() % 128)
        bbits.unsafe_store(i, sign | exp | mant)
    var A2 = RuneTensor[f16](m, k, a, False)
    var B2 = RuneTensor[f16](n, k, b, False)
    var C2 = RuneTensor[f16](m, n, c, False)
    gemm_bf16(A2, B2, C2)
    max_abs = 0.0
    max_rel = 0.0
    for row in range(m):
        for col in range(n):
            var refv: Float64 = 0.0
            for inner in range(k):
                var bits = bbits.unsafe_load(col * k + inner)
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
    _report("BF16_GEMM_K1024", max_abs, max_rel)

    # --- BF16 widening exhaustive ---
    var mismatches = 0
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
        if Float64(bf16_bits_to_f32(bits)) != mag:
            mismatches += 1
    print("BF16_WIDENING_EXHAUSTIVE mismatches=", mismatches, " of 65280 normals")

    # --- F16 roundtrip, 1M values ---
    var lcg3 = _Lcg(0x047)
    var rt_max: Float64 = 0.0
    for _ in range(1000000):
        var v = Float32(lcg3.unit() * 8.0 - 4.0)
        if v > Float32(-0.01) and v < Float32(0.01):
            continue
        var back = v.cast[f16]().cast[DType.float32]()
        var err = Float64(back - v)
        if err < 0:
            err = -err
        var av = v
        if av < 0:
            av = -av
        var rel = err / Float64(av)
        if rel > rt_max:
            rt_max = rel
    print("F16_ROUNDTRIP_1M max_rel=", rt_max, " half_ulp_bound=0.00048828125")

    # --- RMSNorm F32 internal, 4 x 257 ---
    var rows = 4
    var cols = 257
    var t = well.allocate(rows * cols)
    var w = well.allocate(cols)
    var orig = well.allocate(rows * cols)
    var lcg4 = _Lcg(0xBEEF)
    _fill_f16(lcg4, t, rows * cols)
    _fill_f16(lcg4, w, cols)
    for i in range(rows * cols):
        orig.unsafe_store(i, t.unsafe_load(i))
    var T = RuneTensor[f16](rows, cols, t, False)
    var W = RuneTensor[f16](1, cols, w, False)
    rmsnorm(T, W)
    max_abs = 0.0
    max_rel = 0.0
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
    _report("RMSNORM_F32_4x257", max_abs, max_rel)
    print("PROBE DONE")
