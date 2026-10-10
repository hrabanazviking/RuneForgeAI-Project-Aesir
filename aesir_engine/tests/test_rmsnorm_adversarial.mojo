"""Adversarial finite-range and IEEE propagation checks for CPU RMSNorm."""

from std.math import isinf, isnan, sqrt

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16, f32
from core.compute import rmsnorm


def test_rmsnorm_adversarial() raises:
    var well = MimirWell(1024 * 1024)
    var values = RuneTensor[f16](2, 3, well.allocate(6))
    var weights = RuneTensor[f16](1, 3, well.allocate(3))
    var tiny = Float32(5.960464477539063e-8)
    var large = Float32(65504.0)
    for col in range(3):
        values.data.unsafe_store(col, Scalar[f16](tiny))
        values.data.unsafe_store(3 + col, Scalar[f16](large))
        weights.data.unsafe_store(col, Scalar[f16](1.0))
    if values.data.unsafe_load(0) == Scalar[f16](0.0):
        raise Error("F16 minimum subnormal was not represented by the fixture")
    if values.data.unsafe_load(3).cast[f32]() != Float32(65504.0):
        raise Error("F16 maximum finite value was not represented by the fixture")

    var expected = List[Scalar[f16]]()
    for row in range(2):
        var sum_squares: Scalar[f32] = 0.0
        for col in range(3):
            var value = values.data.unsafe_load(row * 3 + col).cast[f32]()
            sum_squares += value * value
        var inverse = 1.0 / sqrt(sum_squares / 3.0 + 1e-5)
        for col in range(3):
            var value = values.data.unsafe_load(row * 3 + col).cast[f32]()
            expected.append(Scalar[f16](value * inverse))
    rmsnorm(values, weights, Scalar[f32](1e-5))
    for index in range(6):
        if values.data.unsafe_load(index) != expected[index]:
            raise Error("RMSNorm extreme finite value differs from scalar F32 reference")
        if isnan(values.data.unsafe_load(index).cast[f32]()) or isinf(
            values.data.unsafe_load(index).cast[f32]()
        ):
            raise Error("RMSNorm finite extreme produced a non-finite output")

    # Tensor and weight exceptional values are admitted. NaN in one input row
    # propagates through that row's reduction; an independent finite row stays
    # finite. This is current IEEE arithmetic behavior, not sanitization.
    var nonfinite_input = RuneTensor[f16](2, 3, well.allocate(6))
    for index in range(6):
        nonfinite_input.data.unsafe_store(index, Scalar[f16](Float32(index + 1)))
    nonfinite_input.data.unsafe_store(1, Scalar[f16](Float32(0.0) / Float32(0.0)))
    rmsnorm(nonfinite_input, weights, Scalar[f32](1e-5))
    for col in range(3):
        if not isnan(nonfinite_input.data.unsafe_load(col).cast[f32]()):
            raise Error("RMSNorm input NaN did not propagate within its row")
    for col in range(3):
        var value = nonfinite_input.data.unsafe_load(3 + col).cast[f32]()
        if isnan(value) or isinf(value):
            raise Error("RMSNorm input NaN contaminated a finite peer row")

    var infinite_input = RuneTensor[f16](2, 3, well.allocate(6))
    infinite_input.data.unsafe_store(0, Scalar[f16](Float32(1.0) / Float32(0.0)))
    infinite_input.data.unsafe_store(1, Scalar[f16](1.0))
    infinite_input.data.unsafe_store(2, Scalar[f16](2.0))
    infinite_input.data.unsafe_store(3, Scalar[f16](Float32(-1.0) / Float32(0.0)))
    infinite_input.data.unsafe_store(4, Scalar[f16](1.0))
    infinite_input.data.unsafe_store(5, Scalar[f16](2.0))
    rmsnorm(infinite_input, weights, Scalar[f32](1e-5))
    for row in range(2):
        if not isnan(infinite_input.data.unsafe_load(row * 3).cast[f32]()):
            raise Error("RMSNorm infinite input must follow Inf multiplied by zero")
        for col in range(1, 3):
            if infinite_input.data.unsafe_load(row * 3 + col) != Scalar[f16](0.0):
                raise Error("RMSNorm finite input beside infinity must normalize to zero")

    # Non-finite weights affect only the corresponding output column and are
    # likewise allowed to propagate through the final F16 cast.
    var weighted = RuneTensor[f16](2, 3, well.allocate(6))
    for index in range(6):
        weighted.data.unsafe_store(index, Scalar[f16](Float32(index + 1)))
    var exceptional_weights = RuneTensor[f16](1, 3, well.allocate(3))
    exceptional_weights.data.unsafe_store(0, Scalar[f16](1.0))
    exceptional_weights.data.unsafe_store(1, Scalar[f16](Float32(1.0) / Float32(0.0)))
    exceptional_weights.data.unsafe_store(2, Scalar[f16](Float32(-1.0) / Float32(0.0)))
    rmsnorm(weighted, exceptional_weights, Scalar[f32](1e-5))
    for row in range(2):
        var exceptional = weighted.data.unsafe_load(row * 3 + 1).cast[f32]()
        if not isinf(exceptional) or exceptional <= 0.0:
            raise Error("RMSNorm infinite weight did not produce an infinite output")
        var negative_exceptional = weighted.data.unsafe_load(row * 3 + 2).cast[f32]()
        if not isinf(negative_exceptional) or negative_exceptional >= 0.0:
            raise Error("RMSNorm negative infinite weight lost its sign")
        for col in range(3):
            if col == 0:
                var value = weighted.data.unsafe_load(row * 3 + col).cast[f32]()
                if isnan(value) or isinf(value):
                    raise Error("RMSNorm infinite weight contaminated another column")

    for index in range(6):
        weighted.data.unsafe_store(index, Scalar[f16](Float32(index + 1)))
    exceptional_weights.data.unsafe_store(1, Scalar[f16](Float32(0.0) / Float32(0.0)))
    exceptional_weights.data.unsafe_store(2, Scalar[f16](1.0))
    rmsnorm(weighted, exceptional_weights, Scalar[f32](1e-5))
    for row in range(2):
        if not isnan(weighted.data.unsafe_load(row * 3 + 1).cast[f32]()):
            raise Error("RMSNorm NaN weight did not propagate at its output column")
        for col in range(3):
            if col != 1:
                var value = weighted.data.unsafe_load(row * 3 + col).cast[f32]()
                if isnan(value) or isinf(value):
                    raise Error("RMSNorm NaN weight contaminated another column")

    print("PASS: RMSNorm finite extremes and IEEE exceptional-value behavior")


def main() raises:
    test_rmsnorm_adversarial()
