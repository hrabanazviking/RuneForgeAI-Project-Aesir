# spikes/a029_mojo_gpu_target/gemm_probe.mojo
# A-029 probe 2: engine-shaped GEMM kernel (one output cell per thread,
# K-loop accumulation - the exact shape of core/cuda_compute.mojo's
# _cuda_f16_gemm_kernel, here in f32) executed on gfx1151 via
# DeviceContext(api="hip"). Verified in-program against the CPU oracle
# computed in the same k-ascending order; reports exact-match count and
# max abs diff (FMA contraction may legitimately differ in last ulps).
from std.gpu import global_idx
from std.memory import Pointer
from std.math import abs
from max.gpu.host import DeviceContext


def _gemm_kernel[
    a_origin: Origin[mut=False],
    b_origin: Origin[mut=False],
    c_origin: MutOrigin,
](
    a: Pointer[Scalar[DType.float32], a_origin],
    b: Pointer[Scalar[DType.float32], b_origin],
    c: Pointer[Scalar[DType.float32], c_origin],
    n_count: Int32,
    k_count: Int32,
    output_count: Int32,
):
    var output_index = Int(global_idx.x)
    if output_index < Int(output_count):
        var n = Int(n_count)
        var k = Int(k_count)
        var row = output_index // n
        var col = output_index - row * n
        var acc: Scalar[DType.float32] = 0.0
        for inner in range(k):
            acc += a.unsafe_load(row * k + inner) * b.unsafe_load(
                col * k + inner
            )
        c.unsafe_store(output_index, acc)


def main() raises:
    comptime M = 128
    comptime N = 128
    comptime K = 128
    with DeviceContext(0, api="hip") as ctx:
        print("device_name:", ctx.name())
        var host_a = ctx.enqueue_create_host_buffer[DType.float32](M * K)
        var host_b = ctx.enqueue_create_host_buffer[DType.float32](N * K)
        var host_c = ctx.enqueue_create_host_buffer[DType.float32](M * N)
        var dev_a = ctx.enqueue_create_buffer[DType.float32](M * K)
        var dev_b = ctx.enqueue_create_buffer[DType.float32](N * K)
        var dev_c = ctx.enqueue_create_buffer[DType.float32](M * N)
        for i in range(M * K):
            host_a[i] = Float32((i * 7) % 13) * Float32(0.25) - Float32(1.5)
        for i in range(N * K):
            host_b[i] = Float32((i * 5) % 11) * Float32(0.125) - Float32(0.5)
        for i in range(M * N):
            host_c[i] = Float32(-9999.0)
        ctx.enqueue_copy(dev_a, host_a)
        ctx.enqueue_copy(dev_b, host_b)
        ctx.enqueue_copy(dev_c, host_c)
        ctx.synchronize()
        ctx.enqueue_function[
            _gemm_kernel[origin_of(dev_a), origin_of(dev_b), origin_of(dev_c)]
        ](
            dev_a.unsafe_ptr(),
            dev_b.unsafe_ptr(),
            dev_c.unsafe_ptr(),
            Int32(N),
            Int32(K),
            Int32(M * N),
            grid_dim=(M * N) // 256,
            block_dim=256,
        )
        ctx.enqueue_copy(host_c, dev_c)
        ctx.synchronize()
        var exact = 0
        var within = 0
        var max_diff: Float32 = 0.0
        for row in range(M):
            for col in range(N):
                var oracle: Float32 = 0.0
                for inner in range(K):
                    oracle += host_a[row * K + inner] * host_b[col * K + inner]
                var got = host_c[row * N + col]
                var diff = abs(got - oracle)
                if diff > max_diff:
                    max_diff = diff
                if got == oracle:
                    exact += 1
                if diff <= Float32(0.001):
                    within += 1
        print("cells:", M * N, "exact:", exact, "within_1e-3:", within)
        print("max_abs_diff:", max_diff)
        if within == M * N:
            print("GEMM_PASS")
        else:
            print("GEMM_FAIL")
