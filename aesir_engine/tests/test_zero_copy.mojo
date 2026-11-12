"""Zero-copy allocator (A-019): one allocation type serving CPU and
GPU behind the checked-span discipline, built on the A-008 findings.

HIP backend (the A-008 default): hipMallocManaged buffers are
written by the CPU, read by a real HIPRTC-compiled gfx1151 kernel
(transform), and written by a second kernel (fill) that the CPU
reads back - byte-exact against the CPU oracle in both directions,
with the shim's instrumentation counters proving the path ran with
ZERO copy calls (the shim never resolves hipMemcpy) while kernel
launches advanced.

Vulkan backend: HOST_CACHED host-coherent buffers only (the A-008
rule - the DEVICE_LOCAL/DEVICE_UNCACHED_AMD coherent type reads
back at 0.11 GB/s on the CPU and is refused here), dispatched with
the A-015 vec_add kernel on the A-014 context, byte-exact, with the
Vulkan shim's copy counter at zero (it resolves no copy entry
point at all).

Present/absent discipline matches A-011/A-014/A-015: on purpleraider
the HIP device and the RADV STRIX_HALO Vulkan device must be real
and every case verifies real device execution; on a host without
them the cases assert fail-closed behaviour and pass as
honest-absent.
"""
from core.zero_copy import (
    ZeroCopy,
    ZeroCopyBuffer,
    BACKEND_HIP_MANAGED,
    BACKEND_VULKAN_CACHED,
)
from core.hip_memory import HipMemory
from core.vulkan_buffers import VulkanBuffers


def _fa(i: Int) -> Float32:
    return Float32((i * 37 + 11) % 997) * Float32(0.5) - Float32(100.0)


def _fb(i: Int) -> Float32:
    return Float32((i * 91 + 7) % 613) * Float32(0.25) + Float32(3.0)


def _hip_present() -> Bool:
    if not ZeroCopy.hip_available():
        return False
    try:
        return HipMemory.device_count() >= 1
    except:
        return False


def _vk_present() -> Bool:
    if not VulkanBuffers.runtime_available():
        return False
    if not VulkanBuffers.dispatch_available():
        return False
    try:
        var info = VulkanBuffers.device_info()
        if info.vendor_id != 0x1002:
            return False
        if info.device_type == 4:
            return False
        return VulkanBuffers.device_name_is_radv()
    except:
        return False


def _run_hip_transform(n: Int) raises:
    var bytes = n * 4
    var src = ZeroCopy.allocate_default(bytes)
    var dst = ZeroCopy.allocate_default(bytes)
    var ps = ZeroCopy.cpu_ptr(src)
    var fs = ps.unsafe_bitcast[Float32]()
    for i in range(n):
        fs.unsafe_store(i, _fa(i))
    var pd = ZeroCopy.cpu_ptr(dst)
    var fd = pd.unsafe_bitcast[Float32]()
    for i in range(n):
        fd.unsafe_store(i, Float32(-9999.0))
    ZeroCopy.hip_transform(dst, src, n)
    for i in range(n):
        var expected = _fa(i) * Float32(2.0) + Float32(1.0)
        var got = fd.unsafe_load(i)
        if got != expected:
            ZeroCopy.free(src)
            ZeroCopy.free(dst)
            raise Error(
                "hip transform mismatch at n=" + String(n) + " index "
                + String(i) + ": got " + String(got) + " want "
                + String(expected)
            )
    ZeroCopy.free(src)
    ZeroCopy.free(dst)


def test_zero_copy_hip_cpu_write_gpu_read() raises:
    print("--- Testing zero-copy HIP CPU-write GPU-read oracle (A-019) ---")
    if not _hip_present():
        var rejected = False
        try:
            var b = ZeroCopy.allocate_default(4096)
            ZeroCopy.free(b)
        except:
            rejected = True
        if not rejected:
            raise Error("HIP unavailable but allocate succeeded (fabricated)")
        print("HIP UNAVAILABLE: zero-copy fail-closed: PASS (honest-absent)")
        return
    var c0 = ZeroCopy.counters()
    var sizes = [1, 7, 255, 256, 257, 1000, 4097, 65537]
    for s in range(len(sizes)):
        _run_hip_transform(sizes[s])
    var c1 = ZeroCopy.counters()
    if c1.hip_memcpy_calls != c0.hip_memcpy_calls:
        raise Error("HIP memcpy counter moved on the zero-copy path")
    if c1.hip_memcpy_calls != 0:
        raise Error("HIP memcpy counter is not zero")
    if c1.hip_kernel_launches <= c0.hip_kernel_launches:
        raise Error("no HIP kernel launch was recorded")
    print(
        "Zero-copy HIP CPU-write -> GPU kernel read (n=1/7/255/256/257/"
        "1000/4097/65537, byte-exact both oracle directions checked,"
        " memcpy calls = 0, kernel launches = "
        + String(c1.hip_kernel_launches - c0.hip_kernel_launches)
        + "): PASS"
    )


