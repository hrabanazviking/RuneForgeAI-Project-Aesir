#!/usr/bin/env python3
"""J-016 reference router instrument (Project Aesir, Janas clean-room road).

A purpose-built OLMoE forward pass, implemented from the GGUF file's own
tensors (gguf-py dequantization + numpy float32), whose ONLY product is the
router trace: for every token, every layer, the top-k experts the router
selects, their renormalized weights, and the selection margin (probability
gap between the k-th and (k+1)-th expert).

This is NOT Aesir's engine (Aesir has no MoE code at all — J-012) and it is
not llama.cpp. It is a named reference instrument of this slice, run on
purplelongship, CPU-only, thread-capped. Its traces are labelled
"trace_kind": "measured" with this instrument named in the header.

Method notes (the choices a reader needs to judge the traces):
  * Full prefill forward per prompt (causal attention, float32), prompts
    processed layer-major so every weight is dequantized exactly once.
  * Architecture from the GGUF metadata + tensor map (J-015): 16 layers,
    hidden 2048, MHA 16 heads x 128, RoPE base 10000 (NeoX rotate-half,
    the HF/GGUF convention), RMSNorm eps 1e-5, router = softmax over
    ffn_gate_inp logits, top-8, weights renormalized to sum 1 (the
    published OLMoE routing rule), expert = down(silu(gate(x)) * up(x)).
  * QK-norm: the file stores a 2048-wide q_norm/k_norm. Two readings exist
    (per-head RMS over 128 with the vector viewed as (16, 128), or one RMS
    over the full 2048). --qknorm chooses; the slice ran both on the prose
    prompt and kept the reading whose next-token distribution is coherent
    (experiment recorded in the J-016 document).
  * Tokenizer: GPT-2 byte-level BPE rebuilt from the GGUF vocab + merges,
    with an ASCII-safe approximation of the 'olmo' pre-tokenizer split
    (letter runs / digit runs of <=3 / space-prefixed words / punctuation
    runs). The file declares add_bos_token=false, so no BOS is added.
    Every prompt is round-trip checked (decode(encode(x)) == x) before
    the forward runs; a failed check aborts the run.
  * A greedy continuation of the prose prompt is computed as a coherence
    witness and its tokens are appended to the trace (phase "gen").

Usage:
  j016_router_forward.py --gguf PATH --prompts PROMPTS.txt --out TRACE.jsonl
      [--qknorm perhead|full] [--gen-tokens 12] [--only-first-prompt]
Writes a human log to stdout (token counts, top-5 next-token predictions,
the greedy continuation, margins summary).
"""
import argparse
import json
import math
import re
import sys
import time

import numpy as np

# --------------------------------------------------------------------------
# GPT-2 byte-level BPE from the GGUF vocab/merges
# --------------------------------------------------------------------------

def bytes_to_unicode():
    bs = list(range(ord("!"), ord("~") + 1)) + list(range(ord("¡"), ord("¬") + 1)) + list(range(ord("®"), ord("ÿ") + 1))
    cs = bs[:]
    n = 0
    for b in range(256):
        if b not in bs:
            bs.append(b)
            cs.append(256 + n)
            n += 1
    return {b: chr(c) for b, c in zip(bs, cs)}


PRE_RE = re.compile(r"'(?:[sdmt]|ll|ve|re)| ?[A-Za-z]+| ?[0-9]{1,3}| ?[^\sA-Za-z0-9]+|\s+(?!\S)|\s+")


class Gpt2Bpe:
    def __init__(self, tokens, merges):
        self.encoder = {tok: i for i, tok in enumerate(tokens)}
        self.decoder = {i: tok for tok, i in self.encoder.items()}
        self.b2u = bytes_to_unicode()
        self.u2b = {v: k for k, v in self.b2u.items()}
        self.ranks = {}
        for rank, m in enumerate(merges):
            a, _, b = m.partition(" ")
            self.ranks[(a, b)] = rank
        self.cache = {}

    def _bpe(self, word):
        if word in self.cache:
            return self.cache[word]
        parts = list(word)
        while len(parts) > 1:
            best, best_rank = None, None
            for i in range(len(parts) - 1):
                r = self.ranks.get((parts[i], parts[i + 1]))
                if r is not None and (best_rank is None or r < best_rank):
                    best, best_rank = i, r
            if best is None:
                break
            parts = parts[:best] + [parts[best] + parts[best + 1]] + parts[best + 2:]
        self.cache[word] = parts
        return parts

    def encode(self, text):
        ids = []
        for chunk in PRE_RE.findall(text):
            mapped = "".join(self.b2u[b] for b in chunk.encode("utf-8"))
            for piece in self._bpe(mapped):
                ids.append(self.encoder[piece])
        return ids

    def decode(self, ids):
        mapped = "".join(self.decoder[i] for i in ids)
        raw = bytearray()
        for c in mapped:
            b = self.u2b.get(c)
            if b is None:
                # special tokens (e.g. <|endoftext|>) are stored literally,
                # not in byte-mapped form; pass their characters through.
                raw.extend(c.encode("utf-8"))
            else:
                raw.append(b)
        return bytes(raw).decode("utf-8", errors="replace")


