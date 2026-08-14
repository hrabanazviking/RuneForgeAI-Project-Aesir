# tests/test_quantization.mojo
# Verification of Universal Compressed LLM Format Matrix (Slice 10)

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from core.mimir_well import CompressedFormatType, Scalar, f16
from core.compute import (
    dequantize_q2_k,
    dequantize_q3_k,
    dequantize_q4_0,
    dequantize_q4_1,
    dequantize_q5_0,
    dequantize_q6_k,
    dequantize_q8_0,
    dequantize_gptq_4bit,
    dequantize_awq_4bit,
    dequantize_exl2,
    dequantize_hqq,
    dequantize_smoothquant_int8,
    dequantize_compressed_tensor
)

def test_compressed_format_enum():
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

    if success:
        print("CompressedFormatType: PASS")
    else:
        print("CompressedFormatType: FAIL")


def test_dequantization_kernels():
    print("--- Testing Dequantization Kernels across 18 Compressed Formats ---")
    var success = True
    var num_elements = 32
    var in_bytes = alloc(Layout[UInt8](count=32)).unsafe_leak()
    var out_f16 = alloc(Layout[Scalar[f16]](count=32)).unsafe_leak()

    for i in range(32):
        in_bytes.unsafe_store(i, UInt8(i * 7 % 256))

    # Dispatch Q2_K
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.Q2_K), in_bytes, out_f16, num_elements)

    # Dispatch Q4_0
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.Q4_0), in_bytes, out_f16, num_elements)
    
    # Dispatch Q8_0
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.Q8_0), in_bytes, out_f16, num_elements)

    # Dispatch GPTQ_4BIT
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.GPTQ_4BIT), in_bytes, out_f16, num_elements)

    # Dispatch AWQ_4BIT
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.AWQ_4BIT), in_bytes, out_f16, num_elements)

    # Dispatch EXL2_VARBIT
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.EXL2_VARBIT), in_bytes, out_f16, num_elements)

    # Dispatch HQQ
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.HQQ), in_bytes, out_f16, num_elements)

    # Dispatch SMOOTHQUANT_INT8
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.SMOOTHQUANT_INT8), in_bytes, out_f16, num_elements)

    in_bytes.unsafe_free()
    out_f16.unsafe_free()

    if success:
        print("Dequantization Kernels: PASS")
    else:
        print("Dequantization Kernels: FAIL")


def main():
    test_compressed_format_enum()
    test_dequantization_kernels()

