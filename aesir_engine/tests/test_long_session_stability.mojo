"""Long-session stability (J-085): the pre-registered
verdict rule's three legs over the J-033-shaped fixture
stream -- (a) no drift: the speculative emission over
2,224 emitted tokens across 8 mixed segments equals the
plain sequential account token-for-token (divergence
exactly -1); (b) no state leakage across rollbacks:
after every round the committed KV / context / proposer
KV / RNG word recomputed from the pre-draft checkpoint
and the J-071 account matches the loop state exactly,
violations counted, zero the only passing number, with
the same accounts closing at every segment boundary;
(c) memory held: KV/context maxima inside the 512
capacity, verify widths inside the J-035 band, ledger
rows at the 5-row bound with the closing plateau,
growth fully accounted by row creation, rollback
identity exact over the whole stream. Plus the composed
controllers over the long stream (J-079 adaptive bounds,
J-084 guard), the hostile fixed-k segment (the guard
disables at exactly round 8 and the plain fallback
finishes the segment drift-free with the guard frozen),
segment-boundary isolation, refusals leaving state
untouched, and determinism.

Fixtures are the module's stated stream (SIMULATED):
plain tokens by the module's arithmetic rule, drafts by
its regime cycles (J-079's filed cycles, shaped from
J-075's filed rows). No model drafted or verified
anywhere in this suite. Live long-session stability is
NOT PROVEN (J-085 doc section 6).
"""
from core.long_session_stability import (
    DRAFT_MISS_OFFSET,
    DRIVE_ADAPTIVE,
    DRIVE_FIXED,
    LEDGER_ROW_UNITS,
    LONG_KV_CAPACITY,
    LONG_LEDGER_ROW_BOUND,
    LONG_MIN_EMITTED,
    LONG_PROMPT_MAX,
    LONG_SEGMENT_COUNT,
    REGIME_COLD,
    REGIME_HOT,
    REGIME_MIXED,
    SegmentSpec,
    build_plain_segment,
    build_round_drafts,
    drive_segment,
    plain_token,
    regime_name,
    regime_prefix_length,
    run_long_session,
    sampling_band_agrees,
    segment_spec,
    stability_passed,
    total_plain_length,
)
from core.speculative_acceptance import (
    LANG_ENGLISH,
    LANG_ITALIAN,
    LANG_NOT_APPLICABLE,
    LANG_OTHER,
    TEXT_CODE,
    TEXT_PROSE,
    TEXT_STRUCTURED,
    AcceptanceLedger,
)
from core.speculative_loop import LOOP_K_INITIAL
from core.speculative_verify import (
    plan_verify,
    sequences_identical,
)

comptime RNG_WORD = UInt64(424242)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "LongSessionStability " + what + ": expected "
            + String(expected) + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("LongSessionStability " + what + ": expected true")


def test_stream_table() raises:
    expect_eq(LONG_SEGMENT_COUNT, 8, "the J-033 soak has 8 windows")
    expect_eq(total_plain_length(), 2224, "stream plain total")
    expect_true(
        total_plain_length() >= LONG_MIN_EMITTED,
        "the stream meets the 2,000-token soak floor",
    )
    expect_eq(LONG_MIN_EMITTED, 2000, "the soak floor is J-033's 2,000")
    var rows_seen = 0
    for i in range(LONG_SEGMENT_COUNT):
        var spec = segment_spec(i)
        expect_true(spec.plain_len > 0, "every segment generates")
        expect_true(spec.prompt_len <= LONG_PROMPT_MAX, "prompt bound (J-033)")
        expect_true(
            spec.prompt_len + spec.plain_len <= LONG_KV_CAPACITY,
            "every segment fits its session context",
        )
        _ = regime_name(spec.regime)
        # Count first sightings of each (type, language) row.
        var seen_before = False
        for j in range(i):
            var prev = segment_spec(j)
            if prev.text_type == spec.text_type and prev.language == spec.language:
                seen_before = True
        if not seen_before:
            rows_seen += 1
    expect_eq(rows_seen, LONG_LEDGER_ROW_BOUND, "the stream exercises 5 rows")
    expect_eq(LONG_LEDGER_ROW_BOUND, 5, "one pair's full J-075 row space")
    expect_eq(LEDGER_ROW_UNITS, 19, "row units = 3 scalars + 16 hist bins")
    var refused = False
    try:
        _ = segment_spec(8)
    except:
        refused = True
    expect_true(refused, "a ninth segment is refused")
    print("PASS: stream table -- 8 segments, 2,224 plain, 5 rows, bounds stated")


