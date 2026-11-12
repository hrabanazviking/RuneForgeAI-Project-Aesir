# core/gpu_weight_residency.mojo
# GpuWeightResidency: GPU weight residency (slice A-064).
#
# Fixture weights resident ONCE, in unified memory, shared with
# the CPU path (extends A-020 from HIP host-registration of the
# GGUF mmap to the Vulkan path Wave 7 built):
#
# - resident_allocate() creates ONE Vulkan allocation per weight
#   tensor through the A-014 gateway. On Strix Halo the A-014
#   preferred memory type is simultaneously DEVICE_LOCAL,
#   HOST_VISIBLE and HOST_COHERENT (the unified pool), so the
#   mapped host pointer and the device buffer are the same
#   physical pages: CPU writes through the map are visible to
#   GPU dispatches with no copy, no staging buffer and no
#   re-upload call. The shim resolves no Vulkan copy entry point
#   at all (A-019), so upload_call_count() is structurally zero.
# - Residency is measured, never asserted from design: the shim
#   live_bytes()/live_count() accounting must show exactly one
#   allocation of exactly alloc_size bytes per resident tensor,
#   and repeated GEMV dispatches against the same allocation
#   must leave both counters unchanged while the dispatch
#   counter advances - the filed proof that repeated runs do
#   not re-upload.
# - The A-020 split still governs the source side: zero-copy
#   GGUF tensors alias the single file mmap (single residency);
#   this module governs the GPU-side resident copy of the raw
#   weight bytes the Vulkan kernels consume, and it is exactly
#   one copy, accounted in alloc_size bytes.
#
# Fail-closed contract (house style of A-014/A-020/A-056): when
# the Vulkan runtime or the RADV device is unavailable every
# operation raises; non-positive sizes raise before allocation;
# nothing is simulated and no duplicate is fabricated.

from core.vulkan_buffers import VulkanBuffers, VulkanAllocation

struct GpuResidencyAccounting(Copyable, ImplicitlyCopyable):
    """Live shim accounting snapshot for resident weights."""

    var live_bytes: Int
    var live_count: Int
    var upload_calls: Int

    def __init__(out self, live_bytes: Int, live_count: Int, upload_calls: Int):
        self.live_bytes = live_bytes
        self.live_count = live_count
        self.upload_calls = upload_calls


struct GpuWeightResidency:
    """Static GPU weight-residency gateway (A-064). See header."""

    @staticmethod
    def resident_allocate(size_bytes: Int) raises -> VulkanAllocation:
        """Allocate ONE resident weight buffer of size_bytes in
        the unified (device-local + host-visible + host-coherent)
        pool. The returned allocation is the single residency:
        callers fill it once through VulkanBuffers.map() and
        reuse the same allocation id for every dispatch."""
        if size_bytes <= 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: GpuWeightResidency."
                "resident_allocate: size must be positive"
            )
        return VulkanBuffers.allocate(size_bytes)

    @staticmethod
    def accounting() -> GpuResidencyAccounting:
        """Snapshot of the shim accounting counters."""
        return GpuResidencyAccounting(
            VulkanBuffers.live_bytes(),
            VulkanBuffers.live_count(),
            VulkanBuffers.copy_call_count(),
        )

    @staticmethod
    def upload_call_count() -> Int:
        """Vulkan copy/upload calls issued through the shim.
        Structurally zero (A-019: no copy entry point resolved);
        read back as the no-re-upload evidence."""
        return VulkanBuffers.copy_call_count()

    @staticmethod
    def is_unified_type(allocation: VulkanAllocation) raises -> Bool:
        """True iff the allocation memory type is DEVICE_LOCAL
        (0x1) + HOST_VISIBLE (0x2) + HOST_COHERENT (0x4): the
        unified-memory type where host map and device buffer are
        one residency, not two copies."""
        var flags = VulkanBuffers.buffer_type_flags(allocation)
        return (flags & 0x1) != 0 and (flags & 0x2) != 0 and (flags & 0x4) != 0

    @staticmethod
    def single_residency_delta(
        before: GpuResidencyAccounting,
        during: GpuResidencyAccounting,
        allocation: VulkanAllocation,
    ) -> Bool:
        """True iff moving from before to during added exactly
        this one allocation (alloc_size bytes, count +1) and no
        upload/copy call was issued."""
        return (
            during.live_bytes - before.live_bytes == allocation.alloc_size
            and during.live_count - before.live_count == 1
            and during.upload_calls == before.upload_calls
        )

    @staticmethod
    def unchanged(
        a: GpuResidencyAccounting, b: GpuResidencyAccounting
    ) -> Bool:
        """True iff two accounting snapshots are identical: no
        bytes, buffers or upload calls appeared or vanished
        between them (the repeated-runs-do-not-re-upload test)."""
        return (
            a.live_bytes == b.live_bytes
            and a.live_count == b.live_count
            and a.upload_calls == b.upload_calls
        )
