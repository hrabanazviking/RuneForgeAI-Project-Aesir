"""A-088 bench/probe: HIP zero-copy (managed memory) measurement
vs the Vulkan weight-residency path (A-064).

Standalone proof (not an E-MASTER case - timing assertions do
not belong in the suite; A-085 doc+bench precedent). Three
allocation paths measured at ONE weight-scale size
(N = 16,777,216 Float32 = 64 MiB per buffer) with identical
CPU-side code, on the real gfx1151 device:
  hip_managed   - ZeroCopy HIP managed (hipMallocManaged,
                  A-008/A-019 default): GPU op hip_transform
                  (dst = src*2+1, traffic 2*N*4 bytes).
  vk_residency  - GpuWeightResidency.resident_allocate (A-064:
                  DEVICE_LOCAL|HOST_VISIBLE|HOST_COHERENT
                  unified type): GPU op vec_add (c = a+b,
                  traffic 3*N*4 bytes).
  vk_cached     - VulkanBuffers.allocate_cached (A-019
                  HOST_CACHED coherent type): same vec_add.
Common denominators (identical CPU code, head-to-head fair):
allocation median, CPU write GB/s, CPU read GB/s (8-accumulator
checksum scan, the A-008 ruler fix). GPU kernel numbers are
bandwidth-normalised per path but the kernels differ - they are
reported path-specific, never as a kernel head-to-head
(comparator-artifact law). A residency section then runs
repeated Q8_0 GEMV dispatches against ONE A-064 resident
allocation: dispatch counter advances by exactly the rep count
while residency accounting stays byte-identical and the
sequential CPU oracle holds (the A-064 proof, timed).
Device-execution evidence (law 6): HIP - device_count >= 1,
mem_info total, kernel launch counter delta with memcpy
counter at exactly 0. Vulkan - vendor 0x1002 + RADV asserted
(llvmpipe refused), type flags per path, copy_call_count 0,
GEMV dispatch counter delta exact. Fail-closed throughout.
"""
from std.ffi import external_call
from std.memory import Pointer
from core.zero_copy import ZeroCopy, BACKEND_HIP_MANAGED
from core.hip_memory import HipMemory
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_gemv import VulkanGemv
from core.gpu_weight_residency import GpuWeightResidency


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A088 clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def _median(mut xs: List[Int]) -> Int:
    for i in range(1, len(xs)):
        var v = xs[i]
        var j = i - 1
        while j >= 0 and xs[j] > v:
            xs[j + 1] = xs[j]
            j -= 1
        xs[j + 1] = v
    return xs[len(xs) // 2]


def _fa(i: Int) -> Float32:
    return Float32(i & 1023) * Float32(0.5) - Float32(100.0)


def _fb(i: Int) -> Float32:
    return Float32((i >> 4) & 511) * Float32(0.25) + Float32(3.0)


comptime _N = 16777216
comptime _REPS = 7

def _cpu_write(p: Pointer[Float32, MutUntrackedOrigin], which: Int) raises -> Int:
    var t0 = monotonic_ns()
    for i in range(_N):
        if which == 0:
            p.unsafe_store(i, _fa(i))
        else:
            p.unsafe_store(i, _fb(i))
    return monotonic_ns() - t0


def _cpu_read_sum(p: Pointer[Float32, MutUntrackedOrigin]) raises -> Float32:
    var a0: Float32 = 0.0
    var a1: Float32 = 0.0
    var a2: Float32 = 0.0
    var a3: Float32 = 0.0
    var a4: Float32 = 0.0
    var a5: Float32 = 0.0
    var a6: Float32 = 0.0
    var a7: Float32 = 0.0
    var i = 0
    while i + 8 <= _N:
        a0 += p.unsafe_load(i)
        a1 += p.unsafe_load(i + 1)
        a2 += p.unsafe_load(i + 2)
        a3 += p.unsafe_load(i + 3)
        a4 += p.unsafe_load(i + 4)
        a5 += p.unsafe_load(i + 5)
        a6 += p.unsafe_load(i + 6)
        a7 += p.unsafe_load(i + 7)
        i += 8
    while i < _N:
        a0 += p.unsafe_load(i)
        i += 1
    return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7


def _gbps(bytes_moved: Int, ns: Int) -> Float64:
    if ns <= 0:
        return Float64(0.0)
    return Float64(bytes_moved) / Float64(ns)


def _hip_path() raises:
    var bytes = _N * 4
    var alloc_times = List[Int]()
    for _ in range(3):
        var t0 = monotonic_ns()
        var tmp = ZeroCopy.allocate(bytes, BACKEND_HIP_MANAGED)
        alloc_times.append(monotonic_ns() - t0)
        ZeroCopy.free(tmp)
    var src = ZeroCopy.allocate(bytes, BACKEND_HIP_MANAGED)
    var dst = ZeroCopy.allocate(bytes, BACKEND_HIP_MANAGED)
    var ps = ZeroCopy.cpu_ptr(src)
    var fs = ps.unsafe_bitcast[Float32]()
    var write_times = List[Int]()
    for _ in range(3):
        write_times.append(_cpu_write(fs, 0))
    var pd = ZeroCopy.cpu_ptr(dst)
    var fd = pd.unsafe_bitcast[Float32]()
    for i in range(_N):
        fd.unsafe_store(i, Float32(-9999.0))
    var c0 = ZeroCopy.counters()
    for _ in range(2):
        ZeroCopy.hip_transform(dst, src, _N)
    var gpu_times = List[Int]()
    for _ in range(_REPS):
        var t0 = monotonic_ns()
        ZeroCopy.hip_transform(dst, src, _N)
        gpu_times.append(monotonic_ns() - t0)
    var c1 = ZeroCopy.counters()
    var bad = 0
    for i in range(_N):
        if fd.unsafe_load(i) != _fa(i) * Float32(2.0) + Float32(1.0):
            bad += 1
    var read_times = List[Int]()
    var sums = List[Float32]()
    for _ in range(3):
        var t0 = monotonic_ns()
        sums.append(_cpu_read_sum(fd))
        read_times.append(monotonic_ns() - t0)
    print(
        "A088_PATH path=hip_managed bytes=" + String(bytes)
        + " alloc_median_ns=" + String(_median(alloc_times))
        + " cpu_write_median_ns=" + String(_median(write_times))
        + " cpu_write_GBps=" + String(_gbps(bytes, _median(write_times)))
        + " gpu_median_ns=" + String(_median(gpu_times))
        + " gpu_traffic_GBps=" + String(_gbps(2 * bytes, _median(gpu_times)))
        + " cpu_read_median_ns=" + String(_median(read_times))
        + " cpu_read_GBps=" + String(_gbps(bytes, _median(read_times)))
        + " launches_delta=" + String(c1.hip_kernel_launches - c0.hip_kernel_launches)
        + " memcpy_calls=" + String(c1.hip_memcpy_calls)
        + " bad=" + String(bad)
        + " read_sum=" + String(sums[0])
    )
    if bad != 0:
        raise Error("HIP transform oracle mismatch")
    if c1.hip_memcpy_calls != 0:
        raise Error("HIP memcpy counter moved on zero-copy path")
    if c1.hip_kernel_launches - c0.hip_kernel_launches != 2 + _REPS:
        raise Error("HIP launch counter delta wrong")
    ZeroCopy.free(src)
    ZeroCopy.free(dst)

def _vk_path(name: String, cached: Bool) raises:
    var bytes = _N * 4
    var alloc_times = List[Int]()
    for _ in range(3):
        var t0 = monotonic_ns()
        var tmp: VulkanAllocation
        if cached:
            tmp = VulkanBuffers.allocate_cached(bytes)
        else:
            tmp = GpuWeightResidency.resident_allocate(bytes)
        alloc_times.append(monotonic_ns() - t0)
        VulkanBuffers.free(tmp)
    var a: VulkanAllocation
    var b: VulkanAllocation
    var c: VulkanAllocation
    if cached:
        a = VulkanBuffers.allocate_cached(bytes)
        b = VulkanBuffers.allocate_cached(bytes)
        c = VulkanBuffers.allocate_cached(bytes)
    else:
        a = GpuWeightResidency.resident_allocate(bytes)
        b = GpuWeightResidency.resident_allocate(bytes)
        c = GpuWeightResidency.resident_allocate(bytes)
    var flags = VulkanBuffers.buffer_type_flags(a)
    var pa = VulkanBuffers.map(a)
    var fa = pa.unsafe_bitcast[Float32]()
    var write_times = List[Int]()
    for _ in range(3):
        write_times.append(_cpu_write(fa, 0))
    VulkanBuffers.unmap(a)
    var pb = VulkanBuffers.map(b)
    var fb = pb.unsafe_bitcast[Float32]()
    for i in range(_N):
        fb.unsafe_store(i, _fb(i))
    VulkanBuffers.unmap(b)
    var pc = VulkanBuffers.map(c)
    var fc = pc.unsafe_bitcast[Float32]()
    for i in range(_N):
        fc.unsafe_store(i, Float32(-9999.0))
    VulkanBuffers.unmap(c)
    var acct0 = GpuWeightResidency.accounting()
    for _ in range(2):
        VulkanBuffers.vec_add(a, b, c, _N)
    var gpu_times = List[Int]()
    for _ in range(_REPS):
        var t0 = monotonic_ns()
        VulkanBuffers.vec_add(a, b, c, _N)
        gpu_times.append(monotonic_ns() - t0)
    var acct1 = GpuWeightResidency.accounting()
    var pc2 = VulkanBuffers.map(c)
    var fc2 = pc2.unsafe_bitcast[Float32]()
    var bad = 0
    for i in range(_N):
        if fc2.unsafe_load(i) != _fa(i) + _fb(i):
            bad += 1
    var read_times = List[Int]()
    var sums = List[Float32]()
    for _ in range(3):
        var t0 = monotonic_ns()
        sums.append(_cpu_read_sum(fc2))
        read_times.append(monotonic_ns() - t0)
    VulkanBuffers.unmap(c)
    print(
        "A088_PATH path=" + name + " bytes=" + String(bytes)
        + " type_flags=" + String(flags)
        + " alloc_median_ns=" + String(_median(alloc_times))
        + " cpu_write_median_ns=" + String(_median(write_times))
        + " cpu_write_GBps=" + String(_gbps(bytes, _median(write_times)))
        + " gpu_median_ns=" + String(_median(gpu_times))
        + " gpu_traffic_GBps=" + String(_gbps(3 * bytes, _median(gpu_times)))
        + " cpu_read_median_ns=" + String(_median(read_times))
        + " cpu_read_GBps=" + String(_gbps(bytes, _median(read_times)))
        + " vk_copy_calls=" + String(acct1.upload_calls)
        + " acct_unchanged=" + String(GpuWeightResidency.unchanged(acct0, acct1))
        + " bad=" + String(bad)
        + " read_sum=" + String(sums[0])
    )
    if bad != 0:
        raise Error("vec_add oracle mismatch on " + name)
    if acct1.upload_calls != 0:
        raise Error("Vulkan copy counter moved on " + name)
    if not GpuWeightResidency.unchanged(acct0, acct1):
        raise Error("residency accounting changed across repeats on " + name)
    VulkanBuffers.free(a)
    VulkanBuffers.free(b)
    VulkanBuffers.free(c)

comptime _GROWS = 64
comptime _GCOLS = 1024
comptime _GWBYTES = _GROWS * (_GCOLS // 32) * 34


def _resident_gemv() raises:
    var w = GpuWeightResidency.resident_allocate(_GWBYTES)
    var xs = List[Float32]()
    var state: UInt64 = 0xA088
    var pw = VulkanBuffers.map(w)
    for blk in range(_GROWS * (_GCOLS // 32)):
        state = state * 6364136223846793005 + 1442695040888963407
        var s = Float32(0.002) + Float32((state >> 11) & 0xFFFFFF) / Float32(16777216.0) * Float32(0.018)
        pw.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(s))
        for lane in range(32):
            state = state * 6364136223846793005 + 1442695040888963407
            pw.unsafe_store(blk * 34 + 2 + lane, UInt8((state >> 11) & 0xFF))
    VulkanBuffers.unmap(w)
    for i in range(_GCOLS):
        xs.append(Float32((i * 73 + 19) & 1023) * Float32(0.002) - Float32(0.997))
    var x = VulkanBuffers.allocate(_GCOLS * 4)
    var px = VulkanBuffers.map(x)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(_GCOLS):
        fx.unsafe_store(i, xs[i])
    VulkanBuffers.unmap(x)
    var y = VulkanBuffers.allocate(_GROWS * 4)
    var want = List[Float32]()
    var qw = VulkanBuffers.map(w)
    for r in range(_GROWS):
        var acc: Float32 = 0.0
        for blk in range(_GCOLS // 32):
            var base = (r * (_GCOLS // 32) + blk) * 34
            var scale = qw.unsafe_bitcast[Float16]().unsafe_load((r * (_GCOLS // 32) + blk) * 17).cast[DType.float32]()
            for lane in range(32):
                var raw = Int(qw.unsafe_load(base + 2 + lane))
                var q = raw - 256 if raw >= 128 else raw
                acc += scale * Float32(q) * xs[blk * 32 + lane]
        want.append(acc)
    VulkanBuffers.unmap(w)
    var acct0 = GpuWeightResidency.accounting()
    var d0 = VulkanGemv.dispatch_count()
    for _ in range(2):
        VulkanGemv.q8_0_gemv(w, x, y, _GROWS, _GCOLS)
    var gpu_times = List[Int]()
    for _ in range(_REPS):
        var t0 = monotonic_ns()
        VulkanGemv.q8_0_gemv(w, x, y, _GROWS, _GCOLS)
        gpu_times.append(monotonic_ns() - t0)
    var d1 = VulkanGemv.dispatch_count()
    var acct1 = GpuWeightResidency.accounting()
    var qy = VulkanBuffers.map(y)
    var gy = qy.unsafe_bitcast[Float32]()
    var worst: Float32 = 0.0
    for i in range(_GROWS):
        var d = gy.unsafe_load(i) - want[i]
        if d < 0:
            d = -d
        if d > worst:
            worst = d
    VulkanBuffers.unmap(y)
    print(
        "A088_RESIDENT_GEMV rows=" + String(_GROWS) + " cols=" + String(_GCOLS)
        + " weight_bytes=" + String(_GWBYTES)
        + " dispatch_delta=" + String(d1 - d0)
        + " gpu_median_ns=" + String(_median(gpu_times))
        + " oracle_worst_max_abs=" + String(worst)
        + " acct_unchanged=" + String(GpuWeightResidency.unchanged(acct0, acct1))
        + " vk_copy_calls=" + String(acct1.upload_calls)
    )
    if d1 - d0 != 2 + _REPS:
        raise Error("GEMV dispatch delta wrong")
    if worst > Float32(0.001):
        raise Error("resident GEMV oracle parity exceeded A-064 bound")
    if not GpuWeightResidency.unchanged(acct0, acct1):
        raise Error("residency accounting changed across GEMV repeats")
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)
    VulkanBuffers.free(w)

def main() raises:
    if not ZeroCopy.hip_available():
        raise Error("A088 bench: HIP zero-copy runtime absent (fail-closed)")
    var hip_count = HipMemory.device_count()
    var info = HipMemory.mem_info()
    print(
        "A088_HIP_DEVICE count=" + String(hip_count)
        + " total_bytes=" + String(info.total_bytes)
        + " free_bytes=" + String(info.free_bytes)
    )
    if hip_count < 1:
        raise Error("A088 bench: no HIP device (fail-closed)")
    if not VulkanBuffers.runtime_available() or not VulkanBuffers.dispatch_available():
        raise Error("A088 bench: Vulkan dispatch absent (fail-closed)")
    var vinfo = VulkanBuffers.device_info()
    if vinfo.vendor_id != 0x1002 or vinfo.device_type == 4:
        raise Error("A088 bench: not the RADV gfx1151 device (fail-closed)")
    if not VulkanBuffers.device_name_is_radv():
        raise Error("A088 bench: device is not RADV (llvmpipe refused)")
    print("A088_VK_DEVICE vendor=0x1002 radv=true type=" + String(vinfo.device_type))
    _hip_path()
    _vk_path("vk_residency", False)
    _vk_path("vk_cached", True)
    _resident_gemv()
    print("A088_ZERO_COPY_RESIDENCY_BENCH: PASS")
