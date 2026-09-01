"""External quantization formats must fail closed until their real layouts exist."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16
from core.external_quantization import (
    GPTQ4BitMatrix,
    GPTQ8BitMatrix,
    AWQ4BitMatrix,
    SmoothQuantW8A8Matrix,
    HQQ4BitAxis1Matrix,
    dequantize_gptq_4bit_matrix,
    dequantize_gptq_8bit_matrix,
    gemm_gptq_4bit_matrix,
    gemm_gptq_8bit_matrix,
    dequantize_awq_4bit_matrix,
    gemm_awq_4bit_matrix,
    dequantize_smoothquant_weights,
    gemm_smoothquant_w8a8,
    quantize_smoothquant_int8,
    dequantize_hqq_4bit_axis1,
    gemm_hqq_4bit_axis1,
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


def test_gptq_8bit_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var qweight = well.allocate(8).unsafe_bitcast[UInt32]()
    var qzeros = well.allocate(4).unsafe_bitcast[UInt32]()
    var scales = well.allocate(8).unsafe_bitcast[Float16]()
    var dequantized = well.allocate(16).unsafe_bitcast[Float16]()
    var input = well.allocate(8).unsafe_bitcast[Float16]()
    var output = well.allocate(8).unsafe_bitcast[Float16]()

    # Each output uses q=[10,20,30,40] across the four input channels.
    for output_index in range(4):
        qweight.unsafe_store(output_index, UInt32(0x281E140A))
    # Real zeros 12 and 25 are stored as 11 and 24.
    qzeros.unsafe_store(0, UInt32(0x0B0B0B0B))
    qzeros.unsafe_store(1, UInt32(0x18181818))
    for output_index in range(4):
        scales.unsafe_store(output_index, Float16(0.5))
        scales.unsafe_store(4 + output_index, Float16(0.25))

    var matrix = GPTQ8BitMatrix(qweight, 4, qzeros, 2, scales, 8, 4, 4, 2)
    dequantize_gptq_8bit_matrix(matrix, dequantized, 16)
    var expected = [
        Float16(-1.0), Float16(4.0), Float16(1.25), Float16(3.75)
    ]
    for output_index in range(4):
        for input_index in range(4):
            if dequantized.unsafe_load(output_index * 4 + input_index) != expected[input_index]:
                raise Error("GPTQ 8-bit dequantization disagrees with hand-computed weights")

    for input_index in range(4):
        input.unsafe_store(input_index, Float16(1.0))
        input.unsafe_store(4 + input_index, Float16(input_index + 1))
    gemm_gptq_8bit_matrix(input, 8, 2, matrix, output, 8)
    for output_index in range(4):
        if output.unsafe_load(output_index) != Float16(8.0):
            raise Error("GPTQ 8-bit GEMM first row mismatch")
        if output.unsafe_load(4 + output_index) != Float16(25.75):
            raise Error("GPTQ 8-bit GEMM second row mismatch")
    print("GPTQ_8BIT canonical AutoGPTQ dequantization and GEMM: PASS")


def test_awq_4bit_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var qweight = well.allocate(8).unsafe_bitcast[UInt32]()
    var qzeros = well.allocate(4).unsafe_bitcast[UInt32]()
    var scales = well.allocate(16).unsafe_bitcast[Float16]()
    var dequantized = well.allocate(32).unsafe_bitcast[Float16]()
    var input = well.allocate(8).unsafe_bitcast[Float16]()
    var output = well.allocate(16).unsafe_bitcast[Float16]()

    # Logical output values [1..8] packed in AutoAWQ order [0,2,4,6,1,3,5,7].
    for input_index in range(4):
        qweight.unsafe_store(input_index, UInt32(0x86427531))
    qzeros.unsafe_store(0, UInt32(0x11111111))
    qzeros.unsafe_store(1, UInt32(0x11111111))
    for output_index in range(8):
        scales.unsafe_store(output_index, Float16(0.5))
        scales.unsafe_store(8 + output_index, Float16(0.25))

    var matrix = AWQ4BitMatrix(qweight, 4, qzeros, 2, scales, 16, 4, 8, 2)
    dequantize_awq_4bit_matrix(matrix, dequantized, 32)
    for output_index in range(8):
        var delta = Float16(output_index)
        var expected_first = delta * Float16(0.5)
        var expected_second = delta * Float16(0.25)
        if dequantized.unsafe_load(output_index * 4) != expected_first:
            raise Error("AWQ 4-bit reordered weight mismatch in first group")
        if dequantized.unsafe_load(output_index * 4 + 1) != expected_first:
            raise Error("AWQ 4-bit reordered weight mismatch in first group")
        if dequantized.unsafe_load(output_index * 4 + 2) != expected_second:
            raise Error("AWQ 4-bit reordered weight mismatch in second group")
        if dequantized.unsafe_load(output_index * 4 + 3) != expected_second:
            raise Error("AWQ 4-bit reordered weight mismatch in second group")

    for input_index in range(4):
        input.unsafe_store(input_index, Float16(1.0))
        input.unsafe_store(4 + input_index, Float16(input_index + 1))
    gemm_awq_4bit_matrix(input, 8, 2, matrix, output, 16)
    for output_index in range(8):
        var delta = Float16(output_index)
        if output.unsafe_load(output_index) != delta * Float16(1.5):
            raise Error("AWQ 4-bit GEMM first row mismatch")
        if output.unsafe_load(8 + output_index) != delta * Float16(3.25):
            raise Error("AWQ 4-bit GEMM second row mismatch")
    print("AWQ_4BIT canonical AutoAWQ GEMM layout and execution: PASS")


def test_exl2_boundary() raises:
    assert_external_format_rejected(CompressedFormatType(CompressedFormatType.EXL2_VARBIT), "EXL2_VARBIT")


def test_hqq_4bit_axis1_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var packed = well.allocate(2).unsafe_bitcast[UInt8]()
    var scales = well.allocate(4).unsafe_bitcast[Float16]()
    var zeros = well.allocate(4).unsafe_bitcast[Float16]()
    var expanded = well.allocate(8).unsafe_bitcast[Float16]()
    var input = well.allocate(8).unsafe_bitcast[Float16]()
    var output = well.allocate(4).unsafe_bitcast[Float16]()
    packed.unsafe_store(0, UInt8(0x15))
    packed.unsafe_store(1, UInt8(0x26))
    packed.unsafe_store(2, UInt8(0x37))
    packed.unsafe_store(3, UInt8(0x48))
    var scale_values = [
        Float16(0.5), Float16(1.0), Float16(0.25), Float16(0.125)
    ]
    var zero_values = [
        Float16(1.0), Float16(2.0), Float16(3.0), Float16(4.0)
    ]
    for i in range(4):
        scales.unsafe_store(i, scale_values[i])
        zeros.unsafe_store(i, zero_values[i])
    var matrix = HQQ4BitAxis1Matrix(
        packed, 4, scales, 4, zeros, 4, 4, 2, 2
    )
    dequantize_hqq_4bit_axis1(matrix, expanded, 8)
    var expected_weights = [
        Float16(0.0), Float16(0.5), Float16(1.0), Float16(2.0),
        Float16(0.5), Float16(0.75), Float16(0.375), Float16(0.5),
    ]
    for i in range(8):
        if expanded.unsafe_load(i) != expected_weights[i]:
            raise Error("HQQ 4-bit axis=1 cross-group unpack mismatch")

    for i in range(4):
        input.unsafe_store(i, Float16(i + 1))
        input.unsafe_store(4 + i, Float16(1.0))
    gemm_hqq_4bit_axis1(input, 8, 2, matrix, output, 4)
    var expected_output = [
        Float16(12.0), Float16(5.125), Float16(3.5), Float16(2.125)
    ]
    for i in range(4):
        if output.unsafe_load(i) != expected_output[i]:
            raise Error("HQQ 4-bit axis=1 GEMM mismatch")
    print("HQQ 4-bit axis=1 native packing and execution: PASS")


def test_smoothquant_int8_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var weights = well.allocate(4).unsafe_bitcast[Int8]()
    var bias = well.allocate(4).unsafe_bitcast[Float32]()
    var expanded = well.allocate(8).unsafe_bitcast[Float16]()
    var input = well.allocate(8).unsafe_bitcast[Float16]()
    var output = well.allocate(4).unsafe_bitcast[Float16]()
    var raw_weights = [
        Int8(1), Int8(-2), Int8(3), Int8(-4),
        Int8(5), Int8(6), Int8(-7), Int8(-8),
    ]
    for i in range(8):
        weights.unsafe_store(i, raw_weights[i])
    bias.unsafe_store(0, Float32(1.0))
    bias.unsafe_store(1, Float32(-2.0))
    var matrix = SmoothQuantW8A8Matrix(
        weights, 8, Float32(0.25), Float32(0.5), 4, 2, bias, 2, True
    )

    dequantize_smoothquant_weights(matrix, expanded, 8)
    for i in range(8):
        if expanded.unsafe_load(i) != Float16(raw_weights[i]) * Float16(0.25):
            raise Error("SmoothQuant W8 weight expansion mismatch")
    if quantize_smoothquant_int8(Float32(100.0), Float32(0.5)) != Int8(127):
        raise Error("SmoothQuant positive activation saturation mismatch")
    if quantize_smoothquant_int8(Float32(-100.0), Float32(0.5)) != Int8(-128):
        raise Error("SmoothQuant negative activation saturation mismatch")
    if quantize_smoothquant_int8(Float32(0.75), Float32(0.5)) != Int8(2):
        raise Error("SmoothQuant positive nearest rounding mismatch")
    if quantize_smoothquant_int8(Float32(-0.75), Float32(0.5)) != Int8(-2):
        raise Error("SmoothQuant negative nearest rounding mismatch")

    var input_values = [
        Float16(0.5), Float16(-1.0), Float16(1.5), Float16(-2.0),
        Float16(1.0), Float16(-0.5), Float16(0.0), Float16(2.0),
    ]
    for i in range(8):
        input.unsafe_store(i, input_values[i])
    gemm_smoothquant_w8a8(input, 8, 2, matrix, output, 4)
    var expected = [
        Float16(4.75), Float16(-1.5), Float16(-0.5), Float16(-5.5)
    ]
    for i in range(4):
        if output.unsafe_load(i) != expected[i]:
            raise Error("SmoothQuant W8A8 INT32 GEMM mismatch")
    print("SMOOTHQUANT_INT8 static W8A8 execution: PASS")
