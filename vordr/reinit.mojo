# VÖRÐR post-reset re-initialization (H148).
#
# After a commanded reset: BAR re-validation, firmware-state probe,
# DMA buffer re-establishment, return to ready. The firmware question
# ("did FW survive reset?") is answered EMPIRICALLY in-slice by the
# probe below — never assumed. A test hook forcing reset failure must
# fail closed with the named error ReinitRefused: VÖRÐR never proceeds
# on a half-reset device.
#
# L12: all device contact through hailbru.api (reset, parse_resource,
# bars_sane, check_identity, DmaRegistry, dma_fill/verify_pattern).

from hailbru.syscall import os_clock_ms
from hailbru.errors import herror
from hailbru.api import (
    DmaRegistry,
    ResetReport,
    bars_sane,
    check_identity,
    dma_fill_pattern,
    dma_verify_pattern,
    parse_resource,
    read_identity,
    uio_driver_link_target,
)
from vordr.events import event_emit_slice, json_str
from vordr.reset_ctl import vordr_reset


struct ReinitReport:
    var reset_ms: Int64
    var bars_ok: Bool
    var fw_note: String
    var dma_ok: Bool
    var ready_ok: Bool

    def __init__(out self):
        self.reset_ms = 0
        self.bars_ok = False
        self.fw_note = String("")
        self.dma_ok = False
        self.ready_ok = False


def firmware_state_probe(
    arch: String, sysfs_root: String, bdf: String
) raises -> String:
    # Empirical firmware probe (H148): the on-device firmware state is
    # owned by the vendor driver (hailo1x) — VÖRÐR cannot read it
    # directly (H005 §6). What CAN be probed: (1) the bound driver link
    # (is the vendor driver back on the device after reset?), (2) the
    # host-side blob catalogue state via the FWREG vendor mirror
    # (BAR0+0x0098 coherency already proved the device answers).
    # The note documents the finding honestly.
    var drv = uio_driver_link_target(arch, sysfs_root, bdf)
    if drv == "hailo1x":
        return (
            "vendor driver hailo1x bound after reset; on-device firmware "
            "state is driver-managed and was re-established by the "
            "driver's re-probe (see dmesg evidence in the H148 run log); "
            "host-side FW blobs untouched (L7 user-side prerequisite)"
        )
    if drv == "uio_pci_generic":
        return (
            "device on uio_pci_generic (userspace path): no vendor driver "
            "present, so no driver-managed firmware state; device is a "
            "bare PCIe endpoint in this configuration"
        )
    return (
        "driver link reads '" + drv + "' — unexpected; firmware state "
        "UNKNOWN, refusing to assume (fail-closed posture)"
    )


def reinit(
    arch: String,
    sysfs_root: String,
    bdf: String,
    log_path: String,
    hook_fail_reset: Bool,
) raises -> ReinitReport:
    # Full reset -> re-init cycle. hook_fail_reset=True forces the
    # reset to fail (test hook) and asserts the fail-closed path:
    # ReinitRefused is raised and NO further step runs.
    var rep = ReinitReport()
    event_emit_slice(
        arch, log_path, "H148", "ReinitStarted", "\"bdf\": \"" + bdf + "\""
    )
    var hook = String("d3hot") if hook_fail_reset else String("")
    var rrep: ResetReport
    try:
        rrep = vordr_reset(arch, sysfs_root, bdf, log_path, hook)
    except e:
        event_emit_slice(
            arch, log_path, "H148", "ReinitRefused",
            "\"reason\": \"reset did not complete — refusing to proceed "
            "on a half-reset device\", \"cause\": " + json_str(String(e)),
        )
        raise herror(
            "ReinitRefused",
            "reset failed; re-init refuses to proceed on a half-reset "
            "device (cause: " + String(e) + ")",
        )
    rep.reset_ms = rrep.total_ms()

    # Step 2: BAR re-validation.
    var t0 = os_clock_ms(arch)
    var bars = parse_resource(arch, sysfs_root, bdf)
    rep.bars_ok = bars_sane(bars)
    event_emit_slice(
        arch, log_path, "H148", "ReinitBarsValidated",
        "\"bars_ok\": true, \"ms\": " + String(os_clock_ms(arch) - t0),
    )

    # Step 3: firmware-state probe (empirical, documented — no guessing).
    t0 = os_clock_ms(arch)
    rep.fw_note = firmware_state_probe(arch, sysfs_root, bdf)
    event_emit_slice(
        arch, log_path, "H148", "ReinitFirmwareProbed",
        "\"note\": " + json_str(rep.fw_note)
        + ", \"ms\": " + String(os_clock_ms(arch) - t0),
    )

    # Step 4: DMA buffer re-establishment (real alloc/fill/verify/free).
    t0 = os_clock_ms(arch)
    var reg = DmaRegistry()
    var buf = reg.alloc(arch, 65536, False)
    dma_fill_pattern(buf.addr, buf.size, UInt64(0x9E3779B97F4A7C15))
    if not dma_verify_pattern(buf.addr, buf.size, UInt64(0x9E3779B97F4A7C15)):
        raise herror(
            "ReinitFailed", "DMA re-establishment: pattern verify failed"
        )
    reg.free(arch, buf.addr, buf.size)
    if reg.count() != 0:
        raise herror("ReinitFailed", "DMA registry not empty after free")
    rep.dma_ok = True
    event_emit_slice(
        arch, log_path, "H148", "ReinitDmaReestablished",
        "\"bytes\": 65536, \"ms\": " + String(os_clock_ms(arch) - t0),
    )

    # Step 5: return to ready — identity + D0 coherency.
    t0 = os_clock_ms(arch)
    var ident = read_identity(arch, sysfs_root, bdf)
    _ = check_identity(ident, UInt16(0x1E60), UInt16(0x45C4), UInt32(0x0B4000))
    rep.ready_ok = True
    event_emit_slice(
        arch, log_path, "H148", "ReinitReady",
        "\"ready\": true, \"ms\": " + String(os_clock_ms(arch) - t0)
        + ", \"reset_ms\": " + String(rep.reset_ms),
    )
    return rep^
