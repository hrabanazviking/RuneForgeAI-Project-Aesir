"""Attention share accounting (J-092): the split of
J-091's ladder frame into attention vs the rest for
the dense mid-size witness (Qwen2.5-Coder-7B: 28
layers, hidden 3584, ffn 18944, 28 query heads,
4 kv heads, head_dim 128, vocab 152064, cap 32768).

The validation gate is J-091's filed section 5 table
reproduced EXACTLY through this module (prefill
attention + projection totals and write-leg attention
totals at every rung; per-token rests reproducing
J-053's 6,525,288,448 projection figure). The splits
and crossings pinned below are exact integer
arithmetic from those totals (shares as floored
parts per million): decode token-at-context crosses
half at context 35,228 (beyond the 32,768 cap; at
the cap the share is 481,914 ppm); the prefill
marginal token crosses at exactly 32,512 (attention
== rest there); the prompt average crosses at
65,024 (never within the ladder); decode traffic
crosses at 81,667 (f16) / 158,384 (int8); host
prefill traffic is a sawtooth (first 700, permanent
808 at f16; first 1,259, permanent 1,379 at int8);
GPU width-1 prefill traffic crosses at 163,332
(f16) / 316,766 (int8). No wall, no speed, no time
split is claimed here: every TIME split is NOT
PROVEN, deferred to the J-098 gate (J-092 doc s.7).
"""
from core.attention_share import (
    share_attention_macs_at_context,
    share_attention_unit,
    share_decode_crossing_context,
    share_decode_kv_read_per_token,
    share_decode_traffic_crossing_context,
    share_head_macs,
    share_is_at_least_half,
    share_marginal_crossing_context,
    share_ppm,
    share_prefill_attention_total,
    share_prefill_average_crossing,
    share_prefill_kv_shape_bytes,
    share_prefill_rest_total,
    share_prefill_traffic_first_crossing,
    share_prefill_traffic_permanent_crossing_host,
    share_prefill_weight_pass_bytes,
    share_projection_macs_per_token,
    share_rest_decode_token,
    share_rest_prefill_token,
    share_write_attention_total,
    share_write_rest_total,
)
from core.kv_ladder import (
    LADDER_PRECISION_F16,
    LADDER_PRECISION_INT8,
    ladder_kv_bytes_per_token,
    ladder_rung,
)
from core.prefill_anatomy import SURFACE_CUDA_WIDTH1, SURFACE_HOST_BATCHED

comptime LAYERS = 28
comptime HIDDEN = 3584
comptime FFN = 18944
comptime Q_HEADS = 28
comptime KV_HEADS = 4
comptime HEAD_DIM = 128
comptime Q_WIDTH = 3584
comptime KV_WIDTH = 512
comptime VOCAB = 152064
comptime PROFILE_CAP = 32768
comptime WEIGHTS = 4683074688
comptime GEN = 128


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "AttentionShare " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("AttentionShare " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("AttentionShare " + what + ": expected false")


def test_endpoints() raises:
    # The split's atoms ARE J-053/J-091's filed
    # figures, reached through the ladder: unit
    # 200,704; projection 6,525,288,448 per token
    # (J-053's Coder figure); head 544,997,376.
    expect_eq(share_attention_unit(LAYERS, Q_WIDTH), 200704, "attention unit")
    expect_eq(
        share_projection_macs_per_token(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN),
        6525288448,
        "projection per token (J-053 filed)",
    )
    expect_eq(share_head_macs(HIDDEN, VOCAB), 544997376, "head pass")
    expect_eq(
        share_rest_prefill_token(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN),
        6525288448,
        "prefill token rest == projections",
    )
    expect_eq(
        share_rest_decode_token(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB),
        7070285824,
        "decode token rest == projections + head",
    )
    expect_eq(
        ladder_kv_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16),
        57344,
        "kv f16 per token (J-087)",
    )
    expect_eq(
        ladder_kv_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8),
        29568,
        "kv int8 per token (J-088)",
    )
    print(
        "PASS: endpoints -- unit 200,704; projection/token 6,525,288,448"
        " == J-053 filed; head 544,997,376; rests 6,525,288,448 (prefill)"
        " / 7,070,285,824 (decode); KV 57,344 f16 / 29,568 int8"
    )


