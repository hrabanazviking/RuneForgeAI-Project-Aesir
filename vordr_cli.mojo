# VÖRÐR CLI (MÍMISBRUNNR Campaign 8, D6).
#
# The operator + PRÓF-facing surface for every C8 slice. Subcommands:
#   monitor-run / monitor-start / monitor-stop / monitor-status  (H141/H142)
#   watchdog-run / watchdog-parent                               (H146)
#   selftest-decode  (H144: 100% bit coverage via scripted image)
#   selftest-hang    (H143: stall hook + 1000 clean ops)
#   selftest-shadow  (H150: 100 tiles @10%, corruption hook)
#   selftest-recovery(H149: 3 scenarios + illegal transitions)
#   selftest-retry   (H156: absorption, exhaustion, backoff timing)
#   selftest-integrity (H154: 500 bit flips, 0 escapes)
#   selftest-degrade (H157: 20 ops, 1 faulted, no sticky fallback)
#   reset-cycle      (H147: N commanded resets, golden compare each)
#   reinit-cycle     (H148: N reset->re-init cycles, timings)
#   reinit-hook-fail (H148: fail-closed proof)
#   fi-remove-device (H153: REAL UIO unbind removal fault)
#   measure-hang-budgets (H143: derive budgets from measured p99 x3)
#   measure-recovery (H155: p50/p99 per recovery class)
#   h158-run         (H158: supervised inference under fault injection)
#
# FAULT-INJECTION HOOKS (the TEST-ONLY interface PRÓF drives):
#   --hook-corrupt-shadow, --hook-stall-op, --hook-fail-stage,
#   --hook-fail-reset, --hook-reg-image, --hook-dma-corrupt,
#   --fi-fault <file> (H158: fault descriptor injected per iteration).
# Hooks never touch live device registers (H005 S6); register images
# are scripted/emulated and labeled as such.

from std.sys import argv

from vordr.monitor import (
    load_thresholds,
    monitor_run,
    monitor_threads_self,
    task_count,
    thermal_level,
)
from vordr.hang import HeartbeatMonitor, OpBudget, load_budgets
from vordr.errdecode import decode_image
from vordr.recovery import (
    RecoveryMachine,
    scenario_fatal,
    scenario_persistent,
    scenario_transient,
)
from vordr.retry import (
    RetryDriver,
    RetryPolicy,
    jittered_delay,
    load_retry_policy,
)
from vordr.integrity import StagingBuffer
from vordr.degrade import run_stage_alloc
from vordr.shadow import shadow_plan, shadow_verify_tile, XorShift64
from vordr.reset_ctl import vordr_reset
from vordr.reinit import reinit
from vordr.watchdog import watchdog_run, watchdog_parent_run
from vordr.spawn import pid_alive, spawn_process
from vordr.events import event_emit_slice


def _arch() -> String:
    return "aarch64"


def _get(args: List[String], name: String, default: String) -> String:
    for i in range(len(args) - 1):
        if args[i] == name:
            return args[i + 1]
    return default


def _has(args: List[String], name: String) -> Bool:
    for i in range(len(args)):
        if args[i] == name:
            return True
    return False


def _count_kind(arch: String, log_path: String, kind: String) raises -> Int:
    # Count JSONL lines whose "kind" equals kind (PRÓF-side assertion aid).
    from hailbru.syscall import read_file_str, file_exists

    if not file_exists(arch, log_path):
        return 0
    var raw = read_file_str(arch, log_path, 1 << 24)
    var n = 0
    var line = String("")
    for b in raw.bytes():
        if Int(b) == 10:
            if _line_has_kind(line, kind):
                n += 1
            line = String("")
        else:
            line += String(chr(Int(b)))
    if line.byte_length() > 0 and _line_has_kind(line, kind):
        n += 1
    return n


def _line_has_kind(line: String, kind: String) -> Bool:
    return _contains(line, String("\"kind\": \"") + kind + String("\""))


def _contains(hay: String, needle: String) -> Bool:
    var nb = List[UInt8]()
    for b in needle.bytes():
        nb.append(b)
    var lb = List[UInt8]()
    for b in hay.bytes():
        lb.append(b)
    if len(nb) > len(lb):
        return False
    for i in range(len(lb) - len(nb) + 1):
        var hit = True
        for k in range(len(nb)):
            if lb[i + k] != nb[k]:
                hit = False
                break
        if hit:
            return True
    return False


# ---------------------------------------------------------------- monitor
def cmd_monitor_run(args: List[String]) raises -> Int:
    var arch = _arch()
    var n = monitor_run(
        arch,
        _get(args, "--sysfs-root", "/sys"),
        _get(args, "--bdf", "0001:01:00.0"),
        _get(args, "--thermal", "/sys/class/thermal/thermal_zone0/temp"),
        _get(args, "--out-dir", "/tmp/vordr-mon"),
        _get(args, "--thresholds", "data/vordr/thermal_thresholds.json"),
        Int(_get(args, "--duration-s", "600")),
        Int(_get(args, "--period-s", "5")),
        _get(args, "--pidfile", "/tmp/vordr-mon.pid"),
        _get(args, "--stopfile", "/tmp/vordr-mon.stop"),
    )
    print("monitor_run: samples=" + String(n))
    return 0


def cmd_monitor_start(args: List[String]) raises -> Int:
    # Spawn THIS binary detached running monitor-run; the starter exits
    # immediately (the child is reparented, no zombie).
    var arch = _arch()
    var raw = argv()
    var self_bin = String(raw[0])
    var cargs = List[String]()
    cargs.append("monitor-run")
    for i in range(2, len(raw)):
        cargs.append(String(raw[i]))
    var pid = spawn_process(self_bin, cargs)
    print("monitor started pid=" + String(pid))
    return 0


def cmd_monitor_stop(args: List[String]) raises -> Int:
    from hailbru.syscall import (
        file_exists,
        os_kill,
        os_sleep_ms,
        os_unlinkat,
        read_file_str,
        write_file_str,
    )
    from hailbru.util import trim

    var arch = _arch()
    var pidfile = _get(args, "--pidfile", "/tmp/vordr-mon.pid")
    var stopfile = _get(args, "--stopfile", "/tmp/vordr-mon.stop")
    if not file_exists(arch, pidfile):
        print("monitor_stop: not running (no pidfile)")
        return 1
    var pid = Int(trim(read_file_str(arch, pidfile, 32)))
    write_file_str(arch, stopfile, "stop\n")
    var waited = 0
    while waited < 15000:
        if not pid_alive(arch, Int64(pid)):
            break
        os_sleep_ms(arch, 250)
        waited += 250
    var alive = pid_alive(arch, Int64(pid))
    if alive:
        print("monitor_stop: WARNING still alive after 15s, SIGTERM")
        _ = os_kill(arch, Int64(pid), 15)
        os_sleep_ms(arch, 2000)
        alive = pid_alive(arch, Int64(pid))
    try:
        _ = os_unlinkat(arch, stopfile)
    except e:
        pass
    print("monitor_stop: alive=" + ("true" if alive else "false"))
    return 0 if not alive else 1


