"""Code completion mode (J-111): the pure completion
layer -- the per-arch FIM honesty table (no arch in
this tree carries true FIM), the prefix/suffix plan
(the generation prompt is the prefix exactly; the
suffix is never part of it), the J-097 window
composition capped at the cursor, the overlap trim,
the published-class latency grading, and the parser
surface the wiring lands on (suffix carried bounded;
the audit's suffix flip).

No number in this suite is a behaviour of a live
server: no socket was opened, no session started, no
inference ran, and no latency was measured -- the
latency group grades caller-supplied millisecond
counts against the published band only. The live
completion leg is J-111's deferred leg (doc section
5), re-cited at the J-118 gate.
"""
from core.code_completion import (
    CC_LATENCY_FASTER,
    CC_LATENCY_SLOWER,
    CC_LATENCY_WITHIN,
    CC_MAX_TEXT_BYTES,
    CC_MODE_FIM,
    CC_MODE_PREFIX_SUFFIX,
    CC_PUBLISHED_HIGH_MS,
    CC_PUBLISHED_LOW_MS,
    cc_arch_names,
    cc_arch_recognised,
    cc_fim_reason,
    cc_fim_supported,
    cc_latency_class,
    cc_latency_name,
    cc_mode_for_arch,
    cc_mode_name,
    cc_overlap_bytes,
    cc_plan,
    cc_trim_overlap,
    cc_window_reuse,
)
from core.kv_window import kw_first_divergence, kw_reusable
from core.openai_audit import FIELD_PARTIAL, completion_field_verdict
from server.openai import OpenAIRequest


def expect_eq_int(got: Int, want: Int, what: String) raises:
    if got != want:
        raise Error(
            "CodeCompletion " + what + ": expected " + String(want)
            + ", got " + String(got)
        )


