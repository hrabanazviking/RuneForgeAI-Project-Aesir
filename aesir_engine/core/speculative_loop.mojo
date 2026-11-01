"""Speculative draft loop (Janas road J-072).

The roadmap text: "The draft loop. Propose k, verify in one
pass, accept the longest true prefix + one; rollback of KV
and sampler state exact; k adaptive bounds stated."

This module builds the loop J-071's account
(core/speculative_verify.mojo) specified, in the same pure
pattern: it executes no forward, times nothing, opens no
device, and contains no speed and no acceptance statistic.
A live host supplies, per round, one proposer's draft list
and the target's own greedy list from ONE draft-check pass;
this module owns everything around those lists:

- PROPOSER-SLOT DISPATCH (J-014 gate adjustment A3): the
  loop takes THREE slots -- SLOT_HEAD (an MTP head or an
  assistant model), SLOT_CROSS_MODEL, SLOT_CONVERSATION --
  and dispatch_proposer() refuses any kind filed under the
  wrong slot, so a round can never silently run a proposer
  shape the account did not state.
- ONE ROUND (run_loop_round), following J-071's host
  contract steps (1)-(6) exactly: snapshot the committed KV
  length, the context-token count, the RNG state word, and
  the proposer's own KV length (where it carries one);
  derive the round through plan_verify (which enforces the
  band, the proposer caps, the KV-capacity fit, and the
  greedy round's zero-RNG-draw invariant); tentatively
  advance by the full pass width k+1; then roll back
  exactly k - accepted rows, so the committed lengths land
  at snapshot + accepted + 1 for KV and context alike, the
  proposer's own KV lands at snapshot + accepted (its
  unaccepted drafts are discarded with the target's), and
  the RNG word is asserted EQUAL to the snapshot -- a
  greedy round consumes no draw, so sampler state after a
  round is the snapshot's state, not a reconstruction.
  Emission is appended from the account only, and the
  account is built from the target's list only (J-071):
  the loop therefore cannot change the text, only keep or
  discard pass work.
- k BOUNDS AND THE ADAPTIVE SHAPE (bounds stated here;
  measured tuning is J-079 and is NOT built): k_min = 1;
  k_initial = 4; the effective cap is the proposer's own
  cap from plan_proposer (15 for model proposers -- the
  J-035 draft-check band 2..16 binds the pass width k+1 --
  and 8 for the conversation proposer). plan_round_k()
  applies the KV-capacity bound BEFORE proposing: the
  deepest k that fits is capacity - kv_before - 1; a
  requested k deeper than that is SHORTENED explicitly --
  the plan records requested vs planned and the shortening
  flag, so the host proposes the planned depth and no pass
  is ever silently truncated (plan_verify still refuses a
  pass that cannot fit, as the backstop). Where not even
  k=1 fits, the plan refuses: the host ends the generation
  or waits for capacity; it does not speculate past the
  cache. suggest_next_k() states the adaptation rule's
  SHAPE only: deepen by one after a fully accepted round
  (bounded by the cap), halve (floor 1) after a round that
  accepted nothing, hold otherwise. It is a pure function
  of the last round's account; nothing here measures
  whether the shape pays -- that measurement, and any live
  tuning built on it, is J-079.
- MULTI-ROUND DRIVING (run_loop): rounds chained over one
  LoopState, each round's target list sliced from the
  stated plain-greedy continuation (the account-level
  premise J-071 section 5 stated: in a live host those
  lists come from the verify passes themselves). The
  driver refuses a flat encoding that runs out of drafts
  or target tokens mid-round, and at the end asserts the
  concatenated emission is token-identical to the plain
  continuation under J-071's checker -- a divergence is
  raised, never filed as a result.

LEGACY BOUND RECONCILIATION (J-071 section 6's named item,
decided here): core/speculative.mojo's SpeculativeEngine
carried a draft bound of default 4, hard limit 64 -- an
older bound from before Part III's taxonomy existed. The
verify pass is a draft-check pass, so the band governs
every draft count that can ever reach one: the legacy
module's hard limit is aligned to 15 in this slice (its
evaluate_acceptance now refuses counts above 15), and its
default 4 is retained as this loop's k_initial -- the
depth a session starts at before any adaptation. The 64
survives nowhere as a verify width; quoting it as one was
the discrepancy J-071 named, and it is closed.

WHAT IS NOT WIRED, stated plainly: no session in this tree
runs this loop. No proposer implementation exists (no MTP
head has been read from any file -- J-076/J-077; no
assistant or cross-model pairing has run -- J-074/J-078;
no conversation proposer is built), no verify-pass executor
exists for a session to call, the MoE and dense sessions
carry no loop state, require_draft_check_use() still fails
closed, and the engine facade's speculative_generate still
raises not-implemented. Wiring the loop into a session
without an executor and proposers would fake an integration
that cannot run; the honest wiring is this tested module
plus the host contract below, and the first live wiring
belongs with the slices that build the executors and
proposers it consumes. Live token-identity over real
generations is J-073's proof and is NOT PROVEN here.

HOST CONTRACT (binding on the first live host): (1) build
one LoopState at generation start from the session's
committed KV length, context count, RNG word, KV capacity,
and the proposer's KV length (0 when it carries none);
(2) per round, plan k with plan_round_k and propose exactly
the planned depth from the dispatched slot's proposer;
(3) run ONE draft-check pass of width k+1 and record the
target's greedy choice at every position; (4) call
run_loop_round with those two lists and emit exactly the
state\'s appended tokens; (5) file every round's account
with the run's evidence (J-073/J-075 read accounts, not
reconstructions); (6) adapt k only through suggest_next_k's
stated bounds until J-079 measures the tuning.
"""