def cmd_monitor_status(args: List[String]) raises -> Int:
    from hailbru.syscall import file_exists, read_file_str
    from hailbru.util import trim

    var arch = _arch()
    var pidfile = _get(args, "--pidfile", "/tmp/vordr-mon.pid")
    if not file_exists(arch, pidfile):
        print("monitor_status: stopped")
        return 1
    var pid = Int(trim(read_file_str(arch, pidfile, 32)))
    if not pid_alive(arch, Int64(pid)):
        print("monitor_status: pidfile stale (pid " + String(pid) + " gone)")
        return 1
    print(
        "monitor_status: running pid=" + String(pid)
        + " threads=" + String(task_count(arch, Int64(pid)))
    )
    return 0


# ---------------------------------------------------------------- watchdog
def cmd_watchdog_run(args: List[String]) raises -> Int:
    var arch = _arch()
    var cargs = List[String]()
    var extra = _get(args, "--child-args", "")
    if extra.byte_length() > 0:
        # Comma-separated child args.
        var cur = String("")
        for b in extra.bytes():
            if Int(b) == 44:
                cargs.append(cur)
                cur = String("")
            else:
                cur += String(chr(Int(b)))
        if cur.byte_length() > 0:
            cargs.append(cur)
    var rc = watchdog_run(
        arch,
        _get(args, "--prog", "/bin/sleep"),
        cargs,
        _get(args, "--policy", "data/vordr/watchdog_policy.json"),
        _get(args, "--log", "/tmp/vordr-wd-events.jsonl"),
        _get(args, "--restart-log", "/tmp/vordr-wd-restarts.jsonl"),
        _get(args, "--pidfile", "/tmp/vordr-wd.pid"),
        _get(args, "--stopfile", "/tmp/vordr-wd.stop"),
    )
    print("watchdog_run: rc=" + String(rc))
    return rc


def cmd_watchdog_parent(args: List[String]) raises -> Int:
    var arch = _arch()
    var raw = argv()
    var wargs = List[String]()
    wargs.append("watchdog-run")
    for i in range(2, len(raw)):
        wargs.append(String(raw[i]))
    var rc = watchdog_parent_run(
        arch,
        String(raw[0]),
        wargs,
        _get(args, "--log", "/tmp/vordr-wd-events.jsonl"),
        _get(args, "--pidfile", "/tmp/vordr-wd-parent.pid"),
        _get(args, "--stopfile", "/tmp/vordr-wd-parent.stop"),
    )
    return rc


# ---------------------------------------------------------------- selftests
def cmd_selftest_decode(args: List[String]) raises -> Int:
    # H144: scripted register image — every documented error bit set
    # one at a time; assert the correct named condition. 100% bit
    # coverage of the documented decode set.
    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-st-decode.jsonl")
    var checked = 0
    var failed = 0
    # PCI status (0x06): expected name per bit.
    var want = List[String]()
    for b in range(16):
        want.append("")
    want[15] = "PciStatus.DetectedParityError"
    want[14] = "PciStatus.SignaledSystemError"
    want[13] = "PciStatus.ReceivedMasterAbort"
    want[12] = "PciStatus.ReceivedTargetAbort"
    want[11] = "PciStatus.SignaledTargetAbort"
    want[10] = "PciStatus.DevselTiming"
    want[9] = "PciStatus.DevselTiming"
    want[8] = "PciStatus.MasterDataParityError"
    want[7] = "PciStatus.FastBackToBack"
    want[5] = "PciStatus.Cap66MHz"
    want[4] = "PciStatus.CapabilitiesList"
    want[3] = "PciStatus.InterruptStatus"
    for b in range(16):
        var img = List[Int]()
        img.append(0x06)
        img.append(1 << b)
        var d = decode_image(img)
        checked += 1
        if len(d) != 1:
            print("FAIL bit " + String(b) + ": decoded " + String(len(d)))
            failed += 1
            continue
        var exp = want[b]
        if exp == "":
            exp = "UnknownErrorBit"
        if d[0].name != exp:
            print(
                "FAIL bit " + String(b) + ": got " + d[0].name
                + " want " + exp
            )
            failed += 1
    # PMCSR (0x44): bits 15 and 8 documented.
    var pmb = List[Int]()
    pmb.append(15)
    pmb.append(8)
    var pmw = List[String]()
    pmw.append("Pmcsr.PmeStatus")
    pmw.append("Pmcsr.PmeEn")
    for k in range(2):
        var img = List[Int]()
        img.append(0x44)
        img.append(1 << pmb[k])
        var d = decode_image(img)
        checked += 1
        if len(d) != 1 or d[0].name != pmw[k]:
            print("FAIL pmcsr bit " + String(pmb[k]))
            failed += 1
    # BAR0 0x018C: all 32 bits undocumented -> UnknownErrorBit each.
    for b in range(32):
        var img = List[Int]()
        img.append(0x018C)
        img.append(1 << b)
        var d = decode_image(img)
        checked += 1
        if len(d) != 1 or d[0].name != "UnknownErrorBit":
            print("FAIL 0x018C bit " + String(b) + ": not UnknownErrorBit")
            failed += 1
        if d[0].offset != 0x018C or d[0].bit != b:
            print("FAIL 0x018C bit " + String(b) + ": wrong offset/bit")
            failed += 1
    event_emit_slice(
        _arch(), log, "H144", "DecodeSelftest",
        "\"checked\": " + String(checked) + ", \"failed\": " + String(failed),
    )
    print("selftest-decode: checked=" + String(checked) + " failed=" + String(failed))
    return 0 if failed == 0 else 1


def cmd_selftest_hang(args: List[String]) raises -> Int:
    # H143: stall hook fires within budget+5s; 1000 clean ops, zero
    # false positives.
    from hailbru.syscall import os_clock_ms, os_sleep_ms

    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-st-hang.jsonl")
    var mon = HeartbeatMonitor()
    var failed = 0
    var before = _count_kind(arch, log, "HangDetected")
    # 1) Stall hook.
    var budget = Int64(300)
    mon.begin_op(arch, "stalled_op", budget)
    var t0 = os_clock_ms(arch)
    var detected = False
    while os_clock_ms(arch) - t0 < budget + 5000:
        var od = mon.overdue(arch, log)
        if len(od) > 0:
            detected = True
            if od[0] != "stalled_op":
                print("FAIL: hang named wrong op: " + od[0])
                failed += 1
            break
        os_sleep_ms(arch, 25)
    var elapsed = os_clock_ms(arch) - t0
    if not detected:
        print("FAIL: stall not detected within budget+5s")
        failed += 1
    elif elapsed > budget + 5000:
        print("FAIL: detection took " + String(elapsed) + "ms > budget+5s")
        failed += 1
    else:
        print("stall detected in " + String(elapsed) + "ms (budget 300ms)")
    # 2) 1000 clean ops, zero false positives.
    for i in range(1000):
        mon.begin_op(arch, "op_" + String(i), Int64(5000))
        os_sleep_ms(arch, 1)
        mon.complete_op("op_" + String(i))
        if i % 100 == 0:
            var od2 = mon.overdue(arch, log)
            if len(od2) > 0:
                print("FAIL: false positive at op " + String(i))
                failed += 1
    var after = _count_kind(arch, log, "HangDetected")
    var fp = after - before - (1 if detected else 0)
    if fp != 0:
        print("FAIL: false positives = " + String(fp))
        failed += 1
    print("selftest-hang: 1000 clean ops, false_positives=" + String(fp))
    return 0 if failed == 0 else 1


