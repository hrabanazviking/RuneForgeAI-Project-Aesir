# tests/test_quantize_streaming_qc_6.mojo
# QC-6 proof: (A) the Q8_0 kind of the dequantizing input path,
# (B) the QC-6 tiling plan (dim0 % 256 gate + named fallbacks),
# (C) the streaming Q4_K_M converter on stories260K -- the hostile-
# shape fixture where NO matrix is 256-aligned: every K designee
# must fall back (Q8_0 where dim0 % 32 == 0, keep-at-source where
# not), and the product must be payload-identical to QC-3b's proven
# streaming Q8_0 product except general.file_type, must construct
# in PackedGGUF (the admission QC-5's flat product was refused),
# and must generate token-identically to that product in the engine.
#
# Usage: test_quantize_streaming_qc_6 <stories.gguf> <ref.gguf> <out.gguf>

from std.ffi import external_call
from std.sys import argv

from core.dequantize_input import (
    dequant_input_supported,
    dequant_input_type_name,
    dequantize_range_f32,
    dequantize_value_f32,
)
from core.mimir_well import MimirWell
from core.packed_quantization import Bytes
from cli.quantize import (
    q4_k_m_plan_qc6,
    quantize_gguf_q4_k_m_streaming_qc6,
    quantize_gguf_q8_0_streaming,
)
from loader.gguf import GGMLType, GGUFSeer, GGUFState
from loader.gguf_writer import GGUFDirectoryEntry, read_gguf_header_copy
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver
from aesir import AesirEngine


def check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def read_file_bytes(path: String) raises -> List[UInt8]:
    var path_bytes = List[Int8]()
    for byte in path.as_bytes():
        path_bytes.append(Int8(byte))
    path_bytes.append(0)
    var fd = external_call["open64", Int32](path_bytes.unsafe_ptr(), Int32(0), Int32(0))
    if fd < 0:
        raise Error("failed to open file for readback: " + path)
    var out = List[UInt8]()
    var buffer = List[UInt8]()
    buffer.resize(65536, UInt8(0))
    while True:
        var got = external_call["read", Int](Int(fd), buffer.unsafe_ptr(), 65536)
        if got < 0:
            _ = external_call["close", Int32](fd)
            raise Error("failed to read file: " + path)
        if got == 0:
            break
        for i in range(got):
            out.append(buffer[i])
    _ = external_call["close", Int32](fd)
    return out^


def entry(name: String, dims: List[UInt64], t: UInt32) -> GGUFDirectoryEntry:
    return GGUFDirectoryEntry(name, dims, t, 0, 0)


