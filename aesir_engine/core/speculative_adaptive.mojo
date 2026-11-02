"""Speculative adaptive depth (Janas road J-079).

The roadmap text: "Adaptive depth. Draft length k tuned
live by measured acceptance (deepen when hot, shallow when
cold), with the tuning itself measured against fixed k."

THE TUNING RULE, PRE-REGISTERED before any measurement
(the slice doc, docs/janas/J079_ADAPTIVE_DEPTH.md section 1,
is its normative text; this header restates it exactly):

- EVIDENCE: the controller consumes J-071 VerifyAccounts
  only, gated on account_is_consistent() and on the
  account's proposer kind matching the controller's kind.
  It recomputes nothing J-071 derived: a round's evidence
  is (account.k drafted, account.accepted_count accepted).
  The same evidence, filed through J-075's ledger, is what
  decide_from_ledger_row() reads -- through J-075's own
  rate_basis_points(), over an AcceptanceRow, never through
  a restated rate.
- WINDOW / MINIMUM EVIDENCE: decisions are made only over
  a completed WINDOW of ADAPT_WINDOW_ROUNDS = 4 consecutive
  rounds. Fewer rounds are PENDING: k does not move, however
  hot or cold the partial window looks. The window counters
  reset at every decision, so a decision always rests on
  exactly the last 4 rounds, never on a lifetime average.
- DECISION (hysteresis deadband): over a window, let
  wasted = window_drafted - window_accepted and rate_bp =
  window_accepted * 10000 // window_drafted. The window
  DEEPENS only on near-saturation: wasted <=
  ADAPT_DEEPEN_MAX_WASTED (2) over the whole window --
  the drafts actually proposed were almost all accepted,
  so a deeper draft has evidence it would be used. (A
  rate-only hot threshold was measured first in this
  slice and REJECTED: it deepened until the rate fell
  under the threshold, overshooting the stated hot
  fixture to k=12 with more wasted work than fixed k=8
  on both axes; the filed rule is the revision, doc
  section 6.) The window SHALLOWS when rate_bp <=
  ADAPT_COLD_BP (3000), inclusive. Everything else is
  the deadband and HOLDS: a window can be warm (even
  8500 bp) and still hold, when its wasted count says
  the extra depth was not being used.
- STEP: a deepening window deepens k by ADAPT_STEP = 2;
  a cold window shallows k by ADAPT_STEP = 2. No other
  move exists.
- BOUNDS: k never leaves [LOOP_K_MIN, the proposer's cap],
  the floor read from J-072 and the cap read from J-071's
  plan_proposer() on every decision, never restated here.
  Deepening at the cap and shallowing at the floor are
  HOLDs (the events are counted as holds, not as moves).
- START: a session starts at J-072's LOOP_K_INITIAL (4)
  unless the host states another in-bounds start.
- NO-PATHOLOGICAL-OSCILLATION PROPERTY (stated, tested):
  k changes at most once per window (at most one move per
  4 rounds) and by at most ADAPT_STEP; and any window whose
  rounds alternate hot and cold per-round (the fastest
  possible alternation) has a rate inside the deadband by
  construction of the fixture rates, so it HOLDS -- per-
  round alternation cannot move k at all. A reversal needs
  a full opposite window of evidence after the move.

RELATION TO J-072: suggest_next_k() in the loop module is
the unmeasured single-round SHAPE (deepen one on a fully
accepted round, halve on a zero round, instantly). This
module SUPERSEDES that shape as the tuning rule a live host
uses: windowed, thresholded, and measured in this slice
against fixed k (doc section 4, SIMULATED fixtures). The
loop function is not edited; the host contract below names
this controller, and plan_adaptive_round() plans each
round's k through J-072's plan_round_k(), so the KV-
capacity shortening stays J-072's recorded plan fact and
is never this controller's silent move.

WHAT THIS MODULE IS NOT: it executes no forward, times
nothing, opens no device, and contains no speed. Its
measurement (doc section 4) replays stated acceptance
fixtures through this rule and through fixed-k baselines
under a stated cost model; those numbers are properties
of the fixtures, labelled SIMULATED, never of a model
pair. Tuning on a live pair is NOT PROVEN (doc section 6,
deferred with its recipe to the J-086 gate): no proposer
implementation, verify-pass executor, or session wiring
exists in this tree, and require_draft_check_use() still
fails closed.

HOST CONTRACT (binding on the first live host): (1) start
one controller per (session, proposer kind) with
adaptive_initial() (or adaptive_start() with a stated
in-bounds k); (2) per round, plan k with
plan_adaptive_round() and propose exactly the planned
depth; if the plan shortens for capacity, that round's
account is still filed with J-075's ledger but the host
states the shortening beside the controller's record --
the controller itself consumes accounts as filed;
(3) after each round, call record_adaptive_round() with
the round's VerifyAccount and propose the controller's
next k (adaptive_next_k()) on the following round;
(4) file the controller's counters with the run's
evidence, so a filed k trajectory is reproducible from
the filed accounts alone.
"""

