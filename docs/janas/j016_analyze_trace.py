#!/usr/bin/env python3
"""J-016 router-trace analysis tool (Project Aesir, Janas clean-room road).

Reads a router trace in the J-016 trace format (JSON Lines) and computes the
measurements the Part II cache decisions stand on:

  * expert hit distribution (aggregate and per layer): counts, share,
    entropy, dead experts, hottest experts;
  * reuse distance (LRU stack distance over the (layer, expert) access
    stream, plus token-gap between successive uses of the same expert);
  * working-set size over sliding token windows (distinct (layer, expert)
    pairs, and the implied streamed bytes when per-expert byte sizes are
    supplied in the trace header);
  * cold vs repeated experts (first-use accounting, per prompt and global);
  * per-token routed-expert counts (integrity check against top-k);
  * LRU and LFU cache simulations at several capacities (offline policy
    evidence for J-018 / J-024; simulation on a recorded trace, not a live
    run).

Trace format (one JSON object per line):
  {"type": "header", "model": ..., "arch": ..., "n_layer": L,
   "n_expert": E, "top_k": K, "instrument": ..., "hardware": ...,
   "expert_bytes_per_layer": [bytes per expert for layer 0..L-1]  (optional)}
  {"type": "token", "prompt_id": str, "pos": int, "token_id": int,
   "layers": [[expert, ...] x L]}        # each inner list has top_k experts
  {"type": "token", ..., "weights": [[float, ...] x L]}   (optional)
  {"type": "end"}

Honesty: this tool only ever analyses a trace file it is given. Whether the
trace itself is real or synthetic is a property of the trace's header
("trace_kind": "measured" | "synthetic-validation"), and the analysis
output repeats that label verbatim so the two can never be confused
downstream.

Usage: j016_analyze_trace.py TRACE.jsonl [--windows 32,128,512]
       [--cache-sizes 256,1024,4096] [--out STATS.json]
Exit 0 on success; exit 2 on a malformed trace (integrity failure).
"""
import argparse
import json
import math
import sys
from collections import Counter, OrderedDict


def load_trace(path):
    header = None
    tokens = []
    with open(path) as f:
        for ln, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                raise ValueError(f"line {ln}: bad JSON: {e}")
            t = obj.get("type")
            if t == "header":
                if header is not None:
                    raise ValueError(f"line {ln}: duplicate header")
                header = obj
            elif t == "token":
                tokens.append(obj)
            elif t == "end":
                break
            else:
                raise ValueError(f"line {ln}: unknown record type {t!r}")
    if header is None:
        raise ValueError("no header record")
    for key in ("n_layer", "n_expert", "top_k"):
        if key not in header:
            raise ValueError(f"header missing {key}")
    return header, tokens


def check_integrity(header, tokens):
    L, K = header["n_layer"], header["top_k"]
    problems = []
    for i, tok in enumerate(tokens):
        layers = tok.get("layers")
        if layers is None or len(layers) != L:
            problems.append(f"token {i}: layers length != {L}")
            continue
        for l, sel in enumerate(layers):
            if len(sel) != K:
                problems.append(f"token {i} layer {l}: {len(sel)} experts != top_k {K}")
            if len(set(sel)) != len(sel):
                problems.append(f"token {i} layer {l}: duplicate expert in one selection")
            for e in sel:
                if not (0 <= e < header["n_expert"]):
                    problems.append(f"token {i} layer {l}: expert {e} out of range")
        if len(problems) > 20:
            break
    return problems


def percentile(sorted_vals, p):
    if not sorted_vals:
        return None
    idx = min(len(sorted_vals) - 1, max(0, math.ceil(p / 100.0 * len(sorted_vals)) - 1))
    return sorted_vals[idx]


def entropy_bits(counter, total):
    h = 0.0
    for c in counter.values():
        if c:
            q = c / total
            h -= q * math.log2(q)
    return h


