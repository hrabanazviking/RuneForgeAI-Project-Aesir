# C2 verification binary (H021-H040, minus H037 which is the PRÓF suite
# and H040 which is the review document).
#
# Built on Mimir via armvegr/build.sh. Runs every slice's acceptance
# checks with on-device scalar/fp64 references, prints per-slice
# PASS/FAIL lines plus PERF lines for the H038 baseline collection,
# and exits non-zero if any check fails.
#
# Usage: build/c2_verify

from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc
from std.collections import List
from std.ffi import external_call

from armvegr import neon_available, armvegr_version
from armvegr.util import (
    now_ns,
    rng_next,
    rand_range_f16,
    fill_rand_f16,
    max_abs_err_f16,
    sum_f64,
)
from armvegr.gemm import (
    gemm_fp16,
    gemm_micro_8x8,
    gemm_pack_a,
    gemm_pack_b,
)
from armvegr.gemv import gemv_fp16, gemv_bytes
from armvegr.elem import elem_add, elem_mul, elem_scale, elem_axpy
from armvegr.norm import layernorm_fp16
from armvegr.rmsnorm import rmsnorm_fp16
from armvegr.softmax import softmax_fp16, softmax_masked_fp16
from armvegr.act import silu_fp16, gelu_fp16
from armvegr.rope import rope_fp16
from armvegr.quant import (
    fp32_to_fp16,
    fp16_to_q80,
    q80_to_fp16,
    fp16_bits_of,
    fp16_from_bits,
    q80_block_scale,
)
from armvegr.q4 import fp16_to_q40, q40_to_fp16
from armvegr.qgemm import q80_gemm
from armvegr.attn import attn_sdpa_causal_fp16
from armvegr.mha import mha_forward_seq, mha_forward_par
from armvegr.backend import (
    BACKEND_CPU,
    BACKEND_NPU,
    BACKEND_AUTO,
    NpuBackendStub,
    select_backend,
)
from std.math import exp as _exp, sqrt as _sqrt, log as _log, cos as _cos, sin as _sin


def f64_exp(v: Float64) -> Float64:
    return _exp(SIMD[DType.float64, 1](v))[0]


def f64_log(v: Float64) -> Float64:
    return _log(SIMD[DType.float64, 1](v))[0]


def f64_cos(v: Float64) -> Float64:
    return _cos(SIMD[DType.float64, 1](v))[0]


def f64_sin(v: Float64) -> Float64:
    return _sin(SIMD[DType.float64, 1](v))[0]


def f64_sqrt(v: Float64) -> Float64:
    return _sqrt(SIMD[DType.float64, 1](v))[0]


def f32_sqrt(v: Float32) -> Float32:
    return _sqrt(SIMD[DType.float32, 1](v))[0]


struct Ctx:
    var fails: Int
    var state: Pointer[UInt64, MutUntrackedOrigin]
    var stream_gbs: Float64
    var gemv_gbs: Float64

    def __init__(out self):
        self.fails = 0
        self.state = unsafe_alloc[UInt64](1)
        self.state[unsafe_offset=0] = UInt64(0x12345678)
        self.stream_gbs = Float64(0)
        self.gemv_gbs = Float64(0)

    def seed(mut self, s: UInt64):
        self.state[unsafe_offset=0] = s

    def check(mut self, name: String, ok: Bool, detail: String):
        if ok:
            print("PASS", name, detail)
        else:
            print("FAIL", name, detail)
            self.fails += 1


def gemm_scalar_ref(
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    c: Pointer[Float16, MutUntrackedOrigin],
    M: Int,
    N: Int,
    K: Int,
):
    # Scalar fp32-accumulation reference (matches the kernel's numerics
    # class; the H037 oracle compares against an independent fp64 ref).
    for i in range(M):
        for j in range(N):
            var s = Float32(0)
            for k in range(K):
                s += Float32(a[unsafe_offset=i * K + k]) * Float32(
                    b[unsafe_offset=k * N + j]
                )
            c[unsafe_offset=i * N + j] = Float16(s)


def test_h021(mut ctx: Ctx):
    ctx.check("H021", neon_available(), "neon_available()=True on Mimir")
    ctx.check("H021", armvegr_version() == "0.2.0", "version=0.2.0")


def test_h022(mut ctx: Ctx):
    # 100 random 8x8 tiles, kc=32, micro-kernel vs scalar fp32 ref.
    var kc = 32
    var a = unsafe_alloc[Float16](8 * kc)
    var b = unsafe_alloc[Float16](kc * 8)
    var ap = unsafe_alloc[Float16](8 * kc)
    var bp = unsafe_alloc[Float16](8 * kc)
    var acc = unsafe_alloc[Float32](64)
    var expected = unsafe_alloc[Float16](64)
    var worst = Float64(0)
    ctx.seed(UInt64(0x2201))
    for t in range(100):
        fill_rand_f16(a, 8 * kc, ctx.state, -1.0, 1.0)
        fill_rand_f16(b, kc * 8, ctx.state, -1.0, 1.0)
        gemm_pack_a(a, ap, kc, 0, 8, 0, kc)
        gemm_pack_b(b, bp, 8, 0, 8, 0, kc)
        for i in range(64):
            acc[unsafe_offset=i] = Float32(0)
        gemm_micro_8x8(ap, bp, acc, kc, 8)
        for i in range(8):
            for j in range(8):
                var s = Float32(0)
                for k in range(kc):
                    s += Float32(a[unsafe_offset=i * kc + k]) * Float32(
                        b[unsafe_offset=k * 8 + j]
                    )
                expected[unsafe_offset=i * 8 + j] = Float16(s)
        for i in range(64):
            var d = Float64(acc[unsafe_offset=i]) - Float64(expected[unsafe_offset=i])
            if d < 0:
                d = -d
            if d > worst:
                worst = d
    ctx.check("H022", worst <= 1e-3, String("100 tiles maxerr=") + String(worst))


def test_gemm_case(mut ctx: Ctx, M: Int, N: Int, K: Int, tag: String) -> Float64:
    var a = unsafe_alloc[Float16](M * K)
    var b = unsafe_alloc[Float16](K * N)
    var c = unsafe_alloc[Float16](M * N)
    var r = unsafe_alloc[Float16](M * N)
    fill_rand_f16(a, M * K, ctx.state, -1.0, 1.0)
    fill_rand_f16(b, K * N, ctx.state, -1.0, 1.0)
    gemm_fp16(a, b, c, M, N, K)
    gemm_scalar_ref(a, b, r, M, N, K)
    var e = max_abs_err_f16(c, r, M * N)
    ctx.check(
        "H023",
        e <= 1e-3,
        tag + String(" M=") + String(M) + String(" N=") + String(N) + String(" K=")
        + String(K) + String(" maxerr=") + String(e),
    )
    return e


