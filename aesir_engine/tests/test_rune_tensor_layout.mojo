"""Baseline for the existing contiguous 2D RuneTensor logical layout."""

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16


def test_rune_tensor_layout() raises:
    var well = MimirWell(4096)
    var tensor = RuneTensor[f16].checked(3, 4, well.allocate(12))
    if tensor.rows != 3 or tensor.cols != 4 or tensor.size != 12:
        raise Error("RuneTensor 2D descriptor geometry changed")

    for row in range(3):
        for col in range(4):
            tensor.set(row, col, Scalar[f16](Float32(row * 10 + col)))

    for row in range(3):
        for col in range(4):
            var actual = Float32(tensor.get_checked(row, col))
            var expected = Float32(row * 10 + col)
            if actual != expected:
                raise Error("RuneTensor row-major logical indexing changed")

    var negative_rejected = False
    try:
        _ = tensor.get_checked(-1, 0)
    except:
        negative_rejected = True
    if not negative_rejected:
        raise Error("RuneTensor checked indexing admitted a negative row")

    var endpoint_rejected = False
    try:
        _ = tensor.get_checked(0, 4)
    except:
        endpoint_rejected = True
    if not endpoint_rejected:
        raise Error("RuneTensor checked indexing admitted an endpoint column")

    for invalid_row in [3, Int(1) << 62, (Int(1) << 63) - 1]:
        var rejected = False
        try:
            _ = tensor.get_checked(invalid_row, 0)
        except:
            rejected = True
        if not rejected:
            raise Error("RuneTensor admitted an extreme out-of-range row")

    var before = Float32(tensor.get_checked(1, 2))
    var invalid_store_rejected = False
    try:
        tensor.set_checked(-1, 2, Scalar[f16](999.0))
    except:
        invalid_store_rejected = True
    if not invalid_store_rejected:
        raise Error("RuneTensor set_checked admitted a negative row")
    if Float32(tensor.get_checked(1, 2)) != before:
        raise Error("Rejected RuneTensor write mutated an in-range element")


def main() raises:
    test_rune_tensor_layout()
    print("PASS: RuneTensor 3x4 contiguous row-major indexing baseline")
