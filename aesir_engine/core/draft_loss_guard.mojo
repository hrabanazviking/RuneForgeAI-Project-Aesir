"""Draft loss guard (Janas road J-084).

The roadmap text: "When drafts lose. The measured floor:
pairs and text types where speculation is a loss, the
engine detects and disables it live, the disabling logged.
A feature that knows when to stop."

THE MEASURED FLOOR (derived in the slice doc,
docs/janas/J084_WHEN_DRAFTS_LOSE.md section 1, from the
road's filed evidence; this header states the arithmetic
the guard enforces). One speculative round emits a + 1
tokens for its price (J-071: the accepted prefix plus
exactly one target token), so a round's GAIN over plain
decode is exactly its accepted count a: plain decode emits
1 token per target pass, the round emits a + 1 tokens for
one verify pass plus k draft steps. Over any set of rounds,
with every cost stated by the host in ONE currency:

  emitted  = accepted + rounds
  value    = emitted * plain_cost_per_token
  net      = value - sum(round_cost)
  LOSS iff net < 0 (break-even, net == 0, is NOT a loss)

Break-even mean acceptance per round is therefore
a* = mean(round_cost) / plain_cost_per_token - 1, and
where a round's cost takes the step form (one verify pass
priced as one plain step, J-071's one-pass accounting,
plus k draft steps at r plain steps each) a* = k * r and
the break-even RATE is exactly r, at every k. The filed
instantiations (doc section 1): the first pair's draft
steps at the parameter ratio 0.6B / 4B = 3/20 filed by
J-074 give a step floor of 1500 bp; the worst-case
admissible drafter at J-074's materially-smaller bound
(half the target's resident bytes) gives 5000 bp; J-080's
byte currency convicts the cold regime at every depth
(+47.10 % per emitted token at k = 2, 128-pair budget, on
the measured MoE trace) where the step currency for the
first pair does not -- which is why this guard follows
HOST-STATED costs and no hardcoded threshold: the same
acceptance stream is a win under one pair's true costs
and a loss under another's, and only the host's stated
costs say which. Cells the filed evidence cannot price
(head and assistant draft-cost ratios, dense-target byte
taxes, every wall cell) are NOT PROVEN in the doc and are
priced here by nobody: the host states costs live, or the
guard has nothing honest to decide from.

THE DISABLE RULE (pre-registered here, before the code;
the module's tests grade exactly this):

- IDENTITY: one guard watches one (proposer kind, pair id,
  text type, language) row -- J-075's row key, validated by
  J-075's own rules (pair id 0 unless cross-model, where it
  names the J-074 verdict's index; language applies to
  prose rows only, not_applicable elsewhere). A collapse in
  one row disables that row only: the Italian-prose lesson
  (J-075) is precisely that rows must never be merged, so
  English prose keeps drafting while Italian prose is off.
- EVIDENCE: the guard consumes J-071 VerifyAccounts only,
  gated on account_is_consistent() and on the account's
  proposer kind matching the guard's kind, each paired
  with the host-stated cost of that round (an Int in the
  guard's one currency; negative costs refused). It
  recomputes nothing J-071 derived: a round's tokens are
  (account.k drafted, account.accepted_count accepted,
  accepted + 1 emitted). A refusal consumes nothing and
  leaves the guard exactly as it was.
- WINDOW: decisions rest on completed windows of
  LOSS_WINDOW_ROUNDS = 4 consecutive rounds -- J-079's
  evidence quantum, imported from the adaptive-depth
  module, never restated, so the two controllers' windows
  align round for round: J-079 shallows first (its window
  closes on the same rounds), and this guard judges what
  remains. A partial window is PENDING and decides
  nothing, however losing it looks.
- LOSS: a completed window is LOSING iff its net < 0
  (strict). net == 0 is break-even: counted, reported,
  never losing. A winning or break-even window resets the
  consecutive-losing count to zero.
- DISABLE: the guard DISABLES at the close of the SECOND
  consecutive losing window -- round 8 at the earliest --
  and the disabling round's decision is GUARD_DISABLED.
  One losing window never disables (hysteresis: a single
  bad stretch is J-079's shallowing case, not a verdict
  that the pair loses); two in a row, over 8 rounds of
  filed accounts and stated costs, is the sustained loss
  the roadmap names.
- POSTURE AFTER DISABLE (answered-locally, doc section 7):
  disabled FOR THE SESSION. There is no automatic
  re-probe: a probe round is itself a speculative round,
  so re-probing a proven-losing row burns the exact cost
  this guard exists to stop, and no filed evidence prices
  a safe probe cadence. Re-enabling is a host act -- a new
  session, or a new J-083 configuration -- never this
  module's silent move. Recording a round into a disabled
  guard is refused by name, loudly, so a host that keeps
  speculating past a disable fails in its own logs.
- COMPOSITION: disabling is a runtime session state, not
  a configuration change. J-083's draft_config module is
  not edited and not consulted: a disabled row's stored
  configuration still validates and persists exactly as
  before, and a new session starts a fresh guard over the
  same configuration. J-079's controller is likewise
  untouched: it may keep shallowing a disabled row's k in
  its own record, but no round runs, so nothing feeds it.
- THE LOGGING CONTRACT: at the moment of disabling, the
  guard freezes its totals and disable_record_text()
  renders the disable record in the fixed field order the
  tests pin (event, reason, row key, posture, plain cost,
  and the window + total accounts the decision rested on).
  The host files that record beside the run's J-036 /
  J-083 records, in the same evidence set as the rounds'
  VerifyAccounts, so the disabling is reproducible from
  the filed record alone. Before disabling, the function
  refuses: there is no record of a disable that has not
  happened.

WHAT THIS MODULE IS NOT: it executes no forward, times
nothing, opens no device, and contains no speed. It
decides from accounts and host-stated costs only. No
proposer implementation, verify-pass executor, or session
wiring exists in this tree (G-PROPOSER + G-EXECUTOR stand,
J-083): require_draft_check_use() still fails closed and
the facade's speculative_generate still raises
not-implemented, so tonight no live session can disable
anything -- the guard is proven over stated fixture
streams (SIMULATED), and the live disabling leg is
deferred with its recipe to the J-086 gate (doc
section 6).

HOST CONTRACT (binding on the first live host): (1) start
one guard per (session, row) with loss_guard_start(),
stating plain_cost_per_token in the same currency every
round cost will be stated in; (2) run rounds under J-072's
host contract, price each round in that currency (draft
steps + the verify pass + any J-081 crossings the host
chooses to price in -- the currency and its contents are
the host's stated choice, filed with the run); (3) after
each round, call record_loss_round() with the round's
VerifyAccount and its stated cost; on GUARD_DISABLED,
stop speculating that row, run it plain, and file
disable_record_text() beside the run's records; (4) file
the guard's counters with the run's evidence, so a filed
disabling is reproducible from the filed accounts and
stated costs alone.
"""