def test_h023(mut ctx: Ctx):
    ctx.seed(UInt64(0x2301))
    test_gemm_case(ctx, 1, 1, 1, "tiny")
    test_gemm_case(ctx, 1, 1, 64, "edge")
    test_gemm_case(ctx, 1, 64, 1, "edge")
    test_gemm_case(ctx, 64, 1, 1, "edge")
    test_gemm_case(ctx, 7, 7, 7, "edge")
    test_gemm_case(ctx, 65, 65, 65, "edge")
    test_gemm_case(ctx, 1, 7, 65, "edge")
    test_gemm_case(ctx, 65, 7, 1, "edge")
    test_gemm_case(ctx, 7, 65, 64, "edge")
    test_gemm_case(ctx, 64, 64, 64, "square")
    test_gemm_case(ctx, 64, 64, 65, "k-edge")
    test_gemm_case(ctx, 65, 64, 64, "m-edge")
    test_gemm_case(ctx, 64, 65, 64, "n-edge")
    test_gemm_case(ctx, 256, 256, 256, "med")
    test_gemm_case(ctx, 256, 64, 256, "med")
    test_gemm_case(ctx, 64, 256, 64, "med")
    test_gemm_case(ctx, 64, 64, 512, "k512")
    test_gemm_case(ctx, 64, 64, 1024, "k1024")
    test_gemm_case(ctx, 64, 64, 2048, "k2048")
    test_gemm_case(ctx, 64, 64, 4096, "k4096")
    test_gemm_case(ctx, 256, 256, 1024, "big")
    test_gemm_case(ctx, 512, 512, 64, "big")
    test_gemm_case(ctx, 1024, 1024, 64, "big")
    test_gemm_case(ctx, 2048, 64, 64, "big")
    test_gemm_case(ctx, 4096, 64, 64, "big")
    test_gemm_case(ctx, 64, 4096, 64, "big")
    test_gemm_case(ctx, 1024, 1024, 1024, "perf1024")
    # Perf: 1024^3, median of 11 runs (H038 methodology; also H023's
    # 2x-H007 bar: 32 GFLOPS).
    var n = 1024
    var a = unsafe_alloc[Float16](n * n)
    var b = unsafe_alloc[Float16](n * n)
    var c = unsafe_alloc[Float16](n * n)
    fill_rand_f16(a, n * n, ctx.state, -1.0, 1.0)
    fill_rand_f16(b, n * n, ctx.state, -1.0, 1.0)
    gemm_fp16(a, b, c, n, n, n)  # warmup
    var dts = unsafe_alloc[Int64](11)
    for r in range(11):
        var t0 = now_ns()
        gemm_fp16(a, b, c, n, n, n)
        dts[unsafe_offset=r] = now_ns() - t0
    for i in range(11):
        for j in range(i + 1, 11):
            if dts[unsafe_offset=j] < dts[unsafe_offset=i]:
                var tmp = dts[unsafe_offset=i]
                dts[unsafe_offset=i] = dts[unsafe_offset=j]
                dts[unsafe_offset=j] = tmp
    var median = dts[unsafe_offset=5]
    var flops = Float64(2) * Float64(n) * Float64(n) * Float64(n)
    var gflops = flops / Float64(median)
    print(
        "PERF gemm_fp16 shape=1024x1024x1024 runs=11 median_ns=",
        median,
        "min_ns=",
        dts[unsafe_offset=0],
        "max_ns=",
        dts[unsafe_offset=10],
        "gflops=",
        gflops,
    )
    # The 2x-H007 bar (32 GFLOPS) is recorded, not hard-failed: the slice
    # criterion explicitly permits a DEVLOG shortfall analysis instead.
    if gflops >= 32.0:
        print("NOTE H023 perf bar MET: gflops=", gflops, ">= 32.0")
    else:
        print("NOTE H023 perf bar MISSED: gflops=", gflops, "< 32.0; see DEVLOG analysis")


def gemv_scalar_ref(
    a: Pointer[Float16, MutUntrackedOrigin],
    x: Pointer[Float16, MutUntrackedOrigin],
    y: Pointer[Float16, MutUntrackedOrigin],
    M: Int,
    N: Int,
):
    for i in range(M):
        var s = Float32(0)
        for k in range(N):
            s += Float32(a[unsafe_offset=i * N + k]) * Float32(x[unsafe_offset=k])
        y[unsafe_offset=i] = Float16(s)


def test_gemv_case(mut ctx: Ctx, M: Int, N: Int):
    var a = unsafe_alloc[Float16](M * N)
    var x = unsafe_alloc[Float16](N)
    var y = unsafe_alloc[Float16](M)
    var r = unsafe_alloc[Float16](M)
    fill_rand_f16(a, M * N, ctx.state, -1.0, 1.0)
    fill_rand_f16(x, N, ctx.state, -1.0, 1.0)
    gemv_fp16(a, x, y, M, N)
    gemv_scalar_ref(a, x, r, M, N)
    var e = max_abs_err_f16(y, r, M)
    ctx.check(
        "H024",
        e <= 1e-3,
        String("M=") + String(M) + String(" N=") + String(N) + String(" maxerr=")
        + String(e),
    )


def stream_bw_gbs() -> Float64:
    # STREAM-like triad microbenchmark (in-slice, documented): c = a + s*b
    # on 64 MiB arrays, median of 11. Returns GiB/s.
    var n = 16 * 1024 * 1024
    var a = unsafe_alloc[Float32](n)
    var b = unsafe_alloc[Float32](n)
    var c = unsafe_alloc[Float32](n)
    for i in range(0, n, 1024):
        a[unsafe_offset=i] = Float32(1)
        b[unsafe_offset=i] = Float16(2)
    var dts = unsafe_alloc[Int64](11)
    for r in range(11):
        var t0 = now_ns()
        for i in range(n):
            c[unsafe_offset=i] = a[unsafe_offset=i] + Float32(2) * b[unsafe_offset=i]
        dts[unsafe_offset=r] = now_ns() - t0
    for i in range(11):
        for j in range(i + 1, 11):
            if dts[unsafe_offset=j] < dts[unsafe_offset=i]:
                var tmp = dts[unsafe_offset=i]
                dts[unsafe_offset=i] = dts[unsafe_offset=j]
                dts[unsafe_offset=j] = tmp
    var median = dts[unsafe_offset=5]
    var bytes = Float64(3 * n * 4)
    return bytes / Float64(median)


def test_h024(mut ctx: Ctx):
    ctx.seed(UInt64(0x2401))
    test_gemv_case(ctx, 128, 128)
    test_gemv_case(ctx, 128, 1024)
    test_gemv_case(ctx, 128, 4096)
    test_gemv_case(ctx, 128, 8192)
    test_gemv_case(ctx, 1024, 128)
    test_gemv_case(ctx, 1024, 1024)
    test_gemv_case(ctx, 1024, 4096)
    test_gemv_case(ctx, 1024, 8192)
    test_gemv_case(ctx, 4096, 128)
    test_gemv_case(ctx, 4096, 1024)
    test_gemv_case(ctx, 4096, 4096)
    test_gemv_case(ctx, 4096, 8192)
    test_gemv_case(ctx, 8192, 128)
    test_gemv_case(ctx, 8192, 1024)
    test_gemv_case(ctx, 8192, 4096)
    test_gemv_case(ctx, 8192, 8192)
    var stream = stream_bw_gbs()
    ctx.stream_gbs = stream
    print("PERF stream_triad_gbs median_of_11 =", stream)
    # GEMV bandwidth on 8192x8192, median of 11.
    var M = 8192
    var N = 8192
    var a = unsafe_alloc[Float16](M * N)
    var x = unsafe_alloc[Float16](N)
    var y = unsafe_alloc[Float16](M)
    fill_rand_f16(a, M * N, ctx.state, -1.0, 1.0)
    fill_rand_f16(x, N, ctx.state, -1.0, 1.0)
    gemv_fp16(a, x, y, M, N)
    var dts = unsafe_alloc[Int64](11)
    for r in range(11):
        var t0 = now_ns()
        gemv_fp16(a, x, y, M, N)
        dts[unsafe_offset=r] = now_ns() - t0
    for i in range(11):
        for j in range(i + 1, 11):
            if dts[unsafe_offset=j] < dts[unsafe_offset=i]:
                var tmp = dts[unsafe_offset=i]
                dts[unsafe_offset=i] = dts[unsafe_offset=j]
                dts[unsafe_offset=j] = tmp
    var median = dts[unsafe_offset=5]
    var bw = Float64(gemv_bytes(M, N)) / Float64(median)
    ctx.gemv_gbs = bw
    var pct = Float64(100) * bw / stream
    print("PERF gemv_fp16 shape=8192x8192 median_ns=", median, "gbs=", bw)
    print("PERF gemv_stream_pct =", pct)
    ctx.check(
        "H024",
        pct >= 60.0,
        String("gemv_bw_pct_of_stream=") + String(pct) + " bar=60",
    )