def test_plain_and_drafts() raises:
    for seg in range(LONG_SEGMENT_COUNT):
        var plain = build_plain_segment(seg)
        expect_eq(len(plain), segment_spec(seg).plain_len, "segment length")
        for pos in range(len(plain)):
            expect_eq(
                plain[pos], plain_token(seg, pos), "plain token reproducible"
            )
    # The draft builder + J-071 derive exactly min(k, L).
    var target = List[Int]()
    for i in range(5):
        target.append(100 + i)
    var cases = List[Int]()
    cases.append(0)
    cases.append(2)
    cases.append(4)
    cases.append(9)
    var expected = List[Int]()
    expected.append(0)
    expected.append(2)
    expected.append(4)
    expected.append(4)
    for c in range(4):
        var drafts = build_round_drafts(target, cases[c])
        expect_eq(len(drafts), 4, "draft list holds k")
        var account = plan_verify(2, drafts, target, 0, 512, 0, 0)
        expect_eq(
            account.accepted_count, expected[c], "accepted == min(k, L)"
        )
        if cases[c] == 0:
            expect_eq(
                drafts[0], target[0] + DRAFT_MISS_OFFSET, "a miss is offset"
            )
    # Regime cycles are the filed J-079 cycles.
    expect_eq(regime_prefix_length(REGIME_HOT, 0), 8, "hot cycle head")
    expect_eq(regime_prefix_length(REGIME_COLD, 1), 0, "cold cycle second")
    expect_eq(regime_prefix_length(REGIME_MIXED, 5), 5, "mixed cycle sixth")
    expect_eq(
        regime_prefix_length(REGIME_COLD, 9),
        regime_prefix_length(REGIME_COLD, 1),
        "cycles repeat every 8 rounds",
    )
    print("PASS: plain + drafts -- reproducible stream; accepted == min(k, L)")


def test_sampling_band() raises:
    expect_true(
        sampling_band_agrees(),
        "J-082's sampled k cap equals J-071's band top less one",
    )
    print("PASS: sampling band -- J-082 bound to J-071's draft-check band")


def test_single_segment() raises:
    var ledger = AcceptanceLedger()
    var spec = segment_spec(0)
    var plain = build_plain_segment(0)
    var res = drive_segment(
        spec, plain, ledger, DRIVE_ADAPTIVE, LOOP_K_INITIAL, RNG_WORD
    )
    expect_true(
        sequences_identical(res.emitted, plain),
        "segment 0 emission identical to plain",
    )
    expect_eq(res.emitted_count, spec.plain_len, "segment 0 emitted in full")
    expect_eq(res.leakage_violations, 0, "segment 0 leakage zero")
    var fallback_checks = 0
    if res.fallback_tokens > 0:
        fallback_checks = 2
    expect_eq(
        res.leakage_checks, res.rounds * 11 + 4 + fallback_checks,
        "segment 0 checks counted per round + boundary",
    )
    expect_eq(
        res.final_kv, spec.prompt_len + spec.plain_len, "segment 0 final KV"
    )
    expect_eq(
        res.final_context,
        spec.prompt_len + spec.plain_len,
        "segment 0 final context",
    )
    expect_eq(res.final_draft_kv, res.accepted, "proposer KV = accepted total")
    expect_eq(
        res.rollback_rows, res.drafted - res.accepted, "rollback identity"
    )
    expect_eq(len(ledger.rows), 1, "one row filed for one segment")
    var row = ledger.rows[0].copy()
    expect_eq(row.rounds, res.rounds, "ledger rounds == driven rounds")
    expect_eq(row.text_type, TEXT_PROSE, "segment 0 files as prose")
    expect_eq(row.language, LANG_ENGLISH, "segment 0 files as english")
    print("PASS: single segment -- drift-free, leakage zero, accounts close")


def test_long_session_drift() raises:
    var report = run_long_session(RNG_WORD)
    expect_eq(report.segments, 8, "all segments driven")
    expect_eq(report.emitted, 2224, "emitted meets the filed total")
    expect_true(report.emitted >= LONG_MIN_EMITTED, "soak floor met")
    expect_eq(report.divergence, -1, "divergence exactly -1 (no drift)")
    expect_true(
        sequences_identical(report.spec_emitted, report.plain_full),
        "speculative stream identical to plain stream",
    )
    expect_eq(
        len(report.spec_emitted), report.emitted, "emitted list is the product"
    )
    expect_true(stability_passed(report), "the pre-registered verdict passes")
    print("PASS: long drift -- 2,224 emitted, divergence -1, verdict PASS")


