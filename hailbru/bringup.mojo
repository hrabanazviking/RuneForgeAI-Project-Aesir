# HAILBRU bring-up orchestrator (H081, Campaign 5).
#
# The ordered PM-cycle bring-up sequence as a single auditable function
# with per-step start/end timestamps. Under the current kernel the device
# cannot be firmware-booted (Phase-B NO-GO); "cold boot" here is the
# PM-cycle bring-up defined in docs/hailbru/COLD_BOOT_DEFINITION.md
# option (c): D3hot -> D0 -> verify -> ready-poll -> restore D3hot.
#
# "Ready" (READY_PM) = D0 + vendor-mirror register coherency + clean
# power-state cycle. Firmware-ready is F3-banked and stays banked.
#
# The firmware_load and boot_handshake steps are explicit F3-BANKED stubs:
# they emit a step_banked event citing the exact prerequisite (F3-4) and
# never pretend to run. Skipping any REAL step via the --omit-step test
# hook fails the boot with a named StepOmitted error — the steps are
# load-bearing, not ceremonial.
#
# Safety: the final step always restores D3hot (the state the vendor
# driver left the device in). A crashed run leaves at most D0; the next
# run's enter_d3hot step is idempotent.

from std.memory.alloc import unsafe_alloc
from hailbru.syscall import (
    cstr_to_string,
    os_clock_ms,
    os_readlinkat,
    os_sleep_ms,
    read_file_bytes,
    write_file_str,
)
from hailbru.errors import herror
from hailbru.config import check_identity, read_identity
from hailbru.bars import parse_resource
from hailbru.regs import (
    map_sysfs_resource,
    reg_read16,
    reg_read32,
    unmap_bar,
)
from hailbru.pm import (
    PM_STATE_D0,
    PM_STATE_D3HOT,
    find_pm_cap,
    pm_assert_state,
    pm_read_pmcsr,
    pm_read_power_state_file,
    pm_set_state,
)


def BRINGUP_EXPECTED_DRIVER() -> String:
    return "hailo1x"


def BRINGUP_EXPECTED_VENDOR() -> Int:
    return 0x1E60


def BRINGUP_EXPECTED_DEVICE() -> Int:
    return 0x45C4


def BRINGUP_EXPECTED_CLASS() -> Int:
    return 0x0B4000


def hex16(v: Int) -> String:
    var digits = "0123456789abcdef"
    var s = "0x"
    for i in range(4):
        var shift = 12 - i * 4
        s += digits[byte=(v >> shift) & 0xF]
    return s


struct BringupOpts:
    var log_path: String
    var omit_step: String
    var stall_step: String
    var step_budget_ms: Int64

    def __init__(
        out self,
        log_path: String = "",
        omit_step: String = "",
        stall_step: String = "",
        step_budget_ms: Int64 = 10000,
    ):
        self.log_path = log_path
        self.omit_step = omit_step
        self.stall_step = stall_step
        self.step_budget_ms = step_budget_ms


struct BringupLog:
    var lines: List[String]

    def __init__(out self):
        self.lines = List[String]()

    def emit(mut self, ts_ms: Int64, step: String, event: String,
             outcome: String, dur_ms: Int64, detail: String):
        # JSON-lines per docs/hailbru/BRINGUP_LOG_SCHEMA.md (H089).
        var line = (
            "{\"ts_ms\": " + String(ts_ms) + ", \"step\": \"" + step
            + "\", \"event\": \"" + event + "\", \"outcome\": \"" + outcome
            + "\", \"dur_ms\": " + String(dur_ms) + ", \"detail\": \""
            + detail + "\"}"
        )
        self.lines.append(line)

    def flush(self, arch: String, path: String) raises:
        var out = ""
        for i in range(len(self.lines)):
            out += self.lines[i] + "\n"
        write_file_str(arch, path, out)


struct StepCtx:
    var arch: String
    var sysfs_root: String
    var bdf: String
    var log_path: String
    var omit_step: String
    var stall_step: String
    var step_budget_ms: Int64
    var log: BringupLog

    def __init__(
        out self, arch: String, sysfs_root: String, bdf: String,
        opts: BringupOpts,
    ):
        self.arch = arch
        self.sysfs_root = sysfs_root
        self.bdf = bdf
        self.log_path = opts.log_path
        self.omit_step = opts.omit_step
        self.stall_step = opts.stall_step
        self.step_budget_ms = opts.step_budget_ms
        self.log = BringupLog()


