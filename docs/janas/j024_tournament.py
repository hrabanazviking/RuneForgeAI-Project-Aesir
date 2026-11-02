#!/usr/bin/env python3
"""J-024 cache policy tournament (Project Aesir, Janas clean-room road).

Offline tournament of expert-cache eviction policies on the J-016 measured
OLMoE trace (j016_trace_olmoe.jsonl, 577 tokens, 73,856 accesses; the trace
itself is kept in campaign records, NOT committed -- this script takes its
path as an argument).

Policies:
  lru       -- faithful J-016/J-018 LRU baseline (byte budget).
  lfu       -- faithful J-016/J-018 LFU baseline (byte budget, cumulative
               frequency, no aging, no gate).
  segmented -- the J-018 shipping policy (probation 1/8 + frequency gate +
               promotion on second touch + TinyLFU-style aging of exact
               counters), run through a fast re-implementation that is
               VALIDATED EXACT against the J-020 Python replica of the real
               Mojo ExpertCache (j020_policy.py) at budgets 128/512 before
               any tournament number is trusted; the gate also checks the
               replica numbers themselves against the recorded J-018 replay
               results (j018_replay_results.txt).
  rda       -- reuse-distance-aware (NEW in this slice; definition in
               J024_CACHE_POLICY_TOURNAMENT.md): single segment; admission
               bypass when the access's exact stack distance (distinct
               (layer,expert) pairs since the pair's previous use, computed
               online from past accesses only) is >= the pair capacity --
               such a pair could not have survived in a capacity-sized
               cache, so admitting it only churns; eviction picks the
               resident whose last observed stack distance is largest
               (never-reused residents score by the distinct pairs that
               have flowed since their admission), ties by LRU.
  fsketch   -- TinyLFU-style frequency-sketch (NEW as a standalone entry;
               the sketch machinery itself is J-018's): single segment,
               LRU victim, admission only when the candidate's aged
               sketch frequency exceeds the victim's; otherwise bypass.
               Exact counters with halving every 4096 accesses, the same
               aging cadence as the segmented policy, so the comparison
               isolates segmentation vs sketch-admission.

Budgets are byte budgets built exactly as J-016/J-018 built them:
pairs x mean scaled pair size (3720 = mean of header expert_bytes_per_layer
/ 1024; the division is exact for both OLMoE layer classes). Sizes are the
scaled sizes; full-scale bytes = scaled x 1024, exact by construction.

Also measured: the J-017 D6 dropping trial's OFFLINE part. Documented
starting candidate (Janas public docs via the Part I census): when the
cache holds < 1/5 of the model's experts, a non-resident routed expert
whose router weight is < 0.8/k is not read. Simulated on the trace's
recorded weights (which are renormalised top-8 shares -- every token-layer
sums to 1.0; see the doc for why that caveat matters) over the lru and
segmented policies at budget 128 (the only tournament budget under 1/5 of
1024 pairs), plus a clearly-labelled what-if at 512 with the cache-fraction
condition waived. The faithfulness (agreement-cost) leg is NOT simulated
here -- it needs graded live runs and is recorded NOT PROVEN in the doc.

Usage: j024_tournament.py TRACE.jsonl [--out RESULTS.json]
Exit 0 on success; exit 3 if the validation gate fails (a simulator bug --
no tournament number may be reported from a failed gate).
"""
import argparse
import hashlib
import json
import sys
from collections import Counter, deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from j020_policy import ExpertCacheReplica, HIT as REPLICA_HIT  # noqa: E402

HIT = 1
MISS_ADMITTED = 0
MISS_BYPASSED = -1
MISS_TOO_LARGE = -2
PROBATION = 0
MAIN = 1
AGING = 4096
KEYMUL = 1048576

