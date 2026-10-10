# VÖRÐR-commanded device reset (H147).
#
# The ONLY path by which VÖRÐR resets the device: it calls
# hailbru.api.reset() — the HAILBRÚ interface — and verifies the
# post-reset state. VÖRÐR never touches registers, BARs, or device
# nodes itself. AUDIT (L6/L12): this file imports NO hailbru module
# except hailbru.api and hailbru.syscall/hailbru.errors; the call graph
# VÖRÐR→reset()→(pm, regs) contains no register-level access from
# VÖRÐR's side. Grep evidence recorded in the H147 DEVLOG entry:
#   grep -rn "reg_read\|reg_write\|map_sysfs\|mmap\|ioctl" vordr/ => no hits.

from hailbru.syscall import os_clock_ms
from hailbru.errors import herror
from hailbru.api import ResetReport, reset
from vordr.events import event_emit_slice, json_str


def vordr_reset(
    arch: String,
    sysfs_root: String,
    bdf: String,
    log_path: String,
    hook_fail_at: String,
) raises -> ResetReport:
    # Command ONE reset through HAILBRÚ's interface. Emits
    # ResetCommanded before and ResetComplete/ResetFailed after — the
    # recovery state machine (H149) and the H147 50-cycle proof both
    # key off these events.
    var t0 = os_clock_ms(arch)
    event_emit_slice(
        arch, log_path, "H147", "ResetCommanded",
        "\"bdf\": \"" + bdf + "\", \"via\": \"hailbru.api.reset\"",
    )
    try:
        var rep = reset(arch, sysfs_root, bdf, hook_fail_at)
        var fields = String(
            "\"total_ms\": " + String(rep.total_ms())
            + ", \"golden_clean\": " + ("true" if rep.golden_clean() else "false")
        )
        var sfields = String("\"steps\": [")
        for i in range(len(rep.steps)):
            var st = rep.steps[i]
            sfields += (
                "{\"name\": \"" + st.name + "\", \"ms\": "
                + String(st.ms) + "}"
                + (", " if i + 1 < len(rep.steps) else "")
            )
        sfields += "]"
        event_emit_slice(
            arch, log_path, "H147", "ResetComplete",
            fields + ", " + sfields
            + ", \"wall_ms\": " + String(os_clock_ms(arch) - t0),
        )
        return rep^
    except e:
        event_emit_slice(
            arch, log_path, "H147", "ResetFailed",
            "\"wall_ms\": " + String(os_clock_ms(arch) - t0)
            + ", \"error\": " + json_str(String(e)),
        )
        raise e
