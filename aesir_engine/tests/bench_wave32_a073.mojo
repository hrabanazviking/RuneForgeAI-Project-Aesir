"""A-073 bench: wavefront-32 tuning measurements for the banked
Vulkan GEMV kernels (A-056 Q8_0, A-057 Q4_K, A-058 Q6_K/Q5_K,
A-059 IQ family) and the A-068 GEMM kernels.

Standalone timing proof (not an E-MASTER case): fills synthetic
weight bytes (LCG), dispatches each kernel on the RADV STRIX_HALO
device at a Coder-class decode shape (rows=2048, cols=4096) and a
prefill GEMM shape (tokens=64, rows=1024, cols=4096... filed as
1024x1024), and prints median dispatch wall time, effective
weight bandwidth, and the shim dispatch-count delta (device
execution evidence). Parity is NOT judged here - the E-MASTER
cases of A-056..A-059/A-068 judge parity at their filed bounds.
Fails closed if the RADV device is not the selected device.
"""
from std.ffi import external_call
from std.memory import Pointer
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_gemv import VulkanGemv
from core.vulkan_gemm import VulkanGemm
from core.extreme_quantization import iq_grid_materialize
from std.memory.alloc import alloc


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A073 clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def _lcg(state: Int64) -> Int64:
    return state * Int64(6364136223846793005) + Int64(1442695040888963407)


