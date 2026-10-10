# VÖRÐR error-register polling + decode (H144).
#
# Reads the device's error/status registers on the monitor cadence and
# decodes set bits into NAMED error conditions. "Documented" here means
# honestly documented: the PCI configuration-space registers (standard
# PCI/PCIe bits — cited per bit) plus the BAR0 offsets the H005 study
# established. The BAR0 0x018C host-interrupt status bits are
# UNDOCUMENTED (H087) — any set bit there is reported as
# UnknownErrorBit(offset, bit): never ignored, never mislabeled.
#
# L12: live reads go through hailbru.api only (read_config_bytes,
# map_sysfs_resource/reg_read32/unmap_bar). The test hook injects a
# scripted register image instead of touching hardware.

from hailbru.syscall import os_clock_ms
from hailbru.errors import herror
from vordr.events import event_emit_slice


struct RegBit:
    # One decoded bit: name, meaning, severity, documented-or-not.
    var name: String
    var meaning: String
    var severity: String
    var documented: Bool

    def __init__(
        out self, name: String, meaning: String, severity: String, documented: Bool
    ):
        self.name = name
        self.meaning = meaning
        self.severity = severity
        self.documented = documented


struct DecodedError:
    var name: String
    var meaning: String
    var severity: String
    var offset: Int
    var bit: Int

    def __init__(
        out self, name: String, meaning: String, severity: String,
        offset: Int, bit: Int,
    ):
        self.name = name
        self.meaning = meaning
        self.severity = severity
        self.offset = offset
        self.bit = bit

    def to_fields(self) -> String:
        return (
            "\"name\": \"" + self.name + "\", \"meaning\": \""
            + self.meaning + "\", \"severity\": \"" + self.severity
            + "\", \"offset\": " + String(self.offset)
            + ", \"bit\": " + String(self.bit)
        )


def _bit(v: Int, b: Int) -> Bool:
    return (v >> b) & 1 == 1


def decode_pci_status(status: Int, mut out: List[DecodedError]):
    # PCI config Status register (offset 0x06, 16 bits). Bit meanings
    # per the PCI Local Bus Specification (standard, documented).
    # Appends into out (in place — DecodedError is move-only).
    var names = List[String]()
    var meanings = List[String]()
    var sevs = List[String]()
    var is_err = List[Bool]()
    for b in range(16):
        names.append("")
        meanings.append("")
        sevs.append("info")
        is_err.append(False)
    names[15] = "PciStatus.DetectedParityError"
    meanings[15] = "parity error detected on the bus (sticky)"
    sevs[15] = "error"
    is_err[15] = True
    names[14] = "PciStatus.SignaledSystemError"
    meanings[14] = "device asserted SERR# (sticky)"
    sevs[14] = "critical"
    is_err[14] = True
    names[13] = "PciStatus.ReceivedMasterAbort"
    meanings[13] = "master abort received (sticky)"
    sevs[13] = "error"
    is_err[13] = True
    names[12] = "PciStatus.ReceivedTargetAbort"
    meanings[12] = "target abort received (sticky)"
    sevs[12] = "error"
    is_err[12] = True
    names[11] = "PciStatus.SignaledTargetAbort"
    meanings[11] = "device signaled target abort (sticky)"
    sevs[11] = "error"
    is_err[11] = True
    names[10] = "PciStatus.DevselTiming"
    meanings[10] = "DEVSEL timing field (informational)"
    names[9] = "PciStatus.DevselTiming"
    meanings[9] = "DEVSEL timing field (informational)"
    names[8] = "PciStatus.MasterDataParityError"
    meanings[8] = "master data parity error (sticky)"
    sevs[8] = "error"
    is_err[8] = True
    names[7] = "PciStatus.FastBackToBack"
    meanings[7] = "fast back-to-back capable (informational)"
    names[5] = "PciStatus.Cap66MHz"
    meanings[5] = "66 MHz capable (informational)"
    names[4] = "PciStatus.CapabilitiesList"
    meanings[4] = "capabilities list present (informational)"
    names[3] = "PciStatus.InterruptStatus"
    meanings[3] = "interrupt status (informational)"
    for b in range(16):
        if _bit(status, b):
            if is_err[b]:
                out.append(DecodedError(names[b], meanings[b], sevs[b], 0x06, b))
            elif names[b].byte_length() > 0:
                out.append(DecodedError(names[b], meanings[b], "info", 0x06, b))
            else:
                out.append(DecodedError(
                    "UnknownErrorBit", "undocumented status bit set",
                    "warning", 0x06, b,
                ))
    return


def decode_pmcsr(pmcsr: Int, mut out: List[DecodedError]):
    # PCI Power Management Control/Status (PM cap + 4, 16 bits).
    # Appends into out (in place — DecodedError is move-only).
    if _bit(pmcsr, 15):
        out.append(DecodedError(
            "Pmcsr.PmeStatus",
            "PME status sticky bit set — device requested power-management event",
            "warning", 0x44, 15,
        ))
    if _bit(pmcsr, 8):
        out.append(DecodedError(
            "Pmcsr.PmeEn", "PME enabled (informational)", "info", 0x44, 8
        ))
    return


def decode_bar0_irq018c(status: UInt32, mut out: List[DecodedError]):
    # BAR0+0x018C host-interrupt status (H087). Bit meanings are
    # UNDOCUMENTED — every set bit becomes UnknownErrorBit, honestly.
    # Appends into out (in place — DecodedError is move-only).
    var v = Int(status)
    for b in range(32):
        if _bit(v, b):
            out.append(DecodedError(
                "UnknownErrorBit",
                "undocumented BAR0+0x018C interrupt bit set — never "
                "ignored, never mislabeled (H087)",
                "warning", 0x018C, b,
            ))
    return


def poll_decode_live(
    arch: String, sysfs_root: String, bdf: String, log_path: String
) raises -> List[DecodedError]:
    # Live poll via HAILBRÚ's public API only (L12): config-space
    # status dword + PMCSR via read_config_bytes, BAR0 0x018C via
    # map_sysfs_resource/reg_read32. Emits one RegisterErrorDecoded
    # event per named condition.
    from hailbru.api import map_sysfs_resource, read_config_bytes, reg_read32, unmap_bar

    var out = List[DecodedError]()
    var cfg = read_config_bytes(arch, sysfs_root, bdf, 64)
    var status = Int(cfg[6]) | (Int(cfg[7]) << 8)
    decode_pci_status(status, out)
    var m = map_sysfs_resource(arch, sysfs_root, bdf, 0, 0x4000, False)
    var irq = reg_read32(m, 0x018C)
    unmap_bar(arch, m)
    decode_bar0_irq018c(irq, out)
    for i in range(len(out)):
        event_emit_slice(
            arch, log_path, "H144", "RegisterErrorDecoded", out[i].to_fields()
        )
    return out^


def decode_image(image: List[Int]) -> List[DecodedError]:
    # Test-hook path: scripted register image, pairs of
    # (offset, value). Offsets: 0x06 = PCI status, 0x44 = PMCSR,
    # 0x018C = BAR0 irq status. Any other offset decodes as unknown.
    var out = List[DecodedError]()
    var i = 0
    while i + 1 < len(image):
        var off = image[i]
        var val = image[i + 1]
        if off == 0x06:
            decode_pci_status(val, out)
        elif off == 0x44:
            decode_pmcsr(val, out)
        elif off == 0x018C:
            decode_bar0_irq018c(UInt32(val), out)
        else:
            out.append(DecodedError(
                "UnknownErrorBit", "register offset not in the documented "
                "decode set", "warning", off, -1,
            ))
        i += 2
    return out^
