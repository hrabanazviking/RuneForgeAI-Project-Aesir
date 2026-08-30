from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from loader.quantization import dequantize_q4_0_block
from core.mimir_well import MimirWell, RuneTensor, KVCache, f16, f32
from core.inference import TransformerBlock
from core.compute import gemm_f16, rmsnorm, apply_rope, silu, flash_attention_gqa

def main() raises:
    var seer = GGUFSeer("qwen2.5-0.5b-instruct-q4_0.gguf")
    var tokenizer = RuneWeaver()
    var well = MimirWell(400 * 1024 * 1024)
    seer.mmap_and_load(well, tokenizer)
    
    var tokens = tokenizer.encode("Hello", False)
    ref token_embd = seer.tensors["token_embd.weight"]
    var hidden_dim = token_embd.cols
    var x_ptr = well.allocate(hidden_dim)
    var x = RuneTensor[f16](1, hidden_dim, x_ptr, False)
    
    var num_blocks = hidden_dim // 32
    var src_ptr = token_embd.data.unsafe_bitcast[Byte]().unsafe_offset((tokens[0] * num_blocks) * 18)
    dequantize_q4_0_block(src_ptr, x.data, num_blocks)
    
    var block0 = TransformerBlock(0, seer.config.head_dim(), seer.config.head_count, seer)
    
    rmsnorm(x, block0.attn_norm_weight, block0.rms_epsilon)

    var q_cols = block0.attn_q_weight.rows
    var k_cols = block0.attn_k_weight.rows
    var v_cols = block0.attn_v_weight.rows
    var q = RuneTensor[f16](x.rows, q_cols, well.allocate(x.rows * q_cols), False)
    var k = RuneTensor[f16](x.rows, k_cols, well.allocate(x.rows * k_cols), False)
    var v = RuneTensor[f16](x.rows, v_cols, well.allocate(x.rows * v_cols), False)
    gemm_f16(x, block0.attn_q_weight, q)
    gemm_f16(x, block0.attn_k_weight, k)
    gemm_f16(x, block0.attn_v_weight, v)
    
    if block0.has_bias:
        for i in range(q.size):
            q.data.unsafe_store(i, q.data.unsafe_load(i) + block0.attn_q_bias.data.unsafe_load(i % block0.attn_q_bias.cols))
        for i in range(k.size):
            k.data.unsafe_store(i, k.data.unsafe_load(i) + block0.attn_k_bias.data.unsafe_load(i % block0.attn_k_bias.cols))
        for i in range(v.size):
            v.data.unsafe_store(i, v.data.unsafe_load(i) + block0.attn_v_bias.data.unsafe_load(i % block0.attn_v_bias.cols))

    apply_rope(q, k, 0, block0.head_dim)

    var kv_cache = KVCache(2048, seer.config.kv_dim(), well, seer.config.block_count)
    kv_cache.append(0, 0, k, v)
    var k_slice = kv_cache.get_k_slice(0, 1)
    var v_slice = kv_cache.get_v_slice(0, 1)
    var attn_out = RuneTensor[f16](x.rows, x.cols, well.allocate(x.size), False)
    flash_attention_gqa(q, k_slice, v_slice, attn_out, 1, block0.head_dim, block0.num_heads, block0.num_kv_heads)
    
    print("attn_out[0..3] cast to Float32:")
    print(attn_out.data.unsafe_load(0).cast[f32]())
    print(attn_out.data.unsafe_load(1).cast[f32]())
    print(attn_out.data.unsafe_load(2).cast[f32]())
    print(attn_out.data.unsafe_load(3).cast[f32]())

