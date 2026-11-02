"""Qwen3.5-MoE / Qwen3.6 hybrid layout rules (Janas road J-124).

The roadmap text: "Qwen3.6 verification. The 3.6 generation
graded the same way; MTP presence per J-076 confirmed in the
process."

This module is the layout's PERMANENT, mechanical half: the
layer-classification and tensor-directory rules, stated once,
that the loader's `_validate_qwen35moe_tensors` branch applies
and that this slice's census/inspect tooling re-derives. The
module reads no file, opens no device, and contains no forward:
it classifies layers and names tensors. Admission (the loader
branch consuming these rules) is loader/census-level only -- no
session steps a qwen35moe file through this module, and none
may claim to until a forward exists (J-124 doc section 0.1(c)).

THE RULES (from the architecture's public record -- the Qwen
team's published Qwen3.5-MoE / Qwen3.6 descriptions and the
models' public model cards: Qwen3.6-35B-A3B shares its
architecture and model type with Qwen3.5-MoE -- plus Aesir's
own filed records for the sibling branches, qwen35 dense and
qwen3next; no Janas source, no llama.cpp source):

- Every `full_attention_interval`-th layer (1-based; the public
  record's repeating 3 x Gated-DeltaNet + 1 x Gated-Attention
  pattern, interval 4 for the 35B-A3B file) is a gated-attention
  layer; every other layer is a Gated-DeltaNet SSM layer. At the
  filed real geometry (40 blocks, interval 4): 30 SSM + 10
  attention, attention exactly at indices 3, 7, ..., 39.
- Every block carries the same 9 common tensors: two norms
  (attn_norm, post_attention_norm -- the pre-FFN norm role, as
  in qwen35; there is no ffn_norm), the router (ffn_gate_inp),
  the routed-expert triple (ffn_gate_exps / ffn_up_exps /
  ffn_down_exps, stored 3-D), and the shared-expert triple
  (ffn_gate_shexp / ffn_up_shexp / ffn_down_shexp).
- An SSM block adds 9 tensors: attn_qkv, attn_gate, ssm_alpha,
  ssm_beta, ssm_a, ssm_conv1d, ssm_dt.bias, ssm_norm, ssm_out
  (the qwen35 SSM set, unchanged) -- 18 per SSM block.
- An attention block adds 6 tensors -- 15 per attention block --
  in the fused-gate form only: attn_q at twice the Q width (the
  gate fused into the query projection, the qwen35 form; this
  family carries no separate attn_gate on attention blocks),
  plus attn_k, attn_v, attn_output, attn_q_norm, attn_k_norm.
- Globals: token_embd.weight, output_norm.weight, output.weight.
- A prediction-head (MTP) block, where a file carries one, lives
  outside this directory (the extra-block nextn form J-121
  filed); these rules neither require nor forbid it -- presence
  is graded by core.mtp_census (J-076), not here.

CENSUS ARITHMETIC: at the real geometry the directory totals
30 x 18 + 10 x 15 + 3 = 693 tensors for a head-free file. No
filed header count witnesses this (no qwen35moe file exists in
Aesir's records -- J-076, J-124 doc section 0.4): 693 is the
directory's own arithmetic and a falsifiable prediction for
the deferred real-file census (J-124 doc section 0.6).
"""


comptime QWEN35MOE_KIND_SSM = 0
comptime QWEN35MOE_KIND_ATTENTION = 1


def qwen35moe_effective_interval(interval: Int) -> Int:
    """The interval a file's metadata states, with the family
    default: an absent/non-positive interval means 4 (the public
    record's pattern, and the qwen35 branch's own default)."""
    if interval <= 0:
        return 4
    return interval


def qwen35moe_is_attention_layer(layer: Int, interval: Int) -> Bool:
    """True when `layer` (0-based) is a gated-attention layer:
    every interval-th layer, 1-based."""
    var iv = qwen35moe_effective_interval(interval)
    return (layer + 1) % iv == 0


def qwen35moe_layer_kind(layer: Int, interval: Int) -> Int:
    if qwen35moe_is_attention_layer(layer, interval):
        return QWEN35MOE_KIND_ATTENTION
    return QWEN35MOE_KIND_SSM


def qwen35moe_layer_kind_name(kind: Int) -> String:
    if kind == QWEN35MOE_KIND_ATTENTION:
        return String("attention")
    return String("ssm")


def qwen35moe_attention_layer_count(blocks: Int, interval: Int) -> Int:
    var n = 0
    for layer in range(blocks):
        if qwen35moe_is_attention_layer(layer, interval):
            n += 1
    return n


def qwen35moe_ssm_layer_count(blocks: Int, interval: Int) -> Int:
    return blocks - qwen35moe_attention_layer_count(blocks, interval)


def qwen35moe_common_suffixes() -> List[String]:
    """The 9 tensors every block carries, in directory order."""
    var out = List[String]()
    out.append("attn_norm.weight")
    out.append("post_attention_norm.weight")
    out.append("ffn_gate_inp.weight")
    out.append("ffn_gate_exps.weight")
    out.append("ffn_up_exps.weight")
    out.append("ffn_down_exps.weight")
    out.append("ffn_gate_shexp.weight")
    out.append("ffn_up_shexp.weight")
    out.append("ffn_down_shexp.weight")
    return out^


def qwen35moe_ssm_suffixes() -> List[String]:
    """The 9 extra tensors of a Gated-DeltaNet SSM block."""
    var out = List[String]()
    out.append("attn_qkv.weight")
    out.append("attn_gate.weight")
    out.append("ssm_alpha.weight")
    out.append("ssm_beta.weight")
    out.append("ssm_a")
    out.append("ssm_conv1d.weight")
    out.append("ssm_dt.bias")
    out.append("ssm_norm.weight")
    out.append("ssm_out.weight")
    return out^


def qwen35moe_attention_suffixes() -> List[String]:
    """The 6 extra tensors of a gated-attention block, fused-gate
    form (attn_q carries the gate at twice the Q width; there is
    no attn_gate tensor on an attention block in this family)."""
    var out = List[String]()
    out.append("attn_q.weight")
    out.append("attn_k.weight")
    out.append("attn_v.weight")
    out.append("attn_output.weight")
    out.append("attn_q_norm.weight")
    out.append("attn_k_norm.weight")
    return out^


def qwen35moe_block_tensor_count(kind: Int) -> Int:
    var n = 9
    if kind == QWEN35MOE_KIND_ATTENTION:
        n += 6
    else:
        n += 9
    return n


def qwen35moe_total_tensor_count(
    blocks: Int, interval: Int
) -> Int:
    """Globals (3) + per-block directory, by these rules. A
    prediction-head block, where a file carries one, adds its
    tensors on top of this count (J-124 doc section 0.4)."""
    var total = 3
    for layer in range(blocks):
        total += qwen35moe_block_tensor_count(
            qwen35moe_layer_kind(layer, interval)
        )
    return total
