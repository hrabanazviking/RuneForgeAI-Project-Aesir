"""Dense-layer residency: the Part II residency machinery, generalised
to dense models (Janas road J-021).

J-017 decided the residency design for routed experts (resident set vs
streamed set, whole-expert cache unit, byte accounting at directory-true
sizes, statistics in the J-016 vocabulary) and J-018 built it as
core/expert_cache.mojo. This module re-expresses Aesir's proven dense
spill path (core/llama3_spill.mojo: front layers resident on the GPU,
tail layers on the CPU path) through the same machinery, with dense
layers as the streaming unit:

- The unit is one whole dense layer: all of its tensors (attention,
  norms, FFN) admitted / evicted / accounted atomically, at the layer's
  directory-true byte size summed from the file's tensor directory
  (dense_layer_bytes) -- never a family layout assumption, exactly the
  J-017 section 3.3 contract applied to layers instead of experts.
- The always-resident set (the J-017 D1 analogue) is everything that is
  not a layer: token embedding, rope factors where present, the final
  norm and the output head where untied (dense_always_resident_bytes).
  It is never counted against a layer budget and never evictable.
- The spill split itself is a residency plan (DenseResidencyPlan): a
  front prefix of layers pinned GPU-resident, the tail host-resident.
  plan_dense_spill derives the largest front prefix a device budget
  admits; describe_dense_spill states a chosen split in the same
  vocabulary. The llama3_spill session reports its split through this
  plan at open (the [RESIDENCY] line) -- the plan is accounting and
  validation; the session's execution path is unchanged.
- DenseLayerCache is the demand-managed form of the same contract: the
  J-018 policy interface (segmented probationary/frequency shipping
  policy, faithful lru/lfu baselines), the same access outcome codes,
  the same sizing arithmetic (plan_dense_layer_budget mirrors
  plan_expert_cache_budget term for term), pinning, shrink, and
  statistics whose describe() emits exactly the J-018 field names over
  (layer) units instead of (layer, expert) pairs. It manages residency
  metadata only -- dense layer bytes live in the file image / device
  buffers the session already owns, unlike streamed expert slabs, which
  land in cache-owned buffers (J-019). That is the one structural
  difference from ExpertCache, and it is deliberate.

What the dense access pattern does to demand caching is measured, not
assumed: a dense token touches every layer exactly once, in order, so
the demand stream is a cyclic scan. The replay filed with J-021 shows
the J-018 policies at any sub-total budget score zero hits on that
scan (the classic scan-thrash result, reproduced in Aesir's own
machinery) -- which is why the shipping dense form is the static
pinned partition (the spill plan), and the demand cache stands as the
measured counterfactual and as the accounting ledger, not as the
execution policy. Nothing here claims the spill path streams layers
through this cache at run time; the integration gap is recorded in
docs/janas/J021_DENSE_SPILL_GENERALISED.md.
"""

from loader.packed_gguf import PackedGGUF

# Access outcome codes -- identical values and meanings to
# core/expert_cache.mojo (J-018), so statistics stay comparable.
comptime ACCESS_HIT = 1
comptime ACCESS_MISS_ADMITTED = 0
comptime ACCESS_MISS_BYPASSED = -1
comptime ACCESS_MISS_TOO_LARGE = -2

comptime SEGMENT_PROBATION = 0
comptime SEGMENT_MAIN = 1

# Frequency counters are halved after this many accesses so stale
# hotness decays (TinyLFU-style aging, exact counters at this scale).
# Same interval as J-018.
comptime FREQ_AGING_INTERVAL = 4096


