#!/usr/bin/env python3
# prof/gauntlet/analyze_soak.py
# H185 — soak-log analyzer: drift and slowdown detection (TEST-ONLY).
#
# Ingests a soak JSONL log (data/gauntlet/soak_cpu_4h.log format) and
# reports, per metric, the OLS trend slope per hour WITH its 95%
# confidence interval, and a DRIFT-FREE / DRIFT-DETECTED verdict.
# Statistics, not eyeballing.
#
# Metrics analyzed:
#   decode_tps     — throughput trend (drift if |slope| significant and
#                     the end-to-end change exceeds 10%)
#   wall_s         — latency creep (same rule on generation wall time)
#   peak_rss_mb    — memory growth (H189: slope over the run)
#   soc_temp_c     — temperature ramp (from status records)
#
# Usage: python3 prof/gauntlet/analyze_soak.py <log.jsonl> [--out report.json]
# Exit 0 with a JSON report on stdout (or --out). The report carries
# per-metric verdicts; the caller (H196) decides PASS/FAIL.

import argparse
import json
import math
import sys
from pathlib import Path


def ols(xs, ys):
    n = len(xs)
    mx = sum(xs) / n
    my = sum(ys) / n
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    den = sum((x - mx) ** 2 for x in xs)
    if den == 0:
        raise ValueError("degenerate x")
    b = num / den
    a = my - b * mx
    rss = sum((y - (a + b * x)) ** 2 for x, y in zip(xs, ys))
    se = math.sqrt((rss / (n - 2)) / den) if n > 2 else float("inf")
    return b, 1.96 * se


def analyze_metric(name, series, drift_frac_tol=0.10):
    """series: list of (t_hours, value)."""
    if len(series) < 10:
        return {"metric": name, "verdict": "INSUFFICIENT-DATA",
                "n": len(series)}
    t0 = series[0][0]
    xs = [t - t0 for t, _ in series]
    ys = [v for _, v in series]
    slope, ci = ols(xs, ys)
    # End-to-end fractional change implied by the slope over the span.
    span_h = xs[-1] - xs[0]
    mean_y = sum(ys) / len(ys)
    frac_change = (slope * span_h / mean_y) if mean_y else 0.0
    # DRIFT-DETECTED only if the slope is statistically significant
    # (CI excludes 0) AND the implied change exceeds the tolerance.
    significant = abs(slope) > ci
    big = abs(frac_change) > drift_frac_tol
    verdict = "DRIFT-DETECTED" if (significant and big) else "DRIFT-FREE"
    return {
        "metric": name,
        "n": len(series),
        "span_h": round(span_h, 3),
        "slope_per_h": slope,
        "slope_ci95_halfwidth": ci,
        "implied_frac_change": frac_change,
        "verdict": verdict,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    gens = []   # (ts, decode_tps, wall_s, peak_rss_mb)
    temps = []  # (ts, temp_c)
    anomalies = 0
    for line in open(args.log):
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        if r.get("phase") == "soak" and "decode_tps" in r:
            gens.append((r["ts"], r["decode_tps"], r["wall_s"],
                         r.get("peak_rss_mb")))
        elif r.get("phase") == "status" and r.get("soc_temp_c") is not None:
            temps.append((r["ts"], r["soc_temp_c"]))
        if "anomaly" in r:
            anomalies += 1

    t0 = gens[0][0] if gens else 0
    to_h = lambda ts: (ts - t0) / 3600.0
    report = {
        "log": args.log,
        "generations": len(gens),
        "anomalies": anomalies,
        "metrics": {},
    }
    if gens:
        report["metrics"]["decode_tps"] = analyze_metric(
            "decode_tps", [(to_h(ts), t) for ts, t, _, _ in gens])
        report["metrics"]["wall_s"] = analyze_metric(
            "wall_s", [(to_h(ts), w) for ts, _, w, _ in gens])
        rss = [(to_h(ts), r) for ts, _, _, r in gens if r]
        if rss:
            # H189: leak signal — slope in MB/hour.
            m = analyze_metric("peak_rss_mb", rss, drift_frac_tol=10**9)
            m["leak_slope_mb_per_h"] = m.pop("slope_per_h")
            m["leak_slope_ci95"] = m.pop("slope_ci95_halfwidth")
            report["metrics"]["peak_rss_mb"] = m
    if temps:
        report["metrics"]["soc_temp_c"] = analyze_metric(
            "soc_temp_c", [(to_h(ts), t) for ts, t in temps],
            drift_frac_tol=0.25)

    text = json.dumps(report, indent=2)
    if args.out:
        Path(args.out).write_text(text)
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
