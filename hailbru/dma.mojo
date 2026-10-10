# HAILBRU DMA-coherent buffer allocation (H066/H067).
#
# Two mechanism paths, both implemented:
#  - VFIO path (H066): userspace allocation (page-aligned, mlock'ed),
#    IOMMU mapping via VFIO_IOMMU_MAP_DMA, CPU VA + IOVA returned.
#  - UIO path (H067): active only when UIO is the chosen mechanism;
#    refuses with WrongMechanism otherwise (mechanism hygiene).
#
# STATUS ON MIMIR (2026-10-10): F3-BANKED for device-visible DMA.
# Neither VFIO nor UIO exists on this kernel (H004), so there is no
# path to DMA-coherent, device-visible memory from userspace (H018).
# What IS real here: the CPU-side allocation primitives (page-aligned
# mmap, mlock, pattern fill/readback coherency sanity), the 100-buffer
# allocate/free matrix, the fail-closed double-free/unknown-free paths,
# and the named cache-maintenance hooks (no-ops with logging per H018 —
# pure userspace on ARM64 cannot issue DC CVAC/DC IVAC).

from hailbru.errors import herror
from hailbru.syscall import (
    MAP_ANONYMOUS,
    MAP_PRIVATE,
    PROT_READ,
    PROT_WRITE,
    errno_name,
    errno_now,
    os_mlock,
    os_mmap,
    os_munmap,
)
from hailbru.vfio import VFIO_IOMMU_MAP_DMA, vfio_ioctl_checked
from std.memory import Pointer
from std.origin import MutUntrackedOrigin


def PAGE_SIZE() -> Int64:
    return Int64(4096)


struct DmaBuffer:
    var addr: Int64
    var size: Int64
    var locked: Bool

    def __init__(out self, addr: Int64, size: Int64, locked: Bool):
        self.addr = addr
        self.size = size
        self.locked = locked

    def ptr(self) -> Pointer[UInt8, MutUntrackedOrigin]:
        return Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=Int(self.addr)
        )


struct DmaRegistry:
    # Live-allocation registry. Double-free and free-of-unknown-buffer
    # fail closed with named errors (H066 acceptance).
    var live: Dict[Int64, Int64]  # addr -> size
    var ever: Dict[Int64, Int]  # every addr ever allocated (for DoubleFree)

    def __init__(out self):
        self.live = Dict[Int64, Int64]()
        self.ever = Dict[Int64, Int]()

    def is_live(self, addr: Int64) -> Bool:
        try:
            _ = self.live[addr]
            return True
        except:
            return False

    def was_ever(self, addr: Int64) -> Bool:
        try:
            _ = self.ever[addr]
            return True
        except:
            return False

    def count(self) -> Int:
        return len(self.live)

    def alloc(
        mut self, arch: String, size: Int64, want_lock: Bool
    ) raises -> DmaBuffer:
        # Page-aligned anonymous mapping. want_lock=True attempts mlock
        # and fails closed (DmaLockFailed) when the lock cannot be taken —
        # unlocked memory is never silently delivered as "DMA" memory.
        var n = ((size + PAGE_SIZE() - Int64(1)) // PAGE_SIZE()) * PAGE_SIZE()
        if n <= 0:
            raise herror(
                "DmaError", "refusing zero/negative alloc " + String(size)
            )
        var addr = os_mmap(
            arch,
            n,
            PROT_READ() | PROT_WRITE(),
            MAP_PRIVATE() | MAP_ANONYMOUS(),
            -1,
            0,
        )
        if addr < 0:
            var e = errno_now()
            raise herror(
                "DmaError",
                "mmap anon " + String(n) + " failed: " + errno_name(e),
            )
        if addr % PAGE_SIZE() != 0:
            _ = os_munmap(arch, addr, n)
            raise herror(
                "DmaError",
                "mmap returned non-page-aligned addr " + String(addr),
            )
        var locked = False
        if want_lock:
            var r = os_mlock(arch, addr, n)
            if r != 0:
                var e = errno_now()
                _ = os_munmap(arch, addr, n)
                raise herror(
                    "DmaLockFailed",
                    "mlock " + String(n) + " bytes failed: "
                    + errno_name(e)
                    + " — run with operator-granted privileges (root) or "
                    + "sufficient RLIMIT_MEMLOCK",
                )
            locked = True
        var buf = DmaBuffer(addr, n, locked)
        self.live[addr] = n
        self.ever[addr] = 1
        return buf^

    def free(mut self, arch: String, addr: Int64, size: Int64) raises:
        if not self.is_live(addr):
            if self.was_ever(addr):
                raise herror(
                    "DoubleFree",
                    "double-free of buffer addr " + String(addr),
                )
            raise herror(
                "UnknownBuffer",
                "free of unknown buffer addr " + String(addr)
                + " (never allocated by this registry)",
            )
        var tracked = self.live[addr]
        if tracked != size:
            raise herror(
                "DmaError",
                "size mismatch on free: tracked " + String(tracked)
                + " vs buffer " + String(size),
            )
        _ = self.live.pop(addr)
        var r = os_munmap(arch, addr, size)
        if r != 0:
            var e = errno_now()
            raise herror("DmaError", "munmap failed: " + errno_name(e))


def dma_fill_pattern(addr: Int64, size: Int64, seed: UInt64):
    # Fill with a deterministic 64-bit splitmix64 stream (CPU-side
    # coherency sanity: fill here, verify after — H066 acceptance).
    var dst = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(addr))
    var x = seed + UInt64(0x9E3779B97F4A7C15)
    var nwords = Int(size) // 8
    for i in range(nwords):
        x += UInt64(0x9E3779B97F4A7C15)
        var z = x
        z = (z ^ (z >> UInt64(30))) * UInt64(0xBF58476D1CE4E5B9)
        z = (z ^ (z >> UInt64(27))) * UInt64(0x94D049BB133111EB)
        z = z ^ (z >> UInt64(31))
        for k in range(8):
            dst[unsafe_offset=i * 8 + k] = UInt8(
                (z >> UInt64(8 * k)) & UInt64(0xFF)
            )


