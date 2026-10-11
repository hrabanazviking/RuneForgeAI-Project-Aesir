#!/usr/bin/env python3
# prof/run_all.py
# H198 — TEST-ONLY (PRÓF): full suite final run.
#
# Executes the ENTIRE PRÓF corpus — every prof/**/test_*.py plus the
# victory-gate drivers — in dependency order, unattended (stdin closed),
# and ends with a summary: total tests, passed, failed (must be 0),
# skipped (each skip justified). Total runtime is recorded.
#
# The corpus spans two machines by construction (each test runs where
# its toolchain lives, exactly as its own campaign ran it):
#   - "mimir": the production target (Raspberry Pi 5). Run AS ROOT —
#     the C8 VÖRÐR tests drive vordr_cli, whose device supervision
#     needs root (see H186).
#   - "x86": the cross-compile host (this forge VM): the two tests
#     that drive the pixi x86 cross-compile toolchain
#     (test_cpu_smoke, test_tokenizers).
# Run each side, then merge:
#   sudo python3 prof/run_all.py --version 1.0 --machine mimir < /dev/null
#   python3 prof/run_all.py --version 1.0 --machine x86 < /dev/null
#   python3 prof/run_all.py --merge
# The merged summary lands in data/gauntlet/full_suite.json.
#
# Order within a machine: fast pure checks first, then domain suites,
# then the long production proofs (packaging, reset storm,
# determinism, fault injection, the 4h soak), then the victory gates.
#
# Invocation notes (found by the H198 first attempts, 2026-10-11):
# - test_log_schema.py requires --selftest (bare run prints usage).
# - test_error_paths.py is a pytest module (self-runs pytest) and
#   needs $HAILBRU_PROBE pointing at the C5 probe binary.
# - test_reset_cycles.py requires --probe/--out; the probe is the C5
#   bring-up CLI kept reboot-safe at ~/mimisbrunnr_c5/bin/probe.

import argparse
import glob
import json
import os
import platform
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
PROBE = "/home/pi/mimisbrunnr_c5/bin/probe"

# (script, extra_args, note, extra_env, machine)
SUITE = [
    ("prof/gauntlet/test_gauntlet_purity.py", [], "H181 architectural self-test", None, "mimir"),
    ("prof/gauntlet/test_stability_gates.py", [], "H182 gate discrimination", None, "mimir"),
    ("prof/gauntlet/test_analyze_soak.py", [], "H185 analyzer validation (synthetic)", None, "mimir"),
    ("prof/vordr/test_taxonomy_complete.py", [], "C8 taxonomy completeness", None, "mimir"),
    ("prof/hailbru/test_log_schema.py", ["--selftest"], "C8 log schema", None, "mimir"),
    ("prof/hailbru/test_error_paths.py", [], "C8 error paths",
     {"HAILBRU_PROBE": PROBE}, "mimir"),
    ("prof/vordr/test_fallback_audit.py", [], "C8 fallback audit", None, "mimir"),
    ("prof/armvegr/test_cpu_smoke.py", [], "C2 CPU smoke (x86 xcompile host)", None, "x86"),
    ("prof/armvegr/test_tokenizers.py", [], "C3 tokenizers (x86 xcompile host)", None, "x86"),
    ("prof/armvegr/test_kernel_oracles.py", [], "C2 kernel oracles", None, "mimir"),
    ("prof/bench/test_perf_regression.py", [], "C9 perf regression guard", None, "mimir"),
    ("prof/hailbru/test_reset_cycles.py",
     ["--probe", PROBE, "--bdf", "0001:01:00.0", "--cycles", "100",
      "--out", "data/hailbru/reset_cycles_100.json", "--sudo"],
     "C5/H084 reset cycles (100 PM-cycle bring-ups)", None, "mimir"),
    ("prof/vordr/test_fi_registers.py", [], "C8 FI: registers", None, "mimir"),
    ("prof/vordr/test_fi_hangs.py", [], "C8 FI: hangs", None, "mimir"),
    ("prof/vordr/test_fi_dma_corrupt.py", [], "C8 FI: DMA corruption", None, "mimir"),
    ("prof/vordr/test_fi_removal.py", [], "C8 FI: removal", None, "mimir"),
    ("prof/vordr/test_fi_supervised.py", [], "C8 FI: supervised", None, "mimir"),
    ("prof/gauntlet/test_packaging.py", ["--version", "{ver}"], "H190 packaging", None, "mimir"),
    ("prof/gauntlet/test_reset_storm.py", [], "H187 reset storm", None, "mimir"),
    ("prof/gauntlet/test_determinism.py", [], "H188 determinism", None, "mimir"),
    ("prof/gauntlet/check_rss.py", [], "H189 RSS leak check", None, "mimir"),
    ("prof/gauntlet/test_fi_campaign.py", [], "H186 FI campaign (60 min)", None, "mimir"),
    ("prof/gauntlet/test_soak_cpu_4h.py", [], "H183 4h soak", None, "mimir"),
    ("prof/gauntlet/victory_gate_1.py", [], "H195 victory gate 1", None, "mimir"),
    ("prof/gauntlet/victory_gate_2.py", [], "H196 victory gate 2", None, "mimir"),
    ("prof/gauntlet/victory_gate_3.py", [], "H197 victory gate 3", None, "mimir"),
]

