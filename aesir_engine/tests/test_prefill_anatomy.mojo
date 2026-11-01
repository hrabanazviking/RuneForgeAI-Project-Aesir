"""Prefill anatomy accounting (J-053): pass plans per surface at
the baseline lengths, KV bytes, causal pair counts, projection /
attention / LM-head MACs, weight-pass traffic, and the MoE mean
stream projection.

All model numbers are filed figures restated so the arithmetic is
checked against the road's own record: the dense GQA profiles
(core/dense_gqa_profile.mojo -- Llama 3 8B 32L/4096/q4096/kv1024/
ffn14336/vocab128256; Llama 3.2 3B 28L/3072/q3072/kv1024/ffn8192;
Qwen3 0.6B 28L/1024/q2048/kv1024/ffn3072), the Gemma 4 E2B profile
(core/gemma4_profile.mojo -- 35 layers, 20 shared-KV layers so 15
owning layers: 12 local at kv width 256, 3 global at kv width 512),
OLMoE (J-015: 16 layers, hidden 2048, 16/16 heads at head_dim 128,
so kv width 2048), and the J-030 streamed total (32,948,699,136 B
over 91 stepped tokens). No number here is a speed.
"""
from core.prefill_anatomy import (
    SURFACE_CUDA_TILE4,
    SURFACE_CUDA_WIDTH1,
    SURFACE_HOST_BATCHED,
    SURFACE_HOST_PER_TOKEN,
    SURFACE_MOE_WIDTH1,
    plan_prefill_passes,
    prefill_attention_macs,
    prefill_attention_pairs,
    prefill_kv_bytes,
    prefill_lm_head_macs,
    prefill_moe_mean_stream_bytes,
    prefill_projection_macs_per_token,
    prefill_weight_pass_bytes,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PrefillAnatomy "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def test_host_batched_plans() raises:
    # Cap 256 (the S-033 default): at the four baseline lengths the
    # host plan is pure chunks of 256 plus one final chunk.
    var p256 = plan_prefill_passes(SURFACE_HOST_BATCHED, 256, 256)
    expect_eq(p256.passes, 1, "host 256 passes")
    expect_eq(p256.pure_prefill_passes, 0, "host 256 pure")
    expect_eq(p256.final_pass_width, 256, "host 256 final width")
    var p1024 = plan_prefill_passes(SURFACE_HOST_BATCHED, 1024, 256)
    expect_eq(p1024.passes, 4, "host 1024 passes")
    expect_eq(p1024.pure_prefill_passes, 3, "host 1024 pure")
    var p4096 = plan_prefill_passes(SURFACE_HOST_BATCHED, 4096, 256)
    expect_eq(p4096.passes, 16, "host 4096 passes")
    var p8192 = plan_prefill_passes(SURFACE_HOST_BATCHED, 8192, 256)
    expect_eq(p8192.passes, 32, "host 8192 passes")
    expect_eq(p8192.lm_head_passes, 1, "host head passes")
    # The S-033 shape: a 213-token prompt is 7 passes at cap 32 and
    # a single pass at cap 256 -- the pass-count reading of its
    # measured 9-14% wall cut.
    var s32 = plan_prefill_passes(SURFACE_HOST_BATCHED, 213, 32)
    expect_eq(s32.passes, 7, "S-033 cap32 passes")
    expect_eq(s32.final_pass_width, 21, "S-033 cap32 final width")
    var s256 = plan_prefill_passes(SURFACE_HOST_BATCHED, 213, 256)
    expect_eq(s256.passes, 1, "S-033 cap256 passes")
    print("PASS: host batched plans at the baseline lengths + S-033 shape")


def test_width1_and_tile_plans() raises:
    var per = plan_prefill_passes(SURFACE_HOST_PER_TOKEN, 1024)
    expect_eq(per.passes, 1024, "per-token passes")
    expect_eq(per.pure_prefill_passes, 1023, "per-token pure")
    expect_eq(per.lm_head_passes, 1, "per-token head")
    var cuda1 = plan_prefill_passes(SURFACE_CUDA_WIDTH1, 1024)
    expect_eq(cuda1.passes, 1024, "cuda width1 passes")
    expect_eq(cuda1.lm_head_passes, 1, "cuda width1 head")
    # Tile-4: tiles while >= 4 tokens remain before the last, then
    # singles. 256 -> 63 tiles + 4 singles; 1024 -> 255 + 4;
    # the J-022 prompt length 67 -> 16 tiles + 3 singles.
    var t256 = plan_prefill_passes(SURFACE_CUDA_TILE4, 256)
    expect_eq(t256.passes, 67, "tile4 256 passes")
    var t1024 = plan_prefill_passes(SURFACE_CUDA_TILE4, 1024)
    expect_eq(t1024.passes, 259, "tile4 1024 passes")
    var t67 = plan_prefill_passes(SURFACE_CUDA_TILE4, 67)
    expect_eq(t67.passes, 19, "tile4 67 passes")
    expect_eq(t67.lm_head_passes, 1, "tile4 head")
    print("PASS: per-token, CUDA width-1, and CUDA tile-4 plans")


def test_moe_head_finding() raises:
    # The MoE session's step() pays the LM head on every token:
    # at 256 tokens that is 256 head passes against 1 everywhere
    # else, and zero passes count as pure prefill.
    var moe = plan_prefill_passes(SURFACE_MOE_WIDTH1, 256)
    expect_eq(moe.passes, 256, "moe passes")
    expect_eq(moe.pure_prefill_passes, 0, "moe pure")
    expect_eq(moe.lm_head_passes, 256, "moe head passes")
    # OLMoE head MACs at 256 tokens vs the same head paid once:
    # hidden 2048; vocab 50304 derived exactly from J-015's filed
    # output.weight size (84,510,720 B of Q6_K at 210/256 B per
    # element over hidden 2048).
    var moe_head = prefill_lm_head_macs(2048, 50304, moe.lm_head_passes)
    expect_eq(moe_head, 26373783552, "moe head MACs at 256")
    var once = prefill_lm_head_macs(2048, 50304, 1)
    expect_eq(once, 103022592, "head MACs paid once")
    print("PASS: MoE width-1 plan pins the per-token LM head finding")


def test_kv_bytes() raises:
    # Llama 3 8B: 32 layers x K+V x 1024 wide x f16 = 131,072 B/tok.
    expect_eq(prefill_kv_bytes(131072, 256), 33554432, "llama8b KV at 256")
    expect_eq(
        prefill_kv_bytes(131072, 8192), 1073741824, "llama8b KV at 8192"
    )
    # OLMoE coincidentally lands on the same figure by a different
    # shape: 16 layers x K+V x 2048 wide x f16.
    expect_eq(prefill_kv_bytes(131072, 1024), 134217728, "olmoe KV at 1024")
    # Gemma 4 E2B: 15 owning layers (12 local x 256 + 3 global x
    # 512 kv width) x K+V x f16 = 18,432 B/token.
    expect_eq(prefill_kv_bytes(18432, 8192), 150994944, "gemma e2b KV at 8192")
    print("PASS: KV bytes written per prompt, per profile shape")


def test_attention_pairs_and_macs() raises:
    expect_eq(prefill_attention_pairs(256), 32896, "pairs at 256")
    expect_eq(prefill_attention_pairs(8192), 33558528, "pairs at 8192")
    # Sliding window 512 (Gemma 4 local layers) at 8,192 tokens.
    expect_eq(
        prefill_attention_pairs(8192, 512), 4063488, "windowed pairs at 8192"
    )
    expect_eq(
        prefill_attention_pairs(256, 512), 32896, "window above length is full"
    )
    # Llama 3 8B attention MACs at 256: 32 layers x 32,896 pairs x
    # q width 4096 x 2.
    expect_eq(
        prefill_attention_macs(32, 4096, 256), 8623489024, "llama8b attn MACs"
    )
    print("PASS: causal pair counts (full + windowed) and attention MACs")


def test_projection_macs() raises:
    # Llama 3.2 3B per token: (2*3072*3072 + 2*3072*1024 +
    # 3*3072*8192) x 28 layers.
    expect_eq(
        prefill_projection_macs_per_token(28, 3072, 3072, 1024, 8192),
        2818572288,
        "llama 3B projection MACs per token",
    )
    # Llama 3 8B per token.
    expect_eq(
        prefill_projection_macs_per_token(32, 4096, 4096, 1024, 14336),
        6979321856,
        "llama 8B projection MACs per token",
    )
    # Qwen3 0.6B per token.
    expect_eq(
        prefill_projection_macs_per_token(28, 1024, 2048, 1024, 3072),
        440401920,
        "qwen3 0.6B projection MACs per token",
    )
    print("PASS: dense projection + FFN MACs per token, per profile")


def test_weight_pass_and_stream_projection() raises:
    # Weight traffic shape scales with passes: the host 8,192 plan
    # (32 passes) re-reads the weight blocks 32 times where the
    # per-token plan does so 8,192 times, at any stated figure.
    expect_eq(
        prefill_weight_pass_bytes(32, 1000000), 32000000, "batched weight passes"
    )
    expect_eq(
        prefill_weight_pass_bytes(8192, 1000000),
        8192000000,
        "per-token weight passes",
    )
    # MoE mean stream projection at the J-030 rate: 67 prompt
    # tokens project to 24,258,932,330 B; 256 to 92,690,845,921 B.
    expect_eq(
        prefill_moe_mean_stream_bytes(67, 32948699136, 91),
        24258932330,
        "moe stream projection at 67",
    )
    expect_eq(
        prefill_moe_mean_stream_bytes(256, 32948699136, 91),
        92690845921,
        "moe stream projection at 256",
    )
    print("PASS: weight-pass traffic shape + MoE mean stream projection")


def test_refusals() raises:
    var refused = 0
    try:
        _ = plan_prefill_passes(SURFACE_HOST_BATCHED, 256, 1)
    except:
        refused += 1
    try:
        _ = plan_prefill_passes(SURFACE_HOST_BATCHED, 0, 256)
    except:
        refused += 1
    try:
        _ = plan_prefill_passes(99, 256)
    except:
        refused += 1
    try:
        _ = prefill_attention_pairs(256, -1)
    except:
        refused += 1
    try:
        _ = prefill_projection_macs_per_token(0, 3072, 3072, 1024, 8192)
    except:
        refused += 1
    try:
        _ = prefill_moe_mean_stream_bytes(256, 32948699136, 0)
    except:
        refused += 1
    expect_eq(refused, 6, "refusal count")
    print("PASS: refusals -- cap, token count, surface, window, shape, rate")


def main() raises:
    test_host_batched_plans()
    test_width1_and_tile_plans()
    test_moe_head_finding()
    test_kv_bytes()
    test_attention_pairs_and_macs()
    test_projection_macs()
    test_weight_pass_and_stream_projection()
    test_refusals()
    print("ALL PASS: prefill anatomy accounting (8 groups)")
