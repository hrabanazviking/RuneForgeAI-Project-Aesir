"""J-092 share harness: the attention-vs-rest split
of J-091's ladder frame, printed from
core/attention_share.mojo (itself defined through
core/kv_ladder / core/prefill_anatomy).

Witness (fixed, stated): Qwen2.5-Coder-7B (28 layers,
hidden 3584, ffn 18944, 28 query heads, 4 kv heads,
head_dim 128, vocab 152064, profile cap 32768),
Q4_K_M file 4,683,074,688 B (sha256
8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b,
the wave crown pin; J-091's witness).

Per rung (1024 / 4096 / 8192 / 16384 / 32768) one
SHARE line prints: the prompt-average work pair
(pre_attn / pre_rest totals) and its share in floored
parts per million; the token-at-context attention at
the rung with its marginal (prefill-rest) and decode
(rest incl. head) shares; the write-leg (128 tokens)
attention/rest totals and share; the decode traffic
pair's KV bytes at both KV precisions with their
shares against the file's bytes; the prefill KV-read
shape at both precisions with its traffic shares on
the host-batched surface (chunk cap 256) and the
GPU width-1 surface. One CROSS line prints every
crossing context solved exactly from the closed
forms (see core/attention_share.mojo's header for
the pre-registered definitions and crossing rule).

Every number is exact arithmetic. NO WALL AND NO
TIME SPLIT IS MEASURED OR PRINTED: a MAC share is
not a time share; every per-token TIME split is
NOT PROVEN in this slice and deferred to the J-098
gate recipe in the J-092 doc (section 7).
Deterministic: identical output on every run.
"""
from core.attention_share import (
    share_attention_macs_at_context,
    share_attention_unit,
    share_decode_crossing_context,
    share_decode_kv_read_per_token,
    share_decode_traffic_crossing_context,
    share_marginal_crossing_context,
    share_ppm,
    share_prefill_attention_total,
    share_prefill_average_crossing,
    share_prefill_kv_shape_bytes,
    share_prefill_rest_total,
    share_prefill_traffic_first_crossing,
    share_prefill_traffic_permanent_crossing_host,
    share_prefill_weight_pass_bytes,
    share_rest_decode_token,
    share_rest_prefill_token,
    share_write_attention_total,
    share_write_rest_total,
)
from core.kv_ladder import (
    LADDER_GEN_TOKENS,
    LADDER_PRECISION_F16,
    LADDER_PRECISION_INT8,
    LADDER_RUNG_COUNT,
    ladder_kv_bytes_per_token,
    ladder_rung,
)
from core.prefill_anatomy import SURFACE_CUDA_WIDTH1, SURFACE_HOST_BATCHED

comptime LAYERS = 28
comptime HIDDEN = 3584
comptime FFN = 18944
comptime KV_HEADS = 4
comptime HEAD_DIM = 128
comptime Q_WIDTH = 3584
comptime KV_WIDTH = 512
comptime VOCAB = 152064
comptime WEIGHTS = 4683074688


