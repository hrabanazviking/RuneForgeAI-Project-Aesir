# H038 — C2 performance baseline benchmark (runs ON MIMIR).
#
# Measures every C2 kernel (H022-H035) at a representative shape:
#   warmup 3 runs, then 11 timed runs; reports median/min/max.
# A DCE sink accumulates checksums of each kernel's outputs so the
# optimizer cannot delete the timed work (without the sink, whole
# kernels were eliminated: 74 ns for an 8192^2 GEMV).
# Single-threaded; pin with taskset to one core (see BENCHMARK_METHOD.md).
# Prints one JSON object per line; the caller assembles
# data/armvegr/kernel_perf.json and adds run metadata (temp, Mojo
# version, clock-pin state).

from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin
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


def new_rng(seed: UInt64) -> Pointer[UInt64, MutUntrackedOrigin]:
    var st = unsafe_alloc[UInt64](1)
    st[unsafe_offset=0] = seed
    return st


struct Timer:
    var s: List[Float64]

    def __init__(out self):
        self.s = List[Float64]()

    def record(mut self, ns: Float64):
        self.s.append(ns)

    def sorted_median(mut self) -> Float64:
        # Insertion sort of the 11 samples; median is element 5.
        var n = len(self.s)
        for i in range(1, n):
            var key = self.s[i]
            var j = i - 1
            while j >= 0 and self.s[j] > key:
                self.s[j + 1] = self.s[j]
                j -= 1
            self.s[j + 1] = key
        return self.s[n // 2]

    def min_ns(self) -> Float64:
        var m = self.s[0]
        for i in range(1, len(self.s)):
            if self.s[i] < m:
                m = self.s[i]
        return m

    def max_ns(self) -> Float64:
        var m = self.s[0]
        for i in range(1, len(self.s)):
            if self.s[i] > m:
                m = self.s[i]
        return m


def emit(
    kernel: String,
    shape: String,
    unit: String,
    work: Float64,
    mut t: Timer,
    mut sink: Float64,
):
    # work: FLOPs for GFLOPS, or bytes for GB/s. rate = work / median_ns.
    var med = t.sorted_median()
    var r_med = work / med
    var r_min = work / t.max_ns()
    var r_max = work / t.min_ns()
    print(
        '{"kernel": "'
        + kernel
        + '", "shape": "'
        + shape
        + '", "unit": "'
        + unit
        + '", "median": '
        + String(r_med)
        + ', "min": '
        + String(r_min)
        + ', "max": '
        + String(r_max)
        + ', "median_ns": '
        + String(Int64(med))
        + ', "min_ns": '
        + String(Int64(t.min_ns()))
        + ', "max_ns": '
        + String(Int64(t.max_ns()))
        + '}'
    )
    sink += r_med * 0.0  # keep sink live without perturbing it


def bench_stream(mut sink: Float64):
    var n = 8 * 1024 * 1024
    var a = unsafe_alloc[Float32](n)
    var b = unsafe_alloc[Float32](n)
    var c = unsafe_alloc[Float32](n)
    var st = new_rng(11)
    for i in range(n):
        var w = st[unsafe_offset=0] + UInt64(0x9E3779B97F4A7C15)
        st[unsafe_offset=0] = w
        b[unsafe_offset=i] = Float32(w >> 32) / Float32(4294967296.0)
        c[unsafe_offset=i] = Float32(w & 0xFFFFFFFF) / Float32(4294967296.0)
    var scalar = Float32(3.0)
    for _ in range(3):
        for i in range(n):
            a[unsafe_offset=i] = b[unsafe_offset=i] + scalar * c[unsafe_offset=i]
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        for i in range(n):
            a[unsafe_offset=i] = b[unsafe_offset=i] + scalar * c[unsafe_offset=i]
        var t1 = now_ns()
        t.record(Float64(t1 - t0))
        sink += Float64(a[unsafe_offset=0]) + Float64(a[unsafe_offset=n - 1])
    # STREAM triad is not auto-vectorized reliably; unroll 8-wide manually
    # for the canonical number (kept simple: scalar loop above is the honest
    # baseline; vectorized variant measured separately below).
    emit("stream_triad_scalar", "8M_fp32", "GB/s", Float64(3 * 4 * n), t, sink)


def bench_stream_vec(mut sink: Float64):
    var n = 8 * 1024 * 1024
    var a = unsafe_alloc[Float32](n)
    var b = unsafe_alloc[Float32](n)
    var c = unsafe_alloc[Float32](n)
    var st = new_rng(12)
    for i in range(n):
        var w = st[unsafe_offset=0] + UInt64(0x9E3779B97F4A7C15)
        st[unsafe_offset=0] = w
        b[unsafe_offset=i] = Float32(w >> 32) / Float32(4294967296.0)
        c[unsafe_offset=i] = Float32(w & 0xFFFFFFFF) / Float32(4294967296.0)
    var scalar = SIMD[DType.float32, 8](3.0)
    for _ in range(3):
        var i = 0
        while i < n:
            var bv = b.unsafe_offset(i).unsafe_load[8]()
            var cv = c.unsafe_offset(i).unsafe_load[8]()
            a.unsafe_offset(i).unsafe_store[8](bv + scalar * cv)
            i += 8
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        var i = 0
        while i < n:
            var bv = b.unsafe_offset(i).unsafe_load[8]()
            var cv = c.unsafe_offset(i).unsafe_load[8]()
            a.unsafe_offset(i).unsafe_store[8](bv + scalar * cv)
            i += 8
        var t1 = now_ns()
        t.record(Float64(t1 - t0))
        sink += Float64(a[unsafe_offset=0]) + Float64(a[unsafe_offset=n - 1])
    emit("stream_triad", "8M_fp32", "GB/s", Float64(3 * 4 * n), t, sink)


def bench_gemm(mut sink: Float64):
    var M = 1024
    var N = 1024
    var K = 1024
    var a = unsafe_alloc[Float16](M * K)
    var b = unsafe_alloc[Float16](K * N)
    var c = unsafe_alloc[Float16](M * N)
    var st = new_rng(21)
    fill_rand_f16(a, M * K, st, -1.0, 1.0)
    fill_rand_f16(b, K * N, st, -1.0, 1.0)
    for _ in range(3):
        gemm_fp16(a, b, c, M, N, K)
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        gemm_fp16(a, b, c, M, N, K)
        var t1 = now_ns()
        t.record(Float64(t1 - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=M * N - 1])
    emit("gemm_fp16", "1024x1024x1024", "GFLOPS", Float64(2 * M * N * K), t, sink)


def bench_gemv(mut sink: Float64):
    var M = 8192
    var N = 8192
    var a = unsafe_alloc[Float16](M * N)
    var x = unsafe_alloc[Float16](N)
    var y = unsafe_alloc[Float16](M)
    var st = new_rng(22)
    fill_rand_f16(a, M * N, st, -1.0, 1.0)
    fill_rand_f16(x, N, st, -1.0, 1.0)
    for _ in range(3):
        gemv_fp16(a, x, y, M, N)
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        gemv_fp16(a, x, y, M, N)
        var t1 = now_ns()
        t.record(Float64(t1 - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=M - 1])
    var traffic = Float64((M * N + N + M) * 2)
    emit("gemv_fp16", "8192x8192", "GB/s", traffic, t, sink)


def bench_elem(mut sink: Float64):
    var n = 2 * 1024 * 1024
    var a = unsafe_alloc[Float16](n)
    var b = unsafe_alloc[Float16](n)
    var c = unsafe_alloc[Float16](n)
    var st = new_rng(23)
    fill_rand_f16(a, n, st, -1.0, 1.0)
    fill_rand_f16(b, n, st, -1.0, 1.0)
    var t = Timer()
    for _ in range(3):
        elem_add(a, b, c, n)
    t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        elem_add(a, b, c, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=n - 1])
    emit("elem_add", "2M", "GB/s", Float64(3 * 2 * n), t, sink)
    t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        elem_mul(a, b, c, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=n - 1])
    emit("elem_mul", "2M", "GB/s", Float64(3 * 2 * n), t, sink)
    t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        elem_scale(a, c, Float16(0.5), n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=n - 1])
    emit("elem_scale", "2M", "GB/s", Float64(2 * 2 * n), t, sink)
    t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        elem_axpy(a, b, c, Float16(0.5), n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=n - 1])
    emit("elem_axpy", "2M", "GB/s", Float64(3 * 2 * n), t, sink)


