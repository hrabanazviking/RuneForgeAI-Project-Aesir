# core/sampler.mojo
# Sampler Stack & Deterministic Seeded PRNG for Project Aesir

from std.math import exp, isinf, isnan, log, max, min
from std.memory import Pointer
from .mimir_well import f16, f32
from .vocab_restriction import VocabRestrictor


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


def sort_candidates_descending(mut candidates: List[TokenCandidate]):
    """Insertion sort candidates by logit in descending order."""
    var n = len(candidates)
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


def apply_top_k(mut candidates: List[TokenCandidate], top_k: Int):
    """Truncates candidates list to top_k entries."""
    if len(candidates) == 0 or top_k <= 0 or top_k >= len(candidates):
        return
    sort_candidates_descending(candidates)
    var kept = List[TokenCandidate]()
    for i in range(top_k):
        kept.append(candidates[i])
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


def apply_vocab_restriction(
    mut candidates: List[TokenCandidate],
    candidate_texts: List[String],
    restrictor: VocabRestrictor,
) raises -> Int:
    """Masks every candidate the vocabulary restrictor does
    not admit to -1e9 (the apply_token_mask grain), leaving
    admitted candidates untouched. The decision is exactly
    J-113's VocabRestrictor.is_token_valid per candidate
    text, in candidate order -- no second implementation.
    Raises on a candidate/text count mismatch: a mask
    applied to the wrong texts is a programming error,
    never a silent pass. Returns the admitted count."""
    if len(candidates) != len(candidate_texts):
        raise Error(
            "Vocab restriction candidate/text count mismatch: "
            + String(len(candidates)) + " candidates, "
            + String(len(candidate_texts)) + " texts")
    var allowed = 0
    for c_idx in range(len(candidates)):
        if restrictor.is_token_valid(candidate_texts[c_idx]):
            allowed += 1
        else:
            candidates[c_idx].logit = Float32(-1e9)
    return allowed


def _vr_is_suppressed(suppress_tokens: List[Int], token_id: Int) -> Bool:
    for s_idx in range(len(suppress_tokens)):
        if suppress_tokens[s_idx] == token_id:
            return True
    return False


def sample_token_from_logits_restricted(
    logits_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    vocab_size: Int,
    token_texts: List[String],
    restrictor: VocabRestrictor,
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
) raises -> Int:
    """The restricted sibling of sample_token_from_logits
    (J-114): exact permitted-vocabulary enforcement at
    sampling time. token_texts must carry one decoded
    text per vocabulary ID (a count mismatch raises --
    token IDs alone contain no lexical information, the
    grammar layer's standing rule). Only tokens whose
    text the restrictor admits from its current state
    can be returned; suppressed IDs are excluded in both
    paths. Returns -1 when no candidate is admitted --
    never a disallowed token, never the unrestricted
    function's return-0 fallback. The restrictor is
    taken by value and is NOT advanced: the caller
    commits the emitted token's text through
    VocabRestrictor.advance_state after emission
    (validate-then-commit preserved end-to-end).
    Path rules mirror the unrestricted function: greedy
    (temperature <= 0 or top_k == 1) scans admitted IDs
    with sanitised logits, lowest ID on ties; the
    sampled path thresholds at 15.0 below the ADMITTED
    set's maximum (the renormalised distribution's own
    max), then runs the standing penalty / temperature /
    top-k / top-p / min-p pipeline over the admitted
    candidates only. The sampled path scans validity
    twice (max scan + collect); the greedy path once."""
    if vocab_size <= 0:
        return -1
    if len(token_texts) != vocab_size:
        raise Error(
            "Vocab restriction requires one decoded token "
            "text per vocabulary ID: vocab_size "
            + String(vocab_size) + ", texts "
            + String(len(token_texts)))

    if temperature <= 0.0 or top_k == 1:
        var best_id = -1
        var max_val = Float32(0.0)
        for i in range(vocab_size):
            if not restrictor.is_token_valid(token_texts[i]):
                continue
            if _vr_is_suppressed(suppress_tokens, i):
                continue
            var val = sanitize_logit(logits_ptr.unsafe_load(i).cast[f32]())
            if best_id < 0 or val > max_val:
                max_val = val
                best_id = i
        return best_id

    var max_logit = Float32(0.0)
    var found = False
    for i in range(vocab_size):
        if not restrictor.is_token_valid(token_texts[i]):
            continue
        if _vr_is_suppressed(suppress_tokens, i):
            continue
        var val = sanitize_logit(logits_ptr.unsafe_load(i).cast[f32]())
        if not found or val > max_logit:
            max_logit = val
            found = True
    if not found:
        return -1

    var threshold = max_logit - Float32(15.0)
    var candidates = List[TokenCandidate]()
    for i in range(vocab_size):
        if not restrictor.is_token_valid(token_texts[i]):
            continue
        if _vr_is_suppressed(suppress_tokens, i):
            continue
        var val = sanitize_logit(logits_ptr.unsafe_load(i).cast[f32]())
        if val >= threshold:
            candidates.append(TokenCandidate(i, val))

    if len(candidates) == 0:
        return -1

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
        return -1

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
    var max_logit = sanitize_logit(logits_ptr.unsafe_load(0).cast[f32]())
    for i in range(1, vocab_size):
        var val = sanitize_logit(logits_ptr.unsafe_load(i).cast[f32]())
        if val > max_logit:
            max_logit = val

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
