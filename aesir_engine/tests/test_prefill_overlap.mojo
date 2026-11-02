"""Prefill/decode overlap plan (J-057): exact pipeline
arithmetic under both schedules, the min(prep, compute)
bound per boundary, the nothing-to-hide and single-chunk
verdicts, the ragged final chunk, the filed Llama 3 8B
application with its exchange-rate sensitivity sweep, the
margin thresholds, the prefill-to-decode boundary, refusals.

Filed shapes restated from the record: Llama 3 8B projection
MACs 6,979,321,856 per token (J-053 section 5; attention
excluded, which understates compute and so overstates the
hidden fraction -- the conservative direction for the
rejection graded here); host chunk width 256 (J-053). The
filed application's movable figure is the token-slice
staging count: 256 ids per boundary at one operation per id
(parity), swept to 10,000 operations per id in the same
group. No speed anywhere.
"""
from core.prefill_overlap import (
    OVERLAP_NO_BOUNDARY,
    OVERLAP_REJECTED_BELOW_MARGIN,
    OVERLAP_REJECTED_NOTHING_TO_HIDE,
    OVERLAP_SURVIVES,
    evaluate_overlap_accounting,
    overlap_staging_bytes,
    plan_decode_boundary,
    plan_prefill_overlap,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PrefillOverlap " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("PrefillOverlap " + what + ": expected true")


def test_pipeline_arithmetic_exact() raises:
    # 16 tokens at width 4, compute 10/token, movable prep 15
    # and unmovable 5 per chunk: chunk 0's prep is fill
    # (exposed), boundaries 1..3 each hide min(15, 40) = 15.
    var p = plan_prefill_overlap(16, 4, 10, 15, 5)
    expect_eq(p.chunks, 4, "chunks")
    expect_eq(p.final_chunk_width, 4, "final width")
    expect_eq(p.boundaries, 3, "boundaries")
    expect_eq(p.full_chunk_compute, 40, "full chunk compute")
    expect_eq(p.compute_total, 160, "compute total")
    expect_eq(p.prep_total, 80, "prep total")
    expect_eq(p.hidden_per_boundary, 15, "hidden per boundary")
    expect_eq(p.hidden_total, 45, "hidden total")
    expect_eq(p.sequential_total, 240, "sequential total")
    expect_eq(p.overlapped_total, 195, "overlapped total")
    expect_eq(p.sequential_stall, 80, "sequential stall is all prep")
    expect_eq(p.overlapped_stall, 35, "exposed: fill 20 + unmovable 15")
    expect_eq(p.hidden_basis_points, 1875, "hidden share")
    print("PASS: pipeline arithmetic -- both schedules exact, fill exposed")


def test_hidden_capped_by_compute() raises:
    # Prep longer than compute: the boundary hides only the
    # compute it runs behind; the rest stays exposed. This is
    # the min(prep, compute) bound, pinned.
    var p = plan_prefill_overlap(16, 4, 10, 50, 0)
    expect_eq(p.hidden_per_boundary, 40, "hidden capped at full compute")
    expect_eq(p.hidden_total, 120, "hidden total capped")
    expect_eq(p.sequential_total, 360, "sequential total")
    expect_eq(p.overlapped_total, 240, "overlapped total")
    expect_eq(p.overlapped_stall, 80, "residual stall 10/boundary + fill 50")
    print("PASS: min bound -- hidden per boundary is min(prep, compute)")


def test_nothing_to_hide() raises:
    # Movable prep zero (the doc's graded position for the
    # surfaces that exist tonight): the schedules coincide
    # and the verdict names why.
    var p = plan_prefill_overlap(1024, 256, 1000, 0, 7)
    expect_eq(p.hidden_total, 0, "nothing hidden")
    expect_eq(p.overlapped_total, p.sequential_total, "schedules coincide")
    expect_eq(p.hidden_basis_points, 0, "hidden share zero")
    var v = evaluate_overlap_accounting(p)
    expect_eq(v.verdict, OVERLAP_REJECTED_NOTHING_TO_HIDE, "verdict")
    if v.verdict_name() != String("rejected_nothing_to_hide"):
        raise Error("PrefillOverlap verdict name: expected nothing to hide")
    print("PASS: nothing to hide -- schedules coincide, verdict named")


def test_single_chunk_no_boundary() raises:
    # A 256-token prompt at width 256 is one chunk: no
    # internal boundary exists however large the prep is.
    var p = plan_prefill_overlap(256, 256, 1000, 500, 0)
    expect_eq(p.chunks, 1, "one chunk")
    expect_eq(p.boundaries, 0, "no boundaries")
    expect_eq(p.hidden_total, 0, "nothing can hide")
    var v = evaluate_overlap_accounting(p)
    expect_eq(v.verdict, OVERLAP_NO_BOUNDARY, "verdict")
    if v.verdict_name() != String("no_boundary_single_chunk"):
        raise Error("PrefillOverlap verdict name: expected no boundary")
    print("PASS: single chunk -- no boundary, no hiding, verdict named")


def test_ragged_final_chunk() raises:
    # 67 tokens at width 4: 17 chunks, final width 3; compute
    # conserves per-token exactly, and every boundary hides
    # behind a FULL chunk (only the final chunk is ragged,
    # and nothing inside the prompt follows it).
    var p = plan_prefill_overlap(67, 4, 10, 15, 0)
    expect_eq(p.chunks, 17, "ceil chunks")
    expect_eq(p.final_chunk_width, 3, "final width")
    expect_eq(p.compute_total, 670, "compute conserves per-token")
    expect_eq(p.hidden_total, 240, "16 boundaries x 15")
    expect_eq(p.sequential_total, 925, "sequential total")
    expect_eq(p.overlapped_total, 685, "overlapped total")
    expect_eq(p.hidden_basis_points, 2594, "hidden share")
    print("PASS: ragged final chunk -- compute conserves, hiding exact")


def test_filed_llama_application() raises:
    # Llama 3 8B, 1,024 tokens at width 256, projection MACs
    # per token from J-053. Movable prep = the token-slice
    # staging count, 256 ids per boundary: at PARITY cost
    # (1 op per staged id against 1 MAC) and at 10,000 ops
    # per id -- a four-order-of-magnitude sensitivity sweep
    # -- the hidden share floors to 0 basis points either
    # way: the filed verdict does not rest on an exchange
    # rate. Attention MACs are excluded from compute, which
    # only overstates the share further.
    expect_eq(overlap_staging_bytes(256, 8), 2048, "staging bytes at width 256")
    var p = plan_prefill_overlap(1024, 256, 6979321856, 256, 0)
    expect_eq(p.compute_total, 7146825580544, "llama compute total")
    expect_eq(p.full_chunk_compute, 1786706395136, "llama chunk compute")
    expect_eq(p.hidden_total, 768, "hidden at parity")
    expect_eq(p.hidden_basis_points, 0, "hidden share floors to 0 bp")
    var v = evaluate_overlap_accounting(p)
    expect_eq(v.verdict, OVERLAP_REJECTED_BELOW_MARGIN, "parity verdict")
    var s = plan_prefill_overlap(1024, 256, 6979321856, 2560000, 0)
    expect_eq(s.hidden_total, 7680000, "hidden at 10000x")
    expect_eq(s.hidden_basis_points, 0, "hidden share still 0 bp at 10000x")
    var vs = evaluate_overlap_accounting(s)
    expect_eq(vs.verdict, OVERLAP_REJECTED_BELOW_MARGIN, "sweep verdict")
    print("PASS: filed Llama 3 8B -- hidden share 0 bp at parity and 10000x")


def test_margin_thresholds() raises:
    # The same rule, both sides of the 10% margin, on
    # synthetic units: a prep-heavy pipeline survives
    # accounting; a prep-light one is rejected below margin
    # (it is not nothing-to-hide -- prep exists, it is
    # simply not worth machinery).
    var hot = plan_prefill_overlap(64, 16, 100, 1500, 0)
    expect_eq(hot.hidden_basis_points, 3629, "hot hidden share")
    var vh = evaluate_overlap_accounting(hot)
    expect_eq(vh.verdict, OVERLAP_SURVIVES, "hot verdict survives")
    if vh.verdict_name() != String("survives_accounting"):
        raise Error("PrefillOverlap verdict name: expected survives")
    var cold = plan_prefill_overlap(64, 16, 100, 10, 0)
    expect_eq(cold.hidden_basis_points, 46, "cold hidden share")
    var vc = evaluate_overlap_accounting(cold)
    expect_eq(vc.verdict, OVERLAP_REJECTED_BELOW_MARGIN, "cold verdict")
    if vc.verdict_name() != String("rejected_below_margin"):
        raise Error("PrefillOverlap verdict name: expected below margin")
    print("PASS: margin thresholds -- survives above 10%, rejected below")


def test_decode_boundary() raises:
    # The one boundary after the prompt: final-chunk compute
    # 256,000 units hides movable decode prep up to itself;
    # the sampled-token input (in the unmovable bucket) is
    # exposed in both schedules; the share is graded against
    # the whole prompt total, not the chunk.
    var d = plan_decode_boundary(256, 1000, 2000, 500, 1000000)
    expect_eq(d.final_chunk_compute, 256000, "final chunk compute")
    expect_eq(d.hidden, 2000, "decode hidden")
    expect_eq(d.sequential_stall, 2500, "decode sequential stall")
    expect_eq(d.overlapped_stall, 500, "only unmovable stays exposed")
    expect_eq(d.hidden_basis_points, 20, "share at prompt scale")
    var big = plan_decode_boundary(256, 1000, 300000, 500, 1000000)
    expect_eq(big.hidden, 256000, "decode hidden capped at final compute")
    expect_eq(big.overlapped_stall, 44500, "residual decode stall")
    print("PASS: decode boundary -- hidden capped, graded at prompt scale")


def test_refusals() raises:
    var refused = 0
    try:
        _ = plan_prefill_overlap(0, 256, 1000, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_prefill_overlap(256, 0, 1000, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_prefill_overlap(256, 256, 0, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_prefill_overlap(256, 256, 1000, -1, 0)
    except:
        refused += 1
    try:
        _ = plan_prefill_overlap(256, 256, 1000, 0, -1)
    except:
        refused += 1
    try:
        _ = overlap_staging_bytes(0, 8)
    except:
        refused += 1
    try:
        _ = overlap_staging_bytes(256, 0)
    except:
        refused += 1
    try:
        _ = plan_decode_boundary(0, 1000, 0, 0, 1000000)
    except:
        refused += 1
    try:
        _ = plan_decode_boundary(256, 1000, -1, 0, 1000000)
    except:
        refused += 1
    try:
        _ = plan_decode_boundary(256, 1000, 0, 0, 0)
    except:
        refused += 1
    expect_eq(refused, 10, "refusal count")
    print("PASS: refusals -- shapes, compute, negative prep, decode inputs")


def main() raises:
    test_pipeline_arithmetic_exact()
    test_hidden_capped_by_compute()
    test_nothing_to_hide()
    test_single_chunk_no_boundary()
    test_ragged_final_chunk()
    test_filed_llama_application()
    test_margin_thresholds()
    test_decode_boundary()
    test_refusals()
    print("ALL PASS: prefill overlap plan (9 groups)")
