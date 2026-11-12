"""Vulkan compute dispatch smoke (A-015): one trivial SPIR-V kernel
(vector add) dispatched through the A-014 VulkanBuffers gateway on
the A-013/A-014 Vulkan context and read back, byte-exact against a
CPU oracle at several sizes including non-multiples of the 256-wide
workgroup.

The kernel is aesir_engine/shaders/vec_add.comp, compiled by
glslangValidator and embedded in the buffer shim; the element count
travels as a push constant and guards every invocation, so the tail
workgroup of a non-multiple size writes nothing out of bounds.

Present/absent discipline matches A-014: on purpleraider the selected
device must be the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is
explicitly refused by the identity check - and every case verifies
real device execution; on a host without that device the cases
assert fail-closed behaviour and pass as honest-absent.
"""
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation


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


def _fa(i: Int) -> Float32:
    return Float32((i * 37 + 11) % 997) * Float32(0.5) - Float32(100.0)


def _fb(i: Int) -> Float32:
    return Float32((i * 91 + 7) % 613) * Float32(0.25) + Float32(3.0)


def _run_vec_add(n: Int) raises:
    var bytes = n * 4
    var a = VulkanBuffers.allocate(bytes)
    var b = VulkanBuffers.allocate(bytes)
    var c = VulkanBuffers.allocate(bytes)
    var pa = VulkanBuffers.map(a)
    var fa = pa.unsafe_bitcast[Float32]()
    for i in range(n):
        fa.unsafe_store(i, _fa(i))
    VulkanBuffers.unmap(a)
    var pb = VulkanBuffers.map(b)
    var fb = pb.unsafe_bitcast[Float32]()
    for i in range(n):
        fb.unsafe_store(i, _fb(i))
    VulkanBuffers.unmap(b)
    var pc = VulkanBuffers.map(c)
    var fc = pc.unsafe_bitcast[Float32]()
    for i in range(n):
        fc.unsafe_store(i, Float32(-9999.0))
    VulkanBuffers.unmap(c)
    VulkanBuffers.vec_add(a, b, c, n)
    var qc = VulkanBuffers.map(c)
    var gc = qc.unsafe_bitcast[Float32]()
    for i in range(n):
        var expected = _fa(i) + _fb(i)
        var got = gc.unsafe_load(i)
        if got != expected:
            VulkanBuffers.unmap(c)
            VulkanBuffers.free(a)
            VulkanBuffers.free(b)
            VulkanBuffers.free(c)
            raise Error(
                "vec_add mismatch at n=" + String(n) + " index "
                + String(i) + ": got " + String(got) + " want "
                + String(expected)
            )
    VulkanBuffers.unmap(c)
    VulkanBuffers.free(a)
    VulkanBuffers.free(b)
    VulkanBuffers.free(c)


def test_vulkan_dispatch_vec_add_oracle() raises:
    print("--- Testing Vulkan vec_add dispatch oracle (A-015) ---")
    if not _vk_present():
        var rejected = False
        try:
            var a = VulkanBuffers.allocate(4096)
            VulkanBuffers.free(a)
        except:
            rejected = True
        if not rejected:
            raise Error("Vulkan unavailable but allocate succeeded (fabricated)")
        print("Vulkan UNAVAILABLE: dispatch fail-closed: PASS (honest-absent)")
        return
    var sizes = [1, 7, 255, 256, 257, 1000, 4097, 65537]
    for s in range(len(sizes)):
        _run_vec_add(sizes[s])
    print(
        "Vulkan vec_add dispatch (n=1/7/255/256/257/1000/4097/65537,"
        " incl. non-multiples of workgroup 256, RADV device, oracle"
        " exact at every element): PASS"
    )


def test_vulkan_dispatch_rejection() raises:
    print("--- Testing Vulkan dispatch rejection (A-015) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection cases not run (honest-absent)")
        return
    var a = VulkanBuffers.allocate(1024)
    var b = VulkanBuffers.allocate(1024)
    var c = VulkanBuffers.allocate(1024)
    var zero_rejected = False
    try:
        VulkanBuffers.vec_add(a, b, c, 0)
    except:
        zero_rejected = True
    if not zero_rejected:
        raise Error("vec_add accepted a zero element count")
    var oversize_rejected = False
    try:
        VulkanBuffers.vec_add(a, b, c, 300)
    except:
        oversize_rejected = True
    if not oversize_rejected:
        raise Error("vec_add accepted an element count beyond the buffers")
    var bogus = VulkanAllocation(9999, 1024, 1024, 16, 3)
    var bogus_rejected = False
    try:
        VulkanBuffers.vec_add(a, b, bogus, 16)
    except:
        bogus_rejected = True
    if not bogus_rejected:
        raise Error("vec_add accepted a bogus buffer id")
    VulkanBuffers.free(a)
    VulkanBuffers.free(b)
    VulkanBuffers.free(c)
    print("Vulkan dispatch rejection (zero n, oversize n, bogus id): PASS")


def test_vulkan_dispatch_no_leak() raises:
    print("--- Testing Vulkan dispatch no-leak (A-015) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: no-leak case not run (honest-absent)")
        return
    _run_vec_add(64)
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    for _ in range(50):
        _run_vec_add(257)
    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("vec_add loop leaked device bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("vec_add loop leaked buffers")
    print("Vulkan dispatch no-leak (50 dispatches at n=257, accounting exact): PASS")
