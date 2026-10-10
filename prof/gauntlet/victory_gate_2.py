#!/usr/bin/env python3
# prof/gauntlet/victory_gate_2.py
# H196 — TEST-ONLY (PRÓF): victory gate 2 — stable multi-hour soak proof.
#
# GAUNTLET evaluates the H183/H186/H187/H188/H189/H195 measurements
# against data/gauntlet/STABILITY_GATES.json and emits the STABILITY
# verdict with the per-gate results table in
# data/gauntlet/victory_gate_2.json. Every gate shows measured vs
# threshold. A failing gate routes to a named H201+ remediation slice
# (the gate has teeth, not theater).
#
# Run on Mimir from the repo root AFTER the soak, FI campaign, reset
# storm, determinism, RSS check, and victory gate 1 have produced their
# evidence JSON files.

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gauntlet_eval import load_gates, evaluate

REPO = Path(__file__).resolve().parents[2]
D = REPO / "data" / "gauntlet"
OUT = D / "victory_gate_2.json"


def load(name):
    p = D / name
    if not p.exists():
        return None
    return json.loads(p.read_text())


def main() -> int:
    soak = load("soak_cpu_4h_summary.json")
    fi = load("fi_campaign/scoreboard.json")
    storm = load("reset_storm.json")
    det = load("determinism.json")
    rss = load("rss_check.json")
    vg1 = load("victory_gate_1.json")

    missing = [n for n, v in [
        ("soak_cpu_4h_summary.json", soak),
        ("fi_campaign/scoreboard.json", fi),
        ("reset_storm.json", storm),
        ("determinism.json", det),
        ("rss_check.json", rss),
        ("victory_gate_1.json", vg1)] if v is None]
    if missing:
        print("H196 FAIL: missing evidence: %s" % missing)
        return 1

    vg1_prompts = [p for m in vg1["models"] for p in m["prompts"]]
    measurements = {
        "soak_error_rate": {
            "value": 0.0 if soak["verdict"] == "PASS" else 1.0,
            "evidence": "data/gauntlet/soak_cpu_4h_summary.json"},
        "soak_duration_h": {
            "value": soak["elapsed_h"],
            "evidence": "data/gauntlet/soak_cpu_4h_summary.json"},
        "soak_drift_ratio": {
            "value": soak["drift_ratio"],
            "evidence": "data/gauntlet/soak_cpu_4h_summary.json"},
        "fi_unhandled_count": {
            "value": float(fi["injected_total"] - fi["handled_total"]),
            "evidence": "data/gauntlet/fi_campaign/scoreboard.json"},
        "fi_crash_count": {
            "value": float(fi["child_crashes"]),
            "evidence": "data/gauntlet/fi_campaign/scoreboard.json"},
        "recovery_success_rate": {
            "value": storm["recoveries_to_service"] / storm["restarts"],
            "evidence": "data/gauntlet/reset_storm.json"},
        "determinism_match_rate": {
            "value": det["match_rate"],
            "evidence": "data/gauntlet/determinism.json"},
        "rss_slope_mb_per_h": {
            "value": rss["rss_slope_mb_per_h"],
            "evidence": "data/gauntlet/rss_check.json"},
        "coherence_pass_rate": {
            "value": (sum(1 for p in vg1_prompts if p["pass"]) / len(vg1_prompts)
                      if vg1_prompts else 0.0),
            "evidence": "data/gauntlet/victory_gate_1.json"},
    }

    result = evaluate(load_gates(), measurements)
    result["title"] = "VICTORY GATE 2 — STABILITY"
    result["remediation"] = []
    for r in result["results"]:
        if r["verdict"] == "FAIL":
            rid = "H%d" % (200 + len(result["remediation"]) + 1)
            result["remediation"].append({
                "slice": rid,
                "gate": r["gate_id"],
                "goal": "Remediate failing stability gate %s (%s): measured %s vs threshold %s %s" % (
                    r["gate_id"], r["metric"], r["measured"], r["op"], r["threshold"]),
                "acceptance": "Re-run the source slice's measurement; the gate must PASS. U1-U4.",
            })
    OUT.write_text(json.dumps(result, indent=2))

    print("H196 STABILITY verdict: %s (%d/%d gates)" %
          (result["overall"], result["n_pass"], result["n_gates"]))
    for r in result["results"]:
        print("  %s %-22s measured=%s threshold(%s)=%s" %
              (r["verdict"], r["gate_id"], r["measured"], r["op"], r["threshold"]))
    if result["remediation"]:
        print("H196: FAILING GATES ROUTED TO: %s" %
              [x["slice"] for x in result["remediation"]])
    return 0 if result["overall"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
