"""Assistant-model draft pairing (J-078): the pair gate
between J-076's census, J-077's head gate, J-074's pairing
account, and J-071/J-072's draft loop.

Groups: a SIMULATED Gemma-pattern pair admitted in each of
its two forms (an assistant file carrying its own assistant
tensors, admitted through J-077's gate; and a standalone
small model of the family, admitted under J-074's pairing
discipline), in both cases under J-071's assistant shape
dispatched through J-072's head slot; the pair's memory
budget exact -- footprints, share, and the single shared
sizing through J-026's pool, headroom charged once; every
refusal class by name (empty name, missing file, uncensused
file with its carried names never counted, vocab-only on
either side, family mismatch and unknown family, an
MTP-head file refused as an assistant, tokenizer unverified
even with an identical comparison in hand, tokenizer
mismatch carrying its divergence index, assistant not
materially smaller, assistant over its budget share, k
outside the J-071 cap, and a starved shared pool); the
bounds admitted exactly (half resident, quarter share,
k at cap); and refusal lines naming both files, with a
refused pair yielding no drafter shape.

Evidence classes, stated plainly: every directory, token
table, and byte size below is a stated SIMULATED fixture in
the forms the road's filed records pre-registered -- no
Gemma pair file exists in any filed census (J-076 section
3: the assistant file is absent at ledger level and no
Gemma main file's directory has been read), so no fixture
here is, or claims to be, a real file. The real-file ground
this gate is filed against is in docs/janas/
j078_pair_record_output.txt (the roadmap's Gemma pair and
the VM's real files, each refused by name on filed facts).
Live pairing and measured gain are the deferred leg
(J-086 gate).
"""
from core.assistant_pairing import (
    ASSISTANT_ADMITTED,
    ASSISTANT_MAX_SHARE_PER_MILLE,
    ASSISTANT_NO_CENSUS_VERDICT,
    ASSISTANT_REFUSE_ASSISTANT_FORM,
    ASSISTANT_REFUSE_ASSISTANT_NOT_SMALLER,
    ASSISTANT_REFUSE_BUDGET_EXCEEDED,
    ASSISTANT_REFUSE_EMPTY_FILE_NAME,
    ASSISTANT_REFUSE_FAMILY_MISMATCH,
    ASSISTANT_REFUSE_K_OVER_CAP,
    ASSISTANT_REFUSE_MISSING_FILE,
    ASSISTANT_REFUSE_OVER_BUDGET_SHARE,
    ASSISTANT_REFUSE_TOKENIZER_MISMATCH,
    ASSISTANT_REFUSE_TOKENIZER_UNVERIFIED,
    ASSISTANT_REFUSE_UNCENSUSED_FILE,
    ASSISTANT_REFUSE_VOCAB_ONLY,
    ASSISTANT_ROUTE_HEAD,
    ASSISTANT_ROUTE_STANDALONE,
    AssistantPairVerdict,
    admitted_assistant_shape,
    assistant_k_cap,
    assistant_pair_refusal_line,
    assistant_reason_name,
    assistant_route_name,
    evaluate_assistant_pair,
)
from core.cross_model_pairing import (
    FAMILY_GEMMA4,
    FAMILY_QWEN3,
    FAMILY_UNKNOWN,
    ModelSide,
    TokenizerComparison,
    compare_tokenizers,
)
from core.expert_cache import plan_shared_cache_pool
from core.mtp_census import VERDICT_NO_MTP, VERDICT_VOCAB_ONLY, VERDICT_WITH_MTP
from core.speculative_loop import dispatch_proposer
from core.speculative_verify import (
    PROPOSER_ASSISTANT_MODEL,
    SLOT_HEAD,
    plan_proposer,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "AssistantPairing " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("AssistantPairing " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("AssistantPairing " + what + ": expected false")


def vocab_a() -> List[String]:
    var v = List[String]()
    v.append(String("<start_of_turn>"))
    v.append(String(" the"))
    v.append(String(" of"))
    v.append(String("Ġthe"))
    v.append(String("token"))
    return v.copy()


def vocab_b() -> List[String]:
    # Identical to vocab_a except at index 3.
    var v = vocab_a()
    v[3] = String("Ġdifferent")
    return v.copy()


def merges_a() -> List[String]:
    var m = List[String]()
    m.append(String("Ġ t"))
    m.append(String("th e"))
    return m.copy()


def identical_comparison() -> TokenizerComparison:
    return compare_tokenizers(
        vocab_a(), vocab_a(), merges_a(), merges_a(),
        String("gemma"), String("gemma"), 2, 2, 1, 1,
    )


def mismatched_comparison() -> TokenizerComparison:
    return compare_tokenizers(
        vocab_a(), vocab_b(), merges_a(), merges_a(),
        String("gemma"), String("gemma"), 2, 2, 1, 1,
    )


def target_directory() -> List[String]:
    var v = List[String]()
    v.append(String("token_embd.weight"))
    v.append(String("blk.0.attn_q.weight"))
    v.append(String("blk.0.ffn_gate.weight"))
    v.append(String("blk.0.ffn_down.weight"))
    v.append(String("output_norm.weight"))
    v.append(String("output.weight"))
    return v.copy()


def assistant_head_directory() -> List[String]:
    var v = List[String]()
    v.append(String("token_embd.weight"))
    v.append(String("assistant.blk.0.attn_q.weight"))
    v.append(String("assistant.draft.weight"))
    return v.copy()


def assistant_plain_directory() -> List[String]:
    var v = List[String]()
    v.append(String("token_embd.weight"))
    v.append(String("blk.0.attn_q.weight"))
    v.append(String("output.weight"))
    return v.copy()


def head_file_directory() -> List[String]:
    var v = List[String]()
    v.append(String("token_embd.weight"))
    v.append(String("blk.48.nextn.eh_proj.weight"))
    return v.copy()


# Stated scenario sizes (SIMULATED fixtures, not measurements):
# an 8 GiB-class Gemma target against a 1 GiB-class assistant.
def target_side() -> ModelSide:
    return ModelSide(FAMILY_GEMMA4, True, 8_000_000_000, 1_000_000_000, 100_000_000)


def assistant_head_side() -> ModelSide:
    # The census form: the assistant reads the target's KV,
    # so its own KV allowance is stated as 0.
    return ModelSide(FAMILY_GEMMA4, True, 1_000_000_000, 0, 50_000_000)


def assistant_plain_side() -> ModelSide:
    return ModelSide(FAMILY_GEMMA4, True, 1_000_000_000, 200_000_000, 50_000_000)


def judge(
    target_name: String,
    target: ModelSide,
    target_read: Bool,
    target_dir: List[String],
    assistant_name: String,
    assistant: ModelSide,
    assistant_read: Bool,
    assistant_dir: List[String],
    tokenizer: TokenizerComparison,
    verified: Bool,
    k: Int,
    free: Int,
) raises -> AssistantPairVerdict:
    return evaluate_assistant_pair(
        target_name, target, target_read, target_dir,
        assistant_name, assistant, assistant_read, assistant_dir,
        tokenizer, verified, k, free, 32_000_000_000, 0, 1_000_000,
    )


def head_pair(k: Int) raises -> AssistantPairVerdict:
    return judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), True,
        assistant_head_directory(), identical_comparison(), True, k,
        20_000_000_000,
    )


