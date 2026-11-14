# tests/test_quantize_model_qc_5.mojo
# QC-5 proof: whole-model Q4_K_M conversion of stories260K.F16.gguf through
# cli/quantize.mojo (QC-1 writer + QC-5 K-quant packers + the llama.cpp
# Q4_K_M policy), and the emitted file's load proof through BOTH readers
# plus the engine.
#
# Usage: test_quantize_model_qc_5 <stories260K.F16.gguf> <out.gguf>
#
# Source census (independent Python parse, QC-5 stage 1; fixture pin sha256
# 57a81ed1...09da1a0e, 601,248 B, 21 KVs, 48 tensors, data_offset 14240):
# 37 F16 weight matrices + 11 F32 one-dimensional norms. Every matrix's
# TOTAL element count is a multiple of 256 (flat tiling -- the engine's own
# pricing, loader/gguf _tensor_byte_size), while NO matrix has dim0
# divisible by 256 (llama.cpp's per-row tiling would fall back; see
# QC-5-NOTES for the arbitration).
#
# Policy expectation, derived from the census + llama.cpp's Q4_K_M rules
# (n_layers = 5; use_more_bits(i, 5) holds exactly for i in {2, 4}):
#   Q6_K (5): output.weight, blk.2/4.attn_v.weight, blk.2/4.ffn_down.weight
#             -- 58,880 elements, 230 blocks, 48,300 bytes
#   Q4_K (32): every other matrix
#             -- 233,216 elements, 911 blocks, 131,184 bytes
#   kept (11): the F32 norms, byte-identical, 2,816 bytes
# Emitted file: payload 182,300 + header 14,240 + alignment padding 276
# (nine 16 B pads after the non-final 6,192 B ffn_gate/ffn_up payloads,
# three 16 B pads after the Q4_K ffn_down payloads, two 16 B pads after
# the 1,680 B Q6_K attn_v payloads, two 26 B pads after the 9,030 B
# Q6_K ffn_down payloads; blk.4.ffn_up is the final tensor and takes
# no pad) = 196,816 bytes.
#
# Beyond structure, EVERY quantized element of the emitted file is checked
# against the QC-5 proven per-sub-block bound (the stage-2 formulas, with
# ideal fits recomputed from the source values and stored reconstructions
# parsed from the emitted bytes).

from std.ffi import external_call
from std.memory import bitcast
from std.sys import argv
from core.dequantize_input import dequantize_range_f32
from core.mimir_well import MimirWell, f16, f32
from core.quantize import Q4_K_BLOCK_BYTES, Q6_K_BLOCK_BYTES
from cli.quantize import quantize_gguf_q4_k_m
from loader.gguf import GGMLType, GGUFSeer, GGUFState
from loader.gguf_writer import gguf_kv_equal, read_gguf_header_copy
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


def f16_at(data: List[UInt8], byte_offset: Int) -> Float32:
    var bits = UInt16(data[byte_offset]) | (UInt16(data[byte_offset + 1]) << 8)
    return bitcast[DType.float16](bits).cast[f32]()


def q4_scale_min(
    data: List[UInt8], base: Int, block: Int, j: Int
) -> Tuple[Int, Int]:
    # Longhand get_scale_min_k4 over the 12 scale bytes at base+block*144+4.
    var p = base + block * Q4_K_BLOCK_BYTES + 4
    if j < 4:
        return (Int(data[p + j]) & 63, Int(data[p + j + 4]) & 63)
    var scale = (Int(data[p + j + 4]) & 15) | ((Int(data[p + j - 4]) >> 6) << 4)
    var minimum = (Int(data[p + j + 4]) >> 4) | ((Int(data[p + j]) >> 6) << 4)
    return (scale, minimum)


def q4_ideal(values: List[Float32], sub: Int) -> Tuple[Float32, Float32]:
    var mn = values[sub]
    var mx = values[sub]
    for i in range(32):
        if values[sub + i] < mn:
            mn = values[sub + i]
        if values[sub + i] > mx:
            mx = values[sub + i]
    if mx == mn:
        if mn < Float32(0.0):
            return (Float32(0.0), -mn)
        return (mn / Float32(15.0), Float32(0.0))
    var min_eff = mn if mn < Float32(0.0) else Float32(0.0)
    return ((mx - min_eff) / Float32(15.0), -min_eff)


