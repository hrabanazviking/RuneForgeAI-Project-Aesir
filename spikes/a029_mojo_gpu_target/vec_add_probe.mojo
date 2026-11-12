# spikes/a029_mojo_gpu_target/vec_add_probe.mojo
# A-029 probe: can a Mojo-native GPU kernel compile for gfx1151 and
# EXECUTE on the Radeon 8060S through MAX DeviceContext(api="hip")?
# Modes (argv[1]): vecadd (default) | spin
# vecadd: out[i] = a[i] + b[i] for N f32, verified on host vs the CPU
# oracle out[i] == 3*i exactly; prints VECADD_PASS only on full match.
# spin: compute-bound kernel launched repeatedly; used with an external
# gpu_busy_percent sampler to prove device-side execution.
from std.sys import argv, has_accelerator
from std.gpu import global_idx
from std.memory import Pointer
from max.gpu.host import DeviceContext


def _vec_add_kernel[
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


def _spin_kernel[
    c_origin: MutOrigin,
](
    c: Pointer[Scalar[DType.float32], c_origin],
    count: Int32,
    iters: Int32,
):
    var i = Int(global_idx.x)
    if i < Int(count):
        var acc = c.unsafe_load(i)
        for _ in range(Int(iters)):
            acc = acc * 1.0000001 + 0.0000001
            if acc > 10000000000.0:
                acc = 1.0
        c.unsafe_store(i, acc)


def main() raises:
    var mode = String("vecadd")
    if len(argv()) > 1:
        mode = String(argv()[1])
    print("has_accelerator:", has_accelerator())
    var ndevices = DeviceContext.number_of_devices(api="hip")
    print("hip_device_count:", ndevices)
    with DeviceContext(0, api="hip") as ctx:
        print("device_name:", ctx.name())
        print("api_version:", ctx.get_api_version())
        comptime N = 1048576
        var host_a = ctx.enqueue_create_host_buffer[DType.float32](N)
        var host_b = ctx.enqueue_create_host_buffer[DType.float32](N)
        var host_out = ctx.enqueue_create_host_buffer[DType.float32](N)
        var dev_a = ctx.enqueue_create_buffer[DType.float32](N)
        var dev_b = ctx.enqueue_create_buffer[DType.float32](N)
        var dev_out = ctx.enqueue_create_buffer[DType.float32](N)
        for i in range(N):
            host_a[i] = Float32(i)
            host_b[i] = Float32(2 * i)
            host_out[i] = Float32(-9999.0)
        ctx.enqueue_copy(dev_a, host_a)
        ctx.enqueue_copy(dev_b, host_b)
        ctx.enqueue_copy(dev_out, host_out)
        ctx.synchronize()
        if mode == "spin":
            for _round in range(100):
                ctx.enqueue_function[
                    _spin_kernel[origin_of(dev_out)]
                ](
                    dev_out.unsafe_ptr(),
                    Int32(N),
                    Int32(200000),
                    grid_dim=N // 256,
                    block_dim=256,
                )
                ctx.synchronize()
            print("SPIN_DONE")
            return
        ctx.enqueue_function[
            _vec_add_kernel[
                origin_of(dev_a), origin_of(dev_b), origin_of(dev_out)
            ]
        ](
            dev_a.unsafe_ptr(),
            dev_b.unsafe_ptr(),
            dev_out.unsafe_ptr(),
            Int32(N),
            grid_dim=N // 256,
            block_dim=256,
        )
        ctx.enqueue_copy(host_out, dev_out)
        ctx.synchronize()
        var mismatches = 0
        var first_bad = -1
        for i in range(N):
            if host_out[i] != Float32(3 * i):
                mismatches += 1
                if first_bad < 0:
                    first_bad = i
        print("mismatches:", mismatches, "first_bad:", first_bad)
        if mismatches == 0:
            print("VECADD_PASS", N)
        else:
            print("VECADD_FAIL", N)
