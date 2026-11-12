# core/hip_memory.mojo
# HipMemory: HIP device memory for the AMD ROCm / HIP realm (slice A-011).
#
# Real hipMalloc / hipFree / hipMallocManaged / hipMemcpy / hipMemGetInfo /
# hipGetDeviceCount / hipDeviceSynchronize calls, reached through the
# flat C ABI in aesir_engine/hip_memory_shim.c (libaesir_hip.so, staged
# and linked exactly like libaesir_hailo10h / libaesir_par; the shim
# header explains why dynamic loading lives in C: Mojo 1.0 cannot mix
# this repo's external_call dlopen idiom with stdlib OwnedDLHandle in
# one program — conflicting erased dlclose signatures, proven on
# purpleraider and filed in the A-011 ledger).
#
# Soname honesty: distro HIP runtime packages install the versioned
# soname only (libamdhip64.so.7); the unversioned libamdhip64.so symlink
# ships with the -dev package and is absent on purpleraider. The shim
# tries the unversioned name first, then versioned sonames. AMDGate's
# probe historically tried only the unversioned name and so reported
# the runtime absent on this machine while it was present; A-011
# extends that probe with the versioned name as well.
#
# Fail-closed contract: when the HIP runtime is not loadable, the shim
# reports unavailable and every operation here raises; nothing is
# simulated and no pointer is fabricated. Device allocations are owned
# by the caller and must be released with HipMemory.free() exactly once.
#
# Leak accounting contract (A-011 acceptance): warm up first — the HIP
# runtime reserves a one-time context/pool block on first use (proven
# on purpleraider: 148,971,520 bytes retained after the first 1,000
# mixed iterations, then exactly 0 further bytes across repeated
# 1,000-iteration rounds) — take the hipMemGetInfo baseline, run the
# iterations, and require the free-byte count to return to the baseline
# exactly.

from std.ffi import external_call
from std.memory import Pointer
from core.checked_span import checked_span

comptime _HIP_MEMCPY_HOST_TO_DEVICE = 1
comptime _HIP_MEMCPY_DEVICE_TO_HOST = 2
comptime _HIP_ABSENT = -1


struct HipMemInfo(Copyable, ImplicitlyCopyable):
    """Snapshot of hipMemGetInfo: free and total device-visible bytes."""

    var free_bytes: Int
    var total_bytes: Int

    def __init__(out self, free_bytes: Int, total_bytes: Int):
        self.free_bytes = free_bytes
        self.total_bytes = total_bytes


struct HipMemory:
    """Static HIP device-memory gateway (A-011). See file header."""

    @staticmethod
    def runtime_available() -> Bool:
        """True iff the shim loaded libamdhip64 and resolved every HIP
        entry point. Library-level probe; device presence is
        device_count()'s job."""
        return external_call["aesir_hip_available", Int32]() == Int32(1)

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        if Int(rc) == _HIP_ABSENT:
            raise Error(
                "HipMemory." + what + ": HIP runtime is not loadable on"
                " this host (honest-absent)"
            )
        raise Error(
            "HipMemory." + what + ": HIP call failed, code " + String(Int(rc))
        )

    @staticmethod
    def device_count() raises -> Int:
        """Real hipGetDeviceCount through the loaded runtime."""
        var count: Int32 = 0
        var rc = external_call["aesir_hip_device_count", Int32](
            Pointer(to=count)
        )
        if rc != 0:
            Self._raise_for_rc("device_count", rc)
        return Int(count)

    @staticmethod
    def mem_info() raises -> HipMemInfo:
        """Real hipMemGetInfo: (free, total) device-visible bytes."""
        var free_b: UInt64 = 0
        var total_b: UInt64 = 0
        var rc = external_call["aesir_hip_mem_get_info", Int32](
            Pointer(to=free_b), Pointer(to=total_b)
        )
        if rc != 0:
            Self._raise_for_rc("mem_info", rc)
        return HipMemInfo(Int(free_b), Int(total_b))

    @staticmethod
    def allocate(size_bytes: Int) raises -> Pointer[UInt8, MutUntrackedOrigin]:
        """hipMalloc: device-only allocation of size_bytes bytes."""
        if size_bytes <= 0:
            raise Error("HipMemory.allocate: size_bytes must be positive")
        var addr: Int = 0
        var rc = external_call["aesir_hip_malloc", Int32](
            Pointer(to=addr), UInt64(size_bytes)
        )
        if rc != 0:
            Self._raise_for_rc("allocate", rc)
        if addr == 0:
            raise Error("HipMemory.allocate: hipMalloc returned null")
        return Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)

    @staticmethod
    def allocate_managed(
        size_bytes: Int,
    ) raises -> Pointer[UInt8, MutUntrackedOrigin]:
        """hipMallocManaged (hipMemAttachGlobal): one pointer valid on
        both host and device — the unified-memory allocation on Strix
        Halo's shared pool."""
        if size_bytes <= 0:
            raise Error(
                "HipMemory.allocate_managed: size_bytes must be positive"
            )
        var addr: Int = 0
        var rc = external_call["aesir_hip_malloc_managed", Int32](
            Pointer(to=addr), UInt64(size_bytes)
        )
        if rc != 0:
            Self._raise_for_rc("allocate_managed", rc)
        if addr == 0:
            raise Error(
                "HipMemory.allocate_managed: hipMallocManaged returned null"
            )
        return Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)

    @staticmethod
    def free(ptr: Pointer[UInt8, MutUntrackedOrigin]) raises:
        """hipFree for either allocation kind. Null is a no-op (house
        style, cf. CUDAGate.free_vram); any other pointer must be a live
        HipMemory allocation, freed exactly once."""
        if Int(ptr) == 0:
            return
        var rc = external_call["aesir_hip_free", Int32](ptr)
        if rc != 0:
            Self._raise_for_rc("free", rc)

    @staticmethod
    def device_synchronize() raises:
        """hipDeviceSynchronize: block until device work completes."""
        var rc = external_call["aesir_hip_device_synchronize", Int32]()
        if rc != 0:
            Self._raise_for_rc("device_synchronize", rc)

    @staticmethod
    def memcpy_host_to_device(
        dst_dev: Pointer[UInt8, MutUntrackedOrigin],
        src_host: Pointer[UInt8, MutUntrackedOrigin],
        size_bytes: Int,
    ) raises:
        """hipMemcpy host->device, size in BYTES (never elements). The
        byte count is admitted through checked_span discipline."""
        var span = checked_span(0, size_bytes, size_bytes)
        if span.length == 0:
            return
        var rc = external_call["aesir_hip_memcpy", Int32](
            dst_dev, src_host, UInt64(span.length),
            Int32(_HIP_MEMCPY_HOST_TO_DEVICE),
        )
        if rc != 0:
            Self._raise_for_rc("memcpy_host_to_device", rc)

    @staticmethod
    def memcpy_device_to_host(
        dst_host: Pointer[UInt8, MutUntrackedOrigin],
        src_dev: Pointer[UInt8, MutUntrackedOrigin],
        size_bytes: Int,
    ) raises:
        """hipMemcpy device->host, size in BYTES (never elements)."""
        var span = checked_span(0, size_bytes, size_bytes)
        if span.length == 0:
            return
        var rc = external_call["aesir_hip_memcpy", Int32](
            dst_host, src_dev, UInt64(span.length),
            Int32(_HIP_MEMCPY_DEVICE_TO_HOST),
        )
        if rc != 0:
            Self._raise_for_rc("memcpy_device_to_host", rc)
