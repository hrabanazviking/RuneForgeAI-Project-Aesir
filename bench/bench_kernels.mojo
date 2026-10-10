# bench/bench_kernels.mojo
# H161 — C2 kernel timings ported into the C9 harness (Domain D1 ARMVEGR).
#
# The timing bodies are the H038 (perf_bench.mojo) originals, unchanged in
# shape/seed/work-count, but parameterized by (warmup, trials) and reporting
# through bench_env.TrialStats so every C9 measurement shares one method.
# perf_bench.mojo is left untouched as C2 provenance.

from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from bench.bench_env import TrialStats, bench_stats_json
from armvegr.util import now_ns, fill_rand_f16, rand_range_f16
from armvegr.gemm import gemm_fp16
from armvegr.gemv import gemv_fp16
from armvegr.elem import elem_add, elem_mul, elem_scale, elem_axpy
from armvegr.norm import layernorm_fp16
from armvegr.rmsnorm import rmsnorm_fp16
from armvegr.softmax import softmax_fp16
from armvegr.act import silu_fp16, gelu_fp16
from armvegr.rope import rope_fp16
from armvegr.quant import fp32_to_fp16, fp16_to_q80, q80_to_fp16
from armvegr.q4 import fp16_to_q40, q40_to_fp16
from armvegr.qgemm import q80_gemm, q80_gemm_bytes
from armvegr.attn import attn_sdpa_causal_fp16
from armvegr.mha import mha_forward_seq


def _new_rng(seed: UInt64) -> Pointer[UInt64, MutUntrackedOrigin]:
    var st = unsafe_alloc[UInt64](1)
    st[unsafe_offset=0] = seed
    return st


def kern_stream_scalar(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var n = 8 * 1024 * 1024
    var a = unsafe_alloc[Float32](n)
    var b = unsafe_alloc[Float32](n)
    var c = unsafe_alloc[Float32](n)
    var st = _new_rng(11)
    for i in range(n):
        var w = st[unsafe_offset=0] + UInt64(0x9E3779B97F4A7C15)
        st[unsafe_offset=0] = w
        b[unsafe_offset=i] = Float32(w >> 32) / Float32(4294967296.0)
        c[unsafe_offset=i] = Float32(w & 0xFFFFFFFF) / Float32(4294967296.0)
    var scalar = Float32(3.0)
    for _ in range(warmup):
        for _ in range(repeat):
            for i in range(n):
                a[unsafe_offset=i] = b[unsafe_offset=i] + scalar * c[unsafe_offset=i]
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            for i in range(n):
                a[unsafe_offset=i] = b[unsafe_offset=i] + scalar * c[unsafe_offset=i]
        t.record(Float64(now_ns() - t0))
        sink += Float64(a[unsafe_offset=0]) + Float64(a[unsafe_offset=n - 1])
    return bench_stats_json("stream_triad_scalar", "8M_fp32", Float64((3 * 4 * n) * repeat), t)


def kern_stream(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var n = 8 * 1024 * 1024
    var a = unsafe_alloc[Float32](n)
    var b = unsafe_alloc[Float32](n)
    var c = unsafe_alloc[Float32](n)
    var st = _new_rng(12)
    for i in range(n):
        var w = st[unsafe_offset=0] + UInt64(0x9E3779B97F4A7C15)
        st[unsafe_offset=0] = w
        b[unsafe_offset=i] = Float32(w >> 32) / Float32(4294967296.0)
        c[unsafe_offset=i] = Float32(w & 0xFFFFFFFF) / Float32(4294967296.0)
    var scalar = SIMD[DType.float32, 8](3.0)
    for _ in range(warmup):
        for _ in range(repeat):
            var i = 0
            while i < n:
                var bv = b.unsafe_offset(i).unsafe_load[8]()
                var cv = c.unsafe_offset(i).unsafe_load[8]()
                a.unsafe_offset(i).unsafe_store[8](bv + scalar * cv)
                i += 8
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            var i = 0
            while i < n:
                var bv = b.unsafe_offset(i).unsafe_load[8]()
                var cv = c.unsafe_offset(i).unsafe_load[8]()
                a.unsafe_offset(i).unsafe_store[8](bv + scalar * cv)
                i += 8
        t.record(Float64(now_ns() - t0))
        sink += Float64(a[unsafe_offset=0]) + Float64(a[unsafe_offset=n - 1])
    return bench_stats_json("stream_triad", "8M_fp32", Float64((3 * 4 * n) * repeat), t)


def kern_gemm(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var M = 1024
    var N = 1024
    var K = 1024
    var a = unsafe_alloc[Float16](M * K)
    var b = unsafe_alloc[Float16](K * N)
    var c = unsafe_alloc[Float16](M * N)
    var st = _new_rng(21)
    fill_rand_f16(a, M * K, st, -1.0, 1.0)
    fill_rand_f16(b, K * N, st, -1.0, 1.0)
    for _ in range(warmup):
        for _ in range(repeat):
            gemm_fp16(a, b, c, M, N, K)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            gemm_fp16(a, b, c, M, N, K)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=M * N - 1])
    return bench_stats_json("gemm_fp16", "1024x1024x1024", Float64((2 * M * N * K) * repeat), t)


def kern_gemv(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var M = 8192
    var N = 8192
    var a = unsafe_alloc[Float16](M * N)
    var x = unsafe_alloc[Float16](N)
    var y = unsafe_alloc[Float16](M)
    var st = _new_rng(22)
    fill_rand_f16(a, M * N, st, -1.0, 1.0)
    fill_rand_f16(x, N, st, -1.0, 1.0)
    for _ in range(warmup):
        for _ in range(repeat):
            gemv_fp16(a, x, y, M, N)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            gemv_fp16(a, x, y, M, N)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=M - 1])
    return bench_stats_json("gemv_fp16", "8192x8192", Float64(((M * N + N + M) * 2) * repeat), t)


