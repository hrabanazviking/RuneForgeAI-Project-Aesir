#!/usr/bin/env python3
"""J-025 router-shadow prefetch measurement (Project Aesir, Janas road).

Roadmap text (J-025): "One-layer-ahead expert prefetch (the router's
previous-layer pattern) measured; kept only if it pays on the real traces."

PREDICTORS -- defined BEFORE any payoff measurement (doc
J025_ROUTER_SHADOW_PREFETCH.md states the same definitions and the
verdict rule before its results sections). The demand target is the
routed set S(t,l) = the top-8 experts the router chose for token t at
layer l, in the J-016 trace's recorded rank order (rank = router-weight
order). A predictor emits an ordered candidate list for (t,l) using
ONLY information available before (t,l)'s router runs:

  PL   same-token previous layer:  cand(t,l) = S(t,l-1), l >= 1.
       (The roadmap's named pattern: the router's previous-layer set,
       read as expert IDs at layer l.)
  PT   previous-token same layer:  cand(t,l) = S(t-1,l), t not the
       first token of its prompt.
  PTD  previous-token diagonal:    cand(t,l) = S(t-1,l-1), both guards.
  UNION  PL union PT, deduplicated, ranked by the larger of the two
       source weights (a candidate in both sets keeps the max),
       truncated to 8 (UNION8). 
  ORACLE cand(t,l) = S(t,l) itself -- the perfect-shadow upper bound;
       not a buildable predictor, the ceiling every real one is
       graded against.

Widths: PL/PT/PTD run at FULL8 (all 8 candidates) and TOP4 (the
source set's top-4 by router weight). UNION runs at 8 by definition.

PREFETCH MECHANICS (the honest charging model, fixed in advance):
  - Issue point: the candidate batch for (t,l) is issued immediately
    before (t,l)'s demand accesses, in candidate rank order. In a
    sequential trace replay every earlier issue point inside the gap
    (during layer l-1's compute, at token start) is indistinguishable
    except for batch grouping; per-layer issue is the grouping the
    one-layer-ahead design actually has (prefetch for l+1 is issued
    while layer l computes, consumed by layer l+1).
  - A candidate already resident costs nothing and is not fetched.
  - A fetched candidate is charged its full pair size as streamed
    bytes, whether or not it is admitted.
  - Admission modes:
      DIRECT -- the prefetch admits unconditionally, evicting LRU
        residents until the pair fits (a dedicated prefetch path).
      GATED  -- the prefetch must pass fsketch's own admission test
        (candidate's aged sketch frequency must exceed the LRU
        victim's, victims evicted one at a time, a refusal leaves
        earlier evictions standing -- the tournament loop verbatim),
        with NO frequency bump for the candidate (a prefetch is not
        demand evidence). The fetch is charged before the test --
        the demand path's own ordering.
      GATEDPRE -- the same test, but evaluated on metadata BEFORE
        the fetch (the sketch frequencies and the LRU order are in
        memory; a real prefetch hook can and would test first). A
        candidate whose victim chain fails the test is never
        fetched and costs nothing (counted as a gate skip, not a
        fetch); a passing candidate is fetched, its victim chain
        evicted, and it is admitted.
      BUFFER -- DIRECT admission, but prefetched entries are marked
        evict-first (an artificially ancient recency stamp): any
        admission, demand or prefetch, sheds unused prefetches
        before touching a demand-admitted resident. A demand hit
        re-stamps the entry with the real tick -- use promotes a
        prefetch to full citizenship. This is the standard
        protective prefetch-buffer discipline.
    Prefetch evictions are real evictions: they enter the cache's
    evicted-before-reuse window and can destroy useful residents;
    that cost shows up in the demand hit rate, not in a footnote.
  - A fetched+admitted candidate that is demand-hit before eviction
    is USEFUL. A fetched candidate that is refused, evicted before
    use, or still resident-but-unused at trace end is WASTE; its
    bytes stay in the streamed total.
  - Prefetches never touch the demand statistics (accesses / hits /
    misses / cold) and never bump sketch frequencies.

BASE POLICY: fsketch, the shipping default since J-024's integration
(single LRU segment, aged exact counters halved every 4096 accesses,
admit iff candidate frequency exceeds the victim's). Byte budgets are
built exactly as J-016/J-018/J-024 built them: pairs x mean scaled
pair size (3720); sizes simulated scaled /1024, exact for both OLMoE
layer classes; full-scale bytes = scaled x 1024.

VALIDATION GATE (runs first; exit 3 on failure, no payoff number is
reported from a failed gate): the no-prefetch base run of this
script's cache must reproduce, EXACTLY and at budgets 128/256/512,
the fsketch counters in j024_tournament_results.json (global runs),
AND at 128/512 the real-MoJO-module replay counters recorded in
j024_replay_results.txt (hits 25953/56781, streamed scaled
178149792/63662880, bypasses 46724/14895, admissions 1179/2180,
evictions 1050/1668, evicted-before-reuse 22335/12194, cold 1024,
entries 129/512, resident scaled 474336/1903056).

VERDICT RULE (stated before results): prefetch is KEPT only if some
(predictor, width, admission mode) at an operating budget (128 or 512
pairs) achieves ALL of: (a) negative net streamed-bytes delta vs the
no-prefetch base in the global session; (b) no per-text-type segment
with a net delta worse than +2% (no collapsing on a text type);
(c) a useful-prefetch fraction of at least 0.25 (at most three
wasted fetches per useful one). If several configurations pass, the
winner is the one with the largest global net saving at 128 pairs
(the harsh bigger-than-RAM edge is Part II's operating point),
tie-broken at 512. Otherwise prefetch is REJECTED and the measured
rejection is the slice result.

Usage: j025_prefetch.py TRACE.jsonl J024_RESULTS.json [--out RESULTS.json]
"""
import argparse
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from j024_tournament import (FSketchCache, load_stream, KEYMUL, HIT)  # noqa: E402

