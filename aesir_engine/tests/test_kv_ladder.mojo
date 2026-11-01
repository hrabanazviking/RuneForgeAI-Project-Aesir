"""Context ladder accounting (J-091): the ladder frame
for the dense mid-size witness (Qwen2.5-Coder-7B:
28 layers, hidden 3584, ffn 18944, 28 query heads,
4 kv heads, head_dim 128, vocab 152064, profile cap
32768) -- KV prices reproducing J-087's census and
J-088's store exactly, work counts reproducing
J-053's prefill anatomy at 8192 exactly, decode
traffic on the context sum, the pre-registered cell
verdicts (host cap, profile cap, integration judged
first), and the GPU admission arithmetic reproducing
the filed 16384 whole-model refusal total within its
stated 4-byte residual. No wall, no speed, no live
run claimed here: the ladder's walls are deferred to
the J-098 gate recipe in the J-091 doc.
"""
from core.kv_account import kv_bytes_per_token
from core.kv_int8 import kv8_bytes_per_token
from core.kv_ladder import (
    LADDER_ACCOUNTED,
    LADDER_CAP_REFUSED,
    LADDER_GEN_TOKENS,
    LADDER_GPU_SPILL,
    LADDER_GPU_WHOLE,
    LADDER_INTEGRATION_BLOCKED,
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
    ladder_gpu_required_bytes,
    ladder_head_macs,
    ladder_kv_bytes_per_token,
    ladder_kv_total,
    ladder_prefill_attention_macs,
    ladder_prefill_pairs,
    ladder_prefill_projection_macs,
    ladder_rung,
    ladder_session_context,
    ladder_verdict_name,
)

# The witness shape (core/dense_gqa_profile.mojo
# qwen2_coder_7b_profile) and the GPU line's filed
# machine facts (J-031 usable VRAM; GPU_2060_STATE
# device weights for the sha-pinned Q4_K_M file).
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
comptime USABLE = 5368709120
comptime ACT_FIXED = 208896
comptime ACT_PER_CONTEXT = 28
comptime SAMPLING = 905728


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "KVLadder " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def test_rungs_and_per_token() raises:
    expect_eq(LADDER_RUNG_COUNT, 5, "rung count")
    expect_eq(ladder_rung(0), 1024, "rung 0")
    expect_eq(ladder_rung(1), 4096, "rung 1")
    expect_eq(ladder_rung(2), 8192, "rung 2")
    expect_eq(ladder_rung(3), 16384, "rung 3")
    expect_eq(ladder_rung(4), 32768, "rung 4")
    expect_eq(LADDER_GEN_TOKENS, 128, "write leg length")
    # Per-token endpoints ARE J-087's census and
    # J-088's store prices, not new numbers.
    expect_eq(
        ladder_kv_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16),
        57344,
        "Coder f16 per token (J-087)",
    )
    expect_eq(
        ladder_kv_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16),
        kv_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM, 2),
        "f16 endpoint == kv_account",
    )
    expect_eq(
        ladder_kv_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8),
        29568,
        "Coder int8 per token (J-088)",
    )
    expect_eq(
        ladder_kv_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8),
        kv8_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM),
        "int8 endpoint == kv_int8",
    )
    print(
        "PASS: rungs + per-token -- 1024/4096/8192/16384/32768, gen 128;"
        " f16 57,344 == J-087 census, int8 29,568 == J-088 store"
    )


def test_kv_totals() raises:
    # The ladder's KV column, both precisions, every
    # rung (exact arithmetic; @8192 f16 is J-087
    # section 4.1's filed Coder total 469,762,048).
    expect_eq(ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, 1024), 58720256, "kv f16 @1024")
    expect_eq(ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, 4096), 234881024, "kv f16 @4096")
    expect_eq(ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, 8192), 469762048, "kv f16 @8192 (J-087 filed)")
    expect_eq(ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, 16384), 939524096, "kv f16 @16384")
    expect_eq(ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, 32768), 1879048192, "kv f16 @32768")
    expect_eq(ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8, 1024), 30277632, "kv int8 @1024")
    expect_eq(ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8, 4096), 121110528, "kv int8 @4096")
    expect_eq(ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8, 8192), 242221056, "kv int8 @8192")
    expect_eq(ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8, 16384), 484442112, "kv int8 @16384")
    expect_eq(ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8, 32768), 968884224, "kv int8 @32768")
    print(
        "PASS: KV totals -- f16 58,720,256 .. 1,879,048,192 and int8"
        " 30,277,632 .. 968,884,224 across the rungs (@8192 f16 == J-087 filed)"
    )


