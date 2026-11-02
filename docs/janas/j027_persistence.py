#!/usr/bin/env python3
"""J-027 cache persistence measurement (Project Aesir, Janas road).

Roadmap text (J-027): "Whether a warm expert map (which experts, not
their bytes) should persist between sessions like Janas's learned
config does: measured benefit, decided on evidence, recorded either
way."

PRE-REGISTRATION -- predictors, mechanics, segmentation and the
verdict rule below were all fixed BEFORE any payoff number was
measured (doc J027_CACHE_PERSISTENCE.md section 2 states the same
text). No Janas material was used or needed; this slice stands on
J-016/J-020/J-024 evidence. Clean-room law not engaged.

WHAT PERSISTENCE MEANS HERE. A MAP -- the ranked list of (layer,
expert) pairs with access counts, NOT expert bytes -- is saved at
session end. At the next session open it guides PRELOAD: the map's
top-128 pairs are streamed in before token 0 (charged in full, see
mechanics), exactly the J-020 warm-up shape (main-segment preload,
<= 1/4 of a 512-pair budget). Persisted map format (the spec this
slice prices): 16-byte header + 4 bytes per entry (layer u8, expert
u8, count u16 LE saturating). Map sizes below are that format's real
sizes for the maps each candidate actually builds.

CANDIDATES (all learned from PRIOR sessions only; no candidate ever
sees the target session -- the oracle is the only exception and is a
ceiling, never a candidate):
  NO-PERSIST  cold fsketch cache every session (the base).
  LAST        ranked by frequency in the immediately previous
              session alone (ties: more recent last use, then pair).
              Persisted map = that session's distinct pairs.
  CUMULATIVE  ranked by frequency over ALL prior sessions (the
              learned-config analogue; ties as LAST). Persisted map
              = all distinct pairs seen so far (universe cap 1024).
  FIRSTTOK    J-020's FIRSTTOK predictor, cross-session form: ranked
              by how many prior sessions' TOKEN-0 sets contain the
              pair, ties by cumulative frequency. Persisted map (the
              bounded form priced for the verdict) = top 128 entries.
  ORACLE      the target session's OWN token-0 set, ranked by the
              target session's own frequency (J-020's oracle form).
              Ceiling only.

MECHANISMS (how a persisted map is applied at session open):
  PRELOAD-PLAIN  the top-128 preload below, sketch frequency 0 for
                 preloaded pairs, no other seeding.
  SEED           no preload at all (zero prefetch bytes); the
                 session's fsketch frequency sketch is initialised
                 from the persisted map's counts (every mapped pair),
                 so admission priority -- the task's own alternative
                 -- is what is tested.
  SEED+PRELOAD   the top-128 preload, with each preloaded pair's
                 sketch frequency initialised to its persisted count,
                 and the rest of the map seeded as in SEED. This is
                 J-020's proven preload shape (its replica preload
                 took freq_hint = the predictor's evidence counts).
AMENDMENT RECORD (honesty): PRELOAD-PLAIN was run first. Reviewing
its rows against J-020's filing showed the plain form discards the
counts that ARE a frequency map's content (J-020's preload carried
freq hints), i.e. it fairly tests a persisted SET but not a
persisted frequency map. The SEED and SEED+PRELOAD mechanisms were
therefore added under the SAME verdict thresholds below, defined
here BEFORE either was measured. The verdict rule applies per
(candidate x mechanism) row; an adoption names its row exactly.

PRELOAD MECHANICS (honest charging, fixed in advance):
  - At session open, the ranked map's top 128 pairs are considered in
    rank order. A pair that does not fit the remaining budget is
    SKIPPED on metadata (no fetch, no charge -- a real loader knows
    pair sizes from the directory before reading). Every admitted
    pair is FETCHED and charged its full pair size as prefetch
    streamed bytes; prefetch bytes are part of the strategy's total.
  - Preloaded entries enter the fsketch cache with ancient recency
    (best-ranked least ancient), frequency 0 in the sketch (a preload
    is not demand evidence -- J-025's rule), and no demand-statistic
    contact. Demand admissions therefore shed unused preloads first.
  - A preloaded pair demand-hit before eviction is USEFUL; evicted
    before use and resident-but-unused at session end are counted
    separately and their bytes stay charged.
  - Cap pressure reported per session: preload bytes / budget,
    demand evictions vs the NO-PERSIST session, preloaded pairs
    evicted before use.

SEGMENTATIONS (same-model OLMoE sessions throughout -- the trace's
six prompts are six workloads on ONE model file; persistence here is
within-model, cross-workload):
  NATURAL (primary; the verdict rests on it): the six prompts as six
    sessions in trace order -- prose (67 prompt + its 4 gen tokens),
    code, structured, numbers, instructions, technical. Models
    successive separate conversations / CLI runs on a machine where
    the model stays installed and only the expert cache is cold.
  REPEAT (secondary): NATURAL's six sessions run a second lap in the
    same order (sessions 7-12 repeat the same prompts). Models the
    returning user -- daily reuse of the same model for similar work,
    the strongest honest case for a learned map.
  GROUPED (secondary): three sittings -- {prose+technical},
    {code+structured}, {numbers+instructions} -- the cache (and the
    NO-PERSIST base) reset only between sittings; a map learned from
    prior sittings preloads each sitting. Models one sitting with
    several prompts, engine restarted between sittings (J-026's
    tenant grouping is the precedent for the type pairing).

SESSION ELIGIBILITY: session 1 of a segmentation has no prior
session and is NO-PERSIST for every candidate by definition.
Headline aggregates cover the ELIGIBLE sessions only (2..N); the
all-session totals are also filed.

BUDGETS: 128 and 512 pairs (byte budgets = pairs x mean scaled pair
size 3720, exactly as J-016/J-018/J-024 built them; full-scale bytes
= scaled x 1024). 256 is run for the NO-PERSIST validation gate.
Cache under test: fsketch, the shipping default since J-024's
integration. A segmented-policy continuity check (J-020's cold
numbers) is part of the gate, not the payoff.

VALIDATION GATE (runs first; exit 3 on failure, no payoff number is
reported from a failed gate):
  (a) this script's fsketch, run as ONE global session over the whole
      trace, reproduces j024_tournament_results.json fsketch
      counters EXACTLY at 128/256/512 (every recorded field);
  (b) the same global run reproduces the real-MoJO-module replay
      counters (j024_replay_results.txt) EXACTLY at 128/512;
  (c) J-024's FastCache segmented, run globally, reproduces J-020's
      recorded cold-session numbers EXACTLY (hits 56165, misses
      17691, cold 1024, streamed scaled 65896320), and on the prose
      stream alone J-020's prose_cold EXACTLY (hits 4877, misses
      4211, cold 975, streamed scaled 15682608).

VERDICT RULE (stated before results; NATURAL segmentation, eligible
sessions):
  ADOPT (full-map persistence) iff some full-map candidate (LAST or
  CUMULATIVE) satisfies ALL of: (a) aggregate net streamed saving
  >= 2.0% at 512 pairs AND >= 0% at 128; (b) token-0 streamed saving
  >= 20% at both budgets; (c) no eligible session with a net loss
  worse than 2%. Winner: the larger 512 saving.
  ADOPT-BOUNDED (first-token map only) iff no full candidate passes
  but FIRSTTOK satisfies ALL of: (a) aggregate net saving > 0% at
  512 AND >= -1.0% at 128; (b) token-0 streamed saving >= 40% at
  512; (c) no eligible session with a net loss worse than 5% at 512.
  Otherwise REJECT: no map persists between sessions. (J-020's
  FIRSTTOK warm-up design is untouched by any verdict here: it was
  measured leave-one-prompt-out as a warm-up pass design, not as a
  persisted cross-session file -- this slice's question is exactly
  the file.)
  The oracle is never a candidate. REPEAT/GROUPED are reported as
  supporting evidence; a contradiction there is named in the doc,
  it does not silently override the NATURAL verdict.

Usage: j027_persistence.py TRACE.jsonl J024_RESULTS.json [--out R.json]
"""
import argparse
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from j024_tournament import FSketchCache, FastCache, load_stream, KEYMUL, HIT, MISS_ADMITTED  # noqa: E402

