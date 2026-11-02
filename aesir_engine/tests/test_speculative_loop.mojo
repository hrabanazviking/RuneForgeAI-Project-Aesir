"""Speculative draft loop (J-072): proposer-slot dispatch;
one round's propose -> verify -> accept-prefix-plus-one ->
exact rollback of KV, context, proposer KV, and RNG word
asserted against the snapshot; k planning under the band,
the proposer caps, and the KV capacity (explicit shortening,
never silent truncation; refusal where nothing fits); the
adaptation shape's stated bounds; the legacy draft bound
reconciled in code (hard limit 15, default 4 retained as the
loop's initial k); multi-round driving whose emission is
token-identical to plain greedy, across adversarial drafts
and across slot switches; and refused rounds leaving the
state exactly at its snapshot. No forward runs: the token
lists below are stated fixtures checking the loop machinery
only -- live identity over real generations is J-073.
"""
from core.speculative import SpeculativeEngine, DraftProposal
from core.speculative_loop import (
    LOOP_K_INITIAL,
    LOOP_K_MAX_CONVERSATION,
    LOOP_K_MAX_MODEL,
    LOOP_K_MIN,
    LoopState,
    dispatch_proposer,
    plan_round_k,
    run_loop,
    run_loop_round,
    suggest_next_k,
)
from core.speculative_verify import (
    PROPOSER_ASSISTANT_MODEL,
    PROPOSER_CONVERSATION,
    PROPOSER_CROSS_MODEL,
    PROPOSER_MTP_HEAD,
    SLOT_CONVERSATION,
    SLOT_CROSS_MODEL,
    SLOT_HEAD,
    sequences_identical,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "SpeculativeLoop " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("SpeculativeLoop " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("SpeculativeLoop " + what + ": expected false")


def test_slot_dispatch() raises:
    var head_mtp = dispatch_proposer(SLOT_HEAD, PROPOSER_MTP_HEAD)
    expect_eq(head_mtp.max_k, LOOP_K_MAX_MODEL, "head/MTP cap")
    var head_asst = dispatch_proposer(SLOT_HEAD, PROPOSER_ASSISTANT_MODEL)
    expect_eq(head_asst.max_k, LOOP_K_MAX_MODEL, "head/assistant cap")
    var cross = dispatch_proposer(SLOT_CROSS_MODEL, PROPOSER_CROSS_MODEL)
    expect_true(cross.carries_own_kv, "cross-model carries its own KV")
    var conv = dispatch_proposer(SLOT_CONVERSATION, PROPOSER_CONVERSATION)
    expect_eq(conv.max_k, LOOP_K_MAX_CONVERSATION, "conversation cap")
    var refused = 0
    try:
        _ = dispatch_proposer(SLOT_HEAD, PROPOSER_CROSS_MODEL)
    except:
        refused += 1
    try:
        _ = dispatch_proposer(SLOT_CROSS_MODEL, PROPOSER_CONVERSATION)
    except:
        refused += 1
    try:
        _ = dispatch_proposer(SLOT_CONVERSATION, PROPOSER_MTP_HEAD)
    except:
        refused += 1
    try:
        _ = dispatch_proposer(99, PROPOSER_MTP_HEAD)
    except:
        refused += 1
    expect_eq(refused, 4, "wrong-slot dispatch refusal count")
    print("PASS: slot dispatch -- three slots, four kinds, wrong slots refused (4/4)")


def test_round_all_accepted() raises:
    var state = LoopState(512, 67, 67, UInt64(424242), 67)
    var drafts: List[Int] = [10, 11, 12, 13]
    var target: List[Int] = [10, 11, 12, 13, 14]
    var a = run_loop_round(state, SLOT_HEAD, PROPOSER_MTP_HEAD, drafts, target, 0)
    expect_eq(a.accepted_count, 4, "all accepted")
    expect_eq(state.kv_length, 72, "KV commits prefix + bonus")
    expect_eq(state.context_count, 72, "context commits with KV")
    expect_eq(state.draft_kv_length, 67, "head proposer carries no KV: untouched")
    expect_true(state.rng_word == UInt64(424242), "RNG word is the snapshot's")
    expect_eq(len(state.emitted), 5, "emitted appended from the account")
    expect_eq(state.emitted[4], 14, "bonus is the target's token")
    print("PASS: all-accepted round -- commit exact, no rollback, RNG word intact")


def test_round_partial_rollback_exact() raises:
    var state = LoopState(512, 40, 40, UInt64(7), 40)
    var drafts: List[Int] = [10, 11, 99, 13]
    var target: List[Int] = [10, 11, 12, 13, 14]
    var a = run_loop_round(
        state, SLOT_CROSS_MODEL, PROPOSER_CROSS_MODEL, drafts, target, 0
    )
    expect_eq(a.accepted_count, 2, "accepted prefix")
    expect_eq(a.kv_rows_to_roll_back, 2, "rollback rows")
    # Tentative advance was 40 + 5 = 45; rollback of 2 lands
    # exactly at snapshot + accepted + 1 = 43, in both the
    # target's lengths and the proposer's own KV.
    expect_eq(state.kv_length, 43, "KV after exact rollback")
    expect_eq(state.context_count, 43, "context after exact rollback")
    expect_eq(state.draft_kv_length, 42, "proposer KV keeps only the accepted prefix")
    expect_eq(state.emitted[2], 12, "correction is the target's token")
    print("PASS: partial round -- KV/context/proposer-KV rollback exact vs snapshot")


def test_round_zero_accepted_rollback() raises:
    var state = LoopState(512, 3, 3, UInt64(9), 3)
    var drafts: List[Int] = [77, 78]
    var target: List[Int] = [10, 11, 12]
    var a = run_loop_round(
        state, SLOT_CROSS_MODEL, PROPOSER_CROSS_MODEL, drafts, target, 0
    )
    expect_eq(a.accepted_count, 0, "nothing accepted")
    expect_eq(state.kv_length, 4, "KV advances by the one correction only")
    expect_eq(state.draft_kv_length, 3, "proposer KV fully rolled back")
    expect_eq(len(state.emitted), 1, "exactly one emission")
    print("PASS: zero-accepted round -- whole draft rolls back, one target token commits")


def test_k_plan_bounds_and_caps() raises:
    var plan = plan_round_k(PROPOSER_MTP_HEAD, LOOP_K_INITIAL, 0, 512)
    expect_eq(plan.planned_k, 4, "initial k planned at an empty cache")
    expect_false(plan.shortened_for_capacity, "no shortening at an empty cache")
    var refused = 0
    try:
        _ = plan_round_k(PROPOSER_MTP_HEAD, 0, 0, 512)
    except:
        refused += 1
    try:
        _ = plan_round_k(PROPOSER_MTP_HEAD, 16, 0, 512)
    except:
        refused += 1
    try:
        _ = plan_round_k(PROPOSER_CONVERSATION, 9, 0, 512)
    except:
        refused += 1
    try:
        _ = plan_round_k(99, 4, 0, 512)
    except:
        refused += 1
    expect_eq(refused, 4, "k plan refusal count (floor / band / cap / kind)")
    var conv = plan_round_k(PROPOSER_CONVERSATION, 8, 0, 512)
    expect_eq(conv.planned_k, 8, "conversation cap admitted exactly")
    print("PASS: k planning -- floor, band top, proposer caps enforced (4/4 refusals)")


def test_k_plan_capacity_shortening() raises:
    # 509 committed of 512: only k=2 fits (509 + 2 + 1 = 512).
    # The plan shortens EXPLICITLY: requested stays on record.
    var plan = plan_round_k(PROPOSER_MTP_HEAD, 4, 509, 512)
    expect_eq(plan.requested_k, 4, "requested k on record")
    expect_eq(plan.planned_k, 2, "planned k shortened to fit")
    expect_eq(plan.fit_k, 2, "fit k exact")
    expect_true(plan.shortened_for_capacity, "shortening flagged, never silent")
    # The shortened depth actually runs, and fits exactly.
    var state = LoopState(512, 509, 509, UInt64(1), 0)
    var drafts: List[Int] = [5, 6]
    var target: List[Int] = [5, 6, 7]
    var a = run_loop_round(state, SLOT_HEAD, PROPOSER_MTP_HEAD, drafts, target, 0)
    expect_eq(state.kv_length, 512, "shortened round commits exactly at capacity")
    expect_eq(a.verify_width, 3, "shortened pass width")
    # Where not even k=1 fits, the plan refuses outright.
    var refused = 0
    try:
        _ = plan_round_k(PROPOSER_MTP_HEAD, 4, 511, 512)
    except:
        refused += 1
    expect_eq(refused, 1, "no-fit capacity refusal")
    print("PASS: KV capacity -- host shortens k explicitly; no-fit refused, never truncated")


def test_refused_round_leaves_state() raises:
    var state = LoopState(512, 509, 509, UInt64(31337), 20)
    var drafts: List[Int] = [1, 2, 3, 4]
    var target: List[Int] = [1, 2, 3, 4, 5]
    var refused = 0
    try:
        # k=4 at 509 committed cannot fit 512: plan_verify refuses.
        _ = run_loop_round(state, SLOT_HEAD, PROPOSER_MTP_HEAD, drafts, target, 0)
    except:
        refused += 1
    try:
        # A greedy round reporting an RNG draw is refused.
        var d1: List[Int] = [1]
        var t1: List[Int] = [1, 2]
        _ = run_loop_round(state, SLOT_HEAD, PROPOSER_MTP_HEAD, d1, t1, 1)
    except:
        refused += 1
    expect_eq(refused, 2, "refused round count")
    expect_eq(state.kv_length, 509, "state KV untouched by refused rounds")
    expect_eq(state.context_count, 509, "state context untouched")
    expect_eq(state.draft_kv_length, 20, "state proposer KV untouched")
    expect_true(state.rng_word == UInt64(31337), "state RNG word untouched")
    expect_eq(len(state.emitted), 0, "nothing emitted by refused rounds")
    print("PASS: refused rounds (capacity / RNG draw) leave the state at its snapshot")


def test_adapt_shape_bounds() raises:
    expect_eq(suggest_next_k(PROPOSER_MTP_HEAD, 4, 4), 5, "full round deepens by one")
    expect_eq(suggest_next_k(PROPOSER_MTP_HEAD, 15, 15), 15, "deepening capped at the band")
    expect_eq(suggest_next_k(PROPOSER_CONVERSATION, 8, 8), 8, "deepening capped at the conversation cap")
    expect_eq(suggest_next_k(PROPOSER_MTP_HEAD, 5, 0), 2, "empty round halves")
    expect_eq(suggest_next_k(PROPOSER_MTP_HEAD, 1, 0), 1, "halving floored at k_min")
    expect_eq(suggest_next_k(PROPOSER_MTP_HEAD, 4, 2), 4, "partial round holds")
    var refused = 0
    try:
        _ = suggest_next_k(PROPOSER_CONVERSATION, 9, 9)
    except:
        refused += 1
    try:
        _ = suggest_next_k(PROPOSER_MTP_HEAD, 4, 5)
    except:
        refused += 1
    expect_eq(refused, 2, "adapt-shape refusal count")
    print("PASS: adaptation shape -- deepen / halve / hold, bounds stated and enforced")


def test_legacy_bound_reconciled() raises:
    # The default 4 is retained (it is the loop's initial k).
    expect_eq(LOOP_K_INITIAL, 4, "legacy default retained as initial k")
    var engine = SpeculativeEngine(LOOP_K_INITIAL)
    expect_eq(engine.num_draft_tokens, 4, "legacy default constructs")
    # The hard limit is now the band's 15: a 15-token proposal
    # is admitted by the arithmetic, 16 and the old 64 refuse.
    var proposal = DraftProposal()
    var target = List[Float64]()
    var draws = List[Float64]()
    for _i in range(15):
        proposal.draft_tokens.append(1)
        proposal.draft_probs.append(0.5)
        target.append(0.5)
        draws.append(0.5)
    var result = SpeculativeEngine(15).evaluate_acceptance(proposal, target, draws, 0)
    expect_eq(result.accepted_count, 15, "band-top proposal admitted by legacy arithmetic")
    var refused = 0
    try:
        _ = SpeculativeEngine(16).evaluate_acceptance(proposal, target, draws, 0)
    except:
        refused += 1
    try:
        _ = SpeculativeEngine(64).evaluate_acceptance(proposal, target, draws, 0)
    except:
        refused += 1
    expect_eq(refused, 2, "over-band legacy counts refused (16 and the old 64)")
    print("PASS: legacy bound reconciled -- hard limit 15 in code, default 4 = initial k")


def test_multi_round_identity() raises:
    # J-071's adversarial scenario driven through the LOOP:
    # six rounds over a stated 24-token plain continuation,
    # drafts exact, mid-draft-wrong with a coincidence after,
    # and first-token-wrong. The loop's concatenated emission
    # must equal the plain continuation token-for-token, with
    # KV, proposer KV, and rollback totals exact.
    var plain: List[Int] = [
        11, 4, 19, 7, 23, 5, 17, 2, 29, 13,
        3, 31, 37, 41, 43, 47, 53, 59, 61, 67,
        71, 73, 79, 83,
    ]
    var ks: List[Int] = [4, 4, 3, 5, 4, 4]
    var wrongs: List[Int] = [-1, 2, 0, -1, 3, -1]
    var drafts_flat = List[Int]()
    var pos = 0
    for r in range(len(ks)):
        for i in range(ks[r]):
            if i == wrongs[r]:
                drafts_flat.append(900 + r)
            else:
                drafts_flat.append(plain[pos + i])
        # Advance pos by what a correct account will emit:
        # accepted prefix (up to the wrong index) + 1.
        var acc = ks[r]
        if wrongs[r] != -1:
            acc = wrongs[r]
        pos += acc + 1
    expect_eq(pos, 24, "fixture covers the continuation exactly")
    var initial = LoopState(4096, 67, 67, UInt64(2024), 67)
    var result = run_loop(
        initial, SLOT_CROSS_MODEL, PROPOSER_CROSS_MODEL, drafts_flat, ks, plain
    )
    expect_eq(result.rounds, 6, "round count")
    expect_true(sequences_identical(result.emitted, plain), "loop emission identical to plain greedy (24/24)")
    expect_eq(result.final_kv_length, 91, "KV advanced by exactly the emitted count")
    expect_eq(result.final_context_count, 91, "context advanced with KV")
    expect_eq(result.total_accepted, 18, "accepted total exact (4+2+0+5+3+4)")
    expect_eq(result.total_rollback_rows, 6, "rollback total exact (2+3+1)")
    expect_eq(result.final_draft_kv_length, 85, "proposer KV = start + accepted (67+18)")
    expect_true(result.rng_word == UInt64(2024), "RNG word unchanged across all rounds")
    print("PASS: multi-round loop -- emission identical to plain greedy (24/24), totals exact")


def test_multi_round_slot_switching() raises:
    # One continuation, three rounds from three different
    # slots in sequence: identity holds across slot switches
    # because emission is always the target's.
    var plain: List[Int] = [8, 6, 7, 5, 3, 0, 9, 2, 4, 1]
    var state = LoopState(512, 10, 10, UInt64(5), 0)
    var pos = 0
    # Round 1 (head/MTP), k=3, all accepted: emits 4.
    var d1 = List[Int]()
    var t1 = List[Int]()
    for i in range(3):
        d1.append(plain[pos + i])
    for i in range(4):
        t1.append(plain[pos + i])
    var a1 = run_loop_round(state, SLOT_HEAD, PROPOSER_MTP_HEAD, d1, t1, 0)
    pos += a1.emitted_count()
    # Round 2 (conversation), k=2, first wrong: emits 1.
    var d2: List[Int] = [999, plain[pos + 1]]
    var t2 = List[Int]()
    for i in range(3):
        t2.append(plain[pos + i])
    var a2 = run_loop_round(state, SLOT_CONVERSATION, PROPOSER_CONVERSATION, d2, t2, 0)
    pos += a2.emitted_count()
    # Round 3 (cross-model), k=4, wrong at 3: emits 4.
    state.draft_kv_length = state.kv_length
    var d3 = List[Int]()
    var t3 = List[Int]()
    for i in range(4):
        if i == 3:
            d3.append(888)
        else:
            d3.append(plain[pos + i])
    for i in range(5):
        t3.append(plain[pos + i])
    var a3 = run_loop_round(state, SLOT_CROSS_MODEL, PROPOSER_CROSS_MODEL, d3, t3, 0)
    pos += a3.emitted_count()
    expect_eq(pos, 9, "rounds covered 9 of 10 (fixture stops one short by design)")
    _ = pos
    # The emitted stream so far is exactly the plain prefix.
    var prefix = List[Int]()
    for i in range(len(state.emitted)):
        prefix.append(plain[i])
    expect_true(sequences_identical(state.emitted, prefix), "emission across slots is the plain prefix")
    expect_eq(len(state.emitted), 9, "emitted count across slots (4+1+4)")
    print("PASS: multi-round slot switching -- head/conversation/cross rounds, identity holds")


def test_driver_refusals() raises:
    var plain: List[Int] = [1, 2, 3, 4]
    var initial = LoopState(512, 0, 0, UInt64(0), 0)
    var refused = 0
    # Flat drafts run out mid-round.
    var short_drafts: List[Int] = [1]
    var ks1: List[Int] = [3]
    try:
        _ = run_loop(initial, SLOT_HEAD, PROPOSER_MTP_HEAD, short_drafts, ks1, plain)
    except:
        refused += 1
    # Rounds end short of the continuation: no partial identity.
    var drafts2: List[Int] = [1]
    var ks2: List[Int] = [1]
    try:
        _ = run_loop(initial, SLOT_HEAD, PROPOSER_MTP_HEAD, drafts2, ks2, plain)
    except:
        refused += 1
    # A zero-depth round is refused.
    var ks3: List[Int] = [0]
    var empty = List[Int]()
    try:
        _ = run_loop(initial, SLOT_HEAD, PROPOSER_MTP_HEAD, empty, ks3, plain)
    except:
        refused += 1
    expect_eq(refused, 3, "driver refusal count")
    print("PASS: driver refusals -- short drafts / partial drive / zero-depth round (3/3)")


def main() raises:
    test_slot_dispatch()
    test_round_all_accepted()
    test_round_partial_rollback_exact()
    test_round_zero_accepted_rollback()
    test_k_plan_bounds_and_caps()
    test_k_plan_capacity_shortening()
    test_refused_round_leaves_state()
    test_adapt_shape_bounds()
    test_legacy_bound_reconciled()
    test_multi_round_identity()
    test_multi_round_slot_switching()
    test_driver_refusals()
    print("ALL PASS: speculative draft loop (12 groups)")
