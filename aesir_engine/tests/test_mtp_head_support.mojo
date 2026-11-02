"""MTP head support (J-077): the admission gate between
J-076's census and J-071/J-072's draft loop.

Groups: a synthetic WITH_MTP directory (nextn form, then a
mixed nextn+mtp+assistant form) admitted with every head
tensor named in directory order and the drafter shape taken
from J-071/J-072, never restated; an assistant-only directory
admitted under the assistant shape (tokenizer match required);
real-file rows from J-076's census refused by name (zen-4b
qwen3 and tinyllama under NO_MTP, the vocab fixtures under
VOCAB_ONLY); an uncensused file refused as NOT PROVEN even
when the names carried beside it are head-shaped; an empty
file name refused; every refusal line naming file + verdict
+ reason; a refused admission yielding no drafter shape; and
the k cap read from J-071's account.

Evidence classes, stated plainly: the WITH_MTP directories
are SIMULATED -- stated fixture names in the GGUF naming
forms J-076 pre-registered, not names read from any real
file (no WITH_MTP file exists in any filed census). The
NO_MTP / VOCAB_ONLY groups carry PROVEN file identities and
verdicts from J-076's filed census (the files, their pins,
and their full-directory verdicts are J-076 section 2); the
directories fed here for those files are the stated ordinary
names -- the full real directories are filed in
docs/janas/j076_census_output.txt and their admission over
the filed census rows is filed in
docs/janas/j077_admission_output.txt.
"""
from core.mtp_census import (
    HEAD_ASSISTANT,
    HEAD_MTP,
    HEAD_NEXTN,
    VERDICT_NO_MTP,
    VERDICT_VOCAB_ONLY,
    VERDICT_WITH_MTP,
)
from core.mtp_head_support import (
    MTP_ADMITTED,
    MTP_NO_CENSUS_VERDICT,
    MTP_REFUSE_EMPTY_FILE_NAME,
    MTP_REFUSE_NOT_PROVEN,
    MTP_REFUSE_NO_MTP,
    MTP_REFUSE_VOCAB_ONLY,
    admitted_proposer_shape,
    evaluate_mtp_admission,
    mtp_head_k_cap,
    mtp_reason_name,
    mtp_refusal_line,
)
from core.speculative_loop import dispatch_proposer
from core.speculative_verify import (
    PROPOSER_ASSISTANT_MODEL,
    PROPOSER_MTP_HEAD,
    SLOT_HEAD,
    plan_proposer,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "MtpHeadSupport " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("MtpHeadSupport " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("MtpHeadSupport " + what + ": expected false")


def ordinary_directory() -> List[String]:
    """Ordinary tensor names, no head among them: the real
    expert/attention naming forms J-015/J-076 filed."""
    var v = List[String]()
    v.append(String("token_embd.weight"))
    v.append(String("blk.0.attn_q.weight"))
    v.append(String("blk.0.ffn_gate_exps.weight"))
    v.append(String("blk.0.ffn_down_exps.weight"))
    v.append(String("output_norm.weight"))
    v.append(String("output.weight"))
    return v.copy()


def test_nextn_admitted() raises:
    var names = List[String]()
    names.append(String("token_embd.weight"))
    names.append(String("blk.48.nextn.eh_proj.weight"))
    names.append(String("blk.0.attn_q.weight"))
    names.append(String("blk.48.nextn.embed_tokens.weight"))
    var adm = evaluate_mtp_admission(
        String("synthetic-nextn.gguf"), True, names
    )
    expect_true(adm.admitted, "nextn file admitted")
    expect_eq(adm.reason_code, MTP_ADMITTED, "admitted reason")
    expect_true(adm.has_census, "admission carries its census")
    expect_eq(adm.census_verdict, VERDICT_WITH_MTP, "with-mtp verdict")
    expect_eq(adm.n_tensors, 4, "directory size")
    expect_eq(adm.nextn_count, 2, "nextn count")
    expect_eq(adm.mtp_count, 0, "mtp count")
    expect_eq(adm.head_count(), 2, "head tensors named")
    expect_true(
        adm.head_names[0] == "blk.48.nextn.eh_proj.weight",
        "first head named, directory order",
    )
    expect_true(
        adm.head_names[1] == "blk.48.nextn.embed_tokens.weight",
        "second head named, directory order",
    )
    expect_eq(adm.head_kinds[0], HEAD_NEXTN, "first head kind")
    expect_eq(adm.head_kinds[1], HEAD_NEXTN, "second head kind")
    expect_eq(adm.proposer_kind, PROPOSER_MTP_HEAD, "mtp-head proposer")
    expect_eq(adm.proposer_slot, SLOT_HEAD, "head slot")
    expect_false(adm.requires_tokenizer_match, "head shares tokenizer")
    expect_false(adm.carries_own_kv, "head carries no KV of its own")
    print("PASS: admission -- nextn WITH_MTP admitted, heads named")


def test_mixed_heads_admitted() raises:
    var names = List[String]()
    names.append(String("blk.27.mtp.fc.weight"))
    names.append(String("blk.0.attn_q.weight"))
    names.append(String("blk.48.nextn.eh_proj.weight"))
    names.append(String("assistant.draft.weight"))
    var adm = evaluate_mtp_admission(
        String("synthetic-mixed.gguf"), True, names
    )
    expect_true(adm.admitted, "mixed file admitted")
    expect_eq(adm.nextn_count, 1, "nextn count")
    expect_eq(adm.mtp_count, 1, "mtp count")
    expect_eq(adm.assistant_count, 1, "assistant count")
    expect_eq(adm.head_count(), 3, "all heads named")
    expect_eq(adm.head_kinds[0], HEAD_MTP, "mtp kind first in order")
    expect_eq(adm.head_kinds[1], HEAD_NEXTN, "nextn kind second")
    expect_eq(adm.head_kinds[2], HEAD_ASSISTANT, "assistant kind third")
    expect_eq(
        adm.proposer_kind, PROPOSER_MTP_HEAD,
        "nextn/mtp present: the mtp-head proposer governs",
    )
    print("PASS: admission -- mixed heads admitted as mtp-head")


def test_assistant_only_admitted() raises:
    var names = List[String]()
    names.append(String("token_embd.weight"))
    names.append(String("assistant.blk.0.attn_q.weight"))
    var adm = evaluate_mtp_admission(
        String("synthetic-assistant.gguf"), True, names
    )
    expect_true(adm.admitted, "assistant-only file admitted")
    expect_eq(adm.census_verdict, VERDICT_WITH_MTP, "with-mtp verdict")
    expect_eq(
        adm.proposer_kind, PROPOSER_ASSISTANT_MODEL,
        "assistant-only heads admit as the assistant proposer",
    )
    expect_eq(adm.proposer_slot, SLOT_HEAD, "assistant fills head slot")
    expect_true(
        adm.requires_tokenizer_match,
        "assistant shape requires a verified tokenizer match (J-071)",
    )
    print("PASS: admission -- assistant-only admitted, assistant shape")


def test_no_mtp_refused_by_name() raises:
    # PROVEN inputs: file identities + NO_MTP verdicts are
    # J-076 section 2's filed census rows.
    var adm = evaluate_mtp_admission(
        String("zen-4b.i1-Q4_K_M.gguf"), True, ordinary_directory()
    )
    expect_false(adm.admitted, "zen qwen3 file refused for MTP")
    expect_eq(adm.reason_code, MTP_REFUSE_NO_MTP, "no-mtp reason")
    expect_eq(adm.census_verdict, VERDICT_NO_MTP, "no-mtp verdict")
    expect_true(
        adm.file_name == "zen-4b.i1-Q4_K_M.gguf",
        "refusal names the zen file",
    )
    expect_eq(adm.head_count(), 0, "refusal names no heads")
    expect_eq(adm.proposer_kind, -1, "refusal carries no proposer")
    var tiny = evaluate_mtp_admission(
        String("tinyllama.Q4_0.gguf"), True, ordinary_directory()
    )
    expect_false(tiny.admitted, "tinyllama refused for MTP")
    expect_eq(tiny.reason_code, MTP_REFUSE_NO_MTP, "tinyllama reason")
    print("PASS: refusal -- proven NO_MTP files refused by name")


def test_vocab_only_refused_by_name() raises:
    var empty = List[String]()
    var adm = evaluate_mtp_admission(
        String("ggml-vocab-qwen35.gguf"), True, empty
    )
    expect_false(adm.admitted, "vocab fixture refused for MTP")
    expect_eq(adm.reason_code, MTP_REFUSE_VOCAB_ONLY, "vocab reason")
    expect_eq(adm.census_verdict, VERDICT_VOCAB_ONLY, "vocab verdict")
    expect_eq(adm.n_tensors, 0, "empty directory")
    var g4 = evaluate_mtp_admission(
        String("ggml-vocab-gemma-4.gguf"), True, empty
    )
    expect_false(g4.admitted, "gemma vocab fixture refused")
    expect_eq(g4.reason_code, MTP_REFUSE_VOCAB_ONLY, "gemma vocab reason")
    print("PASS: refusal -- VOCAB_ONLY fixtures refused by name")


def test_not_proven_refused() raises:
    # Head-shaped names carried beside an unread directory
    # are NOT trusted: uncensused is NOT PROVEN, never assumed.
    var names = List[String]()
    names.append(String("blk.48.nextn.eh_proj.weight"))
    var adm = evaluate_mtp_admission(
        String("Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf"), False, names
    )
    expect_false(adm.admitted, "uncensused file not admitted")
    expect_eq(adm.reason_code, MTP_REFUSE_NOT_PROVEN, "not-proven reason")
    expect_false(adm.has_census, "uncensused file has no census")
    expect_eq(
        adm.census_verdict, MTP_NO_CENSUS_VERDICT, "no verdict invented"
    )
    expect_eq(adm.n_tensors, 0, "carried names never counted")
    expect_eq(adm.head_count(), 0, "carried names never classified")
    print("PASS: refusal -- uncensused file refused as NOT PROVEN")


def test_empty_name_refused() raises:
    var adm = evaluate_mtp_admission(
        String(""), True, ordinary_directory()
    )
    expect_false(adm.admitted, "empty name not admitted")
    expect_eq(
        adm.reason_code, MTP_REFUSE_EMPTY_FILE_NAME, "empty-name reason"
    )
    print("PASS: refusal -- empty file name refused")


def test_refusal_lines() raises:
    var no_mtp = evaluate_mtp_admission(
        String("zen-4b.i1-Q6_K.gguf"), True, ordinary_directory()
    )
    var line = mtp_refusal_line(no_mtp)
    expect_true("REFUSED" in line, "no-mtp line says refused")
    expect_true(
        "zen-4b.i1-Q6_K.gguf" in line, "no-mtp line names the file"
    )
    expect_true("NO_MTP" in line, "no-mtp line names the verdict")
    expect_true("not run plain" in line, "no-mtp line bars plain fallback")
    var empty = List[String]()
    var vocab = evaluate_mtp_admission(
        String("ggml-vocab-gemma-4.gguf"), True, empty
    )
    var vline = mtp_refusal_line(vocab)
    expect_true("VOCAB_ONLY" in vline, "vocab line names the verdict")
    expect_true(
        "ggml-vocab-gemma-4.gguf" in vline, "vocab line names the file"
    )
    var un = evaluate_mtp_admission(
        String("Qwen3.5-2B.gguf"), False, ordinary_directory()
    )
    var uline = mtp_refusal_line(un)
    expect_true("NOT_PROVEN" in uline, "uncensused line says NOT_PROVEN")
    expect_true(
        "REFUSE_NOT_PROVEN" in uline, "uncensused line names the reason"
    )
    var names = List[String]()
    names.append(String("blk.27.mtp.fc.weight"))
    var adm = evaluate_mtp_admission(String("synthetic-mtp.gguf"), True, names)
    var aline = mtp_refusal_line(adm)
    expect_true("ADMITTED" in aline, "admitted line says admitted")
    expect_true("WITH_MTP" in aline, "admitted line names the verdict")
    expect_true(
        "synthetic-mtp.gguf" in aline, "admitted line names the file"
    )
    print("PASS: record -- refusal/admission lines name file+verdict+reason")


def test_refused_has_no_shape() raises:
    var refused = 0
    var no_mtp = evaluate_mtp_admission(
        String("zen-4b.i1-Q4_K_M.gguf"), True, ordinary_directory()
    )
    try:
        _ = admitted_proposer_shape(no_mtp)
    except:
        refused += 1
    var empty = List[String]()
    var vocab = evaluate_mtp_admission(
        String("ggml-vocab-qwen35.gguf"), True, empty
    )
    try:
        _ = admitted_proposer_shape(vocab)
    except:
        refused += 1
    var un = evaluate_mtp_admission(
        String("unread.gguf"), False, ordinary_directory()
    )
    try:
        _ = admitted_proposer_shape(un)
    except:
        refused += 1
    expect_eq(refused, 3, "every refusal class yields no shape (3/3)")
    var names = List[String]()
    names.append(String("blk.48.nextn.eh_proj.weight"))
    var adm = evaluate_mtp_admission(String("synthetic.gguf"), True, names)
    var shape = admitted_proposer_shape(adm)
    var dispatched = dispatch_proposer(SLOT_HEAD, PROPOSER_MTP_HEAD)
    expect_eq(shape.kind, dispatched.kind, "shape is J-072's dispatch")
    expect_eq(shape.slot, dispatched.slot, "shape slot is the dispatch's")
    expect_eq(shape.max_k, dispatched.max_k, "shape cap is the dispatch's")
    print("PASS: binding -- refused has no shape; admitted shape is J-072 dispatch")


def test_k_cap_from_j071() raises:
    expect_eq(
        mtp_head_k_cap(PROPOSER_MTP_HEAD),
        plan_proposer(PROPOSER_MTP_HEAD).max_k,
        "mtp-head cap read from J-071",
    )
    expect_eq(
        mtp_head_k_cap(PROPOSER_ASSISTANT_MODEL),
        plan_proposer(PROPOSER_ASSISTANT_MODEL).max_k,
        "assistant cap read from J-071",
    )
    var names = List[String]()
    names.append(String("blk.27.mtp.fc.weight"))
    var adm = evaluate_mtp_admission(String("synthetic.gguf"), True, names)
    expect_eq(adm.max_k, mtp_head_k_cap(PROPOSER_MTP_HEAD), "admission cap")
    expect_true(
        mtp_reason_name(MTP_ADMITTED) == "ADMITTED", "reason name admitted"
    )
    expect_true(
        mtp_reason_name(MTP_REFUSE_NOT_PROVEN) == "REFUSE_NOT_PROVEN",
        "reason name not-proven",
    )
    print("PASS: binding -- k cap from J-071, reason names round-trip")


def main() raises:
    test_nextn_admitted()
    test_mixed_heads_admitted()
    test_assistant_only_admitted()
    test_no_mtp_refused_by_name()
    test_vocab_only_refused_by_name()
    test_not_proven_refused()
    test_empty_name_refused()
    test_refusal_lines()
    test_refused_has_no_shape()
    test_k_cap_from_j071()
    print("ALL PASS: mtp head support (10 groups)")
