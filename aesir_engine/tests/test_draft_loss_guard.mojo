"""Draft loss guard (J-084): the pre-registered disable
rule's properties -- one guard per J-075 row (kind, pair,
text type, language), validated by J-075's own rules; no
decision before a full 4-round window (J-079's quantum);
a window is losing iff its net < 0 in the host-stated
currency (break-even, net == 0, never loses); ONE losing
window holds, TWO consecutive losing windows disable at
exactly the closing round; a winning or break-even window
resets the consecutive count; disabling is for the
session (further rounds refused by name); the disable
record's fields are pinned byte-for-byte; and the SAME
acceptance stream disables under one pair's stated costs
and survives under another's -- the guard follows costs,
not acceptance alone.

Fixtures are stated shapes traceable to filed numbers,
never measurements (SIMULATED): the Italian-prose stream
is J-075's filed fixture row (cross-model pair 1, k = 4,
12 accepted of 40 drafted over 10 rounds, histogram
1 x 0 / 6 x 1 / 3 x 2, rate 3000 bp); the English-prose
stream is J-075's English row (34 of 40, six fully
accepted rounds); the boundary stream sits exactly on
the worst-case floor derived in the J-084 doc section 1
(accepted 2 of 4 every round, 5000 bp); the byte stream
prices its rounds from J-080's filed cold tax at k = 2
(+47.10 % per emitted token at the 128-pair budget: a
speculative token costs 14710 units where a plain token
costs 10000). Stated round costs in the step fixtures are
the doc's step form: one verify pass at the plain price
(100) plus k draft steps at 50 (the worst-case admissible
drafter, J-074's half-bytes bound, r = 1/2) = 300, or at
15 (the first pair's 0.6B / 4B ratio, r = 3/20) = 160.
Live disabling is NOT PROVEN (J-084 doc section 6).
"""
from core.draft_loss_guard import (
    DISABLE_REASON,
    GUARD_DISABLED,
    GUARD_HOLD,
    GUARD_PENDING,
    LOSS_DISABLE_WINDOWS,
    LOSS_WINDOW_ROUNDS,
    LossGuard,
    disable_record_text,
    guard_decision_name,
    loss_guard_disabled,
    loss_guard_start,
    record_loss_round,
)
from core.speculative_acceptance import (
    LANG_ENGLISH,
    LANG_ITALIAN,
    LANG_NOT_APPLICABLE,
    TEXT_CODE,
    TEXT_PROSE,
)
from core.speculative_verify import (
    PROPOSER_CROSS_MODEL,
    PROPOSER_MTP_HEAD,
    VerifyAccount,
    plan_verify,
)

# Stated fixture prices (header): plain token 100 units;
# a k = 4 round at 300 (worst-case admissible drafter) or
# 160 (the first pair's step ratio).
comptime PLAIN = 100
comptime COST_WORST = 300
comptime COST_FIRST = 160


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "DraftLossGuard " + what + ": expected "
            + String(expected) + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("DraftLossGuard " + what + ": expected true")


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "DraftLossGuard " + what + ":\nexpected:\n" + expected
            + "\ngot:\n" + actual
        )


def make_account(kind: Int, k: Int, accepted: Int) raises -> VerifyAccount:
    """A synthetic round through J-071's plan_verify: the
    draft matches the target for exactly `accepted`
    positions, then diverges."""
    var target = List[Int]()
    for i in range(k + 1):
        target.append(100 + i)
    var draft = List[Int]()
    for i in range(k):
        if i < accepted:
            draft.append(100 + i)
        else:
            draft.append(900 + i)
    return plan_verify(kind, draft, target, 0, 512, 0, 0)


def italian_guard(cost_plain: Int) raises -> LossGuard:
    """The J-075 Italian-prose row's guard: cross-model
    pair 1, prose, italian."""
    return loss_guard_start(
        PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ITALIAN, cost_plain
    )


def feed(
    mut guard: LossGuard, k: Int, accepted_list: List[Int], round_cost: Int
) raises -> Int:
    """Feed stated rounds at one stated cost; return the
    last round's decision."""
    var decision = GUARD_PENDING
    for i in range(len(accepted_list)):
        var account = make_account(guard.proposer_kind, k, accepted_list[i])
        decision = record_loss_round(guard, account, round_cost)
    return decision


