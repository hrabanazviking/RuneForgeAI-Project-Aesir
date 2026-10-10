#!/usr/bin/env python3
# PRÓF TEST-ONLY — H159 no-silent-fallback audit.
#
# Triggers every degrade/fallback path in docs/vordr/FALLBACK_AUDIT.md
# and asserts its structured event appears in the log — 100% path
# coverage, zero silent paths. Any path found without an event is
# fixed in-slice (the audit has teeth).
#
# Needs root for the device-touching paths (12, 13, 14-live).
# Pure-MoJo ships; this file is TESTS ONLY (D8 PRÓF).

import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

VORDR = "/home/pi/mimisbrunnr_c8/vordr_cli"
F1BIN = "/home/pi/mimisbrunnr_c8/f1_infer"
F1CFG = "/home/pi/mimisbrunnr_c8/data/fallback/f1_config.json"
REPO = "/home/pi/mimisbrunnr_c8"
NEEDS_ROOT = True  # set False to skip device paths when unprivileged

fails = []


def run(cmd, timeout=300):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def kinds(log):
    out = set()
    p = Path(log)
    if p.exists():
        for line in p.read_text().splitlines():
            i = line.find('"kind": "')
            if i >= 0:
                out.add(line[i + 10:].split('"')[0])
    return out


def check(label, log, want):
    got = kinds(log)
    missing = [w for w in want if w not in got]
    if missing:
        fails.append(f"{label}: missing events {missing}")
        print(f"  {label}: MISSING {missing}")
    else:
        print(f"  {label}: {want} OK")


