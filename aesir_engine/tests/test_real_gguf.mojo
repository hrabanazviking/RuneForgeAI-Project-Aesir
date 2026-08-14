# tests/test_real_gguf.mojo
# Opt-in integration proving for a dynamically supplied real GGUF path.

from std.sys import argv

from core.mimir_well import DeviceTopology, KVCache, MimirWell, f16
from loader.gguf import GGMLType, GGUFSeer
from loader.tokenizer import RuneWeaver
from core.inference import TransformerBlock, forward_pass


def validate_reference_model(seer: GGUFSeer, tokenizer: RuneWeaver) raises:
    if not seer.is_loaded:
        raise Error("real GGUF loader did not reach validated state")
    if seer.version != 3 or seer.tensor_count != 48 or seer.kv_count != 21:
        raise Error("real GGUF header counts do not match the pinned fixture")
    if seer.config.architecture != "llama":
        raise Error("real GGUF architecture mismatch")
    if seer.config.context_length != 128:
        raise Error("real GGUF context length mismatch")
    if seer.config.embedding_length != 64:
        raise Error("real GGUF embedding length mismatch")
    if seer.config.feed_forward_length != 172:
        raise Error("real GGUF feed-forward length mismatch")
    if seer.config.block_count != 5:
        raise Error("real GGUF block count mismatch")
    if seer.config.head_count != 8 or seer.config.head_count_kv != 4:
        raise Error("real GGUF grouped-query head counts mismatch")
    if tokenizer.vocab_size != 512:
        raise Error("real GGUF vocabulary size mismatch")
    if seer.tensor_types.get("token_embd.weight", UInt32(99)) != GGMLType.F16:
        raise Error("embedding tensor is not mapped as F16")
    if seer.tensor_types.get("output_norm.weight", UInt32(99)) != GGMLType.F32:
        raise Error("output normalization tensor is not recognized as F32")


def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: mojo run tests/test_real_gguf.mojo <model.gguf>")

    var pool = MimirWell(2 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(arguments[1])
    seer.mmap_and_load(pool, tokenizer)
    validate_reference_model(seer, tokenizer)

    var mapped_embedding = seer.mmap_ptr.unsafe_offset(
        seer.tensor_file_offsets["token_embd.weight"]
    ).unsafe_bitcast[Scalar[f16]]()
    if seer.tensors["token_embd.weight"].data != mapped_embedding:
        raise Error("F16 embedding tensor was copied instead of mapped zero-copy")

    var source_norm = seer.mmap_ptr.unsafe_offset(
        seer.tensor_file_offsets["output_norm.weight"]
    ).unsafe_bitcast[Float32]()
    var expected_norm = source_norm.unsafe_load(0).cast[f16]()
    if seer.tensors["output_norm.weight"].data.unsafe_load(0) != expected_norm:
        raise Error("F32 normalization tensor conversion changed its value")

    var tokens = tokenizer.encode("One day, Timmy went to", True)
    var expected_tokens = List[Int]()
    expected_tokens.append(1)
    expected_tokens.append(385)
    expected_tokens.append(328)
    expected_tokens.append(432)
    expected_tokens.append(405)
    expected_tokens.append(263)
    expected_tokens.append(377)
    expected_tokens.append(267)
    if len(tokens) != len(expected_tokens):
        raise Error("real GGUF tokenizer token count differs from llama.cpp")
    for index in range(len(tokens)):
        if tokens[index] != expected_tokens[index]:
            raise Error("real GGUF tokenizer token ID differs from llama.cpp")
    print("Reference prompt token IDs:")
    for index in range(len(tokens)):
        print(tokens[index])

    var blocks = List[TransformerBlock]()
    for layer_index in range(seer.config.block_count):
        blocks.append(
            TransformerBlock(
                layer_index,
                seer.config.head_dim(),
                seer.config.head_count,
                seer,
            )
        )
    var kv_cache = KVCache(
        seer.config.context_length,
        seer.config.kv_dim(),
        pool,
        seer.config.block_count,
    )
    var next_token = 0
    for position in range(len(tokens)):
        next_token = forward_pass(
            tokens,
            seer,
            pool,
            kv_cache,
            position,
            seer.config.block_count,
            seer.config.head_dim(),
            seer.config.head_count,
            DeviceTopology(1),
            blocks,
        )
    print("Reference first greedy token ID:", next_token)
    print("Reference first greedy token text:", tokenizer.decode(next_token))
    if next_token != 265:
        raise Error("real GGUF first token differs from llama.cpp greedy output")
    print("Real GGUF loader, tokenizer, and first-token inference: PASS")
