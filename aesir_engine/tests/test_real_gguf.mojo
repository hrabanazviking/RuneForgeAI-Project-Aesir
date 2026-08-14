# tests/test_real_gguf.mojo
# Opt-in integration proving for a dynamically supplied real GGUF path.

from std.sys import argv

from core.mimir_well import DeviceTopology, KVCache, MimirWell, f16
from loader.gguf import GGMLType, GGUFSeer
from loader.tokenizer import RuneWeaver
from core.inference import TransformerBlock, forward_pass
from aesir import AesirEngine


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

    var expected_generated = List[Int]()
    expected_generated.append(265)
    expected_generated.append(282)
    expected_generated.append(295)
    expected_generated.append(433)
    expected_generated.append(335)
    expected_generated.append(345)
    expected_generated.append(357)
    expected_generated.append(426)
    expected_generated.append(342)
    expected_generated.append(394)
    expected_generated.append(261)
    expected_generated.append(370)
    expected_generated.append(268)
    expected_generated.append(414)
    expected_generated.append(444)
    expected_generated.append(335)
    expected_generated.append(261)
    expected_generated.append(370)
    expected_generated.append(268)
    expected_generated.append(414)
    expected_generated.append(444)
    expected_generated.append(426)
    expected_generated.append(291)
    expected_generated.append(268)
    expected_generated.append(414)
    expected_generated.append(444)
    expected_generated.append(286)
    expected_generated.append(399)
    expected_generated.append(262)
    expected_generated.append(423)
    expected_generated.append(388)
    expected_generated.append(269)

    var engine = AesirEngine(arguments[1], knowledge_capacity=1)
    var result = engine.generate_tokens("One day, Timmy went to", 32)
    if result.prompt_token_count != 8:
        raise Error("structured generation reported the wrong prompt token count")
    if result.generated_token_count() != 32:
        raise Error("structured generation did not return exactly 32 tokens")
    if result.stop_reason != "length":
        raise Error("32-token reference request did not stop for length")
    for index in range(len(expected_generated)):
        if result.token_ids[index] != expected_generated[index]:
            print("Generated token mismatch at index", index)
            print("Expected:", expected_generated[index], "Actual:", result.token_ids[index])
            raise Error("multi-token output differs from pinned llama.cpp oracle")

    var expected_text = String(" the park with his mom. They saw a big box with a big box. The box was very small and")
    if result.text != expected_text:
        print("Expected text:", expected_text)
        print("Actual text:", result.text)
        raise Error("decoded multi-token text differs from pinned llama.cpp oracle")

    var one_token = engine.generate_tokens("One day, Timmy went to", 1)
    if len(one_token.token_ids) != 1 or one_token.token_ids[0] != 265:
        raise Error("one-token compatibility regression")
    if one_token.text != " the" or one_token.stop_reason != "length":
        raise Error("one-token decoded output or stop reason regressed")

    # BOS plus 127 single-piece `a` tokens exactly fills this model's
    # 128-position context. The engine may emit the first token obtained from
    # the final legal prompt position, but must not evaluate that generated
    # token at position 128.
    var full_context_prompt = String("a")
    for _ in range(126):
        full_context_prompt += String(" a")
    var context_result = engine.generate_tokens(full_context_prompt, 2)
    if context_result.prompt_token_count != 128:
        raise Error("context-boundary fixture no longer tokenizes to 128 tokens")
    if context_result.generated_token_count() != 1:
        raise Error("context-boundary request evaluated beyond the legal prompt")
    if context_result.stop_reason != "context_exhausted":
        raise Error("full-context request did not report context exhaustion")
    if engine.pool.offset != engine.runtime_offset:
        raise Error("generation did not restore the persistent runtime boundary")

    print("Real GGUF loader, tokenizer, and exact 32-token inference: PASS")