from core.speculative_acceptance import AcceptanceRow, rate_basis_points
from core.speculative_loop import (
    LOOP_K_INITIAL,
    LOOP_K_MIN,
    KPlan,
    plan_round_k,
)
from core.speculative_verify import (
    VerifyAccount,
    account_is_consistent,
    plan_proposer,
)

# The pre-registered tuning rule (header, doc section 1).
comptime ADAPT_WINDOW_ROUNDS = 4
comptime ADAPT_DEEPEN_MAX_WASTED = 2
comptime ADAPT_COLD_BP = 3000
comptime ADAPT_STEP = 2

# Decision codes (record_adaptive_round's return and the
# controller's last_decision).
comptime ADAPT_PENDING = 0
comptime ADAPT_HOLD = 1
comptime ADAPT_DEEPEN = 2
comptime ADAPT_SHALLOW = 3


def adapt_decision_name(code: Int) raises -> String:
    if code == ADAPT_PENDING:
        return String("pending")
    if code == ADAPT_HOLD:
        return String("hold")
    if code == ADAPT_DEEPEN:
        return String("deepen")
    if code == ADAPT_SHALLOW:
        return String("shallow")
    raise Error("SpeculativeAdaptive: unknown decision code")


struct AdaptiveDepth(Copyable):
    """One controller's state for one proposer kind.

    current_k is the depth the next round proposes (before
    J-072's capacity planning). The window counters cover
    only the current, not-yet-decided window; the totals
    cover every round the controller has consumed, so a
    filed trajectory can be checked against filed accounts.
    last_window_rate_bp is -1 until the first window closes.
    """

    var proposer_kind: Int
    var current_k: Int
    var window_rounds: Int
    var window_drafted: Int
    var window_accepted: Int
    var total_rounds: Int
    var total_drafted: Int
    var total_accepted: Int
    var windows_completed: Int
    var deepen_events: Int
    var shallow_events: Int
    var hold_events: Int
    var last_window_rate_bp: Int
    var last_decision: Int

    def __init__(out self, proposer_kind: Int, current_k: Int):
        self.proposer_kind = proposer_kind
        self.current_k = current_k
        self.window_rounds = 0
        self.window_drafted = 0
        self.window_accepted = 0
        self.total_rounds = 0
        self.total_drafted = 0
        self.total_accepted = 0
        self.windows_completed = 0
        self.deepen_events = 0
        self.shallow_events = 0
        self.hold_events = 0
        self.last_window_rate_bp = -1
        self.last_decision = ADAPT_PENDING

    def __copyinit__(out self, existing: Self):
        self.proposer_kind = existing.proposer_kind
        self.current_k = existing.current_k
        self.window_rounds = existing.window_rounds
        self.window_drafted = existing.window_drafted
        self.window_accepted = existing.window_accepted
        self.total_rounds = existing.total_rounds
        self.total_drafted = existing.total_drafted
        self.total_accepted = existing.total_accepted
        self.windows_completed = existing.windows_completed
        self.deepen_events = existing.deepen_events
        self.shallow_events = existing.shallow_events
        self.hold_events = existing.hold_events
        self.last_window_rate_bp = existing.last_window_rate_bp
        self.last_decision = existing.last_decision

    def copy(self) -> Self:
        var copied = Self(self.proposer_kind, self.current_k)
        copied.window_rounds = self.window_rounds
        copied.window_drafted = self.window_drafted
        copied.window_accepted = self.window_accepted
        copied.total_rounds = self.total_rounds
        copied.total_drafted = self.total_drafted
        copied.total_accepted = self.total_accepted
        copied.windows_completed = self.windows_completed
        copied.deepen_events = self.deepen_events
        copied.shallow_events = self.shallow_events
        copied.hold_events = self.hold_events
        copied.last_window_rate_bp = self.last_window_rate_bp
        copied.last_decision = self.last_decision
        return copied^