def italian_ten() -> List[Int]:
    """J-075's Italian fixture, round by round: accepted
    counts summing to 12 over 10 rounds at k = 4, with the
    filed histogram (one 0, six 1s, three 2s, no 4s)."""
    var seq = List[Int]()
    seq.append(0)
    seq.append(1)
    seq.append(1)
    seq.append(1)
    seq.append(1)
    seq.append(1)
    seq.append(2)
    seq.append(2)
    seq.append(2)
    seq.append(1)
    return seq^


def english_ten() -> List[Int]:
    """J-075's English fixture: 34 accepted over 10 rounds
    at k = 4, six of them fully accepted."""
    var seq = List[Int]()
    for _ in range(6):
        seq.append(4)
    seq.append(3)
    seq.append(3)
    seq.append(2)
    seq.append(2)
    return seq^


def test_start_validation() raises:
    var g = italian_guard(PLAIN)
    expect_true(not loss_guard_disabled(g), "a fresh guard is active")
    expect_eq(g.last_window_rate_bp, -1, "no window has closed yet")
    expect_eq(LOSS_WINDOW_ROUNDS, 4, "window is J-079's 4, imported")
    expect_eq(LOSS_DISABLE_WINDOWS, 2, "two losing windows disable")
    expect_str(String(DISABLE_REASON), "DISABLE_SUSTAINED_LOSS", "reason name")
    expect_str(guard_decision_name(GUARD_PENDING), "pending", "decision name")
    expect_str(guard_decision_name(GUARD_DISABLED), "disabled", "decision name")
    # A head-proposer row (pair id 0) and a code row
    # (language not_applicable) both start cleanly.
    _ = loss_guard_start(
        PROPOSER_MTP_HEAD, 0, TEXT_PROSE, LANG_ENGLISH, PLAIN
    )
    _ = loss_guard_start(
        PROPOSER_CROSS_MODEL, 1, TEXT_CODE, LANG_NOT_APPLICABLE, PLAIN
    )
    var refused = 0
    try:
        _ = loss_guard_start(PROPOSER_MTP_HEAD, 1, TEXT_PROSE, LANG_ENGLISH, PLAIN)
    except:
        refused += 1
    try:
        _ = loss_guard_start(PROPOSER_CROSS_MODEL, 0, TEXT_PROSE, LANG_ITALIAN, PLAIN)
    except:
        refused += 1
    try:
        _ = loss_guard_start(PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_NOT_APPLICABLE, PLAIN)
    except:
        refused += 1
    try:
        _ = loss_guard_start(PROPOSER_CROSS_MODEL, 1, TEXT_CODE, LANG_ENGLISH, PLAIN)
    except:
        refused += 1
    try:
        _ = loss_guard_start(PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ITALIAN, 0)
    except:
        refused += 1
    try:
        _ = loss_guard_start(99, 0, TEXT_PROSE, LANG_ENGLISH, PLAIN)
    except:
        refused += 1
    expect_eq(refused, 6, "start refusals (pair/language/price/kind) 6/6")
    print("PASS: start validation -- row keys by J-075's rules; refusals 6/6")


def test_minimum_evidence() raises:
    var g = italian_guard(PLAIN)
    var seq = italian_ten()
    var first = List[Int]()
    for i in range(3):
        first.append(seq[i])
    var d = feed(g, 4, first, COST_WORST)
    expect_eq(d, GUARD_PENDING, "three losing-looking rounds still pending")
    expect_eq(g.windows_completed, 0, "no window has closed")
    expect_true(not loss_guard_disabled(g), "a partial window disables nothing")
    var fourth = List[Int]()
    fourth.append(seq[3])
    d = feed(g, 4, fourth, COST_WORST)
    expect_eq(d, GUARD_HOLD, "the first losing window holds, never disables")
    expect_eq(g.windows_completed, 1, "one window closed")
    expect_eq(g.consecutive_losing_windows, 1, "one consecutive losing window")
    expect_eq(g.last_window_net, -500, "window 1 net (7 emitted x 100 - 1200)")
    expect_eq(g.last_window_rate_bp, 1875, "window 1 rate (3 of 16)")
    expect_true(not loss_guard_disabled(g), "one losing window is not a disable")
    print("PASS: minimum evidence -- pending until the window closes; one losing window holds")


