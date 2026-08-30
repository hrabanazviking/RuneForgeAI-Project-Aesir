# tests/test_quantized_inference.mojo
# Quantized GGUF Q4_K_M Inference Vertical Slice Test Suite

from std.memory import Pointer, alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import BlockQ4_K, gemm_f16, gemm_q4_k_m, dequantize_q4_k_m

def test_gemm_q4_k_m_fused_parity() raises:
    """Known-value raw GGUF regression, independent of legacy padded structs."""
    var well = MimirWell(8192)
    var raw = well.allocate(144).unsafe_bitcast[UInt8]()
    for i in range(144):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(1))
    for i in range(12):
        raw.unsafe_store(4 + i, UInt8(1))
    for i in range(128):
        raw.unsafe_store(16 + i, UInt8(17))
    var expected = Float32(256)

    var input = well.allocate(256)
    for i in range(256):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 256, input, False)
    var B = RuneTensor[f16](1, 256, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q4_K_M))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load().cast[f32]() != expected:
        raise Error("Raw Q4_K_M matvec known-value mismatch")
    _ = well  # Keep the arena alive through every borrowed-pointer read.
    print("raw Q4_K_M matvec: PASS")


def test_quantized_tensor_mapping() raises:
    print("--- Testing RuneTensor Q4_K_M quantization metadata ---")
    var well = MimirWell(1024 * 1024)
    var ptr = well.allocate(32)
    var tensor = RuneTensor[f16](1, 32, ptr, True, CompressedFormatType(CompressedFormatType.Q4_K_M))
    if not tensor.is_quantized:
        raise Error("RuneTensor failed to retain is_quantized flag")
    if tensor.quant_format.value != CompressedFormatType.Q4_K_M:
        raise Error("RuneTensor failed to retain quant_format metadata")
    print("RuneTensor Q4_K_M quantization metadata: PASS")

def main() raises:
    test_gemm_q4_k_m_fused_parity()
    test_quantized_tensor_mapping()