from core.speculative_acceptance import (
    LANG_NOT_APPLICABLE,
    TEXT_PROSE,
    language_name,
    text_type_name,
)
from core.speculative_adaptive import ADAPT_WINDOW_ROUNDS
from core.speculative_verify import (
    PROPOSER_CROSS_MODEL,
    VerifyAccount,
    account_is_consistent,
    plan_proposer,
    proposer_kind_name,
)

# The evidence quantum: J-079's window, imported so the
# two controllers decide over the same rounds (header).
comptime LOSS_WINDOW_ROUNDS = ADAPT_WINDOW_ROUNDS

# Consecutive losing windows that disable (header rule).
comptime LOSS_DISABLE_WINDOWS = 2

# Decision codes (record_loss_round's return and the
# guard's last_decision).
comptime GUARD_PENDING = 0
comptime GUARD_HOLD = 1
comptime GUARD_DISABLED = 2

# The disable reason name, carried on every record.
comptime DISABLE_REASON = "DISABLE_SUSTAINED_LOSS"


def guard_decision_name(code: Int) raises -> String:
    if code == GUARD_PENDING:
        return String("pending")
    if code == GUARD_HOLD:
        return String("hold")
    if code == GUARD_DISABLED:
        return String("disabled")
    raise Error("DraftLossGuard: unknown decision code")