def _step_start(mut ctx: StepCtx, name: String) raises -> Int64:
    var ts = os_clock_ms(ctx.arch)
    ctx.log.emit(ts, name, "step_start", "running", 0, "")
    if ctx.omit_step == name:
        ctx.log.emit(ts, name, "error", "failed", 0, "omitted by test hook")
        raise herror(
            "StepOmitted",
            "bring-up step '" + name + "' omitted by test hook; boot failed",
        )
    if ctx.stall_step == name:
        os_sleep_ms(ctx.arch, ctx.step_budget_ms + 6000)
    return ts


def _step_end(
    mut ctx: StepCtx, name: String, t_start: Int64, detail: String
) raises:
    var dur = os_clock_ms(ctx.arch) - t_start
    if dur > ctx.step_budget_ms + 5000:
        var dump = ""
        try:
            var vals = bringup_dump_registers(
                ctx.arch, ctx.sysfs_root, ctx.bdf
            )
            for i in range(len(vals)):
                dump += hex16(vals[i]) + " "
        except e:
            dump = "dump failed: " + String(e)
        raise herror(
            "BootHang",
            "step '" + name + "' exceeded budget+5s (" + String(dur)
            + "ms > " + String(ctx.step_budget_ms + 5000)
            + "ms); registers: " + dump,
        )
    ctx.log.emit(os_clock_ms(ctx.arch), name, "step_end", "ok", dur, detail)


def _bound_driver(arch: String, sysfs_root: String, bdf: String) raises -> String:
    var path = sysfs_root + "/bus/pci/devices/" + bdf + "/driver"
    var buf = unsafe_alloc[UInt8](512)
    var n = os_readlinkat(arch, path, buf, 512)
    if n < 0:
        buf.unsafe_free()
        raise herror("DriverBindingMismatch", bdf + " has no driver bound")
    var tmp = unsafe_alloc[UInt8](Int(n) + 1)
    for i in range(Int(n)):
        tmp[unsafe_offset=i] = buf[unsafe_offset=i]
    tmp[unsafe_offset=Int(n)] = 0
    var s = cstr_to_string(tmp, Int(n) + 1)
    tmp.unsafe_free()
    buf.unsafe_free()
    # basename after the last "/"
    var bs = List[UInt8]()
    for b in s.bytes():
        bs.append(b)
    var cut = -1
    for i in range(len(bs)):
        if bs[i] == 47:  # "/"
            cut = i
    if cut >= 0:
        var out = ""
        for i in range(cut + 1, len(bs)):
            out += String(chr(Int(bs[i])))
        return out
    return s


def bringup_dump_registers(
    arch: String, sysfs_root: String, bdf: String
) raises -> List[Int]:
    # Hang/evidence dump: 16 config-space dwords + 5 BAR0 registers when
    # the device is in D0 (>=10 values always, per H088).
    var cfg = read_file_bytes(
        arch, sysfs_root + "/bus/pci/devices/" + bdf + "/config", 64
    )
    if len(cfg) < 64:
        raise herror("ConfigReadFailed", "short config read for " + bdf)
    var vals = List[Int]()
    for i in range(16):
        vals.append(
            Int(cfg[i * 4])
            | (Int(cfg[i * 4 + 1]) << 8)
            | (Int(cfg[i * 4 + 2]) << 16)
            | (Int(cfg[i * 4 + 3]) << 24)
        )
    try:
        var m = map_sysfs_resource(arch, sysfs_root, bdf, 0, 0x4000, False)
        vals.append(Int(reg_read16(m, 0x0098)))
        vals.append(Int(reg_read32(m, 0x0188)))
        vals.append(Int(reg_read32(m, 0x018C)))
        vals.append(Int(reg_read32(m, 0x0400)))
        vals.append(Int(reg_read32(m, 0x0500)))
        unmap_bar(arch, m)
    except:
        pass
    return vals^


