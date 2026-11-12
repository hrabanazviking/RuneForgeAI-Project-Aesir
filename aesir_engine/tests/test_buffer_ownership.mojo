"""Buffer ownership law (A-022): adversarial tests for every buffer
type in the engine.

The law (aesir_engine/buffer_ownership.h, core/buffer_ownership.mojo,
ledger hidden_files/A022_LEDGER.md): exactly one owner per buffer;
hand-off tombstones the sender until the receiver claims; borrows
never own; a handle is valid only for its own kind, shim, device,
and generation. Every violation fails closed with a named taxonomy
error (MEM-004 USE_AFTER_FREE, MEM-005 DOUBLE_FREE, MEM-011
USE_AFTER_HANDOFF, MEM-012 CROSS_DEVICE_MISUSE, MEM-013
NON_OWNER_FREE, MEM-014 STALE_HANDLE, MEM-015
FREE_WITH_ACTIVE_BORROWS) - never a crash, never a silent double
free, and the shim's live-byte accounting returns to baseline after
every adversarial sequence.

Covered types: HIP allocations + pinned host + streams/events
(A-011/A-012), Vulkan buffers (A-014/A-015), ZeroCopy unified
buffers (A-019, both backends), and XRT buffer objects (A-016) at
the API-contract level (the probe has no Mojo wrapper; the contract
registry in core/buffer_ownership.mojo is the enforcement point
every future XRT wrapper routes through - no sudo, no ioctls).

Present/absent discipline matches A-011/A-014/A-019: on purpleraider
every device path is real and adversarially exercised; on a host
without the runtime the cases assert fail-closed behaviour and pass
as honest-absent.
"""
from std.memory.alloc import alloc
from core.hip_memory import HipMemory
from core.hip_transfer import HipTransfer, HipStream, HipEvent
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.zero_copy import (
    ZeroCopy,
    ZeroCopyBuffer,
    BACKEND_HIP_MANAGED,
)
from core.buffer_ownership import XrtBoOwnership, XrtBoHandle


def _hip_present() -> Bool:
    if not HipMemory.runtime_available():
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


def _refused_with(needle: String, error: Error) -> Bool:
    return needle in String(error)


