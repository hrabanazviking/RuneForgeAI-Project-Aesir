"""Speculative sampling correctness (Janas road J-082).

The roadmap text: "Sampling correctness. Under temperature/
top-k/top-p, speculative sampling uses the proper rejection
correction; distribution tests (chi-square over seeded runs)
prove the sampler's honesty, not just greedy identity."

THE GAP THIS SLICE CLOSES. J-071 proved the GREEDY form of
the invariant (emission built from the target's choices only,
token-identical to plain greedy) and named the sampled form
as this slice's account. The tree already carried the pieces,
unintegrated: core/speculative.mojo's SpeculativeEngine holds
the min(1, p/q) acceptance primitive over caller-supplied
probabilities but REFUSES the rest by name ("speculative
reconciliation requires per-step normalized distributions,
residual sampling, and KV coordination"), and
core/sampler.mojo holds the engine's shaping stack
(temperature, top-k, top-p over TokenCandidate logits) and
its deterministic RuneRNG, but no speculative path consumes
either. This module is the pure correction layer between
them: it shapes both models' distributions, runs the
standard speculative-sampling rule over them, and proves
the rule's distributional honesty with seeded chi-square
tests. It executes no forward, opens no device, and wires
no session -- G-PROPOSER and G-EXECUTOR stand exactly as
J-081 recorded them, require_draft_check_use() (J-036)
still fails closed, and the facade's speculative_generate
still raises not-implemented. A live sampled round is
J-086's gate leg, not this slice's claim.

THE RULE (standard published speculative-sampling
mathematics -- Leviathan et al. 2023 / Chen et al. 2023;
derived from the mathematics, never from Janas code, which
this road has never opened). Per position, with target
distribution p and draft distribution q (both ALREADY
SHAPED, see below):

- Draw the draft token x from q.
- Accept x with probability min(1, p(x)/q(x)).
- On rejection, emit a token drawn from the RESIDUAL
  distribution norm(max(0, p - q)) and end the round.
- If all k draft positions accept, emit one BONUS token
  drawn from the target distribution at position k.

The emitted token at every position is then distributed
exactly as p: the acceptance path contributes min(p, q)
and the rejection path contributes (1 - sum min(p, q)) *
norm(max(0, p - q)) = p - min(p, q); the two sum to p.
The bonus token is drawn from p directly. This is an
exact identity, not an approximation: any implementation
whose seeded frequencies drift from p beyond sampling
noise is WRONG, which is what the chi-square verdict
below grades.

SHAPING BINDS TO THE ENGINE'S OWN SAMPLER, NOT A SECOND
ONE. shape_distribution() applies, in core/sampler.mojo's
own order (sample_token_from_logits: repetition/frequency
penalties, then temperature, then top-k, then top-p, then
softmax over the survivors): temperature scaling of the
logits (division by T), softmax, top-k truncation, top-p
(nucleus) truncation, renormalising after each truncation
-- the sampler renormalises implicitly by softmaxing over
the kept candidates, which is the same arithmetic on the
kept support. Sampler details this layer states plainly:
(a) the sampler's greedy branch (temperature <= 0, or
top_k == 1) returns the argmax before any shaping; this
layer's temperature == 0 returns the one-hot distribution
at the argmax (lowest id on ties, the sampler's own tie
rule), so a greedy target/draft pair shapes to one-hot
distributions and the correction over them reduces to
J-071's greedy identity (accept iff the ids agree);
(b) the sampler pre-filters candidates to logits within
15.0 of the max before shaping (relative probability
< exp(-15) ~ 3e-7) -- a numerical guard over a full vocab,
immaterial to the distributions graded here, and stated
so no reader believes the two code paths are byte-equal;
(c) the sampler works in Float32 over f16 logits; this
layer works in Float64 over stated logit fixtures, the
precision the distribution evidence is graded in.
Repetition/frequency/presence penalties and min-p are
context-dependent logit edits, not distribution shaping:
they belong to the host's logit preparation BEFORE this
layer (exactly where the sampler applies them, before
temperature), and are out of this slice's scope by name.
The seeded runs below draw from core/sampler.mojo's
RuneRNG, the engine's own deterministic PRNG -- no second
RNG is introduced.

THE VERDICT RULE, pre-registered (written here and in
docs/janas/J082_SAMPLING_CORRECTNESS.md section 1 BEFORE
any seeded run was executed; the suite in
tests/test_speculative_sampling.mojo is its executable
form, and its filed numbers are graded against THIS rule,
never against a threshold chosen after seeing them):

- FIXTURES (vocab V = 8, stated logits, Float64):
  target logits [2.0, 1.0, 0.5, 0.0, -0.5, -1.0, -1.5,
  -2.0]; draft logits [1.2, 0.2, 1.6, -0.8, 0.6, -1.4,
  -0.2, -2.2] -- deliberately different from the target
  (per-token acceptance sum min(p, q) between 0.46 and
  0.60 across the cases, so both the acceptance path and
  the residual path carry real mass in every case).
- CASES (shaping applied to BOTH distributions with the
  same parameters; the correction always consumes the
  SHAPED p and q): A: temperature 1.0, no truncation.
  B: temperature 0.7. C: top-k 3. D: top-p 0.8.
  E: temperature 1.4 + top-k 4 + top-p 0.9 combined.
- RUNS: N = 60,000 single-position speculative samples
  per case, seeds 20261101 (primary) -- one seeded stream
  per case, RuneRNG seeded once per case, three draws per
  step (draft, acceptance, residual) consumed in fixed
  order whether or not the step needs them, so the stream
  is a function of (seed, case) alone. A second seed
  (777) is filed as a robustness witness in the slice doc
  from the design prototype; the Mojo suite's verdict
  rests on the primary seed alone, as registered here.
- STATISTIC: Pearson chi-square of the observed counts
  against the SHAPED TARGET distribution, df = (target
  support size - 1), graded at alpha = 0.001 (critical
  values: df 1: 10.828, 2: 13.816, 3: 16.266, 4: 18.467,
  5: 20.515, 6: 22.458, 7: 24.322). The corrected sampler
  must PASS (statistic < critical) in EVERY case. An
  observed count in a bin where the shaped target has
  probability zero is an automatic FAIL (the statistic is
  infinite there); chi_square_statistic() reports that
  state as the sentinel -1.0, never as a small number.
- THE CONTROL (the test must be able to fail): the NAIVE
  sampler -- emit the draft token unconditionally, no
  correction -- run over the same fixtures, the same N,
  the same seeds, must FAIL the same chi-square in EVERY
  case (statistic > critical, or the automatic zero-bin
  FAIL in the truncated cases where the draft's shaped
  support reaches tokens the target truncated away). A
  slice whose control passes has proved nothing and does
  not bank.
- BONUS PATH: rounds of k = 2 over case A's stationary
  fixture (the same shaped p and q at every position),
  seed 424242, run until 12,000 bonus tokens are
  collected (rounds capped at 200,000; the collection
  count itself is filed). Bonus tokens -- emitted only
  on full acceptance, drawn from p by the rule -- must
  PASS the same chi-square against p at df 7. The
  first-position emission of every round is the
  single-position rule itself and is graded by the
  per-case runs, not double-counted here.
- DETERMINISTIC LEGS (no statistics): scripted-draw
  rounds pin the rule's mechanics exactly -- acceptance
  prefix, residual emission on the rejecting position
  and nowhere else, bonus emission on full acceptance
  and nowhere else, and every refusal (k outside the
  J-071 band 1..15, flat-length mismatches, malformed
  distributions, out-of-range draws, the undefined
  residual of identical distributions).

WHAT THIS MODULE DECIDES, AND WHAT IT REFUSES TO DECIDE:
the correction's arithmetic and its distributional
honesty over stated fixtures are PROVEN by the suite;
the honesty of a LIVE pair (real models, real logits) is
NOT PROVEN here and is roaded to the J-086 gate with the
recipe in the slice doc. No speed, acceptance-rate, or
tok/s claim exists anywhere in this module: acceptance
rates over fixtures are fixture properties, and the
suite files none as a model claim.

HOST CONTRACT (for the loop that will consume this layer
when a proposer and a verify executor exist): (1) shape
the target's and the draft's logits at every position
with the SESSION's temperature/top-k/top-p through
shape_distribution() -- the correction must consume the
shaped distributions, never the raw softmaxes, or the
emitted stream follows the wrong distribution;
(2) snapshot KV/context/RNG state per J-072's contract
before the round (a sampled round DOES consume RNG draws
-- the exact count is the round account's business: k
draft draws + k acceptance draws + 1 final draw under
this module's fixed consumption, vs the greedy round's
zero, which J-071's account enforces for greedy rounds
only); (3) derive the round through run_sampled_round()
and emit exactly its emitted_tokens; (4) roll KV and
context back to snapshot + len(emitted_tokens), per
J-072; (5) file the round's account with the run's
evidence.
"""

