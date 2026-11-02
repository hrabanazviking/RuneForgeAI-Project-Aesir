"""Qwen3-Next hybrid layout rules (J-123): layer classification
at the real geometry (48 blocks, interval 4: 36 SSM + 12
attention, attention exactly at 3, 7, ..., 47) and at the
synthetic fixture geometry (4 blocks: 3 SSM + 1 attention);
the per-kind tensor-directory lists; the block and total
tensor counts, including the census witness 36 x 18 + 12 x 16
+ 3 = 843 at the real geometry in the separate-gate form and
831 in the fused-gate form; and the interval default rule.
All geometries are stated fixtures from the architecture's
public record, not values read from any real file in this
suite (the real file's header census is J-123 doc 0.6)."""
from core.qwen3next_layout import (
    QWEN3NEXT_KIND_ATTENTION,
    QWEN3NEXT_KIND_SSM,
    qwen3next_attention_layer_count,
    qwen3next_attention_suffixes,
    qwen3next_block_tensor_count,
    qwen3next_common_suffixes,
    qwen3next_effective_interval,
    qwen3next_is_attention_layer,
    qwen3next_layer_kind,
    qwen3next_layer_kind_name,
    qwen3next_ssm_layer_count,
    qwen3next_ssm_suffixes,
    qwen3next_total_tensor_count,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "Qwen3NextLayout " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("Qwen3NextLayout " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("Qwen3NextLayout " + what + ": expected false")


def test_real_geometry_classification() raises:
    expect_eq(qwen3next_attention_layer_count(48, 4), 12, "real attention count")
    expect_eq(qwen3next_ssm_layer_count(48, 4), 36, "real SSM count")
    for layer in range(48):
        var want_attn = (layer + 1) % 4 == 0
        if qwen3next_is_attention_layer(layer, 4) != want_attn:
            raise Error("real geometry: layer " + String(layer) + " misclassified")
        var kind = qwen3next_layer_kind(layer, 4)
        if want_attn and kind != QWEN3NEXT_KIND_ATTENTION:
            raise Error("real geometry: attention kind mismatch")
        if not want_attn and kind != QWEN3NEXT_KIND_SSM:
            raise Error("real geometry: SSM kind mismatch")
    print("PASS: classification -- real geometry 48 blocks (36 SSM / 12 attention)")


def test_fixture_geometry_classification() raises:
    expect_false(qwen3next_is_attention_layer(0, 4), "fixture block 0 is SSM")
    expect_false(qwen3next_is_attention_layer(1, 4), "fixture block 1 is SSM")
    expect_false(qwen3next_is_attention_layer(2, 4), "fixture block 2 is SSM")
    expect_true(qwen3next_is_attention_layer(3, 4), "fixture block 3 is attention")
    expect_eq(qwen3next_attention_layer_count(4, 4), 1, "fixture attention count")
    expect_eq(qwen3next_ssm_layer_count(4, 4), 3, "fixture SSM count")
    print("PASS: classification -- fixture geometry 4 blocks (3 SSM / 1 attention)")


def test_interval_default() raises:
    expect_eq(qwen3next_effective_interval(0), 4, "interval 0 defaults to 4")
    expect_eq(qwen3next_effective_interval(-3), 4, "negative interval defaults to 4")
    expect_eq(qwen3next_effective_interval(4), 4, "interval 4 kept")
    expect_eq(qwen3next_effective_interval(2), 2, "interval 2 kept")
    expect_true(qwen3next_is_attention_layer(1, 2), "interval 2: layer 1 attention")
    print("PASS: classification -- interval default rule")


def test_directory_lists() raises:
    var common = qwen3next_common_suffixes()
    expect_eq(len(common), 9, "common suffix count")
    expect_true(common[0] == "attn_norm.weight", "common[0]")
    expect_true(common[2] == "ffn_gate_inp.weight", "common router")
    expect_true(common[6] == "ffn_gate_shexp.weight", "common shared gate")
    expect_true(common[8] == "ffn_down_shexp.weight", "common shared down")
    var ssm = qwen3next_ssm_suffixes()
    expect_eq(len(ssm), 9, "SSM suffix count")
    expect_true(ssm[0] == "attn_qkv.weight", "SSM[0]")
    expect_true(ssm[4] == "ssm_a", "SSM ssm_a carries no .weight")
    expect_true(ssm[8] == "ssm_out.weight", "SSM[8]")
    var attn_sep = qwen3next_attention_suffixes(False)
    expect_eq(len(attn_sep), 7, "attention separate-gate suffix count")
    expect_true(attn_sep[6] == "attn_gate.weight", "separate-gate has attn_gate")
    var attn_fused = qwen3next_attention_suffixes(True)
    expect_eq(len(attn_fused), 6, "attention fused-gate suffix count")
    for i in range(len(attn_fused)):
        if attn_fused[i] == "attn_gate.weight":
            raise Error("fused-gate list must not carry attn_gate")
    print("PASS: directory lists -- common 9, SSM +9, attention +7/+6")


def test_counts_and_census_witness() raises:
    expect_eq(
        qwen3next_block_tensor_count(QWEN3NEXT_KIND_SSM, False), 18, "SSM block count"
    )
    expect_eq(
        qwen3next_block_tensor_count(QWEN3NEXT_KIND_ATTENTION, False),
        16,
        "attention block count (separate-gate)",
    )
    expect_eq(
        qwen3next_block_tensor_count(QWEN3NEXT_KIND_ATTENTION, True),
        15,
        "attention block count (fused-gate)",
    )
    expect_eq(
        qwen3next_total_tensor_count(48, 4, False), 843, "real total separate-gate"
    )
    expect_eq(
        qwen3next_total_tensor_count(48, 4, True), 831, "real total fused-gate"
    )
    expect_eq(
        qwen3next_total_tensor_count(4, 4, False), 73, "fixture total separate-gate"
    )
    expect_eq(
        qwen3next_total_tensor_count(4, 4, True), 72, "fixture total fused-gate"
    )
    print("PASS: counts -- census witness 843 (36x18 + 12x16 + 3), fixture 73/72")


def test_kind_names() raises:
    expect_true(
        qwen3next_layer_kind_name(QWEN3NEXT_KIND_SSM) == "ssm", "SSM kind name"
    )
    expect_true(
        qwen3next_layer_kind_name(QWEN3NEXT_KIND_ATTENTION) == "attention",
        "attention kind name",
    )
    print("PASS: kind names -- ssm / attention")


def main() raises:
    test_real_geometry_classification()
    test_fixture_geometry_classification()
    test_interval_default()
    test_directory_lists()
    test_counts_and_census_witness()
    test_kind_names()
    print("test_qwen3next_layout: ALL PASS (6 groups)")
