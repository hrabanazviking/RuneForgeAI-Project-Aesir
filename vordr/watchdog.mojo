# VÖRÐR watchdog / supervisor process (H146).
#
# A separate Mojo process that supervises the inference process:
# spawns it, watches liveness (kill(pid,0) + waitpid reaping),
# restarts it on death per the backoff policy, and keeps a restart
# log. Restart storms are damped by escalating delays (policy in
# data/vordr/watchdog_policy.json: 1s, 2s, 4s, 8s, ...).
#
# The watchdog's OWN death is covered by a documented external
# mechanism (implemented, not hand-waved):
#   1. docs/vordr/vordr-watchdog.service — systemd unit (operator
#      installs it; Restart=always).
#   2. `vordr_cli watchdog-parent` — a parent-monitor mode that spawns
#      the watchdog and restarts IT on death (runs unprivileged).

from hailbru.syscall import (
    AT_FDCWD,
    append_file_str,
    file_exists,
    os_clock_ms,
    os_getpid,
    os_sleep_ms,
    os_unlinkat,
    read_file_str,
    write_file_str,
)
from hailbru.errors import herror
from vordr.events import event_emit_slice, json_str
from vordr.spawn import (
    describe_status,
    pid_alive,
    spawn_process,
    waitpid_nonblock,
)


struct WatchdogPolicy:
    var base_delay_s: Int64
    var factor: Int64
    var max_delay_s: Int64
    var rapid_window_s: Int64
    var max_restarts: Int

    def __init__(
        out self, base_delay_s: Int64, factor: Int64, max_delay_s: Int64,
        rapid_window_s: Int64, max_restarts: Int,
    ):
        self.base_delay_s = base_delay_s
        self.factor = factor
        self.max_delay_s = max_delay_s
        self.rapid_window_s = rapid_window_s
        self.max_restarts = max_restarts

    fn delay_for(self, rapid_deaths: Int) -> Int64:
        # rapid_deaths = consecutive deaths inside the rapid window.
        # 1st rapid death -> base, 2nd -> base*factor, ... (5th -> 8s
        # with base=1, factor=2 — the H146 anti-storm proof point).
        var d = self.base_delay_s
        var k = 1
        while k < rapid_deaths:
            d = d * self.factor
            if d > self.max_delay_s:
                d = self.max_delay_s
                break
            k += 1
        if d > self.max_delay_s:
            d = self.max_delay_s
        return d


def load_watchdog_policy(arch: String, path: String) raises -> WatchdogPolicy:
    # Hand-parsed JSON: base_delay_s, factor, max_delay_s,
    # rapid_window_s, max_restarts (integers, in order).
    var raw = read_file_str(arch, path, 4096)
    var vals = List[Int64]()
    var v = Int64(0)
    var in_num = False
    for b in raw.bytes():
        var c = Int(b)
        if c >= 48 and c <= 57:
            v = v * 10 + Int64(c - 48)
            in_num = True
        else:
            if in_num:
                vals.append(v)
                v = 0
                in_num = False
    if in_num:
        vals.append(v)
    if len(vals) < 5:
        raise herror(
            "BadPolicy",
            "expected 5 integers in " + path + ", found " + String(len(vals)),
        )
    return WatchdogPolicy(vals[0], vals[1], vals[2], vals[3], Int(vals[4]))


