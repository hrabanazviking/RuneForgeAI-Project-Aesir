"""Long-prompt watching (J-059): the pre-registered
reporting discipline applied to the filed shapes -- the
earn/silence bounds, boundary-only emission, the 10%
step throttle at the host cap, at width 1 and at tile
width 4, the ragged final chunk, monotonicity and the
never-report-unread invariant, the final record exactly
once, the O2 timestamp carriage, both render forms, and
refusals.

Filed shapes restated from the record: the host chunk cap
is 256 by default (J-053, _prefill_batch_cap); J-053's
baseline lengths are 256 / 1024 / 4096 / 8192 tokens; the
CUDA sessions read at width 1 with width-4 tiles on the
one admitted Llama 3.2 3B profile; the MoE session reads
at width 1. No speed anywhere -- the discipline grades
counts only.
"""
from core.prompt_progress import (
    PROGRESS_MIN_CHUNKS,
    PROGRESS_MIN_TOKENS,
    plan_prompt_progress,
    progress_record,
    render_progress_event,
    render_progress_line,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PromptProgress " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("PromptProgress " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("PromptProgress " + what + ": expected false")


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "PromptProgress " + what + ": expected '" + expected
            + "', got '" + actual + "'"
        )


def test_silence_bounds() raises:
    # R1: below either bound the read is silent, at every
    # boundary including the final one.
    expect_eq(PROGRESS_MIN_TOKENS, 1024, "min tokens constant")
    expect_eq(PROGRESS_MIN_CHUNKS, 4, "min chunks constant")
    var short = plan_prompt_progress(256, 256)
    expect_eq(short.chunks, 1, "256/256 chunks")
    expect_false(short.watched, "256-token read unwatched")
    expect_eq(short.records_expected, 0, "256-token records")
    expect_false(progress_record(short, 1).emit, "short final boundary silent")
    var under_tokens = plan_prompt_progress(1023, 256)
    expect_eq(under_tokens.chunks, 4, "1023/256 chunks")
    expect_false(under_tokens.watched, "1023 tokens unwatched despite 4 chunks")
    expect_eq(under_tokens.records_expected, 0, "1023-token records")
    var under_chunks = plan_prompt_progress(4096, 8192)
    expect_eq(under_chunks.chunks, 1, "4096 in one wide chunk")
    expect_false(under_chunks.watched, "single-chunk long read unwatched")
    expect_eq(under_chunks.records_expected, 0, "single-chunk records")
    print("PASS: silence bounds -- token bound and chunk bound both bind")


def test_host_1024() raises:
    # The smallest watched host read: 1024 tokens at the
    # 256 cap. Every boundary crosses a 10% step, so all
    # four boundaries emit, the last exactly once as final.
    var plan = plan_prompt_progress(1024, 256)
    expect_eq(plan.chunks, 4, "chunks")
    expect_eq(plan.final_chunk_width, 256, "final width")
    expect_true(plan.watched, "watched")
    expect_eq(plan.records_expected, 4, "records")
    var dones = List[Int]()
    dones.append(256)
    dones.append(512)
    dones.append(768)
    dones.append(1024)
    var pcts = List[Int]()
    pcts.append(25)
    pcts.append(50)
    pcts.append(75)
    pcts.append(100)
    for k in range(1, 5):
        var r = progress_record(plan, k)
        expect_true(r.emit, "boundary emits")
        expect_eq(r.tokens_done, dones[k - 1], "tokens done")
        expect_eq(r.percent, pcts[k - 1], "percent")
        expect_eq(r.chunk_index, k, "chunk index")
        expect_eq(r.chunk_count, 4, "chunk count")
        expect_true(r.is_final == (k == 4), "final only at k=4")
    print("PASS: host 1024/256 -- four boundaries, four records, final once")