MAP_HEADER_BYTES = 16
MAP_ENTRY_BYTES = 4
PRELOAD_N = 128

MOJO_REPLAY = {
    128: dict(hits=25953, misses=47903, cold=1024, bypasses=46724,
              admissions=1179, evictions=1050, ebr=22335,
              streamed=178149792, entries=129, resident=474336),
    512: dict(hits=56781, misses=17075, cold=1024, bypasses=14895,
              admissions=2180, evictions=1668, ebr=12194,
              streamed=63662880, entries=512, resident=1903056),
}
J020_COLD = dict(hits=56165, misses=17691, cold=1024, streamed=65896320)
J020_PROSE_COLD = dict(hits=4877, misses=4211, cold=975, streamed=15682608)

PROMPT_ORDER = ["prose", "code", "structured", "numbers",
                "instructions", "technical"]
GROUPED_SITTINGS = [("prose+technical", ["prose", "technical"]),
                    ("code+structured", ["code", "structured"]),
                    ("numbers+instructions", ["numbers", "instructions"])]


class PersistFSketch(FSketchCache):
    """FSketchCache + a session-open preload path. Demand behaviour
    inherited unchanged; the gate re-proves it on this subclass."""

    def __init__(self, budget_bytes):
        super().__init__(budget_bytes)
        self.pf = dict(considered=0, fetched=0, fetched_bytes=0,
                       skipped_no_room=0, useful=0,
                       evicted_before_use=0, resident_unused=0)
        self.pending = {}  # key -> size (scaled)

    def seed_freq(self, counts):
        """counts: {(layer, expert): persisted count}. Initialises
        the sketch only -- no residency, no bytes."""
        for (l, e), c in counts.items():
            key = l * KEYMUL + e
            if c > self.freq.get(key, 0):
                self.freq[key] = c

    def preload(self, ranked_pairs, sizes, counts=None):
        """ranked_pairs: [(layer, expert), ...] best first."""
        for i, (l, e) in enumerate(ranked_pairs):
            key = l * KEYMUL + e
            self.pf["considered"] += 1
            if key in self.entries:
                continue
            size = sizes[l]
            if self.resident + size > self.budget:
                self.pf["skipped_no_room"] += 1
                continue
            # ancient recency: best-ranked (i=0) least ancient
            self.entries[key] = dict(size=size, last_tick=-i)
            self.resident += size
            self.pending[key] = size
            self.pf["fetched"] += 1
            self.pf["fetched_bytes"] += size
            if counts is not None and (l, e) in counts:
                if counts[(l, e)] > self.freq.get(key, 0):
                    self.freq[key] = counts[(l, e)]

    def note_access(self, l, e, rc):
        key = l * KEYMUL + e
        if rc == HIT and key in self.pending:
            del self.pending[key]
            self.pf["useful"] += 1
        if rc == MISS_ADMITTED:
            # evictions happen only inside an admitting access;
            # reconcile: pending keys no longer resident were evicted
            for k in list(self.pending):
                if k not in self.entries:
                    del self.pending[k]
                    self.pf["evicted_before_use"] += 1

    def finish_session(self):
        self.pf["resident_unused"] = len(self.pending)
        self.pending = {}


