"""Vulkan buffers (A-014): host-visible coherent buffer allocation,
mapped write/read oracle, and the alignment rules read live from the
device limits.

Present/absent discipline matches the house style of the A-011 HIP
cases: on a Vulkan host every case verifies real device memory; on a
host without a usable Vulkan device every case asserts fail-closed
behaviour and passes as honest-absent. No case ever claims a round
trip it did not run. On purpleraider the selected device must be the
AMD RADV device (vendor 0x1002) - the llvmpipe software device never
satisfies these cases.
"""
from core.vulkan_buffers import (
    VulkanBuffers,
    align_up,
    is_power_of_two,
)


def _vk_present() -> Bool:
    if not VulkanBuffers.runtime_available():
        return False
    try:
        var info = VulkanBuffers.device_info()
        if info.vendor_id != 0x1002:
            return False
        return VulkanBuffers.device_name_is_radv()
    except:
        return False


def _expect_vk_fail_closed() raises:
    var alloc_rejected = False
    try:
        var a = VulkanBuffers.allocate(4096)
        VulkanBuffers.free(a)
    except:
        alloc_rejected = True
    if not alloc_rejected:
        raise Error(
            "Vulkan unavailable but VulkanBuffers.allocate succeeded"
            " (fabricated allocation)"
        )
    var limits_rejected = False
    try:
        _ = VulkanBuffers.limits()
    except:
        limits_rejected = True
    if not limits_rejected:
        raise Error(
            "Vulkan unavailable but VulkanBuffers.limits succeeded"
            " (fabricated limits)"
        )


def _pattern_a(i: Int) -> UInt8:
    return UInt8((i * 31 + 7) % 251)


def _pattern_b(i: Int) -> UInt8:
    return UInt8((i * 17 + 3) % 241)


def test_vulkan_buffer_alignment_rules() raises:
    print("--- Testing Vulkan buffer alignment rules (A-014) ---")
    # Pure checked arithmetic first (device-independent).
    if align_up(0, 4096) != 0 or align_up(1, 4096) != 4096:
        raise Error("align_up boundary values wrong")
    if align_up(4096, 4096) != 4096 or align_up(4097, 4096) != 8192:
        raise Error("align_up rounding wrong")
    if align_up(7, 4) != 8 or align_up(8, 4) != 8:
        raise Error("align_up small alignment wrong")
    if not is_power_of_two(1) or not is_power_of_two(4096):
        raise Error("is_power_of_two rejected a power of two")
    if is_power_of_two(0) or is_power_of_two(3) or is_power_of_two(-2):
        raise Error("is_power_of_two accepted a non power of two")
    var bad_alignment_rejected = False
    try:
        _ = align_up(10, 3)
    except:
        bad_alignment_rejected = True
    if not bad_alignment_rejected:
        raise Error("align_up accepted a non-power-of-two alignment")
    var overflow_rejected = False
    try:
        _ = align_up(9223372036854775807, 4096)
    except:
        overflow_rejected = True
    if not overflow_rejected:
        raise Error("align_up wrapped on overflow")
    if not _vk_present():
        print(
            "Vulkan UNAVAILABLE: pure alignment arithmetic PASS;"
            " device-limit assertions not run (honest-absent)"
        )
        return
    # Device limits, read live: every alignment the rules rely on is a
    # positive power of two, and the requirements for a probe size obey
    # them (driver size is a multiple of driver alignment, and covers
    # the request).
    var limits = VulkanBuffers.limits()
    if not is_power_of_two(limits.min_memory_map_alignment):
        raise Error("minMemoryMapAlignment is not a power of two")
    if not is_power_of_two(limits.min_storage_buffer_offset_alignment):
        raise Error("minStorageBufferOffsetAlignment not a power of two")
    if not is_power_of_two(limits.min_uniform_buffer_offset_alignment):
        raise Error("minUniformBufferOffsetAlignment not a power of two")
    if not is_power_of_two(limits.min_texel_buffer_offset_alignment):
        raise Error("minTexelBufferOffsetAlignment not a power of two")
    if not is_power_of_two(limits.non_coherent_atom_size):
        raise Error("nonCoherentAtomSize is not a power of two")
    if limits.preferred_type_index < 0:
        raise Error("no host-visible coherent memory type on this device")
    # Preferred type flags must carry HOST_VISIBLE (0x2) + HOST_COHERENT
    # (0x4): the coherence the mapped round trip relies on.
    if limits.preferred_type_flags & 0x6 != 0x6:
        raise Error("preferred memory type is not host-visible coherent")
    if limits.preferred_heap_size <= 0:
        raise Error("preferred heap reports a non-positive size")
    var req = VulkanBuffers.requirements(1000)
    if req.size < 1000:
        raise Error("requirements size smaller than the request")
    if not is_power_of_two(req.alignment) or req.alignment <= 0:
        raise Error("requirements alignment is not a positive power of two")
    if req.size % req.alignment != 0:
        raise Error("requirements size is not a multiple of its alignment")
    if align_up(1000, req.alignment) > req.size:
        raise Error("aligned request exceeds the requirements size")
    if req.type_bits == 0:
        raise Error("requirements report no usable memory types")
    print(
        "Vulkan alignment rules (align_up checked; device limits powers"
        " of two; requirements size % alignment == 0): PASS"
    )


