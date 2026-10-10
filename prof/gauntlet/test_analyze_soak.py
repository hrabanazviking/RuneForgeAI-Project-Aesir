#!/usr/bin/env python3
# prof/gauntlet/test_analyze_soak.py
# H185 — analyzer validation (TEST-ONLY).
#
# Validates prof/gauntlet/analyze_soak.py against synthetic logs:
#   1. injected 15% linear slowdown  -> DRIFT-DETECTED on decode_tps
#   2. clean synthetic log (flat + noise) -> DRIFT-FREE (no false positive)
#   3. the injected slope lands inside the reported 95% CI
#
# Run: python3 prof/gauntlet/test_analyze_soak.py  (from the repo root)

import json
import random
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ANALYZER = REPO / "prof" / "gauntlet" / "analyze_soak.py"


def synth_log(path, n=120, drift_frac=0.0, seed=1):
    rng = random.Random(seed)
    t = 1_700_000_000.0
    with open(path, "w") as f:
        for i in range(n):
            # One generation every ~40 s, like the real soak.
            t += 40.0
            tps = 2.0 * (1.0 - drift_frac * i / (n - 1)) + rng.gauss(0, 0.02)
            f.write(json.dumps({
                "idx": i, "phase": "soak", "ts": t,
                "decode_tps": round(tps, 3),
                "wall_s": round(64 / tps, 3),
                "peak_rss_mb": 2140.0 + rng.gauss(0, 2),
            }) + "\n")
            if i % 8 == 0:
                f.write(json.dumps({
                    "phase": "status", "ts": t, "soc_temp_c": 45.0 + rng.gauss(0, 0.5),
                }) + "\n")


def run_analyzer(path):
    r = subprocess.run([sys.executable, str(ANALYZER), str(path)],
                       capture_output=True, text=True)
    assert r.returncode == 0, f"analyzer failed: {r.stderr[-500:]}"
    return json.loads(r.stdout)


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        # 1. Injected 15% slowdown must be detected.
        p1 = Path(td) / "drift.jsonl"
        synth_log(p1, drift_frac=0.15)
        rep = run_analyzer(p1)
        m = rep["metrics"]["decode_tps"]
        assert m["verdict"] == "DRIFT-DETECTED", \
            f"missed injected drift: {m}"
        # Slope must match the injected -15% over the span, within CI.
        span_h = m["span_h"]
        expected = -0.15 * 2.0 / span_h
        lo = m["slope_per_h"] - m["slope_ci95_halfwidth"]
        hi = m["slope_per_h"] + m["slope_ci95_halfwidth"]
        assert lo <= expected <= hi, \
            f"injected slope {expected} outside CI [{lo}, {hi}]"
        print(f"H185: injected 15% slowdown -> DRIFT-DETECTED "
              f"(slope {m['slope_per_h']:.5f}/h, expected {expected:.5f})")

        # 2. Clean log: no false positive.
        p2 = Path(td) / "clean.jsonl"
        synth_log(p2, drift_frac=0.0, seed=7)
        rep2 = run_analyzer(p2)
        m2 = rep2["metrics"]["decode_tps"]
        assert m2["verdict"] == "DRIFT-FREE", \
            f"false positive on clean log: {m2}"
        print("H185: clean synthetic log -> DRIFT-FREE (no false positive)")

        # 3. wall_s creep detection mirrors decode_tps.
        assert rep["metrics"]["wall_s"]["verdict"] == "DRIFT-DETECTED"
        assert rep2["metrics"]["wall_s"]["verdict"] == "DRIFT-FREE"
        print("H185: wall_s latency-creep detection consistent")

    print("H185-ALL-PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
