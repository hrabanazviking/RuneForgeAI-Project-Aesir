"""Unimplemented extreme quantization layouts must fail without mutation."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16


def assert_extreme_format_rejected(format: CompressedFormatType, label: String) raises:
    var well = MimirWell(1024 * 1024)
    var rows = 2
    var columns = 256
    var outputs = 2
    var input = RuneTensor[f16](rows, columns, well.allocate(rows * columns), False)
    var weights = RuneTensor[f16](outputs, columns, well.allocate(outputs * columns), True, format)
    var output = RuneTensor[f16](rows, outputs, well.allocate(rows * outputs), False)
    for i in range(rows * columns):
        input.data.unsafe_store(i, Scalar[f16](i + 1))
    for i in range(outputs * columns):
        weights.data.unsafe_store(i, Scalar[f16](i + 1))
    for i in range(rows * outputs):
        output.data.unsafe_store(i, Scalar[f16](197.0))

    var rejected = False
    try:
        gemm_f16(input, weights, output)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error(label + " was accepted without its authoritative layout")
    for i in range(rows * outputs):
        if output.data.unsafe_load(i) != Scalar[f16](197.0):
            raise Error(label + " rejection mutated output")
    print(label, "explicit mutation-free rejection: PASS")


def test_iq1_s_boundary() raises:
    assert_extreme_format_rejected(CompressedFormatType(CompressedFormatType.IQ1_S), "IQ1_S")


def test_iq2_xxs_boundary() raises:
    assert_extreme_format_rejected(CompressedFormatType(CompressedFormatType.IQ2_XXS), "IQ2_XXS")


def test_ternary_boundary() raises:
    assert_extreme_format_rejected(CompressedFormatType(CompressedFormatType.TERNARY_155BIT), "TERNARY_155BIT")
