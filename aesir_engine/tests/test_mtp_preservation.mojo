"""MTP preservation at conversion (J-121): the
J-120 converter extended so prediction-head tensors
survive conversion intact and labelled -- head
identification bound to J-076's classifier
(core/mtp_census.mojo, mirrored in the converter and
proven to agree), verbatim carry under the strict
naming path, the aesir.mtp.* metadata label emitted
only when heads are present, tensor-for-tensor
census agreement between source checkpoint and
converted file, J-077 admission agreement over the
converted directory, local MTP-block extraction,
and the from-gguf round trip over a head-carrying
file.

The head-carrying directories here are SIMULATED in
J-077's sense: synthetic names in J-076's
pre-registered forms, not names read from any real
file (no WITH_MTP file exists in any filed census,
J-076 section 3). No session was started, no
inference ran.
"""
from core.lora_convert import (
    LC_HEAD_ASSISTANT,
    LC_HEAD_MTP,
    LC_HEAD_NEXTN,
    LC_HEAD_NONE,
    LcAdapterConfig,
    LcGeometry,
    LcTensor,
    lc_convert_base,
    lc_convert_from_gguf,
    lc_extract_mtp_block,
    lc_gguf_name_for_hf,
    lc_mtp_head_kind,
    lc_read_gguf,
)
from core.mtp_census import (
    HEAD_ASSISTANT,
    HEAD_MTP,
    HEAD_NEXTN,
    HEAD_NONE,
    MtpCensus,
    VERDICT_WITH_MTP,
    classify_tensor_name,
)
from core.mtp_head_support import evaluate_mtp_admission


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("MtpPreservation " + what + ": expected true")


def expect_eq_int(got: Int, want: Int, what: String) raises:
    if got != want:
        raise Error(
            "MtpPreservation " + what + ": expected " + String(want)
            + ", got " + String(got))


def expect_eq_str(got: String, want: String, what: String) raises:
    if got != want:
        raise Error(
            "MtpPreservation " + what + ": expected '" + want
            + "', got '" + got + "'")


def tensor(name: String, dims: List[Int], values: List[Float32]) -> LcTensor:
    return LcTensor(name, dims, values)


def patterned(count: Int, step: Int, denom: Float32) -> List[Float32]:
    var out = List[Float32]()
    for i in range(count):
        out.append(Float32((i * step) % 7 - 3) / denom)
    return out^


def dims2(a: Int, b: Int) -> List[Int]:
    var d = List[Int]()
    d.append(a)
    d.append(b)
    return d^


def dims1(a: Int) -> List[Int]:
    var d = List[Int]()
    d.append(a)
    return d^


def fixture_geometry() -> LcGeometry:
    var tokens = List[String]()
    for t in ["<unk>", "<s>", "</s>", "a", "b", "c", "d", "e"]:
        tokens.append(String(t))
    return LcGeometry(
        "llama", "j121-synthetic", 128, 4, 6, 1, 2, 1, 2,
        Float32(10000.0), Float32(0.00001), tokens)


def ordinary_model() -> List[LcTensor]:
    """The J-120 unit fixture shape: hidden 4, ffn 6,
    vocab 8, 1 layer, HF names, no head tensors."""
    var tensors = List[LcTensor]()
    tensors.append(tensor("model.embed_tokens.weight", dims2(8, 4), patterned(32, 1, Float32(8.0))))
    tensors.append(tensor("model.norm.weight", dims1(4), patterned(4, 1, Float32(8.0))))
    tensors.append(tensor("lm_head.weight", dims2(8, 4), patterned(32, 2, Float32(8.0))))
    tensors.append(tensor("model.layers.0.input_layernorm.weight", dims1(4), patterned(4, 2, Float32(8.0))))
    tensors.append(tensor("model.layers.0.self_attn.q_proj.weight", dims2(4, 4), patterned(16, 1, Float32(8.0))))
    tensors.append(tensor("model.layers.0.self_attn.k_proj.weight", dims2(2, 4), patterned(8, 1, Float32(8.0))))
    tensors.append(tensor("model.layers.0.self_attn.v_proj.weight", dims2(2, 4), patterned(8, 2, Float32(8.0))))
    tensors.append(tensor("model.layers.0.self_attn.o_proj.weight", dims2(4, 4), patterned(16, 3, Float32(8.0))))
    tensors.append(tensor("model.layers.0.post_attention_layernorm.weight", dims1(4), patterned(4, 3, Float32(8.0))))
    tensors.append(tensor("model.layers.0.mlp.gate_proj.weight", dims2(6, 4), patterned(24, 1, Float32(8.0))))
    tensors.append(tensor("model.layers.0.mlp.up_proj.weight", dims2(6, 4), patterned(24, 2, Float32(8.0))))
    tensors.append(tensor("model.layers.0.mlp.down_proj.weight", dims2(4, 6), patterned(24, 3, Float32(8.0))))
    return tensors^