from core.speculative_verify import (
    DRAFT_CHECK_MAX_WIDTH,
    PROPOSER_ASSISTANT_MODEL,
    PROPOSER_CONVERSATION,
    PROPOSER_CROSS_MODEL,
    PROPOSER_MTP_HEAD,
    SLOT_CONVERSATION,
    SLOT_CROSS_MODEL,
    SLOT_HEAD,
    ProposerShape,
    VerifyAccount,
    account_is_consistent,
    plan_proposer,
    plan_verify,
    sequences_identical,
)

# The loop's k bounds (stated; see the header). k_initial is
# the legacy speculative module's default 4, retained.
comptime LOOP_K_MIN = 1
comptime LOOP_K_INITIAL = 4
comptime LOOP_K_MAX_MODEL = 15
comptime LOOP_K_MAX_CONVERSATION = 8


def dispatch_proposer(slot: Int, kind: Int) raises -> ProposerShape:
    """The shape for a kind, checked against its slot.

    The J-014 gate gives the loop three slots; each of the
    census's four proposer kinds belongs to exactly one.
    A kind filed under the wrong slot is refused, never
    re-filed silently: the round's account names the kind,
    and J-075's instrumentation reads accounts by slot.
    """
    var shape = plan_proposer(kind)
    if shape.slot != slot:
        raise Error(
            "SpeculativeLoop: proposer kind does not belong to the"
            " requested slot; dispatch refused"
        )
    return shape


struct KPlan(Copyable, ImplicitlyCopyable):
    """One round's planned depth, derived before proposing.

    requested_k is what the host asked for; planned_k is
    what it may propose. shortened_for_capacity is True
    exactly when the KV capacity bound -- not the proposer
    cap, not the band -- cut the depth. The shortening is
    a recorded plan fact, never a silent truncation: the
    host proposes planned_k drafts, and plan_verify remains
    the backstop that refuses any pass that cannot fit.
    """

    var requested_k: Int
    var planned_k: Int
    var cap_k: Int
    var fit_k: Int
    var shortened_for_capacity: Bool

    def __init__(
        out self,
        requested_k: Int,
        planned_k: Int,
        cap_k: Int,
        fit_k: Int,
        shortened_for_capacity: Bool,
    ):
        self.requested_k = requested_k
        self.planned_k = planned_k
        self.cap_k = cap_k
        self.fit_k = fit_k
        self.shortened_for_capacity = shortened_for_capacity


