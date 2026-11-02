"""Speculative verification account (Janas road J-071).

The roadmap text: "Verification-first design. Speculative
decoding in Aesir's terms: the verify pass as a Part III
draft-check pass; the invariant that output distribution is
the target model's own (greedy output must be token-identical
to non-speculative greedy -- the slice that proves the
machinery can never change the text)."

THE DESIGN, stated before any building (the slice doc,
docs/janas/J071_VERIFICATION_FIRST_DESIGN.md section 1, is
its normative text). Speculation in Aesir is a DRAFT-CHECK
pass in J-035's taxonomy: role = verify a proposed token
sequence against the target model in one batch; design band
width 2..16 (J-035, adopted from Janas's documented band).
One round of the J-072 draft loop, in this account's terms:

- A PROPOSER offers k draft tokens (k >= 1) for the positions
  after the committed prefix. Proposers never emit text.
- The VERIFY PASS forwards k+1 inputs in one batch -- the
  pending emitted token plus the k drafts, under the tree's
  feed-the-emitted-token convention (MoE step() forwards a
  token at self.position, then position += 1) -- and the
  TARGET model produces its own greedy choice at each of the
  k+1 positions: target_greedy[0..k]. The pass width is
  therefore k+1, so the band binds k to 1..15.
- ACCEPTANCE (greedy form): the longest prefix a such that
  draft[i] == target_greedy[i] for every i < a. The round
  EMITS a+1 tokens, and every emitted token is taken from
  the TARGET's list, never from the draft: emitted[i] =
  target_greedy[i] for i <= a. Where the prefix runs the
  full k, target_greedy[k] is the bonus token; where it
  stops early, target_greedy[a] is the correction token.
  Draft tokens past the first mismatch are never emitted,
  even where a later draft coincidentally equals a later
  target choice -- acceptance is a prefix, not a filter.
- THE INVARIANT, by construction: a plain greedy round emits
  exactly target_greedy[0] and advances one position. A
  speculative round emits target_greedy[0..a] and advances
  a+1 positions, landing in exactly the state the plain loop
  reaches after a+1 of its own rounds over the same choices
  (the verify pass's later choices are computed on contexts
  the plain loop would also build, because each accepted
  draft equals the target choice that precedes it). By
  induction over rounds, speculative greedy output is
  token-identical to non-speculative greedy output -- not
  because drafts are usually right, but because the emitted
  stream is BUILT from the target's choices only. A bad
  proposer costs speed, never text. This is the greedy form
  of the invariant; the sampled form (temperature / top-k /
  top-p with the rejection correction) is J-082's account,
  built on core/speculative.mojo's existing min(1, p/q)
  arithmetic, and is NOT claimed here.
- ROLLBACK, exact: the pass tentatively writes k+1 KV rows;
  the round commits kv_before + a + 1 and discards
  (k + 1) - (a + 1) = k - a rows. In this tree's KVCache
  (fixed-capacity contiguous positions, append by explicit
  position, reads bounded by active length) discarding is a
  LENGTH restore, not a byte clear: rows past the restored
  length are never read and are overwritten by the next
  append at that position. Sampler state restores with it:
  the context-token count returns to (context_before + a + 1)
  and the RNG state word is UNCHANGED -- a greedy verify
  round consumes zero RNG draws (the sampler's greedy branch
  returns before any RNG use), and this account refuses a
  greedy round that reports a draw.

PROPOSERS (J-072's interface contract). The census (J-006)
documents four draft sources; the J-014 gate adjustment
gives J-072's loop THREE proposer slots, and this account
reconciles the two: the head slot is filled by either of
the two --mtp-file forms.

- SLOT_HEAD: an MTP prediction head of the target itself
  (PROPOSER_MTP_HEAD: shares the target's forward state and
  tokenizer by construction, carries no KV of its own), or
  an assistant drafter model of the target's family
  (PROPOSER_ASSISTANT_MODEL: reads the target's KV per the
  census; tokenizer match required and verified, J-074).
- SLOT_CROSS_MODEL: a separate small model drafting for a
  large one (PROPOSER_CROSS_MODEL: carries its own KV;
  tokenizer identity required and verified, J-074).
- SLOT_CONVERSATION: guesses copied from the conversation
  itself (PROPOSER_CONVERSATION: no model, no KV, tokenizer
  trivially the session's own).
A proposer is described to the loop only by its ProposerShape
(kind, slot, tokenizer-match requirement, own-KV flag, k cap).
The loop never asks a proposer for probabilities in the
greedy form, and no proposer output reaches the emitted
stream except through plan_verify's target-built emission.

PLACEMENT: the verify pass IS a draft-check pass, so it is
placed by Part III's engine exactly as one: --drafts-on
(J-036, stored today behind require_draft_check_use()'s
fail-closed gate, which names this slice and J-072), chosen
by core/draft_placement.mojo (J-042) once a real executor
exists for J-038/J-039 to measure. This account changes no
gate: J-072 replaces the refusal with real consumption when
it builds the loop, and only then.

WHAT THE ACCOUNT DECIDES, AND WHAT IT REFUSES TO DECIDE
(the verdict rule, pre-registered in the doc section 1):

- PERMITTED BY ACCOUNT (construction alone): the greedy
  identity claim for any round sequence whose every round
  is a complete, consistent plan_verify account -- the
  emission is target-built by construction, so the identity
  needs no measurement luck.
- REQUIRES LIVE: a live token-identity claim (speculative
  vs plain greedy ids from a real model run) until the ids
  are filed and compared by this account's checker (J-073
  owns the arch-matrix proof; the J-086 gate re-runs it);
  any speed / tok/s / acceptance-rate claim, always --
  accounting contains no speed and no acceptance statistic.
- REFUSED outright: an identity claim grounded on an
  incomplete or inconsistent account (a round whose target
  list is not exactly k+1, a width outside the draft-check
  band, a pass that cannot fit the KV capacity, a greedy
  round that consumed an RNG draw); a live identity claim
  whose filed ids diverge.

This module is pure arithmetic in the J-066..J-069 pattern:
it executes no forward, times nothing, opens no device, and
contains no speed. No existing module is changed by this
slice except a comment-only host contract in aesir.mojo.

HOST CONTRACT (for J-072's loop, binding): (1) snapshot the
session's committed KV length, context-token count, and RNG
state word before proposing; (2) obtain k drafts from one
proposer slot (1 <= k <= 15, and k <= the proposer's cap);
(3) run ONE draft-check pass of width k+1 and record the
target's greedy choice at every position -- the target
choices come from the pass, never from the proposer;
(4) derive the round through plan_verify and emit exactly
account.emitted_tokens; (5) restore KV length and context
count to the account's restore points (rows past the length
are dead by the read bound) and assert the RNG word is the
snapshot's; (6) file the round's account with the run's
evidence, so J-073's identity proof and J-075's acceptance
instrumentation read accounts, not reconstructions.
"""