def expect_eq_str(got: String, want: String, what: String) raises:
    if got != want:
        raise Error(
            "CodeCompletion " + what + ": expected '" + want
            + "', got '" + got + "'"
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("CodeCompletion " + what + ": expected true")


def expect_false(value: Bool, what: String) raises:
    if value:
        raise Error("CodeCompletion " + what + ": expected false")


def test_arch_fim_honesty() raises:
    var names = cc_arch_names()
    expect_eq_int(len(names), 5, "recognised arch table size")
    for name in names:
        expect_true(cc_arch_recognised(name), "arch recognised: " + name)
        expect_false(cc_fim_supported(name), "no arch carries FIM: " + name)
        expect_eq_int(
            cc_mode_for_arch(name), CC_MODE_PREFIX_SUFFIX,
            "mode is prefix/suffix: " + name)
        expect_true(
            cc_fim_reason(name).byte_length() > 20,
            "each arch states its FIM reason: " + name)
    expect_eq_str(
        cc_mode_name(CC_MODE_PREFIX_SUFFIX), "PREFIX_SUFFIX", "mode name")
    expect_eq_str(cc_mode_name(CC_MODE_FIM), "FIM", "fim mode name exists")
    expect_eq_str(cc_mode_name(99), "UNKNOWN", "mode name fallback")
    var refused = 0
    try:
        _ = cc_fim_supported("starcoder")
    except:
        refused += 1
    try:
        _ = cc_mode_for_arch("")
    except:
        refused += 1
    try:
        _ = cc_plan("deepseek", "x", "y")
    except:
        refused += 1
    expect_eq_int(refused, 3, "unrecognised archs refused by name")
    print("PASS: arch FIM honesty (5 recognised archs, none carries FIM, every mode PREFIX_SUFFIX, reasons stated, strangers refused)")


def test_plan() raises:
    var prefix = String("fn main() {\n    let x = ")
    var suffix = String(";\n    println(x);\n}")
    var plan = cc_plan("qwen3", prefix, suffix)
    expect_eq_int(plan.mode, CC_MODE_PREFIX_SUFFIX, "plan mode")
    expect_eq_str(
        plan.generation_prompt, prefix,
        "generation prompt is the prefix, exactly")
    expect_eq_str(plan.suffix, suffix, "suffix retained separately")
    expect_true(
        suffix not in plan.generation_prompt,
        "the suffix is never inside the generation prompt")
    expect_eq_int(plan.prefix_bytes, prefix.byte_length(), "prefix bytes")
    expect_eq_int(plan.suffix_bytes, suffix.byte_length(), "suffix bytes")
    var at_start = cc_plan("llama", "", "return 1;")
    expect_eq_str(
        at_start.generation_prompt, "", "cursor at file start: empty prefix")
    var at_end = cc_plan("gemma4", "return 1;", "")
    expect_eq_str(at_end.suffix, "", "cursor at file end: empty suffix")
    var refused = 0
    try:
        _ = cc_plan("llama", "", "")
    except:
        refused += 1
    var big = String("")
    for _ in range(CC_MAX_TEXT_BYTES + 1):
        big += "a"
    try:
        _ = cc_plan("llama", big, "y")
    except:
        refused += 1
    try:
        _ = cc_plan("llama", "x", big)
    except:
        refused += 1
    expect_eq_int(refused, 3, "empty document and over-bound texts refused")
    print("PASS: plan (generation prompt == prefix exactly, suffix separate and never inside it, cursor-at-edge plans, bounds + empty-document refusals)")


def doc_with(tokens: Int, mark_at: Int, mark: Int) -> List[Int]:
    var out = List[Int]()
    for i in range(tokens):
        out.append(mark if i == mark_at else i)
    return out^


def test_window_composition() raises:
    # A 16-token document, cursor after token 10 (prefix
    # length 10). Cases grade cc_window_reuse against
    # J-097's own functions computed alongside.
    var old = doc_with(16, -1, 0)
    # Edit AFTER the cursor (position 13): divergence is
    # past the cursor, so reuse is the cursor cap: the
    # whole prefix but its final token (final-token rule
    # applied to the generation prompt).
    var after = doc_with(16, 13, 999)
    expect_eq_int(kw_first_divergence(old, after), 13, "divergence after cursor")
    expect_eq_int(cc_window_reuse(old, after, 10), 9, "edit after cursor: reuse == cursor - 1")
    # Edit BEFORE the cursor (position 4): reuse stops
    # at the divergence, exactly J-097's account.
    var before = doc_with(16, 4, 999)
    expect_eq_int(
        cc_window_reuse(old, before, 10),
        kw_reusable(16, 16, 4), "edit before cursor: reuse == J-097 account")
    expect_eq_int(cc_window_reuse(old, before, 10), 4, "edit before cursor value")
    # No change: divergence at the length; the cursor
    # cap still binds (the generation prompt's final
    # token always recomputes).
    var same = doc_with(16, -1, 0)
    expect_eq_int(cc_window_reuse(old, same, 10), 9, "no change: reuse == cursor - 1")
    # Empty prefix reuses nothing, whatever the edit.
    expect_eq_int(cc_window_reuse(old, before, 0), 0, "empty prefix reuses 0")
    # An insertion before the cursor slides positions:
    # divergence at the insertion point caps reuse.
    var inserted = List[Int]()
    for i in range(17):
        inserted.append(555 if i == 2 else (i if i < 2 else i - 1))
    expect_eq_int(cc_window_reuse(old, inserted, 10), 2, "insert before cursor: reuse at divergence")
    var refused = 0
    try:
        _ = cc_window_reuse(old, same, 17)
    except:
        refused += 1
    try:
        _ = cc_window_reuse(old, same, -1)
    except:
        refused += 1
    expect_eq_int(refused, 2, "cursor outside the document refused")
    print("PASS: window composition (J-097 divergence account capped at the cursor: after-cursor 9, before-cursor 4, no-change 9, insert 2, empty prefix 0)")


def test_overlap_trim() raises:
    var suffix = String(";\n    println(x);\n}")
    expect_eq_int(
        cc_overlap_bytes("1 + 2;\n    xyzzy", suffix), 0,
        "no shared span: zero overlap")
    var completion = String("1 + 2;\n")
    expect_eq_str(
        cc_trim_overlap(completion, suffix), "1 + 2",
        "the re-generated suffix opening is trimmed")
    expect_eq_int(cc_overlap_bytes(completion, suffix), 2, "overlap is byte-exact")
    expect_eq_str(
        cc_trim_overlap("abc", "abc"), "",
        "a completion that is entirely overlap trims to empty")
    expect_eq_str(
        cc_trim_overlap("hello", "world"), "hello",
        "no overlap: completion unchanged")
    expect_eq_str(
        cc_trim_overlap("value }", "}"), "value ",
        "a one-byte overlap is trimmed")
    expect_eq_str(
        cc_trim_overlap("", "anything"), "", "empty completion stays empty")
    expect_eq_str(
        cc_trim_overlap("anything", ""), "anything",
        "empty suffix trims nothing")
    print("PASS: overlap trim (suffix opening removed byte-exactly, full overlap empties, no overlap unchanged, edges held)")


def test_latency_grading() raises:
    expect_eq_int(CC_PUBLISHED_LOW_MS, 1500, "published band low (published, not measured)")
    expect_eq_int(CC_PUBLISHED_HIGH_MS, 2200, "published band high (published, not measured)")
    expect_eq_int(cc_latency_class(0), CC_LATENCY_FASTER, "0 ms is faster than the class")
    expect_eq_int(cc_latency_class(1499), CC_LATENCY_FASTER, "1499 faster")
    expect_eq_int(cc_latency_class(1500), CC_LATENCY_WITHIN, "1500 within (band low inclusive)")
    expect_eq_int(cc_latency_class(1850), CC_LATENCY_WITHIN, "1850 within")
    expect_eq_int(cc_latency_class(2200), CC_LATENCY_WITHIN, "2200 within (band high inclusive)")
    expect_eq_int(cc_latency_class(2201), CC_LATENCY_SLOWER, "2201 slower")
    expect_eq_str(
        cc_latency_name(CC_LATENCY_WITHIN), "WITHIN_PUBLISHED_CLASS",
        "latency verdict name")
    var refused = False
    try:
        _ = cc_latency_class(-1)
    except:
        refused = True
    expect_true(refused, "a negative measurement is refused, never graded")
    print("PASS: latency grading (published band 1500-2200 ms pinned as published; 1499 faster, 1500/2200 within, 2201 slower, negative refused)")


def test_parser_and_audit_surface() raises:
    var body = String(
        "{\"model\":\"m\",\"prompt\":\"let x = \",\"suffix\":\";\"}")
    var request = OpenAIRequest(body)
    expect_true(request.has_prompt, "parser carries the prompt")
    expect_true(request.has_suffix, "parser carries the suffix flag")
    expect_eq_str(request.suffix, ";", "parser carries the suffix text")
    var plain = OpenAIRequest(
        String("{\"model\":\"m\",\"prompt\":\"let x = \"}"))
    expect_false(plain.has_suffix, "no suffix field: flag stays false")
    expect_eq_str(plain.suffix, "", "no suffix field: text stays empty")
    var refused = 0
    try:
        _ = OpenAIRequest(String(
            "{\"model\":\"m\",\"prompt\":\"x\",\"suffix\":\"a\","
            "\"suffix\":\"b\"}"))
    except:
        refused += 1
    expect_eq_int(refused, 1, "a duplicate suffix is refused like every field")
    expect_eq_int(
        completion_field_verdict("suffix"), FIELD_PARTIAL,
        "audit suffix row is PARTIAL (J-111 flip)")
    print("PASS: parser + audit surface (suffix parsed and bounded by the standing grammar, duplicates refused, audit row PARTIAL)")


def main() raises:
    test_arch_fim_honesty()
    test_plan()
    test_window_composition()
    test_overlap_trim()
    test_latency_grading()
    test_parser_and_audit_surface()
    print("ALL PASS: code completion (6 groups)")