from std.math import exp, isinf, isnan

from core.sampler import RuneRNG  # noqa: F401  (re-exported binding: the seeded runs draw from the engine's own PRNG)

# The J-071 draft-check band binds k exactly as it binds
# the greedy loop: pass width k+1 in 2..16, so k in 1..15.
comptime SAMPLED_K_MIN = 1
comptime SAMPLED_K_MAX = 15

# chi_square_statistic() sentinel: an observed count sits
# in a zero-probability bin; the true statistic is
# infinite and the verdict is an automatic FAIL.
comptime CHI_SQUARE_ZERO_BIN = -1.0


def _validate_distribution(probs: List[Float64], what: String) raises:
    if len(probs) == 0:
        raise Error("SpeculativeSampling: " + what + " distribution is empty")
    var total = Float64(0.0)
    for i in range(len(probs)):
        var v = probs[i]
        if isnan(v) or isinf(v) or v < 0.0 or v > 1.0:
            raise Error(
                "SpeculativeSampling: "
                + what
                + " probability outside [0, 1]"
            )
        total += v
    if total < 0.999999 or total > 1.000001:
        raise Error(
            "SpeculativeSampling: "
            + what
            + " distribution does not sum to 1"
        )


def _validate_draw(u: Float64, what: String) raises:
    if isnan(u) or isinf(u) or u < 0.0 or u >= 1.0:
        raise Error(
            "SpeculativeSampling: " + what + " draw outside [0, 1)"
        )


