#!/usr/bin/env python3
# TEST-ONLY (PRÓF) — H082/H096: build the golden register snapshots from
# repeated `probe snapshot` captures.
#
# Usage: build_golden.py --state post_reset --snaps s1.json s2.json s3.json \
#            --out data/hailbru/register_map_golden.json [--update]
# Merges per-state entries into register_map_golden.json (creates it if
# absent with --update). Volatile bits = bits that differ across the
# repeated captures; those mask bits are cleared (not compared later).
# KNOWN_VOLATILE documents bits proven volatile by direct measurement.
import argparse
import json
import sys

# offset-name -> volatile bitmask (bits observed to churn; cleared from
# the compare mask). Evidence: 2026-10-10 — 0x018C bit23 reads 0x0 ~1ms
# after D0 entry (bringup ready_poll) but 0x00800000 ~200ms+ later
# (pm-set + snapshot path); stable across consecutive reads once set.
# It is time-since-D0-entry dependent, so it must not be compared.
KNOWN_VOLATILE = {
    "bar0_0x018c": 0x00800000,
}


def load_snaps(paths):
    snaps = []
    for p in paths:
        with open(p) as f:
            snaps.append(json.load(f))
    return snaps


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--state", required=True,
                    choices=["post_reset", "booting", "ready", "in_reset"])
    ap.add_argument("--snaps", nargs="+", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--update", action="store_true")
    a = ap.parse_args()

    snaps = load_snaps(a.snaps)
    reg_names = sorted(snaps[0]["registers"].keys())
    for s in snaps[1:]:
        if sorted(s["registers"].keys()) != reg_names:
            print("register set mismatch across snapshots", file=sys.stderr)
            return 1

    entries = {}
    for name in reg_names:
        vals = [s["registers"][name] for s in snaps]
        # Bits that differ across captures are volatile -> mask them out.
        diff = 0
        for v in vals[1:]:
            diff |= vals[0] ^ v
        mask = (~diff) & 0xFFFFFFFF
        kv = KNOWN_VOLATILE.get(name, 0)
        if kv:
            mask &= (~kv) & 0xFFFFFFFF
        entries[name] = {
            "value": vals[0],
            "value_hex": hex(vals[0]),
            "mask": mask,
            "mask_hex": hex(mask),
            "observed_values": vals,
            "known_volatile_bits": hex(kv) if kv else "0x0",
            "evidence": "probe snapshot x%d on Mimir 2026-10-10 (%s)"
                        % (len(vals), a.state),
        }
        if diff & ~kv:
            print("NOTE %s: cross-capture churn beyond known-volatile: %s"
                  % (name, hex(diff & ~kv)))

    try:
        with open(a.out) as f:
            golden = json.load(f)
    except FileNotFoundError:
        if not a.update:
            print("no golden file; pass --update to create", file=sys.stderr)
            return 1
        golden = {"states": {}, "notes": []}
    golden["states"][a.state] = entries
    golden.setdefault("notes", []).append(
        "state '%s' captured %d runs 2026-10-10; mask bits = compared bits; "
        "cleared mask bits = volatile/ignored" % (a.state, len(snaps)))
    with open(a.out, "w") as f:
        json.dump(golden, f, indent=2)
    print("state %s: %d registers written to %s" % (a.state, len(entries), a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