def main():
    tmp = Path("/tmp/vordr-audit")
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True)

    # 1: scalar fallback degrade
    log = str(tmp / "degrade.jsonl")
    run([VORDR, "selftest-degrade", "--log", log])
    check("degrade", log, ["DEGRADED"])

    # 2-4: retry paths
    log = str(tmp / "retry.jsonl")
    run([VORDR, "selftest-retry", "--log", log])
    check("retry", log, ["OpRecovered", "RetryExhausted", "RetryScheduled",
                         "RetryFired", "TransientFault"])

    # 5: recovery transitions
    log = str(tmp / "recovery.jsonl")
    run([VORDR, "selftest-recovery", "--log", log])
    check("recovery", log, ["RecoveryTransition"])

    # 6-7: integrity
    log = str(tmp / "integrity.jsonl")
    run([VORDR, "selftest-integrity", "--log", log])
    check("integrity", log, ["IntegrityCorrupt", "IntegrityRetransferred"])

    # 8: shadow
    log = str(tmp / "shadow.jsonl")
    run([VORDR, "selftest-shadow", "--log", log, "--contract", "0.001"])
    check("shadow", log, ["ShadowMismatch", "ShadowPlan"])

    # 9: hang
    log = str(tmp / "hang.jsonl")
    run([VORDR, "selftest-hang", "--log", log])
    check("hang", log, ["HangDetected"])

    # 10/10b/11: thermal warning + reload + recovered via live monitor
    if NEEDS_ROOT:
        tdir = tmp / "thermal"
        tdir.mkdir()
        th = tdir / "thresholds.json"
        th.write_text(json.dumps({"soc": {"warn_mc": 1, "crit_mc": 2},
                                  "_note": "no digits by design"}))
        out = tdir / "mon"
        out.mkdir()
        pidf, stopf = str(tdir / "m.pid"), str(tdir / "m.stop")
        proc = subprocess.Popen(
            [VORDR, "monitor-run", "--out-dir", str(out),
             "--thresholds", str(th), "--duration-s", "40", "--period-s", "2",
             "--pidfile", pidf, "--stopfile", stopf],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL)
        time.sleep(7)
        # Reload: raise thresholds back above the SoC temp -> Recovered.
        # Atomic replace so the monitor never reads a half-written file.
        tmpth = tdir / "thresholds.json.tmp"
        tmpth.write_text(json.dumps({"soc": {"warn_mc": 70000, "crit_mc": 80000},
                                     "_note": "no digits by design"}))
        tmpth.replace(th)
        proc.wait(timeout=90)
        check("thermal", str(out / "events.jsonl"),
              ["ThermalWarning", "ThresholdsReloaded", "ThermalRecovered"])

    # 12-13: reset + reinit (REAL device)
    if NEEDS_ROOT:
        log = str(tmp / "reset.jsonl")
        r = run([VORDR, "reset-cycle", "--n", "1", "--log", log])
        if r.returncode != 0:
            fails.append("reset-cycle rc != 0")
        check("reset", log, ["ResetCommanded", "ResetComplete"])
        log = str(tmp / "reinit.jsonl")
        r = run([VORDR, "reinit-cycle", "--n", "1", "--log", log])
        if r.returncode != 0:
            fails.append("reinit-cycle rc != 0")
        check("reinit", log, ["ReinitStarted", "ReinitReady"])
        log = str(tmp / "hookfail.jsonl")
        r = run([VORDR, "reinit-hook-fail", "--log", log])
        check("reinit-refused", log, ["ReinitRefused"])

    # 14: live register decode via h158 iterations
    if NEEDS_ROOT:
        out = str(tmp / "h158dec")
        run([VORDR, "h158-run", "--out-dir", out, "--f1-bin", F1BIN,
             "--f1-config", F1CFG, "--max-tokens", "8", "--duration-s", "600",
             "--max-iters", "2", "--iter-budget-ms", "120000"])
        check("reg-decode-live", out + "/events.jsonl", ["RegisterErrorDecoded"])

    # 15-16: watchdog restarts a dying child, then gives up
    wdir = tmp / "wd"
    wdir.mkdir()
    pol = wdir / "policy.json"
    pol.write_text(json.dumps({"base_delay_s": 1, "factor": 2,
                               "max_delay_s": 300, "rapid_window_s": 60,
                               "max_restarts": 3,
                               "_note": "no digits by design"}))
    log = str(wdir / "events.jsonl")
    rlog = str(wdir / "restarts.jsonl")
    r = run([VORDR, "watchdog-run", "--prog", "/bin/false",
             "--policy", str(pol), "--log", log, "--restart-log", rlog,
             "--pidfile", str(wdir / "w.pid"),
             "--stopfile", str(wdir / "w.stop")], timeout=120)
    # rc=2 expected (budget exhausted); events must show the arc.
    check("watchdog", log, ["WatchdogStarted", "ChildRestarted", "WatchdogGaveUp"])
    n_restart = sum(1 for l in Path(log).read_text().splitlines()
                    if '"kind": "ChildRestarted"' in l) if Path(log).exists() else 0
    if n_restart != 3:
        fails.append(f"watchdog: ChildRestarted x{n_restart}, want 3")

    # 17: parent revives a dead watchdog
    pdir = tmp / "wpar"
    pdir.mkdir()
    plog = str(pdir / "events.jsonl")
    # watchdog child configured to give up after 1 restart
    cpol = pdir / "cpolicy.json"
    cpol.write_text(json.dumps({"base_delay_s": 1, "factor": 2,
                                "max_delay_s": 300, "rapid_window_s": 60,
                                "max_restarts": 1,
                                "_note": "no digits by design"}))
    child_args = ",".join([
        "--prog", "/bin/false",
        "--policy", str(cpol),
        "--log", str(pdir / "c-events.jsonl"),
        "--restart-log", str(pdir / "r.jsonl"),
        "--pidfile", str(pdir / "c.pid"),
        "--stopfile", str(pdir / "c.stop")])
    proc = subprocess.Popen(
        [VORDR, "watchdog-parent", "--log", plog,
         "--pidfile", str(pdir / "p.pid"), "--stopfile", str(pdir / "p.stop"),
         "--child-args", child_args],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL)
    time.sleep(14)
    Path(pdir / "p.stop").write_text("stop\n")
    time.sleep(2)
    Path(pdir / "c.stop").write_text("stop\n")
    proc.wait(timeout=30)
    check("watchdog-parent", plog,
          ["WatchdogParentStarted", "WatchdogRevived"])

    # 18-19: supervised-run fault handling + halt
    fi = tmp / "fi.json"
    fi.write_text(json.dumps({"fault": "hang", "detail": ""}))
    out = str(tmp / "h158a")
    run([VORDR, "h158-run", "--out-dir", out, "--f1-bin", F1BIN,
         "--f1-config", F1CFG, "--max-tokens", "8", "--duration-s", "600",
         "--max-iters", "3", "--fi-file", str(fi),
         "--iter-budget-ms", "120000"])
    check("h158-handled", out + "/events.jsonl",
          ["FaultInjected", "FaultHandled"])
    fi.write_text(json.dumps({"fault": "regerr", "detail": "0x06:0x4000"}))
    out = str(tmp / "h158b")
    run([VORDR, "h158-run", "--out-dir", out, "--f1-bin", F1BIN,
         "--f1-config", F1CFG, "--max-tokens", "8", "--duration-s", "600",
         "--max-iters", "3", "--fi-file", str(fi),
         "--iter-budget-ms", "120000"])
    check("h158-halt", out + "/events.jsonl", ["SupervisedRunHalted"])

    # 20: backend L11 declaration via a Mojo probe
    probe = tmp / "be_probe.mojo"
    probe.write_text(
        "from armvegr.backend import select_backend, BACKEND_AUTO\n"
        "def main():\n"
        "    var log = List[String]()\n"
        "    var b = select_backend(\"probe_op\", 8, 8, 32, BACKEND_AUTO(), log)\n"
        "    print(\"backend=\" + String(b))\n"
        "    for i in range(len(log)):\n"
        "        print(\"LOG: \" + log[i])\n")
    r = run(["mojo", "build", "-I", REPO, str(probe),
             "-o", str(tmp / "be_probe")], timeout=300)
    if r.returncode != 0:
        fails.append("backend probe build failed: " + r.stderr[-300:])
    else:
        r = run([str(tmp / "be_probe")], timeout=60)
        if "NPU" not in r.stdout or "unavailable" not in r.stdout.lower():
            fails.append("backend probe: L11 declaration not in log: "
                         + r.stdout[-300:])
        else:
            print("  backend L11 declaration: OK")

    print()
    if fails:
        print("H159 AUDIT FAIL:")
        for f in fails:
            print("  " + f)
        sys.exit(1)
    print("H159: all degrade/fallback paths emit their events — "
          "zero silent paths")
