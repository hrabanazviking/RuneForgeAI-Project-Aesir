import sys
sys.path.insert(0, "/home/volmarr/j016")
import numpy as np
from j016_router_forward import OlmoeForward, rms_norm
M = "/home/volmarr/aesir-gpu/.aesir/models/olmoe-1b-7b-0924-instruct-q4_k_m.gguf"
model = OlmoeForward(M, "full")
for name in ["token_embd.weight","output.weight","output_norm.weight","blk.0.attn_q.weight","blk.0.attn_q_norm.weight","blk.0.ffn_gate_exps.weight","blk.0.ffn_down_exps.weight","blk.15.ffn_down_exps.weight"]:
    t = model.T[name]
    print("TYPE", name, t.tensor_type, t.shape)
out_w = model.deq("output.weight"); out_n = model.deq("output_norm.weight")
print("output_norm stats", float(out_n.min()), float(out_n.max()), float(out_n.mean()))
IDS = [int(x) for x in open("/home/volmarr/j022/prompt_prose_ids.csv").read().strip().split(",")]
for nm, ids in [("seq1", IDS[:1]), ("seq2", IDS[:2])]:
    emb = model.deq("token_embd.weight")
    states = [emb[np.array(ids, dtype=np.int64)].astype(np.float32).copy()]
    del emb
    sink = [[[] for _ in ids]]
    for l in range(model.n_layer):
        states = model.layer(l, states, sink)
    h = rms_norm(states[0], out_n, model.eps)
    logits = h[-1] @ out_w.T
    top = np.argsort(-logits)[:6]
    print(nm, "top6:", [(int(i), round(float(logits[i]),3)) for i in top])
