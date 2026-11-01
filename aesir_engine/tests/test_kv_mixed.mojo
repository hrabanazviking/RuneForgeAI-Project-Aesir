"""Mixed-precision KV layouts (J-090): candidate prices
defined through J-087's census and J-088's store
accounting (endpoints pinned to both), the candidate
table for the 8B and Qwen3-0.6B shapes, the per-channel
break-even identity, and the pre-registered keep rule in
mechanical form -- including its price boundary, where
upgrading half the layers costs exactly half the saving
and is therefore NOT kept even under indictment. No
store, no wall, no speed claimed here: the verdict's
measured inputs come from the J-090 concentration
harness, filed separately.
"""
from core.kv_account import kv_int8_projected_per_token
from core.kv_int8 import (
    kv8_bytes_per_token,
    kv8_per_channel_total_bytes,
)
from core.kv_mixed import (
    MIXED_KEPT,
    MIXED_NOT_KEPT_NO_INDICTMENT,
    MIXED_NOT_KEPT_NOT_RESTORED,
    MIXED_NOT_KEPT_PRICE,
    mixed_bytes_per_token,
    mixed_heads_bytes_per_token,
    mixed_keep_verdict,
    mixed_layers_bytes_per_token,
    mixed_overhead_vs_int8_per_token,
    mixed_pair_delta_bytes,
    mixed_saving_vs_f16_per_token,
    mixed_total_bytes,
    mixed_verdict_name,
    per_channel_break_even_context,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "KVMixed " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def test_endpoints_reproduce_uniforms() raises:
    # Zero upgrades IS J-088's uniform int8, mechanically
    # (and through it, J-087's projection); all upgrades
    # IS the f16 census price. Three shapes.
    expect_eq(mixed_bytes_per_token(32, 8, 128, 0, 0), 67584, "8B int8 endpoint")
    expect_eq(
        mixed_bytes_per_token(32, 8, 128, 0, 0),
        kv8_bytes_per_token(32, 8, 128),
        "8B int8 endpoint == kv_int8",
    )
    expect_eq(
        mixed_bytes_per_token(32, 8, 128, 0, 0),
        kv_int8_projected_per_token(32, 8, 128, 4),
        "8B int8 endpoint == J-087 projection",
    )
    expect_eq(mixed_bytes_per_token(32, 8, 128, 256, 256), 131072, "8B f16 endpoint")
    expect_eq(mixed_bytes_per_token(28, 8, 128, 0, 0), 59136, "0.6B int8 endpoint")
    expect_eq(mixed_bytes_per_token(28, 8, 128, 224, 224), 114688, "0.6B f16 endpoint")
    expect_eq(mixed_bytes_per_token(28, 4, 128, 0, 0), 29568, "Coder int8 endpoint")
    expect_eq(mixed_bytes_per_token(16, 32, 64, 0, 0), 69632, "OLMoE int8 endpoint")
    expect_eq(mixed_bytes_per_token(16, 32, 64, 512, 512), 131072, "OLMoE f16 endpoint")
    print(
        "PASS: endpoints -- zero upgrades == J-088 int8 == J-087 projection;"
        " all upgrades == f16 census (8B / 0.6B / Coder / OLMoE)"
    )


def test_candidate_prices_8b() raises:
    # The J-090 candidate table (doc section 3), 8B shape
    # (32 layers x 8 kv-heads x 128). Delta per upgraded
    # tensor row-pair set is pinned first.
    expect_eq(mixed_pair_delta_bytes(128), 124, "pair delta at head_dim 128")
    expect_eq(mixed_pair_delta_bytes(64), 60, "pair delta at head_dim 64")
    expect_eq(mixed_layers_bytes_per_token(32, 8, 128, 1), 69568, "first layer f16")
    expect_eq(mixed_layers_bytes_per_token(32, 8, 128, 2), 71552, "first+last f16")
    expect_eq(mixed_heads_bytes_per_token(32, 8, 128, 1), 75520, "one head f16")
    expect_eq(mixed_layers_bytes_per_token(32, 8, 128, 16), 99328, "half layers f16")
    expect_eq(mixed_bytes_per_token(32, 8, 128, 256, 0), 99328, "K only f16")
    expect_eq(mixed_bytes_per_token(32, 8, 128, 0, 256), 99328, "V only f16")
    # K-only and V-only are additive and symmetric: their
    # sum is int8 + f16 exactly.
    expect_eq(
        mixed_bytes_per_token(32, 8, 128, 256, 0)
        + mixed_bytes_per_token(32, 8, 128, 0, 256),
        67584 + 131072,
        "K-only + V-only == int8 + f16",
    )
    # Monotone: each further upgraded layer costs the
    # same delta, never less, never more.
    var prev = mixed_layers_bytes_per_token(32, 8, 128, 0)
    for n in range(1, 33):
        var cur = mixed_layers_bytes_per_token(32, 8, 128, n)
        expect_eq(cur - prev, 1984, "per-layer step is constant")
        prev = cur
    expect_eq(prev, 131072, "32 layers upgraded == f16")
    # Totals at the 8B profile cap.
    expect_eq(mixed_total_bytes(32, 8, 128, 8, 8, 8192), 569901056, "first-layer total at 8192")
    expect_eq(mixed_total_bytes(32, 8, 128, 0, 0, 8192), 553648128, "int8 total at 8192")
    print(
        "PASS: candidate prices (8B) -- first layer 69,568; first+last 71,552;"
        " one head 75,520; half layers / K-only / V-only 99,328 B/token"
    )


def test_candidate_prices_second_shape() raises:
    # Qwen3 0.6B (28 x 8 x 128) -- the J-089 section 7
    # live-recipe model, priced so a later live
    # indictment is judged against filed numbers.
    expect_eq(mixed_layers_bytes_per_token(28, 8, 128, 1), 61120, "0.6B first layer")
    expect_eq(mixed_heads_bytes_per_token(28, 8, 128, 1), 66080, "0.6B one head")
    expect_eq(mixed_total_bytes(28, 8, 128, 0, 0, 32768), 1937768448, "0.6B int8 total at cap")
    expect_eq(mixed_total_bytes(28, 8, 128, 8, 8, 32768), 2002780160, "0.6B first-layer total at cap")
    # Overhead / saving split for the cheapest candidate.
    expect_eq(mixed_overhead_vs_int8_per_token(32, 8, 128, 8, 8), 1984, "first-layer overhead")
    expect_eq(mixed_saving_vs_f16_per_token(32, 8, 128, 8, 8), 61504, "first-layer saving kept")
    print(
        "PASS: candidate prices (Qwen3 0.6B) -- int8 59,136; first layer 61,120;"
        " one head 66,080 B/token; overhead/saving split closes"
    )


def test_per_channel_break_even() raises:
    # Break-even is exactly head_dim tokens, every shape,
    # and at that context the two totals agree byte for
    # byte; past it per-channel is cheaper, before it
    # per-row is.
    expect_eq(per_channel_break_even_context(32, 8, 128), 128, "8B break-even")
    expect_eq(per_channel_break_even_context(16, 32, 64), 64, "OLMoE break-even")
    expect_eq(
        kv8_per_channel_total_bytes(32, 8, 128, 128),
        8650752,
        "per-channel total at break-even",
    )
    expect_eq(
        mixed_total_bytes(32, 8, 128, 0, 0, 128),
        8650752,
        "per-row total at break-even (agrees)",
    )
    if not kv8_per_channel_total_bytes(32, 8, 128, 8192) < mixed_total_bytes(
        32, 8, 128, 0, 0, 8192
    ):
        raise Error("KVMixed: per-channel must win at 8192")
    expect_eq(
        mixed_total_bytes(32, 8, 128, 0, 0, 8192)
        - kv8_per_channel_total_bytes(32, 8, 128, 8192),
        16515072,
        "per-channel saving at 8192",
    )
    if not kv8_per_channel_total_bytes(32, 8, 128, 1) > mixed_total_bytes(
        32, 8, 128, 0, 0, 1
    ):
        raise Error("KVMixed: per-row must win at 1 token")
    print(
        "PASS: per-channel break-even -- exactly head_dim tokens (128 / 64);"
        " totals agree there; per-channel saves 16,515,072 B at 8,192"
    )


def test_keep_verdict_mechanics() raises:
    # The pre-registered rule (module header R1-R3), each
    # conjunct isolated. Prices: 8B int8 67,584 / f16
    # 131,072; first-layer candidate 69,568 (cheap);
    # half-layers candidate 99,328 (the boundary).
    expect_eq(
        mixed_keep_verdict(False, True, 69568, 67584, 131072),
        MIXED_NOT_KEPT_NO_INDICTMENT,
        "no indictment -> NOT KEPT however cheap",
    )
    expect_eq(
        mixed_keep_verdict(False, False, 69568, 67584, 131072),
        MIXED_NOT_KEPT_NO_INDICTMENT,
        "indictment is judged before restoration",
    )
    expect_eq(
        mixed_keep_verdict(True, False, 69568, 67584, 131072),
        MIXED_NOT_KEPT_NOT_RESTORED,
        "indicted but unrestored -> NOT KEPT",
    )
    expect_eq(
        mixed_keep_verdict(True, True, 69568, 67584, 131072),
        MIXED_KEPT,
        "indicted + restored + cheap -> KEPT",
    )
    # The price boundary, pinned exactly: half the
    # layers costs overhead 31,744; twice it EQUALS the
    # saving 63,488; R3 demands strictly less, so the
    # boundary candidate is NOT kept on price.
    expect_eq(
        mixed_keep_verdict(True, True, 99328, 67584, 131072),
        MIXED_NOT_KEPT_PRICE,
        "overhead == half the saving -> NOT KEPT on price (strict)",
    )
    if mixed_verdict_name(MIXED_KEPT) != String("KEPT"):
        raise Error("KVMixed: KEPT name")
    if mixed_verdict_name(MIXED_NOT_KEPT_NO_INDICTMENT) != String(
        "NOT_KEPT_NO_INDICTMENT"
    ):
        raise Error("KVMixed: no-indictment name")
    print(
        "PASS: keep verdict -- no-indictment / not-restored / price-boundary"
        " all NOT KEPT; indicted+restored+cheap KEPT"
    )


def test_refusals() raises:
    var refused = 0
    try:
        _ = mixed_bytes_per_token(32, 8, 128, -1, 0)
    except:
        refused += 1
    try:
        _ = mixed_bytes_per_token(32, 8, 128, 0, 257)
    except:
        refused += 1
    try:
        _ = mixed_bytes_per_token(0, 8, 128, 0, 0)
    except:
        refused += 1
    try:
        _ = mixed_pair_delta_bytes(4)
    except:
        refused += 1
    try:
        _ = mixed_layers_bytes_per_token(32, 8, 128, 33)
    except:
        refused += 1
    try:
        _ = mixed_heads_bytes_per_token(32, 8, 128, 9)
    except:
        refused += 1
    try:
        _ = mixed_keep_verdict(True, True, 67584, 67584, 131072)
    except:
        refused += 1
    try:
        _ = mixed_keep_verdict(True, True, 131072, 67584, 131072)
    except:
        refused += 1
    try:
        _ = mixed_keep_verdict(True, True, 69568, 131072, 67584)
    except:
        refused += 1
    try:
        _ = mixed_total_bytes(32, 8, 128, 0, 0, 0)
    except:
        refused += 1
    expect_eq(refused, 10, "refusal count")
    print(
        "PASS: refusals -- pair counts out of range, zero layers, degenerate"
        " head_dim, layer/head counts out of range, endpoint candidates and"
        " inverted uniforms in the verdict, zero context"
    )


def main() raises:
    test_endpoints_reproduce_uniforms()
    test_candidate_prices_8b()
    test_candidate_prices_second_shape()
    test_per_channel_break_even()
    test_keep_verdict_mechanics()
    test_refusals()
    print("ALL PASS: kv mixed (6 groups)")
