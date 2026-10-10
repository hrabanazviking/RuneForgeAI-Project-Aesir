# HAILBRU UIO fallback path (H065).
#
# The H004 fallback-order mechanism: only activated when VFIO is
# unavailable. Bind per the H013 dry-run plan, open /dev/uioN, mmap the
# BAR resource.
#
# STATUS ON MIMIR (2026-10-10, kernel 6.12.112-v8-16k-hailo+): UNBLOCKED.
# CONFIG_UIO_PCI_GENERIC=m; the bind/unbind/bind/restore SEQUENCE is
# real (uio_step_*), restoring hailo1x afterward. VFIO is NOT usable
# for 0001:01:00.0 (no IOMMU group, no CONFIG_VFIO_NOIOMMU) — UIO is
# the real userspace-driver path. Bind/unbind needs root.

from hailbru.errors import herror
from hailbru.syscall import (
    O_RDONLY,
    errno_name,
    errno_now,
    file_exists,
    list_dir,
    os_close,
    os_openat,
    os_readlinkat,
    read_file_str,
    write_file_str,
)
from hailbru.syscall import unsafe_alloc


def uio_find_nodes(arch: String, dev_root: String) raises -> List[String]:
    var names = list_dir(arch, dev_root)
    var out = List[String]()
    for i in range(len(names)):
        var n = names[i]
        var nb = List[UInt8]()
        for b in n.bytes():
            nb.append(b)
        if len(nb) >= 4 and nb[0] == 117 and nb[1] == 105 and nb[2] == 111:
            # "uio" prefix; rest must be digits.
            var ok = True
            for k in range(3, len(nb)):
                var c = Int(nb[k])
                if c < 48 or c > 57:
                    ok = False
                    break
            if ok:
                out.append(n)
    return out^


def uio_open(arch: String, dev_root: String) raises -> Int64:
    # Raises MechanismUnavailable when no /dev/uio* node exists.
    var nodes = uio_find_nodes(arch, dev_root)
    if len(nodes) == 0:
        raise herror(
            "MechanismUnavailable",
            "no /dev/uio* nodes under " + dev_root
            + " — uio_pci_generic absent (H004/H013); UIO path F3-banked",
        )
    var fd = os_openat(arch, dev_root + "/" + nodes[0], O_RDONLY(), 0)
    if fd < 0:
        var e = errno_now()
        raise herror(
            "UioError",
            "open " + nodes[0] + " failed: " + errno_name(e),
        )
    return fd


def uio_driver_link_target(
    arch: String, sysfs_root: String, bdf: String
) -> String:
    # Basename of the driver symlink target ("<none>" when unbound).
    var link = sysfs_root + "/bus/pci/devices/" + bdf + "/driver"
    var buf = unsafe_alloc[UInt8](512)
    var n = os_readlinkat(arch, link, buf, 511)
    if n < 0:
        buf.unsafe_free()
        return "<none>"
    var target = String("")
    for i in range(Int(n)):
        target += String(chr(Int(buf[unsafe_offset=i])))
    buf.unsafe_free()
    var bs = List[UInt8]()
    for b in target.bytes():
        bs.append(b)
    var slash = -1
    for i in range(len(bs)):
        if bs[i] == 47:
            slash = i
    if slash < 0:
        return target
    var base = String("")
    for i in range(slash + 1, len(bs)):
        base += String(chr(Int(bs[i])))
    return base


def _uio_gates(
    arch: String, sysfs_root: String, as_root: Bool
) raises:
    # Fail-closed gates shared by every bind/unbind step (H065).
    var uio_drv = sysfs_root + "/bus/pci/drivers/uio_pci_generic"
    # NOTE: new_id is write-only — check the driver directory itself.
    if not file_exists(arch, uio_drv):
        raise herror(
            "MechanismUnavailable",
            "uio_pci_generic not registered (no " + uio_drv
            + ") — H013: module absent from this kernel; bind F3-banked",
        )
    if not as_root:
        raise herror(
            "PrivilegeRequired",
            "bind/unbind needs root (operator-granted); refusing",
        )


def uio_step_unbind(
    arch: String, sysfs_root: String, bdf: String, as_root: Bool
) raises -> String:
    # Step 1: unbind the current driver. Returns the original driver name
    # so the caller can restore it later.
    _uio_gates(arch, sysfs_root, as_root)
    var original = uio_driver_link_target(arch, sysfs_root, bdf)
    var devdir = sysfs_root + "/bus/pci/devices/" + bdf
    write_file_str(arch, devdir + "/driver/unbind", bdf)
    return original