def parse_byte_size(text: String) raises -> Int:
    """Parse a byte size: plain bytes, or a K/M/G suffix (1024-based).

    The grammar is J-018's, unchanged: the dense cap surface speaks the
    same language as the expert cap surface.
    """
    var trimmed = String(text.strip())
    if trimmed.byte_length() == 0:
        raise Error("Dense layer byte size must not be empty")
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
        raise Error("Dense layer byte size has no digits")
    var digit_bytes = digits.as_bytes()
    for j in range(len(digit_bytes)):
        var c = Int(digit_bytes[j])
        if c < 48 or c > 57:
            raise Error("Dense layer byte size must be a nonnegative integer")
    var value = atol(digits)
    if value < 0 or value > (Int(9223372036854775807) // multiplier):
        raise Error("Dense layer byte size overflow")
    return value * multiplier


def _suffix_len(upper: String, letter: String) -> Int:
    if upper.endswith(letter + "IB"):
        return 3
    if upper.endswith(letter + "B"):
        return 2
    return 1


def resolve_hard_cap(flag_bytes: Int, env_bytes: Int) raises -> Int:
    """Resolve the hard cap: flag beats env; zero from both means unset.

    Same rule as J-018's resolve_hard_cap. The dense surface names are
    the flag --dense-layer-cache-bytes and the environment variable
    AESIR_DENSE_LAYER_CACHE_BYTES (surface plumbing is J-036's, as with
    the expert surface); the resolution rule is fixed here.
    """
    if flag_bytes < 0 or env_bytes < 0:
        raise Error("Dense layer cap values must be nonnegative")
    if flag_bytes > 0:
        return flag_bytes
    return env_bytes


# -- directory-true layer accounting ------------------------------------


def dense_layer_suffixes() -> List[String]:
    """The tensor suffixes that make up one dense GQA layer.

    This is the require-list of core/dense_gqa_profile.mojo (the
    families the spill path serves: llama / qwen2 dense GQA), with the
    optional q/k norms and attention biases last. Presence is checked
    per tensor against the directory, so a family without the optional
    tensors accounts exactly its own bytes.
    """
    var suffixes = List[String]()
    suffixes.append(String("attn_norm.weight"))
    suffixes.append(String("ffn_norm.weight"))
    suffixes.append(String("attn_q.weight"))
    suffixes.append(String("attn_k.weight"))
    suffixes.append(String("attn_v.weight"))
    suffixes.append(String("attn_output.weight"))
    suffixes.append(String("ffn_gate.weight"))
    suffixes.append(String("ffn_up.weight"))
    suffixes.append(String("ffn_down.weight"))
    suffixes.append(String("attn_q_norm.weight"))
    suffixes.append(String("attn_k_norm.weight"))
    suffixes.append(String("attn_q.bias"))
    suffixes.append(String("attn_k.bias"))
    suffixes.append(String("attn_v.bias"))
    return suffixes^


def dense_layer_bytes(model: PackedGGUF, layer: Int) raises -> Int:
    """One layer's true byte size, summed from the tensor directory.

    Every offset/size comes from the opened file's directory (the
    J-017 section 3.3 contract); no family layout is assumed. A layer
    with none of its tensors present is an error, not a zero: a silent
    zero would understate every budget built on it.
    """
    if layer < 0:
        raise Error("Dense layer index out of range")
    var prefix = String("blk.") + String(layer) + String(".")
    var suffixes = dense_layer_suffixes()
    var total = 0
    var found = 0
    for i in range(len(suffixes)):
        var name = prefix + suffixes[i]
        if name in model.tensors:
            total += model.tensors[name].byte_count
            found += 1
    if found == 0:
        raise Error("Dense layer has no tensors in the directory")
    return total


def dense_always_resident_bytes(model: PackedGGUF) raises -> Int:
    """The dense always-resident set: everything that is not a layer.

    Token embedding, rope factors where the file carries them, the
    final norm, and the output head where the file carries one untied.
    Presence is a per-file fact read from the directory (a tied head
    contributes nothing here, exactly as J-017 section 2.2 requires the
    budget to be derived, never defaulted).
    """
    var total = 0
    if "token_embd.weight" in model.tensors:
        total += model.tensors["token_embd.weight"].byte_count
    if "rope_freqs.weight" in model.tensors:
        total += model.tensors["rope_freqs.weight"].byte_count
    if "output_norm.weight" in model.tensors:
        total += model.tensors["output_norm.weight"].byte_count
    if "output.weight" in model.tensors:
        total += model.tensors["output.weight"].byte_count
    if total == 0:
        raise Error("Dense directory carries no always-resident tensors")
    return total


# -- the spill split as a residency plan ---------------------------------


struct DenseResidencyPlan(Copyable, ImplicitlyCopyable):
    """A dense split stated in the residency vocabulary.

    gpu layers are the front prefix, pinned resident on the device for
    the life of the open (never evicted, never counted against any
    demand budget -- the D1 rule); host layers are the tail, resident
    in host memory through the loader's mapping. always_resident_bytes
    rides with the device side in the spill session (the front session
    uploads the embedding with its front tensors).
    """

    var layer_count: Int
    var gpu_layers: Int
    var host_layers: Int
    var always_resident_bytes: Int
    var gpu_layer_bytes: Int
    var host_layer_bytes: Int
    var total_layer_bytes: Int
    var device_budget_bytes: Int
    var spilled: Bool

    def __init__(
        out self,
        layer_count: Int,
        gpu_layers: Int,
        always_resident_bytes: Int,
        gpu_layer_bytes: Int,
        host_layer_bytes: Int,
        total_layer_bytes: Int,
        device_budget_bytes: Int,
    ):
        self.layer_count = layer_count
        self.gpu_layers = gpu_layers
        self.host_layers = layer_count - gpu_layers
        self.always_resident_bytes = always_resident_bytes
        self.gpu_layer_bytes = gpu_layer_bytes
        self.host_layer_bytes = host_layer_bytes
        self.total_layer_bytes = total_layer_bytes
        self.device_budget_bytes = device_budget_bytes
        self.spilled = gpu_layers < layer_count

    def device_resident_bytes(self) -> Int:
        """Bytes the device must hold: always-resident + front layers."""
        return self.always_resident_bytes + self.gpu_layer_bytes

    def describe(self) -> String:
        return (
            "layers="
            + String(self.layer_count)
            + " gpu_layers="
            + String(self.gpu_layers)
            + " host_layers="
            + String(self.host_layers)
            + " always_resident_bytes="
            + String(self.always_resident_bytes)
            + " gpu_layer_bytes="
            + String(self.gpu_layer_bytes)
            + " host_layer_bytes="
            + String(self.host_layer_bytes)
            + " total_layer_bytes="
            + String(self.total_layer_bytes)
            + " device_resident_bytes="
            + String(self.device_resident_bytes())
            + " device_budget_bytes="
            + String(self.device_budget_bytes)
            + " spilled="
            + String(self.spilled)
        )


def describe_dense_spill(
    layer_sizes: List[Int], gpu_layers: Int, always_resident_bytes: Int
) raises -> DenseResidencyPlan:
    """State a chosen front/tail split as a residency plan.

    gpu_layers is the session's exec_layers: layers [0, gpu_layers)
    are device-resident, the rest host-resident. Sizes are the
    directory-true per-layer bytes; the plan sums them, it does not
    estimate them.
    """
    if gpu_layers < 0 or gpu_layers > len(layer_sizes):
        raise Error("Dense spill gpu_layers out of range")
    if always_resident_bytes < 0:
        raise Error("Dense spill always-resident bytes out of range")
    var gpu_bytes = 0
    var host_bytes = 0
    for i in range(len(layer_sizes)):
        if layer_sizes[i] <= 0:
            raise Error("Dense layer sizes must be positive")
        if i < gpu_layers:
            gpu_bytes += layer_sizes[i]
        else:
            host_bytes += layer_sizes[i]
    return DenseResidencyPlan(
        len(layer_sizes),
        gpu_layers,
        always_resident_bytes,
        gpu_bytes,
        host_bytes,
        gpu_bytes + host_bytes,
        0,
    )


def plan_dense_spill(
    layer_sizes: List[Int],
    always_resident_bytes: Int,
    device_budget_bytes: Int,
) raises -> DenseResidencyPlan:
    """Choose the largest front prefix a device budget admits.

    The budget must cover the always-resident set first (it is not
    optional); layers then join the front prefix in order while they
    fit whole -- a layer is never split across the boundary (the unit
    is atomic, D3 generalised). If even the always-resident set exceeds
    the budget the plan reports gpu_layers = 0 with the budget stated,
    and the caller sees the refusal in the numbers rather than a
    silently truncated model.
    """
    if device_budget_bytes < 0 or always_resident_bytes < 0:
        raise Error("Dense spill planning values out of range")
    var gpu_bytes = 0
    var gpu_layers = 0
    var spent = always_resident_bytes
    for i in range(len(layer_sizes)):
        if layer_sizes[i] <= 0:
            raise Error("Dense layer sizes must be positive")
        if spent + layer_sizes[i] <= device_budget_bytes:
            spent += layer_sizes[i]
            gpu_bytes += layer_sizes[i]
            gpu_layers += 1
        else:
            break
    var host_bytes = 0
    for i in range(gpu_layers, len(layer_sizes)):
        host_bytes += layer_sizes[i]
    return DenseResidencyPlan(
        len(layer_sizes),
        gpu_layers,
        always_resident_bytes,
        gpu_bytes,
        host_bytes,
        gpu_bytes + host_bytes,
        device_budget_bytes,
    )


# -- open-time sizing (the J-018 contract, dense terms) -------------------


struct DenseLayerSizing(Copyable, ImplicitlyCopyable):
    """Open-time budget arithmetic, stated in full for the open report.

    Field-for-field the DenseLayerStats/ExpertCacheSizing shape: the
    reserve composition is J-018's (always-resident + KV allowance +
    scratch + one fifth of total memory as OS headroom).
    """

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


def plan_dense_layer_budget(
    free_at_open_bytes: Int,
    total_bytes: Int,
    hard_cap_bytes: Int,
    resident_bytes: Int,
    kv_allowance_bytes: Int,
    scratch_bytes: Int,
    largest_layer_bytes: Int,
) raises -> DenseLayerSizing:
    """Budget = min(hard cap if set, free-at-open - reserve).

    Term-for-term J-018's plan_expert_cache_budget. The floor differs
    in kind, honestly: the expert floor is one token's routed demand;
    the dense floor is the largest single layer, because a layer cache
    smaller than its largest unit cannot hold even one unit.
    """
    if (
        free_at_open_bytes < 0
        or total_bytes <= 0
        or hard_cap_bytes < 0
        or resident_bytes < 0
        or kv_allowance_bytes < 0
        or scratch_bytes < 0
        or largest_layer_bytes <= 0
    ):
        raise Error("Dense layer sizing values out of range")
    var os_headroom = total_bytes // 5
    var reserve = resident_bytes + kv_allowance_bytes + scratch_bytes + os_headroom
    if reserve < 0:
        raise Error("Dense layer reserve overflow")
    var budget = free_at_open_bytes - reserve
    if budget < 0:
        budget = 0
    var capped = False
    if hard_cap_bytes > 0 and budget > hard_cap_bytes:
        budget = hard_cap_bytes
        capped = True
    return DenseLayerSizing(
        budget,
        reserve,
        resident_bytes,
        kv_allowance_bytes,
        scratch_bytes,
        os_headroom,
        hard_cap_bytes,
        capped,
        budget < largest_layer_bytes,
    )


# -- statistics (the J-016/J-018 vocabulary over layer units) -------------


struct DenseLayerStats(Copyable, ImplicitlyCopyable):
    """Run statistics with exactly ExpertCacheStats' field names.

    accesses/hits/misses/cold are over layer units; bytes_streamed is
    what a demand form would have had to move. A reader who knows the
    J-018 describe() line can read this one unchanged.
    """

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


struct _LayerEntry(Copyable, ImplicitlyCopyable):
    var layer: Int
    var size_bytes: Int
    var segment: Int
    var last_tick: Int
    var pin_count: Int

    def __init__(
        out self, layer: Int, size_bytes: Int, segment: Int, last_tick: Int
    ):
        self.layer = layer
        self.size_bytes = size_bytes
        self.segment = segment
        self.last_tick = last_tick
        self.pin_count = 0


struct _Freq(Copyable, ImplicitlyCopyable):
    var key: Int
    var count: Int

    def __init__(out self, key: Int, count: Int):
        self.key = key
        self.count = count


struct DenseLayerCache(Copyable, Movable):
    """Byte-budgeted demand cache over whole dense layers.

    The J-018 ExpertCache policy machinery with the unit changed from
    (layer, expert) pairs to layers: two segments (probation one
    eighth, main the rest), a frequency gate on probation admission,
    promotion on second touch against a frequency-compared victim,
    faithful lru/lfu baselines through the same interface, pinning,
    policy-ordered shrink, and the hard cap honoured exactly
    (evict-then-admit, never transiently exceeded). Metadata only --
    see the module docstring for why no payload is held.
    """

    var budget_bytes: Int
    var probation_bytes: Int
    var policy: String
    var entries: List[_LayerEntry]
    var freq: List[_Freq]
    var seen_keys: List[Int]
    var evicted_keys: List[Int]
    var tick: Int
    var stats: DenseLayerStats

    def __init__(out self, budget_bytes: Int, policy: String) raises:
        if budget_bytes <= 0:
            raise Error("Dense layer cache budget must be positive")
        if policy != "segmented" and policy != "lru" and policy != "lfu":
            raise Error("Dense layer cache policy must be segmented, lru or lfu")
        self.budget_bytes = budget_bytes
        self.probation_bytes = budget_bytes // 8
        if self.probation_bytes == 0:
            self.probation_bytes = budget_bytes
        self.policy = policy
        self.entries = List[_LayerEntry]()
        self.freq = List[_Freq]()
        self.seen_keys = List[Int]()
        self.evicted_keys = List[Int]()
        self.tick = 0
        self.stats = DenseLayerStats()
        self.stats.budget_bytes = budget_bytes

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

    def _find(self, layer: Int) -> Int:
        for i in range(len(self.entries)):
            if self.entries[i].layer == layer:
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

    def _was_evicted(self, layer: Int) -> Bool:
        for i in range(len(self.evicted_keys)):
            if self.evicted_keys[i] == layer:
                return True
        return False

    def _evict_at(mut self, index: Int):
        var key = self.entries[index].layer
        self.stats.evictions += 1
        self.stats.bytes_evicted += self.entries[index].size_bytes
        self.evicted_keys.append(key)
        if len(self.evicted_keys) > 8192:
            _ = self.evicted_keys.pop(0)
        var last = self.entries.pop()
        if index < len(self.entries):
            self.entries[index] = last

    def _victim(self, segment: Int, mode: String) -> Int:
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
                var fi = self._freq_of(self.entries[i].layer)
                var fb = self._freq_of(self.entries[best].layer)
                if fi < fb or (
                    fi == fb
                    and self.entries[i].last_tick < self.entries[best].last_tick
                ):
                    best = i
        return best

    def _make_room(
        mut self, segment: Int, incoming_bytes: Int, segment_cap: Int
    ) -> Bool:
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

    def access(mut self, layer: Int, size_bytes: Int) raises -> Int:
        """One whole-layer access at its directory-true size.

        Outcome codes are J-018's: on a hit the caller owes zero
        movement for that layer; on a miss the caller owes exactly one
        whole-layer stream, and the code says whether the layer was
        admitted, bypassed, or refused as larger than the budget.
        """
        if layer < 0 or size_bytes <= 0:
            raise Error("Dense layer access values out of range")
        self.tick += 1
        if self.policy == "segmented" and self.tick % FREQ_AGING_INTERVAL == 0:
            self._freq_age()
        var seen_before = False
        for i in range(len(self.seen_keys)):
            if self.seen_keys[i] == layer:
                seen_before = True
                break
        if not seen_before:
            self.seen_keys.append(layer)
        self._freq_bump(layer)
        self.stats.accesses += 1

        var index = self._find(layer)
        if index >= 0:
            if self.entries[index].size_bytes != size_bytes:
                raise Error("Dense layer size changed for a resident layer")
            self.stats.hits += 1
            self.entries[index].last_tick = self.tick
            if (
                self.policy == "segmented"
                and self.entries[index].segment == SEGMENT_PROBATION
            ):
                self._try_promote(index)
            self._sync_stats()
            return ACCESS_HIT

        self.stats.misses += 1
        if not seen_before:
            self.stats.cold_misses += 1
        if self._was_evicted(layer):
            self.stats.evicted_before_reuse += 1
        self.stats.bytes_streamed += size_bytes
        if size_bytes > self.budget_bytes:
            self.stats.too_large += 1
            self._sync_stats()
            return ACCESS_MISS_TOO_LARGE

        if self.policy == "lru" or self.policy == "lfu":
            if not self._make_room(SEGMENT_MAIN, size_bytes, self.budget_bytes):
                self.stats.bypasses += 1
                self._sync_stats()
                return ACCESS_MISS_BYPASSED
            self.entries.append(
                _LayerEntry(layer, size_bytes, SEGMENT_MAIN, self.tick)
            )
            self.stats.admissions += 1
            self._sync_stats()
            return ACCESS_MISS_ADMITTED

        var probation_victim = self._victim(SEGMENT_PROBATION, String("lru"))
        if (
            probation_victim >= 0
            and self._segment_bytes(SEGMENT_PROBATION) + size_bytes
            > self.probation_bytes
            and self._freq_of(layer)
            < self._freq_of(self.entries[probation_victim].layer)
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
        self.entries.append(
            _LayerEntry(layer, size_bytes, SEGMENT_PROBATION, self.tick)
        )
        self.stats.admissions += 1
        self._sync_stats()
        return ACCESS_MISS_ADMITTED

    def _try_promote(mut self, index_in: Int):
        var index = index_in
        var size = self.entries[index].size_bytes
        var key = self.entries[index].layer
        var main_cap = self.budget_bytes - self.probation_bytes
        while self._segment_bytes(SEGMENT_MAIN) + size > main_cap:
            var victim = self._victim(SEGMENT_MAIN, String("freq"))
            if victim < 0:
                return
            if self._freq_of(self.entries[victim].layer) > self._freq_of(key):
                return
            self._evict_at(victim)
            index = self._find(key)
            if index < 0:
                return
        self.entries[index].segment = SEGMENT_MAIN
        self.stats.promotions += 1

    def pin(mut self, layer: Int) raises -> Bool:
        """Pin a resident layer (in-flight use). False if not resident."""
        var index = self._find(layer)
        if index < 0:
            return False
        self.entries[index].pin_count += 1
        return True

    def unpin(mut self, layer: Int) raises:
        var index = self._find(layer)
        if index < 0 or self.entries[index].pin_count <= 0:
            raise Error("Dense layer unpin of an unpinned layer")
        self.entries[index].pin_count -= 1

    def shrink(mut self, new_budget_bytes: Int) raises -> Int:
        """Reduce the budget, shedding policy-order entries, pins held.

        Same contract as J-018's shrink: probation sheds first, then
        main by (frequency, recency); the returned resident bytes make
        any pinned overage visible instead of corrupting in-flight work.
        """
        if new_budget_bytes <= 0:
            raise Error("Dense layer shrink budget must be positive")
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

    def _sync_stats(mut self):
        self.stats.bytes_resident_now = self._total_bytes()
        self.stats.entries_now = len(self.entries)

    def snapshot(mut self) -> DenseLayerStats:
        self._sync_stats()
        return self.stats

    def contains(self, layer: Int) -> Bool:
        return self._find(layer) >= 0
