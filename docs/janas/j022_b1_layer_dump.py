#!/usr/bin/env python3
"""J-022 B1 experiment B (numpy side): per-layer hidden-state dump for one
sequence, using the J-016 reference instrument's forward conventions
(gguf-py dequant + numpy float32, QK-norm FULL-WIDTH reading as adopted
in J-016, NeoX RoPE, router softmax/top-8/renormalize, silu(gate)*up).

Usage: j022_b1_layer_dump.py <gguf> <ids_csv> <out.npz>
Saves: emb (T,hidden) initial states, attn[l] post-attention-residual
states, ffn[l] post-MoE-residual states (= next layer input), final
hidden, final normed hidden, last-position logits. float32.
"""
import sys, math
import numpy as np

sys.path.insert(0, "/home/volmarr/j016")
from j016_router_forward import OlmoeForward, rms_norm  # noqa: E402


def main():
    gguf_path, ids_csv, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    ids = [int(x) for x in ids_csv.split(",")]
    model = OlmoeForward(gguf_path, "full")
    emb = model.deq("token_embd.weight")
    states = emb[np.array(ids, dtype=np.int64)].astype(np.float32).copy()
    del emb
    T = len(ids)
    sink = [[[] for _ in range(T)]]
    saved = {"emb": states.copy()}
    orig_layer = model.layer

    # Monkeypatch-free copy of the layer body with mid-layer capture:
    # re-implement using the instrument's own helpers to record the
    # post-attention state as well as the post-MoE state.
    import types
    src_layer = orig_layer

    def layer_dump(l, states, trace_sink):
        T0 = model.deq(f"blk.{l}.attn_norm.weight")
        Wq = model.deq(f"blk.{l}.attn_q.weight"); Wk = model.deq(f"blk.{l}.attn_k.weight")
        Wv = model.deq(f"blk.{l}.attn_v.weight"); Wo = model.deq(f"blk.{l}.attn_output.weight")
        wqn = model.deq(f"blk.{l}.attn_q_norm.weight"); wkn = model.deq(f"blk.{l}.attn_k_norm.weight")
        h = states[0]
        x = rms_norm(h, T0, model.eps)
        q = (x @ Wq.T).reshape(-1, model.n_head, model.head_dim)
        k = (x @ Wk.T).reshape(-1, model.n_head, model.head_dim)
        v = (x @ Wv.T).reshape(-1, model.n_head, model.head_dim)
        q = rms_norm(q.reshape(-1, model.hidden), wqn, model.eps).reshape(-1, model.n_head, model.head_dim)
        k = rms_norm(k.reshape(-1, model.hidden), wkn, model.eps).reshape(-1, model.n_head, model.head_dim)
        pos = np.arange(h.shape[0])
        q = model.rope(q, pos); k = model.rope(k, pos)
        scale = 1.0 / math.sqrt(model.head_dim)
        scores = np.einsum("thd,shd->hts", q, k) * scale
        mask = np.triu(np.ones(scores.shape[-2:], dtype=bool), k=1)
        scores = np.where(mask[None], -1e30, scores)
        scores = scores - scores.max(axis=-1, keepdims=True)
        p = np.exp(scores); p /= p.sum(axis=-1, keepdims=True)
        att = np.einsum("hts,shd->thd", p, v).reshape(-1, model.hidden)
        states[0] = h + att @ Wo.T
        saved[f"attn{l}"] = states[0].copy()
        del Wq, Wk, Wv, Wo
        # MoE half: delegate to the instrument's layer for the FFN part by
        # running its full layer on a copy would double-count attention;
        # instead replicate its MoE block exactly (same code path values).
        wfn = model.deq(f"blk.{l}.ffn_norm.weight")
        Wr = model.deq(f"blk.{l}.ffn_gate_inp.weight")
        xn = rms_norm(states[0], wfn, model.eps)
        logits_r = xn @ Wr.T
        logits_r = logits_r - logits_r.max(axis=-1, keepdims=True)
        probs = np.exp(logits_r); probs /= probs.sum(axis=-1, keepdims=True)
        idx = np.argpartition(-probs, model.top_k + 1, axis=-1)
        top = idx[:, :model.top_k]
        order = np.argsort(-np.take_along_axis(probs, top, axis=-1), axis=-1)
        top = np.take_along_axis(top, order, axis=-1)
        topw = np.take_along_axis(probs, top, axis=-1)
        w_norm = topw / topw.sum(axis=-1, keepdims=True)
        saved[f"route{l}_experts"] = top
        saved[f"route{l}_weights"] = w_norm
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
            g = xe @ gate[e].T
            u = xe @ up[e].T
            act = (g / (1.0 + np.exp(-g))) * u
            y = act @ down[e].T
            out[toks] += y * w_norm[toks, slots][:, None].astype(np.float32)
        states[0] = states[0] + out
        saved[f"ffn{l}"] = states[0].copy()
        return states

    states_l = [states]
    for l in range(model.n_layer):
        states_l = layer_dump(l, states_l, sink)
        print(f"layer {l} dumped", flush=True)
    final = states_l[0]
    out_w = model.deq("output.weight")
    out_n = model.deq("output_norm.weight")
    normed = rms_norm(final, out_n, model.eps)
    logits = normed @ out_w.T
    saved["final"] = final
    saved["normed"] = normed
    saved["logits"] = logits
    np.savez(out_path, **saved)
    top5 = np.argsort(-logits[-1])[:5]
    print("last-position top5:", [(int(i), float(logits[-1][i])) for i in top5])
    print("saved", out_path)


if __name__ == "__main__":
    main()
