from std.sys import argv
from std.ffi import external_call
from core.mimir_well import DeviceTopology, KVCache, MimirWell, f16
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.inference import TransformerBlock, forward_pass
def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A037 clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])
def expected_generated() -> List[Int]:
    var e = List[Int]()
    e.append(265); e.append(282); e.append(295); e.append(433)
    e.append(335); e.append(345); e.append(357); e.append(426)
    e.append(342); e.append(394); e.append(261); e.append(370)
    e.append(268); e.append(414); e.append(444); e.append(335)
    e.append(261); e.append(370); e.append(268); e.append(414)
    e.append(444); e.append(426); e.append(291); e.append(268)
    e.append(414); e.append(444); e.append(286); e.append(399)
    e.append(262); e.append(423); e.append(388); e.append(269)
    return e^
def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: bench_decode_census_a037 <model.gguf>")
    var path = arguments[1]
    var pool = MimirWell(64 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(path)
    seer.mmap_and_load(pool, tokenizer)
    var tokens8 = tokenizer.encode("One day, Timmy went to", True)
    var blocks = List[TransformerBlock]()
    for layer_index in range(seer.config.block_count):
        blocks.append(TransformerBlock(layer_index, seer.config.head_dim(), seer.config.head_count, seer))
    var nlayers = seer.config.block_count
    var hdim = seer.config.head_dim()
    var nheads = seer.config.head_count
    var kvdim = seer.config.kv_dim()
    var ctx = seer.config.context_length
    var oracle = expected_generated()
    print("A037 fixture loaded layers", nlayers, "ctx", ctx)
    var total_tokens = 0
    var t_all0 = monotonic_ns()
    for rep in range(1200):
        var mark = pool.offset
        var kv = KVCache(ctx, kvdim, pool, nlayers)
        var seq = tokens8.copy()
        var nxt = 0
        for pos in range(8):
            nxt = forward_pass(seq, seer, pool, kv, pos, nlayers, hdim, nheads, DeviceTopology(1), blocks)
        var gen = List[Int]()
        gen.append(nxt)
        for step in range(32):
            seq.append(nxt)
            nxt = forward_pass(seq, seer, pool, kv, 8 + step, nlayers, hdim, nheads, DeviceTopology(1), blocks)
            gen.append(nxt)
        for i in range(32):
            if gen[i] != oracle[i]:
                raise Error("A037 decode token differs from oracle")
        total_tokens += 32
        pool.reset_kv_cache(mark)
    var t_all1 = monotonic_ns()
    var elapsed = t_all1 - t_all0
    print("A037_DECODE total_tokens=", total_tokens, "elapsed_ns=", elapsed, "tokens_per_s=", Float64(total_tokens) * 1000000000.0 / Float64(elapsed))
    print("A037_BENCH: PASS")
