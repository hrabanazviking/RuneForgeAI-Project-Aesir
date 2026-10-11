#!/usr/bin/env python3
# prof/run_all.py
# H198 — TEST-ONLY (PRÓF): full suite final run.
#
# Executes the ENTIRE PRÓF corpus — every prof/**/test_*.py plus the
# victory-gate drivers — in dependency order, unattended (stdin closed),
# and ends with a summary: total tests, passed, failed (must be 0),
# skipped (each skip justified). Total runtime is recorded.
#
# Order: fast pure checks first, then domain suites, then the long
# production proofs (packaging, reset storm, determinism, fault
# injection, the 4h soak), then the victory gates.
#
# Run on Mimir from the repo root (takes ~7-8 h unattended), AS ROOT
# (the C8 VÖRÐR tests drive vordr_cli, whose device supervision needs
# root — see H186):
#   sudo python3 prof/run_all.py --version <release-version> < /dev/null

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# (script, extra_args, justification_if_slow, extra_env)
# Invocation notes (found by the H198 first attempt, 2026-10-11):
# - test_log_schema.py requires --selftest (bare run prints usage, rc 2).
# - test_error_paths.py is a pytest module (self-runs pytest) and needs
#   $HAILBRU_PROBE pointing at the C5 probe binary.
# - test_reset_cycles.py requires --probe/--out; the probe is the C5
#   bring-up CLI kept reboot-safe at ~/mimisbrunnr_c5/bin/probe.
PROBE = "/home/pi/mimisbrunnr_c5/bin/probe"
SUITE = [
    ("prof/gauntlet/test_gauntlet_purity.py", [], "H181 architectural self-test", None),
    ("prof/gauntlet/test_stability_gates.py", [], "H182 gate discrimination", None),
    ("prof/gauntlet/test_analyze_soak.py", [], "H185 analyzer validation (synthetic)", None),
    ("prof/vordr/test_taxonomy_complete.py", [], "C8 taxonomy completeness", None),
    ("prof/hailbru/test_log_schema.py", ["--selftest"], "C8 log schema", None),
    ("prof/hailbru/test_error_paths.py", [], "C8 error paths",
     {"HAILBRU_PROBE": PROBE}),
    ("prof/vordr/test_fallback_audit.py", [], "C8 fallback audit", None),
    ("prof/armvegr/test_cpu_smoke.py", [], "C2 CPU smoke", None),
    ("prof/armvegr/test_tokenizers.py", [], "C3 tokenizers", None),
    ("prof/armvegr/test_kernel_oracles.py", [], "C2 kernel oracles", None),
    ("prof/bench/test_perf_regression.py", [], "C9 perf regression guard", None),
    ("prof/hailbru/test_reset_cycles.py",
     ["--probe", PROBE, "--bdf", "0001:01:00.0", "--cycles", "100",
      "--out", "data/hailbru/reset_cycles_100.json", "--sudo"],
     "C5/H084 reset cycles (100 PM-cycle bring-ups)", None),
    ("prof/vordr/test_fi_registers.py", [], "C8 FI: registers", None),
    ("prof/vordr/test_fi_hangs.py", [], "C8 FI: hangs", None),
    ("prof/vordr/test_fi_dma_corrupt.py", [], "C8 FI: DMA corruption", None),
    ("prof/vordr/test_fi_removal.py", [], "C8 FI: removal", None),
    ("prof/vordr/test_fi_supervised.py", [], "C8 FI: supervised", None),
    ("prof/gauntlet/test_packaging.py", ["--version", "{ver}"], "H190 packaging", None),
    ("prof/gauntlet/test_reset_storm.py", [], "H187 reset storm", None),
    ("prof/gauntlet/test_determinism.py", [], "H188 determinism", None),
    ("prof/gauntlet/check_rss.py", [], "H189 RSS leak check", None),
    ("prof/gauntlet/test_fi_campaign.py", [], "H186 FI campaign (60 min)", None),
    ("prof/gauntlet/test_soak_cpu_4h.py", [], "H183 4h soak", None),
    ("prof/gauntlet/victory_gate_1.py", [], "H195 victory gate 1", None),
    ("prof/gauntlet/victory_gate_2.py", [], "H196 victory gate 2", None),
    ("prof/gauntlet/victory_gate_3.py", [], "H197 victory gate 3", None),
]

SKIPPED = [
    # (test, reason) — branch-justified skips only.
    ("prof/gauntlet/test_soak_npu_4h.py",
     "H184 SKIPPED: H111 was NO-GO — no NPU compute path exists to soak; "
     "recorded skipped-with-reason per docs/fallback/RESCOPED_PLAN.md"),
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    args = ap.parse_args()
    t0 = time.time()
    results = []
    for script, extra, note, extra_env in SUITE:
        argv = [sys.executable, script] + [
            a.format(ver=args.version) for a in extra]
        print("=" * 70, flush=True)
        print("H198 RUN: %s  (%s)" % (script, note), flush=True)
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
        "verdict": "PASS" if not failed and len(results) == len(SUITE) else "FAIL",
        "total_tests": len(SUITE),
        "executed": len(results),
        "passed": passed,
        "failed": failed,
        "skipped": [{"test": t, "reason": r} for t, r in SKIPPED],
        "total_runtime_s": round(total_s, 1),
        "total_runtime_h": round(total_s / 3600, 2),
        "results": results,
    }
    out = REPO / "data" / "gauntlet" / "full_suite.json"
    out.write_text(json.dumps(summary, indent=2))
    print("=" * 70)
    print("H198 SUMMARY: %d/%d passed, failed=%s, skipped=%d, runtime=%.2fh" % (
        passed, len(SUITE), failed, len(SKIPPED), total_s / 3600))
    print("H198-ALL-PASS" if summary["verdict"] == "PASS" else "H198 FAIL")
    return 0 if summary["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