# Proposer kinds (the census's four documented draft sources).
comptime PROPOSER_MTP_HEAD = 0
comptime PROPOSER_ASSISTANT_MODEL = 1
comptime PROPOSER_CROSS_MODEL = 2
comptime PROPOSER_CONVERSATION = 3

# Proposer slots (J-072's three loop slots, per the J-014
# gate adjustment: three proposers including conversation).
comptime SLOT_HEAD = 0
comptime SLOT_CROSS_MODEL = 1
comptime SLOT_CONVERSATION = 2

# Claim kinds for evaluate_spec_claim.
comptime CLAIM_GREEDY_IDENTITY_BY_CONSTRUCTION = 0
comptime CLAIM_LIVE_TOKEN_IDENTITY = 1
comptime CLAIM_SPEED_GAIN = 2

# Claim verdicts (the J-067/J-069 claim-verdict vocabulary).
comptime SPEC_CLAIM_PERMITTED = 0
comptime SPEC_CLAIM_REQUIRES_LIVE = 1
comptime SPEC_CLAIM_REFUSED = 2

# The draft-check design band (J-035): pass width 2..16.
comptime DRAFT_CHECK_MIN_WIDTH = 2
comptime DRAFT_CHECK_MAX_WIDTH = 16


def proposer_kind_name(code: Int) raises -> String:
    if code == PROPOSER_MTP_HEAD:
        return String("mtp_head")
    if code == PROPOSER_ASSISTANT_MODEL:
        return String("assistant_model")
    if code == PROPOSER_CROSS_MODEL:
        return String("cross_model")
    if code == PROPOSER_CONVERSATION:
        return String("conversation")
    raise Error("SpeculativeVerify: unknown proposer kind code")


