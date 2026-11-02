"""8-bit KV (J-088): the int8 store priced against J-087's
census, the quantizer's round-trip bounds, quantize-on-
append / dequantize-inside-attention exercised at module
level, and the --kv-precision / --kv-scale option surface
(scan / env-shape / resolve / refusals). No live session,
no wall, no speed claimed here -- the bench harness files
the measured numbers separately.
"""
from core.kv_account import kv_int8_projected_per_token
from core.kv_int8 import (
    KV8_PRECISION_F16,
    KV8_PRECISION_INT8,
    KV8_SCALE_PER_CHANNEL,
    KV8_SCALE_PER_ROW,
    KV8_SOURCE_CLI,
    KV8_SOURCE_DEFAULT,
    KV8_SOURCE_ENV,
    Int8KVStore,
    RawKvInputs,
    attention_f32_head,
    attention_int8_head,
    kv8_bytes_per_token,
    kv8_dequantize,
    kv8_payload_per_token,
    kv8_per_channel_total_bytes,
    kv8_precision_code,
    kv8_precision_name,
    kv8_quantize,
    kv8_row_scale,
    kv8_saving_vs_f16_per_token,
    kv8_saving_vs_f32_per_token,
    kv8_scale_code,
    kv8_scales_per_token,
    kv8_total_bytes,
    resolve_kv_precision,
    scan_kv_args,
    validate_kv8_selection,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "KVInt8 " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_close(actual: Float32, expected: Float32, tol: Float32, what: String) raises:
    var d = actual - expected
    if d < Float32(0):
        d = -d
    if d > tol:
        raise Error("KVInt8 " + what + ": deviation too large")


def synth(i: Int) -> Float32:
    """Deterministic synthetic values in [-1, 1]."""
    return Float32((i * 37) % 17 - 8) / Float32(8.0)


def test_codes() raises:
    expect_eq(kv8_precision_code("f16"), KV8_PRECISION_F16, "f16 code")
    expect_eq(kv8_precision_code("int8"), KV8_PRECISION_INT8, "int8 code")
    expect_eq(kv8_scale_code("per-row"), KV8_SCALE_PER_ROW, "per-row code")
    expect_eq(kv8_scale_code("per-channel"), KV8_SCALE_PER_CHANNEL, "per-channel code")
    if kv8_precision_name(KV8_PRECISION_INT8) != String("int8"):
        raise Error("KVInt8: int8 name")
    print("PASS: codes -- f16 beside int8; scale modes per-row (built) and per-channel (priced)")


def test_accounting_reproduces_j087() raises:
    # The grading identity: J-087 section 7's projection for
    # the Llama 3 8B shape, reproduced mechanically.
    expect_eq(kv8_bytes_per_token(32, 8, 128), 67584, "8B int8 per-token")
    expect_eq(kv8_bytes_per_token(32, 8, 128), kv_int8_projected_per_token(32, 8, 128, 4), "8B == J-087 projection function")
    expect_eq(kv8_payload_per_token(32, 8, 128), 65536, "8B payload")
    expect_eq(kv8_scales_per_token(32, 8), 2048, "8B scales per token")
    expect_eq(kv8_saving_vs_f16_per_token(32, 8, 128), 63488, "8B saving vs f16 (131072-67584)")
    expect_eq(kv8_saving_vs_f32_per_token(32, 8, 128), 194560, "8B-shape saving vs f32 (262144-67584)")
    expect_eq(kv8_bytes_per_token(28, 8, 128), 59136, "3B/Qwen3-0.6B int8 per-token")
    expect_eq(kv8_bytes_per_token(28, 4, 128), 29568, "Coder int8 per-token")
    expect_eq(kv8_bytes_per_token(16, 32, 64), 69632, "OLMoE int8 per-token (kv_dim 2048 as 32x64)")
    expect_eq(kv8_total_bytes(32, 8, 128, 8192), 553648128, "8B int8 total at its 8192 cap")
    print("PASS: accounting reproduces J-087 -- 8B 67,584 B/token (65,536 payload + 2,048 scales), ratio 0.5156 of f16")


def test_per_channel_accounting() raises:
    # Per-channel scales are paid once, not per token:
    # payload 65,536 x 8192 + one table 32*2*8*128*4.
    expect_eq(kv8_per_channel_total_bytes(32, 8, 128, 8192), 537133056, "8B per-channel total at 8192")
    expect_eq(kv8_per_channel_total_bytes(32, 8, 128, 1), 327680, "8B per-channel total at 1 token (table dominates)")
    print("PASS: per-channel accounting -- scale table paid once (262,144 B for the 8B shape), payload per token")


def test_quantizer_bounds() raises:
    # Round-trip: |dequant(quant(x)) - x| <= scale/2 for the
    # row's own scale, over deterministic synthetic values.
    var vals = List[Float32]()
    for i in range(64):
        vals.append(synth(i))
    var maxabs = Float32(0)
    for i in range(len(vals)):
        var a = vals[i] if vals[i] >= Float32(0) else -vals[i]
        if a > maxabs:
            maxabs = a
    var scale = kv8_row_scale(maxabs)
    for i in range(len(vals)):
        var rt = kv8_dequantize(kv8_quantize(vals[i], scale), scale)
        expect_close(rt, vals[i], scale / Float32(2.0) + Float32(0.000001), "round-trip bound")
    # The row maximum maps to code 127 exactly (no clamp loss).
    expect_eq(Int(kv8_quantize(maxabs, scale)), 127, "row max -> 127")
    # Out-of-range values clamp, never wrap.
    expect_eq(Int(kv8_quantize(Float32(300.0), Float32(1.0))), 127, "clamp high")
    expect_eq(Int(kv8_quantize(Float32(-300.0), Float32(1.0))), -127, "clamp low")
    # A zero row: scale 1.0, codes zero, exact round-trip.
    if kv8_row_scale(Float32(0)) != Float32(1.0):
        raise Error("KVInt8: zero-row scale")
    expect_eq(Int(kv8_quantize(Float32(0), Float32(1.0))), 0, "zero code")
    print("PASS: quantizer bounds -- round-trip within scale/2, row max exact at 127, clamping, zero row exact")


def test_store_append_read() raises:
    var store = Int8KVStore(2, 2, 4, 8)
    # Accounting from the store's own buffers.
    expect_eq(store.bytes_per_token(), kv8_bytes_per_token(2, 2, 4), "store bytes/token == accounting")
    expect_eq(store.total_bytes(), kv8_total_bytes(2, 2, 4, 8), "store total == accounting")
    var key = List[Float32]()
    var val = List[Float32]()
    for i in range(8):
        key.append(synth(i + 3))
        val.append(synth(i + 40))
    store.append(1, 5, key, val)
    var rk = store.read_k(1, 5)
    var rv = store.read_v(1, 5)
    # Each head-slice round-trips within its own scale/2.
    for h in range(2):
        var kmax = Float32(0)
        for j in range(4):
            var a = key[h * 4 + j] if key[h * 4 + j] >= Float32(0) else -key[h * 4 + j]
            if a > kmax:
                kmax = a
        var tol = kv8_row_scale(kmax) / Float32(2.0) + Float32(0.000001)
        for j in range(4):
            expect_close(rk[h * 4 + j], key[h * 4 + j], tol, "store K round-trip")
        var vmax = Float32(0)
        for j in range(4):
            var a = val[h * 4 + j] if val[h * 4 + j] >= Float32(0) else -val[h * 4 + j]
            if a > vmax:
                vmax = a
        var vtol = kv8_row_scale(vmax) / Float32(2.0) + Float32(0.000001)
        for j in range(4):
            expect_close(rv[h * 4 + j], val[h * 4 + j], vtol, "store V round-trip")
    # An untouched row is exactly zero.
    var rz = store.read_k(0, 0)
    for j in range(8):
        if rz[j] != Float32(0):
            raise Error("KVInt8: untouched row not zero")
    print("PASS: store append/read -- quantize-on-append, per-head round-trip within scale/2, buffer accounting closes")


def test_attention_exercise() raises:
    # One layer, 2 kv-heads, head_dim 4, 6 positions.
    var store = Int8KVStore(1, 2, 4, 8)
    var keys = List[Float32]()   # head 0 rows, [6][4]
    var vals = List[Float32]()
    for t in range(6):
        var krow = List[Float32]()
        var vrow = List[Float32]()
        # Full-width rows: head 0 slice = synth, head 1 = zeros.
        for j in range(4):
            krow.append(synth(t * 4 + j + 11))
            vrow.append(synth(t * 4 + j + 70))
        for _ in range(4):
            krow.append(Float32(0))
            vrow.append(Float32(0))
        store.append(0, t, krow, vrow)
        for j in range(4):
            keys.append(krow[j])
            vals.append(vrow[j])
    var query = List[Float32]()
    for j in range(4):
        query.append(synth(j + 5))
    var got = attention_int8_head(store, 0, 0, query, 6)
    var want = attention_f32_head(keys, vals, query, 6, 4)
    for j in range(4):
        expect_close(got[j], want[j], Float32(0.05), "int8 attention vs f32 reference")
    print("PASS: attention exercise -- dequantize-inside-attention output within 0.05 of the f32 reference (synthetic)")


def test_option_surface() raises:
    var empty = RawKvInputs()
    var choice = resolve_kv_precision(empty, empty)
    expect_eq(choice.precision, KV8_PRECISION_F16, "default precision is f16")
    expect_eq(choice.precision_source, KV8_SOURCE_DEFAULT, "default source")
    validate_kv8_selection(choice)
    var env = RawKvInputs()
    env.precision = String("int8")
    env.precision_set = True
    var args = List[String]()
    args.append(String("--kv-precision=f16"))
    args.append(String("--kv-scale"))
    args.append(String("per-row"))
    var cli = scan_kv_args(args)
    choice = resolve_kv_precision(cli, env)
    expect_eq(choice.precision, KV8_PRECISION_F16, "cli beats env")
    expect_eq(choice.precision_source, KV8_SOURCE_CLI, "cli source")
    expect_eq(choice.scale_mode, KV8_SCALE_PER_ROW, "space-form scale value")
    var env_only = resolve_kv_precision(empty, env)
    expect_eq(env_only.precision, KV8_PRECISION_INT8, "env int8")
    expect_eq(env_only.precision_source, KV8_SOURCE_ENV, "env source")
    validate_kv8_selection(env_only)
    print("PASS: option surface -- default f16; cli > env > default; = and space forms; int8+per-row usable")


def test_refusals() raises:
    var refused = 0
    try:
        _ = kv8_precision_code("f32")
    except:
        refused += 1
    try:
        var a = List[String]()
        a.append(String("--kv-precison"))
        a.append(String("int8"))
        _ = scan_kv_args(a)
    except:
        refused += 1
    try:
        var a = List[String]()
        a.append(String("--kv-precision"))
        _ = scan_kv_args(a)
    except:
        refused += 1
    try:
        var a = List[String]()
        a.append(String("--kv-precision"))
        a.append(String("int8"))
        a.append(String("--kv-precision"))
        a.append(String("f16"))
        _ = scan_kv_args(a)
    except:
        refused += 1
    # int8 + per-channel resolves but is refused at use.
    try:
        var c = RawKvInputs()
        c.precision = String("int8")
        c.precision_set = True
        c.scale = String("per-channel")
        c.scale_set = True
        var choice = resolve_kv_precision(c, RawKvInputs())
        validate_kv8_selection(choice)
    except:
        refused += 1
    try:
        var s = Int8KVStore(0, 2, 4, 8)
        _ = s.total_bytes()
    except:
        refused += 1
    try:
        var s = Int8KVStore(1, 1, 4, 2)
        var row = List[Float32]()
        row.append(Float32(0))
        s.append(0, 2, row, row)
    except:
        refused += 1
    try:
        _ = kv8_quantize(Float32(1.0), Float32(0))
    except:
        refused += 1
    expect_eq(refused, 8, "refusal count")
    print("PASS: refusals -- bad precision, typo'd flag, missing value, duplicate, per-channel at use, bad dims, append past capacity, zero scale")


def main() raises:
    test_codes()
    test_accounting_reproduces_j087()
    test_per_channel_accounting()
    test_quantizer_bounds()
    test_store_append_read()
    test_attention_exercise()
    test_option_surface()
    test_refusals()
    print("ALL PASS: kv int8 (8 groups)")
