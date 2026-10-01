"""Independent NumPy long-attention oracle; consumes the physical Mojo CSV.

Test-only dependency: NumPy 2.4.4. No import in the native inference engine.
"""
import argparse
import csv
import numpy as np


def check(path):
    cases = {(count, heads): {} for count in (1, 7, 31, 32, 33, 1024, 4096, 8192)
             for heads in (8, 24, 32)}
    sentinel = False
    with open(path, encoding="utf-8") as source:
        for row in csv.reader(source):
            if row == ["PASS: 24 exact long-attention cases and guarded outputs"]:
                assert not sentinel, "duplicate completion marker"
                sentinel = True
                continue
            assert not sentinel and len(row) == 4, "malformed or trailing output"
            count, heads, index = map(int, row[:3])
            assert (count, heads) in cases, "unexpected attention case"
            values = cases[count, heads]
            assert index not in values, "duplicate attention index"
            values[index] = float(row[3])
    assert sentinel, "missing physical completion marker"
    maximum = 0.0
    tested = 0
    for (count, heads), actual in cases.items():
        assert set(actual) == set(range(heads * 128)), "incomplete attention output"
        t = np.arange(count)[:, None]
        i = np.arange(1024)[None, :]
        # Mirror input serialization precision, then evaluate independently in F64.
        values = ((t * 13 + i * 7) % 97 - 48).astype(np.float32)
        values = (values / np.float32(17)).astype(np.float16).astype(np.float64)
        values = values.reshape(count, 8, 128)
        values = np.repeat(values, heads // 8, axis=1)
        head = np.arange(heads)[:, None]
        scores = ((np.arange(count)[None, :] + head * 7) % 17 + 1).astype(np.float32)
        scores = (scores / np.float32(count * 9)).astype(np.float64)
        expected = np.einsum("ht,thd->hd", scores, values).ravel()
        observed = np.array([actual[i] for i in range(heads * 128)])
        np.testing.assert_allclose(observed, expected, atol=2e-5, rtol=2e-5)
        error = float(np.max(np.abs(observed - expected)))
        maximum = max(maximum, error)
        tested += len(expected)
        print(f"PASS count={count} heads={heads}: {len(expected)} values, max_absolute_error={error:.9g}")
    print(f"PASS: {tested} physical long-attention values, independent maximum_absolute_error={maximum:.9g}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv")
    check(parser.parse_args().csv)
