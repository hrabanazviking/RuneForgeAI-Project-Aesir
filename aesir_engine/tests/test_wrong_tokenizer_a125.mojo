# tests/test_wrong_tokenizer_a125.mojo
# A-125: Wrong-tokenizer adversarial -- the 14-case
# adversarial set judged by the banked J-074
# compare_tokenizers, and these cases cover: the
# case axis and its count, duplicate-free
# enumeration, both controls admitted, the
# unverified refusal (verified, not assumed), the
# token divergences with their first indices, the
# vocab-length refusals both ways, the model /
# BOS / EOS refusals by name, the merges refusals
# (divergence and one-sided), the empty-vocab
# refusal, no silent grading anywhere (every row
# graded == -1, every refusal named), summary
# counts summing to the totals, degenerate case
# axes refused, the row-line render, and a
# deterministic digest across re-runs.

from core.wrong_tokenizer_a125 import (
    WT_ADMITTED,
    WT_REFUSED,
    WrongTokReport,
    WrongTokRow,
    build_wrong_tokenizer_battery,
    judge_presentation,
    ref_merges,
    ref_tokens,
    run_wrong_tokenizer_battery,
    wrong_tokenizer_cases,
    wrong_tokenizer_line,
    wrong_tokenizer_render,
    wrong_tokenizer_row_line,
)


def _row(
    read report: WrongTokReport, case_name: String
) raises -> WrongTokRow:
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.case_name == case_name:
            return r
    raise Error("wrong-tokenizer row not found")


def _raises_build(cases: List[String]) -> Bool:
    try:
        _ = build_wrong_tokenizer_battery(cases)
    except:
        return True
    return False


def test_wtok_axes_product() raises:
    var cases = wrong_tokenizer_cases()
    if len(cases) != 14:
        raise Error("wtok axis must file exactly 14 cases")
    if cases[0] != String("control_identical"):
        raise Error("axis must start with the identical control")
    if cases[13] != String("eos_mismatch"):
        raise Error("axis must end with the EOS mismatch")
    var report = run_wrong_tokenizer_battery()
    if report.total != 14 or len(report.rows) != 14:
        raise Error("battery must file exactly 14 rows")


def test_wtok_enumeration_unique() raises:
    var report = run_wrong_tokenizer_battery()
    for i in range(len(report.rows)):
        for j in range(i + 1, len(report.rows)):
            if report.rows[i].case_name == report.rows[j].case_name:
                raise Error("duplicate wrong-tokenizer row")
    if String("A-125 wrong-tokenizer adversarial") not in wrong_tokenizer_line():
        raise Error("battery line must name the slice")
    if report.rows[0].case_name != String("control_identical"):
        raise Error("enumeration must start at the identical control")


def test_wtok_controls_admitted() raises:
    var report = run_wrong_tokenizer_battery()
    var a = _row(report.copy(), String("control_identical"))
    if a.verdict != WT_ADMITTED or a.reason != String("MATCH_VERIFIED"):
        raise Error("identical control must be ADMITTED / MATCH_VERIFIED")
    if a.token_mismatches != 0 or a.merge_mismatches != 0:
        raise Error("identical control must carry zero mismatches")
    if a.vocab_compared != 12:
        raise Error("identical control must compare the full 12-token vocab")
    var b = _row(report.copy(), String("control_both_absent_merges"))
    if b.verdict != WT_ADMITTED or b.reason != String("MATCH_VERIFIED"):
        raise Error("both-absent-merges control must be ADMITTED")


def test_wtok_unverified_refused() raises:
    var report = run_wrong_tokenizer_battery()
    var r = _row(report.copy(), String("unverified"))
    if r.verdict != WT_REFUSED:
        raise Error("unverified presentation must be REFUSED")
    if r.reason != String("TOKENIZER_UNVERIFIED"):
        raise Error("unverified refusal must name TOKENIZER_UNVERIFIED")
    var direct = judge_presentation(
        String("probe"), ref_tokens(), ref_merges(),
        String("llama-bpe"), 0, 1, False,
    )
    if direct.verdict != WT_REFUSED:
        raise Error("a direct unverified judgement must refuse")


def test_wtok_token_divergence() raises:
    var report = run_wrong_tokenizer_battery()
    var r = _row(report.copy(), String("token_content_divergence"))
    if r.verdict != WT_REFUSED or r.reason != String("TOKEN_DIVERGENCE"):
        raise Error("content divergence must refuse as TOKEN_DIVERGENCE")
    if r.first_token_divergence != 5 or r.token_mismatches != 1:
        raise Error("content divergence must sit at index 5, exactly 1")
    var s = _row(report.copy(), String("special_token_text_divergence"))
    if s.reason != String("TOKEN_DIVERGENCE"):
        raise Error("special-token text divergence must refuse by name")
    if s.first_token_divergence != 0:
        raise Error("special-token divergence must sit at index 0")


def test_wtok_order_permutation() raises:
    var report = run_wrong_tokenizer_battery()
    var r = _row(report.copy(), String("token_order_permutation"))
    if r.verdict != WT_REFUSED or r.reason != String("TOKEN_DIVERGENCE"):
        raise Error("order permutation must refuse: a vocab is a table")
    if r.first_token_divergence != 3 or r.token_mismatches != 2:
        raise Error("permutation must diverge at 3 with exactly 2 mismatches")


