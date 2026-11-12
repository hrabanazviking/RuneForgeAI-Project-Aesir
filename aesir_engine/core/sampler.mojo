# core/sampler.mojo
# Sampler Stack & Deterministic Seeded PRNG for Project Aesir

from std.math import exp, isinf, isnan, log, max, min
from std.memory import Pointer
from .mimir_well import f16, f32


@always_inline
def sanitize_logit(val: Float32) -> Float32:
    """Sanitizes non-finite logit values to prevent NaN propagation."""
    if isnan(val) or isinf(val):
        return Float32(-1e9)
    return val


struct RuneRNG(Copyable):
    """Deterministic SplitMix64 pseudo-random number generator."""

    var state: UInt64

    def __init__(out self, seed: UInt64 = 42):
        if seed == 0:
            self.state = 0x9E3779B97F4A7C15
        else:
            self.state = seed

    def __copyinit__(out self, existing: Self):
        self.state = existing.state

    @always_inline
    def copy(self) -> Self:
        return Self(self.state)

    def next_u64(mut self) -> UInt64:
        self.state = (self.state ^ (self.state >> 30)) * 0xBF58476D1CE4E5B9
        self.state = (self.state ^ (self.state >> 27)) * 0x94D049BB133111EB
        return self.state ^ (self.state >> 31)

    def next_float32(mut self) -> Float32:
        """Returns a uniform random Float32 in range [0.0, 1.0)."""
        var val = self.next_u64()
        return Float32(val & 0xFFFFFF) / Float32(16777216)


struct TokenCandidate(Copyable, ImplicitlyCopyable):
    var id: Int
    var logit: Float32

    def __init__(out self, id: Int, logit: Float32):
        self.id = id
        self.logit = logit

    def __copyinit__(out self, existing: Self):
        self.id = existing.id
        self.logit = existing.logit

    @always_inline
    def copy(self) -> Self:
        return Self(self.id, self.logit)


def apply_repetition_penalty(
    mut candidates: List[TokenCandidate],
    context_tokens: List[Int],
    penalty: Float32,
):
    """Applies repetition penalty to candidates present in context_tokens."""
    if len(candidates) == 0 or penalty == 1.0 or len(context_tokens) == 0:
        return
    for c_idx in range(len(candidates)):
        var cid = candidates[c_idx].id
        var present = False
        for ctx_idx in range(len(context_tokens)):
            if context_tokens[ctx_idx] == cid:
                present = True
                break
        if present:
            if candidates[c_idx].logit < 0.0:
                candidates[c_idx].logit *= penalty
            else:
                candidates[c_idx].logit /= penalty


def apply_temperature(
    mut candidates: List[TokenCandidate],
    temperature: Float32,
):
    """Scales candidate logits by 1.0 / temperature."""
    if len(candidates) == 0 or temperature <= 0.0 or temperature == 1.0:
        return
    var inv_temp = Float32(1.0) / temperature
    for i in range(len(candidates)):
        candidates[i].logit *= inv_temp


def _merge_sort_range(
    mut candidates: List[TokenCandidate],
    mut scratch: List[TokenCandidate],
    lo: Int,
    hi: Int,
):
    """Stable merge sort of candidates[lo:hi] by logit descending.

    Stability matches the old insertion sort exactly: equal logits
    keep their original (ascending-id) order, because the merge
    takes from the left run on ties (>=). A-044.
    """
    if hi - lo < 2:
        return
    var mid = (lo + hi) // 2
    _merge_sort_range(candidates, scratch, lo, mid)
    _merge_sort_range(candidates, scratch, mid, hi)
    var i = lo
    var j = mid
    var k = lo
    while i < mid and j < hi:
        if candidates[i].logit >= candidates[j].logit:
            scratch[k] = candidates[i].copy()
            i += 1
        else:
            scratch[k] = candidates[j].copy()
            j += 1
        k += 1
    while i < mid:
        scratch[k] = candidates[i].copy()
        i += 1
        k += 1
    while j < hi:
        scratch[k] = candidates[j].copy()
        j += 1
        k += 1
    for t in range(lo, hi):
        candidates[t] = scratch[t].copy()


