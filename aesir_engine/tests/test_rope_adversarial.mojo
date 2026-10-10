"""Adversarial current behavior for apply_rope theta domain."""

from std.math import isnan

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16, f32
from core.compute import apply_rope


def has_nan(T: RuneTensor[f16]) -> Bool:
    for index in range(T.size):
        if isnan(T.data.unsafe_load(index).cast[f32]()):
            return True
    return False


def check_invalid_theta(theta: Scalar[f32]) raises:
    var well = MimirWell(1024)
    var Q = RuneTensor[f16](1, 4, well.allocate(4))
    var K = RuneTensor[f16](1, 4, well.allocate(4))
    for index in range(4):
        Q.data.unsafe_store(index, Scalar[f16](Float32(index + 1)))
        K.data.unsafe_store(index, Scalar[f16](Float32(index + 2)))
    var rejected = False
    try:
        apply_rope(Q, K, 2, 4, theta)
    except error:
        rejected = True
        if "theta must be finite and positive" not in String(error):
            raise Error("RoPE rejected an invalid theta for an unexpected reason")
    if not rejected:
        raise Error("RoPE admitted an invalid theta")
    for index in range(4):
        if Q.data.unsafe_load(index) != Scalar[f16](Float32(index + 1)):
            raise Error("Invalid theta rejection mutated Q")
        if K.data.unsafe_load(index) != Scalar[f16](Float32(index + 2)):
            raise Error("Invalid theta rejection mutated K")


def test_rope_adversarial() raises:
    check_invalid_theta(Scalar[f32](0.0))
    check_invalid_theta(Scalar[f32](-1.0))
    check_invalid_theta(Scalar[f32](0.0 / 0.0))
    check_invalid_theta(Scalar[f32](1.0 / 0.0))
    check_invalid_theta(Scalar[f32](-1.0 / 0.0))
    print("PASS: RoPE rejects invalid theta before mutating Q or K")


def main() raises:
    test_rope_adversarial()
