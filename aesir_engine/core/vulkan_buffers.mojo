# core/vulkan_buffers.mojo
# VulkanBuffers: Vulkan buffer allocation with host-visible coherent
# mapping for the AMD / Vulkan realm (slice A-014).
#
# Real vkCreateBuffer / vkAllocateMemory / vkBindBufferMemory /
# vkMapMemory calls on the selected physical device (on purpleraider:
# the Radeon 8060S Graphics, RADV STRIX_HALO, gfx1151), reached through
# the flat C ABI in aesir_engine/vulkan_buffer_shim.c (libaesir_vulkan.so,
# staged and linked exactly like libaesir_hailo10h / libaesir_par /
# libaesir_hip; the shim header explains why dynamic loading and the
# struct-heavy Vulkan calls live in C, and why A-014 carries a minimal
# context of its own until A-013's full context wrapper lands and the
# keeper reconciles the two at banking).
#
# Memory contract (A-014 acceptance): every allocation requests
# HOST_VISIBLE | HOST_COHERENT memory, preferring a DEVICE_LOCAL type
# among the candidates the buffer's own VkMemoryRequirements allow - on
# Strix Halo's unified pool that is the type that is simultaneously
# device-local, host-visible and host-coherent. Because the memory is
# coherent, writes through the mapped pointer need no flush and reads
# need no invalidate. If no host-visible coherent type satisfies a
# buffer, allocation fails closed; no staging copy is fabricated.
#
# Alignment law (values READ FROM THE DEVICE through the shim at run
# time, never assumed; the A-014 ledger files the measured table):
#   - a mapped pointer for offset 0 is aligned to
#     limits.min_memory_map_alignment;
#   - every allocation size is the driver's VkMemoryRequirements.size,
#     a multiple of VkMemoryRequirements.alignment;
#   - offsets into storage / uniform / texel buffers must be multiples
#     of the matching min_*_buffer_offset_alignment limit;
#   - non-coherent atom granularity (limits.non_coherent_atom_size)
#     would govern flush/invalidate ranges for non-coherent memory;
#     this gateway never allocates non-coherent memory, so no flush
#     ranges exist in its contract.
#
# Fail-closed contract: when libvulkan is not loadable, the shim
# reports unavailable and every operation here raises; nothing is
# simulated and no pointer is fabricated. Buffer ids are owned by the
# caller and must be released with VulkanBuffers.free() exactly once.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc
from core.checked_span import checked_span
from core.buffer_ownership import ownership_taxonomy_name

comptime _VK_ABSENT = -1000000
comptime _VK_INVALID = -1000001

# Indices into the shim's limits array (see vulkan_buffer_shim.c).
comptime _LIM_MIN_MAP_ALIGNMENT = 0
comptime _LIM_MIN_STORAGE_OFFSET = 1
comptime _LIM_MIN_UNIFORM_OFFSET = 2
comptime _LIM_MIN_TEXEL_OFFSET = 3
comptime _LIM_NON_COHERENT_ATOM = 4
comptime _LIM_BUFFER_IMAGE_GRANULARITY = 5
comptime _LIM_OPTIMAL_COPY_OFFSET = 6
comptime _LIM_MAX_ALLOC_COUNT = 7
comptime _LIM_MAX_STORAGE_RANGE = 8
comptime _LIM_MAX_PUSH_CONSTANTS = 9
comptime _LIM_PREFERRED_TYPE_INDEX = 10
comptime _LIM_PREFERRED_HEAP_INDEX = 11
comptime _LIM_PREFERRED_HEAP_SIZE = 12
comptime _LIM_PREFERRED_TYPE_FLAGS = 13
comptime _LIM_MEMORY_TYPE_COUNT = 14
comptime _LIM_MEMORY_HEAP_COUNT = 15
comptime _LIM_COUNT = 16


def is_power_of_two(value: Int) -> Bool:
    """True iff value is a positive power of two."""
    return value > 0 and (value & (value - 1)) == 0


def align_up(value: Int, alignment: Int) raises -> Int:
    """Round value up to a multiple of alignment (checked arithmetic).

    Alignment must be a positive power of two - every alignment the
    Vulkan spec hands this gateway (memory-requirements alignment and
    the min_* limits) has that shape, and the device case asserts it
    from the live limits. Overflow raises instead of wrapping.
    """
    if value < 0:
        raise Error("VulkanBuffers.align_up: value must be nonnegative")
    if not is_power_of_two(alignment):
        raise Error(
            "VulkanBuffers.align_up: alignment must be a positive"
            " power of two"
        )
    if value > 9223372036854775807 - (alignment - 1):
        raise Error("VulkanBuffers.align_up: overflow")
    return (value + alignment - 1) & ~(alignment - 1)


