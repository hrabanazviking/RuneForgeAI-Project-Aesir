"""Whole-layer dense on GPU plan (J-055): fit with exact headroom,
the Stheno no-fit/fit pair on the filed J-021 figures, max-weights
inversion, sync counts at exactly layers x, the agreement basis
points on Janas's filed Gemma counts (census J-005, behaviour
only), staging pricing cross-checked against J-031's filed chunk
counts, the full-context KV charge, refusals.

Shapes restated from the record: purplelongship's 6 GiB card
usable budget 5,368,709,120 B (J-021/J-031); Stheno L3-8B
Q4_K_M tensor-byte total 4,912,898,048 B (J-021 section 3, file
4,920,734,240 B, sha256 8e98c195...fc4); Llama 3 8B KV
131,072 B/token and Gemma 4 E2B KV 18,432 B/token (J-053
section 5); J-031's OLMoE resident 311,027,712 B (5 staging
chunks) and expert body 3,900,702,720 B (59 chunks). No speed.
"""
from core.whole_layer_gpu import (
    VERDICT_NO_FIT_SPILL,
    VERDICT_WHOLE_FITS,
    agreement_basis_points,
    plan_whole_layer_fit,
    plan_whole_layer_syncs,
    whole_layer_max_weights,
    whole_layer_upload_chunks,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "WholeLayerGPU " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def test_fit_with_exact_headroom() raises:
    var p = plan_whole_layer_fit(1000000, 131072, 8, 1000, 2000, 3000, 3000000)
    expect_eq(p.kv_bytes, 1048576, "kv charge")
    expect_eq(p.required_bytes, 2054576, "required")
    expect_eq(p.headroom_bytes, 945424, "headroom")
    expect_eq(p.verdict, VERDICT_WHOLE_FITS, "verdict fits")
    expect_eq(p.upload_chunks, 1, "upload chunks")
    if p.verdict_name() != String("whole_fits"):
        raise Error("WholeLayerGPU verdict name: expected whole_fits")
    print("PASS: whole-layer fit with exact headroom, verdict named in-plan")


def test_stheno_no_fit_and_fit_pair() raises:
    # The J-021 shape on this module's arithmetic (weights = the
    # file's tensor-byte total; scratch/scores/reserve stated 0,
    # so this is a LOWER bound on the engine's own charge -- the
    # engine filed required 5,459,657,764 B at context 4096,
    # shortfall 90,948,644 B; both accounts refuse at 4096 and
    # both fit at 2048, which is why J-021's comparator ran there).
    var p4096 = plan_whole_layer_fit(
        4912898048, 131072, 4096, 0, 0, 0, 5368709120
    )
    expect_eq(p4096.kv_bytes, 536870912, "stheno kv at 4096")
    expect_eq(p4096.required_bytes, 5449768960, "stheno required at 4096")
    expect_eq(p4096.headroom_bytes, -81059840, "stheno shortfall at 4096")
    expect_eq(p4096.verdict, VERDICT_NO_FIT_SPILL, "stheno verdict at 4096")
    if p4096.verdict_name() != String("no_fit_spill_is_the_fallback"):
        raise Error("WholeLayerGPU verdict name: expected spill fallback")
    var p2048 = plan_whole_layer_fit(
        4912898048, 131072, 2048, 0, 0, 0, 5368709120
    )
    expect_eq(p2048.required_bytes, 5181333504, "stheno required at 2048")
    expect_eq(p2048.headroom_bytes, 187375616, "stheno headroom at 2048")
    expect_eq(p2048.verdict, VERDICT_WHOLE_FITS, "stheno verdict at 2048")
    print("PASS: Stheno pair -- no-fit at 4096 (exact shortfall), fits at 2048")


def test_max_weights_inversion() raises:
    var m = whole_layer_max_weights(131072, 2048, 0, 0, 0, 5368709120)
    expect_eq(m, 5100273664, "max weights at 2048")
    # Inversion is exact: weights == max fits with headroom 0,
    # max + 1 does not fit.
    var at = plan_whole_layer_fit(m, 131072, 2048, 0, 0, 0, 5368709120)
    expect_eq(at.headroom_bytes, 0, "max weights headroom zero")
    expect_eq(at.verdict, VERDICT_WHOLE_FITS, "max weights fits")
    var over = plan_whole_layer_fit(m + 1, 131072, 2048, 0, 0, 0, 5368709120)
    expect_eq(over.verdict, VERDICT_NO_FIT_SPILL, "max weights + 1 refused")
    # Zero/negative is stated, not clamped: a context whose KV
    # alone exceeds the budget leaves a negative allowance.
    var neg = whole_layer_max_weights(131072, 8192, 0, 0, 0, 1000000000)
    expect_eq(neg, -73741824, "negative max weights stated")
    print("PASS: max-weights inversion exact; negative allowance stated, not clamped")


def test_sync_counts_exact_layers_ratio() raises:
    var s = plan_whole_layer_syncs(256, 256, 32)
    expect_eq(s.whole_width1_syncs, 256, "whole width1 syncs")
    expect_eq(s.whole_block_syncs, 1, "whole block syncs")
    expect_eq(s.per_layer_width1_syncs, 8192, "per-layer width1 syncs")
    expect_eq(s.per_layer_block_syncs, 32, "per-layer block syncs")
    expect_eq(
        s.per_layer_width1_syncs // s.whole_width1_syncs, 32, "ratio width1"
    )
    expect_eq(
        s.per_layer_block_syncs // s.whole_block_syncs, 32, "ratio block"
    )
    # Gemma E2B shape: 35 layers, 1,024 tokens at width 256.
    var g = plan_whole_layer_syncs(1024, 256, 35)
    expect_eq(g.whole_block_syncs, 4, "gemma block syncs")
    expect_eq(g.per_layer_block_syncs, 140, "gemma per-layer block syncs")
    # Non-divisible prompt: 67 tokens at width 4 -> 17 chunks.
    var t = plan_whole_layer_syncs(67, 4, 28)
    expect_eq(t.whole_block_syncs, 17, "ceil chunks at 67/4")
    expect_eq(t.per_layer_block_syncs, 476, "per-layer at 67/4")
    print("PASS: sync counts -- whole-layer vs per-layer ratio is exactly layers")


def test_agreement_basis_points() raises:
    # Janas's filed Gemma 4 whole-layer agreement counts vs
    # llama.cpp on 400 tokens (census J-005, behaviour only --
    # Janas's numbers on Janas's machine, restated here ONLY to
    # pin this module's counting arithmetic, never as Aesir's).
    expect_eq(agreement_basis_points(367, 400), 9175, "12B GPU 367/400")
    expect_eq(agreement_basis_points(362, 400), 9050, "12B CPU 362/400")
    expect_eq(agreement_basis_points(321, 400), 8025, "26B 321/400")
    expect_eq(agreement_basis_points(386, 400), 9650, "E2B GPU 386/400")
    expect_eq(agreement_basis_points(391, 400), 9775, "E2B CPU 391/400")
    expect_eq(agreement_basis_points(392, 400), 9800, "E4B GPU 392/400")
    expect_eq(agreement_basis_points(394, 400), 9850, "E4B CPU 394/400")
    expect_eq(agreement_basis_points(400, 400), 10000, "perfect agreement")
    expect_eq(agreement_basis_points(0, 400), 0, "zero agreement")
    # Floor, not rounding: 1/3 is 3333 bp, never 3334.
    expect_eq(agreement_basis_points(1, 3), 3333, "floor not rounding")
    print("PASS: agreement basis points on the filed Gemma counts (floor, exact)")


def test_staging_chunks_crosscheck() raises:
    expect_eq(whole_layer_upload_chunks(0), 0, "zero upload")
    expect_eq(whole_layer_upload_chunks(67108864), 1, "one staging chunk")
    expect_eq(whole_layer_upload_chunks(67108865), 2, "two staging chunks")
    # J-031's filed counts, reproduced: OLMoE resident -> 5, body -> 59.
    expect_eq(whole_layer_upload_chunks(311027712), 5, "J-031 resident chunks")
    expect_eq(whole_layer_upload_chunks(3900702720), 59, "J-031 body chunks")
    print("PASS: staging chunks reproduce J-031's filed 5 / 59")


def test_full_context_kv_charge() raises:
    # The KV charge is for the session's FULL context (prompt +
    # generation), not the prompt alone: Gemma E2B at context
    # 8,192 charges exactly J-053's filed KV-written figure.
    var p = plan_whole_layer_fit(1000000, 18432, 8192, 0, 0, 0, 5368709120)
    expect_eq(p.kv_bytes, 150994944, "gemma kv at full 8192 context")
    expect_eq(p.verdict, VERDICT_WHOLE_FITS, "gemma-shape fit verdict")
    print("PASS: KV charged for the full session context (J-053 figure exact)")


def test_refusals() raises:
    var refused = 0
    try:
        _ = plan_whole_layer_fit(0, 131072, 8, 0, 0, 0, 3000000)
    except:
        refused += 1
    try:
        _ = plan_whole_layer_fit(1000000, 0, 8, 0, 0, 0, 3000000)
    except:
        refused += 1
    try:
        _ = plan_whole_layer_fit(1000000, 131072, 0, 0, 0, 0, 3000000)
    except:
        refused += 1
    try:
        _ = plan_whole_layer_fit(1000000, 131072, 8, -1, 0, 0, 3000000)
    except:
        refused += 1
    try:
        _ = plan_whole_layer_fit(1000000, 131072, 8, 0, 0, 0, 0)
    except:
        refused += 1
    try:
        _ = whole_layer_max_weights(0, 2048, 0, 0, 0, 5368709120)
    except:
        refused += 1
    try:
        _ = whole_layer_max_weights(131072, 2048, 0, 0, -1, 5368709120)
    except:
        refused += 1
    try:
        _ = plan_whole_layer_syncs(0, 256, 32)
    except:
        refused += 1
    try:
        _ = plan_whole_layer_syncs(256, 0, 32)
    except:
        refused += 1
    try:
        _ = plan_whole_layer_syncs(256, 256, 0)
    except:
        refused += 1
    try:
        _ = agreement_basis_points(1, 0)
    except:
        refused += 1
    try:
        _ = agreement_basis_points(401, 400)
    except:
        refused += 1
    try:
        _ = agreement_basis_points(-1, 400)
    except:
        refused += 1
    try:
        _ = whole_layer_upload_chunks(-1)
    except:
        refused += 1
    expect_eq(refused, 14, "refusal count")
    print("PASS: refusals -- fit, max-weights, sync, agreement, upload inputs")


def main() raises:
    test_fit_with_exact_headroom()
    test_stheno_no_fit_and_fit_pair()
    test_max_weights_inversion()
    test_sync_counts_exact_layers_ratio()
    test_agreement_basis_points()
    test_staging_chunks_crosscheck()
    test_full_context_kv_charge()
    test_refusals()
    print("ALL PASS: whole-layer GPU plan (8 groups)")