def head_tensors() -> List[LcTensor]:
    """Four synthetic head tensors, all three J-076
    classes: nextn x2 (2-D + 1-D), mtp x1, assistant x1."""
    var tensors = List[LcTensor]()
    tensors.append(tensor("model.nextn.eh_proj.weight", dims2(4, 8), patterned(32, 1, Float32(8.0))))
    tensors.append(tensor("model.nextn.shared_head_norm.weight", dims1(4), patterned(4, 2, Float32(8.0))))
    tensors.append(tensor("model.mtp.fc.weight", dims2(4, 4), patterned(16, 3, Float32(8.0))))
    tensors.append(tensor("model.assistant.head_norm.weight", dims1(4), patterned(4, 1, Float32(8.0))))
    return tensors^


def mtp_model() -> List[LcTensor]:
    var tensors = ordinary_model()
    for t in head_tensors():
        tensors.append(t.copy())
    return tensors^


def kv_count_of(bytes: List[Byte]) -> Int:
    var v = 0
    for i in range(8):
        v += Int(bytes[16 + i]) << (8 * i)
    return v


def bytes_contain(bytes: List[Byte], needle: String) -> Bool:
    var raw = needle.as_bytes()
    if len(raw) == 0 or len(raw) > len(bytes):
        return False
    for start in range(len(bytes) - len(raw) + 1):
        var ok = True
        for j in range(len(raw)):
            if bytes[start + j] != raw[j]:
                ok = False
                break
        if ok:
            return True
    return False


def test_mirror_agreement() raises:
    var probes = List[String]()
    for n in [
        "model.nextn.eh_proj.weight",
        "model.nextn.shared_head_norm.weight",
        "model.mtp.fc.weight",
        "model.assistant.head_norm.weight",
        "blk.48.nextn.eh_proj.weight",
        "mtp.weight",
        "assistant.weight",
        "model.layers.0.mlp.gate_proj.weight",
        "token_embd.weight",
        "model.embed_tokens.weight",
        "model.mtp.nextn.weight",
        "model.assistant.mtp.weight",
    ]:
        probes.append(String(n))
    for n in probes:
        expect_eq_int(
            lc_mtp_head_kind(n), classify_tensor_name(n),
            "mirror agrees with J-076 classifier on " + n)
    # First-match order, stated in both rule texts.
    expect_eq_int(lc_mtp_head_kind("model.mtp.nextn.weight"), LC_HEAD_NEXTN, "nextn wins over mtp")
    expect_eq_int(lc_mtp_head_kind("model.assistant.mtp.weight"), LC_HEAD_MTP, "mtp wins over assistant")
    expect_eq_int(LC_HEAD_NEXTN, HEAD_NEXTN, "kind constants align nextn")
    expect_eq_int(LC_HEAD_MTP, HEAD_MTP, "kind constants align mtp")
    expect_eq_int(LC_HEAD_ASSISTANT, HEAD_ASSISTANT, "kind constants align assistant")
    expect_eq_int(LC_HEAD_NONE, HEAD_NONE, "kind constants align none")
    print("PASS: mirror agreement (J-076 classifier, 12 probes, first-match order)")


def test_verbatim_carry() raises:
    var model = mtp_model()
    var conv = lc_convert_base(model, fixture_geometry())
    expect_eq_int(len(conv.census), 16, "census counts ordinary + head tensors")
    expect_eq_int(len(conv.head_names), 4, "conversion records 4 carried heads")
    var want_names = List[String]()
    for n in [
        "model.nextn.eh_proj.weight",
        "model.nextn.shared_head_norm.weight",
        "model.mtp.fc.weight",
        "model.assistant.head_norm.weight",
    ]:
        want_names.append(String(n))
    var want_kinds = List[Int]()
    want_kinds.append(LC_HEAD_NEXTN)
    want_kinds.append(LC_HEAD_NEXTN)
    want_kinds.append(LC_HEAD_MTP)
    want_kinds.append(LC_HEAD_ASSISTANT)
    for i in range(4):
        expect_eq_str(conv.head_names[i], want_names[i], "head name verbatim " + String(i))
        expect_eq_int(conv.head_kinds[i], want_kinds[i], "head kind " + String(i))
    # The census carries the head names verbatim, after the 12 mapped names.
    for i in range(4):
        expect_eq_str(conv.census[12 + i].name, want_names[i], "census head entry " + String(i))
    # Values intact after the storage rule: read back and compare
    # element-for-element against the source tensors (the fixture
    # values are BF16-exact by construction).
    var read = lc_read_gguf(conv.bytes)
    expect_eq_int(len(read.tensors), 16, "re-read tensor count")
    for src in model:
        var gname: String
        if lc_mtp_head_kind(src.name) != LC_HEAD_NONE:
            gname = src.name
        else:
            gname = lc_gguf_name_for_hf(src.name)
        var found = -1
        for j in range(len(read.tensors)):
            if read.tensors[j].name == gname:
                found = j
                break
        expect_true(found >= 0, "converted census has " + gname)
        var back = read.tensors[found].copy()
        expect_eq_int(len(back.dims), len(src.dims), "dims rank for " + gname)
        for d in range(len(src.dims)):
            expect_eq_int(back.dims[d], src.dims[d], "dims agree for " + gname)
        expect_eq_int(len(back.values), len(src.values), "element count for " + gname)
        for k in range(len(src.values)):
            if back.values[k] != src.values[k]:
                raise Error("MtpPreservation value mismatch in " + gname)
    print("PASS: verbatim carry (names, census, values exact after storage rule)")


