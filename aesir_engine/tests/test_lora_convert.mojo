"""LoRA merge at conversion (J-120): the pure
converter layer -- safetensors round-trips and
refusals, adapter-config parsing, the merge proven
EXACT against a test-local slow-way computation
(sharing no code with the layer), the refusal
battery (rank/alpha-side shape mismatches, missing
adapter tensors, incomplete pairs, non-LoRA
checkpoints), HF->GGUF naming, the GGUF writer's
census + the layer's own GGUF re-read, the C10
from-gguf round trip (plain and merged), the
quantized-input refusal, and the C05 BF16-only
scope refusal.

No number in this suite is a behaviour of a live
model: no session was started, no inference ran.
The file-level loader re-read (PackedGGUF /
GGUFSeer) is the separate j120_reread driver.
"""
from core.lora_convert import (
    LC_DTYPE_BF16,
    LC_DTYPE_F16,
    LC_DTYPE_F32,
    LcAdapterConfig,
    LcGeometry,
    LcTensor,
    lc_build_safetensors,
    lc_c05_scope_text,
    lc_convert_base,
    lc_convert_from_gguf,
    lc_f32_to_bf16_bits,
    lc_gguf_name_for_hf,
    lc_merge_model,
    lc_parse_adapter_config,
    lc_parse_safetensors,
    lc_read_gguf,
    lc_refuse_quantize,
)


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("LoRAConvert " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("LoRAConvert " + what + ": expected false")


def expect_eq_int(got: Int, want: Int, what: String) raises:
    if got != want:
        raise Error(
            "LoRAConvert " + what + ": expected " + String(want)
            + ", got " + String(got))


def expect_eq_f32(got: Float32, want: Float32, what: String) raises:
    if got != want:
        raise Error("LoRAConvert " + what + ": float mismatch")


def expect_eq_str(got: String, want: String, what: String) raises:
    if got != want:
        raise Error(
            "LoRAConvert " + what + ": expected '" + want
            + "', got '" + got + "'")


def tensor(name: String, dims: List[Int], values: List[Float32]) -> LcTensor:
    return LcTensor(name, dims, values)


def patterned(count: Int, step: Int, denom: Float32) -> List[Float32]:
    var out = List[Float32]()
    for i in range(count):
        out.append(Float32((i * step) % 7 - 3) / denom)
    return out^


def slow_merge(
    w: List[Float32], rows: Int, cols: Int,
    a: List[Float32], rank: Int, b: List[Float32], scale: Float32,
) -> List[Float32]:
    """The slow way, test-local: form the full
    product matrix P = B*A first, then add."""
    var p = List[Float32]()
    for i in range(rows):
        for j in range(cols):
            var acc = Float32(0.0)
            for k in range(rank):
                acc += b[i * rank + k] * a[k * cols + j]
            p.append(acc)
    var out = List[Float32]()
    for idx in range(rows * cols):
        out.append(w[idx] + scale * p[idx])
    return out^


def test_safetensors_roundtrip() raises:
    var dims2 = List[Int]()
    dims2.append(2)
    dims2.append(3)
    var vals = List[Float32]()
    for v in [Float32(1.0), Float32(-2.5), Float32(0.25), Float32(3.5), Float32(-0.125), Float32(0.0)]:
        vals.append(v)
    var dims1 = List[Int]()
    dims1.append(4)
    var tensors = List[LcTensor]()
    tensors.append(tensor("model.layers.0.self_attn.q_proj.weight", dims2, vals))
    tensors.append(tensor("model.norm.weight", dims1, patterned(4, 1, Float32(8.0))))
    var bytes = lc_build_safetensors(tensors, LC_DTYPE_F32)
    var back = lc_parse_safetensors(bytes)
    expect_eq_int(len(back), 2, "round-trip tensor count")
    expect_eq_str(back[0].name, "model.layers.0.self_attn.q_proj.weight", "round-trip name")
    expect_eq_int(back[0].dims[0], 2, "round-trip dim0")
    expect_eq_int(back[0].dims[1], 3, "round-trip dim1")
    for i in range(6):
        expect_eq_f32(back[0].values[i], vals[i], "F32 round-trip exact")
    var bf = lc_build_safetensors(tensors, LC_DTYPE_BF16)
    var back_bf = lc_parse_safetensors(bf)
    for i in range(6):
        # BF16 decode of the stored rounding, via the
        # codec's own inverse pair on known values:
        # all fixture values here are BF16-exact.
        var want = vals[i]
        expect_eq_f32(back_bf[0].values[i], want, "BF16 round-trip exact on exact values")
    # F16 decode of crafted bit patterns: build the
    # bytes by hand through the emitter at F16.
    var f16bytes = lc_build_safetensors(tensors, LC_DTYPE_F16)
    var back_f16 = lc_parse_safetensors(f16bytes)
    for i in range(6):
        expect_eq_f32(back_f16[0].values[i], vals[i], "F16 round-trip exact on exact values")
    print("PASS: safetensors round-trip (F32 exact, BF16/F16 exact on exact values)")


def test_safetensors_refusals() raises:
    var dims = List[Int]()
    dims.append(2)
    var two = List[LcTensor]()
    two.append(tensor("a.weight", dims, patterned(2, 1, Float32(4.0))))
    two.append(tensor("a.weight", dims, patterned(2, 2, Float32(4.0))))
    var dup_bytes = lc_build_safetensors(two, LC_DTYPE_F32)
    var raised = False
    try:
        _ = lc_parse_safetensors(dup_bytes)
    except:
        raised = True
    expect_true(raised, "duplicate tensor name refused")
    var one = List[LcTensor]()
    one.append(tensor("a.weight", dims, patterned(2, 1, Float32(4.0))))
    var good = lc_build_safetensors(one, LC_DTYPE_F32)
    var trunc = List[Byte]()
    for i in range(len(good) - 2):
        trunc.append(good[i])
    raised = False
    try:
        _ = lc_parse_safetensors(trunc)
    except:
        raised = True
    expect_true(raised, "truncated tensor data refused")
    raised = False
    try:
        _ = lc_parse_safetensors(List[Byte]())
    except:
        raised = True
    expect_true(raised, "empty file refused")
    print("PASS: safetensors refusals (duplicate name, truncated data, empty file)")


def test_adapter_config() raises:
    var cfg = lc_parse_adapter_config(
        "{\"r\": 2, \"lora_alpha\": 4, \"target_modules\": [\"q_proj\"],"
        " \"task_type\": \"CAUSAL_LM\", \"nested\": {\"r\": 99}}"
    )
    expect_eq_int(cfg.rank, 2, "rank read by name, nested r ignored")
    expect_eq_f32(cfg.alpha, Float32(4.0), "alpha read by name")
    expect_eq_f32(cfg.scale(), Float32(2.0), "scale is alpha/r")
    var cfg2 = lc_parse_adapter_config("{\"lora_alpha\": 1.5, \"r\": 3}")
    expect_eq_int(cfg2.rank, 3, "key order independent")
    expect_eq_f32(cfg2.scale(), Float32(0.5), "fractional alpha scale")
    var raised = False
    try:
        _ = lc_parse_adapter_config("{\"lora_alpha\": 4}")
    except:
        raised = True
    expect_true(raised, "missing r refused")
    raised = False
    try:
        _ = lc_parse_adapter_config("{\"r\": 2}")
    except:
        raised = True
    expect_true(raised, "missing lora_alpha refused")
    raised = False
    try:
        _ = lc_parse_adapter_config("{\"r\": 0, \"lora_alpha\": 4}")
    except:
        raised = True
    expect_true(raised, "zero rank refused")
    print("PASS: adapter config (by-name parse, nested decoy, missing/zero refused)")


def tiny_base() -> List[LcTensor]:
    var tensors = List[LcTensor]()
    var d_w = List[Int]()
    d_w.append(4)
    d_w.append(4)
    tensors.append(tensor(
        "model.layers.0.self_attn.q_proj.weight", d_w, patterned(16, 1, Float32(8.0))))
    var d_n = List[Int]()
    d_n.append(4)
    tensors.append(tensor("model.layers.0.input_layernorm.weight", d_n, patterned(4, 3, Float32(8.0))))
    return tensors^


def tiny_adapter() -> List[LcTensor]:
    var adapter = List[LcTensor]()
    var d_a = List[Int]()
    d_a.append(2)
    d_a.append(4)
    adapter.append(tensor(
        "base_model.model.model.layers.0.self_attn.q_proj.lora_A.default.weight",
        d_a, patterned(8, 2, Float32(4.0))))
    var d_b = List[Int]()
    d_b.append(4)
    d_b.append(2)
    adapter.append(tensor(
        "base_model.model.model.layers.0.self_attn.q_proj.lora_B.default.weight",
        d_b, patterned(8, 1, Float32(4.0))))
    return adapter^


def test_merge_exact() raises:
    var base = tiny_base()
    var adapter = tiny_adapter()
    var cfg = LcAdapterConfig(2, Float32(4.0))
    var merged = lc_merge_model(base, adapter, cfg)
    var out = merged[0].copy()
    var report = merged[1].copy()
    expect_eq_int(len(report.merged_names), 1, "one merged tensor")
    expect_eq_str(
        report.merged_names[0], "model.layers.0.self_attn.q_proj.weight",
        "merged name")
    expect_eq_int(len(report.passed_names), 1, "one pass-through tensor")
    var want = slow_merge(
        base[0].values, 4, 4, adapter[0].values, 2, adapter[1].values, Float32(2.0))
    var diffs = 0
    for i in range(16):
        if out[0].values[i] != want[i]:
            diffs += 1
    expect_eq_int(diffs, 0, "merged == slow way EXACT (0 differing elements)")
    for i in range(4):
        expect_eq_f32(out[1].values[i], base[1].values[i], "pass-through bit-exact")
    print("PASS: merge exact vs slow way (0 diffs, PEFT names, pass-through exact)")


def expect_merge_refusal(
    base: List[LcTensor], adapter: List[LcTensor], cfg: LcAdapterConfig, what: String
) raises:
    var raised = False
    try:
        _ = lc_merge_model(base, adapter, cfg)
    except:
        raised = True
    expect_true(raised, what)


def test_merge_refusals() raises:
    var base = tiny_base()
    var cfg = LcAdapterConfig(2, Float32(4.0))
    # Empty adapter: the non-LoRA checkpoint shape.
    expect_merge_refusal(base, List[LcTensor](), cfg, "empty adapter refused")
    # A plain weight tensor as the adapter: not LoRA.
    var plain = List[LcTensor]()
    var d = List[Int]()
    d.append(4)
    plain.append(tensor("model.layers.0.self_attn.q_proj.weight", d, patterned(4, 1, Float32(4.0))))
    expect_merge_refusal(base, plain, cfg, "non-LoRA adapter tensor refused")
    # Incomplete pair (A only).
    var a_only = List[LcTensor]()
    var ta1 = tiny_adapter()
    a_only.append(ta1[0].copy())
    expect_merge_refusal(base, a_only, cfg, "incomplete pair refused (missing lora_B)")
    # Pair whose stem has no base tensor.
    var stray = List[LcTensor]()
    var da = List[Int]()
    da.append(2)
    da.append(4)
    stray.append(tensor("model.layers.0.mlp.gate_proj.lora_A.weight", da, patterned(8, 1, Float32(4.0))))
    var db = List[Int]()
    db.append(6)
    db.append(2)
    stray.append(tensor("model.layers.0.mlp.gate_proj.lora_B.weight", db, patterned(12, 1, Float32(4.0))))
    expect_merge_refusal(base, stray, cfg, "pair with no base tensor refused")
    # Rank mismatch: adapter inner dim 3 vs configured rank 2.
    var bad_rank = List[LcTensor]()
    var d3a = List[Int]()
    d3a.append(3)
    d3a.append(4)
    bad_rank.append(tensor("model.layers.0.self_attn.q_proj.lora_A.weight", d3a, patterned(12, 1, Float32(4.0))))
    var d3b = List[Int]()
    d3b.append(4)
    d3b.append(3)
    bad_rank.append(tensor("model.layers.0.self_attn.q_proj.lora_B.weight", d3b, patterned(12, 1, Float32(4.0))))
    expect_merge_refusal(base, bad_rank, cfg, "rank mismatch refused (adapter rank 3 vs config 2)")
    # Config rank mismatch: pair rank 2 vs configured rank 4.
    expect_merge_refusal(
        base, tiny_adapter(), LcAdapterConfig(4, Float32(4.0)),
        "rank mismatch refused (config rank 4 vs adapter 2)")
    # Shape mismatch: B out-dim disagrees with the base.
    var bad_shape = List[LcTensor]()
    var ta2 = tiny_adapter()
    bad_shape.append(ta2[0].copy())
    var dbb = List[Int]()
    dbb.append(5)
    dbb.append(2)
    bad_shape.append(tensor(
        "base_model.model.model.layers.0.self_attn.q_proj.lora_B.default.weight",
        dbb, patterned(10, 1, Float32(4.0))))
    expect_merge_refusal(base, bad_shape, cfg, "shape mismatch refused (B out 5 vs base 4)")
    # Non-2-D merge target.
    var base1d = List[LcTensor]()
    var dn = List[Int]()
    dn.append(4)
    base1d.append(tensor("model.norm.weight", dn, patterned(4, 1, Float32(8.0))))
    var ad1d = List[LcTensor]()
    var daa = List[Int]()
    daa.append(2)
    daa.append(4)
    ad1d.append(tensor("model.norm.lora_A.weight", daa, patterned(8, 1, Float32(4.0))))
    var dbb2 = List[Int]()
    dbb2.append(4)
    dbb2.append(2)
    ad1d.append(tensor("model.norm.lora_B.weight", dbb2, patterned(8, 1, Float32(4.0))))
    expect_merge_refusal(base1d, ad1d, cfg, "non-2-D merge target refused")
    print("PASS: merge refusals (empty, non-LoRA, incomplete, no-base, rank x2, shape, non-2-D)")


def test_naming() raises:
    expect_eq_str(
        lc_gguf_name_for_hf("model.embed_tokens.weight"), "token_embd.weight", "embed map")
    expect_eq_str(lc_gguf_name_for_hf("lm_head.weight"), "output.weight", "head map")
    expect_eq_str(
        lc_gguf_name_for_hf("model.layers.10.self_attn.o_proj.weight"),
        "blk.10.attn_output.weight", "two-digit layer map")
    expect_eq_str(
        lc_gguf_name_for_hf("model.layers.0.mlp.down_proj.weight"),
        "blk.0.ffn_down.weight", "down map")
    expect_eq_str(
        lc_gguf_name_for_hf("model.layers.3.post_attention_layernorm.weight"),
        "blk.3.ffn_norm.weight", "ffn norm map")
    var raised = False
    try:
        _ = lc_gguf_name_for_hf("model.layers.0.self_attn.q_proj.bias")
    except:
        raised = True
    expect_true(raised, "unmapped name refused by name")
    print("PASS: naming (llama subset exact, unknown refused)")


def fixture_geometry() -> LcGeometry:
    var tokens = List[String]()
    for t in ["<unk>", "<s>", "</s>", "a", "b", "c", "d", "e"]:
        tokens.append(String(t))
    return LcGeometry(
        "llama", "j120-synthetic", 128, 4, 6, 1, 2, 1, 2,
        Float32(10000.0), Float32(0.00001), tokens)


def fixture_model() -> List[LcTensor]:
    """A complete tiny llama-shaped tensor list in
    HF names: hidden 4, ffn 6, vocab 8, 1 layer."""
    var tensors = List[LcTensor]()
    var d84 = List[Int]()
    d84.append(8)
    d84.append(4)
    tensors.append(tensor("model.embed_tokens.weight", d84, patterned(32, 1, Float32(8.0))))
    var d4 = List[Int]()
    d4.append(4)
    tensors.append(tensor("model.norm.weight", d4, patterned(4, 1, Float32(8.0))))
    tensors.append(tensor("lm_head.weight", d84, patterned(32, 2, Float32(8.0))))
    tensors.append(tensor("model.layers.0.input_layernorm.weight", d4, patterned(4, 2, Float32(8.0))))
    var d44 = List[Int]()
    d44.append(4)
    d44.append(4)
    tensors.append(tensor("model.layers.0.self_attn.q_proj.weight", d44, patterned(16, 1, Float32(8.0))))
    var d24 = List[Int]()
    d24.append(2)
    d24.append(4)
    tensors.append(tensor("model.layers.0.self_attn.k_proj.weight", d24, patterned(8, 1, Float32(8.0))))
    tensors.append(tensor("model.layers.0.self_attn.v_proj.weight", d24, patterned(8, 2, Float32(8.0))))
    tensors.append(tensor("model.layers.0.self_attn.o_proj.weight", d44, patterned(16, 3, Float32(8.0))))
    tensors.append(tensor("model.layers.0.post_attention_layernorm.weight", d4, patterned(4, 3, Float32(8.0))))
    var d64 = List[Int]()
    d64.append(6)
    d64.append(4)
    tensors.append(tensor("model.layers.0.mlp.gate_proj.weight", d64, patterned(24, 1, Float32(8.0))))
    tensors.append(tensor("model.layers.0.mlp.up_proj.weight", d64, patterned(24, 2, Float32(8.0))))
    var d46 = List[Int]()
    d46.append(4)
    d46.append(6)
    tensors.append(tensor("model.layers.0.mlp.down_proj.weight", d46, patterned(24, 3, Float32(8.0))))
    return tensors^


def test_gguf_write_reread() raises:
    var model = fixture_model()
    var conv = lc_convert_base(model, fixture_geometry())
    expect_eq_int(len(conv.census), 12, "census counts every tensor")
    expect_eq_int(conv.data_offset % 32, 0, "data offset aligned")
    var saw_bf16 = 0
    var saw_f32 = 0
    for e in conv.census:
        expect_eq_int(e.offset % 32, 0, "tensor offset aligned: " + e.name)
        if e.ggml_type == 30:
            saw_bf16 += 1
        elif e.ggml_type == 0:
            saw_f32 += 1
    expect_eq_int(saw_bf16, 9, "2-D tensors stored BF16")
    expect_eq_int(saw_f32, 3, "1-D tensors stored F32")
    var last = conv.census[len(conv.census) - 1].copy()
    expect_eq_int(
        len(conv.bytes), conv.data_offset + last.offset + last.byte_count,
        "file ends exactly at the last tensor")
    var back = lc_read_gguf(conv.bytes)
    expect_eq_int(len(back.tensors), 12, "re-read tensor count agrees")
    expect_eq_str(back.geom.arch, "llama", "re-read arch")
    expect_eq_int(back.geom.embedding_length, 4, "re-read hidden")
    expect_eq_int(len(back.geom.tokens), 8, "re-read vocab")
    # Values: q_proj (index 4 in file order == model
    # order) round-trips through BF16 exactly on
    # these BF16-exact fixture values.
    for i in range(len(back.tensors)):
        expect_eq_str(back.tensors[i].name, conv.census[i].name, "re-read name order")
        for j in range(len(model[i].values)):
            expect_eq_f32(
                back.tensors[i].values[j], model[i].values[j],
                "re-read values exact: " + model[i].name)
    print("PASS: GGUF write + re-read (census 12, BF16/F32 split, values exact)")


def test_from_gguf() raises:
    var model = fixture_model()
    var conv = lc_convert_base(model, fixture_geometry())
    var cfg = LcAdapterConfig(2, Float32(4.0))
    var plain = lc_convert_from_gguf(conv.bytes, List[LcTensor](), cfg, False)
    var plain_conv = plain[0].copy()
    expect_eq_int(len(plain_conv.census), len(conv.census), "from-gguf census count")
    for i in range(len(conv.census)):
        expect_eq_str(plain_conv.census[i].name, conv.census[i].name, "from-gguf census name")
        expect_eq_int(plain_conv.census[i].ggml_type, conv.census[i].ggml_type, "from-gguf census type")
        expect_eq_int(plain_conv.census[i].byte_count, conv.census[i].byte_count, "from-gguf census bytes")
    expect_eq_int(len(plain_conv.bytes), len(conv.bytes), "from-gguf re-emission size identical")
    var same = True
    for i in range(len(conv.bytes)):
        if plain_conv.bytes[i] != conv.bytes[i]:
            same = False
    expect_true(same, "from-gguf re-emission byte-identical (deterministic writer)")
    # Merged from-gguf: adapter over the GGUF's
    # q_proj, verified against the slow way run on
    # the re-read (BF16-decoded) base values.
    var adapter = tiny_adapter()
    var merged = lc_convert_from_gguf(conv.bytes, adapter, cfg, True)
    var merged_conv = merged[0].copy()
    var report = merged[1].copy()
    expect_eq_int(len(report.merged_names), 1, "from-gguf merge reports one merge")
    var base_back = lc_read_gguf(conv.bytes)
    var q_base: List[Float32] = List[Float32]()
    for t in base_back.tensors:
        if t.name == "blk.0.attn_q.weight":
            q_base = t.values.copy()
    expect_eq_int(len(q_base), 16, "found q in the GGUF census")
    var want = slow_merge(q_base, 4, 4, adapter[0].values, 2, adapter[1].values, Float32(2.0))
    var out_back = lc_read_gguf(merged_conv.bytes)
    var diffs = 0
    for t in out_back.tensors:
        if t.name == "blk.0.attn_q.weight":
            for i in range(16):
                var stored = t.values[i]
                # want values are BF16-exact by fixture
                # construction (dyadic, small).
                var rounded = want[i]
                if stored != rounded:
                    diffs += 1
    expect_eq_int(diffs, 0, "from-gguf merged == slow way EXACT after storage")
    print("PASS: from-gguf (byte-identical re-emission, merged == slow way)")


def test_quantized_and_scope() raises:
    # A hand-built minimal GGUF holding one Q4_K
    # tensor: the from-gguf reader must refuse it.
    var bytes = List[Byte]()
    var magic = List[Int]()
    for v in [0x47, 0x47, 0x55, 0x46]:
        magic.append(v)
    for v in magic:
        bytes.append(Byte(v))
    for v in [3, 0, 0, 0]:
        bytes.append(Byte(v))
    for v in [1, 0, 0, 0, 0, 0, 0, 0]:
        bytes.append(Byte(v))
    for v in [0, 0, 0, 0, 0, 0, 0, 0]:
        bytes.append(Byte(v))
    var name = String("blk.0.attn_q.weight")
    bytes.append(Byte(name.byte_length()))
    for _ in range(7):
        bytes.append(Byte(0))
    var raw = name.as_bytes()
    for i in range(len(raw)):
        bytes.append(raw[i])
    for v in [1, 0, 0, 0]:
        bytes.append(Byte(v))
    for v in [32, 0, 0, 0, 0, 0, 0, 0]:
        bytes.append(Byte(v))
    for v in [12, 0, 0, 0]:
        bytes.append(Byte(v))
    for _ in range(8):
        bytes.append(Byte(0))
    while len(bytes) % 32 != 0:
        bytes.append(Byte(0))
    for _ in range(18):
        bytes.append(Byte(0))
    var raised = False
    try:
        _ = lc_read_gguf(bytes)
    except:
        raised = True
    expect_true(raised, "quantized GGUF tensor refused by the from-gguf reader")
    raised = False
    try:
        lc_refuse_quantize("q4_k_m")
    except:
        raised = True
    expect_true(raised, "quantize request refused")
    var scope = lc_c05_scope_text()
    expect_true("BF16-only" in scope, "scope text states BF16-only")
    expect_true("C05" in scope, "scope text names C05")
    _ = lc_f32_to_bf16_bits(Float32(1.0))
    print("PASS: quantized refusal + C05 scope (BF16-only, refused by name)")


def main() raises:
    test_safetensors_roundtrip()
    test_safetensors_refusals()
    test_adapter_config()
    test_merge_exact()
    test_merge_refusals()
    test_naming()
    test_gguf_write_reread()
    test_from_gguf()
    test_quantized_and_scope()
    print("ALL PASS: lora convert (9 groups)")