def test_j091_frame_reproduced() raises:
    # VALIDATION GATE: J-091 doc section 5.1's filed
    # columns, reproduced exactly through this
    # module at every rung.
    var attn = [105329459200, 1684038221824, 6735330803712, 26939679047680, 107755427856384]
    var proj = [6681895370752, 26727581483008, 53455162966016, 106910325932032, 213820651864064]
    var wattn = [27937996800, 106858020864, 212084719616, 422538117120, 843444912128]
    for i in range(5):
        var rung = ladder_rung(i)
        expect_eq(
            share_prefill_attention_total(LAYERS, Q_WIDTH, rung),
            attn[i],
            "prefill attention total == J-091 filed",
        )
        expect_eq(
            share_prefill_rest_total(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB, rung),
            proj[i] + 544997376,
            "prefill rest total == J-091 projection + one head",
        )
        expect_eq(
            share_write_attention_total(LAYERS, Q_WIDTH, rung, GEN),
            wattn[i],
            "write attention total == J-091 filed",
        )
        expect_eq(
            share_write_rest_total(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB, GEN),
            7070285824 * 128,
            "write rest total == 128 x decode rest",
        )
    print(
        "PASS: J-091 frame reproduced -- prefill attention, projection"
        " (+head) and write-leg attention totals EXACT at all 5 rungs"
    )


def test_decode_token_split() raises:
    # Token-at-context, decode rest: attention grows
    # linearly, never reaches half at any rung; at
    # the profile cap it is 481,914 ppm (48.19%).
    var attn = [205520896, 822083584, 1644167168, 3288334336, 6576668672]
    var ppm = [28247, 104161, 188671, 317449, 481914]
    var rest = share_rest_decode_token(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB)
    for i in range(5):
        var rung = ladder_rung(i)
        expect_eq(
            share_attention_macs_at_context(LAYERS, Q_WIDTH, rung),
            attn[i],
            "decode attention at rung",
        )
        expect_eq(
            share_ppm(attn[i], rest), ppm[i], "decode share ppm at rung"
        )
        expect_false(
            share_is_at_least_half(attn[i], rest),
            "decode share below half at every rung",
        )
    expect_eq(
        share_ppm(
            share_attention_macs_at_context(LAYERS, Q_WIDTH, PROFILE_CAP),
            rest,
        ),
        481914,
        "decode share at cap 481,914 ppm",
    )
    print(
        "PASS: decode token split -- 28,247 ppm @1024 .. 481,914 ppm"
        " @32768 (48.19% at the cap); below half at every rung"
    )


def test_marginal_and_write_split() raises:
    # Prefill marginal token (rest = projections):
    # crosses exactly at the top rung's neighbourhood
    # -- at 32,768 it is 501,960 ppm, the ladder's
    # only above-half work cell. Write-leg average
    # tracks the decode split, just above it.
    var marg_ppm = [30534, 111888, 201257, 335078, 501960]
    var write_ppm = [29946, 105606, 189856, 318287, 482398]
    var rest_pre = share_rest_prefill_token(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN)
    for i in range(5):
        var rung = ladder_rung(i)
        expect_eq(
            share_ppm(share_attention_macs_at_context(LAYERS, Q_WIDTH, rung), rest_pre),
            marg_ppm[i],
            "marginal share ppm at rung",
        )
        expect_eq(
            share_ppm(
                share_write_attention_total(LAYERS, Q_WIDTH, rung, GEN),
                share_write_rest_total(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB, GEN),
            ),
            write_ppm[i],
            "write-leg average share ppm at rung",
        )
    expect_true(
        share_is_at_least_half(
            share_attention_macs_at_context(LAYERS, Q_WIDTH, 32768), rest_pre
        ),
        "marginal token at 32768 is attention-majority",
    )
    expect_false(
        share_is_at_least_half(
            share_attention_macs_at_context(LAYERS, Q_WIDTH, 16384), rest_pre
        ),
        "marginal token at 16384 is not",
    )
    print(
        "PASS: marginal + write split -- marginal 30,534 ppm @1024 .."
        " 501,960 ppm @32768 (above half only at the top rung);"
        " write-leg average 29,946 .. 482,398 ppm"
    )


