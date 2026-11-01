"""Speculative acceptance measurement (J-075): the
classifier's stated rules (structured before code before
prose; language for prose only, by the fixed marker counts,
ties and low evidence filed as other); the ledger bound to
J-071's verify account (a round enters only as a consistent
VerifyAccount, keyed by the account's own proposer kind;
totals and the accepted-count histogram accumulated from
the account alone; an inconsistent account, a pair id on a
non-cross-model kind, and a language/text-type combination
the rules forbid each refused); rows separated by pair and
by text type and by language; the rate reproduced from a
row's distribution; and the filed SIMULATED measurement
over synthetic-proposer fixtures (the J-074 first pair's
shape, stated draft/target lists built through plan_verify):
English prose 34/40, Italian prose 12/40 -- the same pair,
the same depth, a collapse the prose aggregate (46/80)
hides and the separated rows expose. No forward runs: the
fixtures check the instrument and demonstrate the lesson at
the SIMULATED class; real-pair acceptance is NOT PROVEN
(J-075 doc section 6, re-cited at the J-086 gate).
"""
from core.speculative_acceptance import (
    LANG_ENGLISH,
    LANG_ITALIAN,
    LANG_NOT_APPLICABLE,
    LANG_OTHER,
    PAIR_ID_NONE,
    PAIR_ID_QWEN3_06B_TO_4B,
    TEXT_CODE,
    TEXT_PROSE,
    TEXT_STRUCTURED,
    AcceptanceLedger,
    TextFeatures,
    classify_text,
    language_name,
    ledger_totals,
    rate_basis_points,
    record_round,
    record_round_classified,
    row_totals_reproduce,
    text_type_name,
)
from core.speculative_verify import (
    PROPOSER_CONVERSATION,
    PROPOSER_CROSS_MODEL,
    PROPOSER_MTP_HEAD,
    VerifyAccount,
    plan_verify,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "SpeculativeAcceptance " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("SpeculativeAcceptance " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("SpeculativeAcceptance " + what + ": expected false")


def features(
    fences: Int,
    semis: Int,
    braces: Int,
    brackets: Int,
    colons: Int,
    keywords: Int,
    starts: Bool,
    italian: Int,
    english: Int,
) -> TextFeatures:
    return TextFeatures(
        fences, semis, braces, brackets, colons, keywords, starts, italian, english
    )


def prose_features(italian: Int, english: Int) -> TextFeatures:
    return features(0, 0, 0, 0, 1, 0, False, italian, english)


def make_account(kind: Int, k: Int, accepted: Int) raises -> VerifyAccount:
    """A synthetic round: the draft matches the target's
    greedy list for exactly `accepted` positions, then
    diverges. Built through J-071's plan_verify, so every
    fixture account is a consistent verify account."""
    var target = List[Int]()
    for i in range(k + 1):
        target.append(100 + i)
    var draft = List[Int]()
    for i in range(k):
        if i < accepted:
            draft.append(100 + i)
        else:
            draft.append(900 + i)
    return plan_verify(kind, draft, target, 0, 256, 0, 0)


def record_n(
    mut ledger: AcceptanceLedger,
    kind: Int,
    pair_id: Int,
    text_type: Int,
    language: Int,
    k: Int,
    accepted_list: List[Int],
) raises:
    for i in range(len(accepted_list)):
        var account = make_account(kind, k, accepted_list[i])
        record_round(ledger, pair_id, text_type, language, account)


def test_classifier_structured_and_code() raises:
    var structured = classify_text(features(0, 0, 3, 2, 5, 0, True, 0, 0))
    expect_eq(structured.text_type, TEXT_STRUCTURED, "brace-led keyed text")
    expect_eq(structured.language, LANG_NOT_APPLICABLE, "structured language")
    var priority = classify_text(features(1, 4, 3, 2, 5, 6, True, 0, 0))
    expect_eq(priority.text_type, TEXT_STRUCTURED, "structured beats code (rule order)")
    var fenced = classify_text(features(1, 0, 0, 0, 0, 0, False, 0, 0))
    expect_eq(fenced.text_type, TEXT_CODE, "a fence makes code")
    expect_eq(fenced.language, LANG_NOT_APPLICABLE, "code language")
    var keywords = classify_text(features(0, 0, 0, 0, 0, 3, False, 0, 0))
    expect_eq(keywords.text_type, TEXT_CODE, "keyword density makes code")
    var punct = classify_text(features(0, 3, 1, 0, 0, 0, False, 0, 0))
    expect_eq(punct.text_type, TEXT_CODE, "semicolons + brace makes code")
    var almost = classify_text(features(0, 0, 1, 0, 0, 0, True, 0, 0))
    expect_eq(almost.text_type, TEXT_PROSE, "brace-led without colons/keys is prose")
    print("PASS: classifier -- structured first, then code, by stated features")


def test_classifier_prose_and_language() raises:
    var en = classify_text(prose_features(1, 6))
    expect_eq(en.text_type, TEXT_PROSE, "plain text is prose")
    expect_eq(en.language, LANG_ENGLISH, "english markers win")
    var it = classify_text(prose_features(7, 1))
    expect_eq(it.language, LANG_ITALIAN, "italian markers win")
    var tie = classify_text(prose_features(3, 3))
    expect_eq(tie.language, LANG_OTHER, "a marker tie files as other")
    var low = classify_text(prose_features(1, 0))
    expect_eq(low.language, LANG_OTHER, "below-threshold evidence files as other")
    var none = classify_text(prose_features(0, 0))
    expect_eq(none.language, LANG_OTHER, "no markers files as other")
    var code_it = classify_text(features(1, 0, 0, 0, 0, 0, False, 9, 0))
    expect_eq(code_it.language, LANG_NOT_APPLICABLE,
              "italian markers inside code stay not_applicable")
    print("PASS: classifier -- prose language by markers; tie/low = other; code NA")


def test_record_binds_verify_account() raises:
    var ledger = AcceptanceLedger()
    var account = make_account(PROPOSER_MTP_HEAD, 4, 3)
    record_round(ledger, PAIR_ID_NONE, TEXT_PROSE, LANG_ENGLISH, account)
    expect_eq(len(ledger.rows), 1, "one row filed")
    var row = ledger.rows[0].copy()
    expect_eq(row.proposer_kind, PROPOSER_MTP_HEAD, "kind read off the account")
    expect_eq(row.rounds, 1, "rounds")
    expect_eq(row.drafted, 4, "drafted is the account's k")
    expect_eq(row.accepted, 3, "accepted is the account's accepted_count")
    expect_eq(row.hist[3], 1, "histogram bin for accepted=3")
    expect_eq(rate_basis_points(row), 7500, "rate 3/4 in basis points")
    var second = make_account(PROPOSER_MTP_HEAD, 4, 4)
    record_round(ledger, PAIR_ID_NONE, TEXT_PROSE, LANG_ENGLISH, second)
    var row2 = ledger.rows[0].copy()
    expect_eq(row2.rounds, 2, "same key accumulates in one row")
    expect_eq(row2.drafted, 8, "drafted accumulates")
    expect_eq(row2.accepted, 7, "accepted accumulates")
    print("PASS: record -- bound to the J-071 account, totals from the account alone")


def test_record_refusals() raises:
    var ledger = AcceptanceLedger()
    # An inconsistent account (tampered after plan_verify).
    var bad = make_account(PROPOSER_MTP_HEAD, 4, 3)
    bad.kv_after = bad.kv_after + 1
    var refused = False
    try:
        record_round(ledger, PAIR_ID_NONE, TEXT_PROSE, LANG_ENGLISH, bad)
    except:
        refused = True
    expect_true(refused, "inconsistent account refused")
    expect_eq(len(ledger.rows), 0, "a refused record files nothing")
    # A pair id on a non-cross-model kind.
    var good = make_account(PROPOSER_MTP_HEAD, 4, 3)
    refused = False
    try:
        record_round(ledger, PAIR_ID_QWEN3_06B_TO_4B, TEXT_PROSE, LANG_ENGLISH, good)
    except:
        refused = True
    expect_true(refused, "pair id on a head proposer refused")
    # Prose with not_applicable language.
    refused = False
    try:
        record_round(ledger, PAIR_ID_NONE, TEXT_PROSE, LANG_NOT_APPLICABLE, good)
    except:
        refused = True
    expect_true(refused, "prose without a language refused")
    # Code with a real language.
    refused = False
    try:
        record_round(ledger, PAIR_ID_NONE, TEXT_CODE, LANG_ENGLISH, good)
    except:
        refused = True
    expect_true(refused, "code with a language refused")
    expect_eq(len(ledger.rows), 0, "every refusal left the ledger empty")
    print("PASS: record refusals -- inconsistent account, pair-id misuse, language misuse")


def test_row_key_separation() raises:
    var ledger = AcceptanceLedger()
    var a = make_account(PROPOSER_CROSS_MODEL, 4, 2)
    record_round(ledger, 1, TEXT_PROSE, LANG_ENGLISH, a)
    record_round(ledger, 2, TEXT_PROSE, LANG_ENGLISH, a)
    var b = make_account(PROPOSER_CONVERSATION, 4, 2)
    record_round(ledger, PAIR_ID_NONE, TEXT_PROSE, LANG_ENGLISH, b)
    record_round(ledger, 1, TEXT_PROSE, LANG_ITALIAN, a)
    record_round(ledger, 1, TEXT_CODE, LANG_NOT_APPLICABLE, a)
    expect_eq(len(ledger.rows), 5, "kind/pair/type/language each separate rows")
    expect_true(ledger.find_row(PROPOSER_CROSS_MODEL, 2, TEXT_PROSE, LANG_ENGLISH) >= 0,
                "second pair has its own row")
    expect_eq(ledger.find_row(PROPOSER_CROSS_MODEL, 3, TEXT_PROSE, LANG_ENGLISH), -1,
              "an unfiled pair has no row")
    print("PASS: separation -- rows keyed by kind, pair, text type, language")


def measure_pair_ledger() raises -> AcceptanceLedger:
    """The filed SIMULATED measurement fixture: the first
    pair's shape (cross-model, pair id 1), k=4, ten rounds
    per row, accepted counts stated per row."""
    var ledger = AcceptanceLedger()
    var en = List[Int]()
    en.append(4)
    en.append(4)
    en.append(3)
    en.append(4)
    en.append(3)
    en.append(4)
    en.append(4)
    en.append(3)
    en.append(4)
    en.append(1)
    record_n(ledger, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B,
             TEXT_PROSE, LANG_ENGLISH, 4, en)
    var it = List[Int]()
    it.append(2)
    it.append(1)
    it.append(1)
    it.append(2)
    it.append(1)
    it.append(0)
    it.append(2)
    it.append(1)
    it.append(1)
    it.append(1)
    record_n(ledger, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B,
             TEXT_PROSE, LANG_ITALIAN, 4, it)
    var code = List[Int]()
    code.append(4)
    code.append(3)
    code.append(4)
    code.append(4)
    code.append(2)
    code.append(4)
    code.append(3)
    code.append(4)
    code.append(4)
    code.append(4)
    record_n(ledger, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B,
             TEXT_CODE, LANG_NOT_APPLICABLE, 4, code)
    var structured = List[Int]()
    structured.append(3)
    structured.append(3)
    structured.append(4)
    structured.append(3)
    structured.append(2)
    structured.append(3)
    structured.append(4)
    structured.append(3)
    structured.append(3)
    structured.append(3)
    record_n(ledger, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B,
             TEXT_STRUCTURED, LANG_NOT_APPLICABLE, 4, structured)
    return ledger^


def test_measurement_italian_collapse() raises:
    var ledger = measure_pair_ledger()
    var en_idx = ledger.find_row(PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ENGLISH)
    var it_idx = ledger.find_row(PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ITALIAN)
    var en = ledger.rows[en_idx].copy()
    var it = ledger.rows[it_idx].copy()
    expect_eq(en.accepted, 34, "english prose accepted")
    expect_eq(en.drafted, 40, "english prose drafted")
    expect_eq(rate_basis_points(en), 8500, "english prose rate")
    expect_eq(it.accepted, 12, "italian prose accepted")
    expect_eq(it.drafted, 40, "italian prose drafted")
    expect_eq(rate_basis_points(it), 3000, "italian prose rate")
    expect_true(rate_basis_points(it) * 2 < rate_basis_points(en),
                "italian rate is under half the english rate (the collapse)")
    # The prose aggregate hides it; the rows expose it.
    var prose = AcceptanceLedger()
    var en_only = List[Int]()
    en_only.append(4)
    en_only.append(4)
    en_only.append(3)
    en_only.append(4)
    en_only.append(3)
    en_only.append(4)
    en_only.append(4)
    en_only.append(3)
    en_only.append(4)
    en_only.append(1)
    var it_only = List[Int]()
    it_only.append(2)
    it_only.append(1)
    it_only.append(1)
    it_only.append(2)
    it_only.append(1)
    it_only.append(0)
    it_only.append(2)
    it_only.append(1)
    it_only.append(1)
    it_only.append(1)
    record_n(prose, PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ENGLISH, 4, en_only)
    record_n(prose, PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ITALIAN, 4, it_only)
    var agg = ledger_totals(prose, PROPOSER_CROSS_MODEL, 1)
    expect_eq(agg.accepted, 46, "prose aggregate accepted")
    expect_eq(agg.drafted, 80, "prose aggregate drafted")
    expect_eq(rate_basis_points(agg), 5750, "prose aggregate rate")
    expect_true(
        rate_basis_points(it) < rate_basis_points(agg)
        and rate_basis_points(agg) < rate_basis_points(en),
        "the aggregate sits between the rows it hides")
    print("MEASURE SIMULATED pair=cross_model/1 prose/english accepted=34 drafted=40 rate_bp=8500")
    print("MEASURE SIMULATED pair=cross_model/1 prose/italian accepted=12 drafted=40 rate_bp=3000")
    print("MEASURE SIMULATED pair=cross_model/1 prose/AGGREGATE accepted=46 drafted=80 rate_bp=5750")
    print("PASS: measurement -- italian-prose collapse separated; aggregate hides it")


def test_measurement_text_types() raises:
    var ledger = measure_pair_ledger()
    var code_idx = ledger.find_row(PROPOSER_CROSS_MODEL, 1, TEXT_CODE, LANG_NOT_APPLICABLE)
    var st_idx = ledger.find_row(PROPOSER_CROSS_MODEL, 1, TEXT_STRUCTURED, LANG_NOT_APPLICABLE)
    var code = ledger.rows[code_idx].copy()
    var structured = ledger.rows[st_idx].copy()
    expect_eq(code.accepted, 36, "code accepted")
    expect_eq(rate_basis_points(code), 9000, "code rate")
    expect_eq(structured.accepted, 31, "structured accepted")
    expect_eq(rate_basis_points(structured), 7750, "structured rate")
    var agg = ledger_totals(ledger, PROPOSER_CROSS_MODEL, 1)
    expect_eq(agg.rounds, 40, "pair rounds across all rows")
    expect_eq(agg.drafted, 160, "pair drafted across all rows")
    expect_eq(agg.accepted, 113, "pair accepted across all rows")
    expect_eq(rate_basis_points(agg), 7062, "pair aggregate rate")
    print("MEASURE SIMULATED pair=cross_model/1 code accepted=36 drafted=40 rate_bp=9000")
    print("MEASURE SIMULATED pair=cross_model/1 structured accepted=31 drafted=40 rate_bp=7750")
    print("MEASURE SIMULATED pair=cross_model/1 ALL accepted=113 drafted=160 rate_bp=7062")
    print("PASS: measurement -- per-text-type rates for one pair, aggregate beside them")


def test_distribution_reproduces_totals() raises:
    var ledger = measure_pair_ledger()
    for i in range(len(ledger.rows)):
        var row = ledger.rows[i].copy()
        expect_true(row_totals_reproduce(row), "row distribution reproduces its totals")
    var it_idx = ledger.find_row(PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ITALIAN)
    var it = ledger.rows[it_idx].copy()
    expect_eq(it.hist[0], 1, "italian rounds accepting none")
    expect_eq(it.hist[1], 6, "italian rounds accepting one")
    expect_eq(it.hist[2], 3, "italian rounds accepting two")
    expect_eq(it.hist[4], 0, "italian rounds accepting all four")
    var en_idx = ledger.find_row(PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ENGLISH)
    var en = ledger.rows[en_idx].copy()
    expect_eq(en.hist[4], 6, "english rounds accepting all four")
    print("PASS: distribution -- histogram reproduces rounds and accepted per row")


def test_classified_recording_path() raises:
    var ledger = AcceptanceLedger()
    var account = make_account(PROPOSER_CROSS_MODEL, 4, 2)
    record_round_classified(ledger, 1, prose_features(8, 1), account)
    expect_true(ledger.find_row(PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ITALIAN) >= 0,
                "classified italian prose lands in the italian row")
    record_round_classified(ledger, 1, features(1, 0, 0, 0, 0, 0, False, 9, 0), account)
    expect_true(
        ledger.find_row(PROPOSER_CROSS_MODEL, 1, TEXT_CODE, LANG_NOT_APPLICABLE) >= 0,
        "classified code lands in the code row, language NA despite markers")
    expect_eq(len(ledger.rows), 2, "two classified rows")
    print("PASS: classified recording -- the host path files by classifier verdict")


def test_rate_edges_and_names() raises:
    var empty = AcceptanceLedger()
    var agg = ledger_totals(empty, PROPOSER_CROSS_MODEL, 1)
    expect_eq(agg.drafted, 0, "an unmeasured pair has no drafted tokens")
    var refused = False
    try:
        _ = rate_basis_points(agg)
    except:
        refused = True
    expect_true(refused, "a rate over zero drafted refuses, never 0 or 100%")
    expect_true(text_type_name(TEXT_PROSE) == String("prose"), "type names itself")
    expect_true(text_type_name(TEXT_STRUCTURED) == String("structured"), "type names itself")
    expect_true(language_name(LANG_ITALIAN) == String("italian"), "language names itself")
    expect_true(language_name(LANG_NOT_APPLICABLE) == String("not_applicable"),
                "language names itself")
    print("PASS: rate edges -- empty pair has no rate; names are the stated words")


def main() raises:
    test_classifier_structured_and_code()
    test_classifier_prose_and_language()
    test_record_binds_verify_account()
    test_record_refusals()
    test_row_key_separation()
    test_measurement_italian_collapse()
    test_measurement_text_types()
    test_distribution_reproduces_totals()
    test_classified_recording_path()
    test_rate_edges_and_names()
    print("ALL PASS: speculative acceptance measurement (10 groups)")