def proposer_slot_name(code: Int) raises -> String:
    if code == SLOT_HEAD:
        return String("head")
    if code == SLOT_CROSS_MODEL:
        return String("cross_model")
    if code == SLOT_CONVERSATION:
        return String("conversation")
    raise Error("SpeculativeVerify: unknown proposer slot code")


def claim_name(code: Int) raises -> String:
    if code == SPEC_CLAIM_PERMITTED:
        return String("PERMITTED")
    if code == SPEC_CLAIM_REQUIRES_LIVE:
        return String("REQUIRES_LIVE")
    if code == SPEC_CLAIM_REFUSED:
        return String("REFUSED")
    raise Error("SpeculativeVerify: unknown claim code")


struct ProposerShape(Copyable, ImplicitlyCopyable):
    """One proposer's contract with the J-072 loop.

    A proposer offers tokens only. Whether its tokenizer must
    be verified against the target's, whether it carries a KV
    of its own (state J-072 must snapshot beside the target's),
    and the deepest k it may offer are stated here so the loop
    binds to shapes, never to a proposer's internals.
    """

    var kind: Int
    var slot: Int
    var requires_tokenizer_match: Bool
    var carries_own_kv: Bool
    var max_k: Int

    def __init__(
        out self,
        kind: Int,
        slot: Int,
        requires_tokenizer_match: Bool,
        carries_own_kv: Bool,
        max_k: Int,
    ):
        self.kind = kind
        self.slot = slot
        self.requires_tokenizer_match = requires_tokenizer_match
        self.carries_own_kv = carries_own_kv
        self.max_k = max_k


def plan_proposer(kind: Int) raises -> ProposerShape:
    """The design's stated shape for each documented proposer.

    max_k is the band cap (15) for model proposers; the
    conversation proposer is capped at 8 -- its guesses are
    copied text with the census's lowest documented hit
    character (~1/4), and a deeper conversation draft only
    widens the verify pass it usually wastes. Unknown kinds
    are refused, never defaulted.
    """
    if kind == PROPOSER_MTP_HEAD:
        return ProposerShape(kind, SLOT_HEAD, False, False, 15)
    if kind == PROPOSER_ASSISTANT_MODEL:
        return ProposerShape(kind, SLOT_HEAD, True, False, 15)
    if kind == PROPOSER_CROSS_MODEL:
        return ProposerShape(kind, SLOT_CROSS_MODEL, True, True, 15)
    if kind == PROPOSER_CONVERSATION:
        return ProposerShape(kind, SLOT_CONVERSATION, False, False, 8)
    raise Error("SpeculativeVerify: unknown proposer kind")


struct VerifyAccount(Copyable):
    """One greedy verify round, fully derived -- never asserted.

    Every field is computed by plan_verify from the draft list
    and the target's own greedy list. emitted_tokens is built
    from the target list only; the draft list decides how much
    of the pass's work is kept, never what the text is.
    """

    var proposer_kind: Int
    var k: Int
    var verify_width: Int
    var accepted_count: Int
    var first_mismatch_index: Int
    var emitted_tokens: List[Int]
    var kv_before: Int
    var kv_after: Int
    var kv_rows_to_roll_back: Int
    var context_before: Int
    var context_after: Int
    var rng_draws_consumed: Int

    def __init__(out self):
        self.proposer_kind = -1
        self.k = 0
        self.verify_width = 0
        self.accepted_count = 0
        self.first_mismatch_index = -1
        self.emitted_tokens = List[Int]()
        self.kv_before = 0
        self.kv_after = 0
        self.kv_rows_to_roll_back = 0
        self.context_before = 0
        self.context_after = 0
        self.rng_draws_consumed = 0

    def __copyinit__(out self, existing: Self):
        self.proposer_kind = existing.proposer_kind
        self.k = existing.k
        self.verify_width = existing.verify_width
        self.accepted_count = existing.accepted_count
        self.first_mismatch_index = existing.first_mismatch_index
        self.emitted_tokens = existing.emitted_tokens.copy()
        self.kv_before = existing.kv_before
        self.kv_after = existing.kv_after
        self.kv_rows_to_roll_back = existing.kv_rows_to_roll_back
        self.context_before = existing.context_before
        self.context_after = existing.context_after
        self.rng_draws_consumed = existing.rng_draws_consumed

    def all_accepted(self) -> Bool:
        """True when the whole draft prefix held (bonus round)."""
        return self.first_mismatch_index == -1

    def emitted_count(self) -> Int:
        """Tokens this round emits: always accepted + 1."""
        return len(self.emitted_tokens)


