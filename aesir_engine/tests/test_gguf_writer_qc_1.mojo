# tests/test_gguf_writer_qc_1.mojo
# QC-1 proof: the GGUF writer core (loader/gguf_writer.mojo) emits a
# spec-exact GGUF v3 byte stream that BOTH readers accept, and its
# metadata-copy path reproduces a real file's header/KV/directory
# exactly (stories260K.F16.gguf, pinned sha256
# 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0e, 601,248 B,
# 21 KV entries, 48 tensors, data_offset 14240 — measured by an
# independent Python parse before this test was written).
#
# Usage: test_gguf_writer_qc_1 <stories260K.F16.gguf>
#
# Synthetic model: F32 norm (32 elems, 128 B) + F16 matrix
# (64x4, 512 B) + Q8_0 matrix (64x8 = 512 elems = 16 hand-built
# 34-byte blocks, 544 B). Payload sizes are multiples of the
# 32-byte alignment, so offsets are 0 / 128 / 640 and the plan's
# size identity (file size == data_offset + payload sum) holds
# exactly. GGUFSeer "loads" a synthetic non-model file in the
# codebase's established baseline sense (Q8-1 / metadata-types
# pattern): every tensor maps, and the load then fails ONLY at
# required-tensor validation. PackedGGUF has no such validation
# and must construct in full.

from std.ffi import external_call
from std.memory import bitcast
from std.sys import argv

from core.mimir_well import MimirWell
from loader.gguf import GGUFSeer, GGUFState
from loader.gguf_writer import (
    GGUFKV,
    GGUFKVValue,
    GGUFModelDesc,
    GGUFWriterTensor,
    build_gguf_bytes,
    copy_gguf_model,
    gguf_kv_bool,
    gguf_kv_bool_array,
    gguf_kv_equal,
    gguf_kv_f32,
    gguf_kv_f32_array,
    gguf_kv_f64,
    gguf_kv_i16,
    gguf_kv_i32,
    gguf_kv_i32_array,
    gguf_kv_i64,
    gguf_kv_i8,
    gguf_kv_string,
    gguf_kv_string_array,
    gguf_kv_u16,
    gguf_kv_u32,
    gguf_kv_u32_array,
    gguf_kv_u64,
    gguf_kv_u8,
    read_gguf_header_copy,
    write_gguf_file,
)
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver


def append_u32_le(mut bytes: List[UInt8], value: UInt32):
    for shift in range(4):
        bytes.append(UInt8((value >> UInt32(shift * 8)) & 0xff))


def rd_u32(bytes: List[UInt8], offset: Int) -> UInt32:
    var value = UInt32(0)
    for i in range(4):
        value |= UInt32(bytes[offset + i]) << UInt32(i * 8)
    return value


def rd_u64(bytes: List[UInt8], offset: Int) -> UInt64:
    var value = UInt64(0)
    for i in range(8):
        value |= UInt64(bytes[offset + i]) << UInt64(i * 8)
    return value


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


def unlink_path(path: String):
    var bytes = List[Int8]()
    for byte in path.as_bytes():
        bytes.append(Int8(byte))
    bytes.append(0)
    _ = external_call["unlink", Int32](bytes.unsafe_ptr())


def check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def expect_build_error(desc: GGUFModelDesc, needle: String, label: String) raises:
    var error_text = String("")
    try:
        var bytes = build_gguf_bytes(desc)
        _ = bytes
    except error:
        error_text = String(error)
    if needle not in error_text:
        raise Error(label + ": expected refusal containing '" + needle + "', got: " + error_text)
    print("PASS: writer refusal —", label, "->", error_text)