def plain_pair(k: Int) raises -> AssistantPairVerdict:
    return judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"), assistant_plain_side(), True,
        assistant_plain_directory(), identical_comparison(), True, k,
        20_000_000_000,
    )


def test_head_form_admitted() raises:
    var v = head_pair(4)
    expect_true(v.admitted, "head-form Gemma pair admitted (SIMULATED)")
    expect_eq(v.reason_code, ASSISTANT_ADMITTED, "admitted reason")
    expect_eq(v.route, ASSISTANT_ROUTE_HEAD, "head route")
    expect_eq(v.target_census_verdict, VERDICT_NO_MTP, "target census")
    expect_eq(v.assistant_census_verdict, VERDICT_WITH_MTP, "assistant census")
    expect_eq(v.assistant_head_count, 2, "assistant heads counted")
    expect_eq(v.assistant_nextn_count, 0, "no nextn heads")
    expect_eq(v.assistant_mtp_count, 0, "no mtp heads")
    expect_eq(v.assistant_kind_count, 2, "assistant-kind heads")
    expect_eq(v.proposer_kind, PROPOSER_ASSISTANT_MODEL, "assistant proposer")
    expect_eq(v.proposer_slot, SLOT_HEAD, "head slot")
    expect_true(v.requires_tokenizer_match, "assistant needs verified match")
    expect_false(v.carries_own_kv, "assistant carries no KV of its own")
    expect_eq(v.max_k, 15, "assistant cap from J-071")
    print("PASS: admission -- head-form assistant admitted through J-077 gate")


