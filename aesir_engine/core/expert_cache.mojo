"""In-memory cache of streamed routed experts (Janas road J-018).

Implements the J-017 expert residency design (D4, section 4.1 and 5.1):

- The cache unit is one whole expert: one (layer, expert) pair whose three
  slabs are admitted and evicted atomically. A hit therefore means the
  firing needs zero disk reads.
- Accounting is in bytes at directory-true per-(layer, expert) sizes,
  which are layer-dependent (J-015: up to 15 percent per pair). Pair
  counts in statistics are derived, never primary.
- The budget is sized once at open from free memory minus a stated
  reserve, under a hard cap that is never exceeded, not even transiently
  during admission (evict-then-admit, or refuse admission).
- Resident-set bytes (embeddings, attention, norms, routers, shared
  experts) are never counted here and never evictable; this module only
  ever holds routed-expert bytes.
- Admission is never unconditional in the filtering policies: the
  shipping default (fsketch, since J-024's integration step) admits a
  miss only when its aged sketch frequency exceeds the LRU victim's;
  the segmented policy admits a first touch to probation under a
  frequency gate and promotes on second touch. A miss may be bypassed
  (served without admission) when the policy judges admission
  harmful; bypasses are counted. J-024 starvation fix: when the total
  free budget can hold the incoming pair, no gate may refuse it.
- The budget can shrink after open; in-flight experts are pinned and
  never evicted, and the cache sheds before anything else does.
- Statistics are reported in the J-016 trace vocabulary: (layer, expert)
  pair accesses, hits, misses, cold misses, hit rate, bytes streamed.

Hard-cap surface (names decided by J-018): the command-line flag
--expert-cache-bytes and the environment variable
AESIR_EXPERT_CACHE_BYTES, both parsed by parse_byte_size; the flag wins
over the environment when both are set. Host wiring that reads the
actual environment into resolve_hard_cap lands with the MoE core; this
module is the tested engine the wiring will call.

There is no MoE forward path in the engine yet (J-012, J-016, J-017):
this module is deliberately standalone so the later Part II slices
integrate a proven cache instead of designing one under load.
"""

# Access outcome codes returned by ExpertCache.access.
comptime ACCESS_HIT = 1
comptime ACCESS_MISS_ADMITTED = 0
comptime ACCESS_MISS_BYPASSED = -1
comptime ACCESS_MISS_TOO_LARGE = -2

comptime SEGMENT_PROBATION = 0
comptime SEGMENT_MAIN = 1

# Frequency counters are halved after this many accesses so stale
# hotness decays (TinyLFU-style aging, exact counters at this scale).
comptime FREQ_AGING_INTERVAL = 4096