# --------------------------------------------------------------------------
# OLMoE forward (layer-major over a batch of prompts)
# --------------------------------------------------------------------------

def rms_norm(x, w, eps):
    return x * (1.0 / np.sqrt(np.mean(x * x, axis=-1, keepdims=True) + eps)) * w


class OlmoeForward:
    def __init__(self, gguf_path, qknorm):
        import gguf
        self.gguf = gguf
        self.r = gguf.GGUFReader(gguf_path)
        self.T = {t.name: t for t in self.r.tensors}
        f = self.r.fields
        def scalar(key):
            fld = f[key]
            return np.asarray(fld.parts[fld.data[0]]).reshape(-1)[0]
        self.n_layer = int(scalar("olmoe.block_count"))
        self.hidden = int(scalar("olmoe.embedding_length"))
        self.n_head = int(scalar("olmoe.attention.head_count"))
        self.n_expert = int(scalar("olmoe.expert_count"))
        self.top_k = int(scalar("olmoe.expert_used_count"))
        self.eps = float(scalar("olmoe.attention.layer_norm_rms_epsilon"))
        self.rope_base = float(scalar("olmoe.rope.freq_base"))
        self.head_dim = self.hidden // self.n_head
        self.qknorm = qknorm
        # tokenizer
        tf = f["tokenizer.ggml.tokens"]
        tokens = [bytes(tf.parts[i]).decode("utf-8") for i in tf.data]
        mf = f["tokenizer.ggml.merges"]
        merges = [bytes(mf.parts[i]).decode("utf-8") for i in mf.data]
        self.tok = Gpt2Bpe(tokens, merges)
        self.expert_bytes_per_layer = []
        for l in range(self.n_layer):
            tot = 0
            for nm in ("ffn_gate_exps", "ffn_up_exps", "ffn_down_exps"):
                t = self.T[f"blk.{l}.{nm}.weight"]
                tot += int(t.data.nbytes)
            self.expert_bytes_per_layer.append(tot // self.n_expert)

    def deq(self, name):
        t = self.T[name]
        return self.gguf.quants.dequantize(t.data, t.tensor_type)

    def rope(self, x, positions):
        # x: (T, n_head, head_dim) NeoX rotate-half convention
        half = self.head_dim // 2
        inv_freq = 1.0 / (self.rope_base ** (np.arange(0, half, dtype=np.float32) / half))
        ang = positions[:, None].astype(np.float32) * inv_freq[None, :]  # (T, half)
        cos = np.cos(ang)[:, None, :]  # (T, 1, half)
        sin = np.sin(ang)[:, None, :]
        x1, x2 = x[..., :half], x[..., half:]
        rot = np.concatenate([x1 * cos - x2 * sin, x2 * cos + x1 * sin], axis=-1)
        return rot

    def layer(self, l, states, trace_sink):
        """states: list of (T, hidden) float32 hidden states, one per prompt.
        trace_sink: list per prompt of per-token layer records (appended)."""
        T0 = self.deq(f"blk.{l}.attn_norm.weight")
        Wq = self.deq(f"blk.{l}.attn_q.weight"); Wk = self.deq(f"blk.{l}.attn_k.weight")
        Wv = self.deq(f"blk.{l}.attn_v.weight"); Wo = self.deq(f"blk.{l}.attn_output.weight")
        wqn = self.deq(f"blk.{l}.attn_q_norm.weight"); wkn = self.deq(f"blk.{l}.attn_k_norm.weight")
        for pi, h in enumerate(states):
            x = rms_norm(h, T0, self.eps)
            q = (x @ Wq.T).reshape(-1, self.n_head, self.head_dim)
            k = (x @ Wk.T).reshape(-1, self.n_head, self.head_dim)
            v = (x @ Wv.T).reshape(-1, self.n_head, self.head_dim)
            if self.qknorm == "perhead":
                q = rms_norm(q, wqn.reshape(self.n_head, self.head_dim), self.eps)
                k = rms_norm(k, wkn.reshape(self.n_head, self.head_dim), self.eps)
            else:
                q = rms_norm(q.reshape(-1, self.hidden), wqn, self.eps).reshape(-1, self.n_head, self.head_dim)
                k = rms_norm(k.reshape(-1, self.hidden), wkn, self.eps).reshape(-1, self.n_head, self.head_dim)
            pos = np.arange(h.shape[0])
            q = self.rope(q, pos); k = self.rope(k, pos)
            # attention: (heads, T, T)
            scale = 1.0 / math.sqrt(self.head_dim)
            scores = np.einsum("thd,shd->hts", q, k) * scale
            mask = np.triu(np.ones(scores.shape[-2:], dtype=bool), k=1)
            scores = np.where(mask[None], -1e30, scores)
            scores = scores - scores.max(axis=-1, keepdims=True)
            p = np.exp(scores); p /= p.sum(axis=-1, keepdims=True)
            att = np.einsum("hts,shd->thd", p, v).reshape(-1, self.hidden)
            states[pi] = h + att @ Wo.T
        del Wq, Wk, Wv, Wo

        # --- MoE block ---
        wfn = self.deq(f"blk.{l}.ffn_norm.weight")
        Wr = self.deq(f"blk.{l}.ffn_gate_inp.weight")  # (E, hidden) F32
        normed = [rms_norm(h, wfn, self.eps) for h in states]
        # router first for every prompt (records the trace)
        selections = []
        for pi, x in enumerate(normed):
            logits = x @ Wr.T
            logits = logits - logits.max(axis=-1, keepdims=True)
            probs = np.exp(logits); probs /= probs.sum(axis=-1, keepdims=True)
            idx = np.argpartition(-probs, self.top_k + 1, axis=-1)
            top = idx[:, :self.top_k]
            order = np.argsort(-np.take_along_axis(probs, top, axis=-1), axis=-1)
            top = np.take_along_axis(top, order, axis=-1)
            topw = np.take_along_axis(probs, top, axis=-1)
            # margin = (k-th largest) minus ((k+1)-th largest), computed exactly
            sorted_p = np.sort(probs, axis=-1)
            margin = sorted_p[:, -self.top_k] - sorted_p[:, -self.top_k - 1]
            w_norm = topw / topw.sum(axis=-1, keepdims=True)
            selections.append((top, w_norm))
            for t in range(x.shape[0]):
                trace_sink[pi][t].append({
                    "experts": [int(e) for e in top[t]],
                    "weights": [round(float(w), 6) for w in w_norm[t]],
                    "margin": round(float(margin[t]), 6),
                })
        # experts: dequantize fused tensors once per layer, apply per prompt
        gate = self.deq(f"blk.{l}.ffn_gate_exps.weight")  # (E, ffn, hidden)
        up = self.deq(f"blk.{l}.ffn_up_exps.weight")
        down = self.deq(f"blk.{l}.ffn_down_exps.weight")  # (E, hidden, ffn)
        for pi, x in enumerate(normed):
            top, w_norm = selections[pi]
            out = np.zeros_like(x)
            for e in range(self.n_expert):
                rows = np.argwhere(top == e)
                if rows.size == 0:
                    continue
                toks, slots = rows[:, 0], rows[:, 1]
                xe = x[toks]
                g = xe @ gate[e].T
                u = xe @ up[e].T
                act = (g / (1.0 + np.exp(-g))) * u  # silu(gate) * up
                y = act @ down[e].T
                out[toks] += y * w_norm[toks, slots][:, None].astype(np.float32)
            states[pi] = states[pi] + out
        return states


def parse_prompts(path):
    text = open(path).read()
    prompts = []
    cur_id, buf = None, []
    for line in text.splitlines():
        m = re.match(r"=== (.+) ===$", line.strip())
        if m:
            if cur_id is not None:
                prompts.append((cur_id, "\n".join(buf).strip("\n")))
            cur_id, buf = m.group(1), []
        else:
            buf.append(line)
    if cur_id is not None:
        prompts.append((cur_id, "\n".join(buf).strip("\n")))
    return [(pid, txt.strip()) for pid, txt in prompts if txt.strip()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gguf", required=True)
    ap.add_argument("--prompts", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--qknorm", choices=["perhead", "full"], default="perhead")
    ap.add_argument("--gen-tokens", type=int, default=12)
    ap.add_argument("--only-first-prompt", action="store_true")
    ap.add_argument("--log", default=None)
    args = ap.parse_args()
    log_lines = []
    def log(*a):
        s = " ".join(str(x) for x in a)
        log_lines.append(s)
        print(s, flush=True)

    t_start = time.time()
    model = OlmoeForward(args.gguf, args.qknorm)
    log(f"model loaded: layers={model.n_layer} hidden={model.hidden} heads={model.n_head} "
        f"experts={model.n_expert} top_k={model.top_k} eps={model.eps} rope_base={model.rope_base} qknorm={args.qknorm}")
    log(f"expert_bytes_per_layer={model.expert_bytes_per_layer}")

    prompts = parse_prompts(args.prompts)
    if args.only_first_prompt:
        prompts = prompts[:1]
    enc = []
    for pid, txt in prompts:
        ids = model.tok.encode(txt)
        rt = model.tok.decode(ids)
        if rt != txt:
            log(f"FATAL round-trip mismatch for prompt {pid!r}")
            sys.exit(3)
        enc.append((pid, ids))
        log(f"prompt {pid}: {len(ids)} tokens (round-trip OK)")

    emb = model.deq("token_embd.weight")
    states = [emb[np.array(ids, dtype=np.int64)].astype(np.float32).copy() for _, ids in enc]
    del emb
    trace = [[[] for _ in ids] for _, ids in enc]  # trace[pi][t] = list per layer
    for l in range(model.n_layer):
        t0 = time.time()
        states = model.layer(l, states, trace)
        log(f"layer {l} done in {time.time() - t0:.1f}s")

    out_w = model.deq("output.weight")
    out_n = model.deq("output_norm.weight")
    records = []
    for pi, (pid, ids) in enumerate(enc):
        h = rms_norm(states[pi], out_n, model.eps)
        logits = h[-1] @ out_w.T
        top5 = np.argsort(-logits)[:5]
        lp = logits - logits.max(); pr = np.exp(lp); pr /= pr.sum()
        log(f"prompt {pid} last-token top5: " + ", ".join(
            f"{model.tok.decode([int(i)])!r} p={pr[i]:.3f}" for i in top5))
    # greedy continuation of prompt 0 (prefill states already computed for it;
    # recompute incrementally with full-sequence forwards per new token)
    gen_ids = []
    if args.gen_tokens > 0:
        pid0, ids0 = enc[0]
        cur = list(ids0)
        for step in range(args.gen_tokens):
            emb = model.deq("token_embd.weight")
            st = [emb[np.array(cur, dtype=np.int64)].astype(np.float32).copy()]
            del emb
            sink = [[[] for _ in cur]]
            for l in range(model.n_layer):
                st = model.layer(l, st, sink)
            h = rms_norm(st[0], out_n, model.eps)
            nxt = int(np.argmax(h[-1] @ out_w.T))
            gen_ids.append(nxt)
            cur.append(nxt)
            # record routing of the newly generated token (last position)
            records.append({"prompt_id": pid0, "phase": "gen", "pos": len(cur) - 1,
                            "token_id": nxt, "layers_rec": sink[0][-1]})
        log(f"greedy continuation of {pid0}: {model.tok.decode(gen_ids)!r}")

    with open(args.out, "w") as fo:
        header = {
            "type": "header", "trace_kind": "measured",
            "model": "allenai/OLMoE-1B-7B-0924-Instruct-GGUF olmoe-1b-7b-0924-instruct-q4_k_m.gguf",
            "model_sha256": "8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f",
            "arch": "olmoe", "n_layer": model.n_layer, "n_expert": model.n_expert,
            "top_k": model.top_k,
            "instrument": "j016_router_forward.py (GGUF-tensor reference forward, gguf-py dequant + numpy float32 prefill; NOT the Aesir engine)",
            "hardware": "purplelongship (AMD Ryzen 9 4900HS), CPU only, thread-capped",
            "qknorm": args.qknorm,
            "expert_bytes_per_layer": model.expert_bytes_per_layer,
        }
        fo.write(json.dumps(header) + "\n")
        for pi, (pid, ids) in enumerate(enc):
            for t, tid in enumerate(ids):
                layers = [rec["experts"] for rec in trace[pi][t]]
                weights = [rec["weights"] for rec in trace[pi][t]]
                margins = [rec["margin"] for rec in trace[pi][t]]
                fo.write(json.dumps({"type": "token", "prompt_id": pid, "phase": "prompt",
                                     "pos": t, "token_id": int(tid), "layers": layers,
                                     "weights": weights, "margins": margins}) + "\n")
        for rec in records:
            layers = [r["experts"] for r in rec["layers_rec"]]
            weights = [r["weights"] for r in rec["layers_rec"]]
            margins = [r["margin"] for r in rec["layers_rec"]]
            fo.write(json.dumps({"type": "token", "prompt_id": rec["prompt_id"], "phase": "gen",
                                 "pos": rec["pos"], "token_id": rec["token_id"], "layers": layers,
                                 "weights": weights, "margins": margins}) + "\n")
        fo.write(json.dumps({"type": "end"}) + "\n")
    margins_all = [rec["margin"] for pi in range(len(enc)) for t in trace[pi] for rec in t]
    margins_all = np.array(margins_all)
    log(f"margins (k-th minus (k+1)-th router prob): mean={margins_all.mean():.4f} "
        f"median={np.median(margins_all):.4f} frac<0.01={(margins_all < 0.01).mean():.3f} "
        f"frac<0.001={(margins_all < 0.001).mean():.3f}")
    log(f"total wall {time.time() - t_start:.1f}s; trace written to {args.out}")
    if args.log:
        open(args.log, "w").write("\n".join(log_lines) + "\n")


if __name__ == "__main__":
    main()
