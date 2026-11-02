#!/usr/bin/env python3
"""Flatten the J-016 trace into the J-026 interleaved two-tenant
schedule CSV for the real-module Mojo replay: one row per access,
tenant,layer,expert,scaled_size, in the exact token round-robin
order j026_multi.py replays (tenant A = prose+code+technical,
tenant B = structured+numbers+instructions)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from j024_tournament import load_stream  # noqa: E402
from j026_multi import build_tenant_streams, interleave  # noqa: E402


def main():
    trace, out = sys.argv[1], sys.argv[2]
    header, tokens, accesses, mean_scaled = load_stream(trace)
    scaled = [s // 1024 for s in header["expert_bytes_per_layer"]]
    streams, ntok = build_tenant_streams(tokens, scaled)
    rows = []
    left = {"A": len(streams["A"]), "B": len(streams["B"])}
    for t, accs in interleave(streams):
        for (l, e, size) in accs:
            rows.append(f"{t},{l},{e},{size}")
        left[t] -= 1
        if left[t] == 0:
            # Exhaustion marker: the tenant is inactive from here
            # (session open, not serving) -- the lending tail.
            rows.append(f"X,{t}")
    Path(out).write_text("\n".join(rows) + "\n")
    print(f"wrote {out}: {len(rows)} rows")


if __name__ == "__main__":
    main()
