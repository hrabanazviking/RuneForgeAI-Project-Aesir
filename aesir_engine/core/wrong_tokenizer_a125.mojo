"""A-125: Wrong-tokenizer adversarial -- mismatched
tokenizer/model pairs must fail loudly at load
(Wave 14, Architecture breadth).

The roadmap text: "Wrong-tokenizer adversarial.
Mismatched tokenizer/model pairs must fail loudly
at load. Acceptance: adversarial set passes (all
rejected with named errors, none silently
generate)."

This battery files an ADVERSARIAL SET of tokenizer
presentations against one reference (model-side)
tokenizer, judged by the banked J-074 comparison
(core/cross_model_pairing.mojo compare_tokenizers,
called -- never re-implemented): same tokenizer
model string, same vocabulary length, every token
string equal at every index, merges equal at every
index where both sides carry merges (a one-sided
merges section is itself a mismatch), equal BOS /
EOS ids, and the comparison must actually have
been RUN (verified, not assumed -- J-074 rule 4,
whose own probe found two files with identical
vocab length and identical model strings whose
token tables diverge).

THE SET (14 cases, filed order): two honest
controls that must be ADMITTED (an identical
presentation; an identical presentation where
both sides carry no merges -- the SPM form,
MERGES_BOTH_ABSENT in the banked account) and
twelve adversarial presentations that must be
REFUSED with a named error: unverified, empty
vocab, model-string mismatch, vocab truncated,
vocab extended, token content divergence, token
ORDER permutation (same set, wrong order -- a
vocab is a table, not a bag), special-token text
divergence at index 0, merges divergence,
one-sided merges, BOS mismatch, EOS mismatch.

THE VERDICT RULE, PRE-REGISTERED (stated here
before any test in
tests/test_wrong_tokenizer_a125.mojo was run).
For one case, in order:
  (W1) comparison not run (verified == False)
       -> REFUSED, TOKENIZER_UNVERIFIED. Family
       name, shared vocab size, and catalogue
       pairing are evidence of nothing (J-074).
  (W2) vocab_compared == 0 -> REFUSED,
       EMPTY_VOCAB (the banked identical() is
       False on an empty comparison).
  (W3) model strings differ -> REFUSED,
       TOKENIZER_MODEL_MISMATCH.
  (W4) vocab lengths differ -> REFUSED,
       VOCAB_LENGTH_MISMATCH.
  (W5) any token string differs -> REFUSED,
       TOKEN_DIVERGENCE, first index carried.
  (W6) merges one-sided -> REFUSED,
       MERGES_ONE_SIDED.
  (W7) any merge differs -> REFUSED,
       MERGE_DIVERGENCE, first index carried.
  (W8) BOS ids differ -> REFUSED, BOS_MISMATCH.
  (W9) EOS ids differ -> REFUSED, EOS_MISMATCH.
  Otherwise the banked identical() must hold and
  the case is ADMITTED, reason MATCH_VERIFIED.
  Any residual divergence files REFUSED /
  UNKNOWN_DIVERGENCE and counts as unexplained;
  the filed battery has zero.

NO SILENT GRADING (the slice's whole point): a
refused pair is never graded. Every row carries
graded == -1 (no teacher-forcing rank, no logit
gap, no verdict of faithfulness is filed for ANY
row of this battery -- admission is a GATE, not
a grade, exactly as J-074 states of admissibility).
A row that is refused with an empty reason, or
that carries any grade witness, counts in the
report's silent field; the filed battery's
silent count is 0 and the suite pins it.

The tables are SYNTHETIC fixtures, labelled as
such in every render line: a 12-token reference
vocabulary and 4 merges, built in code. No real
model file is opened, no forward is executed, no
generation is attempted, and no accelerator claim
is made. What is proven is the GATE: the banked
comparison, applied at load, refuses every
mismatched presentation by name and admits only
verified-identical ones. Grading discipline for
admitted pairs stays where it has always lived:
teacher-forcing rank + logit gap on RAW prompts,
CPU engine vs CPU comparator only, near-tie band
rank <= 2 with sub-logit gap = faithful, IQ
coherence-only, comparator artifacts a verdict
class (A-109..A-115) -- none of it is exercised
or claimed here.

The bench driver
(tests/bench_wrong_tokenizer_a125.mojo) emits the
full battery on the Z13 in one command; its log
is the acceptance evidence.
"""