def test_non_head_refusal() raises:
    var model = ordinary_model()
    model.append(tensor("model.vision_tower.weight", dims2(4, 4), patterned(16, 1, Float32(8.0))))
    var raised = False
    var message = String("")
    try:
        _ = lc_convert_base(model, fixture_geometry())
    except e:
        raised = True
        message = String(e)
    expect_true(raised, "unmapped non-head name refused")
    expect_true(
        "no GGUF name mapping for HF tensor: model.vision_tower.weight" in message,
        "refusal names the tensor with J-120's text")
    # A head tensor of rank 3 is refused by the rank rule, not carried.
    var model3 = mtp_model()
    model3.append(tensor("model.mtp.stack.weight", dims2(2, 2), patterned(4, 1, Float32(8.0))))
    # (dims2 stands in shape-count only; use a real 3-D tensor below)
    var d3 = List[Int]()
    d3.append(2)
    d3.append(2)
    d3.append(2)
    model3[len(model3) - 1] = tensor("model.mtp.stack.weight", d3, patterned(8, 1, Float32(8.0)))
    var raised3 = False
    try:
        _ = lc_convert_base(model3, fixture_geometry())
    except:
        raised3 = True
    expect_true(raised3, "3-D head tensor refused by rank rule")
    print("PASS: non-head refusal (unmapped name by name; 3-D head refused)")


def test_metadata_labels() raises:
    var with_heads = lc_convert_base(mtp_model(), fixture_geometry())
    expect_eq_int(kv_count_of(with_heads.bytes), 21, "21 metadata entries with heads")
    expect_true(bytes_contain(with_heads.bytes, "aesir.mtp.head_count"), "head_count key present")
    expect_true(bytes_contain(with_heads.bytes, "aesir.mtp.head_tensors"), "head_tensors key present")
    for n in with_heads.head_names:
        expect_true(bytes_contain(with_heads.bytes, n), "label names " + n)
    var plain = lc_convert_base(ordinary_model(), fixture_geometry())
    expect_eq_int(kv_count_of(plain.bytes), 19, "19 metadata entries without heads")
    expect_true(not bytes_contain(plain.bytes, "aesir.mtp."), "no aesir.mtp.* key without heads")
    print("PASS: metadata labels (21 with heads, contents exact; 19 without)")


def test_census_agreement() raises:
    var model = mtp_model()
    var conv = lc_convert_base(model, fixture_geometry())
    var src_census = MtpCensus()
    for t in model:
        src_census.record(t.name)
    var dst_census = MtpCensus()
    for e in conv.census:
        dst_census.record(e.name)
    expect_eq_int(src_census.n_tensors, 16, "source census count")
    expect_eq_int(dst_census.n_tensors, src_census.n_tensors, "census counts agree")
    expect_eq_int(dst_census.nextn_count, 2, "converted nextn count")
    expect_eq_int(dst_census.mtp_count, 1, "converted mtp count")
    expect_eq_int(dst_census.assistant_count, 1, "converted assistant count")
    expect_eq_int(dst_census.nextn_count, src_census.nextn_count, "nextn counts agree")
    expect_eq_int(dst_census.mtp_count, src_census.mtp_count, "mtp counts agree")
    expect_eq_int(dst_census.assistant_count, src_census.assistant_count, "assistant counts agree")
    expect_eq_int(src_census.verdict(), VERDICT_WITH_MTP, "source verdict WITH_MTP")
    expect_eq_int(dst_census.verdict(), VERDICT_WITH_MTP, "converted verdict WITH_MTP")
    print("PASS: census agreement (counts, per-kind counts, WITH_MTP both sides)")


