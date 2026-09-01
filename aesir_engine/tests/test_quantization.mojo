# tests/test_quantization.mojo
# Verification of compressed-format discriminants and execution boundaries

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from core.mimir_well import CompressedFormatType, Scalar, f16
from core.compute import dequantize_compressed_tensor

def test_compressed_format_enum() raises:
    print("--- Testing CompressedFormatType (Format Discriminants) ---")
    var success = True
    var fmt_q2 = CompressedFormatType(CompressedFormatType.Q2_K)
    var fmt_gptq = CompressedFormatType(CompressedFormatType.GPTQ_4BIT)
    var fmt_awq = CompressedFormatType(CompressedFormatType.AWQ_4BIT)
    var fmt_exl2 = CompressedFormatType(CompressedFormatType.EXL2_VARBIT)
    var fmt_hqq = CompressedFormatType(CompressedFormatType.HQQ)
    var fmt_sq = CompressedFormatType(CompressedFormatType.SMOOTHQUANT_INT8)

    if fmt_q2.name() != "Q2_K":
        print("FAIL: Expected Q2_K, got", fmt_q2.name())
        success = False
    if fmt_gptq.name() != "GPTQ_4BIT":
        print("FAIL: Expected GPTQ_4BIT, got", fmt_gptq.name())
        success = False
    if fmt_awq.name() != "AWQ_4BIT":
        print("FAIL: Expected AWQ_4BIT, got", fmt_awq.name())
        success = False
    if fmt_exl2.name() != "EXL2_VARBIT":
        print("FAIL: Expected EXL2_VARBIT, got", fmt_exl2.name())
        success = False
    if fmt_hqq.name() != "HQQ":
        print("FAIL: Expected HQQ, got", fmt_hqq.name())
        success = False
    if fmt_sq.name() != "SMOOTHQUANT_INT8":
        print("FAIL: Expected SMOOTHQUANT_INT8, got", fmt_sq.name())
        success = False

    # Test GGMLType to CompressedFormatType conversion
    from loader.gguf import GGMLType
    var mapped_q2 = GGMLType.to_compressed_format(10)
    var mapped_q4k = GGMLType.to_compressed_format(12)
    if mapped_q2.name() != "Q2_K" or mapped_q4k.name() != "Q4_K_M":
        print("FAIL: GGMLType mapping mismatch")
        success = False
    var rejected_f32 = False
    try:
        _ = GGMLType.to_compressed_format(GGMLType.F32)
    except error:
        rejected_f32 = "unsupported GGML tensor type" in String(error)
    if not rejected_f32:
        print("FAIL: non-quantized F32 was silently mapped to Q4_K_M")
        success = False
    var rejected_iq = False
    try:
        _ = GGMLType.to_compressed_format(GGMLType.IQ2_XXS)
    except error:
        rejected_iq = "unsupported GGML tensor type" in String(error)
    if not rejected_iq:
        print("FAIL: unimplemented IQ2_XXS tensor layout was accepted")
        success = False

    if success:
        print("CompressedFormatType: PASS")
    else:
        raise Error("CompressedFormatType invariant mismatch")


def assert_external_dequantization_rejected(
    format: CompressedFormatType,
    label: String,
    input: Pointer[UInt8, MutUntrackedOrigin],
    output: Pointer[Scalar[f16], MutUntrackedOrigin],
) raises:
    var num_elements = 32
    for i in range(32):
        output.unsafe_store(i, Scalar[f16](123.0))
    var rejected = False
    try:
        dequantize_compressed_tensor(format, input, output, num_elements)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error(label + " dequantization was accepted without required metadata")
    for i in range(32):
        if output.unsafe_load(i) != Scalar[f16](123.0):
            raise Error(label + " dequantization rejection mutated output")


def assert_partial_block_rejected(
    format: CompressedFormatType,
    block_size: Int,
    label: String,
    input: Pointer[UInt8, MutUntrackedOrigin],
    output: Pointer[Scalar[f16], MutUntrackedOrigin],
) raises:
    for i in range(256):
        output.unsafe_store(i, Scalar[f16](143.0))
    var rejected = False
    try:
        dequantize_compressed_tensor(format, input, output, block_size - 1)
    except error:
        rejected = "complete quantization blocks" in String(error)
    if not rejected:
        raise Error(label + " accepted a partial quantization block")
    for i in range(256):
        if output.unsafe_load(i) != Scalar[f16](143.0):
            raise Error(label + " partial-block rejection mutated output")


def test_dequantization_kernels() raises:
    print("--- Testing compressed-format dequantization boundaries ---")
    var input = alloc(Layout[UInt8](count=512)).unsafe_leak()
    var output = alloc(Layout[Scalar[f16]](count=256)).unsafe_leak()
    for i in range(512):
        input.unsafe_store(i, UInt8(i * 7 % 256))
    assert_external_dequantization_rejected(CompressedFormatType(CompressedFormatType.GPTQ_4BIT), "GPTQ_4BIT", input, output)
    assert_external_dequantization_rejected(CompressedFormatType(CompressedFormatType.GPTQ_8BIT), "GPTQ_8BIT", input, output)
    assert_external_dequantization_rejected(CompressedFormatType(CompressedFormatType.AWQ_4BIT), "AWQ_4BIT", input, output)
    assert_external_dequantization_rejected(CompressedFormatType(CompressedFormatType.EXL2_VARBIT), "EXL2_VARBIT", input, output)
    assert_external_dequantization_rejected(CompressedFormatType(CompressedFormatType.HQQ), "HQQ", input, output)
    assert_external_dequantization_rejected(CompressedFormatType(CompressedFormatType.SMOOTHQUANT_INT8), "SMOOTHQUANT_INT8", input, output)
    assert_partial_block_rejected(CompressedFormatType(CompressedFormatType.Q2_K), 256, "Q2_K", input, output)
    assert_partial_block_rejected(CompressedFormatType(CompressedFormatType.Q3_K_M), 256, "Q3_K", input, output)
    assert_partial_block_rejected(CompressedFormatType(CompressedFormatType.Q4_0), 32, "Q4_0", input, output)
    assert_partial_block_rejected(CompressedFormatType(CompressedFormatType.Q5_0), 32, "Q5_0", input, output)
    assert_partial_block_rejected(CompressedFormatType(CompressedFormatType.Q6_K), 256, "Q6_K", input, output)
    assert_partial_block_rejected(CompressedFormatType(CompressedFormatType.Q8_0), 32, "Q8_0", input, output)
    assert_partial_block_rejected(CompressedFormatType(CompressedFormatType.Q4_K_M), 256, "Q4_K", input, output)
    input.unsafe_free()
    output.unsafe_free()
    print("compressed-format dequantization boundaries: PASS")


def test_quantized_byte_span_validation() raises:
    print("--- Testing Quantized Byte Span Bounds & Alignment Validation ---")
    from loader.quantization import validate_quantized_byte_span
    
    # Valid span: 1 block Q4_K_M (144 bytes, 256 elements)
    var fmt_q4 = CompressedFormatType(CompressedFormatType.Q4_K_M)
    validate_quantized_byte_span(144, 256, fmt_q4)
    
    # Invalid non-divisible byte buffer (140 bytes)
    var rejected = False
    try:
        validate_quantized_byte_span(140, 256, fmt_q4)
    except:
        rejected = True
    if not rejected:
        raise Error("validate_quantized_byte_span failed to reject non-divisible buffer length")
        
    print("Quantized Byte Span Bounds & Alignment Validation: PASS")

def main() raises:
    test_compressed_format_enum()
    test_dequantization_kernels()
    test_quantized_byte_span_validation()
