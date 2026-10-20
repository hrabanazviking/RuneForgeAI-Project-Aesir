"""Scalar F32 causal-prefix reference and future-value isolation checks."""

from std.math import exp, sqrt

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16, f32
from core.compute import flash_attention_2


def fill_inputs(
    mut Q: RuneTensor[f16],
    mut K: RuneTensor[f16],
    mut V: RuneTensor[f16],
    future_delta: Scalar[f32],
) raises:
    for row in range(3):
        for col in range(3):
            Q.data.unsafe_store(row * 3 + col, Scalar[f16](Float32((row + 1) * (col - 1)) / 4.0))
            K.data.unsafe_store(row * 3 + col, Scalar[f16](Float32((row - col + 1)) / 3.0))
            var value = Float32((row + 1) * (col + 2)) / 2.0
            if row == 2:
                value += future_delta
            V.data.unsafe_store(row * 3 + col, Scalar[f16](value))


def check_outputs(future_delta: Scalar[f32]) raises:
    var rows = 3
    var cols = 3
    var d = 3
    var well = MimirWell(4096)
    var Q = RuneTensor[f16](rows, cols, well.allocate(rows * cols))
    var K = RuneTensor[f16](rows, cols, well.allocate(rows * cols))
    var V = RuneTensor[f16](rows, cols, well.allocate(rows * cols))
    var Out = RuneTensor[f16](rows, cols, well.allocate(rows * cols))
    fill_inputs(Q, K, V, future_delta)

    var expected = List[Scalar[f16]]()
    var scale = 1.0 / sqrt(Float32(d))
    for i in range(rows):
        var scores = List[Scalar[f32]]()
        var top: Scalar[f32] = -1e20
        for j in range(i + 1):
            var score: Scalar[f32] = 0.0
            for x in range(d):
                score += Q.data.unsafe_load(i * cols + x).cast[f32]() * K.data.unsafe_load(j * cols + x).cast[f32]()
            score *= scale
            scores.append(score)
            if score > top:
                top = score
        var denominator: Scalar[f32] = 0.0
        for j in range(i + 1):
            denominator += exp(scores[j] - top)
        for x in range(d):
            var result: Scalar[f32] = 0.0
            for j in range(i + 1):
                var probability = exp(scores[j] - top) / denominator
                result += probability * V.data.unsafe_load(j * cols + x).cast[f32]()
            expected.append(Scalar[f16](result))

    flash_attention_2(Q, K, V, Out, rows, d)
    for index in range(rows * cols):
        var actual = Out.data.unsafe_load(index).cast[f32]()
        var reference = expected[index].cast[f32]()
        var error = actual - reference
        if error < 0.0:
            error = -error
        if error > 0.05:
            raise Error("Causal attention exceeds scalar F32 reference tolerance")
    if Out.data.unsafe_load(0) != V.data.unsafe_load(0):
        raise Error("Single-row causal prefix must equal its only allowed value")


def test_attention_reference() raises:
    check_outputs(0.0)
    check_outputs(100.0)
    print("PASS: causal attention scalar reference and future-value isolation")


def main() raises:
    test_attention_reference()