def test_standalone_admitted() raises:
    var v = plain_pair(4)
    expect_true(v.admitted, "standalone Gemma pair admitted (SIMULATED)")
    expect_eq(v.route, ASSISTANT_ROUTE_STANDALONE, "standalone route")
    expect_eq(v.assistant_census_verdict, VERDICT_NO_MTP, "assistant census")
    expect_eq(v.assistant_head_count, 0, "standalone assistant has no heads")
    expect_eq(v.proposer_kind, PROPOSER_ASSISTANT_MODEL, "assistant proposer")
    expect_eq(v.proposer_slot, SLOT_HEAD, "head slot")
    # The family rule is same-known-family, not Gemma-only:
    # a same-family Qwen pair in standalone form admits too.
    var q = judge(
        String("qwen-target.gguf"),
        ModelSide(FAMILY_QWEN3, True, 8_000_000_000, 1_000_000_000, 100_000_000),
        True, target_directory(),
        String("qwen-assistant.gguf"),
        ModelSide(FAMILY_QWEN3, True, 1_000_000_000, 200_000_000, 50_000_000),
        True, assistant_plain_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    expect_true(q.admitted, "same-family Qwen standalone pair admitted")
    print("PASS: admission -- standalone small model of the family admitted")


def test_budget_arithmetic_exact() raises:
    var v = head_pair(4)
    expect_eq(v.target_footprint_bytes, 9_100_000_000, "target footprint")
    expect_eq(v.assistant_footprint_bytes, 1_050_000_000, "assistant footprint")
    expect_eq(v.pair_footprint_bytes, 10_150_000_000, "pair footprint")
    expect_eq(v.assistant_share_per_mille, 103, "assistant share per mille")
    expect_true(
        v.assistant_share_per_mille <= ASSISTANT_MAX_SHARE_PER_MILLE,
        "share inside the pre-registered quarter bound",
    )
    expect_eq(v.pair_resident_bytes, 9_000_000_000, "pair resident summed")
    expect_eq(v.pair_kv_allowance_bytes, 1_000_000_000, "pair KV summed")
    expect_true(v.budget_checked, "budget rule reached")
    var direct = plan_shared_cache_pool(
        20_000_000_000, 32_000_000_000, 0,
        9_000_000_000, 1_000_000_000, 150_000_000, 1_000_000,
    )
    expect_eq(v.sizing.budget_bytes, direct.budget_bytes, "sizing == direct pool")
    expect_eq(v.sizing.reserve_bytes, direct.reserve_bytes, "reserve == direct")
    expect_eq(v.sizing.budget_bytes, 3_450_000_000, "exact pair budget")
    expect_eq(v.sizing.reserve_bytes, 16_550_000_000, "exact pair reserve")
    expect_eq(
        v.sizing.os_headroom_bytes, 6_400_000_000,
        "OS headroom charged once (total // 5)",
    )
    expect_false(v.sizing.below_floor, "budget above the one-token floor")
    var p = plain_pair(4)
    expect_eq(p.assistant_footprint_bytes, 1_250_000_000, "standalone footprint")
    expect_eq(p.pair_footprint_bytes, 10_350_000_000, "standalone pair footprint")
    expect_eq(p.assistant_share_per_mille, 120, "standalone share per mille")
    expect_eq(p.sizing.budget_bytes, 3_250_000_000, "exact standalone budget")
    expect_eq(p.sizing.reserve_bytes, 16_750_000_000, "exact standalone reserve")
    print("PASS: budget -- pair sized once, exact arithmetic, headroom once")


def test_missing_empty_uncensused_vocab() raises:
    var empty_name = judge(
        String(""), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), True,
        assistant_head_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    expect_eq(
        empty_name.reason_code, ASSISTANT_REFUSE_EMPTY_FILE_NAME, "empty target"
    )
    var missing = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"),
        ModelSide(FAMILY_GEMMA4, False, 1_000_000_000, 0, 50_000_000),
        True, assistant_head_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    expect_eq(missing.reason_code, ASSISTANT_REFUSE_MISSING_FILE, "missing file")
    # Uncensused: head-shaped names carried beside an unread
    # directory are never trusted, counted, or classified.
    var unc = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), False,
        assistant_head_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    expect_eq(
        unc.reason_code, ASSISTANT_REFUSE_UNCENSUSED_FILE, "uncensused assistant"
    )
    expect_eq(
        unc.assistant_census_verdict, ASSISTANT_NO_CENSUS_VERDICT,
        "no verdict invented for an unread directory",
    )
    expect_eq(unc.assistant_head_count, 0, "carried names never counted")
    var unc_t = judge(
        String("gemma-target.gguf"), target_side(), False, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), True,
        assistant_head_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    expect_eq(
        unc_t.reason_code, ASSISTANT_REFUSE_UNCENSUSED_FILE, "uncensused target"
    )
    var empty_dir = List[String]()
    var vocab = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("ggml-vocab-gemma-4.gguf"), assistant_head_side(), True,
        empty_dir, identical_comparison(), True, 4, 20_000_000_000,
    )
    expect_eq(vocab.reason_code, ASSISTANT_REFUSE_VOCAB_ONLY, "vocab assistant")
    expect_eq(
        vocab.assistant_census_verdict, VERDICT_VOCAB_ONLY, "vocab verdict filed"
    )
    print("PASS: refusal -- empty / missing / uncensused / vocab-only by name")