def test_work_frame() raises:
    # By-construction work counts through J-053's
    # account: @8192 the attention MACs reproduce
    # J-053's Coder row (6,735,330,803,712) and the
    # projection total reproduces J-068's filed Coder
    # figure (53,455,162,966,016) exactly.
    expect_eq(ladder_prefill_pairs(1024), 524800, "pairs @1024")
    expect_eq(ladder_prefill_pairs(32768), 536887296, "pairs @32768")
    expect_eq(
        ladder_prefill_attention_macs(LAYERS, Q_WIDTH, 8192),
        6735330803712,
        "attention MACs @8192 (J-053 filed)",
    )
    expect_eq(
        ladder_prefill_attention_macs(LAYERS, Q_WIDTH, 1024),
        105329459200,
        "attention MACs @1024",
    )
    expect_eq(
        ladder_prefill_projection_macs(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, 8192),
        53455162966016,
        "projection MACs @8192 (J-068 filed)",
    )
    expect_eq(
        ladder_prefill_projection_macs(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, 1024),
        6681895370752,
        "projection MACs @1024",
    )
    expect_eq(ladder_head_macs(HIDDEN, VOCAB), 544997376, "LM head MACs x1")
    print(
        "PASS: work frame -- pairs, attention MACs @8192 == J-053 filed,"
        " projection @8192 == J-068 filed, head 544,997,376"
    )


def test_decode_traffic() raises:
    # The write leg (128 tokens) priced on the context
    # sum: traffic and attention grow with the rung.
    expect_eq(ladder_decode_context_sum(1024, 128), 139200, "context sum @1024")
    expect_eq(ladder_decode_context_sum(8192, 128), 1056704, "context sum @8192")
    expect_eq(ladder_decode_context_sum(32768, 128), 4202432, "context sum @32768")
    expect_eq(ladder_decode_kv_read_bytes(57344, 1024, 128), 7982284800, "decode KV read f16 @1024")
    expect_eq(ladder_decode_kv_read_bytes(29568, 1024, 128), 4115865600, "decode KV read int8 @1024")
    expect_eq(ladder_decode_kv_read_bytes(57344, 32768, 128), 240984260608, "decode KV read f16 @32768")
    expect_eq(ladder_decode_kv_read_bytes(29568, 32768, 128), 124257509376, "decode KV read int8 @32768")
    expect_eq(
        ladder_decode_attention_macs(LAYERS, Q_WIDTH, 8192, 128),
        212084719616,
        "decode attention MACs @8192",
    )
    print(
        "PASS: decode traffic -- context sums pinned; KV read f16"
        " 7,982,284,800 @1024 .. 240,984,260,608 @32768 (int8 roughly half)"
    )