def uio_step_register_id(
    arch: String,
    sysfs_root: String,
    vendor_hex: String,
    device_hex: String,
    as_root: Bool,
) raises:
    # Step 2: register the vendor:device ID with uio_pci_generic.
    # Tolerates EEXIST (id already registered by an earlier run).
    _uio_gates(arch, sysfs_root, as_root)
    var uio_drv = sysfs_root + "/bus/pci/drivers/uio_pci_generic"
    try:
        write_file_str(arch, uio_drv + "/new_id", vendor_hex + " " + device_hex)
    except e:
        if "(17)" not in String(e):
            raise e


def uio_step_bind(
    arch: String, sysfs_root: String, bdf: String, as_root: Bool
) raises:
    # Step 3: bind the device to uio_pci_generic. NOTE: the kernel
    # auto-binds on new_id, so the device may already be bound here —
    # the explicit bind write is then skipped (it would fail EBUSY).
    _uio_gates(arch, sysfs_root, as_root)
    var uio_drv = sysfs_root + "/bus/pci/drivers/uio_pci_generic"
    var pre = uio_driver_link_target(arch, sysfs_root, bdf)
    if pre != "uio_pci_generic":
        try:
            write_file_str(arch, uio_drv + "/bind", bdf)
        except e:
            # Tolerate the auto-bind race: re-check the link.
            var raced = uio_driver_link_target(arch, sysfs_root, bdf)
            if raced != "uio_pci_generic":
                raise e
    var bound = uio_driver_link_target(arch, sysfs_root, bdf)
    if bound != "uio_pci_generic":
        raise herror(
            "BindError",
            "bind failed: driver link is '" + bound
            + "' (expected uio_pci_generic)",
        )


def uio_step_restore(
    arch: String, sysfs_root: String, bdf: String, original: String,
    as_root: Bool,
) raises -> String:
    # Step 4: unbind from uio_pci_generic and rebind the ORIGINAL driver.
    # Verifies the driver symlink points back at the original afterward
    # (H065 acceptance). Returns the restored driver name. Tolerates the
    # device not being on uio_pci_generic (bind may never have landed).
    _uio_gates(arch, sysfs_root, as_root)
    var uio_drv = sysfs_root + "/bus/pci/drivers/uio_pci_generic"
    var cur = uio_driver_link_target(arch, sysfs_root, bdf)
    if cur == "uio_pci_generic":
        write_file_str(arch, uio_drv + "/unbind", bdf)
    elif cur != "<none>":
        # Bound elsewhere unexpected — unbind from wherever it is.
        var curdrv = sysfs_root + "/bus/pci/drivers/" + cur
        write_file_str(arch, curdrv + "/unbind", bdf)
    var orig_drv = sysfs_root + "/bus/pci/drivers/" + original
    write_file_str(arch, orig_drv + "/bind", bdf)
    var restored = uio_driver_link_target(arch, sysfs_root, bdf)
    if restored != original:
        raise herror(
            "BindError",
            "RESTORE FAILED: driver link is '" + restored
            + "', original was '" + original + "' — operator attention "
            + "required (this is why the real path needs root + care)",
        )
    return restored


def uio_mmap_bar_offset(bar_index: Int) -> Int64:
    # UIO mmap contract: BARn maps at offset n * PAGE_SIZE on /dev/uioN.
    return Int64(bar_index) * Int64(4096)


def uio_node_for_bdf(
    arch: String, sysfs_root: String, bdf: String
) raises -> String:
    # The /dev/uioN node for a bound device: the device's sysfs
    # "uio" subdirectory contains exactly one uioN entry.
    var udir = sysfs_root + "/bus/pci/devices/" + bdf + "/uio"
    var names = list_dir(arch, udir)
    for i in range(len(names)):
        var n = names[i]
        var nb = List[UInt8]()
        for b in n.bytes():
            nb.append(b)
        if len(nb) >= 4 and nb[0] == 117 and nb[1] == 105 and nb[2] == 111:
            return n
    raise herror(
        "UioError",
        "no uioN entry under " + udir + " — device not bound to UIO?",
    )
