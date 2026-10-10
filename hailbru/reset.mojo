# HAILBRÚ device reset primitive (H147).
#
# Exposes the ONE reset VÖRÐR is allowed to command: reset() performs
# the C5-proven H083 "clean reset" cycle — PMCSR-asserted D3hot, verify,
# D0, BAR coherency — followed by a golden-map comparison against the
# H096 re-scoped golden (config dword0 identity + 5 BAR0 offsets).
# Only standard PCI PM is written (C4-established practice); ZERO BAR
# writes (H005 §6 governs BAR writes). VÖRÐR calls this through
# hailbru.api.reset() and never touches registers itself (L6/L12).
#
# The `hook_fail_at` test hook ("", "d3hot", "d0", "coherency",
# "golden") forces a named ResetFailed at that step — H148's
# fail-closed proof that re-init never proceeds on a half-reset device.

from hailbru.errors import herror
from hailbru.syscall import os_clock_ms, os_sleep_ms
from hailbru.pm import PM_STATE_D0, PM_STATE_D3HOT, pm_assert_state
from hailbru.api import (
    map_sysfs_resource,
    reg_read16,
    reg_read32,
    unmap_bar,
)


struct ResetStep:
    var name: String
    var ms: Int64
    var ok: Bool

    def __init__(out self, name: String, ms: Int64, ok: Bool):
        self.name = name
        self.ms = ms
        self.ok = ok


struct ResetReport:
    var steps: List[ResetStep]
    var golden_mismatches: List[String]

    def __init__(out self):
        self.steps = List[ResetStep]()
        self.golden_mismatches = List[String]()

    fn total_ms(self) -> Int64:
        var t = Int64(0)
        for i in range(len(self.steps)):
            t += self.steps[i].ms
        return t

    fn golden_clean(self) -> Bool:
        return len(self.golden_mismatches) == 0


fn _hex8(v: Int) -> String:
    var out = String("")
    var db = List[UInt8]()
    for b in String("0123456789abcdef").bytes():
        db.append(b)
    for i in range(8):
        var shift = (7 - i) * 4
        out += String(chr(Int(db[(v >> shift) & 0xF])))
    return out


def golden_check(
    arch: String, sysfs_root: String, bdf: String
) raises -> List[String]:
    # H096 re-scoped golden, D0 post-reset state. Every entry cites its
    # evidence: the C5 register_observations.json D0 snapshot and the
    # invariant PCI identity (1e60:45c4).
    var bad = List[String]()
    var m = map_sysfs_resource(arch, sysfs_root, bdf, 0, 0x4000, False)
    var checks = List[Int]()
    # (offset, expected) pairs.
    checks.append(0x0098)
    checks.append(0x1E60)
    checks.append(0x0188)
    checks.append(0x00000000)
    checks.append(0x018C)
    checks.append(0x00800000)
    checks.append(0x0400)
    checks.append(0x00000000)
    checks.append(0x0500)
    checks.append(0x00000000)
    var i = 0
    while i < len(checks):
        var off = checks[i]
        var want = checks[i + 1]
        var got: UInt32
        if off == 0x0098:
            got = UInt32(reg_read16(m, off))
        else:
            got = reg_read32(m, off)
        if Int(got) != want:
            bad.append(
                "BAR0+0x" + _hex8(off) + ": got 0x" + _hex8(Int(got))
                + ", golden 0x" + _hex8(want)
            )
        i += 2
    unmap_bar(arch, m)
    return bad


def reset(
    arch: String,
    sysfs_root: String,
    bdf: String,
    hook_fail_at: String,
) raises -> ResetReport:
    # Full commanded reset. Raises the NAMED error ResetFailed (never a
    # half-reset success) when any step — real or hook-forced — fails.
    var rep = ResetReport()

    var t0 = os_clock_ms(arch)
    if hook_fail_at == "d3hot":
        raise herror("ResetFailed", "test hook forced failure at d3hot step")
    _ = pm_assert_state(arch, sysfs_root, bdf, PM_STATE_D3HOT())
    rep.steps.append(ResetStep("d3hot", os_clock_ms(arch) - t0, True))

    t0 = os_clock_ms(arch)
    if hook_fail_at == "d0":
        raise herror("ResetFailed", "test hook forced failure at d0 step")
    _ = pm_assert_state(arch, sysfs_root, bdf, PM_STATE_D0())
    rep.steps.append(ResetStep("d0", os_clock_ms(arch) - t0, True))

    t0 = os_clock_ms(arch)
    if hook_fail_at == "coherency":
        raise herror("ResetFailed", "test hook forced failure at coherency step")
    var m = map_sysfs_resource(arch, sysfs_root, bdf, 0, 0x4000, False)
    var ok = True
    for k in range(5):
        if Int(reg_read16(m, 0x0098)) != 0x1E60:
            ok = False
        _ = os_sleep_ms(arch, 20)
    unmap_bar(arch, m)
    if not ok:
        raise herror(
            "ResetFailed",
            "post-reset coherency: BAR0+0x0098 != 0x1e60 after D0",
        )
    rep.steps.append(ResetStep("coherency", os_clock_ms(arch) - t0, True))

    t0 = os_clock_ms(arch)
    if hook_fail_at == "golden":
        raise herror("ResetFailed", "test hook forced failure at golden step")
    var bad = golden_check(arch, sysfs_root, bdf)
    for i in range(len(bad)):
        rep.golden_mismatches.append(bad[i])
    if len(bad) > 0:
        raise herror(
            "ResetFailed",
            "golden-map mismatch after reset: " + bad[0]
            + (" (+" + String(len(bad) - 1) + " more)" if len(bad) > 1 else ""),
        )
    rep.steps.append(ResetStep("golden", os_clock_ms(arch) - t0, True))
    return rep