def _validate_k(kind: Int, k: Int) raises:
    """k inside [LOOP_K_MIN, the J-071 cap for this kind]."""
    var shape = plan_proposer(kind)
    if k < LOOP_K_MIN or k > shape.max_k:
        raise Error(
            "SpeculativeAdaptive: k outside this proposer's bounds"
            " (floor read from J-072, cap read from J-071)"
        )


def adaptive_start(kind: Int, starting_k: Int) raises -> AdaptiveDepth:
    """A controller at a stated in-bounds starting depth."""
    _validate_k(kind, starting_k)
    return AdaptiveDepth(kind, starting_k)


def adaptive_initial(kind: Int) raises -> AdaptiveDepth:
    """A controller at J-072's initial depth (LOOP_K_INITIAL)."""
    return adaptive_start(kind, LOOP_K_INITIAL)


def adaptive_next_k(state: AdaptiveDepth) -> Int:
    """The depth the next round proposes (pre-capacity-plan)."""
    return state.current_k


def adaptive_window_rate_bp(state: AdaptiveDepth) raises -> Int:
    """The open window's rate so far, in basis points.

    Refused when the open window has drafted nothing: a
    window with no evidence has no rate (J-075's rule).
    """
    if state.window_drafted <= 0:
        raise Error("SpeculativeAdaptive: an empty window has no rate")
    return state.window_accepted * 10000 // state.window_drafted


struct _Decision(Copyable, ImplicitlyCopyable):
    var decision: Int
    var next_k: Int

    def __init__(out self, decision: Int, next_k: Int):
        self.decision = decision
        self.next_k = next_k


def _decide(
    kind: Int, current_k: Int, rate_bp: Int, wasted: Int, evidence_rounds: Int
) raises -> _Decision:
    """The rule's decision over one completed window.

    Deepen on near-saturation (wasted, scaled by the
    evidence length, at most ADAPT_DEEPEN_MAX_WASTED per
    window: wasted * ADAPT_WINDOW_ROUNDS <=
    ADAPT_DEEPEN_MAX_WASTED * evidence_rounds, exact
    integer arithmetic), shallow on a cold rate; deepen/
    shallow by ADAPT_STEP, clamped to the bounds. A move
    the bound already forbids (deepen at cap, shallow at
    floor) is a HOLD, so the event counters never claim a
    move that did not happen.
    """
    var shape = plan_proposer(kind)
    if wasted * ADAPT_WINDOW_ROUNDS <= ADAPT_DEEPEN_MAX_WASTED * evidence_rounds:
        if current_k >= shape.max_k:
            return _Decision(ADAPT_HOLD, current_k)
        var deepened = current_k + ADAPT_STEP
        if deepened > shape.max_k:
            deepened = shape.max_k
        return _Decision(ADAPT_DEEPEN, deepened)
    if rate_bp <= ADAPT_COLD_BP:
        if current_k <= LOOP_K_MIN:
            return _Decision(ADAPT_HOLD, current_k)
        var shallowed = current_k - ADAPT_STEP
        if shallowed < LOOP_K_MIN:
            shallowed = LOOP_K_MIN
        return _Decision(ADAPT_SHALLOW, shallowed)
    return _Decision(ADAPT_HOLD, current_k)


