"""External quantization formats must fail closed until their real layouts exist."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16


def assert_external_format_rejected(format: CompressedFormatType, label: String) raises:
    var well = MimirWell(1024 * 1024)
    var rows = 2
    var columns = 32
    var outputs = 2
    var input_ptr = well.allocate(rows * columns)
    var weight_ptr = well.allocate(outputs * columns)
    var output_ptr = well.allocate(rows * outputs)
    var input = RuneTensor[f16](rows, columns, input_ptr, False)
    var weights = RuneTensor[f16](outputs, columns, weight_ptr, True, format)
    var output = RuneTensor[f16](rows, outputs, output_ptr, False)

    for i in range(rows * columns):
        input.data.unsafe_store(i, Scalar[f16](i + 1))
    for i in range(outputs * columns):
        weights.data.unsafe_store(i, Scalar[f16](i + 1))
    for i in range(rows * outputs):
        output.data.unsafe_store(i, Scalar[f16](321.0))

    var rejected = False
    try:
        gemm_f16(input, weights, output)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error(label + " was accepted without its required format metadata")
    for i in range(rows * outputs):
        if output.data.unsafe_load(i) != Scalar[f16](321.0):
            raise Error(label + " rejection mutated the output buffer")
    print(label, "explicit mutation-free rejection: PASS")


def test_gptq_4bit_boundary() raises:
    assert_external_format_rejected(CompressedFormatType(CompressedFormatType.GPTQ_4BIT), "GPTQ_4BIT")


def test_gptq_8bit_boundary() raises:
    assert_external_format_rejected(CompressedFormatType(CompressedFormatType.GPTQ_8BIT), "GPTQ_8BIT")


def test_awq_4bit_boundary() raises:
    assert_external_format_rejected(CompressedFormatType(CompressedFormatType.AWQ_4BIT), "AWQ_4BIT")


def test_exl2_boundary() raises:
    assert_external_format_rejected(CompressedFormatType(CompressedFormatType.EXL2_VARBIT), "EXL2_VARBIT")


def test_hqq_boundary() raises:
    assert_external_format_rejected(CompressedFormatType(CompressedFormatType.HQQ), "HQQ")


def test_smoothquant_int8_boundary() raises:
    assert_external_format_rejected(CompressedFormatType(CompressedFormatType.SMOOTHQUANT_INT8), "SMOOTHQUANT_INT8")
