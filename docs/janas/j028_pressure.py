#!/usr/bin/env python3
"""J-028 memory-pressure measurement (Project Aesir, Janas road).

Roadmap text (J-028): "Behaviour when free memory shrinks mid-run
(another process takes RAM): the cache sheds, the run continues or
refuses cleanly -- never swaps the machine to death. Janas's own
warning, engineered against."

BINDING DESIGN (J-017 section 5.3 + section 4, decided before this
slice): cache sheds before anything else; order is expert cache
shrinks -> at the floor the run refuses cleanly with the reason
stated; the resident set and the KV cache are never cannibalised;
a shrink sheds policy-ordered entries, pins in-flight experts, and
completes within the current token. The mechanism under test is the
real module's (expert_cache.mojo, J-028): plan_pressure_budget
turns a fresh free-memory sample into CONTINUE / SHRINK / REGROW
(capped at the open-time budget and the hard cap) / REFUSE (below
the floor = one token's full routed demand), the host applies
SHRINK/REGROW via ExpertCache.resize_budget and REFUSE via
shed_to_resident(0) followed by a clean stop -- never a resize to
a non-positive budget. This simulator mirrors that host loop at
token boundaries (the documented sampling cadence: per token
boundary, never mid-token, so no pin spans an application point;
pin behaviour itself is proven by the Mojo unit tests, not here).

PRE-REGISTERED VERDICT RULES (stated BEFORE measuring; doc
J028_MEMORY_PRESSURE.md section 2 states the same text). The slice
passes iff ALL hold:
  (a) after every pressure event, resident <= new budget (the
      simulator holds no pins, so the explicitly-reported pinned
      overage the rule allows is 0 throughout; any violation
      fails the slice);
  (b) every non-refusal schedule completes the full trace with
      accounting closing (hits + misses == accesses == 73,856;
      admissions - evictions == entries at every token end);
  (c) the below-floor schedule REFUSES at the stated token (288),
      sheds to zero resident bytes BEFORE refusing, serves exactly
      the tokens before it (288 tokens / 36,864 accesses), and
      never resizes to a non-positive budget;
  (d) degradation vs the no-pressure baseline (hit rate, streamed
      bytes, per-token streamed MB) is reported in full for every
      schedule, whatever it is -- no threshold is set on it; the
      honesty is the requirement.
The no-shed counterfactual (what a cache that refused to shed
would have held against the pressured allowance) is reported as
the swap-risk quantity: max over tokens of (no-shed resident -
pressured budget), and the token count where it is positive.
SIMULATED by construction and named as such.

SCHEDULES (budgets in pairs; open budget 512 pairs, the J-024
operating point; floor 128 pairs = one token's full routed demand,
8 experts x 16 layers, exact in pairs by the trace's construction;
events apply BEFORE the named token):
  BASE      no events (the no-pressure baseline).
  STEP      512 -> 256 at token 192 -> 128 (the floor) at 384:
            two clean step-downs mid-session, ending exactly at
            the floor, where the run must still continue.
  CRASH     512 -> 64 at token 288: a deep grab to half the floor;
            the run must refuse at 288, shed first, serve no
            further token.
  RECOVERY  512 -> 256 at 144 -> 128 at 288 -> regrow to 512 at
            360: pressure that eases; regrow restores the cap (never
            above the open budget) but shed entries must re-earn
            residency through demand.
  SQUEEZE   gradual: -32 pairs every 48 tokens from token 48
            (480, 448, ..., 160 at token 528): a slow squeeze that
            never reaches the floor.

VALIDATION GATE (runs first; exit 3 on failure, no pressure number
is reported from a failed gate): this script's no-pressure fsketch
base must reproduce EXACTLY, on the full J-016 trace (sha256
re-verified),
  - the J-024 tournament's fsketch counters at 128/256/512, and
  - the real Mojo module's replay counters at 128/256/512
    (j024_replay_results.txt).

Cache under test: fsketch, the shipping default since J-024's
integration. Shrink order in the simulator is the real module's
shed order for fsketch (lowest sketch frequency, ties by LRU --
ExpertCache.shed_to_resident via resize_budget), NOT the admission
path's LRU victim; the J-028 Mojo replay (j028_replay.mojo) drives
the real module through RECOVERY and must reproduce this
simulator's RECOVERY counters EXACTLY.

Usage: j028_pressure.py TRACE.jsonl J024_RESULTS.json [--out R.json]
Honesty class: SIMULATED on the MEASURED J-016 trace, through a
simulator validated EXACT against the real module (gate above);
RECOVERY's counters are additionally real-module numbers via the
replay cross-check filed beside this script.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from j024_tournament import FSketchCache, load_stream  # noqa: E402

OPEN_PAIRS = 512
FLOOR_PAIRS = 128

SCHEDULES = {
    "base": {},
    "step": {192: 256, 384: 128},
    "crash": {288: 64},
    "recovery": {144: 256, 288: 128, 360: 512},
    "squeeze": {48 * k: 512 - 32 * k for k in range(1, 12)},
}

# Real-MoJo-module replay counters (docs/janas/j024_replay_results.txt).
MOJO_REPLAY = {
    128: dict(hits=25953, misses=47903, cold=1024, bypasses=46724,
              admissions=1179, evictions=1050, ebr=22335,
              streamed=178149792, entries=129, resident=474336),
    256: dict(hits=39394, misses=34462, cold=1024, bypasses=32689,
              admissions=1773, evictions=1516, ebr=20797,
              streamed=128259888, entries=257, resident=949968),
    512: dict(hits=56781, misses=17075, cold=1024, bypasses=14895,
              admissions=2180, evictions=1668, ebr=12194,
              streamed=63662880, entries=512, resident=1903056),
}


class PressuredFSketch(FSketchCache):
    """FSketchCache plus the J-028 host operations, mirroring the
    real module: shrink through the cache's shed order (lowest
    sketch frequency, ties by LRU -- shed_to_resident), regrow as a
    cap-only change (resize_budget's growing case)."""

    def shrink_to(self, new_budget):
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

    def _shed_to_zero(self):
        """The refusal shed: shed_to_resident(0) -- evict to a zero
        resident ceiling WITHOUT changing the budget. No pins are
        held at a token boundary, so this empties the cache."""
        evicted_bytes = 0
        while self.entries:
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
        return evicted_bytes

    def set_budget(self, new_budget):
        self.budget = new_budget


def build_token_stream(tokens, scaled_sizes):
    """Per-token access lists in trace order: (layer, expert, size)."""
    stream = []
    for tok in tokens:
        accs = []
        for l, sel in enumerate(tok["layers"]):
            for e in sel:
                accs.append((l, e, scaled_sizes[l]))
        stream.append(accs)
    return stream


def summarise(cache, n_tokens_served):
    st = cache.stats
    total = st["accesses"] or 1
    return dict(
        accesses=st["accesses"], hits=st["hits"], misses=st["misses"],
        cold=st["cold_misses"],
        hit_rate=round(st["hits"] / total, 6),
        bypasses=st["bypasses"], admissions=st["admissions"],
        evictions=st["evictions"],
        evicted_before_reuse=st["evicted_before_reuse"],
        streamed_scaled=st["bytes_streamed"],
        streamed_full_bytes=st["bytes_streamed"] * 1024,
        streamed_mb_per_token=round(
            st["bytes_streamed"] * 1024 / 1e6 / max(n_tokens_served, 1), 3),
        entries_now=len(cache.entries),
        resident_scaled=cache.resident_bytes(),
        tokens_served=n_tokens_served,
    )


def run_schedule(name, token_stream, mean_scaled, base_resident_by_token):
    events = SCHEDULES[name]
    cache = PressuredFSketch(OPEN_PAIRS * mean_scaled)
    event_log = []
    invariant_violations = 0
    accounting_violations = 0
    refusal = None
    served = 0
    for t, accs in enumerate(token_stream):
        if t in events:
            pairs = events[t]
            target = pairs * mean_scaled
            if pairs < FLOOR_PAIRS:
                # REFUSE per the host contract: shed to zero first
                # (shed_to_resident(0); the budget is never resized
                # to a non-positive value), then stop cleanly.
                resident_before = cache.resident_bytes()
                cache._shed_to_zero()
                refusal = dict(
                    token=t, pressured_pairs=pairs,
                    floor_pairs=FLOOR_PAIRS,
                    resident_before_shed_scaled=resident_before,
                    resident_after_shed_scaled=cache.resident_bytes(),
                    entries_after_shed=len(cache.entries),
                    accesses_served=cache.stats["accesses"],
                )
                event_log.append(dict(
                    token=t, decision="refuse", to_pairs=pairs,
                    resident_after_scaled=cache.resident_bytes()))
                break
            if target < cache.budget:
                cache.shrink_to(target)
                decision = "shrink"
            elif target > cache.budget:
                cache.set_budget(target)
                decision = "regrow"
            else:
                decision = "continue"
            event_log.append(dict(
                token=t, decision=decision, to_pairs=pairs,
                resident_after_scaled=cache.resident_bytes()))
        for (l, e, size) in accs:
            cache.access(l, e, size)
        served = t + 1
        if cache.resident_bytes() > cache.budget:
            invariant_violations += 1
        st = cache.stats
        if st["hits"] + st["misses"] != st["accesses"]:
            accounting_violations += 1
        if st["admissions"] - st["evictions"] != len(cache.entries):
            accounting_violations += 1
    summary = summarise(cache, served)
    # No-shed counterfactual: the BASE run's resident trajectory
    # against this schedule's allowance at each token.
    max_excess_scaled = 0
    tokens_over = 0
    for t in range(len(token_stream)):
        allowed = OPEN_PAIRS * mean_scaled
        for et, p in sorted(events.items()):
            if et <= t:
                allowed = p * mean_scaled
        excess = base_resident_by_token[t] - allowed
        if excess > 0:
            tokens_over += 1
            max_excess_scaled = max(max_excess_scaled, excess)
        if refusal and t >= refusal["token"]:
            break
    summary["invariant_violations"] = invariant_violations
    summary["accounting_violations"] = accounting_violations
    summary["events"] = event_log
    summary["refusal"] = refusal
    summary["counterfactual_no_shed"] = dict(
        max_excess_full_bytes=max_excess_scaled * 1024,
        tokens_resident_over_allowance=tokens_over,
    )
    return summary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("trace")
    ap.add_argument("j024_results")
    ap.add_argument("--out")
    args = ap.parse_args()

    raw = Path(args.trace).read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    print(f"trace sha256 {sha}")
    assert sha == "85e1d2413cbfcd43516a03d8463c7266d486cf0f0d0a6ed3104d09111facf99a", \
        "trace sha mismatch -- refusing to measure an unpinned trace"

    header, tokens, accesses, mean_scaled = load_stream(args.trace)
    scaled_sizes = [s // 1024 for s in header["expert_bytes_per_layer"]]
    assert mean_scaled == 3720
    token_stream = build_token_stream(tokens, scaled_sizes)
    assert len(token_stream) == 577
    assert sum(len(a) for a in token_stream) == 73856
    per_token_floor = sum(scaled_sizes) * header["top_k"]
    assert per_token_floor == FLOOR_PAIRS * mean_scaled, per_token_floor

    # ---- validation gate -------------------------------------------
    tourn = json.loads(Path(args.j024_results).read_text())
    gate = {}
    ok = True
    for pairs in (128, 256, 512):
        cache = FSketchCache(pairs * mean_scaled)
        for (l, e, size, pid, w) in accesses:
            cache.access(l, e, size)
        st = cache.stats
        got = dict(hits=st["hits"], misses=st["misses"],
                   cold=st["cold_misses"], bypasses=st["bypasses"],
                   admissions=st["admissions"], evictions=st["evictions"],
                   ebr=st["evicted_before_reuse"],
                   streamed=st["bytes_streamed"],
                   entries=len(cache.entries),
                   resident=cache.resident_bytes())
        want_t = tourn["global_runs"][f"fsketch@{pairs}"]
        t_ok = (got["hits"] == want_t["hits"]
                and got["misses"] == want_t["misses"]
                and got["cold"] == want_t["cold"]
                and got["bypasses"] == want_t["bypasses"]
                and got["admissions"] == want_t["admissions"]
                and got["evictions"] == want_t["evictions"]
                and got["ebr"] == want_t["evicted_before_reuse"]
                and got["streamed"] * 1024 == want_t["streamed_full_bytes"]
                and got["entries"] == want_t["entries_now"]
                and got["resident"] == want_t["resident_scaled"])
        m_ok = all(got[k] == v for k, v in MOJO_REPLAY[pairs].items())
        gate[f"tournament@{pairs}"] = "EXACT" if t_ok else f"MISMATCH {got} vs {want_t}"
        gate[f"mojo_replay@{pairs}"] = "EXACT" if m_ok else f"MISMATCH {got} vs {MOJO_REPLAY[pairs]}"
        ok = ok and t_ok and m_ok
        print(f"gate fsketch@{pairs}: tournament={'EXACT' if t_ok else 'FAIL'} "
              f"mojo={'EXACT' if m_ok else 'FAIL'}")
    if not ok:
        print("VALIDATION GATE FAILED -- no pressure number reported")
        sys.exit(3)
    print("validation gate: PASS (6/6 EXACT)")

    # Base resident trajectory for the counterfactual.
    base_cache = FSketchCache(OPEN_PAIRS * mean_scaled)
    base_resident_by_token = []
    for accs in token_stream:
        for (l, e, size) in accs:
            base_cache.access(l, e, size)
        base_resident_by_token.append(base_cache.resident_bytes())

    results = {"trace_sha256": sha, "n_tokens": len(token_stream),
               "n_accesses": 73856, "open_pairs": OPEN_PAIRS,
               "floor_pairs": FLOOR_PAIRS,
               "validation_gate": gate, "schedules": {}}
    for name in ("base", "step", "crash", "recovery", "squeeze"):
        s = run_schedule(name, token_stream, mean_scaled,
                         base_resident_by_token)
        results["schedules"][name] = s
        print(f"{name}: hit={s['hit_rate']} streamed_full={s['streamed_full_bytes']} "
              f"served={s['tokens_served']} accesses={s['accesses']} "
              f"evictions={s['evictions']} inv_viol={s['invariant_violations']} "
              f"acct_viol={s['accounting_violations']} refusal={s['refusal']}")

    base = results["schedules"]["base"]
    for name, s in results["schedules"].items():
        if name == "base":
            continue
        denom = s["tokens_served"] or 1
        base_rate = base["streamed_full_bytes"] / 577
        s["degradation_vs_base"] = dict(
            hit_rate_delta=round(s["hit_rate"] - base["hit_rate"], 6),
            streamed_bytes_ratio_per_served_token=round(
                (s["streamed_full_bytes"] / denom) / base_rate, 6),
        )
    verdict = dict(
        rule_a_invariant=all(
            s["invariant_violations"] == 0
            for s in results["schedules"].values()),
        rule_b_accounting=all(
            s["accounting_violations"] == 0
            and (s["accesses"] == 73856 or s["refusal"] is not None)
            for s in results["schedules"].values()),
        rule_c_refusal=(
            results["schedules"]["crash"]["refusal"] is not None
            and results["schedules"]["crash"]["refusal"]["token"] == 288
            and results["schedules"]["crash"]["refusal"]
                ["resident_after_shed_scaled"] == 0
            and results["schedules"]["crash"]["refusal"]
                ["accesses_served"] == 288 * 128),
        rule_d_reported=True,
    )
    verdict["slice_passes"] = all(verdict.values())
    results["verdict"] = verdict
    print("verdict:", verdict)
    if args.out:
        Path(args.out).write_text(json.dumps(results, indent=1) + "\n")
        print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