def make_synthetic_desc() raises -> GGUFModelDesc:
    var desc = GGUFModelDesc()
    desc.add_kv(gguf_kv_string("general.architecture", "llama"))
    desc.add_kv(gguf_kv_string("general.name", "qc1-synthetic"))
    desc.add_kv(gguf_kv_u32("general.alignment", 32))
    desc.add_kv(gguf_kv_u32("general.file_type", 7))
    desc.add_kv(gguf_kv_u32("llama.context_length", 128))
    desc.add_kv(gguf_kv_u32("llama.embedding_length", 32))
    desc.add_kv(gguf_kv_u32("llama.block_count", 1))
    desc.add_kv(gguf_kv_u32("llama.feed_forward_length", 64))
    desc.add_kv(gguf_kv_u32("llama.attention.head_count", 4))
    desc.add_kv(gguf_kv_u32("llama.attention.head_count_kv", 4))
    desc.add_kv(gguf_kv_u32("llama.rope.dimension_count", 8))
    desc.add_kv(gguf_kv_f32("llama.rope.freq_base", Float32(10000.0)))
    desc.add_kv(gguf_kv_f32("llama.attention.layer_norm_rms_epsilon", Float32(0.00001)))
    desc.add_kv(gguf_kv_string("tokenizer.ggml.model", "llama"))
    var tokens = List[String]()
    tokens.append("<unk>")
    tokens.append("<s>")
    tokens.append("</s>")
    desc.add_kv(gguf_kv_string_array("tokenizer.ggml.tokens", tokens))
    var scores = List[Float32]()
    scores.append(Float32(0.0))
    scores.append(Float32(0.0))
    scores.append(Float32(0.0))
    desc.add_kv(gguf_kv_f32_array("tokenizer.ggml.scores", scores))
    var types = List[Int32]()
    types.append(Int32(1))
    types.append(Int32(1))
    types.append(Int32(1))
    desc.add_kv(gguf_kv_i32_array("tokenizer.ggml.token_type", types))
    desc.add_kv(gguf_kv_u32("tokenizer.ggml.unknown_token_id", 0))
    desc.add_kv(gguf_kv_u32("tokenizer.ggml.bos_token_id", 1))
    desc.add_kv(gguf_kv_u32("tokenizer.ggml.eos_token_id", 2))
    desc.add_kv(gguf_kv_bool("tokenizer.ggml.add_bos_token", True))
    # Every remaining scalar value type, under reader-neutral keys.
    desc.add_kv(gguf_kv_u8("extension.u8", 200))
    desc.add_kv(gguf_kv_i8("extension.i8", Int8(-5)))
    desc.add_kv(gguf_kv_u16("extension.u16", 60000))
    desc.add_kv(gguf_kv_i16("extension.i16", Int16(-3000)))
    desc.add_kv(gguf_kv_i32("extension.i32", Int32(-123456)))
    desc.add_kv(gguf_kv_u64("extension.u64", UInt64(12345678901234)))
    desc.add_kv(gguf_kv_i64("extension.i64", Int64(-9876543210)))
    desc.add_kv(gguf_kv_f64("extension.f64", Float64(2.5)))
    desc.add_kv(gguf_kv_bool("extension.bool", False))
    var f32s = List[Float32]()
    f32s.append(Float32(0.5))
    f32s.append(Float32(-1.25))
    desc.add_kv(gguf_kv_f32_array("extension.f32_array", f32s))
    var u32s = List[UInt32]()
    u32s.append(UInt32(3))
    u32s.append(UInt32(1))
    u32s.append(UInt32(4))
    desc.add_kv(gguf_kv_u32_array("extension.u32_array", u32s))
    var bools = List[Bool]()
    bools.append(True)
    bools.append(False)
    bools.append(True)
    desc.add_kv(gguf_kv_bool_array("extension.bool_array", bools))
    # Tensor 1: F32 norm, dims [32], 128 B. Values (i-16)*0.25 are
    # exact in f32 and f16, so the loader's F32->f16 pool copy can be
    # checked value-for-value below.
    var norm_payload = List[UInt8]()
    for i in range(32):
        append_u32_le(norm_payload, bitcast[DType.uint32](Float32(i - 16) * Float32(0.25)))
    var norm_dims = List[UInt64]()
    norm_dims.append(UInt64(32))
    desc.add_tensor(GGUFWriterTensor("norm.weight", norm_dims, UInt32(0), norm_payload))
    # Tensor 2: F16 matrix, dims [64, 4] GGML order, 512 B pattern.
    var matrix_payload = List[UInt8]()
    for i in range(512):
        matrix_payload.append(UInt8((i * 7 + 3) % 256))
    var matrix_dims = List[UInt64]()
    matrix_dims.append(UInt64(64))
    matrix_dims.append(UInt64(4))
    desc.add_tensor(GGUFWriterTensor("matrix.weight", matrix_dims, UInt32(1), matrix_payload))
    # Tensor 3: Q8_0 matrix, dims [64, 8] = 512 elems = 16 blocks,
    # hand-built per the reader's 34 B layout: f16 d @0, 32 x i8 @2.
    var quant_payload = List[UInt8]()
    for block in range(16):
        var d_bits = UInt16(0x3800) if block % 2 == 0 else UInt16(0x3400)
        quant_payload.append(UInt8(d_bits & 0xff))
        quant_payload.append(UInt8((d_bits >> 8) & 0xff))
        for lane in range(32):
            var q = lane - 16 + (block % 5) - 2
            quant_payload.append(UInt8(q & 0xFF))
    var quant_dims = List[UInt64]()
    quant_dims.append(UInt64(64))
    quant_dims.append(UInt64(8))
    desc.add_tensor(GGUFWriterTensor("quant.weight", quant_dims, UInt32(8), quant_payload))
    return desc^


