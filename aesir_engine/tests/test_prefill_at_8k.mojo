"""Prefill at 8k account (J-068): the 8,192-token row composed
from J-053's accounting, per-arch attention shares, context
verdicts at the cap, and the MoE head-waste account (F1).

All figures are the road's filed figures restated so the
arithmetic is checked: dense GQA profiles (Llama 3 8B
32L/4096/q4096/kv131072B-per-token/proj 6,979,321,856 per token/
head 525,336,576; Qwen3 0.6B proj 440,401,920 per token), OLMoE
(16L, q width 2048, kv 131,072 B/token, routed proj 1,075,838,976
per token, head 103,022,592 per pass), Gemma 4 E2B hybrid totals
from J-053 section 5 (proj total 10,146,860,236,800; hybrid
attention total 2,390,413,541,376). No number here is a speed.
"""
from core.prefill_anatomy import (
    SURFACE_CUDA_TILE4,
    SURFACE_CUDA_WIDTH1,
    SURFACE_HOST_BATCHED,
    SURFACE_MOE_WIDTH1,
)
from core.prefill_at_8k import (
    CTX_FITS,
    CTX_NO_GENERATION_ROOM,
    CTX_REFUSED,
    EIGHT_K_TOKENS,
    attention_dominates,
    attention_share_bp,
    context_verdict,
    context_verdict_name,
    head_waste_macs,
    plan_8k_row,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PrefillAt8k " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def test_host_batched_llama8b_row() raises:
    var r = plan_8k_row(
        SURFACE_HOST_BATCHED, 256, 32, 4096, 131072, 6979321856, 525336576
    )
    expect_eq(r.passes, 32, "host passes")
    expect_eq(r.pure_prefill_passes, 31, "host pure")
    expect_eq(r.lm_head_passes, 1, "host head")
    expect_eq(r.kv_bytes_written, 1073741824, "kv at 8k")
    expect_eq(r.causal_pairs_per_layer, 33558528, "pairs at 8k")
    expect_eq(r.attention_macs, 8797166764032, "attn macs")
    expect_eq(r.projection_macs_total, 57174604644352, "proj total")
    expect_eq(r.attention_share_bp, 1333, "attn share bp")
    expect_eq(r.head_waste_macs, 0, "host head waste")
    print("PASS: host batched Llama 3 8B row at 8192 (share 1333 bp)")


def test_width1_and_tile4_rows() raises:
    var w = plan_8k_row(
        SURFACE_CUDA_WIDTH1, 256, 32, 4096, 131072, 6979321856, 525336576
    )
    expect_eq(w.passes, 8192, "width1 passes")
    expect_eq(w.pure_prefill_passes, 8191, "width1 pure")
    expect_eq(w.lm_head_passes, 1, "width1 head")
    var t = plan_8k_row(
        SURFACE_CUDA_TILE4, 256, 28, 3072, 131072, 2818572288, 394002432
    )
    expect_eq(t.passes, 2051, "tile4 passes")
    expect_eq(t.attention_share_bp, 2000, "3B attn share bp")
    print("PASS: width-1 passes 8192, tile-4 passes 2051 at 8192")


def test_moe_width1_row_and_head_waste() raises:
    var r = plan_8k_row(
        SURFACE_MOE_WIDTH1, 256, 16, 2048, 131072, 1075838976, 103022592
    )
    expect_eq(r.passes, 8192, "moe passes")
    expect_eq(r.pure_prefill_passes, 0, "moe pure")
    expect_eq(r.lm_head_passes, 8192, "moe head passes")
    expect_eq(r.head_waste_macs, 843858051072, "moe head waste")
    expect_eq(r.kv_bytes_written, 1073741824, "moe kv")
    expect_eq(r.attention_macs, 2199291691008, "moe attn")
    expect_eq(r.attention_share_bp, 1997, "moe share bp")
    expect_eq(head_waste_macs(103022592, 1), 0, "chunk-form waste")
    print("PASS: MoE width-1 row at 8192; F1 head waste exact; chunk form zero")


def test_attention_share_per_arch() raises:
    # Qwen3 0.6B is the one filed profile whose attention share
    # crosses half at 8k; the others do not -- per-arch arithmetic.
    expect_eq(attention_share_bp(3607772528640, 3848760459264), 5161, "qwen06")
    expect_eq(attention_share_bp(10146860236800, 2390413541376), 1906, "e2b")
    expect_eq(attention_share_bp(53455162966016, 6735330803712), 1119, "coder")
    if not attention_dominates(3607772528640, 3848760459264):
        raise Error("PrefillAt8k: Qwen3 0.6B attention must dominate at 8k")
    if attention_dominates(57174604644352, 8797166764032):
        raise Error("PrefillAt8k: Llama 3 8B attention must not dominate at 8k")
    print("PASS: attention shares per arch at 8192; dominance is per-arch")


def test_windowed_pairs_row() raises:
    # Gemma 4 local-layer class: window 512 caps the pairs.
    var r = plan_8k_row(
        SURFACE_HOST_BATCHED, 256, 28, 2048, 18432, 1238630400, 402653184, 512
    )
    expect_eq(r.causal_pairs_per_layer, 4063488, "windowed pairs")
    print("PASS: sliding-window pairs at 8192 = 4,063,488 per layer")


def test_context_verdicts() raises:
    expect_eq(context_verdict(8192, 4096, 0), CTX_REFUSED, "olmoe cap")
    expect_eq(context_verdict(8192, 8192, 24), CTX_NO_GENERATION_ROOM, "llama cap+gen")
    expect_eq(context_verdict(8192, 8192, 0), CTX_FITS, "llama exact fill")
    expect_eq(context_verdict(8168, 8192, 24), CTX_FITS, "llama with reserve")
    expect_eq(context_verdict(8192, 32768, 24), CTX_FITS, "qwen cap")
    if context_verdict_name(CTX_REFUSED) != String("refused_by_context"):
        raise Error("PrefillAt8k: refused name")
    print("PASS: context verdicts at 8192 (refused / no-room / fits)")


def test_refusals() raises:
    var refused = 0
    try:
        _ = attention_share_bp(0, 100)
    except:
        refused += 1
    try:
        _ = attention_share_bp(100, -1)
    except:
        refused += 1
    try:
        _ = context_verdict(0, 8192, 0)
    except:
        refused += 1
    try:
        _ = context_verdict(8192, 0, 0)
    except:
        refused += 1
    try:
        _ = head_waste_macs(0, 4)
    except:
        refused += 1
    try:
        _ = plan_8k_row(SURFACE_HOST_BATCHED, 256, 0, 4096, 131072, 100, 100)
    except:
        refused += 1
    try:
        _ = context_verdict_name(99)
    except:
        refused += 1
    expect_eq(refused, 7, "refusal count")
    expect_eq(EIGHT_K_TOKENS, 8192, "row length")
    print("PASS: invalid inputs refused (7/7)")


def main() raises:
    test_host_batched_llama8b_row()
    test_width1_and_tile4_rows()
    test_moe_width1_row_and_head_waste()
    test_attention_share_per_arch()
    test_windowed_pairs_row()
    test_context_verdicts()
    test_refusals()
    print("ALL PASS: prefill at 8k account (7 groups)")
