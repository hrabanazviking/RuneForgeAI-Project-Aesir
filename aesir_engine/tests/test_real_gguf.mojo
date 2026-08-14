# tests/test_real_gguf.mojo
# Opt-in integration proving for a dynamically supplied real GGUF path.

from std.sys import argv

from core.mimir_well import MimirWell
from loader.gguf import GGMLType, GGUFSeer
from loader.tokenizer import RuneWeaver


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

    var tokens = tokenizer.encode("One day, Timmy went to", True)
    if len(tokens) <= 1:
        raise Error("real GGUF tokenizer returned no prompt tokens")
    print("Reference prompt token IDs:")
    for index in range(len(tokens)):
        print(tokens[index])
    print("Real GGUF loader and tokenizer metadata: PASS")