def test_synthetic() raises:
    var desc = make_synthetic_desc()
    var path = String("/tmp/aesir-qc1-synthetic.gguf")
    var written = write_gguf_file(path, desc)
    var file_bytes = read_file_bytes(path)
    check(len(file_bytes) == written, "synthetic: readback length differs from written size")
    # Header bytes, read raw.
    check(rd_u32(file_bytes, 0) == UInt32(0x46554747), "synthetic: magic mismatch")
    check(rd_u32(file_bytes, 4) == UInt32(3), "synthetic: version must be 3")
    check(rd_u64(file_bytes, 8) == UInt64(3), "synthetic: tensor_count must be 3")
    check(rd_u64(file_bytes, 16) == UInt64(len(desc.kvs)), "synthetic: kv_count mismatch")
    # Metadata-copy parse must reproduce the inputs EXACTLY.
    var head = read_gguf_header_copy(path)
    check(head.version == UInt32(3), "synthetic: copy version mismatch")
    check(len(head.kvs) == len(desc.kvs), "synthetic: copy kv count mismatch")
    for i in range(len(desc.kvs)):
        check(gguf_kv_equal(head.kvs[i], desc.kvs[i]), "synthetic: copy kv mismatch at index " + String(i))
    check(len(head.directory) == 3, "synthetic: copy directory must hold 3 tensors")
    var expected_offsets = List[Int]()
    expected_offsets.append(0)
    expected_offsets.append(128)
    expected_offsets.append(640)
    var expected_sizes = List[Int]()
    expected_sizes.append(128)
    expected_sizes.append(512)
    expected_sizes.append(544)
    for i in range(3):
        ref entry = head.directory[i]
        ref tensor = desc.tensors[i]
        check(entry.name == tensor.name, "synthetic: directory name mismatch at " + String(i))
        check(entry.tensor_type == tensor.tensor_type, "synthetic: directory type mismatch at " + String(i))
        check(len(entry.dims) == len(tensor.dims), "synthetic: directory rank mismatch at " + String(i))
        for d in range(len(tensor.dims)):
            check(entry.dims[d] == tensor.dims[d], "synthetic: directory dim mismatch")
        check(entry.relative_offset == expected_offsets[i], "synthetic: offset mismatch at " + String(i))
        check(entry.relative_offset % 32 == 0, "synthetic: offset not 32-aligned at " + String(i))
        check(entry.byte_size == expected_sizes[i], "synthetic: byte size mismatch at " + String(i))
        # Payload bytes in the file are byte-identical to the inputs.
        for j in range(entry.byte_size):
            check(
                file_bytes[head.data_offset + entry.relative_offset + j] == tensor.payload[j],
                "synthetic: payload byte mismatch, tensor " + String(i) + " byte " + String(j),
            )
    check(head.data_offset % 32 == 0, "synthetic: data_offset not 32-aligned")
    check(
        len(file_bytes) == head.data_offset + 128 + 512 + 544,
        "synthetic: file size != data_offset + payload sum",
    )
    print("PASS: synthetic header/KV/directory exact, offsets 0/128/640 all 32-aligned, size == data_offset + 1184, payloads byte-identical")
    # GGUFSeer metadata path.
    var seer_meta = GGUFSeer(path)
    var tokenizer_meta = RuneWeaver()
    seer_meta.inspect_metadata(tokenizer_meta)
    check(seer_meta.state == GGUFState.HEADER_PARSED, "synthetic: inspect_metadata did not reach HEADER_PARSED")
    check(seer_meta.config.architecture == "llama", "synthetic: seer architecture mismatch")
    check(seer_meta.config.context_length == 128, "synthetic: seer context_length mismatch")
    check(seer_meta.config.embedding_length == 32, "synthetic: seer embedding_length mismatch")
    check(seer_meta.config.block_count == 1, "synthetic: seer block_count mismatch")
    check(seer_meta.config.rope_freq_base == Float32(10000.0), "synthetic: seer rope_freq_base mismatch")
    check(seer_meta.alignment == 32, "synthetic: seer alignment mismatch")
    check(tokenizer_meta.vocab_size == 3, "synthetic: tokenizer vocab size mismatch")
    print("PASS: GGUFSeer inspect_metadata parses the synthetic header/KV exactly")
    # GGUFSeer full path: all tensors map; failure ONLY at required-
    # tensor validation (the codebase's synthetic baseline pattern).
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(65536)
    var error_text = String("")
    try:
        seer.mmap_and_load(pool, tokenizer)
    except error:
        error_text = String(error)
    check("GGUF is missing required tensor:" in error_text, "synthetic: GGUFSeer load did not reach required-tensor validation: " + error_text)
    check(seer.data_offset == head.data_offset, "synthetic: seer data_offset != copy data_offset")
    for i in range(3):
        ref tensor = desc.tensors[i]
        check(tensor.name in seer.tensors, "synthetic: seer did not map " + tensor.name)
        check(seer.tensor_types[tensor.name] == tensor.tensor_type, "synthetic: seer type mismatch for " + tensor.name)
        check(
            seer.tensor_file_offsets[tensor.name] == head.data_offset + expected_offsets[i],
            "synthetic: seer file offset mismatch for " + tensor.name,
        )
    ref norm = seer.tensors["norm.weight"]
    check(norm.rows == 1 and norm.cols == 32, "synthetic: norm shape must map as 1x32")
    for i in range(32):
        check(
            norm.data.unsafe_load(i) == Float16(Float32(i - 16) * Float32(0.25)),
            "synthetic: norm F32->f16 pool value mismatch at " + String(i),
        )
    ref matrix = seer.tensors["matrix.weight"]
    check(matrix.rows == 4 and matrix.cols == 64, "synthetic: matrix shape must map as 4x64")
    ref quant = seer.tensors["quant.weight"]
    check(quant.rows == 8 and quant.cols == 64, "synthetic: quant shape must map as 8x64")
    print("PASS: GGUFSeer maps all 3 synthetic tensors at the written offsets/types/shapes (load stops only at required-tensor validation)")
    # PackedGGUF constructs in full.
    var packed = PackedGGUF(path)
    check(packed.data_offset == head.data_offset, "synthetic: packed data_offset mismatch")
    check(len(packed.tensors) == 3, "synthetic: packed tensor count mismatch")
    for i in range(3):
        ref tensor = desc.tensors[i]
        var entry = packed.tensors[tensor.name]
        check(entry.offset == head.data_offset + expected_offsets[i], "synthetic: packed offset mismatch for " + tensor.name)
        check(entry.kind == Int(tensor.tensor_type), "synthetic: packed kind mismatch for " + tensor.name)
        check(entry.byte_count == expected_sizes[i], "synthetic: packed byte_count mismatch for " + tensor.name)
    check(packed.text("general.architecture") == "llama", "synthetic: packed architecture mismatch")
    check(packed.integer("llama.context_length") == 128, "synthetic: packed context_length mismatch")
    check(packed.floating("llama.rope.freq_base") == Float32(10000.0), "synthetic: packed rope_freq_base mismatch")
    print("PASS: PackedGGUF loads the synthetic file in full (offsets/kinds/byte counts + typed KV reads)")
    unlink_path(path)


