# core/zero_copy.mojo
# ZeroCopy: one unified allocation type serving CPU and GPU behind
# the repo's checked-span discipline (slice A-019), built on the
# A-008 zero-copy design rule (banked ledger, hidden_files/
# A008_LEDGER.md):
#
#   1. DEFAULT backend = HIP managed memory (A-011/A-019 HIP shim):
#      hipMallocManaged on Strix Halo's unified pool - the GPU reads
#      and writes it at full DRAM speed, the CPU reads/writes it at
#      full speed in both directions, first-touch costs unmeasurable.
#      No copy call belongs in this path, and none exists: the HIP
#      zero-copy shim (aesir_engine/zero_copy_shim.c) never resolves
#      hipMemcpy, and its memcpy counter is read back by the tests.
#   2. Vulkan backend = HOST_CACHED host-coherent memory ONLY
#      (VulkanBuffers.allocate_cached, A-019 extension of the A-014
#      shim): the A-008 measurements show the DEVICE_LOCAL coherent
#      type with DEVICE_UNCACHED_AMD reads back on the CPU at
#      0.11 GB/s - a ~300x trap - so the cached-coherent type is the
#      only Vulkan type this gateway will allocate, and the
#      uncached bit is refused outright. Dispatch reuses the A-015
#      vec_add kernel on the A-014 context; the Vulkan shim resolves
#      no copy entry point at all (its copy counter is structural).
#   3. NPU (XRT) buffer objects are NOT part of this slice (A-016
#      note); pinned host memory is a valid zero-copy path but beats
#      managed on nothing (A-008), so it is not a backend here.
#
# Checked-span discipline: every byte/element range a caller touches
# through this gateway is admitted through core/checked_span before
# any pointer arithmetic; out-of-range spans raise, never wrap.
#
# Fail-closed contract: when a backend's runtime is not loadable,
# its operations raise; nothing is simulated and no pointer is
# fabricated. Buffers are owned by the caller and must be released
# with ZeroCopy.free() exactly once.

from std.ffi import external_call
from std.memory import Pointer
from core.checked_span import checked_span, CheckedSpan
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation

comptime BACKEND_HIP_MANAGED = 1
comptime BACKEND_VULKAN_CACHED = 2
comptime _ZC_ABSENT = -1


struct ZeroCopyBuffer(Copyable, ImplicitlyCopyable):
    """One live zero-copy allocation: backend tag, requested byte
    size, and the backend's own handle (HIP managed pointer address
    or the A-014 Vulkan allocation)."""

    var backend: Int
    var size: Int
    var hip_addr: Int
    var vk: VulkanAllocation

    def __init__(
        out self, backend: Int, size: Int, hip_addr: Int, vk: VulkanAllocation
    ):
        self.backend = backend
        self.size = size
        self.hip_addr = hip_addr
        self.vk = vk


struct ZeroCopyCounters(Copyable, ImplicitlyCopyable):
    """Instrumentation snapshot proving the zero-copy path: kernel
    launches happened while every copy counter stayed at zero."""

    var hip_allocs: Int
    var hip_frees: Int
    var hip_live_bytes: Int
    var hip_kernel_launches: Int
    var hip_memcpy_calls: Int
    var vk_copy_calls: Int

    def __init__(
        out self,
        hip_allocs: Int,
        hip_frees: Int,
        hip_live_bytes: Int,
        hip_kernel_launches: Int,
        hip_memcpy_calls: Int,
        vk_copy_calls: Int,
    ):
        self.hip_allocs = hip_allocs
        self.hip_frees = hip_frees
        self.hip_live_bytes = hip_live_bytes
        self.hip_kernel_launches = hip_kernel_launches
        self.hip_memcpy_calls = hip_memcpy_calls
        self.vk_copy_calls = vk_copy_calls


