from std.sys import argv
from core.mimir_well import DeviceTopology, KVCache, MimirWell, f16
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.inference import TransformerBlock, forward_pass
def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: bench_arch_matrix_a048 <model.gguf>")
    var path = arguments[1]
    var pool = MimirWell(256 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(path)
    seer.mmap_and_load(pool, tokenizer)
    print("A048_LOAD: PASS arch=", seer.config.architecture, " layers=", seer.config.block_count, " emb=", seer.config.embedding_length, " ffn=", seer.config.feed_forward_length, " heads=", seer.config.head_count, " kv_heads=", seer.config.head_count_kv, " ctx=", seer.config.context_length)
    var tokens = tokenizer.encode("One day, Timmy went to", True)
    print("A048_PROMPT_TOKENS:", len(tokens))
    var blocks = List[TransformerBlock]()
    for layer_index in range(seer.config.block_count):
        blocks.append(TransformerBlock(layer_index, seer.config.head_dim(), seer.config.head_count, seer))
    var nlayers = seer.config.block_count
    var hdim = seer.config.head_dim()
    var nheads = seer.config.head_count
    var kvdim = seer.config.kv_dim()
    var ctx = seer.config.context_length
    var kv = KVCache(ctx, kvdim, pool, nlayers)
    var seq = tokens.copy()
    var n = len(tokens)
    var nxt = 0
    for pos in range(n):
        nxt = forward_pass(seq, seer, pool, kv, pos, nlayers, hdim, nheads, DeviceTopology(1), blocks)
    var gen = List[Int]()
    gen.append(nxt)
    for step in range(15):
        seq.append(nxt)
        nxt = forward_pass(seq, seer, pool, kv, n + step, nlayers, hdim, nheads, DeviceTopology(1), blocks)
        gen.append(nxt)
    var line = String("A048_GEN:")
    for i in range(len(gen)):
        if gen[i] < 0 or gen[i] >= 512:
            raise Error("A048: generated token out of vocab range")
        line += String(" ") + String(gen[i])
    print(line)
    print("A048_SMOKE: PASS arch=", seer.config.architecture)
