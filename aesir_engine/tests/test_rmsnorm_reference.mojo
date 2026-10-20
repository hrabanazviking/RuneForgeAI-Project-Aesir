"""Scalar F32 reference checks for CPU RMSNorm SIMD boundaries."""

from std.math import sqrt

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16, f32
from core.compute import rmsnorm


def check_width(cols: Int) raises:
    var rows = 2
    # Match the suite's standard bounded arena size; this keeps each tensor
    # and its weight in a stable arena class across SIMD widths.
    var well = MimirWell(1024 * 1024)
    var values = RuneTensor[f16](rows, cols, well.allocate(rows * cols))
    var weights = RuneTensor[f16](1, cols, well.allocate(cols))
    for index in range(rows * cols):
        var numerator = (index % 13) - 6
        values.data.unsafe_store(
            index, Scalar[f16](Float32(numerator) / 3.0)
        )
    for col in range(cols):
        var numerator = (col % 7) - 3
        weights.data.unsafe_store(
            col, Scalar[f16](Float32(numerator) / 5.0)
        )

    var expected = List[Scalar[f16]]()
    for row in range(rows):
        var sum_squares: Scalar[f32] = 0.0
        for col in range(cols):
            var value = values.data.unsafe_load(row * cols + col).cast[f32]()
            sum_squares += value * value
        var inverse = 1.0 / sqrt(sum_squares / Float32(cols) + 1e-5)
        for col in range(cols):
            var value = values.data.unsafe_load(row * cols + col).cast[f32]()
            var weight = weights.data.unsafe_load(col).cast[f32]()
            expected.append(Scalar[f16](value * inverse * weight))

    rmsnorm(values, weights, 1e-5)
    for index in range(rows * cols):
        if values.data.unsafe_load(index) != expected[index]:
            raise Error(
                "RMSNorm F16 output differs from scalar F32 reference at width "
                + String(cols)
                + " index "
                + String(index)
            )


def test_rmsnorm_reference() raises:
    check_width(3)
    check_width(15)
    check_width(16)
    check_width(17)
    check_width(33)
    print("PASS: RMSNorm scalar F32 reference across SIMD widths and tails")


def main() raises:
    test_rmsnorm_reference()