def q6_ideal(values: List[Float32], sub: Int) -> Float32:
    var amax = Float32(0.0)
    for i in range(16):
        var magnitude = abs_f32(values[sub + i])
        if magnitude > amax:
            amax = magnitude
    return amax / Float32(32.0)


def main() raises:
    var arguments = argv()
    if len(arguments) != 3:
        raise Error("usage: test_quantize_model_qc_5 <source.gguf> <out.gguf>")
    var source_path = arguments[1]
    var out_path = arguments[2]

    var src_head = read_gguf_header_copy(source_path)
    check(len(src_head.kvs) == 21, "source: kv count must be 21")
    check(len(src_head.directory) == 48, "source: tensor count must be 48")
    check(src_head.data_offset == 14240, "source: data_offset must be 14240")

    # --- conversion through the slice's own code path ---
    var report = quantize_gguf_q4_k_m(source_path, out_path)
    check(report.quantized_count() == 37, "policy: quantized count must be 37, got " + String(report.quantized_count()))
    check(report.kept_count() == 11, "policy: kept count must be 11, got " + String(report.kept_count()))
    check(report.quantized_output_total() == 179484, "size: K payload total must be 179484, got " + String(report.quantized_output_total()))
    check(report.kept_total() == 2816, "size: kept payload total must be 2816, got " + String(report.kept_total()))
    check(report.output_bytes == 196816, "size: emitted file must be 196816 bytes, got " + String(report.output_bytes))
    check(report.file_type == 15, "report: file_type must be 15 (Q4_K_M)")

    var q6_names = List[String]()
    q6_names.append(String("output.weight"))
    q6_names.append(String("blk.2.attn_v.weight"))
    q6_names.append(String("blk.4.attn_v.weight"))
    q6_names.append(String("blk.2.ffn_down.weight"))
    q6_names.append(String("blk.4.ffn_down.weight"))
    var q4_count = 0
    var q6_count = 0
    var q6_payload = 0
    var q4_payload = 0
    for i in range(len(report.quantized_names)):
        var name = report.quantized_names[i]
        if name in q6_names:
            check(report.quantized_types[i] == UInt32(14), "policy: " + name + " must be Q6_K (14)")
            q6_count += 1
            q6_payload += report.quantized_output_bytes[i]
        else:
            check(report.quantized_types[i] == UInt32(12), "policy: " + name + " must be Q4_K (12)")
            q4_count += 1
            q4_payload += report.quantized_output_bytes[i]
    check(q6_count == 5, "policy: exactly 5 Q6_K tensors, got " + String(q6_count))
    check(q4_count == 32, "policy: exactly 32 Q4_K tensors, got " + String(q4_count))
    check(q6_payload == 48300, "size: Q6_K payload must be 48300, got " + String(q6_payload))
    check(q4_payload == 131184, "size: Q4_K payload must be 131184, got " + String(q4_payload))
    for i in range(len(report.kept_names)):
        var name = report.kept_names[i]
        check(name.endswith("_norm.weight"), "policy: unexpected kept tensor: " + name)
        check(report.kept_types[i] == UInt32(GGMLType.F32), "policy: kept norm must stay F32: " + name)
        check("one-dimensional" in report.kept_reasons[i], "policy: kept reason must name the 1-D class: " + name)
    print("PASS: conversion policy as applied -- 32x Q4_K + 5x Q6_K (output, blk.2/4 attn_v, blk.2/4 ffn_down); 11x F32 norms kept with reasons")

    # --- emitted file structure: header copy vs source ---
    var out_head = read_gguf_header_copy(out_path)
    check(len(out_head.kvs) == 21, "out: kv count must be 21")
    check(len(out_head.directory) == 48, "out: tensor count must be 48")
    check(out_head.data_offset == src_head.data_offset, "out: data_offset must match source")
    for i in range(len(src_head.kvs)):
        if src_head.kvs[i].key == "general.file_type":
            check(out_head.kvs[i].value.as_u32() == 15, "out: general.file_type must be 15 (Q4_K_M)")
        else:
            check(gguf_kv_equal(out_head.kvs[i], src_head.kvs[i]), "out: KV must be copied verbatim: " + src_head.kvs[i].key)
    print("PASS: emitted metadata == source metadata except general.file_type = 15; all 21 KVs accounted for")
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
            var want = UInt32(14) if s.name in q6_names else UInt32(12)
            check(o.tensor_type == want, "out: quantized tensor has wrong kind: " + s.name)
        else:
            check(o.tensor_type == s.tensor_type, "out: kept tensor must keep source type: " + s.name)
            check(o.byte_size == s.byte_size, "out: kept tensor must keep byte size: " + s.name)
    print("PASS: emitted directory preserves names/shapes/order; kinds as planned; all offsets 32-aligned")

    # --- kept payloads byte-identical; full bound sweep over quantized ---
    var src_bytes = read_file_bytes(source_path)
    var out_bytes = read_file_bytes(out_path)
    check(len(src_bytes) == 601248, "source: file length must be 601248")
    check(len(out_bytes) == 196816, "out: file length must be 196816")
    for i in range(len(src_head.directory)):
        var s = src_head.directory[i].copy()
        if s.name in report.quantized_names:
            continue
        var s_base = src_head.data_offset + s.relative_offset
        var o_base = out_head.data_offset + out_head.directory[i].relative_offset
        for j in range(s.byte_size):
            check(out_bytes[o_base + j] == src_bytes[s_base + j], "kept payload byte mismatch: " + s.name + " at payload byte " + String(j))
    print("PASS: every kept tensor's payload is byte-identical to the source payload")

    var well = MimirWell(1048576)
    var buf = well.allocate((len(out_bytes) + 1) // 2 + 16).unsafe_bitcast[UInt8]()
    for i in range(len(out_bytes)):
        buf.unsafe_store(i, out_bytes[i])
    var worst4 = Float32(0.0)
    var worst6 = Float32(0.0)
    for i in range(len(src_head.directory)):
        var s = src_head.directory[i].copy()
        if s.name not in report.quantized_names:
            continue
        var o = out_head.directory[i].copy()
        var count = 1
        for dim in s.dims:
            count *= Int(dim)
        var s_base = src_head.data_offset + s.relative_offset
        var o_base = out_head.data_offset + o.relative_offset
        var values = List[Float32]()
        values.reserve(count)
        for k in range(count):
            values.append(f16_at(src_bytes, s_base + k * 2))
        var back = dequantize_range_f32(buf, o_base, Int(o.tensor_type), 0, count)
        check(len(back) == count, "sweep: dequant count mismatch for " + s.name)
        if o.tensor_type == UInt32(12):
            for block in range(count // 256):
                var d = f16_at(out_bytes, o_base + block * Q4_K_BLOCK_BYTES)
                var dmin = f16_at(out_bytes, o_base + block * Q4_K_BLOCK_BYTES + 2)
                for j in range(8):
                    var sm = q4_scale_min(out_bytes, o_base, block, j)
                    var s_hat = d * Float32(sm[0])
                    var m_hat = dmin * Float32(sm[1])
                    var ideal = q4_ideal(values, block * 256 + j * 32)
                    for k in range(32):
                        var idx = block * 256 + j * 32 + k
                        var err = abs_f32(back[idx] - values[idx])
                        var bound = (
                            s_hat * Float32(0.5)
                            + Float32(15.0) * abs_f32(s_hat - ideal[0])
                            + abs_f32(m_hat - ideal[1])
                            + Float32(0.000001)
                            * (Float32(1.0) + abs_f32(values[idx]) + s_hat + m_hat)
                            + Float32(0.0000001)
                        )
                        check(err <= bound, "sweep: Q4_K bound violated for " + s.name + " at " + String(idx))
                        if bound > Float32(0.0) and err / bound > worst4:
                            worst4 = err / bound
        else:
            for block in range(count // 256):
                var d = f16_at(out_bytes, o_base + block * Q6_K_BLOCK_BYTES + 208)
                for g in range(16):
                    var sc_byte = Int(out_bytes[o_base + block * Q6_K_BLOCK_BYTES + 192 + g])
                    var sc = sc_byte if sc_byte < 128 else sc_byte - 256
                    var s_hat = d * Float32(sc)
                    var s_j = q6_ideal(values, block * 256 + g * 16)
                    for k in range(16):
                        var idx = block * 256 + g * 16 + k
                        var err = abs_f32(back[idx] - values[idx])
                        var bound = (
                            s_hat * Float32(0.5)
                            + Float32(32.0) * abs_f32(s_hat - s_j)
                            + s_j
                            + Float32(0.000001)
                            * (Float32(1.0) + abs_f32(values[idx]) + s_hat)
                            + Float32(0.0000001)
                        )
                        check(err <= bound, "sweep: Q6_K bound violated for " + s.name + " at " + String(idx))
                        if bound > Float32(0.0) and err / bound > worst6:
                            worst6 = err / bound
    print("PASS: whole-model bound sweep -- worst err/bound q4_k=" + String(worst4) + " q6_k=" + String(worst6))

    # --- load proof: GGUFSeer full load reaches VALIDATED ---
    var seer = GGUFSeer(out_path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(2 * 1024 * 1024)
    seer.mmap_and_load(pool, tokenizer)
    check(seer.is_loaded and seer.state == GGUFState.VALIDATED, "load: emitted file must reach GGUFSeer VALIDATED")
    check(seer.config.architecture == "llama", "load: architecture must be llama")
    check(seer.tensor_count == 48 and seer.kv_count == 21, "load: header counts must match source")
    check(tokenizer.vocab_size == 512, "load: tokenizer vocab must be 512")
    check(seer.tensor_types.get("token_embd.weight", UInt32(99)) == UInt32(12), "load: token_embd must map as Q4_K")
    check(seer.tensor_types.get("output.weight", UInt32(99)) == UInt32(14), "load: output must map as Q6_K")
    check(seer.tensor_types.get("blk.2.attn_v.weight", UInt32(99)) == UInt32(14), "load: blk.2 attn_v must map as Q6_K")
    check(seer.tensor_types.get("blk.0.attn_v.weight", UInt32(99)) == UInt32(12), "load: blk.0 attn_v must map as Q4_K")
    check(seer.tensor_types.get("blk.4.ffn_down.weight", UInt32(99)) == UInt32(14), "load: blk.4 ffn_down must map as Q6_K")
    check(seer.tensor_types.get("blk.1.ffn_down.weight", UInt32(99)) == UInt32(12), "load: blk.1 ffn_down must map as Q4_K")
    check(seer.tensor_types.get("output_norm.weight", UInt32(99)) == UInt32(GGMLType.F32), "load: output_norm must map as F32")
    print("PASS: GGUFSeer loads the emitted Q4_K_M file to VALIDATED (llama config + tokenizer agree; tensor kinds as emitted)")

    # --- admission probe: PackedGGUF (the per-row packed reader) ---
    # FINDING (QC-5-NOTES): PackedGGUF prices K-quant tensors PER ROW
    # (packed_row_bytes requires columns % 256 == 0) while GGUFSeer
    # prices them FLAT. A flat-tiled K tensor has no per-row
    # decomposition, so PackedGGUF refuses this file -- the named
    # admission difference vs the F16 source, which PackedGGUF admits.
    # The refusal text is asserted exactly, so a future flat-K
    # PackedGGUF must update this test deliberately.
    var packed_error = String("")
    try:
        var packed = PackedGGUF(out_path)
        _ = packed
    except err:
        packed_error = String(err)
    check(
        "K-quant row is not block aligned" in packed_error,
        "packed: expected the named per-row refusal, got: " + packed_error,
    )
    print("FINDING: PackedGGUF refuses the flat-tiled Q4_K_M file --", packed_error)

    # --- forward admission probe: AesirEngine generation ---
    # FINDING (QC-5-NOTES): the llama forward dispatches K tensors to
    # the fused K GEMM, which addresses blocks PER ROW
    # (blocks_per_row = A.cols // 256 in _gemm_k_fast) and refuses
    # A.cols % 256 != 0. stories260K contracts over dim0 64 / 172, so
    # no Q4_K_M file can execute in this forward for this model --
    # llama.cpp's own product avoids K kinds here entirely. The QC-5
    # grade is therefore taken on the dequantized weight set this
    # file encodes (stage 3c). The refusal text is asserted exactly.
    var engine_error = String("")
    try:
        var engine = AesirEngine(out_path, knowledge_capacity=1)
        var result = engine.generate_tokens("One day, Timmy went to", 8)
        _ = result
    except err:
        engine_error = String(err)
    check(
        "invalid shape or incomplete quantization block" in engine_error,
        "engine: expected the fused K GEMM per-row refusal, got: "
        + engine_error,
    )
    print("FINDING: AesirEngine forward refuses the Q4_K_M file --", engine_error)

    print("SIZE source=601248 ours=" + String(report.output_bytes) + " q8_0_product=379152")
    print("QC-5 conversion + load proof: ALL PASS")