def test_family_refusals() raises:
    var cross = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("qwen-assistant.gguf"),
        ModelSide(FAMILY_QWEN3, True, 1_000_000_000, 0, 50_000_000),
        True, assistant_head_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    expect_eq(cross.reason_code, ASSISTANT_REFUSE_FAMILY_MISMATCH, "cross-family")
    var unknown = judge(
        String("gemma-target.gguf"),
        ModelSide(FAMILY_UNKNOWN, True, 8_000_000_000, 1_000_000_000, 100_000_000),
        True, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), True,
        assistant_head_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    expect_eq(
        unknown.reason_code, ASSISTANT_REFUSE_FAMILY_MISMATCH, "unknown family"
    )
    print("PASS: refusal -- family mismatch and unknown family refused")


def test_assistant_form_refusal() raises:
    # A file carrying nextn heads is an MTP head file: J-077
    # owns it under the MTP-head kind; this gate refuses it
    # AS AN ASSISTANT rather than re-filing it as one.
    var nextn = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), True,
        head_file_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    expect_eq(nextn.reason_code, ASSISTANT_REFUSE_ASSISTANT_FORM, "nextn form")
    expect_eq(nextn.assistant_census_verdict, VERDICT_WITH_MTP, "with-mtp census")
    expect_eq(nextn.assistant_nextn_count, 1, "nextn head counted")
    var mixed_dir = assistant_head_directory()
    mixed_dir.append(String("blk.48.nextn.eh_proj.weight"))
    var mixed = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), True,
        mixed_dir, identical_comparison(), True, 4, 20_000_000_000,
    )
    expect_eq(mixed.reason_code, ASSISTANT_REFUSE_ASSISTANT_FORM, "mixed form")
    print("PASS: refusal -- MTP-head files refused as assistants by name")