def plan_verify(
    proposer_kind: Int,
    draft_tokens: List[Int],
    target_greedy_tokens: List[Int],
    kv_before: Int,
    kv_capacity: Int,
    context_before: Int,
    rng_draws_consumed: Int,
) raises -> VerifyAccount:
    """Derive one greedy verify round from its two token lists.

    draft_tokens: the proposer's k tokens. target_greedy_tokens:
    the TARGET's greedy choice at each of the pass's k+1
    positions, from the verify pass itself -- never from the
    proposer. Refusals: unknown proposer kind; k outside
    1..15 (the pass width k+1 must sit in the draft-check
    design band 2..16); k above the proposer's cap; a target
    list not exactly k+1 long; any negative token id; a
    negative committed length or context; a pass that cannot
    fit the KV capacity (kv_before + k + 1 > kv_capacity --
    the host shortens k, J-079's business, rather than this
    account silently truncating); any RNG draw reported for
    a greedy round (greedy consumes none by construction --
    a draw means the round was not the greedy round claimed).
    """
    var shape = plan_proposer(proposer_kind)
    var k = len(draft_tokens)
    if k < 1:
        raise Error("SpeculativeVerify: a round proposes at least one draft token")
    if k > DRAFT_CHECK_MAX_WIDTH - 1:
        raise Error(
            "SpeculativeVerify: verify width k+1 must sit in the draft-check"
            " design band 2..16 (J-035); shorten k"
        )
    if k > shape.max_k:
        raise Error(
            "SpeculativeVerify: k exceeds this proposer's stated cap; shorten k"
        )
    if len(target_greedy_tokens) != k + 1:
        raise Error(
            "SpeculativeVerify: the target list must hold exactly k+1 greedy"
            " choices, one per verify-pass position"
        )
    for i in range(k):
        if draft_tokens[i] < 0:
            raise Error("SpeculativeVerify: draft token IDs must be non-negative")
    for i in range(k + 1):
        if target_greedy_tokens[i] < 0:
            raise Error("SpeculativeVerify: target token IDs must be non-negative")
    if kv_before < 0 or kv_capacity < 0 or context_before < 0:
        raise Error("SpeculativeVerify: lengths and context must be non-negative")
    if kv_before + k + 1 > kv_capacity:
        raise Error(
            "SpeculativeVerify: the verify pass cannot fit the KV capacity;"
            " shorten k rather than truncate the pass"
        )
    if rng_draws_consumed != 0:
        raise Error(
            "SpeculativeVerify: a greedy verify round consumes no RNG draws;"
            " a reported draw means the round was not greedy"
        )

    var accepted = 0
    var mismatch = -1
    for i in range(k):
        if draft_tokens[i] == target_greedy_tokens[i]:
            accepted += 1
        else:
            mismatch = i
            break

    var account = VerifyAccount()
    account.proposer_kind = proposer_kind
    account.k = k
    account.verify_width = k + 1
    account.accepted_count = accepted
    account.first_mismatch_index = mismatch
    # Emission is built from the TARGET list only: the accepted
    # prefix (where draft == target, so either list would read
    # the same -- the target's is used by rule) plus exactly one
    # further target choice: the correction at the mismatch, or
    # the bonus when the prefix ran whole.
    for i in range(accepted + 1):
        account.emitted_tokens.append(target_greedy_tokens[i])
    account.kv_before = kv_before
    account.kv_after = kv_before + accepted + 1
    account.kv_rows_to_roll_back = k - accepted
    account.context_before = context_before
    account.context_after = context_before + accepted + 1
    account.rng_draws_consumed = rng_draws_consumed
    return account^