struct VulkanDeviceInfo(Copyable, ImplicitlyCopyable):
    """Identity of the physical device the shim selected."""

    var vendor_id: Int
    var device_id: Int
    var api_version: Int
    var device_type: Int
    var queue_family: Int

    def __init__(
        out self,
        vendor_id: Int,
        device_id: Int,
        api_version: Int,
        device_type: Int,
        queue_family: Int,
    ):
        self.vendor_id = vendor_id
        self.device_id = device_id
        self.api_version = api_version
        self.device_type = device_type
        self.queue_family = queue_family


struct VulkanLimits(Copyable, ImplicitlyCopyable):
    """Device limits read live from the selected physical device."""

    var min_memory_map_alignment: Int
    var min_storage_buffer_offset_alignment: Int
    var min_uniform_buffer_offset_alignment: Int
    var min_texel_buffer_offset_alignment: Int
    var non_coherent_atom_size: Int
    var buffer_image_granularity: Int
    var optimal_buffer_copy_offset_alignment: Int
    var max_memory_allocation_count: Int
    var max_storage_buffer_range: Int
    var max_push_constants_size: Int
    var preferred_type_index: Int
    var preferred_heap_index: Int
    var preferred_heap_size: Int
    var preferred_type_flags: Int
    var memory_type_count: Int
    var memory_heap_count: Int

    def __init__(out self, raw: Pointer[UInt64, MutUntrackedOrigin]):
        self.min_memory_map_alignment = Int(
            raw.unsafe_load(_LIM_MIN_MAP_ALIGNMENT)
        )
        self.min_storage_buffer_offset_alignment = Int(
            raw.unsafe_load(_LIM_MIN_STORAGE_OFFSET)
        )
        self.min_uniform_buffer_offset_alignment = Int(
            raw.unsafe_load(_LIM_MIN_UNIFORM_OFFSET)
        )
        self.min_texel_buffer_offset_alignment = Int(
            raw.unsafe_load(_LIM_MIN_TEXEL_OFFSET)
        )
        self.non_coherent_atom_size = Int(
            raw.unsafe_load(_LIM_NON_COHERENT_ATOM)
        )
        self.buffer_image_granularity = Int(
            raw.unsafe_load(_LIM_BUFFER_IMAGE_GRANULARITY)
        )
        self.optimal_buffer_copy_offset_alignment = Int(
            raw.unsafe_load(_LIM_OPTIMAL_COPY_OFFSET)
        )
        self.max_memory_allocation_count = Int(
            raw.unsafe_load(_LIM_MAX_ALLOC_COUNT)
        )
        self.max_storage_buffer_range = Int(
            raw.unsafe_load(_LIM_MAX_STORAGE_RANGE)
        )
        self.max_push_constants_size = Int(
            raw.unsafe_load(_LIM_MAX_PUSH_CONSTANTS)
        )
        self.preferred_type_index = Int(
            raw.unsafe_load(_LIM_PREFERRED_TYPE_INDEX)
        )
        self.preferred_heap_index = Int(
            raw.unsafe_load(_LIM_PREFERRED_HEAP_INDEX)
        )
        self.preferred_heap_size = Int(
            raw.unsafe_load(_LIM_PREFERRED_HEAP_SIZE)
        )
        self.preferred_type_flags = Int(
            raw.unsafe_load(_LIM_PREFERRED_TYPE_FLAGS)
        )
        self.memory_type_count = Int(raw.unsafe_load(_LIM_MEMORY_TYPE_COUNT))
        self.memory_heap_count = Int(raw.unsafe_load(_LIM_MEMORY_HEAP_COUNT))


struct VulkanBufferRequirements(Copyable, ImplicitlyCopyable):
    """VkMemoryRequirements for one requested buffer size."""

    var size: Int
    var alignment: Int
    var type_bits: UInt32

    def __init__(out self, size: Int, alignment: Int, type_bits: UInt32):
        self.size = size
        self.alignment = alignment
        self.type_bits = type_bits


