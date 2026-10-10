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
    # AES500-107 captures current behavior; domain admission policy is deferred.
    apply_rope(Q, K, 2, 4, theta)
    if not has_nan(Q) or not has_nan(K):
        raise Error("Invalid theta did not produce NaN in both Q and K")


def test_rope_adversarial() raises:
    check_invalid_theta(Scalar[f32](0.0))
    check_invalid_theta(Scalar[f32](-1.0))
    print("PASS: RoPE zero and negative theta currently propagate NaN into Q and K")


def main() raises:
    test_rope_adversarial()
