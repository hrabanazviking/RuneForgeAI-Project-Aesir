# tests/test_quantized_inference.mojo
# Quantized GGUF Q4_K_M Inference Vertical Slice Test Suite

from std.memory import Pointer, alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import BlockQ4_K, gemm_f16, gemm_q4_k_m, dequantize_q4_k_m

def test_gemm_q4_k_m_fused_parity() raises:
    print("--- Testing fused Q4_K_M GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)

    # 1. Allocate block memory for 1 BlockQ4_K (32 elements)
    var block_layout = Layout[BlockQ4_K](count=1)
    var block_alloc = alloc(block_layout)
    var block_mem = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ4_K]()
    
    # Scale = 2.0, Min = 0.5, qs = 0x31
    block_mem[] = BlockQ4_K(
        scale=Scalar[f16](2.0),
        min_val=Scalar[f16](0.5),
        qs=SIMD[DType.uint8, 16](0x31)
    )

    # 2. Dequantize into explicit F16 weight tensor
    var f16_w_ptr = well.allocate(32)
    dequantize_q4_k_m(block_mem, f16_w_ptr, 1)
    var B_f16 = RuneTensor[f16](1, 32, f16_w_ptr, False)

    # 3. Create quantized weight tensor representation
    var quant_w_ptr = block_mem.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](1, 32, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q4_K_M))

    # 4. Create input vector A (1 x 32)
    var a_ptr = well.allocate(32)
    for i in range(32):
        a_ptr.unsafe_store(i, Scalar[f16](1.0))
    var A = RuneTensor[f16](1, 32, a_ptr, False)

    # 5. Output tensors C1 and C2 (1 x 1)
    var c1_ptr = well.allocate(1)
    var C1 = RuneTensor[f16](1, 1, c1_ptr, False)
    var c2_ptr = well.allocate(1)
    var C2 = RuneTensor[f16](1, 1, c2_ptr, False)

    gemm_f16(A, B_f16, C1)
    gemm_f16(A, B_quant, C2)

    var val1 = C1.data.unsafe_load(0)
    var val2 = C2.data.unsafe_load(0)
    var diff = val1 - val2
    if diff < 0:
        diff = -diff
    if diff > Scalar[f16](0.01):
        raise Error("fused Q4_K_M GEMM output mismatch vs uncompressed gemm_f16")

    print("fused Q4_K_M GEMM parity: PASS")


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