def test_elem_case(mut ctx: Ctx, n: Int):
    var a = unsafe_alloc[Float16](n)
    var b = unsafe_alloc[Float16](n)
    var c = unsafe_alloc[Float16](n)
    var r = unsafe_alloc[Float16](n)
    fill_rand_f16(a, n, ctx.state, -2.0, 2.0)
    fill_rand_f16(b, n, ctx.state, -2.0, 2.0)
    var alpha = Float16(0.75)
    # add
    elem_add(a, b, c, n)
    for i in range(n):
        r[unsafe_offset=i] = a[unsafe_offset=i] + b[unsafe_offset=i]
    var e = max_abs_err_f16(c, r, n)
    ctx.check("H025", e <= 1e-4, String("add n=") + String(n) + String(" maxerr=") + String(e))
    # mul
    elem_mul(a, b, c, n)
    for i in range(n):
        r[unsafe_offset=i] = a[unsafe_offset=i] * b[unsafe_offset=i]
    e = max_abs_err_f16(c, r, n)
    ctx.check("H025", e <= 1e-4, String("mul n=") + String(n) + String(" maxerr=") + String(e))
    # scale
    elem_scale(a, c, alpha, n)
    for i in range(n):
        r[unsafe_offset=i] = a[unsafe_offset=i] * alpha
    e = max_abs_err_f16(c, r, n)
    ctx.check("H025", e <= 1e-4, String("scale n=") + String(n) + String(" maxerr=") + String(e))
    # axpy
    elem_axpy(a, b, c, alpha, n)
    for i in range(n):
        r[unsafe_offset=i] = a[unsafe_offset=i] * alpha + b[unsafe_offset=i]
    e = max_abs_err_f16(c, r, n)
    ctx.check("H025", e <= 1e-4, String("axpy n=") + String(n) + String(" maxerr=") + String(e))


def test_h025(mut ctx: Ctx):
    ctx.seed(UInt64(0x2501))
    test_elem_case(ctx, 1)
    test_elem_case(ctx, 3)
    test_elem_case(ctx, 16)
    test_elem_case(ctx, 1000)
    test_elem_case(ctx, 1000000)


def test_norm_case(mut ctx: Ctx, n: Int, eps: Float32, tag: String):
    var x = unsafe_alloc[Float16](n)
    var w = unsafe_alloc[Float16](n)
    var b = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    var r = unsafe_alloc[Float16](n)
    fill_rand_f16(x, n, ctx.state, -3.0, 3.0)
    fill_rand_f16(w, n, ctx.state, 0.5, 1.5)
    fill_rand_f16(b, n, ctx.state, -1.0, 1.0)
    layernorm_fp16(x, w, b, y, n, eps)
    # fp64 reference
    var mean = Float64(0)
    for i in range(n):
        mean += Float64(x[unsafe_offset=i])
    mean /= Float64(n)
    var var_ = Float64(0)
    for i in range(n):
        var d = Float64(x[unsafe_offset=i]) - mean
        var_ += d * d
    var_ /= Float64(n)
    var inv = 1.0 / f64_sqrt(var_ + Float64(eps))
    for i in range(n):
        var yn = (Float64(x[unsafe_offset=i]) - mean) * inv * Float64(
            w[unsafe_offset=i]
        ) + Float64(b[unsafe_offset=i])
        r[unsafe_offset=i] = Float16(yn)
    var e = max_abs_err_f16(y, r, n)
    ctx.check(
        "H026",
        e <= 1e-3,
        tag + String(" n=") + String(n) + String(" maxerr=") + String(e),
    )


def test_h026(mut ctx: Ctx):
    ctx.seed(UInt64(0x2601))
    for t in range(50):
        var n = 128
        if t % 4 == 1:
            n = 1024
        elif t % 4 == 2:
            n = 4096
        elif t % 4 == 3:
            n = 8192
        var eps = Float32(1e-5)
        if t % 2 == 1:
            eps = Float32(1e-6)
        test_norm_case(ctx, n, eps, String("rand") + String(t))
    # zero-variance (constant) input: must be finite, not NaN.
    var n = 1024
    var x = unsafe_alloc[Float16](n)
    var w = unsafe_alloc[Float16](n)
    var b = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    for i in range(n):
        x[unsafe_offset=i] = Float16(2.5)
        w[unsafe_offset=i] = Float16(1)
        b[unsafe_offset=i] = Float16(0)
    layernorm_fp16(x, w, b, y, n, Float32(1e-5))
    var finite = True
    for i in range(n):
        var v = y[unsafe_offset=i]
        if v != v:
            finite = False  # NaN check
    ctx.check("H026", finite, "constant-input finite (no NaN)")


def test_rmsnorm_case(mut ctx: Ctx, n: Int, tag: String, with_w: Bool):
    var x = unsafe_alloc[Float16](n)
    var w = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    var r = unsafe_alloc[Float16](n)
    fill_rand_f16(x, n, ctx.state, -3.0, 3.0)
    fill_rand_f16(w, n, ctx.state, 0.5, 1.5)
    if not with_w:
        for i in range(n):
            w[unsafe_offset=i] = Float16(1)
    rmsnorm_fp16(x, w, y, n, Float32(1e-6))
    var ms = Float64(0)
    for i in range(n):
        var v = Float64(x[unsafe_offset=i])
        ms += v * v
    ms /= Float64(n)
    var inv = 1.0 / f64_sqrt(ms + 1e-6)
    for i in range(n):
        r[unsafe_offset=i] = Float16(
            Float64(x[unsafe_offset=i]) * inv * Float64(w[unsafe_offset=i])
        )
    var e = max_abs_err_f16(y, r, n)
    ctx.check(
        "H027",
        e <= 1e-3,
        tag + String(" n=") + String(n) + String(" maxerr=") + String(e),
    )


def test_h027(mut ctx: Ctx):
    ctx.seed(UInt64(0x2701))
    for t in range(50):
        var n = 128
        if t % 4 == 1:
            n = 1024
        elif t % 4 == 2:
            n = 4096
        elif t % 4 == 3:
            n = 8192
        test_rmsnorm_case(ctx, n, String("rand") + String(t), t % 2 == 0)
    # RMSNorm != Layernorm on the same input (copy-paste guard).
    var n = 64
    var x = unsafe_alloc[Float16](n)
    var w = unsafe_alloc[Float16](n)
    var b = unsafe_alloc[Float16](n)
    var y1 = unsafe_alloc[Float16](n)
    var y2 = unsafe_alloc[Float16](n)
    for i in range(n):
        x[unsafe_offset=i] = Float16(Float32(i) / Float32(8))
        w[unsafe_offset=i] = Float16(1)
        b[unsafe_offset=i] = Float16(0)
    layernorm_fp16(x, w, b, y1, n, Float32(1e-5))
    rmsnorm_fp16(x, w, y2, n, Float32(1e-5))
    var diff = max_abs_err_f16(y1, y2, n)
    ctx.check("H027", diff > 1e-2, String("rmsnorm!=layernorm diff=") + String(diff))


def test_softmax_case(mut ctx: Ctx, n: Int, lo: Float64, hi: Float64, tag: String):
    var x = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    fill_rand_f16(x, n, ctx.state, lo, hi)
    softmax_fp16(x, y, n)
    # fp64 reference
    var m = Float64(x[unsafe_offset=0])
    for i in range(n):
        var v = Float64(x[unsafe_offset=i])
        if v > m:
            m = v
    var s = 0.0
    for i in range(n):
        s += f64_exp(Float64(x[unsafe_offset=i]) - m)
    var worst = Float64(0)
    var total = Float64(0)
    var ok = True
    for i in range(n):
        var expected = f64_exp(Float64(x[unsafe_offset=i]) - m) / s
        var got = Float64(y[unsafe_offset=i])
        total += got
        var d = got - expected
        if d < 0:
            d = -d
        if d > worst:
            worst = d
        # NaN or Inf: fp16 outputs are finite within +-65504
        if got != got or got > Float64(65504) or got < Float64(-65504):
            ok = False
    var sum_ok = total > Float64(1) - 1e-3 and total < Float64(1) + 1e-3
    ctx.check(
        "H028",
        worst <= 1e-3 and ok and sum_ok,
        tag + String(" n=") + String(n) + String(" maxerr=") + String(worst)
        + String(" sum=") + String(total),
    )


