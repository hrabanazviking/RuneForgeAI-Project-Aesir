"""Speculative adaptive depth (J-079): the pre-registered
tuning rule's properties -- k starts at J-072's initial 4
and never leaves [1, the J-071 cap for the kind]; no
decision before a full 4-round window of evidence, however
hot the partial window; a near-saturated window (<= 2 wasted
in the window) deepens by exactly 2, a cold window
(<= 3000 bp) shallows by exactly 2 (inclusive); anything
else -- however warm -- holds; deepening at the cap and shallowing at the
floor are holds, never claimed moves; per-round hot/cold
alternation cannot move k (no pathological oscillation),
and a reversal needs a full opposite window; the rule read
off a J-075 ledger row through J-075's own rate gives the
same decisions, and a short row is pending; refusals
(inconsistent account, wrong-kind account, out-of-bounds
starts) leave the controller untouched; two controllers fed
the same accounts follow identical k trajectories, and a
long hot climb and a long cold fall clamp exactly at the
cap and the floor. Fixtures are synthetic accounts built
through J-071's plan_verify (SIMULATED): they prove the
rule's properties, never a model pair's acceptance. The
fixture-replay measurement against fixed k is filed
separately (docs/janas/j079_measurement.py); live-pair
tuning is NOT PROVEN (J-079 doc section 6).
"""
from core.speculative_acceptance import (
    LANG_ENGLISH,
    LANG_ITALIAN,
    LANG_NOT_APPLICABLE,
    PAIR_ID_QWEN3_06B_TO_4B,
    TEXT_CODE,
    TEXT_PROSE,
    AcceptanceLedger,
    record_round,
)
from core.speculative_adaptive import (
    ADAPT_COLD_BP,
    ADAPT_DEEPEN,
    ADAPT_DEEPEN_MAX_WASTED,
    ADAPT_HOLD,
    ADAPT_PENDING,
    ADAPT_SHALLOW,
    ADAPT_STEP,
    ADAPT_WINDOW_ROUNDS,
    AdaptiveDepth,
    adapt_decision_name,
    adaptive_initial,
    adaptive_next_k,
    adaptive_start,
    adaptive_window_rate_bp,
    decide_from_ledger_row,
    plan_adaptive_round,
    record_adaptive_round,
)
from core.speculative_verify import (
    PROPOSER_CONVERSATION,
    PROPOSER_CROSS_MODEL,
    PROPOSER_MTP_HEAD,
    VerifyAccount,
    plan_verify,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "SpeculativeAdaptive " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("SpeculativeAdaptive " + what + ": expected true")


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


def feed(
    mut state: AdaptiveDepth, k: Int, accepted_list: List[Int]
) raises -> Int:
    """Feed one stated window (or part of one); return the
    last round's decision."""
    var decision = ADAPT_PENDING
    for i in range(len(accepted_list)):
        var account = make_account(state.proposer_kind, k, accepted_list[i])
        decision = record_adaptive_round(state, account)
    return decision


def test_initial_and_bounds() raises:
    var s = adaptive_initial(PROPOSER_CROSS_MODEL)
    expect_eq(adaptive_next_k(s), 4, "initial k is J-072's LOOP_K_INITIAL")
    expect_eq(s.last_window_rate_bp, -1, "no window has closed yet")
    expect_eq(ADAPT_WINDOW_ROUNDS, 4, "window is the pre-registered 4")
    expect_eq(ADAPT_STEP, 2, "step is the pre-registered 2")
    # Out-of-bounds starts refused: 0, over the model cap,
    # over the conversation cap, unknown kind.
    var refused = 0
    try:
        _ = adaptive_start(PROPOSER_CROSS_MODEL, 0)
    except:
        refused += 1
    try:
        _ = adaptive_start(PROPOSER_CROSS_MODEL, 16)
    except:
        refused += 1
    try:
        _ = adaptive_start(PROPOSER_CONVERSATION, 9)
    except:
        refused += 1
    try:
        _ = adaptive_start(99, 4)
    except:
        refused += 1
    expect_eq(refused, 4, "out-of-bounds starts refused 4/4")
    # The conversation cap itself admits exactly.
    var conv = adaptive_start(PROPOSER_CONVERSATION, 8)
    expect_eq(adaptive_next_k(conv), 8, "conversation cap admits at 8")
    print("PASS: bounds -- initial k=4; floor/caps from J-071/J-072; bad starts refused 4/4")


def test_minimum_evidence() raises:
    var s = adaptive_initial(PROPOSER_CROSS_MODEL)
    # Three fully accepted rounds: as hot as a window can
    # look -- and still no decision, by the minimum-evidence
    # threshold.
    var hot3: List[Int] = [4, 4, 4]
    var d = feed(s, 4, hot3)
    expect_eq(d, ADAPT_PENDING, "three hot rounds are still pending")
    expect_eq(adaptive_next_k(s), 4, "k does not move before the window closes")
    expect_eq(s.windows_completed, 0, "no window completed")
    expect_eq(adaptive_window_rate_bp(s), 10000, "open-window rate reads exactly")
    var one: List[Int] = [4]
    d = feed(s, 4, one)
    expect_eq(d, ADAPT_DEEPEN, "the fourth hot round closes the window and deepens")
    expect_eq(adaptive_next_k(s), 6, "deepened by the step")
    print("PASS: minimum evidence -- 3 hot rounds pending, the 4th decides")


def test_deepen_on_hot() raises:
    var s = adaptive_initial(PROPOSER_CROSS_MODEL)
    # J-075's English-prose shape, first window: 15/16.
    var window: List[Int] = [4, 4, 3, 4]
    var d = feed(s, 4, window)
    expect_eq(d, ADAPT_DEEPEN, "hot window deepens")
    expect_eq(adaptive_next_k(s), 6, "deepen is exactly +2")
    expect_eq(s.last_window_rate_bp, 9375, "window rate exact")
    expect_eq(s.deepen_events, 1, "one deepen event")
    expect_eq(s.window_rounds, 0, "window counters reset at the decision")
    expect_eq(s.total_accepted, 15, "totals keep every round")
    expect_eq(s.total_drafted, 16, "totals keep every draft")
    print("PASS: deepen -- hot window (9375 bp) deepens 4 -> 6, window resets")


def test_shallow_on_cold() raises:
    var s = adaptive_start(PROPOSER_CROSS_MODEL, 6)
    var window: List[Int] = [1, 0, 1, 2]
    var d = feed(s, 6, window)
    expect_eq(d, ADAPT_SHALLOW, "cold window shallows")
    expect_eq(adaptive_next_k(s), 4, "shallow is exactly -2")
    expect_eq(s.last_window_rate_bp, 1666, "window rate exact (4/24)")
    expect_eq(s.shallow_events, 1, "one shallow event")
    print("PASS: shallow -- cold window (1666 bp) shallows 6 -> 4")


def test_hysteresis_deadband_holds() raises:
    var s = adaptive_initial(PROPOSER_CROSS_MODEL)
    var mid: List[Int] = [2, 3, 2, 1]
    var d = feed(s, 4, mid)
    expect_eq(d, ADAPT_HOLD, "mid window (5000 bp) holds")
    expect_eq(adaptive_next_k(s), 4, "deadband leaves k unchanged")
    # A warm-but-wasteful window: 11/16 = 6875 bp, 5 wasted.
    var under_hot: List[Int] = [3, 3, 2, 3]
    d = feed(s, 4, under_hot)
    expect_eq(d, ADAPT_HOLD, "6875 bp with 5 wasted is still the deadband")
    # Just over the cold edge: 7/16 = 4375 bp holds.
    var over_cold: List[Int] = [2, 2, 1, 2]
    d = feed(s, 4, over_cold)
    expect_eq(d, ADAPT_HOLD, "4375 bp is still the deadband")
    expect_eq(s.hold_events, 3, "three deadband holds")
    expect_true(
        adapt_decision_name(ADAPT_HOLD) == String("hold"), "decision names itself"
    )
    print("PASS: hysteresis -- deadband holds at 5000/6875/4375 bp (warm is not saturated)")


def test_thresholds_exact() raises:
    expect_eq(ADAPT_DEEPEN_MAX_WASTED, 2, "deepen allowance is the pre-registered 2")
    expect_eq(ADAPT_COLD_BP, 3000, "cold threshold is the pre-registered 3000")
    # At the deepen boundary: exactly 2 wasted in the
    # window deepens (14/16 = 8750 bp); 3 wasted holds even
    # at 8125 bp -- the rate alone never deepens.
    var edge = adaptive_initial(PROPOSER_CROSS_MODEL)
    var ew: List[Int] = [4, 4, 4, 2]
    var d = feed(edge, 4, ew)
    expect_eq(d, ADAPT_DEEPEN, "exactly 2 wasted deepens")
    var warm = adaptive_initial(PROPOSER_CROSS_MODEL)
    var ww: List[Int] = [4, 4, 4, 1]
    d = feed(warm, 4, ww)
    expect_eq(d, ADAPT_HOLD, "3 wasted holds at 8125 bp: rate alone never deepens")
    expect_eq(warm.last_window_rate_bp, 8125, "the warm window's rate is exact")
    # Exactly cold: 6/20 = 3000 bp shallows (inclusive edge).
    var cold = adaptive_start(PROPOSER_CROSS_MODEL, 5)
    var cw: List[Int] = [2, 1, 2, 1]
    d = feed(cold, 5, cw)
    expect_eq(d, ADAPT_SHALLOW, "exactly 3000 bp shallows")
    expect_eq(cold.last_window_rate_bp, 3000, "cold edge rate exact")
    print("PASS: thresholds exact -- 2 wasted deepens, 3 holds at 8125 bp; 3000 bp shallows")


def test_bounds_clamp_at_cap_and_floor() raises:
    # Deepening at the model cap is a hold, not a move.
    var capped = adaptive_start(PROPOSER_MTP_HEAD, 15)
    var full: List[Int] = [15, 15, 15, 15]
    var d = feed(capped, 15, full)
    expect_eq(d, ADAPT_HOLD, "deepen at the cap holds")
    expect_eq(adaptive_next_k(capped), 15, "k never exceeds the cap")
    expect_eq(capped.deepen_events, 0, "no deepen event claimed at the cap")
    expect_eq(capped.hold_events, 1, "the cap decision counts as a hold")
    # A step that would overshoot the conversation cap clamps to it.
    var conv = adaptive_start(PROPOSER_CONVERSATION, 7)
    var conv_full: List[Int] = [7, 7, 7, 7]
    d = feed(conv, 7, conv_full)
    expect_eq(d, ADAPT_DEEPEN, "hot window under the cap deepens")
    expect_eq(adaptive_next_k(conv), 8, "deepen clamps exactly at the cap 8")
    # Shallowing at the floor is a hold; a step past it clamps to it.
    var floored = adaptive_start(PROPOSER_CROSS_MODEL, 1)
    var zero: List[Int] = [0, 0, 0, 0]
    d = feed(floored, 1, zero)
    expect_eq(d, ADAPT_HOLD, "shallow at the floor holds")
    expect_eq(adaptive_next_k(floored), 1, "k never goes below the floor")
    var three = adaptive_start(PROPOSER_CROSS_MODEL, 3)
    var zero3: List[Int] = [0, 0, 0, 0]
    d = feed(three, 3, zero3)
    expect_eq(d, ADAPT_SHALLOW, "cold window above the floor shallows")
    expect_eq(adaptive_next_k(three), 1, "shallow clamps exactly at the floor 1")
    print("PASS: bounds clamp -- cap/floor are holds there; steps clamp exactly to them")


def test_no_pathological_oscillation() raises:
    var s = adaptive_initial(PROPOSER_CROSS_MODEL)
    # The fastest possible alternation -- a fully accepted
    # round, then a zero round, repeating -- is a 5000 bp
    # window: the deadband. Three windows of it never move k.
    for _ in range(3):
        var alt: List[Int] = [4, 0, 4, 0]
        var d = feed(s, 4, alt)
        expect_eq(d, ADAPT_HOLD, "alternating window holds")
    expect_eq(adaptive_next_k(s), 4, "alternation never moved k")
    expect_eq(
        s.deepen_events + s.shallow_events, 0, "no moves under alternation"
    )
    # A reversal needs a full opposite window: one hot
    # window deepens, one cold window shallows back -- two
    # moves over eight rounds, never one per round.
    var hot: List[Int] = [4, 4, 4, 4]
    _ = feed(s, 4, hot)
    expect_eq(adaptive_next_k(s), 6, "a full hot window deepens")
    var cold: List[Int] = [0, 1, 0, 1]
    var d2 = feed(s, 6, cold)
    expect_eq(d2, ADAPT_SHALLOW, "a full cold window is required to reverse")
    expect_eq(adaptive_next_k(s), 4, "the reversal lands one step back")
    expect_eq(s.windows_completed, 5, "five windows, at most one move each")
    print("PASS: no pathological oscillation -- alternation holds; reversal needs a full opposite window")


def test_ledger_row_binding() raises:
    # J-075's filed SIMULATED fixture, recorded through the
    # ledger itself, then read back through this rule.
    var ledger = AcceptanceLedger()
    var en: List[Int] = [4, 4, 3, 4, 3, 4, 4, 3, 4, 1]
    for i in range(len(en)):
        var account = make_account(PROPOSER_CROSS_MODEL, 4, en[i])
        record_round(
            ledger, PAIR_ID_QWEN3_06B_TO_4B, TEXT_PROSE, LANG_ENGLISH, account
        )
    var it: List[Int] = [2, 1, 1, 2, 1, 0, 2, 1, 1, 1]
    for i in range(len(it)):
        var account2 = make_account(PROPOSER_CROSS_MODEL, 4, it[i])
        record_round(
            ledger, PAIR_ID_QWEN3_06B_TO_4B, TEXT_PROSE, LANG_ITALIAN, account2
        )
    var code: List[Int] = [4, 3, 4, 4, 2, 4, 3, 4, 4, 4]
    for i in range(len(code)):
        var account3 = make_account(PROPOSER_CROSS_MODEL, 4, code[i])
        record_round(
            ledger,
            PAIR_ID_QWEN3_06B_TO_4B,
            TEXT_CODE,
            LANG_NOT_APPLICABLE,
            account3,
        )
    var en_row = ledger.rows[
        ledger.find_row(
            PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ENGLISH
        )
    ].copy()
    var en_decision = decide_from_ledger_row(PROPOSER_CROSS_MODEL, 4, en_row)
    expect_eq(en_decision.decision, ADAPT_HOLD, "english row (8500 bp, 6 wasted over 10) holds: warm is not saturated")
    expect_eq(en_decision.next_k, 4, "english row next k unchanged")
    expect_eq(en_decision.rate_bp, 8500, "rate is J-075's own, not restated")
    var it_row = ledger.rows[
        ledger.find_row(
            PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ITALIAN
        )
    ].copy()
    var it_decision = decide_from_ledger_row(PROPOSER_CROSS_MODEL, 4, it_row)
    expect_eq(it_decision.decision, ADAPT_SHALLOW, "italian row (3000 bp) shallows")
    expect_eq(it_decision.next_k, 2, "italian row next k")
    var code_row = ledger.rows[
        ledger.find_row(
            PROPOSER_CROSS_MODEL, 1, TEXT_CODE, LANG_NOT_APPLICABLE
        )
    ].copy()
    var code_decision = decide_from_ledger_row(PROPOSER_CROSS_MODEL, 4, code_row)
    expect_eq(code_decision.rate_bp, 9000, "code row rate exact")
    expect_eq(code_decision.decision, ADAPT_DEEPEN, "code row deepens")
    # A row short of the window is pending, at any rate.
    var short_ledger = AcceptanceLedger()
    for i in range(3):
        var account4 = make_account(PROPOSER_CROSS_MODEL, 4, 4)
        record_round(
            short_ledger, 1, TEXT_PROSE, LANG_ENGLISH, account4
        )
    var short_row = short_ledger.rows[
        short_ledger.find_row(PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ENGLISH)
    ].copy()
    var short_decision = decide_from_ledger_row(
        PROPOSER_CROSS_MODEL, 4, short_row
    )
    expect_eq(short_decision.decision, ADAPT_PENDING, "a 3-round row is pending")
    expect_eq(short_decision.rate_bp, -1, "a pending row states no rate")
    # A row of another kind refuses.
    var refused = False
    try:
        _ = decide_from_ledger_row(PROPOSER_MTP_HEAD, 4, en_row)
    except:
        refused = True
    expect_true(refused, "a row of another kind refuses")
    print("PASS: ledger binding -- J-075 rows decide via J-075's rate; short row pending; wrong kind refused")


def test_refusals_leave_state_untouched() raises:
    var s = adaptive_initial(PROPOSER_CROSS_MODEL)
    var two: List[Int] = [3, 4]
    _ = feed(s, 4, two)
    # An inconsistent account (tampered KV advance) refuses.
    var broken = make_account(PROPOSER_CROSS_MODEL, 4, 4)
    broken.kv_after += 1
    var refused = 0
    try:
        _ = record_adaptive_round(s, broken)
    except:
        refused += 1
    # An account of another proposer kind refuses.
    var foreign = make_account(PROPOSER_MTP_HEAD, 4, 4)
    try:
        _ = record_adaptive_round(s, foreign)
    except:
        refused += 1
    expect_eq(refused, 2, "inconsistent and foreign accounts refused 2/2")
    expect_eq(s.total_rounds, 2, "refusals consumed no rounds")
    expect_eq(s.window_rounds, 2, "the open window is exactly as it was")
    expect_eq(adaptive_next_k(s), 4, "refusals never move k")
    # An empty window has no rate.
    var fresh = adaptive_initial(PROPOSER_CROSS_MODEL)
    var rate_refused = False
    try:
        _ = adaptive_window_rate_bp(fresh)
    except:
        rate_refused = True
    expect_true(rate_refused, "an empty window's rate refuses")
    print("PASS: refusals -- inconsistent/foreign accounts leave the controller untouched")


def test_determinism_trajectory_and_planning() raises:
    # The same account sequence through two fresh
    # controllers: identical trajectories, exactly.
    var seq_k: List[Int] = [4, 4, 4, 4, 6, 6, 6, 6, 8, 8, 8, 8]
    var seq_a: List[Int] = [4, 4, 3, 4, 6, 5, 6, 6, 8, 8, 7, 8]
    var a = adaptive_initial(PROPOSER_CROSS_MODEL)
    var b = adaptive_initial(PROPOSER_CROSS_MODEL)
    for i in range(len(seq_k)):
        var acc_a = make_account(PROPOSER_CROSS_MODEL, seq_k[i], seq_a[i])
        _ = record_adaptive_round(a, acc_a)
        var acc_b = make_account(PROPOSER_CROSS_MODEL, seq_k[i], seq_a[i])
        _ = record_adaptive_round(b, acc_b)
        expect_eq(
            adaptive_next_k(a),
            adaptive_next_k(b),
            "identical evidence, identical k at every round",
        )
    expect_eq(adaptive_next_k(a), 10, "the hot trajectory climbs 4 -> 6 -> 8 -> 10")
    expect_eq(a.deepen_events, 3, "three windows, three deepens")
    # A long cold fall clamps at the floor and stays there.
    var fall = adaptive_start(PROPOSER_CROSS_MODEL, 5)
    for _ in range(4):
        var cold_window: List[Int] = [0, 1, 0, 0]
        _ = feed(fall, adaptive_next_k(fall), cold_window)
    expect_eq(adaptive_next_k(fall), 1, "the cold fall lands on the floor and holds")
    # Planning binds J-072: the controller's k, shortened
    # explicitly for capacity, its own k unchanged.
    var planned_state = adaptive_initial(PROPOSER_CROSS_MODEL)
    var plan = plan_adaptive_round(planned_state, 509, 512)
    expect_eq(plan.requested_k, 4, "the plan requests the controller's k")
    expect_eq(plan.planned_k, 2, "capacity shortens the plan to 2")
    expect_true(plan.shortened_for_capacity, "the shortening is on record")
    expect_eq(adaptive_next_k(planned_state), 4, "planning never moves the controller")
    print("PASS: determinism -- identical trajectories; hot climb and cold fall clamp; J-072 planning bound")


def main() raises:
    test_initial_and_bounds()
    test_minimum_evidence()
    test_deepen_on_hot()
    test_shallow_on_cold()
    test_hysteresis_deadband_holds()
    test_thresholds_exact()
    test_bounds_clamp_at_cap_and_floor()
    test_no_pathological_oscillation()
    test_ledger_row_binding()
    test_refusals_leave_state_untouched()
    test_determinism_trajectory_and_planning()
    print("ALL PASS: speculative adaptive depth (11 groups)")