def test_admission_agreement() raises:
    var model = mtp_model()
    var conv = lc_convert_base(model, fixture_geometry())
    var src_names = List[String]()
    for t in model:
        src_names.append(t.name)
    var dst_names = List[String]()
    for e in conv.census:
        dst_names.append(e.name)
    var src_adm = evaluate_mtp_admission("source.safetensors", True, src_names)
    var dst_adm = evaluate_mtp_admission("converted.gguf", True, dst_names)
    expect_true(src_adm.admitted, "source directory admitted")
    expect_true(dst_adm.admitted, "converted directory admitted")
    expect_eq_int(dst_adm.nextn_count, src_adm.nextn_count, "admission nextn counts agree")
    expect_eq_int(dst_adm.mtp_count, src_adm.mtp_count, "admission mtp counts agree")
    expect_eq_int(dst_adm.assistant_count, src_adm.assistant_count, "admission assistant counts agree")
    expect_eq_int(len(dst_adm.head_names), 4, "admission names 4 heads")
    for i in range(4):
        expect_eq_str(dst_adm.head_names[i], conv.head_names[i], "admission head name " + String(i))
        expect_eq_int(dst_adm.head_kinds[i], conv.head_kinds[i], "admission head kind " + String(i))
    print("PASS: admission agreement (J-077 admits converted + source, heads named)")


def test_extraction() raises:
    var model = mtp_model()
    var block = lc_extract_mtp_block(model)
    expect_eq_int(len(block), 4, "block holds exactly the head tensors")
    var want = head_tensors()
    for i in range(4):
        expect_eq_str(block[i].name, want[i].name, "block order " + String(i))
        expect_eq_int(len(block[i].values), len(want[i].values), "block values carried " + String(i))
        for k in range(len(want[i].values)):
            if block[i].values[k] != want[i].values[k]:
                raise Error("MtpPreservation block value mismatch")
    var raised = False
    try:
        _ = lc_extract_mtp_block(ordinary_model())
    except:
        raised = True
    expect_true(raised, "zero-head extraction refused by name")
    var block_conv = lc_convert_base(block, fixture_geometry())
    expect_eq_int(len(block_conv.census), 4, "block-only census is the head census")
    expect_eq_int(len(block_conv.head_names), 4, "block-only conversion labels all 4")
    var bc = MtpCensus()
    for e in block_conv.census:
        bc.record(e.name)
    expect_eq_int(bc.verdict(), VERDICT_WITH_MTP, "block-only file verdict WITH_MTP")
    expect_eq_int(bc.nextn_count, 2, "block nextn count")
    expect_eq_int(bc.mtp_count, 1, "block mtp count")
    expect_eq_int(bc.assistant_count, 1, "block assistant count")
    print("PASS: extraction (exact head set + order, zero-head refused, block census)")


def test_from_gguf_roundtrip() raises:
    var conv = lc_convert_base(mtp_model(), fixture_geometry())
    var cfg = LcAdapterConfig(2, Float32(4.0))
    var plain = lc_convert_from_gguf(conv.bytes, List[LcTensor](), cfg, False)
    var reemitted = plain[0].copy()
    expect_eq_int(len(reemitted.bytes), len(conv.bytes), "re-emission byte count")
    for i in range(len(conv.bytes)):
        if reemitted.bytes[i] != conv.bytes[i]:
            raise Error("MtpPreservation re-emission differs at byte " + String(i))
    expect_eq_int(len(reemitted.census), 16, "re-emitted census count")
    expect_eq_int(len(reemitted.head_names), 4, "re-emitted head label count")
    for i in range(4):
        expect_eq_str(reemitted.head_names[i], conv.head_names[i], "re-emitted head " + String(i))
    print("PASS: from-gguf round trip (byte-identical, head census unchanged)")


def test_head_free_unchanged() raises:
    var conv = lc_convert_base(ordinary_model(), fixture_geometry())
    expect_eq_int(len(conv.census), 12, "head-free census 12")
    expect_eq_int(len(conv.head_names), 0, "head-free conversion records no heads")
    expect_eq_int(kv_count_of(conv.bytes), 19, "head-free metadata 19")
    print("PASS: head-free unchanged (census 12, no heads, 19 metadata entries)")


def main() raises:
    test_mirror_agreement()
    test_verbatim_carry()
    test_non_head_refusal()
    test_metadata_labels()
    test_census_agreement()
    test_admission_agreement()
    test_extraction()
    test_from_gguf_roundtrip()
    test_head_free_unchanged()
    print("ALL PASS: mtp preservation (9 groups)")
