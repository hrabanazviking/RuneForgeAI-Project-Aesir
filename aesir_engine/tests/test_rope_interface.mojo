"""Accepted/rejected input contract checks for CPU apply_rope."""

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16
from core.compute import apply_rope


def expect_rejected_without_mutation(
    mut Q: RuneTensor[f16],
    mut K: RuneTensor[f16],
    start_pos: Int,
    head_dim: Int,
    expected_error: String,
) raises:
    var q_before = List[Scalar[f16]]()
    var k_before = List[Scalar[f16]]()
    for index in range(Q.size):
        q_before.append(Q.data.unsafe_load(index))
    for index in range(K.size):
        k_before.append(K.data.unsafe_load(index))
    var rejected = False
    try:
        apply_rope(Q, K, start_pos, head_dim)
    except error:
        rejected = True
        if expected_error not in String(error):
            raise Error("RoPE rejected an input for an unexpected reason")
    if not rejected:
        raise Error("RoPE admitted an invalid interface input")
    for index in range(Q.size):
        if Q.data.unsafe_load(index) != q_before[index]:
            raise Error("Rejected RoPE call mutated Q")
    for index in range(K.size):
        if K.data.unsafe_load(index) != k_before[index]:
            raise Error("Rejected RoPE call mutated K")


def test_rope_interface() raises:
    var well = MimirWell(4096)
    var Q = RuneTensor[f16](2, 8, well.allocate(16))
    var K = RuneTensor[f16](3, 4, well.allocate(12))
    for index in range(Q.size):
        Q.data.unsafe_store(index, Scalar[f16](Float32(index + 1) / 4.0))
    for index in range(K.size):
        K.data.unsafe_store(index, Scalar[f16](Float32(index + 1) / 3.0))

    # Distinct head counts are admitted and both tensors are transformed.
    apply_rope(Q, K, 3, 4)
    if Q.data.unsafe_load(0) == Scalar[f16](0.25):
        raise Error("Accepted RoPE call did not transform Q")
    if K.data.unsafe_load(0) == Scalar[f16](1.0 / 3.0):
        raise Error("Accepted RoPE call did not transform K")
    if K.data.unsafe_load(8) == Scalar[f16](9.0 / 3.0):
        raise Error("RoPE did not transform K rows beyond Q.rows")

    # Every admission failure is checked before either tensor is mutated.
    var q2 = RuneTensor[f16](2, 8, well.allocate(16))
    var k2 = RuneTensor[f16](2, 4, well.allocate(8))
    for index in range(q2.size):
        q2.data.unsafe_store(index, Scalar[f16](Float32(index + 1)))
    for index in range(k2.size):
        k2.data.unsafe_store(index, Scalar[f16](Float32(index + 11)))

    expect_rejected_without_mutation(q2, k2, -1, 4, "start_pos cannot be negative")
    expect_rejected_without_mutation(q2, k2, 0, 0, "head_dim must be positive and even")
    expect_rejected_without_mutation(q2, k2, 0, 3, "head_dim must be positive and even")
    var bad_q = RuneTensor[f16](2, 7, well.allocate(14))
    expect_rejected_without_mutation(bad_q, k2, 0, 4, "columns must be a multiple")
    var bad_k = RuneTensor[f16](2, 6, well.allocate(12))
    expect_rejected_without_mutation(q2, bad_k, 0, 4, "columns must be a multiple")
    var empty_q = RuneTensor[f16](0, 8, well.allocate(1))
    expect_rejected_without_mutation(empty_q, k2, 0, 4, "dimensions must be positive")
    # Current source accepts zero columns because divisibility succeeds and
    # only row counts are checked. Pin the observation for a later policy slice.
    var empty_k = RuneTensor[f16](2, 0, well.allocate(1))
    expect_rejected_without_mutation(q2, empty_k, 0, 4, "dimensions must be positive")

    print("PASS: RoPE interface admission and mutation-free rejection")


def main() raises:
    test_rope_interface()