SKIPPED = [
    # (test, reason) — branch-justified skips only.
    ("prof/gauntlet/test_soak_npu_4h.py",
     "H184 SKIPPED: H111 was NO-GO — no NPU compute path exists to soak; "
     "recorded skipped-with-reason per docs/fallback/RESCOPED_PLAN.md"),
]


def detect_machine():
    m = platform.machine().lower()
    return "mimir" if m in ("aarch64", "arm64") else "x86"


def clean_scratch():
    """Restore the fresh-/tmp assumption the C8 tests were written
    against (their campaign ran on a wiped /tmp). Several vordr tests
    append to fixed-name event logs under /tmp (e.g.
    /tmp/vordr-h154-events.jsonl); a stale log double-counts events —
    exactly the H198 attempt-1 failure at test_fi_dma_corrupt
    (1000 events counted vs 500 injected). All /tmp/vordr-* state is
    per-run disposable, so it is removed before every mimir test."""
    for p in glob.glob("/tmp/vordr-*"):
        try:
            if os.path.isdir(p):
                import shutil
                shutil.rmtree(p, ignore_errors=True)
            else:
                os.unlink(p)
        except OSError:
            pass


def run_machine(machine, version, resume=False) -> int:
    subset = [s for s in SUITE if s[4] == machine]
    out = REPO / "data" / "gauntlet" / ("full_suite_%s.json" % machine)
    kept = {}
    if resume and out.exists():
        prev = json.loads(out.read_text())
        kept = {r["script"]: r for r in prev.get("results", []) if r["pass"]}
        print("H198 RESUME [%s]: keeping %d passed results" % (machine, len(kept)),
              flush=True)
    t0 = time.time()
    results = []
    for script, extra, note, extra_env, _mach in subset:
        if script in kept:
            results.append(kept[script])
            print("H198 SKIP (passed in earlier attempt): %s" % script, flush=True)
            continue
        if machine == "mimir":
            clean_scratch()
        argv = [sys.executable, script] + [
            a.format(ver=version) for a in extra]
        print("=" * 70, flush=True)
        print("H198 RUN [%s]: %s  (%s)" % (machine, script, note), flush=True)
        t1 = time.time()
        env = None
        if extra_env:
            env = dict(os.environ)
            env.update(extra_env)
        try:
            r = subprocess.run(argv, cwd=str(REPO), stdin=subprocess.DEVNULL,
                               capture_output=True, text=True, timeout=6 * 3600,
                               env=env)
            ok = (r.returncode == 0)
            tail = (r.stdout or "")[-800:] + (r.stderr or "")[-800:]
        except subprocess.TimeoutExpired:
            ok, tail = False, "TIMEOUT after 6h"
        except OSError as e:
            ok, tail = False, "spawn failed: %s" % e
        dt = time.time() - t1
        results.append({"script": script, "pass": ok,
                        "seconds": round(dt, 1), "tail": tail})
        print("H198 %s: %s (%.1fs)" % ("PASS" if ok else "FAIL", script, dt),
              flush=True)
        if not ok:
            print("H198 ABORTING on first failure.", flush=True)
            break

    total_s = time.time() - t0
    passed = sum(1 for r in results if r["pass"])
    failed = [r["script"] for r in results if not r["pass"]]
    summary = {
        "machine": machine,
        "resumed": resume,
        "verdict": "PASS" if not failed and len(results) == len(subset) else "FAIL",
        "total_tests": len(subset),
        "executed": len(results),
        "passed": passed,
        "failed": failed,
        "total_runtime_s": round(total_s, 1),
        "total_runtime_h": round(total_s / 3600, 2),
        "results": results,
    }
    out.write_text(json.dumps(summary, indent=2))
    print("=" * 70)
    print("H198 [%s] SUMMARY: %d/%d passed, failed=%s, runtime=%.2fh" % (
        machine, passed, len(subset), failed, total_s / 3600))
    print("H198-%s-%s" % (machine.upper(), "ALL-PASS" if summary["verdict"] == "PASS" else "FAIL"))
    return 0 if summary["verdict"] == "PASS" else 1


