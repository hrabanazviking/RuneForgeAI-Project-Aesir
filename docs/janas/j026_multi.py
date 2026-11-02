#!/usr/bin/env python3
"""J-026 multi-model residency measurement (Project Aesir, Janas road).

Roadmap text (J-026): "Two models open in one process with a shared
cache budget (the server case); fairness rule; measured."

QUESTION ANSWERED LOCALLY (clean-room record): Janas's public
documentation does not specify a multi-model cache fairness rule (the
Part I census documents a per-process free-memory-sized cache with a
hard cap; it is silent on dividing one budget between two open
models). The rule below is Aesir's own, derived from Aesir's
architecture (J-018 sizing charges the OS headroom and the reserve
once per *session*, so two sessions sized independently against the
same free-memory snapshot over-commit the machine) and from the
J-016/J-024 measurements.

THE OVER-COMMIT PROBLEM (what this slice fixes): ExpertCache sizing
(plan_expert_cache_budget) and MoEStreamSession construction each
take a budget with no coordination. Two sessions opened in one
process each size against the full free memory (or each receive the
full configured cap): resident + KV + scratch are charged twice,
the 1/5-of-total OS headroom is charged twice, and the two expert
caches together may hold 2x the intended bytes. Nothing in the
pre-J-026 tree sums the two budgets against one total.

FAIRNESS RULE -- FLOOR-AND-BORROW (stated BEFORE measuring):
  - One pool total T for the process (sized ONCE by
    plan_shared_cache_pool in expert_cache.mojo: reserves summed,
    OS headroom charged once).
  - Per-tenant floor F = T / (2N) for N tenants (N=2 here: T/4).
    The floor is a RETURN GUARANTEE, not standing empty space.
  - Tenant i's instantaneous cap:
        cap_i = max(F, T - sum_{j != i} P_j)
        P_j = resident_j            if tenant j is active
        P_j = min(resident_j, F)    if tenant j is inactive
    An active peer's resident bytes are fully protected; an
    inactive (idle / finished, session still open) peer protects
    only its floor -- the rest is lendable.
  - Work-conserving: a lone / first tenant may use the whole pool;
    unused floor space is borrowed, never left idle while a peer
    streams.
  - Shrink behaviour: caps are re-applied before a tenant's access.
    A borrower whose cap fell (peer returned / peer grew) is shrunk
    to its cap through its own cache's shrink order (fsketch:
    lowest sketch frequency, ties by LRU -- ExpertCache.shrink).
    If a tenant's raw cap is below its floor, the arbiter first
    shrinks the OTHER tenants toward their protected levels
    (active peers toward T - F_i - other protected, never below
    their own floor resident; inactive peers toward their floor)
    so the floor is real, then the tenant proceeds at F.
  - Reclaim on admission (the lending settlement): an inactive
    peer's above-floor bytes are LENT, not freed -- they still
    occupy the pool. When a borrower's admission would push the
    summed resident bytes over T, the arbiter reclaims the
    inactive lender's above-floor bytes first (shrink order, down
    to its floor, never below). The invariant the measurement
    checks after every access is sum(resident) <= T. (The first
    version of this script omitted the reclaim and the invariant
    check caught summed residency at T + F -- the defect and its
    fix are recorded in the slice doc.)
  - Pinned (in-flight) experts are never arbiter-evicted: the Mojo
    shrink returns the pinned overage visibly instead of forcing
    it (J-018 contract, unchanged). The simulator holds no pins.

TENANTS (the honest server-case construction): both tenants are
sessions of the SAME OLMoE model file (the J-016 trace's model)
serving DISJOINT prompt subsets of the real J-016 trace:
  tenant A = prose + code + technical   (266 tokens, 34,048 accesses)
  tenant B = structured + numbers + instructions
                                        (311 tokens, 39,808 accesses)
This is two sessions in one process, NOT two different model files;
per-tenant caches cannot share entries in this construction (each
session holds its own payloads, as MoEStreamSession does), so the
measurement isolates the BUDGET question. Entry sharing for two
sessions of one file is a different optimisation, named in the doc
as not built. The split is defensible from J-016/J-024: tenant A
carries code (the most cache-friendly type: 700 cold pairs, isolated
fsketch hit 0.924 @512) while tenant B carries numbers +
instructions (the least friendly: ~1,010 cold pairs each, isolated
hit 0.668/0.713 @512) -- an asymmetric pair, which is exactly where
a fairness rule has something to decide.

INTERLEAVING: strict token round-robin (one token of A, one of B,
preserving each tenant's internal trace order); when a tenant's
stream is exhausted it becomes inactive and the other continues
alone under the same rule (the lending tail).

SCHEMES at shared totals T = 256 and 512 pairs (byte budgets built
exactly as J-016/J-018/J-024: pairs x mean scaled pair size 3720;
sizes scaled /1024, exact for both OLMoE layer classes; full-scale
bytes = scaled x 1024):
  (a) naive    -- each tenant sized independently at the full T
                  (the pre-J-026 behaviour; commitment 2T).
  (b) static   -- equal partition, each tenant fixed at T/2.
  (c) pool     -- floor-and-borrow as above (commitment T).
  (d) ceiling  -- each tenant ALONE at the full T (solo runs; the
                  per-tenant reference (a)'s numbers must equal
                  (d)'s exactly, since (a)'s caches are independent
                  -- the identity is checked, and (a) is then read
                  as "(d)'s quality at 2x commitment, infeasible
                  under a T budget").

FAIRNESS MEASURES: per-tenant hit rate and streamed MB per tenant
token; relative hit r_i = hit_i / hit_i_ceiling(d); worst-tenant
relative hit min_i r_i; Jain index over the relative hits,
(sum r)^2 / (N * sum r^2) -- 1.0 is perfectly equal RELATIVE
outcomes. Jain over raw hits is also reported.

VALIDATION GATE (runs first; exit 3 on failure, no two-tenant
number is reported from a failed gate): this script's fsketch runs
must reproduce EXACTLY, on the full trace,
  - the J-024 tournament's fsketch counters at 128/256/512
    (j024_tournament_results.json, global runs), and
  - the real Mojo module's replay counters at 256/512
    (j024_replay_results.txt: hits 39394/56781, streamed scaled
    128259888/63662880, bypasses 32689/14895, admissions 1773/2180,
    evictions 1516/1668, ebr 20797/12194, cold 1024),
and the pool subclass with a single tenant must reproduce the same
counters at 256/512 (its cap machinery must be a no-op solo).

Base policy everywhere: fsketch, the shipping default since J-024's
integration (single LRU segment, aged exact counters halved every
4096 accesses, admit iff candidate frequency exceeds victim's).

Usage: j026_multi.py TRACE.jsonl J024_RESULTS.json [--out RESULTS.json]
Honesty class of the two-tenant numbers: SIMULATED on the MEASURED
J-016 trace, through a simulator validated EXACT against the real
module's counters (the Mojo pool itself is unit-tested PROVEN on
the VM; see the slice doc).
"""
import argparse
import hashlib
import json
import math
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from j024_tournament import FSketchCache, load_stream, HIT  # noqa: E402