struct ZeroCopy:
    """Static unified zero-copy allocator gateway (A-019)."""

    @staticmethod
    def hip_available() -> Bool:
        """True iff the zero-copy HIP shim loaded libamdhip64 +
        libhiprtc and resolved every entry point (incl. kernels)."""
        return external_call["aesir_zc_available", Int32]() == Int32(1)

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        if Int(rc) == _ZC_ABSENT:
            raise Error(
                "ZeroCopy." + what + ": HIP/HIPRTC runtime is not"
                " loadable on this host (honest-absent)"
            )
        raise Error(
            "ZeroCopy." + what + ": HIP call failed, code " + String(Int(rc))
        )

    @staticmethod
    def allocate(size_bytes: Int, backend: Int) raises -> ZeroCopyBuffer:
        """Allocate one zero-copy buffer of size_bytes on backend.

        The byte count is admitted through checked_span discipline.
        HIP managed is the A-008 default; Vulkan allocates the
        HOST_CACHED coherent type only (see file header).
        """
        if size_bytes <= 0:
            raise Error("ZeroCopy.allocate: size_bytes must be positive")
        var span = checked_span(0, size_bytes, size_bytes)
        if backend == BACKEND_HIP_MANAGED:
            var addr: Int = 0
            var rc = external_call["aesir_zc_hip_alloc_managed", Int32](
                Pointer(to=addr), UInt64(span.length)
            )
            if rc != 0:
                Self._raise_for_rc("allocate", rc)
            if addr == 0:
                raise Error("ZeroCopy.allocate: hipMallocManaged returned null")
            var dummy = VulkanAllocation(0, 0, 0, 0, 0)
            return ZeroCopyBuffer(backend, span.length, addr, dummy)
        if backend == BACKEND_VULKAN_CACHED:
            var vk = VulkanBuffers.allocate_cached(span.length)
            return ZeroCopyBuffer(backend, span.length, 0, vk)
        raise Error("ZeroCopy.allocate: unknown backend " + String(backend))

    @staticmethod
    def allocate_default(size_bytes: Int) raises -> ZeroCopyBuffer:
        """The A-008 default backend: HIP managed memory."""
        return Self.allocate(size_bytes, BACKEND_HIP_MANAGED)

    @staticmethod
    def free(buffer: ZeroCopyBuffer) raises:
        """Release a buffer exactly once (HIP hipFree / Vulkan free)."""
        if buffer.backend == BACKEND_HIP_MANAGED:
            if buffer.hip_addr == 0:
                return
            var ptr = Pointer[UInt8, MutUntrackedOrigin](
                unsafe_from_address=buffer.hip_addr
            )
            var rc = external_call["aesir_zc_hip_free", Int32](ptr)
            if rc != 0:
                Self._raise_for_rc("free", rc)
            return
        if buffer.backend == BACKEND_VULKAN_CACHED:
            VulkanBuffers.free(buffer.vk)
            return
        raise Error("ZeroCopy.free: unknown backend " + String(buffer.backend))

    @staticmethod
    def checked_f32_span(
        buffer: ZeroCopyBuffer, elem_offset: Int, elem_count: Int
    ) raises -> CheckedSpan:
        """Admit an [elem_offset, elem_offset+elem_count) Float32
        element span within the buffer's capacity. Raises on any
        out-of-range span; the returned span is the caller's proof."""
        var capacity = buffer.size // 4
        return checked_span(elem_offset, elem_count, capacity)

    @staticmethod
    def cpu_ptr(
        buffer: ZeroCopyBuffer,
    ) raises -> Pointer[UInt8, MutUntrackedOrigin]:
        """The CPU-side pointer for the buffer: the managed pointer
        itself (HIP - host and device share it) or a vkMapMemory
        mapping (Vulkan - release with release_cpu_ptr)."""
        if buffer.backend == BACKEND_HIP_MANAGED:
            if buffer.hip_addr == 0:
                raise Error("ZeroCopy.cpu_ptr: null HIP managed pointer")
            return Pointer[UInt8, MutUntrackedOrigin](
                unsafe_from_address=buffer.hip_addr
            )
        if buffer.backend == BACKEND_VULKAN_CACHED:
            return VulkanBuffers.map(buffer.vk)
        raise Error(
            "ZeroCopy.cpu_ptr: unknown backend " + String(buffer.backend)
        )

    @staticmethod
    def release_cpu_ptr(buffer: ZeroCopyBuffer) raises:
        """Release a cpu_ptr: a no-op for HIP managed memory (the
        pointer is the allocation), vkUnmapMemory for Vulkan."""
        if buffer.backend == BACKEND_VULKAN_CACHED:
            VulkanBuffers.unmap(buffer.vk)
            return
        if buffer.backend == BACKEND_HIP_MANAGED:
            return
        raise Error(
            "ZeroCopy.release_cpu_ptr: unknown backend "
            + String(buffer.backend)
        )

    @staticmethod
    def hip_transform(
        dst: ZeroCopyBuffer, src: ZeroCopyBuffer, n: Int
    ) raises:
        """GPU kernel: dst[i] = src[i]*2 + 1 for i in [0, n), Float32,
        launched by the zero-copy HIP shim (HIPRTC, gfx1151) directly
        on the managed pointers - the CPU-written src is read by the
        kernel with no copy call anywhere in the path. Both buffers
        must be HIP managed; n is admitted through checked spans on
        both sides before launch."""
        if src.backend != BACKEND_HIP_MANAGED or dst.backend != BACKEND_HIP_MANAGED:
            raise Error("ZeroCopy.hip_transform: both buffers must be HIP managed")
        _ = Self.checked_f32_span(src, 0, n)
        _ = Self.checked_f32_span(dst, 0, n)
        var rc = external_call["aesir_zc_hip_transform", Int32](
            Pointer[UInt8, MutUntrackedOrigin](
                unsafe_from_address=src.hip_addr
            ),
            Pointer[UInt8, MutUntrackedOrigin](
                unsafe_from_address=dst.hip_addr
            ),
            UInt32(n),
        )
        if rc != 0:
            Self._raise_for_rc("hip_transform", rc)

    @staticmethod
    def hip_fill(dst: ZeroCopyBuffer, n: Int) raises:
        """GPU kernel: dst[i] = ((i*37+11) % 997) * 0.5 - 100 for i in
        [0, n), Float32 - the GPU writes the managed buffer and the
        CPU reads it back directly (again, no copy call)."""
        if dst.backend != BACKEND_HIP_MANAGED:
            raise Error("ZeroCopy.hip_fill: buffer must be HIP managed")
        _ = Self.checked_f32_span(dst, 0, n)
        var rc = external_call["aesir_zc_hip_fill", Int32](
            Pointer[UInt8, MutUntrackedOrigin](
                unsafe_from_address=dst.hip_addr
            ),
            UInt32(n),
        )
        if rc != 0:
            Self._raise_for_rc("hip_fill", rc)

    @staticmethod
    def vk_vec_add(
        a: ZeroCopyBuffer, b: ZeroCopyBuffer, c: ZeroCopyBuffer, n: Int
    ) raises:
        """A-015 Vulkan compute dispatch on HOST_CACHED coherent
        buffers: c[i] = a[i] + b[i]. The kernel reads the CPU-written
        mapped memory directly; no staging or copy is involved."""
        if (
            a.backend != BACKEND_VULKAN_CACHED
            or b.backend != BACKEND_VULKAN_CACHED
            or c.backend != BACKEND_VULKAN_CACHED
        ):
            raise Error("ZeroCopy.vk_vec_add: all buffers must be Vulkan cached")
        VulkanBuffers.vec_add(a.vk, b.vk, c.vk, n)

    @staticmethod
    def counters() -> ZeroCopyCounters:
        """Live instrumentation counters from both backend shims."""
        return ZeroCopyCounters(
            Int(external_call["aesir_zc_alloc_count", UInt64]()),
            Int(external_call["aesir_zc_free_count", UInt64]()),
            Int(external_call["aesir_zc_live_bytes", UInt64]()),
            Int(external_call["aesir_zc_kernel_launch_count", UInt64]()),
            Int(external_call["aesir_zc_memcpy_call_count", UInt64]()),
            VulkanBuffers.copy_call_count(),
        )
