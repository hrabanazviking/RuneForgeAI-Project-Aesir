# HAILBRU register access layer (H068).
#
# Built on top of a mapped BAR: reg_read32, reg_write32, and
# reg_write32_verified (write + readback + compare), with offset
# bounds-checking against the BAR size BEFORE any memory access.
#
# MAPPING SOURCES (L12: HAILBRU is the only domain that mmaps BARs):
#  - map_sysfs_resource: root mmap of the sysfs `resourceN` file
#    (recon-only per H004 — permitted for H003-style recon reads).
#  - map_emulated: test hook mapping a scratch file (the write/readback
#    and ReadbackMismatch tests run here — H005 §6 found NO safe scratch
#    register on the live device, so ZERO writes go to live hardware).
#
# SÓLRÚN RE-SCOPE (H068, per H005 §6): the acceptance criterion's
# "write/readback of 50 random values to a scratch-safe register" is
# replaced by (a) 50x read-only coherency reads of the vendor-ID mirror
# at BAR0+0x0098 expecting 0x1e60 (study-prescribed), (b) full
# write/readback + ReadbackMismatch logic against the emulated mapping,
# (c) 10 bad-offset fail-closed tests. Live device: reads only.

from hailbru.errors import herror
from hailbru.syscall import (
    MAP_SHARED,
    O_RDONLY,
    O_RDWR,
    PROT_READ,
    PROT_WRITE,
    errno_name,
    errno_now,
    os_close,
    os_mmap,
    os_munmap,
    os_openat,
)
from std.memory import Pointer
from std.origin import MutUntrackedOrigin


struct BarMapping:
    var addr: Int64
    var size: Int
    var label: String

    def __init__(out self, addr: Int64, size: Int, label: String):
        self.addr = addr
        self.size = size
        self.label = label

    def ptr(self) -> Pointer[UInt8, MutUntrackedOrigin]:
        return Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=Int(self.addr)
        )


def map_sysfs_resource(
    arch: String,
    sysfs_root: String,
    bdf: String,
    bar_index: Int,
    size: Int,
    writable: Bool,
) raises -> BarMapping:
    # Recon mapping of a sysfs resourceN file (H004: recon-only).
    # Fails closed with PrivilegeRequired when not root.
    var path = (
        sysfs_root + "/bus/pci/devices/" + bdf
        + "/resource" + String(bar_index)
    )
    var flags = O_RDONLY()
    var prot = PROT_READ()
    if writable:
        flags = O_RDWR()
        prot = PROT_READ() | PROT_WRITE()
    var fd = os_openat(arch, path, flags, 0)
    if fd < 0:
        var e = errno_now()
        var code = "OsError"
        if e == 13 or e == 1:
            code = "PrivilegeRequired"
        raise herror(
            code,
            "open " + path + " failed: " + errno_name(e)
            + " (" + String(e) + ") — sysfs resource mmap needs root",
        )
    var addr = os_mmap(
        arch, Int64(size), prot, MAP_SHARED(), fd, 0
    )
    _ = os_close(arch, fd)
    if addr < 0:
        var e = errno_now()
        raise herror(
            "OsError",
            "mmap " + path + " failed: " + errno_name(e),
        )
    return BarMapping(addr, size, "sysfs:" + bdf + ":bar" + String(bar_index))


def map_emulated(arch: String, path: String, size: Int) raises -> BarMapping:
    # Test hook: mmap a scratch file as a fake BAR. All write/readback
    # tests run here — never against live hardware.
    var fd = os_openat(arch, path, O_RDWR(), 0)
    if fd < 0:
        var e = errno_now()
        raise herror(
            "OsError",
            "open emulated bar " + path + " failed: " + errno_name(e),
        )
    var addr = os_mmap(
        arch, Int64(size), PROT_READ() | PROT_WRITE(), MAP_SHARED(), fd, 0
    )
    _ = os_close(arch, fd)
    if addr < 0:
        var e = errno_now()
        raise herror(
            "OsError",
            "mmap emulated bar " + path + " failed: " + errno_name(e),
        )
    return BarMapping(addr, size, "emulated:" + path)


def unmap_bar(arch: String, m: BarMapping) raises:
    var r = os_munmap(arch, m.addr, Int64(m.size))
    if r != 0:
        var e = errno_now()
        raise herror("OsError", "munmap failed: " + errno_name(e))


def _check_offset(m: BarMapping, offset: Int, width: Int) raises:
    if offset < 0 or offset + width > m.size:
        raise herror(
            "RegOutOfRange",
            "offset 0x" + String(offset) + " + " + String(width)
            + " exceeds " + m.label + " size " + String(m.size),
        )
    if offset % width != 0:
        raise herror(
            "RegUnaligned",
            "offset 0x" + String(offset) + " not " + String(width)
            + "-byte aligned on " + m.label,
        )


def reg_read32(m: BarMapping, offset: Int) raises -> UInt32:
    _check_offset(m, offset, 4)
    var p = m.ptr()
    var v = UInt32(0)
    for i in range(4):
        v |= UInt32(p[unsafe_offset=offset + i]) << UInt32(8 * i)
    return v


def reg_read16(m: BarMapping, offset: Int) raises -> UInt16:
    _check_offset(m, offset, 2)
    var p = m.ptr()
    return UInt16(p[unsafe_offset=offset]) | (
        UInt16(p[unsafe_offset=offset + 1]) << UInt16(8)
    )


def reg_write32(m: BarMapping, offset: Int, v: UInt32) raises:
    _check_offset(m, offset, 4)
    var p = m.ptr()
    for i in range(4):
        p[unsafe_offset=offset + i] = UInt8(
            (v >> UInt32(8 * i)) & UInt32(0xFF)
        )


def reg_write32_verified(m: BarMapping, offset: Int, v: UInt32) raises:
    # Write + readback + compare. A write to a read-only register is
    # detected by readback mismatch and reported as named
    # ReadbackMismatch — never silently accepted (H068).
    reg_write32(m, offset, v)
    var back = reg_read32(m, offset)
    if back != v:
        raise herror(
            "ReadbackMismatch",
            "wrote 0x" + String(Int(v)) + " to " + m.label
            + "+0x" + String(offset) + ", read back 0x" + String(Int(back))
            + " (register is read-only or write-ignored)",
        )