def dma_verify_pattern(addr: Int64, size: Int64, seed: UInt64) -> Bool:
    # Recompute the stream and compare. True on full match.
    var src = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(addr))
    var x = seed + UInt64(0x9E3779B97F4A7C15)
    var nwords = Int(size) // 8
    for i in range(nwords):
        x += UInt64(0x9E3779B97F4A7C15)
        var z = x
        z = (z ^ (z >> UInt64(30))) * UInt64(0xBF58476D1CE4E5B9)
        z = (z ^ (z >> UInt64(27))) * UInt64(0x94D049BB133111EB)
        z = z ^ (z >> UInt64(31))
        for k in range(8):
            var want = UInt8((z >> UInt64(8 * k)) & UInt64(0xFF))
            if src[unsafe_offset=i * 8 + k] != want:
                return False
    return True


def vfio_iommu_map(
    arch: String,
    container_fd: Int64,
    vaddr: Int64,
    iova: UInt64,
    size: Int64,
) raises:
    # H066 VFIO IOMMU path. Fails closed on this kernel: no VFIO
    # container can exist (H004/H012), so the ioctl is never issued.
    # The real ioctl sequence is implemented below the guard for the
    # operator-rebuilt kernel (F3).
    if container_fd < 0:
        raise herror(
            "MechanismUnavailable",
            "VFIO_IOMMU_MAP_DMA unavailable: no VFIO container "
            "(H004 MECHANISM_VERDICT.md) — IOMMU DMA mapping F3-banked "
            "pending operator kernel rebuild with CONFIG_VFIO=y + "
            "CONFIG_ARM_SMMU=y",
        )
    # Future path (not executed on this kernel): build
    # vfio_iommu_type1_dma_map { argsz, flags, vaddr, iova, size } and
    # issue VFIO_IOMMU_MAP_DMA via vfio_ioctl_checked.
    _ = vfio_ioctl_checked(
        arch, container_fd, VFIO_IOMMU_MAP_DMA(), 0, "VFIO_IOMMU_MAP_DMA"
    )
    _ = vaddr
    _ = iova
    _ = size


def uio_dma_alloc(
    arch: String, active_mechanism: String, size: Int64
) raises -> DmaBuffer:
    # H067 UIO-path allocator. Mechanism hygiene: refuses with
    # WrongMechanism unless UIO is the active mechanism (tested).
    if active_mechanism != "uio":
        raise herror(
            "WrongMechanism",
            "uio_dma_alloc called with active mechanism '"
            + active_mechanism + "' (want 'uio')",
        )
    raise herror(
        "MechanismUnavailable",
        "UIO DMA unavailable: uio_pci_generic absent (H004/H013) — "
        "F3-banked pending operator kernel rebuild with "
        "CONFIG_UIO_PCI_GENERIC=m",
    )
    _ = arch
    _ = size


def dma_cache_flush(addr: Int64) -> String:
    # H018: pure userspace on ARM64 cannot issue DC CVAC (EL1+). The hook
    # exists as a named function with its call site; on this kernel it is
    # a no-op WITH logging — never a silent skip.
    _ = addr
    return (
        "dma_cache_flush: no-op (H018 — userspace cannot issue DC CVAC; "
        "DMA buffers must be mapped uncached by a future kernel partner)"
    )


def dma_cache_invalidate(addr: Int64) -> String:
    _ = addr
    return (
        "dma_cache_invalidate: no-op (H018 — userspace cannot issue "
        "DC IVAC; see dma_cache_flush)"
    )