def _median(mut xs: List[Int]) -> Int:
    for i in range(1, len(xs)):
        var v = xs[i]
        var j = i - 1
        while j >= 0 and xs[j] > v:
            xs[j + 1] = xs[j]
            j -= 1
        xs[j + 1] = v
    return xs[len(xs) // 2]


def _wbytes(kind: Int, rows: Int, cols: Int) -> Int:
    if kind == 0:
        return rows * (cols // 32) * 34
    if kind == 1:
        return rows * (cols // 256) * 144
    if kind == 2:
        return rows * (cols // 256) * 210
    if kind == 3:
        return rows * (cols // 256) * 176
    if kind == 4:
        return rows * (cols // 256) * 66
    if kind == 5:
        return rows * (cols // 256) * 50
    if kind == 6:
        return rows * (cols // 256) * 98
    return rows * (cols // 32) * 18


def _name(kind: Int) -> String:
    if kind == 0:
        return "q8_0_gemv"
    if kind == 1:
        return "q4k_gemv"
    if kind == 2:
        return "q6k_gemv"
    if kind == 3:
        return "q5k_gemv"
    if kind == 4:
        return "iq2xxs_gemv"
    if kind == 5:
        return "iq1s_gemv"
    if kind == 6:
        return "iq3xxs_gemv"
    return "iq4nl_gemv"


def _dispatch(kind: Int, w: VulkanAllocation, x: VulkanAllocation, y: VulkanAllocation, g: VulkanAllocation, rows: Int, cols: Int) raises:
    if kind == 0:
        VulkanGemv.q8_0_gemv(w, x, y, rows, cols)
    elif kind == 1:
        VulkanBuffers.q4k_gemv(w, x, y, cols, rows)
    elif kind == 2:
        VulkanGemv.q6_k_gemv(w, x, y, rows, cols)
    elif kind == 3:
        VulkanGemv.q5_k_gemv(w, x, y, rows, cols)
    elif kind == 4:
        VulkanGemv.iq2_xxs_gemv(w, x, y, g, rows, cols)
    elif kind == 5:
        VulkanGemv.iq1_s_gemv(w, x, y, g, rows, cols)
    elif kind == 6:
        VulkanGemv.iq3_xxs_gemv(w, x, y, g, rows, cols)
    else:
        VulkanGemv.iq4_nl_gemv(w, x, y, rows, cols)


def _grid(kind: Int) raises -> VulkanAllocation:
    var host = alloc[UInt16](2048)
    for i in range(2048):
        host.unsafe_store(i, UInt16(0))
    iq_grid_materialize(kind, host)
    var a = VulkanBuffers.allocate(4096)
    var p = VulkanBuffers.map(a)
    var bytes = host.unsafe_bitcast[UInt8]()
    for i in range(4096):
        p.unsafe_store(i, bytes.unsafe_load(i))
    VulkanBuffers.unmap(a)
    host.unsafe_free()
    return a^


def _count(kind: Int) -> Int:
    if kind == 0:
        return VulkanGemv.dispatch_count()
    if kind == 1:
        return VulkanBuffers.q4k_gemv_dispatch_count()
    if kind == 2:
        return VulkanGemv.q6_dispatch_count()
    if kind == 3:
        return VulkanGemv.q5_dispatch_count()
    if kind == 4:
        return VulkanGemv.iq2xxs_dispatch_count()
    if kind == 5:
        return VulkanGemv.iq1s_dispatch_count()
    if kind == 6:
        return VulkanGemv.iq3xxs_dispatch_count()
    return VulkanGemv.iq4nl_dispatch_count()


def _time_gemv(kind: Int, rows: Int, cols: Int, reps: Int) raises:
    var wb = _wbytes(kind, rows, cols)
    var w = VulkanBuffers.allocate(wb)
    var x = VulkanBuffers.allocate(cols * 4)
    var y = VulkanBuffers.allocate(rows * 4)
    var gk = 16 if kind == 4 else (19 if kind == 5 else 18)
    var g = _grid(gk)
    var pw = VulkanBuffers.map(w)
    var s = Int64(0xA073 + kind)
    for i in range(wb):
        s = _lcg(s + Int64(i & 1023))
        pw.unsafe_store(i, UInt8((s >> 33) & 0xFF))
    VulkanBuffers.unmap(w)
    var px = VulkanBuffers.map(x)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(cols):
        fx.unsafe_store(i, Float32((i * 73 + 19) % 997) * Float32(0.002) - Float32(0.997))
    VulkanBuffers.unmap(x)
    for _ in range(2):
        _dispatch(kind, w, x, y, g, rows, cols)
    var before = _count(kind)
    var times = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        _dispatch(kind, w, x, y, g, rows, cols)
        times.append(monotonic_ns() - t0)
    var after = _count(kind)
    var med = _median(times)
    var gbs = Float64(wb) / Float64(med)
    print(
        "A073_GEMV kernel=" + _name(kind) + " rows=" + String(rows)
        + " cols=" + String(cols) + " median_ns=" + String(med)
        + " weight_GBps=" + String(gbs)
        + " dispatches=" + String(after - before)
    )
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)
    VulkanBuffers.free(g)


def _time_gemm(f32: Bool, rows: Int, cols: Int, tokens: Int, reps: Int) raises:
    var wb = rows * cols * 4
    if not f32:
        wb = rows * (cols // 32) * 34
    var w = VulkanBuffers.allocate(wb)
    var x = VulkanBuffers.allocate(tokens * cols * 4)
    var y = VulkanBuffers.allocate(tokens * rows * 4)
    var pw = VulkanBuffers.map(w)
    var s = Int64(0xA068)
    for i in range(wb):
        s = _lcg(s + Int64(i & 1023))
        pw.unsafe_store(i, UInt8((s >> 33) & 0xFF))
    VulkanBuffers.unmap(w)
    var px = VulkanBuffers.map(x)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(tokens * cols):
        fx.unsafe_store(i, Float32((i * 31 + 7) % 499) * Float32(0.004) - Float32(0.998))
    VulkanBuffers.unmap(x)
    for _ in range(2):
        if f32:
            VulkanGemm.f32_gemm(w, x, y, rows, cols, tokens)
        else:
            VulkanGemm.q8_0_gemm(w, x, y, rows, cols, tokens)
    var before = VulkanGemm.f32_dispatch_count() if f32 else VulkanGemm.q8_dispatch_count()
    var times = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        if f32:
            VulkanGemm.f32_gemm(w, x, y, rows, cols, tokens)
        else:
            VulkanGemm.q8_0_gemm(w, x, y, rows, cols, tokens)
        times.append(monotonic_ns() - t0)
    var after = VulkanGemm.f32_dispatch_count() if f32 else VulkanGemm.q8_dispatch_count()
    var med = _median(times)
    var nm = "f32_gemm" if f32 else "q8_0_gemm"
    print(
        "A073_GEMM kernel=" + nm + " rows=" + String(rows)
        + " cols=" + String(cols) + " tokens=" + String(tokens)
        + " median_ns=" + String(med)
        + " dispatches=" + String(after - before)
    )
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)


def main() raises:
    if not VulkanBuffers.runtime_available() or not VulkanBuffers.dispatch_available():
        raise Error("A073 bench: Vulkan dispatch unavailable (fail-closed)")
    var info = VulkanBuffers.device_info()
    if info.vendor_id != 0x1002 or info.device_type == 4:
        raise Error("A073 bench: selected device is not the AMD iGPU")
    if not VulkanBuffers.device_name_is_radv():
        raise Error("A073 bench: selected device is not RADV (llvmpipe refused)")
    print("A073_DEVICE vendor=" + String(info.vendor_id) + " RADV=1")
    for kind in range(8):
        _time_gemv(kind, 2048, 4096, 25)
    _time_gemm(True, 1024, 1024, 64, 25)
    _time_gemm(False, 1024, 1024, 64, 25)
    print("A073_WAVE32_BENCH: PASS")
