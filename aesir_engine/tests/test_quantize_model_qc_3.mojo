# tests/test_quantize_model_qc_3.mojo
# QC-3a proof: whole-model Q8_0 conversion of stories260K.F16.gguf
# through cli/quantize.mojo (QC-1 writer + QC-2 quantizer), and the
# emitted file's load proof through BOTH readers plus the engine.
#
# Usage: test_quantize_model_qc_3 <stories260K.F16.gguf> <out.gguf>
#
# Source census (independent Python parse before this test was
# written; fixture pin sha256 57a81ed1...09da1a0e, 601,248 B,
# 21 KV, 48 tensors, data_offset 14240): 37 F16 weight matrices +
# 11 F32 one-dimensional norms. Policy expectation, derived from
# the census, not from the converter: 32 matrices have dim0 = 64
# (multiple of 32) and quantize; the 5 blk.*.ffn_down.weight
# matrices have dim0 = 172 (172 % 32 = 12) and stay F16; the 11
# norms stay F32. Quantized elements 237,056 -> 7,408 blocks ->
# 251,872 Q8_0 bytes; kept payload 110,080 (F16) + 2,816 (F32) =
# 112,896 bytes; with inter-tensor alignment padding the emitted
# file is 379,152 bytes (payload 364,768 + data_offset 14,240 +
# 144 bytes of inter-tensor alignment padding: nine 16-byte pads
# after the nine non-final 11,696-byte gate/up payloads; no pad
# follows the final tensor).

from std.ffi import external_call
from std.memory import bitcast
from std.sys import argv

from core.mimir_well import MimirWell, f16, f32
from core.quantize import Q8_0_BLOCK_BYTES, Q8_0_BLOCK_ELEMENTS
from cli.quantize import quantize_gguf_q8_0
from loader.gguf import GGMLType, GGUFSeer, GGUFState
from loader.gguf_writer import (
    gguf_kv_equal,
    read_gguf_header_copy,
)
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


def abs_f32(value: Float32) -> Float32:
    return value if value >= Float32(0.0) else -value


