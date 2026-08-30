from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.mimir_well import MimirWell, RuneTensor, f16, f32, Scalar, Byte
from core.compute import gemm_q8_0, gemm_f16, dequantize_q8_0, BlockQ8_0

def main() raises:
    var seer = GGUFSeer("qwen2.5-0.5b-instruct-q4_0.gguf")
    var well = MimirWell(500 * 1024 * 1024)
    var weaver = RuneWeaver()
    seer.mmap_and_load(well, weaver)

    ref out_weight = seer.tensors["output.weight"]
    print("Output weight shape:", out_weight.rows, "x", out_weight.cols, "quantized:", out_weight.is_quantized, "fmt:", out_weight.quant_format.name())

    # Create dummy input A (1, 896)
    var a_ptr = well.allocate(896)
    var A = RuneTensor[f16](1, 896, a_ptr, False)
    for i in range(896):
        A.data.unsafe_store(i, Scalar[f16](0.01 * Float32(i % 10)))

    # Compute quantized gemm_q8_0 for first 100 output tokens
    var C_quant_ptr = well.allocate(100)
    var C_quant = RuneTensor[f16](1, 100, C_quant_ptr, False)

    # Sub-tensor view of B (first 100 rows)
    var B_sub = RuneTensor[f16](100, 896, out_weight.data, True, out_weight.quant_format)
    gemm_q8_0(A, B_sub, C_quant)

    print("First 10 logits from gemm_q8_0:")
    for i in range(10):
        var q_val = C_quant.data.unsafe_load(i).cast[f32]()
        print("  Token", i, ": Quantized=", q_val)

    # Now dequantize B_sub into F16 tensor and run unquantized gemm_f16
    var b_dequant_ptr = well.allocate(100 * 896)
    var B_dequant = RuneTensor[f16](100, 896, b_dequant_ptr, False)
    var num_blocks = (100 * 896) // 32
    dequantize_q8_0(out_weight.data.unsafe_bitcast[BlockQ8_0](), b_dequant_ptr, num_blocks)

    var C_dequant_ptr = well.allocate(100)
    var C_dequant = RuneTensor[f16](1, 100, C_dequant_ptr, False)
    gemm_f16(A, B_dequant, C_dequant)

    print("First 10 logits comparison (Quantized vs Dequantized F16):")
    for i in range(10):
        var q_val = C_quant.data.unsafe_load(i).cast[f32]()
        var d_val = C_dequant.data.unsafe_load(i).cast[f32]()
        print("  Token", i, ": Quantized=", q_val, " Dequantized=", d_val, " Diff=", abs(q_val - d_val))