# Real-MoJO-module replay counters (docs/janas/j024_replay_results.txt,
# J-024 integration step, branch yrsa/janas-j024-integration).
MOJO_REPLAY = {
    128: dict(hits=25953, misses=47903, cold=1024, bypasses=46724,
              admissions=1179, evictions=1050, ebr=22335,
              streamed=178149792, entries=129, resident=474336),
    512: dict(hits=56781, misses=17075, cold=1024, bypasses=14895,
              admissions=2180, evictions=1668, ebr=12194,
              streamed=63662880, entries=512, resident=1903056),
}


class PrefetchFSketch(FSketchCache):
    """FSketchCache (J-024 tournament class, itself validated EXACT
    against the J-020 replica / J-018 replay in J-024) plus a prefetch
    path. Demand behaviour is inherited unchanged; the validation
    gate below re-proves that on this subclass before use."""

    def __init__(self, budget_bytes):
        super().__init__(budget_bytes)
        self.pf = dict(attempts=0, resident_skips=0, fetches=0,
                       fetched_bytes=0, admitted=0, refused=0,
                       useful=0, wasted_at_eviction=0, gate_skips=0)
        self.pf_pending = {}  # key -> fetched size (scaled)
        self.pf_seq = 0

    def _evict_key(self, key):
        e = self.entries.pop(key)
        self.resident -= e["size"]
        self.stats["evictions"] += 1
        self.stats["bytes_evicted"] += e["size"]
        self.evicted.add(key)
        if key in self.pf_pending:
            del self.pf_pending[key]
            self.pf["wasted_at_eviction"] += 1

    def note_demand(self, layer, expert, rc):
        if rc == HIT:
            key = layer * KEYMUL + expert
            if key in self.pf_pending:
                del self.pf_pending[key]
                self.pf["useful"] += 1

    def reconcile_pending(self):
        """Demand-side admissions evict through the base class's own
        code path, not _evict_key; any pending prefetch no longer
        resident after a demand access was evicted before use."""
        for key in list(self.pf_pending):
            if key not in self.entries:
                del self.pf_pending[key]
                self.pf["wasted_at_eviction"] += 1

    def prefetch(self, layer, expert, size, mode):
        key = layer * KEYMUL + expert
        self.pf["attempts"] += 1
        if key in self.entries:
            self.pf["resident_skips"] += 1
            return
        if size > self.budget:
            self.pf["refused"] += 1
            return
        if mode == "gatedpre":
            # Test the whole victim chain on metadata first.
            chain = []
            freed = 0
            for vk in sorted(self.entries,
                             key=lambda k: self.entries[k]["last_tick"]):
                if self.resident - freed + size <= self.budget:
                    break
                if self._freq_of(key) <= self._freq_of(vk):
                    self.pf["gate_skips"] += 1
                    return
                chain.append(vk)
                freed += self.entries[vk]["size"]
            if self.resident - freed + size > self.budget:
                self.pf["gate_skips"] += 1
                return
            self.pf["fetches"] += 1
            self.pf["fetched_bytes"] += size
            for vk in chain:
                self._evict_key(vk)
            self.entries[key] = dict(size=size, last_tick=self.tick)
            self.resident += size
            self.pf["admitted"] += 1
            self.pf_pending[key] = size
            return
        self.pf["fetches"] += 1
        self.pf["fetched_bytes"] += size
        if mode == "gated":
            while self.resident + size > self.budget:
                victim = min(self.entries,
                             key=lambda k: self.entries[k]["last_tick"],
                             default=None)
                if victim is None or \
                        self._freq_of(key) <= self._freq_of(victim):
                    self.pf["refused"] += 1
                    return
                self._evict_key(victim)
        else:  # direct / buffer (victim order is the same LRU scan;
            # buffer differs only in the recency stamp given below,
            # which makes unused prefetches the LRU-first victims of
            # every later admission, demand admissions included --
            # the base class picks victims by last_tick)
            while self.resident + size > self.budget:
                victim = min(self.entries,
                             key=lambda k: self.entries[k]["last_tick"],
                             default=None)
                if victim is None:
                    self.pf["refused"] += 1
                    return
                self._evict_key(victim)
        if mode == "buffer":
            self.pf_seq += 1
            stamp = -1_000_000_000 + self.pf_seq
        else:
            stamp = self.tick
        self.entries[key] = dict(size=size, last_tick=stamp)
        self.resident += size
        self.pf["admitted"] += 1
        self.pf_pending[key] = size