def sort_candidates_descending(mut candidates: List[TokenCandidate]):
    """Sort candidates by logit in descending order (stable).

    A-044: the old insertion sort was O(n^2) -- at a realistic
    32k vocab with a flat logits window it cost ~64 ms per sampled
    token (measured, bench_sampling_a044). This version keeps the
    exact same stable result: an O(n) already-descending fast path
    (the re-sorts inside apply_top_p/apply_min_p after apply_top_k
    now cost one scan), the original insertion sort for small n,
    and a stable merge sort (O(n log n)) otherwise.
    """
    var n = len(candidates)
    if n < 2:
        return
    var already = True
    for i in range(1, n):
        if candidates[i].logit > candidates[i - 1].logit:
            already = False
            break
    if already:
        return
    if n <= 24:
        for i in range(1, n):
            var key_id = candidates[i].id
            var key_logit = candidates[i].logit
            var j = i - 1
            while j >= 0 and candidates[j].logit < key_logit:
                candidates[j + 1].id = candidates[j].id
                candidates[j + 1].logit = candidates[j].logit
                j -= 1
            candidates[j + 1].id = key_id
            candidates[j + 1].logit = key_logit
        return
    var scratch = List[TokenCandidate]()
    for i in range(n):
        scratch.append(candidates[i].copy())
    _merge_sort_range(candidates, scratch, 0, n)


def _ranks_before(candidates: List[TokenCandidate], a: Int, b: Int) -> Bool:
    """Total order matching the stable descending sort: higher logit
    first; ties by original position (lower index first)."""
    if candidates[a].logit != candidates[b].logit:
        return candidates[a].logit > candidates[b].logit
    return a < b


def apply_top_k(mut candidates: List[TokenCandidate], top_k: Int):
    """Truncates candidates list to top_k entries.

    A-044: previously this fully sorted all candidates (insertion
    sort, O(n^2)) just to keep top_k. Now: quickselect the winning
    SET in average O(n) under the exact stable-sort total order
    (logit descending, original position ascending on ties), collect
    the winners in original order, then stable-sort only the kept
    top_k. The result is element-for-element the first top_k of the
    old full stable sort, for every input and every tie pattern.
    """
    if len(candidates) == 0 or top_k <= 0 or top_k >= len(candidates):
        return
    var n = len(candidates)
    var idx = List[Int]()
    for i in range(n):
        idx.append(i)
    # Quickselect rank top_k-1 (0-based) into place under _ranks_before.
    var target = top_k - 1
    var lo = 0
    var hi = n - 1
    while lo < hi:
        # Median-of-three pivot, moved to idx[hi].
        var mid = (lo + hi) // 2
        if _ranks_before(candidates, idx[mid], idx[lo]):
            var tmp = idx[lo]
            idx[lo] = idx[mid]
            idx[mid] = tmp
        if _ranks_before(candidates, idx[hi], idx[lo]):
            var tmp2 = idx[lo]
            idx[lo] = idx[hi]
            idx[hi] = tmp2
        if _ranks_before(candidates, idx[mid], idx[hi]):
            var tmp3 = idx[hi]
            idx[hi] = idx[mid]
            idx[mid] = tmp3
        var pivot = idx[hi]
        var store = lo
        for i in range(lo, hi):
            if _ranks_before(candidates, idx[i], pivot):
                var tmp4 = idx[i]
                idx[i] = idx[store]
                idx[store] = tmp4
                store += 1
        idx[hi] = idx[store]
        idx[store] = pivot
        if store == target:
            break
        elif store < target:
            lo = store + 1
        else:
            hi = store - 1
    var selected = List[Bool]()
    for _ in range(n):
        selected.append(False)
    for t in range(top_k):
        selected[idx[t]] = True
    var kept = List[TokenCandidate]()
    for i in range(n):
        if selected[i]:
            kept.append(candidates[i].copy())
    sort_candidates_descending(kept)
    candidates = kept.copy()


def apply_top_p(mut candidates: List[TokenCandidate], top_p: Float32):
    """Nucleus sampling: keeps smallest candidate set with cumulative softmax probability >= top_p."""
    if len(candidates) == 0 or top_p >= 1.0 or len(candidates) <= 1:
        return
    sort_candidates_descending(candidates)

    var max_logit = candidates[0].logit
    var sum_exp = Float32(0.0)
    var probs = List[Float32]()
    for i in range(len(candidates)):
        var p_val = exp(candidates[i].logit - max_logit)
        probs.append(p_val)
        sum_exp += p_val

    if sum_exp > 0.0:
        for i in range(len(candidates)):
            probs[i] /= sum_exp

    var cum_sum = Float32(0.0)
    var cutoff_idx = len(candidates) - 1
    for i in range(len(candidates)):
        cum_sum += probs[i]
        if cum_sum >= top_p:
            cutoff_idx = i
            break

    var kept = List[TokenCandidate]()
    for i in range(cutoff_idx + 1):
        kept.append(candidates[i])
    candidates = kept.copy()


