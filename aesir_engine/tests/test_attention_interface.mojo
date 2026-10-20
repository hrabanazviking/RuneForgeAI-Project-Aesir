"""Admission and mutation-free rejection checks for flash_attention_2."""

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16
from core.compute import flash_attention_2


def expect_rejected(
    Q: RuneTensor[f16],
    K: RuneTensor[f16],
    V: RuneTensor[f16],
    mut Out: RuneTensor[f16],
    seq_len: Int,
    head_dim: Int,
    expected: String,
) raises:
    var before = List[Scalar[f16]]()
    for index in range(Out.size):
        before.append(Out.data.unsafe_load(index))
    var rejected = False
    try:
        flash_attention_2(Q, K, V, Out, seq_len, head_dim)
    except error:
        rejected = True
        if expected not in String(error):
            raise Error("Attention rejected a shape for an unexpected reason")
    if not rejected:
        raise Error("Attention admitted an invalid shape")
    for index in range(Out.size):
        if Out.data.unsafe_load(index) != before[index]:
            raise Error("Rejected attention call mutated output")


def test_attention_interface() raises:
    var well = MimirWell(8192)
    var Q = RuneTensor[f16](3, 4, well.allocate(12))
    var K = RuneTensor[f16](3, 4, well.allocate(12))
    var V = RuneTensor[f16](3, 4, well.allocate(12))
    var Out = RuneTensor[f16](3, 4, well.allocate(12))
    for index in range(12):
        Q.data.unsafe_store(index, Scalar[f16](0.25))
        K.data.unsafe_store(index, Scalar[f16](0.5))
        V.data.unsafe_store(index, Scalar[f16](Float32(index + 1)))
        Out.data.unsafe_store(index, Scalar[f16](99.0))

    flash_attention_2(Q, K, V, Out, 3, 2)
    if Out.data.unsafe_load(0) == Scalar[f16](99.0):
        raise Error("Accepted attention call did not write output")

    expect_rejected(Q, K, V, Out, 0, 2, "must be positive")
    expect_rejected(Q, K, V, Out, 3, 0, "must be positive")
    var bad_q = RuneTensor[f16](3, 3, well.allocate(9))
    var bad_k = RuneTensor[f16](3, 3, well.allocate(9))
    var bad_v = RuneTensor[f16](3, 3, well.allocate(9))
    var bad_out = RuneTensor[f16](3, 3, well.allocate(9))
    for index in range(9):
        bad_out.data.unsafe_store(index, Scalar[f16](77.0))
    expect_rejected(bad_q, bad_k, bad_v, bad_out, 3, 2, "positive multiple")

    var narrow = RuneTensor[f16](3, 2, well.allocate(6))
    expect_rejected(Q, narrow, V, Out, 3, 2, "column dimension mismatch")
    expect_rejected(Q, K, narrow, Out, 3, 2, "column dimension mismatch")
    expect_rejected(Q, K, V, narrow, 3, 2, "column dimension mismatch")
    var short_rows = RuneTensor[f16](2, 4, well.allocate(8))
    expect_rejected(short_rows, K, V, Out, 3, 2, "row dimension smaller")
    expect_rejected(Q, short_rows, V, Out, 3, 2, "row dimension smaller")
    expect_rejected(Q, K, short_rows, Out, 3, 2, "row dimension smaller")
    var short_out = RuneTensor[f16](2, 4, well.allocate(8))
    for index in range(short_out.size):
        short_out.data.unsafe_store(index, Scalar[f16](55.0))
    expect_rejected(Q, K, V, short_out, 3, 2, "row dimension smaller")
    print("PASS: attention interface admission and mutation-free rejection")


def main() raises:
    test_attention_interface()