def test_long_session_leakage() raises:
    var report = run_long_session(RNG_WORD)
    expect_eq(report.leakage_violations, 0, "zero leakage violations")
    expect_true(
        report.leakage_checks >= report.rounds * 11 + 4 * LONG_SEGMENT_COUNT,
        "every round and boundary was checked",
    )
    expect_true(report.rounds > 400, "the stream is long (hundreds of rounds)")
    expect_eq(
        report.rollback_rows,
        report.drafted - report.accepted,
        "rollback identity over the whole stream",
    )
    expect_eq(
        report.emitted,
        report.accepted + report.rounds + report.fallback_tokens,
        "emitted = accepted + one per round + plain fallback",
    )
    print("PASS: long leakage -- violations 0 over every round + boundary")


def test_long_session_memory() raises:
    var report = run_long_session(RNG_WORD)
    expect_eq(report.max_kv, 355, "max KV = segment 0's 67 + 288")
    expect_eq(report.max_context, 355, "max context = segment 0's 67 + 288")
    expect_true(report.max_kv <= LONG_KV_CAPACITY, "KV inside capacity")
    expect_true(report.max_width <= 16, "verify width inside the band")
    expect_true(report.max_width >= 5, "verify passes really ran wide")
    expect_true(report.max_window_rounds <= 3, "window counters under 4")
    expect_eq(report.ledger_rows_final, 5, "ledger rows at the bound")
    expect_eq(report.overhead_final, 95, "overhead = 5 rows x 19 units")
    expect_eq(len(report.segment_end_rows), 8, "growth sampled per segment")
    for i in range(8):
        if i > 0:
            expect_true(
                report.segment_end_rows[i] >= report.segment_end_rows[i - 1],
                "rows never shrink",
            )
            var delta = (
                report.segment_end_overhead[i]
                - report.segment_end_overhead[i - 1]
            )
            expect_true(
                delta == 0 or delta == LEDGER_ROW_UNITS,
                "growth is row creations only",
            )
    expect_eq(report.segment_end_rows[7], 5, "plateau: last segment at bound")
    expect_eq(report.segment_end_rows[6], 5, "plateau: growth stopped early")
    print("PASS: long memory -- bounds held, plateau reached, growth accounted")


def test_long_session_controllers() raises:
    var report = run_long_session(RNG_WORD)
    expect_true(report.adaptive_windows > 0, "adaptive windows closed")
    expect_true(report.min_k_seen >= 1, "k never below J-072's floor")
    expect_true(report.max_k_seen <= 15, "k never above the proposer's cap")
    expect_true(report.max_k_seen > LOOP_K_INITIAL, "the hot segments deepened")
    expect_eq(
        report.ledger_rounds_total, report.rounds, "ledger read every round"
    )
    expect_true(
        report.guard_disables <= report.segments, "disables are per segment"
    )
    print("PASS: long controllers -- adaptive in bounds; ledger complete")


def test_hostile_segment_disable() raises:
    var ledger = AcceptanceLedger()
    var spec = SegmentSpec(TEXT_PROSE, LANG_ITALIAN, REGIME_COLD, 64, 40)
    var plain = List[Int]()
    for pos in range(64):
        plain.append(plain_token(4, pos))
    var res = drive_segment(spec, plain, ledger, DRIVE_FIXED, 4, RNG_WORD)
    expect_true(res.guard_disabled, "the hostile segment's guard disables")
    expect_eq(res.guard_disabled_at_round, 8, "disabled at exactly round 8")
    expect_eq(res.rounds, 8, "speculation stopped at the disable")
    expect_eq(res.guard_rounds, 8, "the frozen guard consumed exactly 8")
    expect_eq(res.accepted, 8, "cold cycle accepted over 8 rounds")
    expect_eq(res.fallback_tokens, 48, "the remainder ran plain")
    expect_eq(res.emitted_count, 64, "the segment still completes in full")
    expect_true(
        sequences_identical(res.emitted, plain),
        "disable + fallback stays drift-free",
    )
    expect_eq(res.leakage_violations, 0, "no leakage across the disable")
    expect_eq(res.final_draft_kv, 8, "proposer KV froze with acceptance")
    expect_eq(len(ledger.rows), 1, "only speculative rounds filed")
    var row = ledger.rows[0].copy()
    expect_eq(row.rounds, 8, "fallback tokens file no ledger rounds")
    print("PASS: hostile segment -- disable at round 8, plain fallback exact")


def test_fixed_hot_segment() raises:
    var ledger = AcceptanceLedger()
    var spec = SegmentSpec(TEXT_CODE, LANG_NOT_APPLICABLE, REGIME_HOT, 48, 40)
    var plain = List[Int]()
    for pos in range(48):
        plain.append(plain_token(1, pos))
    var res = drive_segment(spec, plain, ledger, DRIVE_FIXED, 2, RNG_WORD)
    expect_true(not res.guard_disabled, "a hot fixed segment never disables")
    expect_eq(res.emitted_count, 48, "the segment completes")
    expect_true(
        sequences_identical(res.emitted, plain), "fixed-k emission identical"
    )
    expect_eq(res.leakage_violations, 0, "no leakage at fixed k")
    print("PASS: fixed hot segment -- no disable, drift-free at fixed k=2")