def test_h028(mut ctx: Ctx):
    ctx.seed(UInt64(0x2801))
    test_softmax_case(ctx, 128, -100.0, 100.0, "extreme")
    test_softmax_case(ctx, 1024, -100.0, 100.0, "extreme")
    test_softmax_case(ctx, 32768, -100.0, 100.0, "extreme")
    test_softmax_case(ctx, 1024, -3.0, 3.0, "normal")
    # causal-masked variant
    var n = 256
    var x = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    fill_rand_f16(x, n, ctx.state, -5.0, 5.0)
    var valid = 100
    softmax_masked_fp16(x, y, n, valid)
    var total = Float64(0)
    var masked_zero = True
    for i in range(n):
        var v = Float64(y[unsafe_offset=i])
        total += v
        if i >= valid and v != Float64(0):
            masked_zero = False
    var sum_ok = total > Float64(1) - 1e-3 and total < Float64(1) + 1e-3
    ctx.check(
        "H028",
        masked_zero and sum_ok,
        String("masked sum=") + String(total) + String(" masked_zero=") + String(masked_zero),
    )


def test_h029(mut ctx: Ctx):
    ctx.seed(UInt64(0x2901))
    var n = 10000
    var x = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    fill_rand_f16(x, n, ctx.state, -10.0, 10.0)
    # SiLU vs fp64
    silu_fp16(x, y, n)
    var worst = Float64(0)
    for i in range(n):
        var v = Float64(x[unsafe_offset=i])
        var expected = v / (1.0 + f64_exp(-v))
        var d = Float64(y[unsafe_offset=i]) - expected
        if d < 0:
            d = -d
        if d > worst:
            worst = d
    ctx.check("H029", worst <= 2e-3, String("silu maxerr=") + String(worst))
    # GELU (tanh approx) vs fp64
    gelu_fp16(x, y, n)
    worst = Float64(0)
    for i in range(n):
        var v = Float64(x[unsafe_offset=i])
        var inner = 0.7978845608028654 * (v + 0.044715 * v * v * v)
        var t = f64_exp(2.0 * inner)
        t = (t - 1.0) / (t + 1.0)
        var expected = 0.5 * v * (1.0 + t)
        var d = Float64(y[unsafe_offset=i]) - expected
        if d < 0:
            d = -d
        if d > worst:
            worst = d
    ctx.check("H029", worst <= 2e-3, String("gelu maxerr=") + String(worst))
    # Monotonicity, RE-SCOPED (see audit): non-decreasing on [0, 10].
    var m = 2001
    var xs = unsafe_alloc[Float16](m)
    var ys = unsafe_alloc[Float16](m)
    for i in range(m):
        xs[unsafe_offset=i] = Float16(Float32(i) * Float32(0.01) - Float32(10))
    silu_fp16(xs, ys, m)
    var nondecr = True
    for i in range(1000, m - 1):
        if Float32(ys[unsafe_offset=i + 1]) < Float32(ys[unsafe_offset=i]):
            nondecr = False
    ctx.check("H029", nondecr, "silu non-decreasing on [0,10] @0.01")
    # Dip check: minimum over [-10, 10] at x in [-1.30, -1.25], value in [-0.29, -0.27].
    var minv = Float32(ys[unsafe_offset=0])
    var minx = Float32(-10)
    for i in range(m):
        var v = Float32(ys[unsafe_offset=i])
        if v < minv:
            minv = v
            minx = Float32(i) * Float32(0.01) - Float32(10)
    var dip_ok = minx > Float32(-1.30) and minx < Float32(-1.25) and minv > Float32(
        -0.29
    ) and minv < Float32(-0.27)
    ctx.check(
        "H029",
        dip_ok,
        String("silu dip x=") + String(minx) + String(" v=") + String(minv),
    )