def test_losing_stream_disables_at_round_eight() raises:
    var g = italian_guard(PLAIN)
    var seq = italian_ten()
    var first_eight = List[Int]()
    for i in range(8):
        first_eight.append(seq[i])
    var decisions = List[Int]()
    for i in range(8):
        var one = List[Int]()
        one.append(first_eight[i])
        decisions.append(feed(g, 4, one, COST_WORST))
    expect_eq(decisions[3], GUARD_HOLD, "round 4 closes losing window 1 as hold")
    expect_eq(decisions[7], GUARD_DISABLED, "round 8 closes losing window 2 as disable")
    expect_true(loss_guard_disabled(g), "the guard is disabled")
    expect_eq(g.disabled_at_round, 8, "disabled at exactly round 8")
    expect_eq(g.total_rounds, 8, "totals: rounds")
    expect_eq(g.total_drafted, 32, "totals: drafted (8 x k=4)")
    expect_eq(g.total_accepted, 9, "totals: accepted (3 + 6)")
    expect_eq(g.total_emitted, 17, "totals: emitted (accepted + rounds)")
    expect_eq(g.total_cost, 2400, "totals: cost (8 x 300)")
    expect_eq(g.total_net(), -700, "totals: net (1700 - 2400)")
    expect_eq(g.last_window_net, -200, "window 2 net (10 x 100 - 1200)")
    expect_eq(g.last_window_rate_bp, 3750, "window 2 rate (6 of 16)")
    expect_eq(g.losing_windows, 2, "both windows were losing")
    print("PASS: losing stream -- the Italian shape disables at exactly round 8")


def test_disable_record_pinned() raises:
    var g = italian_guard(PLAIN)
    # No record exists before the disable.
    var refused = False
    try:
        _ = disable_record_text(g)
    except:
        refused = True
    expect_true(refused, "the record is refused before any disable")
    var seq = italian_ten()
    var first_eight = List[Int]()
    for i in range(8):
        first_eight.append(seq[i])
    _ = feed(g, 4, first_eight, COST_WORST)
    var expected = String("draft-loss-disable:\n")
    expected += "event=drafts_disabled\n"
    expected += "reason=DISABLE_SUSTAINED_LOSS\n"
    expected += "proposer_kind=cross_model\n"
    expected += "pair_id=1\n"
    expected += "text_type=prose\n"
    expected += "language=italian\n"
    expected += "disabled_at_round=8\n"
    expected += "posture=disabled for the session; re-enable only by a new session or a new configuration (host act)\n"
    expected += "plain_cost_per_token=100\n"
    expected += "window_rounds=4\n"
    expected += "losing_windows_consecutive=2\n"
    expected += "last_window_rate_bp=3750\n"
    expected += "last_window_net=-200\n"
    expected += "total_rounds=8\n"
    expected += "total_drafted=32\n"
    expected += "total_accepted=9\n"
    expected += "total_emitted=17\n"
    expected += "total_cost=2400\n"
    expected += "total_value=1700\n"
    expected += "total_net=-700"
    expect_str(disable_record_text(g), expected, "the disable record, byte for byte")
    print("PASS: disable record -- every field pinned; refused before the disable")


def test_winning_stream_never_disables() raises:
    var g = loss_guard_start(
        PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ENGLISH, PLAIN
    )
    var d = feed(g, 4, english_ten(), COST_WORST)
    expect_eq(d, GUARD_PENDING, "round 10 leaves a partial window pending")
    expect_true(not loss_guard_disabled(g), "the English shape never disables")
    expect_eq(g.windows_completed, 2, "two windows closed, both winning")
    expect_eq(g.consecutive_losing_windows, 0, "no losing streak")
    expect_eq(g.losing_windows, 0, "no losing window at all")
    expect_eq(g.total_accepted, 34, "J-075's English total, reproduced")
    expect_eq(g.total_emitted, 44, "emitted (34 + 10 rounds)")
    expect_eq(g.total_net(), 1400, "net (4400 - 3000) at worst-case costs")
    print("PASS: winning stream -- English prose at worst-case costs never disables")