def test_segment_boundary_isolation() raises:
    var ledger = AcceptanceLedger()
    var spec0 = segment_spec(0)
    var res0 = drive_segment(
        spec0, build_plain_segment(0), ledger, DRIVE_ADAPTIVE,
        LOOP_K_INITIAL, RNG_WORD,
    )
    var spec1 = segment_spec(1)
    var res1 = drive_segment(
        spec1, build_plain_segment(1), ledger, DRIVE_ADAPTIVE,
        LOOP_K_INITIAL, RNG_WORD,
    )
    expect_eq(
        res1.final_kv,
        spec1.prompt_len + spec1.plain_len,
        "segment 1 closes on its own checkpoint, not segment 0's end",
    )
    expect_eq(
        res1.final_draft_kv, res1.accepted, "proposer KV is per-session"
    )
    expect_true(res0.final_kv != res1.final_kv, "checkpoints distinct")
    expect_eq(len(ledger.rows), 2, "the shared ledger keeps both rows")
    print("PASS: boundary isolation -- each session closes on its own account")


def test_refusals_leave_state_untouched() raises:
    var ledger = AcceptanceLedger()
    var refused = 0
    var spec = segment_spec(0)
    var short_plain = List[Int]()
    short_plain.append(1)
    try:
        _ = drive_segment(
            spec, short_plain, ledger, DRIVE_ADAPTIVE, LOOP_K_INITIAL, RNG_WORD
        )
    except:
        refused += 1
    var long_prompt = SegmentSpec(TEXT_PROSE, LANG_ENGLISH, REGIME_HOT, 16, 201)
    var plain16 = List[Int]()
    for pos in range(16):
        plain16.append(plain_token(0, pos))
    try:
        _ = drive_segment(
            long_prompt, plain16, ledger, DRIVE_ADAPTIVE, LOOP_K_INITIAL, RNG_WORD
        )
    except:
        refused += 1
    var too_big = SegmentSpec(TEXT_PROSE, LANG_ENGLISH, REGIME_HOT, 500, 67)
    var plain500 = List[Int]()
    for pos in range(500):
        plain500.append(plain_token(0, pos))
    try:
        _ = drive_segment(
            too_big, plain500, ledger, DRIVE_ADAPTIVE, LOOP_K_INITIAL, RNG_WORD
        )
    except:
        refused += 1
    try:
        _ = drive_segment(
            spec, build_plain_segment(0), ledger, 99, LOOP_K_INITIAL, RNG_WORD
        )
    except:
        refused += 1
    try:
        _ = drive_segment(
            spec, build_plain_segment(0), ledger, DRIVE_FIXED, 0, RNG_WORD
        )
    except:
        refused += 1
    try:
        _ = drive_segment(
            spec, build_plain_segment(0), ledger, DRIVE_FIXED, 16, RNG_WORD
        )
    except:
        refused += 1
    expect_eq(refused, 6, "drive refusals 6/6")
    expect_eq(len(ledger.rows), 0, "a refused drive files nothing")
    print("PASS: refusals -- bad drives refused 6/6, ledger untouched")


def test_determinism() raises:
    var a = run_long_session(RNG_WORD)
    var b = run_long_session(RNG_WORD)
    expect_eq(a.rounds, b.rounds, "same rounds")
    expect_eq(a.drafted, b.drafted, "same drafted")
    expect_eq(a.accepted, b.accepted, "same accepted")
    expect_eq(a.fallback_tokens, b.fallback_tokens, "same fallback")
    expect_eq(a.divergence, b.divergence, "same divergence")
    expect_true(
        sequences_identical(a.spec_emitted, b.spec_emitted),
        "identical streams file identical emissions",
    )
    for i in range(8):
        expect_eq(
            a.segment_end_rows[i], b.segment_end_rows[i], "same growth"
        )
    print("PASS: determinism -- identical streams, identical reports")


def main() raises:
    test_stream_table()
    test_plain_and_drafts()
    test_sampling_band()
    test_single_segment()
    test_long_session_drift()
    test_long_session_leakage()
    test_long_session_memory()
    test_long_session_controllers()
    test_hostile_segment_disable()
    test_fixed_hot_segment()
    test_segment_boundary_isolation()
    test_refusals_leave_state_untouched()
    test_determinism()
    print("ALL PASS: long session stability (13 groups)")