# J-018 recorded replay (real Mojo module), from j018_replay_results.txt.
J018_REFERENCE = {
    # (policy, budget_pairs): dict of exact recorded counters
    ("lru", 128): dict(hits=13733, misses=60123, cold=1024, bypasses=0,
                       admissions=60123, promotions=0, evictions=59995,
                       ebr=58369, streamed=223620864),
    ("lfu", 128): dict(hits=22215, misses=51641, cold=1024, bypasses=0,
                       admissions=51641, promotions=0, evictions=51514,
                       ebr=50139, streamed=191958528),
    ("segmented", 128): dict(hits=24605, misses=49251, cold=1024,
                             bypasses=42551, admissions=6700,
                             promotions=1021, evictions=6573, ebr=35416,
                             streamed=183104688),
    ("lru", 512): dict(hits=54691, misses=19165, cold=1024, bypasses=0,
                       admissions=19165, promotions=0, evictions=18653,
                       ebr=18131, streamed=71264496),
    ("lfu", 512): dict(hits=55200, misses=18656, cold=1024, bypasses=0,
                       admissions=18656, promotions=0, evictions=18144,
                       ebr=17620, streamed=69423552),
    ("segmented", 512): dict(hits=56165, misses=17691, cold=1024,
                             bypasses=8149, admissions=9542,
                             promotions=3089, evictions=9031, ebr=14728,
                             streamed=65896320),
}