def test_prompt_average_split() raises:
    # The prefill leg's headline form: the whole
    # prompt's share is far below the marginal form
    # (early tokens attend to almost nothing) and
    # never reaches half on the ladder.
    var ppm = [15517, 59271, 111899, 201266, 335084]
    for i in range(5):
        var rung = ladder_rung(i)
        expect_eq(
            share_ppm(
                share_prefill_attention_total(LAYERS, Q_WIDTH, rung),
                share_prefill_rest_total(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB, rung),
            ),
            ppm[i],
            "prompt-average share ppm at rung",
        )
        expect_false(
            share_is_at_least_half(
                share_prefill_attention_total(LAYERS, Q_WIDTH, rung),
                share_prefill_rest_total(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB, rung),
            ),
            "prompt average below half at every rung",
        )
    print(
        "PASS: prompt-average split -- 15,517 ppm @1024 .. 335,084 ppm"
        " @32768 (33.51%); below half at every rung"
    )


def test_work_crossings() raises:
    # The three work crossings, exact: marginal at
    # EXACTLY 32,512 (attention == rest there);
    # decode at 35,228 (35,227 is 86,016 MACs short);
    # prompt-average at 65,024 (quadratic search).
    expect_eq(
        share_marginal_crossing_context(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN),
        32512,
        "marginal crossing context",
    )
    var rest_pre = share_rest_prefill_token(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN)
    expect_eq(
        share_attention_macs_at_context(LAYERS, Q_WIDTH, 32512),
        rest_pre,
        "marginal crossing is exact equality",
    )
    expect_eq(
        share_ppm(share_attention_macs_at_context(LAYERS, Q_WIDTH, 32512), rest_pre),
        500000,
        "marginal share at crossing is exactly half",
    )
    expect_eq(
        share_decode_crossing_context(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB),
        35228,
        "decode crossing context",
    )
    var rest_dec = share_rest_decode_token(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB)
    expect_false(
        share_is_at_least_half(
            share_attention_macs_at_context(LAYERS, Q_WIDTH, 35227), rest_dec
        ),
        "decode at 35227 still below half",
    )
    expect_eq(
        rest_dec - share_attention_macs_at_context(LAYERS, Q_WIDTH, 35227),
        86016,
        "decode shortfall at 35227 is 86,016 MACs",
    )
    expect_true(
        share_is_at_least_half(
            share_attention_macs_at_context(LAYERS, Q_WIDTH, 35228), rest_dec
        ),
        "decode at 35228 at or above half",
    )
    expect_eq(
        share_prefill_average_crossing(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB),
        65024,
        "prompt-average crossing length",
    )
    expect_false(
        share_is_at_least_half(
            share_prefill_attention_total(LAYERS, Q_WIDTH, 65023),
            share_prefill_rest_total(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB, 65023),
        ),
        "prompt average at 65023 still below half",
    )
    expect_true(
        share_is_at_least_half(
            share_prefill_attention_total(LAYERS, Q_WIDTH, 65024),
            share_prefill_rest_total(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB, 65024),
        ),
        "prompt average at 65024 at or above half",
    )
    print(
        "PASS: work crossings -- marginal 32,512 (exact equality);"
        " decode 35,228 (86,016 MACs short at 35,227; cap is 32,768);"
        " prompt-average 65,024 (beyond 2x the cap)"
    )


