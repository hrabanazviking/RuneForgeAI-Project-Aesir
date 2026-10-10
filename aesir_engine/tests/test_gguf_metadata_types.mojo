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
    if target_type == 4:
        append_u32(bytes, 1)
    elif target_type == 10:
        append_u64(bytes, 1)
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


def probe(target_key: String, target_type: UInt32) raises:
    var path = make_metadata_file(target_key, target_type)
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var error_text = String("")
    try:
        seer.inspect_metadata(tokenizer)
    except error:
        error_text = String(error)
    unlink_path(path)
    if len(error_text.as_bytes()) != 0:
        raise Error(
            "mismatched metadata type did not retain skip behavior for "
            + target_key + ": " + error_text
        )
    if not seer.is_mapped:
        raise Error("metadata inspection unexpectedly failed/cleaned mapping")
    if target_key == "llama.context_length" and seer.config.context_length != 0:
        raise Error("mismatched context length modified the default configuration")
    if target_key == "llama.rope.freq_base" and seer.config.rope_freq_base != 10000.0:
        raise Error("mismatched RoPE frequency modified the default configuration")
    if target_key == "tokenizer.ggml.add_bos_token" and not tokenizer.add_bos_token:
        raise Error("mismatched tokenizer bool changed the default flag")
    if target_key == "general.alignment" and seer.alignment != 32:
        raise Error("mismatched alignment changed the default alignment")
    print("OBSERVED mismatch skipped with unchanged default:", target_key)


def test_gguf_metadata_type_baseline() raises:
    probe("llama.context_length", 10)
    probe("llama.rope.freq_base", 4)
    probe("tokenizer.ggml.add_bos_token", 4)
    probe("general.alignment", 10)
    print("PASS: GGUF metadata mismatch baseline trajectories captured")

def main() raises:
    test_gguf_metadata_type_baseline()
