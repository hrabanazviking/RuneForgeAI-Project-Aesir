#!/usr/bin/env python3
# prof/gauntlet/gauntlet_eval.py
# TEST-ONLY evaluator for data/gauntlet/STABILITY_GATES.json.
#
# Loads the gates, evaluates a measurements dict
#   {metric_name: {"value": float, "evidence": str}}
# and emits per-gate verdicts plus an overall PASS/FAIL.
# Used by test_stability_gates.py (canned data) and victory_gate_2.py
# (real soak measurements).

import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GATES_PATH = REPO / "data" / "gauntlet" / "STABILITY_GATES.json"


def load_gates(path=GATES_PATH):
    with open(path) as f:
        return json.load(f)["gates"]


def evaluate_gate(gate, value):
    op = gate["op"]
    thr = gate["threshold"]
    tol = gate.get("tolerance", 0.0)
    if op == "le":
        holds = value <= thr
    elif op == "lt":
        holds = value < thr
    elif op == "ge":
        holds = value >= thr
    elif op == "gt":
        holds = value > thr
    elif op == "eq":
        holds = abs(value - thr) <= tol
    else:
        raise ValueError(f"unknown op {op!r}")
    return "PASS" if holds else "FAIL"


def evaluate(gates, measurements):
    """measurements: {metric: {"value": float, "evidence": str}}."""
    results = []
    for g in gates:
        m = measurements[g["metric"]]
        verdict = evaluate_gate(g, m["value"])
        results.append({
            "gate_id": g["gate_id"],
            "metric": g["metric"],
            "verdict": verdict,
            "measured": m["value"],
            "threshold": g["threshold"],
            "op": g["op"],
            "evidence": m["evidence"],
            "source_slice": g["source_slice"],
            "justification": g["justification"],
        })
    overall = "PASS" if all(r["verdict"] == "PASS" for r in results) else "FAIL"
    return {"overall": overall, "n_gates": len(results),
            "n_pass": sum(1 for r in results if r["verdict"] == "PASS"),
            "results": results}