def test_vulkan_buffer_round_trip() raises:
    print("--- Testing Vulkan mapped buffer round trip (A-014) ---")
    if not _vk_present():
        _expect_vk_fail_closed()
        print("Vulkan UNAVAILABLE: round trip fail-closed: PASS")
        return
    var limits = VulkanBuffers.limits()
    var sizes = [1, 7, 64, 4096, 65536, 1048576]
    for s in range(len(sizes)):
        var n = sizes[s]
        var a = VulkanBuffers.allocate(n)
        if a.alloc_size < n:
            VulkanBuffers.free(a)
            raise Error("allocation smaller than the request")
        if a.alloc_size % a.alignment != 0:
            VulkanBuffers.free(a)
            raise Error("allocation size not a multiple of its alignment")
        # Write pattern A through the mapping, unmap, remap, verify:
        # persistence across unmap/remap proves a real device mapping,
        # not a host-side staging buffer.
        var p = VulkanBuffers.map(a)
        if Int(p) % limits.min_memory_map_alignment != 0:
            VulkanBuffers.unmap(a)
            VulkanBuffers.free(a)
            raise Error("mapped pointer violates minMemoryMapAlignment")
        for i in range(n):
            p.unsafe_store(i, _pattern_a(i))
        VulkanBuffers.unmap(a)
        var q = VulkanBuffers.map(a)
        for i in range(n):
            if q.unsafe_load(i) != _pattern_a(i):
                VulkanBuffers.unmap(a)
                VulkanBuffers.free(a)
                raise Error(
                    "Vulkan round trip pattern A mismatch at size "
                    + String(n) + " index " + String(i)
                )
        # Overwrite with pattern B and verify in the same mapping.
        for i in range(n):
            q.unsafe_store(i, _pattern_b(i))
        for i in range(n):
            if q.unsafe_load(i) != _pattern_b(i):
                VulkanBuffers.unmap(a)
                VulkanBuffers.free(a)
                raise Error(
                    "Vulkan round trip pattern B mismatch at size "
                    + String(n) + " index " + String(i)
                )
        VulkanBuffers.unmap(a)
        VulkanBuffers.free(a)
    print(
        "Vulkan mapped round trip (1B/7B/64B/4KiB/64KiB/1MiB, two"
        " patterns, unmap/remap persistence, byte-exact): PASS"
    )


