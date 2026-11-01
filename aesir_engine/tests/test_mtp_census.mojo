"""MTP census classifier (J-076): the stated name rules
(nextn / mtp / assistant substrings, first match in that
order); ordinary directory names -- including the real
expert-tensor names from J-015's filed directories --
classifying as no-head; a census row accumulating counts
per kind; and the three file verdicts (an empty directory
is VOCAB_ONLY, a fully-read ordinary directory is NO_MTP,
any head tensor makes WITH_MTP). All names in this suite
are stated fixtures: the head-shaped names are the GGUF
naming forms for the censused cases, not names read from
any real file tonight (the real directories the census
read are filed in docs/janas/j076_census_output.txt, and
every VM-present model file in it is NO_MTP)."""
from core.mtp_census import (
    HEAD_ASSISTANT,
    HEAD_MTP,
    HEAD_NEXTN,
    HEAD_NONE,
    VERDICT_NO_MTP,
    VERDICT_VOCAB_ONLY,
    VERDICT_WITH_MTP,
    MtpCensus,
    classify_tensor_name,
    head_kind_name,
    verdict_name,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "MtpCensus " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("MtpCensus " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("MtpCensus " + what + ": expected false")


def test_nextn_names() raises:
    expect_eq(
        classify_tensor_name("blk.48.nextn.eh_proj.weight"),
        HEAD_NEXTN, "nextn block tensor",
    )
    expect_eq(
        classify_tensor_name("nextn.predict_norm.weight"),
        HEAD_NEXTN, "nextn prefix tensor",
    )
    print("PASS: classifier -- nextn names")


def test_mtp_names() raises:
    expect_eq(
        classify_tensor_name("blk.27.mtp.fc.weight"),
        HEAD_MTP, "mtp block tensor",
    )
    expect_eq(
        classify_tensor_name("mtp_head.weight"),
        HEAD_MTP, "mtp head tensor",
    )
    print("PASS: classifier -- mtp names")


def test_assistant_names() raises:
    expect_eq(
        classify_tensor_name("assistant_embd.weight"),
        HEAD_ASSISTANT, "assistant tensor",
    )
    print("PASS: classifier -- assistant names")


def test_ordinary_names_no_head() raises:
    # Ordinary names, including the real expert-tensor names
    # filed by J-015's full-directory scans.
    for name in [
        "token_embd.weight",
        "output.weight",
        "output_norm.weight",
        "blk.0.attn_q.weight",
        "blk.0.attn_norm.weight",
        "blk.0.ffn_gate_exps.weight",
        "blk.0.ffn_up_exps.weight",
        "blk.0.ffn_down_exps.weight",
        "blk.0.ffn_gate_inp.weight",
        "blk.15.ffn_norm.weight",
    ]:
        expect_eq(
            classify_tensor_name(name), HEAD_NONE, "ordinary " + name,
        )
    print("PASS: classifier -- ordinary names carry no head")


def test_first_match_order() raises:
    # A name carrying two markers files under the first rule.
    expect_eq(
        classify_tensor_name("blk.48.nextn.mtp_proj.weight"),
        HEAD_NEXTN, "nextn wins over mtp",
    )
    print("PASS: classifier -- first-match order nextn before mtp")


def test_census_aggregation() raises:
    var c = MtpCensus()
    c.record("token_embd.weight")
    c.record("blk.0.attn_q.weight")
    c.record("blk.48.nextn.eh_proj.weight")
    c.record("blk.48.nextn.embed_tokens.weight")
    c.record("blk.27.mtp.fc.weight")
    expect_eq(c.n_tensors, 5, "total tensors")
    expect_eq(c.nextn_count, 2, "nextn count")
    expect_eq(c.mtp_count, 1, "mtp count")
    expect_eq(c.assistant_count, 0, "assistant count")
    expect_eq(c.head_count(), 3, "head total")
    expect_true(c.has_head(), "has head")
    expect_eq(c.verdict(), VERDICT_WITH_MTP, "verdict with head")
    print("PASS: census -- aggregation counts per kind")


def test_verdicts() raises:
    var empty = MtpCensus()
    expect_eq(empty.verdict(), VERDICT_VOCAB_ONLY, "empty is vocab-only")
    expect_false(empty.has_head(), "empty has no head")
    var plain = MtpCensus()
    plain.record("token_embd.weight")
    plain.record("blk.0.ffn_gate_exps.weight")
    expect_eq(plain.verdict(), VERDICT_NO_MTP, "ordinary is no-mtp")
    expect_false(plain.has_head(), "ordinary has no head")
    print("PASS: census -- verdicts vocab-only / no-mtp / with-mtp")


def test_names_round_trip() raises:
    expect_true(head_kind_name(HEAD_NEXTN) == "nextn", "nextn name")
    expect_true(head_kind_name(HEAD_MTP) == "mtp", "mtp name")
    expect_true(
        head_kind_name(HEAD_ASSISTANT) == "assistant", "assistant name"
    )
    expect_true(head_kind_name(HEAD_NONE) == "none", "none name")
    expect_true(verdict_name(VERDICT_WITH_MTP) == "WITH_MTP", "with name")
    expect_true(verdict_name(VERDICT_NO_MTP) == "NO_MTP", "no name")
    expect_true(
        verdict_name(VERDICT_VOCAB_ONLY) == "VOCAB_ONLY", "vocab name"
    )
    print("PASS: census -- kind and verdict names")


def main() raises:
    test_nextn_names()
    test_mtp_names()
    test_assistant_names()
    test_ordinary_names_no_head()
    test_first_match_order()
    test_census_aggregation()
    test_verdicts()
    test_names_round_trip()
    print("ALL PASS: mtp census classifier (8 groups)")