def watchdog_run(
    arch: String,
    prog: String,
    child_args: List[String],
    policy_path: String,
    log_path: String,
    restart_log: String,
    pidfile: String,
    stopfile: String,
) raises -> Int:
    # Supervise until stopfile appears or max_restarts is exceeded.
    # Returns 0 on clean stop, 2 when the restart budget is exhausted
    # (fail closed — the external mechanism must notice).
    var policy = load_watchdog_policy(arch, policy_path)
    var me = os_getpid(arch)
    write_file_str(arch, pidfile, String(me) + "\n")
    event_emit_slice(
        arch, log_path, "H146", "WatchdogStarted",
        "\"pid\": " + String(me) + ", \"supervised\": " + json_str(prog)
        + ", \"max_restarts\": " + String(policy.max_restarts),
    )
    var restarts = 0
    var rapid = 0
    var last_death_ms = Int64(0)
    var child = spawn_process(prog, child_args)
    var child_start = os_clock_ms(arch)
    event_emit_slice(
        arch, log_path, "H146", "ChildSpawned",
        "\"pid\": " + String(child) + ", \"restart\": 0",
    )
    while True:
        if file_exists(arch, stopfile):
            event_emit_slice(
                arch, log_path, "H146", "WatchdogStopRequested",
                "\"restarts\": " + String(restarts),
            )
            break
        var st = waitpid_nonblock(child)
        if st == -2:
            os_sleep_ms(arch, 250)
            continue
        # Child is gone (reaped or already dead).
        var now = os_clock_ms(arch)
        var desc = "unknown"
        if st >= 0:
            desc = describe_status(st)
        elif not pid_alive(arch, child):
            desc = "gone"
        if now - last_death_ms <= policy.rapid_window_s * 1000:
            rapid += 1
        else:
            rapid = 1
        last_death_ms = now
        restarts += 1
        var delay = policy.delay_for(rapid)
        var line = (
            "{\"ts_ms\": " + String(now) + ", \"restart\": " + String(restarts)
            + ", \"child_pid\": " + String(child) + ", \"status\": \""
            + desc + "\", \"rapid_deaths\": " + String(rapid)
            + ", \"backoff_s\": " + String(delay)
            + ", \"uptime_ms\": " + String(now - child_start) + "}\n"
        )
        append_file_str(arch, restart_log, line)
        event_emit_slice(
            arch, log_path, "H146", "ChildRestarted",
            "\"restart\": " + String(restarts) + ", \"status\": \""
            + desc + "\", \"backoff_s\": " + String(delay),
        )
        if restarts >= policy.max_restarts:
            event_emit_slice(
                arch, log_path, "H146", "WatchdogGaveUp",
                "\"restarts\": " + String(restarts)
                + ", \"note\": \"restart budget exhausted — external "
                "mechanism (systemd unit or watchdog-parent) must notice\"",
            )
            try:
                _ = os_unlinkat(arch, AT_FDCWD(), pidfile)
            except e:
                pass
            return 2
        os_sleep_ms(arch, delay * 1000)
        child = spawn_process(prog, child_args)
        child_start = os_clock_ms(arch)
    try:
        _ = os_unlinkat(arch, AT_FDCWD(), pidfile)
    except e:
        pass
    return 0


def watchdog_parent_run(
    arch: String,
    watchdog_prog: String,
    watchdog_args: List[String],
    log_path: String,
    pidfile: String,
    stopfile: String,
) raises -> Int:
    # The documented external mechanism #2: a parent monitor that
    # keeps the WATCHDOG itself alive. If the watchdog dies, the parent
    # restarts it (with a 5s settle) and logs the event. This is the
    # implemented answer to "the watchdog itself dying".
    var me = os_getpid(arch)
    write_file_str(arch, pidfile, String(me) + "\n")
    event_emit_slice(
        arch, log_path, "H146", "WatchdogParentStarted",
        "\"pid\": " + String(me),
    )
    var wd = spawn_process(watchdog_prog, watchdog_args)
    var revivals = 0
    while True:
        if file_exists(arch, stopfile):
            event_emit_slice(
                arch, log_path, "H146", "WatchdogParentStopRequested",
                "\"revivals\": " + String(revivals),
            )
            break
        var st = waitpid_nonblock(wd)
        if st == -2:
            os_sleep_ms(arch, 1000)
            continue
        revivals += 1
        event_emit_slice(
            arch, log_path, "H146", "WatchdogRevived",
            "\"revival\": " + String(revivals)
            + ", \"watchdog_status\": \""
            + (describe_status(st) if st >= 0 else "gone") + "\"",
        )
        os_sleep_ms(arch, 5000)
        wd = spawn_process(watchdog_prog, watchdog_args)
    try:
        _ = os_unlinkat(arch, AT_FDCWD(), pidfile)
    except e:
        pass
    return 0