struct LossGuard(Copyable):
    """One guard's state for one (kind, pair, type,
    language) row of one session.

    plain_cost_per_token is the host-stated price of one
    plainly-decoded token, in the one currency every round
    cost fed to this guard is stated in. The window
    counters cover only the current, not-yet-decided
    window; the totals cover every round consumed, so a
    filed disabling is checkable against filed accounts.
    last_window_net / last_window_rate_bp describe the most
    recently closed window (rate -1, net 0 before the first
    window closes). Once disabled, every counter is frozen:
    a disabled guard consumes nothing further.
    """

    var proposer_kind: Int
    var pair_id: Int
    var text_type: Int
    var language: Int
    var plain_cost_per_token: Int
    var disabled: Bool
    var disabled_at_round: Int
    var window_rounds: Int
    var window_drafted: Int
    var window_accepted: Int
    var window_emitted: Int
    var window_cost: Int
    var total_rounds: Int
    var total_drafted: Int
    var total_accepted: Int
    var total_emitted: Int
    var total_cost: Int
    var windows_completed: Int
    var losing_windows: Int
    var consecutive_losing_windows: Int
    var last_window_net: Int
    var last_window_rate_bp: Int
    var last_decision: Int

    def __init__(
        out self,
        proposer_kind: Int,
        pair_id: Int,
        text_type: Int,
        language: Int,
        plain_cost_per_token: Int,
    ):
        self.proposer_kind = proposer_kind
        self.pair_id = pair_id
        self.text_type = text_type
        self.language = language
        self.plain_cost_per_token = plain_cost_per_token
        self.disabled = False
        self.disabled_at_round = -1
        self.window_rounds = 0
        self.window_drafted = 0
        self.window_accepted = 0
        self.window_emitted = 0
        self.window_cost = 0
        self.total_rounds = 0
        self.total_drafted = 0
        self.total_accepted = 0
        self.total_emitted = 0
        self.total_cost = 0
        self.windows_completed = 0
        self.losing_windows = 0
        self.consecutive_losing_windows = 0
        self.last_window_net = 0
        self.last_window_rate_bp = -1
        self.last_decision = GUARD_PENDING

    def __copyinit__(out self, existing: Self):
        self.proposer_kind = existing.proposer_kind
        self.pair_id = existing.pair_id
        self.text_type = existing.text_type
        self.language = existing.language
        self.plain_cost_per_token = existing.plain_cost_per_token
        self.disabled = existing.disabled
        self.disabled_at_round = existing.disabled_at_round
        self.window_rounds = existing.window_rounds
        self.window_drafted = existing.window_drafted
        self.window_accepted = existing.window_accepted
        self.window_emitted = existing.window_emitted
        self.window_cost = existing.window_cost
        self.total_rounds = existing.total_rounds
        self.total_drafted = existing.total_drafted
        self.total_accepted = existing.total_accepted
        self.total_emitted = existing.total_emitted
        self.total_cost = existing.total_cost
        self.windows_completed = existing.windows_completed
        self.losing_windows = existing.losing_windows
        self.consecutive_losing_windows = (
            existing.consecutive_losing_windows
        )
        self.last_window_net = existing.last_window_net
        self.last_window_rate_bp = existing.last_window_rate_bp
        self.last_decision = existing.last_decision

    def copy(self) -> Self:
        var copied = Self(
            self.proposer_kind,
            self.pair_id,
            self.text_type,
            self.language,
            self.plain_cost_per_token,
        )
        copied.disabled = self.disabled
        copied.disabled_at_round = self.disabled_at_round
        copied.window_rounds = self.window_rounds
        copied.window_drafted = self.window_drafted
        copied.window_accepted = self.window_accepted
        copied.window_emitted = self.window_emitted
        copied.window_cost = self.window_cost
        copied.total_rounds = self.total_rounds
        copied.total_drafted = self.total_drafted
        copied.total_accepted = self.total_accepted
        copied.total_emitted = self.total_emitted
        copied.total_cost = self.total_cost
        copied.windows_completed = self.windows_completed
        copied.losing_windows = self.losing_windows
        copied.consecutive_losing_windows = (
            self.consecutive_losing_windows
        )
        copied.last_window_net = self.last_window_net
        copied.last_window_rate_bp = self.last_window_rate_bp
        copied.last_decision = self.last_decision
        return copied^

    def total_net(self) -> Int:
        """The session-to-date net in the guard's currency:
        the plain value of everything emitted, less every
        stated round cost."""
        return (
            self.total_emitted * self.plain_cost_per_token
            - self.total_cost
        )


