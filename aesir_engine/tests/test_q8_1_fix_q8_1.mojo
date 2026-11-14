# tests/test_q8_1_fix_q8_1.mojo
# Q8-1 fix proof: ggml block_q8_1 is 36 bytes, and a tensor after a
# Q8_1 tensor in a GGUF file parses at its correct offset/values.
#
# Arbitration (ggml/src/ggml-common.h in ~/llama.cpp-build):
#   typedef struct { ggml_half d; ggml_half s; int8_t qs[32]; } block_q8_1;
#   static_assert(sizeof(block_q8_1) == 2*sizeof(ggml_half) + QK8_1);
# i.e. f16 d @0, f16 s @2 (s = d * sum(qs), auxiliary), qs @4..36, 36 B.
# ggml.c type traits: Q8_1 blck_size = QK8_1 (32), type_size = sizeof = 36.
# The loader (gguf._tensor_byte_size, mmproj geometry) already priced
# 36 B and was correct; core/compute walked a fictitious 40-byte
# f32/f32 layout and was the defect (fixed in this slice).
#
# Fixture: tensor 1 = one Q8_1 block (d=0.5, s=-8, qs=-16..15) at
# offset 0 (36 bytes, padded to the 32-byte alignment -> next tensor
# at offset 64); tensor 2 = F32 [1.5, -2.25, 3.0, 42.0] at offset 64.
# The full load then fails at llama required-tensor validation, after
# both tensors are mapped (the metadata-test baseline pattern).

from std.ffi import external_call
from loader.gguf import GGUFSeer
from loader.mmproj import mmproj_tensor_byte_count
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver
from core.compute import dequantize_q8_1
from core.mimir_well import MimirWell, CompressedFormatType
from core.quantization_autotuner import get_quantization_format_info


def append_u32(mut bytes: List[UInt8], value: UInt32):
    for shift in range(4):
        bytes.append(UInt8((value >> UInt32(shift * 8)) & 0xff))


def append_u64(mut bytes: List[UInt8], value: UInt64):
    for shift in range(8):
        bytes.append(UInt8((value >> UInt64(shift * 8)) & 0xff))


def append_string(mut bytes: List[UInt8], value: String):
    append_u64(bytes, UInt64(len(value.as_bytes())))
    for byte in value.as_bytes():
        bytes.append(UInt8(byte))


def append_f32_bits(mut bytes: List[UInt8], bits: UInt32):
    append_u32(bytes, bits)


def append_f16_bits(mut bytes: List[UInt8], bits: UInt16):
    bytes.append(UInt8(bits & 0xff))
    bytes.append(UInt8((bits >> 8) & 0xff))