def test_hip_buffer_ownership_adversarial() raises:
    print("--- Testing HIP buffer ownership adversarial (A-022) ---")
    if not _hip_present():
        var rejected = False
        try:
            var p = HipMemory.allocate(4096)
            HipMemory.free(p)
        except:
            rejected = True
        if not rejected:
            raise Error("HIP unavailable but allocate succeeded (fabricated)")
        print("HIP UNAVAILABLE: ownership fail-closed: PASS (honest-absent)")
        return
    # Warm-up absorbs the one-time HIP context retention, then the
    # registry baseline is exact.
    var warm = HipMemory.allocate(4096)
    HipMemory.free(warm)
    var base_bytes = HipMemory.live_bytes()
    var base_count = HipMemory.live_count()
    var v0 = HipMemory.ownership_violation_count()
    var host = alloc[UInt8](4096)
    for i in range(4096):
        host.unsafe_store(i, UInt8((i * 31 + 7) % 251))

    # Double-free (device + managed) refused with MEM-005.
    var p = HipMemory.allocate(4096)
    HipMemory.memcpy_host_to_device(p, host, 4096)
    HipMemory.free(p)
    var df = False
    try:
        HipMemory.free(p)
    except error:
        df = _refused_with("MEM-005", error)
    if not df:
        raise Error("HIP double-free was not refused with MEM-005")
    var m = HipMemory.allocate_managed(4096)
    HipMemory.free(m)
    var mdf = False
    try:
        HipMemory.free(m)
    except error:
        mdf = _refused_with("MEM-005", error)
    if not mdf:
        raise Error("HIP managed double-free was not refused with MEM-005")

    # Use-after-free through memcpy refused with MEM-004.
    var uaf = False
    try:
        HipMemory.memcpy_host_to_device(p, host, 4096)
    except error:
        uaf = _refused_with("MEM-004", error)
    if not uaf:
        raise Error("HIP use-after-free memcpy was not refused with MEM-004")

    # Foreign pointer free refused with MEM-013; the foreign
    # allocation itself is untouched and freed by its real owner.
    var foreign = False
    try:
        HipMemory.free(host)
    except error:
        foreign = _refused_with("MEM-013", error)
    if not foreign:
        raise Error("HIP free of a foreign pointer was not refused")

    # Cross-kind frees refused with MEM-012, buffers unharmed.
    var pinned = HipTransfer.host_allocate(4096)
    var kind1 = False
    try:
        HipMemory.free(pinned)
    except error:
        kind1 = _refused_with("MEM-012", error)
    if not kind1:
        raise Error("device-free of pinned host memory was not refused")
    var dev = HipMemory.allocate(4096)
    var kind2 = False
    try:
        HipTransfer.host_free(dev)
    except error:
        kind2 = _refused_with("MEM-012", error)
    if not kind2:
        raise Error("host-free of device memory was not refused")
    HipTransfer.host_free(pinned)
    HipMemory.free(dev)

    # Hand-off: sender use/free refused with MEM-011 until claim.
    var h = HipMemory.allocate(4096)
    HipMemory.handoff(h)
    var hof = False
    try:
        HipMemory.free(h)
    except error:
        hof = _refused_with("MEM-011", error)
    if not hof:
        raise Error("free after hand-off was not refused with MEM-011")
    var hou = False
    try:
        HipMemory.memcpy_host_to_device(h, host, 4096)
    except error:
        hou = _refused_with("MEM-011", error)
    if not hou:
        raise Error("use after hand-off was not refused with MEM-011")
    HipMemory.claim(h)
    HipMemory.memcpy_host_to_device(h, host, 4096)
    HipMemory.free(h)

    # Streams/events: a copied handle value is not a second owner.
    # The Mojo wrapper zeroes its own variable on destroy, so the
    # adversarial copy is fabricated from the raw handle - exactly
    # the aliasing the shim registry now refuses.
    var s = HipStream.create()
    var s_copy = HipStream(s.handle)
    s.destroy()
    var sdf = False
    try:
        s_copy.destroy()
    except error:
        sdf = _refused_with("MEM-005", error)
    if not sdf:
        raise Error("stream double-destroy was not refused with MEM-005")
    var suf = False
    try:
        s_copy.synchronize()
    except error:
        suf = _refused_with("MEM-004", error)
    if not suf:
        raise Error("stream use-after-destroy was not refused with MEM-004")
    var e = HipEvent.create()
    var e_copy = HipEvent(e.handle)
    e.destroy()
    var edf = False
    try:
        e_copy.destroy()
    except error:
        edf = _refused_with("MEM-005", error)
    if not edf:
        raise Error("event double-destroy was not refused with MEM-005")
    var euf = False
    try:
        e_copy.synchronize()
    except error:
        euf = _refused_with("MEM-004", error)
    if not euf:
        raise Error("event use-after-destroy was not refused with MEM-004")

    host.unsafe_free()
    if HipMemory.live_bytes() != base_bytes:
        raise Error("HIP ownership sequences leaked registry bytes")
    if HipMemory.live_count() != base_count:
        raise Error("HIP ownership sequences leaked registry allocations")
    if HipMemory.ownership_violation_count() <= v0:
        raise Error("HIP ownership violation counter did not advance")
    print(
        "HIP ownership adversarial (double-free MEM-005, use-after-"
        "free MEM-004, foreign MEM-013, cross-kind MEM-012, hand-off"
        " MEM-011, stream/event alias destroy, accounting baseline):"
        " PASS"
    )