def run_bringup(
    arch: String, sysfs_root: String, bdf: String, opts: BringupOpts
) raises -> String:
    var ctx = StepCtx(arch, sysfs_root, bdf, opts)
    var t0 = os_clock_ms(arch)

    var ts = _step_start(ctx, "assert_binding")
    var drv = _bound_driver(arch, sysfs_root, bdf)
    if drv != BRINGUP_EXPECTED_DRIVER():
        raise herror(
            "DriverBindingMismatch",
            bdf + " bound to '" + drv + "', expected '"
            + BRINGUP_EXPECTED_DRIVER() + "'",
        )
    _step_end(ctx, "assert_binding", ts, "driver=" + drv)

    ts = _step_start(ctx, "read_initial_state")
    var ident = read_identity(arch, sysfs_root, bdf)
    _ = check_identity(
        ident,
        UInt16(BRINGUP_EXPECTED_VENDOR()),
        UInt16(BRINGUP_EXPECTED_DEVICE()),
        UInt32(BRINGUP_EXPECTED_CLASS()),
    )
    var ps0 = pm_read_power_state_file(arch, sysfs_root, bdf)
    var pmcap = find_pm_cap(arch, sysfs_root, bdf)
    var pmcsr0 = pm_read_pmcsr(arch, sysfs_root, bdf, pmcap)
    _step_end(
        ctx, "read_initial_state", ts,
        "power_state=" + ps0 + " pmcsr=" + hex16(pmcsr0)
        + " pmcap=" + hex16(pmcap),
    )

    ts = _step_start(ctx, "enter_d3hot")
    pm_set_state(arch, sysfs_root, bdf, PM_STATE_D3HOT())
    _step_end(ctx, "enter_d3hot", ts, "state=D3hot")

    ts = _step_start(ctx, "verify_d3hot")
    var st = pm_assert_state(arch, sysfs_root, bdf, PM_STATE_D3HOT())
    _step_end(ctx, "verify_d3hot", ts, "verified=" + st)

    ts = _step_start(ctx, "enter_d0")
    pm_set_state(arch, sysfs_root, bdf, PM_STATE_D0())
    _step_end(ctx, "enter_d0", ts, "state=D0")

    ts = _step_start(ctx, "bar_verify")
    var bars = parse_resource(arch, sysfs_root, bdf)
    if len(bars) == 0:
        raise herror("BarParseFailed", bdf + " has no BARs")
    var m = map_sysfs_resource(arch, sysfs_root, bdf, 0, 0x4000, False)
    var mirror = reg_read16(m, 0x0098)
    unmap_bar(arch, m)
    if Int(mirror) != BRINGUP_EXPECTED_VENDOR():
        raise herror(
            "VendorMirrorMismatch",
            "BAR0+0x0098 = " + hex16(Int(mirror)) + ", expected "
            + hex16(BRINGUP_EXPECTED_VENDOR()),
        )
    _step_end(
        ctx, "bar_verify", ts,
        "bars=" + String(len(bars)) + " mirror=" + hex16(Int(mirror)),
    )

    ts = _step_start(ctx, "ready_poll")
    var m2 = map_sysfs_resource(arch, sysfs_root, bdf, 0, 0x4000, False)
    var ok = 0
    for i in range(5):
        if Int(reg_read16(m2, 0x0098)) == BRINGUP_EXPECTED_VENDOR():
            ok += 1
    var status = reg_read32(m2, 0x018C)
    unmap_bar(arch, m2)
    if ok != 5:
        raise herror(
            "DeviceNotReady",
            "coherency " + String(ok) + "/5 at BAR0+0x0098",
        )
    _step_end(
        ctx, "ready_poll", ts,
        "coherency=5/5 irq_status=" + hex16(Int(status)),
    )

    # F3-banked steps: explicitly banked, never silently skipped.
    ctx.log.emit(
        os_clock_ms(arch), "firmware_load", "step_banked", "banked", 0,
        "F3-BANKED: needs F3-4 (IOMMU DMA + MSI) after kernel rebuild; "
        "see docs/hailbru/F3_UNBLOCK_RUNBOOK.md F3-4",
    )
    ctx.log.emit(
        os_clock_ms(arch), "boot_handshake", "step_banked", "banked", 0,
        "F3-BANKED: needs F3-4 (firmware DMA upload + boot handshake); "
        "see docs/hailbru/F3_UNBLOCK_RUNBOOK.md F3-4",
    )

    ts = _step_start(ctx, "restore_d3hot")
    pm_set_state(arch, sysfs_root, bdf, PM_STATE_D3HOT())
    _step_end(ctx, "restore_d3hot", ts, "device left undisturbed in D3hot")

    var total = os_clock_ms(arch) - t0
    var summary = (
        "{\"result\": \"READY_PM\", \"bdf\": \"" + bdf
        + "\", \"total_ms\": " + String(total)
        + ", \"ready_meaning\": \"D0 + vendor-mirror coherency + clean "
        + "power-state cycle; firmware boot F3-banked\"}"
    )
    ctx.log.emit(os_clock_ms(arch), "bringup", "info", "ok", total, summary)
    if ctx.log_path != "":
        ctx.log.flush(arch, ctx.log_path)
    return summary