def main() raises:
    var arguments = argv()
    if len(arguments) != 3:
        raise Error("usage: test_quantize_model_qc_3 <source.gguf> <out.gguf>")
    var source_path = arguments[1]
    var out_path = arguments[2]

    var src_head = read_gguf_header_copy(source_path)
    check(len(src_head.kvs) == 21, "source: kv count must be 21")
    check(len(src_head.directory) == 48, "source: tensor count must be 48")
    check(src_head.data_offset == 14240, "source: data_offset must be 14240")

    # --- conversion through the slice's own code path ---
    var report = quantize_gguf_q8_0(source_path, out_path)
    check(report.quantized_count() == 32, "policy: quantized count must be 32, got " + String(report.quantized_count()))
    check(report.kept_count() == 16, "policy: kept count must be 16, got " + String(report.kept_count()))
    check(report.quantized_output_total() == 251872, "size: Q8_0 payload total must be 251872, got " + String(report.quantized_output_total()))
    check(report.kept_total() == 112896, "size: kept payload total must be 112896, got " + String(report.kept_total()))
    check(report.output_bytes == 379152, "size: emitted file must be 379152 bytes, got " + String(report.output_bytes))
    var kept_ffn_down = 0
    var kept_norms = 0
    for i in range(len(report.kept_names)):
        var name = report.kept_names[i]
        if name.endswith(".ffn_down.weight"):
            kept_ffn_down += 1
            check(report.kept_types[i] == UInt32(GGMLType.F16), "policy: ffn_down must stay F16: " + name)
            check("not a multiple" in report.kept_reasons[i], "policy: ffn_down reason must name dim0 alignment: " + name)
        else:
            kept_norms += 1
            check(report.kept_types[i] == UInt32(GGMLType.F32), "policy: kept non-ffn_down must be an F32 norm: " + name)
            check(name.endswith("_norm.weight") or name == "output_norm.weight", "policy: unexpected kept tensor: " + name)
    check(kept_ffn_down == 5, "policy: exactly 5 ffn_down tensors stay F16, got " + String(kept_ffn_down))
    check(kept_norms == 11, "policy: exactly 11 norms stay F32, got " + String(kept_norms))
    print("PASS: conversion policy as applied -- 32 quantized to Q8_0; 16 kept (5x ffn_down F16, dim0 172 not a multiple of 32; 11x norms F32, one-dimensional), every kept tensor named with its reason")

    # --- emitted file structure: header copy vs source ---
    var out_head = read_gguf_header_copy(out_path)
    check(len(out_head.kvs) == 21, "out: kv count must be 21")
    check(len(out_head.directory) == 48, "out: tensor count must be 48")
    check(out_head.data_offset == src_head.data_offset, "out: data_offset must match source (same header/KV/directory size)")
    for i in range(len(src_head.kvs)):
        if src_head.kvs[i].key == "general.file_type":
            check(out_head.kvs[i].value.as_u32() == 7, "out: general.file_type must be 7 (Q8_0)")
        else:
            check(gguf_kv_equal(out_head.kvs[i], src_head.kvs[i]), "out: KV must be copied verbatim: " + src_head.kvs[i].key)
    print("PASS: emitted metadata == source metadata except general.file_type = 7; all 21 KVs accounted for")
    for i in range(len(src_head.directory)):
        var s = src_head.directory[i].copy()
        var o = out_head.directory[i].copy()
        check(o.name == s.name, "out: tensor order/name mismatch at " + String(i))
        check(len(o.dims) == len(s.dims), "out: dims rank mismatch for " + s.name)
        for d in range(len(s.dims)):
            check(o.dims[d] == s.dims[d], "out: dims mismatch for " + s.name)
        check(o.relative_offset % 32 == 0, "out: offset not 32-aligned for " + s.name)
        var quantized = s.name in report.quantized_names
        if quantized:
            check(o.tensor_type == UInt32(GGMLType.Q8_0), "out: quantized tensor must be type Q8_0: " + s.name)
        else:
            check(o.tensor_type == s.tensor_type, "out: kept tensor must keep source type: " + s.name)
            check(o.byte_size == s.byte_size, "out: kept tensor must keep byte size: " + s.name)
    print("PASS: emitted directory preserves names/shapes/order; quantized tensors are Q8_0, kept tensors keep source type and size; all offsets 32-aligned")

    # --- kept payloads are byte-identical to the source payloads ---
    var src_bytes = read_file_bytes(source_path)
    var out_bytes = read_file_bytes(out_path)
    check(len(out_bytes) == 379152, "out: file length must be 379152")
    for i in range(len(src_head.directory)):
        var s = src_head.directory[i].copy()
        if s.name in report.quantized_names:
            continue
        var s_base = src_head.data_offset + s.relative_offset
        var o_base = out_head.data_offset + out_head.directory[i].relative_offset
        for j in range(s.byte_size):
            check(out_bytes[o_base + j] == src_bytes[s_base + j], "kept payload byte mismatch: " + s.name + " at payload byte " + String(j))
    print("PASS: every kept tensor's payload is byte-identical to the source payload")

    # --- Q8_0 payload correctness against the QC-2 proven bound ---
    # For two representative tensors, dequantize the emitted blocks
    # by hand (q * f16 d) and assert the QC-2 per-element bound with
    # d and amax recomputed from the source F16 values.
    var probe_names = List[String]()
    probe_names.append(String("token_embd.weight"))
    probe_names.append(String("blk.0.attn_q.weight"))
    for probe in probe_names:
        var s_idx = -1
        var o_idx = -1
        for i in range(len(src_head.directory)):
            if src_head.directory[i].name == probe:
                s_idx = i
            if out_head.directory[i].name == probe:
                o_idx = i
        check(s_idx >= 0 and o_idx >= 0, "probe tensor missing: " + probe)
        var s_entry = src_head.directory[s_idx].copy()
        var o_entry = out_head.directory[o_idx].copy()
        var count = 1
        for dim in s_entry.dims:
            count *= Int(dim)
        check(count % Q8_0_BLOCK_ELEMENTS == 0, "probe: count must be block aligned")
        var s_base = src_head.data_offset + s_entry.relative_offset
        var o_base = out_head.data_offset + o_entry.relative_offset
        var worst_ratio = Float32(0.0)
        for block in range(count // Q8_0_BLOCK_ELEMENTS):
            var amax = Float32(0.0)
            for lane in range(Q8_0_BLOCK_ELEMENTS):
                var bits = UInt16(src_bytes[s_base + (block * 32 + lane) * 2]) | (UInt16(src_bytes[s_base + (block * 32 + lane) * 2 + 1]) << 8)
                var value = bitcast[DType.float16](bits).cast[f32]()
                if abs_f32(value) > amax:
                    amax = abs_f32(value)
            var d = amax / Float32(127.0)
            var d_bits = UInt16(out_bytes[o_base + block * Q8_0_BLOCK_BYTES]) | (UInt16(out_bytes[o_base + block * Q8_0_BLOCK_BYTES + 1]) << 8)
            var d_hat = bitcast[DType.float16](d_bits).cast[f32]()
            var bound = d_hat / Float32(2.0) + Float32(127.0) * abs_f32(d_hat - d) + amax * Float32(0.0009765625) + d_hat * Float32(0.002) + Float32(0.0000001)
            for lane in range(Q8_0_BLOCK_ELEMENTS):
                var bits = UInt16(src_bytes[s_base + (block * 32 + lane) * 2]) | (UInt16(src_bytes[s_base + (block * 32 + lane) * 2 + 1]) << 8)
                var value = bitcast[DType.float16](bits).cast[f32]()
                var q_byte = out_bytes[o_base + block * Q8_0_BLOCK_BYTES + 2 + lane]
                var q = Int(q_byte) if q_byte < 128 else Int(q_byte) - 256
                var dequant = Float32(q) * d_hat
                var err = abs_f32(dequant - value)
                check(err <= bound, "probe: round-trip bound violated for " + probe + " block " + String(block) + " lane " + String(lane))
                if bound > Float32(0.0) and err / bound > worst_ratio:
                    worst_ratio = err / bound
        print("PASS: emitted Q8_0 blocks for", probe, "dequantize inside the QC-2 proven bound (worst err/bound", worst_ratio, ")")

    # --- load proof: GGUFSeer full load reaches VALIDATED ---
    var seer = GGUFSeer(out_path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(2 * 1024 * 1024)
    seer.mmap_and_load(pool, tokenizer)
    check(seer.is_loaded and seer.state == GGUFState.VALIDATED, "load: emitted file must reach GGUFSeer VALIDATED")
    check(seer.config.architecture == "llama", "load: architecture must be llama")
    check(seer.tensor_count == 48 and seer.kv_count == 21, "load: header counts must match source")
    check(tokenizer.vocab_size == 512, "load: tokenizer vocab must be 512")
    check(seer.tensor_types.get("token_embd.weight", UInt32(99)) == UInt32(GGMLType.Q8_0), "load: token_embd must map as Q8_0")
    check(seer.tensor_types.get("output.weight", UInt32(99)) == UInt32(GGMLType.Q8_0), "load: output must map as Q8_0")
    check(seer.tensor_types.get("output_norm.weight", UInt32(99)) == UInt32(GGMLType.F32), "load: output_norm must map as F32")
    check(seer.tensor_types.get("blk.0.ffn_down.weight", UInt32(99)) == UInt32(GGMLType.F16), "load: ffn_down must map as F16")
    print("PASS: GGUFSeer loads the emitted file to VALIDATED (llama config + tokenizer agree; tensor types as emitted)")

    # --- load proof: PackedGGUF constructs in full ---
    var packed = PackedGGUF(out_path)
    check(packed.data_offset == out_head.data_offset, "packed: data_offset mismatch")
    check(len(packed.tensors) == 48, "packed: must hold 48 tensors")
    for entry in out_head.directory:
        var packed_entry = packed.tensors[entry.name]
        check(packed_entry.offset == out_head.data_offset + entry.relative_offset, "packed: offset mismatch for " + entry.name)
        check(packed_entry.byte_count == entry.byte_size, "packed: byte_count mismatch for " + entry.name)
        check(packed_entry.kind == Int(entry.tensor_type), "packed: kind mismatch for " + entry.name)
    check(packed.integer("general.file_type") == 7, "packed: general.file_type must read 7")
    print("PASS: PackedGGUF loads the emitted file in full (offsets/kinds/byte counts for all 48 tensors; file_type reads 7)")

    # --- engine runs the emitted file ---
    var engine = AesirEngine(out_path, knowledge_capacity=1)
    var result = engine.generate_tokens("One day, Timmy went to", 8)
    check(result.prompt_token_count == 8, "engine: prompt token count must be 8")
    check(result.generated_token_count() == 8, "engine: must generate exactly 8 tokens")
    var ids = String("")
    for i in range(len(result.token_ids)):
        ids += String(result.token_ids[i]) + String(" ")
    print("PASS: engine runs the emitted Q8_0 file (greedy 8 from the reference prompt:", ids, ") text:", result.text)

    print("QC-3a conversion + load proof: ALL PASS")