class LRUCache:
    def __init__(self, cap):
        self.cap = cap
        self.od = OrderedDict()
        self.hits = 0
        self.misses = 0

    def access(self, key):
        if key in self.od:
            self.od.move_to_end(key)
            self.hits += 1
            return True
        self.misses += 1
        if self.cap > 0:
            self.od[key] = True
            if len(self.od) > self.cap:
                self.od.popitem(last=False)
        return False


class LFUCache:
    def __init__(self, cap):
        self.cap = cap
        self.freq = Counter()
        self.present = OrderedDict()  # recency order among present keys
        self.hits = 0
        self.misses = 0

    def access(self, key):
        self.freq[key] += 1
        if key in self.present:
            self.present.move_to_end(key)
            self.hits += 1
            return True
        self.misses += 1
        if self.cap > 0:
            if len(self.present) >= self.cap:
                # evict least-frequently-used; ties broken by least-recent
                victim = min(self.present.keys(), key=lambda k: self.freq[k])
                del self.present[victim]
            self.present[key] = True
        return False


def analyse(header, tokens, windows, cache_sizes):
    L, E, K = header["n_layer"], header["n_expert"], header["top_k"]
    n_tok = len(tokens)
    expert_bytes = header.get("expert_bytes_per_layer")

    # Access stream: (layer, expert) in token order, selection order as recorded.
    stream = []
    for tok in tokens:
        for l, sel in enumerate(tok["layers"]):
            for e in sel:
                stream.append((l, e))
    total_accesses = len(stream)

    # ---- Hit distribution -------------------------------------------------
    agg = Counter(e for (_, e) in stream)
    per_layer = [Counter() for _ in range(L)]
    for (l, e) in stream:
        per_layer[l][e] += 1
    agg_sorted = sorted(agg.items(), key=lambda kv: -kv[1])
    hit_dist = {
        "total_accesses": total_accesses,
        "distinct_experts_hit_aggregate": len(agg),
        "dead_experts_aggregate": E - len(agg),
        "entropy_bits": round(entropy_bits(agg, total_accesses), 4) if total_accesses else None,
        "entropy_max_bits": round(math.log2(E), 4),
        "top10": [{"expert": e, "hits": c, "share": round(c / total_accesses, 6)} for e, c in agg_sorted[:10]],
        "bottom_share": round(sum(c for _, c in agg_sorted[-10:]) / total_accesses, 6) if total_accesses else None,
        "per_layer": [],
    }
    for l in range(L):
        c = per_layer[l]
        tot = sum(c.values())
        srt = sorted(c.items(), key=lambda kv: -kv[1])
        hit_dist["per_layer"].append({
            "layer": l,
            "accesses": tot,
            "distinct_hit": len(c),
            "dead": E - len(c),
            "entropy_bits": round(entropy_bits(c, tot), 4) if tot else None,
            "top5": [{"expert": e, "hits": n} for e, n in srt[:5]],
        })

    # ---- Reuse distance ----------------------------------------------------
    # Stack distance: number of distinct (layer, expert) pairs touched since
    # the previous access of the same pair; cold (first) accesses separated.
    stack_dists = []
    token_gaps = []
    last_tok_idx = {}
    cold = 0
    # Stack distance via a Fenwick tree over stream positions: the tree holds
    # a 1 at each pair's most recent access position, so the number of
    # distinct pairs touched since the previous access of a pair is the
    # range sum between the two positions. O(n log n) for any trace size.
    n_stream = len(stream)
    bit = [0] * (n_stream + 2)

    def bit_add(i, delta):
        i += 1
        while i <= n_stream + 1:
            bit[i] += delta
            i += i & -i

    def bit_sum(i):  # sum over [0, i)
        s = 0
        while i > 0:
            s += bit[i]
            i -= i & -i
        return s

    last_pos = {}
    for idx, key in enumerate(stream):
        prev = last_pos.get(key)
        if prev is None:
            cold += 1
        else:
            stack_dists.append(bit_sum(idx) - bit_sum(prev + 1))
            bit_add(prev, -1)
        bit_add(idx, +1)
        last_pos[key] = idx
    for ti, tok in enumerate(tokens):
        keys = {(l, e) for l, sel in enumerate(tok["layers"]) for e in sel}
        for key in keys:
            if key in last_tok_idx:
                token_gaps.append(ti - last_tok_idx[key])
            last_tok_idx[key] = ti
    stack_dists.sort()
    token_gaps.sort()
    reuse = {
        "cold_accesses": cold,
        "cold_fraction": round(cold / total_accesses, 6) if total_accesses else None,
        "repeat_accesses": total_accesses - cold,
        "stack_distance": {
            "mean": round(sum(stack_dists) / len(stack_dists), 3) if stack_dists else None,
            "median": percentile(stack_dists, 50),
            "p90": percentile(stack_dists, 90),
            "max": stack_dists[-1] if stack_dists else None,
        },
        "token_gap_between_uses": {
            "mean": round(sum(token_gaps) / len(token_gaps), 3) if token_gaps else None,
            "median": percentile(token_gaps, 50),
            "p90": percentile(token_gaps, 90),
            "max": token_gaps[-1] if token_gaps else None,
        },
    }

    # ---- Working set over sliding windows ----------------------------------
    ws = {}
    per_token_keys = []
    for tok in tokens:
        per_token_keys.append({(l, e) for l, sel in enumerate(tok["layers"]) for e in sel})
    for W in windows:
        if n_tok == 0:
            ws[str(W)] = None
            continue
        sizes = []
        byte_sizes = []
        counts = Counter()
        # sliding distinct count with add/remove
        def add(keys, delta):
            for k in keys:
                counts[k] += delta
                if counts[k] == 0:
                    del counts[k]
        for i in range(n_tok):
            add(per_token_keys[i], +1)
            if i >= W:
                add(per_token_keys[i - W], -1)
            if i >= W - 1 or i == n_tok - 1:
                sizes.append(len(counts))
                if expert_bytes:
                    byte_sizes.append(sum(expert_bytes[l] for (l, _) in counts))
        entry = {
            "mean_distinct_pairs": round(sum(sizes) / len(sizes), 2) if sizes else None,
            "max_distinct_pairs": max(sizes) if sizes else None,
            "min_distinct_pairs": min(sizes) if sizes else None,
            "of_total_pairs": L * E,
        }
        if byte_sizes:
            entry["mean_bytes"] = int(sum(byte_sizes) / len(byte_sizes))
            entry["max_bytes"] = max(byte_sizes)
        ws[str(W)] = entry
    full_ws = len({k for keys in per_token_keys for k in keys})
    ws["full_trace"] = {"distinct_pairs": full_ws, "of_total_pairs": L * E}
    if expert_bytes:
        all_keys = {k for keys in per_token_keys for k in keys}
        ws["full_trace"]["bytes"] = int(sum(expert_bytes[l] for (l, _) in all_keys))

    # ---- Cold vs repeated, per prompt --------------------------------------
    prompts = {}
    seen_global = set()
    cold_global_first = 0
    order = []
    for tok in tokens:
        pid = tok.get("prompt_id", "?")
        if pid not in prompts:
            prompts[pid] = {"tokens": 0, "accesses": 0, "cold_first_use_in_prompt": 0,
                            "pairs": set(), "per_prompt_seen": set()}
            order.append(pid)
        p = prompts[pid]
        p["tokens"] += 1
        for l, sel in enumerate(tok["layers"]):
            for e in sel:
                p["accesses"] += 1
                key = (l, e)
                p["pairs"].add(key)
                if key not in p["per_prompt_seen"]:
                    p["per_prompt_seen"].add(key)
                    p["cold_first_use_in_prompt"] += 1
                if key not in seen_global:
                    seen_global.add(key)
                    cold_global_first += 1
    per_prompt = {}
    for pid in order:
        p = prompts[pid]
        per_prompt[pid] = {
            "tokens": p["tokens"],
            "accesses": p["accesses"],
            "distinct_pairs": len(p["pairs"]),
            "cold_first_use_in_prompt": p["cold_first_use_in_prompt"],
        }

    # ---- Per-token routed counts -------------------------------------------
    per_token_counts = [sum(len(sel) for sel in tok["layers"]) for tok in tokens]
    distinct_per_token = [len(keys) for keys in per_token_keys]
    distinct_experts_per_token = [len({e for sel in tok["layers"] for e in sel}) for tok in tokens]
    routed = {
        "expected_per_token": L * K,
        "all_tokens_match_topk_x_layers": all(c == L * K for c in per_token_counts),
        "distinct_pairs_per_token_mean": round(sum(distinct_per_token) / len(distinct_per_token), 3) if n_tok else None,
        "distinct_pairs_per_token_max": max(distinct_per_token) if n_tok else None,
        "distinct_expert_ids_per_token_mean": round(sum(distinct_experts_per_token) / len(distinct_experts_per_token), 3) if n_tok else None,
        "distinct_expert_ids_per_token_min": min(distinct_experts_per_token) if n_tok else None,
        "distinct_expert_ids_per_token_max": max(distinct_experts_per_token) if n_tok else None,
    }

    # ---- Cache simulations (offline, on this trace) -------------------------
    sims = {}
    for cap in cache_sizes:
        lru = LRUCache(cap)
        lfu = LFUCache(cap)
        for key in stream:
            lru.access(key)
            lfu.access(key)
        tot = total_accesses or 1
        sims[str(cap)] = {
            "capacity_pairs": cap,
            "lru_hit_rate": round(lru.hits / tot, 6),
            "lfu_hit_rate": round(lfu.hits / tot, 6),
        }
        if expert_bytes:
            # capacity expressed in bytes is capacity_pairs x mean expert size;
            # report the byte size of this pair-capacity at the mean layer size.
            sims[str(cap)]["approx_bytes_at_mean_expert"] = int(cap * (sum(expert_bytes) / len(expert_bytes)))

    return {
        "trace_kind": header.get("trace_kind", "unspecified"),
        "model": header.get("model"),
        "arch": header.get("arch"),
        "instrument": header.get("instrument"),
        "n_tokens": n_tok,
        "n_prompts": len(per_prompt),
        "prompts": per_prompt,
        "hit_distribution": hit_dist,
        "reuse": reuse,
        "working_set": ws,
        "routed_counts": routed,
        "cache_simulation": sims,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description="J-016 router-trace analysis")
    ap.add_argument("trace")
    ap.add_argument("--windows", default="32,128,512")
    ap.add_argument("--cache-sizes", default="128,256,512,1024,2048,4096")
    ap.add_argument("--out")
    args = ap.parse_args(argv)

    try:
        header, tokens = load_trace(args.trace)
    except (OSError, ValueError) as e:
        print(f"ERROR loading trace: {e}", file=sys.stderr)
        return 2
    problems = check_integrity(header, tokens)
    if problems:
        print("INTEGRITY FAILURE:", file=sys.stderr)
        for p in problems[:20]:
            print(f"  {p}", file=sys.stderr)
        return 2
    windows = [int(x) for x in args.windows.split(",") if x.strip()]
    cache_sizes = [int(x) for x in args.cache_sizes.split(",") if x.strip()]
    stats = analyse(header, tokens, windows, cache_sizes)
    stats["integrity"] = "PASS (every token has n_layer selections of top_k distinct in-range experts)"
    out = json.dumps(stats, indent=1)
    if args.out:
        with open(args.out, "w") as f:
            f.write(out + "\n")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