def record_adaptive_round(
    mut state: AdaptiveDepth, account: VerifyAccount
) raises -> Int:
    """Consume one round's J-071 account; return the decision.

    Refusals (each leaving the controller exactly as it
    was): an account account_is_consistent() rejects; an
    account whose proposer kind is not the controller's
    kind. Until the window completes the decision is
    ADAPT_PENDING and k does not move; at the window's
    close the pre-registered rule decides, the window
    counters reset, and the decision is returned.
    """
    if not account_is_consistent(account):
        raise Error(
            "SpeculativeAdaptive: an inconsistent verify account grounds"
            " no tuning decision; restate the account or the round"
        )
    if account.proposer_kind != state.proposer_kind:
        raise Error(
            "SpeculativeAdaptive: the account's proposer kind is not"
            " this controller's kind; file it with its own controller"
        )
    state.window_rounds += 1
    state.window_drafted += account.k
    state.window_accepted += account.accepted_count
    state.total_rounds += 1
    state.total_drafted += account.k
    state.total_accepted += account.accepted_count
    if state.window_rounds < ADAPT_WINDOW_ROUNDS:
        state.last_decision = ADAPT_PENDING
        return ADAPT_PENDING
    var rate_bp = state.window_accepted * 10000 // state.window_drafted
    var wasted = state.window_drafted - state.window_accepted
    var decided = _decide(
        state.proposer_kind, state.current_k, rate_bp, wasted, state.window_rounds
    )
    var decision = decided.decision
    state.current_k = decided.next_k
    state.last_window_rate_bp = rate_bp
    state.last_decision = decision
    state.windows_completed += 1
    if decision == ADAPT_DEEPEN:
        state.deepen_events += 1
    elif decision == ADAPT_SHALLOW:
        state.shallow_events += 1
    else:
        state.hold_events += 1
    state.window_rounds = 0
    state.window_drafted = 0
    state.window_accepted = 0
    return decision


struct TuningDecision(Copyable, ImplicitlyCopyable):
    """A decision read off filed evidence, without mutating
    any controller: the decision code, the k it would set,
    the rate it rested on (-1 when there is no rate yet),
    and the rounds of evidence behind it."""

    var decision: Int
    var next_k: Int
    var rate_bp: Int
    var rounds: Int

    def __init__(
        out self, decision: Int, next_k: Int, rate_bp: Int, rounds: Int
    ):
        self.decision = decision
        self.next_k = next_k
        self.rate_bp = rate_bp
        self.rounds = rounds


def decide_from_ledger_row(
    kind: Int, current_k: Int, row: AcceptanceRow
) raises -> TuningDecision:
    """The rule applied to one J-075 ledger row.

    The row is the ledger's own aggregate (rounds, drafted,
    accepted, histogram) for one (kind, pair, text type,
    language); its rate is J-075's rate_basis_points(),
    not a restatement. A row with fewer than
    ADAPT_WINDOW_ROUNDS rounds is PENDING (minimum evidence
    applies to filed rows exactly as to live windows); a
    row whose kind is not the stated kind is refused.
    """
    _validate_k(kind, current_k)
    if row.proposer_kind != kind:
        raise Error(
            "SpeculativeAdaptive: the ledger row's proposer kind is"
            " not the stated kind"
        )
    if row.rounds < ADAPT_WINDOW_ROUNDS or row.drafted <= 0:
        return TuningDecision(ADAPT_PENDING, current_k, -1, row.rounds)
    var rate_bp = rate_basis_points(row)
    var decided = _decide(
        kind, current_k, rate_bp, row.drafted - row.accepted, row.rounds
    )
    return TuningDecision(decided.decision, decided.next_k, rate_bp, row.rounds)


def plan_adaptive_round(
    state: AdaptiveDepth, kv_before: Int, kv_capacity: Int
) raises -> KPlan:
    """Plan the controller's next round through J-072.

    The plan is plan_round_k()'s own: the capacity bound
    may shorten the controller's k for this round, with
    the shortening recorded on the plan -- the controller
    never silently truncates, and its own current_k is
    unchanged by planning.
    """
    return plan_round_k(
        state.proposer_kind, state.current_k, kv_before, kv_capacity
    )
