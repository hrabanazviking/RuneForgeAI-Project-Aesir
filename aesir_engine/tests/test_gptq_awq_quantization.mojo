"""External quantization formats must fail closed until their real layouts exist."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16
from core.external_quantization import (
    GPTQ4BitMatrix,
    dequantize_gptq_4bit_matrix,
    gemm_gptq_4bit_matrix,
)


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


def test_gptq_4bit_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var qweight = well.allocate(16).unsafe_bitcast[UInt32]()
    var qzeros = well.allocate(4).unsafe_bitcast[UInt32]()
    var scales = well.allocate(16).unsafe_bitcast[Float16]()
    var dequantized = well.allocate(64).unsafe_bitcast[Float16]()
    var input = well.allocate(16).unsafe_bitcast[Float16]()
    var output = well.allocate(16).unsafe_bitcast[Float16]()
    var g_idx = well.allocate(16).unsafe_bitcast[Int32]()

    # Every output channel uses q=[1..8] over the eight input channels.
    for output_index in range(8):
        qweight.unsafe_store(output_index, UInt32(0x87654321))
    # Stored GPTQ zeros are real_zero - 1: groups use zero 2 and zero 4.
    qzeros.unsafe_store(0, UInt32(0x11111111))
    qzeros.unsafe_store(1, UInt32(0x33333333))
    for output_index in range(8):
        scales.unsafe_store(output_index, Float16(0.5))
        scales.unsafe_store(8 + output_index, Float16(0.25))

    var matrix = GPTQ4BitMatrix(qweight, 8, qzeros, 2, scales, 16, 8, 8, 4)
    dequantize_gptq_4bit_matrix(matrix, dequantized, 64)
    var expected = [
        Float16(-0.5), Float16(0.0), Float16(0.5), Float16(1.0),
        Float16(0.25), Float16(0.5), Float16(0.75), Float16(1.0),
    ]
    for output_index in range(8):
        for input_index in range(8):
            if dequantized.unsafe_load(output_index * 8 + input_index) != expected[input_index]:
                raise Error("GPTQ 4-bit dequantization disagrees with hand-computed weights")

    for input_index in range(8):
        input.unsafe_store(input_index, Float16(1.0))
        input.unsafe_store(8 + input_index, Float16(input_index + 1))
    gemm_gptq_4bit_matrix(input, 16, 2, matrix, output, 16)
    for output_index in range(8):
        if output.unsafe_load(output_index) != Float16(3.5):
            raise Error("GPTQ 4-bit GEMM first row mismatch")
        if output.unsafe_load(8 + output_index) != Float16(22.5):
            raise Error("GPTQ 4-bit GEMM second row mismatch")

    # Activation-order models select groups through g_idx rather than K order.
    for input_index in range(8):
        g_idx.unsafe_store(input_index, Int32(1 if input_index < 4 else 0))
    var act_order_matrix = GPTQ4BitMatrix(
        qweight, 8, qzeros, 2, scales, 16, 8, 8, 4, g_idx, 8, True
    )
    dequantize_gptq_4bit_matrix(act_order_matrix, dequantized, 64)
    var act_order_expected = [
        Float16(-0.75), Float16(-0.5), Float16(-0.25), Float16(0.0),
        Float16(1.5), Float16(2.0), Float16(2.5), Float16(3.0),
    ]
    for input_index in range(8):
        if dequantized.unsafe_load(input_index) != act_order_expected[input_index]:
            raise Error("GPTQ 4-bit activation-order group selection mismatch")

    # Reject mismatched backing storage before touching caller output.
    for i in range(64):
        dequantized.unsafe_store(i, Float16(99.0))
    var rejected = False
    try:
        dequantize_gptq_4bit_matrix(act_order_matrix, dequantized, 63)
    except:
        rejected = True
    if not rejected:
        raise Error("GPTQ 4-bit accepted a short output allocation")
    for i in range(64):
        if dequantized.unsafe_load(i) != Float16(99.0):
            raise Error("GPTQ 4-bit short-output rejection mutated output")

    # Reject all bad group metadata before touching caller output.
    g_idx.unsafe_store(7, Int32(2))
    rejected = False
    try:
        dequantize_gptq_4bit_matrix(act_order_matrix, dequantized, 64)
    except:
        rejected = True
    if not rejected:
        raise Error("GPTQ 4-bit accepted out-of-range g_idx metadata")
    for i in range(64):
        if dequantized.unsafe_load(i) != Float16(99.0):
            raise Error("GPTQ 4-bit invalid-metadata rejection mutated output")
    print("GPTQ_4BIT canonical AutoGPTQ dequantization and GEMM: PASS")


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