def build_prompt_accesses(tokens, scaled_sizes):
    """prompt_id -> [(l, e, size, pid)] in pos order (prompt tokens,
    then that prompt's gen tokens, which carry its prompt_id)."""
    by_pid = {}
    for t in tokens:
        pid = t.get("prompt_id", "?")
        lst = by_pid.setdefault(pid, [])
        for l, sel in enumerate(t["layers"]):
            for e in sel:
                lst.append((l, e, scaled_sizes[l], pid))
    return by_pid


def rank_counter(counter, last_seen):
    return sorted(counter,
                  key=lambda p: (-counter[p], -last_seen.get(p, 0),
                                 p[0], p[1]))


def build_maps(prior_sessions, target_session):
    """prior_sessions / target_session: [(label, accesses)].
    Returns {candidate: (ranked_pairs_topN, persisted_entries,
    seed_counts)} where seed_counts is the persisted map's own
    {(layer, expert): count} (for FIRSTTOK, its bounded top-128
    map only -- that is the artefact that would persist)."""
    maps = {}
    if not prior_sessions:
        return maps
    # LAST
    last_acc = prior_sessions[-1][1]
    c_last = Counter((l, e) for (l, e, _, _) in last_acc)
    ls_last = {}
    for i, (l, e, _, _) in enumerate(last_acc):
        ls_last[(l, e)] = i
    maps["LAST"] = (rank_counter(c_last, ls_last)[:PRELOAD_N],
                    len(c_last), dict(c_last))
    # CUMULATIVE
    c_cum = Counter()
    ls_cum = {}
    idx = 0
    t0_sets = []
    for _, acc in prior_sessions:
        c_cum.update((l, e) for (l, e, _, _) in acc)
        for (l, e, _, _) in acc:
            ls_cum[(l, e)] = idx
            idx += 1
        t0_sets.append(set((l, e) for (l, e, _, _) in acc[:128]))
    maps["CUMULATIVE"] = (rank_counter(c_cum, ls_cum)[:PRELOAD_N],
                          len(c_cum), dict(c_cum))
    # FIRSTTOK
    c_t0 = Counter()
    for s in t0_sets:
        c_t0.update(s)
    ranked_t0 = sorted(c_t0,
                       key=lambda p: (-c_t0[p], -c_cum.get(p, 0),
                                      -ls_cum.get(p, 0), p[0], p[1]))
    bounded_t0 = ranked_t0[:PRELOAD_N]
    maps["FIRSTTOK"] = (bounded_t0, min(len(c_t0), PRELOAD_N),
                        {p: c_t0[p] for p in bounded_t0})
    # ORACLE (ceiling only): target's own token-0 set ranked by the
    # target session's own frequency.
    tgt = target_session[1]
    c_tgt = Counter((l, e) for (l, e, _, _) in tgt)
    t0_tgt = []
    seen = set()
    for (l, e, _, _) in tgt[:128]:
        if (l, e) not in seen:
            seen.add((l, e))
            t0_tgt.append((l, e))
    t0_tgt.sort(key=lambda p: (-c_tgt[p], p[0], p[1]))
    maps["ORACLE"] = (t0_tgt[:PRELOAD_N], None, dict(c_tgt))
    return maps