def shape_distribution(
    logits: List[Float64],
    temperature: Float64,
    top_k: Int,
    top_p: Float64,
) raises -> List[Float64]:
    """Shape one logit vector into a distribution.

    The engine sampler's order (core/sampler.mojo):
    temperature, softmax, top-k, top-p, renormalising
    after each truncation. temperature == 0 is the greedy
    shape: the one-hot distribution at the argmax (lowest
    id on ties). top_k <= 0 or >= vocab disables top-k
    (the sampler's own no-op condition); top_p >= 1
    disables top-p. The result is indexed by token id.
    """
    var n = len(logits)
    if n == 0:
        raise Error("SpeculativeSampling: cannot shape an empty logit vector")
    for i in range(n):
        if isnan(logits[i]) or isinf(logits[i]):
            raise Error("SpeculativeSampling: logit is not finite")
    if isnan(temperature) or isinf(temperature) or temperature < 0.0:
        raise Error("SpeculativeSampling: temperature must be finite >= 0")
    if isnan(top_p) or isinf(top_p) or top_p <= 0.0 or top_p > 1.0:
        raise Error("SpeculativeSampling: top_p must be in (0, 1]")

    var probs = List[Float64]()
    if temperature == 0.0:
        var best = 0
        for i in range(1, n):
            if logits[i] > logits[best]:
                best = i
        for i in range(n):
            probs.append(1.0 if i == best else 0.0)
        return probs^

    # Temperature + softmax (max-subtracted).
    var max_z = logits[0] / temperature
    for i in range(1, n):
        var z = logits[i] / temperature
        if z > max_z:
            max_z = z
    var total = Float64(0.0)
    for i in range(n):
        var e = exp(logits[i] / temperature - max_z)
        probs.append(e)
        total += e
    for i in range(n):
        probs[i] /= total

    # Order: probability descending, token id ascending on
    # ties (deterministic; the sampler sorts candidates by
    # logit descending, and equal logits keep id order
    # under its insertion sort's strict comparison).
    var order = List[Int]()
    for i in range(n):
        order.append(i)
    for i in range(1, n):
        var key = order[i]
        var j = i - 1
        while j >= 0 and (
            probs[order[j]] < probs[key]
            or (probs[order[j]] == probs[key] and order[j] > key)
        ):
            order[j + 1] = order[j]
            j -= 1
        order[j + 1] = key

    # Top-k truncation + renormalisation.
    if top_k > 0 and top_k < n:
        var kept = List[Bool]()
        for _ in range(n):
            kept.append(False)
        for r in range(top_k):
            kept[order[r]] = True
        total = 0.0
        for i in range(n):
            if kept[i]:
                total += probs[i]
            else:
                probs[i] = 0.0
        for i in range(n):
            if kept[i]:
                probs[i] /= total

    # Top-p (nucleus) truncation + renormalisation: the
    # smallest highest-probability set whose cumulative
    # mass reaches top_p; at least the top token is kept.
    if top_p < 1.0:
        var kept2 = List[Bool]()
        for _ in range(n):
            kept2.append(False)
        var cum = Float64(0.0)
        for r in range(n):
            var idx = order[r]
            if probs[idx] <= 0.0:
                continue
            kept2[idx] = True
            cum += probs[idx]
            if cum >= top_p:
                break
        total = 0.0
        for i in range(n):
            if kept2[i]:
                total += probs[i]
            else:
                probs[i] = 0.0
        for i in range(n):
            if kept2[i]:
                probs[i] /= total

    return probs^


