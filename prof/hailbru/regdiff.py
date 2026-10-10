#!/usr/bin/env python3
# TEST-ONLY (PRÓF) — H096: diff a live `probe snapshot` against the golden
# register map. Reports only genuine deviations (volatile-masked bits
# never reported).
#
# Usage: regdiff.py --golden data/hailbru/register_map_golden.json \
#            --state ready --snap live.json
# Exit 0 = no deviations; exit 2 = deviations found (listed as JSON).
import argparse
import json
import sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--golden", required=True)
    ap.add_argument("--state", required=True)
    ap.add_argument("--snap", required=True)
    a = ap.parse_args()

    with open(a.golden) as f:
        golden = json.load(f)["states"][a.state]
    with open(a.snap) as f:
        live = json.load(f)["registers"]

    deviations = []
    for name, g in golden.items():
        if name not in live:
            deviations.append({"register": name, "kind": "missing_in_live"})
            continue
        got = live[name] & g["mask"]
        want = g["value"] & g["mask"]
        if got != want:
            deviations.append({
                "register": name,
                "kind": "value_mismatch",
                "got": hex(live[name]),
                "expected": g["value_hex"],
                "mask": g["mask_hex"],
                "got_masked": hex(got),
                "expected_masked": hex(want),
            })
    print(json.dumps({"deviations": deviations,
                      "count": len(deviations)}, indent=2))
    return 2 if deviations else 0


if __name__ == "__main__":
    sys.exit(main())
