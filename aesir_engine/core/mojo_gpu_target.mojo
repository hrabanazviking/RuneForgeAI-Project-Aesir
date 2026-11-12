# core/mojo_gpu_target.mojo
# MojoNative: Mojo-native GPU kernels on AMD gfx1151 (A-029).
#
# A-029 determination (docs/AESIR_Z13_MOJO_GPU_DECISION.md, evidence in
# hidden_files/A029_LEDGER.md + hidden_files/a029/): with the pinned
# toolchain (Mojo 1.0.0 / MAX 26.5.0), a Mojo kernel compiled with
# --target-accelerator gfx1151 EXECUTES on the Radeon 8060S through
# MAX DeviceContext(api="hip") - it is not FFI-only. Proof is
# triangulated, because unified memory makes a correct result alone
# worthless as evidence:
#   1. the built binary embeds an amdgcn-amd-amdhsa gfx1151 code
#      object for each kernel in this module;
#   2. the same source built for gfx942 fails at launch on this
#      device with hipErrorNoBinaryForGpu - the kernel image is
#      arch-specific and device-loaded;
#   3. with the GPU hidden (HIP_VISIBLE_DEVICES= / ROCR_VISIBLE_
#      DEVICES=) the context raises hipErrorNoDevice - there is no
#      silent CPU fallback anywhere in this path;
#   4. a compute-bound spin kernel held gpu_busy_percent at a 99%
#      median (100% max) for its full 15.8 s run.
# Correctness vs the CPU oracle is byte-exact in the filed probes
# (vec_add 1,048,576 lanes; GEMM 128x128x128, 16,384/16,384 cells
# bit-exact) and is re-verified in-suite by tests/test_mojo_gpu_
# target.mojo on every run on this machine.
#
# Scope of the claim: elementwise and one-output-cell-per-thread
# GEMM kernel shapes in f32 - the shapes the engine's own CUDA
# kernels use (core/cuda_compute.mojo). Shared-memory tiling,
# barriers, subgroup ops and f16 kernel performance are NOT probed
# by A-029 and must not be claimed from this module; the first
# Part III kernel slice that needs them probes them first.
#
# Present/absent discipline matches A-011/A-019: available() is the
# gate; on a host with no HIP device the launchers raise, and the
# tests assert that fail-closed behaviour as honest-absent.
from max.gpu.host import DeviceContext
from std.gpu import global_idx
from std.memory import Pointer


def _mojo_vec_add_kernel[
    a_origin: Origin[mut=False],
    b_origin: Origin[mut=False],
    c_origin: MutOrigin,
](
    a: Pointer[Scalar[DType.float32], a_origin],
    b: Pointer[Scalar[DType.float32], b_origin],
    c: Pointer[Scalar[DType.float32], c_origin],
    count: Int32,
):
    var i = Int(global_idx.x)
    if i < Int(count):
        c.unsafe_store(i, a.unsafe_load(i) + b.unsafe_load(i))


