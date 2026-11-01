"""Cross-model draft pairing (J-074): tokenizer tables
compared token-for-token (identity exact; a single differing
token refused at its index; a length difference diverging at
the shorter length; merges compared with the same discipline
and a one-sided merges section itself a mismatch; model /
BOS / EOS inequality breaking identity); the six pairing
rules each refusing mechanically with their named reason in
rule order (missing file, unknown or cross family, drafter
not materially smaller, tokenizer unverified -- even when
the comparison in hand is identical -- tokenizer mismatch
carrying its divergence index, k outside the cross-model
slot's cap taken from J-071's account, and the pair's summed
reserve leaving no shared budget); and one admissible pair
whose memory is sized ONCE through J-026's shared pool over
the summed quantities. No forward runs and no file reads:
the token tables and byte sizes below are stated fixtures
checking the pairing machinery only -- the real-file
tokenizer evidence is the J-074 doc's probe record, and
live pairing is the deferred leg (J-086 gate).
"""
from core.cross_model_pairing import (
    FAMILY_GEMMA4,
    FAMILY_LLAMA3,
    FAMILY_QWEN3,
    FAMILY_UNKNOWN,
    MERGES_BOTH_ABSENT,
    MERGES_BOTH_COMPARED,
    MERGES_ONE_SIDED,
    PAIR_ADMISSIBLE,
    PAIR_REFUSE_BUDGET_EXCEEDED,
    PAIR_REFUSE_DRAFTER_NOT_SMALLER,
    PAIR_REFUSE_K_OVER_CAP,
    PAIR_REFUSE_MISSING_FILE,
    PAIR_REFUSE_TOKENIZER_MISMATCH,
    PAIR_REFUSE_TOKENIZER_UNVERIFIED,
    PAIR_REFUSE_UNKNOWN_FAMILY_PAIRING,
    ModelSide,
    TokenizerComparison,
    compare_tokenizers,
    cross_model_k_cap,
    evaluate_pair,
    pair_reason_name,
)
from core.expert_cache import plan_shared_cache_pool
from core.speculative_verify import PROPOSER_CROSS_MODEL, plan_proposer


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "CrossModelPairing " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("CrossModelPairing " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("CrossModelPairing " + what + ": expected false")


def vocab_a() -> List[String]:
    var v = List[String]()
    v.append(String("<|endoftext|>"))
    v.append(String(" the"))
    v.append(String(" of"))
    v.append(String("Ġthe"))
    v.append(String("token"))
    return v.copy()


def merges_a() -> List[String]:
    var m = List[String]()
    m.append(String("Ġ t"))
    m.append(String("th e"))
    return m.copy()


def identical_comparison() -> TokenizerComparison:
    return compare_tokenizers(
        vocab_a(), vocab_a(), merges_a(), merges_a(),
        String("gpt2"), String("gpt2"), 151643, 151643, 151643, 151643,
    )


# Stated scenario sizes (fixtures, not measurements): a
# 0.6B-class drafter against a 4B-class target, the
# documented first pair's shape.
def drafter_side() -> ModelSide:
    return ModelSide(FAMILY_QWEN3, True, 380_000_000, 60_000_000, 10_000_000)


def target_side() -> ModelSide:
    return ModelSide(FAMILY_QWEN3, True, 2_400_000_000, 200_000_000, 10_000_000)


def judge(
    drafter: ModelSide,
    target: ModelSide,
    tokenizer: TokenizerComparison,
    verified: Bool,
    k: Int,
    free: Int,
) raises -> Int:
    var v = evaluate_pair(
        drafter, target, tokenizer, verified, k, free, 16_000_000_000, 0, 1_000_000
    )
    return v.reason_code


def test_tokenizer_identity_exact() raises:
    var cmp = identical_comparison()
    expect_true(cmp.identical(), "identical tables are identical")
    expect_eq(cmp.token_mismatches, 0, "token mismatches")
    expect_eq(cmp.first_token_divergence, -1, "token divergence")
    expect_eq(cmp.vocab_compared, 5, "vocab compared")
    expect_eq(cmp.merges_state, MERGES_BOTH_COMPARED, "merges state")
    expect_eq(cmp.merge_mismatches, 0, "merge mismatches")
    expect_eq(cmp.first_merge_divergence, -1, "merge divergence")
    print("PASS: tokenizer identity -- full tables equal, divergences -1")


def test_tokenizer_single_token_mismatch() raises:
    var other = vocab_a()
    other[3] = String("Ġdifferent")
    var cmp = compare_tokenizers(
        vocab_a(), other, merges_a(), merges_a(),
        String("gpt2"), String("gpt2"), 1, 1, 2, 2,
    )
    expect_false(cmp.identical(), "one differing token breaks identity")
    expect_eq(cmp.token_mismatches, 1, "exactly one mismatch")
    expect_eq(cmp.first_token_divergence, 3, "divergence at the changed index")
    print("PASS: tokenizer mismatch -- one token, refused at its index")


def test_tokenizer_length_and_merges() raises:
    var longer = vocab_a()
    longer.append(String("extra"))
    var cmp = compare_tokenizers(
        vocab_a(), longer, merges_a(), merges_a(),
        String("gpt2"), String("gpt2"), 1, 1, 2, 2,
    )
    expect_false(cmp.identical(), "length difference breaks identity")
    expect_eq(cmp.first_token_divergence, 5, "diverges at the shorter length")
    expect_eq(cmp.token_mismatches, 1, "past-the-end counts once per index")
    var bad_merges = merges_a()
    bad_merges[1] = String("x y")
    var cmp2 = compare_tokenizers(
        vocab_a(), vocab_a(), merges_a(), bad_merges,
        String("gpt2"), String("gpt2"), 1, 1, 2, 2,
    )
    expect_false(cmp2.identical(), "a differing merge breaks identity")
    expect_eq(cmp2.first_merge_divergence, 1, "merge divergence index")
    var no_merges = List[String]()
    var cmp3 = compare_tokenizers(
        vocab_a(), vocab_a(), merges_a(), no_merges,
        String("gpt2"), String("gpt2"), 1, 1, 2, 2,
    )
    expect_eq(cmp3.merges_state, MERGES_ONE_SIDED, "one-sided merges state")
    expect_false(cmp3.identical(), "one-sided merges is a mismatch")
    var cmp4 = compare_tokenizers(
        vocab_a(), vocab_a(), no_merges, no_merges.copy(),
        String("llama-bpe"), String("llama-bpe"), 1, 1, 2, 2,
    )
    expect_eq(cmp4.merges_state, MERGES_BOTH_ABSENT, "both-absent merges state")
    expect_true(cmp4.identical(), "both-absent merges can be identical")
    print("PASS: tokenizer length + merges -- divergence, one-sided, both-absent")


def test_tokenizer_model_and_special_ids() raises:
    var cmp = compare_tokenizers(
        vocab_a(), vocab_a(), merges_a(), merges_a(),
        String("gpt2"), String("llama-bpe"), 1, 1, 2, 2,
    )
    expect_false(cmp.identical(), "different tokenizer model breaks identity")
    var cmp2 = compare_tokenizers(
        vocab_a(), vocab_a(), merges_a(), merges_a(),
        String("gpt2"), String("gpt2"), 1, 9, 2, 2,
    )
    expect_false(cmp2.identical(), "different BOS breaks identity")
    var cmp3 = compare_tokenizers(
        vocab_a(), vocab_a(), merges_a(), merges_a(),
        String("gpt2"), String("gpt2"), 1, 1, 2, 9,
    )
    expect_false(cmp3.identical(), "different EOS breaks identity")
    print("PASS: tokenizer model/BOS/EOS -- each inequality breaks identity")


def test_admissible_pair_and_shared_sizing() raises:
    var v = evaluate_pair(
        drafter_side(), target_side(), identical_comparison(), True, 4,
        8_000_000_000, 16_000_000_000, 0, 1_000_000,
    )
    expect_true(v.admissible, "the stated pair is admissible")
    expect_eq(v.reason_code, PAIR_ADMISSIBLE, "admissible reason")
    expect_eq(v.k_cap, 15, "k cap is the band cap")
    expect_eq(v.k_cap, plan_proposer(PROPOSER_CROSS_MODEL).max_k,
              "k cap taken from J-071's cross-model shape")
    expect_eq(v.k_cap, cross_model_k_cap(), "k cap helper agrees")
    expect_eq(v.pair_resident_bytes, 2_780_000_000, "resident bytes summed")
    expect_eq(v.pair_kv_allowance_bytes, 260_000_000, "KV allowances summed")
    expect_true(v.budget_checked, "budget rule reached")
    # The pair is sized ONCE through J-026's shared pool over
    # the summed quantities -- identical sizing, headroom once.
    var direct = plan_shared_cache_pool(
        8_000_000_000, 16_000_000_000, 0, 2_780_000_000, 260_000_000,
        20_000_000, 1_000_000,
    )
    expect_eq(v.sizing.budget_bytes, direct.budget_bytes, "shared sizing budget")
    expect_eq(v.sizing.reserve_bytes, direct.reserve_bytes, "shared sizing reserve")
    expect_eq(v.sizing.os_headroom_bytes, 3_200_000_000, "OS headroom charged once")
    expect_true(v.sizing.budget_bytes > 0, "pool budget positive")
    print("PASS: admissible pair -- k cap from J-071, memory sized once (J-026)")


def test_missing_file_refusals() raises:
    var no_drafter = ModelSide(FAMILY_QWEN3, False, 380_000_000, 60_000_000, 10_000_000)
    expect_eq(
        judge(no_drafter, target_side(), identical_comparison(), True, 4, 8_000_000_000),
        PAIR_REFUSE_MISSING_FILE, "missing drafter file refused")
    var no_target = ModelSide(FAMILY_QWEN3, False, 2_400_000_000, 200_000_000, 10_000_000)
    expect_eq(
        judge(drafter_side(), no_target, identical_comparison(), True, 4, 8_000_000_000),
        PAIR_REFUSE_MISSING_FILE, "missing target file refused")
    print("PASS: missing-file refusals -- either side, named reason")


def test_family_refusals() raises:
    var gemma_drafter = ModelSide(FAMILY_GEMMA4, True, 380_000_000, 60_000_000, 10_000_000)
    expect_eq(
        judge(gemma_drafter, target_side(), identical_comparison(), True, 4, 8_000_000_000),
        PAIR_REFUSE_UNKNOWN_FAMILY_PAIRING, "cross-family pair refused")
    var unknown_drafter = ModelSide(FAMILY_UNKNOWN, True, 380_000_000, 60_000_000, 10_000_000)
    expect_eq(
        judge(unknown_drafter, target_side(), identical_comparison(), True, 4, 8_000_000_000),
        PAIR_REFUSE_UNKNOWN_FAMILY_PAIRING, "unknown family refused")
    var llama_pair_d = ModelSide(FAMILY_LLAMA3, True, 380_000_000, 60_000_000, 10_000_000)
    var llama_pair_t = ModelSide(FAMILY_LLAMA3, True, 2_400_000_000, 200_000_000, 10_000_000)
    expect_eq(
        judge(llama_pair_d, llama_pair_t, identical_comparison(), True, 4, 8_000_000_000),
        PAIR_ADMISSIBLE, "same known family (llama3) is a known pairing")
    print("PASS: family refusals -- cross-family and unknown refused, same-family admitted")


def test_size_refusals() raises:
    var equal_drafter = ModelSide(FAMILY_QWEN3, True, 2_400_000_000, 60_000_000, 10_000_000)
    expect_eq(
        judge(equal_drafter, target_side(), identical_comparison(), True, 4, 8_000_000_000),
        PAIR_REFUSE_DRAFTER_NOT_SMALLER, "drafter == target refused")
    var sixty = ModelSide(FAMILY_QWEN3, True, 1_440_000_000, 60_000_000, 10_000_000)
    expect_eq(
        judge(sixty, target_side(), identical_comparison(), True, 4, 8_000_000_000),
        PAIR_REFUSE_DRAFTER_NOT_SMALLER, "drafter at 60% is not materially smaller")
    var half = ModelSide(FAMILY_QWEN3, True, 1_200_000_000, 60_000_000, 10_000_000)
    expect_eq(
        judge(half, target_side(), identical_comparison(), True, 4, 8_000_000_000),
        PAIR_ADMISSIBLE, "drafter at exactly half passes the size rule")
    print("PASS: size refusals -- equal and 60% refused, exactly-half admitted")


def test_tokenizer_gate_refusals() raises:
    expect_eq(
        judge(drafter_side(), target_side(), identical_comparison(), False, 4, 8_000_000_000),
        PAIR_REFUSE_TOKENIZER_UNVERIFIED,
        "identical-but-unverified comparison still refused")
    var other = vocab_a()
    other[3] = String("Ġdifferent")
    var mismatched = compare_tokenizers(
        vocab_a(), other, merges_a(), merges_a(),
        String("gpt2"), String("gpt2"), 151643, 151643, 151643, 151643,
    )
    var v = evaluate_pair(
        drafter_side(), target_side(), mismatched, True, 4,
        8_000_000_000, 16_000_000_000, 0, 1_000_000,
    )
    expect_eq(v.reason_code, PAIR_REFUSE_TOKENIZER_MISMATCH, "mismatch refused")
    expect_eq(v.first_token_divergence, 3, "verdict carries the divergence index")
    expect_false(v.budget_checked, "budget not reached on a tokenizer refusal")
    print("PASS: tokenizer gate -- unverified refused, mismatch refused with index")


def test_k_and_budget_refusals() raises:
    expect_eq(
        judge(drafter_side(), target_side(), identical_comparison(), True, 0, 8_000_000_000),
        PAIR_REFUSE_K_OVER_CAP, "k=0 refused")
    expect_eq(
        judge(drafter_side(), target_side(), identical_comparison(), True, 16, 8_000_000_000),
        PAIR_REFUSE_K_OVER_CAP, "k=16 refused (over the slot cap)")
    expect_eq(
        judge(drafter_side(), target_side(), identical_comparison(), True, 15, 8_000_000_000),
        PAIR_ADMISSIBLE, "k=15 (cap) admitted")
    var v = evaluate_pair(
        drafter_side(), target_side(), identical_comparison(), True, 4,
        3_000_000_000, 16_000_000_000, 0, 1_000_000,
    )
    expect_eq(v.reason_code, PAIR_REFUSE_BUDGET_EXCEEDED, "starved pool refused")
    expect_true(v.budget_checked, "budget refusal comes from the sizing")
    expect_eq(v.sizing.budget_bytes, 0, "starved pool budget is zero")
    var named = pair_reason_name(PAIR_REFUSE_BUDGET_EXCEEDED)
    expect_true(named == String("REFUSE_BUDGET_EXCEEDED"), "reason names itself")
    print("PASS: k and budget refusals -- cap enforced, starved pool refused")


def main() raises:
    test_tokenizer_identity_exact()
    test_tokenizer_single_token_mismatch()
    test_tokenizer_length_and_merges()
    test_tokenizer_model_and_special_ids()
    test_admissible_pair_and_shared_sizing()
    test_missing_file_refusals()
    test_family_refusals()
    test_size_refusals()
    test_tokenizer_gate_refusals()
    test_k_and_budget_refusals()
    print("ALL PASS: cross-model draft pairing (10 groups)")