def bench_layernorm(mut sink: Float64):
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var w = unsafe_alloc[Float16](n)
    var b = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    var st = new_rng(24)
    fill_rand_f16(x, n, st, -3.0, 3.0)
    fill_rand_f16(w, n, st, 0.5, 1.5)
    fill_rand_f16(b, n, st, -1.0, 1.0)
    for _ in range(3):
        layernorm_fp16(x, w, b, y, n, Float32(1e-5))
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        layernorm_fp16(x, w, b, y, n, Float32(1e-5))
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    emit("layernorm_fp16", "1M", "GB/s", Float64(4 * 2 * n), t, sink)


def bench_rmsnorm(mut sink: Float64):
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var w = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    var st = new_rng(25)
    fill_rand_f16(x, n, st, -3.0, 3.0)
    fill_rand_f16(w, n, st, 0.5, 1.5)
    for _ in range(3):
        rmsnorm_fp16(x, w, y, n, Float32(1e-5))
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        rmsnorm_fp16(x, w, y, n, Float32(1e-5))
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    emit("rmsnorm_fp16", "1M", "GB/s", Float64(3 * 2 * n), t, sink)


def bench_softmax(mut sink: Float64):
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    var st = new_rng(26)
    fill_rand_f16(x, n, st, -2.0, 2.0)
    for _ in range(3):
        softmax_fp16(x, y, n)
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        softmax_fp16(x, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    # two passes over x (max, exp/sum) + one write
    emit("softmax_fp16", "1M", "GB/s", Float64(3 * 2 * n), t, sink)


def bench_act(mut sink: Float64):
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var y = unsafe_alloc[Float16](n)
    var st = new_rng(27)
    fill_rand_f16(x, n, st, -10.0, 10.0)
    for _ in range(3):
        silu_fp16(x, y, n)
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        silu_fp16(x, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    emit("silu_fp16", "1M", "GB/s", Float64(2 * 2 * n), t, sink)
    t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        gelu_fp16(x, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    emit("gelu_fp16", "1M", "GB/s", Float64(2 * 2 * n), t, sink)


def bench_rope(mut sink: Float64):
    var hd = 128
    var reps = 4096
    var x = unsafe_alloc[Float16](hd)
    var y = unsafe_alloc[Float16](hd)
    var st = new_rng(28)
    fill_rand_f16(x, hd, st, -1.0, 1.0)
    for _ in range(3):
        for p in range(reps):
            rope_fp16(x, y, hd, p, Float32(10000))
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        for p in range(reps):
            rope_fp16(x, y, hd, p, Float32(10000))
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=hd - 1])
    emit("rope_fp16", "hd128_x4096", "GB/s", Float64(reps * 2 * hd * 2), t, sink)


def bench_fp32_to_fp16(mut sink: Float64):
    var n = 1024 * 1024
    var x = unsafe_alloc[Float32](n)
    var y = unsafe_alloc[Float16](n)
    var st = new_rng(29)
    for i in range(n):
        x[unsafe_offset=i] = Float32(rand_range_f16(st, -6.0, 6.0))
    for _ in range(3):
        fp32_to_fp16(x, y, n)
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        fp32_to_fp16(x, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    emit("fp32_to_fp16", "1M", "GB/s", Float64(4 * n + 2 * n), t, sink)


def bench_q80(mut sink: Float64):
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var q = unsafe_alloc[Int8]((n // 32) * 34)
    var y = unsafe_alloc[Float16](n)
    var st = new_rng(30)
    fill_rand_f16(x, n, st, -6.0, 6.0)
    for _ in range(3):
        fp16_to_q80(x, q, n)
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        fp16_to_q80(x, q, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(q[unsafe_offset=0]) + Float64(q[unsafe_offset=(n // 32) * 34 - 1])
    emit("fp16_to_q80", "1M", "GB/s", Float64(2 * n + (n // 32) * 34), t, sink)
    for _ in range(3):
        q80_to_fp16(q, y, n)
    t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        q80_to_fp16(q, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    emit("q80_to_fp16", "1M", "GB/s", Float64((n // 32) * 34 + 2 * n), t, sink)


def bench_q40(mut sink: Float64):
    var n = 1024 * 1024
    var x = unsafe_alloc[Float16](n)
    var q = unsafe_alloc[Int8]((n // 32) * 18)
    var y = unsafe_alloc[Float16](n)
    var st = new_rng(31)
    fill_rand_f16(x, n, st, -6.0, 6.0)
    for _ in range(3):
        fp16_to_q40(x, q, n)
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        fp16_to_q40(x, q, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(q[unsafe_offset=0]) + Float64(q[unsafe_offset=(n // 32) * 18 - 1])
    emit("fp16_to_q40", "1M", "GB/s", Float64(2 * n + (n // 32) * 18), t, sink)
    for _ in range(3):
        q40_to_fp16(q, y, n)
    t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        q40_to_fp16(q, y, n)
        t.record(Float64(now_ns() - t0))
        sink += Float64(y[unsafe_offset=0]) + Float64(y[unsafe_offset=n - 1])
    emit("q40_to_fp16", "1M", "GB/s", Float64((n // 32) * 18 + 2 * n), t, sink)


def bench_q80_gemm(mut sink: Float64):
    var M = 1
    var N = 4096
    var K = 4096
    var xa = unsafe_alloc[Float16](M * K)
    var xb = unsafe_alloc[Float16](K * N)
    var aq = unsafe_alloc[Int8]((M * K // 32) * 34)
    # Bq is K-major: row j holds (K/32) blocks.
    var bqt = unsafe_alloc[Float16](N * K)
    var bq = unsafe_alloc[Int8]((N * K // 32) * 34)
    var c = unsafe_alloc[Float32](M * N)
    var st = new_rng(32)
    fill_rand_f16(xa, M * K, st, -1.0, 1.0)
    fill_rand_f16(xb, K * N, st, -1.0, 1.0)
    for j in range(N):
        for k in range(K):
            bqt[unsafe_offset=j * K + k] = xb[unsafe_offset=k * N + j]
    fp16_to_q80(xa, aq, M * K)
    fp16_to_q80(bqt, bq, N * K)
    for _ in range(3):
        q80_gemm(aq, bq, c, M, N, K)
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        q80_gemm(aq, bq, c, M, N, K)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=M * N - 1])
    emit(
        "q80_gemm",
        "M1_N4096_K4096",
        "GB/s",
        Float64(q80_gemm_bytes(M, K)),
        t,
        sink,
    )


def bench_attn(mut sink: Float64):
    var seq = 512
    var hd = 64
    var n = seq * hd
    var q = unsafe_alloc[Float16](n)
    var k = unsafe_alloc[Float16](n)
    var v = unsafe_alloc[Float16](n)
    var o = unsafe_alloc[Float16](n)
    var st = new_rng(33)
    fill_rand_f16(q, n, st, -0.5, 0.5)
    fill_rand_f16(k, n, st, -0.5, 0.5)
    fill_rand_f16(v, n, st, -0.5, 0.5)
    for _ in range(3):
        _ = attn_sdpa_causal_fp16(q, k, v, o, seq, hd)
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        _ = attn_sdpa_causal_fp16(q, k, v, o, seq, hd)
        t.record(Float64(now_ns() - t0))
        sink += Float64(o[unsafe_offset=0]) + Float64(o[unsafe_offset=n - 1])
    # QK^T + AV: 2 * (2 * seq^2 * hd)
    emit(
        "attn_sdpa_causal_fp16",
        "seq512_hd64",
        "GFLOPS",
        Float64(4 * seq * seq * hd),
        t,
        sink,
    )


def bench_mha(mut sink: Float64):
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
    var st = new_rng(34)
    fill_rand_f16(x, seq * dm, st, -0.5, 0.5)
    fill_rand_f16(wq, dm * dm, st, -0.2, 0.2)
    fill_rand_f16(wk, dm * dm, st, -0.2, 0.2)
    fill_rand_f16(wv, dm * dm, st, -0.2, 0.2)
    fill_rand_f16(wo, dm * dm, st, -0.2, 0.2)
    for _ in range(2):
        mha_forward_seq(x, wq, wk, wv, wo, o, seq, nh, hd, Float32(10000))
    var t = Timer()
    for _ in range(11):
        var t0 = now_ns()
        mha_forward_seq(x, wq, wk, wv, wo, o, seq, nh, hd, Float32(10000))
        t.record(Float64(now_ns() - t0))
        sink += Float64(o[unsafe_offset=0]) + Float64(o[unsafe_offset=seq * dm - 1])
    # 4 projections (2*seq*dm^2 each) + causal attn QK+AV (2*seq^2*dm each)
    var flops = Float64(4 * 2 * seq * dm * dm + 2 * 2 * seq * seq * dm)
    emit("mha_forward_seq", "seq128_nh8_hd64", "GFLOPS", flops, t, sink)


def main():
    var sink = Float64(0)
    bench_stream(sink)
    bench_stream_vec(sink)
    bench_gemm(sink)
    bench_gemv(sink)
    bench_elem(sink)
    bench_layernorm(sink)
    bench_rmsnorm(sink)
    bench_softmax(sink)
    bench_act(sink)
    bench_rope(sink)
    bench_fp32_to_fp16(sink)
    bench_q80(sink)
    bench_q40(sink)
    bench_q80_gemm(sink)
    bench_attn(sink)
    bench_mha(sink)
    print('{"sink": ' + String(sink) + "}")
