# VÖRÐR health-monitor loop (H141) + thermal thresholding (H142).
#
# The monitor is a single-threaded Mojo PROCESS (not a thread): the
# vordr CLI runs `monitor-run`, which samples device/CPU health every
# `period_s` seconds for `duration_s` seconds and exits. start/stop/
# status are CLI-level operations on a pidfile + stop-flag file, so
# "no thread left running after stop" is verified by process absence
# (stronger than a thread-count check — and the running monitor itself
# is verified to have exactly 1 thread via /proc/<pid>/task).
#
# L12: sampling goes through vordr.health_obs (H087 hooks) only.

from hailbru.syscall import (
    append_file_str,
    file_exists,
    list_dir,
    os_clock_ms,
    os_getpid,
    os_sleep_ms,
    os_unlinkat,
    read_file_str,
    write_file_str,
)
from hailbru.errors import herror
from hailbru.util import trim
from vordr.events import event_emit_slice, json_str
from vordr.health_obs import HealthSample, health_sample


def _ints_in_text(raw: String) -> List[Int]:
    # All unsigned-integer runs in the text, in order. Used for the
    # thresholds file (pure Mojo, no JSON library — L1).
    var vals = List[Int]()
    var v = 0
    var in_num = False
    for b in raw.bytes():
        var c = Int(b)
        if c >= 48 and c <= 57:
            v = v * 10 + (c - 48)
            in_num = True
        else:
            if in_num:
                vals.append(v)
                v = 0
                in_num = False
    if in_num:
        vals.append(v)
    return vals


def task_count(arch: String, pid: Int64) -> Int:
    # Thread count of a process via /proc/<pid>/task. -1 when unreadable.
    try:
        var names = list_dir(arch, "/proc/" + String(pid) + "/task")
        return len(names)
    except e:
        return -1


def monitor_threads_self(arch: String) -> Int:
    # Thread count of THIS process (the running monitor must be 1).
    return task_count(arch, os_getpid(arch))


def thermal_level(soc_mc: Int, warn_mc: Int, crit_mc: Int) -> String:
    if soc_mc < 0:
        return "unknown"
    if soc_mc >= crit_mc:
        return "critical"
    if soc_mc >= warn_mc:
        return "warning"
    return "ok"


def _int_after_key(raw: String, key: String) -> Int:
    # Minimal key-aware extraction: finds "key" then the first
    # unsigned integer after the following ':'. -1 when absent.
    var kb = List[UInt8]()
    kb.append(34)  # quote
    for b in key.bytes():
        kb.append(b)
    kb.append(34)
    var tb = List[UInt8]()
    for b in raw.bytes():
        tb.append(b)
    var kn = len(kb)
    var tn = len(tb)
    var i = 0
    while i + kn < tn:
        var hit = True
        for k in range(kn):
            if tb[i + k] != kb[k]:
                hit = False
                break
        if hit:
            var j = i + kn
            while j < tn and tb[j] != 58:  # ':'
                j += 1
            j += 1
            var v = 0
            var got = False
            while j < tn:
                var c = Int(tb[j])
                if c >= 48 and c <= 57:
                    v = v * 10 + (c - 48)
                    got = True
                elif got:
                    break
                j += 1
            if got:
                return v
            return -1
        i += 1
    return -1


def load_thresholds(arch: String, path: String) raises -> List[Int]:
    # Returns [soc_warn_mc, soc_crit_mc] from data/vordr/
    # thermal_thresholds.json, extracted by key ("soc" section).
    # The file documents units honestly (see the Sólrún audit: the
    # Hailo-10 die temperature is NOT readable on this kernel).
    var raw = read_file_str(arch, path, 8192)
    # Restrict to the "soc" object so device_die nulls never match.
    var sb = List[UInt8]()
    for b in raw.bytes():
        sb.append(b)
    var soc_at = -1
    var i = 0
    while i + 4 < len(sb):
        if (sb[i] == 34 and sb[i + 1] == 115 and sb[i + 2] == 111
                and sb[i + 3] == 99 and sb[i + 4] == 34):
            soc_at = i
            break
        i += 1
    if soc_at < 0:
        raise herror("BadThresholds", "no \"soc\" section in " + path)
    var tail = String("")
    for k in range(soc_at, len(sb)):
        tail += String(chr(Int(sb[k])))
    var warn_mc = _int_after_key(tail, "warn_mc")
    var crit_mc = _int_after_key(tail, "crit_mc")
    if warn_mc < 0 or crit_mc < 0:
        raise herror(
            "BadThresholds",
            "missing warn_mc/crit_mc in soc section of " + path,
        )
    var out = List[Int]()
    out.append(warn_mc)
    out.append(crit_mc)
    return out


