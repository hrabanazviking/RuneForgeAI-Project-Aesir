#!/usr/bin/env python3
# prof/gauntlet/victory_gate_3.py
# H197 — TEST-ONLY (PRÓF): victory gate 3 — crash-resistance proof.
#
# GAUNTLET emits the CRASH-RESISTANCE verdict from the H186 fault-
# injection campaign evidence: the fault scoreboard
# (injected/handled/missed per class, missed = 0), explicitly covering
# process crashes (0), unhandled faults (0), silent degradations (0 per
# the H159 audit), and recovery-budget compliance (H155 budgets met).
# Stored in data/gauntlet/victory_gate_3.json.
#
# Run on Mimir from the repo root AFTER the H186 campaign.

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
D = REPO / "data" / "gauntlet"
OUT = D / "victory_gate_3.json"


def main() -> int:
    sb_path = D / "fi_campaign" / "scoreboard.json"
    storm_path = D / "reset_storm.json"
    if not sb_path.exists():
        print("H197 FAIL: missing fi_campaign/scoreboard.json (run H186 first)")
        return 1
    sb = json.loads(sb_path.read_text())
    storm = json.loads(storm_path.read_text()) if storm_path.exists() else None

    per_class = {}
    for cls in sorted(set(sb["injected"]) | set(sb["handled"])):
        inj = sb["injected"].get(cls, 0)
        han = sb["handled"].get(cls, 0)
        per_class[cls] = {"injected": inj, "handled": han,
                          "missed": inj - han}

    checks = {
        "process_crashes_zero": sb["child_crashes"] == 0,
        "unhandled_faults_zero": all(v["missed"] == 0 for v in per_class.values()),
        "faults_ge_100": sb["injected_total"] >= 100,
        "all_classes_covered": all(sb["injected"].get(c, 0) > 0
                                   for c in ("hang", "regerr", "dmacorrupt")),
        # H159 audit: no silent degradations — every injected fault has a
        # handling event; the reconciliation below is the machine check.
        "silent_degradations_zero": sb["injected_total"] == sb["handled_total"],
        # H155 budgets: the reset storm (H187) proves recovery-budget
        # compliance on the same build.
        "recovery_budget_compliant": bool(
            storm and storm["verdict"] == "PASS"
            and storm["all_within_h155_budget_ms"]),
    }
    verdict = "PASS" if all(checks.values()) else "FAIL"
    result = {
        "title": "VICTORY GATE 3 — CRASH-RESISTANCE",
        "verdict": verdict,
        "scoreboard_per_class": per_class,
        "injected_total": sb["injected_total"],
        "handled_total": sb["handled_total"],
        "process_crashes": sb["child_crashes"],
        "checks": checks,
        "evidence": {
            "fi_campaign": "data/gauntlet/fi_campaign/scoreboard.json",
            "fi_events": "data/gauntlet/fi_campaign/events.jsonl",
            "reset_storm": "data/gauntlet/reset_storm.json",
            "h159_audit": "docs/vordr/FALLBACK_AUDIT.md",
        },
    }
    OUT.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    print("H197-ALL-PASS" if verdict == "PASS" else "H197 FAIL")
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