from core.cross_model_pairing import (
    MERGES_ONE_SIDED,
    TokenizerComparison,
    compare_tokenizers,
)
from core.matrix_runner import mx_fnv1a64

comptime WT_ADMITTED = 0
comptime WT_REFUSED = 1
comptime WT_REF_MODEL = "llama-bpe"
comptime WT_REF_BOS = 0
comptime WT_REF_EOS = 1


def wrong_tokenizer_cases() -> List[String]:
    """The 14 adversarial-set case names, filed order."""
    var v = List[String]()
    v.append(String("control_identical"))
    v.append(String("control_both_absent_merges"))
    v.append(String("unverified"))
    v.append(String("empty_vocab"))
    v.append(String("model_string_mismatch"))
    v.append(String("vocab_truncated"))
    v.append(String("vocab_extended"))
    v.append(String("token_content_divergence"))
    v.append(String("token_order_permutation"))
    v.append(String("special_token_text_divergence"))
    v.append(String("merges_divergence"))
    v.append(String("merges_one_sided"))
    v.append(String("bos_mismatch"))
    v.append(String("eos_mismatch"))
    return v^


def ref_tokens() -> List[String]:
    var t = List[String]()
    t.append(String("<bos>"))
    t.append(String("<eos>"))
    t.append(String("<pad>"))
    t.append(String("the"))
    t.append(String(" quick"))
    t.append(String(" brown"))
    t.append(String(" fox"))
    t.append(String(" jumps"))
    t.append(String(" over"))
    t.append(String(" lazy"))
    t.append(String(" dog"))
    t.append(String("."))
    return t^


def ref_merges() -> List[String]:
    var m = List[String]()
    m.append(String("t h"))
    m.append(String("th e"))
    m.append(String("q u"))
    m.append(String("qu ick"))
    return m^


def wt_verdict_name(verdict: Int) -> String:
    if verdict == WT_ADMITTED:
        return String("ADMITTED")
    return String("REFUSED")


struct WrongTokRow(Copyable, ImplicitlyCopyable):
    var case_name: String
    var verdict: Int
    var reason: String
    var first_token_divergence: Int
    var first_merge_divergence: Int
    var token_mismatches: Int
    var merge_mismatches: Int
    var vocab_compared: Int
    var graded: Int

    def __init__(
        out self,
        case_name: String,
        verdict: Int,
        reason: String,
        first_token_divergence: Int,
        first_merge_divergence: Int,
        token_mismatches: Int,
        merge_mismatches: Int,
        vocab_compared: Int,
        graded: Int,
    ):
        self.case_name = case_name
        self.verdict = verdict
        self.reason = reason
        self.first_token_divergence = first_token_divergence
        self.first_merge_divergence = first_merge_divergence
        self.token_mismatches = token_mismatches
        self.merge_mismatches = merge_mismatches
        self.vocab_compared = vocab_compared
        self.graded = graded


struct WrongTokReport(Copyable, Movable):
    var rows: List[WrongTokRow]
    var total: Int
    var admitted: Int
    var refused: Int
    var silent: Int
    var unexplained: Int
    var digest: UInt64

    def __init__(
        out self,
        rows: List[WrongTokRow],
        total: Int,
        admitted: Int,
        refused: Int,
        silent: Int,
        unexplained: Int,
        digest: UInt64,
    ):
        self.rows = rows.copy()
        self.total = total
        self.admitted = admitted
        self.refused = refused
        self.silent = silent
        self.unexplained = unexplained
        self.digest = digest