def account_is_consistent(account: VerifyAccount) raises -> Bool:
    """Mechanical completeness check for a filed round account.

    True only when every derived relation holds: width in the
    band and equal to k+1, accepted a prefix count within the
    draft, emitted exactly accepted+1 tokens, KV and context
    advancing by exactly the emitted count, rollback exactly
    the uncommitted remainder, and no RNG draw. An account
    that fails this check grounds no identity claim (see
    evaluate_spec_claim) -- it is restated or the run is.
    """
    var shape = plan_proposer(account.proposer_kind)
    if account.k < 1 or account.k > shape.max_k:
        return False
    if account.verify_width != account.k + 1:
        return False
    if account.verify_width < DRAFT_CHECK_MIN_WIDTH:
        return False
    if account.verify_width > DRAFT_CHECK_MAX_WIDTH:
        return False
    if account.accepted_count < 0 or account.accepted_count > account.k:
        return False
    if account.all_accepted() != (account.accepted_count == account.k):
        return False
    if len(account.emitted_tokens) != account.accepted_count + 1:
        return False
    if account.kv_after != account.kv_before + account.accepted_count + 1:
        return False
    if account.kv_rows_to_roll_back != account.k - account.accepted_count:
        return False
    if account.context_after != account.context_before + account.accepted_count + 1:
        return False
    if account.rng_draws_consumed != 0:
        return False
    for i in range(len(account.emitted_tokens)):
        if account.emitted_tokens[i] < 0:
            return False
    return True


def identity_first_divergence(
    speculative_tokens: List[Int], plain_tokens: List[Int]
) -> Int:
    """First index where two token streams differ, or -1.

    The mechanical checker for the identity invariant: -1
    means identical (same length, every token equal). A
    length difference with an equal shared prefix diverges
    at the shorter length. Empty vs empty is identical.
    """
    var shared = len(speculative_tokens)
    if len(plain_tokens) < shared:
        shared = len(plain_tokens)
    for i in range(shared):
        if speculative_tokens[i] != plain_tokens[i]:
            return i
    if len(speculative_tokens) != len(plain_tokens):
        return shared
    return -1


def sequences_identical(
    speculative_tokens: List[Int], plain_tokens: List[Int]
) -> Bool:
    """True iff the two streams are token-for-token identical."""
    return identity_first_divergence(speculative_tokens, plain_tokens) == -1


def evaluate_spec_claim(
    claim_kind: Int,
    account_consistent: Bool,
    live_ids_filed: Bool,
    live_ids_identical: Bool,
    live_speed_measured: Bool,
) raises -> Int:
    """The pre-registered verdict rule (doc section 1).

    - CLAIM_GREEDY_IDENTITY_BY_CONSTRUCTION: PERMITTED when
      every round's account is complete and consistent (the
      emission is target-built, so identity holds by
      construction); REFUSED on an incomplete or inconsistent
      account -- construction claims rest on the account, and
      a broken account is a broken claim.
    - CLAIM_LIVE_TOKEN_IDENTITY: REQUIRES_LIVE until a real
      run's speculative and plain greedy ids are filed;
      PERMITTED when the filed ids are identical under
      identity_first_divergence; REFUSED when they diverge.
    - CLAIM_SPEED_GAIN (any tok/s or wall claim for drafts):
      REQUIRES_LIVE until a live measurement on named
      hardware grounds it; accounting permits no speed claim.
    """
    if claim_kind == CLAIM_GREEDY_IDENTITY_BY_CONSTRUCTION:
        if account_consistent:
            return SPEC_CLAIM_PERMITTED
        return SPEC_CLAIM_REFUSED
    if claim_kind == CLAIM_LIVE_TOKEN_IDENTITY:
        if not live_ids_filed:
            return SPEC_CLAIM_REQUIRES_LIVE
        if live_ids_identical:
            return SPEC_CLAIM_PERMITTED
        return SPEC_CLAIM_REFUSED
    if claim_kind == CLAIM_SPEED_GAIN:
        if live_speed_measured:
            return SPEC_CLAIM_PERMITTED
        return SPEC_CLAIM_REQUIRES_LIVE
    raise Error("SpeculativeVerify: unknown claim kind")