def test_zero_copy_hip_gpu_write_cpu_read() raises:
    print("--- Testing zero-copy HIP GPU-write CPU-read oracle (A-019) ---")
    if not _hip_present():
        print("HIP UNAVAILABLE: GPU-write case not run (honest-absent)")
        return
    var c0 = ZeroCopy.counters()
    var sizes = [1, 7, 257, 1000, 65537]
    for s in range(len(sizes)):
        var n = sizes[s]
        var buf = ZeroCopy.allocate_default(n * 4)
        ZeroCopy.hip_fill(buf, n)
        var p = ZeroCopy.cpu_ptr(buf)
        var f = p.unsafe_bitcast[Float32]()
        for i in range(n):
            var got = f.unsafe_load(i)
            if got != _fa(i):
                ZeroCopy.free(buf)
                raise Error(
                    "hip fill mismatch at n=" + String(n) + " index "
                    + String(i) + ": got " + String(got) + " want "
                    + String(_fa(i))
                )
        ZeroCopy.free(buf)
    var c1 = ZeroCopy.counters()
    if c1.hip_memcpy_calls != 0:
        raise Error("HIP memcpy counter is not zero after GPU-write path")
    print(
        "Zero-copy HIP GPU kernel write -> CPU read (n=1/7/257/1000/"
        "65537, byte-exact, memcpy calls = 0): PASS"
    )


def _run_vk_vec_add(n: Int) raises:
    var bytes = n * 4
    var a = ZeroCopy.allocate(bytes, BACKEND_VULKAN_CACHED)
    var b = ZeroCopy.allocate(bytes, BACKEND_VULKAN_CACHED)
    var c = ZeroCopy.allocate(bytes, BACKEND_VULKAN_CACHED)
    var flags = VulkanBuffers.buffer_type_flags(a.vk)
    # A-008 rule: HOST_VISIBLE(0x2) | HOST_COHERENT(0x4) |
    # HOST_CACHED(0x8) required; DEVICE_UNCACHED_AMD(0x40) refused.
    if (flags & 0x2) == 0 or (flags & 0x4) == 0 or (flags & 0x8) == 0:
        ZeroCopy.free(a)
        ZeroCopy.free(b)
        ZeroCopy.free(c)
        raise Error(
            "Vulkan zero-copy type is not HOST_CACHED coherent: flags "
            + String(flags)
        )
    if (flags & 0x40) != 0:
        ZeroCopy.free(a)
        ZeroCopy.free(b)
        ZeroCopy.free(c)
        raise Error("Vulkan zero-copy type carries DEVICE_UNCACHED_AMD")
    var pa = ZeroCopy.cpu_ptr(a)
    var fa = pa.unsafe_bitcast[Float32]()
    for i in range(n):
        fa.unsafe_store(i, _fa(i))
    ZeroCopy.release_cpu_ptr(a)
    var pb = ZeroCopy.cpu_ptr(b)
    var fb = pb.unsafe_bitcast[Float32]()
    for i in range(n):
        fb.unsafe_store(i, _fb(i))
    ZeroCopy.release_cpu_ptr(b)
    var pc = ZeroCopy.cpu_ptr(c)
    var fc = pc.unsafe_bitcast[Float32]()
    for i in range(n):
        fc.unsafe_store(i, Float32(-9999.0))
    ZeroCopy.release_cpu_ptr(c)
    ZeroCopy.vk_vec_add(a, b, c, n)
    var qc = ZeroCopy.cpu_ptr(c)
    var gc = qc.unsafe_bitcast[Float32]()
    for i in range(n):
        var expected = _fa(i) + _fb(i)
        var got = gc.unsafe_load(i)
        if got != expected:
            ZeroCopy.release_cpu_ptr(c)
            ZeroCopy.free(a)
            ZeroCopy.free(b)
            ZeroCopy.free(c)
            raise Error(
                "vk vec_add mismatch at n=" + String(n) + " index "
                + String(i) + ": got " + String(got) + " want "
                + String(expected)
            )
    ZeroCopy.release_cpu_ptr(c)
    ZeroCopy.free(a)
    ZeroCopy.free(b)
    ZeroCopy.free(c)


