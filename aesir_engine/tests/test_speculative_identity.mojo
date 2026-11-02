"""Token-identity proof (J-073): long generations through
the J-072 draft loop over SUPPLIED target-choice streams.

Roadmap text: "Across the arch matrix, greedy speculative
output vs greedy plain output: token-for-token identity
over long generations, or the slice does not bank."

What this suite proves, graded exactly: the LOOP MACHINERY
(core/speculative_loop.mojo over J-071's account) preserves
token identity over LONG generations -- hundreds of tokens
and hundreds of rounds per configuration, materially beyond
J-072's 24-token run -- across all three proposer slots
(including slot switching inside one generation), varied k
(the band top 15, the conversation cap 8, capacity-shortened
rounds at the KV tail), and adversarial proposer behaviour
(always-right, always-wrong, alternating, coincidence-past-
mismatch traps, and long zero-acceptance stretches). For
every configuration the speculative emission is asserted
token-for-token identical to the plain greedy continuation,
and the final KV / context / proposer-KV / RNG state is
asserted equal to the plain loop's state after the same
number of tokens (proposer KV: start + total accepted for a
proposer that carries one; untouched for one that does not).

The target choices are SIMULATED (stated token streams, the
account-level premise J-071 section 5 and J-072 stated: in a
live host those lists come from verify passes against a real
model). This is a PROVEN property of the loop machinery over
supplied streams; it is NOT a live model proof and NOT an
arch-matrix live proof. The live leg is DEFERRED-WITH-REASON
in docs/janas/J073_TOKEN_IDENTITY_PROOF.md with its exact
recipe, re-cited at the J-086 Part V gate. No forward runs,
no timing, no speed or acceptance claim anywhere here.
"""
from core.speculative_loop import (
    LoopResult,
    LoopState,
    plan_round_k,
    run_loop,
    run_loop_round,
)
from core.speculative_verify import (
    PROPOSER_ASSISTANT_MODEL,
    PROPOSER_CONVERSATION,
    PROPOSER_CROSS_MODEL,
    PROPOSER_MTP_HEAD,
    SLOT_CONVERSATION,
    SLOT_CROSS_MODEL,
    SLOT_HEAD,
    identity_first_divergence,
    sequences_identical,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "SpeculativeIdentity " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("SpeculativeIdentity " + what + ": expected true")


def make_plain(seed: Int, length: Int) -> List[Int]:
    var plain = List[Int]()
    for i in range(length):
        plain.append(((i * 37 + seed * 1013) % 4000) + 17)
    return plain^


def run_fixed_config(
    slot: Int,
    kind: Int,
    k: Int,
    behaviour: Int,
    wrong_index: Int,
    length: Int,
    seed: Int,
    start_kv: Int,
    rng_word: UInt64,
    proposer_kv_start: Int,
) raises -> LoopResult:
    """Drive run_loop over one long stated continuation.

    behaviour: 0 = always-right, 1 = always-wrong,
    2 = alternating rounds (even right, odd wrong),
    3 = coincidence trap (single wrong draft at
    wrong_index, every later draft coincidentally equal to
    the target -- a prefix, never a filter, must discard
    them). The fixture must divide exactly: every round's
    emitted count is accepted + 1 by construction here, and
    a fixture that does not cover the continuation exactly
    is refused by this helper, not silently padded.
    """
    var plain = make_plain(seed, length)
    var ks = List[Int]()
    var drafts_flat = List[Int]()
    var pos = 0
    var round_idx = 0
    while pos < length:
        var wrong_this_round = False
        var wrong_at = -1
        if behaviour == 1:
            wrong_this_round = True
            wrong_at = 0
        elif behaviour == 2 and round_idx % 2 == 1:
            wrong_this_round = True
            wrong_at = 0
        elif behaviour == 3:
            wrong_this_round = True
            wrong_at = wrong_index
        var accepted = k
        if wrong_this_round:
            accepted = wrong_at
        for i in range(k):
            if behaviour == 1 or (behaviour == 2 and round_idx % 2 == 1):
                drafts_flat.append(plain[pos + i] + 9000)
            elif wrong_this_round and i == wrong_at:
                drafts_flat.append(plain[pos + i] + 9000)
            else:
                drafts_flat.append(plain[pos + i])
        ks.append(k)
        pos += accepted + 1
        round_idx += 1
    if pos != length:
        raise Error("SpeculativeIdentity: fixture does not divide exactly")
    var initial = LoopState(8192, start_kv, start_kv, rng_word, proposer_kv_start)
    var result = run_loop(initial, slot, kind, drafts_flat, ks, plain)
    expect_true(
        sequences_identical(result.emitted, plain),
        "emission identical to plain greedy over the whole generation",
    )
    expect_eq(
        identity_first_divergence(result.emitted, plain), -1, "no divergence index"
    )
    expect_eq(result.rounds, round_idx, "round count exact")
    expect_eq(
        result.final_kv_length,
        start_kv + length,
        "final KV == plain loop KV after the same token count",
    )
    expect_eq(
        result.final_context_count,
        start_kv + length,
        "final context == plain loop context after the same token count",
    )
    expect_true(result.rng_word == rng_word, "RNG word unchanged over the generation")
    return result^


def drive_specs(
    slot: Int,
    kind: Int,
    ks: List[Int],
    wrong_at_list: List[Int],
    seed: Int,
    length: Int,
    start_kv: Int,
    rng_word: UInt64,
    proposer_kv_start: Int,
) raises -> LoopState:
    """Drive run_loop_round over an explicit round-spec list.

    Each spec is (k, wrong_at): wrong_at -1 is an all-right
    round; otherwise the single wrong draft sits at
    wrong_at and every later draft coincidentally equals the
    target (the loop observes only the accepted prefix, so
    an always-wrong round and a wrong-at-0 trap round are
    the same account shape: accepted 0). Target lists are
    sliced from a source stream 16 tokens longer than the
    generation: entries past the generation's end are
    pass-position choices on draft contexts, discarded by
    the round and never emitted or compared -- the identity
    assertion below compares only the generation itself.
    Account totals are asserted against the spec formula.
    """
    var plain = make_plain(seed, length)
    var source = make_plain(seed, length + 16)
    var state = LoopState(8192, start_kv, start_kv, rng_word, proposer_kv_start)
    var pos = 0
    var acc_total = 0
    var rb_total = 0
    var expected_acc = 0
    var expected_rb = 0
    for r in range(len(ks)):
        var k = ks[r]
        var w = wrong_at_list[r]
        var drafts = List[Int]()
        var target = List[Int]()
        for i in range(k):
            if w != -1 and i == w:
                drafts.append(source[pos + i] + 9000)
            else:
                drafts.append(source[pos + i])
        for i in range(k + 1):
            target.append(source[pos + i])
        var account = run_loop_round(state, slot, kind, drafts, target, 0)
        pos += account.emitted_count()
        acc_total += account.accepted_count
        rb_total += account.kv_rows_to_roll_back
        var spec_acc = k
        if w != -1:
            spec_acc = w
        expected_acc += spec_acc
        expected_rb += k - spec_acc
    expect_eq(pos, length, "spec drive covers the generation exactly")
    expect_eq(acc_total, expected_acc, "account accepted total matches spec formula")
    expect_eq(rb_total, expected_rb, "account rollback total matches spec formula")
    expect_true(
        sequences_identical(state.emitted, plain),
        "spec-drive emission identical to plain greedy",
    )
    expect_eq(state.kv_length, start_kv + length, "spec-drive final KV == plain state")
    expect_eq(
        state.context_count, start_kv + length, "spec-drive final context == plain"
    )
    expect_true(state.rng_word == rng_word, "spec-drive RNG word unchanged")
    return state^


def test_checker_negative_control() raises:
    # The proof's checker must be able to FAIL: a tampered
    # copy of a long stream diverges at exactly the tampered
    # index, and a truncated copy diverges at its length.
    var plain = make_plain(11, 600)
    var tampered = plain.copy()
    tampered[257] = plain[257] + 1
    expect_eq(
        identity_first_divergence(tampered, plain), 257, "tamper index exact"
    )
    expect_true(not sequences_identical(tampered, plain), "tampered stream refused")
    var truncated = List[Int]()
    for i in range(599):
        truncated.append(plain[i])
    expect_eq(
        identity_first_divergence(truncated, plain), 599, "length divergence exact"
    )
    print("PASS: checker negative control -- tamper at 257 and truncation at 599 both detected")


def test_head_mtp_always_right_long() raises:
    var result = run_fixed_config(
        SLOT_HEAD, PROPOSER_MTP_HEAD, 4, 0, -1, 500, 21, 67, UInt64(424242), 67
    )
    expect_eq(result.total_accepted, 400, "A accepted total (100 rounds x 4)")
    expect_eq(result.total_rollback_rows, 0, "A rollback total")
    expect_eq(result.final_draft_kv_length, 67, "A head proposer KV untouched")
    print("PASS: A head/MTP k=4 always-right -- identity 500/500 over 100 rounds, plain state exact")


def test_head_assistant_band_top_long() raises:
    var result = run_fixed_config(
        SLOT_HEAD, PROPOSER_ASSISTANT_MODEL, 15, 0, -1, 512, 22, 32, UInt64(99), 32
    )
    expect_eq(result.total_accepted, 480, "B accepted total (32 rounds x 15)")
    expect_eq(result.total_rollback_rows, 0, "B rollback total")
    expect_eq(result.final_draft_kv_length, 32, "B assistant proposer KV untouched")
    print("PASS: B head/assistant k=15 (band top) always-right -- identity 512/512 over 32 rounds, plain state exact")


def test_cross_always_wrong_zero_stretch() raises:
    # 295 consecutive zero-accepted rounds at k=5 (295
    # tokens, one correction each), then one all-right
    # closing round at k=4 consuming the last 5 tokens --
    # a generation cannot end on a low-acceptance round in
    # the flat slicing model, so the closing round is part
    # of the stated spec, not a dilution: the stretch under
    # test is the 295 rounds before it.
    var ks = List[Int]()
    var wrongs = List[Int]()
    for _r in range(295):
        ks.append(5)
        wrongs.append(0)
    ks.append(4)
    wrongs.append(-1)
    var state = drive_specs(
        SLOT_CROSS_MODEL, PROPOSER_CROSS_MODEL, ks, wrongs, 23, 300, 40, UInt64(7), 40
    )
    expect_eq(
        state.draft_kv_length, 44, "C proposer KV == start + closing accepted (40+4)"
    )
    print("PASS: C cross-model k=5 always-wrong -- identity 300/300 over 296 rounds (295 zero-accepted + closing), plain state exact")


def test_conversation_alternating_cap() raises:
    # 39 alternating pairs at the conversation cap k=8
    # (right round emits 9, wrong-at-0 round emits 1), then
    # two all-right closing rounds at k=4 consuming the
    # last 10 tokens. 80 rounds in total.
    var ks = List[Int]()
    var wrongs = List[Int]()
    for _p in range(39):
        ks.append(8)
        wrongs.append(-1)
        ks.append(8)
        wrongs.append(0)
    ks.append(4)
    wrongs.append(-1)
    ks.append(4)
    wrongs.append(-1)
    var state = drive_specs(
        SLOT_CONVERSATION, PROPOSER_CONVERSATION, ks, wrongs, 24, 400, 16, UInt64(5), 16
    )
    expect_eq(state.draft_kv_length, 16, "D conversation proposer KV untouched")
    print("PASS: D conversation k=8 (cap) alternating right/wrong -- identity 400/400 over 80 rounds, plain state exact")


def test_cross_coincidence_traps() raises:
    # 148 trap rounds at k=6, wrong at index 2 with every
    # later draft coincidentally equal to the target (the
    # prefix rule must discard them), then one all-right
    # closing round at k=5 consuming the last 6 tokens.
    var ks = List[Int]()
    var wrongs = List[Int]()
    for _r in range(148):
        ks.append(6)
        wrongs.append(2)
    ks.append(5)
    wrongs.append(-1)
    var state = drive_specs(
        SLOT_CROSS_MODEL, PROPOSER_CROSS_MODEL, ks, wrongs, 25, 450, 50, UInt64(2024), 50
    )
    expect_eq(
        state.draft_kv_length,
        351,
        "E proposer KV == start + accepted (50 + 148x2 + 5)",
    )
    print("PASS: E cross-model k=6 coincidence-past-mismatch traps -- identity 450/450 over 149 rounds, plain state exact")


def test_capacity_shortened_tail() raises:
    # Long run ending exactly at KV capacity: 19 always-right
    # rounds at k=15 (304 tokens), 20 always-wrong rounds
    # (20 tokens, the last 9 of them capacity-shortened),
    # and a final always-right round whose planned k is
    # capacity-shortened 15 -> 5 and consumes the last 6
    # tokens exactly at capacity. Shortened rounds are a
    # recorded plan fact on every round (plan_round_k).
    var length = 330
    var start = 48
    var capacity = 378
    var plain = make_plain(26, length)
    var state = LoopState(capacity, start, start, UInt64(31337), start)
    var pos = 0
    var rounds = 0
    var shortened = 0
    var accepted_total = 0
    var rollback_total = 0
    while pos < length:
        var plan = plan_round_k(PROPOSER_MTP_HEAD, 15, state.kv_length, capacity)
        var k = plan.planned_k
        if plan.shortened_for_capacity:
            shortened += 1
        var always_right = pos < 304 or pos >= 324
        var drafts = List[Int]()
        var target = List[Int]()
        for i in range(k):
            if always_right:
                drafts.append(plain[pos + i])
            else:
                drafts.append(plain[pos + i] + 9000)
        for i in range(k + 1):
            target.append(plain[pos + i])
        var account = run_loop_round(
            state, SLOT_HEAD, PROPOSER_MTP_HEAD, drafts, target, 0
        )
        pos += account.emitted_count()
        rounds += 1
        accepted_total += account.accepted_count
        rollback_total += account.kv_rows_to_roll_back
    expect_eq(pos, length, "F fixture covers the continuation exactly")
    expect_eq(rounds, 40, "F round count (19 + 20 + 1)")
    expect_eq(shortened, 10, "F capacity-shortened rounds (9 zero rounds + final round)")
    expect_eq(accepted_total, 290, "F accepted total (285 + 0 + 5)")
    expect_eq(rollback_total, 255, "F rollback total (zero-phase rounds)")
    expect_true(sequences_identical(state.emitted, plain), "F emission identical 330/330")
    expect_eq(state.kv_length, capacity, "F final KV exactly at capacity == plain state")
    expect_eq(state.context_count, capacity, "F final context == plain state")
    expect_eq(state.draft_kv_length, start, "F head proposer KV untouched")
    expect_true(state.rng_word == UInt64(31337), "F RNG word unchanged")
    print("PASS: F head/MTP capacity-shortened tail -- identity 330/330 over 40 rounds, 10 shortened rounds on record, final KV at capacity")


def test_slot_switching_long() raises:
    # One 350-token generation switching proposer slot every
    # round in a 4-round cycle: MTP head (k=4, right),
    # conversation (k=4, wrong at 1 with coincidences after),
    # cross-model (k=3, wrong at 2), assistant (k=7, wrong
    # at 3). Identity holds across switches because emission
    # is always the target's; the cross-model proposer's own
    # KV is carried across its rounds separately (sentinel
    # 777 proves the other proposers never touch it).
    var length = 350
    var start = 20
    var plain = make_plain(27, length)
    var source = make_plain(27, length + 16)
    var state = LoopState(4096, start, start, UInt64(8080), 777)
    var cross_kv = start
    var pos = 0
    var rounds = 0
    var accepted_total = 0
    var rollback_total = 0
    for _cycle in range(25):
        # Round A: head / MTP, k=4, always right -> emits 5.
        state.draft_kv_length = 777
        var da = List[Int]()
        var ta = List[Int]()
        for i in range(4):
            da.append(source[pos + i])
        for i in range(5):
            ta.append(source[pos + i])
        var aa = run_loop_round(state, SLOT_HEAD, PROPOSER_MTP_HEAD, da, ta, 0)
        expect_eq(state.draft_kv_length, 777, "G MTP round leaves proposer-KV sentinel")
        pos += aa.emitted_count()
        rounds += 1
        accepted_total += aa.accepted_count
        rollback_total += aa.kv_rows_to_roll_back
        # Round B: conversation, k=4, wrong at 1 -> emits 2.
        state.draft_kv_length = 777
        var db = List[Int]()
        var tb = List[Int]()
        for i in range(4):
            if i == 1:
                db.append(source[pos + i] + 9000)
            else:
                db.append(source[pos + i])
        for i in range(5):
            tb.append(source[pos + i])
        var ab = run_loop_round(
            state, SLOT_CONVERSATION, PROPOSER_CONVERSATION, db, tb, 0
        )
        expect_eq(state.draft_kv_length, 777, "G conversation round leaves sentinel")
        pos += ab.emitted_count()
        rounds += 1
        accepted_total += ab.accepted_count
        rollback_total += ab.kv_rows_to_roll_back
        # Round C: cross-model, k=3, wrong at 2 -> emits 3.
        state.draft_kv_length = cross_kv
        var dc = List[Int]()
        var tc = List[Int]()
        for i in range(3):
            if i == 2:
                dc.append(source[pos + i] + 9000)
            else:
                dc.append(source[pos + i])
        for i in range(4):
            tc.append(source[pos + i])
        var ac = run_loop_round(
            state, SLOT_CROSS_MODEL, PROPOSER_CROSS_MODEL, dc, tc, 0
        )
        cross_kv = state.draft_kv_length
        pos += ac.emitted_count()
        rounds += 1
        accepted_total += ac.accepted_count
        rollback_total += ac.kv_rows_to_roll_back
        # Round D: head / assistant, k=7, wrong at 3 -> emits 4.
        state.draft_kv_length = 777
        var dd = List[Int]()
        var td = List[Int]()
        for i in range(7):
            if i == 3:
                dd.append(source[pos + i] + 9000)
            else:
                dd.append(source[pos + i])
        for i in range(8):
            td.append(source[pos + i])
        var ad = run_loop_round(
            state, SLOT_HEAD, PROPOSER_ASSISTANT_MODEL, dd, td, 0
        )
        expect_eq(state.draft_kv_length, 777, "G assistant round leaves sentinel")
        pos += ad.emitted_count()
        rounds += 1
        accepted_total += ad.accepted_count
        rollback_total += ad.kv_rows_to_roll_back
    expect_eq(pos, length, "G cycles cover the continuation exactly (25 x 14)")
    expect_eq(rounds, 100, "G round count")
    expect_eq(accepted_total, 250, "G accepted total (25 x (4+1+2+3))")
    expect_eq(rollback_total, 200, "G rollback total (25 x (0+3+1+4))")
    expect_true(sequences_identical(state.emitted, plain), "G emission identical 350/350")
    expect_eq(state.kv_length, start + length, "G final KV == plain state")
    expect_eq(state.context_count, start + length, "G final context == plain state")
    expect_eq(cross_kv, start + 50, "G cross proposer KV == start + its accepted (20+50)")
    expect_true(state.rng_word == UInt64(8080), "G RNG word unchanged")
    print("PASS: G slot switching (head/conversation/cross/head, 25 cycles) -- identity 350/350 over 100 rounds, plain state exact, cross KV exact")


def main() raises:
    test_checker_negative_control()
    test_head_mtp_always_right_long()
    test_head_assistant_band_top_long()
    test_cross_always_wrong_zero_stretch()
    test_conversation_alternating_cap()
    test_cross_coincidence_traps()
    test_capacity_shortened_tail()
    test_slot_switching_long()
    print("ALL PASS: speculative token-identity proof (8 groups; 7 long configurations, 2842 tokens, 797 rounds)")
