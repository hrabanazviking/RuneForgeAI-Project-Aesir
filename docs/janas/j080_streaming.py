#!/usr/bin/env python3
"""J-080 drafts + streaming measurement (Project Aesir, Janas road).

Roadmap text (J-080): "Drafts + streaming. Speculation over the
Part II expert stream: verification batches change expert demand;
cache interplay measured on the J-022 model (drafts are where MoE
speculation pays most, per Janas's headline)."

QUESTION. Sequential decode touches one token's routed experts at
a time, token-major (token, then layer). A speculative round
verifies k+1 positions in ONE pass: the pass is layer-major (for
each layer, all positions together), and positions past the first
rejection are computed and then discarded. What does that do to
the Part II expert cache (fsketch, the J-024 shipping default) --
hit rates, streamed bytes, evictions, wasted fetches -- versus
plain sequential decode, on the J-022 model (OLMoE Q4_K_M, pin
sha256 8c310f14...f3f) and its real demand (the J-016 trace,
sha256 85e1d241...cf99a, 73,856 accesses)?

MECHANISM (stated before measuring; the doc states the same).
A round starting at trace position s of one prompt verifies
width w = k+1 positions s..s+k (clipped at the prompt end).
Acceptance A in [0, k] is the accepted draft prefix length;
the round commits A+1 tokens (the prefix plus exactly one
target correction/bonus token, J-071) and the next round starts
at s+A+1. Positions s..s+A are USEFUL; positions s+A+1..s+k
are WASTED: a batched verify pass touches their routed experts
before the rejection is known, and that demand is discarded.
Because the trace records only the target's true continuation,
a wasted position's routed set is PROXIED by the true
continuation's set at the same offset (same access count, real
measured locality; NOT the draft's own routed set, which no
filed fact records). Every number that depends on the proxy
or on modelled acceptance is SIMULATED on the MEASURED trace.

ACCEPTANCE SOURCE (stated, honest). No live pair is admitted
on any filed fact (J-078/J-079 record stands), so acceptance is
MODELLED from the road's own filed fixtures: the per-round
would-be prefix lengths L are J-079 section 4's deterministic
cycles, shaped from J-075's filed fixture shapes --
  hot   [8,6,9,7,8,6,9,5]  (English-prose/code-like)
  cold  [1,0,2,1,1,0,1,2]  (Italian-prose-like collapse)
  mixed [3,1,4,0,2,5,1,3]  (structured-like spread)
A = min(k, L); the cycle advances one step per round, globally
across prompts in trace order. PERFECT (A = k always) is the
zero-waste ceiling, never a candidate. Fixed k in {2, 4, 8}
(J-079's baselines; 4 is J-072's initial depth).

DISCIPLINES (candidates stated before measuring).
  SEQ          token-major sequential decode (the base).
  BATCH-ALL    layer-major verify pass over all w positions,
               waste charged in full (the buildable shape: a
               batched forward cannot know the rejection point
               before it runs).
  BATCH-PREFIX layer-major verify pass over the useful
               positions only. NOT buildable as stated (it
               needs the rejection point in advance); it is the
               decomposition bound that separates the batching
               (reorder + sharing) effect from the waste effect:
               BATCH-ALL minus BATCH-PREFIX is the waste cost,
               BATCH-PREFIX minus SEQ is the reorder gain/loss.

COST ACCOUNTING. Every access goes through the J-024
tournament's FSketchCache (the demand path unchanged). A miss
streams its full pair size whether admitted or bypassed (the
simulator's accounting, identical to J-024/J-025). Streamed
bytes are normalised per EMITTED token (577 for every run --
rounds always emit the whole trace), never per access, so
waste cannot hide in a larger denominator. Waste fetches are
the misses among wasted accesses; evictions/admissions are
attributed to the access class that triggered them.

VERDICT RULE (pre-registered). At each operating budget
(128 and 512 pairs):
  - Speculation is CACHE-NEUTRAL-OR-BETTER in a (regime, k)
    cell iff BATCH-ALL streamed bytes per emitted token <= SEQ.
  - If no buildable cell is neutral-or-better but BATCH-PREFIX
    beats SEQ somewhere, the verdict is MIXED: batching itself
    pays, rejected-suffix waste more than eats it (both halves
    quantified).
  - If BATCH-PREFIX also never beats SEQ, the verdict is TAX:
    speculation imposes a streamed-bytes tax on this trace,
    quantified per regime/k/budget, to be weighed against
    tok/s at the J-086 gate (no speed is measured here; a
    latency/speed case is NOT PROVEN either way, exactly as
    J-025 section 7a binds its own verdict).
  The PERFECT regime is reported beside the modelled regimes:
  if even PERFECT BATCH-ALL costs bytes, the tax is in the
  batching itself, not in acceptance.

VALIDATION GATE (runs first; exit 3 on failure, no interplay
number is reported from a failed gate): the SEQ run of this
script's cache must reproduce, EXACTLY at 128/256/512, the
fsketch counters in j024_tournament_results.json (global runs),
AND at 128/512 the real-MoJo-module replay counters in
j024_replay_results.txt (J-024 integration record).

Usage: j080_streaming.py TRACE.jsonl J024_RESULTS.json
       [--out RESULTS.json]
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from j024_tournament import FSketchCache, load_stream, HIT  # noqa: E402

MEAN = 3720
BUDGETS = (128, 512)
KS = (2, 4, 8)
REGIMES = {
    "hot": [8, 6, 9, 7, 8, 6, 9, 5],
    "cold": [1, 0, 2, 1, 1, 0, 1, 2],
    "mixed": [3, 1, 4, 0, 2, 5, 1, 3],
    "perfect": None,  # A = k always; the zero-waste ceiling
}
MOJO_REPLAY = {
    128: dict(hits=25953, misses=47903, cold=1024, bypasses=46724,
              admissions=1179, evictions=1050, ebr=22335,
              streamed=178149792, entries=129, resident=474336),
    512: dict(hits=56781, misses=17075, cold=1024, bypasses=14895,
              admissions=2180, evictions=1668, ebr=12194,
              streamed=63662880, entries=512, resident=1903056),
}


def build_prompts(tokens, scaled_sizes):
    """Tokens grouped into CONTIGUOUS file-order segments (a new
    segment starts whenever prompt_id changes). File order is
    load-bearing: the trace files prose's 4 generation tokens
    AFTER the technical prompt, so grouping by prompt_id would
    move them and break the validation gate -- segments keep
    the exact J-024 global order for SEQ, and rounds never
    cross a segment boundary. Each token -> list over layers
    of (layer, expert, size). Returns (order, segments) with
    segments a list of token-lists in file order."""
    order = []
    segments = []
    prev = None
    for tok in tokens:
        pid = tok["prompt_id"]
        if pid != prev:
            segments.append([])
            order.append(pid)
            prev = pid
        layers = []
        for l, sel in enumerate(tok["layers"]):
            layers.append([(l, e, scaled_sizes[l]) for e in sel])
        segments[-1].append(layers)
    return order, segments


def plan_rounds(n_tokens_prompt, k, regime_cycle, round_counter):
    """Partition one prompt into rounds. Returns (rounds, counter)
    where each round is (start, width, accepted)."""
    rounds = []
    s = 0
    counter = round_counter
    while s < n_tokens_prompt:
        width = min(k + 1, n_tokens_prompt - s)
        drafts = width - 1
        if regime_cycle is None:
            accepted = drafts
        else:
            ell = regime_cycle[counter % len(regime_cycle)]
            accepted = min(drafts, ell)
        rounds.append((s, width, accepted))
        counter += 1
        s += accepted + 1
    return rounds, counter


def fresh_extra():
    return dict(useful_accesses=0, useful_hits=0, useful_streamed=0,
                useful_evictions=0, useful_admissions=0,
                waste_accesses=0, waste_hits=0, waste_streamed=0,
                waste_fetches=0, waste_evictions=0, waste_admissions=0,
                rounds=0, emitted=0, batch_slots=0, batch_distinct=0)


def run_seq(order, prompts, budget_pairs):
    cache = FSketchCache(budget_pairs * MEAN)
    for seg in prompts:
        for layers in seg:
            for layer_accs in layers:
                for (l, e, size) in layer_accs:
                    cache.access(l, e, size)
    return cache


def run_batch(order, prompts, budget_pairs, k, regime, prefix_only):
    cycle = REGIMES[regime]
    cache = FSketchCache(budget_pairs * MEAN)
    extra = fresh_extra()
    counter = 0
    for toks in prompts:
        rounds, counter = plan_rounds(len(toks), k, cycle, counter)
        for (s, width, accepted) in rounds:
            extra["rounds"] += 1
            extra["emitted"] += accepted + 1
            positions = list(range(s, s + width))
            useful_pos = set(range(s, s + accepted + 1))
            # Batch sharing: distinct pairs over the verified set.
            seen_pairs = set()
            slots = 0
            for p in positions:
                for layer_accs in toks[p]:
                    for (l, e, size) in layer_accs:
                        slots += 1
                        seen_pairs.add((l, e))
            extra["batch_slots"] += slots
            extra["batch_distinct"] += len(seen_pairs)
            issue = [p for p in positions
                     if (not prefix_only) or (p in useful_pos)]
            # Layer-major issue: for each layer, all positions.
            for l in range(16):
                for p in issue:
                    is_waste = p not in useful_pos
                    for (ll, e, size) in toks[p][l]:
                        ev_before = cache.stats["evictions"]
                        ad_before = cache.stats["admissions"]
                        rc = cache.access(ll, e, size)
                        ev_d = cache.stats["evictions"] - ev_before
                        ad_d = cache.stats["admissions"] - ad_before
                        if is_waste:
                            extra["waste_accesses"] += 1
                            extra["waste_evictions"] += ev_d
                            extra["waste_admissions"] += ad_d
                            if rc == HIT:
                                extra["waste_hits"] += 1
                            else:
                                extra["waste_fetches"] += 1
                                extra["waste_streamed"] += size
                        else:
                            extra["useful_accesses"] += 1
                            extra["useful_evictions"] += ev_d
                            extra["useful_admissions"] += ad_d
                            if rc == HIT:
                                extra["useful_hits"] += 1
                            else:
                                extra["useful_streamed"] += size
    return cache, extra


def summarise(cache, n_emitted):
    st = cache.stats
    full = st["bytes_streamed"] * 1024
    return dict(
        accesses=st["accesses"], hits=st["hits"], misses=st["misses"],
        cold=st["cold_misses"],
        hit_rate=(st["hits"] / st["accesses"] if st["accesses"] else 0.0),
        bypasses=st["bypasses"], admissions=st["admissions"],
        promotions=st["promotions"], evictions=st["evictions"],
        evicted_before_reuse=st["evicted_before_reuse"],
        streamed_scaled=st["bytes_streamed"],
        streamed_full_bytes=full,
        streamed_mb_per_emitted_token=full / 1e6 / n_emitted,
        entries_now=len(cache.entries),
        resident_scaled=cache.resident_bytes(),
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("trace")
    ap.add_argument("j024_results")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    raw = Path(args.trace).read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    header, tokens, accesses, mean_scaled = load_stream(args.trace)
    assert mean_scaled == MEAN, mean_scaled
    scaled_sizes = [s // 1024 for s in header["expert_bytes_per_layer"]]
    order, prompts = build_prompts(tokens, scaled_sizes)
    n_tokens = len(tokens)
    assert len(accesses) == 73856 and n_tokens == 577

    j024 = json.loads(Path(args.j024_results).read_text())

    # ---- validation gate: SEQ vs tournament + real-module replay
    gate = {}
    gate_ok = True
    seq_by_budget = {}
    for b in (128, 256, 512):
        cache = run_seq(order, prompts, b)
        seq_by_budget[b] = cache
        ref = j024["global_runs"][f"fsketch@{b}"]
        got = summarise(cache, n_tokens)
        fields = dict(hits=got["hits"], misses=got["misses"],
                      cold=got["cold"], bypasses=got["bypasses"],
                      admissions=got["admissions"],
                      evictions=got["evictions"],
                      ebr=got["evicted_before_reuse"],
                      streamed=got["streamed_scaled"],
                      entries=got["entries_now"],
                      resident=got["resident_scaled"])
        refmap = dict(hits=ref["hits"], misses=ref["misses"],
                      cold=ref["cold"], bypasses=ref["bypasses"],
                      admissions=ref["admissions"],
                      evictions=ref["evictions"],
                      ebr=ref["evicted_before_reuse"],
                      streamed=ref["streamed_full_bytes"] // 1024,
                      entries=ref["entries_now"],
                      resident=ref["resident_scaled"])
        exact_t = all(fields[k] == refmap[k] for k in refmap)
        entry = {"tournament": "EXACT" if exact_t else "MISMATCH"}
        if b in MOJO_REPLAY:
            m = MOJO_REPLAY[b]
            exact_m = all(fields[k] == m[k] for k in m)
            entry["mojo_replay"] = "EXACT" if exact_m else "MISMATCH"
            exact_t = exact_t and exact_m
        gate[f"seq@{b}"] = entry
        gate_ok = gate_ok and exact_t
    print(f"validation_gate: {gate}")
    if not gate_ok:
        print("GATE FAILED -- no interplay number may be reported")
        return 3

    results = {
        "trace_sha256": sha,
        "model_sha256": header["model_sha256"],
        "n_tokens": n_tokens, "n_accesses_seq": len(accesses),
        "mean_scaled_pair_bytes": mean_scaled,
        "validation_gate": gate,
        "seq": {}, "batch_all": {}, "batch_prefix": {},
    }
    for b in BUDGETS:
        results["seq"][str(b)] = summarise(seq_by_budget[b], n_tokens)

    for b in BUDGETS:
        seq_mb = results["seq"][str(b)]["streamed_mb_per_emitted_token"]
        for regime in REGIMES:
            for k in KS:
                for disc, prefix_only, store in (
                        ("batch_all", False, results["batch_all"]),
                        ("batch_prefix", True, results["batch_prefix"])):
                    cache, extra = run_batch(order, prompts, b, k,
                                             regime, prefix_only)
                    assert extra["emitted"] == n_tokens, extra["emitted"]
                    s = summarise(cache, n_tokens)
                    s["net_vs_seq_pct"] = (
                        100.0 * (s["streamed_mb_per_emitted_token"]
                                 - seq_mb) / seq_mb)
                    s.update(extra)
                    if extra["useful_accesses"]:
                        s["useful_hit_rate"] = (
                            extra["useful_hits"]
                            / extra["useful_accesses"])
                    s["waste_streamed_full_bytes"] = (
                        extra["waste_streamed"] * 1024)
                    store.setdefault(regime, {})[f"k{k}@{b}"] = s

    # ---- verdict per the pre-registered rule
    verdict = {"neutral_or_better_cells": [], "prefix_beats_seq_cells": [],
               "per_budget": {}}
    for b in BUDGETS:
        neutral = []
        prefix_wins = []
        for regime in ("hot", "cold", "mixed"):
            for k in KS:
                if (results["batch_all"][regime][f"k{k}@{b}"]
                        ["net_vs_seq_pct"] <= 0.0):
                    neutral.append(f"{regime}/k{k}")
                if (results["batch_prefix"][regime][f"k{k}@{b}"]
                        ["net_vs_seq_pct"] < 0.0):
                    prefix_wins.append(f"{regime}/k{k}")
        verdict["per_budget"][str(b)] = {
            "neutral_or_better": neutral, "prefix_beats_seq": prefix_wins}
        verdict["neutral_or_better_cells"].extend(
            f"{c}@{b}" for c in neutral)
        verdict["prefix_beats_seq_cells"].extend(
            f"{c}@{b}" for c in prefix_wins)
    if verdict["neutral_or_better_cells"]:
        verdict["verdict"] = "CACHE-NEUTRAL-OR-BETTER in named cells"
    elif verdict["prefix_beats_seq_cells"]:
        verdict["verdict"] = "MIXED -- batching pays, waste eats it"
    else:
        verdict["verdict"] = "TAX -- speculation costs streamed bytes"
    results["verdict"] = verdict

    print(f"trace sha256 {sha}")
    print(f"gate PASS; seq: " + "; ".join(
        f"@{b} hit {results['seq'][str(b)]['hit_rate']:.3f} "
        f"{results['seq'][str(b)]['streamed_mb_per_emitted_token']:.1f} MB/tok"
        for b in BUDGETS))
    for b in BUDGETS:
        print(f"-- budget {b} pairs (SEQ "
              f"{results['seq'][str(b)]['streamed_mb_per_emitted_token']:.2f} MB/emitted-token)")
        for regime in REGIMES:
            for k in KS:
                a = results["batch_all"][regime][f"k{k}@{b}"]
                p = results["batch_prefix"][regime][f"k{k}@{b}"]
                print(
                    f"BATCH regime={regime} k={k} @{b} "
                    f"all_net={a['net_vs_seq_pct']:+.2f}% "
                    f"all_hit={a['hit_rate']:.3f} "
                    f"useful_hit={a.get('useful_hit_rate', 0):.3f} "
                    f"waste_fetches={a['waste_fetches']} "
                    f"waste_streamed_MB={a['waste_streamed_full_bytes']/1e6:.1f} "
                    f"evictions={a['evictions']} "
                    f"prefix_net={p['net_vs_seq_pct']:+.2f}% "
                    f"rounds={a['rounds']}")
    print(f"VERDICT: {verdict['verdict']}")
    print(f"neutral cells: {verdict['neutral_or_better_cells']}")
    print(f"prefix-beats-seq cells: {verdict['prefix_beats_seq_cells']}")

    if args.out:
        Path(args.out).write_text(json.dumps(results, indent=1) + "\n")
        print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
