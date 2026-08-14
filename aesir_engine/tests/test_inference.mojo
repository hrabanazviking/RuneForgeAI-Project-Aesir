# tests/test_inference.mojo

from loader.gguf import GGUFSeer
from core.mimir_well import MimirWell, RuneTensor, f16
from core.inference import forward_pass
from aesir import generation_stop_reason


def test_generation_stop_policy() raises:
    print("--- Testing deterministic generation stop policy ---")

    if generation_stop_reason(2, 2, 1, 32, 8, 128) != "eos":
        raise Error("EOS must terminate generation before visible decoding")
    if generation_stop_reason(265, 2, 32, 32, 39, 128) != "length":
        raise Error("requested generation length must report 'length'")
    if generation_stop_reason(265, 2, 1, 32, 128, 128) != "context_exhausted":
        raise Error("context boundary must stop before an out-of-range evaluation")
    if generation_stop_reason(265, 2, 1, 32, 8, 128) != "":
        raise Error("nonterminal generation state must continue")

    print("deterministic generation stop policy: PASS")

def test_forward_pass() raises:
    print("--- Testing forward_pass (The Loom of Fate) ---")
    
    var well = MimirWell(1024 * 1024 * 2) # 2 MB well
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
    
    var tokens = List[Int]()
    tokens.append(1)
    tokens.append(2)
    tokens.append(3)
    var num_layers = 1
    
    var next_token = forward_pass(tokens, seer, well, num_layers, head_dim, heads)
    print("Next token generated:", next_token)
    if next_token != 0:
        raise Error("zero-initialized synthetic forward pass must select token 0")
    print("forward_pass: PASS")