def test_host_4096_throttle() raises:
    # At 4096/256 the step throttle bites: boundary 1
    # (6.25%) emits nothing; the emitting boundaries are
    # exactly 2,4,5,7,8,10,12,13,15,16 -- ten records.
    var plan = plan_prompt_progress(4096, 256)
    expect_eq(plan.chunks, 16, "chunks")
    expect_true(plan.watched, "watched")
    expect_eq(plan.records_expected, 10, "records")
    var emitting = List[Int]()
    emitting.append(2)
    emitting.append(4)
    emitting.append(5)
    emitting.append(7)
    emitting.append(8)
    emitting.append(10)
    emitting.append(12)
    emitting.append(13)
    emitting.append(15)
    emitting.append(16)
    var seen = 0
    for k in range(1, 17):
        var r = progress_record(plan, k)
        if r.emit:
            expect_eq(k, emitting[seen], "emitting boundary")
            seen += 1
        if k == 2:
            expect_eq(r.tokens_done, 512, "boundary 2 done")
            expect_eq(r.percent, 12, "boundary 2 percent floored")
    expect_eq(seen, 10, "emitted count")
    print("PASS: host 4096/256 -- step throttle, exactly the 10 filed boundaries")


def test_width1_no_spam() raises:
    # Width 1 (CUDA width-1 loops, MoE step loop): 4096
    # boundaries, still exactly 10 records -- the step,
    # not the width, is the throttle (R3).
    var plan = plan_prompt_progress(4096, 1)
    expect_eq(plan.chunks, 4096, "chunks")
    expect_eq(plan.records_expected, 10, "records at width 1")
    var seen = 0
    var last_emit = 0
    for k in range(1, 4097):
        if progress_record(plan, k).emit:
            seen += 1
            last_emit = k
    expect_eq(seen, 10, "emitted count at width 1")
    expect_eq(last_emit, 4096, "last emission is the final boundary")
    print("PASS: width 1 -- 4096 boundaries, 10 records, no per-token spam")


def test_tile4() raises:
    # The admitted CUDA tile: 1024 tokens at width 4 is
    # 256 boundaries; the discipline emits 10 records.
    var plan = plan_prompt_progress(1024, 4)
    expect_eq(plan.chunks, 256, "tile chunks")
    expect_true(plan.watched, "tile read watched")
    expect_eq(plan.records_expected, 10, "tile records")
    print("PASS: tile width 4 -- 256 boundaries, 10 records")


def test_ragged_final_chunk() raises:
    # 1025 tokens at cap 256: the final chunk is 1 token
    # wide. Its boundary reports 1025 done -- never the
    # padded 1280 -- and only it is final.
    var plan = plan_prompt_progress(1025, 256)
    expect_eq(plan.chunks, 5, "chunks")
    expect_eq(plan.final_chunk_width, 1, "ragged final width")
    expect_eq(plan.records_expected, 5, "records")
    var r4 = progress_record(plan, 4)
    expect_eq(r4.tokens_done, 1024, "boundary 4 done")
    expect_eq(r4.percent, 99, "boundary 4 percent")
    expect_true(r4.emit, "boundary 4 crosses the 90% step")
    expect_false(r4.is_final, "boundary 4 not final")
    var r5 = progress_record(plan, 5)
    expect_eq(r5.tokens_done, 1025, "final done is the true total")
    expect_eq(r5.fraction_basis_points, 10000, "final fraction exact")
    expect_true(r5.is_final, "boundary 5 final")
    print("PASS: ragged final chunk -- true totals, never padded, final exact")


def test_monotonic_never_unread() raises:
    # R2/R5 across a whole watched read: done strictly
    # increases, never exceeds the total, emitted
    # fractions strictly increase, and exactly one record
    # in the read is final.
    var plan = plan_prompt_progress(4096, 256)
    var prev_done = 0
    var prev_emitted_bp = -1
    var finals = 0
    for k in range(1, 17):
        var r = progress_record(plan, k)
        expect_true(r.tokens_done > prev_done, "done strictly increases")
        expect_true(r.tokens_done <= 4096, "never reports unread tokens")
        prev_done = r.tokens_done
        if r.emit:
            expect_true(
                r.fraction_basis_points > prev_emitted_bp,
                "emitted fractions strictly increase",
            )
            prev_emitted_bp = r.fraction_basis_points
        if r.is_final:
            finals += 1
            expect_eq(r.tokens_done, 4096, "final done")
            expect_eq(r.fraction_basis_points, 10000, "final bp")
    expect_eq(finals, 1, "exactly one final record")
    print("PASS: monotonic -- done and emitted fractions rise, final once")


