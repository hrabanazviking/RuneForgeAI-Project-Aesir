"""Speculative verification account (J-071): the greedy verify
round derived -- never asserted -- from a draft list and the
target's own greedy list; emission built from the target list
only; acceptance a strict prefix (a coincidental match past
the first mismatch is never emitted); KV/context rollback
exact; the greedy round consuming no RNG draw; the band and
capacity refusals; the proposer shapes for J-072's three
slots; the identity checker; a multi-round adversarial
simulation whose concatenated emission is token-identical to
the plain greedy continuation; and the claim verdict on
every branch. No forward runs: the token lists below are
stated fixtures checking the account machinery only.
"""
from core.speculative_verify import (
    CLAIM_GREEDY_IDENTITY_BY_CONSTRUCTION,
    CLAIM_LIVE_TOKEN_IDENTITY,
    CLAIM_SPEED_GAIN,
    PROPOSER_ASSISTANT_MODEL,
    PROPOSER_CONVERSATION,
    PROPOSER_CROSS_MODEL,
    PROPOSER_MTP_HEAD,
    SLOT_CONVERSATION,
    SLOT_CROSS_MODEL,
    SLOT_HEAD,
    SPEC_CLAIM_PERMITTED,
    SPEC_CLAIM_REFUSED,
    SPEC_CLAIM_REQUIRES_LIVE,
    VerifyAccount,
    account_is_consistent,
    claim_name,
    evaluate_spec_claim,
    identity_first_divergence,
    plan_proposer,
    plan_verify,
    proposer_kind_name,
    proposer_slot_name,
    sequences_identical,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "SpeculativeVerify " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("SpeculativeVerify " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("SpeculativeVerify " + what + ": expected false")


def test_all_accepted_bonus_round() raises:
    # Drafts match the target at every drafted position: the
    # round emits the whole prefix plus the target's bonus.
    var drafts: List[Int] = [10, 11, 12, 13]
    var target: List[Int] = [10, 11, 12, 13, 14]
    var a = plan_verify(PROPOSER_MTP_HEAD, drafts, target, 67, 512, 67, 0)
    expect_eq(a.accepted_count, 4, "all-accepted count")
    expect_eq(a.first_mismatch_index, -1, "no mismatch")
    expect_true(a.all_accepted(), "all_accepted flag")
    expect_eq(a.emitted_count(), 5, "emitted = k + 1")
    expect_eq(a.emitted_tokens[4], 14, "bonus token is the target's own")
    expect_eq(a.verify_width, 5, "pass width k+1")
    expect_eq(a.kv_after, 72, "KV commits every emitted token")
    expect_eq(a.kv_rows_to_roll_back, 0, "nothing rolls back")
    expect_eq(a.context_after, 72, "context advances with KV")
    expect_true(account_is_consistent(a), "account consistent")
    print("PASS: all-accepted round emits prefix + target bonus, no rollback")


def test_prefix_plus_correction() raises:
    # Mismatch at index 2 of 4: emit the true prefix plus the
    # target's correction -- the draft's token never appears.
    var drafts: List[Int] = [10, 11, 99, 13]
    var target: List[Int] = [10, 11, 12, 13, 14]
    var a = plan_verify(PROPOSER_CROSS_MODEL, drafts, target, 40, 512, 40, 0)
    expect_eq(a.accepted_count, 2, "accepted prefix")
    expect_eq(a.first_mismatch_index, 2, "mismatch index")
    expect_eq(a.emitted_count(), 3, "emitted = accepted + 1")
    expect_eq(a.emitted_tokens[2], 12, "correction is the target's token")
    expect_eq(a.kv_after, 43, "KV commits prefix + correction only")
    expect_eq(a.kv_rows_to_roll_back, 2, "uncommitted rows roll back")
    expect_true(account_is_consistent(a), "account consistent")
    print("PASS: prefix + correction -- emitted built from the target list")


def test_coincidence_past_mismatch_never_emitted() raises:
    # The draft at index 2 coincidentally equals the target's
    # choice there, but index 1 already mismatched: acceptance
    # is a prefix, so the coincidence is not emitted.
    var drafts: List[Int] = [5, 9, 7]
    var target: List[Int] = [5, 8, 7, 3]
    var a = plan_verify(PROPOSER_CONVERSATION, drafts, target, 10, 512, 10, 0)
    expect_eq(a.accepted_count, 1, "prefix stops at first mismatch")
    expect_eq(a.emitted_count(), 2, "emitted = prefix + correction")
    expect_eq(a.emitted_tokens[0], 5, "accepted token")
    expect_eq(a.emitted_tokens[1], 8, "correction token, not the coincidence")
    expect_eq(a.kv_rows_to_roll_back, 2, "rows past the prefix roll back")
    print("PASS: coincidence past the first mismatch is never emitted")


def test_zero_accepted() raises:
    var drafts: List[Int] = [77, 78]
    var target: List[Int] = [10, 11, 12]
    var a = plan_verify(PROPOSER_ASSISTANT_MODEL, drafts, target, 3, 512, 3, 0)
    expect_eq(a.accepted_count, 0, "nothing accepted")
    expect_eq(a.emitted_count(), 1, "exactly the target's correction emits")
    expect_eq(a.emitted_tokens[0], 10, "correction token")
    expect_eq(a.kv_after, 4, "KV advances by the one emitted token")
    expect_eq(a.kv_rows_to_roll_back, 2, "whole draft rolls back")
    print("PASS: zero-accepted round still emits exactly one target token")


def test_band_and_proposer_caps() raises:
    # Width 16 (k=15) is the band's top and is admitted for a
    # model proposer; width 17 (k=16) is refused. The
    # conversation proposer's cap is 8.
    var d15 = List[Int]()
    var t16 = List[Int]()
    for i in range(15):
        d15.append(100 + i)
        t16.append(100 + i)
    t16.append(200)
    var a = plan_verify(PROPOSER_MTP_HEAD, d15, t16, 0, 512, 0, 0)
    expect_eq(a.verify_width, 16, "band top admitted")
    var refused = 0
    var d16 = List[Int]()
    var t17 = List[Int]()
    for i in range(16):
        d16.append(100 + i)
        t17.append(100 + i)
    t17.append(200)
    try:
        _ = plan_verify(PROPOSER_MTP_HEAD, d16, t17, 0, 512, 0, 0)
    except:
        refused += 1
    var d9 = List[Int]()
    var t10 = List[Int]()
    for i in range(9):
        d9.append(50 + i)
        t10.append(50 + i)
    t10.append(90)
    try:
        _ = plan_verify(PROPOSER_CONVERSATION, d9, t10, 0, 512, 0, 0)
    except:
        refused += 1
    expect_eq(refused, 2, "band + proposer cap refusal count")
    print("PASS: band top (width 16) admitted; width 17 and over-cap k refused")


def test_capacity_refusal() raises:
    var drafts: List[Int] = [1, 2, 3, 4]
    var target: List[Int] = [1, 2, 3, 4, 5]
    var refused = 0
    try:
        # 509 + 5 rows > 512 capacity: refuse, never truncate.
        _ = plan_verify(PROPOSER_MTP_HEAD, drafts, target, 509, 512, 509, 0)
    except:
        refused += 1
    expect_eq(refused, 1, "over-capacity refusal")
    var a = plan_verify(PROPOSER_MTP_HEAD, drafts, target, 507, 512, 507, 0)
    expect_eq(a.kv_after, 512, "exactly-at-capacity admitted")
    print("PASS: pass that cannot fit the KV capacity refused; exact fit admitted")


def test_rng_invariant() raises:
    var drafts: List[Int] = [1]
    var target: List[Int] = [1, 2]
    var refused = 0
    try:
        _ = plan_verify(PROPOSER_MTP_HEAD, drafts, target, 0, 512, 0, 1)
    except:
        refused += 1
    try:
        _ = plan_verify(PROPOSER_MTP_HEAD, drafts, target, 0, 512, 0, -1)
    except:
        refused += 1
    expect_eq(refused, 2, "greedy round reporting an RNG draw refused")
    print("PASS: a greedy verify round consumes zero RNG draws, enforced")


def test_validation_refusals() raises:
    var refused = 0
    var empty = List[Int]()
    var one: List[Int] = [1]
    try:
        _ = plan_verify(PROPOSER_MTP_HEAD, empty, one, 0, 512, 0, 0)
    except:
        refused += 1
    var d2: List[Int] = [1, 2]
    var t2: List[Int] = [1, 2]
    try:
        # Target list must be exactly k+1.
        _ = plan_verify(PROPOSER_MTP_HEAD, d2, t2, 0, 512, 0, 0)
    except:
        refused += 1
    var dneg: List[Int] = [-1]
    var t2b: List[Int] = [1, 2]
    try:
        _ = plan_verify(PROPOSER_MTP_HEAD, dneg, t2b, 0, 512, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_verify(99, one, t2b, 0, 512, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_verify(PROPOSER_MTP_HEAD, one, t2b, -1, 512, 0, 0)
    except:
        refused += 1
    expect_eq(refused, 5, "validation refusal count")
    print("PASS: validation refusals -- empty draft / short target / negative id / bad kind / negative length (5/5)")


def test_proposer_shapes() raises:
    var mtp = plan_proposer(PROPOSER_MTP_HEAD)
    expect_eq(mtp.slot, SLOT_HEAD, "MTP fills the head slot")
    expect_false(mtp.requires_tokenizer_match, "MTP shares the target tokenizer")
    expect_false(mtp.carries_own_kv, "MTP carries no KV of its own")
    var asst = plan_proposer(PROPOSER_ASSISTANT_MODEL)
    expect_eq(asst.slot, SLOT_HEAD, "assistant fills the head slot")
    expect_true(asst.requires_tokenizer_match, "assistant tokenizer verified")
    expect_false(asst.carries_own_kv, "assistant reads the target KV (census)")
    var cross = plan_proposer(PROPOSER_CROSS_MODEL)
    expect_eq(cross.slot, SLOT_CROSS_MODEL, "cross-model slot")
    expect_true(cross.requires_tokenizer_match, "cross-model tokenizer verified")
    expect_true(cross.carries_own_kv, "cross-model carries its own KV")
    var conv = plan_proposer(PROPOSER_CONVERSATION)
    expect_eq(conv.slot, SLOT_CONVERSATION, "conversation slot")
    expect_eq(conv.max_k, 8, "conversation cap")
    # Three distinct slots across the four documented sources:
    # the J-014 gate's three-proposer loop shape.
    if proposer_kind_name(PROPOSER_MTP_HEAD) != String("mtp_head"):
        raise Error("SpeculativeVerify: MTP kind name")
    if proposer_slot_name(SLOT_HEAD) != String("head"):
        raise Error("SpeculativeVerify: head slot name")
    print("PASS: proposer shapes -- four sources, three slots, flags exact")


def test_identity_checker() raises:
    var a: List[Int] = [3, 1, 4, 1, 5]
    var b: List[Int] = [3, 1, 4, 1, 5]
    expect_true(sequences_identical(a, b), "identical streams")
    expect_eq(identity_first_divergence(a, b), -1, "no divergence")
    var c: List[Int] = [3, 1, 9, 1, 5]
    expect_eq(identity_first_divergence(a, c), 2, "divergence index exact")
    expect_false(sequences_identical(a, c), "divergent streams")
    var short: List[Int] = [3, 1, 4]
    expect_eq(identity_first_divergence(a, short), 3, "length divergence at shorter length")
    var empty1 = List[Int]()
    var empty2 = List[Int]()
    expect_true(sequences_identical(empty1, empty2), "empty streams identical")
    expect_eq(identity_first_divergence(empty1, a), 0, "empty vs non-empty diverges at 0")
    print("PASS: identity checker -- identical / divergence index / length / empty")


def test_multi_round_identity_simulation() raises:
    # A stated plain-greedy continuation (24 tokens). Each
    # round's target list is the continuation's own next k+1
    # tokens -- what the target produces on the state the
    # plain loop would have built, which is the simulation's
    # stated premise. Drafts are adversarial: exact runs, a
    # mid-draft error with a coincidence after it, a first-
    # token error. The concatenated emission must equal the
    # plain continuation token-for-token.
    var plain: List[Int] = [
        11, 4, 19, 7, 23, 5, 17, 2, 29, 13,
        3, 31, 37, 41, 43, 47, 53, 59, 61, 67,
        71, 73, 79, 83,
    ]
    var emitted_all = List[Int]()
    var pos = 0
    var kv = 67
    var rounds = 0
    var total_rollback = 0
    # Round shapes (k, wrong_index or -1): emission per round
    # is derived by the account, never by this test.
    var ks: List[Int] = [4, 4, 3, 5, 4, 4]
    var wrongs: List[Int] = [-1, 2, 0, -1, 3, -1]
    for r in range(len(ks)):
        var k = ks[r]
        var target = List[Int]()
        for i in range(k + 1):
            target.append(plain[pos + i])
        var drafts = List[Int]()
        for i in range(k):
            if i == wrongs[r]:
                drafts.append(900 + r)
            else:
                drafts.append(plain[pos + i])
        var a = plan_verify(
            PROPOSER_CROSS_MODEL, drafts, target, kv, 4096, kv, 0
        )
        expect_true(account_is_consistent(a), "round account consistent")
        for i in range(len(a.emitted_tokens)):
            emitted_all.append(a.emitted_tokens[i])
        pos += a.emitted_count()
        kv = a.kv_after
        total_rollback += a.kv_rows_to_roll_back
        rounds += 1
    expect_eq(rounds, 6, "round count")
    expect_eq(pos, 24, "every plain token emitted exactly once")
    expect_eq(kv, 91, "KV advanced by exactly the emitted count")
    expect_true(
        sequences_identical(emitted_all, plain),
        "speculative emission token-identical to plain greedy",
    )
    expect_eq(
        identity_first_divergence(emitted_all, plain), -1, "no divergence"
    )
    # Rollback total: rounds 2, 3, 5 discard 2 + 3 + 1 rows.
    expect_eq(total_rollback, 6, "total rolled-back rows exact")
    print("PASS: multi-round adversarial simulation -- emission identical to plain greedy (24/24)")


def test_inconsistent_account_detected() raises:
    var drafts: List[Int] = [10, 11]
    var target: List[Int] = [10, 11, 12]
    var a = plan_verify(PROPOSER_MTP_HEAD, drafts, target, 0, 512, 0, 0)
    expect_true(account_is_consistent(a), "derived account consistent")
    var broken = plan_verify(PROPOSER_MTP_HEAD, drafts, target, 0, 512, 0, 0)
    broken.kv_after += 1
    expect_false(account_is_consistent(broken), "tampered KV advance detected")
    var broken2 = plan_verify(PROPOSER_MTP_HEAD, drafts, target, 0, 512, 0, 0)
    broken2.rng_draws_consumed = 1
    expect_false(account_is_consistent(broken2), "smuggled RNG draw detected")
    print("PASS: inconsistent accounts detected mechanically")


def test_claim_verdicts() raises:
    expect_eq(
        evaluate_spec_claim(
            CLAIM_GREEDY_IDENTITY_BY_CONSTRUCTION, True, False, False, False
        ),
        SPEC_CLAIM_PERMITTED,
        "construction identity permitted on a consistent account",
    )
    expect_eq(
        evaluate_spec_claim(
            CLAIM_GREEDY_IDENTITY_BY_CONSTRUCTION, False, False, False, False
        ),
        SPEC_CLAIM_REFUSED,
        "construction identity refused on a broken account",
    )
    expect_eq(
        evaluate_spec_claim(
            CLAIM_LIVE_TOKEN_IDENTITY, True, False, False, False
        ),
        SPEC_CLAIM_REQUIRES_LIVE,
        "live identity requires filed ids",
    )
    expect_eq(
        evaluate_spec_claim(
            CLAIM_LIVE_TOKEN_IDENTITY, True, True, True, False
        ),
        SPEC_CLAIM_PERMITTED,
        "filed identical ids permit the live claim",
    )
    expect_eq(
        evaluate_spec_claim(
            CLAIM_LIVE_TOKEN_IDENTITY, True, True, False, False
        ),
        SPEC_CLAIM_REFUSED,
        "filed divergent ids refuse the live claim",
    )
    expect_eq(
        evaluate_spec_claim(CLAIM_SPEED_GAIN, True, True, True, False),
        SPEC_CLAIM_REQUIRES_LIVE,
        "no speed claim from accounting",
    )
    expect_eq(
        evaluate_spec_claim(CLAIM_SPEED_GAIN, True, True, True, True),
        SPEC_CLAIM_PERMITTED,
        "speed claim permitted only on live measurement",
    )
    if claim_name(SPEC_CLAIM_REQUIRES_LIVE) != String("REQUIRES_LIVE"):
        raise Error("SpeculativeVerify: claim name")
    var refused = 0
    try:
        _ = evaluate_spec_claim(99, True, True, True, True)
    except:
        refused += 1
    expect_eq(refused, 1, "unknown claim kind refused")
    print("PASS: claim verdicts -- construction / live identity / speed on every branch")


def main() raises:
    test_all_accepted_bonus_round()
    test_prefix_plus_correction()
    test_coincidence_past_mismatch_never_emitted()
    test_zero_accepted()
    test_band_and_proposer_caps()
    test_capacity_refusal()
    test_rng_invariant()
    test_validation_refusals()
    test_proposer_shapes()
    test_identity_checker()
    test_multi_round_identity_simulation()
    test_inconsistent_account_detected()
    test_claim_verdicts()
    print("ALL PASS: speculative verification account (13 groups)")
