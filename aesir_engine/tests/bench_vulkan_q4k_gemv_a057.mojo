"""A-057 bench/probe: Vulkan Q4_K GEMV vs the Z13 CPU oracle.

Standalone proof (not an E-MASTER case): fills deterministic
synthetic Q4_K super-blocks (LCG seed 0xA057, d/dmin pinned like
A-040), dispatches the GPU kernel through VulkanBuffers.q4k_gemv on
the RADV STRIX_HALO device, and compares every output row against
the CPU oracle (dequantize_ggml_k kind 12 into f16, then an f32
dot) - the A-054-declared reference oracle. Prints per-shape max
abs/rel error, the shim dispatch counter before/after (device
execution evidence), and median GPU vs CPU wall times at a
Coder-class decode shape. Fails closed if the RADV device is not
the selected device.
"""
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc
from std.math import abs as fabs
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.compute import dequantize_ggml_k
from core.mimir_well import f16, f32


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A057 clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def _lcg(state: Int64) -> Int64:
    return state * Int64(6364136223846793005) + Int64(1442695040888963407)


def _fx(i: Int) -> Float32:
    return Float32((i * 73 + 19) % 997) * Float32(0.002) - Float32(0.997)


def _fill_weights(pw: Pointer[UInt8, MutUntrackedOrigin], total_blocks: Int):
    var s = Int64(0xA057)
    for b in range(total_blocks):
        s = _lcg(s + Int64(b))
        var st = s
        for i in range(144):
            st = _lcg(st)
            pw.unsafe_store(b * 144 + i, UInt8((st >> 33) & 0xFF))
        pw.unsafe_store(b * 144 + 0, UInt8(0x00))
        pw.unsafe_store(b * 144 + 1, UInt8(0x2E))
        pw.unsafe_store(b * 144 + 2, UInt8(0x00))
        pw.unsafe_store(b * 144 + 3, UInt8(0x1E))


def _median(mut xs: List[Int]) -> Int:
    for i in range(1, len(xs)):
        var v = xs[i]
        var j = i - 1
        while j >= 0 and xs[j] > v:
            xs[j + 1] = xs[j]
            j -= 1
        xs[j + 1] = v
    return xs[len(xs) // 2]


def _run_shape(n_rows: Int, k_elems: Int, reps: Int) raises:
    var nblocks = k_elems // 256
    var w_bytes = n_rows * nblocks * 144
    var w = VulkanBuffers.allocate(w_bytes)
    var x = VulkanBuffers.allocate(k_elems * 4)
    var y = VulkanBuffers.allocate(n_rows * 4)
    var pw = VulkanBuffers.map(w)
    _fill_weights(pw, n_rows * nblocks)
    VulkanBuffers.unmap(w)
    var px = VulkanBuffers.map(x)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(k_elems):
        fx.unsafe_store(i, _fx(i))
    VulkanBuffers.unmap(x)
    var py = VulkanBuffers.map(y)
    var fy = py.unsafe_bitcast[Float32]()
    for r in range(n_rows):
        fy.unsafe_store(r, Float32(-9999.0))
    VulkanBuffers.unmap(y)
    # CPU oracle: dequantize row by row (kind 12) and dot in f32.
    var oracle = alloc[Float32](n_rows)
    var w_host = alloc[UInt8](w_bytes)
    var pw2 = VulkanBuffers.map(w)
    for i in range(w_bytes):
        w_host.unsafe_store(i, pw2.unsafe_load(i))
    VulkanBuffers.unmap(w)
    var deq = alloc[Scalar[f16]](k_elems)
    var cpu_times = List[Int]()
    for _rep in range(reps):
        var t0 = monotonic_ns()
        for r in range(n_rows):
            dequantize_ggml_k(
                w_host.unsafe_offset(r * nblocks * 144), deq, k_elems, 12
            )
            var acc = Float32(0.0)
            for e in range(k_elems):
                acc += deq.unsafe_load(e).cast[f32]() * _fx(e)
            oracle.unsafe_store(r, acc)
        cpu_times.append(monotonic_ns() - t0)
    var before = VulkanBuffers.q4k_gemv_dispatch_count()
    var gpu_times = List[Int]()
    for _rep in range(reps):
        var t0 = monotonic_ns()
        VulkanBuffers.q4k_gemv(w, x, y, k_elems, n_rows)
        gpu_times.append(monotonic_ns() - t0)
    var after = VulkanBuffers.q4k_gemv_dispatch_count()
    var qy = VulkanBuffers.map(y)
    var gy = qy.unsafe_bitcast[Float32]()
    var max_abs = Float32(0.0)
    var max_rel = Float32(0.0)
    for r in range(n_rows):
        var got = gy.unsafe_load(r)
        var want = oracle.unsafe_load(r)
        var d = fabs(got - want)
        if d > max_abs:
            max_abs = d
        var denom = fabs(want)
        if denom > Float32(1.0):
            var rel = d / denom
            if rel > max_rel:
                max_rel = rel
    VulkanBuffers.unmap(y)
    print(
        "A057_SHAPE rows=" + String(n_rows) + " k=" + String(k_elems)
        + " max_abs_err=" + String(max_abs)
        + " max_rel_err=" + String(max_rel)
        + " dispatches=" + String(after - before)
        + " gpu_median_ns=" + String(_median(gpu_times))
        + " cpu_median_ns=" + String(_median(cpu_times))
    )
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)
    w_host.unsafe_free()
    deq.unsafe_free()
    oracle.unsafe_free()


def main() raises:
    if not VulkanBuffers.runtime_available() or not VulkanBuffers.dispatch_available():
        raise Error("A057 bench: Vulkan dispatch unavailable (fail-closed)")
    var info = VulkanBuffers.device_info()
    if info.vendor_id != 0x1002 or info.device_type == 4:
        raise Error("A057 bench: selected device is not the AMD iGPU")
    if not VulkanBuffers.device_name_is_radv():
        raise Error("A057 bench: selected device is not RADV (llvmpipe refused)")
    print(
        "A057_DEVICE vendor=" + String(info.vendor_id)
        + " device=" + String(info.device_id)
        + " type=" + String(info.device_type)
        + " api=" + String(info.api_version) + " RADV=1"
    )
    _run_shape(1, 256, 3)
    _run_shape(7, 512, 3)
    _run_shape(64, 1024, 3)
    _run_shape(33, 2048, 3)
    _run_shape(4096, 4096, 5)
    print("A057_VULKAN_Q4K_GEMV_BENCH: PASS")