def main() raises:
    var pt_f16 = ladder_kv_bytes_per_token(
        LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16
    )
    var pt_i8 = ladder_kv_bytes_per_token(
        LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8
    )
    var rest_pre = share_rest_prefill_token(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN)
    var rest_dec = share_rest_decode_token(
        LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB
    )
    print(
        "SHAREHEAD model=qwen2.5-coder-7b unit="
        + String(share_attention_unit(LAYERS, Q_WIDTH))
        + " rest_prefill_token="
        + String(rest_pre)
        + " rest_decode_token="
        + String(rest_dec)
        + " kv_per_token_f16="
        + String(pt_f16)
        + " kv_per_token_int8="
        + String(pt_i8)
        + " weights="
        + String(WEIGHTS)
        + " gen="
        + String(LADDER_GEN_TOKENS)
    )
    for i in range(LADDER_RUNG_COUNT):
        var rung = ladder_rung(i)
        var pre_attn = share_prefill_attention_total(LAYERS, Q_WIDTH, rung)
        var pre_rest = share_prefill_rest_total(
            LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB, rung
        )
        var tok_attn = share_attention_macs_at_context(LAYERS, Q_WIDTH, rung)
        var w_attn = share_write_attention_total(
            LAYERS, Q_WIDTH, rung, LADDER_GEN_TOKENS
        )
        var w_rest = share_write_rest_total(
            LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB, LADDER_GEN_TOKENS
        )
        var dkv_f16 = share_decode_kv_read_per_token(pt_f16, rung)
        var dkv_i8 = share_decode_kv_read_per_token(pt_i8, rung)
        var pkv_f16 = share_prefill_kv_shape_bytes(pt_f16, rung)
        var pkv_i8 = share_prefill_kv_shape_bytes(pt_i8, rung)
        var host_w = share_prefill_weight_pass_bytes(
            SURFACE_HOST_BATCHED, rung, WEIGHTS
        )
        var gpu_w = share_prefill_weight_pass_bytes(
            SURFACE_CUDA_WIDTH1, rung, WEIGHTS
        )
        print(
            "SHARE L="
            + String(rung)
            + " pre_attn="
            + String(pre_attn)
            + " pre_rest="
            + String(pre_rest)
            + " pre_ppm="
            + String(share_ppm(pre_attn, pre_rest))
            + " tok_attn="
            + String(tok_attn)
            + " marg_ppm="
            + String(share_ppm(tok_attn, rest_pre))
            + " dec_ppm="
            + String(share_ppm(tok_attn, rest_dec))
            + " write_attn="
            + String(w_attn)
            + " write_rest="
            + String(w_rest)
            + " write_ppm="
            + String(share_ppm(w_attn, w_rest))
            + " dec_kv_f16="
            + String(dkv_f16)
            + " traf_dec_f16_ppm="
            + String(share_ppm(dkv_f16, WEIGHTS))
            + " dec_kv_int8="
            + String(dkv_i8)
            + " traf_dec_int8_ppm="
            + String(share_ppm(dkv_i8, WEIGHTS))
            + " pre_kv_f16="
            + String(pkv_f16)
            + " traf_pre_host_f16_ppm="
            + String(share_ppm(pkv_f16, host_w))
            + " traf_pre_gpu_f16_ppm="
            + String(share_ppm(pkv_f16, gpu_w))
            + " pre_kv_int8="
            + String(pkv_i8)
            + " traf_pre_host_int8_ppm="
            + String(share_ppm(pkv_i8, host_w))
            + " traf_pre_gpu_int8_ppm="
            + String(share_ppm(pkv_i8, gpu_w))
        )
    print(
        "CROSS marg_work="
        + String(
            share_marginal_crossing_context(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN)
        )
        + " dec_work="
        + String(
            share_decode_crossing_context(
                LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB
            )
        )
        + " preavg_work="
        + String(
            share_prefill_average_crossing(
                LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB
            )
        )
        + " traf_dec_f16="
        + String(share_decode_traffic_crossing_context(pt_f16, WEIGHTS))
        + " traf_dec_int8="
        + String(share_decode_traffic_crossing_context(pt_i8, WEIGHTS))
        + " traf_pre_host_f16_first="
        + String(
            share_prefill_traffic_first_crossing(
                SURFACE_HOST_BATCHED, pt_f16, WEIGHTS
            )
        )
        + " traf_pre_host_f16_perm="
        + String(share_prefill_traffic_permanent_crossing_host(pt_f16, WEIGHTS))
        + " traf_pre_host_int8_first="
        + String(
            share_prefill_traffic_first_crossing(
                SURFACE_HOST_BATCHED, pt_i8, WEIGHTS
            )
        )
        + " traf_pre_host_int8_perm="
        + String(share_prefill_traffic_permanent_crossing_host(pt_i8, WEIGHTS))
        + " traf_pre_gpu_f16="
        + String(
            share_prefill_traffic_first_crossing(
                SURFACE_CUDA_WIDTH1, pt_f16, WEIGHTS
            )
        )
        + " traf_pre_gpu_int8="
        + String(
            share_prefill_traffic_first_crossing(
                SURFACE_CUDA_WIDTH1, pt_i8, WEIGHTS
            )
        )
    )
    print("SHAREDONE rungs=5 time_split=NOT_PROVEN_DEFERRED_J098")