def loss_guard_start(
    proposer_kind: Int,
    pair_id: Int,
    text_type: Int,
    language: Int,
    plain_cost_per_token: Int,
) raises -> LossGuard:
    """A guard for one row, at a stated plain-token price.

    Refusals (J-075's row-key rules, restated nowhere --
    validated here against the same names the ledger
    uses): an unknown proposer kind (through J-071's
    plan_proposer); a pair id on a non-cross-model kind,
    or no pair id on a cross-model kind; an unknown text
    type or language (through J-075's name functions); a
    language on a non-prose row, or not_applicable on a
    prose row; a plain price that is not positive (a free
    plain token makes every round a loss by construction,
    which is a mis-stated currency, not a measurement).
    """
    _ = plan_proposer(proposer_kind)
    if proposer_kind == PROPOSER_CROSS_MODEL:
        if pair_id < 1:
            raise Error(
                "DraftLossGuard: a cross-model row names its"
                " J-074 pair id (1 is the first pair)"
            )
    elif pair_id != 0:
        raise Error(
            "DraftLossGuard: pair id 0 for every"
            " non-cross-model proposer (J-075)"
        )
    _ = text_type_name(text_type)
    _ = language_name(language)
    # Prose rows carry a real language; every other row
    # carries not_applicable (J-075's rule).
    if text_type == TEXT_PROSE:
        if language == LANG_NOT_APPLICABLE:
            raise Error(
                "DraftLossGuard: a prose row carries a"
                " language (J-075); not_applicable is for"
                " code and structured rows"
            )
    elif language != LANG_NOT_APPLICABLE:
        raise Error(
            "DraftLossGuard: language applies to prose"
            " rows only (J-075); other rows carry"
            " not_applicable"
        )
    if plain_cost_per_token <= 0:
        raise Error(
            "DraftLossGuard: the plain price must be"
            " positive; restate the currency"
        )
    return LossGuard(
        proposer_kind, pair_id, text_type, language,
        plain_cost_per_token,
    )


def record_loss_round(
    mut guard: LossGuard, account: VerifyAccount, round_cost: Int
) raises -> Int:
    """Consume one round's account + its host-stated cost;
    return the decision.

    Refusals (each leaving the guard exactly as it was):
    a disabled guard (the disable is for the session --
    a host still speculating this row must fail loudly);
    an account account_is_consistent() rejects; an
    account whose proposer kind is not the guard's kind;
    a negative round cost. Until the window completes the
    decision is GUARD_PENDING; at its close the header's
    rule decides: a losing window (net < 0) increments the
    consecutive count, any other window resets it, and the
    second consecutive losing window disables, freezing
    the guard at this round.
    """
    if guard.disabled:
        raise Error(
            "DraftLossGuard: this row is DISABLED for the"
            " session (DISABLE_SUSTAINED_LOSS at round "
            + String(guard.disabled_at_round)
            + "); run it plain -- re-enabling is a host act"
            " (new session or new configuration)"
        )
    if not account_is_consistent(account):
        raise Error(
            "DraftLossGuard: an inconsistent verify account"
            " grounds no loss decision; restate the account"
            " or the round"
        )
    if account.proposer_kind != guard.proposer_kind:
        raise Error(
            "DraftLossGuard: the account's proposer kind is"
            " not this guard's kind; file it with its own"
            " guard"
        )
    if round_cost < 0:
        raise Error(
            "DraftLossGuard: a round cost cannot be"
            " negative; restate the round's price"
        )
    var emitted = account.accepted_count + 1
    guard.window_rounds += 1
    guard.window_drafted += account.k
    guard.window_accepted += account.accepted_count
    guard.window_emitted += emitted
    guard.window_cost += round_cost
    guard.total_rounds += 1
    guard.total_drafted += account.k
    guard.total_accepted += account.accepted_count
    guard.total_emitted += emitted
    guard.total_cost += round_cost
    if guard.window_rounds < LOSS_WINDOW_ROUNDS:
        guard.last_decision = GUARD_PENDING
        return GUARD_PENDING
    var window_value = (
        guard.window_emitted * guard.plain_cost_per_token
    )
    var window_net = window_value - guard.window_cost
    guard.last_window_net = window_net
    guard.last_window_rate_bp = (
        guard.window_accepted * 10000 // guard.window_drafted
    )
    guard.windows_completed += 1
    if window_net < 0:
        guard.losing_windows += 1
        guard.consecutive_losing_windows += 1
    else:
        guard.consecutive_losing_windows = 0
    guard.window_rounds = 0
    guard.window_drafted = 0
    guard.window_accepted = 0
    guard.window_emitted = 0
    guard.window_cost = 0
    if guard.consecutive_losing_windows >= LOSS_DISABLE_WINDOWS:
        guard.disabled = True
        guard.disabled_at_round = guard.total_rounds
        guard.last_decision = GUARD_DISABLED
        return GUARD_DISABLED
    guard.last_decision = GUARD_HOLD
    return GUARD_HOLD


