"""Vocabulary restriction (J-113): the pure
demonstrator layer -- word-list parsing and membership,
the token-text restrictor (completed words permitted,
trailing partial a permitted prefix), the pure
selection form, a SIMULATED greedy loop over synthetic
candidates (filed as simulation: it proves this layer's
decisions, not a sampler), the finished-text audit, and
the NSM disposition (REFUSED, with reasons and re-open
criteria).

No number in this suite is a behaviour of a live
sampler: no session was started, no logits were masked,
no inference ran. Exact sampler enforcement, its
measured cost, and the chat + server surface are
J-114's scope; the live leg is re-cited at the J-118
gate (J-113 doc section 5).
"""
from core.vocab_restriction import (
    VR_MAX_ENTRIES,
    VR_MAX_WORD_BYTES,
    PermittedVocab,
    VocabRestrictor,
    vr_audit_text,
    vr_contains,
    vr_nsm_disposition,
    vr_parse_word_list,
    vr_render_word_list,
    vr_word_count,
)


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("VocabRestriction " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("VocabRestriction " + what + ": expected false")


def expect_eq_int(got: Int, want: Int, what: String) raises:
    if got != want:
        raise Error(
            "VocabRestriction " + what + ": expected " + String(want)
            + ", got " + String(got))


def expect_eq_str(got: String, want: String, what: String) raises:
    if got != want:
        raise Error(
            "VocabRestriction " + what + ": expected '" + want
            + "', got '" + got + "'")


def expect_in(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "VocabRestriction " + what + ": '" + needle
            + "' not in the text")


def test_parse_render() raises:
    var vocab = vr_parse_word_list("the, cat; sat\nthe  dog,cat")
    expect_eq_int(vr_word_count(vocab), 4, "distinct count after dedupe")
    expect_eq_str(
        vr_render_word_list(vocab), "the, cat, sat, dog",
        "canonical render preserves first order")
    var round = vr_parse_word_list(vr_render_word_list(vocab))
    expect_eq_str(
        vr_render_word_list(round), "the, cat, sat, dog",
        "render parses back to the same list")
    var tabs = vr_parse_word_list("\t one \r\ntwo ; three,")
    expect_eq_str(
        vr_render_word_list(tabs), "one, two, three",
        "every separator class splits")
    print("PASS: parse + render (separators, dedupe, order, round-trip)")


def test_membership_bounds() raises:
    var vocab = vr_parse_word_list("the cat sat")
    expect_true(vr_contains(vocab, "cat"), "exact member")
    expect_false(vr_contains(vocab, "The"), "case differs is not a member")
    expect_false(vr_contains(vocab, "cats"), "superstring is not a member")
    expect_false(vr_contains(vocab, "ca"), "prefix is not a member")
    expect_false(vr_contains(vocab, ""), "empty is not a member")
    var raised = False
    try:
        _ = vr_parse_word_list("")
    except:
        raised = True
    expect_true(raised, "empty spec refused")
    raised = False
    try:
        _ = vr_parse_word_list(" , ; \n ")
    except:
        raised = True
    expect_true(raised, "separators-only spec refused")
    var long_word = String("")
    for _ in range(VR_MAX_WORD_BYTES + 1):
        long_word += "x"
    raised = False
    try:
        _ = vr_parse_word_list(long_word)
    except:
        raised = True
    expect_true(raised, "entry over the byte bound refused")
    var max_word = String("")
    for _ in range(VR_MAX_WORD_BYTES):
        max_word += "y"
    var at_bound = vr_parse_word_list(max_word)
    expect_eq_int(vr_word_count(at_bound), 1, "entry at the byte bound held")
    var big = String("")
    for i in range(VR_MAX_ENTRIES + 1):
        big += "w" + String(i) + ","
    raised = False
    try:
        _ = vr_parse_word_list(big)
    except:
        raised = True
    expect_true(raised, "list over the entry bound refused")
    print("PASS: membership + bounds (exact/case, empty, byte + entry caps)")


def test_restrictor() raises:
    var vocab = vr_parse_word_list("the cat sat on mat")
    var r = VocabRestrictor(vocab)
    expect_true(r.is_accepting(), "empty text accepts")
    expect_true(r.is_token_valid("the"), "whole permitted word token")
    expect_true(r.is_token_valid(" th"), "partial prefix token")
    expect_false(r.is_token_valid(""), "empty token text invalid")
    expect_false(r.is_token_valid(" dog"), "partial with no permitted word")
    expect_false(
        r.is_token_valid("dog "), "token completing a forbidden word")
    expect_true(
        r.is_token_valid("the cat "),
        "one token completing two permitted words")
    expect_true(
        r.is_token_valid("  the"), "leading separators complete nothing")
    r.advance_state("the")
    expect_eq_str(r.partial_word, "the", "partial after whole-word token")
    expect_true(r.is_accepting(), "partial is itself a permitted word")
    r.advance_state(" c")
    expect_eq_str(r.partial_word, "c", "partial mid-word")
    expect_false(r.is_accepting(), "mid-word partial does not accept")
    expect_eq_int(r.completed_words, 1, "one word completed so far")
    r.advance_state("at sat")
    expect_eq_str(r.partial_word, "sat", "partial after spanning token")
    expect_eq_int(r.completed_words, 2, "spanning token completed cat")
    var raised = False
    try:
        r.advance_state(" dog")
    except:
        raised = True
    expect_true(raised, "violating advance raises")
    expect_eq_str(r.partial_word, "sat", "refused advance mutates nothing")
    expect_eq_int(r.completed_words, 2, "refused advance counts nothing")
    print("PASS: restrictor (validity, spanning tokens, commit/refusal)")


def test_selection() raises:
    var vocab = vr_parse_word_list("the cat sat on mat")
    var r = VocabRestrictor(vocab)
    r.advance_state("the ")
    var candidates = List[String]()
    candidates.append(" dog")
    candidates.append(" cat")
    candidates.append(" on")
    candidates.append(" bird ")
    var allowed = r.allowed_indices(candidates)
    expect_eq_int(len(allowed), 2, "exactly two candidates admitted")
    expect_eq_int(allowed[0], 1, "first admitted index")
    expect_eq_int(allowed[1], 2, "second admitted index")
    expect_eq_int(r.first_allowed(candidates), 1, "first allowed")
    var none = List[String]()
    none.append(" dog")
    none.append(" bird")
    expect_eq_int(r.first_allowed(none), -1, "no candidate admitted is -1")
    expect_eq_int(
        len(r.allowed_indices(none)), 0, "no candidate admitted is empty")
    print("PASS: selection (allowed indices exact, none-allowed is -1)")


def test_simulated_loop() raises:
    var vocab = vr_parse_word_list("the cat sat on the mat")
    expect_eq_int(vr_word_count(vocab), 5, "demo list dedupes the")
    var r = VocabRestrictor(vocab)
    var steps = List[List[String]]()
    var s1 = List[String]()
    s1.append("a")
    s1.append("the")
    steps.append(s1^)
    var s2 = List[String]()
    s2.append(" dog")
    s2.append(" cat")
    steps.append(s2^)
    var s3 = List[String]()
    s3.append(" ran")
    s3.append(" sat")
    steps.append(s3^)
    var s4 = List[String]()
    s4.append(" on")
    s4.append(" under")
    steps.append(s4^)
    var s5 = List[String]()
    s5.append(" the")
    s5.append(" a")
    steps.append(s5^)
    var s6 = List[String]()
    s6.append(" dog")
    s6.append(" mat")
    steps.append(s6^)
    var s7 = List[String]()
    s7.append(" dog")
    s7.append(" bird")
    steps.append(s7^)
    var text = String("")
    var stopped_at = -1
    for step_idx in range(len(steps)):
        var pick = r.first_allowed(steps[step_idx])
        if pick < 0:
            stopped_at = step_idx
            break
        text += steps[step_idx][pick]
        r.advance_state(steps[step_idx][pick])
    expect_eq_str(
        text, "the cat sat on the mat", "demonstrated text (SIMULATED)")
    expect_eq_int(stopped_at, 6, "loop stops at the no-allowed step")
    expect_eq_int(r.completed_words, 5, "five words completed in the loop")
    expect_true(r.is_accepting(), "demonstrated text ends accepting")
    var audit = vr_audit_text(vocab, text)
    expect_eq_int(audit.total_words, 6, "demo audit total")
    expect_eq_int(audit.permitted_words, 6, "demo audit all permitted")
    expect_false(audit.has_offender, "demo audit has no offender")
    print("PASS: simulated loop (greedy first-allowed, clean stop, audit)")


def test_audit_disposition() raises:
    var vocab = vr_parse_word_list("the cat sat on mat")
    var mixed = vr_audit_text(vocab, "the dog sat")
    expect_eq_int(mixed.total_words, 3, "mixed total")
    expect_eq_int(mixed.permitted_words, 2, "mixed permitted")
    expect_true(mixed.has_offender, "mixed has an offender")
    expect_eq_str(mixed.first_offender, "dog", "first offender exact")
    var empty = vr_audit_text(vocab, "  \n ")
    expect_eq_int(empty.total_words, 0, "empty text has no words")
    expect_false(empty.has_offender, "empty text has no offender")
    var clean = vr_audit_text(vocab, "on the mat")
    expect_eq_int(clean.permitted_words, 3, "clean text all permitted")
    var disposition = vr_nsm_disposition()
    expect_in(disposition, "REFUSED", "disposition carries the verdict")
    expect_in(disposition, "CC BY-NC-SA", "disposition carries the licence reason")
    expect_in(disposition, "single-paper", "disposition carries the instrument reason")
    expect_in(disposition, "no Aesir consumer", "disposition carries the consumer reason")
    expect_in(disposition, "Re-open only if", "disposition carries re-open criteria")
    expect_in(disposition, "J-114", "disposition names the core's build slice")
    print("PASS: audit + disposition (counts, first offender, REFUSED text)")


def main() raises:
    test_parse_render()
    test_membership_bounds()
    test_restrictor()
    test_selection()
    test_simulated_loop()
    test_audit_disposition()
    print("ALL PASS: vocab restriction (6 groups)")