def main() raises:
    var arguments = argv()
    if len(arguments) != 4:
        raise Error("usage: test_quantize_streaming_qc_6 <source.gguf> <ref.gguf> <out.gguf>")
    var source_path = arguments[1]
    var ref_path = arguments[2]
    var out_path = arguments[3]

    # --- (A) Q8_0 dequant kind: hand-built blocks, longhand values ---
    check(dequant_input_supported(8), "A: Q8_0 (8) must be a supported dequant input")
    check(dequant_input_type_name(8) == "Q8_0", "A: type 8 must name Q8_0")
    var payload = List[UInt8]()
    # block 0: d = 0.5 (f16 0x3800), qs = lane - 16 for lane 0..31
    payload.append(UInt8(0x00))
    payload.append(UInt8(0x38))
    for lane in range(32):
        payload.append(UInt8((lane - 16) % 256))
    # block 1: d = -2.0 (f16 0xC000), qs all 3
    payload.append(UInt8(0x00))
    payload.append(UInt8(0xC0))
    for _ in range(32):
        payload.append(UInt8(3))
    var well = MimirWell(4096)
    var buf = well.allocate(512).unsafe_bitcast[UInt8]()
    for i in range(len(payload)):
        buf.unsafe_store(i, payload[i])
    var w: Bytes = buf
    for lane in range(32):
        var v = dequantize_value_f32(w, 0, 8, lane)
        check(v == Float32(lane - 16) * Float32(0.5), "A: block0 lane " + String(lane) + " must be q*d exactly")
    for lane in range(32):
        var v = dequantize_value_f32(w, 0, 8, 32 + lane)
        check(v == Float32(-6.0), "A: block1 lane " + String(lane) + " must be -6.0")
    var rng = dequantize_range_f32(w, 0, 8, 16, 32)
    check(len(rng) == 32, "A: range length")
    check(rng[0] == Float32(0.0) and rng[31] == Float32(-6.0), "A: range crosses the block boundary exactly")
    print("PASS A: Q8_0 dequant kind exact on hand-built blocks (d=0.5 signed lanes; d=-2.0 block; cross-block range)")

    # --- (B) the QC-6 plan: policy, tiling gate, fallbacks ---
    var d5120 = List[UInt64]()
    d5120.append(UInt64(5120))
    d5120.append(UInt64(6144))
    var p = q4_k_m_plan_qc6("blk.3.attn_v.weight", entry("blk.3.attn_v.weight", d5120.copy(), UInt32(8)), 64)
    check(p[0] == 14, "B: blk.3 attn_v (use_more_bits) must plan Q6_K")
    p = q4_k_m_plan_qc6("blk.20.attn_v.weight", entry("blk.20.attn_v.weight", d5120.copy(), UInt32(8)), 64)
    check(p[0] == 12, "B: blk.20 attn_v must plan Q4_K")
    var ddown = List[UInt64]()
    ddown.append(UInt64(17408))
    ddown.append(UInt64(5120))
    p = q4_k_m_plan_qc6("blk.22.ffn_down.weight", entry("blk.22.ffn_down.weight", ddown.copy(), UInt32(8)), 64)
    check(p[0] == 14, "B: blk.22 ffn_down (use_more_bits) must plan Q6_K")
    p = q4_k_m_plan_qc6("blk.21.ffn_down.weight", entry("blk.21.ffn_down.weight", ddown.copy(), UInt32(8)), 64)
    check(p[0] == 12, "B: blk.21 ffn_down must plan Q4_K")
    var dembd = List[UInt64]()
    dembd.append(UInt64(5120))
    dembd.append(UInt64(248320))
    p = q4_k_m_plan_qc6("output.weight", entry("output.weight", dembd.copy(), UInt32(8)), 64)
    check(p[0] == 14, "B: output.weight must plan Q6_K")
    p = q4_k_m_plan_qc6("token_embd.weight", entry("token_embd.weight", dembd.copy(), UInt32(8)), 64)
    check(p[0] == 12, "B: token_embd.weight must plan Q4_K")
    var d64 = List[UInt64]()
    d64.append(UInt64(64))
    d64.append(UInt64(172))
    p = q4_k_m_plan_qc6("blk.0.ffn_gate.weight", entry("blk.0.ffn_gate.weight", d64.copy(), UInt32(1)), 5)
    check(p[0] == 8, "B: dim0=64 Q4_K designee must fall back to Q8_0")
    var dout = List[UInt64]()
    dout.append(UInt64(64))
    dout.append(UInt64(512))
    p = q4_k_m_plan_qc6("output.weight", entry("output.weight", dout.copy(), UInt32(1)), 5)
    check(p[0] == 8, "B: dim0=64 Q6_K designee must fall back to Q8_0 (llama rule)")
    var d172 = List[UInt64]()
    d172.append(UInt64(172))
    d172.append(UInt64(64))
    p = q4_k_m_plan_qc6("blk.0.ffn_down.weight", entry("blk.0.ffn_down.weight", d172.copy(), UInt32(1)), 5)
    check(p[0] == -1 and "not a multiple of 32" in p[1], "B: dim0=172 must keep at source with the shape reason")
    var dconv = List[UInt64]()
    dconv.append(UInt64(4))
    dconv.append(UInt64(10240))
    p = q4_k_m_plan_qc6("blk.0.ssm_conv1d.weight", entry("blk.0.ssm_conv1d.weight", dconv.copy(), UInt32(0)), 64)
    check(p[0] == -1 and "ssm_conv1d" in p[1], "B: ssm_conv1d must keep at source (QC-0 section 3)")
    var d48 = List[UInt64]()
    d48.append(UInt64(48))
    p = q4_k_m_plan_qc6("blk.0.ssm_a", entry("blk.0.ssm_a", d48.copy(), UInt32(0)), 64)
    check(p[0] == -1 and "one-dimensional" in p[1], "B: rank-1 must keep with the 1-D reason")
    p = q4_k_m_plan_qc6("blk.0.attn_q.weight", entry("blk.0.attn_q.weight", d5120.copy(), UInt32(2)), 64)
    check(p[0] == -1 and "no F32 dequantizer" in p[1], "B: unwired source type (Q4_0) must keep with the dequant reason")
    print("PASS B: QC-6 plan -- file_type-15 policy on 256-aligned shapes; Q8_0 fallback at dim0%32==0; keep-at-source named for dim0%32!=0, ssm_conv1d, rank-1, unwired types")

    # --- (C) stories260K through the streaming K path ---
    var ref_report = quantize_gguf_q8_0_streaming(source_path, ref_path)
    check(ref_report.file_type == 7, "C: QC-3b reference must carry file_type 7")
    var report = quantize_gguf_q4_k_m_streaming_qc6(source_path, out_path)
    check(report.file_type == 15, "C: QC-6 product must carry file_type 15")
    check(report.quantized_count() == 32, "C: 32 matrices must quantize (Q8_0 fallback), got " + String(report.quantized_count()))
    check(report.kept_count() == 16, "C: 16 tensors must keep (11 norms + 5 ffn_down), got " + String(report.kept_count()))
    for i in range(len(report.quantized_names)):
        check(report.quantized_types[i] == UInt32(8), "C: every quantized tensor must be the Q8_0 fallback: " + report.quantized_names[i])
    var saw_down_keep = 0
    for i in range(len(report.kept_names)):
        if report.kept_names[i].endswith(".ffn_down.weight"):
            saw_down_keep += 1
            check("not a multiple of 32" in report.kept_reasons[i], "C: ffn_down keep reason must name the shape")
            check(report.kept_types[i] == UInt32(GGMLType.F16), "C: ffn_down must stay F16")
    check(saw_down_keep == 5, "C: exactly 5 ffn_down keeps")
    print("PASS C1: stories policy under the tiling rule -- 32x Q8_0 fallback, 5x ffn_down kept F16 (dim0 172), 11x norms kept")

    # payload identity vs the QC-3b proven product, tensor by tensor
    var ref_head = read_gguf_header_copy(ref_path)
    var out_head = read_gguf_header_copy(out_path)
    check(len(out_head.directory) == len(ref_head.directory), "C: directory size must match reference")
    var ref_bytes = read_file_bytes(ref_path)
    var out_bytes = read_file_bytes(out_path)
    for i in range(len(ref_head.directory)):
        var r = ref_head.directory[i].copy()
        var o = out_head.directory[i].copy()
        check(o.name == r.name, "C: tensor order mismatch at " + String(i))
        check(o.tensor_type == r.tensor_type, "C: tensor type mismatch for " + r.name)
        check(o.byte_size == r.byte_size, "C: tensor byte size mismatch for " + r.name)
        var rb = ref_head.data_offset + r.relative_offset
        var ob = out_head.data_offset + o.relative_offset
        for j in range(r.byte_size):
            check(out_bytes[ob + j] == ref_bytes[rb + j], "C: payload byte mismatch: " + r.name + " at " + String(j))
    print("PASS C2: QC-6 stories product is payload-identical to QC-3b's proven Q8_0 product, tensor by tensor (only general.file_type differs: 15 vs 7)")

    # admission: GGUFSeer VALIDATED
    var seer = GGUFSeer(out_path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(2 * 1024 * 1024)
    seer.mmap_and_load(pool, tokenizer)
    check(seer.is_loaded and seer.state == GGUFState.VALIDATED, "C: GGUFSeer must VALIDATE the QC-6 stories product")
    check(tokenizer.vocab_size == 512, "C: tokenizer vocab must be 512")
    print("PASS C3: GGUFSeer loads the QC-6 stories product to VALIDATED")

    # admission: PackedGGUF constructs (refused QC-5's flat product)
    var packed = PackedGGUF(out_path)
    _ = packed
    print("PASS C4: PackedGGUF constructs on the QC-6 stories product (per-row shapes valid under the fallbacks)")

    # forward: token-identical generation vs the QC-3b product
    var engine_ref = AesirEngine(ref_path, knowledge_capacity=1)
    var result_ref = engine_ref.generate_tokens("One day, Timmy went to", 8)
    var engine_out = AesirEngine(out_path, knowledge_capacity=1)
    var result_out = engine_out.generate_tokens("One day, Timmy went to", 8)
    check(len(result_out.token_ids) == len(result_ref.token_ids), "C: generation length must match reference")
    for i in range(len(result_ref.token_ids)):
        check(result_out.token_ids[i] == result_ref.token_ids[i], "C: generated token mismatch at " + String(i))
    print("PASS C5: engine generates token-identically from the QC-6 product and the QC-3b product (" + String(len(result_out.token_ids)) + " tokens)")
    print("QC-6 streaming converter proof: ALL PASS")