def apply_frequency_presence_penalty(
    mut candidates: List[TokenCandidate],
    context_tokens: List[Int],
    frequency_penalty: Float32,
    presence_penalty: Float32,
):
    """Applies OpenAI-style frequency (count-based) and presence (binary) penalties."""
    if len(candidates) == 0 or (frequency_penalty == 0.0 and presence_penalty == 0.0) or len(context_tokens) == 0:
        return

    for c_idx in range(len(candidates)):
        var cid = candidates[c_idx].id
        var count = 0
        for ctx_idx in range(len(context_tokens)):
            if context_tokens[ctx_idx] == cid:
                count += 1
        if count > 0:
            var freq_loss = Float32(count) * frequency_penalty
            var pres_loss = presence_penalty
            candidates[c_idx].logit -= (freq_loss + pres_loss)


def apply_min_p(mut candidates: List[TokenCandidate], min_p: Float32):
    """Min-P sampling: truncates candidate tokens whose softmax probability is less than min_p * max_prob."""
    if len(candidates) == 0 or min_p <= 0.0 or min_p >= 1.0 or len(candidates) <= 1:
        return
    sort_candidates_descending(candidates)

    var max_logit = candidates[0].logit
    var sum_exp = Float32(0.0)
    var probs = List[Float32]()
    for i in range(len(candidates)):
        var p_val = exp(candidates[i].logit - max_logit)
        probs.append(p_val)
        sum_exp += p_val

    if sum_exp > 0.0:
        for i in range(len(candidates)):
            probs[i] /= sum_exp

    var max_prob = probs[0]
    var threshold = min_p * max_prob

    var kept = List[TokenCandidate]()
    for i in range(len(candidates)):
        if probs[i] >= threshold:
            kept.append(candidates[i])
        else:
            break
    if len(kept) > 0:
        candidates = kept.copy()


def apply_token_mask(
    mut candidates: List[TokenCandidate],
    suppress_tokens: List[Int],
):
    """Forces suppressed token logits to -1e9 to suppress them from selection."""
    if len(candidates) == 0 or len(suppress_tokens) == 0:
        return
    for c_idx in range(len(candidates)):
        var cid = candidates[c_idx].id
        for s_idx in range(len(suppress_tokens)):
            if suppress_tokens[s_idx] == cid:
                candidates[c_idx].logit = Float32(-1e9)
                break


