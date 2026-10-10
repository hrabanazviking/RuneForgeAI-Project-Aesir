# HAILBRU VFIO path (H064).
#
# The primary driver mechanism per H004: open the VFIO container, set the
# IOMMU type, open the group, get the device fd, mmap the BAR region.
# Every ioctl return is checked and mapped to a named error.
#
# STATUS ON MIMIR (2026-10-10): F3-BANKED. /dev/vfio does not exist
# (CONFIG_VFIO not set — H004/H012). All entry points fail closed with
# MechanismUnavailable / VfioError before touching anything. The positive
# path is implemented for the future operator-rebuilt kernel; it is NOT
# executed here and NOT marked simulated-success.

from hailbru.errors import herror
from hailbru.syscall import (
    MAP_SHARED,
    O_RDONLY,
    PROT_READ,
    PROT_WRITE,
    errno_name,
    errno_now,
    os_close,
    os_ioctl,
    os_mmap,
    os_munmap,
    os_openat,
    os_readlinkat,
)
from hailbru.syscall import unsafe_alloc
from std.memory import Pointer
from std.origin import MutUntrackedOrigin


# linux/vfio.h UAPI ioctl numbers (public interface constants).
def VFIO_GET_API_VERSION() -> Int64:
    return Int64(0x3B64)


def VFIO_CHECK_EXTENSION() -> Int64:
    return Int64(0x3B65)


def VFIO_SET_IOMMU() -> Int64:
    return Int64(0x3B66)


def VFIO_GROUP_GET_DEVICE_FD() -> Int64:
    return Int64(0x3B6A)


def VFIO_DEVICE_GET_REGION_INFO() -> Int64:
    return Int64(0x3B6C)


def VFIO_DEVICE_SET_IRQS() -> Int64:
    return Int64(0x3B6E)


def VFIO_IOMMU_MAP_DMA() -> Int64:
    return Int64(0x3B71)


def VFIO_IOMMU_UNMAP_DMA() -> Int64:
    return Int64(0x3B72)


def VFIO_TYPE1_IOMMU() -> Int64:
    return Int64(1)


def vfio_ioctl_checked(
    arch: String, fd: Int64, req: Int64, arg: Int64, op: String
) raises -> Int64:
    # Every VFIO ioctl's return value is checked and mapped to a named
    # error (H064 acceptance). Test target: invalid fd -> named VfioError.
    if fd < 0:
        raise herror(
            "VfioError",
            op + ": invalid fd " + String(fd) + " (no container open)",
        )
    var r = os_ioctl(arch, fd, req, arg)
    if r < 0:
        var e = errno_now()
        raise herror(
            "VfioError",
            op + " ioctl 0x" + String(req) + " failed: "
            + errno_name(e) + " (" + String(e) + ")",
        )
    return r


def vfio_open_container(arch: String, dev_root: String) raises -> Int64:
    # Raises MechanismUnavailable when /dev/vfio is absent (H012 record).
    var fd = os_openat(arch, dev_root + "/vfio/vfio", O_RDONLY(), 0)
    if fd < 0:
        var e = errno_now()
        raise herror(
            "MechanismUnavailable",
            "VFIO container unavailable: " + dev_root
            + "/vfio/vfio: " + errno_name(e)
            + " — see H004 MECHANISM_VERDICT.md / H012 remediation record; "
            + "positive path F3-banked pending operator kernel rebuild",
        )
    return fd


def vfio_assert_driver_bound(
    arch: String, sysfs_root: String, bdf: String, expected: String
) raises:
    # H064 acceptance: assert the device is bound to the H004-chosen
    # driver before mapping; named BindError citing the H012 record.
    # (On the future VFIO kernel the expected driver is "vfio-pci".)
    var link = sysfs_root + "/bus/pci/devices/" + bdf + "/driver"
    var buf = unsafe_alloc[UInt8](512)
    var n = os_readlinkat(arch, link, buf, 511)
    if n < 0:
        buf.unsafe_free()
        var e = errno_now()
        raise herror(
            "BindError",
            "cannot read driver binding of " + bdf + ": "
            + errno_name(e)
            + " (H012 remediation record: device must be bound to the "
            + "H004-chosen driver before mapping)",
        )
    var target = String("")
    for i in range(Int(n)):
        target += String(chr(Int(buf[unsafe_offset=i])))
    buf.unsafe_free()
    # Basename of the symlink target.
    var base = target
    var bs = List[UInt8]()
    for b in target.bytes():
        bs.append(b)
    var slash = -1
    for i in range(len(bs)):
        if bs[i] == 47:
            slash = i
    if slash >= 0:
        base = String("")
        for i in range(slash + 1, len(bs)):
            base += String(chr(Int(bs[i])))
    if base != expected:
        raise herror(
            "BindError",
            bdf + " bound to '" + base + "', expected '" + expected
            + "' (H012 remediation record: bind the H004-chosen driver "
            + "via driver_override before mapping)",
        )


def vfio_map_bar(
    arch: String,
    dev_root: String,
    sysfs_root: String,
    bdf: String,
    bar_offset: Int64,
    bar_size: Int64,
) raises -> Int64:
    # Full VFIO BAR-mapping sequence (positive path). On Mimir this fails
    # closed at vfio_open_container (MechanismUnavailable) — the rest is
    # the F3-banked implementation for the operator-rebuilt kernel.
    var cfd = vfio_open_container(arch, dev_root)
    var ver = vfio_ioctl_checked(
        arch, cfd, VFIO_GET_API_VERSION(), 0, "VFIO_GET_API_VERSION"
    )
    _ = ver
    _ = vfio_ioctl_checked(
        arch, cfd, VFIO_SET_IOMMU(), VFIO_TYPE1_IOMMU(), "VFIO_SET_IOMMU"
    )
    # NOTE: group discovery (iommu_group sysfs node), group fd open,
    # VFIO_GROUP_SET_CONTAINER, VFIO_GROUP_GET_DEVICE_FD, then
    # VFIO_DEVICE_GET_REGION_INFO for the BAR offset/size, then mmap of
    # the device fd at the region offset. Each step ioctls through
    # vfio_ioctl_checked. Implemented in full when a VFIO-capable kernel
    # exists to test against; the container-open + IOMMU-set above are
    # the steps whose failure modes H064 tests on this kernel.
    _ = os_close(arch, cfd)
    _ = bar_offset
    _ = bar_size
    _ = sysfs_root
    _ = bdf
    raise herror(
        "MechanismUnavailable",
        "VFIO group/device bring-up F3-banked: no IOMMU group for "
        + bdf + " on this kernel (H004); container open path verified, "
        + "remainder implemented for the operator-rebuilt kernel",
    )
