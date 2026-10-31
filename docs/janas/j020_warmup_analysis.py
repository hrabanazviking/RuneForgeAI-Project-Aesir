#!/usr/bin/env python3
"""J-020 warm-up pass evaluation on the J-016 OLMoE trace.

Question (roadmap J-020 + J-017 section 5.2 constraint): are any early
experts predictable enough that prefetching them during prompt reading
pays? Tested, not assumed, three ways:

A. Structure: first-token demand overlap across prompts (pairwise,
   per-layer top-1 agreement), consecutive-token demand persistence,
   global frequency coverage (the hot-set question restated for
   warm-up-sized sets).
B. Coverage (policy-free, leave-one-prompt-out): candidate predictor
   sets built ONLY from the other five prompts; coverage of the held-out
   prompt's first token / first-8 window / full demand, and waste.
C. Cache-level simulation (the validated-exact J-018 replica,
   segmented policy, 512-pair byte budget): baseline cold run of the
   held-out prompt vs warm-up runs (prefetch charged in bytes, entries
   preloaded into the main segment, cap pressure + evicted-before-use
   counted). Net = prefetch + demand-streamed vs baseline streamed.

An ORACLE candidate (the held-out prompt's own first token) bounds what
any predictor could ever win on the first token.
"""
import json
import sys
from collections import Counter

sys.path.insert(0, "/home/hatch/workspace/model-tests/janas")
from j020_policy import ExpertCacheReplica, HIT

TRACE = "/home/hatch/workspace/model-tests/janas/j016_trace_olmoe.jsonl"
MEAN = 3720
BUDGET = 512 * MEAN

header = None
raw_tokens = []
for line in open(TRACE):
    d = json.loads(line)
    if d.get("type") == "header":
        header = d
    elif d.get("type") == "token":
        raw_tokens.append(d)