def _one_tensor_desc(payload_len: Int, dims: List[UInt64], tensor_type: UInt32) -> GGUFModelDesc:
    var desc = GGUFModelDesc()
    desc.add_kv(gguf_kv_string("general.architecture", "llama"))
    var payload = List[UInt8]()
    for _ in range(payload_len):
        payload.append(0)
    desc.add_tensor(GGUFWriterTensor("probe.weight", dims, tensor_type, payload))
    return desc^


def test_refusals() raises:
    var dup_kv = GGUFModelDesc()
    dup_kv.add_kv(gguf_kv_string("general.name", "a"))
    dup_kv.add_kv(gguf_kv_string("general.name", "b"))
    expect_build_error(dup_kv, "duplicate metadata key", "duplicate KV key")
    var dup_tensor = _one_tensor_desc(4, [UInt64(1)], UInt32(0))
    var extra_payload = List[UInt8]()
    for _ in range(4):
        extra_payload.append(0)
    dup_tensor.add_tensor(GGUFWriterTensor("probe.weight", [UInt64(1)], UInt32(0), extra_payload))
    expect_build_error(dup_tensor, "duplicate tensor name", "duplicate tensor name")
    var wrong_type = GGUFModelDesc()
    wrong_type.add_kv(gguf_kv_string("llama.context_length", "wide"))
    expect_build_error(wrong_type, "unexpected value type", "typed-key contract (context_length as string)")
    var wrong_tokens = GGUFModelDesc()
    var ids = List[UInt32]()
    ids.append(UInt32(1))
    wrong_tokens.add_kv(gguf_kv_u32_array("tokenizer.ggml.tokens", ids))
    expect_build_error(wrong_tokens, "array of strings", "tokenizer tokens must be a string array")
    expect_build_error(_one_tensor_desc(100, [UInt64(32)], UInt32(0)), "payload size mismatch", "payload length != reader-priced size")
    expect_build_error(_one_tensor_desc(102, [UInt64(48), UInt64(2)], UInt32(8)), "not block aligned", "Q8_0 dim0 not a multiple of 32")
    expect_build_error(_one_tensor_desc(64, [UInt64(2), UInt64(2), UInt64(2), UInt64(2)], UInt32(0)), "one to three dimensions", "rank-4 tensor")
    var align_desc = GGUFModelDesc()
    align_desc.add_kv(gguf_kv_u32("general.alignment", 64))
    expect_build_error(align_desc, "does not match the emission alignment", "general.alignment != emission alignment")
    expect_build_error(_one_tensor_desc(18, [UInt64(32)], UInt32(15)), "unsupported tensor type", "Q8_K (type 15) has no explicit reader price")
    var nested_raw = List[UInt8]()
    append_u32_le(nested_raw, 9)
    for _ in range(8):
        nested_raw.append(0)
    var nested = GGUFModelDesc()
    nested.add_kv(GGUFKV("extension.bad", GGUFKVValue(UInt32(9), nested_raw)))
    expect_build_error(nested, "array element type refused", "nested array (elem type 9)")
    print("PASS: all writer refusals fire before emission")


