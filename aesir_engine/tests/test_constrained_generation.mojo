"""Constrained generation (J-114): exact enforcement
of J-113's permitted-vocabulary restriction in the
sampler -- the sampler mask's agreement with the pure
selection form (allowed_indices) on deterministic
synthetic candidate sets in several restrictor
states; the restricted sampler over synthetic f16
logits (greedy + sampled paths, suppression, the
none-admitted -1 refusal); a step-by-step enforcement
loop driven through the real sampler and committed
through advance_state; the deterministic scan-cost
account; and the chat (/constrain) + server
(vocab_restriction field) surface behaviours.

No model inference ran for this suite: every logits
table and candidate set is synthetic and filed. The
loop below is a real sampler run over synthetic
logits -- it proves the sampler's enforcement, not a
model's behaviour. Live constrained generation is
deferred to the J-118 gate (J-114 doc section 0.7).
"""
from core.constrained_generation import (
    cg_apply_vocab_mask,
    cg_constrain_response,
    cg_greedy_choice,
    cg_is_constrain_command,
    cg_masked_indices,
    cg_scan_account,
    cg_serve_vocab_response,
)
from core.sampler import (
    RuneRNG,
    TokenCandidate,
    apply_vocab_restriction,
    sample_token_from_logits,
    sample_token_from_logits_restricted,
)
from core.vocab_restriction import (
    VocabRestrictor,
    vr_audit_text,
    vr_parse_word_list,
)
from server.openai import OpenAIRequest
from core.mimir_well import f16
from core.compute import MutUntrackedOrigin
from std.memory import Pointer, dealloc
from std.memory.alloc import alloc, Layout


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("ConstrainedGeneration " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("ConstrainedGeneration " + what + ": expected false")


def expect_eq_int(got: Int, want: Int, what: String) raises:
    if got != want:
        raise Error(
            "ConstrainedGeneration " + what + ": expected "
            + String(want) + ", got " + String(got))


def expect_eq_str(got: String, want: String, what: String) raises:
    if got != want:
        raise Error(
            "ConstrainedGeneration " + what + ": expected '" + want
            + "', got '" + got + "'")


def expect_in(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "ConstrainedGeneration " + what + ": '" + needle
            + "' not in the text")


def _candidates(logits: List[Float32]) -> List[TokenCandidate]:
    var out = List[TokenCandidate]()
    for i in range(len(logits)):
        out.append(TokenCandidate(i, logits[i]))
    return out^


def _flat(n: Int) -> List[TokenCandidate]:
    var out = List[TokenCandidate]()
    for i in range(n):
        out.append(TokenCandidate(i, Float32(1.0)))
    return out^


def _expect_indices(
    got: List[Int], want: List[Int], what: String
) raises:
    expect_eq_int(len(got), len(want), what + " (count)")
    for i in range(len(want)):
        expect_eq_int(got[i], want[i], what + " (position)")


def test_mask_agreement() raises:
    var vocab = vr_parse_word_list("the cat sat on mat")
    # Fresh state: partial "".
    var r = VocabRestrictor(vocab)
    var texts = List[String]()
    texts.append(" dog")
    texts.append(" cat")
    texts.append(" on")
    texts.append(" bird ")
    texts.append("the")
    texts.append(" ca")
    var logits = List[Float32]()
    logits.append(Float32(9.0))
    logits.append(Float32(1.0))
    logits.append(Float32(2.0))
    logits.append(Float32(8.0))
    logits.append(Float32(3.0))
    logits.append(Float32(4.0))
    var want = List[Int]()
    want.append(1)
    want.append(2)
    want.append(4)
    want.append(5)
    _expect_indices(r.allowed_indices(texts), want, "pure form, fresh state")
    _expect_indices(
        cg_masked_indices(_candidates(logits), texts, r), want,
        "cg masked indices, fresh state")
    var masked = _candidates(logits)
    var admitted = cg_apply_vocab_mask(masked, texts, r)
    expect_eq_int(admitted, 4, "admitted count, fresh state")
    expect_true(masked[0].logit == Float32(-1e9), "disallowed masked to -1e9")
    expect_true(masked[3].logit == Float32(-1e9), "completing-forbidden masked")
    expect_true(masked[1].logit == Float32(1.0), "admitted logit untouched")
    expect_true(masked[5].logit == Float32(4.0), "admitted logit untouched 2")
    expect_eq_int(
        admitted + 2, len(texts), "admitted + masked == scanned (full scan)")
    var masked2 = _candidates(logits)
    expect_eq_int(
        apply_vocab_restriction(masked2, texts, r), 4,
        "sampler mask admitted count agrees")
    expect_eq_int(
        cg_greedy_choice(_candidates(logits), texts, r), 5,
        "greedy choice is the best admitted position")
    # State after a completed word: partial "" again, count 1.
    r.advance_state("the ")
    var texts2 = List[String]()
    texts2.append(" cat")
    texts2.append(" the")
    texts2.append(" dog")
    texts2.append(" mat ")
    var want2 = List[Int]()
    want2.append(0)
    want2.append(1)
    want2.append(3)
    _expect_indices(r.allowed_indices(texts2), want2, "pure form, after word")
    _expect_indices(
        cg_masked_indices(_flat(4), texts2, r), want2,
        "cg masked indices, after word")
    # Mid-word state: partial "th".
    var r2 = VocabRestrictor(vocab)
    r2.advance_state(" th")
    var texts3 = List[String]()
    texts3.append("e")
    texts3.append("e cat ")
    texts3.append("e dog ")
    texts3.append("x")
    texts3.append(" cat")
    var want3 = List[Int]()
    want3.append(0)
    want3.append(1)
    _expect_indices(r2.allowed_indices(texts3), want3, "pure form, mid-word")
    _expect_indices(
        cg_masked_indices(_flat(5), texts3, r2), want3,
        "cg masked indices, mid-word")
    # None admitted / all admitted edges.
    var none = List[String]()
    none.append(" dog")
    none.append(" bird")
    expect_eq_int(
        len(cg_masked_indices(_flat(2), none, r)), 0,
        "none admitted is empty")
    expect_eq_int(
        cg_greedy_choice(_flat(2), none, r), -1,
        "none admitted greedy choice is -1")
    var all_in = List[String]()
    all_in.append(" cat")
    all_in.append(" on")
    expect_eq_int(
        len(cg_masked_indices(_flat(2), all_in, r)), 2,
        "all admitted kept")
    # Count mismatches raise in the sampler mask.
    var raised = False
    var short_texts = List[String]()
    short_texts.append(" cat")
    try:
        var two = List[TokenCandidate]()
        two.append(TokenCandidate(0, Float32(1.0)))
        two.append(TokenCandidate(1, Float32(2.0)))
        _ = apply_vocab_restriction(two, short_texts, r)
    except:
        raised = True
    expect_true(raised, "sampler mask count mismatch raises")
    print("PASS: mask agreement (pure form == sampler mask in 3 states, edges, mismatch raises)")


def _greedy_picks(
    texts: List[String], r: VocabRestrictor, r_none: VocabRestrictor,
    mut values: List[Int], mut mismatch: List[Int],
) raises:
    """All greedy-path sampler calls over one logits
    allocation; the allocation is consumed on both the
    success and the raise path before results return."""
    var allocation = alloc(Layout[Scalar[f16]](count=5))
    var logits = allocation.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    logits.unsafe_store(0, Scalar[f16](9.0))
    logits.unsafe_store(1, Scalar[f16](5.0))
    logits.unsafe_store(2, Scalar[f16](7.0))
    logits.unsafe_store(3, Scalar[f16](8.0))
    logits.unsafe_store(4, Scalar[f16](1.0))
    var mismatch_raised = False
    try:
        var rng_u = RuneRNG(42)
        values.append(sample_token_from_logits(
            logits, 5, 0.0, 40, 1.0, 1.0, List[Int](), rng_u))
        var rng = RuneRNG(42)
        values.append(sample_token_from_logits_restricted(
            logits, 5, texts, r, 0.0, 40, 1.0, 1.0, List[Int](), rng))
        logits.unsafe_store(1, Scalar[f16](7.0))
        var rng_tie = RuneRNG(43)
        values.append(sample_token_from_logits_restricted(
            logits, 5, texts, r, 0.0, 40, 1.0, 1.0, List[Int](), rng_tie))
        var suppress = List[Int]()
        suppress.append(1)
        var rng_s = RuneRNG(44)
        values.append(sample_token_from_logits_restricted(
            logits, 5, texts, r, 0.0, 40, 1.0, 1.0, List[Int](), rng_s,
            suppress_tokens=suppress))
        var rng_n = RuneRNG(45)
        values.append(sample_token_from_logits_restricted(
            logits, 5, texts, r_none, 0.0, 40, 1.0, 1.0,
            List[Int](), rng_n))
        var short = List[String]()
        short.append(" cat")
        var rng_m = RuneRNG(46)
        try:
            _ = sample_token_from_logits_restricted(
                logits, 5, short, r, 0.0, 40, 1.0, 1.0,
                List[Int](), rng_m)
        except:
            mismatch_raised = True
    except e:
        dealloc(allocation^)
        raise e^
    dealloc(allocation^)
    mismatch.append(1 if mismatch_raised else 0)


def test_greedy_sampler() raises:
    var vocab = vr_parse_word_list("the cat sat on mat")
    var texts = List[String]()
    texts.append(" dog")
    texts.append(" cat")
    texts.append(" on")
    texts.append(" bird")
    texts.append("the")
    var other = vr_parse_word_list("qqq")
    var values = List[Int]()
    var mismatch = List[Int]()
    _greedy_picks(
        texts, VocabRestrictor(vocab), VocabRestrictor(other),
        values, mismatch)
    expect_eq_int(
        values[0], 0, "unrestricted greedy takes the global max")
    expect_eq_int(
        values[1], 2, "restricted greedy takes the best admitted")
    expect_eq_int(
        values[2], 1, "restricted greedy tie picks the lowest ID")
    expect_eq_int(
        values[3], 2, "suppressed admitted token is excluded")
    expect_eq_int(
        values[4], -1, "none admitted greedy returns -1")
    expect_eq_int(mismatch[0], 1, "text/vocab count mismatch raises")
    print("PASS: greedy sampler (best admitted, tie lowest ID, suppression, -1, mismatch)")


def _sampled_run(
    texts: List[String], r: VocabRestrictor, r_none: VocabRestrictor,
    mut seen: List[Int], mut results: List[Int],
) raises:
    var allocation = alloc(Layout[Scalar[f16]](count=5))
    var logits = allocation.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    for i in range(5):
        logits.unsafe_store(i, Scalar[f16](1.0))
    var escaped = -2
    var single_ok = True
    var none_pick = -2
    var supp_pick = -2
    try:
        for seed in range(1, 513):
            var rng = RuneRNG(UInt64(seed))
            var pick = sample_token_from_logits_restricted(
                logits, 5, texts, r, 1.0, 40, 1.0, 1.0,
                List[Int](), rng)
            if pick == 1:
                seen[0] += 1
            elif pick == 2:
                seen[1] += 1
            elif pick == 4:
                seen[2] += 1
            else:
                escaped = pick
                break
        if escaped == -2:
            logits.unsafe_store(1, Scalar[f16](-100.0))
            logits.unsafe_store(2, Scalar[f16](10.0))
            logits.unsafe_store(4, Scalar[f16](-100.0))
            for seed in range(1, 65):
                var rng = RuneRNG(UInt64(seed))
                var pick = sample_token_from_logits_restricted(
                    logits, 5, texts, r, 1.0, 40, 1.0, 1.0,
                    List[Int](), rng)
                if pick != 2:
                    single_ok = False
            var rng_n = RuneRNG(7)
            none_pick = sample_token_from_logits_restricted(
                logits, 5, texts, r_none, 1.0, 40, 1.0, 1.0,
                List[Int](), rng_n)
            var suppress_all = List[Int]()
            suppress_all.append(1)
            suppress_all.append(2)
            suppress_all.append(4)
            var rng_sa = RuneRNG(8)
            supp_pick = sample_token_from_logits_restricted(
                logits, 5, texts, r, 1.0, 40, 1.0, 1.0,
                List[Int](), rng_sa, suppress_tokens=suppress_all)
    except e:
        dealloc(allocation^)
        raise e^
    dealloc(allocation^)
    results.append(1 if single_ok else 0)
    results.append(none_pick)
    results.append(supp_pick)
    results.append(escaped)


def test_sampled_sampler() raises:
    var vocab = vr_parse_word_list("the cat sat on mat")
    var texts = List[String]()
    texts.append(" dog")
    texts.append(" cat")
    texts.append(" on")
    texts.append(" bird")
    texts.append("the")
    var other = vr_parse_word_list("qqq")
    var seen = List[Int]()
    seen.append(0)
    seen.append(0)
    seen.append(0)
    var results = List[Int]()
    _sampled_run(
        texts, VocabRestrictor(vocab), VocabRestrictor(other),
        seen, results)
    expect_eq_int(
        results[3], -2, "no sampled draw escaped the admitted set")
    expect_true(
        seen[0] > 0 and seen[1] > 0 and seen[2] > 0,
        "every admitted ID is reachable in sampled draws")
    expect_eq_int(
        results[0], 1, "single in-threshold admitted ID always drawn")
    expect_eq_int(results[1], -1, "none admitted sampled returns -1")
    expect_eq_int(
        results[2], -1, "all admitted suppressed sampled returns -1")
    print("PASS: sampled sampler (512 draws inside the admitted set, single-ID, -1 cases)")


def _loop_run(
    mut picks: List[Int], mut text_out: List[String],
    mut nums: List[Int],
) raises:
    var vocab = vr_parse_word_list("the cat sat on the mat")
    var texts = List[String]()
    texts.append("a")
    texts.append("the")
    texts.append(" dog")
    texts.append(" cat")
    texts.append(" ran")
    texts.append(" sat")
    texts.append(" on")
    texts.append(" under")
    texts.append(" mat")
    texts.append(" bird")
    texts.append(" the")
    var favourites = List[Int]()
    favourites.append(0)
    favourites.append(2)
    favourites.append(4)
    favourites.append(7)
    favourites.append(2)
    favourites.append(9)
    var continuations = List[Int]()
    continuations.append(1)
    continuations.append(3)
    continuations.append(5)
    continuations.append(6)
    continuations.append(10)
    continuations.append(8)
    var allocation = alloc(Layout[Scalar[f16]](count=11))
    var logits = allocation.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    var r = VocabRestrictor(vocab)
    var text = String("")
    var dead_pick = -2
    try:
        for step in range(6):
            for i in range(11):
                logits.unsafe_store(i, Scalar[f16](-5.0))
            logits.unsafe_store(favourites[step], Scalar[f16](9.0))
            logits.unsafe_store(continuations[step], Scalar[f16](6.0))
            var rng = RuneRNG(UInt64(100 + step))
            var pick = sample_token_from_logits_restricted(
                logits, 11, texts, r, 0.0, 40, 1.0, 1.0,
                List[Int](), rng)
            picks.append(pick)
            if pick >= 0:
                text += texts[pick]
                r.advance_state(texts[pick])
    except e:
        dealloc(allocation^)
        raise e^
    dealloc(allocation^)
    var dead_texts = List[String]()
    dead_texts.append(" dog")
    dead_texts.append(" bird")
    dead_texts.append(" fish")
    var dead_alloc = alloc(Layout[Scalar[f16]](count=3))
    var dead_logits = dead_alloc.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    dead_logits.unsafe_store(0, Scalar[f16](9.0))
    dead_logits.unsafe_store(1, Scalar[f16](8.0))
    dead_logits.unsafe_store(2, Scalar[f16](7.0))
    _ = dead_pick
    try:
        var rng_d = RuneRNG(200)
        dead_pick = sample_token_from_logits_restricted(
            dead_logits, 3, dead_texts, r, 0.0, 40, 1.0, 1.0,
            List[Int](), rng_d)
    except e:
        dealloc(dead_alloc^)
        raise e^
    dealloc(dead_alloc^)
    text_out.append(text)
    text_out.append(r.partial_word)
    nums.append(r.completed_words)
    nums.append(1 if r.is_accepting() else 0)
    nums.append(dead_pick)


def test_enforcement_loop() raises:
    var picks = List[Int]()
    var text_out = List[String]()
    var nums = List[Int]()
    _loop_run(picks, text_out, nums)
    var continuations = List[Int]()
    continuations.append(1)
    continuations.append(3)
    continuations.append(5)
    continuations.append(6)
    continuations.append(10)
    continuations.append(8)
    _expect_indices(picks, continuations, "loop picks")
    expect_eq_str(text_out[0], "the cat sat on the mat", "loop text (real sampler)")
    expect_eq_int(nums[0], 5, "loop completed words")
    expect_eq_int(nums[1], 1, "loop ends accepting")
    var vocab = vr_parse_word_list("the cat sat on the mat")
    var audit = vr_audit_text(vocab, text_out[0])
    expect_eq_int(audit.total_words, 6, "loop audit total")
    expect_eq_int(audit.permitted_words, 6, "loop audit all permitted")
    expect_false(audit.has_offender, "loop audit has no offender")
    expect_eq_int(nums[2], -1, "no-admitted step returns -1")
    expect_eq_str(text_out[1], "mat", "refused step leaves the partial word")
    expect_eq_int(nums[0], 5, "refused step leaves the count")
    print("PASS: enforcement loop (real sampler, clean audit, -1 stop, state untouched)")


def test_scan_account() raises:
    var texts = List[String]()
    texts.append(" dog")
    texts.append(" cat")
    texts.append(" on")
    texts.append(" bird ")
    texts.append("the")
    texts.append(" ca")
    var account = cg_scan_account(texts)
    expect_eq_int(account.candidates_scanned, 6, "scan count is the set size")
    expect_eq_int(account.text_bytes, 23, "scan bytes exact")
    var big = List[String]()
    var pieces = List[String]()
    pieces.append(" the")
    pieces.append(" cat")
    pieces.append(" dog")
    pieces.append(" xy")
    for i in range(1024):
        big.append(pieces[i % 4])
    var big_account = cg_scan_account(big)
    expect_eq_int(big_account.candidates_scanned, 1024, "big scan count")
    expect_eq_int(big_account.text_bytes, 3840, "big scan bytes exact")
    var vocab = vr_parse_word_list("the cat sat on mat")
    var r = VocabRestrictor(vocab)
    var logits = List[Float32]()
    for _ in range(1024):
        logits.append(Float32(1.0))
    var big_candidates = _candidates(logits)
    var admitted = cg_apply_vocab_mask(big_candidates, big, r)
    expect_eq_int(admitted, 512, "big set admitted count exact")
    expect_eq_int(
        admitted + 512, big_account.candidates_scanned,
        "admitted + masked == scanned at 1024")
    print("PASS: scan account (full scan, exact counts at 6 and 1024 candidates)")


def test_chat_surface() raises:
    expect_true(cg_is_constrain_command("/constrain"), "bare form is a command")
    expect_true(
        cg_is_constrain_command("/constrain list the"), "list form is a command")
    expect_false(
        cg_is_constrain_command("/constraints"), "near miss is not a command")
    expect_false(
        cg_is_constrain_command("/services"), "services is not a command here")
    var status = cg_constrain_response("/constrain")
    expect_in(status, "8192", "status carries the entry bound")
    expect_in(status, "64 bytes", "status carries the byte bound")
    expect_in(status, "NOT PROVEN", "status carries the binding honesty")
    expect_in(status, "/constrain list", "status names the list form")
    var listed = cg_constrain_response("/constrain list the, cat; sat the")
    expect_in(listed, "3 permitted words", "list form counts distinct words")
    expect_in(listed, "the, cat, sat", "list form canonicalises")
    var bare = cg_constrain_response("/constrain list")
    expect_in(bare, "Usage: /constrain list", "bare list form is a usage refusal")
    var empty = cg_constrain_response("/constrain list , ;")
    expect_in(empty, "constrain list refused:", "empty list refused by the layer")
    var long_word = String("")
    for _ in range(65):
        long_word += "x"
    var over = cg_constrain_response("/constrain list " + long_word)
    expect_in(over, "constrain list refused:", "over-bound word refused")
    var audit = cg_constrain_response(
        "/constrain audit the cat sat :: the dog sat")
    expect_in(audit, "3 words, 2 permitted", "audit counts exact")
    expect_in(audit, "first offender: dog", "audit offender exact")
    var clean = cg_constrain_response(
        "/constrain audit the on mat :: on the mat")
    expect_in(clean, "no offender", "clean audit has no offender")
    var no_sep = cg_constrain_response("/constrain audit the cat")
    expect_in(no_sep, "Usage: /constrain audit", "audit without separator refused")
    var unknown = cg_constrain_response("/constrain frobnicate")
    expect_in(unknown, "Unknown constrain form:", "unknown form refused by name")
    print("PASS: chat surface (status, list validate/canonicalise, audit, refusals)")


def test_server_surface() raises:
    var request = OpenAIRequest(
        String("{\"model\":\"m\",\"prompt\":\"x\","
               "\"vocab_restriction\":\"the cat\"}"))
    expect_true(request.has_vocab_restriction, "parser carries the flag")
    expect_eq_str(
        request.vocab_restriction, "the cat", "parser carries the list text")
    var plain = OpenAIRequest(
        String("{\"model\":\"m\",\"prompt\":\"x\"}"))
    expect_false(plain.has_vocab_restriction, "no field: flag stays false")
    expect_eq_str(plain.vocab_restriction, "", "no field: text stays empty")
    var refused = 0
    try:
        _ = OpenAIRequest(String(
            "{\"model\":\"m\",\"prompt\":\"x\","
            "\"vocab_restriction\":\"a\",\"vocab_restriction\":\"b\"}"))
    except:
        refused += 1
    expect_eq_int(refused, 1, "a duplicate vocab_restriction is refused")
    refused = 0
    try:
        _ = OpenAIRequest(String(
            "{\"model\":\"m\",\"prompt\":\"x\","
            "\"vocab_restriction\":\"the cat\","
            "\"response_format\":{\"type\":\"json_schema\","
            "\"json_schema\":{\"name\":\"b\",\"strict\":true,"
            "\"schema\":{\"type\":\"boolean\"}}}}"))
    except:
        refused += 1
    expect_eq_int(
        refused, 1, "vocab_restriction + Boolean response_format refused")
    var valid = cg_serve_vocab_response("the cat sat")
    expect_in(valid, "list valid (3 permitted words", "serve text counts the list")
    expect_in(valid, "the, cat, sat", "serve text canonicalises")
    expect_in(valid, "generation refused", "serve text states the refusal")
    expect_in(valid, "cannot enforce", "serve text states the reason")
    var invalid = cg_serve_vocab_response("")
    expect_in(
        invalid, "vocab_restriction refused:", "serve text refuses an empty list")
    var long_word = String("")
    for _ in range(65):
        long_word += "y"
    var over = cg_serve_vocab_response(long_word)
    expect_in(
        over, "vocab_restriction refused:", "serve text refuses an over-bound word")
    print("PASS: server surface (field parsed/bounded, duplicates + format refused, serve text)")


def main() raises:
    test_mask_agreement()
    test_greedy_sampler()
    test_sampled_sampler()
    test_enforcement_loop()
    test_scan_account()
    test_chat_surface()
    test_server_surface()
    print("ALL PASS: constrained generation (7 groups)")