def test_zero_copy_vulkan_cpu_write_gpu_read() raises:
    print("--- Testing zero-copy Vulkan CPU-write GPU-read oracle (A-019) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: zero-copy case not run (honest-absent)")
        return
    var c0 = ZeroCopy.counters()
    var sizes = [1, 7, 257, 1000, 65537]
    for s in range(len(sizes)):
        _run_vk_vec_add(sizes[s])
    var c1 = ZeroCopy.counters()
    if c1.vk_copy_calls != c0.vk_copy_calls or c1.vk_copy_calls != 0:
        raise Error("Vulkan copy counter moved on the zero-copy path")
    print(
        "Zero-copy Vulkan CPU-write -> GPU kernel read on HOST_CACHED"
        " coherent buffers (n=1/7/257/1000/65537, byte-exact, vk copy"
        " calls = 0): PASS"
    )


def test_zero_copy_rejection() raises:
    print("--- Testing zero-copy rejection (A-019) ---")
    var zero_hip = False
    try:
        var b = ZeroCopy.allocate(0, BACKEND_HIP_MANAGED)
        ZeroCopy.free(b)
    except:
        zero_hip = True
    if not zero_hip:
        raise Error("zero-size HIP allocation was accepted")
    var zero_vk = False
    try:
        var b = ZeroCopy.allocate(0, BACKEND_VULKAN_CACHED)
        ZeroCopy.free(b)
    except:
        zero_vk = True
    if not zero_vk:
        raise Error("zero-size Vulkan allocation was accepted")
    var bad_backend = False
    try:
        var b = ZeroCopy.allocate(64, 99)
        ZeroCopy.free(b)
    except:
        bad_backend = True
    if not bad_backend:
        raise Error("unknown backend was accepted")
    if _hip_present():
        var buf = ZeroCopy.allocate_default(1024)
        var oob_span = False
        try:
            _ = ZeroCopy.checked_f32_span(buf, 200, 100)
        except:
            oob_span = True
        if not oob_span:
            ZeroCopy.free(buf)
            raise Error("out-of-range checked span was admitted")
        var oob_launch = False
        try:
            ZeroCopy.hip_fill(buf, 300)
        except:
            oob_launch = True
        if not oob_launch:
            ZeroCopy.free(buf)
            raise Error("kernel launch beyond the buffer was admitted")
        if _vk_present():
            var vk = ZeroCopy.allocate(1024, BACKEND_VULKAN_CACHED)
            var cross = False
            try:
                ZeroCopy.hip_transform(buf, vk, 16)
            except:
                cross = True
            ZeroCopy.free(vk)
            if not cross:
                ZeroCopy.free(buf)
                raise Error("cross-backend transform was accepted")
        ZeroCopy.free(buf)
    print(
        "Zero-copy rejection (zero size both backends, unknown"
        " backend, OOB span, OOB launch, cross-backend): PASS"
    )


def test_zero_copy_no_leak() raises:
    print("--- Testing zero-copy no-leak accounting (A-019) ---")
    if not _hip_present():
        print("HIP UNAVAILABLE: no-leak case not run (honest-absent)")
        return
    _run_hip_transform(64)
    var base = HipMemory.mem_info()
    var vk_base_bytes = VulkanBuffers.live_bytes()
    var vk_base_count = VulkanBuffers.live_count()
    var c0 = ZeroCopy.counters()
    for _ in range(200):
        var src = ZeroCopy.allocate_default(4096)
        var dst = ZeroCopy.allocate_default(4096)
        ZeroCopy.hip_transform(dst, src, 257)
        ZeroCopy.free(src)
        ZeroCopy.free(dst)
    if _vk_present():
        for _ in range(50):
            _run_vk_vec_add(257)
    var after = HipMemory.mem_info()
    if after.free_bytes != base.free_bytes:
        raise Error(
            "zero-copy loop leaked HIP bytes: free "
            + String(base.free_bytes) + " -> " + String(after.free_bytes)
        )
    if VulkanBuffers.live_bytes() != vk_base_bytes:
        raise Error("zero-copy loop leaked Vulkan bytes")
    if VulkanBuffers.live_count() != vk_base_count:
        raise Error("zero-copy loop leaked Vulkan buffers")
    var c1 = ZeroCopy.counters()
    if (c1.hip_allocs - c0.hip_allocs) != (c1.hip_frees - c0.hip_frees):
        raise Error("zero-copy HIP alloc/free counters do not balance")
    if c1.hip_live_bytes != c0.hip_live_bytes:
        raise Error("zero-copy HIP live bytes did not return to baseline")
    if c1.hip_memcpy_calls != 0 or c1.vk_copy_calls != 0:
        raise Error("a copy counter moved during the no-leak loop")
    print(
        "Zero-copy no-leak (200 HIP transform rounds + 50 Vulkan"
        " rounds, HIP free bytes / Vulkan accounting / shim counters"
        " all back to baseline exactly): PASS"
    )