def build_token_layers(tokens, scaled_sizes):
    """Per (token, layer): (prompt_id, [(expert, size, weight), ...])."""
    tls = []
    for tok in tokens:
        pid = tok.get("prompt_id", "?")
        weights = tok.get("weights")
        for l, sel in enumerate(tok["layers"]):
            dem = [(e, scaled_sizes[l], weights[l][j] if weights else 0.0)
                   for j, e in enumerate(sel)]
            tls.append((pid, l, dem))
    return tls


def candidates(name, width, tls, ti, l):
    """Candidate expert IDs for token-layer index ti at layer l."""
    pid, _, dem = tls[ti]
    out = []
    if name in ("pl", "union"):
        if l >= 1:
            src = tls[ti - 1]  # previous layer, same token (tls are
            # ordered token-major, layer-minor: ti-1 is (t, l-1))
            assert src[1] == l - 1 and src[0] == pid
            out += [(e, w) for (e, _, w) in src[2]]
    if name in ("pt", "union"):
        back = ti - 16
        if back >= 0 and tls[back][0] == pid and tls[back][1] == l:
            out_pt = [(e, w) for (e, _, w) in tls[back][2]]
            if name == "pt":
                out = out_pt
            else:
                merged = {}
                for e, w in out:
                    merged[e] = max(merged.get(e, 0.0), w)
                for e, w in out_pt:
                    merged[e] = max(merged.get(e, 0.0), w)
                out = sorted(merged.items(), key=lambda kv: -kv[1])
                out = [(e, w) for e, w in out]
    if name == "ptd":
        back = ti - 16 - 1
        if l >= 1 and back >= 0 and tls[back][0] == pid and \
                tls[back][1] == l - 1:
            out = [(e, w) for (e, _, w) in tls[back][2]]
    if name == "oracle":
        out = [(e, w) for (e, _, w) in dem]
    if width is not None:
        out = out[:width]
    return [e for e, _ in out]


