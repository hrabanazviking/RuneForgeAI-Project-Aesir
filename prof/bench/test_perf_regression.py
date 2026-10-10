#!/usr/bin/env python3
# H176 — C9 performance regression guard (TEST-ONLY).
#
# Fails if measured performance drops below the C9-optimized baselines.
# Run on Mimir: python3 prof/bench/test_perf_regression.py
#
# This is a TEST file (Python allowed per C9 HARD LAWS: "Python TESTS ONLY").

import json
import sys
from pathlib import Path

# C9-optimized baselines (measured 2026-10-10 on Mimir).
# Regression threshold: 10% below baseline fails.
BASELINES = {
    "data/bench/baseline_kernels.json": {
        "gemm_fp16": 6.934,      # H162 (pre-H164); H164 winner is 7.773
        "gemv_fp16": 4.724,
    },
    "data/bench/decode_fast.json": {
        # 47 tokens in 24.50s = 1.918 tok/s; we check median_ns directly
        "decode_median_ns_max": 26.0e9,  # allow 6% slack over 24.5s
    },
    "data/bench/prefill_opt.json": {
        "prefill_median_ns_max": 168.0e9,  # allow 10% slack over 152.3s
    },
}

THRESHOLD = 0.10  # 10% regression fails


def check_kernel_baseline(path: Path) -> list[str]:
    """Check H162 kernel baselines haven't regressed."""
    failures = []
    d = json.loads(path.read_text())
    results = {r["name"]: r["median"] for r in d["results"]}
    baselines = BASELINES["data/bench/baseline_kernels.json"]
    for name, baseline in baselines.items():
        if name not in results:
            failures.append(f"{path}: missing kernel {name}")
            continue
        measured = results[name]
        if measured < baseline * (1 - THRESHOLD):
            failures.append(
                f"{path}: {name} regressed: {measured:.3f} < "
                f"{baseline * (1 - THRESHOLD):.3f} "
                f"(baseline {baseline:.3f}, -{THRESHOLD:.0%})"
            )
    return failures


def check_e2e(path: Path, key: str, max_ns: float) -> list[str]:
    """Check e2e latency hasn't regressed."""
    failures = []
    d = json.loads(path.read_text())
    median_ns = d["results"][0]["median_ns"]
    if median_ns > max_ns:
        failures.append(
            f"{path}: {key} regressed: {median_ns/1e9:.1f}s > {max_ns/1e9:.1f}s "
            f"(max allowed)"
        )
    return failures


def main() -> int:
    root = Path(__file__).resolve().parent.parent.parent
    failures = []

    # Kernel baselines
    p = root / "data/bench/baseline_kernels.json"
    if p.exists():
        failures.extend(check_kernel_baseline(p))
    else:
        failures.append(f"missing {p}")

    # Decode (H173)
    p = root / "data/bench/decode_fast.json"
    if p.exists():
        failures.extend(
            check_e2e(p, "decode", BASELINES["data/bench/decode_fast.json"]["decode_median_ns_max"])
        )
    else:
        failures.append(f"missing {p} (run H173 measurement)")

    # Prefill (H174)
    p = root / "data/bench/prefill_opt.json"
    if p.exists():
        failures.extend(
            check_e2e(p, "prefill", BASELINES["data/bench/prefill_opt.json"]["prefill_median_ns_max"])
        )
    else:
        failures.append(f"missing {p} (run H174 measurement)")

    if failures:
        print("PERF REGRESSION FAILURES:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("PERF REGRESSION GUARD: PASS (all baselines within 10%)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