def loss_guard_disabled(guard: LossGuard) -> Bool:
    """True once the guard has disabled its row."""
    return guard.disabled


def disable_record_text(guard: LossGuard) raises -> String:
    """The disable record, in its pinned field order.

    Refused while the guard is not disabled: there is no
    record of a disable that has not happened. The host
    files this text beside the run's J-036 / J-083 records
    (header, logging contract); every number on it is the
    guard's frozen account at the disabling round, so the
    record reproduces from the filed rounds alone.
    """
    if not guard.disabled:
        raise Error(
            "DraftLossGuard: no disable record exists until"
            " the guard disables; this row has not disabled"
        )
    var out_str = String("draft-loss-disable:\n")
    out_str += "event=drafts_disabled\n"
    out_str += "reason=" + String(DISABLE_REASON) + "\n"
    out_str += (
        "proposer_kind=" + proposer_kind_name(guard.proposer_kind)
        + "\n"
    )
    out_str += "pair_id=" + String(guard.pair_id) + "\n"
    out_str += (
        "text_type=" + text_type_name(guard.text_type) + "\n"
    )
    out_str += "language=" + language_name(guard.language) + "\n"
    out_str += (
        "disabled_at_round=" + String(guard.disabled_at_round)
        + "\n"
    )
    out_str += (
        "posture=disabled for the session; re-enable only by"
        " a new session or a new configuration (host act)\n"
    )
    out_str += (
        "plain_cost_per_token="
        + String(guard.plain_cost_per_token) + "\n"
    )
    out_str += (
        "window_rounds=" + String(LOSS_WINDOW_ROUNDS) + "\n"
    )
    out_str += (
        "losing_windows_consecutive="
        + String(guard.consecutive_losing_windows) + "\n"
    )
    out_str += (
        "last_window_rate_bp="
        + String(guard.last_window_rate_bp) + "\n"
    )
    out_str += (
        "last_window_net=" + String(guard.last_window_net)
        + "\n"
    )
    out_str += (
        "total_rounds=" + String(guard.total_rounds) + "\n"
    )
    out_str += (
        "total_drafted=" + String(guard.total_drafted) + "\n"
    )
    out_str += (
        "total_accepted=" + String(guard.total_accepted) + "\n"
    )
    out_str += (
        "total_emitted=" + String(guard.total_emitted) + "\n"
    )
    out_str += "total_cost=" + String(guard.total_cost) + "\n"
    out_str += (
        "total_value="
        + String(
            guard.total_emitted * guard.plain_cost_per_token
        )
        + "\n"
    )
    out_str += "total_net=" + String(guard.total_net())
    return out_str
