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
# Run on Mimir from the repo root (takes ~7-8 h unattended):
#   python3 prof/run_all.py --version <release-version> < /dev/null

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# (script, extra_args, justification_if_slow)
SUITE = [
    ("prof/gauntlet/test_gauntlet_purity.py", [], "H181 architectural self-test"),
    ("prof/gauntlet/test_stability_gates.py", [], "H182 gate discrimination"),
    ("prof/gauntlet/test_analyze_soak.py", [], "H185 analyzer validation (synthetic)"),
    ("prof/vordr/test_taxonomy_complete.py", [], "C8 taxonomy completeness"),
    ("prof/hailbru/test_log_schema.py", [], "C8 log schema"),
    ("prof/hailbru/test_error_paths.py", [], "C8 error paths"),
    ("prof/vordr/test_fallback_audit.py", [], "C8 fallback audit"),
    ("prof/armvegr/test_cpu_smoke.py", [], "C2 CPU smoke"),
    ("prof/armvegr/test_tokenizers.py", [], "C3 tokenizers"),
    ("prof/armvegr/test_kernel_oracles.py", [], "C2 kernel oracles"),
    ("prof/bench/test_perf_regression.py", [], "C9 perf regression guard"),
    ("prof/hailbru/test_reset_cycles.py", [], "C8 reset cycles"),
    ("prof/vordr/test_fi_registers.py", [], "C8 FI: registers"),
    ("prof/vordr/test_fi_hangs.py", [], "C8 FI: hangs"),
    ("prof/vordr/test_fi_dma_corrupt.py", [], "C8 FI: DMA corruption"),
    ("prof/vordr/test_fi_removal.py", [], "C8 FI: removal"),
    ("prof/vordr/test_fi_supervised.py", [], "C8 FI: supervised"),
    ("prof/gauntlet/test_packaging.py", ["--version", "{ver}"], "H190 packaging"),
    ("prof/gauntlet/test_reset_storm.py", [], "H187 reset storm"),
    ("prof/gauntlet/test_determinism.py", [], "H188 determinism"),
    ("prof/gauntlet/check_rss.py", [], "H189 RSS leak check"),
    ("prof/gauntlet/test_fi_campaign.py", [], "H186 FI campaign (60 min)"),
    ("prof/gauntlet/test_soak_cpu_4h.py", [], "H183 4h soak"),
    ("prof/gauntlet/victory_gate_1.py", [], "H195 victory gate 1"),
    ("prof/gauntlet/victory_gate_2.py", [], "H196 victory gate 2"),
    ("prof/gauntlet/victory_gate_3.py", [], "H197 victory gate 3"),
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
    for script, extra, note in SUITE:
        argv = [sys.executable, script] + [
            a.format(ver=args.version) for a in extra]
        print("=" * 70, flush=True)
        print("H198 RUN: %s  (%s)" % (script, note), flush=True)
        t1 = time.time()
        try:
            r = subprocess.run(argv, cwd=str(REPO), stdin=subprocess.DEVNULL,
                               capture_output=True, text=True, timeout=6 * 3600)
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
