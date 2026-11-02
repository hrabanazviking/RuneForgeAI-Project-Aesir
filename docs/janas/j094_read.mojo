"""J-094 prompt-read harness: the prompt-read
account of the ladder witness at every rung,
printed from core/prompt_read.mojo (itself defined
through core/kv_ladder / core/prefill_anatomy /
core/attention_share / core/gpu_block_prefill /
core/split_prompt).

Witness (fixed, stated): Qwen2.5-Coder-7B (28
layers, hidden 3584, ffn 18944, 28 query heads,
4 kv heads, head_dim 128, vocab 152064, profile
cap 32768), Q4_K_M file 4,683,074,688 B (sha256
8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b,
the wave crown pin; J-091's witness). GPU machine
fact: usable VRAM 5,368,709,120 B (J-031,
purplelongship RTX 2060). Activation elements
208,896 fixed + 28 per context token; sampling
device bytes 905,728 (the J-091/J-093 admission
shape).

Per rung and precision one READ line prints: the
causal pairs per layer; the work account (attention
/ projection / total MACs, mean per token, the
attention share of the read work in floored ppm,
and the one head pass filed separately as the
first-token hand-off); KV written and the KV-read
touch shape; per surface (host batched cap 256,
GPU width-1) the passes, weight-pass bytes, total
touch shape and sync crossings; the CPU/GPU read
verdicts under the tree's integration facts (int8
integrated on neither line); and the GPU read
admission total with its placement. Per rung one
EFFECT line prints Part IV's priced deltas: host
chunking's weight delta; the f16->int8 KV deltas
(written / read shape); J-054's block account at
width 256 (counterfactual, UNBUILT); J-056's split
plan at width 256 with its own rule's verdict
under the rung's f16 read-placement parent flag.

Every number is exact arithmetic through the
tree's own modules. NO WALL AND NO READ TIME IS
MEASURED OR PRINTED: this VM is below its
inference gate and purplelongship is unreachable;
every live read is deferred to the J-098 gate
recipe in the J-094 doc (section 7).
Deterministic: identical output on every run.
"""
from core.kv_ladder import (
    LADDER_GPU_WHOLE,
    LADDER_LINE_CPU,
    LADDER_LINE_GPU,
    LADDER_PRECISION_F16,
    LADDER_PRECISION_INT8,
    LADDER_RUNG_COUNT,
    ladder_gpu_placement_name,
    ladder_kv_bytes_per_token,
    ladder_rung,
    ladder_verdict_name,
)
from core.prefill_anatomy import (
    SURFACE_CUDA_WIDTH1,
    SURFACE_HOST_BATCHED,
)
from core.prompt_read import (
    read_attention_share_ppm,
    read_block_cf,
    read_chunk_weight_delta,
    read_gpu_placement,
    read_gpu_required,
    read_head_macs,
    read_kv_read_shape,
    read_kv_written,
    read_pairs,
    read_passes,
    read_precision_kv_shape_delta,
    read_precision_kv_written_delta,
    read_split_plan,
    read_split_verdict,
    read_sync_crossings,
    read_touch_shape,
    read_verdict,
    read_weight_pass_bytes,
    read_work_attention,
    read_work_per_token,
    read_work_projection,
    read_work_total,
)
comptime LAYERS = 28
comptime HIDDEN = 3584
comptime Q_WIDTH = 3584
comptime KV_WIDTH = 512
comptime FFN = 18944
comptime KV_HEADS = 4
comptime HEAD_DIM = 128
comptime VOCAB = 152064
comptime PROFILE_CAP = 32768
comptime WEIGHTS = 4683074688
comptime ACT_FIXED = 208896
comptime ACT_PER_CONTEXT = 28
comptime SAMPLING = 905728
comptime USABLE = 5368709120


def _prec_name(precision: Int) -> String:
    return String("f16") if precision == LADDER_PRECISION_F16 else String("int8")


def _kv_pt(precision: Int) raises -> Int:
    return ladder_kv_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM, precision)


