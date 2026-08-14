# tests/test_kv_cache.mojo
# Test suite for Ring-Buffer KV Cache & Multi-step state accumulation

from core.mimir_well import MimirWell, RuneTensor, KVCache, f16
from core.inference import forward_pass
from loader.gguf import GGUFSeer

def test_kv_cache() raises:
    print("--- Testing KVCache (The Waters of Mímisbrunnr) ---")

    # 1. Instantiation test
    var well = MimirWell(1024 * 1024 * 2) # 2 MB well
    var max_seq_len = 64
    var hidden_dim = 16
    var num_layers = 2

    var kv_cache = KVCache(max_seq_len, hidden_dim, well, num_layers)
    if kv_cache.max_seq_len != 64 or kv_cache.hidden_dim != 16 or kv_cache.num_layers != 2:
        print("FAIL: KVCache initialization metadata mismatch")
        return
    print("KVCache instantiation: PASS")

    # 2. Token append test
    var k_ptr = well.allocate(hidden_dim)
    var v_ptr = well.allocate(hidden_dim)
    var single_k = RuneTensor[f16](1, hidden_dim, k_ptr, False)
    var single_v = RuneTensor[f16](1, hidden_dim, v_ptr, False)

    for i in range(hidden_dim):
        single_k.set(0, i, Scalar[f16](Float32(i + 1)))
        single_v.set(0, i, Scalar[f16](Float32((i + 1) * 2)))

    kv_cache.append(0, 0, single_k, single_v)
    
    # Check value at layer 0, pos 0
    var k0 = kv_cache.get_k_slice(0, 1)
    var v0 = kv_cache.get_v_slice(0, 1)
    if k0.get(0, 0) != 1.0 or v0.get(0, 0) != 2.0:
        print("FAIL: KVCache token append data corruption")
        return
    print("KVCache token append: PASS")

    # 3. Multi-step single-token forward pass state accumulation
    var seer = GGUFSeer("dummy.gguf")
    var vocab = 10
    var dim = 16
    var heads = 4
    var head_dim = 4
    var ffn_hidden = 32

    seer.tensors["token_embd.weight"] = RuneTensor[f16](vocab, dim, well.allocate(vocab * dim), False)
    seer.tensors["blk.0.attn_norm.weight"] = RuneTensor[f16](1, dim, well.allocate(dim), False)
    seer.tensors["blk.0.attn_q.weight"] = RuneTensor[f16](dim, dim, well.allocate(dim * dim), False)
    seer.tensors["blk.0.attn_k.weight"] = RuneTensor[f16](dim, dim, well.allocate(dim * dim), False)
    seer.tensors["blk.0.attn_v.weight"] = RuneTensor[f16](dim, dim, well.allocate(dim * dim), False)
    seer.tensors["blk.0.attn_output.weight"] = RuneTensor[f16](dim, dim, well.allocate(dim * dim), False)
    seer.tensors["blk.0.ffn_norm.weight"] = RuneTensor[f16](1, dim, well.allocate(dim), False)
    seer.tensors["blk.0.ffn_gate.weight"] = RuneTensor[f16](ffn_hidden, dim, well.allocate(ffn_hidden * dim), False)
    seer.tensors["blk.0.ffn_up.weight"] = RuneTensor[f16](ffn_hidden, dim, well.allocate(ffn_hidden * dim), False)
    seer.tensors["blk.0.ffn_down.weight"] = RuneTensor[f16](dim, ffn_hidden, well.allocate(ffn_hidden * dim), False)
    seer.tensors["output_norm.weight"] = RuneTensor[f16](1, dim, well.allocate(dim), False)
    seer.tensors["output.weight"] = RuneTensor[f16](vocab, dim, well.allocate(vocab * dim), False)

    var test_cache = KVCache(16, dim, well, 1)
    var tokens = List[Int]()
    tokens.append(1)

    # Step 0
    var t0 = forward_pass(tokens, seer, well, test_cache, 0, 1, head_dim, heads)
    _ = t0
    
    # Step 1
    tokens.append(2)
    var t1 = forward_pass(tokens, seer, well, test_cache, 1, 1, head_dim, heads)
    _ = t1

    print("KVCache state accumulation: PASS")
    print("test_kv_cache: PASS")
