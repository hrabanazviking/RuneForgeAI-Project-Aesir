"""Causal tile-boundary and future-value adversarial checks."""

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16, f32
from core.compute import flash_attention_2


def test_attention_adversarial() raises:
    var rows = 33
    var well = MimirWell(8192)
    var Q = RuneTensor[f16](rows, 1, well.allocate(rows))
    var K = RuneTensor[f16](rows, 1, well.allocate(rows))
    var V = RuneTensor[f16](rows, 1, well.allocate(rows))
    var Out = RuneTensor[f16](rows, 1, well.allocate(rows))
    for row in range(rows):
        Q.data.unsafe_store(row, Scalar[f16](0.0))
        K.data.unsafe_store(row, Scalar[f16](0.0))
        V.data.unsafe_store(row, Scalar[f16](2.0))
    V.data.unsafe_store(32, Scalar[f16](1024.0))

    flash_attention_2(Q, K, V, Out, rows, 1)
    if Out.data.unsafe_load(0) != Scalar[f16](2.0):
        raise Error("Future tile value contaminated the first causal output")
    if Out.data.unsafe_load(31) != Scalar[f16](2.0):
        raise Error("Position 32 leaked across the 32-key tile boundary")
    var last = Out.data.unsafe_load(32).cast[f32]()
    var expected = Float32(1088.0) / 33.0
    var error = last - expected
    if error < 0.0:
        error = -error
    if error > 0.1:
        raise Error("Last-row prefix did not include the boundary value correctly")
    print("PASS: causal attention excludes future tile values and admits boundary row")


def main() raises:
    test_attention_adversarial()