def main() raises:
    print(
        "READHEAD model=qwen2.5-coder-7b weights="
        + String(WEIGHTS)
        + " usable_gpu="
        + String(USABLE)
        + " host_cap=256 block_width=256 split_width=256"
    )
    var precisions = List[Int]()
    precisions.append(LADDER_PRECISION_F16)
    precisions.append(LADDER_PRECISION_INT8)
    for i in range(LADDER_RUNG_COUNT):
        var rung = ladder_rung(i)
        for precision in precisions:
            var kv_pt = _kv_pt(precision)
            var required = read_gpu_required(
                WEIGHTS, kv_pt, rung, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING
            )
            print(
                "READ L="
                + String(rung)
                + " prec="
                + _prec_name(precision)
                + " pairs="
                + String(read_pairs(rung))
                + " work_attn="
                + String(read_work_attention(LAYERS, Q_WIDTH, rung))
                + " work_proj="
                + String(
                    read_work_projection(
                        LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, rung
                    )
                )
                + " work_total="
                + String(
                    read_work_total(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, rung)
                )
                + " work_per_token="
                + String(
                    read_work_per_token(
                        LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, rung
                    )
                )
                + " attn_share_ppm="
                + String(
                    read_attention_share_ppm(
                        LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, rung
                    )
                )
                + " head="
                + String(read_head_macs(HIDDEN, VOCAB))
                + " kv_written="
                + String(
                    read_kv_written(LAYERS, KV_HEADS, HEAD_DIM, precision, rung)
                )
                + " kv_read_shape="
                + String(read_kv_read_shape(kv_pt, rung))
                + " passes_host="
                + String(read_passes(SURFACE_HOST_BATCHED, rung))
                + " weight_host="
                + String(
                    read_weight_pass_bytes(SURFACE_HOST_BATCHED, rung, WEIGHTS)
                )
                + " touch_host="
                + String(
                    read_touch_shape(kv_pt, SURFACE_HOST_BATCHED, rung, WEIGHTS)
                )
                + " passes_gpu="
                + String(read_passes(SURFACE_CUDA_WIDTH1, rung))
                + " weight_gpu="
                + String(
                    read_weight_pass_bytes(SURFACE_CUDA_WIDTH1, rung, WEIGHTS)
                )
                + " touch_gpu="
                + String(
                    read_touch_shape(kv_pt, SURFACE_CUDA_WIDTH1, rung, WEIGHTS)
                )
                + " syncs_gpu="
                + String(read_sync_crossings(SURFACE_CUDA_WIDTH1, rung))
                + " verdict_cpu="
                + ladder_verdict_name(
                    read_verdict(
                        LADDER_LINE_CPU, precision, rung,
                        False, False, PROFILE_CAP,
                    )
                )
                + " verdict_gpu="
                + ladder_verdict_name(
                    read_verdict(
                        LADDER_LINE_GPU, precision, rung,
                        False, False, PROFILE_CAP,
                    )
                )
                + " gpu_required="
                + String(required)
                + " gpu_place="
                + ladder_gpu_placement_name(
                    read_gpu_placement(required, USABLE)
                )
            )
        var req_f16 = read_gpu_required(
            WEIGHTS, _kv_pt(LADDER_PRECISION_F16), rung,
            ACT_FIXED, ACT_PER_CONTEXT, SAMPLING,
        )
        var fits = read_gpu_placement(req_f16, USABLE) == LADDER_GPU_WHOLE
        var cf = read_block_cf(rung, 256, LAYERS, WEIGHTS)
        var split = read_split_plan(
            rung, 256, LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, WEIGHTS, fits
        )
        var split_verdict = read_split_verdict(split)
        print(
            "EFFECT L="
            + String(rung)
            + " chunk_weight_delta="
            + String(read_chunk_weight_delta(rung, WEIGHTS))
            + " kvw_delta="
            + String(
                read_precision_kv_written_delta(LAYERS, KV_HEADS, HEAD_DIM, rung)
            )
            + " kvr_delta="
            + String(
                read_precision_kv_shape_delta(LAYERS, KV_HEADS, HEAD_DIM, rung)
            )
            + " block_chunks="
            + String(cf.chunks)
            + " block_syncs="
            + String(cf.sync_crossings)
            + " block_gemm="
            + String(cf.batched_gemm_calls)
            + " block_attn_calls="
            + String(cf.per_row_attention_calls)
            + " block_weight="
            + String(cf.weight_read_bytes)
            + " block_admission=unbuilt"
            + " split_fits="
            + String(fits)
            + " split_join="
            + String(split.join_bytes)
            + " split_transfers="
            + String(split.boundary_transfers)
            + " split_crossings="
            + String(split.split_crossings)
            + " split_verdict="
            + split_verdict.verdict_name()
        )
    print("READDONE rungs=5 walls=NOT_PROVEN_DEFERRED_J098")