def test_cpu_verdicts() raises:
    # CPU line, f16 (the shipping precision): the host
    # generation path's 16000 allocation cap refuses
    # the 16384 and 32768 rungs in both directions;
    # the lower rungs are ACCOUNTED (walls deferred).
    for i in range(3):
        var rung = ladder_rung(i)
        expect_eq(
            ladder_cell_verdict(LADDER_LINE_CPU, LADDER_PRECISION_F16, rung, LADDER_READ, False, False, PROFILE_CAP),
            LADDER_ACCOUNTED,
            "cpu f16 read accounted",
        )
        expect_eq(
            ladder_cell_verdict(LADDER_LINE_CPU, LADDER_PRECISION_F16, rung, LADDER_WRITE, False, False, PROFILE_CAP),
            LADDER_ACCOUNTED,
            "cpu f16 write accounted",
        )
    for i in range(3, 5):
        var rung = ladder_rung(i)
        expect_eq(
            ladder_cell_verdict(LADDER_LINE_CPU, LADDER_PRECISION_F16, rung, LADDER_READ, False, False, PROFILE_CAP),
            LADDER_CAP_REFUSED,
            "cpu f16 read cap-refused above 16000",
        )
        expect_eq(
            ladder_cell_verdict(LADDER_LINE_CPU, LADDER_PRECISION_F16, rung, LADDER_WRITE, False, False, PROFILE_CAP),
            LADDER_CAP_REFUSED,
            "cpu f16 write cap-refused above 16000",
        )
    expect_eq(ladder_session_context(8192, LADDER_WRITE), 8320, "write session context")
    expect_eq(ladder_session_context(8192, LADDER_READ), 8192, "read session context")
    if ladder_verdict_name(LADDER_CAP_REFUSED) != String("CAP_REFUSED"):
        raise Error("KVLadder: CAP_REFUSED name")
    print(
        "PASS: CPU verdicts -- f16 ACCOUNTED at 1024/4096/8192,"
        " CAP_REFUSED at 16384/32768 (host cap 16000), both directions"
    )


def test_gpu_and_int8_verdicts() raises:
    # GPU line, f16: reads admitted at every rung (the
    # profile cap is 32768); the 32768 WRITE needs a
    # 32896 session context and is CAP_REFUSED as
    # defined (the live recipe's cap-adjusted form is
    # the doc's, section 7).
    for i in range(5):
        var rung = ladder_rung(i)
        expect_eq(
            ladder_cell_verdict(LADDER_LINE_GPU, LADDER_PRECISION_F16, rung, LADDER_READ, False, False, PROFILE_CAP),
            LADDER_ACCOUNTED,
            "gpu f16 read accounted",
        )
    for i in range(4):
        var rung = ladder_rung(i)
        expect_eq(
            ladder_cell_verdict(LADDER_LINE_GPU, LADDER_PRECISION_F16, rung, LADDER_WRITE, False, False, PROFILE_CAP),
            LADDER_ACCOUNTED,
            "gpu f16 write accounted",
        )
    expect_eq(
        ladder_cell_verdict(LADDER_LINE_GPU, LADDER_PRECISION_F16, 32768, LADDER_WRITE, False, False, PROFILE_CAP),
        LADDER_CAP_REFUSED,
        "gpu f16 write @32768 cap-refused (32896 > 32768)",
    )
    # int8 on either line, as the tree stands
    # (integrated nowhere): INTEGRATION_BLOCKED at
    # every rung and direction -- judged BEFORE caps.
    for line in [LADDER_LINE_CPU, LADDER_LINE_GPU]:
        for i in range(5):
            var rung = ladder_rung(i)
            for direction in [LADDER_READ, LADDER_WRITE]:
                expect_eq(
                    ladder_cell_verdict(line, LADDER_PRECISION_INT8, rung, direction, False, False, PROFILE_CAP),
                    LADDER_INTEGRATION_BLOCKED,
                    "int8 blocked while unintegrated",
                )
    # The ordering, proven with the hypothetical
    # integrated facts: caps then bind exactly as f16's.
    expect_eq(
        ladder_cell_verdict(LADDER_LINE_CPU, LADDER_PRECISION_INT8, 8192, LADDER_READ, True, False, PROFILE_CAP),
        LADDER_ACCOUNTED,
        "int8 cpu @8192 if integrated",
    )
    expect_eq(
        ladder_cell_verdict(LADDER_LINE_CPU, LADDER_PRECISION_INT8, 16384, LADDER_READ, True, False, PROFILE_CAP),
        LADDER_CAP_REFUSED,
        "int8 cpu @16384 if integrated (cap binds second)",
    )
    print(
        "PASS: GPU + int8 verdicts -- gpu f16 reads all ACCOUNTED, write"
        " @32768 CAP_REFUSED; int8 INTEGRATION_BLOCKED everywhere as the"
        " tree stands, caps binding only behind integration"
    )