def find_kv(kvs: List[GGUFKV], key: String) raises -> GGUFKV:
    for kv in kvs:
        if kv.key == key:
            return kv.copy()
    raise Error("metadata key not found: " + key)


def test_real_file(stories_path: String) raises:
    var head = read_gguf_header_copy(stories_path)
    check(head.version == UInt32(3), "stories: copy version must be 3")
    check(len(head.kvs) == 21, "stories: copy must hold 21 KV entries, got " + String(len(head.kvs)))
    check(len(head.directory) == 48, "stories: copy must hold 48 tensors, got " + String(len(head.directory)))
    check(head.data_offset == 14240, "stories: copy data_offset must be 14240, got " + String(head.data_offset))
    check(head.alignment == 32, "stories: copy alignment must default to 32")
    # The loader's own parse of the same file must agree, field by field.
    var seer_meta = GGUFSeer(stories_path)
    var tokenizer_meta = RuneWeaver()
    seer_meta.inspect_metadata(tokenizer_meta)
    check(seer_meta.kv_count == len(head.kvs), "stories: seer kv_count != copy kv count")
    check(seer_meta.tensor_count == len(head.directory), "stories: seer tensor_count != copy directory size")
    check(seer_meta.alignment == head.alignment, "stories: seer alignment != copy alignment")
    check(find_kv(head.kvs, "general.architecture").value.as_string() == seer_meta.config.architecture, "stories: architecture copy != seer config")
    check(Int(find_kv(head.kvs, "llama.context_length").value.as_u32()) == seer_meta.config.context_length, "stories: context_length copy != seer config")
    check(Int(find_kv(head.kvs, "llama.embedding_length").value.as_u32()) == seer_meta.config.embedding_length, "stories: embedding_length copy != seer config")
    check(Int(find_kv(head.kvs, "llama.block_count").value.as_u32()) == seer_meta.config.block_count, "stories: block_count copy != seer config")
    check(Int(find_kv(head.kvs, "llama.attention.head_count").value.as_u32()) == seer_meta.config.head_count, "stories: head_count copy != seer config")
    # stories260K carries no llama.rope.freq_base key (independent
    # Python census of the file, QC-1): the reader defaults it to
    # 10000.0, and the copy must faithfully show the key ABSENT.
    var has_rope_key = False
    for kv in head.kvs:
        if kv.key == "llama.rope.freq_base":
            has_rope_key = True
    check(not has_rope_key, "stories: copy must show llama.rope.freq_base absent")
    check(seer_meta.config.rope_freq_base == Float32(10000.0), "stories: seer rope_freq_base must be the 10000.0 default")
    check(find_kv(head.kvs, "llama.attention.layer_norm_rms_epsilon").value.as_f32() == seer_meta.config.rms_epsilon, "stories: rms_epsilon copy != seer config")
    print("PASS: stories260K header copy == GGUFSeer parse (21 KV, 48 tensors, data_offset 14240, typed values == config)")
    # Full loader parse per tensor: types, absolute offsets, shapes.
    var seer = GGUFSeer(stories_path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(1 << 20)
    seer.mmap_and_load(pool, tokenizer)
    check(seer.is_loaded and seer.state == GGUFState.VALIDATED, "stories: source file must reach VALIDATED")
    check(seer.data_offset == head.data_offset, "stories: seer data_offset != copy data_offset")
    for entry in head.directory:
        check(entry.name in seer.tensors, "stories: seer did not map " + entry.name)
        check(seer.tensor_types[entry.name] == entry.tensor_type, "stories: seer type mismatch for " + entry.name)
        check(seer.tensor_file_offsets[entry.name] == head.data_offset + entry.relative_offset, "stories: seer offset mismatch for " + entry.name)
        var expected_cols = Int(entry.dims[0])
        var expected_rows = Int(entry.dims[1]) if len(entry.dims) == 2 else 1
        ref tensor = seer.tensors[entry.name]
        check(tensor.cols == expected_cols and tensor.rows == expected_rows, "stories: seer shape mismatch for " + entry.name)
    print("PASS: stories260K directory == GGUFSeer full-load parse for all 48 tensors (type/offset/shape)")
    var packed = PackedGGUF(stories_path)
    check(packed.data_offset == head.data_offset, "stories: packed data_offset != copy data_offset")
    check(len(packed.tensors) == 48, "stories: packed must hold 48 tensors")
    for entry in head.directory:
        var packed_entry = packed.tensors[entry.name]
        check(packed_entry.offset == head.data_offset + entry.relative_offset, "stories: packed offset mismatch for " + entry.name)
        check(packed_entry.byte_count == entry.byte_size, "stories: packed byte_count mismatch for " + entry.name)
        check(packed_entry.kind == Int(entry.tensor_type), "stories: packed kind mismatch for " + entry.name)
    print("PASS: stories260K directory == PackedGGUF parse for all 48 tensors (offset/byte_count/kind)")
    # Re-emit the copied model through the writer: the result must be
    # byte-identical to the source (raw KV preservation, minimal
    # aligned offsets, zero gaps — all verified of the source by an
    # independent Python parse before this test was written).
    var desc = copy_gguf_model(stories_path)
    var out_path = String("/tmp/aesir-qc1-stories-copy.gguf")
    var size = write_gguf_file(out_path, desc)
    check(size == 601248, "stories: re-emitted size must be 601248, got " + String(size))
    var source_bytes = read_file_bytes(stories_path)
    var copy_bytes = read_file_bytes(out_path)
    check(len(source_bytes) == len(copy_bytes), "stories: re-emitted length differs")
    var mismatches = 0
    var first_mismatch = -1
    for i in range(len(source_bytes)):
        if source_bytes[i] != copy_bytes[i]:
            mismatches += 1
            if first_mismatch < 0:
                first_mismatch = i
    check(mismatches == 0, "stories: re-emitted file differs in " + String(mismatches) + " bytes, first at " + String(first_mismatch))
    print("PASS: stories260K metadata+payload copy re-emits a BYTE-IDENTICAL file (601248 bytes, 0 mismatches)")
    var head2 = read_gguf_header_copy(out_path)
    check(len(head2.kvs) == len(head.kvs), "stories: re-emitted kv count differs")
    for i in range(len(head.kvs)):
        check(gguf_kv_equal(head2.kvs[i], head.kvs[i]), "stories: re-emitted kv mismatch at index " + String(i))
    check(head2.data_offset == head.data_offset, "stories: re-emitted data_offset differs")
    for i in range(len(head.directory)):
        check(head2.directory[i].name == head.directory[i].name, "stories: re-emitted tensor name differs at " + String(i))
        check(head2.directory[i].relative_offset == head.directory[i].relative_offset, "stories: re-emitted tensor offset differs at " + String(i))
        check(head2.directory[i].tensor_type == head.directory[i].tensor_type, "stories: re-emitted tensor type differs at " + String(i))
    var seer_copy = GGUFSeer(out_path)
    var tokenizer_copy = RuneWeaver()
    var pool_copy = MimirWell(1 << 20)
    seer_copy.mmap_and_load(pool_copy, tokenizer_copy)
    check(seer_copy.is_loaded and seer_copy.state == GGUFState.VALIDATED, "stories: re-emitted file must reach VALIDATED")
    print("PASS: re-emitted stories260K parses identically and reaches GGUFSeer VALIDATED")
    unlink_path(out_path)


def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: test_gguf_writer_qc_1 <stories260K.F16.gguf>")
    test_synthetic()
    test_refusals()
    test_real_file(arguments[1])
    print("QC-1 GGUF writer proof: ALL PASS")
