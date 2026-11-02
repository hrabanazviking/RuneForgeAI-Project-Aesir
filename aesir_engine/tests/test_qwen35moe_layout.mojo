"""Qwen3.5-MoE / Qwen3.6 hybrid layout rules (J-124): layer
classification at the real geometry (40 blocks, interval 4:
30 SSM + 10 attention, attention exactly at 3, 7, ..., 39) and
at the synthetic fixture geometry (4 blocks: 3 SSM + 1
attention); the per-kind tensor-directory lists (attention in
the fused-gate form only -- no attn_gate on attention blocks);
the block and total tensor counts, including the directory
arithmetic 30 x 18 + 10 x 15 + 3 = 693 at the real geometry
(a prediction for the deferred real-file census, J-124 doc
section 0.4 -- no filed header count witnesses it); and the
interval default rule. All geometries are stated fixtures from
the architecture's public record, not values read from any
real file in this suite (no qwen35moe file exists in Aesir's
records; the real file's header census is J-124 doc 0.6)."""
from core.qwen35moe_layout import (
    QWEN35MOE_KIND_ATTENTION,
    QWEN35MOE_KIND_SSM,
    qwen35moe_attention_layer_count,
    qwen35moe_attention_suffixes,
    qwen35moe_block_tensor_count,
    qwen35moe_common_suffixes,
    qwen35moe_effective_interval,
    qwen35moe_is_attention_layer,
    qwen35moe_layer_kind,
    qwen35moe_layer_kind_name,
    qwen35moe_ssm_layer_count,
    qwen35moe_ssm_suffixes,
    qwen35moe_total_tensor_count,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "Qwen35MoeLayout " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("Qwen35MoeLayout " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("Qwen35MoeLayout " + what + ": expected false")


def test_real_geometry_classification() raises:
    expect_eq(qwen35moe_attention_layer_count(40, 4), 10, "real attention count")
    expect_eq(qwen35moe_ssm_layer_count(40, 4), 30, "real SSM count")
    for layer in range(40):
        var want_attn = (layer + 1) % 4 == 0
        if qwen35moe_is_attention_layer(layer, 4) != want_attn:
            raise Error("real geometry: layer " + String(layer) + " misclassified")
        var kind = qwen35moe_layer_kind(layer, 4)
        if want_attn and kind != QWEN35MOE_KIND_ATTENTION:
            raise Error("real geometry: attention kind mismatch")
        if not want_attn and kind != QWEN35MOE_KIND_SSM:
            raise Error("real geometry: SSM kind mismatch")
    print("PASS: classification -- real geometry 40 blocks (30 SSM / 10 attention)")


def test_fixture_geometry_classification() raises:
    expect_false(qwen35moe_is_attention_layer(0, 4), "fixture block 0 is SSM")
    expect_false(qwen35moe_is_attention_layer(1, 4), "fixture block 1 is SSM")
    expect_false(qwen35moe_is_attention_layer(2, 4), "fixture block 2 is SSM")
    expect_true(qwen35moe_is_attention_layer(3, 4), "fixture block 3 is attention")
    expect_eq(qwen35moe_attention_layer_count(4, 4), 1, "fixture attention count")
    expect_eq(qwen35moe_ssm_layer_count(4, 4), 3, "fixture SSM count")
    print("PASS: classification -- fixture geometry 4 blocks (3 SSM / 1 attention)")


def test_interval_default() raises:
    expect_eq(qwen35moe_effective_interval(0), 4, "interval 0 defaults to 4")
    expect_eq(qwen35moe_effective_interval(-3), 4, "negative interval defaults to 4")
    expect_eq(qwen35moe_effective_interval(4), 4, "interval 4 kept")
    expect_eq(qwen35moe_effective_interval(2), 2, "interval 2 kept")
    expect_true(qwen35moe_is_attention_layer(1, 2), "interval 2: layer 1 attention")
    print("PASS: classification -- interval default rule")


def test_directory_lists() raises:
    var common = qwen35moe_common_suffixes()
    expect_eq(len(common), 9, "common suffix count")
    expect_true(common[0] == "attn_norm.weight", "common[0]")
    expect_true(common[2] == "ffn_gate_inp.weight", "common router")
    expect_true(common[6] == "ffn_gate_shexp.weight", "common shared gate")
    expect_true(common[8] == "ffn_down_shexp.weight", "common shared down")
    var ssm = qwen35moe_ssm_suffixes()
    expect_eq(len(ssm), 9, "SSM suffix count")
    expect_true(ssm[0] == "attn_qkv.weight", "SSM[0]")
    expect_true(ssm[4] == "ssm_a", "SSM ssm_a carries no .weight")
    expect_true(ssm[8] == "ssm_out.weight", "SSM[8]")
    var attn = qwen35moe_attention_suffixes()
    expect_eq(len(attn), 6, "attention fused-gate suffix count")
    expect_true(attn[0] == "attn_q.weight", "attention[0]")
    expect_true(attn[5] == "attn_k_norm.weight", "attention[5]")
    for i in range(len(attn)):
        if attn[i] == "attn_gate.weight":
            raise Error("fused-gate attention list must not carry attn_gate")
    print("PASS: directory lists -- common 9, SSM +9, attention +6 (fused)")


def test_counts_and_arithmetic() raises:
    expect_eq(
        qwen35moe_block_tensor_count(QWEN35MOE_KIND_SSM), 18, "SSM block count"
    )
    expect_eq(
        qwen35moe_block_tensor_count(QWEN35MOE_KIND_ATTENTION),
        15,
        "attention block count (fused-gate)",
    )
    expect_eq(
        qwen35moe_total_tensor_count(40, 4), 693, "real total (prediction)"
    )
    expect_eq(
        qwen35moe_total_tensor_count(4, 4), 72, "fixture total"
    )
    print("PASS: counts -- directory arithmetic 693 (30x18 + 10x15 + 3), fixture 72")


def test_kind_names() raises:
    expect_true(
        qwen35moe_layer_kind_name(QWEN35MOE_KIND_SSM) == "ssm", "SSM kind name"
    )
    expect_true(
        qwen35moe_layer_kind_name(QWEN35MOE_KIND_ATTENTION) == "attention",
        "attention kind name",
    )
    print("PASS: kind names -- ssm / attention")


def main() raises:
    test_real_geometry_classification()
    test_fixture_geometry_classification()
    test_interval_default()
    test_directory_lists()
    test_counts_and_arithmetic()
    test_kind_names()
    print("test_qwen35moe_layout: ALL PASS (6 groups)")