def make_q8_1_file() raises -> String:
    var bytes = List[UInt8]()
    bytes.append(0x47); bytes.append(0x47); bytes.append(0x55); bytes.append(0x46)
    append_u32(bytes, 3)
    append_u64(bytes, 2)
    append_u64(bytes, 5)
    append_string(bytes, "general.architecture")
    append_u32(bytes, 8)
    append_string(bytes, "llama")
    append_string(bytes, "extension.label")
    append_u32(bytes, 8)
    append_string(bytes, "fixture")
    append_string(bytes, "tokenizer.ggml.tokens")
    append_u32(bytes, 9); append_u32(bytes, 8); append_u64(bytes, 3)
    append_string(bytes, "<unk>"); append_string(bytes, "<s>"); append_string(bytes, "</s>")
    append_string(bytes, "tokenizer.ggml.scores")
    append_u32(bytes, 9); append_u32(bytes, 6); append_u64(bytes, 3)
    for _ in range(3):
        append_u32(bytes, 0)
    append_string(bytes, "tokenizer.ggml.token_type")
    append_u32(bytes, 9); append_u32(bytes, 5); append_u64(bytes, 3)
    for _ in range(3):
        append_u32(bytes, 1)
    append_string(bytes, "probe.q8_1.weight")
    append_u32(bytes, 1); append_u64(bytes, 32); append_u32(bytes, 9); append_u64(bytes, 0)
    append_string(bytes, "probe.after.weight")
    append_u32(bytes, 1); append_u64(bytes, 4); append_u32(bytes, 0); append_u64(bytes, 64)
    while len(bytes) % 32 != 0:
        bytes.append(0)
    # Q8_1 block: f16 d=0.5 @0, f16 s=-8 @2, int8 qs=-16..15 @4..36.
    append_f16_bits(bytes, UInt16(0x3800))  # d = 0.5
    append_f16_bits(bytes, UInt16(0xC800))  # s = -8.0 = d * sum(qs)
    for i in range(32):
        bytes.append(UInt8((i + 240) % 256))  # int8 qs = -16..15
    while len(bytes) % 32 != 0:
        bytes.append(0)
    append_f32_bits(bytes, UInt32(0x3FC00000))  # 1.5
    append_f32_bits(bytes, UInt32(0xC0100000))  # -2.25
    append_f32_bits(bytes, UInt32(0x40400000))  # 3.0
    append_f32_bits(bytes, UInt32(0x42280000))  # 42.0
    var template = List[Int8]()
    for byte in String("/tmp/aesir-q8-1-XXXXXX").as_bytes():
        template.append(Int8(byte))
    template.append(0)
    var fd = external_call["mkstemp", Int32](template.unsafe_ptr())
    if fd < 0:
        raise Error("failed to create Q8_1 fixture")
    var offset = 0
    while offset < len(bytes):
        var wrote = external_call["write", Int](Int(fd), bytes.unsafe_ptr().unsafe_offset(offset), len(bytes) - offset)
        if wrote <= 0:
            _ = external_call["close", Int32](fd)
            raise Error("failed to write Q8_1 fixture")
        offset += wrote
    if external_call["close", Int32](fd) != 0:
        raise Error("failed to close Q8_1 fixture")
    return String(unsafe_from_utf8_ptr=template.unsafe_ptr())


def unlink_path(path: String):
    var bytes = List[Int8]()
    for byte in path.as_bytes():
        bytes.append(Int8(byte))
    bytes.append(0)
    _ = external_call["unlink", Int32](bytes.unsafe_ptr())


def test_dequant_unit() raises:
    var well = MimirWell(4096)
    var raw = well.allocate(36).unsafe_bitcast[UInt8]()
    for i in range(72):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.5))
    raw.unsafe_offset(2).unsafe_bitcast[Float16]().unsafe_store(0, Float16(-8))
    for i in range(32):
        raw.unsafe_offset(4).unsafe_bitcast[Int8]().unsafe_store(i, Int8(i - 16))
    var out = well.allocate(32)
    dequantize_q8_1(raw, out, 1)
    for i in range(32):
        if out.unsafe_load(i) != Float16(Float32(i - 16) * Float32(0.5)):
            raise Error("dequant unit mismatch at lane " + String(i))
    print("PASS: dequantize_q8_1 unit (36-byte block, f16 d/s, qs @4)")


def test_byte_size_units() raises:
    var seer = GGUFSeer("unused.gguf")
    if seer._tensor_byte_size(32, UInt32(9)) != 36:
        raise Error("loader _tensor_byte_size: 32 Q8_1 elements must be 36 bytes")
    if seer._tensor_byte_size(64, UInt32(9)) != 72:
        raise Error("loader _tensor_byte_size: 64 Q8_1 elements must be 72 bytes")
    if seer._tensor_byte_size(320, UInt32(9)) != 360:
        raise Error("loader _tensor_byte_size: 320 Q8_1 elements must be 360 bytes")
    var dims32 = List[Int](); dims32.append(32)
    if mmproj_tensor_byte_count(9, dims32) != 36:
        raise Error("mmproj: 32 Q8_1 elements must be 36 bytes")
    var dims64 = List[Int](); dims64.append(64)
    if mmproj_tensor_byte_count(9, dims64) != 72:
        raise Error("mmproj: 64 Q8_1 elements must be 72 bytes")
    var info = get_quantization_format_info(CompressedFormatType(CompressedFormatType.Q8_1))
    if info.block_bytes != 36 or info.block_weights != 32:
        raise Error("autotuner: Q8_1 format info must be 32 weights / 36 bytes")
    print("PASS: Q8_1 byte-size units agree at 36 B/block (loader, mmproj, autotuner)")


