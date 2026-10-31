#!/usr/bin/env python3
"""Flatten the J-016 trace into the J-028 replay CSV for the
real-module Mojo replay: one row per access,
token,layer,expert,scaled_size, in trace token order, so the
replay can apply pressure events at token boundaries exactly as
j028_pressure.py does."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from j024_tournament import load_stream  # noqa: E402
from j028_pressure import build_token_stream  # noqa: E402


def main():
    trace, out = sys.argv[1], sys.argv[2]
    header, tokens, accesses, mean_scaled = load_stream(trace)
    scaled = [s // 1024 for s in header["expert_bytes_per_layer"]]
    stream = build_token_stream(tokens, scaled)
    rows = []
    for t, accs in enumerate(stream):
        for (l, e, size) in accs:
            rows.append(f"{t},{l},{e},{size}")
    Path(out).write_text("\n".join(rows) + "\n")
    print(f"wrote {out}: {len(rows)} rows, {len(stream)} tokens")


if __name__ == "__main__":
    main()