MECHANISMS = ("PRELOAD-PLAIN", "SEED", "SEED+PRELOAD")


def run_session(accesses, budget, ranked, sizes, mechanism=None,
                counts=None):
    cache = PersistFSketch(budget)
    if mechanism == "SEED":
        if counts:
            cache.seed_freq(counts)
    elif mechanism == "SEED+PRELOAD":
        if counts:
            cache.seed_freq(counts)
        if ranked:
            cache.preload(ranked, sizes, counts=counts)
    elif ranked:
        cache.preload(ranked, sizes)
    tok0_hits = 0
    tok0_streamed = 0
    for i, (l, e, size, pid) in enumerate(accesses):
        before = cache.stats["bytes_streamed"]
        rc = cache.access(l, e, size)
        cache.note_access(l, e, rc)
        if i < 128:
            if rc == HIT:
                tok0_hits += 1
            tok0_streamed += cache.stats["bytes_streamed"] - before
    cache.finish_session()
    st = cache.stats
    return dict(
        accesses=st["accesses"], hits=st["hits"], misses=st["misses"],
        cold=st["cold_misses"], bypasses=st["bypasses"],
        admissions=st["admissions"], evictions=st["evictions"],
        evicted_before_reuse=st["evicted_before_reuse"],
        demand_streamed_scaled=st["bytes_streamed"],
        tok0_hits=tok0_hits, tok0_streamed_scaled=tok0_streamed,
        prefetch=dict(cache.pf),
        total_streamed_scaled=st["bytes_streamed"] + cache.pf["fetched_bytes"],
        entries_now=len(cache.entries),
        resident_scaled=cache.resident_bytes())