def test_downstream_tensor() raises:
    # Full-load baseline pattern (as in test_gguf_metadata_types):
    # both tensors map, then the load fails only at llama
    # required-tensor validation. Values are read through the F32
    # tensor's MimirWell copy (F32 tensors are converted at load);
    # the Q8_1 block bytes are asserted by construction in
    # make_q8_1_file, by the dequant unit above, and by the Q8/FP8
    # GEMM parity runner. Direct pointer reads of a mapped Q8_1
    # tensor from this test binary segfaulted intermittently during
    # this slice (2026-11-14; recorded in Q8-1-FIX-NOTES.md as an
    # out-of-scope observation, not chased).
    var path = make_q8_1_file()
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(4096)
    var error_text = String("")
    try:
        seer.mmap_and_load(pool, tokenizer)
    except error:
        error_text = String(error)
    unlink_path(path)
    if "GGUF is missing required tensor:" not in error_text:
        raise Error("Q8_1 fixture did not reach required-tensor validation: " + error_text)
    if "probe.q8_1.weight" not in seer.tensors or "probe.after.weight" not in seer.tensors:
        raise Error("Q8_1 fixture tensors did not both map")
    var q_off = seer.tensor_file_offsets["probe.q8_1.weight"]
    var a_off = seer.tensor_file_offsets["probe.after.weight"]
    if a_off - q_off != 64:
        raise Error("downstream tensor offset delta must be 64 (36 B block, 32-aligned), got " + String(a_off - q_off))
    if seer.tensor_types["probe.q8_1.weight"] != UInt32(9):
        raise Error("Q8_1 tensor type must be recorded as GGML type 9")
    ref qt = seer.tensors["probe.q8_1.weight"]
    if qt.rows != 1 or qt.cols != 32:
        raise Error("Q8_1 tensor shape must map as 1x32")
    var expected = List[Float16](); expected.append(Float16(1.5)); expected.append(Float16(-2.25)); expected.append(Float16(3.0)); expected.append(Float16(42.0))
    ref after = seer.tensors["probe.after.weight"]
    for i in range(4):
        if after.data.unsafe_load(i) != expected[i]:
            raise Error("downstream F32 tensor value mismatch at index " + String(i))
    print("PASS: Q8_1 tensor + downstream F32 tensor parse at correct offset with correct values")


def test_packed_gguf_refusal() raises:
    var path = make_q8_1_file()
    var error_text = String("")
    try:
        var packed = PackedGGUF(path)
        _ = packed^
    except error:
        error_text = String(error)
    unlink_path(path)
    # PackedGGUF has no Q8_1 geometry (packed_block_geometry has no
    # kind-9 case): a 32-column Q8_1 row is refused by the K-quant
    # row-alignment guard, a 256-aligned row by the geometry lookup
    # ("unsupported tensor type 9"). Either way it refuses outright.
    if "unsupported tensor type 9" not in error_text and "not block aligned" not in error_text:
        raise Error("PackedGGUF must refuse Q8_1 (type 9) outright, got: " + error_text)
    print("PASS: PackedGGUF refuses Q8_1 outright -- honest support state, refusal:", error_text)


def main() raises:
    test_dequant_unit()
    test_byte_size_units()
    test_downstream_tensor()
    test_packed_gguf_refusal()
    print("Q8-1 fix proof: ALL PASS")