def test_decode_traffic() raises:
    # Bytes, not MACs: a decode token's KV reads vs
    # the weight set read once per token. Weights
    # dominate at every rung at both precisions.
    var kv_f16 = [58720256, 234881024, 469762048, 939524096, 1879048192]
    var ppm_f16 = [12383, 47759, 91165, 167097, 286347]
    var ppm_i8 = [6423, 25209, 49178, 93747, 171424]
    for i in range(5):
        var rung = ladder_rung(i)
        expect_eq(
            share_decode_kv_read_per_token(57344, rung),
            kv_f16[i],
            "decode KV read f16 at rung",
        )
        expect_eq(share_ppm(kv_f16[i], WEIGHTS), ppm_f16[i], "decode traffic f16 ppm")
        expect_eq(
            share_ppm(share_decode_kv_read_per_token(29568, rung), WEIGHTS),
            ppm_i8[i],
            "decode traffic int8 ppm",
        )
        expect_false(
            share_is_at_least_half(kv_f16[i], WEIGHTS),
            "weights dominate decode traffic at every rung",
        )
    expect_eq(
        share_decode_traffic_crossing_context(57344, WEIGHTS),
        81667,
        "decode traffic crossing f16",
    )
    expect_eq(
        share_decode_traffic_crossing_context(29568, WEIGHTS),
        158384,
        "decode traffic crossing int8",
    )
    print(
        "PASS: decode traffic -- f16 12,383 ppm @1024 .. 286,347 ppm"
        " @32768, crossing 81,667; int8 6,423 .. 171,424 ppm,"
        " crossing 158,384 (weights dominate throughout the ladder)"
    )