def test_wtok_vocab_length_refused() raises:
    var report = run_wrong_tokenizer_battery()
    var t = _row(report.copy(), String("vocab_truncated"))
    if t.verdict != WT_REFUSED or t.reason != String("VOCAB_LENGTH_MISMATCH"):
        raise Error("truncated vocab must refuse as VOCAB_LENGTH_MISMATCH")
    if t.first_token_divergence != 10:
        raise Error("truncated vocab must diverge at the shorter length 10")
    var e = _row(report.copy(), String("vocab_extended"))
    if e.verdict != WT_REFUSED or e.reason != String("VOCAB_LENGTH_MISMATCH"):
        raise Error("extended vocab must refuse as VOCAB_LENGTH_MISMATCH")
    if e.first_token_divergence != 12:
        raise Error("extended vocab must diverge at the reference length 12")


def test_wtok_model_and_special_ids() raises:
    var report = run_wrong_tokenizer_battery()
    var m = _row(report.copy(), String("model_string_mismatch"))
    if m.verdict != WT_REFUSED or m.reason != String("TOKENIZER_MODEL_MISMATCH"):
        raise Error("model-string mismatch must refuse by name")
    var b = _row(report.copy(), String("bos_mismatch"))
    if b.verdict != WT_REFUSED or b.reason != String("BOS_MISMATCH"):
        raise Error("BOS mismatch must refuse as BOS_MISMATCH")
    var e = _row(report.copy(), String("eos_mismatch"))
    if e.verdict != WT_REFUSED or e.reason != String("EOS_MISMATCH"):
        raise Error("EOS mismatch must refuse as EOS_MISMATCH")


def test_wtok_merges_refused() raises:
    var report = run_wrong_tokenizer_battery()
    var d = _row(report.copy(), String("merges_divergence"))
    if d.verdict != WT_REFUSED or d.reason != String("MERGE_DIVERGENCE"):
        raise Error("merges divergence must refuse as MERGE_DIVERGENCE")
    if d.first_merge_divergence != 1 or d.merge_mismatches != 1:
        raise Error("merges divergence must sit at index 1, exactly 1")
    var o = _row(report.copy(), String("merges_one_sided"))
    if o.verdict != WT_REFUSED or o.reason != String("MERGES_ONE_SIDED"):
        raise Error("one-sided merges must refuse as MERGES_ONE_SIDED")


def test_wtok_empty_vocab_refused() raises:
    var report = run_wrong_tokenizer_battery()
    var r = _row(report.copy(), String("empty_vocab"))
    if r.verdict != WT_REFUSED or r.reason != String("EMPTY_VOCAB"):
        raise Error("empty vocab must refuse as EMPTY_VOCAB")


def test_wtok_no_silent_grading() raises:
    var report = run_wrong_tokenizer_battery()
    if report.silent != 0:
        raise Error("silent count must be 0: no refused pair is graded")
    if report.unexplained != 0:
        raise Error("unexplained count must be 0")
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.graded != -1:
            raise Error("no row of this battery may carry a grade witness")
        if r.verdict == WT_REFUSED and r.reason.byte_length() == 0:
            raise Error("every refusal must carry a named reason")
        if r.verdict == WT_REFUSED and r.reason == String("MATCH_VERIFIED"):
            raise Error("a refused row must never claim a verified match")


def test_wtok_summary_sums() raises:
    var report = run_wrong_tokenizer_battery()
    if report.admitted != 2 or report.refused != 12:
        raise Error("summary must be 2 admitted / 12 refused")
    if report.admitted + report.refused != report.total:
        raise Error("summary counts must sum to the total")
    var text = wrong_tokenizer_render(report.copy())
    if String("A125_BATTERY_SUMMARY total=14") not in text:
        raise Error("render must carry the summary line")


def test_wtok_invalid_cases_refused() raises:
    var empty = List[String]()
    if not _raises_build(empty):
        raise Error("empty case axis must be refused")
    var dup = List[String]()
    dup.append(String("bos_mismatch"))
    dup.append(String("bos_mismatch"))
    if not _raises_build(dup):
        raise Error("duplicate case entries must be refused")
    var bogus = List[String]()
    bogus.append(String("nope_case"))
    if not _raises_build(bogus):
        raise Error("unknown case names must be refused")


def test_wtok_row_line_render() raises:
    var report = run_wrong_tokenizer_battery()
    var r = _row(report.copy(), String("token_content_divergence"))
    var line = wrong_tokenizer_row_line(r)
    if String("WT_ROW case=token_content_divergence") not in line:
        raise Error("row line must name the case")
    if String("fixture=SYNTHETIC") not in line:
        raise Error("row line must label the fixture SYNTHETIC")
    if String("verdict=REFUSED") not in line:
        raise Error("row line must carry the refusal")
    if String("graded=-1") not in line:
        raise Error("row line must show the ungraded witness")


def test_wtok_digest_deterministic() raises:
    var a = run_wrong_tokenizer_battery()
    var b = run_wrong_tokenizer_battery()
    if a.digest != b.digest:
        raise Error("battery digest must be deterministic across re-runs")
    if a.digest == 0:
        raise Error("battery digest must be non-zero")