def acceptance_probability(p_x: Float64, q_x: Float64) raises -> Float64:
    """min(1, p/q) for one drafted token -- the same
    arithmetic core/speculative.mojo's evaluate_acceptance
    applies, stated over shaped distributions. A token the
    draft distribution cannot propose (q_x == 0) is refused
    by name: it can never be a draft token, so its
    acceptance is a question no honest caller can ask."""
    if isnan(p_x) or isinf(p_x) or p_x < 0.0 or p_x > 1.0:
        raise Error("SpeculativeSampling: target probability outside [0, 1]")
    if isnan(q_x) or isinf(q_x) or q_x <= 0.0 or q_x > 1.0:
        raise Error(
            "SpeculativeSampling: draft probability for a drafted token"
            " must be in (0, 1]"
        )
    var a = p_x / q_x
    if a > 1.0:
        a = 1.0
    return a


def residual_distribution(
    p: List[Float64], q: List[Float64]
) raises -> List[Float64]:
    """norm(max(0, p - q)): the rejection resample's
    distribution. Undefined when p == q (the residual mass
    is zero and the rejection path is unreachable -- the
    acceptance probability is 1 almost surely); that state
    is refused, never papered over with a fallback."""
    if len(p) != len(q):
        raise Error("SpeculativeSampling: residual needs equal-length p and q")
    _validate_distribution(p, "target")
    _validate_distribution(q, "draft")
    var out = List[Float64]()
    var total = Float64(0.0)
    for i in range(len(p)):
        var r = p[i] - q[i]
        if r < 0.0:
            r = 0.0
        out.append(r)
        total += r
    if total <= 1e-12:
        raise Error(
            "SpeculativeSampling: residual is undefined when the shaped"
            " target and draft distributions are identical"
        )
    for i in range(len(out)):
        out[i] /= total
    return out^


