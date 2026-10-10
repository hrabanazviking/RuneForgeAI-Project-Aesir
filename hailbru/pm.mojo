# HAILBRU PCI power-management control (H083/H090, Campaign 5).
#
# Implements the clean-reset / power-state-cycle procedure using ONLY the
# documented PCI Power Management capability register (PMCSR). Writing the
# PMCSR power-state field is standard PCI power management — the same
# operation the kernel performs on suspend/resume — and is NOT a BAR
# register write (H005 section 6 governs BAR writes; C4 established this
# practice with setpci: "D3hot->D0 via PM-control 0xFC<-0x2008").
#
# State model used by Campaign 5:
#   D3hot = "reset/asserted" state (config-space reads return 0xFFFFFFFF,
#           vendor driver parked the device here)
#   D0    = "bootable/ready" state (BAR0 reads coherent, 0x0098 = 0x1e60)
#
# All functions take sysfs_root/bdf as parameters (no absolute paths).
# Requires root for the config-space write half (PrivilegeRequired).

from std.memory.alloc import unsafe_alloc
from hailbru.syscall import (
    O_RDWR,
    errno_name,
    errno_now,
    os_clock_ms,
    os_close,
    os_openat,
    os_pwrite,
    os_sleep_ms,
    read_file_bytes,
    read_file_str,
)
from hailbru.util import trim
from hailbru.errors import herror
from hailbru.regs import map_sysfs_resource, reg_read16, unmap_bar


def PM_STATE_D0() -> Int:
    return 0


def PM_STATE_D3HOT() -> Int:
    return 3


def pm_state_name(state: Int) -> String:
    if state == 0:
        return "D0"
    if state == 3:
        return "D3hot"
    return "D" + String(state)


def find_pm_cap(arch: String, sysfs_root: String, bdf: String) raises -> Int:
    # Walk the PCI capability list (config 0x34 -> next pointers) looking
    # for capability ID 0x01 (Power Management). Returns the cap offset.
    var cfg = read_file_bytes(
        arch, sysfs_root + "/bus/pci/devices/" + bdf + "/config", 256
    )
    if len(cfg) < 256:
        raise herror("ConfigReadFailed", "short config read for " + bdf)
    var ptr = Int(cfg[0x34]) & 0xFC
    var guard = 0
    while ptr != 0 and guard < 48:
        var cid = Int(cfg[ptr])
        if cid == 0x01:
            return ptr
        ptr = Int(cfg[ptr + 1]) & 0xFC
        guard += 1
    raise herror(
        "PowerManagementUnsupported",
        bdf + " has no PCI PM capability (cap walk exhausted)",
    )


def pm_read_pmcsr(
    arch: String, sysfs_root: String, bdf: String, pmcap: Int
) raises -> Int:
    var cfg = read_file_bytes(
        arch, sysfs_root + "/bus/pci/devices/" + bdf + "/config", 256
    )
    if len(cfg) < 256:
        raise herror("ConfigReadFailed", "short config read for " + bdf)
    var off = pmcap + 4
    return (Int(cfg[off + 1]) << 8) | Int(cfg[off])


def pm_write_pmcsr(
    arch: String, sysfs_root: String, bdf: String, pmcap: Int, val: Int
) raises:
    var path = sysfs_root + "/bus/pci/devices/" + bdf + "/config"
    var fd = os_openat(arch, path, O_RDWR(), 0)
    if fd < 0:
        var e = errno_now()
        _ = os_close(arch, fd)
        raise herror(
            "PrivilegeRequired",
            "cannot open config for write (need root): "
            + path
            + " errno "
            + errno_name(e),
        )
    var p = unsafe_alloc[UInt8](2)
    p[unsafe_offset=0] = UInt8(val & 0xFF)
    p[unsafe_offset=1] = UInt8((val >> 8) & 0xFF)
    var rc = os_pwrite(arch, fd, p, 2, Int64(pmcap + 4))
    p.unsafe_free()
    _ = os_close(arch, fd)
    if rc != 2:
        raise herror(
            "OsError",
            "short pwrite to PMCSR at " + bdf + " (wrote " + String(rc) + ")",
        )


def pm_read_power_state_file(
    arch: String, sysfs_root: String, bdf: String
) raises -> String:
    return trim(
        read_file_str(
            arch, sysfs_root + "/bus/pci/devices/" + bdf + "/power_state", 64
        )
    )


def pm_set_state(
    arch: String, sysfs_root: String, bdf: String, target: Int
) raises:
    # Assert a PCI power state via PMCSR; poll until the state lands or
    # the timeout expires (fail-closed with a named error + dump).
    var pmcap = find_pm_cap(arch, sysfs_root, bdf)
    var cur = pm_read_pmcsr(arch, sysfs_root, bdf, pmcap) & 0x3
    if cur == target:
        return
    var pmcsr = pm_read_pmcsr(arch, sysfs_root, bdf, pmcap)
    pm_write_pmcsr(arch, sysfs_root, bdf, pmcap, (pmcsr & 0xFFFC) | target)
    var deadline = os_clock_ms(arch) + 5000
    while os_clock_ms(arch) < deadline:
        var got = pm_read_pmcsr(arch, sysfs_root, bdf, pmcap) & 0x3
        if got == target:
            _ = os_sleep_ms(arch, 50)
            return
        _ = os_sleep_ms(arch, 25)
    var dump = (
        "target=" + pm_state_name(target) + " pmcsr=0x"
        + String(pm_read_pmcsr(arch, sysfs_root, bdf, pmcap))
        + " power_state="
        + pm_read_power_state_file(arch, sysfs_root, bdf)
    )
    raise herror("PowerTransitionFailed", bdf + " " + dump)


def pm_assert_state(
    arch: String, sysfs_root: String, bdf: String, target: Int
) raises -> String:
    # Transition, then verify functionally (not via the sysfs
    # power_state file — see note below). Returns the verified state name.
    #
    # NOTE (2026-10-10, measured on Mimir): the kernel's power_state
    # sysfs file does NOT follow manual PMCSR writes; it still reads
    # "D3hot" 5+ seconds after PMCSR reads back D0 and BAR0 reads are
    # fully coherent. The file is kernel-PCI-core bookkeeping that only
    # changes on kernel-initiated transitions. The authoritative signals
    # are therefore the PMCSR field readback (polled in pm_set_state)
    # plus a functional BAR probe here.
    pm_set_state(arch, sysfs_root, bdf, target)
    var want = pm_state_name(target)
    var m = map_sysfs_resource(arch, sysfs_root, bdf, 0, 0x4000, False)
    var mirror = Int(reg_read16(m, 0x0098))
    unmap_bar(arch, m)
    if target == 0 and mirror != 0x1E60:
        raise herror(
            "PowerTransitionFailed",
            bdf + " PMCSR=D0 but BAR0+0x0098 reads "
            + String(mirror) + " (want 0x1e60)",
        )
    if target == 3 and mirror != 0xFFFF:
        raise herror(
            "PowerTransitionFailed",
            bdf + " PMCSR=D3hot but BAR0+0x0098 reads "
            + String(mirror) + " (want 0xFFFF: D3hot all-ones behavior)",
        )
    return want