def test_tokenizer_gate() raises:
    var unverified = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), True,
        assistant_head_directory(), identical_comparison(), False, 4,
        20_000_000_000,
    )
    expect_eq(
        unverified.reason_code, ASSISTANT_REFUSE_TOKENIZER_UNVERIFIED,
        "unverified refused even with an identical comparison in hand",
    )
    expect_false(unverified.budget_checked, "budget unreached on tokenizer refusal")
    var mismatch = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), True,
        assistant_head_directory(), mismatched_comparison(), True, 4,
        20_000_000_000,
    )
    expect_eq(
        mismatch.reason_code, ASSISTANT_REFUSE_TOKENIZER_MISMATCH, "mismatch"
    )
    expect_eq(mismatch.first_token_divergence, 3, "divergence index carried")
    print("PASS: tokenizer gate -- unverified refused, mismatch at its index")


def test_size_and_share_refusals() raises:
    var big = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"),
        ModelSide(FAMILY_GEMMA4, True, 5_000_000_000, 0, 50_000_000),
        True, assistant_head_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    expect_eq(
        big.reason_code, ASSISTANT_REFUSE_ASSISTANT_NOT_SMALLER, "over half"
    )
    # Exactly half the resident bytes, share inside the bound: admitted.
    var half = judge(
        String("gemma-target.gguf"),
        ModelSide(FAMILY_GEMMA4, True, 8_000_000_000, 8_000_000_000, 0),
        True, target_directory(),
        String("gemma-assistant.gguf"),
        ModelSide(FAMILY_GEMMA4, True, 4_000_000_000, 0, 0),
        True, assistant_plain_directory(), identical_comparison(), True, 4,
        40_000_000_000,
    )
    expect_true(half.admitted, "exactly-half assistant admitted")
    expect_eq(half.assistant_share_per_mille, 200, "half-case share")
    # Resident passes rule 6, but a large private KV demand
    # pushes the assistant over its quarter share: refused.
    var greedy = judge(
        String("gemma-target.gguf"),
        ModelSide(FAMILY_GEMMA4, True, 8_000_000_000, 0, 0),
        True, target_directory(),
        String("gemma-assistant.gguf"),
        ModelSide(FAMILY_GEMMA4, True, 3_000_000_000, 2_000_000_000, 0),
        True, assistant_plain_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    expect_eq(
        greedy.reason_code, ASSISTANT_REFUSE_OVER_BUDGET_SHARE, "over share"
    )
    expect_eq(greedy.assistant_share_per_mille, 384, "over-share arithmetic")
    # Exactly the quarter share: admitted.
    var exact = judge(
        String("gemma-target.gguf"),
        ModelSide(FAMILY_GEMMA4, True, 9_000_000_000, 3_000_000_000, 0),
        True, target_directory(),
        String("gemma-assistant.gguf"),
        ModelSide(FAMILY_GEMMA4, True, 2_000_000_000, 2_000_000_000, 0),
        True, assistant_plain_directory(), identical_comparison(), True, 4,
        40_000_000_000,
    )
    expect_true(exact.admitted, "exactly-quarter-share assistant admitted")
    expect_eq(
        exact.assistant_share_per_mille, ASSISTANT_MAX_SHARE_PER_MILLE,
        "share exactly at the bound",
    )
    print("PASS: refusal -- not-smaller and over-share; both bounds exact-admit")


def test_k_and_budget_refusals() raises:
    var k0 = head_pair(0)
    expect_eq(k0.reason_code, ASSISTANT_REFUSE_K_OVER_CAP, "k=0 refused")
    var k16 = head_pair(16)
    expect_eq(k16.reason_code, ASSISTANT_REFUSE_K_OVER_CAP, "k=16 refused")
    var k15 = head_pair(15)
    expect_true(k15.admitted, "k at the J-071 cap admitted")
    var starved = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), True,
        assistant_head_directory(), identical_comparison(), True, 4,
        10_000_000_000,
    )
    expect_eq(
        starved.reason_code, ASSISTANT_REFUSE_BUDGET_EXCEEDED, "starved pool"
    )
    expect_true(starved.budget_checked, "budget refusal comes from the sizing")
    expect_eq(starved.sizing.budget_bytes, 0, "starved pool budget is zero")
    print("PASS: k and budget refusals -- cap enforced, starved pool refused")