def _simd_logits_max(
    logits_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    vocab_size: Int,
) -> Float32:
    """Sanitized maximum logit, width-16 SIMD (A-044).

    Exactness: F16 lanes cast to F32 are finite iff |x| <= 65504.
    The pass also reduces min and sum: any lane outside the finite
    F16 range, or a NaN-poisoned sum, proves a non-finite lane
    exists, and the function then recomputes the maximum with the
    original scalar sanitize_logit loop, bit-identical for every
    input. On the all-finite fast path the SIMD max equals the
    scalar sanitized max exactly (max is order-independent and
    F16->F32 casts are exact).
    """
    comptime W = 16
    var end = (vocab_size // W) * W
    var best = SIMD[DType.float32, W](Float32(-1e9))
    var low = SIMD[DType.float32, W](Float32(1e9))
    var tot = SIMD[DType.float32, W](Float32(0.0))
    for base in range(0, end, W):
        var v = logits_ptr.unsafe_load[width=W](base).cast[f32]()
        best = max(best, v)
        low = min(low, v)
        tot += v
    var gmax = best.reduce_max()
    var bad = gmax > Float32(65504.0) or low.reduce_min() < Float32(-65504.0) or tot.reduce_add() != tot.reduce_add()
    for i in range(end, vocab_size):
        var val = sanitize_logit(logits_ptr.unsafe_load(i).cast[f32]())
        if val != logits_ptr.unsafe_load(i).cast[f32]():
            bad = True
        if val > gmax:
            gmax = val
    if not bad:
        return gmax
    var scalar_max = sanitize_logit(logits_ptr.unsafe_load(0).cast[f32]())
    for i in range(1, vocab_size):
        var val = sanitize_logit(logits_ptr.unsafe_load(i).cast[f32]())
        if val > scalar_max:
            scalar_max = val
    return scalar_max


def _simd_argmax_first(
    logits_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    vocab_size: Int,
    gmax: Float32,
) -> Int:
    """First index whose raw logit equals gmax (all-finite path).

    Only called when _simd_logits_max proved every lane finite, so
    raw F32 casts equal the sanitized values and the first match
    is exactly the scalar scan's lowest-id maximum. -1 if absent.
    """
    comptime W = 16
    var end = (vocab_size // W) * W
    for base in range(0, end, W):
        var v = logits_ptr.unsafe_load[width=W](base).cast[f32]()
        if v.reduce_max() == gmax:
            for j in range(W):
                if logits_ptr.unsafe_load(base + j).cast[f32]() == gmax:
                    return base + j
    for i in range(end, vocab_size):
        if logits_ptr.unsafe_load(i).cast[f32]() == gmax:
            return i
    return -1


def sample_token_from_logits(
    logits_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    vocab_size: Int,
    temperature: Float32,
    top_k: Int,
    top_p: Float32,
    repetition_penalty: Float32,
    context_tokens: List[Int],
    mut rng: RuneRNG,
    frequency_penalty: Float32 = 0.0,
    presence_penalty: Float32 = 0.0,
    min_p: Float32 = 0.0,
    suppress_tokens: List[Int] = List[Int](),
) -> Int:
    """Samples raw F16 logits; greedy equal finite maxima choose the lowest ID."""
    if vocab_size <= 0:
        return 0

    if temperature <= 0.0 or top_k == 1:
        if len(suppress_tokens) == 0:
            # A-044 fast path: SIMD sanitized max + first-index scan.
            # Semantics identical to the scalar loop below (lowest-id
            # tie break, non-finite lanes sanitized to -1e9): the
            # helper falls back to that exact scalar computation
            # whenever any lane is non-finite.
            var gmax = _simd_logits_max(logits_ptr, vocab_size)
            var found = _simd_argmax_first(logits_ptr, vocab_size, gmax)
            if found >= 0:
                return found
            # gmax came from the sanitized scalar fallback but a
            # non-finite lane made raw equality miss it; use the
            # exact scalar loop below.
            if gmax == Float32(-1e9):
                return 0
        var best_id = 0
        var max_val = sanitize_logit(logits_ptr.unsafe_load(0).cast[f32]())
        for s_idx in range(len(suppress_tokens)):
            if suppress_tokens[s_idx] == 0:
                max_val = Float32(-1e9)
                break

        for i in range(1, vocab_size):
            var val = sanitize_logit(logits_ptr.unsafe_load(i).cast[f32]())
            var is_suppressed = False
            for s_idx in range(len(suppress_tokens)):
                if suppress_tokens[s_idx] == i:
                    is_suppressed = True
                    break
            if is_suppressed:
                val = Float32(-1e9)
            if val > max_val:
                max_val = val
                best_id = i
        return best_id

    # O(N) Fast Threshold Filter: Collect candidates within 15.0 log-probability of max logit
    # Logits smaller than max_logit - 15.0 have relative probability < exp(-15) = 3.0e-7 and are truncated
    var max_logit = _simd_logits_max(logits_ptr, vocab_size)

    var threshold = max_logit - Float32(15.0)
    var candidates = List[TokenCandidate]()
    for i in range(vocab_size):
        var val = sanitize_logit(logits_ptr.unsafe_load(i).cast[f32]())
        if val >= threshold:
            candidates.append(TokenCandidate(i, val))

    if len(suppress_tokens) > 0:
        apply_token_mask(candidates, suppress_tokens)

    apply_repetition_penalty(candidates, context_tokens, repetition_penalty)
    apply_frequency_presence_penalty(candidates, context_tokens, frequency_penalty, presence_penalty)
    apply_temperature(candidates, temperature)
    if top_k > 0:
        apply_top_k(candidates, top_k)
    if top_p < 1.0:
        apply_top_p(candidates, top_p)
    if min_p > 0.0:
        apply_min_p(candidates, min_p)

    if len(candidates) == 0:
        return 0

    var max_l = candidates[0].logit
    for i in range(1, len(candidates)):
        if candidates[i].logit > max_l:
            max_l = candidates[i].logit

    var sum_e = Float32(0.0)
    var exps = List[Float32]()
    for i in range(len(candidates)):
        var e_val = exp(candidates[i].logit - max_l)
        exps.append(e_val)
        sum_e += e_val

    if sum_e <= 0.0:
        return candidates[0].id

    var r = rng.next_float32() * sum_e
    var acc = Float32(0.0)
    for i in range(len(candidates)):
        acc += exps[i]
        if r <= acc:
            return candidates[i].id

    return candidates[len(candidates) - 1].id
