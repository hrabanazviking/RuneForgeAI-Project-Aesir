"""Qwen3-Next hybrid layout rules (Janas road J-123).

The roadmap text: "Qwen3-Next (MoE) verification. The architecture
Janas headlines: Aesir reads a sha-pinned Qwen3-Next GGUF; per-arch
faithfulness graded; deltas (hybrid recurrence per its public
architecture descriptions) built as needed."

This module is the layout's PERMANENT, mechanical half: the
layer-classification and tensor-directory rules, stated once, that
the loader's `_validate_qwen3next_tensors` branch applies and that
this slice's census/inspect tooling re-derives. The module reads no
file, opens no device, and contains no forward: it classifies
layers and names tensors. Admission (the loader branch consuming
these rules) is loader/census-level only -- no session steps a
qwen3next file through this module, and none may claim to until a
forward exists (blocker B2b, J-032, stands).

THE RULES (from the architecture's public record -- the Qwen team's
published Qwen3-Next description and the model's public model card
-- plus the GGUF file's own metadata as filed by J-022/J-032; no
Janas source, no llama.cpp source):

- Every `full_attention_interval`-th layer (1-based; the public
  record's repeating 3 x Gated-DeltaNet + 1 x Gated-Attention
  pattern, interval 4 for the 80B-A3B file) is a gated-attention
  layer; every other layer is a Gated-DeltaNet SSM layer. At the
  filed real geometry (48 blocks, interval 4): 36 SSM + 12
  attention, attention exactly at indices 3, 7, ..., 47.
- Every block carries the same 9 common tensors: two norms
  (attn_norm, post_attention_norm -- the pre-FFN norm role, as in
  qwen35; there is no ffn_norm), the router (ffn_gate_inp), the
  routed-expert triple (ffn_gate_exps / ffn_up_exps /
  ffn_down_exps, stored 3-D), and the shared-expert triple
  (ffn_gate_shexp / ffn_up_shexp / ffn_down_shexp).
- An SSM block adds 9 tensors: attn_qkv, attn_gate, ssm_alpha,
  ssm_beta, ssm_a, ssm_conv1d, ssm_dt.bias, ssm_norm, ssm_out
  (the qwen35 SSM set, unchanged) -- 18 per SSM block.
- An attention block adds 7 tensors -- 16 per attention block --
  in either gated form: separate-gate (attn_q at the plain Q
  width, plus attn_gate at the Q width) or fused-gate (attn_q at
  twice the Q width, no attn_gate; the qwen35 fused form). Both
  forms carry attn_k, attn_v, attn_output, attn_q_norm,
  attn_k_norm.
- Globals: token_embd.weight, output_norm.weight, output.weight.

CENSUS WITNESS: at the real geometry the directory totals
36 x 18 + 12 x 16 + 3 = 843 tensors -- exactly the count J-022's
header read filed for the sha-pinned file. That agreement is
support for these rules, not the real file's census; only a
header census on the file itself proves its directory (J-123
doc section 0.4).
"""


comptime QWEN3NEXT_KIND_SSM = 0
comptime QWEN3NEXT_KIND_ATTENTION = 1


def qwen3next_effective_interval(interval: Int) -> Int:
    """The interval a file's metadata states, with the family
    default: an absent/non-positive interval means 4 (the public
    record's pattern, and the qwen35 branch's own default)."""
    if interval <= 0:
        return 4
    return interval


def qwen3next_is_attention_layer(layer: Int, interval: Int) -> Bool:
    """True when `layer` (0-based) is a gated-attention layer:
    every interval-th layer, 1-based."""
    var iv = qwen3next_effective_interval(interval)
    return (layer + 1) % iv == 0


def qwen3next_layer_kind(layer: Int, interval: Int) -> Int:
    if qwen3next_is_attention_layer(layer, interval):
        return QWEN3NEXT_KIND_ATTENTION
    return QWEN3NEXT_KIND_SSM


def qwen3next_layer_kind_name(kind: Int) -> String:
    if kind == QWEN3NEXT_KIND_ATTENTION:
        return String("attention")
    return String("ssm")


def qwen3next_attention_layer_count(blocks: Int, interval: Int) -> Int:
    var n = 0
    for layer in range(blocks):
        if qwen3next_is_attention_layer(layer, interval):
            n += 1
    return n


def qwen3next_ssm_layer_count(blocks: Int, interval: Int) -> Int:
    return blocks - qwen3next_attention_layer_count(blocks, interval)


def qwen3next_common_suffixes() -> List[String]:
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


def qwen3next_ssm_suffixes() -> List[String]:
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


def qwen3next_attention_suffixes(fused_gate: Bool) -> List[String]:
    """The extra tensors of a gated-attention block: 7 in the
    separate-gate form, 6 in the fused-gate form (attn_q carries
    the gate at twice the Q width and no attn_gate exists)."""
    var out = List[String]()
    out.append("attn_q.weight")
    out.append("attn_k.weight")
    out.append("attn_v.weight")
    out.append("attn_output.weight")
    out.append("attn_q_norm.weight")
    out.append("attn_k_norm.weight")
    if not fused_gate:
        out.append("attn_gate.weight")
    return out^


def qwen3next_block_tensor_count(kind: Int, fused_gate: Bool) -> Int:
    var n = 9
    if kind == QWEN3NEXT_KIND_ATTENTION:
        n += 6 if fused_gate else 7
    else:
        n += 9
    return n


def qwen3next_total_tensor_count(
    blocks: Int, interval: Int, fused_gate: Bool
) -> Int:
    """Globals (3) + per-block directory, by these rules."""
    var total = 3
    for layer in range(blocks):
        total += qwen3next_block_tensor_count(
            qwen3next_layer_kind(layer, interval), fused_gate
        )
    return total