def kern_elem(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var n = 2 * 1024 * 1024
    var a = unsafe_alloc[Float16](n)
    var b = unsafe_alloc[Float16](n)
    var c = unsafe_alloc[Float16](n)
    var st = _new_rng(23)
    fill_rand_f16(a, n, st, -1.0, 1.0)
    fill_rand_f16(b, n, st, -1.0, 1.0)
    var out = String("")
    for _ in range(warmup):
        for _ in range(repeat):
            elem_add(a, b, c, n)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            elem_add(a, b, c, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=n - 1])
    out += bench_stats_json("elem_add", "2M", Float64((3 * 2 * n) * repeat), t) + ",\n"
    t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            elem_mul(a, b, c, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=n - 1])
    out += bench_stats_json("elem_mul", "2M", Float64((3 * 2 * n) * repeat), t) + ",\n"
    t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            elem_scale(a, c, Float16(0.5), n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=n - 1])
    out += bench_stats_json("elem_scale", "2M", Float64((2 * 2 * n) * repeat), t) + ",\n"
    t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            elem_axpy(a, b, c, Float16(0.5), n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=n - 1])
    out += bench_stats_json("elem_axpy", "2M", Float64((3 * 2 * n) * repeat), t)
    return out


def kern_layernorm(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var w = unsafe_alloc[Float16](n)
    var b = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    var st = _new_rng(24)
    fill_rand_f16(x, n, st, -3.0, 3.0)
    fill_rand_f16(w, n, st, 0.5, 1.5)
    fill_rand_f16(b, n, st, -1.0, 1.0)
    for _ in range(warmup):
        for _ in range(repeat):
            layernorm_fp16(x, w, b, y, n, Float32(1e-5))
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            layernorm_fp16(x, w, b, y, n, Float32(1e-5))
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    return bench_stats_json("layernorm_fp16", "1M", Float64((4 * 2 * n) * repeat), t)


def kern_rmsnorm(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var w = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    var st = _new_rng(25)
    fill_rand_f16(x, n, st, -3.0, 3.0)
    fill_rand_f16(w, n, st, 0.5, 1.5)
    for _ in range(warmup):
        for _ in range(repeat):
            rmsnorm_fp16(x, w, y, n, Float32(1e-5))
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            rmsnorm_fp16(x, w, y, n, Float32(1e-5))
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    return bench_stats_json("rmsnorm_fp16", "1M", Float64((3 * 2 * n) * repeat), t)


def kern_softmax(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    var st = _new_rng(26)
    fill_rand_f16(x, n, st, -2.0, 2.0)
    for _ in range(warmup):
        for _ in range(repeat):
            softmax_fp16(x, y, n)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            softmax_fp16(x, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    return bench_stats_json("softmax_fp16", "1M", Float64((3 * 2 * n) * repeat), t)


def kern_act(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    var st = _new_rng(27)
    fill_rand_f16(x, n, st, -10.0, 10.0)
    for _ in range(warmup):
        for _ in range(repeat):
            silu_fp16(x, y, n)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            silu_fp16(x, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    var out = bench_stats_json("silu_fp16", "1M", Float64((2 * 2 * n) * repeat), t) + ",\n"
    t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            gelu_fp16(x, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    out += bench_stats_json("gelu_fp16", "1M", Float64((2 * 2 * n) * repeat), t)
    return out


def kern_rope(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var hd = 128
    var reps = 4096
    var x = unsafe_alloc[Float16](hd)
    var y = unsafe_alloc[Float16](hd)
    var st = _new_rng(28)
    fill_rand_f16(x, hd, st, -1.0, 1.0)
    for _ in range(warmup):
        for _ in range(repeat):
            for p in range(reps):
                rope_fp16(x, y, hd, p, Float32(10000))
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            for p in range(reps):
                rope_fp16(x, y, hd, p, Float32(10000))
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=hd - 1])
    return bench_stats_json("rope_fp16", "hd128_x4096", Float64((reps * 2 * hd * 2) * repeat), t)


def kern_fp32_to_fp16(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var n = 1024 * 1024
    var x = unsafe_alloc[Float32](n)
    var y = unsafe_alloc[Float16](n)
    var st = _new_rng(29)
    for i in range(n):
        x[unsafe_offset=i] = Float32(rand_range_f16(st, -6.0, 6.0))
    for _ in range(warmup):
        for _ in range(repeat):
            fp32_to_fp16(x, y, n)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            fp32_to_fp16(x, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    return bench_stats_json("fp32_to_fp16", "1M", Float64((4 * n + 2 * n) * repeat), t)


def kern_q80(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var q = unsafe_alloc[Int8]((n // 32) * 34)
    var y = unsafe_alloc[Float16](n)
    var st = _new_rng(30)
    fill_rand_f16(x, n, st, -6.0, 6.0)
    for _ in range(warmup):
        for _ in range(repeat):
            fp16_to_q80(x, q, n)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            fp16_to_q80(x, q, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(q[unsafe_offset=0]) + Float64(q[unsafe_offset=(n // 32) * 34 - 1])
    var out = bench_stats_json("fp16_to_q80", "1M", Float64((2 * n + (n // 32) * 34) * repeat), t) + ",\n"
    for _ in range(warmup):
        q80_to_fp16(q, y, n)
    t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            q80_to_fp16(q, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    out += bench_stats_json("q80_to_fp16", "1M", Float64(((n // 32) * 34 + 2 * n) * repeat), t)
    return out


def kern_q40(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var q = unsafe_alloc[Int8]((n // 32) * 18)
    var y = unsafe_alloc[Float16](n)
    var st = _new_rng(31)
    fill_rand_f16(x, n, st, -6.0, 6.0)
    for _ in range(warmup):
        for _ in range(repeat):
            fp16_to_q40(x, q, n)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            fp16_to_q40(x, q, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(q[unsafe_offset=0]) + Float64(q[unsafe_offset=(n // 32) * 18 - 1])
    var out = bench_stats_json("fp16_to_q40", "1M", Float64((2 * n + (n // 32) * 18) * repeat), t) + ",\n"
    for _ in range(warmup):
        q40_to_fp16(q, y, n)
    t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            q40_to_fp16(q, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    out += bench_stats_json("q40_to_fp16", "1M", Float64(((n // 32) * 18 + 2 * n) * repeat), t)
    return out


def kern_q80_gemm(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var M = 1
    var N = 4096
    var K = 4096
    var xa = unsafe_alloc[Float16](M * K)
    var xb = unsafe_alloc[Float16](K * N)
    var aq = unsafe_alloc[Int8]((M * K // 32) * 34)
    var bqt = unsafe_alloc[Float16](N * K)
    var bq = unsafe_alloc[Int8]((N * K // 32) * 34)
    var c = unsafe_alloc[Float32](M * N)
    var st = _new_rng(32)
    fill_rand_f16(xa, M * K, st, -1.0, 1.0)
    fill_rand_f16(xb, K * N, st, -1.0, 1.0)
    for j in range(N):
        for k in range(K):
            bqt[unsafe_offset=j * K + k] = xb[unsafe_offset=k * N + j]
    fp16_to_q80(xa, aq, M * K)
    fp16_to_q80(bqt, bq, N * K)
    for _ in range(warmup):
        for _ in range(repeat):
            q80_gemm(aq, bq, c, M, N, K)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            q80_gemm(aq, bq, c, M, N, K)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=M * N - 1])
    return bench_stats_json(
        "q80_gemm", "M1_N4096_K4096", Float64(q80_gemm_bytes(M, N, K)) * Float64(repeat), t
    )


def kern_attn(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var seq = 512
    var hd = 64
    var n = seq * hd
    var q = unsafe_alloc[Float16](n)
    var k = unsafe_alloc[Float16](n)
    var v = unsafe_alloc[Float16](n)
    var o = unsafe_alloc[Float16](n)
    var st = _new_rng(33)
    fill_rand_f16(q, n, st, -0.5, 0.5)
    fill_rand_f16(k, n, st, -0.5, 0.5)
    fill_rand_f16(v, n, st, -0.5, 0.5)
    for _ in range(warmup):
        for _ in range(repeat):
            _ = attn_sdpa_causal_fp16(q, k, v, o, seq, hd)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            _ = attn_sdpa_causal_fp16(q, k, v, o, seq, hd)
        t.record(Float64(now_ns() - t0))
        sink += Float64(o[unsafe_offset=0]) + Float64(o[unsafe_offset=n - 1])
    return bench_stats_json(
        "attn_sdpa_causal_fp16", "seq512_hd64", Float64(4 * seq * seq * hd) * Float64(repeat), t
    )


def kern_mha(mut sink: Float64, warmup: Int, trials: Int, repeat: Int) -> String:
    var seq = 128
    var nh = 8
    var hd = 64
    var dm = nh * hd
    var x = unsafe_alloc[Float16](seq * dm)
    var wq = unsafe_alloc[Float16](dm * dm)
    var wk = unsafe_alloc[Float16](dm * dm)
    var wv = unsafe_alloc[Float16](dm * dm)
    var wo = unsafe_alloc[Float16](dm * dm)
    var o = unsafe_alloc[Float16](seq * dm)
    var st = _new_rng(34)
    fill_rand_f16(x, seq * dm, st, -0.5, 0.5)
    fill_rand_f16(wq, dm * dm, st, -0.2, 0.2)
    fill_rand_f16(wk, dm * dm, st, -0.2, 0.2)
    fill_rand_f16(wv, dm * dm, st, -0.2, 0.2)
    fill_rand_f16(wo, dm * dm, st, -0.2, 0.2)
    for _ in range(warmup):
        for _ in range(repeat):
            mha_forward_seq(x, wq, wk, wv, wo, o, seq, nh, hd, Float32(10000))
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        for _ in range(repeat):
            mha_forward_seq(x, wq, wk, wv, wo, o, seq, nh, hd, Float32(10000))
        t.record(Float64(now_ns() - t0))
        sink += Float64(o[unsafe_offset=0]) + Float64(o[unsafe_offset=seq * dm - 1])
    var flops = Float64(4 * 2 * seq * dm * dm + 2 * 2 * seq * seq * dm)
    return bench_stats_json("mha_forward_seq", "seq128_nh8_hd64", flops * Float64(repeat), t)


def bench_all_kernels(
    mut sink: Float64, warmup: Int, trials: Int
) -> String:
    # The 22 C2 kernels in H022-H035 order, as one JSON array body.
    # repeat: invocations per trial, targeting ~50 ms/trial so the timer
    # granularity does not dominate (H162 methodology refinement: the
    # single-invocation H038 method gave 20-60% spreads on sub-5ms kernels).
    var out = String("")
    out += kern_stream_scalar(sink, warmup, trials, 3) + ",\n"
    out += kern_stream(sink, warmup, trials, 3) + ",\n"
    out += kern_gemm(sink, warmup, trials, 1) + ",\n"
    out += kern_gemv(sink, warmup, trials, 2) + ",\n"
    out += kern_elem(sink, warmup, trials, 25) + ",\n"
    out += kern_layernorm(sink, warmup, trials, 30) + ",\n"
    out += kern_rmsnorm(sink, warmup, trials, 55) + ",\n"
    out += kern_softmax(sink, warmup, trials, 11) + ",\n"
    out += kern_act(sink, warmup, trials, 8) + ",\n"
    out += kern_rope(sink, warmup, trials, 8) + ",\n"
    out += kern_fp32_to_fp16(sink, warmup, trials, 55) + ",\n"
    out += kern_q80(sink, warmup, trials, 25) + ",\n"
    out += kern_q40(sink, warmup, trials, 25) + ",\n"
    out += kern_q80_gemm(sink, warmup, trials, 25) + ",\n"
    out += kern_attn(sink, warmup, trials, 3) + ",\n"
    out += kern_mha(sink, warmup, trials, 1) + "\n"
    return out
