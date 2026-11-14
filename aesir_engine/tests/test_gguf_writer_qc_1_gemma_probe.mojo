# tests/test_gguf_writer_qc_1_gemma_probe.mojo
# QC-1 bonus probe (QC-0 U-QC4 parse half): the writer's metadata-
# copy path parses the REAL gemma-4-E2B Q4_K_M file (3,106,738,272 B,
# 56 KV, 601 tensors, data_offset 15819776 — measured by an
# independent Python header parse) WITHOUT materializing tensors,
# and its raw capture of gemma4's per-layer ARRAY keys
# (feed_forward_length = array of i32 x35, sliding_window_pattern =
# array of bool x35) agrees exactly with both readers' own parses.
# No re-emission here: payloads of a 3.1 GB file are QC-3b's road;
# this probe proves the header/KV/directory half on the array-heavy
# real file, complementing stories260K's full byte-identical copy.
#
# Usage: test_gguf_writer_qc_1_gemma_probe <gemma-4-E2B-it-Q4_K_M.gguf>

from std.sys import argv

from loader.gguf import GGUFSeer
from loader.gguf_writer import GGUFKV, read_gguf_header_copy
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver


def check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def find_kv(kvs: List[GGUFKV], key: String) raises -> GGUFKV:
    for kv in kvs:
        if kv.key == key:
            return kv.copy()
    raise Error("metadata key not found: " + key)


def raw_i32_array(kv: GGUFKV) raises -> List[Int]:
    var header = kv.value.array_header()
    check(header[0] == 5, "expected an i32 array for " + kv.key)
    var values = List[Int]()
    var raw = kv.value.raw.copy()
    for i in range(header[1]):
        var bits = UInt32(0)
        for b in range(4):
            bits |= UInt32(raw[12 + i * 4 + b]) << UInt32(b * 8)
        values.append(Int(Int32(bits)))
    return values^


def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: test_gguf_writer_qc_1_gemma_probe <gemma-4-E2B-it-Q4_K_M.gguf>")
    var path = arguments[1]
    var head = read_gguf_header_copy(path)
    check(head.version == UInt32(3), "gemma: copy version must be 3")
    check(len(head.kvs) == 56, "gemma: copy must hold 56 KV entries, got " + String(len(head.kvs)))
    check(len(head.directory) == 601, "gemma: copy must hold 601 tensors, got " + String(len(head.directory)))
    check(head.data_offset == 15819776, "gemma: copy data_offset must be 15819776, got " + String(head.data_offset))
    var ffn = find_kv(head.kvs, "gemma4.feed_forward_length")
    var ffn_header = ffn.value.array_header()
    check(ffn.value.value_type == UInt32(9) and ffn_header[0] == 5 and ffn_header[1] == 35, "gemma: feed_forward_length must be an i32 array of 35")
    var pattern = find_kv(head.kvs, "gemma4.attention.sliding_window_pattern")
    var pattern_header = pattern.value.array_header()
    check(pattern.value.value_type == UInt32(9) and pattern_header[0] == 7 and pattern_header[1] == 35, "gemma: sliding_window_pattern must be a bool array of 35")
    var ffn_values = raw_i32_array(ffn)
    var ffn_max = 0
    for value in ffn_values:
        if value > ffn_max:
            ffn_max = value
    # GGUFSeer's own metadata parse must agree.
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    seer.inspect_metadata(tokenizer)
    check(seer.kv_count == 56 and seer.tensor_count == 601, "gemma: seer counts != copy counts")
    check(seer.alignment == head.alignment, "gemma: seer alignment != copy alignment")
    check(seer.config.feed_forward_length == ffn_max, "gemma: seer feed_forward_length (array max) != copy array max")
    check(seer.config.sliding_window_pattern_count == 35, "gemma: seer sliding_window_pattern_count != 35")
    check(tokenizer.vocab_size == 262144, "gemma: seer vocab size != 262144")
    print("PASS: gemma E2B header copy == GGUFSeer metadata parse (56 KV, 601 tensors, ffn array max", ffn_max, ")")
    # PackedGGUF must agree on the directory and the array values.
    var packed = PackedGGUF(path)
    check(packed.data_offset == head.data_offset, "gemma: packed data_offset != copy data_offset")
    check(len(packed.tensors) == 601, "gemma: packed must hold 601 tensors")
    for entry in head.directory:
        check(entry.relative_offset % head.alignment == 0, "gemma: unaligned offset for " + entry.name)
        var packed_entry = packed.tensors[entry.name]
        check(packed_entry.offset == head.data_offset + entry.relative_offset, "gemma: packed offset mismatch for " + entry.name)
        check(packed_entry.byte_count == entry.byte_size, "gemma: packed byte_count mismatch for " + entry.name)
        check(packed_entry.kind == Int(entry.tensor_type), "gemma: packed kind mismatch for " + entry.name)
    var packed_ffn = packed.integer_array("gemma4.feed_forward_length", 35)
    check(len(packed_ffn) == len(ffn_values), "gemma: packed ffn array length mismatch")
    for i in range(len(ffn_values)):
        check(packed_ffn[i] == ffn_values[i], "gemma: ffn array value mismatch at layer " + String(i))
    print("PASS: gemma E2B directory == PackedGGUF for all 601 tensors; feed_forward_length array identical element-for-element")
    print("QC-1 gemma header-copy probe: ALL PASS")