# Real-MoJO-module replay counters (docs/janas/j024_replay_results.txt).
MOJO_REPLAY = {
    256: dict(hits=39394, misses=34462, cold=1024, bypasses=32689,
              admissions=1773, evictions=1516, ebr=20797,
              streamed=128259888, entries=257, resident=949968),
    512: dict(hits=56781, misses=17075, cold=1024, bypasses=14895,
              admissions=2180, evictions=1668, ebr=12194,
              streamed=63662880, entries=512, resident=1903056),
}

TENANT_A = ("prose", "code", "technical")
TENANT_B = ("structured", "numbers", "instructions")


class PoolFSketch(FSketchCache):
    """FSketchCache plus the arbiter operations the Mojo pool drives:
    an externally-set budget (resize_budget) with shrink through the
    cache's own shrink order (lowest sketch frequency, ties by LRU --
    ExpertCache.shrink for the single-segment fsketch policy)."""

    def shrink_to(self, new_budget):
        """Evict (shrink order) until resident <= new_budget; set the
        budget. Returns evicted scaled bytes."""
        evicted_bytes = 0
        while self.resident > new_budget and self.entries:
            victim = min(
                self.entries,
                key=lambda k: (self._freq_of(k),
                               self.entries[k]["last_tick"]))
            e = self.entries.pop(victim)
            self.resident -= e["size"]
            evicted_bytes += e["size"]
            self.stats["evictions"] += 1
            self.stats["bytes_evicted"] += e["size"]
            self.evicted.add(victim)
        self.budget = new_budget
        return evicted_bytes

    def set_budget(self, new_budget):
        """Grow or hold: budget only, no eviction."""
        self.budget = new_budget