def plan_round_k(
    kind: Int, requested_k: Int, kv_before: Int, kv_capacity: Int
) raises -> KPlan:
    """Plan one round's k under every bound, in order.

    Refusals: unknown kind; requested k below 1; requested
    k above the band (k+1 would leave width 2..16) or above
    the proposer's cap -- caps are contracts, and a host
    that wants more depth changes proposer, it does not
    overrun one; negative lengths; and a KV capacity that
    cannot fit even k=1 (kv_before + 2 > kv_capacity).
    Otherwise planned_k = min(requested, fit) with the
    shortening recorded on the plan.
    """
    var shape = plan_proposer(kind)
    if requested_k < LOOP_K_MIN:
        raise Error("SpeculativeLoop: a round proposes at least one draft token")
    if requested_k > DRAFT_CHECK_MAX_WIDTH - 1:
        raise Error(
            "SpeculativeLoop: verify width k+1 must sit in the draft-check"
            " design band 2..16 (J-035); shorten k"
        )
    if requested_k > shape.max_k:
        raise Error(
            "SpeculativeLoop: k exceeds this proposer's stated cap; shorten k"
        )
    if kv_before < 0 or kv_capacity < 0:
        raise Error("SpeculativeLoop: lengths must be non-negative")
    var fit_k = kv_capacity - kv_before - 1
    if fit_k < LOOP_K_MIN:
        raise Error(
            "SpeculativeLoop: the KV capacity cannot fit even a width-2"
            " verify pass; the host ends or waits, it does not speculate"
            " past the cache"
        )
    var planned = requested_k
    if fit_k < planned:
        planned = fit_k
    return KPlan(requested_k, planned, shape.max_k, fit_k, planned < requested_k)


def suggest_next_k(kind: Int, current_k: Int, accepted_count: Int) raises -> Int:
    """The adaptation rule's SHAPE (stated, unmeasured).

    Deepen by one after a fully accepted round, halve
    (floor LOOP_K_MIN) after a round that accepted nothing,
    hold otherwise; the result is always inside
    [LOOP_K_MIN, the proposer's cap]. Whether this shape
    pays, and any tuning of its steps, is J-079's measured
    business -- this function claims no acceptance rate and
    no speed.
    """
    var shape = plan_proposer(kind)
    if current_k < LOOP_K_MIN or current_k > shape.max_k:
        raise Error("SpeculativeLoop: current k outside this proposer's bounds")
    if accepted_count < 0 or accepted_count > current_k:
        raise Error("SpeculativeLoop: accepted count outside the round's draft")
    var nxt = current_k
    if accepted_count == current_k:
        nxt = current_k + 1
    elif accepted_count == 0:
        nxt = current_k // 2
    if nxt < LOOP_K_MIN:
        nxt = LOOP_K_MIN
    if nxt > shape.max_k:
        nxt = shape.max_k
    return nxt


struct LoopSnapshot(Copyable, ImplicitlyCopyable):
    """The committed state a round starts from (contract 1).

    The RNG word is carried whole (RuneRNG's state is one
    UInt64 word, J-071 section 2), so the round's restore
    assertion is a word equality, not a reconstruction.
    """

    var kv_length: Int
    var context_count: Int
    var rng_word: UInt64
    var draft_kv_length: Int

    def __init__(
        out self,
        kv_length: Int,
        context_count: Int,
        rng_word: UInt64,
        draft_kv_length: Int,
    ):
        self.kv_length = kv_length
        self.context_count = context_count
        self.rng_word = rng_word
        self.draft_kv_length = draft_kv_length