def test_rope_case(mut ctx: Ctx, hd: Int, theta: Float32, pos: Int):
    var x = unsafe_alloc[Float16](hd)
    var y = unsafe_alloc[Float16](hd)
    fill_rand_f16(x, hd, ctx.state, -2.0, 2.0)
    rope_fp16(x, y, hd, pos, theta)
    var worst = Float64(0)
    for i in range(hd // 2):
        var ang = Float64(pos) * f64_exp(
            Float64(-2 * i) / Float64(hd) * f64_log(Float64(theta))
        )
        var x0 = Float64(x[unsafe_offset=2 * i])
        var x1 = Float64(x[unsafe_offset=2 * i + 1])
        var r0 = x0 * f64_cos(ang) - x1 * f64_sin(ang)
        var r1 = x0 * f64_sin(ang) + x1 * f64_cos(ang)
        var d0 = Float64(y[unsafe_offset=2 * i]) - r0
        var d1 = Float64(y[unsafe_offset=2 * i + 1]) - r1
        if d0 < 0:
            d0 = -d0
        if d1 < 0:
            d1 = -d1
        if d0 > worst:
            worst = d0
        if d1 > worst:
            worst = d1
    ctx.check(
        "H030",
        worst <= 1e-3,
        String("hd=") + String(hd) + String(" pos=") + String(pos) + String(" maxerr=")
        + String(worst),
    )


def test_h030(mut ctx: Ctx):
    ctx.seed(UInt64(0x3001))
    test_rope_case(ctx, 64, Float32(10000), 0)
    test_rope_case(ctx, 128, Float32(10000), 0)
    test_rope_case(ctx, 64, Float32(500000), 0)
    test_rope_case(ctx, 128, Float32(500000), 0)
    test_rope_case(ctx, 64, Float32(10000), 1)
    test_rope_case(ctx, 128, Float32(10000), 1)
    test_rope_case(ctx, 64, Float32(500000), 1)
    test_rope_case(ctx, 128, Float32(500000), 1)
    test_rope_case(ctx, 64, Float32(10000), 100)
    test_rope_case(ctx, 128, Float32(10000), 100)
    test_rope_case(ctx, 64, Float32(500000), 100)
    test_rope_case(ctx, 128, Float32(500000), 100)
    test_rope_case(ctx, 64, Float32(10000), 4095)
    test_rope_case(ctx, 128, Float32(10000), 4095)
    test_rope_case(ctx, 64, Float32(500000), 4095)
    test_rope_case(ctx, 128, Float32(500000), 4095)
    # position 0 = identity
    var hd = 128
    var x = unsafe_alloc[Float16](hd)
    var y = unsafe_alloc[Float16](hd)
    fill_rand_f16(x, hd, ctx.state, -2.0, 2.0)
    rope_fp16(x, y, hd, 0, Float32(10000))
    var e = max_abs_err_f16(x, y, hd)
    ctx.check("H030", e == 0.0, String("pos0 identity maxerr=") + String(e))


def test_h031(mut ctx: Ctx):
    ctx.seed(UInt64(0x3101))
    # fp16_bits_of / fp16_from_bits sanity (exact for normals).
    ctx.check("H031", fp16_from_bits(fp16_bits_of(Float32(1.0))) == Float32(1.0), "bits roundtrip 1.0")
    ctx.check("H031", fp16_from_bits(fp16_bits_of(Float32(-2.5))) == Float32(-2.5), "bits roundtrip -2.5")
    ctx.check(
        "H031",
        fp16_bits_of(Float32(0.0009765625)) == UInt16(0x0400),
        "bits 0x0400",
    )
    # fp32 -> fp16 cast.
    var n = 10000
    var f32 = unsafe_alloc[Float32](n)
    var f16 = unsafe_alloc[Float16](n)
    for i in range(n):
        var w = rng_next(ctx.state)
        f32[unsafe_offset=i] = Float32(-6) + Float32(w % UInt64(1000000)) / Float32(1000000) * Float32(12)
    fp32_to_fp16(f32, f16, n)
    var worst = Float64(0)
    for i in range(n):
        var expected = Float16(f32[unsafe_offset=i])
        var d = Float64(f16[unsafe_offset=i]) - Float64(expected)
        if d < 0:
            d = -d
        if d > worst:
            worst = d
    ctx.check("H031", worst == 0.0, String("fp32->fp16 maxerr=") + String(worst))
    # Q8_0 round-trip on uniform[-6, 6]: contract max <= 0.024, RMS <= 0.014
    # (SÓLRÚN re-scope; derivation in quant.mojo header).
    var x = unsafe_alloc[Float16](n)
    var q = unsafe_alloc[Int8]((n // 32) * 34)
    var y = unsafe_alloc[Float16](n)
    fill_rand_f16(x, n, ctx.state, -6.0, 6.0)
    fp16_to_q80(x, q, n)
    q80_to_fp16(q, y, n)
    worst = Float64(0)
    var ss = Float64(0)
    for i in range(n):
        var d = Float64(y[unsafe_offset=i]) - Float64(x[unsafe_offset=i])
        ss += d * d
        if d < 0:
            d = -d
        if d > worst:
            worst = d
    var rms = f64_sqrt(ss / Float64(n))
    ctx.check(
        "H031",
        worst <= 0.024 and rms <= 0.014,
        String("q80 roundtrip max=") + String(worst) + String(" rms=") + String(rms),
    )


def test_h032(mut ctx: Ctx):
    ctx.seed(UInt64(0x3201))
    var n = 10000
    var x = unsafe_alloc[Float16](n)
    var q = unsafe_alloc[Int8]((n // 32) * 18)
    var y = unsafe_alloc[Float16](n)
    fill_rand_f16(x, n, ctx.state, -6.0, 6.0)
    fp16_to_q40(x, q, n)
    q40_to_fp16(q, y, n)
    var worst = Float64(0)
    var ss = Float64(0)
    for i in range(n):
        var d = Float64(y[unsafe_offset=i]) - Float64(x[unsafe_offset=i])
        ss += d * d
        if d < 0:
            d = -d
        if d > worst:
            worst = d
    var rms = f64_sqrt(ss / Float64(n))
    ctx.check(
        "H032",
        worst <= 0.43 and rms <= 0.25,
        String("q40 roundtrip max=") + String(worst) + String(" rms=") + String(rms),
    )
    # Nibble hand-check (H032 acceptance): block with amax = 7 -> scale 1.0;
    # x[0] = 3 -> q = 3, x[1] = -2 -> q = -2 (rest 0).
    # First byte must be 0xE3 (low nibble first: 0x3 | 0xE0).
    var xb = unsafe_alloc[Float16](32)
    var qb = unsafe_alloc[Int8](18)
    for i in range(32):
        xb[unsafe_offset=i] = Float16(0)
    xb[unsafe_offset=0] = Float16(3)
    xb[unsafe_offset=1] = Float16(-2)
    xb[unsafe_offset=2] = Float16(7)
    fp16_to_q40(xb, qb, 32)
    var first = UInt8(qb[unsafe_offset=2])
    ctx.check("H032", first == UInt8(0xE3), String("nibble byte0=") + String(Int(first)))


def q80_gemm_fp32_ref(
    aq: Pointer[Int8, MutUntrackedOrigin],
    bq: Pointer[Int8, MutUntrackedOrigin],
    r: Pointer[Float32, MutUntrackedOrigin],
    M: Int,
    N: Int,
    K: Int,
):
    # Reference: dequantize both sides (fp32), then scalar fp32 GEMM.
    var nb = K // 32
    var ad = unsafe_alloc[Float32](M * K)
    var bd = unsafe_alloc[Float32](K * N)
    for i in range(M):
        for kb in range(nb):
            var bo = (i * nb + kb) * 34
            var s = q80_block_scale(aq, bo)
            for t in range(32):
                ad[unsafe_offset=i * K + kb * 32 + t] = Float32(
                    Int(aq[unsafe_offset=bo + 2 + t])
                ) * s
    for j in range(N):
        for kb in range(nb):
            var bo = (j * nb + kb) * 34
            var s = q80_block_scale(bq, bo)
            for t in range(32):
                bd[unsafe_offset=(kb * 32 + t) * N + j] = Float32(
                    Int(bq[unsafe_offset=bo + 2 + t])
                ) * s
    for i in range(M):
        for j in range(N):
            var s = Float32(0)
            for k in range(K):
                s += ad[unsafe_offset=i * K + k] * bd[unsafe_offset=k * N + j]
            r[unsafe_offset=i * N + j] = s


def test_q80_gemm_case(mut ctx: Ctx, M: Int, N: Int, K: Int):
    var nb = K // 32
    var a = unsafe_alloc[Float16](M * K)
    var b = unsafe_alloc[Float16](K * N)
    var aq = unsafe_alloc[Int8](M * nb * 34)
    var bq = unsafe_alloc[Int8](N * nb * 34)
    var c = unsafe_alloc[Float32](M * N)
    var r = unsafe_alloc[Float32](M * N)
    fill_rand_f16(a, M * K, ctx.state, -1.0, 1.0)
    # bq is N x K (K-major rows); fill a K x N fp16 then transpose-quantize.
    fill_rand_f16(b, K * N, ctx.state, -1.0, 1.0)
    fp16_to_q80(a, aq, M * K)
    var bt = unsafe_alloc[Float16](N * K)
    for j in range(N):
        for k in range(K):
            bt[unsafe_offset=j * K + k] = b[unsafe_offset=k * N + j]
    fp16_to_q80(bt, bq, N * K)
    q80_gemm(aq, bq, c, M, N, K)
    q80_gemm_fp32_ref(aq, bq, r, M, N, K)
    # Error contract (documented): max|q - r| <= 0.05 * rms(r).
    var ss = Float64(0)
    var worst = Float64(0)
    for i in range(M * N):
        var d = Float64(c[unsafe_offset=i]) - Float64(r[unsafe_offset=i])
        ss += Float64(r[unsafe_offset=i]) * Float64(r[unsafe_offset=i])
        if d < 0:
            d = -d
        if d > worst:
            worst = d
    var rms = f64_sqrt(ss / Float64(M * N))
    var bound = Float64(0.05) * rms
    ctx.check(
        "H033",
        worst <= bound,
        String("M=") + String(M) + String(" N=") + String(N) + String(" K=") + String(K)
        + String(" maxerr=") + String(worst) + String(" bound=0.05*rms=") + String(bound),
    )


def test_h033(mut ctx: Ctx):
    ctx.seed(UInt64(0x3301))
    test_q80_gemm_case(ctx, 1, 128, 128)
    test_q80_gemm_case(ctx, 1, 1024, 128)
    test_q80_gemm_case(ctx, 1, 4096, 128)
    test_q80_gemm_case(ctx, 1, 128, 1024)
    test_q80_gemm_case(ctx, 1, 1024, 1024)
    test_q80_gemm_case(ctx, 1, 4096, 1024)
    test_q80_gemm_case(ctx, 8, 128, 128)
    test_q80_gemm_case(ctx, 8, 1024, 128)
    test_q80_gemm_case(ctx, 8, 4096, 128)
    test_q80_gemm_case(ctx, 8, 128, 1024)
    test_q80_gemm_case(ctx, 8, 1024, 1024)
    test_q80_gemm_case(ctx, 8, 4096, 1024)
    test_q80_gemm_case(ctx, 64, 128, 128)
    test_q80_gemm_case(ctx, 64, 1024, 128)
    test_q80_gemm_case(ctx, 64, 4096, 128)
    test_q80_gemm_case(ctx, 64, 128, 1024)
    test_q80_gemm_case(ctx, 64, 1024, 1024)
    test_q80_gemm_case(ctx, 64, 4096, 1024)
    test_q80_gemm_case(ctx, 1, 128, 4096)
    test_q80_gemm_case(ctx, 8, 4096, 4096)
    # M=1 decode-case bandwidth vs H024 GEMV efficiency.
    var K = 4096
    var N = 4096
    var nb = K // 32
    var a = unsafe_alloc[Float16](K)
    var b = unsafe_alloc[Float16](K * N)
    var aq = unsafe_alloc[Int8](nb * 34)
    var bq = unsafe_alloc[Int8](N * nb * 34)
    var c = unsafe_alloc[Float32](N)
    fill_rand_f16(a, K, ctx.state, -1.0, 1.0)
    fill_rand_f16(b, K * N, ctx.state, -1.0, 1.0)
    fp16_to_q80(a, aq, K)
    var bt = unsafe_alloc[Float16](N * K)
    for j in range(N):
        for k in range(K):
            bt[unsafe_offset=j * K + k] = b[unsafe_offset=k * N + j]
    fp16_to_q80(bt, bq, N * K)
    q80_gemm(aq, bq, c, 1, N, K)
    var dts = unsafe_alloc[Int64](11)
    for r in range(11):
        var t0 = now_ns()
        q80_gemm(aq, bq, c, 1, N, K)
        dts[unsafe_offset=r] = now_ns() - t0
    for i in range(11):
        for j in range(i + 1, 11):
            if dts[unsafe_offset=j] < dts[unsafe_offset=i]:
                var tmp = dts[unsafe_offset=i]
                dts[unsafe_offset=i] = dts[unsafe_offset=j]
                dts[unsafe_offset=j] = tmp
    var median = dts[unsafe_offset=5]
    var bytes = Float64((1 + N) * nb * 34)
    var bw = bytes / Float64(median)
    print("PERF q80_gemm M=1 K=4096 N=4096 median_ns=", median, "gbs=", bw)
    print("PERF gemv_gbs_ref =", ctx.gemv_gbs)
    ctx.check(
        "H033",
        bw >= Float64(0.5) * ctx.gemv_gbs,
        String("q80gemv_bw=") + String(bw) + String(" vs 0.5*gemv=") + String(Float64(0.5) * ctx.gemv_gbs),
    )


def test_attn_case(mut ctx: Ctx, seq: Int, hd: Int):
    var q = unsafe_alloc[Float16](seq * hd)
    var k = unsafe_alloc[Float16](seq * hd)
    var v = unsafe_alloc[Float16](seq * hd)
    var o = unsafe_alloc[Float16](seq * hd)
    fill_rand_f16(q, seq * hd, ctx.state, -1.0, 1.0)
    fill_rand_f16(k, seq * hd, ctx.state, -1.0, 1.0)
    fill_rand_f16(v, seq * hd, ctx.state, -1.0, 1.0)
    var peak = attn_sdpa_causal_fp16(q, k, v, o, seq, hd)
    # Unfused fp64 reference.
    var inv_s = 1.0 / f64_sqrt(Float64(hd))
    var worst = Float64(0)
    for i in range(seq):
        var m = -1e30
        for j in range(i + 1):
            var s = 0.0
            for d in range(hd):
                s += Float64(q[unsafe_offset=i * hd + d]) * Float64(
                    k[unsafe_offset=j * hd + d]
                )
            s *= inv_s
            if s > m:
                m = s
        var esum = 0.0
        for j in range(i + 1):
            var s = 0.0
            for d in range(hd):
                s += Float64(q[unsafe_offset=i * hd + d]) * Float64(
                    k[unsafe_offset=j * hd + d]
                )
            esum += f64_exp(s * inv_s - m)
        for d in range(hd):
            var acc = 0.0
            for j in range(i + 1):
                var s = 0.0
                for dd in range(hd):
                    s += Float64(q[unsafe_offset=i * hd + dd]) * Float64(
                        k[unsafe_offset=j * hd + dd]
                    )
                acc += f64_exp(s * inv_s - m) / esum * Float64(
                    v[unsafe_offset=j * hd + d]
                )
            var expected = acc
            var got = Float64(o[unsafe_offset=i * hd + d])
            var dd = got - expected
            if dd < 0:
                dd = -dd
            if dd > worst:
                worst = dd
    ctx.check(
        "H034",
        worst <= 2e-3,
        String("seq=") + String(seq) + String(" hd=") + String(hd) + String(" maxerr=")
        + String(worst) + String(" peak_bytes=") + String(peak),
    )
    if seq == 1024:
        # Never O(n^2): peak must be far below the n^2 fp32 score matrix.
        ctx.check(
            "H034",
            peak < Int64(seq * seq),
            String("peak=") + String(peak) + String(" < n^2=") + String(seq * seq),
        )


def test_h034(mut ctx: Ctx):
    ctx.seed(UInt64(0x3401))
    test_attn_case(ctx, 16, 64)
    test_attn_case(ctx, 16, 128)
    test_attn_case(ctx, 128, 64)
    test_attn_case(ctx, 128, 128)
    test_attn_case(ctx, 1024, 64)
    test_attn_case(ctx, 1024, 128)
    # Causal bit-identical: row i with seq_len=i+1 vs seq_len=2048.
    var hd = 64
    var big = 2048
    var q = unsafe_alloc[Float16](big * hd)
    var k = unsafe_alloc[Float16](big * hd)
    var v = unsafe_alloc[Float16](big * hd)
    var o_big = unsafe_alloc[Float16](big * hd)
    fill_rand_f16(q, big * hd, ctx.state, -1.0, 1.0)
    fill_rand_f16(k, big * hd, ctx.state, -1.0, 1.0)
    fill_rand_f16(v, big * hd, ctx.state, -1.0, 1.0)
    _ = attn_sdpa_causal_fp16(q, k, v, o_big, big, hd)
    var identical = True
    for t in range(3):
        var i = 0
        if t == 1:
            i = 5
        if t == 2:
            i = 100
        var ln = i + 1
        var o_small = unsafe_alloc[Float16](ln * hd)
        _ = attn_sdpa_causal_fp16(q, k, v, o_small, ln, hd)
        for d in range(hd):
            if o_small[unsafe_offset=i * hd + d] != o_big.unsafe_offset(i * hd + d):
                identical = False
    ctx.check("H034", identical, "causal rows bit-identical (seq i+1 vs 2048)")


def mha_naive_ref(
    x: Pointer[Float16, MutUntrackedOrigin],
    wq: Pointer[Float16, MutUntrackedOrigin],
    wk: Pointer[Float16, MutUntrackedOrigin],
    wv: Pointer[Float16, MutUntrackedOrigin],
    wo: Pointer[Float16, MutUntrackedOrigin],
    outp: Pointer[Float16, MutUntrackedOrigin],
    seq: Int,
    n_heads: Int,
    head_dim: Int,
    theta: Float32,
):
    # Fully scalar fp64 reference: projections, RoPE, per-head unfused
    # causal attention, output projection.
    var dm = n_heads * head_dim
    var q = unsafe_alloc[Float64](seq * dm)
    var k = unsafe_alloc[Float64](seq * dm)
    var vv = unsafe_alloc[Float64](seq * dm)
    for s in range(seq):
        for d in range(dm):
            var sq = 0.0
            var sk = 0.0
            var sv = 0.0
            for e in range(dm):
                var xe = Float64(x[unsafe_offset=s * dm + e])
                sq += xe * Float64(wq[unsafe_offset=e * dm + d])
                sk += xe * Float64(wk[unsafe_offset=e * dm + d])
                sv += xe * Float64(wv[unsafe_offset=e * dm + d])
            q[unsafe_offset=s * dm + d] = sq
            k[unsafe_offset=s * dm + d] = sk
            vv[unsafe_offset=s * dm + d] = sv
    var ln_t = f64_log(Float64(theta))
    var inv_s = 1.0 / f64_sqrt(Float64(head_dim))
    var ctx = unsafe_alloc[Float64](seq * dm)
    for h in range(n_heads):
        for i in range(seq):
            # RoPE'd q_i, k_j on the fly; scores; softmax; weighted v.
            var m = -1e30
            for j in range(i + 1):
                var s = 0.0
                for p in range(head_dim // 2):
                    var ang_i = Float64(i) * f64_exp(
                        Float64(-2 * p) / Float64(head_dim) * ln_t
                    )
                    var ang_j = Float64(j) * f64_exp(
                        Float64(-2 * p) / Float64(head_dim) * ln_t
                    )
                    var qi0 = q[unsafe_offset=i * dm + h * head_dim + 2 * p]
                    var qi1 = q[unsafe_offset=i * dm + h * head_dim + 2 * p + 1]
                    var kj0 = k[unsafe_offset=j * dm + h * head_dim + 2 * p]
                    var kj1 = k[unsafe_offset=j * dm + h * head_dim + 2 * p + 1]
                    var rqi0 = qi0 * f64_cos(ang_i) - qi1 * f64_sin(ang_i)
                    var rkj0 = kj0 * f64_cos(ang_j) - kj1 * f64_sin(ang_j)
                    var rkj1 = kj0 * f64_sin(ang_j) + kj1 * f64_cos(ang_j)
                    # q rotated too (full rotation on q side)
                    var rqi1 = qi0 * f64_sin(ang_i) + qi1 * f64_cos(ang_i)
                    s += rqi0 * rkj0 + rqi1 * rkj1
                s *= inv_s
                if s > m:
                    m = s
            var esum = 0.0
            for j in range(i + 1):
                var s = 0.0
                for p in range(head_dim // 2):
                    var ang_i = Float64(i) * f64_exp(
                        Float64(-2 * p) / Float64(head_dim) * ln_t
                    )
                    var ang_j = Float64(j) * f64_exp(
                        Float64(-2 * p) / Float64(head_dim) * ln_t
                    )
                    var qi0 = q[unsafe_offset=i * dm + h * head_dim + 2 * p]
                    var qi1 = q[unsafe_offset=i * dm + h * head_dim + 2 * p + 1]
                    var kj0 = k[unsafe_offset=j * dm + h * head_dim + 2 * p]
                    var kj1 = k[unsafe_offset=j * dm + h * head_dim + 2 * p + 1]
                    var rqi0 = qi0 * f64_cos(ang_i) - qi1 * f64_sin(ang_i)
                    var rqi1 = qi0 * f64_sin(ang_i) + qi1 * f64_cos(ang_i)
                    var rkj0 = kj0 * f64_cos(ang_j) - kj1 * f64_sin(ang_j)
                    var rkj1 = kj0 * f64_sin(ang_j) + kj1 * f64_cos(ang_j)
                    s += rqi0 * rkj0 + rqi1 * rkj1
                esum += f64_exp(s * inv_s - m)
            for d in range(head_dim):
                var acc = 0.0
                for j in range(i + 1):
                    var s = 0.0
                    for p in range(head_dim // 2):
                        var ang_i = Float64(i) * f64_exp(
                            Float64(-2 * p) / Float64(head_dim) * ln_t
                        )
                        var ang_j = Float64(j) * f64_exp(
                            Float64(-2 * p) / Float64(head_dim) * ln_t
                        )
                        var qi0 = q[unsafe_offset=i * dm + h * head_dim + 2 * p]
                        var qi1 = q[unsafe_offset=i * dm + h * head_dim + 2 * p + 1]
                        var kj0 = k[unsafe_offset=j * dm + h * head_dim + 2 * p]
                        var kj1 = k[unsafe_offset=j * dm + h * head_dim + 2 * p + 1]
                        var rqi0 = qi0 * f64_cos(ang_i) - qi1 * f64_sin(ang_i)
                        var rqi1 = qi0 * f64_sin(ang_i) + qi1 * f64_cos(ang_i)
                        var rkj0 = kj0 * f64_cos(ang_j) - kj1 * f64_sin(ang_j)
                        var rkj1 = kj0 * f64_sin(ang_j) + kj1 * f64_cos(ang_j)
                        s += rqi0 * rkj0 + rqi1 * rkj1
                    acc += f64_exp(s * inv_s - m) / esum * vv[unsafe_offset=
                        j * dm + h * head_dim + d
                    ]
                ctx[unsafe_offset=i * dm + h * head_dim + d] = acc
    for s in range(seq):
        for d in range(dm):
            var acc = 0.0
            for e in range(dm):
                acc += ctx[unsafe_offset=s * dm + e] * Float64(
                    wo[unsafe_offset=e * dm + d]
                )
            outp[unsafe_offset=s * dm + d] = Float16(acc)


def test_h035(mut ctx: Ctx):
    ctx.seed(UInt64(0x3501))
    var seq = 128
    var nh = 4
    var hd = 64
    var dm = nh * hd
    var theta = Float32(10000)
    var x = unsafe_alloc[Float16](seq * dm)
    var wq = unsafe_alloc[Float16](dm * dm)
    var wk = unsafe_alloc[Float16](dm * dm)
    var wv = unsafe_alloc[Float16](dm * dm)
    var wo = unsafe_alloc[Float16](dm * dm)
    var o_seq = unsafe_alloc[Float16](seq * dm)
    var o_par = unsafe_alloc[Float16](seq * dm)
    var o_ref = unsafe_alloc[Float16](seq * dm)
    fill_rand_f16(x, seq * dm, ctx.state, -0.5, 0.5)
    fill_rand_f16(wq, dm * dm, ctx.state, -0.2, 0.2)
    fill_rand_f16(wk, dm * dm, ctx.state, -0.2, 0.2)
    fill_rand_f16(wv, dm * dm, ctx.state, -0.2, 0.2)
    fill_rand_f16(wo, dm * dm, ctx.state, -0.2, 0.2)
    mha_forward_seq(x, wq, wk, wv, wo, o_seq, seq, nh, hd, theta)
    mha_forward_par(x, wq, wk, wv, wo, o_par, seq, nh, hd, theta)
    mha_naive_ref(x, wq, wk, wv, wo, o_ref, seq, nh, hd, theta)
    var e = max_abs_err_f16(o_seq, o_ref, seq * dm)
    ctx.check("H035", e <= 2e-3, String("mha vs naive maxerr=") + String(e))
    var identical = True
    for i in range(seq * dm):
        if o_seq[unsafe_offset=i] != o_par.unsafe_offset(i):
            identical = False
    ctx.check("H035", identical, "seq vs par bit-identical")


def test_h036(mut ctx: Ctx):
    var log = List[String]()
    var ops = List[String]()
    ops.append("matmul")
    ops.append("gemv")
    ops.append("attention")
    ops.append("layernorm")
    var n_calls = 0
    for oi in range(4):
        var op = ops[oi]
        for si in range(5):
            var m = 64 * (si + 1)
            var n = 128 * (si + 1)
            var k = 256 * (si + 1)
            var want = BACKEND_AUTO()
            if si == 4:
                want = BACKEND_NPU()  # even an explicit NPU want must fail closed
            var r = select_backend(op, m, n, k, want, log)
            if r != BACKEND_CPU():
                ctx.check("H036", False, String("non-CPU result for ") + op)
            n_calls += 1
    ctx.check("H036", n_calls == 20, String("20 decisions, got ") + String(n_calls))
    var all_cpu = True
    var no_npu_path = True
    for i in range(20):
        var entry = log[i]
        # result marker is "-> CPU"; "-> NPU" must never appear
        var has_cpu = False
        var idx = entry.find("-> CPU")
        if idx >= 0:
            has_cpu = True
        if not has_cpu:
            all_cpu = False
        if entry.find("-> NPU") >= 0:
            no_npu_path = False
    ctx.check("H036", all_cpu, "all 20 decisions -> CPU")
    ctx.check("H036", no_npu_path, "no code path returns NPU")
    var stub = NpuBackendStub()
    ctx.check("H036", not stub.is_ready(), "NPU stub never ready (fail-closed)")


def toy_forward(
    tok: Int,
    emb: Pointer[Float16, MutUntrackedOrigin],
    lnw1: Pointer[Float16, MutUntrackedOrigin],
    lnb1: Pointer[Float16, MutUntrackedOrigin],
    w1: Pointer[Float16, MutUntrackedOrigin],
    w2: Pointer[Float16, MutUntrackedOrigin],
    lnw2: Pointer[Float16, MutUntrackedOrigin],
    lnb2: Pointer[Float16, MutUntrackedOrigin],
    wl: Pointer[Float16, MutUntrackedOrigin],
    logits: Pointer[Float16, MutUntrackedOrigin],
    h: Int,
    vocab: Int,
    use_kernels: Bool,
):
    # H039 toy: embed -> layernorm -> matmul(h->4h) -> silu -> matmul(4h->h)
    #         -> residual add -> layernorm -> matmul(h->vocab) = logits[1, vocab]
    var x = unsafe_alloc[Float16](h)
    var t1 = unsafe_alloc[Float16](h)
    var t2 = unsafe_alloc[Float16](4 * h)
    var t3 = unsafe_alloc[Float16](4 * h)
    var t4 = unsafe_alloc[Float16](h)
    var t5 = unsafe_alloc[Float16](h)
    for i in range(h):
        x[unsafe_offset=i] = emb[unsafe_offset=tok * h + i]
    if use_kernels:
        layernorm_fp16(x, lnw1, lnb1, t1, h, Float32(1e-5))
        gemm_fp16(t1, w1, t2, 1, 4 * h, h)
        silu_fp16(t2, t3, 4 * h)
        gemm_fp16(t3, w2, t4, 1, h, 4 * h)
        elem_add(x, t4, t5, h)
        layernorm_fp16(t5, lnw2, lnb2, t1, h, Float32(1e-5))
        gemm_fp16(t1, wl, logits, 1, vocab, h)
    else:
        # naive scalar fp32 reference
        var mean = Float32(0)
        for i in range(h):
            mean += Float32(x[unsafe_offset=i])
        mean /= Float32(h)
        var vv = Float32(0)
        for i in range(h):
            var d = Float32(x[unsafe_offset=i]) - mean
            vv += d * d
        vv /= Float32(h)
        var inv = Float32(1) / Float32(f64_sqrt(Float64(vv)))
        for i in range(h):
            t1[unsafe_offset=i] = Float16(
                (Float32(x[unsafe_offset=i]) - mean) * inv * Float32(
                    lnw1[unsafe_offset=i]
                ) + Float32(lnb1[unsafe_offset=i])
            )
        for j in range(4 * h):
            var s = Float32(0)
            for i in range(h):
                s += Float32(t1[unsafe_offset=i]) * Float32(w1[unsafe_offset=i * 4 * h + j])
            t2[unsafe_offset=j] = Float16(s)
        for j in range(4 * h):
            var v = Float32(t2[unsafe_offset=j])
            t3[unsafe_offset=j] = Float16(v / Float32(1.0 + f64_exp(Float64(-v))))
        for j in range(h):
            var s = Float32(0)
            for i in range(4 * h):
                s += Float32(t3[unsafe_offset=i]) * Float32(w2[unsafe_offset=i * h + j])
            t4[unsafe_offset=j] = Float16(s)
        for i in range(h):
            t5[unsafe_offset=i] = x[unsafe_offset=i] + t4[unsafe_offset=i]
        mean = Float32(0)
        for i in range(h):
            mean += Float32(t5[unsafe_offset=i])
        mean /= Float32(h)
        vv = Float32(0)
        for i in range(h):
            var d = Float32(t5[unsafe_offset=i]) - mean
            vv += d * d
        vv /= Float32(h)
        inv = Float32(1) / f32_sqrt(vv)
        for i in range(h):
            t1[unsafe_offset=i] = Float16(
                (Float32(t5[unsafe_offset=i]) - mean) * inv * Float32(
                    lnw2[unsafe_offset=i]
                ) + Float32(lnb2[unsafe_offset=i])
            )
        for j in range(vocab):
            var s = Float32(0)
            for i in range(h):
                s += Float32(t1[unsafe_offset=i]) * Float32(wl[unsafe_offset=i * vocab + j])
            logits[unsafe_offset=j] = Float16(s)


def test_h039(mut ctx: Ctx):
    ctx.seed(UInt64(0x3901))
    for hi in range(2):
        var h = 128
        if hi == 1:
            h = 512
        var vocab = 256
        var emb = unsafe_alloc[Float16](vocab * h)
        var lnw1 = unsafe_alloc[Float16](h)
        var lnb1 = unsafe_alloc[Float16](h)
        var w1 = unsafe_alloc[Float16](h * 4 * h)
        var w2 = unsafe_alloc[Float16](4 * h * h)
        var lnw2 = unsafe_alloc[Float16](h)
        var lnb2 = unsafe_alloc[Float16](h)
        var wl = unsafe_alloc[Float16](h * vocab)
        fill_rand_f16(emb, vocab * h, ctx.state, -0.5, 0.5)
        fill_rand_f16(lnw1, h, ctx.state, 0.8, 1.2)
        fill_rand_f16(lnb1, h, ctx.state, -0.1, 0.1)
        fill_rand_f16(w1, h * 4 * h, ctx.state, -0.2, 0.2)
        fill_rand_f16(w2, 4 * h * h, ctx.state, -0.2, 0.2)
        fill_rand_f16(lnw2, h, ctx.state, 0.8, 1.2)
        fill_rand_f16(lnb2, h, ctx.state, -0.1, 0.1)
        fill_rand_f16(wl, h * vocab, ctx.state, -0.2, 0.2)
        var lk = unsafe_alloc[Float16](vocab)
        var lr = unsafe_alloc[Float16](vocab)
        toy_forward(7, emb, lnw1, lnb1, w1, w2, lnw2, lnb2, wl, lk, h, vocab, True)
        toy_forward(7, emb, lnw1, lnb1, w1, w2, lnw2, lnb2, wl, lr, h, vocab, False)
        var e = max_abs_err_f16(lk, lr, vocab)
        var finite = True
        for i in range(vocab):
            var v = lk[unsafe_offset=i]
            if v != v:
                finite = False
        ctx.check(
            "H039",
            e <= 5e-3 and finite,
            String("h=") + String(h) + String(" maxerr=") + String(e) + String(" finite=") + String(finite),
        )


def main():
    var ctx = Ctx()
    test_h021(ctx)
    test_h022(ctx)
    test_h023(ctx)
    test_h024(ctx)
    test_h025(ctx)
    test_h026(ctx)
    test_h027(ctx)
    test_h028(ctx)
    test_h029(ctx)
    test_h030(ctx)
    test_h031(ctx)
    test_h032(ctx)
    test_h033(ctx)
    test_h034(ctx)
    test_h035(ctx)
    test_h036(ctx)
    test_h039(ctx)
    if ctx.fails == 0:
        print("C2_VERIFY ALL PASS")
    else:
        print("C2_VERIFY FAILURES:", ctx.fails)
    _ = external_call["exit", Int32, Int32](Int32(ctx.fails))