def build_tenant_streams(tokens, scaled_sizes):
    """Per-tenant token streams: list of tokens, each a list of
    (layer, expert, size) in trace order."""
    streams = {"A": [], "B": []}
    ntok = {"A": 0, "B": 0}
    for tok in tokens:
        pid = tok.get("prompt_id", "?")
        t = "A" if pid in TENANT_A else "B"
        accs = []
        for l, sel in enumerate(tok["layers"]):
            for e in sel:
                accs.append((l, e, scaled_sizes[l]))
        streams[t].append(accs)
        ntok[t] += 1
    return streams, ntok


def interleave(streams):
    """Token round-robin: [(tenant, token_accesses), ...]."""
    out = []
    a, b = streams["A"], streams["B"]
    for k in range(max(len(a), len(b))):
        if k < len(a):
            out.append(("A", a[k]))
        if k < len(b):
            out.append(("B", b[k]))
    return out


def summarise(cache, n_tokens):
    st = cache.stats
    total = st["accesses"] or 1
    full = st["bytes_streamed"] * 1024
    return dict(
        accesses=st["accesses"], hits=st["hits"], misses=st["misses"],
        cold=st["cold_misses"],
        hit_rate=round(st["hits"] / total, 6),
        bypasses=st["bypasses"], admissions=st["admissions"],
        evictions=st["evictions"],
        evicted_before_reuse=st["evicted_before_reuse"],
        streamed_full_bytes=full,
        streamed_mb_per_token=round(full / n_tokens / 1e6, 3),
        entries_now=len(cache.entries),
        resident_scaled=cache.resident_bytes())


def run_fixed(streams, ntok, budgets, order="interleaved"):
    """Schemes (a)/(b): independent fixed-budget caches (the access
    schedule cannot affect independent caches; it is kept identical
    across schemes for comparability)."""
    caches = {t: FSketchCache(budgets[t]) for t in ("A", "B")}
    max_sum = 0
    seq = interleave(streams) if order == "interleaved" else \
        [(t, accs) for t in ("A", "B") for accs in streams[t]]
    for t, accs in seq:
        c = caches[t]
        for (l, e, size) in accs:
            c.access(l, e, size)
        max_sum = max(max_sum, caches["A"].resident_bytes()
                      + caches["B"].resident_bytes())
    return ({t: summarise(caches[t], ntok[t]) for t in ("A", "B")},
            dict(max_sum_resident_scaled=max_sum))


def run_solo(stream, ntok, budget):
    cache = FSketchCache(budget)
    for accs in stream:
        for (l, e, size) in accs:
            cache.access(l, e, size)
    return summarise(cache, ntok)