struct VulkanAllocation(Copyable, ImplicitlyCopyable):
    """One live buffer allocation: shim id plus driver accounting."""

    var id: Int
    var requested_size: Int
    var alloc_size: Int
    var alignment: Int
    var type_index: Int

    def __init__(
        out self,
        id: Int,
        requested_size: Int,
        alloc_size: Int,
        alignment: Int,
        type_index: Int,
    ):
        self.id = id
        self.requested_size = requested_size
        self.alloc_size = alloc_size
        self.alignment = alignment
        self.type_index = type_index


struct VulkanBuffers:
    """Static Vulkan buffer gateway (A-014). See file header."""

    @staticmethod
    def runtime_available() -> Bool:
        """True iff the shim loaded libvulkan and resolved every entry
        point. Library-level probe; device presence is device_info()'s
        job."""
        return external_call["aesir_vk_buffer_available", Int32]() == Int32(1)

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        if Int(rc) == _VK_ABSENT:
            raise Error(
                "VulkanBuffers." + what + ": Vulkan loader is not"
                " loadable on this host (honest-absent)"
            )
        if Int(rc) == _VK_INVALID:
            raise Error(
                "VulkanBuffers." + what + ": invalid buffer id or"
                " argument for the Vulkan shim"
            )
        if Int(rc) <= -22004 and Int(rc) >= -22016:
            raise Error(
                "VulkanBuffers." + what + ": buffer ownership law refused"
                " the operation: " + ownership_taxonomy_name(Int(rc))
                + " (A-022)"
            )
        raise Error(
            "VulkanBuffers." + what + ": Vulkan call failed, VkResult "
            + String(Int(rc))
        )

    @staticmethod
    def init() raises:
        """Create the shim's context (instance/device/queue) once."""
        var rc = external_call["aesir_vk_init", Int32]()
        if rc != 0:
            Self._raise_for_rc("init", rc)

    @staticmethod
    def device_info() raises -> VulkanDeviceInfo:
        """Identity of the selected physical device."""
        var name_buf = alloc[UInt8](256)
        var vendor: UInt32 = 0
        var device: UInt32 = 0
        var api: UInt32 = 0
        var dtype: UInt32 = 0
        var qfamily: UInt32 = 0
        var rc = external_call["aesir_vk_buffer_device_info", Int32](
            name_buf,
            Int32(256),
            Pointer(to=vendor),
            Pointer(to=device),
            Pointer(to=api),
            Pointer(to=dtype),
            Pointer(to=qfamily),
        )
        name_buf.unsafe_free()
        if rc != 0:
            Self._raise_for_rc("device_info", rc)
        return VulkanDeviceInfo(
            Int(vendor), Int(device), Int(api), Int(dtype), Int(qfamily)
        )

    @staticmethod
    def device_name_is_radv() raises -> Bool:
        """True iff the selected device name carries the RADV marker
        (the full name string is printed by the A-014 C probe and filed
        in the evidence logs; the Mojo side asserts identity through
        vendor/type plus this marker)."""
        var name_buf = alloc[UInt8](256)
        for i in range(256):
            name_buf.unsafe_store(i, UInt8(0))
        var vendor: UInt32 = 0
        var device: UInt32 = 0
        var api: UInt32 = 0
        var dtype: UInt32 = 0
        var qfamily: UInt32 = 0
        var rc = external_call["aesir_vk_buffer_device_info", Int32](
            name_buf,
            Int32(256),
            Pointer(to=vendor),
            Pointer(to=device),
            Pointer(to=api),
            Pointer(to=dtype),
            Pointer(to=qfamily),
        )
        if rc != 0:
            name_buf.unsafe_free()
            Self._raise_for_rc("device_name_is_radv", rc)
        var found = False
        for i in range(253):
            if (
                name_buf.unsafe_load(i) == UInt8(82)
                and name_buf.unsafe_load(i + 1) == UInt8(65)
                and name_buf.unsafe_load(i + 2) == UInt8(68)
                and name_buf.unsafe_load(i + 3) == UInt8(86)
            ):
                found = True
                break
            if name_buf.unsafe_load(i) == UInt8(0):
                break
        name_buf.unsafe_free()
        return found

    @staticmethod
    def limits() raises -> VulkanLimits:
        """Live VkPhysicalDeviceLimits + preferred host-coherent type
        facts for the selected device."""
        var raw = alloc[UInt64](_LIM_COUNT)
        var rc = external_call["aesir_vk_limits", Int32](
            raw, Int32(_LIM_COUNT)
        )
        if rc != 0:
            raw.unsafe_free()
            Self._raise_for_rc("limits", rc)
        var limits = VulkanLimits(raw)
        raw.unsafe_free()
        return limits

    @staticmethod
    def requirements(size_bytes: Int) raises -> VulkanBufferRequirements:
        """VkMemoryRequirements for a buffer of size_bytes (no memory
        is allocated; a probe buffer is created and destroyed inside
        the shim)."""
        if size_bytes <= 0:
            raise Error(
                "VulkanBuffers.requirements: size_bytes must be positive"
            )
        var out_size: UInt64 = 0
        var out_alignment: UInt64 = 0
        var out_bits: UInt32 = 0
        var rc = external_call["aesir_vk_buffer_requirements", Int32](
            UInt64(size_bytes),
            Pointer(to=out_size),
            Pointer(to=out_alignment),
            Pointer(to=out_bits),
        )
        if rc != 0:
            Self._raise_for_rc("requirements", rc)
        return VulkanBufferRequirements(
            Int(out_size), Int(out_alignment), out_bits
        )

    @staticmethod
    def allocate(size_bytes: Int) raises -> VulkanAllocation:
        """Create a buffer and bind host-visible coherent memory.

        The byte count is admitted through checked_span discipline.
        The returned allocation's alloc_size is the driver's
        requirements size (>= size_bytes, a multiple of alignment).
        """
        if size_bytes <= 0:
            raise Error("VulkanBuffers.allocate: size_bytes must be positive")
        var span = checked_span(0, size_bytes, size_bytes)
        var out_id: UInt64 = 0
        var out_alloc: UInt64 = 0
        var out_alignment: UInt64 = 0
        var out_type: UInt32 = 0
        var rc = external_call["aesir_vk_buffer_alloc", Int32](
            UInt64(span.length),
            Pointer(to=out_id),
            Pointer(to=out_alloc),
            Pointer(to=out_alignment),
            Pointer(to=out_type),
        )
        if rc != 0:
            Self._raise_for_rc("allocate", rc)
        if out_id == 0:
            raise Error("VulkanBuffers.allocate: shim returned a null id")
        return VulkanAllocation(
            Int(out_id),
            span.length,
            Int(out_alloc),
            Int(out_alignment),
            Int(out_type),
        )

    @staticmethod
    def allocate_cached(size_bytes: Int) raises -> VulkanAllocation:
        """Create a buffer on a HOST_CACHED host-coherent memory type
        ONLY (slice A-019, the A-008 zero-copy rule): the shim
        refuses the DEVICE_LOCAL coherent type carrying
        DEVICE_UNCACHED_AMD, whose CPU reads measured 0.11 GB/s in
        the A-008 probe, and fails closed when no cached coherent
        type satisfies the buffer. The byte count is admitted
        through checked_span discipline."""
        if size_bytes <= 0:
            raise Error(
                "VulkanBuffers.allocate_cached: size_bytes must be positive"
            )
        var span = checked_span(0, size_bytes, size_bytes)
        var out_id: UInt64 = 0
        var out_alloc: UInt64 = 0
        var out_alignment: UInt64 = 0
        var out_type: UInt32 = 0
        var out_flags: UInt32 = 0
        var rc = external_call["aesir_vk_buffer_alloc_cached", Int32](
            UInt64(span.length),
            Pointer(to=out_id),
            Pointer(to=out_alloc),
            Pointer(to=out_alignment),
            Pointer(to=out_type),
            Pointer(to=out_flags),
        )
        if rc != 0:
            Self._raise_for_rc("allocate_cached", rc)
        if out_id == 0:
            raise Error("VulkanBuffers.allocate_cached: shim returned a null id")
        return VulkanAllocation(
            Int(out_id),
            span.length,
            Int(out_alloc),
            Int(out_alignment),
            Int(out_type),
        )

    @staticmethod
    def buffer_type_flags(allocation: VulkanAllocation) raises -> Int:
        """Live VkMemoryPropertyFlags of the allocation's memory
        type, read back from the shim (A-019 evidence for the
        HOST_CACHED coherent rule)."""
        var flags: UInt32 = 0
        var rc = external_call["aesir_vk_buffer_type_flags", Int32](
            UInt64(allocation.id), Pointer(to=flags)
        )
        if rc != 0:
            Self._raise_for_rc("buffer_type_flags", rc)
        return Int(flags)

    @staticmethod
    def map(
        allocation: VulkanAllocation,
    ) raises -> Pointer[UInt8, MutUntrackedOrigin]:
        """vkMapMemory over the whole allocation; the returned pointer
        is valid until unmap()/free() and, for offset 0, is aligned to
        limits.min_memory_map_alignment."""
        var addr: Int = 0
        var rc = external_call["aesir_vk_buffer_map", Int32](
            UInt64(allocation.id), Pointer(to=addr)
        )
        if rc != 0:
            Self._raise_for_rc("map", rc)
        if addr == 0:
            raise Error("VulkanBuffers.map: vkMapMemory returned null")
        return Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)

    @staticmethod
    def unmap(allocation: VulkanAllocation) raises:
        """vkUnmapMemory; the mapped pointer must not be used after."""
        var rc = external_call["aesir_vk_buffer_unmap", Int32](
            UInt64(allocation.id)
        )
        if rc != 0:
            Self._raise_for_rc("unmap", rc)

    @staticmethod
    def free(allocation: VulkanAllocation) raises:
        """Destroy the buffer and free its memory. Each allocation must
        be freed exactly once; a second free raises (invalid id)."""
        var rc = external_call["aesir_vk_buffer_free", Int32](
            UInt64(allocation.id)
        )
        if rc != 0:
            Self._raise_for_rc("free", rc)

    @staticmethod
    def handoff(
        allocation: VulkanAllocation,
    ) raises -> VulkanAllocation:
        """Hand ownership to a receiver (A-022): the sender's id
        tombstones; the returned allocation carries the receiver's
        new generation-tagged id, inert until claim()."""
        var new_id: UInt64 = 0
        var rc = external_call["aesir_vk_buffer_handoff", Int32](
            UInt64(allocation.id), Pointer(to=new_id)
        )
        if rc != 0:
            Self._raise_for_rc("handoff", rc)
        return VulkanAllocation(
            Int(new_id),
            allocation.requested_size,
            allocation.alloc_size,
            allocation.alignment,
            allocation.type_index,
        )

    @staticmethod
    def claim(allocation: VulkanAllocation) raises:
        """The receiver claims a handed-off allocation."""
        var rc = external_call["aesir_vk_buffer_claim", Int32](
            UInt64(allocation.id)
        )
        if rc != 0:
            Self._raise_for_rc("claim", rc)

    @staticmethod
    def ownership_violation_count() -> Int:
        """Refused ownership operations so far (A-022 evidence)."""
        return Int(
            external_call["aesir_vk_ownership_violation_count", UInt64]()
        )

    @staticmethod
    def dispatch_available() -> Bool:
        """True iff the shim resolved every Vulkan compute dispatch
        entry point (A-015). Library-level probe; device presence is
        device_info()'s job."""
        return external_call["aesir_vk_dispatch_available", Int32]() == Int32(1)

    @staticmethod
    def vec_add(
        a: VulkanAllocation,
        b: VulkanAllocation,
        c: VulkanAllocation,
        n: Int,
    ) raises:
        """Dispatch the A-015 vector-add kernel: c[i] = a[i] + b[i]
        for i in [0, n), Float32 elements, on the A-014 context and
        its compute queue. The shim creates the pipeline per call,
        submits, and waits for the queue to go idle before returning,
        so a mapped read of c after this call observes the completed
        dispatch. All three buffers must hold at least n Float32
        elements; n must be positive. Raises (fail-closed) on any
        Vulkan failure - nothing is computed on the host instead."""
        if n <= 0:
            raise Error("VulkanBuffers.vec_add: element count must be positive")
        if a.requested_size < n * 4 or b.requested_size < n * 4 or c.requested_size < n * 4:
            raise Error("VulkanBuffers.vec_add: a buffer is smaller than the element count")
        var rc = external_call["aesir_vk_buffer_vec_add", Int32](
            UInt64(a.id), UInt64(b.id), UInt64(c.id), UInt32(n)
        )
        if rc != 0:
            Self._raise_for_rc("vec_add", rc)

    @staticmethod
    def live_bytes() -> Int:
        """Shim accounting: bytes held by live A-014 allocations."""
        return Int(external_call["aesir_vk_live_bytes", UInt64]())

    @staticmethod
    def live_count() -> Int:
        """Shim accounting: number of live A-014 allocations."""
        return Int(external_call["aesir_vk_live_count", Int32]())

    @staticmethod
    def copy_call_count() -> Int:
        """A-019 instrumentation: Vulkan copy calls issued through
        this shim. The shim resolves no copy entry point at all, so
        this is structurally zero; the zero-copy tests read it back
        as acceptance evidence."""
        return Int(external_call["aesir_vk_copy_call_count", UInt64]())