def load_stream(trace_path):
    header = None
    tokens = []
    with open(trace_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            if obj.get("type") == "header":
                header = obj
            elif obj.get("type") == "token":
                tokens.append(obj)
            elif obj.get("type") == "end":
                break
    assert header is not None
    full_sizes = header["expert_bytes_per_layer"]
    assert all(s % 1024 == 0 for s in full_sizes), "scaled sizes must be exact"
    scaled_sizes = [s // 1024 for s in full_sizes]
    mean_scaled = sum(scaled_sizes) // len(scaled_sizes)
    assert sum(scaled_sizes) % len(scaled_sizes) == 0
    accesses = []  # (layer, expert, size_scaled, prompt_id, weight|None)
    for tok in tokens:
        pid = tok.get("prompt_id", "?")
        weights = tok.get("weights")
        for l, sel in enumerate(tok["layers"]):
            for j, e in enumerate(sel):
                w = weights[l][j] if weights else None
                accesses.append((l, e, scaled_sizes[l], pid, w))
    return header, tokens, accesses, mean_scaled


class EvictedWindow:
    """Replica-exact evicted-before-reuse window (FIFO, cap 8192 events)."""

    def __init__(self, cap=8192):
        self.cap = cap
        self.q = deque()
        self.counts = Counter()

    def add(self, key):
        self.q.append(key)
        self.counts[key] += 1
        if len(self.q) > self.cap:
            old = self.q.popleft()
            self.counts[old] -= 1
            if self.counts[old] == 0:
                del self.counts[old]

    def __contains__(self, key):
        return key in self.counts


def fresh_stats():
    return dict(accesses=0, hits=0, misses=0, cold_misses=0, bypasses=0,
                too_large=0, admissions=0, promotions=0, evictions=0,
                evicted_before_reuse=0, bytes_streamed=0, bytes_evicted=0)


class FastCache:
    """Statement-faithful fast version of the J-020 replica (lru/lfu/
    segmented). Decisions are identical by construction: victim choice is a
    total order on (frequency, last_tick) / last_tick, which are unique per
    entry, so list order (and swap-remove) cannot change outcomes; segment
    byte totals are maintained incrementally instead of re-summed. The
    validation gate below proves exact equality on the real trace."""

    def __init__(self, budget_bytes, policy):
        assert policy in ("segmented", "lru", "lfu")
        self.budget = budget_bytes
        self.probation_cap = budget_bytes // 8 or budget_bytes
        self.policy = policy
        self.entries = {}  # key -> dict(size, segment, last_tick, pin)
        self.seg_bytes = {PROBATION: 0, MAIN: 0}
        self.freq = {}
        self.seen = set()
        self.evicted = EvictedWindow()
        self.tick = 0
        self.stats = fresh_stats()

    def _freq_of(self, key):
        return self.freq.get(key, 0)

    def _evict(self, key):
        e = self.entries.pop(key)
        self.seg_bytes[e["segment"]] -= e["size"]
        self.stats["evictions"] += 1
        self.stats["bytes_evicted"] += e["size"]
        self.evicted.add(key)

    def _victim(self, segment, mode):
        best = None
        for k, e in self.entries.items():
            if e["segment"] != segment or e["pin"] > 0:
                continue
            if best is None:
                best = k
                continue
            b = self.entries[best]
            if mode == "lru":
                if e["last_tick"] < b["last_tick"]:
                    best = k
            else:
                fi, fb = self._freq_of(k), self._freq_of(best)
                if fi < fb or (fi == fb and e["last_tick"] < b["last_tick"]):
                    best = k
        return best

    def _make_room(self, segment, incoming, cap):
        mode = "lru"
        if segment == MAIN or self.policy == "lfu":
            mode = "freq"
        if self.policy == "lru":
            mode = "lru"
        while self.seg_bytes[segment] + incoming > cap:
            v = self._victim(segment, mode)
            if v is None:
                return False
            self._evict(v)
        return True

    def _try_promote(self, key):
        size = self.entries[key]["size"]
        main_cap = self.budget - self.probation_cap
        while self.seg_bytes[MAIN] + size > main_cap:
            v = self._victim(MAIN, "freq")
            if v is None:
                return
            if self._freq_of(v) > self._freq_of(key):
                return
            self._evict(v)
            if key not in self.entries:
                return
        self.entries[key]["segment"] = MAIN
        self.seg_bytes[PROBATION] -= size
        self.seg_bytes[MAIN] += size
        self.stats["promotions"] += 1

    def contains(self, layer, expert):
        return (layer * KEYMUL + expert) in self.entries

    def access(self, layer, expert, size):
        key = layer * KEYMUL + expert
        self.tick += 1
        if self.policy == "segmented" and self.tick % AGING == 0:
            for k in self.freq:
                self.freq[k] //= 2
        seen_before = key in self.seen
        if not seen_before:
            self.seen.add(key)
        self.freq[key] = self._freq_of(key) + 1
        self.stats["accesses"] += 1
        e = self.entries.get(key)
        if e is not None:
            assert e["size"] == size
            self.stats["hits"] += 1
            e["last_tick"] = self.tick
            if self.policy == "segmented" and e["segment"] == PROBATION:
                self._try_promote(key)
            return HIT
        self.stats["misses"] += 1
        if not seen_before:
            self.stats["cold_misses"] += 1
        if key in self.evicted:
            self.stats["evicted_before_reuse"] += 1
        self.stats["bytes_streamed"] += size
        if size > self.budget:
            self.stats["too_large"] += 1
            return MISS_TOO_LARGE
        if self.policy in ("lru", "lfu"):
            if not self._make_room(MAIN, size, self.budget):
                self.stats["bypasses"] += 1
                return MISS_BYPASSED
            self.entries[key] = dict(size=size, segment=MAIN,
                                     last_tick=self.tick, pin=0)
            self.seg_bytes[MAIN] += size
            self.stats["admissions"] += 1
            return MISS_ADMITTED
        victim = self._victim(PROBATION, "lru")
        if victim is not None and \
                self.seg_bytes[PROBATION] + size > self.probation_cap and \
                self._freq_of(key) < self._freq_of(victim):
            self.stats["bypasses"] += 1
            return MISS_BYPASSED
        if not self._make_room(PROBATION, size, self.probation_cap):
            self.stats["bypasses"] += 1
            return MISS_BYPASSED
        self.entries[key] = dict(size=size, segment=PROBATION,
                                 last_tick=self.tick, pin=0)
        self.seg_bytes[PROBATION] += size
        self.stats["admissions"] += 1
        return MISS_ADMITTED

    def resident_bytes(self):
        return self.seg_bytes[PROBATION] + self.seg_bytes[MAIN]


class RDACache:
    """Reuse-distance-aware policy (see module docstring). Online state is
    built from past accesses only: a Fenwick tree over access positions
    holding a 1 at each pair's most recent position (the J-016 analyser's
    construction), giving exact stack distances for repeat accesses."""

    def __init__(self, budget_bytes, capacity_pairs, n_accesses):
        self.budget = budget_bytes
        self.capacity = capacity_pairs
        self.entries = {}
        self.resident = 0
        self.seen = set()
        self.evicted = EvictedWindow()
        self.tick = 0
        self.stats = fresh_stats()
        self.last_pos = {}
        self.last_stack = {}
        n = n_accesses + 2
        self.bit = [0] * (n + 2)
        self.n = n

    def _bit_add(self, i, delta):
        i += 1
        while i <= self.n + 1:
            self.bit[i] += delta
            i += i & -i

    def _bit_sum(self, i):  # sum over [0, i)
        s = 0
        while i > 0:
            s += self.bit[i]
            i -= i & -i
        return s

    def contains(self, layer, expert):
        return (layer * KEYMUL + expert) in self.entries

    def access(self, layer, expert, size, idx):
        key = layer * KEYMUL + expert
        self.tick += 1
        prev = self.last_pos.get(key)
        cur_stack = None
        if prev is not None:
            cur_stack = self._bit_sum(idx) - self._bit_sum(prev + 1)
        seen_before = key in self.seen
        if not seen_before:
            self.seen.add(key)
        self.stats["accesses"] += 1
        e = self.entries.get(key)
        result = None
        if e is not None:
            self.stats["hits"] += 1
            e["last_tick"] = self.tick
            result = HIT
        else:
            self.stats["misses"] += 1
            if not seen_before:
                self.stats["cold_misses"] += 1
            if key in self.evicted:
                self.stats["evicted_before_reuse"] += 1
            self.stats["bytes_streamed"] += size
            if size > self.budget:
                self.stats["too_large"] += 1
                result = MISS_TOO_LARGE
            elif cur_stack is not None and cur_stack >= self.capacity:
                # History says this pair's reuse needs at least a
                # capacity-sized cache; admitting it only churns.
                self.stats["bypasses"] += 1
                result = MISS_BYPASSED
            else:
                admitted = True
                while self.resident + size > self.budget:
                    victim = self._victim(idx)
                    if victim is None:
                        admitted = False
                        break
                    self._evict(victim)
                if not admitted:
                    self.stats["bypasses"] += 1
                    result = MISS_BYPASSED
                else:
                    self.entries[key] = dict(size=size, last_tick=self.tick,
                                             admit_pos=idx)
                    self.resident += size
                    self.stats["admissions"] += 1
                    result = MISS_ADMITTED
        if cur_stack is not None:
            self.last_stack[key] = cur_stack
        if prev is not None:
            self._bit_add(prev, -1)
        self._bit_add(idx, +1)
        self.last_pos[key] = idx
        return result

    def _score(self, key, idx):
        if key in self.last_stack:
            return self.last_stack[key]
        admit_pos = self.entries[key]["admit_pos"]
        return self._bit_sum(idx) - self._bit_sum(admit_pos + 1)

    def _victim(self, idx):
        best = None
        best_score = None
        for k, e in self.entries.items():
            s = self._score(k, idx)
            if best is None or s > best_score or \
                    (s == best_score and e["last_tick"] <
                     self.entries[best]["last_tick"]):
                best = k
                best_score = s
        return best

    def _evict(self, key):
        e = self.entries.pop(key)
        self.resident -= e["size"]
        self.stats["evictions"] += 1
        self.stats["bytes_evicted"] += e["size"]
        self.evicted.add(key)

    def resident_bytes(self):
        return self.resident


class FSketchCache:
    """TinyLFU-style frequency-sketch admission over a single LRU segment."""

    def __init__(self, budget_bytes):
        self.budget = budget_bytes
        self.entries = {}
        self.resident = 0
        self.freq = {}
        self.seen = set()
        self.evicted = EvictedWindow()
        self.tick = 0
        self.stats = fresh_stats()

    def _freq_of(self, key):
        return self.freq.get(key, 0)

    def contains(self, layer, expert):
        return (layer * KEYMUL + expert) in self.entries

    def access(self, layer, expert, size):
        key = layer * KEYMUL + expert
        self.tick += 1
        if self.tick % AGING == 0:
            for k in self.freq:
                self.freq[k] //= 2
        seen_before = key in self.seen
        if not seen_before:
            self.seen.add(key)
        self.freq[key] = self._freq_of(key) + 1
        self.stats["accesses"] += 1
        e = self.entries.get(key)
        if e is not None:
            self.stats["hits"] += 1
            e["last_tick"] = self.tick
            return HIT
        self.stats["misses"] += 1
        if not seen_before:
            self.stats["cold_misses"] += 1
        if key in self.evicted:
            self.stats["evicted_before_reuse"] += 1
        self.stats["bytes_streamed"] += size
        if size > self.budget:
            self.stats["too_large"] += 1
            return MISS_TOO_LARGE
        while self.resident + size > self.budget:
            victim = min(self.entries,
                         key=lambda k: self.entries[k]["last_tick"],
                         default=None)
            if victim is None or \
                    self._freq_of(key) <= self._freq_of(victim):
                self.stats["bypasses"] += 1
                return MISS_BYPASSED
            ve = self.entries.pop(victim)
            self.resident -= ve["size"]
            self.stats["evictions"] += 1
            self.stats["bytes_evicted"] += ve["size"]
            self.evicted.add(victim)
        self.entries[key] = dict(size=size, last_tick=self.tick)
        self.resident += size
        self.stats["admissions"] += 1
        return MISS_ADMITTED

    def resident_bytes(self):
        return self.resident


def make_policy(name, budget_bytes, capacity_pairs, n_accesses):
    if name in ("lru", "lfu", "segmented"):
        return FastCache(budget_bytes, name)
    if name == "rda":
        return RDACache(budget_bytes, capacity_pairs, n_accesses)
    if name == "fsketch":
        return FSketchCache(budget_bytes)
    raise ValueError(name)


def run_global(name, accesses, budget_pairs, mean_scaled, n_tokens):
    budget = budget_pairs * mean_scaled
    cache = make_policy(name, budget, budget_pairs, len(accesses))
    per_prompt = {}
    for idx, (l, e, size, pid, w) in enumerate(accesses):
        if isinstance(cache, RDACache):
            rc = cache.access(l, e, size, idx)
        else:
            rc = cache.access(l, e, size)
        pp = per_prompt.setdefault(pid, dict(accesses=0, hits=0, misses=0,
                                             streamed_scaled=0))
        pp["accesses"] += 1
        if rc == HIT:
            pp["hits"] += 1
        else:
            pp["misses"] += 1
            pp["streamed_scaled"] += size
    st = cache.stats
    return summarise(st, cache, n_tokens), per_prompt


def summarise(st, cache, n_tokens):
    total = st["accesses"] or 1
    full = st["bytes_streamed"] * 1024
    return dict(
        accesses=st["accesses"], hits=st["hits"], misses=st["misses"],
        cold=st["cold_misses"], hit_rate=round(st["hits"] / total, 6),
        bypasses=st["bypasses"], admissions=st["admissions"],
        promotions=st["promotions"], evictions=st["evictions"],
        evicted_before_reuse=st["evicted_before_reuse"],
        streamed_full_bytes=full,
        streamed_mb_per_token=round(full / n_tokens / 1e6, 3),
        entries_now=len(cache.entries),
        resident_scaled=cache.resident_bytes(),
    )


def build_prompt_streams(tokens, scaled_sizes):
    streams = {}
    for t in tokens:
        pid = t.get("prompt_id", "?")
        lst = streams.setdefault(pid, [])
        weights = t.get("weights")
        for l, sel in enumerate(t["layers"]):
            for j, e in enumerate(sel):
                w = weights[l][j] if weights else None
                lst.append((l, e, scaled_sizes[l], pid, w))
    return streams


def run_stream(name, stream, budget_pairs, mean_scaled, n_tokens):
    budget = budget_pairs * mean_scaled
    cache = make_policy(name, budget, budget_pairs, len(stream))
    for idx, (l, e, size, pid, w) in enumerate(stream):
        if isinstance(cache, RDACache):
            cache.access(l, e, size, idx)
        else:
            cache.access(l, e, size)
    return summarise(cache.stats, cache, n_tokens)


def run_dropping(name, accesses, budget_pairs, mean_scaled, threshold,
                 enforce_fraction, total_pairs, n_tokens, n_layers_token):
    """Dropping trial over a replica-faithful policy (lru/segmented only).

    A non-resident access with recorded weight < threshold is dropped:
    no stream, no admission, no cache-state change. Resident accesses are
    never dropped. Returns trial counters; streamed is the dropped run's.
    """
    budget = budget_pairs * mean_scaled
    cache = FastCache(budget, name)
    dropped = 0
    dropped_mass = 0.0
    per_prompt = {}
    hits = 0
    demand = 0
    active = (not enforce_fraction) or (budget_pairs < total_pairs / 5.0)
    for (l, e, size, pid, w) in accesses:
        pp = per_prompt.setdefault(pid, dict(accesses=0, dropped=0,
                                             dropped_mass=0.0))
        pp["accesses"] += 1
        if active and w is not None and w < threshold and \
                not cache.contains(l, e):
            dropped += 1
            dropped_mass += w
            pp["dropped"] += 1
            pp["dropped_mass"] += w
            continue
        demand += 1
        rc = cache.access(l, e, size)
        if rc == HIT:
            hits += 1
    st = cache.stats
    full = st["bytes_streamed"] * 1024
    return dict(policy=name, budget_pairs=budget_pairs, active=active,
                threshold=threshold, accesses=len(accesses), dropped=dropped,
                dropped_share=round(dropped / len(accesses), 6),
                dropped_mass_total=round(dropped_mass, 3),
                dropped_mass_per_token_layer=round(
                    dropped_mass / n_layers_token, 6),
                demand_accesses=demand, hits=hits,
                hit_rate_on_demand=round(hits / demand, 6) if demand else None,
                hit_rate_on_all=round(hits / len(accesses), 6),
                streamed_full_bytes=full,
                streamed_mb_per_token=round(full / n_tokens / 1e6, 3),
                per_prompt={pid: dict(
                    accesses=v["accesses"], dropped=v["dropped"],
                    dropped_share=round(v["dropped"] / v["accesses"], 6),
                    dropped_mass=round(v["dropped_mass"], 3))
                    for pid, v in per_prompt.items()})


def main(argv=None):
    ap = argparse.ArgumentParser(description="J-024 cache policy tournament")
    ap.add_argument("trace")
    ap.add_argument("--out")
    args = ap.parse_args(argv)

    trace_bytes = Path(args.trace).read_bytes()
    trace_sha = hashlib.sha256(trace_bytes).hexdigest()
    header, tokens, accesses, mean_scaled = load_stream(args.trace)
    n_tokens = len(tokens)
    n_layers_token = sum(len(t["layers"]) for t in tokens)
    total_pairs = header["n_layer"] * header["n_expert"]
    scaled_sizes = [s // 1024 for s in header["expert_bytes_per_layer"]]
    print(f"trace sha256={trace_sha} tokens={n_tokens} "
          f"accesses={len(accesses)} mean_scaled={mean_scaled} "
          f"total_pairs={total_pairs}")

    # ---- Validation gate -------------------------------------------------
    gate = {"replica_vs_j018": {}, "fast_vs_replica": {}}
    gate_ok = True
    for policy in ("lru", "lfu", "segmented"):
        for pairs in (128, 512):
            budget = pairs * mean_scaled
            rep = ExpertCacheReplica(budget, policy)
            for (l, e, size, pid, w) in accesses:
                rep.access(l, e, size)
            rs = rep.stats
            ref = J018_REFERENCE[(policy, pairs)]
            match_ref = (rs["hits"] == ref["hits"] and
                         rs["misses"] == ref["misses"] and
                         rs["cold_misses"] == ref["cold"] and
                         rs["bypasses"] == ref["bypasses"] and
                         rs["admissions"] == ref["admissions"] and
                         rs["promotions"] == ref["promotions"] and
                         rs["evictions"] == ref["evictions"] and
                         rs["evicted_before_reuse"] == ref["ebr"] and
                         rs["bytes_streamed"] == ref["streamed"])
            gate["replica_vs_j018"][f"{policy}@{pairs}"] = \
                "EXACT" if match_ref else f"MISMATCH {rs} vs {ref}"
            if not match_ref:
                gate_ok = False
            fast = FastCache(budget, policy)
            for (l, e, size, pid, w) in accesses:
                fast.access(l, e, size)
            fs = fast.stats
            match_fast = all(fs[k] == rs[k] for k in (
                "accesses", "hits", "misses", "cold_misses", "bypasses",
                "too_large", "admissions", "promotions", "evictions",
                "evicted_before_reuse", "bytes_streamed", "bytes_evicted")) \
                and fast.resident_bytes() == rep.resident_bytes() \
                and len(fast.entries) == len(rep.entries)
            gate["fast_vs_replica"][f"{policy}@{pairs}"] = \
                "EXACT" if match_fast else f"MISMATCH {fs} vs {rs}"
            if not match_fast:
                gate_ok = False
            print(f"gate {policy}@{pairs}: replica_vs_j018="
                  f"{gate['replica_vs_j018'][f'{policy}@{pairs}']} "
                  f"fast_vs_replica="
                  f"{gate['fast_vs_replica'][f'{policy}@{pairs}']}")
    if not gate_ok:
        print("VALIDATION GATE FAILED -- tournament numbers withheld",
              file=sys.stderr)
        return 3

    # ---- Global tournament ------------------------------------------------
    policies = ["lru", "lfu", "segmented", "rda", "fsketch"]
    budgets = [128, 256, 512, 1024]
    global_runs = {}
    per_prompt_global = {}
    for name in policies:
        for pairs in budgets:
            summ, pp = run_global(name, accesses, pairs, mean_scaled,
                                  n_tokens)
            global_runs[f"{name}@{pairs}"] = summ
            if pairs in (128, 512):
                per_prompt_global[f"{name}@{pairs}"] = {
                    pid: dict(accesses=v["accesses"], hits=v["hits"],
                              hit_rate=round(v["hits"] / v["accesses"], 6),
                              streamed_mb_per_token=round(
                                  v["streamed_scaled"] * 1024 /
                                  max(1, sum(1 for t in tokens
                                             if t.get("prompt_id") == pid))
                                  / 1e6, 3))
                    for pid, v in pp.items()}
            print(f"global {name}@{pairs}: hit={summ['hit_rate']} "
                  f"streamed/token={summ['streamed_mb_per_token']} MB "
                  f"cold={summ['cold']} bypass={summ['bypasses']} "
                  f"ebr={summ['evicted_before_reuse']}")

    # ---- Isolated per-prompt runs ------------------------------------------
    streams = build_prompt_streams(tokens, scaled_sizes)
    prompt_tokens = Counter(t.get("prompt_id", "?") for t in tokens)
    isolated = {}
    for name in policies:
        for pairs in (128, 512):
            for pid, stream in streams.items():
                s = run_stream(name, stream, pairs, mean_scaled,
                               prompt_tokens[pid])
                isolated[f"{name}@{pairs}:{pid}"] = s

    # ---- Dropping trial (offline part) -------------------------------------
    top_k = header["top_k"]
    threshold = 0.8 / top_k
    dropping = {}
    for name in ("segmented", "lru"):
        dropping[f"{name}@128:documented"] = run_dropping(
            name, accesses, 128, mean_scaled, threshold, True, total_pairs,
            n_tokens, n_layers_token)
    dropping["segmented@512:whatif_fraction_waived"] = run_dropping(
        "segmented", accesses, 512, mean_scaled, threshold, False,
        total_pairs, n_tokens, n_layers_token)
    # Near-threshold instability + eligible pool, per text type.
    band = {}
    for pid, stream in streams.items():
        ws = [w for (_, _, _, _, w) in stream if w is not None]
        n = len(ws) or 1
        band[pid] = {
            "accesses": len(ws),
            "share_below_threshold": round(
                sum(1 for w in ws if w < threshold) / n, 6),
            "share_within_0.01": round(
                sum(1 for w in ws if abs(w - threshold) <= 0.01) / n, 6),
            "share_within_0.02": round(
                sum(1 for w in ws if abs(w - threshold) <= 0.02) / n, 6),
            "mean_weight_below": round(
                (sum(w for w in ws if w < threshold) /
                 max(1, sum(1 for w in ws if w < threshold))), 6)}
    allw = [w for (_, _, _, _, w) in accesses if w is not None]
    band["ALL"] = {
        "accesses": len(allw),
        "share_below_threshold": round(
            sum(1 for w in allw if w < threshold) / len(allw), 6),
        "share_within_0.01": round(
            sum(1 for w in allw if abs(w - threshold) <= 0.01) /
            len(allw), 6),
        "share_within_0.02": round(
            sum(1 for w in allw if abs(w - threshold) <= 0.02) /
            len(allw), 6),
        "mean_weight_below": round(
            sum(w for w in allw if w < threshold) /
            max(1, sum(1 for w in allw if w < threshold)), 6)}

    results = dict(
        trace_sha256=trace_sha, n_tokens=n_tokens,
        n_accesses=len(accesses), total_pairs=total_pairs,
        mean_scaled_pair_bytes=mean_scaled,
        validation_gate=gate,
        global_runs=global_runs,
        per_prompt_global=per_prompt_global,
        isolated_runs=isolated,
        dropping=dict(threshold=threshold, top_k=top_k, runs=dropping,
                      near_threshold_band=band),
    )
    out = json.dumps(results, indent=1)
    if args.out:
        Path(args.out).write_text(out + "\n")
        print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