def test_gpu_admission() raises:
    # Admission arithmetic at each rung's session
    # context (rung + 128), f16 (the shipping device
    # precision): whole-GPU through 8192, spill from
    # 16384. The int8 counterfactual (same admission
    # shape, J-088 prices) would hold 16384 whole.
    expect_eq(
        ladder_gpu_required_bytes(WEIGHTS, 57344, 1152, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING),
        4751005312,
        "gpu required @1152",
    )
    expect_eq(
        ladder_gpu_required_bytes(WEIGHTS, 57344, 4224, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING),
        4927510144,
        "gpu required @4224",
    )
    expect_eq(
        ladder_gpu_required_bytes(WEIGHTS, 57344, 8320, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING),
        5162849920,
        "gpu required @8320",
    )
    expect_eq(
        ladder_gpu_required_bytes(WEIGHTS, 57344, 16512, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING),
        5633529472,
        "gpu required @16512",
    )
    expect_eq(
        ladder_gpu_placement(5162849920, USABLE), LADDER_GPU_WHOLE, "placement @8320 whole"
    )
    expect_eq(
        ladder_gpu_placement(5633529472, USABLE), LADDER_GPU_SPILL, "placement @16512 spill"
    )
    # The cross-check against the filed refusal: at a
    # pure 16384 context the arithmetic gives
    # 5,626,175,104 -- the filed whole-model refusal
    # total is 5,626,175,108 (GPU_2060_STATE); the
    # 4-byte residual is the filed run's per-run
    # device-weight detail, stated in the header.
    expect_eq(
        ladder_gpu_required_bytes(WEIGHTS, 57344, 16384, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING),
        5626175104,
        "gpu required @16384 (filed refusal within 4 B)",
    )
    expect_eq(
        ladder_gpu_required_bytes(WEIGHTS, 29568, 16512, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING),
        5174892160,
        "gpu required int8 counterfactual @16512",
    )
    expect_eq(
        ladder_gpu_placement(5174892160, USABLE),
        LADDER_GPU_WHOLE,
        "int8 counterfactual would hold 16384 whole",
    )
    expect_eq(
        ladder_gpu_required_bytes(WEIGHTS, 29568, 32896, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING),
        5661169280,
        "gpu required int8 counterfactual @32896",
    )
    expect_eq(
        ladder_gpu_placement(5661169280, USABLE),
        LADDER_GPU_SPILL,
        "int8 counterfactual still spills at 32768 session",
    )
    print(
        "PASS: GPU admission -- required 4,751,005,312 @1152 .."
        " 5,633,529,472 @16512; WHOLE through 8192, SPILL from 16384;"
        " @16384 pure context reproduces the filed refusal within 4 B;"
        " int8 counterfactual holds 16384 whole, still spills at 32768"
    )


def test_refusals() raises:
    var refused = 0
    try:
        _ = ladder_rung(5)
    except:
        refused += 1
    try:
        _ = ladder_kv_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM, 9)
    except:
        refused += 1
    try:
        _ = ladder_kv_total(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, 0)
    except:
        refused += 1
    try:
        _ = ladder_kv_bytes_per_token(0, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16)
    except:
        refused += 1
    try:
        _ = ladder_decode_context_sum(1024, 0)
    except:
        refused += 1
    try:
        _ = ladder_cell_verdict(9, LADDER_PRECISION_F16, 1024, LADDER_READ, False, False, PROFILE_CAP)
    except:
        refused += 1
    try:
        _ = ladder_cell_verdict(LADDER_LINE_CPU, LADDER_PRECISION_F16, 1024, 9, False, False, PROFILE_CAP)
    except:
        refused += 1
    try:
        _ = ladder_gpu_required_bytes(0, 57344, 1152, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING)
    except:
        refused += 1
    try:
        _ = ladder_gpu_placement(0, USABLE)
    except:
        refused += 1
    expect_eq(refused, 9, "refusal count")
    print(
        "PASS: refusals -- rung index, unknown precision/line/direction,"
        " zero shape/context/gen, invalid admission and placement inputs"
    )


def main() raises:
    test_rungs_and_per_token()
    test_kv_totals()
    test_work_frame()
    test_decode_traffic()
    test_cpu_verdicts()
    test_gpu_and_int8_verdicts()
    test_gpu_admission()
    test_refusals()
    print("ALL PASS: kv ladder (8 groups)")