struct LoopState(Copyable):
    """The loop's session-side state, advanced round by round.

    kv_length / context_count are the TARGET session's
    committed lengths; draft_kv_length is the proposer's
    own committed KV length (meaningful only when its shape
    carries one; held at the host's stated value otherwise
    and asserted untouched by rounds whose proposer carries
    none). emitted accumulates the run's output -- appended
    from round accounts only, never from a draft list.
    """

    var kv_capacity: Int
    var kv_length: Int
    var context_count: Int
    var rng_word: UInt64
    var draft_kv_length: Int
    var emitted: List[Int]

    def __init__(
        out self,
        kv_capacity: Int,
        kv_length: Int,
        context_count: Int,
        rng_word: UInt64,
        draft_kv_length: Int,
    ):
        self.kv_capacity = kv_capacity
        self.kv_length = kv_length
        self.context_count = context_count
        self.rng_word = rng_word
        self.draft_kv_length = draft_kv_length
        self.emitted = List[Int]()

    def __copyinit__(out self, existing: Self):
        self.kv_capacity = existing.kv_capacity
        self.kv_length = existing.kv_length
        self.context_count = existing.context_count
        self.rng_word = existing.rng_word
        self.draft_kv_length = existing.draft_kv_length
        self.emitted = existing.emitted.copy()

    def copy(self) -> Self:
        var copied = Self(
            self.kv_capacity,
            self.kv_length,
            self.context_count,
            self.rng_word,
            self.draft_kv_length,
        )
        copied.emitted = self.emitted.copy()
        return copied^

    def snapshot(self) -> LoopSnapshot:
        return LoopSnapshot(
            self.kv_length, self.context_count, self.rng_word, self.draft_kv_length
        )


def run_loop_round(
    mut state: LoopState,
    slot: Int,
    kind: Int,
    draft_tokens: List[Int],
    target_greedy_tokens: List[Int],
    rng_draws_consumed: Int,
) raises -> VerifyAccount:
    """Run one draft-loop round over J-071's account.

    Snapshot -> plan_verify -> tentative advance by the
    full pass width -> exact rollback of the uncommitted
    rows -> assertions against the snapshot -> commit and
    append the account's emission. Any refusal from
    plan_verify (band, cap, capacity fit, a reported RNG
    draw, a malformed list) propagates BEFORE any state is
    touched, so a refused round leaves the state exactly at
    its snapshot. The rollback assertions are internal
    errors, not verdicts: if the arithmetic ever disagreed
    with the account, the loop raises rather than commit a
    state the account does not describe.
    """
    var shape = dispatch_proposer(slot, kind)
    var snap = state.snapshot()
    var account = plan_verify(
        kind,
        draft_tokens,
        target_greedy_tokens,
        snap.kv_length,
        state.kv_capacity,
        snap.context_count,
        rng_draws_consumed,
    )
    if not account_is_consistent(account):
        raise Error("SpeculativeLoop: derived round account is inconsistent")
    # Tentative advance: the pass wrote k+1 rows.
    var tentative_kv = snap.kv_length + account.k + 1
    var tentative_context = snap.context_count + account.k + 1
    var tentative_draft_kv = snap.draft_kv_length
    if shape.carries_own_kv:
        tentative_draft_kv += account.k
    # Exact rollback: discard the uncommitted rows.
    var rolled_kv = tentative_kv - account.kv_rows_to_roll_back
    var rolled_context = tentative_context - account.kv_rows_to_roll_back
    if rolled_kv != account.kv_after:
        raise Error("SpeculativeLoop: KV rollback disagrees with the account")
    if rolled_context != account.context_after:
        raise Error("SpeculativeLoop: context rollback disagrees with the account")
    var rolled_draft_kv = snap.draft_kv_length
    if shape.carries_own_kv:
        rolled_draft_kv = tentative_draft_kv - account.kv_rows_to_roll_back
        if rolled_draft_kv != snap.draft_kv_length + account.accepted_count:
            raise Error(
                "SpeculativeLoop: proposer KV rollback disagrees with the account"
            )
    # Sampler state: a greedy round draws nothing (enforced
    # by plan_verify), so the word after the round must be
    # the snapshot's word, exactly.
    if state.rng_word != snap.rng_word:
        raise Error("SpeculativeLoop: RNG state word changed inside a greedy round")
    state.kv_length = rolled_kv
    state.context_count = rolled_context
    state.draft_kv_length = rolled_draft_kv
    for i in range(len(account.emitted_tokens)):
        state.emitted.append(account.emitted_tokens[i])
    return account^