def merge() -> int:
    parts = {}
    for machine in ("mimir", "x86"):
        p = REPO / "data" / "gauntlet" / ("full_suite_%s.json" % machine)
        if not p.exists():
            print("H198 MERGE FAIL: missing %s" % p)
            return 1
        parts[machine] = json.loads(p.read_text())
    total = sum(p["total_tests"] for p in parts.values())
    executed = sum(p["executed"] for p in parts.values())
    passed = sum(p["passed"] for p in parts.values())
    failed = [f for p in parts.values() for f in p["failed"]]
    runtime = sum(p["total_runtime_s"] for p in parts.values())
    ok = (not failed and executed == total
          and all(p["verdict"] == "PASS" for p in parts.values()))
    summary = {
        "verdict": "PASS" if ok else "FAIL",
        "total_tests": total,
        "executed": executed,
        "passed": passed,
        "failed": failed,
        "skipped": [{"test": t, "reason": r} for t, r in SKIPPED],
        "total_runtime_s": round(runtime, 1),
        "total_runtime_h": round(runtime / 3600, 2),
        "machines": {m: {"verdict": p["verdict"], "passed": p["passed"],
                         "total_tests": p["total_tests"],
                         "total_runtime_h": p["total_runtime_h"]}
                     for m, p in parts.items()},
        "results": [r for p in parts.values() for r in p["results"]],
    }
    out = REPO / "data" / "gauntlet" / "full_suite.json"
    out.write_text(json.dumps(summary, indent=2))
    print("H198 MERGED SUMMARY: %d/%d passed, failed=%s, skipped=%d, runtime=%.2fh" % (
        passed, total, failed, len(SKIPPED), runtime / 3600))
    print("H198-ALL-PASS" if ok else "H198 FAIL")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="1.0")
    ap.add_argument("--machine", choices=["mimir", "x86"], default=None)
    ap.add_argument("--merge", action="store_true")
    ap.add_argument("--resume", action="store_true",
                    help="keep PASS results from an earlier attempt of the "
                         "same machine subset and run only the rest")
    args = ap.parse_args()
    if args.merge:
        return merge()
    return run_machine(args.machine or detect_machine(), args.version,
                       resume=args.resume)


if __name__ == "__main__":
    sys.exit(main())
