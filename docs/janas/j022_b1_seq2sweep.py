import sys, math
sys.path.insert(0, "/home/volmarr/j016")
import numpy as np
from j016_router_forward import OlmoeForward, rms_norm
M = "/home/volmarr/aesir-gpu/.aesir/models/olmoe-1b-7b-0924-instruct-q4_k_m.gguf"
model = OlmoeForward(M, "full")
print("rope_base", model.rope_base, "eps", model.eps, "n_head", model.n_head, "head_dim", model.head_dim, flush=True)
wqn = model.deq("blk.0.attn_q_norm.weight")
print("q_norm periodic128:", bool(np.allclose(wqn, np.tile(wqn[:128], 16), atol=1e-6)), "first8", [round(float(x),4) for x in wqn[:8]], "at128", [round(float(x),4) for x in wqn[128:136]], flush=True)
IDS = [int(x) for x in open("/home/volmarr/j022/prompt_prose_ids.csv").read().strip().split(",")]
out_w = model.deq("output.weight"); out_n = model.deq("output_norm.weight")
def run(ids, qknorm="full", rope="neox", sign=1.0):
    emb = model.deq("token_embd.weight")
    h = emb[np.array(ids, dtype=np.int64)].astype(np.float32).copy()
    del emb
    half = model.head_dim // 2
    inv_freq = 1.0 / (model.rope_base ** (np.arange(0, half, dtype=np.float32) / half))
    for l in range(model.n_layer):
        T0 = model.deq(f"blk.{l}.attn_norm.weight")
        Wq = model.deq(f"blk.{l}.attn_q.weight"); Wk = model.deq(f"blk.{l}.attn_k.weight")
        Wv = model.deq(f"blk.{l}.attn_v.weight"); Wo = model.deq(f"blk.{l}.attn_output.weight")
        wn_q = model.deq(f"blk.{l}.attn_q_norm.weight"); wn_k = model.deq(f"blk.{l}.attn_k_norm.weight")
        x = rms_norm(h, T0, model.eps)
        q = (x @ Wq.T).reshape(-1, model.n_head, model.head_dim)
        k = (x @ Wk.T).reshape(-1, model.n_head, model.head_dim)
        v = (x @ Wv.T).reshape(-1, model.n_head, model.head_dim)
        if qknorm == "full":
            q = rms_norm(q.reshape(-1, model.hidden), wn_q, model.eps).reshape(q.shape)
            k = rms_norm(k.reshape(-1, model.hidden), wn_k, model.eps).reshape(k.shape)
        elif qknorm == "perhead":
            q = rms_norm(q, wn_q.reshape(model.n_head, model.head_dim), model.eps)
            k = rms_norm(k, wn_k.reshape(model.n_head, model.head_dim), model.eps)
        pos = np.arange(h.shape[0], dtype=np.float32)
        ang = sign * pos[:, None] * inv_freq[None, :]
        cos = np.cos(ang)[:, None, :]; sin = np.sin(ang)[:, None, :]
        def rp(t):
            if rope == "none":
                return t
            if rope == "neox":
                x1, x2 = t[..., :half], t[..., half:]
                return np.concatenate([x1 * cos - x2 * sin, x2 * cos + x1 * sin], axis=-1)
            xe = t.reshape(*t.shape[:-1], half, 2)
            x1, x2 = xe[..., 0], xe[..., 1]
            rot = np.stack([x1 * cos - x2 * sin, x2 * cos + x1 * sin], axis=-1)
            return rot.reshape(t.shape)
        q = rp(q); k = rp(k)
        scale = 1.0 / math.sqrt(model.head_dim)
        scores = np.einsum("thd,shd->hts", q, k) * scale
        mask = np.triu(np.ones(scores.shape[-2:], dtype=bool), k=1)
        scores = np.where(mask[None], -1e30, scores)
        scores = scores - scores.max(axis=-1, keepdims=True)
        p = np.exp(scores); p /= p.sum(axis=-1, keepdims=True)
        att = np.einsum("hts,shd->thd", p, v).reshape(-1, model.hidden)
        h = h + att @ Wo.T
        del Wq, Wk, Wv, Wo
        wfn = model.deq(f"blk.{l}.ffn_norm.weight"); Wr = model.deq(f"blk.{l}.ffn_gate_inp.weight")
        xn = rms_norm(h, wfn, model.eps)
        lg = xn @ Wr.T; lg = lg - lg.max(axis=-1, keepdims=True)
        probs = np.exp(lg); probs /= probs.sum(axis=-1, keepdims=True)
        idx = np.argpartition(-probs, model.top_k + 1, axis=-1)
        top = idx[:, :model.top_k]
        ordr = np.argsort(-np.take_along_axis(probs, top, axis=-1), axis=-1)
        top = np.take_along_axis(top, ordr, axis=-1)
        topw = np.take_along_axis(probs, top, axis=-1)
        w_norm = topw / topw.sum(axis=-1, keepdims=True)
        gate = model.deq(f"blk.{l}.ffn_gate_exps.weight"); up = model.deq(f"blk.{l}.ffn_up_exps.weight"); down = model.deq(f"blk.{l}.ffn_down_exps.weight")
        out = np.zeros_like(xn)
        for e in range(model.n_expert):
            rows = np.argwhere(top == e)
            if rows.size == 0: continue
            toks, slots = rows[:, 0], rows[:, 1]
            xe = xn[toks]
            g = xe @ gate[e].T; u = xe @ up[e].T
            act = (g / (1.0 + np.exp(-g))) * u
            out[toks] += (act @ down[e].T) * w_norm[toks, slots][:, None].astype(np.float32)
        h = h + out
    hn = rms_norm(h, out_n, model.eps)
    return hn[-1] @ out_w.T
GGML = {2: (5967, 9.780), 8: (281, 16.634)}
for nm, ids, probe in [("seq2", IDS[:2], [5967, 273, 310]), ("seq8", IDS[:8], [281, 13, 273])]:
    for variant, kw in [("baseline", {}), ("rope_signflip", {"sign": -1.0}), ("no_rope", {"rope": "none"}), ("interleaved", {"rope": "inter"}), ("perhead", {"qknorm": "perhead"})]:
        logits = run(ids, **kw)
        top5 = np.argsort(-logits)[:5]
        print(nm, variant, [(int(i), round(float(logits[i]), 3)) for i in top5], "| probes", {p: round(float(logits[p]), 3) for p in probe}, flush=True)
