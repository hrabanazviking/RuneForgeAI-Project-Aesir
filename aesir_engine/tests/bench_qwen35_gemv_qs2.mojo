# tests/bench_qwen35_gemv_qs2.mojo
# QS-2 GEMV bandwidth micro-bench: times the sequential
# _q8_gemm_kernel vs the QS-2.2 _q8_gemv_kernel (warp per
# row) on synthetic Q8_0 weights at real 27B GEMM shapes
# (weights far larger than any cache, so the numbers are
# DRAM streaming rates). No model file is loaded. Correct-
# ness cross-check: both kernels must agree to f32 rounding
# on the same inputs (printed max diff).
# Usage: bench_qwen35_gemv_qs2 [reps]

from std.sys import argv
from std.time import perf_counter_ns
from std.memory import Pointer
from max.gpu.host import DeviceContext, DeviceBuffer, HostBuffer
from core.packed_quantization import Bytes
from core.qwen35_hip import _q8_gemm_kernel, _q8_gemv_kernel, _q8_gemv_kernel_v4, _q8_gemv_kernel_v5, _q8_gemv_kernel_v6, _q8_gemv_kernel_v7
from core.hip_gemv import HipGemv

comptime Floats = Pointer[Float32, MutUntrackedOrigin]


def run_shape(ctx: DeviceContext, rows: Int, cols: Int, reps: Int) raises:
    var blocks = cols // 32
    var wbytes = rows * blocks * 34
    print("SHAPE rows=", rows, " cols=", cols, " weight_bytes=", wbytes)
    var host_w = ctx.enqueue_create_host_buffer[DType.uint8](wbytes)
    var seed: UInt32 = 2654435761
    for i in range(wbytes):
        seed = seed * 1664525 + 1013904223
        host_w[i] = UInt8((seed >> 24) & 0xFF)
    # Pin every block scale to f16 0.03125 (bytes 0x00, 0x34)
    # so outputs stay in a sane f32 range and the old-vs-new
    # diff measures accumulation order, not overflow noise.
    for r in range(rows):
        for blk in range(blocks):
            var bb = (r * blocks + blk) * 34
            host_w[bb] = UInt8(0)
            host_w[bb + 1] = UInt8(0x34)
    var dev_w = ctx.enqueue_create_buffer[DType.uint8](wbytes)
    ctx.enqueue_copy(dev_w, host_w)
    var host_a = ctx.enqueue_create_host_buffer[DType.float32](cols + rows)
    for i in range(cols):
        host_a[i] = Float32((i % 251) - 125) / 64.0
    for i in range(rows):
        host_a[cols + i] = Float32(-9999.0)
    var dev_a = ctx.enqueue_create_buffer[DType.float32](cols + rows)
    ctx.enqueue_copy(dev_a, host_a)
    ctx.synchronize()
    var w = Bytes(unsafe_from_address=Int(dev_w.unsafe_ptr()))
    var a = Floats(unsafe_from_address=Int(dev_a.unsafe_ptr()))
    # old (sequential) kernel
    var n_old = rows
    var t0 = perf_counter_ns()
    for _ in range(reps):
        ctx.enqueue_function[_q8_gemm_kernel](w, a, Int64(0), Int64(rows), Int64(cols), Int64(0), Int64(cols), Int64(1), grid_dim=(n_old + 255) // 256, block_dim=256)
    ctx.synchronize()
    var old_ns = perf_counter_ns() - t0
    ctx.enqueue_copy(host_a, dev_a)
    ctx.synchronize()
    var old_out = List[Float32]()
    for i in range(rows):
        old_out.append(host_a[cols + i])
    # new (warp) kernel
    var n_new = rows * 32
    t0 = perf_counter_ns()
    for _ in range(reps):
        ctx.enqueue_function[_q8_gemv_kernel](w, a, Int64(0), Int64(rows), Int64(cols), Int64(0), Int64(cols), Int64(1), grid_dim=(n_new + 255) // 256, block_dim=256)
    ctx.synchronize()
    var new_ns = perf_counter_ns() - t0
    ctx.enqueue_copy(host_a, dev_a)
    ctx.synchronize()
    var md = Float32(0.0)
    for i in range(rows):
        var d = host_a[cols + i] - old_out[i]
        if d < Float32(0.0):
            d = -d
        if d > md:
            md = d
    # v4 (coalesced lane-per-slot) kernel
    t0 = perf_counter_ns()
    for _ in range(reps):
        ctx.enqueue_function[_q8_gemv_kernel_v4](w, a, Int64(0), Int64(rows), Int64(cols), Int64(0), Int64(cols), Int64(1), grid_dim=(n_new + 255) // 256, block_dim=256)
    ctx.synchronize()
    var v4_ns = perf_counter_ns() - t0
    ctx.enqueue_copy(host_a, dev_a)
    ctx.synchronize()
    var md4 = Float32(0.0)
    for i in range(rows):
        var d = host_a[cols + i] - old_out[i]
        if d < Float32(0.0):
            d = -d
        if d > md4:
            md4 = d
    var gbs_v4 = Float64(wbytes) * Float64(reps) / (Float64(v4_ns) / 1e9) / 1e9
    print("V4 ms_per_rep=", Float64(v4_ns) / 1e6 / Float64(reps), " GB_s=", gbs_v4)
    print("MAXDIFF old_vs_v4=", md4)
    # v5 (v4 + 2-block unroll) kernel
    t0 = perf_counter_ns()
    for _ in range(reps):
        ctx.enqueue_function[_q8_gemv_kernel_v5](w, a, Int64(0), Int64(rows), Int64(cols), Int64(0), Int64(cols), Int64(1), grid_dim=(n_new + 255) // 256, block_dim=256)
    ctx.synchronize()
    var v5_ns = perf_counter_ns() - t0
    ctx.enqueue_copy(host_a, dev_a)
    ctx.synchronize()
    var md5 = Float32(0.0)
    for i in range(rows):
        var d = host_a[cols + i] - old_out[i]
        if d < Float32(0.0):
            d = -d
        if d > md5:
            md5 = d
    var gbs_v5 = Float64(wbytes) * Float64(reps) / (Float64(v5_ns) / 1e9) / 1e9
    print("V5 ms_per_rep=", Float64(v5_ns) / 1e6 / Float64(reps), " GB_s=", gbs_v5)
    print("MAXDIFF old_vs_v5=", md5)
    # v6 (v4 + 4-block unroll) kernel
    t0 = perf_counter_ns()
    for _ in range(reps):
        ctx.enqueue_function[_q8_gemv_kernel_v6](w, a, Int64(0), Int64(rows), Int64(cols), Int64(0), Int64(cols), Int64(1), grid_dim=(n_new + 255) // 256, block_dim=256)
    ctx.synchronize()
    var v6_ns = perf_counter_ns() - t0
    ctx.enqueue_copy(host_a, dev_a)
    ctx.synchronize()
    var md6 = Float32(0.0)
    for i in range(rows):
        var d = host_a[cols + i] - old_out[i]
        if d < Float32(0.0):
            d = -d
        if d > md6:
            md6 = d
    var gbs_v6 = Float64(wbytes) * Float64(reps) / (Float64(v6_ns) / 1e9) / 1e9
    print("V6 ms_per_rep=", Float64(v6_ns) / 1e6 / Float64(reps), " GB_s=", gbs_v6)
    print("MAXDIFF old_vs_v6=", md6)
    # v7 (v4 + 8-block unroll) kernel
    t0 = perf_counter_ns()
    for _ in range(reps):
        ctx.enqueue_function[_q8_gemv_kernel_v7](w, a, Int64(0), Int64(rows), Int64(cols), Int64(0), Int64(cols), Int64(1), grid_dim=(n_new + 255) // 256, block_dim=256)
    ctx.synchronize()
    var v7_ns = perf_counter_ns() - t0
    ctx.enqueue_copy(host_a, dev_a)
    ctx.synchronize()
    var md7 = Float32(0.0)
    for i in range(rows):
        var d = host_a[cols + i] - old_out[i]
        if d < Float32(0.0):
            d = -d
        if d > md7:
            md7 = d
    var gbs_v7 = Float64(wbytes) * Float64(reps) / (Float64(v7_ns) / 1e9) / 1e9
    print("V7 ms_per_rep=", Float64(v7_ns) / 1e6 / Float64(reps), " GB_s=", gbs_v7)
    print("MAXDIFF old_vs_v7=", md7)
    var gbs_old = Float64(wbytes) * Float64(reps) / (Float64(old_ns) / 1e9) / 1e9
    var gbs_new = Float64(wbytes) * Float64(reps) / (Float64(new_ns) / 1e9) / 1e9
    print("OLD ms_per_rep=", Float64(old_ns) / 1e6 / Float64(reps), " GB_s=", gbs_old)
    print("NEW ms_per_rep=", Float64(new_ns) / 1e6 / Float64(reps), " GB_s=", gbs_new)
    print("MAXDIFF old_vs_new=", md)


def main() raises:
    if not HipGemv.gate_ok():
        print("HIP gate absent: bench refused (honest-absent)")
        return
    var reps = 5
    if len(argv()) > 1:
        reps = Int(atol(String(argv()[1])))
    var ctx = DeviceContext(0, api="hip")
    run_shape(ctx, 17408, 5120, reps)
    run_shape(ctx, 248320, 5120, reps)
    print("QS2_GEMV_BENCH DONE")
