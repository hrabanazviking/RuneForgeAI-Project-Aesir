"""Independent standard-library RMS equations for physical CUDA CSV output.

Expected inputs use explicitly rounded float32 test operations. math.fsum gives
an independent high-precision sum, rather than importing native reduction code.
Accept every declared case exactly once and reject missing/non-finite values.
"""
import argparse
import csv
import math
from pathlib import Path
import struct


def f32(value):
    return struct.unpack("f", struct.pack("f", value))[0]


def check(path):
    expected = {}
    for width in (128, 3072, 4096):
        for groups in (1, 3):
            for inplace in (0, 1):
                for case in range(4):
                    x = [f32(((i * 7) % 29 - 14) / 16)
                         for i in range(width * groups)]
                    factor = (1, 0, f32(1e-12), f32(1e12))[case]
                    x = [f32(value * factor) for value in x]
                    y = []
                    for group in range(groups):
                        row = x[group * width:(group + 1) * width]
                        inv = 1 / math.sqrt(math.fsum(v * v for v in row) / width
                                            + f32(1e-5))
                        y.extend(v * inv * (((i + 4) * 5) % 17 - 8) / 8
                                 for i, v in enumerate(row))
                    expected[width, groups, inplace, case] = y
    actual = {key: {} for key in expected}
    with Path(path).open(encoding="utf-8") as source:
        for row in csv.reader(source):
            if len(row) == 1 and row[0].startswith("PASS:"):
                continue
            if len(row) != 6:
                raise ValueError("Unexpected probe output")
            key = tuple(map(int, row[:4]))
            index, value = int(row[4]), float(row[5])
            if key not in actual or index in actual[key] or not math.isfinite(value):
                raise ValueError("Unexpected/duplicate/non-finite normalization value")
            actual[key][index] = value
    maximum = 0.0
    count = 0
    for key, values in expected.items():
        if set(actual[key]) != set(range(len(values))):
            raise ValueError("Missing normalization values")
        for index, value in enumerate(values):
            error = abs(actual[key][index] - value)
            if error > 2e-6 + 2e-6 * abs(value):
                raise ValueError(f"RMS numerical mismatch: {key}, index={index}")
            maximum = max(maximum, error)
            count += 1
    print(f"PASS: {count} physical RMS values; 48 cases; max_absolute_error={maximum:.9g}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path)
    check(parser.parse_args().csv)
