#!/usr/bin/env python3
# prof/gauntlet/check_rss.py
# H189 — TEST-ONLY (PRÓF): memory-leak check from soak RSS data.
#
# Reads data/gauntlet/soak_rss.jsonl (per-generation peak RSS sampled
# during the H183 4h soak — f1_infer is one-shot per generation, so the
# per-generation peak at the same point in each run is the leak signal)
# and fits RSS vs time over the SECOND hour: slope <= 1 MB/hour passes.
#
# NO-GO branch: no DMA-mapped memory exists (no NPU), so the mapped-bytes
# check does not apply; stated here, not silently skipped.
#
# Run on Mimir from the repo root:
#   python3 prof/gauntlet/check_rss.py

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RSS_LOG = REPO / "data" / "gauntlet" / "soak_rss.jsonl"
OUT = REPO / "data" / "gauntlet" / "rss_check.json"

BUDGET_MB_PER_H = 1.0


def ols_slope(xs, ys):
    n = len(xs)
    mx = sum(xs) / n
    my = sum(ys) / n
    den = sum((x - mx) ** 2 for x in xs)
    if den == 0:
        return 0.0
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / den


def main() -> int:
    pts = []
    for line in open(RSS_LOG):
        line = line.strip()
        if line:
            r = json.loads(line)
            pts.append((r["ts"], r["peak_rss_mb"]))
    if len(pts) < 60:
        print("H189 FAIL: only %d RSS samples" % len(pts))
        return 1
    t0 = pts[0][0]
    # Second hour of the run.
    second = [(t - t0) / 3600.0 for t, _ in pts if 3600 <= t - t0 < 7200]
    rss2 = [r for (t, r) in pts if 3600 <= t - t0 < 7200]
    slope = ols_slope(second, rss2)
    result = {
        "verdict": "PASS" if slope <= BUDGET_MB_PER_H else "FAIL",
        "n_samples": len(pts),
        "n_second_hour": len(second),
        "rss_slope_mb_per_h": slope,
        "budget_mb_per_h": BUDGET_MB_PER_H,
        "rss_first_mb": round(pts[0][1], 1),
        "rss_last_mb": round(pts[-1][1], 1),
        "dma_mapping_check": "N/A (NO-GO branch: no NPU, no DMA-mapped memory)",
    }
    OUT.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    print("H189-ALL-PASS" if result["verdict"] == "PASS"
          else "H189 FAIL: slope %.2f MB/h exceeds budget" % slope)
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
