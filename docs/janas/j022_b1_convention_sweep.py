#!/usr/bin/env python3
"""J-022 B1: convention sweep for the OLMoE attention block.

If neither QK-norm reading (full / perhead, norm->rope, NeoX) reproduces
the ggml comparator's last-position logits, sweep the remaining
convention axes: qknorm in {full, perhead, none} x order in
{norm->rope, rope->norm} x rope in {neox, interleaved}. Everything else
identical to the J-016 instrument (f32, same router/expert maths).
Prints last-position top-5 per variant for seq8 and seq72; the
comparator tables are in j022_b1_qknorm_ab.py's header.
Usage: j022_b1_convention_sweep.py <gguf>
"""
import sys, math
import numpy as np

sys.path.insert(0, "/home/volmarr/j016")
from j016_router_forward import OlmoeForward, rms_norm  # noqa: E402

IDS67 = [int(x) for x in open("/home/volmarr/j022/prompt_prose_ids.csv").read().strip().split(",")]
SEQS = {"seq8": IDS67[:8], "seq72": IDS67 + [187, 187, 510, 1708, 5967]}


def rope_apply(model, x, positions, style):
    half = model.head_dim // 2
    inv_freq = 1.0 / (model.rope_base ** (np.arange(0, half, dtype=np.float32) / half))
    ang = positions[:, None].astype(np.float32) * inv_freq[None, :]
    cos = np.cos(ang)[:, None, :]; sin = np.sin(ang)[:, None, :]
    if style == "neox":
        x1, x2 = x[..., :half], x[..., half:]
        return np.concatenate([x1 * cos - x2 * sin, x2 * cos + x1 * sin], axis=-1)
    # interleaved (GPT-J): pairs (2i, 2i+1) share angle i
    xe = x.reshape(*x.shape[:-1], half, 2)
    x1, x2 = xe[..., 0], xe[..., 1]
    rot = np.stack([x1 * cos - x2 * sin, x2 * cos + x1 * sin], axis=-1)
    return rot.reshape(x.shape)


def run(model, ids, qknorm, order, style):
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
        def qk_norm(t, w):
            if qknorm == "full":
                return rms_norm(t.reshape(-1, model.hidden), w, model.eps).reshape(t.shape)
            if qknorm == "perhead":
                return rms_norm(t, w.reshape(model.n_head, model.head_dim), model.eps)
            return t
        pos = np.arange(h.shape[0])
        if order == "norm->rope":
            q = rope_apply(model, qk_norm(q, wqn), pos, style)
            k = rope_apply(model, qk_norm(k, wkn), pos, style)
        else:
            q = qk_norm(rope_apply(model, q, pos, style), wqn)
            k = qk_norm(rope_apply(model, k, pos, style), wkn)
        scale = 1.0 / math.sqrt(model.head_dim)
        scores = np.einsum("thd,shd->hts", q, k) * scale
        mask = np.triu(np.ones(scores.shape[-2:], dtype=bool), k=1)
        scores = np.where(mask[None], -1e30, scores)
        scores = scores - scores.max(axis=-1, keepdims=True)
        p = np.exp(scores); p /= p.sum(axis=-1, keepdims=True)
        att = np.einsum("hts,shd->thd", p, v).reshape(-1, model.hidden)
        h = h + att @ Wo.T
        del Wq, Wk, Wv, Wo
        # MoE block: reuse the instrument by running its FFN half via a
        # one-layer call is not separable; replicate exactly (as in the
        # layer-dump script).
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
        w_norm = topw / topw.sum(axis=-1, keepdims=True)
        gate = model.deq(f"blk.{l}.ffn_gate_exps.weight")
        up = model.deq(f"blk.{l}.ffn_up_exps.weight")
        down = model.deq(f"blk.{l}.ffn_down_exps.weight")
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
    out_w = model.deq("output.weight"); out_n = model.deq("output_norm.weight")
    hn = rms_norm(h, out_n, model.eps)
    return hn[-1] @ out_w.T


def main():
    model = OlmoeForward(sys.argv[1], "full")
    for qknorm in ("full", "perhead", "none"):
        for order in ("norm->rope", "rope->norm"):
            for style in ("neox", "interleaved"):
                if qknorm == "none" and order == "rope->norm":
                    continue  # order meaningless without norm... (norm absent, rope position same)
                for name, ids in SEQS.items():
                    logits = run(model, ids, qknorm, order, style)
                    top5 = np.argsort(-logits)[:5]
                    print(f"{qknorm:>7} {order:>10} {style:>11} {name}:",
                          [(int(i), round(float(logits[i]), 3)) for i in top5], flush=True)

if __name__ == "__main__":
    main()