def test_timestamp_and_renders() raises:
    # O2 carriage + both render forms, exact strings.
    var plan = plan_prompt_progress(1024, 256)
    var r1 = progress_record(plan, 1)
    expect_eq(r1.elapsed_ms, -1, "timestamp unstated by default")
    expect_str(
        render_progress_line(r1),
        String("prompt read: 256/1024 tokens (25%) chunk 1/4"),
        "CLI line",
    )
    expect_str(
        render_progress_event(r1),
        String(
            '{"event":"prefill_progress","tokens_done":256,'
            '"prompt_tokens":1024,"percent":25,"chunk":1,'
            '"chunks":4,"done":false}'
        ),
        "server event",
    )
    var r4 = progress_record(plan, 4, 42000)
    expect_eq(r4.elapsed_ms, 42000, "timestamp carried")
    expect_str(
        render_progress_line(r4),
        String(
            "prompt read: 1024/1024 tokens (100%) chunk 4/4"
            " -- read complete -- 42000 ms"
        ),
        "CLI final line with timestamp",
    )
    expect_str(
        render_progress_event(r4),
        String(
            '{"event":"prefill_progress","tokens_done":1024,'
            '"prompt_tokens":1024,"percent":100,"chunk":4,'
            '"chunks":4,"done":true,"elapsed_ms":42000}'
        ),
        "server final event with timestamp",
    )
    print("PASS: O2 timestamp carriage -- both render forms exact")


def test_baseline_lengths() raises:
    # J-053's baseline lengths at the host cap, plus the
    # MoE width-1 row at 1024: the discipline's record
    # counts on the road's own table.
    expect_eq(plan_prompt_progress(256, 256).records_expected, 0, "256 silent")
    expect_eq(plan_prompt_progress(1024, 256).records_expected, 4, "1024 host")
    expect_eq(plan_prompt_progress(4096, 256).records_expected, 10, "4096 host")
    expect_eq(plan_prompt_progress(8192, 256).records_expected, 10, "8192 host")
    expect_eq(plan_prompt_progress(8192, 256).chunks, 32, "8192 chunks")
    expect_eq(plan_prompt_progress(1024, 1).records_expected, 10, "1024 MoE width 1")
    print("PASS: baseline lengths -- 0 / 4 / 10 / 10 on the road's own table")


def test_refusals() raises:
    var refused = 0
    try:
        _ = plan_prompt_progress(0, 256)
    except:
        refused += 1
    try:
        _ = plan_prompt_progress(1024, 0)
    except:
        refused += 1
    try:
        _ = plan_prompt_progress(-5, 256)
    except:
        refused += 1
    var plan = plan_prompt_progress(1024, 256)
    try:
        _ = progress_record(plan, 0)
    except:
        refused += 1
    try:
        _ = progress_record(plan, 5)
    except:
        refused += 1
    try:
        _ = progress_record(plan, 1, -2)
    except:
        refused += 1
    expect_eq(refused, 6, "refusal count")
    print("PASS: refusals -- shapes, boundaries outside the read, timestamps")


def main() raises:
    test_silence_bounds()
    test_host_1024()
    test_host_4096_throttle()
    test_width1_no_spam()
    test_tile4()
    test_ragged_final_chunk()
    test_monotonic_never_unread()
    test_timestamp_and_renders()
    test_baseline_lengths()
    test_refusals()
    print("ALL PASS: prompt progress account (10 groups)")
