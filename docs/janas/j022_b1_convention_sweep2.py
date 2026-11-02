#!/usr/bin/env python3
"""J-022 B1: convention sweep 2 -- single-axis variants off the adopted
(full-width QK-norm, norm->rope, NeoX) baseline, hunting the variant
whose last-position logits match the ggml comparator's tables:
  seq8:  281:16.634 13:14.750 273:14.680 4283:14.433 598:14.013
  seq67: 187:15.824 754:15.168 2635:14.913 380:14.314 1292:14.057
  seq72: 6225:13.578 369:13.422 43775:13.170 574:12.280 3139:11.566
Variants: baseline, gate_up_swap, tied_head, attn_scale_x2,
attn_scale_half, router_no_renorm, rope_partial64, pos_plus1.
Usage: j022_b1_convention_sweep2.py <gguf>
"""
import sys, math
import numpy as np

sys.path.insert(0, "/home/volmarr/j016")
from j016_router_forward import OlmoeForward, rms_norm  # noqa: E402

IDS67 = [int(x) for x in open("/home/volmarr/j022/prompt_prose_ids.csv").read().strip().split(",")]
SEQS = {"seq8": IDS67[:8], "seq67": IDS67, "seq72": IDS67 + [187, 187, 510, 1708, 5967]}


def run(model, ids, variant):
    emb = model.deq("token_embd.weight")
    h = emb[np.array(ids, dtype=np.int64)].astype(np.float32).copy()
    del emb
    for l in range(model.n_layer):
        T0 = model.deq(f"blk.{l}.attn_norm.weight")
        Wq = model.deq(f"blk.{l}.attn_q.weight"); Wk = model.deq(f"blk.{l}.attn_k.weight")
        Wv = model.deq(f"blk.{l}.attn_v.weight"); Wo = model.deq(f"blk.{l}.attn_output.weight")
        wqn = model.deq(f"blk.{l}.attn_q_norm.weight"); wkn = model.deq(f"blk.{l}.attn_k_norm.weight")
        x = rms_norm(h, T0, model.eps)
        q = (x @ Wq.T).reshape(-1, model.n_head, model.head_dim)
        k = (x @ Wk.T).reshape(-1, model.n_head, model.head_dim)
        v = (x @ Wv.T).reshape(-1, model.n_head, model.head_dim)
        q = rms_norm(q.reshape(-1, model.hidden), wqn, model.eps).reshape(q.shape)
        k = rms_norm(k.reshape(-1, model.hidden), wkn, model.eps).reshape(k.shape)
        pos = np.arange(h.shape[0])
        if variant == "pos_plus1":
            pos = pos + 1
        half = model.head_dim // 2
        inv_freq = 1.0 / (model.rope_base ** (np.arange(0, half, dtype=np.float32) / half))
        ang = pos[:, None].astype(np.float32) * inv_freq[None, :]
        cos = np.cos(ang)[:, None, :]; sin = np.sin(ang)[:, None, :]
        def rp(t):
            if variant == "rope_partial64":
                tt = t.copy()
                seg = tt[..., :64]
                s1, s2 = seg[..., :32], seg[..., 32:]
                c32 = cos[..., :32]; s32 = sin[..., :32]
                tt[..., :64] = np.concatenate([s1 * c32 - s2 * s32, s2 * c32 + s1 * s32], axis=-1)
                return tt
            x1, x2 = t[..., :half], t[..., half:]
            return np.concatenate([x1 * cos - x2 * sin, x2 * cos + x1 * sin], axis=-1)
        q = rp(q); k = rp(k)
        scale = 1.0 / math.sqrt(model.head_dim)
        if variant == "attn_scale_x2":
            scale *= 2.0
        if variant == "attn_scale_half":
            scale *= 0.5
        scores = np.einsum("thd,shd->hts", q, k) * scale
        mask = np.triu(np.ones(scores.shape[-2:], dtype=bool), k=1)
        scores = np.where(mask[None], -1e30, scores)
        scores = scores - scores.max(axis=-1, keepdims=True)
        p = np.exp(scores); p /= p.sum(axis=-1, keepdims=True)
        att = np.einsum("hts,shd->thd", p, v).reshape(-1, model.hidden)
        h = h + att @ Wo.T
        del Wq, Wk, Wv, Wo
        wfn = model.deq(f"blk.{l}.ffn_norm.weight")
        Wr = model.deq(f"blk.{l}.ffn_gate_inp.weight")
        xn = rms_norm(h, wfn, model.eps)
        lg = xn @ Wr.T; lg = lg - lg.max(axis=-1, keepdims=True)
        probs = np.exp(lg); probs /= probs.sum(axis=-1, keepdims=True)
        idx = np.argpartition(-probs, model.top_k + 1, axis=-1)
        top = idx[:, :model.top_k]
        ordr = np.argsort(-np.take_along_axis(probs, top, axis=-1), axis=-1)
        top = np.take_along_axis(top, ordr, axis=-1)
        topw = np.take_along_axis(probs, top, axis=-1)
        w_norm = topw if variant == "router_no_renorm" else topw / topw.sum(axis=-1, keepdims=True)
        gate = model.deq(f"blk.{l}.ffn_gate_exps.weight")
        up = model.deq(f"blk.{l}.ffn_up_exps.weight")
        down = model.deq(f"blk.{l}.ffn_down_exps.weight")
        if variant == "gate_up_swap":
            gate, up = up, gate
        out = np.zeros_like(xn)
        for e in range(model.n_expert):
            rows = np.argwhere(top == e)
            if rows.size == 0:
                continue
            toks, slots = rows[:, 0], rows[:, 1]
            xe = xn[toks]
            g = xe @ gate[e].T; u = xe @ up[e].T
            act = (g / (1.0 + np.exp(-g))) * u
            out[toks] += (act @ down[e].T) * w_norm[toks, slots][:, None].astype(np.float32)
        h = h + out
    out_n = model.deq("output_norm.weight")
    hn = rms_norm(h, out_n, model.eps)
    if variant == "tied_head":
        emb2 = model.deq("token_embd.weight")
        return hn[-1] @ emb2.T
    out_w = model.deq("output.weight")
    return hn[-1] @ out_w.T


def main():
    model = OlmoeForward(sys.argv[1], "full")
    for variant in ("baseline", "gate_up_swap", "tied_head", "attn_scale_x2",
                    "attn_scale_half", "router_no_renorm", "rope_partial64", "pos_plus1"):
        for name, ids in SEQS.items():
            logits = run(model, ids, variant)
            top5 = np.argsort(-logits)[:5]
            print(f"{variant:>16} {name}:", [(int(i), round(float(logits[i]), 3)) for i in top5], flush=True)

if __name__ == "__main__":
    main()
