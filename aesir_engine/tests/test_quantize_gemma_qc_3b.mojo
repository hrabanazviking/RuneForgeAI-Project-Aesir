# tests/test_quantize_gemma_qc_3b.mojo
# QC-3b stage 3 load proof for the gemma-4-E2B Q8_0 conversion:
#   test_quantize_gemma_qc_3b <source.gguf> <emitted.gguf>
#
# Asserts: (1) emitted metadata == source metadata except
# general.file_type (15 -> 7), all 56 KVs incl. array values
# carried raw (the U-QC4 whole-model re-emission check); (2) the
# directory preserves names/shapes/order and every tensor's type
# matches the QC-3b policy (q8_0_keep_reason_dequant); (3) all
# offsets are alignment-divisible; (4) PackedGGUF constructs in
# full on BOTH files with offsets/kinds/byte counts agreeing with
# the header copies; (5) sampled rows of six named tensors (one
# per source class: Q4_K, Q5_K, Q6_K, BF16, F32) dequantize from
# the emitted Q8_0 blocks inside the QC-2 proven per-element
# bound, against source values read through the QC-3b dequantizing
# input path. GGUFSeer's full-load outcome is PRINTED for both
# files (state or exact refusal) -- the admission comparison the
# slice notes report; it is not asserted, because admission is a
# property of the source file's profile class, and the proof's
# claim is that conversion does not change it (the two printed
# states are compared in the notes, F-3a-1 discipline).

from std.memory import bitcast
from std.sys import argv

from core.mimir_well import MimirWell, f32
from cli.quantize import _read_row_f32, q8_0_keep_reason_dequant
from loader.gguf import GGMLType, GGUFSeer, GGUFState
from loader.gguf_writer import gguf_kv_equal, read_gguf_header_copy
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver


def check(condition: Bool, label: String) raises:
    if not condition:
        raise Error("QC-3b gemma load-proof check failed: " + label)


def abs_f32(value: Float32) -> Float32:
    return value if value >= Float32(0.0) else -value


def type_name(t: UInt32) -> String:
    if t == 0:
        return String("F32")
    if t == 1:
        return String("F16")
    if t == 30:
        return String("BF16")
    if t == 8:
        return String("Q8_0")
    if t == 12:
        return String("Q4_K")
    if t == 13:
        return String("Q5_K")
    if t == 14:
        return String("Q6_K")
    return String("T") + String(t)


def load_state(path: String) -> String:
    try:
        var seer = GGUFSeer(path)
        var tokenizer = RuneWeaver()
        var pool = MimirWell(512 * 1024 * 1024)
        seer.mmap_and_load(pool, tokenizer)
        if seer.is_loaded and seer.state == GGUFState.VALIDATED:
            return String("VALIDATED arch=") + seer.config.architecture + " tensors=" + String(seer.tensor_count) + " kvs=" + String(seer.kv_count) + " vocab=" + String(tokenizer.vocab_size)
        return String("NOT_VALIDATED state=") + String(Int(seer.state)) + " is_loaded=" + String(seer.is_loaded)
    except e:
        return String("RAISED: ") + String(e)


