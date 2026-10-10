# HAILBRU PCI config-space access (H062, H071).
#
# Reads the sysfs `config` file of the discovered BDF: vendor ID, device
# ID, class code, and the capability pointers — all values read, none
# assumed. Standard capability walk (MSI/MSI-X/PM) plus extended
# capabilities (PCIe). Link status + power state from sysfs (H071).

from hailbru.errors import herror
from hailbru.syscall import read_file_bytes, read_file_str
from hailbru.util import trim


struct PciIdentity:
    var vendor: UInt16
    var device: UInt16
    var class_code: UInt32  # 24-bit: base/sub/interface
    var header_type: UInt8
    var cap_ptr: UInt8
    var msi_cap: Int  # offset or -1
    var msix_cap: Int  # offset or -1
    var pm_cap: Int  # offset or -1
    var pcie_ext_cap: Int  # extended-cap offset or -1
    var bytes_read: Int

    def __init__(
        out self,
        vendor: UInt16,
        device: UInt16,
        class_code: UInt32,
        header_type: UInt8,
        cap_ptr: UInt8,
        msi_cap: Int,
        msix_cap: Int,
        pm_cap: Int,
        pcie_ext_cap: Int,
        bytes_read: Int,
    ):
        self.vendor = vendor
        self.device = device
        self.class_code = class_code
        self.header_type = header_type
        self.cap_ptr = cap_ptr
        self.msi_cap = msi_cap
        self.msix_cap = msix_cap
        self.pm_cap = pm_cap
        self.pcie_ext_cap = pcie_ext_cap
        self.bytes_read = bytes_read


def cfg_u16(d: List[UInt8], off: Int) -> UInt16:
    return UInt16(d[off]) | (UInt16(d[off + 1]) << UInt16(8))


def cfg_u32(d: List[UInt8], off: Int) -> UInt32:
    var v = UInt32(0)
    for i in range(4):
        v |= UInt32(d[off + i]) << UInt32(8 * i)
    return v


def read_config_bytes(
    arch: String, sysfs_root: String, bdf: String, max_len: Int
) raises -> List[UInt8]:
    # Raises ConfigReadFailed (named) when the config file cannot be read.
    var path = sysfs_root + "/bus/pci/devices/" + bdf + "/config"
    try:
        return read_file_bytes(arch, path, Int64(max_len))
    except e:
        raise herror(
            "ConfigReadFailed",
            "cannot read config space of " + bdf + ": " + String(e),
        )


def read_identity(
    arch: String, sysfs_root: String, bdf: String
) raises -> PciIdentity:
    # Full identity + capability walk. Reads up to 4096 bytes (root sees
    # extended config; unprivileged sees 64 — both handled: short reads
    # simply find no extended caps).
    var d = read_config_bytes(arch, sysfs_root, bdf, 4096)
    if len(d) < 64:
        raise herror(
            "ConfigReadFailed",
            "config space of " + bdf + " too short: "
            + String(len(d)) + " bytes",
        )
    var vendor = cfg_u16(d, 0)
    var device = cfg_u16(d, 2)
    var class_code = (UInt32(d[11]) << UInt32(16)) | (
        UInt32(d[10]) << UInt32(8)
    ) | UInt32(d[9])
    var header_type = d[14]
    var status = cfg_u16(d, 6)
    var cap_ptr = d[52]
    var msi = -1
    var msix = -1
    var pm = -1
    var pcie_ext = -1
    # Standard capabilities (linked list from 0x34), if the status bit
    # (bit 4) says a list exists.
    if (status & UInt16(0x10)) != UInt16(0):
        var off = Int(cap_ptr)
        var guard = 0
        while off != 0 and off + 2 <= len(d) and guard < 64:
            var cid = d[off]
            var nxt = d[off + 1]
            if cid == 5:
                msi = off
            elif cid == 17:
                msix = off
            elif cid == 1:
                pm = off
            off = Int(nxt)
            guard += 1
    # Extended capabilities from 0x100 (PCIe etc.).
    if len(d) >= 260:
        var off = 256
        var guard = 0
        while off != 0 and off + 4 <= len(d) and guard < 64:
            var hdr = cfg_u32(d, off)
            var cid = Int(hdr & UInt32(0xFFFF))
            if cid == 0:
                break
            if cid == 16:
                pcie_ext = off
            off = Int((hdr >> UInt32(20)) & UInt32(0xFFF))
            guard += 1
            if off <= 256:
                break
    return PciIdentity(
        vendor, device, class_code, header_type, cap_ptr,
        msi, msix, pm, pcie_ext, len(d),
    )


def check_identity(
    ident: PciIdentity, vendor: UInt16, device: UInt16, class_code: UInt32
) raises -> Bool:
    # Identity drift detection (H062): any mismatch fails loudly.
    # Returns True on match; raises IdentityMismatch otherwise.
    if ident.vendor != vendor or ident.device != device:
        raise herror(
            "IdentityMismatch",
            "config space reads vendor:device "
            + String(Int(ident.vendor)) + ":" + String(Int(ident.device))
            + " but census expects "
            + String(Int(vendor)) + ":" + String(Int(device)),
        )
    if ident.class_code != class_code:
        raise herror(
            "IdentityMismatch",
            "config space class "
            + String(Int(ident.class_code))
            + " != census " + String(Int(class_code)),
        )
    return True


struct LinkStatus:
    var cur_speed: String
    var cur_width: String
    var max_speed: String
    var max_width: String

    def __init__(
        out self, cur_speed: String, cur_width: String,
        max_speed: String, max_width: String,
    ):
        self.cur_speed = cur_speed
        self.cur_width = cur_width
        self.max_speed = max_speed
        self.max_width = max_width


def read_link_status(
    arch: String, sysfs_root: String, bdf: String
) raises -> LinkStatus:
    var base = sysfs_root + "/bus/pci/devices/" + bdf + "/"
    return LinkStatus(
        trim(read_file_str(arch, base + "current_link_speed", 64)),
        trim(read_file_str(arch, base + "current_link_width", 64)),
        trim(read_file_str(arch, base + "max_link_speed", 64)),
        trim(read_file_str(arch, base + "max_link_width", 64)),
    )


def read_power_state(arch: String, sysfs_root: String, bdf: String) raises -> String:
    var base = sysfs_root + "/bus/pci/devices/" + bdf + "/"
    return trim(read_file_str(arch, base + "power_state", 64))
