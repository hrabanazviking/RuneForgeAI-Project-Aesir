#!/usr/bin/env python3
"""Independent integer/rational equations for complete physical MMA probe CSV."""
import argparse
import csv
import io
import json
import math
import hashlib
from pathlib import Path

from profile_native_cuda import read_text

CONFIGS = [(case, tiles, block, steps) for case in range(6) for tiles in (1, 3, 7)
           for block in (32, 128) for steps in (1, 3, 7)]


def expected(case, tile, row, column, steps):
    # All inputs are exact F16 binary fractions; integer numerator /256 is exact
    # in F32 at these admitted bounds. This oracle imports no native code.
    if case == 0:
        return float(steps if row % 8 == column else 0)
    seed = case + tile * 7
    numerator = ((row * 3 + column * 2 + seed) % 13 - 6) * 32
    for step in range(steps):
        current = seed + step * 11
        for k in range(8):
            a = (row * 7 + k * 3 + current * 5) % 17 - 8
            b = (k * 5 + column * 11 + current * 3) % 19 - 9
            numerator += a * b
    return numerator / 256.0


def parse(path):
    text = read_text(path, 8 * 1024 * 1024)
    if len(text.encode("utf-8")) > 8 * 1024 * 1024:
        raise ValueError("MMA input grew beyond byte admission")
    metadata = False
    done = False
    counts = []
    current = None
    total = 0
    guards = 0
    for fields in csv.reader(io.StringIO(text)):
        if done or not fields:
            raise ValueError("Unexpected trailing/empty MMA record")
        tag = fields[0]
        if fields == ["META", "1", "cuda", "m16n8k8", "f16", "f32", "9"] and not metadata:
            metadata = True
        elif tag == "CASE" and len(fields) == 6 and metadata:
            if current is not None:
                raise ValueError("Previous MMA case is incomplete")
            index, case, tiles, block, steps = map(int, fields[1:])
            if index != len(counts) or index >= len(CONFIGS) or (case, tiles, block, steps) != CONFIGS[index]:
                raise ValueError("MMA case identity/order mismatch")
            current = {"index": index, "case": case, "tiles": tiles, "steps": steps, "values": 0}
        elif tag == "VALUE" and len(fields) == 6 and current is not None:
            index, tile, row, column = map(int, fields[1:5]); value = float(fields[5])
            position = current["values"]
            if index != current["index"] or (tile, row, column) != (position // 128, position % 128 // 8, position % 8) or position >= current["tiles"] * 128:
                raise ValueError("Duplicate/out-of-order MMA output")
            if not math.isfinite(value) or value != expected(current["case"], tile, row, column, current["steps"]):
                raise ValueError("MMA output failed independent exact equation")
            current["values"] += 1
            total += 1
        elif tag == "GUARD" and len(fields) == 4 and current is not None:
            if fields[1:] != [str(current["index"]), "50", "0"] or current["values"] != current["tiles"] * 128:
                raise ValueError("MMA guards/output are incomplete or failed")
            counts.append(current["values"]); guards += 50; current = None
        elif fields == ["PASS", "mma", "108", "50688", "5400"] and len(counts) == 108 and current is None:
            if total != 50688 or guards != 5400:
                raise ValueError("MMA aggregate counts mismatch")
            done = True
        else:
            raise ValueError("Unexpected MMA CSV record")
    if not done:
        raise ValueError("Missing complete MMA marker")
    return {"schema": 1, "passed": True, "cases": 108, "outputs": total, "guards": guards,
            "invalid_metadata_cases": 9, "max_absolute_error": 0.0,
            "csv_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
            "limits": "Exact synthetic binary operands only. Physical source/lowering/hardware identity is recorded separately. No real-weight F16 quality, full-model acceleration or speed-lead claim."}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("csv", type=Path); p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    with a.output.open("x", encoding="utf-8") as stream:
        try:
            report = parse(a.csv)
        except Exception as error:
            report = {"schema": 1, "passed": False, "error": f"{type(error).__name__}: {error}"}
        json.dump(report, stream, indent=2); stream.write("\n")
    print("PASS: independent MMA equations" if report["passed"] else "FAIL: " + report["error"])
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
