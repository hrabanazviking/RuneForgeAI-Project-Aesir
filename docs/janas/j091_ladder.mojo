"""J-091 ladder harness: the context ladder's frame
for the dense mid-size witness, printed from
core/kv_ladder.mojo.

Witness (fixed, stated): Qwen2.5-Coder-7B (28 layers,
hidden 3584, ffn 18944, 28 query heads, 4 kv heads,
head_dim 128, vocab 152064, profile context cap
32768), Q4_K_M file 4,683,074,688 B (sha256
8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b,
the wave crown pin). GPU line machine facts: usable
VRAM 5,368,709,120 B (J-031, purplelongship RTX 2060);
activation elements 208,896 fixed + 28 per context
token (the profile's own activation_elements shape);
sampling device bytes 905,728 (core/sampling_config).

Per rung (1024 / 4096 / 8192 / 16384 / 32768) one
LADDER line prints: KV bytes per token and total at
the rung for f16 and per-row int8; prefill causal
pairs per layer, attention MACs, projection MACs and
the one head pass; the write leg's (128 tokens)
context sum, KV-read traffic at both precisions and
attention MACs; the CPU-line verdicts (f16 read /
write; int8 read) and GPU-line verdicts (f16 read /
write) under the tree's integration facts (int8
integrated on neither line); the GPU admission total
at the rung's session context (rung + 128) at f16
with its placement, and the int8 counterfactual
admission total with its placement.

Every number is exact arithmetic through
core/kv_account / core/kv_int8 / core/prefill_anatomy
via core/kv_ladder. NO WALL IS MEASURED OR PRINTED:
this VM is below its inference gate and
purplelongship is unreachable; the ladder's walls
are deferred to the J-098 gate recipe in the J-091
doc (section 7). Deterministic: identical output on
every run.
"""
from core.kv_ladder import (
    LADDER_GEN_TOKENS,
    LADDER_LINE_CPU,
    LADDER_LINE_GPU,
    LADDER_PRECISION_F16,
    LADDER_PRECISION_INT8,
    LADDER_READ,
    LADDER_RUNG_COUNT,
    LADDER_WRITE,
    ladder_cell_verdict,
    ladder_decode_attention_macs,
    ladder_decode_context_sum,
    ladder_decode_kv_read_bytes,
    ladder_gpu_placement,
    ladder_gpu_placement_name,
    ladder_gpu_required_bytes,
    ladder_head_macs,
    ladder_kv_bytes_per_token,
    ladder_kv_total,
    ladder_prefill_attention_macs,
    ladder_prefill_pairs,
    ladder_prefill_projection_macs,
    ladder_rung,
    ladder_verdict_name,
)

comptime LAYERS = 28
comptime HIDDEN = 3584
comptime FFN = 18944
comptime KV_HEADS = 4
comptime HEAD_DIM = 128
comptime Q_WIDTH = 3584
comptime KV_WIDTH = 512
comptime VOCAB = 152064
comptime PROFILE_CAP = 32768
comptime WEIGHTS = 4683074688
comptime USABLE = 5368709120
comptime ACT_FIXED = 208896
comptime ACT_PER_CONTEXT = 28
comptime SAMPLING = 905728


def main() raises:
    var pt_f16 = ladder_kv_bytes_per_token(
        LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16
    )
    var pt_i8 = ladder_kv_bytes_per_token(
        LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8
    )
    print(
        "LADDERHEAD model=qwen2.5-coder-7b layers=28 kv_per_token_f16="
        + String(pt_f16)
        + " kv_per_token_int8="
        + String(pt_i8)
        + " gen="
        + String(LADDER_GEN_TOKENS)
        + " usable_gpu="
        + String(USABLE)
    )
    for i in range(LADDER_RUNG_COUNT):
        var rung = ladder_rung(i)
        var session = rung + LADDER_GEN_TOKENS
        var req_f16 = ladder_gpu_required_bytes(
            WEIGHTS, pt_f16, session, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING
        )
        var req_i8 = ladder_gpu_required_bytes(
            WEIGHTS, pt_i8, session, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING
        )
        print(
            "LADDER L="
            + String(rung)
            + " kv_f16="
            + String(
                ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, rung)
            )
            + " kv_int8="
            + String(
                ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8, rung)
            )
            + " pairs="
            + String(ladder_prefill_pairs(rung))
            + " prefill_attn_macs="
            + String(ladder_prefill_attention_macs(LAYERS, Q_WIDTH, rung))
            + " prefill_proj_macs="
            + String(
                ladder_prefill_projection_macs(
                    LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, rung
                )
            )
            + " head_macs="
            + String(ladder_head_macs(HIDDEN, VOCAB))
            + " dec_ctx_sum="
            + String(ladder_decode_context_sum(rung, LADDER_GEN_TOKENS))
            + " dec_kv_read_f16="
            + String(
                ladder_decode_kv_read_bytes(pt_f16, rung, LADDER_GEN_TOKENS)
            )
            + " dec_kv_read_int8="
            + String(
                ladder_decode_kv_read_bytes(pt_i8, rung, LADDER_GEN_TOKENS)
            )
            + " dec_attn_macs="
            + String(
                ladder_decode_attention_macs(
                    LAYERS, Q_WIDTH, rung, LADDER_GEN_TOKENS
                )
            )
            + " cpu_f16_read="
            + ladder_verdict_name(
                ladder_cell_verdict(
                    LADDER_LINE_CPU, LADDER_PRECISION_F16, rung, LADDER_READ,
                    False, False, PROFILE_CAP,
                )
            )
            + " cpu_f16_write="
            + ladder_verdict_name(
                ladder_cell_verdict(
                    LADDER_LINE_CPU, LADDER_PRECISION_F16, rung, LADDER_WRITE,
                    False, False, PROFILE_CAP,
                )
            )
            + " cpu_int8_read="
            + ladder_verdict_name(
                ladder_cell_verdict(
                    LADDER_LINE_CPU, LADDER_PRECISION_INT8, rung, LADDER_READ,
                    False, False, PROFILE_CAP,
                )
            )
            + " gpu_f16_read="
            + ladder_verdict_name(
                ladder_cell_verdict(
                    LADDER_LINE_GPU, LADDER_PRECISION_F16, rung, LADDER_READ,
                    False, False, PROFILE_CAP,
                )
            )
            + " gpu_f16_write="
            + ladder_verdict_name(
                ladder_cell_verdict(
                    LADDER_LINE_GPU, LADDER_PRECISION_F16, rung, LADDER_WRITE,
                    False, False, PROFILE_CAP,
                )
            )
            + " gpu_req_f16="
            + String(req_f16)
            + " gpu_place_f16="
            + ladder_gpu_placement_name(ladder_gpu_placement(req_f16, USABLE))
            + " gpu_req_int8_cf="
            + String(req_i8)
            + " gpu_place_int8_cf="
            + ladder_gpu_placement_name(ladder_gpu_placement(req_i8, USABLE))
        )
    print("LADDERDONE rungs=5 walls=NOT_PROVEN_DEFERRED_J098")
