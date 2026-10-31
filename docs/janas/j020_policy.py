#!/usr/bin/env python3
"""J-020: faithful Python replica of the J-018 ExpertCache module.

Mirrors aesir_engine/core/expert_cache.mojo statement-for-statement
(swap-remove eviction, victim scan order, frequency gate, aging at
tick % 4096, promotion rule) so warm-up candidates can be tournamented
in simulation. The replica is only trusted where it reproduces the real
Mojo module exactly; j020_validate_replica.py performs that check
against the Mojo replay output (per-token miss sets + run totals).
"""
HIT = 1
MISS_ADMITTED = 0
MISS_BYPASSED = -1
MISS_TOO_LARGE = -2
PROBATION = 0
MAIN = 1
AGING = 4096


class ExpertCacheReplica:
    def __init__(self, budget_bytes, policy="segmented"):
        assert policy in ("segmented", "lru", "lfu")
        self.budget = budget_bytes
        self.probation_cap = budget_bytes // 8 or budget_bytes
        self.policy = policy
        self.entries = []  # dicts: key,size,segment,last_tick,pin
        self.freq = {}
        self.seen = set()
        self.evicted_keys = []
        self.tick = 0
        self.stats = dict(accesses=0, hits=0, misses=0, cold_misses=0,
                          bypasses=0, too_large=0, admissions=0,
                          promotions=0, evictions=0,
                          evicted_before_reuse=0, bytes_streamed=0,
                          bytes_evicted=0)

    # -- helpers mirroring the Mojo module --
    def _freq_of(self, key):
        return self.freq.get(key, 0)

    def _find(self, key):
        for i, e in enumerate(self.entries):
            if e["key"] == key:
                return i
        return -1

    def _seg_bytes(self, seg):
        return sum(e["size"] for e in self.entries if e["segment"] == seg)

    def _evict_at(self, index):
        e = self.entries[index]
        self.stats["evictions"] += 1
        self.stats["bytes_evicted"] += e["size"]
        self.evicted_keys.append(e["key"])
        if len(self.evicted_keys) > 8192:
            self.evicted_keys.pop(0)
        last = self.entries.pop()
        if index < len(self.entries):
            self.entries[index] = last

    def _victim(self, segment, mode):
        best = -1
        for i, e in enumerate(self.entries):
            if e["segment"] != segment or e["pin"] > 0:
                continue
            if best < 0:
                best = i
                continue
            b = self.entries[best]
            if mode == "lru":
                if e["last_tick"] < b["last_tick"]:
                    best = i
            else:
                fi, fb = self._freq_of(e["key"]), self._freq_of(b["key"])
                if fi < fb or (fi == fb and e["last_tick"] < b["last_tick"]):
                    best = i
        return best

    def _make_room(self, segment, incoming, cap):
        mode = "lru"
        if segment == MAIN or self.policy == "lfu":
            mode = "freq"
        if self.policy == "lru":
            mode = "lru"
        while self._seg_bytes(segment) + incoming > cap:
            v = self._victim(segment, mode)
            if v < 0:
                return False
            self._evict_at(v)
        return True

    def _try_promote(self, index):
        size = self.entries[index]["size"]
        key = self.entries[index]["key"]
        main_cap = self.budget - self.probation_cap
        while self._seg_bytes(MAIN) + size > main_cap:
            v = self._victim(MAIN, "freq")
            if v < 0:
                return
            if self._freq_of(self.entries[v]["key"]) > self._freq_of(key):
                return
            self._evict_at(v)
            index = self._find(key)
            if index < 0:
                return
        self.entries[index]["segment"] = MAIN
        self.stats["promotions"] += 1

    # -- warm-up preload (J-020's proposed admission path) --
    def preload(self, pairs, freq_hint=None):
        """Insert (layer, expert, size) pairs as MAIN-segment residents.

        Models a warm-up pass that streamed these experts during prompt
        reading: bytes are charged by the caller, entries arrive newest
        last (rank order preserved: later = more protected under LRU),
        frequency hints are the predictor's own evidence counts.
        """
        for (layer, expert, size) in pairs:
            key = layer * 1048576 + expert
            self.tick += 1
            self.seen.add(key)
            if freq_hint is not None:
                self.freq[key] = max(self._freq_of(key),
                                     freq_hint.get((layer, expert), 1))
            self.entries.append(dict(key=key, size=size, segment=MAIN,
                                     last_tick=self.tick, pin=0))
            self.stats["admissions"] += 1

    # -- the access path --
    def access(self, layer, expert, size):
        key = layer * 1048576 + expert
        self.tick += 1
        if self.policy == "segmented" and self.tick % AGING == 0:
            for k in self.freq:
                self.freq[k] //= 2
        seen_before = key in self.seen
        if not seen_before:
            self.seen.add(key)
        self.freq[key] = self._freq_of(key) + 1
        self.stats["accesses"] += 1

        index = self._find(key)
        if index >= 0:
            assert self.entries[index]["size"] == size
            self.stats["hits"] += 1
            self.entries[index]["last_tick"] = self.tick
            if self.policy == "segmented" and \
                    self.entries[index]["segment"] == PROBATION:
                self._try_promote(index)
            return HIT

        self.stats["misses"] += 1
        if not seen_before:
            self.stats["cold_misses"] += 1
        if key in self.evicted_keys:
            self.stats["evicted_before_reuse"] += 1
        self.stats["bytes_streamed"] += size
        if size > self.budget:
            self.stats["too_large"] += 1
            return MISS_TOO_LARGE

        if self.policy in ("lru", "lfu"):
            if not self._make_room(MAIN, size, self.budget):
                self.stats["bypasses"] += 1
                return MISS_BYPASSED
            self.entries.append(dict(key=key, size=size, segment=MAIN,
                                     last_tick=self.tick, pin=0))
            self.stats["admissions"] += 1
            return MISS_ADMITTED

        victim = self._victim(PROBATION, "lru")
        if victim >= 0 and \
                self._seg_bytes(PROBATION) + size > self.probation_cap and \
                self._freq_of(key) < self._freq_of(self.entries[victim]["key"]):
            self.stats["bypasses"] += 1
            return MISS_BYPASSED
        if not self._make_room(PROBATION, size, self.probation_cap):
            self.stats["bypasses"] += 1
            return MISS_BYPASSED
        self.entries.append(dict(key=key, size=size, segment=PROBATION,
                                 last_tick=self.tick, pin=0))
        self.stats["admissions"] += 1
        return MISS_ADMITTED

    def resident_bytes(self):
        return sum(e["size"] for e in self.entries)