def test_boundary_stream_breaks_even() raises:
    var g = italian_guard(PLAIN)
    var twos = List[Int]()
    for _ in range(12):
        twos.append(2)
    _ = feed(g, 4, twos, COST_WORST)
    expect_true(not loss_guard_disabled(g), "break-even never disables")
    expect_eq(g.windows_completed, 3, "three windows closed")
    expect_eq(g.losing_windows, 0, "net == 0 is not a losing window")
    expect_eq(g.last_window_net, 0, "the boundary window nets exactly zero")
    expect_eq(g.last_window_rate_bp, 5000, "the boundary rate is the 5000 bp floor")
    expect_eq(g.total_net(), 0, "the stream as a whole breaks even")
    print("PASS: boundary stream -- exactly at the floor, net zero, holds forever")


def test_hysteresis_alternation() raises:
    var g = italian_guard(PLAIN)
    var italian_window = List[Int]()
    italian_window.append(0)
    italian_window.append(1)
    italian_window.append(1)
    italian_window.append(1)
    var english_window = List[Int]()
    for _ in range(4):
        english_window.append(4)
    _ = feed(g, 4, italian_window, COST_WORST)
    expect_eq(g.consecutive_losing_windows, 1, "losing window 1")
    _ = feed(g, 4, english_window, COST_WORST)
    expect_eq(g.consecutive_losing_windows, 0, "a winning window resets the streak")
    _ = feed(g, 4, italian_window, COST_WORST)
    expect_eq(g.consecutive_losing_windows, 1, "the streak restarts at 1")
    expect_true(not loss_guard_disabled(g), "alternation never disables")
    var d = feed(g, 4, italian_window, COST_WORST)
    expect_eq(d, GUARD_DISABLED, "the second consecutive losing window disables")
    expect_eq(g.disabled_at_round, 16, "disabled at round 16, not before")
    print("PASS: hysteresis -- alternation resets; two in a row disable at round 16")


def test_same_stream_first_pair_costs_survive() raises:
    var g = italian_guard(PLAIN)
    var d = feed(g, 4, italian_ten(), COST_FIRST)
    expect_eq(d, GUARD_PENDING, "round 10 pending, as any stream's is")
    expect_true(
        not loss_guard_disabled(g),
        "the Italian shape at the first pair's step costs never disables",
    )
    expect_eq(g.losing_windows, 0, "both closed windows were winning on steps")
    expect_eq(g.total_accepted, 12, "J-075's Italian total, reproduced")
    expect_eq(g.total_net(), 600, "net (2200 - 1600) at first-pair costs")
    print("PASS: cost sensitivity -- same Italian stream, first-pair costs, no disable")


def test_byte_currency_loss() raises:
    # J-080's filed cold tax at k = 2, 128-pair budget:
    # +47.10 % per emitted token, so a speculative token
    # costs 14710 units where a plain token costs 10000.
    var g = loss_guard_start(
        PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ITALIAN, 10000
    )
    var cycle = List[Int]()
    cycle.append(1)
    cycle.append(0)
    cycle.append(2)
    cycle.append(1)
    var decision = GUARD_PENDING
    for _ in range(2):
        for i in range(4):
            var account = make_account(PROPOSER_CROSS_MODEL, 2, cycle[i])
            var emitted = cycle[i] + 1
            decision = record_loss_round(g, account, emitted * 14710)
    expect_eq(decision, GUARD_DISABLED, "the byte-priced cold stream disables")
    expect_eq(g.disabled_at_round, 8, "disabled at round 8 on bytes too")
    expect_eq(g.total_drafted, 16, "drafted (8 x k=2)")
    expect_eq(g.total_accepted, 8, "accepted (two cold cycles)")
    expect_eq(g.total_emitted, 16, "emitted")
    expect_eq(g.total_cost, 235360, "cost (16 tokens x 14710)")
    expect_eq(g.total_net(), -75360, "net (160000 - 235360)")
    print("PASS: byte currency -- J-080's cold tax priced per round disables at round 8")


