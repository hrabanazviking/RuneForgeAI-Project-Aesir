"""KV census account (J-087): the per-token KV prices of
every Aesir path pinned against the tree's own profile
constants -- dense GQA profiles at f16 (host + CUDA),
OLMoE at the file's kv_dim, Gemma 4's three host tiers
(allocated / written / useful) and its f32 CUDA shape
(fixed local rings + global marginal), the 16,000-token
host allocation cap, the J-088 8-bit projection, and the
mechanical claim verdict -- including the pin that
J-053's filed Llama 3.2 3B figure (131,072) MISMATCHES
its own profile (114,688). No device, no wall, no speed.
"""
from core.kv_account import (
    KV_CLAIM_MATCHES,
    KV_CLAIM_MISMATCH,
    KV_ELEM_F16,
    KV_ELEM_F32,
    KV_PRECISION_F16,
    KV_PRECISION_F32,
    KV_PRECISION_INT8_PROJECTED,
    claim_name,
    evaluate_kv_claim,
    gemma_cuda_fixed_bytes,
    gemma_cuda_marginal_per_token,
    gemma_cuda_total_bytes,
    gemma_global_owning_layers,
    gemma_host_allocated_per_token,
    gemma_host_useful_per_token,
    gemma_host_written_per_token,
    gemma_local_owning_layers,
    gemma_owning_layers,
    host_cache_context,
    kv_bytes_per_token,
    kv_bytes_per_token_width,
    kv_int8_projected_per_token,
    kv_total_bytes,
    precision_elem_bytes,
    precision_name,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "KVAccount " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def test_precision_codes() raises:
    expect_eq(precision_elem_bytes(KV_PRECISION_F16), 2, "f16 elem bytes")
    expect_eq(precision_elem_bytes(KV_PRECISION_F32), 4, "f32 elem bytes")
    expect_eq(precision_elem_bytes(KV_PRECISION_INT8_PROJECTED), 1, "int8 elem bytes")
    if precision_name(KV_PRECISION_F16) != String("f16"):
        raise Error("KVAccount: f16 name")
    if precision_name(KV_PRECISION_F32) != String("f32"):
        raise Error("KVAccount: f32 name")
    if precision_name(KV_PRECISION_INT8_PROJECTED) != String("int8-projected"):
        raise Error("KVAccount: int8 name")
    print("PASS: precision codes -- host/dense-CUDA KV is f16, Gemma 4 CUDA KV is f32, int8 is projection-only")


def test_dense_profiles_f16() raises:
    # dense_gqa_profile.mojo tuples, parsed by j087_inspect.py.
    expect_eq(kv_bytes_per_token(32, 8, 128, KV_ELEM_F16), 131072, "Llama 3 8B per-token")
    expect_eq(kv_bytes_per_token(28, 8, 128, KV_ELEM_F16), 114688, "Llama 3.2 3B / Qwen3 0.6B per-token")
    expect_eq(kv_bytes_per_token(28, 4, 128, KV_ELEM_F16), 57344, "Qwen2.5 Coder 7B per-token")
    print("PASS: dense GQA per-token KV at f16 -- 8B 131072; 3B and Qwen3-0.6B 114688; Coder 57344")


def test_totals_and_caps() raises:
    expect_eq(kv_total_bytes(131072, 8192), 1073741824, "8B total at its 8192 cap")
    expect_eq(kv_total_bytes(114688, 32768), 3758096384, "Qwen3 0.6B total at its 32768 cap")
    expect_eq(kv_total_bytes(57344, 4096), 234881024, "Coder total at 4096")
    expect_eq(host_cache_context(131072), 16000, "host allocation caps a 128k file at 16000")
    expect_eq(host_cache_context(4096), 4096, "host allocation takes a small file whole")
    expect_eq(kv_total_bytes(131072, host_cache_context(131072)), 2097152000, "8B host allocation at the runtime cap")
    print("PASS: totals close at the profile caps; the host allocates min(16000, file context), never the trained context")


def test_olmoe_width_form() raises:
    expect_eq(kv_bytes_per_token_width(16, 2048, KV_ELEM_F16), 131072, "OLMoE at kv_dim 2048")
    expect_eq(
        kv_bytes_per_token_width(16, 2048, KV_ELEM_F16),
        kv_bytes_per_token(16, 32, 64, KV_ELEM_F16),
        "width form == heads form",
    )
    expect_eq(kv_total_bytes(131072, 4096), 536870912, "OLMoE total at its 4096 file cap")
    print("PASS: OLMoE (MoE session, host KVCache) -- 131,072 B/token by the kv_dim form; 512 MiB at the file cap")


def test_gemma_e4b_host_tiers() raises:
    expect_eq(gemma_owning_layers(42, 18), 24, "E4B owning layers")
    expect_eq(gemma_local_owning_layers(42, 18, 6), 20, "E4B local owning")
    expect_eq(gemma_global_owning_layers(42, 18, 6), 4, "E4B global owning")
    expect_eq(gemma_host_allocated_per_token(42, 2, 512), 172032, "E4B allocated/token")
    expect_eq(gemma_host_written_per_token(42, 18, 2, 512), 98304, "E4B written/token (padded)")
    expect_eq(gemma_host_useful_per_token(42, 18, 6, 2, 512, 256), 57344, "E4B useful/token")
    print("PASS: Gemma 4 E4B host tiers -- allocated 172032 > written 98304 > useful 57344 B/token (shared slots + local padding priced)")


def test_gemma_e2b_host_tiers() raises:
    expect_eq(gemma_owning_layers(35, 20), 15, "E2B owning layers")
    expect_eq(gemma_local_owning_layers(35, 20, 5), 12, "E2B local owning")
    expect_eq(gemma_global_owning_layers(35, 20, 5), 3, "E2B global owning")
    expect_eq(gemma_host_allocated_per_token(35, 1, 512), 71680, "E2B allocated/token")
    expect_eq(gemma_host_written_per_token(35, 20, 1, 512), 30720, "E2B written/token (padded)")
    expect_eq(gemma_host_useful_per_token(35, 20, 5, 1, 512, 256), 18432, "E2B useful/token == J-053's figure")
    print("PASS: Gemma 4 E2B host tiers -- allocated 71680; written 30720; useful 18432 (the J-053 headline is the useful tier)")


def test_gemma_cuda_shape() raises:
    expect_eq(gemma_cuda_fixed_bytes(42, 18, 6, 2, 256), 41943040, "E4B CUDA local rings fixed")
    expect_eq(gemma_cuda_marginal_per_token(42, 18, 6, 2, 512), 32768, "E4B CUDA global marginal")
    expect_eq(gemma_cuda_total_bytes(41943040, 32768, 32768), 1115684864, "E4B CUDA total at cap 32768")
    expect_eq(gemma_cuda_fixed_bytes(35, 20, 5, 1, 256), 12582912, "E2B CUDA local rings fixed")
    expect_eq(gemma_cuda_marginal_per_token(35, 20, 5, 1, 512), 12288, "E2B CUDA global marginal")
    expect_eq(gemma_cuda_total_bytes(12582912, 12288, 16384), 213909504, "E2B CUDA total at cap 16384")
    # The f32 exception priced: the same owning shape at f16
    # would cost exactly half the marginal.
    expect_eq(kv_bytes_per_token(4, 2, 512, KV_ELEM_F32), 32768, "E4B global owning at f32")
    expect_eq(kv_bytes_per_token(4, 2, 512, KV_ELEM_F16), 16384, "E4B global owning at f16 (half)")
    print("PASS: Gemma 4 CUDA -- f32 rings fixed (E4B 41,943,040 / E2B 12,582,912) + global marginal (32,768 / 12,288 per token)")


def test_int8_projection() raises:
    var projected = kv_int8_projected_per_token(32, 8, 128, 4)
    expect_eq(projected, 67584, "Llama 3 8B int8 projection with f32 per-head-row scales")
    var today = kv_bytes_per_token(32, 8, 128, KV_ELEM_F16)
    if not (projected < today and projected > today // 2):
        raise Error("KVAccount: projection must land between half and whole of the f16 price")
    print("PASS: 8-bit projection (J-088's grading baseline) -- 67,584 B/token for the 8B shape with f32 scales, ratio 0.5156 not 0.5")


def test_claim_verdict() raises:
    expect_eq(evaluate_kv_claim(131072, 32, 8, 128, KV_ELEM_F16), KV_CLAIM_MATCHES, "true 8B claim matches")
    # The J-053 defect, pinned: its filed 3B figure against the
    # 3B profile's own shape must MISMATCH; the derived figure
    # must MATCH.
    expect_eq(evaluate_kv_claim(131072, 28, 8, 128, KV_ELEM_F16), KV_CLAIM_MISMATCH, "J-053's 3B figure mismatches its profile")
    expect_eq(evaluate_kv_claim(114688, 28, 8, 128, KV_ELEM_F16), KV_CLAIM_MATCHES, "derived 3B figure matches")
    expect_eq(evaluate_kv_claim(131072, 32, 8, 128, KV_ELEM_F32), KV_CLAIM_MISMATCH, "an f16 figure claimed at f32 mismatches")
    if claim_name(KV_CLAIM_MATCHES) != String("MATCHES"):
        raise Error("KVAccount: MATCHES name")
    if claim_name(KV_CLAIM_MISMATCH) != String("MISMATCH"):
        raise Error("KVAccount: MISMATCH name")
    print("PASS: claim verdict is mechanical -- and J-053's Llama 3.2 3B figure is pinned as a MISMATCH against its own profile")


def test_invalid_inputs_refused() raises:
    var refused = 0
    try:
        _ = kv_bytes_per_token(0, 8, 128, KV_ELEM_F16)
    except:
        refused += 1
    try:
        _ = kv_bytes_per_token(32, 8, 128, 3)
    except:
        refused += 1
    try:
        _ = precision_name(99)
    except:
        refused += 1
    try:
        _ = host_cache_context(0)
    except:
        refused += 1
    try:
        _ = gemma_owning_layers(18, 18)
    except:
        refused += 1
    try:
        _ = kv_int8_projected_per_token(32, 8, 128, 0)
    except:
        refused += 1
    expect_eq(refused, 6, "invalid input refusals")
    print("PASS: invalid inputs refused -- zero layers, 3-byte elements, unknown precision, zero context, shared>=layers, scaleless projection")


def main() raises:
    test_precision_codes()
    test_dense_profiles_f16()
    test_totals_and_caps()
    test_olmoe_width_form()
    test_gemma_e4b_host_tiers()
    test_gemma_e2b_host_tiers()
    test_gemma_cuda_shape()
    test_int8_projection()
    test_claim_verdict()
    test_invalid_inputs_refused()
    print("ALL PASS: kv account (10 groups)")