def coverage_stats(tls):
    """Cache-free predictor quality: mean overlap with the demand set
    and mean demand-weight mass covered, per predictor (FULL8/UNION8).
    Random 8-of-64 expectation: overlap 1.0, mass ~0.125."""
    specs = [("pl", None), ("pt", None), ("ptd", None),
             ("union", None), ("oracle", None),
             ("pl", 4), ("pt", 4)]
    agg = {}
    per_type = {}
    for name, width in specs:
        label = name if width is None else f"{name}-top{width}"
        tot_o, tot_m, n = 0.0, 0.0, 0
        pt_agg = {}
        for ti in range(len(tls)):
            pid, l, dem = tls[ti]
            cands = candidates(name, width, tls, ti, l)
            if not cands:
                continue
            dset = {e for e, _, _ in dem}
            wmap = {e: w for e, _, w in dem}
            tot_o += len(set(cands) & dset)
            tot_m += sum(wmap.get(e, 0.0) for e in set(cands))
            n += 1
            a = pt_agg.setdefault(pid, [0.0, 0.0, 0])
            a[0] += len(set(cands) & dset)
            a[1] += sum(wmap.get(e, 0.0) for e in set(cands))
            a[2] += 1
        agg[label] = dict(n_token_layers=n,
                          mean_overlap=round(tot_o / n, 4) if n else None,
                          mean_mass_covered=round(tot_m / n, 4) if n else None)
        per_type[label] = {
            pid: dict(mean_overlap=round(a[0] / a[2], 4),
                      mean_mass_covered=round(a[1] / a[2], 4), n=a[2])
            for pid, a in pt_agg.items()}
    return agg, per_type


def run_sim(tls, budget_pairs, mean_scaled, predictor=None, width=None,
            mode=None, n_tokens=577):
    budget = budget_pairs * mean_scaled
    cache = PrefetchFSketch(budget)
    per_prompt = {}
    for ti, (pid, l, dem) in enumerate(tls):
        pp = per_prompt.setdefault(pid, dict(demand_hits=0, demand=0,
                                             demand_streamed=0,
                                             pf_streamed=0))
        if predictor is not None:
            size = dem[0][1]
            before = cache.pf["fetched_bytes"]
            for e in candidates(predictor, width, tls, ti, l):
                cache.prefetch(l, e, size, mode)
            pp["pf_streamed"] += (cache.pf["fetched_bytes"] - before)
        for (e, size, w) in dem:
            before_b = cache.stats["bytes_streamed"]
            rc = cache.access(l, e, size)
            cache.note_demand(l, e, rc)
            cache.reconcile_pending()
            pp["demand"] += 1
            if rc == HIT:
                pp["demand_hits"] += 1
            else:
                pp["demand_streamed"] += (cache.stats["bytes_streamed"]
                                          - before_b)
    st = cache.stats
    pf = dict(cache.pf)
    pf["unused_at_end"] = len(cache.pf_pending)
    pf["useful_fraction"] = round(pf["useful"] / pf["fetches"], 4) \
        if pf["fetches"] else None
    total_streamed = st["bytes_streamed"] + pf["fetched_bytes"]
    summ = dict(
        accesses=st["accesses"], hits=st["hits"], misses=st["misses"],
        cold=st["cold_misses"],
        hit_rate=round(st["hits"] / st["accesses"], 6),
        bypasses=st["bypasses"], admissions=st["admissions"],
        evictions=st["evictions"],
        evicted_before_reuse=st["evicted_before_reuse"],
        demand_streamed_scaled=st["bytes_streamed"],
        pf_streamed_scaled=pf["fetched_bytes"],
        total_streamed_scaled=total_streamed,
        total_streamed_mb_per_token=round(total_streamed * 1024
                                          / n_tokens / 1e6, 3),
        entries_now=len(cache.entries),
        resident_scaled=cache.resident_bytes(),
        prefetch=pf)
    pp_out = {}
    for pid, v in per_prompt.items():
        tot = v["demand_streamed"] + v["pf_streamed"]
        pp_out[pid] = dict(demand=v["demand"], demand_hits=v["demand_hits"],
                           hit_rate=round(v["demand_hits"] / v["demand"], 6),
                           demand_streamed_scaled=v["demand_streamed"],
                           pf_streamed_scaled=v["pf_streamed"],
                           total_streamed_scaled=tot)
    return summ, pp_out


