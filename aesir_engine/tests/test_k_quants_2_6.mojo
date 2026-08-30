"""
Project Aesir — K-Quantization 2-Bit & 6-Bit Integration Unit Test Suite
════════════════════════════════════════════════════════════════════════
Verifies fused Q2_K and Q6_K matrix-vector multiplication parity against
uncompressed gemm_f16.
"""

from std.memory import Pointer, alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    BlockQ2_K, BlockQ6_K,
    dequantize_q2_k_block, dequantize_q6_k_block,
    gemm_q2_k, gemm_q6_k, gemm_f16
)


def test_fused_q2_k_parity() raises:
    print("--- Testing fused Q2_K GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 256
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.01) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockQ2_K](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ2_K]()
    for n in range(N):
        var scales = SIMD[DType.uint8, 16](0x11)
        var qs = SIMD[DType.uint8, 64](0xAA)
        var blk = BlockQ2_K(scales, qs, Scalar[f16](0.25), Scalar[f16](-0.5))
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q2_K))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_q2_k_block(B_blocks, dequant_w_ptr, N)
    var B_dequant = RuneTensor[f16](N, K, dequant_w_ptr, False)

    var cf_ptr = well.allocate(M * N)
    var cd_ptr = well.allocate(M * N)
    var C_fused = RuneTensor[f16](M, N, cf_ptr, False)
    var C_dequant = RuneTensor[f16](M, N, cd_ptr, False)

    gemm_f16(A, B_quant, C_fused)
    gemm_f16(A, B_dequant, C_dequant)

    for i in range(M * N):
        var diff = C_fused.data.unsafe_load(i) - C_dequant.data.unsafe_load(i)
        var abs_diff = diff if diff >= 0 else -diff
        if abs_diff > 0.05:
            raise Error("test_fused_q2_k_parity: mismatch at index " + String(i))

    print("fused Q2_K GEMM parity: PASS")


def test_fused_q6_k_parity() raises:
    """Known-value raw GGUF regression, independent of legacy padded structs."""
    var well = MimirWell(8192)
    var raw = well.allocate(210).unsafe_bitcast[UInt8]()
    for i in range(210):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_offset(208).unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.125))
    for i in range(128):
        raw.unsafe_store(i, UInt8(85))
    for i in range(64):
        raw.unsafe_store(128 + i, UInt8(51))
    for i in range(16):
        raw.unsafe_store(192 + i, UInt8(1))
    # qh 0x33 gives high pairs [3,0,3,0]; low nibble is always five.
    # Half the weights are +21/8, half -27/8: sum = -96.
    var expected = Float32(-96)

    var input = well.allocate(256)
    for i in range(256):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 256, input, False)
    var B = RuneTensor[f16](1, 256, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q6_K))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load().cast[f32]() != expected:
        raise Error("Raw Q6_K matvec known-value mismatch")
    _ = well  # Keep the arena alive through every borrowed-pointer read.
    print("raw Q6_K matvec: PASS")