def run_pool(streams, ntok, total_budget, order="interleaved"):
    """Scheme (c): floor-and-borrow, arbiter applied before every
    access (the host loop the Mojo pool is built for)."""
    floor = total_budget // 4  # F = T / (2N), N = 2
    caches = {t: PoolFSketch(total_budget) for t in ("A", "B")}
    active = {"A": True, "B": True}
    remaining = {"A": len(streams["A"]), "B": len(streams["B"])}
    arb = dict(floor_enforcements=0, shrink_backs=0,
               arbiter_evicted_scaled=0, cap_applications=0,
               lending_reclaims=0, reclaim_evicted_scaled=0)
    max_sum = 0
    seq = interleave(streams) if order == "interleaved" else \
        [(t, accs) for t in ("A", "B") for accs in streams[t]]
    for t, accs in seq:
        other = "B" if t == "A" else "A"
        for (l, e, size) in accs:
            # Protected bytes of the peer.
            if active[other]:
                prot = caches[other].resident_bytes()
            else:
                prot = min(caches[other].resident_bytes(), floor)
            cap = total_budget - prot
            if cap < floor:
                # Floor enforcement: shrink the peer toward its
                # protected level (active: T - F - 0 other protected
                # terms at N=2 is total - floor; inactive: floor),
                # never below the floor resident itself at N=2
                # because total - floor >= floor.
                target = (total_budget - floor) if active[other] \
                    else floor
                if caches[other].resident_bytes() > target:
                    arb["floor_enforcements"] += 1
                    before = caches[other].resident_bytes()
                    caches[other].shrink_to(target)
                    arb["arbiter_evicted_scaled"] += \
                        (before - caches[other].resident_bytes())
                cap = floor
            # Apply own cap: shrink-back if the cap fell below
            # resident, else just set the budget.
            if caches[t].resident_bytes() > cap:
                arb["shrink_backs"] += 1
                before = caches[t].resident_bytes()
                caches[t].shrink_to(cap)
                arb["arbiter_evicted_scaled"] += \
                    (before - caches[t].resident_bytes())
            else:
                caches[t].set_budget(cap)
            arb["cap_applications"] += 1
            caches[t].access(l, e, size)
            # Reclaim on admission: if the summed residency broke
            # the pool total (only possible against an inactive
            # lender, whose protected bytes are just its floor),
            # shrink the inactive lender toward its floor until
            # the total holds again.
            s = caches["A"].resident_bytes() + caches["B"].resident_bytes()
            if s > total_budget and not active[other] \
                    and caches[other].resident_bytes() > floor:
                arb["lending_reclaims"] += 1
                before = caches[other].resident_bytes()
                caches[other].shrink_to(
                    max(floor, before - (s - total_budget)))
                arb["reclaim_evicted_scaled"] += \
                    (before - caches[other].resident_bytes())
                s = caches["A"].resident_bytes() \
                    + caches["B"].resident_bytes()
            assert s <= total_budget, \
                f"pool invariant broken: sum {s} > total {total_budget}"
            if s > max_sum:
                max_sum = s
        remaining[t] -= 1
        if remaining[t] == 0:
            active[t] = False
    out = {t: summarise(caches[t], ntok[t]) for t in ("A", "B")}
    return out, dict(max_sum_resident_scaled=max_sum, floor_scaled=floor,
                     arbiter=arb)


def run_fixed_phases(streams, ntok, budgets, plan):
    """plan: [(tenant, n_tokens|None), ...] served in order."""
    caches = {t: FSketchCache(budgets[t]) for t in ("A", "B")}
    pos = {"A": 0, "B": 0}
    max_sum = 0
    for t, count in plan:
        toks = streams[t][pos[t]:] if count is None \
            else streams[t][pos[t]:pos[t] + count]
        pos[t] += len(toks)
        for accs in toks:
            for (l, e, size) in accs:
                caches[t].access(l, e, size)
            s = caches["A"].resident_bytes() + caches["B"].resident_bytes()
            if s > max_sum:
                max_sum = s
    return ({t: summarise(caches[t], ntok[t]) for t in ("A", "B")},
            dict(max_sum_resident_scaled=max_sum))


def run_pool_phases(streams, ntok, total_budget, plan):
    """Floor-and-borrow over explicit phases: the serving tenant is
    active, the other inactive (session open, not serving). This is
    the return-guarantee schedule: a tenant that lent its cache
    while idle comes back and its floor is re-established."""
    floor = total_budget // 4
    caches = {t: PoolFSketch(total_budget) for t in ("A", "B")}
    arb = dict(floor_enforcements=0, shrink_backs=0,
               arbiter_evicted_scaled=0, cap_applications=0,
               lending_reclaims=0, reclaim_evicted_scaled=0)
    max_sum = 0
    pos = {"A": 0, "B": 0}
    for t, count in plan:
        other = "B" if t == "A" else "A"
        toks = streams[t][pos[t]:] if count is None \
            else streams[t][pos[t]:pos[t] + count]
        pos[t] += len(toks)
        for accs in toks:
            for (l, e, size) in accs:
                prot = min(caches[other].resident_bytes(), floor)
                cap = total_budget - prot
                if cap < floor:
                    arb["floor_enforcements"] += 1
                    before = caches[other].resident_bytes()
                    caches[other].shrink_to(floor)
                    arb["arbiter_evicted_scaled"] += \
                        (before - caches[other].resident_bytes())
                    cap = floor
                if caches[t].resident_bytes() > cap:
                    arb["shrink_backs"] += 1
                    before = caches[t].resident_bytes()
                    caches[t].shrink_to(cap)
                    arb["arbiter_evicted_scaled"] += \
                        (before - caches[t].resident_bytes())
                else:
                    caches[t].set_budget(cap)
                arb["cap_applications"] += 1
                caches[t].access(l, e, size)
                s = caches["A"].resident_bytes() \
                    + caches["B"].resident_bytes()
                if s > total_budget \
                        and caches[other].resident_bytes() > floor:
                    arb["lending_reclaims"] += 1
                    before = caches[other].resident_bytes()
                    caches[other].shrink_to(
                        max(floor, before - (s - total_budget)))
                    arb["reclaim_evicted_scaled"] += \
                        (before - caches[other].resident_bytes())
                    s = caches["A"].resident_bytes() \
                        + caches["B"].resident_bytes()
                assert s <= total_budget
                if s > max_sum:
                    max_sum = s
    out = {t: summarise(caches[t], ntok[t]) for t in ("A", "B")}
    return out, dict(max_sum_resident_scaled=max_sum,
                     floor_scaled=floor, arbiter=arb)