def draw_from_distribution(probs: List[Float64], u: Float64) raises -> Int:
    """Inverse-CDF draw: the first token whose cumulative
    mass strictly exceeds u. Zero-probability tokens are
    never returned (their cumulative step is empty); the
    final fallback is the last positive-mass token, for
    floating-point dust at the distribution's tail."""
    _validate_draw(u, "inverse-CDF")
    _validate_distribution(probs, "draw")
    var acc = Float64(0.0)
    var last_positive = -1
    for i in range(len(probs)):
        if probs[i] > 0.0:
            last_positive = i
        acc += probs[i]
        if u < acc:
            return i
    return last_positive


struct SampledPosition(Copyable, ImplicitlyCopyable):
    """One speculative-sampling position, fully derived."""

    var draft_token: Int
    var emitted_token: Int
    var accepted: Bool

    def __init__(out self, draft_token: Int, emitted_token: Int, accepted: Bool):
        self.draft_token = draft_token
        self.emitted_token = emitted_token
        self.accepted = accepted


def sample_position(
    p: List[Float64],
    q: List[Float64],
    u_draft: Float64,
    u_accept: Float64,
    u_residual: Float64,
) raises -> SampledPosition:
    """One position of the rule: draw the draft token from
    q, accept it with probability min(1, p/q), else emit a
    residual draw. All three draws are explicit (the caller
    owns the RNG stream, exactly as core/speculative.mojo's
    evaluate_acceptance takes its draws explicitly); the
    residual draw is consumed by the caller whether or not
    this position rejects, keeping seeded streams a
    function of (seed, case) alone."""
    if len(p) != len(q):
        raise Error("SpeculativeSampling: position needs equal-length p and q")
    _validate_distribution(p, "target")
    _validate_distribution(q, "draft")
    _validate_draw(u_draft, "draft")
    _validate_draw(u_accept, "acceptance")
    _validate_draw(u_residual, "residual")
    var x = draw_from_distribution(q, u_draft)
    var a = acceptance_probability(p[x], q[x])
    if u_accept < a:
        return SampledPosition(x, x, True)
    var res = residual_distribution(p, q)
    var y = draw_from_distribution(res, u_residual)
    return SampledPosition(x, y, False)


struct SampledRound(Copyable):
    """One sampled round, fully derived -- never asserted.

    emitted_tokens holds accepted_count draft tokens plus
    exactly one final token: the residual correction on a
    rejection, or the bonus token on full acceptance.
    """

    var k: Int
    var draft_tokens: List[Int]
    var emitted_tokens: List[Int]
    var accepted_count: Int
    var rejected_index: Int  # -1 iff the round fully accepted
    var used_bonus: Bool

    def __init__(out self):
        self.k = 0
        self.draft_tokens = List[Int]()
        self.emitted_tokens = List[Int]()
        self.accepted_count = 0
        self.rejected_index = -1
        self.used_bonus = False

    def __copyinit__(out self, existing: Self):
        self.k = existing.k
        self.draft_tokens = existing.draft_tokens.copy()
        self.emitted_tokens = existing.emitted_tokens.copy()
        self.accepted_count = existing.accepted_count
        self.rejected_index = existing.rejected_index
        self.used_bonus = existing.used_bonus