def test_vulkan_buffer_ownership_adversarial() raises:
    print("--- Testing Vulkan buffer ownership adversarial (A-022) ---")
    if not _vk_present():
        var rejected = False
        try:
            var b = VulkanBuffers.allocate(4096)
            VulkanBuffers.free(b)
        except:
            rejected = True
        if not rejected:
            raise Error("Vulkan unavailable but allocate succeeded")
        print("Vulkan UNAVAILABLE: ownership fail-closed: PASS (honest-absent)")
        return
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    var v0 = VulkanBuffers.ownership_violation_count()

    # Double-free refused with MEM-005; use-after-free with MEM-004.
    var a = VulkanBuffers.allocate(4096)
    var a_slot = a.id % 4294967296
    var pa = VulkanBuffers.map(a)
    for i in range(1024):
        pa.unsafe_store(i, UInt8((i * 17 + 3) % 241))
    VulkanBuffers.unmap(a)
    VulkanBuffers.free(a)
    var df = False
    try:
        VulkanBuffers.free(a)
    except error:
        df = _refused_with("MEM-005", error)
    if not df:
        raise Error("Vulkan double-free was not refused with MEM-005")
    var uaf = False
    try:
        _ = VulkanBuffers.map(a)
    except error:
        uaf = _refused_with("MEM-004", error)
    if not uaf:
        raise Error("Vulkan map-after-free was not refused with MEM-004")

    # Stale-generation (ABA): recycle the freed slot, then present
    # the stale id - it must be refused with MEM-014 and must not
    # touch the new owner's buffer.
    var held = List[VulkanAllocation]()
    var found = False
    for _ in range(128):
        var t = VulkanBuffers.allocate(4096)
        held.append(t)
        if (t.id % 4294967296) == a_slot:
            found = True
            break
    if not found:
        for j in range(len(held)):
            VulkanBuffers.free(held[j])
        raise Error("freed Vulkan slot was never recycled (ABA untestable)")
    var stale = False
    try:
        _ = VulkanBuffers.map(a)
    except error:
        stale = _refused_with("MEM-014", error)
    if not stale:
        raise Error("stale Vulkan id was not refused with MEM-014")
    var stale_free = False
    try:
        VulkanBuffers.free(a)
    except error:
        stale_free = _refused_with("MEM-014", error)
    if not stale_free:
        raise Error("stale Vulkan free was not refused with MEM-014")
    for j in range(len(held)):
        VulkanBuffers.free(held[j])

    # Hand-off: sender ops refused with MEM-011 until claim.
    var h = VulkanBuffers.allocate(4096)
    var h2 = VulkanBuffers.handoff(h)
    var hof = False
    try:
        VulkanBuffers.free(h)
    except error:
        hof = _refused_with("MEM-011", error)
    if not hof:
        raise Error("Vulkan free after hand-off was not refused")
    var hou = False
    try:
        _ = VulkanBuffers.map(h)
    except error:
        hou = _refused_with("MEM-011", error)
    if not hou:
        raise Error("Vulkan map after hand-off was not refused")
    VulkanBuffers.claim(h2)
    var ph = VulkanBuffers.map(h2)
    ph.unsafe_store(0, UInt8(0xAB))
    VulkanBuffers.unmap(h2)
    VulkanBuffers.free(h2)

    # Cross-shim misuse: a HIP pointer presented as a Vulkan id is
    # refused, and the HIP allocation still frees through HIP.
    if _hip_present():
        var hp = HipMemory.allocate(4096)
        var fake = VulkanAllocation(Int(hp), 4096, 4096, 256, 0)
        var cross = False
        try:
            VulkanBuffers.free(fake)
        except:
            cross = True
        if not cross:
            HipMemory.free(hp)
            raise Error("HIP pointer was accepted as a Vulkan buffer id")
        HipMemory.free(hp)

    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("Vulkan ownership sequences leaked shim bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("Vulkan ownership sequences leaked shim buffers")
    if VulkanBuffers.ownership_violation_count() <= v0:
        raise Error("Vulkan ownership violation counter did not advance")
    print(
        "Vulkan ownership adversarial (double-free MEM-005, use-"
        "after-free MEM-004, stale-generation MEM-014, hand-off"
        " MEM-011, cross-shim id refused, accounting baseline): PASS"
    )


def test_zero_copy_buffer_ownership_adversarial() raises:
    print("--- Testing zero-copy ownership adversarial (A-022) ---")
    if not _hip_present():
        var rejected = False
        try:
            var b = ZeroCopy.allocate_default(4096)
            ZeroCopy.free(b)
        except:
            rejected = True
        if not rejected:
            raise Error("HIP unavailable but zero-copy allocate succeeded")
        print("HIP UNAVAILABLE: zero-copy ownership fail-closed: PASS")
        return
    var c0 = ZeroCopy.counters()

    # Double-free of the copied buffer value refused with MEM-005
    # (the pre-A-022 shim called hipFree before checking its own
    # registry - this case is the regression test for that hole).
    var buf = ZeroCopy.allocate_default(4096)
    ZeroCopy.free(buf)
    var df = False
    try:
        ZeroCopy.free(buf)
    except error:
        df = _refused_with("MEM-005", error)
    if not df:
        raise Error("zero-copy double-free was not refused with MEM-005")

    # Use-after-free (kernel launch on the freed buffer) MEM-004.
    var uaf = False
    try:
        ZeroCopy.hip_fill(buf, 16)
    except error:
        uaf = _refused_with("MEM-004", error)
    if not uaf:
        raise Error("zero-copy use-after-free was not refused with MEM-004")

    # Cross-shim misuse: an A-011 HIP-shim managed allocation
    # presented to the zero-copy shim's free is refused with
    # MEM-013, and still frees cleanly through its own shim.
    var hp = HipMemory.allocate_managed(4096)
    var dummy = VulkanAllocation(0, 0, 0, 0, 0)
    var fake = ZeroCopyBuffer(BACKEND_HIP_MANAGED, 4096, Int(hp), dummy)
    var cross = False
    try:
        ZeroCopy.free(fake)
    except error:
        cross = _refused_with("MEM-013", error)
    if not cross:
        HipMemory.free(hp)
        raise Error("cross-shim free was not refused with MEM-013")
    HipMemory.free(hp)
    # And the reverse direction: a zero-copy pointer freed through
    # the HIP shim is refused there too.
    var zbuf = ZeroCopy.allocate_default(4096)
    var zptr = ZeroCopy.cpu_ptr(zbuf)
    var cross2 = False
    try:
        HipMemory.free(zptr)
    except error:
        cross2 = _refused_with("MEM-013", error)
    if not cross2:
        ZeroCopy.free(zbuf)
        raise Error("reverse cross-shim free was not refused with MEM-013")
    ZeroCopy.free(zbuf)

    # Hand-off: sender use/free refused with MEM-011 until claim,
    # then the receiver's buffer works on the real device.
    var hb = ZeroCopy.allocate_default(4096)
    var recv = ZeroCopy.handoff(hb)
    var hou = False
    try:
        ZeroCopy.hip_fill(hb, 16)
    except error:
        hou = _refused_with("MEM-011", error)
    if not hou:
        raise Error("zero-copy use after hand-off was not refused")
    var hof = False
    try:
        ZeroCopy.free(hb)
    except error:
        hof = _refused_with("MEM-011", error)
    if not hof:
        raise Error("zero-copy free after hand-off was not refused")
    ZeroCopy.claim(recv)
    ZeroCopy.hip_fill(recv, 16)
    ZeroCopy.free(recv)

    var c1 = ZeroCopy.counters()
    if c1.hip_live_bytes != c0.hip_live_bytes:
        raise Error("zero-copy ownership sequences leaked live bytes")
    if (c1.hip_allocs - c0.hip_allocs) != (c1.hip_frees - c0.hip_frees):
        raise Error("zero-copy ownership alloc/free counters unbalanced")
    if c1.hip_violations <= c0.hip_violations:
        raise Error("zero-copy ownership violation counter did not advance")
    print(
        "Zero-copy ownership adversarial (double-free MEM-005, use-"
        "after-free MEM-004, cross-shim both directions MEM-013,"
        " hand-off MEM-011, accounting baseline): PASS"
    )


def test_xrt_bo_ownership_contract() raises:
    print("--- Testing XRT BO ownership contract (A-022) ---")
    # Contract level only (A-016 is a host-side probe; no sudo, no
    # device ioctls). The registry is the enforcement point every
    # future XRT wrapper routes alloc/free/use through.
    var reg = XrtBoOwnership()
    var h = reg.register(0)
    reg.use(h)
    # Free with an active borrow refused with MEM-015.
    reg.borrow(h)
    var fwb = False
    try:
        reg.free(h)
    except error:
        fwb = _refused_with("MEM-015", error)
    if not fwb:
        raise Error("free-with-active-borrow was not refused with MEM-015")
    reg.borrow_end(h)
    # Hand-off: sender use/free refused with MEM-011.
    var h2 = reg.handoff(h)
    var hou = False
    try:
        reg.use(h)
    except error:
        hou = _refused_with("MEM-011", error)
    if not hou:
        raise Error("XRT use after hand-off was not refused with MEM-011")
    var hof = False
    try:
        reg.free(h)
    except error:
        hof = _refused_with("MEM-011", error)
    if not hof:
        raise Error("XRT free after hand-off was not refused with MEM-011")
    # Cross-device misuse refused with MEM-012 (use and claim).
    var xuse = False
    try:
        reg.use(XrtBoHandle(1, h2.id, h2.generation))
    except error:
        xuse = _refused_with("MEM-012", error)
    if not xuse:
        raise Error("XRT cross-device use was not refused with MEM-012")
    var xclaim = False
    try:
        reg.claim(XrtBoHandle(1, h2.id, h2.generation))
    except error:
        xclaim = _refused_with("MEM-012", error)
    if not xclaim:
        raise Error("XRT cross-device claim was not refused with MEM-012")
    reg.claim(h2)
    reg.use(h2)
    reg.free(h2)
    # Double-free MEM-005, use-after-free MEM-004.
    var df = False
    try:
        reg.free(h2)
    except error:
        df = _refused_with("MEM-005", error)
    if not df:
        raise Error("XRT double-free was not refused with MEM-005")
    var uaf = False
    try:
        reg.use(h2)
    except error:
        uaf = _refused_with("MEM-004", error)
    if not uaf:
        raise Error("XRT use-after-free was not refused with MEM-004")
    # Foreign handle refused with MEM-013.
    var foreign = False
    try:
        reg.free(XrtBoHandle(0, 99999, 1))
    except error:
        foreign = _refused_with("MEM-013", error)
    if not foreign:
        raise Error("XRT foreign handle was not refused with MEM-013")
    # Stale generation refused with MEM-014.
    var h3 = reg.register(0)
    var stale = False
    try:
        reg.use(XrtBoHandle(0, h3.id, h3.generation + 7))
    except error:
        stale = _refused_with("MEM-014", error)
    if not stale:
        raise Error("XRT stale generation was not refused with MEM-014")
    reg.free(h3)
    if reg.live_count() != 0:
        raise Error("XRT contract registry leaked live BOs")
    print(
        "XRT BO ownership contract (free-while-borrowed MEM-015,"
        " hand-off MEM-011, cross-device MEM-012, double-free"
        " MEM-005, use-after-free MEM-004, foreign MEM-013, stale"
        " MEM-014, live count baseline): PASS"
    )