def judge_presentation(
    case_name: String,
    cand_tokens: List[String],
    cand_merges: List[String],
    cand_model: String,
    cand_bos: Int,
    cand_eos: Int,
    verified: Bool,
) -> WrongTokRow:
    """Judge one presented tokenizer against the
    reference (model-side) tokenizer under the
    pre-registered W1-W9 rule. The comparison is
    the banked J-074 compare_tokenizers, called
    over the FULL tables."""
    var cmp = compare_tokenizers(
        ref_tokens(),
        cand_tokens,
        ref_merges(),
        cand_merges,
        String(WT_REF_MODEL),
        cand_model,
        WT_REF_BOS,
        cand_bos,
        WT_REF_EOS,
        cand_eos,
    )
    if not verified:
        return WrongTokRow(
            case_name, WT_REFUSED, String("TOKENIZER_UNVERIFIED"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    if len(cand_tokens) == 0 or cmp.vocab_compared == 0:
        return WrongTokRow(
            case_name, WT_REFUSED, String("EMPTY_VOCAB"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    if not cmp.model_equal:
        return WrongTokRow(
            case_name, WT_REFUSED, String("TOKENIZER_MODEL_MISMATCH"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    if len(ref_tokens()) != len(cand_tokens):
        return WrongTokRow(
            case_name, WT_REFUSED, String("VOCAB_LENGTH_MISMATCH"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    if cmp.token_mismatches != 0:
        return WrongTokRow(
            case_name, WT_REFUSED, String("TOKEN_DIVERGENCE"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    if cmp.merges_state == MERGES_ONE_SIDED:
        return WrongTokRow(
            case_name, WT_REFUSED, String("MERGES_ONE_SIDED"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    if cmp.merge_mismatches != 0:
        return WrongTokRow(
            case_name, WT_REFUSED, String("MERGE_DIVERGENCE"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    if not cmp.bos_equal:
        return WrongTokRow(
            case_name, WT_REFUSED, String("BOS_MISMATCH"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    if not cmp.eos_equal:
        return WrongTokRow(
            case_name, WT_REFUSED, String("EOS_MISMATCH"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    if cmp.identical():
        return WrongTokRow(
            case_name, WT_ADMITTED, String("MATCH_VERIFIED"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    return WrongTokRow(
        case_name, WT_REFUSED, String("UNKNOWN_DIVERGENCE"),
        cmp.first_token_divergence, cmp.first_merge_divergence,
        cmp.token_mismatches, cmp.merge_mismatches,
        cmp.vocab_compared, -1,
    )


def _case_row(case_name: String) raises -> WrongTokRow:
    var tokens = ref_tokens()
    var merges = ref_merges()
    var model = String(WT_REF_MODEL)
    var bos = WT_REF_BOS
    var eos = WT_REF_EOS
    var verified = True
    if case_name == String("control_identical"):
        pass
    elif case_name == String("control_both_absent_merges"):
        # Both sides carry no merges: judge against a
        # merges-free reference form by clearing the
        # candidate merges AND relying on the dedicated
        # path in _case_row_both_absent below.
        return _both_absent_row()
    elif case_name == String("unverified"):
        verified = False
    elif case_name == String("empty_vocab"):
        tokens = List[String]()
    elif case_name == String("model_string_mismatch"):
        model = String("qwen-bpe")
    elif case_name == String("vocab_truncated"):
        var t = List[String]()
        for i in range(10):
            t.append(tokens[i])
        tokens = t^
    elif case_name == String("vocab_extended"):
        tokens.append(String(" extra"))
    elif case_name == String("token_content_divergence"):
        tokens[5] = String(" blue")
    elif case_name == String("token_order_permutation"):
        var tmp = tokens[3]
        tokens[3] = tokens[4]
        tokens[4] = tmp
    elif case_name == String("special_token_text_divergence"):
        tokens[0] = String("<s>")
    elif case_name == String("merges_divergence"):
        merges[1] = String("th x")
    elif case_name == String("merges_one_sided"):
        merges = List[String]()
    elif case_name == String("bos_mismatch"):
        bos = 2
    elif case_name == String("eos_mismatch"):
        eos = 2
    else:
        raise Error("WrongTokenizer: unknown case refused: " + case_name)
    return judge_presentation(
        case_name, tokens, merges, model, bos, eos, verified
    )


def _both_absent_row() -> WrongTokRow:
    """The SPM-form control: candidate AND reference
    both carry no merges. compare_tokenizers is
    called with empty merges on the candidate side
    against the merges-free form of the same tables:
    judge_presentation always compares against
    ref_merges(), so this control is judged by a
    direct banked comparison of the two merges-free
    tables, stated here openly rather than hidden."""
    var cmp = compare_tokenizers(
        ref_tokens(),
        ref_tokens(),
        List[String](),
        List[String](),
        String(WT_REF_MODEL),
        String(WT_REF_MODEL),
        WT_REF_BOS,
        WT_REF_BOS,
        WT_REF_EOS,
        WT_REF_EOS,
    )
    if cmp.identical():
        return WrongTokRow(
            String("control_both_absent_merges"), WT_ADMITTED,
            String("MATCH_VERIFIED"),
            cmp.first_token_divergence, cmp.first_merge_divergence,
            cmp.token_mismatches, cmp.merge_mismatches,
            cmp.vocab_compared, -1,
        )
    return WrongTokRow(
        String("control_both_absent_merges"), WT_REFUSED,
        String("UNKNOWN_DIVERGENCE"),
        cmp.first_token_divergence, cmp.first_merge_divergence,
        cmp.token_mismatches, cmp.merge_mismatches,
        cmp.vocab_compared, -1,
    )


def _check_cases(cases: List[String]) raises:
    if len(cases) == 0:
        raise Error("WrongTokenizer: case axis is empty")
    var canon = wrong_tokenizer_cases()
    for i in range(len(cases)):
        var found = False
        for j in range(len(canon)):
            if cases[i] == canon[j]:
                found = True
        if not found:
            raise Error("WrongTokenizer: unknown case refused: " + cases[i])
        for j in range(i + 1, len(cases)):
            if cases[i] == cases[j]:
                raise Error(
                    "WrongTokenizer: duplicate case entry " + cases[i]
                )


def build_wrong_tokenizer_battery(
    cases: List[String],
) raises -> List[WrongTokRow]:
    _check_cases(cases)
    var rows = List[WrongTokRow]()
    for i in range(len(cases)):
        rows.append(_case_row(cases[i]))
    return rows^


def run_wrong_tokenizer_battery() raises -> WrongTokReport:
    var rows = build_wrong_tokenizer_battery(wrong_tokenizer_cases())
    var admitted = 0
    var refused = 0
    var silent = 0
    var unexplained = 0
    for i in range(len(rows)):
        if rows[i].verdict == WT_ADMITTED:
            admitted += 1
        else:
            refused += 1
            if rows[i].reason.byte_length() == 0 or rows[i].graded != -1:
                silent += 1
            if rows[i].reason == String("UNKNOWN_DIVERGENCE"):
                unexplained += 1
        if rows[i].graded != -1:
            silent += 1
    var report = WrongTokReport(
        rows.copy(), len(rows), admitted, refused, silent,
        unexplained, UInt64(0),
    )
    report.digest = mx_fnv1a64(wrong_tokenizer_render(report.copy()))
    return report^


def wrong_tokenizer_row_line(row: WrongTokRow) -> String:
    var s = String("WT_ROW case=") + row.case_name
    s += String(" fixture=SYNTHETIC")
    s += String(" verdict=") + wt_verdict_name(row.verdict)
    s += String(" reason=") + row.reason
    s += String(" first_token_divergence=")
    s += String(row.first_token_divergence)
    s += String(" first_merge_divergence=")
    s += String(row.first_merge_divergence)
    s += String(" token_mismatches=") + String(row.token_mismatches)
    s += String(" merge_mismatches=") + String(row.merge_mismatches)
    s += String(" vocab_compared=") + String(row.vocab_compared)
    s += String(" graded=") + String(row.graded)
    return s


def wrong_tokenizer_render(read report: WrongTokReport) -> String:
    var s = String("A125_BATTERY cases=")
    s += String(len(wrong_tokenizer_cases()))
    s += String(" total=") + String(report.total) + String("\n")
    for i in range(len(report.rows)):
        s += wrong_tokenizer_row_line(report.rows[i]) + String("\n")
    s += String("A125_BATTERY_SUMMARY total=") + String(report.total)
    s += String(" admitted=") + String(report.admitted)
    s += String(" refused=") + String(report.refused)
    s += String(" silent=") + String(report.silent)
    s += String(" unexplained=") + String(report.unexplained)
    return s


def wrong_tokenizer_line() -> String:
    return String(
        "A-125 wrong-tokenizer adversarial: 14-case"
        " adversarial set (2 verified-identical controls"
        " admitted, 12 mismatched presentations refused"
        " with named errors) judged by the banked J-074"
        " compare_tokenizers over the full tables;"
        " no refused pair is graded, none silently"
        " generates, zero unexplained"
    )
