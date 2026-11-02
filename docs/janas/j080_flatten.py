#!/usr/bin/env python3
"""Flatten the J-080 headline schedule into the replay CSV for
the real-module Mojo replay: the BATCH-ALL verification order
for k=4, regime=hot, over the J-016 trace -- one row per access,
layer,expert,scaled_size, in the exact layer-major issue order
j080_streaming.py replays (for each round: for each layer, all
verified positions in order, useful and wasted alike; the cache
sees every access). The schedule is budget-independent, so one
CSV serves the replay at both operating budgets.

Usage: j080_flatten.py TRACE.jsonl OUT.csv
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from j024_tournament import load_stream  # noqa: E402
from j080_streaming import build_prompts, plan_rounds, REGIMES  # noqa: E402


def main():
    trace, out = sys.argv[1], sys.argv[2]
    header, tokens, accesses, mean_scaled = load_stream(trace)
    scaled = [s // 1024 for s in header["expert_bytes_per_layer"]]
    order, segments = build_prompts(tokens, scaled)
    k = 4
    cycle = REGIMES["hot"]
    rows = []
    counter = 0
    for toks in segments:
        rounds, counter = plan_rounds(len(toks), k, cycle, counter)
        for (s, width, accepted) in rounds:
            positions = list(range(s, s + width))
            for l in range(16):
                for p in positions:
                    for (ll, e, size) in toks[p][l]:
                        rows.append(f"{ll},{e},{size}")
    Path(out).write_text("\n".join(rows) + "\n")
    print(f"wrote {out}: {len(rows)} rows (BATCH-ALL k=4 hot)")


if __name__ == "__main__":
    main()