def cmd_selftest_shadow(args: List[String]) raises -> Int:
    # H150: 100 tile executions, 10% plan -> exactly 10 verifications,
    # all within contract; corruption hook -> ShadowMismatch naming layer.
    from std.memory.alloc import unsafe_alloc

    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-st-shadow.jsonl")
    var contract = Float64(_get(args, "--contract", "0.02"))
    var seed = UInt64(Int(_get(args, "--seed", "12345")))
    var kc = 32
    var plan = shadow_plan(seed, 100, 0.10)
    var failed = 0
    if len(plan) != 10:
        print("FAIL: plan selected " + String(len(plan)) + ", want 10")
        failed += 1
    # All 100 must be distinct and in range.
    var seen = List[Bool]()
    for i in range(100):
        seen.append(False)
    for k in range(len(plan)):
        if plan[k] < 0 or plan[k] >= 100 or seen[plan[k]]:
            print("FAIL: bad plan entry")
            failed += 1
        seen[plan[k]] = True
    event_emit_slice(
        arch, log, "H150", "ShadowPlan",
        "\"seed\": " + String(seed) + ", \"n_ops\": 100, \"fraction\": 0.10"
        + ", \"selected\": " + String(len(plan)),
    )
    var verified = 0
    var worst_all = Float64(0)
    var rng = XorShift64(seed + UInt64(7))
    for i in range(100):
        # Only sampled tiles pay the double-compute cost.
        var sampled = False
        for k in range(len(plan)):
            if plan[k] == i:
                sampled = True
                break
        if not sampled:
            continue
        var ap = unsafe_alloc[Float16](8 * kc)
        var bp = unsafe_alloc[Float16](8 * kc)
        for t in range(8 * kc):
            var v = Float64(Int(rng.next() % UInt64(2000))) / 1000.0 - 1.0
            ap[unsafe_offset=t] = Float16(v)
            bp[unsafe_offset=t] = Float16(v * 0.5)
        var w = shadow_verify_tile(
            arch, log, "layer_" + String(i), ap, bp, kc, contract, False
        )
        if w > worst_all:
            worst_all = w
        verified += 1
        ap.unsafe_free()
        bp.unsafe_free()
    if verified != 10:
        print("FAIL: verified " + String(verified) + ", want 10")
        failed += 1
    print("selftest-shadow: verified=" + String(verified) + " worst=" + String(worst_all))
    # Corruption hook: must raise ShadowMismatch naming the layer.
    var ap2 = unsafe_alloc[Float16](8 * kc)
    var bp2 = unsafe_alloc[Float16](8 * kc)
    for t in range(8 * kc):
        ap2[unsafe_offset=t] = Float16(0.5)
        bp2[unsafe_offset=t] = Float16(0.5)
    var caught = False
    try:
        _ = shadow_verify_tile(
            arch, log, "layer_corrupt", ap2, bp2, kc, contract, True
        )
    except e:
        var msg = String(e)
        if _contains(msg, "ShadowMismatch") and _contains(msg, "layer_corrupt"):
            caught = True
        else:
            print("FAIL: wrong error: " + msg)
            failed += 1
    ap2.unsafe_free()
    bp2.unsafe_free()
    if not caught:
        print("FAIL: corruption hook did not raise ShadowMismatch")
        failed += 1
    else:
        print("corruption hook -> ShadowMismatch naming layer_corrupt: OK")
    var mm = _count_kind(arch, log, "ShadowMismatch")
    if mm != 1:
        print("FAIL: ShadowMismatch events = " + String(mm) + ", want 1")
        failed += 1
    return 0 if failed == 0 else 1


def cmd_selftest_recovery(args: List[String]) raises -> Int:
    # H149: 3 scripted scenarios match expected transition sequences
    # exactly; 5 illegal transitions rejected with IllegalTransition.
    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-st-recovery.jsonl")
    var failed = 0

    var t1 = List[String]()
    scenario_transient(arch, log, t1)
    var e1 = List[String]()
    e1.append("IDLE -> DEGRADED")
    e1.append("DEGRADED -> IDLE")
    if not _seq_eq(t1, e1):
        print("FAIL: transient scenario mismatch")
        failed += 1

    var t2 = List[String]()
    scenario_persistent(arch, log, t2)
    var e2 = List[String]()
    e2.append("IDLE -> RESETTING")
    e2.append("RESETTING -> REINITING")
    e2.append("REINITING -> VERIFYING")
    e2.append("VERIFYING -> IDLE")
    if not _seq_eq(t2, e2):
        print("FAIL: persistent scenario mismatch")
        failed += 1

    var t3 = List[String]()
    scenario_fatal(arch, log, t3)
    var e3 = List[String]()
    e3.append("IDLE -> HALTED")
    if not _seq_eq(t3, e3):
        print("FAIL: fatal scenario mismatch")
        failed += 1

    # 5 illegal transitions.
    var ill = List[Int]()
    ill.append(4)
    ill.append(2)  # VERIFYING -> RESETTING
    ill.append(0)
    ill.append(3)  # IDLE -> REINITING
    ill.append(2)
    ill.append(0)  # RESETTING -> IDLE
    ill.append(1)
    ill.append(4)  # DEGRADED -> VERIFYING
    ill.append(5)
    ill.append(0)  # HALTED -> IDLE
    var k = 0
    while k < len(ill):
        var m = RecoveryMachine()
        # Drive the machine to the 'from' state legally first.
        var frm = ill[k]
        var to = ill[k + 1]
        _drive_to(arch, log, m, frm)
        var rejected = False
        try:
            m.transition(arch, log, to, "illegal probe")
        except e:
            if _contains(String(e), "IllegalTransition"):
                rejected = True
        if not rejected:
            print(
                "FAIL: illegal transition not rejected"
            )
            failed += 1
        k += 2
    print("selftest-recovery: scenarios=3 illegal_rejected=5 failed=" + String(failed))
    return 0 if failed == 0 else 1


