#!/usr/bin/env python3
# prof/gauntlet/test_stability_gates.py
# H182 — stability gate discrimination test (TEST-ONLY).
#
# Proves the gates in data/gauntlet/STABILITY_GATES.json discriminate:
# a canned all-healthy dataset must yield overall PASS, and a canned
# dataset with one bad metric per gate must yield overall FAIL with the
# right gate flagged. Every gate is individually exercised.
#
# Run: python3 prof/gauntlet/test_stability_gates.py  (from the repo root)

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gauntlet_eval import load_gates, evaluate

EVIDENCE = "canned/h182"


def canned(overrides):
    base = {
        "soak_error_rate": 0.0,
        "soak_duration_h": 4.02,
        "soak_drift_ratio": 0.03,
        "fi_unhandled_count": 0.0,
        "fi_crash_count": 0.0,
        "recovery_success_rate": 1.0,
        "determinism_match_rate": 1.0,
        "rss_slope_mb_per_h": 0.2,
        "coherence_pass_rate": 1.0,
    }
    base.update(overrides)
    return {k: {"value": v, "evidence": EVIDENCE} for k, v in base.items()}


def main() -> int:
    gates = load_gates()
    assert len(gates) >= 8, f"need >= 8 gates, got {len(gates)}"
    print(f"H182: loaded {len(gates)} gates")

    # Every gate has the required fields and a one-sentence justification.
    for g in gates:
        for field in ("gate_id", "metric", "measurement_method", "op",
                      "threshold", "source_slice", "justification"):
            assert field in g, f"gate {g.get('gate_id')} missing {field}"
        assert isinstance(g["threshold"], (int, float)), "threshold must be a number"
        assert len(g["justification"].strip()) > 10, "justification too short"
    print("H182: all gates have metric, method, numeric threshold, slice, justification")

    # Canned PASS: healthy run passes everything.
    r = evaluate(gates, canned({}))
    assert r["overall"] == "PASS", f"canned PASS dataset failed: {r}"
    assert r["n_pass"] == r["n_gates"]
    print(f"H182: canned healthy dataset -> PASS ({r['n_pass']}/{r['n_gates']})")

    # Canned FAIL: break one metric at a time; exactly that gate must fail.
    breakers = {
        "soak_error_rate": 0.01,
        "soak_duration_h": 3.5,
        "soak_drift_ratio": 0.15,
        "fi_unhandled_count": 1.0,
        "fi_crash_count": 1.0,
        "recovery_success_rate": 0.95,
        "determinism_match_rate": 0.9,
        "rss_slope_mb_per_h": 5.0,
        "coherence_pass_rate": 0.8,
    }
    for metric, bad in breakers.items():
        r = evaluate(gates, canned({metric: bad}))
        assert r["overall"] == "FAIL", f"breaking {metric} did not fail overall"
        failed = [x for x in r["results"] if x["verdict"] == "FAIL"]
        assert len(failed) == 1, f"breaking {metric} failed {len(failed)} gates"
        assert failed[0]["metric"] == metric, \
            f"breaking {metric} flagged {failed[0]['metric']}"
        print(f"H182: breaking {metric} -> FAIL flagged on {failed[0]['gate_id']}")
    print("H182-ALL-PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
