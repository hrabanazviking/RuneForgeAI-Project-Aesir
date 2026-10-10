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


def main() raises:
    test_rune_tensor_layout()
    print("PASS: RuneTensor 3x4 contiguous row-major indexing baseline")