struct LoopResult(Copyable):
    """A completed run_loop drive, with its closing state."""

    var emitted: List[Int]
    var rounds: Int
    var total_accepted: Int
    var total_rollback_rows: Int
    var final_kv_length: Int
    var final_context_count: Int
    var final_draft_kv_length: Int
    var rng_word: UInt64

    def __init__(out self):
        self.emitted = List[Int]()
        self.rounds = 0
        self.total_accepted = 0
        self.total_rollback_rows = 0
        self.final_kv_length = 0
        self.final_context_count = 0
        self.final_draft_kv_length = 0
        self.rng_word = UInt64(0)

    def __copyinit__(out self, existing: Self):
        self.emitted = existing.emitted.copy()
        self.rounds = existing.rounds
        self.total_accepted = existing.total_accepted
        self.total_rollback_rows = existing.total_rollback_rows
        self.final_kv_length = existing.final_kv_length
        self.final_context_count = existing.final_context_count
        self.final_draft_kv_length = existing.final_draft_kv_length
        self.rng_word = existing.rng_word


def run_loop(
    initial: LoopState,
    slot: Int,
    kind: Int,
    drafts_flat: List[Int],
    round_ks: List[Int],
    plain_target: List[Int],
) raises -> LoopResult:
    """Drive consecutive rounds over a stated continuation.

    drafts_flat holds every round's drafts concatenated, in
    round order, with round_ks giving each round's depth;
    plain_target is the target's plain-greedy continuation,
    from which each round's k+1 target choices are sliced
    (the account-level premise stated in the header). The
    rounds must exactly cover plain_target: running out of
    drafts or target tokens mid-round is refused, and a
    drive that ends short of the continuation is refused
    rather than filed as a partial identity. On success the
    concatenated emission is asserted token-identical to
    plain_target under J-071's checker.
    """
    _ = dispatch_proposer(slot, kind)
    var state = initial.copy()
    var result = LoopResult()
    var pos = 0
    var draft_pos = 0
    for r in range(len(round_ks)):
        var k = round_ks[r]
        if k < 1:
            raise Error("SpeculativeLoop: a round proposes at least one draft token")
        if draft_pos + k > len(drafts_flat):
            raise Error("SpeculativeLoop: the flat draft encoding ran out mid-round")
        if pos + k + 1 > len(plain_target):
            raise Error(
                "SpeculativeLoop: the target continuation ran out mid-round;"
                " the host stops the loop at the continuation's end"
            )
        var drafts = List[Int]()
        for i in range(k):
            drafts.append(drafts_flat[draft_pos + i])
        var target = List[Int]()
        for i in range(k + 1):
            target.append(plain_target[pos + i])
        var account = run_loop_round(state, slot, kind, drafts, target, 0)
        pos += account.emitted_count()
        draft_pos += k
        result.rounds += 1
        result.total_accepted += account.accepted_count
        result.total_rollback_rows += account.kv_rows_to_roll_back
    if pos != len(plain_target):
        raise Error(
            "SpeculativeLoop: the rounds ended short of the target"
            " continuation; a partial drive files no identity"
        )
    if not sequences_identical(state.emitted, plain_target):
        raise Error("SpeculativeLoop: loop emission diverged from plain greedy")
    result.emitted = state.emitted.copy()
    result.final_kv_length = state.kv_length
    result.final_context_count = state.context_count
    result.final_draft_kv_length = state.draft_kv_length
    result.rng_word = state.rng_word
    return result^