def test_refusal_lines_and_no_shape() raises:
    var fam = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("qwen-assistant.gguf"),
        ModelSide(FAMILY_QWEN3, True, 1_000_000_000, 0, 50_000_000),
        True, assistant_head_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    var line = assistant_pair_refusal_line(fam)
    expect_true("REFUSED" in line, "refusal line says refused")
    expect_true("gemma-target.gguf" in line, "line names the target")
    expect_true("qwen-assistant.gguf" in line, "line names the assistant")
    expect_true("REFUSE_FAMILY_MISMATCH" in line, "line names the reason")
    expect_true("not run" in line, "line bars running the pair")
    var ok_line = assistant_pair_refusal_line(head_pair(4))
    expect_true("ADMITTED" in ok_line, "admitted line says admitted")
    expect_true("head_assistant" in ok_line, "admitted line names the route")
    var refused = 0
    try:
        _ = admitted_assistant_shape(fam)
    except:
        refused += 1
    var tok = judge(
        String("gemma-target.gguf"), target_side(), True, target_directory(),
        String("gemma-assistant.gguf"), assistant_head_side(), True,
        assistant_head_directory(), identical_comparison(), False, 4,
        20_000_000_000,
    )
    try:
        _ = admitted_assistant_shape(tok)
    except:
        refused += 1
    var share = judge(
        String("gemma-target.gguf"),
        ModelSide(FAMILY_GEMMA4, True, 8_000_000_000, 0, 0),
        True, target_directory(),
        String("gemma-assistant.gguf"),
        ModelSide(FAMILY_GEMMA4, True, 3_000_000_000, 2_000_000_000, 0),
        True, assistant_plain_directory(), identical_comparison(), True, 4,
        20_000_000_000,
    )
    try:
        _ = admitted_assistant_shape(share)
    except:
        refused += 1
    expect_eq(refused, 3, "every refusal class yields no shape (3/3)")
    var shape = admitted_assistant_shape(head_pair(4))
    var dispatched = dispatch_proposer(SLOT_HEAD, PROPOSER_ASSISTANT_MODEL)
    expect_eq(shape.kind, dispatched.kind, "shape is J-072's dispatch")
    expect_eq(shape.slot, dispatched.slot, "shape slot is the dispatch's")
    expect_eq(shape.max_k, dispatched.max_k, "shape cap is the dispatch's")
    expect_eq(
        assistant_k_cap(), plan_proposer(PROPOSER_ASSISTANT_MODEL).max_k,
        "k cap read from J-071",
    )
    expect_true(
        assistant_reason_name(ASSISTANT_ADMITTED) == "ADMITTED", "reason admitted"
    )
    expect_true(
        assistant_reason_name(ASSISTANT_REFUSE_OVER_BUDGET_SHARE)
        == "REFUSE_OVER_BUDGET_SHARE",
        "reason over-share",
    )
    expect_true(
        assistant_route_name(ASSISTANT_ROUTE_HEAD) == "head_assistant",
        "route name head",
    )
    expect_true(
        assistant_route_name(ASSISTANT_ROUTE_STANDALONE) == "standalone_model",
        "route name standalone",
    )
    print("PASS: record -- lines name both files; refused pairs yield no shape")


def main() raises:
    test_head_form_admitted()
    test_standalone_admitted()
    test_budget_arithmetic_exact()
    test_missing_empty_uncensused_vocab()
    test_family_refusals()
    test_assistant_form_refusal()
    test_tokenizer_gate()
    test_size_and_share_refusals()
    test_k_and_budget_refusals()
    test_refusal_lines_and_no_shape()
    print("ALL PASS: assistant-model draft pairing (10 groups)")