def main() raises:
    var arguments = argv()
    if len(arguments) != 3:
        raise Error("usage: test_quantize_gemma_qc_3b <source.gguf> <emitted.gguf>")
    var src_path = arguments[1]
    var out_path = arguments[2]
    var src_head = read_gguf_header_copy(src_path)
    var out_head = read_gguf_header_copy(out_path)
    check(len(src_head.kvs) == len(out_head.kvs), "KV count differs")
    var file_type_seen = False
    for i in range(len(src_head.kvs)):
        var s_kv = src_head.kvs[i].copy()
        var o_kv = out_head.kvs[i].copy()
        check(s_kv.key == o_kv.key, "KV key order differs at " + String(i))
        if s_kv.key == "general.file_type":
            file_type_seen = True
            check(s_kv.value.as_u32() == UInt32(15), "source file_type must be 15")
            check(o_kv.value.as_u32() == UInt32(7), "emitted file_type must be 7")
        else:
            check(gguf_kv_equal(s_kv, o_kv), "KV value differs for key " + s_kv.key)
    check(file_type_seen, "general.file_type key missing")
    print("PASS: metadata identical except general.file_type 15 -> 7 (", len(src_head.kvs), " KVs, arrays carried raw)")
    check(len(src_head.directory) == len(out_head.directory), "tensor count differs")
    var quantized = 0
    var kept = 0
    var src_census = List[String]()
    var src_counts = List[Int]()
    var out_census = List[String]()
    var out_counts = List[Int]()
    for i in range(len(src_head.directory)):
        var s_entry = src_head.directory[i].copy()
        var o_entry = out_head.directory[i].copy()
        check(s_entry.name == o_entry.name, "tensor order differs at " + String(i))
        check(len(s_entry.dims) == len(o_entry.dims), "rank differs for " + s_entry.name)
        for d in range(len(s_entry.dims)):
            check(s_entry.dims[d] == o_entry.dims[d], "shape differs for " + s_entry.name)
        check(o_entry.relative_offset % out_head.alignment == 0, "offset not aligned for " + o_entry.name)
        var reason = q8_0_keep_reason_dequant(s_entry.name, s_entry.copy())
        if reason.byte_length() == 0:
            quantized += 1
            check(o_entry.tensor_type == UInt32(GGMLType.Q8_0), "policy says quantize but emitted type is not Q8_0: " + s_entry.name)
        else:
            kept += 1
            check(o_entry.tensor_type == s_entry.tensor_type, "policy says keep but emitted type changed: " + s_entry.name)
        var s_name = type_name(s_entry.tensor_type)
        var found = -1
        for j in range(len(src_census)):
            if src_census[j] == s_name:
                found = j
        if found < 0:
            src_census.append(s_name)
            src_counts.append(1)
        else:
            src_counts[found] += 1
        var o_name = type_name(o_entry.tensor_type)
        found = -1
        for j in range(len(out_census)):
            if out_census[j] == o_name:
                found = j
        if found < 0:
            out_census.append(o_name)
            out_counts.append(1)
        else:
            out_counts[found] += 1
    print("CENSUS source:", end="")
    for j in range(len(src_census)):
        print(" ", src_census[j], "x", src_counts[j], end="")
    print("")
    print("CENSUS emitted:", end="")
    for j in range(len(out_census)):
        print(" ", out_census[j], "x", out_counts[j], end="")
    print("")
    print("POLICY quantized=", quantized, " kept=", kept)
    print("PASS: directory preserved; every emitted type matches the QC-3b policy; all offsets aligned")
    var src_packed = PackedGGUF(src_path)
    var out_packed = PackedGGUF(out_path)
    check(src_packed.integer("general.file_type") == 15, "packed: source file_type must read 15")
    check(out_packed.integer("general.file_type") == 7, "packed: emitted file_type must read 7")
    check(len(out_packed.tensors) == len(out_head.directory), "packed: tensor count differs")
    for entry in out_head.directory:
        var packed_entry = out_packed.tensors[entry.name]
        check(packed_entry.offset == out_head.data_offset + entry.relative_offset, "packed: offset mismatch for " + entry.name)
        check(packed_entry.byte_count == entry.byte_size, "packed: byte_count mismatch for " + entry.name)
        check(packed_entry.kind == Int(entry.tensor_type), "packed: kind mismatch for " + entry.name)
    print("PASS: PackedGGUF constructs in full on both files (601 tensors; offsets/kinds/byte counts agree)")
    print("SRC_LOAD_STATE:", load_state(src_path))
    print("OUT_LOAD_STATE:", load_state(out_path))
    # Bound probes: sampled rows of one tensor per source class.
    var src_seer = GGUFSeer(src_path)
    src_seer._open_and_map()
    src_seer._parse_header()
    var out_seer = GGUFSeer(out_path)
    out_seer._open_and_map()
    out_seer._parse_header()
    var probes = List[String]()
    probes.append(String("token_embd.weight"))
    probes.append(String("per_layer_token_embd.weight"))
    probes.append(String("blk.0.ffn_down.weight"))
    probes.append(String("blk.0.attn_q.weight"))
    probes.append(String("per_layer_model_proj.weight"))
    probes.append(String("blk.0.inp_gate.weight"))
    for probe in probes:
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
        var dim0 = Int(s_entry.dims[0])
        var count = 1
        for dim in s_entry.dims:
            count *= Int(dim)
        var rows = count // dim0
        var s_base = src_head.data_offset + s_entry.relative_offset
        var o_base = out_head.data_offset + o_entry.relative_offset
        var row_bytes = (dim0 // 32) * 34
        var worst = Float32(0.0)
        for sample in [0, rows // 2]:
            var values = _read_row_f32(src_seer, s_base, s_entry.copy(), sample)
            for block in range(dim0 // 32):
                var amax = Float32(0.0)
                for lane in range(32):
                    var v = abs_f32(values[block * 32 + lane])
                    if v > amax:
                        amax = v
                var d = amax / Float32(127.0)
                var block_off = o_base + sample * row_bytes + block * 34
                var d_bytes = List[UInt8]()
                d_bytes.append(UInt8(out_seer.mmap_ptr.unsafe_offset(block_off).unsafe_load()))
                d_bytes.append(UInt8(out_seer.mmap_ptr.unsafe_offset(block_off + 1).unsafe_load()))
                var d_bits = UInt16(d_bytes[0]) | (UInt16(d_bytes[1]) << 8)
                var d_hat = bitcast[DType.float16](d_bits).cast[f32]()
                var bound = d_hat / Float32(2.0) + Float32(127.0) * abs_f32(d_hat - d) + amax * Float32(0.0009765625) + d_hat * Float32(0.002) + Float32(0.0000001)
                for lane in range(32):
                    var q_byte = UInt8(out_seer.mmap_ptr.unsafe_offset(block_off + 2 + lane).unsafe_load())
                    var q = Int(q_byte) if q_byte < 128 else Int(q_byte) - 256
                    var dequant = Float32(q) * d_hat
                    var err = abs_f32(dequant - values[block * 32 + lane])
                    check(err <= bound, "bound violated for " + probe + " row " + String(sample) + " block " + String(block) + " lane " + String(lane))
                    if bound > Float32(0.0) and err / bound > worst:
                        worst = err / bound
        print("PASS: bound probe", probe, "(source", type_name(s_entry.tensor_type), ") rows 0 and", rows // 2, "inside the QC-2 bound, worst err/bound", worst)
    print("QC-3b gemma load proof: ALL PASS")