def test_vulkan_buffer_alloc_rejection() raises:
    print("--- Testing Vulkan buffer allocation rejection (A-014) ---")
    var bad_sizes = [0, -4096]
    for b in range(len(bad_sizes)):
        var size = bad_sizes[b]
        var alloc_rejected = False
        try:
            var a = VulkanBuffers.allocate(size)
            VulkanBuffers.free(a)
        except error:
            alloc_rejected = True
            if "must be positive" not in String(error):
                raise Error(
                    "Vulkan alloc rejection produced unexpected error"
                    " text: " + String(error)
                )
        if not alloc_rejected:
            raise Error("VulkanBuffers.allocate accepted non-positive size")
        var req_rejected = False
        try:
            _ = VulkanBuffers.requirements(size)
        except error:
            req_rejected = True
            if "must be positive" not in String(error):
                raise Error(
                    "Vulkan requirements rejection produced unexpected"
                    " error text: " + String(error)
                )
        if not req_rejected:
            raise Error("VulkanBuffers.requirements accepted bad size")
    if not _vk_present():
        _expect_vk_fail_closed()
        print(
            "Vulkan UNAVAILABLE: rejection local + fail-closed: PASS"
        )
        return
    # Unknown-id operations must fail closed, never crash.
    var limits = VulkanBuffers.limits()
    _ = limits
    var bogus_rejected = False
    try:
        var a = VulkanBuffers.allocate(4096)
        VulkanBuffers.free(a)
        VulkanBuffers.free(a)
    except:
        bogus_rejected = True
    if not bogus_rejected:
        raise Error("double free of a Vulkan buffer was accepted")
    # Oversize: a request beyond the preferred heap must fail closed.
    var oversize_rejected = False
    try:
        var big = VulkanBuffers.allocate(limits.preferred_heap_size * 4)
        VulkanBuffers.free(big)
    except:
        oversize_rejected = True
    if not oversize_rejected:
        raise Error("oversize Vulkan allocation was accepted")
    print(
        "Vulkan allocation rejection (non-positive local, double-free,"
        " oversize fail-closed): PASS"
    )


def test_vulkan_buffer_no_leak() raises:
    print("--- Testing Vulkan buffer leak accounting (A-014) ---")
    if not _vk_present():
        _expect_vk_fail_closed()
        print(
            "Vulkan UNAVAILABLE: leak battery fail-closed, no iterations"
            " claimed: PASS"
        )
        return
    # Warm-up, then baseline the shim's live accounting.
    var warm = VulkanBuffers.allocate(4096)
    VulkanBuffers.free(warm)
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    for it in range(200):
        var n = 1024 + (it % 7) * 137
        var a = VulkanBuffers.allocate(n)
        var p = VulkanBuffers.map(a)
        p.unsafe_store(0, UInt8(165))
        p.unsafe_store(n - 1, UInt8(90))
        if p.unsafe_load(0) != UInt8(165) or p.unsafe_load(n - 1) != UInt8(90):
            VulkanBuffers.unmap(a)
            VulkanBuffers.free(a)
            raise Error(
                "Vulkan leak battery touch mismatch at iteration "
                + String(it)
            )
        VulkanBuffers.unmap(a)
        VulkanBuffers.free(a)
    var end_bytes = VulkanBuffers.live_bytes()
    var end_count = VulkanBuffers.live_count()
    if end_bytes != base_bytes or end_count != base_count:
        raise Error(
            "Vulkan leak battery: live accounting "
            + String(base_bytes) + "B/" + String(base_count)
            + " -> " + String(end_bytes) + "B/" + String(end_count)
            + " across 200 iterations"
        )
    print(
        "Vulkan zero-leak battery: 200 alloc/map/touch/free iterations,"
        " live accounting returned to baseline exactly: PASS"
    )


def main() raises:
    test_vulkan_buffer_alignment_rules()
    test_vulkan_buffer_round_trip()
    test_vulkan_buffer_alloc_rejection()
    test_vulkan_buffer_no_leak()
    print("ALL PASS: vulkan buffers (4 groups)")