def run_segmentation(seg_name, sessions, budgets, sizes, mean_scaled):
    """sessions: [(label, accesses)]. Returns per-budget results."""
    out = {}
    base_cands = ["LAST", "CUMULATIVE", "FIRSTTOK", "ORACLE"]
    cand_names = ["NO-PERSIST"] + [f"{c}|{m}" for c in base_cands
                                   for m in MECHANISMS]
    for pairs in budgets:
        budget = pairs * mean_scaled
        rows = {c: [] for c in cand_names}
        map_sizes = {c: [] for c in cand_names}
        for si, (label, acc) in enumerate(sessions):
            base = run_session(acc, budget, None, sizes)
            rows["NO-PERSIST"].append(dict(session=label, **base))
            maps = build_maps(sessions[:si], (label, acc))
            for cand in base_cands:
                for mech in MECHANISMS:
                    key = f"{cand}|{mech}"
                    if cand not in maps:
                        rows[key].append(None)
                        map_sizes[key].append(None)
                        continue
                    ranked, n_entries, counts = maps[cand]
                    r = run_session(acc, budget, ranked, sizes,
                                    mechanism=mech, counts=counts)
                    rows[key].append(dict(session=label, **r))
                    map_sizes[key].append(
                        None if n_entries is None else
                        MAP_HEADER_BYTES + MAP_ENTRY_BYTES * n_entries)
        # aggregates over eligible sessions (index >= 1)
        agg = {}
        for cand in cand_names:
            elig = [(rows["NO-PERSIST"][i], rows[cand][i])
                    for i in range(1, len(sessions))
                    if rows[cand][i] is not None]
            if not elig:
                agg[cand] = None
                continue
            b_tot = sum(b["total_streamed_scaled"] for b, _ in elig)
            c_tot = sum(c["total_streamed_scaled"] for _, c in elig)
            b_t0 = sum(b["tok0_streamed_scaled"] for b, _ in elig)
            c_t0 = sum(c["tok0_streamed_scaled"] for _, c in elig)
            b_hit = sum(b["hits"] for b, _ in elig)
            c_hit = sum(c["hits"] for _, c in elig)
            n_acc = sum(b["accesses"] for b, _ in elig)
            per_session_net = [
                round((b["total_streamed_scaled"]
                       - c["total_streamed_scaled"])
                      / b["total_streamed_scaled"] * 100, 3)
                if b["total_streamed_scaled"] else 0.0
                for b, c in elig]
            agg[cand] = dict(
                sessions_eligible=len(elig),
                base_total_streamed_scaled=b_tot,
                total_streamed_scaled=c_tot,
                net_saving_pct=round((b_tot - c_tot) / b_tot * 100, 3)
                if b_tot else 0.0,
                base_tok0_streamed_scaled=b_t0,
                tok0_streamed_scaled=c_t0,
                tok0_saving_pct=round((b_t0 - c_t0) / b_t0 * 100, 3)
                if b_t0 else 0.0,
                tok0_hit_rate=round(
                    sum(c["tok0_hits"] for _, c in elig)
                    / (128 * len(elig)), 6),
                base_hit_rate=round(b_hit / n_acc, 6),
                hit_rate=round(c_hit / n_acc, 6),
                prefetch_fetched=sum(c["prefetch"]["fetched"]
                                     for _, c in elig),
                prefetch_fetched_bytes_scaled=sum(
                    c["prefetch"]["fetched_bytes"] for _, c in elig),
                prefetch_useful=sum(c["prefetch"]["useful"]
                                    for _, c in elig),
                prefetch_evicted_before_use=sum(
                    c["prefetch"]["evicted_before_use"] for _, c in elig),
                prefetch_resident_unused=sum(
                    c["prefetch"]["resident_unused"] for _, c in elig),
                prefetch_skipped_no_room=sum(
                    c["prefetch"]["skipped_no_room"] for _, c in elig),
                evictions=sum(c["evictions"] for _, c in elig),
                base_evictions=sum(b["evictions"] for b, _ in elig),
                per_session_net_saving_pct=per_session_net,
                worst_session_net_saving_pct=min(per_session_net)
                if per_session_net else None,
                map_bytes=[m for m in map_sizes[cand][1:]
                           if m is not None],
            )
        out[str(pairs)] = dict(per_session=rows, aggregate=agg)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description="J-027 cache persistence")
    ap.add_argument("trace")
    ap.add_argument("j024_results")
    ap.add_argument("--out")
    args = ap.parse_args(argv)

    trace_sha = hashlib.sha256(Path(args.trace).read_bytes()).hexdigest()
    header, tokens, accesses, mean_scaled = load_stream(args.trace)
    sizes = [s // 1024 for s in header["expert_bytes_per_layer"]]
    n_tokens = len(tokens)
    j024 = json.loads(Path(args.j024_results).read_text())
    print(f"trace sha256={trace_sha} tokens={n_tokens} "
          f"accesses={len(accesses)} mean_scaled={mean_scaled}")

    # ---- Validation gate ------------------------------------------------
    gate = {}
    gate_ok = True
    for pairs in (128, 256, 512):
        budget = pairs * mean_scaled
        c = PersistFSketch(budget)
        for (l, e, size, pid, w) in accesses:
            c.access(l, e, size)
        st = c.stats
        ref = j024["global_runs"][f"fsketch@{pairs}"]
        got = dict(hits=st["hits"], misses=st["misses"],
                   cold=st["cold_misses"], bypasses=st["bypasses"],
                   admissions=st["admissions"], evictions=st["evictions"],
                   evicted_before_reuse=st["evicted_before_reuse"],
                   streamed_full_bytes=st["bytes_streamed"] * 1024,
                   entries_now=len(c.entries),
                   resident_scaled=c.resident_bytes())
        want = dict(hits=ref["hits"], misses=ref["misses"],
                    cold=ref["cold"], bypasses=ref["bypasses"],
                    admissions=ref["admissions"],
                    evictions=ref["evictions"],
                    evicted_before_reuse=ref["evicted_before_reuse"],
                    streamed_full_bytes=ref["streamed_full_bytes"],
                    entries_now=ref["entries_now"],
                    resident_scaled=ref["resident_scaled"])
        ok = got == want
        gate[f"fsketch_tournament@{pairs}"] = "EXACT" if ok else \
            f"MISMATCH got={got} want={want}"
        gate_ok &= ok
        print(f"gate fsketch@{pairs}: {gate[f'fsketch_tournament@{pairs}']}")
        if pairs in MOJO_REPLAY:
            m = MOJO_REPLAY[pairs]
            okm = (st["hits"] == m["hits"] and st["misses"] == m["misses"]
                   and st["cold_misses"] == m["cold"]
                   and st["bypasses"] == m["bypasses"]
                   and st["admissions"] == m["admissions"]
                   and st["evictions"] == m["evictions"]
                   and st["evicted_before_reuse"] == m["ebr"]
                   and st["bytes_streamed"] == m["streamed"]
                   and len(c.entries) == m["entries"]
                   and c.resident_bytes() == m["resident"])
            gate[f"fsketch_mojo_replay@{pairs}"] = "EXACT" if okm else "MISMATCH"
            gate_ok &= okm
            print(f"gate mojo_replay@{pairs}: "
                  f"{gate[f'fsketch_mojo_replay@{pairs}']}")
    # (c) segmented continuity vs J-020 cold
    seg = FastCache(512 * mean_scaled, "segmented")
    for (l, e, size, pid, w) in accesses:
        seg.access(l, e, size)
    ss = seg.stats
    okc = (ss["hits"] == J020_COLD["hits"] and ss["misses"] == J020_COLD["misses"]
           and ss["cold_misses"] == J020_COLD["cold"]
           and ss["bytes_streamed"] == J020_COLD["streamed"])
    gate["segmented_j020_cold@512"] = "EXACT" if okc else \
        f"MISMATCH {ss} vs {J020_COLD}"
    gate_ok &= okc
    print(f"gate segmented_j020_cold@512: {gate['segmented_j020_cold@512']}")
    by_pid = build_prompt_accesses(tokens, sizes)
    segp = FastCache(512 * mean_scaled, "segmented")
    for (l, e, size, pid) in by_pid["prose"]:
        segp.access(l, e, size)
    sp = segp.stats
    okp = (sp["hits"] == J020_PROSE_COLD["hits"]
           and sp["misses"] == J020_PROSE_COLD["misses"]
           and sp["cold_misses"] == J020_PROSE_COLD["cold"]
           and sp["bytes_streamed"] == J020_PROSE_COLD["streamed"])
    gate["segmented_j020_prose_cold@512"] = "EXACT" if okp else \
        f"MISMATCH {sp} vs {J020_PROSE_COLD}"
    gate_ok &= okp
    print(f"gate segmented_j020_prose_cold@512: "
          f"{gate['segmented_j020_prose_cold@512']}")
    if not gate_ok:
        print("VALIDATION GATE FAILED -- payoff numbers withheld",
              file=sys.stderr)
        return 3

    # ---- Segmentations ---------------------------------------------------
    natural = [(pid, by_pid[pid]) for pid in PROMPT_ORDER]
    repeat = natural + [(pid + "#2", acc) for pid, acc in natural]
    grouped = [(name, [a for pid in pids for a in by_pid[pid]])
               for name, pids in GROUPED_SITTINGS]

    results = dict(
        trace_sha256=trace_sha, n_tokens=n_tokens,
        n_accesses=len(accesses), mean_scaled_pair_bytes=mean_scaled,
        validation_gate=gate,
        preload_n=PRELOAD_N,
        map_format=dict(header_bytes=MAP_HEADER_BYTES,
                        entry_bytes=MAP_ENTRY_BYTES),
        segmentations={},
    )
    for name, sessions in (("NATURAL", natural), ("REPEAT", repeat),
                           ("GROUPED", grouped)):
        results["segmentations"][name] = run_segmentation(
            name, sessions, (128, 512), sizes, mean_scaled)
        for pairs in ("128", "512"):
            agg = results["segmentations"][name][pairs]["aggregate"]
            for cand in [k for k in agg if k != "NO-PERSIST"]:
                a = agg[cand]
                print(f"{name}@{pairs} {cand}: net={a['net_saving_pct']}% "
                      f"tok0={a['tok0_saving_pct']}% "
                      f"hit={a['hit_rate']} (base {a['base_hit_rate']}) "
                      f"worst={a['worst_session_net_saving_pct']}% "
                      f"pf_useful={a['prefetch_useful']}/"
                      f"{a['prefetch_fetched']} "
                      f"ebu={a['prefetch_evicted_before_use']}")

    # ---- Verdict (rule stated in the header, applied mechanically) -------
    nat = results["segmentations"]["NATURAL"]
    def full_pass(key):
        a128 = nat["128"]["aggregate"][key]
        a512 = nat["512"]["aggregate"][key]
        return (a512["net_saving_pct"] >= 2.0
                and a128["net_saving_pct"] >= 0.0
                and a128["tok0_saving_pct"] >= 20.0
                and a512["tok0_saving_pct"] >= 20.0
                and a128["worst_session_net_saving_pct"] >= -2.0
                and a512["worst_session_net_saving_pct"] >= -2.0)
    full_rows = [f"{c}|{m}" for c in ("LAST", "CUMULATIVE")
                 for m in MECHANISMS]
    full_winners = [k for k in full_rows if full_pass(k)]
    def bounded_pass(key):
        ft128 = nat["128"]["aggregate"][key]
        ft512 = nat["512"]["aggregate"][key]
        return (ft512["net_saving_pct"] > 0.0
                and ft128["net_saving_pct"] >= -1.0
                and ft512["tok0_saving_pct"] >= 40.0
                and ft512["worst_session_net_saving_pct"] >= -5.0)
    bounded_rows = [f"FIRSTTOK|{m}" for m in MECHANISMS]
    bounded_winners = [k for k in bounded_rows if bounded_pass(k)]
    if full_winners:
        winner = max(full_winners,
                     key=lambda k: nat["512"]["aggregate"][k]
                     ["net_saving_pct"])
        verdict = dict(decision="ADOPT", winner=winner,
                       passing=full_winners)
    elif bounded_winners:
        winner = max(bounded_winners,
                     key=lambda k: nat["512"]["aggregate"][k]
                     ["net_saving_pct"])
        verdict = dict(decision="ADOPT-BOUNDED", winner=winner,
                       passing=[], bounded_passing=bounded_winners)
    else:
        verdict = dict(decision="REJECT", winner=None, passing=[])
    verdict["rule"] = ("ADOPT iff a full-map candidate has NATURAL "
                       "eligible net >= +2.0% @512 and >= 0% @128, "
                       "token-0 saving >= 20% at both, worst session "
                       ">= -2% at both; else ADOPT-BOUNDED iff "
                       "FIRSTTOK net > 0% @512, >= -1.0% @128, token-0 "
                       ">= 40% @512, worst session >= -5% @512; else "
                       "REJECT. Oracle excluded (ceiling only).")
    results["verdict"] = verdict
    print(f"VERDICT: {verdict['decision']} winner={verdict['winner']}")

    if args.out:
        Path(args.out).write_text(json.dumps(results, indent=1) + "\n")
        print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