def test_row_separation() raises:
    var italian = italian_guard(PLAIN)
    var english = loss_guard_start(
        PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ENGLISH, PLAIN
    )
    var code = loss_guard_start(
        PROPOSER_CROSS_MODEL, 1, TEXT_CODE, LANG_NOT_APPLICABLE, PLAIN
    )
    var it = italian_ten()
    var en = english_ten()
    for i in range(8):
        var one_it = List[Int]()
        one_it.append(it[i])
        _ = feed(italian, 4, one_it, COST_WORST)
        var one_en = List[Int]()
        one_en.append(en[i])
        _ = feed(english, 4, one_en, COST_WORST)
        var one_code = List[Int]()
        one_code.append(4)
        _ = feed(code, 4, one_code, COST_WORST)
    expect_true(loss_guard_disabled(italian), "the italian row disabled")
    expect_true(not loss_guard_disabled(english), "the english row still drafts")
    expect_true(not loss_guard_disabled(code), "the code row still drafts")
    print("PASS: row separation -- italian disables; english and code rows unaffected")


def test_refusals_leave_state_untouched() raises:
    var g = italian_guard(PLAIN)
    var refused = 0
    var bad = make_account(PROPOSER_CROSS_MODEL, 4, 2)
    bad.accepted_count = 99
    try:
        _ = record_loss_round(g, bad, COST_WORST)
    except:
        refused += 1
    try:
        var wrong = make_account(PROPOSER_MTP_HEAD, 4, 2)
        _ = record_loss_round(g, wrong, COST_WORST)
    except:
        refused += 1
    try:
        var good = make_account(PROPOSER_CROSS_MODEL, 4, 2)
        _ = record_loss_round(g, good, -1)
    except:
        refused += 1
    expect_eq(refused, 3, "round refusals (inconsistent/wrong kind/negative cost) 3/3")
    expect_eq(g.total_rounds, 0, "a refused round consumes nothing")
    expect_eq(g.total_cost, 0, "a refused cost is never booked")
    # A disabled guard refuses further rounds, by name.
    var seq = italian_ten()
    var first_eight = List[Int]()
    for i in range(8):
        first_eight.append(seq[i])
    _ = feed(g, 4, first_eight, COST_WORST)
    expect_true(loss_guard_disabled(g), "disabled before the refusal check")
    var late_refused = False
    try:
        var late = make_account(PROPOSER_CROSS_MODEL, 4, 4)
        _ = record_loss_round(g, late, COST_WORST)
    except:
        late_refused = True
    expect_true(late_refused, "a disabled guard refuses further rounds")
    expect_eq(g.total_rounds, 8, "the disabled guard's account stays frozen")
    print("PASS: refusals -- bad rounds consume nothing; a disabled guard refuses loudly")


def test_determinism() raises:
    var a = italian_guard(PLAIN)
    var b = italian_guard(PLAIN)
    var seq = italian_ten()
    var first_eight = List[Int]()
    for i in range(8):
        first_eight.append(seq[i])
    _ = feed(a, 4, first_eight, COST_WORST)
    _ = feed(b, 4, first_eight, COST_WORST)
    expect_eq(a.disabled_at_round, b.disabled_at_round, "same disabling round")
    expect_str(
        disable_record_text(a), disable_record_text(b),
        "identical streams file identical records",
    )
    print("PASS: determinism -- identical streams, identical records")


def main() raises:
    test_start_validation()
    test_minimum_evidence()
    test_losing_stream_disables_at_round_eight()
    test_disable_record_pinned()
    test_winning_stream_never_disables()
    test_boundary_stream_breaks_even()
    test_hysteresis_alternation()
    test_same_stream_first_pair_costs_survive()
    test_byte_currency_loss()
    test_row_separation()
    test_refusals_leave_state_untouched()
    test_determinism()
    print("ALL PASS: draft loss guard (12 groups)")
