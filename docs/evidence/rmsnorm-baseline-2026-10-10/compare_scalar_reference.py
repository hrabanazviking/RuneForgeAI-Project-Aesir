"""Compare the captured Mojo RMSNorm values with independent NumPy F32 math."""

import json
from pathlib import Path

import numpy as np


WIDTHS = (3, 15, 16, 17, 33)
EPSILON = np.float32(1e-5)
CAPTURE = Path(__file__).with_name("raw-output.txt")


def scalar_reference(inputs: np.ndarray, weights: np.ndarray) -> np.ndarray:
    rows, width = inputs.shape
    if rows != 2 or weights.shape != (width,):
        raise ValueError("captured RMSNorm input shapes do not match the probe")
    expected = np.empty_like(inputs)
    for row in range(rows):
        total = np.float32(0.0)
        for value in inputs[row]:
            x = np.float32(value)
            total = np.float32(total + np.float32(x * x))
        mean = np.float32(total / np.float32(width))
        denominator = np.float32(mean + EPSILON)
        inverse = np.float32(np.float32(1.0) / np.sqrt(denominator, dtype=np.float32))
        for col in range(width):
            normalized = np.float32(np.float32(inputs[row, col]) * inverse)
            product = np.float32(normalized * np.float32(weights[col]))
            expected[row, col] = np.float16(product)
    return expected


def parse_capture() -> dict[int, tuple[np.ndarray, np.ndarray, np.ndarray]]:
    lines = CAPTURE.read_text(encoding="utf-8").splitlines()
    actual: dict[int, tuple[np.ndarray, np.ndarray, np.ndarray]] = {}
    index = 0
    while index < len(lines):
        if not lines[index].startswith("WIDTH "):
            raise ValueError(f"unexpected capture line: {lines[index]!r}")
        width = int(lines[index].split()[1])
        rows = 2
        index += 1
        blocks = []
        for expected_label, count in (("WEIGHTS", width), ("INPUT", rows * width)):
            if lines[index] != expected_label:
                raise ValueError(f"expected {expected_label}, got {lines[index]!r}")
            index += 1
            blocks.append(
                np.asarray(
                    [np.float16(lines[index + offset]) for offset in range(count)],
                    dtype=np.float16,
                )
            )
            index += count
        if lines[index] != "OUTPUT":
            raise ValueError(f"expected OUTPUT, got {lines[index]!r}")
        index += 1
        outputs = np.asarray(
            [np.float32(lines[index + offset]) for offset in range(rows * width)],
            dtype=np.float32,
        )
        actual[width] = (
            blocks[1].reshape(rows, width),
            blocks[0],
            outputs.reshape(rows, width).astype(np.float16),
        )
        index += rows * width
    return actual


def main() -> None:
    actual_by_width = parse_capture()
    if tuple(actual_by_width) != WIDTHS:
        raise ValueError(f"unexpected widths in capture: {tuple(actual_by_width)}")
    reports = []
    for width in WIDTHS:
        inputs, weights, actual = actual_by_width[width]
        expected = scalar_reference(inputs, weights)
        difference = np.abs(actual.astype(np.float32) - expected.astype(np.float32))
        reports.append(
            {
                "width": width,
                "elements": int(actual.size),
                "mismatched_f16_values": int(np.count_nonzero(actual != expected)),
                "max_abs_error": float(difference.max(initial=np.float32(0))),
                "outputs": actual.astype(np.float32).ravel().tolist(),
            }
        )
    print(json.dumps(reports, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