def test_prefill_traffic() raises:
    # The one line-dependent split: host batched
    # (cap 256) amortizes weights over chunks, GPU
    # Coder prefill is width-1. Filed per surface and
    # precision, shapes at the rungs pinned.
    var host_f16 = [616349, 865255, 927752, 962520, 980901]
    var gpu_f16 = [6236, 24469, 47765, 91170, 167102]
    var host_i8 = [453064, 768038, 868788, 929784, 963613]
    var gpu_i8 = [3225, 12768, 25212, 49181, 93750]
    for i in range(5):
        var rung = ladder_rung(i)
        var shape_f16 = share_prefill_kv_shape_bytes(57344, rung)
        var shape_i8 = share_prefill_kv_shape_bytes(29568, rung)
        var host_w = share_prefill_weight_pass_bytes(SURFACE_HOST_BATCHED, rung, WEIGHTS)
        var gpu_w = share_prefill_weight_pass_bytes(SURFACE_CUDA_WIDTH1, rung, WEIGHTS)
        expect_eq(host_w, (rung // 256) * WEIGHTS, "host weight passes at rung")
        expect_eq(gpu_w, rung * WEIGHTS, "gpu width-1 weight passes at rung")
        expect_eq(share_ppm(shape_f16, host_w), host_f16[i], "prefill traffic host f16 ppm")
        expect_eq(share_ppm(shape_f16, gpu_w), gpu_f16[i], "prefill traffic gpu f16 ppm")
        expect_eq(share_ppm(shape_i8, host_w), host_i8[i], "prefill traffic host int8 ppm")
        expect_eq(share_ppm(shape_i8, gpu_w), gpu_i8[i], "prefill traffic gpu int8 ppm")
    print(
        "PASS: prefill traffic at rungs -- host f16 616,349 ppm @1024"
        " .. 980,901 @32768 vs GPU width-1 6,236 .. 167,102 ppm;"
        " host int8 453,064 .. 963,613; GPU int8 3,225 .. 93,750 ppm"
    )


def test_prefill_traffic_crossings() raises:
    # Sawtooth on the host form (chunk-boundary pass
    # jumps): f16 first 700, re-dip at 769, permanent
    # 808; int8 first 1,259, re-dip at 1,281,
    # permanent 1,379. GPU width-1 form is monotone:
    # single crossings far beyond the cap.
    expect_eq(
        share_prefill_traffic_first_crossing(SURFACE_HOST_BATCHED, 57344, WEIGHTS),
        700,
        "host f16 first crossing",
    )
    expect_eq(
        share_prefill_traffic_permanent_crossing_host(57344, WEIGHTS),
        808,
        "host f16 permanent crossing",
    )
    expect_false(
        share_is_at_least_half(
            share_prefill_kv_shape_bytes(57344, 769),
            share_prefill_weight_pass_bytes(SURFACE_HOST_BATCHED, 769, WEIGHTS),
        ),
        "host f16 re-dip at 769 (pass jump 3 -> 4)",
    )
    expect_eq(
        share_prefill_traffic_first_crossing(SURFACE_HOST_BATCHED, 29568, WEIGHTS),
        1259,
        "host int8 first crossing",
    )
    expect_eq(
        share_prefill_traffic_permanent_crossing_host(29568, WEIGHTS),
        1379,
        "host int8 permanent crossing",
    )
    expect_false(
        share_is_at_least_half(
            share_prefill_kv_shape_bytes(29568, 1281),
            share_prefill_weight_pass_bytes(SURFACE_HOST_BATCHED, 1281, WEIGHTS),
        ),
        "host int8 re-dip at 1281 (pass jump 5 -> 6)",
    )
    expect_eq(
        share_prefill_traffic_first_crossing(SURFACE_CUDA_WIDTH1, 57344, WEIGHTS),
        163332,
        "gpu width-1 f16 crossing",
    )
    expect_eq(
        share_prefill_traffic_first_crossing(SURFACE_CUDA_WIDTH1, 29568, WEIGHTS),
        316766,
        "gpu width-1 int8 crossing",
    )
    print(
        "PASS: prefill traffic crossings -- host f16 first 700 /"
        " permanent 808 (re-dip at 769); host int8 first 1,259 /"
        " permanent 1,379 (re-dip at 1,281); GPU width-1 163,332"
        " (f16) / 316,766 (int8), monotone, beyond any runnable length"
    )


def test_refusals() raises:
    var refused = 0
    try:
        _ = share_attention_unit(0, Q_WIDTH)
    except:
        refused += 1
    try:
        _ = share_attention_macs_at_context(LAYERS, Q_WIDTH, 0)
    except:
        refused += 1
    try:
        _ = share_ppm(-1, 100)
    except:
        refused += 1
    try:
        _ = share_ppm(100, 0)
    except:
        refused += 1
    try:
        _ = share_decode_kv_read_per_token(0, 1024)
    except:
        refused += 1
    try:
        _ = share_decode_traffic_crossing_context(57344, 0)
    except:
        refused += 1
    try:
        _ = share_prefill_kv_shape_bytes(0, 1024)
    except:
        refused += 1
    try:
        _ = share_prefill_weight_pass_bytes(SURFACE_HOST_BATCHED, 1024, 0)
    except:
        refused += 1
    try:
        _ = share_prefill_weight_pass_bytes(99, 1024, WEIGHTS)
    except:
        refused += 1
    try:
        _ = share_write_rest_total(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, VOCAB, 0)
    except:
        refused += 1
    expect_eq(refused, 10, "refusal count")
    print(
        "PASS: refusals -- zero shape/context/price/weights, negative"
        " share inputs, unknown surface, zero gen length"
    )


def main() raises:
    test_endpoints()
    test_j091_frame_reproduced()
    test_decode_token_split()
    test_marginal_and_write_split()
    test_prompt_average_split()
    test_work_crossings()
    test_decode_traffic()
    test_prefill_traffic()
    test_prefill_traffic_crossings()
    test_refusals()
    print("ALL PASS: attention share (10 groups)")