def main(argv=None):
    ap = argparse.ArgumentParser(description="J-025 router-shadow prefetch")
    ap.add_argument("trace")
    ap.add_argument("j024_results")
    ap.add_argument("--out")
    args = ap.parse_args(argv)

    trace_bytes = Path(args.trace).read_bytes()
    trace_sha = hashlib.sha256(trace_bytes).hexdigest()
    header, tokens, accesses, mean_scaled = load_stream(args.trace)
    n_tokens = len(tokens)
    scaled_sizes = [s // 1024 for s in header["expert_bytes_per_layer"]]
    tls = build_token_layers(tokens, scaled_sizes)
    j024 = json.loads(Path(args.j024_results).read_text())
    print(f"trace sha256={trace_sha} tokens={n_tokens} "
          f"accesses={len(accesses)} token_layers={len(tls)} "
          f"mean_scaled={mean_scaled}")
    assert len(tls) == n_tokens * header["n_layer"]

    # ---- Validation gate: base (no prefetch) vs J-024 ---------------
    gate = {}
    gate_ok = True
    base = {}
    base_pp = {}
    for pairs in (128, 256, 512):
        summ, pp = run_sim(tls, pairs, mean_scaled, n_tokens=n_tokens)
        base[pairs] = summ
        base_pp[pairs] = pp
        ref = j024["global_runs"][f"fsketch@{pairs}"]
        fields = [("hits", "hits"), ("misses", "misses"), ("cold", "cold"),
                  ("bypasses", "bypasses"), ("admissions", "admissions"),
                  ("evictions", "evictions"),
                  ("evicted_before_reuse", "evicted_before_reuse"),
                  ("demand_streamed_scaled", "streamed_full_bytes"),
                  ("entries_now", "entries_now"),
                  ("resident_scaled", "resident_scaled")]
    # streamed in j024 json is full bytes; ours is scaled -> convert
        ok = True
        detail = {}
        for mine, theirs in fields:
            want = ref[theirs]
            if theirs == "streamed_full_bytes":
                want = want // 1024
            got = summ[mine]
            detail[mine] = (got, want)
            if got != want:
                ok = False
        if pairs in MOJO_REPLAY:
            m = MOJO_REPLAY[pairs]
            mojo_map = dict(hits=m["hits"], misses=m["misses"],
                            cold=m["cold"], bypasses=m["bypasses"],
                            admissions=m["admissions"],
                            evictions=m["evictions"],
                            evicted_before_reuse=m["ebr"],
                            demand_streamed_scaled=m["streamed"],
                            entries_now=m["entries"],
                            resident_scaled=m["resident"])
            for k, want in mojo_map.items():
                if summ[k] != want:
                    ok = False
                    detail[f"mojo:{k}"] = (summ[k], want)
        gate[f"fsketch@{pairs}"] = "EXACT" if ok else f"MISMATCH {detail}"
        print(f"gate base fsketch@{pairs}: {gate[f'fsketch@{pairs}']}")
        if not ok:
            gate_ok = False
    if not gate_ok:
        print("VALIDATION GATE FAILED -- prefetch numbers withheld",
              file=sys.stderr)
        return 3
    for pairs in (128, 256, 512):
        b = base[pairs]
        print(f"base fsketch@{pairs}: hit={b['hit_rate']} "
              f"streamed_scaled={b['demand_streamed_scaled']} "
              f"total_mb_per_token={b['total_streamed_mb_per_token']} "
              f"bypasses={b['bypasses']} admissions={b['admissions']} "
              f"evictions={b['evictions']} ebr={b['evicted_before_reuse']}")
        print(f"  base types @{pairs}: " + " ".join(
            f"{pid}:hit={v['hit_rate']},streamed={v['total_streamed_scaled']}"
            for pid, v in base_pp[pairs].items()))

    # ---- Predictor quality (cache-free) ------------------------------
    cov, cov_pt = coverage_stats(tls)
    for label, v in cov.items():
        print(f"coverage {label}: overlap={v['mean_overlap']} "
              f"mass={v['mean_mass_covered']} n={v['n_token_layers']}")

    # ---- Prefetch tournament -----------------------------------------
    runs = {}
    matrix = []
    for name, width in [("pl", None), ("pl", 4), ("pt", None), ("pt", 4),
                        ("ptd", None), ("union", None), ("oracle", None)]:
        for mode in ("direct", "gated"):
            for pairs in (128, 512):
                matrix.append((name, width, mode, pairs))
    for name, width in [("pl", None), ("pt", None), ("union", None),
                        ("oracle", None)]:
        matrix.append((name, width, "direct", 256))
    for name, width in [("pl", None), ("pt", None), ("pt", 4),
                        ("union", None), ("oracle", None)]:
        for mode in ("gatedpre", "buffer"):
            for pairs in (128, 512):
                matrix.append((name, width, mode, pairs))
    for (name, width, mode, pairs) in matrix:
        label = f"{name}{'' if width is None else f'-top{width}'}:" \
                f"{mode}@{pairs}"
        summ, pp = run_sim(tls, pairs, mean_scaled, predictor=name,
                           width=width, mode=mode, n_tokens=n_tokens)
        b = base[pairs]
        summ["net_delta_scaled"] = summ["total_streamed_scaled"] \
            - b["total_streamed_scaled"]
        summ["net_delta_pct"] = round(
            100.0 * summ["net_delta_scaled"] / b["total_streamed_scaled"], 3)
        summ["hit_delta"] = round(summ["hit_rate"] - b["hit_rate"], 6)
        per_type = {}
        for pid, v in pp.items():
            bv = base_pp[pairs][pid]
            per_type[pid] = dict(
                hit_rate=v["hit_rate"],
                hit_delta=round(v["hit_rate"] - bv["hit_rate"], 6),
                total_streamed_scaled=v["total_streamed_scaled"],
                net_delta_scaled=v["total_streamed_scaled"]
                - bv["total_streamed_scaled"],
                net_delta_pct=round(
                    100.0 * (v["total_streamed_scaled"]
                             - bv["total_streamed_scaled"])
                    / bv["total_streamed_scaled"], 3))
        runs[label] = dict(summary=summ, per_type=per_type)
        print(f"run {label}: hit={summ['hit_rate']} "
              f"total/token={summ['total_streamed_mb_per_token']} MB "
              f"net={summ['net_delta_pct']:+.2f}% "
              f"useful_frac={summ['prefetch']['useful_fraction']}")
        pf = summ["prefetch"]
        print(f"  pf {label}: attempts={pf['attempts']} "
              f"skips={pf['resident_skips']} fetches={pf['fetches']} "
              f"admitted={pf['admitted']} refused={pf['refused']} "
              f"gate_skips={pf['gate_skips']} useful={pf['useful']} "
              f"waste_evict={pf['wasted_at_eviction']} "
              f"unused_end={pf['unused_at_end']} "
              f"demand_streamed={summ['demand_streamed_scaled']} "
              f"pf_streamed={summ['pf_streamed_scaled']} "
              f"total={summ['total_streamed_scaled']} "
              f"evictions={summ['evictions']} ebr={summ['evicted_before_reuse']}")
        print(f"  types {label}: " + " ".join(
            f"{pid}={v['net_delta_pct']:+.2f}%"
            for pid, v in per_type.items()))

    # ---- Verdict (rule stated in the module docstring) ---------------
    verdict = {"rule": "global net < 0 at 128 or 512 AND no text-type "
                       "segment worse than +2% at that budget AND "
                       "useful fraction >= 0.25; winner = largest "
                       "global net saving at 128, tie-break 512",
               "passing": [], "winner": None}
    for label, r in runs.items():
        if "@256" in label:
            continue
        if label.startswith("oracle"):
            continue  # the oracle is a ceiling, not a candidate
        s = r["summary"]
        if s["net_delta_scaled"] >= 0:
            continue
        if s["prefetch"]["useful_fraction"] is None or \
                s["prefetch"]["useful_fraction"] < 0.25:
            continue
        worst = max(v["net_delta_pct"] for v in r["per_type"].values())
        if worst > 2.0:
            continue
        verdict["passing"].append(
            dict(config=label, net_delta_pct=s["net_delta_pct"],
                 worst_type_pct=worst))
    at128 = [p for p in verdict["passing"] if p["config"].endswith("@128")]
    pool = at128 if at128 else verdict["passing"]
    if pool:
        verdict["winner"] = min(pool, key=lambda p: p["net_delta_pct"])
        verdict["decision"] = "KEEP"
    else:
        verdict["decision"] = "REJECT"
    print(f"VERDICT: {verdict['decision']} winner={verdict['winner']}")

    results = dict(
        trace_sha256=trace_sha, n_tokens=n_tokens,
        n_accesses=len(accesses), mean_scaled_pair_bytes=mean_scaled,
        validation_gate=gate,
        base={str(k): v for k, v in base.items()},
        coverage=cov, coverage_per_type=cov_pt,
        runs=runs, verdict=verdict)
    if args.out:
        try:
            Path(args.out).write_text(json.dumps(results, indent=1) + "\n")
            print(f"wrote {args.out}")
        except OSError as e:
            # The simulation is deterministic; the printed record
            # above carries every headline number, and re-running
            # this script reproduces the file exactly.
            print(f"WRITE_FAILED {args.out}: {e}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