def jain(values):
    n = len(values)
    s = sum(values)
    sq = sum(v * v for v in values)
    if sq == 0:
        return 1.0
    return round((s * s) / (n * sq), 6)


def fairness(per_tenant, ceiling):
    rel = {t: per_tenant[t]["hit_rate"] / ceiling[t]["hit_rate"]
           for t in ("A", "B")}
    return dict(
        relative_hit={t: round(rel[t], 6) for t in ("A", "B")},
        worst_relative_hit=round(min(rel.values()), 6),
        jain_relative=jain(list(rel.values())),
        jain_raw_hit=jain([per_tenant[t]["hit_rate"] for t in ("A", "B")]),
        total_streamed_full_bytes=sum(
            per_tenant[t]["streamed_full_bytes"] for t in ("A", "B")))


def main(argv=None):
    ap = argparse.ArgumentParser(description="J-026 multi-model residency")
    ap.add_argument("trace")
    ap.add_argument("j024_results")
    ap.add_argument("--out")
    args = ap.parse_args(argv)

    trace_bytes = Path(args.trace).read_bytes()
    trace_sha = hashlib.sha256(trace_bytes).hexdigest()
    header, tokens, accesses, mean_scaled = load_stream(args.trace)
    n_tokens = len(tokens)
    scaled_sizes = [s // 1024 for s in header["expert_bytes_per_layer"]]
    j024 = json.loads(Path(args.j024_results).read_text())
    print(f"trace sha256={trace_sha} tokens={n_tokens} "
          f"accesses={len(accesses)} mean_scaled={mean_scaled}")

    # ---- Validation gate ---------------------------------------------
    gate = {}
    gate_ok = True
    for pairs in (128, 256, 512):
        budget = pairs * mean_scaled
        cache = FSketchCache(budget)
        for (l, e, size, pid, w) in accesses:
            cache.access(l, e, size)
        ref = j024["global_runs"][f"fsketch@{pairs}"]
        checks = dict(
            hits=cache.stats["hits"] == ref["hits"],
            misses=cache.stats["misses"] == ref["misses"],
            cold=cache.stats["cold_misses"] == ref["cold"],
            bypasses=cache.stats["bypasses"] == ref["bypasses"],
            admissions=cache.stats["admissions"] == ref["admissions"],
            evictions=cache.stats["evictions"] == ref["evictions"],
            ebr=cache.stats["evicted_before_reuse"]
            == ref["evicted_before_reuse"],
            streamed=cache.stats["bytes_streamed"] * 1024
            == ref["streamed_full_bytes"],
            entries=len(cache.entries) == ref["entries_now"],
            resident=cache.resident_bytes() == ref["resident_scaled"])
        ok = all(checks.values())
        if pairs in MOJO_REPLAY:
            m = MOJO_REPLAY[pairs]
            mojo_ok = (
                cache.stats["hits"] == m["hits"]
                and cache.stats["bytes_streamed"] == m["streamed"]
                and cache.stats["bypasses"] == m["bypasses"]
                and cache.stats["admissions"] == m["admissions"]
                and cache.stats["evictions"] == m["evictions"]
                and cache.stats["evicted_before_reuse"] == m["ebr"]
                and cache.stats["cold_misses"] == m["cold"]
                and len(cache.entries) == m["entries"]
                and cache.resident_bytes() == m["resident"])
            checks["mojo_replay"] = mojo_ok
            ok = ok and mojo_ok
        gate[f"tournament_fsketch@{pairs}"] = \
            "EXACT" if ok else f"MISMATCH {checks} {cache.stats} vs {ref}"
        print(f"gate fsketch@{pairs}: "
              f"{gate[f'tournament_fsketch@{pairs}']}")
        if not ok:
            gate_ok = False
    # Pool subclass, single tenant, must be a no-op solo.
    for pairs in (256, 512):
        budget = pairs * mean_scaled
        cache = PoolFSketch(budget)
        for (l, e, size, pid, w) in accesses:
            cache.access(l, e, size)
        ref = j024["global_runs"][f"fsketch@{pairs}"]
        ok = (cache.stats["hits"] == ref["hits"]
              and cache.stats["bytes_streamed"] * 1024
              == ref["streamed_full_bytes"]
              and cache.stats["evictions"] == ref["evictions"])
        gate[f"pool_solo_fsketch@{pairs}"] = "EXACT" if ok else "MISMATCH"
        print(f"gate pool-solo fsketch@{pairs}: "
              f"{gate[f'pool_solo_fsketch@{pairs}']}")
        if not ok:
            gate_ok = False
    if not gate_ok:
        print("VALIDATION GATE FAILED -- two-tenant numbers withheld",
              file=sys.stderr)
        return 3

    # ---- Tenants -------------------------------------------------------
    streams, ntok = build_tenant_streams(tokens, scaled_sizes)
    print(f"tenant A {TENANT_A}: tokens={ntok['A']} "
          f"accesses={sum(len(x) for x in streams['A'])}")
    print(f"tenant B {TENANT_B}: tokens={ntok['B']} "
          f"accesses={sum(len(x) for x in streams['B'])}")

    results = dict(
        trace_sha256=trace_sha, n_tokens=n_tokens,
        n_accesses=len(accesses), mean_scaled_pair_bytes=mean_scaled,
        validation_gate=gate,
        tenants=dict(
            A=dict(prompts=list(TENANT_A), tokens=ntok["A"],
                   accesses=sum(len(x) for x in streams["A"])),
            B=dict(prompts=list(TENANT_B), tokens=ntok["B"],
                   accesses=sum(len(x) for x in streams["B"]))),
        totals={}, schemes={})

    for pairs in (256, 512):
        total_budget = pairs * mean_scaled
        half = (pairs // 2) * mean_scaled
        # (d) ceiling: solo at full budget.
        ceiling = {t: run_solo(streams[t], ntok[t], total_budget)
                   for t in ("A", "B")}
        # (a) naive: each at full budget, interleaved.
        naive, naive_meta = run_fixed(
            streams, ntok, {"A": total_budget, "B": total_budget})
        identity = all(
            naive[t][k] == ceiling[t][k]
            for t in ("A", "B")
            for k in ("hits", "misses", "cold", "bypasses", "admissions",
                      "evictions", "evicted_before_reuse",
                      "streamed_full_bytes"))
        # (b) static equal partition.
        static, static_meta = run_fixed(
            streams, ntok, {"A": half, "B": half})
        # (c) shared pool, floor-and-borrow.
        pool, pool_meta = run_pool(streams, ntok, total_budget)

        block = dict(
            total_pairs=pairs, total_budget_scaled=total_budget,
            ceiling=ceiling, naive_identity_vs_ceiling=identity,
            naive=dict(per_tenant=naive, meta=naive_meta,
                       commitment_pairs=2 * pairs,
                       fairness=fairness(naive, ceiling)),
            static=dict(per_tenant=static, meta=static_meta,
                        commitment_pairs=pairs,
                        fairness=fairness(static, ceiling)),
            pool=dict(per_tenant=pool, meta=pool_meta,
                      commitment_pairs=pairs,
                      fairness=fairness(pool, ceiling)))
        results["schemes"][f"total@{pairs}"] = block
        for name in ("ceiling",):
            for t in ("A", "B"):
                v = ceiling[t]
                print(f"T={pairs} {name} {t}: hit={v['hit_rate']} "
                      f"streamed/token={v['streamed_mb_per_token']} MB "
                      f"cold={v['cold']}")
        for name, blk in (("naive", block["naive"]),
                          ("static", block["static"]),
                          ("pool", block["pool"])):
            f = blk["fairness"]
            for t in ("A", "B"):
                v = blk["per_tenant"][t]
                print(f"T={pairs} {name} {t}: hit={v['hit_rate']} "
                      f"streamed/token={v['streamed_mb_per_token']} MB "
                      f"rel={f['relative_hit'][t]}")
            print(f"T={pairs} {name}: worst_rel="
                  f"{f['worst_relative_hit']} jain_rel={f['jain_relative']} "
                  f"jain_raw={f['jain_raw_hit']} "
                  f"max_sum_resident={blk['meta']['max_sum_resident_scaled']} "
                  f"commitment={blk['commitment_pairs']} pairs")
        print(f"T={pairs} naive==ceiling identity: {identity}; "
              f"pool arbiter: {pool_meta['arbiter']}")

        # Secondary schedule: sequential phases (both sessions open,
        # one serving at a time -- traffic shifts between models).
        static_seq, static_seq_meta = run_fixed(
            streams, ntok, {"A": half, "B": half}, order="sequential")
        pool_seq, pool_seq_meta = run_pool(
            streams, ntok, total_budget, order="sequential")
        block["sequential"] = dict(
            static=dict(per_tenant=static_seq, meta=static_seq_meta,
                        fairness=fairness(static_seq, ceiling)),
            pool=dict(per_tenant=pool_seq, meta=pool_seq_meta,
                      fairness=fairness(pool_seq, ceiling)))
        for name, blk in (("static-seq", block["sequential"]["static"]),
                          ("pool-seq", block["sequential"]["pool"])):
            f = blk["fairness"]
            for t in ("A", "B"):
                v = blk["per_tenant"][t]
                print(f"T={pairs} {name} {t}: hit={v['hit_rate']} "
                      f"streamed/token={v['streamed_mb_per_token']} MB "
                      f"rel={f['relative_hit'][t]}")
            print(f"T={pairs} {name}: worst_rel="
                  f"{f['worst_relative_hit']} jain_rel={f['jain_relative']} "
                  f"max_sum_resident={blk['meta']['max_sum_resident_scaled']}")
        print(f"T={pairs} pool-seq arbiter: {pool_seq_meta['arbiter']}")

        # Return schedule: A serves its first half, B serves in
        # full (A idle, lending), A returns for its second half.
        half_a = ntok["A"] // 2
        plan = [("A", half_a), ("B", None), ("A", None)]
        static_ret, static_ret_meta = run_fixed_phases(
            streams, ntok, {"A": half, "B": half}, plan)
        pool_ret, pool_ret_meta = run_pool_phases(
            streams, ntok, total_budget, plan)
        block["return"] = dict(
            plan=[(t, c) for (t, c) in plan],
            static=dict(per_tenant=static_ret, meta=static_ret_meta,
                        fairness=fairness(static_ret, ceiling)),
            pool=dict(per_tenant=pool_ret, meta=pool_ret_meta,
                      fairness=fairness(pool_ret, ceiling)))
        for name, blk in (("static-ret", block["return"]["static"]),
                          ("pool-ret", block["return"]["pool"])):
            f = blk["fairness"]
            for t in ("A", "B"):
                v = blk["per_tenant"][t]
                print(f"T={pairs} {name} {t}: hit={v['hit_rate']} "
                      f"streamed/token={v['streamed_mb_per_token']} MB "
                      f"rel={f['relative_hit'][t]}")
            print(f"T={pairs} {name}: worst_rel="
                  f"{f['worst_relative_hit']} jain_rel={f['jain_relative']} "
                  f"max_sum_resident={blk['meta']['max_sum_resident_scaled']}")
        print(f"T={pairs} pool-ret arbiter: {pool_ret_meta['arbiter']}")

    if args.out:
        Path(args.out).write_text(json.dumps(results, indent=1) + "\n")
        print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