def run_sampled_round(
    vocab: Int,
    k: Int,
    p_flat: List[Float64],
    q_flat: List[Float64],
    draft_draws: List[Float64],
    accept_draws: List[Float64],
    final_draw: Float64,
) raises -> SampledRound:
    """One round over per-position SHAPED distributions.

    p_flat carries k+1 distributions of length vocab
    (positions 0..k; position k is the bonus position's
    target distribution); q_flat carries k distributions
    (positions 0..k-1). draft_draws / accept_draws carry
    one draw per drafted position; final_draw serves the
    round's single residual-or-bonus sample. The round
    emits accepted_count + 1 tokens, always.
    """
    if vocab <= 0:
        raise Error("SpeculativeSampling: round vocab must be positive")
    if k < SAMPLED_K_MIN or k > SAMPLED_K_MAX:
        raise Error("SpeculativeSampling: round k outside the J-071 band 1..15")
    if len(p_flat) != (k + 1) * vocab:
        raise Error("SpeculativeSampling: p_flat must hold (k+1) distributions")
    if len(q_flat) != k * vocab:
        raise Error("SpeculativeSampling: q_flat must hold k distributions")
    if len(draft_draws) != k or len(accept_draws) != k:
        raise Error("SpeculativeSampling: one draft and acceptance draw per position")
    _validate_draw(final_draw, "final")

    var round = SampledRound()
    round.k = k
    for i in range(k):
        var p_i = List[Float64]()
        var q_i = List[Float64]()
        for v in range(vocab):
            p_i.append(p_flat[i * vocab + v])
            q_i.append(q_flat[i * vocab + v])
        var pos = sample_position(
            p_i, q_i, draft_draws[i], accept_draws[i], final_draw
        )
        round.draft_tokens.append(pos.draft_token)
        if not pos.accepted:
            round.emitted_tokens.append(pos.emitted_token)
            round.accepted_count = i
            round.rejected_index = i
            round.used_bonus = False
            return round^
        round.emitted_tokens.append(pos.emitted_token)
    # Full acceptance: the bonus token from position k's
    # target distribution.
    var p_k = List[Float64]()
    for v in range(vocab):
        p_k.append(p_flat[k * vocab + v])
    _validate_distribution(p_k, "bonus target")
    var bonus = draw_from_distribution(p_k, final_draw)
    round.emitted_tokens.append(bonus)
    round.accepted_count = k
    round.rejected_index = -1
    round.used_bonus = True
    return round^


def chi_square_statistic(
    observed: List[Int], expected_probs: List[Float64]
) raises -> Float64:
    """Pearson chi-square of observed counts against an
    expected distribution. Returns CHI_SQUARE_ZERO_BIN
    (-1.0) iff any count sits in a zero-probability bin --
    the automatic-FAIL state of the verdict rule, reported
    as a sentinel so it can never be misread as a passing
    small statistic."""
    if len(observed) != len(expected_probs) or len(observed) == 0:
        raise Error("SpeculativeSampling: chi-square needs matched non-empty bins")
    _validate_distribution(expected_probs, "expected")
    var n = 0
    for i in range(len(observed)):
        if observed[i] < 0:
            raise Error("SpeculativeSampling: observed count is negative")
        n += observed[i]
    if n <= 0:
        raise Error("SpeculativeSampling: chi-square needs at least one sample")
    var stat = Float64(0.0)
    for i in range(len(observed)):
        if expected_probs[i] == 0.0:
            if observed[i] > 0:
                return CHI_SQUARE_ZERO_BIN
            continue
        var e = Float64(n) * expected_probs[i]
        var d = Float64(observed[i]) - e
        stat += d * d / e
    return stat


def chi_square_critical_001(df: Int) raises -> Float64:
    """The alpha = 0.001 chi-square critical values the
    verdict rule pre-registers, df 1..10. Anything outside
    that range is refused, never extrapolated."""
    if df == 1:
        return 10.828
    if df == 2:
        return 13.816
    if df == 3:
        return 16.266
    if df == 4:
        return 18.467
    if df == 5:
        return 20.515
    if df == 6:
        return 22.458
    if df == 7:
        return 24.322
    if df == 8:
        return 26.124
    if df == 9:
        return 27.877
    if df == 10:
        return 29.588
    raise Error("SpeculativeSampling: no pre-registered critical value for this df")


def support_df(probs: List[Float64]) raises -> Int:
    """Degrees of freedom of a chi-square against this
    distribution: positive-mass bins minus one."""
    _validate_distribution(probs, "support")
    var support = 0
    for i in range(len(probs)):
        if probs[i] > 0.0:
            support += 1
    if support < 2:
        raise Error("SpeculativeSampling: chi-square needs support >= 2")
    return support - 1