def _mojo_gemm_kernel[
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
    """C[M,N] = A[M,K] x B[N,K]^T, one output cell per thread.

    The B layout ([N,K], indexed col*K + inner) matches
    core/cuda_compute.mojo's _cuda_f16_gemm_kernel exactly.
    """
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


struct MojoNative:
    """Launchers for the Mojo-native gfx1151 kernels above."""

    @staticmethod
    def device_count() -> Int:
        """HIP devices visible to MAX, or -1 when the query fails."""
        try:
            return DeviceContext.number_of_devices(api="hip")
        except:
            return -1

    @staticmethod
    def available() -> Bool:
        return Self.device_count() >= 1

    @staticmethod
    def probe_device(device: Int) -> Bool:
        """True iff a DeviceContext for `device` can be created."""
        try:
            with DeviceContext(device, api="hip") as ctx:
                _ = ctx.name()
            return True
        except:
            return False

    @staticmethod
    def device_name() raises -> String:
        with DeviceContext(0, api="hip") as ctx:
            return ctx.name()

    @staticmethod
    def vec_add(a: List[Float32], b: List[Float32]) raises -> List[Float32]:
        """out[i] = a[i] + b[i] on the GPU; sizes must match."""
        if len(a) != len(b):
            raise Error("MojoNative.vec_add: input size mismatch")
        if len(a) == 0:
            raise Error("MojoNative.vec_add: empty input")
        var n = len(a)
        with DeviceContext(0, api="hip") as ctx:
            var host_a = ctx.enqueue_create_host_buffer[DType.float32](n)
            var host_b = ctx.enqueue_create_host_buffer[DType.float32](n)
            var host_c = ctx.enqueue_create_host_buffer[DType.float32](n)
            var dev_a = ctx.enqueue_create_buffer[DType.float32](n)
            var dev_b = ctx.enqueue_create_buffer[DType.float32](n)
            var dev_c = ctx.enqueue_create_buffer[DType.float32](n)
            for i in range(n):
                host_a[i] = a[i]
                host_b[i] = b[i]
                host_c[i] = Float32(-9999.0)
            ctx.enqueue_copy(dev_a, host_a)
            ctx.enqueue_copy(dev_b, host_b)
            ctx.enqueue_copy(dev_c, host_c)
            ctx.synchronize()
            ctx.enqueue_function[
                _mojo_vec_add_kernel[
                    origin_of(dev_a), origin_of(dev_b), origin_of(dev_c)
                ]
            ](
                dev_a.unsafe_ptr(),
                dev_b.unsafe_ptr(),
                dev_c.unsafe_ptr(),
                Int32(n),
                grid_dim=(n + 255) // 256,
                block_dim=256,
            )
            ctx.enqueue_copy(host_c, dev_c)
            ctx.synchronize()
            var out = List[Float32](capacity=n)
            for i in range(n):
                out.append(host_c[i])
            return out^

    @staticmethod
    def gemm(
        a: List[Float32], b: List[Float32], m: Int, n: Int, k: Int
    ) raises -> List[Float32]:
        """C[M,N] = A[M,K] x B[N,K]^T on the GPU, row-major lists."""
        if m <= 0 or n <= 0 or k <= 0:
            raise Error("MojoNative.gemm: dimensions must be positive")
        if len(a) != m * k:
            raise Error("MojoNative.gemm: A element count != M*K")
        if len(b) != n * k:
            raise Error("MojoNative.gemm: B element count != N*K")
        with DeviceContext(0, api="hip") as ctx:
            var host_a = ctx.enqueue_create_host_buffer[DType.float32](m * k)
            var host_b = ctx.enqueue_create_host_buffer[DType.float32](n * k)
            var host_c = ctx.enqueue_create_host_buffer[DType.float32](m * n)
            var dev_a = ctx.enqueue_create_buffer[DType.float32](m * k)
            var dev_b = ctx.enqueue_create_buffer[DType.float32](n * k)
            var dev_c = ctx.enqueue_create_buffer[DType.float32](m * n)
            for i in range(m * k):
                host_a[i] = a[i]
            for i in range(n * k):
                host_b[i] = b[i]
            for i in range(m * n):
                host_c[i] = Float32(-9999.0)
            ctx.enqueue_copy(dev_a, host_a)
            ctx.enqueue_copy(dev_b, host_b)
            ctx.enqueue_copy(dev_c, host_c)
            ctx.synchronize()
            ctx.enqueue_function[
                _mojo_gemm_kernel[
                    origin_of(dev_a), origin_of(dev_b), origin_of(dev_c)
                ]
            ](
                dev_a.unsafe_ptr(),
                dev_b.unsafe_ptr(),
                dev_c.unsafe_ptr(),
                Int32(n),
                Int32(k),
                Int32(m * n),
                grid_dim=(m * n + 255) // 256,
                block_dim=256,
            )
            ctx.enqueue_copy(host_c, dev_c)
            ctx.synchronize()
            var out = List[Float32](capacity=m * n)
            for i in range(m * n):
                out.append(host_c[i])
            return out^