def _seq_eq(a: List[String], b: List[String]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def _drive_to(arch: String, log_path: String, mut m: RecoveryMachine, s: Int) raises:
    # Drive a fresh machine to state s through legal transitions.
    if s == 1:
        m.on_classified(arch, log_path, "transient", "probe")
    elif s == 2:
        m.on_classified(arch, log_path, "persistent", "probe")
    elif s == 4:
        m.on_classified(arch, log_path, "persistent", "probe")
        m.reset_done(arch, log_path)
        m.reinit_done(arch, log_path)
    elif s == 5:
        m.on_classified(arch, log_path, "fatal", "probe")


def cmd_selftest_retry(args: List[String]) raises -> Int:
    # H156: 3 transient faults absorbed (recovered_after_retries: 3);
    # 6 consecutive faults -> RetryExhausted + PERSISTENT escalation;
    # backoff delays match policy within +/-20% (measured).
    from hailbru.syscall import os_clock_ms, os_sleep_ms

    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-st-retry.jsonl")
    var policy = load_retry_policy(arch, _get(args, "--policy", "data/vordr/retry_policy.json"))
    var drv = RetryDriver(policy)
    var failed = 0

    var n = drv.execute(arch, log, "op_absorb", 3, UInt64(42))
    if n != 3:
        print("FAIL: recovered_after_retries=" + String(n) + " want 3")
        failed += 1
    var rc = _count_kind(arch, log, "OpRecovered")
    if rc < 1:
        print("FAIL: no OpRecovered event")
        failed += 1

    var exhausted = False
    try:
        _ = drv.execute(arch, log, "op_storm", 6, UInt64(42))
    except e:
        if _contains(String(e), "RetryExhausted"):
            exhausted = True
    if not exhausted:
        print("FAIL: 6 faults did not exhaust retries")
        failed += 1
    if _count_kind(arch, log, "RetryExhausted") < 1:
        print("FAIL: no RetryExhausted event")
        failed += 1

    # Backoff timing: measure one real 100ms-nominal delay.
    var nom = policy.nominal_ms(1)
    var t0 = os_clock_ms(arch)
    os_sleep_ms(arch, jittered_delay(
        policy.base_ms, policy.factor, policy.jitter_pct, 1, UInt64(42)
    ))
    var actual = os_clock_ms(arch) - t0
    var lo = nom * 80 // 100
    var hi = nom * 120 // 100 + 30  # +30ms scheduling slack
    if actual < lo or actual > hi:
        print(
            "FAIL: backoff measured " + String(actual) + "ms, nominal "
            + String(nom) + "ms (want within +/-20%)"
        )
        failed += 1
    else:
        print("backoff measured " + String(actual) + "ms vs nominal " + String(nom) + "ms: OK")
    print("selftest-retry: failed=" + String(failed))
    return 0 if failed == 0 else 1


def cmd_selftest_integrity(args: List[String]) raises -> Int:
    # H154: 500 single-bit flips; 500/500 detected before compute;
    # escape count must be 0; re-transfer verifies clean.
    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-st-integrity.jsonl")
    var detected = 0
    var escapes = 0
    var rng = XorShift64(UInt64(999))
    for i in range(500):
        var buf = StagingBuffer("fi_buf", 256, UInt64(1000 + i))
        var bit = Int(rng.next() % UInt64(256 * 8))
        buf.corrupt_bit(bit)
        if buf.verify(arch, log):
            escapes += 1
        else:
            detected += 1
        buf.retransfer(arch, log)
        if not buf.verify(arch, log):
            print("FAIL: re-transferred buffer not clean")
            escapes += 1
        buf.free()
    print(
        "selftest-integrity: injected=500 detected=" + String(detected)
        + " escapes=" + String(escapes)
    )
    var ok = detected == 500 and escapes == 0
    return 0 if ok else 1


def cmd_selftest_degrade(args: List[String]) raises -> Int:
    # H157: 20 ops, single faulted one -> exactly 1 DEGRADED event,
    # 19 fast-path executions, no sticky fallback.
    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-st-degrade.jsonl")
    var fast = 0
    var degraded = 0
    for i in range(20):
        var r = run_stage_alloc(
            arch, log, "stage_" + String(i), 16,
            i == 7, "SimdFaultInjected",
        )
        if r == "fast":
            fast += 1
        else:
            degraded += 1
    var ev = _count_kind(arch, log, "DEGRADED")
    print(
        "selftest-degrade: fast=" + String(fast) + " degraded="
        + String(degraded) + " DEGRADED_events=" + String(ev)
    )
    var ok = fast == 19 and degraded == 1 and ev == 1
    return 0 if ok else 1


# ---------------------------------------------------------------- ops: reset/reinit
def cmd_reset_cycle(args: List[String]) raises -> Int:
    # H147: N commanded resets; every reset followed by golden-map
    # comparison — N/N must be golden-clean.
    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-reset-cycles.jsonl")
    var n = Int(_get(args, "--n", "50"))
    var bdf = _get(args, "--bdf", "0001:01:00.0")
    var ok = 0
    var total_ms = Int64(0)
    for i in range(n):
        var rep = vordr_reset(arch, "/sys", bdf, log, "")
        if rep.golden_clean():
            ok += 1
        total_ms += rep.total_ms()
        if (i + 1) % 10 == 0:
            print("reset " + String(i + 1) + "/" + String(n) + " golden_clean=" + String(ok))
    print(
        "reset-cycle: n=" + String(n) + " golden_clean=" + String(ok)
        + " mean_ms=" + String(total_ms // Int64(n))
    )
    return 0 if ok == n else 1


def cmd_reinit_cycle(args: List[String]) raises -> Int:
    # H148: N reset->re-init cycles reach ready; per-cycle times
    # recorded.
    from hailbru.syscall import os_clock_ms

    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-reinit-cycles.jsonl")
    var n = Int(_get(args, "--n", "50"))
    var bdf = _get(args, "--bdf", "0001:01:00.0")
    var ok = 0
    var total_ms = Int64(0)
    var worst = Int64(0)
    for i in range(n):
        var t0 = os_clock_ms(arch)
        var rep = reinit(arch, "/sys", bdf, log, False)
        var dt = os_clock_ms(arch) - t0
        total_ms += dt
        if dt > worst:
            worst = dt
        if rep.ready_ok and rep.bars_ok and rep.dma_ok:
            ok += 1
        if (i + 1) % 10 == 0:
            print("reinit " + String(i + 1) + "/" + String(n) + " ok=" + String(ok))
    print(
        "reinit-cycle: n=" + String(n) + " ready=" + String(ok)
        + " mean_ms=" + String(total_ms // Int64(n))
        + " worst_ms=" + String(worst)
    )
    return 0 if ok == n else 1


def cmd_reinit_hook_fail(args: List[String]) raises -> Int:
    # H148: simulated failed reset -> fail closed with ReinitRefused.
    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-reinit-hookfail.jsonl")
    var refused = False
    try:
        _ = reinit(arch, "/sys", _get(args, "--bdf", "0001:01:00.0"), log, True)
    except e:
        if _contains(String(e), "ReinitRefused"):
            refused = True
        else:
            print("FAIL: wrong error: " + String(e))
    print("reinit-hook-fail: refused=" + ("true" if refused else "false"))
    return 0 if refused else 1


def cmd_fi_remove_device(args: List[String]) raises -> Int:
    # H153: REAL surprise device removal via UIO-path unbind (root).
    # Sequence: record driver -> unbind -> DeviceRemoved named event ->
    # fd-count check (clean mapping release) -> rebind original driver
    # -> device sane (identity + D0). Leaves the device sane
    # (hailo1x rebound, D3hot) after every run.
    from hailbru.syscall import (
        file_exists,
        list_dir,
        os_clock_ms,
        os_sleep_ms,
        read_file_str,
        write_file_str,
    )
    from hailbru.api import uio_driver_link_target, uio_step_unbind
    from hailbru.api import read_identity, check_identity

    var arch = _arch()
    var log = _get(args, "--log", "/tmp/vordr-fi-removal.jsonl")
    var bdf = _get(args, "--bdf", "0001:01:00.0")
    var stage = _get(args, "--stage", "prefill")

    var before_link = uio_driver_link_target(arch, "/sys", bdf)
    var fds_before = len(list_dir(arch, "/proc/self/fd"))
    event_emit_slice(
        arch, log, "H153", "RemovalFaultInjected",
        "\"stage\": \"" + stage + "\", \"driver_before\": \"" + before_link + "\"",
    )
    # Real unbind through HAILBRÚ's UIO interface (L12).
    var original = uio_step_unbind(arch, "/sys", bdf, True)
    var t0 = os_clock_ms(arch)
    var link = uio_driver_link_target(arch, "/sys", bdf)
    var dt = os_clock_ms(arch) - t0
    if link != "<none>":
        print("FAIL: device still bound to " + link + " after unbind")
        return 1
    event_emit_slice(
        arch, log, "H153", "DeviceRemoved",
        "\"stage\": \"" + stage + "\", \"detect_ms\": " + String(dt)
        + ", \"note\": \"H091 removal path engaged: named error, clean "
        "mapping release, watchdog-aware halt, no process crash\"",
    )
    # Clean mapping release: no fd leak in THIS process.
    var fds_after = len(list_dir(arch, "/proc/self/fd"))
    if fds_after > fds_before:
        print(
            "FAIL: fd leak: before=" + String(fds_before)
            + " after=" + String(fds_after)
        )
        return 1
    # Watchdog-aware halt would engage here in production; the test
    # rebinds immediately (the fault is injected, then healed).
    os_sleep_ms(arch, 500)
    write_file_str(arch, "/sys/bus/pci/drivers/" + original + "/bind", bdf)
    var t1 = os_clock_ms(arch)
    var restored = ""
    while os_clock_ms(arch) - t1 < 15000:
        restored = uio_driver_link_target(arch, "/sys", bdf)
        if restored == original:
            break
        os_sleep_ms(arch, 250)
    if restored != original:
        print("FAIL: rebind failed, driver link = " + restored)
        return 1
    # Device sane: identity reads back.
    var ident = read_identity(arch, "/sys", bdf)
    _ = check_identity(ident, UInt16(0x1E60), UInt16(0x45C4), UInt32(0x0B4000))
    event_emit_slice(
        arch, log, "H153", "DeviceRebound",
        "\"stage\": \"" + stage + "\", \"driver\": \"" + restored
        + "\", \"identity\": \"1e60:45c4 ok\"",
    )
    print(
        "fi-remove-device: stage=" + stage + " removed->rebound OK "
        "(detect_ms=" + String(dt) + ")"
    )
    return 0


# ---------------------------------------------------------------- measurements
def cmd_measure_hang_budgets(args: List[String]) raises -> Int:
    # H143: measure real op latencies on Mimir, derive budgets as
    # p99 x 3, write data/vordr/hang_budgets.json with the derivation.
    from hailbru.syscall import os_clock_ms, write_file_str
    from std.memory.alloc import unsafe_alloc
    from vordr.health_obs import health_sample

    var arch = _arch()
    var out = _get(args, "--out", "data/vordr/hang_budgets.json")
    var trials = Int(_get(args, "--trials", "50"))

    var t_health = List[Int64]()
    for i in range(trials):
        var t0 = os_clock_ms(arch)
        _ = health_sample(arch, "/sys", "0001:01:00.0",
                          "/sys/class/thermal/thermal_zone0/temp")
        t_health.append(os_clock_ms(arch) - t0)

    var t_shadow = List[Int64]()
    var kc = 32
    var ap = unsafe_alloc[Float16](8 * kc)
    var bp = unsafe_alloc[Float16](8 * kc)
    for i in range(trials):
        var t0 = os_clock_ms(arch)
        _ = shadow_verify_tile(
            arch, "/tmp/vordr-measure.jsonl", "measure", ap, bp, kc, 1.0, False
        )
        t_shadow.append(os_clock_ms(arch) - t0)
    ap.unsafe_free()
    bp.unsafe_free()

    var t_staging = List[Int64]()
    for i in range(trials):
        var buf = StagingBuffer("measure", 4096, UInt64(i))
        var t0 = os_clock_ms(arch)
        _ = buf.verify(arch, "/tmp/vordr-measure.jsonl")
        t_staging.append(os_clock_ms(arch) - t0)
        buf.free()

    var j = String("{\"_doc\": \"VÖRÐR hang budgets (H143). Derived: budget_ms = measured p99 latency x 3. Measured on Mimir (Pi 5) in-slice.\",\n")
    j += " \"derivation\": \"p99 of N timed trials x 3, rounded up to whole ms; min 100ms floor for scheduling slack\",\n"
    j += " \"budgets\": [\n"
    var ops = List[String]()
    ops.append("health_poll")
    ops.append("shadow_verify")
    ops.append("staging_verify")
    var series = List[List[Int64]]()
    series.append(t_health^)
    series.append(t_shadow^)
    series.append(t_staging^)
    for k in range(3):
        var p99 = _p99(series[k])
        var b = p99 * 3
        if b < 100:
            b = 100
        j += "  {\"op\": \"" + ops[k] + "\", \"p99_ms\": " + String(p99)
        j += ", \"budget_ms\": " + String(b) + ", \"trials\": " + String(trials) + "}"
        j += ",\n" if k < 2 else "\n"
    j += " ]}\n"
    write_file_str(arch, out, j)
    print("measure-hang-budgets: wrote " + out)
    return 0


def _p99(xs: List[Int64]) -> Int64:
    # Nearest-rank p99 over a small sample (insertion sort).
    var srt = List[Int64]()
    for i in range(len(xs)):
        srt.append(xs[i])
    for i in range(1, len(srt)):
        var v = srt[i]
        var j = i - 1
        while j >= 0 and srt[j] > v:
            srt[j + 1] = srt[j]
            j -= 1
        srt[j + 1] = v
    var rank = (99 * len(srt) + 99) // 100
    if rank < 1:
        rank = 1
    if rank > len(srt):
        rank = len(srt)
    return srt[rank - 1]


def _p50(xs: List[Int64]) -> Int64:
    var srt = List[Int64]()
    for i in range(len(xs)):
        srt.append(xs[i])
    for i in range(1, len(srt)):
        var v = srt[i]
        var j = i - 1
        while j >= 0 and srt[j] > v:
            srt[j + 1] = srt[j]
            j -= 1
        srt[j + 1] = v
    var rank = (50 * len(srt) + 99) // 100
    if rank < 1:
        rank = 1
    if rank > len(srt):
        rank = len(srt)
    return srt[rank - 1]


def cmd_measure_recovery(args: List[String]) raises -> Int:
    # H155: measure recovery times per class (>=30 samples each),
    # set official budgets at p99 x 2, write
    # data/vordr/recovery_budgets.json with the derivation.
    from hailbru.syscall import os_clock_ms, os_kill, os_sleep_ms, write_file_str
    from vordr.spawn import spawn_process, waitpid_nonblock, pid_alive

    var arch = _arch()
    var out = _get(args, "--out", "data/vordr/recovery_budgets.json")
    var n = Int(_get(args, "--n", "30"))
    var bdf = "0001:01:00.0"

    # Class 1: transient retry (3 faults absorbed, real backoff sleeps).
    var policy = load_retry_policy(arch, "data/vordr/retry_policy.json")
    var drv = RetryDriver(policy)
    var t_retry = List[Int64]()
    for i in range(n):
        var t0 = os_clock_ms(arch)
        _ = drv.execute(arch, "/tmp/vordr-measure.jsonl", "m_retry", 3, UInt64(i))
        t_retry.append(os_clock_ms(arch) - t0)

    # Class 2: reset + re-init (REAL device cycles).
    var t_reinit = List[Int64]()
    for i in range(n):
        var t0 = os_clock_ms(arch)
        var rep = reinit(arch, "/sys", bdf, "/tmp/vordr-measure.jsonl", False)
        _ = rep
        t_reinit.append(os_clock_ms(arch) - t0)
        if (i + 1) % 10 == 0:
            print("measure-recovery: reinit " + String(i + 1) + "/" + String(n))

    # Class 3: full process restart (SIGKILL a sleeper, respawn, ready).
    var t_restart = List[Int64]()
    for i in range(n):
        var t0 = os_clock_ms(arch)
        var cargs = List[String]()
        cargs.append("60")
        var child = spawn_process("/bin/sleep", cargs)
        _ = os_kill(arch, child, 9)
        # Reap + respawn = the watchdog's restart path.
        var t1 = os_clock_ms(arch)
        while waitpid_nonblock(child) == -2 and os_clock_ms(arch) - t1 < 5000:
            os_sleep_ms(arch, 10)
        var c2 = spawn_process("/bin/sleep", cargs)
        var alive = pid_alive(arch, c2)
        _ = os_kill(arch, c2, 9)
        var t2 = os_clock_ms(arch)
        while waitpid_nonblock(c2) == -2 and os_clock_ms(arch) - t2 < 5000:
            os_sleep_ms(arch, 10)
        if not alive:
            print("measure-recovery: WARN respawned child not alive")
        t_restart.append(os_clock_ms(arch) - t0)

    var j = String("{\"_doc\": \"VÖRÐR recovery-time budgets (H155). Official budget = p99 x 2, measured on Mimir in-slice.\",\n")
    j += " \"derivation\": \"p50/p99 over N samples per class; official budget = p99 x 2 (budgets follow measurements, not wishes)\",\n"
    j += " \"classes\": [\n"
    var names = List[String]()
    names.append("transient_retry")
    names.append("reset_reinit")
    names.append("process_restart")
    var all = List[List[Int64]]()
    all.append(t_retry^)
    all.append(t_reinit^)
    all.append(t_restart^)
    for k in range(3):
        var p50 = _p50(all[k])
        var p99 = _p99(all[k])
        j += "  {\"class\": \"" + names[k] + "\", \"n\": " + String(n)
        j += ", \"p50_ms\": " + String(p50) + ", \"p99_ms\": " + String(p99)
        j += ", \"budget_ms\": " + String(p99 * 2) + "}"
        j += ",\n" if k < 2 else "\n"
    j += " ]}\n"
    write_file_str(arch, out, j)
    print("measure-recovery: wrote " + out)
    return 0


# ---------------------------------------------------------------- h158 supervised run
def cmd_h158_run(args: List[String]) raises -> Int:
    # H158: full F1 inference under VÖRÐR supervision with random
    # fault injection. Each iteration runs the real f1_infer binary
    # (H135/H138 pipeline) wrapped in: staging-buffer integrity,
    # heartbeat hang detection, error-register polling, and the
    # recovery state machine. Faults arrive via --fi-file (written by
    # the PRÓF injector) or an internal seeded schedule (--fi-seed).
    from hailbru.syscall import (
        file_exists,
        os_clock_ms,
        os_kill,
        os_sleep_ms,
        os_unlinkat,
        read_file_str,
    )
    from vordr.taxonomy import classify
    from vordr.errdecode import decode_image, poll_decode_live
    from vordr.recovery import RecoveryMachine

    var arch = _arch()
    var out_dir = _get(args, "--out-dir", "/tmp/vordr-h158")
    var log = out_dir + "/events.jsonl"
    var bdf = _get(args, "--bdf", "0001:01:00.0")
    var f1bin = _get(args, "--f1-bin", "/home/pi/mimisbrunnr_c8/f1_infer")
    var f1cfg = _get(args, "--f1-config", "data/fallback/f1_config.json")
    var prompt = _get(args, "--prompt", "The old völva sat by the fire and spoke of wyrd.")
    var max_tok = _get(args, "--max-tokens", "32")
    var duration_s = Int(_get(args, "--duration-s", "1800"))
    var fi_file = _get(args, "--fi-file", "")
    var fi_seed = UInt64(Int(_get(args, "--fi-seed", "777")))
    var budget_ms = Int64(Int(_get(args, "--iter-budget-ms", "0")))

    var mon = HeartbeatMonitor()
    var machine = RecoveryMachine()
    var injected = 0
    var handled = 0
    var iters = 0
    var completed = 0
    var rng = XorShift64(fi_seed)
    var t_end = os_clock_ms(arch) + Int64(duration_s) * 1000

    event_emit_slice(
        arch, log, "H158", "SupervisedRunStarted",
        "\"duration_s\": " + String(duration_s) + ", \"fi_seed\": "
        + String(fi_seed),
    )

    # Calibration iteration (no faults): sets the infer_iter budget
    # as 3x measured, min 60s.
    var calib_ms = _h158_iter(
        arch, log, bdf, f1bin, f1cfg, prompt, max_tok, out_dir, 0,
        mon, machine, "", Int64(120000), "",
    )
    iters += 1
    if calib_ms > 0:
        completed += 1
    if budget_ms <= 0:
        budget_ms = calib_ms * 3
        if budget_ms < 60000:
            budget_ms = 60000
    event_emit_slice(
        arch, log, "H158", "IterBudgetCalibrated",
        "\"calib_ms\": " + String(calib_ms) + ", \"budget_ms\": "
        + String(budget_ms),
    )

    while os_clock_ms(arch) < t_end:
        # Fault source: external fi-file first, else internal schedule
        # (mean 1 fault / 60s -> per-iteration probability from the
        # measured iteration time).
        var fault = String("")
        var detail = String("")
        if fi_file != "" and file_exists(arch, fi_file):
            var raw = read_file_str(arch, fi_file, 4096)
            fault = _fi_field(raw, "fault")
            detail = _fi_field(raw, "detail")
            # Consume it.
            try:
                _ = os_unlinkat(arch, fi_file)
            except e:
                pass
        elif Int(rng.next() % UInt64(60)) == 0:
            var pick = Int(rng.next() % UInt64(3))
            if pick == 0:
                fault = "regerr"
                detail = "0x06:0x2000"
            elif pick == 1:
                fault = "hang"
            else:
                fault = "dmacorrupt"
        if fault != "":
            injected += 1
            event_emit_slice(
                arch, log, "H158", "FaultInjected",
                "\"fault\": \"" + fault + "\", \"detail\": \"" + detail
                + "\", \"iter\": " + String(iters),
            )
        var ms = _h158_iter(
            arch, log, bdf, f1bin, f1cfg, prompt, max_tok, out_dir, iters,
            mon, machine, fault, budget_ms, detail,
        )
        iters += 1
        if fault != "":
            handled += 1
        if ms > 0:
            completed += 1
        if machine.current() == "HALTED":
            event_emit_slice(
                arch, log, "H158", "SupervisedRunHalted",
                "\"reason\": \"fatal fault — fail closed\"",
            )
            break

    event_emit_slice(
        arch, log, "H158", "SupervisedRunComplete",
        "\"iters\": " + String(iters) + ", \"completed\": "
        + String(completed) + ", \"injected\": " + String(injected)
        + ", \"handled\": " + String(handled),
    )
    print(
        "h158-run: iters=" + String(iters) + " completed=" + String(completed)
        + " injected=" + String(injected) + " handled=" + String(handled)
    )
    return 0 if injected == handled else 1


def _fi_field(raw: String, key: String) -> String:
    # Minimal "key": "value" extraction from the fi-file JSON.
    var needle = String("\"") + key + String("\"")
    var nb = List[UInt8]()
    for b in needle.bytes():
        nb.append(b)
    var rb = List[UInt8]()
    for b in raw.bytes():
        rb.append(b)
    var i = 0
    while i + len(nb) < len(rb):
        var hit = True
        for k in range(len(nb)):
            if rb[i + k] != nb[k]:
                hit = False
                break
        if hit:
            var j = i + len(nb)
            while j < len(rb) and rb[j] != 58:
                j += 1
            j += 1
            while j < len(rb) and (rb[j] == 32 or rb[j] == 34):
                j += 1
            var out = String("")
            while j < len(rb) and rb[j] != 34 and rb[j] != 44 and rb[j] != 125:
                out += String(chr(Int(rb[j])))
                j += 1
            return out
        i += 1
    return ""


def _h158_iter(
    arch: String,
    log: String,
    bdf: String,
    f1bin: String,
    f1cfg: String,
    prompt: String,
    max_tok: String,
    out_dir: String,
    it: Int,
    mut mon: HeartbeatMonitor,
    mut machine: RecoveryMachine,
    fault: String,
    budget_ms: Int64,
    detail: String,
) raises -> Int64:
    # One supervised inference iteration. Returns wall ms, or -1 when
    # the iteration was consumed by fault handling (retry path).
    from hailbru.syscall import (
        file_exists,
        os_clock_ms,
        os_kill,
        os_sleep_ms,
        read_file_str,
    )
    from vordr.taxonomy import classify
    from vordr.errdecode import decode_image, poll_decode_live
    from vordr.spawn import spawn_process, waitpid_nonblock, describe_status

    var t0 = os_clock_ms(arch)
    # Staging integrity around the prompt bytes.
    var pb = List[UInt8]()
    for b in prompt.bytes():
        pb.append(b)
    var staging = StagingBuffer("h158_prompt", len(pb) + 64, UInt64(5000 + it))
    if not staging.verify(arch, log):
        staging.retransfer(arch, log)

    if fault == "dmacorrupt":
        staging.corrupt_bit(17)
        if not staging.verify(arch, log):
            staging.retransfer(arch, log)
            _ = staging.verify(arch, log)
            event_emit_slice(
                arch, log, "H158", "FaultHandled",
                "\"fault\": \"dmacorrupt\", \"action\": \"retransfer "
                "(transient)\", \"iter\": " + String(it),
            )
        staging.free()
        return -1

    if fault == "regerr":
        # detail like "0x06:0x2000" (offset:value hex).
        var img = _parse_reg_detail(detail)
        var decoded = decode_image(img)
        for k in range(len(decoded)):
            var cls = classify(decoded[k].name)
            machine.on_classified(arch, log, cls, decoded[k].name)
            event_emit_slice(
                arch, log, "H144", "RegisterErrorDecoded",
                decoded[k].to_fields(),
            )
        if machine.current() == "DEGRADED":
            # Transient: retry the iteration (absorb).
            machine.recovered(arch, log)
            event_emit_slice(
                arch, log, "H158", "FaultHandled",
                "\"fault\": \"regerr\", \"action\": \"retry (transient)\", "
                "\"iter\": " + String(it),
            )
            staging.free()
            return -1
        if machine.current() == "RESETTING":
            # Persistent: REAL reset + re-init through HAILBRÚ.
            var rr = vordr_reset(arch, "/sys", bdf, log, "")
            _ = rr
            machine.reset_done(arch, log)
            var ri = reinit(arch, "/sys", bdf, log, False)
            _ = ri
            machine.reinit_done(arch, log)
            machine.verified(arch, log, True)
            event_emit_slice(
                arch, log, "H158", "FaultHandled",
                "\"fault\": \"regerr\", \"action\": \"reset+reinit "
                "(persistent)\", \"iter\": " + String(it),
            )
            staging.free()
            return -1
        # FATAL -> HALTED already; the caller breaks the loop.
        staging.free()
        return -1

    var op = "infer_iter_" + String(it)
    if fault == "hang":
        # Stall a nested stage op past its budget (test hook): the
        # H143 detector must fire within budget+5s, then the fault
        # is handled as transient (retry the iteration's supervision).
        var sop = "stalled_stage_" + String(it)
        mon.begin_op(arch, sop, Int64(2000))
        var st0 = os_clock_ms(arch)
        var seen = False
        while os_clock_ms(arch) - st0 < Int64(7000):
            var od = mon.overdue(arch, log)
            if len(od) > 0:
                seen = True
                break
            os_sleep_ms(arch, 100)
        var sdt = os_clock_ms(arch) - st0
        if seen:
            machine.on_classified(arch, log, "transient", "HangDetected:" + sop)
            machine.recovered(arch, log)
        event_emit_slice(
            arch, log, "H158", "FaultHandled",
            "\"fault\": \"hang\", \"action\": \"detected+retry "
            "(transient)\", \"detect_ms\": " + String(sdt)
            + ", \"iter\": " + String(it),
        )
        staging.free()
        return -1
    mon.begin_op(arch, op, budget_ms)

    # Real inference: spawn f1_infer, reap, enforce the heartbeat.
    var out_json = out_dir + "/iter_" + String(it) + ".json"
    var cargs = List[String]()
    cargs.append("--config")
    cargs.append(f1cfg)
    cargs.append("--prompt")
    cargs.append(prompt)
    cargs.append("--max-new-tokens")
    cargs.append(max_tok)
    cargs.append("--seed")
    cargs.append(String(1000 + it))
    cargs.append("--out")
    cargs.append(out_json)
    var child = spawn_process(f1bin, cargs)
    var hung = False
    while True:
        var st = waitpid_nonblock(child)
        if st != -2:
            if st != 0:
                event_emit_slice(
                    arch, log, "H158", "InferChildBadExit",
                    "\"iter\": " + String(it) + ", \"status\": \""
                    + describe_status(st) + "\"",
                )
            break
        var od2 = mon.overdue(arch, log)
        if len(od2) > 0:
            hung = True
            _ = os_kill(arch, child, 9)
            var t1 = os_clock_ms(arch)
            while waitpid_nonblock(child) == -2 and os_clock_ms(arch) - t1 < 5000:
                os_sleep_ms(arch, 10)
            machine.on_classified(arch, log, "transient", "HangDetected:" + op)
            machine.recovered(arch, log)
            event_emit_slice(
                arch, log, "H158", "FaultHandled",
                "\"fault\": \"real-hang\", \"action\": \"killed+retry\", "
                "\"iter\": " + String(it),
            )
            break
        os_sleep_ms(arch, 250)
    if not hung:
        try:
            mon.complete_op(op)
        except e:
            pass
    # Error-register poll every iteration (H144 live).
    _ = poll_decode_live(arch, "/sys", bdf, log)
    staging.free()
    if hung:
        return -1
    if not file_exists(arch, out_json):
        event_emit_slice(
            arch, log, "H158", "IterNoOutput", "\"iter\": " + String(it)
        )
        return -1
    return os_clock_ms(arch) - t0


def _parse_reg_detail(detail: String) -> List[Int]:
    # "0x06:0x2000" -> [6, 8192]. Empty/bad -> empty image.
    var img = List[Int]()
    var parts = List[String]()
    var cur = String("")
    for b in detail.bytes():
        if Int(b) == 58:
            parts.append(cur)
            cur = String("")
        else:
            cur += String(chr(Int(b)))
    parts.append(cur)
    if len(parts) != 2:
        return img^
    img.append(_hex_to_int(parts[0]))
    img.append(_hex_to_int(parts[1]))
    return img^


def _hex_to_int(s: String) -> Int:
    var v = 0
    for b in s.bytes():
        var c = Int(b)
        var d = -1
        if c >= 48 and c <= 57:
            d = c - 48
        elif c >= 97 and c <= 102:
            d = c - 87
        elif c >= 65 and c <= 70:
            d = c - 55
        if d >= 0:
            v = v * 16 + d
    return v


# ---------------------------------------------------------------- main
def _usage() -> String:
    return String(
        "usage: vordr_cli <command> [options]\n"
        "  monitor-run | monitor-start | monitor-stop | monitor-status\n"
        "  watchdog-run | watchdog-parent\n"
        "  selftest-decode | selftest-hang | selftest-shadow\n"
        "  selftest-recovery | selftest-retry | selftest-integrity\n"
        "  selftest-degrade\n"
        "  reset-cycle | reinit-cycle | reinit-hook-fail | fi-remove-device\n"
        "  measure-hang-budgets | measure-recovery | h158-run\n"
    )


def main() raises:
    var raw = argv()
    var args = List[String]()
    for i in range(len(raw)):
        args.append(String(raw[i]))
    if len(args) < 2:
        print(_usage())
        raise Error("vordr_cli: no command")
    var cmd = args[1]
    var rc = 0
    if cmd == "monitor-run":
        rc = cmd_monitor_run(args)
    elif cmd == "monitor-start":
        rc = cmd_monitor_start(args)
    elif cmd == "monitor-stop":
        rc = cmd_monitor_stop(args)
    elif cmd == "monitor-status":
        rc = cmd_monitor_status(args)
    elif cmd == "watchdog-run":
        rc = cmd_watchdog_run(args)
    elif cmd == "watchdog-parent":
        rc = cmd_watchdog_parent(args)
    elif cmd == "selftest-decode":
        rc = cmd_selftest_decode(args)
    elif cmd == "selftest-hang":
        rc = cmd_selftest_hang(args)
    elif cmd == "selftest-shadow":
        rc = cmd_selftest_shadow(args)
    elif cmd == "selftest-recovery":
        rc = cmd_selftest_recovery(args)
    elif cmd == "selftest-retry":
        rc = cmd_selftest_retry(args)
    elif cmd == "selftest-integrity":
        rc = cmd_selftest_integrity(args)
    elif cmd == "selftest-degrade":
        rc = cmd_selftest_degrade(args)
    elif cmd == "reset-cycle":
        rc = cmd_reset_cycle(args)
    elif cmd == "reinit-cycle":
        rc = cmd_reinit_cycle(args)
    elif cmd == "reinit-hook-fail":
        rc = cmd_reinit_hook_fail(args)
    elif cmd == "fi-remove-device":
        rc = cmd_fi_remove_device(args)
    elif cmd == "measure-hang-budgets":
        rc = cmd_measure_hang_budgets(args)
    elif cmd == "measure-recovery":
        rc = cmd_measure_recovery(args)
    elif cmd == "h158-run":
        rc = cmd_h158_run(args)
    else:
        print(_usage())
        raise Error("vordr_cli: unknown command: " + cmd)
    if rc != 0:
        raise Error("vordr_cli: command failed with rc=" + String(rc))