SIZES = [b // 1024 for b in header["expert_bytes_per_layer"]]
FULL = [b for b in header["expert_bytes_per_layer"]]

prompts = []  # (prompt_id, [token,...]) prompt-phase only, in order
for t in raw_tokens:
    if t["phase"] != "prompt":
        continue
    if not prompts or prompts[-1][0] != t["prompt_id"]:
        prompts.append((t["prompt_id"], []))
    prompts[-1][1].append(t)


def demand_pairs(tok):
    return [(L, e) for L, layer in enumerate(tok["layers"]) for e in layer]


def pair_bytes(p):
    return FULL[p[0]]


# ---------- A. structure ----------
def structure():
    out = {}
    firsts = [(pid, set(demand_pairs(toks[0]))) for pid, toks in prompts]
    inter = []
    for i in range(len(firsts)):
        for j in range(i + 1, len(firsts)):
            inter.append(len(firsts[i][1] & firsts[j][1]))
    out["first_token_pairwise_intersection_mean"] = sum(inter) / len(inter)
    out["first_token_pairwise_intersection_minmax"] = [min(inter), max(inter)]
    out["first_token_pairs_per_prompt"] = 128
    # per-layer top-1 (highest router weight) agreement at token 0
    agree = []
    for L in range(16):
        tops = []
        for pid, toks in prompts:
            t0 = toks[0]
            k = max(range(8), key=lambda i: t0["weights"][L][i])
            tops.append(t0["layers"][L][k])
        modal = Counter(tops).most_common(1)[0]
        agree.append({"layer": L, "modal_expert": modal[0],
                      "prompts_agreeing": modal[1]})
    out["token0_top1_per_layer"] = agree
    out["token0_top1_layers_modal_ge4"] = sum(
        1 for a in agree if a["prompts_agreeing"] >= 4)
    # consecutive-token persistence: recall of token t+1 demand by token t
    rec = []
    for pid, toks in prompts:
        for a, b in zip(toks, toks[1:]):
            sa, sb = set(demand_pairs(a)), set(demand_pairs(b))
            rec.append(len(sa & sb) / len(sb))
    out["consecutive_token_recall_mean"] = sum(rec) / len(rec)
    # global frequency coverage
    allc = Counter()
    for pid, toks in prompts:
        for t in toks:
            allc.update(demand_pairs(t))
    tot = sum(allc.values())
    cov = {}
    run = 0
    ranked = [p for p, _ in allc.most_common()]
    for n in (16, 32, 64, 128, 256, 512):
        cov[str(n)] = sum(allc[p] for p in ranked[:n]) / tot
    out["global_topN_access_coverage"] = cov
    out["distinct_pairs_total"] = len(allc)
    return out


# ---------- B/C. LOO candidates ----------
def ranked(counter, tiebreak):
    return sorted(counter, key=lambda p: (-counter[p], -tiebreak.get(p, 0),
                                          p[0], p[1]))


def candidates(source_toks_by_prompt, held_pid):
    src = [t for pid, toks in source_toks_by_prompt if pid != held_pid
           for t in toks]
    glob = Counter()
    for t in src:
        glob.update(demand_pairs(t))
    firstc = Counter()
    earlyc = Counter()
    for pid, toks in source_toks_by_prompt:
        if pid == held_pid:
            continue
        firstc.update(demand_pairs(toks[0]))
        for t in toks[:8]:
            earlyc.update(demand_pairs(t))
    cands = {}
    for n in (64, 128, 256):
        cands[f"GLOBFREQ-{n}"] = ranked(glob, glob)[:n]
    cands["FIRSTTOK-128"] = ranked(firstc, glob)[:128]
    cands["EARLY8-128"] = ranked(earlyc, glob)[:128]
    per2 = []
    for L in range(16):
        layer_first = Counter()
        for pid, toks in source_toks_by_prompt:
            if pid == held_pid:
                continue
            for e in toks[0]["layers"][L]:
                layer_first[(L, e)] += 1
        per2.extend(ranked(layer_first, glob)[:2])
    cands["PERLAYER2-32"] = per2
    return cands


def coverage_eval():
    rows = []
    for pid, toks in prompts:
        held_first = set(demand_pairs(toks[0]))
        held_early = set()
        for t in toks[:8]:
            held_early.update(demand_pairs(t))
        held_full = set()
        for t in toks:
            held_full.update(demand_pairs(t))
        cands = candidates(prompts, pid)
        oracle = sorted(held_first)
        cands["ORACLE-128"] = oracle
        for name, cand in cands.items():
            cs = set(cand)
            rows.append({
                "held_out": pid, "candidate": name, "n": len(cand),
                "prefetch_bytes": sum(pair_bytes(p) for p in cand),
                "token0_coverage": len(cs & held_first) / len(held_first),
                "early8_coverage": len(cs & held_early) / len(held_early),
                "full_coverage": len(cs & held_full) / len(held_full),
                "waste_fraction": len(cs - held_full) / len(cand),
            })
    return rows


def sim_eval():
    rows = []
    sim_cands = ["GLOBFREQ-64", "GLOBFREQ-128", "FIRSTTOK-128",
                 "EARLY8-128", "PERLAYER2-32", "ORACLE-128"]
    for pid, toks in prompts:
        accesses = [(L, e, SIZES[L]) for t in toks
                    for (L, e) in demand_pairs(t)]
        tok0_acc = accesses[:128]
        base = ExpertCacheReplica(BUDGET, "segmented")
        b_tok0 = 0
        for i, (L, e, sz) in enumerate(accesses):
            before = base.stats["bytes_streamed"]
            base.access(L, e, sz)
            if i < 128:
                b_tok0 += base.stats["bytes_streamed"] - before
        b_total = base.stats["bytes_streamed"]
        cands = candidates(prompts, pid)
        cands["ORACLE-128"] = sorted(set(demand_pairs(toks[0])))
        hint_all = Counter()
        for opid, otoks in prompts:
            if opid != pid:
                for t in otoks:
                    hint_all.update(demand_pairs(t))
        for name in sim_cands:
            cand = cands[name]
            pre = [(L, e, SIZES[L]) for (L, e) in cand]
            pre_bytes = sum(s for _, _, s in pre)
            c = ExpertCacheReplica(BUDGET, "segmented")
            c.preload(pre, freq_hint=hint_all)
            pre_keys = {(L, e) for (L, e) in cand}
            seen_first = {}
            w_tok0 = 0
            for i, (L, e, sz) in enumerate(accesses):
                if (L, e) in pre_keys and (L, e) not in seen_first:
                    seen_first[(L, e)] = c._find(L * 1048576 + e) >= 0
                before = c.stats["bytes_streamed"]
                c.access(L, e, sz)
                if i < 128:
                    w_tok0 += c.stats["bytes_streamed"] - before
            used = sum(1 for v in seen_first.values() if v)
            evicted_before_use = sum(
                1 for k, v in seen_first.items() if not v)
            never_accessed = len(pre_keys) - len(seen_first)
            rows.append({
                "held_out": pid, "candidate": name, "n": len(cand),
                "prefetch_bytes": pre_bytes * 1024,
                "baseline_streamed": b_total * 1024,
                "warmup_total_streamed": (pre_bytes
                                          + c.stats["bytes_streamed"]) * 1024,
                "net_saving_bytes": (b_total - pre_bytes
                                     - c.stats["bytes_streamed"]) * 1024,
                "baseline_token0_streamed": b_tok0 * 1024,
                "warmup_token0_streamed": w_tok0 * 1024,
                "prefetch_used_resident": used,
                "prefetch_evicted_before_use": evicted_before_use,
                "prefetch_never_accessed": never_accessed,
                "cap_fraction": pre_bytes / BUDGET,
            })
    return rows


def agg(rows, key="candidate"):
    out = {}
    for r in rows:
        out.setdefault(r[key], []).append(r)
    return {k: {f: sum(x[f] for x in v) / len(v)
                for f in v[0] if isinstance(v[0][f], (int, float))}
            for k, v in out.items()}


if __name__ == "__main__":
    result = {"structure": structure()}
    cov = coverage_eval()
    result["coverage_rows"] = cov
    result["coverage_mean"] = agg(cov)
    sim = sim_eval()
    result["sim_rows"] = sim
    result["sim_mean"] = agg(sim)
    with open("/tmp/j020/j020_warmup_results.json", "w") as f:
        json.dump(result, f, indent=1)
    s = result["structure"]
    print("first-token pairwise intersection mean:",
          s["first_token_pairwise_intersection_mean"], "/128, minmax",
          s["first_token_pairwise_intersection_minmax"])
    print("token0 top-1 layers with >=4/6 prompts agreeing:",
          s["token0_top1_layers_modal_ge4"], "/16")
    print("consecutive-token recall mean:",
          round(s["consecutive_token_recall_mean"], 4))
    print("global topN coverage:", {k: round(v, 4) for k, v in
                                    s["global_topN_access_coverage"].items()})
    print("\ncoverage means (LOO):")
    for k, v in result["coverage_mean"].items():
        print(f"  {k:16s} n={v['n']:.0f} tok0={v['token0_coverage']:.3f} "
              f"early8={v['early8_coverage']:.3f} full={v['full_coverage']:.3f} "
              f"waste={v['waste_fraction']:.3f} bytes={v['prefetch_bytes']:.0f}")
    print("\nsim means (segmented replica, LOO):")
    for k, v in result["sim_mean"].items():
        print(f"  {k:16s} net={v['net_saving_bytes']:.0f} B "
              f"({v['net_saving_bytes']/v['baseline_streamed']*100:.2f}% of baseline) "
              f"tok0 {v['baseline_token0_streamed']:.0f}->{v['warmup_token0_streamed']:.0f} "
              f"used={v['prefetch_used_resident']:.1f} "
              f"evict-before-use={v['prefetch_evicted_before_use']:.1f} "
              f"never={v['prefetch_never_accessed']:.1f} cap={v['cap_fraction']:.3f}")