def monitor_run(
    arch: String,
    sysfs_root: String,
    bdf: String,
    thermal_path: String,
    out_dir: String,
    thresholds_path: String,
    duration_s: Int,
    period_s: Int,
    pidfile: String,
    stopfile: String,
) raises -> Int:
    # Runs the sampling loop. Returns the number of samples recorded.
    # Writes: <out_dir>/samples.jsonl, <out_dir>/events.jsonl.
    var th = load_thresholds(arch, thresholds_path)
    var warn_mc = th[0]
    var crit_mc = th[1]
    var me = os_getpid(arch)
    write_file_str(arch, pidfile, String(me) + "\n")
    var samples_path = out_dir + "/samples.jsonl"
    var events_path = out_dir + "/events.jsonl"
    event_emit_slice(
        arch, events_path, "H141", "MonitorStarted",
        "\"pid\": " + String(me)
        + ", \"duration_s\": " + String(duration_s)
        + ", \"period_s\": " + String(period_s)
        + ", \"threads\": " + String(monitor_threads_self(arch))
        + ", \"soc_warn_mc\": " + String(warn_mc)
        + ", \"soc_crit_mc\": " + String(crit_mc),
    )
    var t0 = os_clock_ms(arch)
    var deadline = t0 + Int64(duration_s) * 1000
    var expected = t0
    var n = 0
    var missed = 0
    var last_level = String("ok")
    while True:
        var now = os_clock_ms(arch)
        if now >= deadline:
            break
        if file_exists(arch, stopfile):
            event_emit_slice(
                arch, events_path, "H141", "MonitorStopRequested",
                "\"samples\": " + String(n),
            )
            break
        var sched = expected
        expected = expected + Int64(period_s) * 1000
        var drift = now - sched
        if drift < 0:
            drift = -drift
        var s: HealthSample
        try:
            s = health_sample(arch, sysfs_root, bdf, thermal_path)
        except e:
            event_emit_slice(
                arch, events_path, "H141", "SampleFailed",
                "\"n\": " + String(n) + ", \"error\": " + json_str(String(e)),
            )
            missed += 1
            os_sleep_ms(arch, Int64(period_s) * 1000)
            continue
        var lvl = thermal_level(s.soc_temp_millic, warn_mc, crit_mc)
        var line = (
            "{\"n\": " + String(n) + ", \"ts_ms\": " + String(s.ts_ms)
            + ", \"expected_ms\": " + String(sched)
            + ", \"drift_ms\": " + String(drift)
            + ", \"soc_temp_millic\": " + String(s.soc_temp_millic)
            + ", \"irq_status_0x18c\": " + String(s.irq_status_0x18c)
            + ", \"thermal_level\": \"" + lvl + "\"}\n"
        )
        append_file_str(arch, samples_path, line)
        if lvl != last_level and (lvl == "warning" or lvl == "critical"):
            event_emit_slice(
                arch, events_path, "H142", "ThermalWarning",
                "\"level\": \"" + lvl + "\", \"soc_temp_millic\": "
                + String(s.soc_temp_millic) + ", \"warn_mc\": "
                + String(warn_mc) + ", \"crit_mc\": " + String(crit_mc)
                + ", \"n\": " + String(n),
            )
        if lvl == "ok" and last_level != "ok":
            event_emit_slice(
                arch, events_path, "H142", "ThermalRecovered",
                "\"soc_temp_millic\": " + String(s.soc_temp_millic)
                + ", \"n\": " + String(n),
            )
        last_level = lvl
        n += 1
        var after = os_clock_ms(arch)
        var wait = expected - after
        if wait > 0:
            os_sleep_ms(arch, wait)
    event_emit_slice(
        arch, events_path, "H141", "MonitorStopped",
        "\"samples\": " + String(n) + ", \"missed\": " + String(missed),
    )
    try:
        _ = os_unlinkat(arch, pidfile)
    except e:
        pass
    return n
