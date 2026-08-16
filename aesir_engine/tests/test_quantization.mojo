# tests/test_quantization.mojo
# Verification of compressed-format discriminants and toy write scaffolds

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

    if success:
        print("CompressedFormatType: PASS")
    else:
        raise Error("CompressedFormatType invariant mismatch")


def test_dequantization_kernels() raises:
    print("--- Testing toy compressed dispatch writes (not format compatibility) ---")
    var success = True
    var num_elements = 32
    var in_bytes = alloc(Layout[UInt8](count=32)).unsafe_leak()
    var out_f16 = alloc(Layout[Scalar[f16]](count=32)).unsafe_leak()

    for i in range(32):
        in_bytes.unsafe_store(i, UInt8(i * 7 % 256))
        out_f16.unsafe_store(i, Scalar[f16](123.0))

    # Dispatch Q2_K
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.Q2_K), in_bytes, out_f16, num_elements)
    if out_f16.unsafe_load(0) == Scalar[f16](123.0):
        print("FAIL: Q2_K dispatch did not write output")
        success = False

    for i in range(32):
        out_f16.unsafe_store(i, Scalar[f16](123.0))

    # Dispatch Q4_0
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.Q4_0), in_bytes, out_f16, num_elements)
    if out_f16.unsafe_load(0) == Scalar[f16](123.0):
        print("FAIL: Q4_0 dispatch did not write output")
        success = False

    for i in range(32):
        out_f16.unsafe_store(i, Scalar[f16](123.0))
    
    # Dispatch Q8_0
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.Q8_0), in_bytes, out_f16, num_elements)
    if out_f16.unsafe_load(0) == Scalar[f16](123.0):
        print("FAIL: Q8_0 dispatch did not write output")
        success = False

    for i in range(32):
        out_f16.unsafe_store(i, Scalar[f16](123.0))

    # Dispatch GPTQ_4BIT
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.GPTQ_4BIT), in_bytes, out_f16, num_elements)
    if out_f16.unsafe_load(0) == Scalar[f16](123.0):
        print("FAIL: GPTQ_4BIT dispatch did not write output")
        success = False

    for i in range(32):
        out_f16.unsafe_store(i, Scalar[f16](123.0))

    # Dispatch AWQ_4BIT
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.AWQ_4BIT), in_bytes, out_f16, num_elements)
    if out_f16.unsafe_load(0) == Scalar[f16](123.0):
        print("FAIL: AWQ_4BIT dispatch did not write output")
        success = False

    for i in range(32):
        out_f16.unsafe_store(i, Scalar[f16](123.0))

    # Dispatch EXL2_VARBIT
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.EXL2_VARBIT), in_bytes, out_f16, num_elements)
    if out_f16.unsafe_load(0) == Scalar[f16](123.0):
        print("FAIL: EXL2_VARBIT dispatch did not write output")
        success = False

    for i in range(32):
        out_f16.unsafe_store(i, Scalar[f16](123.0))

    # Dispatch HQQ
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.HQQ), in_bytes, out_f16, num_elements)
    if out_f16.unsafe_load(0) == Scalar[f16](123.0):
        print("FAIL: HQQ dispatch did not write output")
        success = False

    for i in range(32):
        out_f16.unsafe_store(i, Scalar[f16](123.0))

    # Dispatch SMOOTHQUANT_INT8
    dequantize_compressed_tensor(CompressedFormatType(CompressedFormatType.SMOOTHQUANT_INT8), in_bytes, out_f16, num_elements)

    if out_f16.unsafe_load(0) == Scalar[f16](123.0):
        print("FAIL: SMOOTHQUANT_INT8 dispatch did not write output")
        success = False

    in_bytes.unsafe_free()
    out_f16.unsafe_free()

    if success:
        print("toy compressed dispatch writes: PASS")
    else:
        raise Error("dequantization dispatch did not write deterministic output")


def test_q4_k_m_block_dequantization() raises:
    print("--- Testing Q4_K_M Block Dequantization Math & Layout ---")
    from core.compute import BlockQ4_K, dequantize_q4_k_m
    var block_mem = alloc(Layout[BlockQ4_K](count=1)).unsafe_leak()
    var out_mem = alloc(Layout[Scalar[f16]](count=32)).unsafe_leak()

    var scale = Scalar[f16](0.5)
    var min_val = Scalar[f16](-1.0)
    var qs = SIMD[DType.uint8, 16](0x21) # lower_4 = 1, upper_4 = 2

    block_mem.unsafe_store(0, BlockQ4_K(scale, min_val, qs))

    dequantize_q4_k_m(block_mem, out_mem, 1)

    var val_lower = out_mem.unsafe_load(0) # 1 * 0.5 + (-1.0) = -0.5
    var val_upper = out_mem.unsafe_load(16) # 2 * 0.5 + (-1.0) = 0.0

    # Zero blocks safety check (must return early without modifying or crashing)
    dequantize_q4_k_m(block_mem, out_mem, 0)

    block_mem.unsafe_free()
    out_mem.unsafe_free()

    if val_lower == Scalar[f16](-0.5) and val_upper == Scalar[f16](0.0):
        print("Q4_K_M block dequantization math & layout: PASS")
    else:
        print("FAIL: Expected lower=-0.5, upper=0.0; got lower=", val_lower, ", upper=", val_upper)
        raise Error("Q4_K_M block dequantization invariant mismatch")


def main() raises:
    test_compressed_format_enum()
    test_dequantization_kernels()
    test_q4_k_m_block_dequantization()
