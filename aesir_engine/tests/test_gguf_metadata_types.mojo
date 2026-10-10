"""Synthetic baseline for selected GGUF metadata value-type mismatches."""

from std.ffi import external_call
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.mimir_well import MimirWell


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


def make_metadata_file(
    target_key: String,
    target_type: UInt32,
    tensor_rank: UInt32 = 0,
    tensor_dim: UInt64 = 1,
    tensor_offset: UInt64 = 0,
    tensor_type: UInt32 = 1,
) raises -> String:
    var bytes = List[UInt8]()
    bytes.append(0x47)
    bytes.append(0x47)
    bytes.append(0x55)
    bytes.append(0x46)
    append_u32(bytes, 3)
    if tensor_rank == 0:
        append_u64(bytes, 0)
    else:
        append_u64(bytes, 1)
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

    if tensor_rank > 0:
        append_string(bytes, "fixture.weight")
        append_u32(bytes, tensor_rank)
        for _ in range(Int(tensor_rank)):
            append_u64(bytes, tensor_dim)
        append_u32(bytes, tensor_type)
        append_u64(bytes, tensor_offset)
        while len(bytes) % 32 != 0:
            bytes.append(0)
        if tensor_type == 0:
            append_u32(bytes, 1065353216)
        else:
            bytes.append(0)
            bytes.append(0)

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
    probe_expected("tokenizer.ggml.tokens", 9, "tokenizer.ggml.tokens must be a string array")
    probe_expected("extension.unknown_key", 13, "invalid metadata value type")
    print("PASS: GGUF selected metadata type unit matrix")

def test_gguf_metadata_type_integration() raises:
    var path = make_metadata_file("llama.context_length", 10)
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(128)
    var initial_offset = pool.offset
    var error_text = String("")
    try:
        seer.mmap_and_load(pool, tokenizer)
    except error:
        error_text = String(error)
    unlink_path(path)
    if "GGUF metadata key has unexpected value type: llama.context_length" not in error_text:
        raise Error("full GGUF load did not preserve metadata type diagnostic")
    if seer.state != 4 or seer.is_mapped or seer.is_loaded:
        raise Error("full GGUF load did not clean rejected metadata mapping/state")
    if pool.offset != initial_offset:
        raise Error("metadata type rejection mutated tensor allocation pool")
    print("PASS: metadata type rejection integrates with full load before allocation")


def test_gguf_tensor_directory_baseline() raises:
    var path = make_metadata_file("extension.label", 8, 1)
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(128)
    var error_text = String("")
    try:
        seer.mmap_and_load(pool, tokenizer)
    except error:
        error_text = String(error)
    unlink_path(path)
    if "GGUF is missing required tensor:" not in error_text:
        raise Error("valid directory baseline did not reach required-tensor validation")
    if "fixture.weight" not in seer.tensors:
        raise Error("valid F16 directory entry did not map before later model rejection")
    if seer.tensors["fixture.weight"].rows != 1 or seer.tensors["fixture.weight"].cols != 1:
        raise Error("valid rank-one directory shape did not map as 1x1")
    if seer.state != 4 or seer.is_mapped:
        raise Error("incomplete model baseline did not clean mapping after later rejection")
    print("PASS: valid rank-one F16 tensor maps before missing-model-tensor rejection")


def tensor_directory_probe(rank: UInt32, dimension: UInt64, expected_error: String) raises:
    var path = make_metadata_file("extension.label", 8, rank, dimension)
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(128)
    var error_text = String("")
    try:
        seer.mmap_and_load(pool, tokenizer)
    except error:
        error_text = String(error)
    unlink_path(path)
    if expected_error not in error_text:
        raise Error("tensor directory admission differs for rank " + String(rank) + ": " + error_text)
    if (rank == 1 or rank == 2) and dimension > 0:
        if "fixture.weight" not in seer.tensors:
            raise Error("accepted rank did not map before later required-tensor failure: " + error_text)
    elif "fixture.weight" in seer.tensors:
        raise Error("rejected tensor directory entry mutated tensor map")
    if seer.state != 4 or seer.is_mapped:
        raise Error("tensor directory admission did not close failed mapping")


def test_gguf_tensor_directory_interface() raises:
    tensor_directory_probe(1, 1, "GGUF is missing required tensor:")
    tensor_directory_probe(2, 1, "GGUF is missing required tensor:")
    tensor_directory_probe(3, 1, "one or two dimensions")
    tensor_directory_probe(1, 0, "non-positive dimension")
    print("PASS: GGUF tensor rank and positive dimension interface matrix")


def tensor_arithmetic_probe(
    rank: UInt32,
    dimension: UInt64,
    tensor_offset: UInt64,
    expected_error: String,
) raises:
    var path = make_metadata_file("extension.label", 8, rank, dimension, tensor_offset)
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(128)
    var error_text = String("")
    try:
        seer.mmap_and_load(pool, tokenizer)
    except error:
        error_text = String(error)
    unlink_path(path)
    if expected_error not in error_text:
        raise Error("tensor arithmetic diagnostic differs: " + error_text)
    if "fixture.weight" in seer.tensors:
        raise Error("rejected tensor arithmetic mutated tensor map")
    if seer.state != 4 or seer.is_mapped or seer.is_loaded:
        raise Error("tensor arithmetic rejection did not clean loader state")


def test_gguf_tensor_directory_adversarial() raises:
    tensor_arithmetic_probe(1, UInt64(18446744073709551615), 0, "dimension exceeds host index")
    tensor_arithmetic_probe(2, UInt64(3037000500), 0, "element count overflows host index")
    tensor_arithmetic_probe(1, UInt64(4611686018427387904), 0, "byte size overflows host index")
    tensor_arithmetic_probe(1, 1, UInt64(9223372036854775776), "absolute offset overflows host index")
    print("PASS: GGUF tensor directory arithmetic hostile boundaries")


def test_gguf_tensor_directory_integration() raises:
    var path = make_metadata_file("extension.label", 8, 1, 1, 0, 0)
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(128)
    var initial_offset = pool.offset
    var error_text = String("")
    try:
        seer.mmap_and_load(pool, tokenizer)
    except error:
        error_text = String(error)
    unlink_path(path)
    if "GGUF is missing required tensor:" not in error_text:
        raise Error("F32 tensor integration did not reach required tensor validation")
    if "fixture.weight" not in seer.tensors or seer.tensor_types["fixture.weight"] != 0:
        raise Error("F32 tensor did not map as the expected synthetic fixture")
    if pool.offset != initial_offset + 1:
        raise Error("F32 normalization conversion did not allocate exactly one element")
    if seer.state != 4 or seer.is_mapped:
        raise Error("F32 integration fixture did not clean mapped state")
    print("PASS: F32 directory entry converts into one MimirWell element")


def main() raises:
    test_gguf_metadata_type_rejection()
    test_gguf_metadata_type_integration()
    test_gguf_tensor_directory_baseline()
    test_gguf_tensor_directory_interface()
    test_gguf_tensor_directory_adversarial()
    test_gguf_tensor_directory_integration()