def parse_byte_size(text: String) raises -> Int:
    """Parse a byte size: plain bytes, or a K/M/G suffix (1024-based).

    Accepts forms like "1048576", "512MiB", "2G", "256K". Suffixes are
    binary (KiB/MiB/GiB semantics) whether or not the "iB" is written;
    the cache cap is a memory quantity, so decimal units would mislead.
    """
    var trimmed = String(text.strip())
    if trimmed.byte_length() == 0:
        raise Error("Expert cache byte size must not be empty")
    var multiplier = 1
    var digits = trimmed
    var upper = String(trimmed.upper())
    if upper.endswith("GIB") or upper.endswith("GB") or upper.endswith("G"):
        multiplier = 1024 * 1024 * 1024
        digits = String(
            trimmed[byte=: trimmed.byte_length() - _suffix_len(upper, "G")]
        )
    elif upper.endswith("MIB") or upper.endswith("MB") or upper.endswith("M"):
        multiplier = 1024 * 1024
        digits = String(
            trimmed[byte=: trimmed.byte_length() - _suffix_len(upper, "M")]
        )
    elif upper.endswith("KIB") or upper.endswith("KB") or upper.endswith("K"):
        multiplier = 1024
        digits = String(
            trimmed[byte=: trimmed.byte_length() - _suffix_len(upper, "K")]
        )
    elif upper.endswith("B"):
        digits = String(trimmed[byte=: trimmed.byte_length() - 1])
    var digits_stripped = String(digits.strip())
    digits = digits_stripped
    if digits.byte_length() == 0:
        raise Error("Expert cache byte size has no digits")
    var digit_bytes = digits.as_bytes()
    for j in range(len(digit_bytes)):
        var c = Int(digit_bytes[j])
        if c < 48 or c > 57:
            raise Error("Expert cache byte size must be a nonnegative integer")
    var value = atol(digits)
    if value < 0 or value > (Int(9223372036854775807) // multiplier):
        raise Error("Expert cache byte size overflow")
    return value * multiplier


def _suffix_len(upper: String, letter: String) -> Int:
    if upper.endswith(letter + "IB"):
        return 3
    if upper.endswith(letter + "B"):
        return 2
    return 1


def resolve_hard_cap(flag_bytes: Int, env_bytes: Int) raises -> Int:
    """Resolve the hard cap: flag beats env; zero from both means unset."""
    if flag_bytes < 0 or env_bytes < 0:
        raise Error("Expert cache cap values must be nonnegative")
    if flag_bytes > 0:
        return flag_bytes
    return env_bytes


struct ExpertCacheSizing(Copyable, ImplicitlyCopyable):
    """Open-time budget arithmetic, stated in full for the open report."""

    var budget_bytes: Int
    var reserve_bytes: Int
    var resident_bytes: Int
    var kv_allowance_bytes: Int
    var scratch_bytes: Int
    var os_headroom_bytes: Int
    var hard_cap_bytes: Int
    var capped: Bool
    var below_floor: Bool

    def __init__(
        out self,
        budget_bytes: Int,
        reserve_bytes: Int,
        resident_bytes: Int,
        kv_allowance_bytes: Int,
        scratch_bytes: Int,
        os_headroom_bytes: Int,
        hard_cap_bytes: Int,
        capped: Bool,
        below_floor: Bool,
    ):
        self.budget_bytes = budget_bytes
        self.reserve_bytes = reserve_bytes
        self.resident_bytes = resident_bytes
        self.kv_allowance_bytes = kv_allowance_bytes
        self.scratch_bytes = scratch_bytes
        self.os_headroom_bytes = os_headroom_bytes
        self.hard_cap_bytes = hard_cap_bytes
        self.capped = capped
        self.below_floor = below_floor

    def describe(self) -> String:
        return (
            "budget_bytes="
            + String(self.budget_bytes)
            + " reserve_bytes="
            + String(self.reserve_bytes)
            + " resident_bytes="
            + String(self.resident_bytes)
            + " kv_allowance_bytes="
            + String(self.kv_allowance_bytes)
            + " scratch_bytes="
            + String(self.scratch_bytes)
            + " os_headroom_bytes="
            + String(self.os_headroom_bytes)
            + " hard_cap_bytes="
            + String(self.hard_cap_bytes)
            + " capped="
            + String(self.capped)
            + " below_floor="
            + String(self.below_floor)
        )


def plan_expert_cache_budget(
    free_at_open_bytes: Int,
    total_bytes: Int,
    hard_cap_bytes: Int,
    resident_bytes: Int,
    kv_allowance_bytes: Int,
    scratch_bytes: Int,
    per_token_routed_bytes: Int,
) raises -> ExpertCacheSizing:
    """Budget = min(hard cap if set, free-at-open - reserve).

    Reserve composition (J-018 decision, recorded in the slice doc):
    resident set bytes measured from the tensor directory, plus a KV
    allowance for the configured context (a named configuration value
    until J-087 measures KV bytes; never invented here), plus scratch,
    plus an OS/other-programs headroom of one fifth of total memory.
    The floor is one token's full routed demand: below it the cache
    cannot hold a single token's working set and the sizing says so
    (below_floor) instead of streaming-thrashing silently.
    """
    if (
        free_at_open_bytes < 0
        or total_bytes <= 0
        or hard_cap_bytes < 0
        or resident_bytes < 0
        or kv_allowance_bytes < 0
        or scratch_bytes < 0
        or per_token_routed_bytes <= 0
    ):
        raise Error("Expert cache sizing values out of range")
    var os_headroom = total_bytes // 5
    var reserve = resident_bytes + kv_allowance_bytes + scratch_bytes + os_headroom
    if reserve < 0:
        raise Error("Expert cache reserve overflow")
    var budget = free_at_open_bytes - reserve
    if budget < 0:
        budget = 0
    var capped = False
    if hard_cap_bytes > 0 and budget > hard_cap_bytes:
        budget = hard_cap_bytes
        capped = True
    return ExpertCacheSizing(
        budget,
        reserve,
        resident_bytes,
        kv_allowance_bytes,
        scratch_bytes,
        os_headroom,
        hard_cap_bytes,
        capped,
        budget < per_token_routed_bytes,
    )


struct ExpertCacheStats(Copyable, ImplicitlyCopyable):
    """Run statistics in the J-016 trace vocabulary ((layer, expert) pairs)."""

    var accesses: Int
    var hits: Int
    var misses: Int
    var cold_misses: Int
    var bypasses: Int
    var too_large: Int
    var admissions: Int
    var promotions: Int
    var evictions: Int
    var evicted_before_reuse: Int
    var bytes_streamed: Int
    var bytes_evicted: Int
    var bytes_resident_now: Int
    var entries_now: Int
    var budget_bytes: Int

    def __init__(out self):
        self.accesses = 0
        self.hits = 0
        self.misses = 0
        self.cold_misses = 0
        self.bypasses = 0
        self.too_large = 0
        self.admissions = 0
        self.promotions = 0
        self.evictions = 0
        self.evicted_before_reuse = 0
        self.bytes_streamed = 0
        self.bytes_evicted = 0
        self.bytes_resident_now = 0
        self.entries_now = 0
        self.budget_bytes = 0

    def hit_rate_per_mille(self) -> Int:
        """Hit rate in thousandths (integer arithmetic, no float drift)."""
        if self.accesses == 0:
            return 0
        return (self.hits * 1000) // self.accesses

    def describe(self) -> String:
        return (
            "accesses="
            + String(self.accesses)
            + " hits="
            + String(self.hits)
            + " misses="
            + String(self.misses)
            + " cold_misses="
            + String(self.cold_misses)
            + " hit_rate_per_mille="
            + String(self.hit_rate_per_mille())
            + " bypasses="
            + String(self.bypasses)
            + " too_large="
            + String(self.too_large)
            + " admissions="
            + String(self.admissions)
            + " promotions="
            + String(self.promotions)
            + " evictions="
            + String(self.evictions)
            + " evicted_before_reuse="
            + String(self.evicted_before_reuse)
            + " bytes_streamed="
            + String(self.bytes_streamed)
            + " bytes_evicted="
            + String(self.bytes_evicted)
            + " bytes_resident_now="
            + String(self.bytes_resident_now)
            + " entries_now="
            + String(self.entries_now)
            + " budget_bytes="
            + String(self.budget_bytes)
        )


struct _Entry(Copyable, Movable):
    var key: Int
    var size_bytes: Int
    var segment: Int
    var last_tick: Int
    var pin_count: Int
    var data: List[UInt8]

    def __init__(
        out self, key: Int, size_bytes: Int, segment: Int, last_tick: Int
    ):
        self.key = key
        self.size_bytes = size_bytes
        self.segment = segment
        self.last_tick = last_tick
        self.pin_count = 0
        self.data = List[UInt8]()
        self.data.resize(size_bytes, UInt8(0))


struct _Freq(Copyable, ImplicitlyCopyable):
    var key: Int
    var count: Int

    def __init__(out self, key: Int, count: Int):
        self.key = key
        self.count = count


def _pair_key(layer: Int, expert: Int) -> Int:
    return layer * 1048576 + expert


struct ExpertCache(Copyable, Movable):
    """Byte-budgeted expert cache (J-018; fsketch + starvation fix J-024).

    Policies behind one interface:
    - fsketch (shipping default since the J-024 integration step): a
      single segment with LRU victims and TinyLFU-style sketch
      admission over aged exact counters -- a miss is admitted only
      when the candidate's frequency exceeds the LRU victim's;
      otherwise it is bypassed. The sketch ages (counters halved)
      every FREQ_AGING_INTERVAL accesses, the J-018 cadence.
    - segmented (the J-018 shipping policy, kept selectable): two
      segments. Probation (one eighth of the budget) admits on first
      touch under LRU with a frequency gate; the main segment holds
      promoted entries. J-024 starvation fix: admission and promotion
      are governed by the total budget, not by segment caps alone --
      when the total free budget can hold the incoming pair, no gate
      may refuse it and no resident may be evicted to satisfy a
      segment cap; promotion moves bytes between segments (the total
      never changes), so it never evicts either. Eviction happens
      only where the total budget actually binds, at admission time.
    - lru / lfu: pure baselines, faithful to the J-016 offline
      simulations, for comparability.
    """

    var budget_bytes: Int
    var probation_bytes: Int
    var policy: String
    var entries: List[_Entry]
    var freq: List[_Freq]
    var seen_keys: List[Int]
    var evicted_keys: List[Int]
    var tick: Int
    var stats: ExpertCacheStats

    def __init__(out self, budget_bytes: Int, policy: String) raises:
        if budget_bytes <= 0:
            raise Error("Expert cache budget must be positive")
        if (
            policy != "segmented"
            and policy != "lru"
            and policy != "lfu"
            and policy != "fsketch"
        ):
            raise Error(
                "Expert cache policy must be segmented, lru, lfu or fsketch"
            )
        self.budget_bytes = budget_bytes
        self.probation_bytes = budget_bytes // 8
        if self.probation_bytes == 0:
            self.probation_bytes = budget_bytes
        self.policy = policy
        self.entries = List[_Entry]()
        self.freq = List[_Freq]()
        self.seen_keys = List[Int]()
        self.evicted_keys = List[Int]()
        self.tick = 0
        self.stats = ExpertCacheStats()
        self.stats.budget_bytes = budget_bytes

    # -- frequency sketch (exact counters, aged) ---------------------

    def _freq_of(self, key: Int) -> Int:
        for i in range(len(self.freq)):
            if self.freq[i].key == key:
                return self.freq[i].count
        return 0

    def _freq_bump(mut self, key: Int):
        for i in range(len(self.freq)):
            if self.freq[i].key == key:
                self.freq[i].count += 1
                return
        self.freq.append(_Freq(key, 1))

    def _freq_age(mut self):
        for i in range(len(self.freq)):
            self.freq[i].count = self.freq[i].count // 2

    # -- entry helpers -------------------------------------------------

    def _find(self, key: Int) -> Int:
        for i in range(len(self.entries)):
            if self.entries[i].key == key:
                return i
        return -1

    def _segment_bytes(self, segment: Int) -> Int:
        var total = 0
        for i in range(len(self.entries)):
            if self.entries[i].segment == segment:
                total += self.entries[i].size_bytes
        return total

    def _total_bytes(self) -> Int:
        var total = 0
        for i in range(len(self.entries)):
            total += self.entries[i].size_bytes
        return total

    def _was_evicted(self, key: Int) -> Bool:
        for i in range(len(self.evicted_keys)):
            if self.evicted_keys[i] == key:
                return True
        return False

    def _evict_at(mut self, index: Int):
        var key = self.entries[index].key
        self.stats.evictions += 1
        self.stats.bytes_evicted += self.entries[index].size_bytes
        self.evicted_keys.append(key)
        if len(self.evicted_keys) > 8192:
            _ = self.evicted_keys.pop(0)
        # Swap-remove: entry order carries no meaning (victim selection
        # scans by tick/frequency), and an indexed pop would shift and
        # deep-copy every following entry's payload on every eviction.
        var last = self.entries.pop()
        if index < len(self.entries):
            self.entries[index] = last^

    def _victim(self, segment: Int, mode: String) -> Int:
        """Index of the eviction victim in a segment, or -1 if none.

        Pinned entries are never victims. mode "lru" picks the least
        recently used; mode "freq" picks the lowest frequency, breaking
        ties by least-recent use.
        """
        var best = -1
        for i in range(len(self.entries)):
            if self.entries[i].segment != segment:
                continue
            if self.entries[i].pin_count > 0:
                continue
            if best < 0:
                best = i
                continue
            if mode == "lru":
                if self.entries[i].last_tick < self.entries[best].last_tick:
                    best = i
            else:
                var fi = self._freq_of(self.entries[i].key)
                var fb = self._freq_of(self.entries[best].key)
                if fi < fb or (
                    fi == fb
                    and self.entries[i].last_tick < self.entries[best].last_tick
                ):
                    best = i
        return best

    def _make_room(
        mut self, segment: Int, incoming_bytes: Int, segment_cap: Int
    ) -> Bool:
        """Evict-then-admit: shed victims until the segment fits.

        Returns False when only pinned bytes block the admission; the
        caller then bypasses. The cap is never exceeded transiently:
        room is made before the new entry exists.
        """
        var mode = String("lru")
        if segment == SEGMENT_MAIN or self.policy == "lfu":
            mode = String("freq")
        if self.policy == "lru":
            mode = String("lru")
        while self._segment_bytes(segment) + incoming_bytes > segment_cap:
            var victim = self._victim(segment, mode)
            if victim < 0:
                return False
            self._evict_at(victim)
        return True

    # -- the access path ------------------------------------------------

    def access(
        mut self, layer: Int, expert: Int, size_bytes: Int
    ) raises -> Int:
        """One routed-expert access for (layer, expert) at its true size.

        On a hit the caller owes zero reads. On a miss the caller owes
        exactly one whole-expert stream (3 slab reads, J-019's concern);
        the return code says whether the expert was admitted, bypassed,
        or refused as larger than the whole budget.
        """
        if layer < 0 or expert < 0 or expert >= 1048576 or size_bytes <= 0:
            raise Error("Expert cache access values out of range")
        var key = _pair_key(layer, expert)
        self.tick += 1
        # Aging belongs to the frequency-sketch policies (segmented and
        # fsketch). The lru/lfu baselines keep J-016's cumulative
        # semantics so their numbers stay comparable with the offline
        # simulations.
        if (
            self.policy == "segmented" or self.policy == "fsketch"
        ) and self.tick % FREQ_AGING_INTERVAL == 0:
            self._freq_age()
        # Cold is a first-ever-access fact, tracked apart from the aged
        # sketch: a decayed frequency of zero must never re-label a
        # repeat access as cold.
        var seen_before = False
        for i in range(len(self.seen_keys)):
            if self.seen_keys[i] == key:
                seen_before = True
                break
        if not seen_before:
            self.seen_keys.append(key)
        self._freq_bump(key)
        self.stats.accesses += 1

        var index = self._find(key)
        if index >= 0:
            if self.entries[index].size_bytes != size_bytes:
                raise Error(
                    "Expert cache size changed for a resident (layer, expert)"
                )
            self.stats.hits += 1
            self.entries[index].last_tick = self.tick
            if (
                self.policy == "segmented"
                and self.entries[index].segment == SEGMENT_PROBATION
            ):
                self._try_promote(index)
            self._sync_stats()
            return ACCESS_HIT

        # Miss path.
        self.stats.misses += 1
        if not seen_before:
            self.stats.cold_misses += 1
        if self._was_evicted(key):
            self.stats.evicted_before_reuse += 1
        self.stats.bytes_streamed += size_bytes
        if size_bytes > self.budget_bytes:
            self.stats.too_large += 1
            self._sync_stats()
            return ACCESS_MISS_TOO_LARGE

        if self.policy == "lru" or self.policy == "lfu":
            # Baselines, faithful to J-016's simulation definitions:
            # unconditional admission, eviction by recency (lru) or by
            # cumulative frequency (lfu). The admission discipline lives
            # in the segmented shipping policy, not in the baselines.
            if not self._make_room(SEGMENT_MAIN, size_bytes, self.budget_bytes):
                self.stats.bypasses += 1
                self._sync_stats()
                return ACCESS_MISS_BYPASSED
            self.entries.append(
                _Entry(key, size_bytes, SEGMENT_MAIN, self.tick)
            )
            self.stats.admissions += 1
            self._sync_stats()
            return ACCESS_MISS_ADMITTED

        if self.policy == "fsketch":
            # Frequency-sketch admission over a single LRU segment
            # (J-024 tournament winner, integrated verbatim from the
            # tournament definition): evict LRU victims one at a time,
            # admitting only while the candidate's aged frequency
            # exceeds each victim's; the first victim that is at least
            # as frequent as the candidate refuses the admission
            # (bypass), with any victims already evicted standing --
            # exactly the tournament simulator's loop. When the total
            # free budget already holds the pair the loop never runs:
            # no gate can refuse under no scarcity (J-024 step 4).
            while self._total_bytes() + size_bytes > self.budget_bytes:
                var victim = self._victim(SEGMENT_MAIN, String("lru"))
                if victim < 0:
                    self.stats.bypasses += 1
                    self._sync_stats()
                    return ACCESS_MISS_BYPASSED
                if self._freq_of(key) <= self._freq_of(
                    self.entries[victim].key
                ):
                    self.stats.bypasses += 1
                    self._sync_stats()
                    return ACCESS_MISS_BYPASSED
                self._evict_at(victim)
            self.entries.append(
                _Entry(key, size_bytes, SEGMENT_MAIN, self.tick)
            )
            self.stats.admissions += 1
            self._sync_stats()
            return ACCESS_MISS_ADMITTED

        # Segmented policy, with the J-024 starvation fix.
        if self._total_bytes() + size_bytes <= self.budget_bytes:
            # No scarcity: the total budget holds the pair, so the
            # probation gate must not refuse it and no resident may be
            # evicted for a segment cap. The pair enters probation
            # while probation has room, otherwise main directly.
            var target = SEGMENT_PROBATION
            if (
                self._segment_bytes(SEGMENT_PROBATION) + size_bytes
                > self.probation_bytes
            ):
                target = SEGMENT_MAIN
            self.entries.append(_Entry(key, size_bytes, target, self.tick))
            self.stats.admissions += 1
            self._sync_stats()
            return ACCESS_MISS_ADMITTED
        # Scarcity: the original probationary path (frequency gate +
        # probation segment room), then total-budget room: promotions
        # may have carried main past its segment cap, so admission
        # evicts main victims by (frequency, recency) until the total
        # budget fits -- the cap that binds is the total.
        var probation_victim = self._victim(SEGMENT_PROBATION, String("lru"))
        if (
            probation_victim >= 0
            and self._segment_bytes(SEGMENT_PROBATION) + size_bytes
            > self.probation_bytes
            and self._freq_of(key)
            < self._freq_of(self.entries[probation_victim].key)
        ):
            self.stats.bypasses += 1
            self._sync_stats()
            return ACCESS_MISS_BYPASSED
        if not self._make_room(
            SEGMENT_PROBATION, size_bytes, self.probation_bytes
        ):
            self.stats.bypasses += 1
            self._sync_stats()
            return ACCESS_MISS_BYPASSED
        while self._total_bytes() + size_bytes > self.budget_bytes:
            var main_victim = self._victim(SEGMENT_MAIN, String("freq"))
            if main_victim < 0:
                self.stats.bypasses += 1
                self._sync_stats()
                return ACCESS_MISS_BYPASSED
            self._evict_at(main_victim)
        self.entries.append(
            _Entry(key, size_bytes, SEGMENT_PROBATION, self.tick)
        )
        self.stats.admissions += 1
        self._sync_stats()
        return ACCESS_MISS_ADMITTED

    def _try_promote(mut self, index_in: Int):
        """Second touch: promote probation -> main.

        J-024 starvation fix: promotion only moves bytes between
        segments -- the total resident bytes never change -- so it
        never needs to evict a resident to satisfy the main segment's
        cap, and it is never refused by a frequency comparison.
        Eviction is deferred to admission, the one place the total
        budget actually binds. (Pre-fix, promotion evicted main
        residents even when the budget held the whole expert body,
        which is half of the @1024 starvation J-024 §2.2 measured.)
        """
        self.entries[index_in].segment = SEGMENT_MAIN
        self.stats.promotions += 1

    # -- pinning and shrink ----------------------------------------------

    def pin(mut self, layer: Int, expert: Int) raises -> Bool:
        """Pin a resident expert (in-flight use). False if not resident."""
        var index = self._find(_pair_key(layer, expert))
        if index < 0:
            return False
        self.entries[index].pin_count += 1
        return True

    def unpin(mut self, layer: Int, expert: Int) raises:
        var index = self._find(_pair_key(layer, expert))
        if index < 0 or self.entries[index].pin_count <= 0:
            raise Error("Expert cache unpin of an unpinned expert")
        self.entries[index].pin_count -= 1

    def shrink(mut self, new_budget_bytes: Int) raises -> Int:
        """Reduce the budget, shedding policy-order entries, pins held.

        Probation (LRU) sheds first, then the main segment by
        (frequency, recency). Returns the bytes still resident; if only
        pinned entries remain above the new budget the return value
        exceeds it and the caller sees the overage rather than a
        corrupted in-flight token.
        """
        if new_budget_bytes <= 0:
            raise Error("Expert cache shrink budget must be positive")
        self.budget_bytes = new_budget_bytes
        self.probation_bytes = new_budget_bytes // 8
        if self.probation_bytes == 0:
            self.probation_bytes = new_budget_bytes
        self.stats.budget_bytes = new_budget_bytes
        while self._total_bytes() > new_budget_bytes:
            var victim = self._victim(SEGMENT_PROBATION, String("lru"))
            if victim < 0:
                victim = self._victim(SEGMENT_MAIN, String("freq"))
            if victim < 0:
                break
            self._evict_at(victim)
        self._sync_stats()
        return self._total_bytes()

    # -- reporting ---------------------------------------------------------

    def _sync_stats(mut self):
        self.stats.bytes_resident_now = self._total_bytes()
        self.stats.entries_now = len(self.entries)

    def snapshot(mut self) -> ExpertCacheStats:
        self._sync_stats()
        return self.stats

    def contains(self, layer: Int, expert: Int) -> Bool:
        return self._find(_pair_key(layer, expert)) >= 0
