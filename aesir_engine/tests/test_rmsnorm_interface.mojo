"""Accepted/rejected input contract checks for the CPU RMSNorm boundary."""

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16, f32
from core.compute import rmsnorm


def expect_rejected_without_mutation(
    mut T: RuneTensor[f16],
    weight: RuneTensor[f16],
    epsilon: Scalar[f32],
    expected_error: String,
) raises:
    var before = List[Scalar[f16]]()
    for index in range(T.size):
        before.append(T.data.unsafe_load(index))
    var rejected = False
    try:
        rmsnorm(T, weight, epsilon)
    except error:
        rejected = True
        if expected_error not in String(error):
            raise Error("RMSNorm rejected an input for an unexpected reason")
    if not rejected:
        raise Error("RMSNorm admitted an invalid interface input")
    for index in range(T.size):
        if T.data.unsafe_load(index) != before[index]:
            raise Error("Rejected RMSNorm call mutated tensor input")


def expect_dimension_rejection_without_mutation(
    mut T: RuneTensor[f16],
    weight: RuneTensor[f16],
    expected_error: String,
) raises:
    # Invalid descriptors have no positive logical span. Check the explicitly
    # allocated sentinel behind their raw pointer to detect any premature write.
    var sentinel = Scalar[f16](321.0)
    T.data.unsafe_store(0, sentinel)
    var rejected = False
    try:
        rmsnorm(T, weight, Scalar[f32](1e-5))
    except error:
        rejected = True
        if expected_error not in String(error):
            raise Error("RMSNorm rejected an invalid dimension unexpectedly")
    if not rejected:
        raise Error("RMSNorm admitted an invalid tensor dimension")
    if T.data.unsafe_load(0) != sentinel:
        raise Error("Dimension rejection mutated the allocated sentinel")


def test_rmsnorm_interface() raises:
    var well = MimirWell(4096)

    # A positive multirow tensor accepts an overlong, non-vector-shaped weight
    # descriptor; this case asserts admission only.
    var accepted = RuneTensor[f16](2, 3, well.allocate(6))
    for index in range(accepted.size):
        accepted.data.unsafe_store(index, Scalar[f16](Float32(index + 1)))
    var flat_weight = RuneTensor[f16](2, 2, well.allocate(4))
    for index in range(flat_weight.size):
        flat_weight.data.unsafe_store(index, Scalar[f16](1.0))
    rmsnorm(accepted, flat_weight, Scalar[f32](1e-5))

    # Invalid dimension, short-weight, and nonpositive-epsilon inputs reject
    # before writing any tensor element.
    var base = RuneTensor[f16](1, 3, well.allocate(3))
    for index in range(base.size):
        base.data.unsafe_store(index, Scalar[f16](Float32(index + 1)))

    var short_weight = RuneTensor[f16](1, 2, well.allocate(2))
    for index in range(short_weight.size):
        short_weight.data.unsafe_store(index, Scalar[f16](1.0))
    expect_rejected_without_mutation(
        base,
        short_weight,
        Scalar[f32](1e-5),
        "rmsnorm: weight dimension mismatch",
    )

    var valid_weight = RuneTensor[f16](1, 3, well.allocate(3))
    for index in range(valid_weight.size):
        valid_weight.data.unsafe_store(index, Scalar[f16](1.0))
    expect_rejected_without_mutation(
        base,
        valid_weight,
        Scalar[f32](0.0),
        "rmsnorm: epsilon must be positive",
    )
    expect_rejected_without_mutation(
        base,
        valid_weight,
        Scalar[f32](-1.0),
        "rmsnorm: epsilon must be positive",
    )


    var zero_rows = RuneTensor[f16](0, 3, well.allocate(1))
    expect_dimension_rejection_without_mutation(
        zero_rows, valid_weight, "rmsnorm: tensor dimensions must be positive"
    )
    var zero_cols = RuneTensor[f16](1, 0, well.allocate(1))
    expect_dimension_rejection_without_mutation(
        zero_cols, valid_weight, "rmsnorm: tensor dimensions must be positive"
    )
    var negative_rows = RuneTensor[f16](-1, 3, well.allocate(1))
    expect_dimension_rejection_without_mutation(
        negative_rows, valid_weight, "rmsnorm: tensor dimensions must be positive"
    )
    var negative_cols = RuneTensor[f16](1, -1, well.allocate(1))
    expect_dimension_rejection_without_mutation(
        negative_cols, valid_weight, "rmsnorm: tensor dimensions must be positive"
    )
    print("PASS: RMSNorm interface admission and mutation-free rejection")


def main() raises:
    test_rmsnorm_interface()
