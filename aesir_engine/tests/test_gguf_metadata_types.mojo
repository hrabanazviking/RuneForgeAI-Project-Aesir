"""Synthetic baseline for selected GGUF metadata value-type mismatches."""

from std.ffi import external_call
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver


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


def make_metadata_file(target_key: String, target_type: UInt32) raises -> String:
    var bytes = List[UInt8]()
    bytes.append(0x47)
    bytes.append(0x47)
    bytes.append(0x55)
    bytes.append(0x46)
    append_u32(bytes, 3)
    append_u64(bytes, 0)
    append_u64(bytes, 5)

    append_string(bytes, "general.architecture")
    append_u32(bytes, 8)
    append_string(bytes, "llama")

    append_string(bytes, target_key)
    append_u32(bytes, target_type)
    if target_type == 10:
        append_u64(bytes, 1)
    elif target_type == 8:
        append_string(bytes, "fixture")
    else:
        append_u32(bytes, 1)

    append_string(bytes, "tokenizer.ggml.tokens")
    append_u32(bytes, 9)
    append_u32(bytes, 8)
    append_u64(bytes, 3)
    append_string(bytes, "<unk>")
    append_string(bytes, "<s>")
    append_string(bytes, "</s>")

    append_string(bytes, "tokenizer.ggml.scores")
    append_u32(bytes, 9)
    append_u32(bytes, 6)
    append_u64(bytes, 3)
    for _ in range(3):
        append_u32(bytes, 0)

    append_string(bytes, "tokenizer.ggml.token_type")
    append_u32(bytes, 9)
    append_u32(bytes, 5)
    append_u64(bytes, 3)
    for _ in range(3):
        append_u32(bytes, 1)

    var template = List[Int8]()
    for byte in String("/tmp/aesir-gguf-type-XXXXXX").as_bytes():
        template.append(Int8(byte))
    template.append(0)
    var fd = external_call["mkstemp", Int32](template.unsafe_ptr())
    if fd < 0:
        raise Error("failed to create metadata type fixture")
    var offset = 0
    while offset < len(bytes):
        var wrote = external_call["write", Int](
            Int(fd), bytes.unsafe_ptr().unsafe_offset(offset), len(bytes) - offset
        )
        if wrote <= 0:
            _ = external_call["close", Int32](fd)
            raise Error("failed to write metadata type fixture")
        offset += wrote
    if external_call["close", Int32](fd) != 0:
        raise Error("failed to close metadata type fixture")
    return String(unsafe_from_utf8_ptr=template.unsafe_ptr())


def unlink_path(path: String):
    var bytes = List[Int8]()
    for byte in path.as_bytes():
        bytes.append(Int8(byte))
    bytes.append(0)
    _ = external_call["unlink", Int32](bytes.unsafe_ptr())


def probe_expected(
    target_key: String,
    target_type: UInt32,
    expected_error: String,
) raises:
    var path = make_metadata_file(target_key, target_type)
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var error_text = String("")
    try:
        seer.inspect_metadata(tokenizer)
    except error:
        error_text = String(error)
    unlink_path(path)
    if expected_error not in error_text:
        raise Error(
            "metadata mismatch diagnostic differs for " + target_key + ": " + error_text
        )
    if seer.state != 4 or seer.is_mapped:
        raise Error("metadata type rejection did not fail and clean the mapping")
    print("PASS: metadata type rejection and cleanup:", target_key)


def probe(target_key: String, target_type: UInt32) raises:
    probe_expected(
        target_key,
        target_type,
        "GGUF metadata key has unexpected value type: " + target_key,
    )


def test_gguf_metadata_type_rejection() raises:
    probe("llama.context_length", 10)
    probe("llama.embedding_length", 6)
    probe("llama.rope.freq_base", 4)
    probe("llama.attention.layer_norm_rms_epsilon", 4)
    probe("tokenizer.ggml.add_bos_token", 4)
    probe("tokenizer.ggml.add_space_prefix", 4)
    probe("general.alignment", 10)
    probe_expected("tokenizer.ggml.tokens", 4, "tokenizer.ggml.tokens is not an array")
    print("PASS: GGUF selected metadata type unit matrix")

def main() raises:
    test_gguf_metadata_type_rejection()
