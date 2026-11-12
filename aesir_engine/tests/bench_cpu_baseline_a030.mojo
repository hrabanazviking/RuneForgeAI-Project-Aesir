# tests/bench_cpu_baseline_a030.mojo
# A-030: CPU performance baseline for the pinned stories260K fixture
# on the Z13 CPU path. Standalone bench driver (NOT part of run_all).
# Discipline: CLOCK_MONOTONIC (clockid 1) nanosecond timing around
# forward loops only; 1 settle run discarded + 5 measured trials;
# correctness verified against the pinned llama.cpp oracle token
# IDs from A-004 (prompt ids, first token 265, 32 greedy ids).
# Configs: prefill8 per-token, prefill64 per-token, prefill64
# batched (forward_pass_batched), decode32, facade generate_tokens.

from std.sys import argv
from std.ffi import external_call

from core.mimir_well import DeviceTopology, KVCache, MimirWell, f16
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.inference import TransformerBlock, forward_pass, forward_pass_batched
from aesir import AesirEngine


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A030: cannot observe monotonic clock")
    if ts[0] < 0 or ts[1] < 0 or ts[1] >= 1000000000:
        raise Error("A030: invalid monotonic clock reading")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def median_of(mut vals: List[Float64]) -> Float64:
    for i in range(len(vals)):
        for j in range(len(vals) - 1 - i):
            if vals[j] > vals[j + 1]:
                var tmp = vals[j]
                vals[j] = vals[j + 1]
                vals[j + 1] = tmp
    return vals[len(vals) // 2]


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
        raise Error("usage: bench_cpu_baseline_a030 <model.gguf>")
    var path = arguments[1]
    var pool = MimirWell(64 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(path)
    seer.mmap_and_load(pool, tokenizer)
    if seer.config.architecture != "llama" or seer.config.block_count != 5:
        raise Error("A030: fixture config mismatch")
    var tokens8 = tokenizer.encode("One day, Timmy went to", True)
    var expected8 = List[Int]()
    expected8.append(1); expected8.append(385); expected8.append(328)
    expected8.append(432); expected8.append(405); expected8.append(263)
    expected8.append(377); expected8.append(267)
    if len(tokens8) != 8:
        raise Error("A030: canonical prompt is not 8 tokens")
    for i in range(8):
        if tokens8[i] != expected8[i]:
            raise Error("A030: prompt token ID differs from oracle")
    var long_text = String("a")
    for _ in range(62):
        long_text += String(" a")
    var tokens64 = tokenizer.encode(long_text, True)
    if len(tokens64) != 64:
        raise Error("A030: long prompt is not 64 tokens")
    var blocks = List[TransformerBlock]()
    for layer_index in range(seer.config.block_count):
        blocks.append(TransformerBlock(layer_index, seer.config.head_dim(), seer.config.head_count, seer))
    var nlayers = seer.config.block_count
    var hdim = seer.config.head_dim()
    var nheads = seer.config.head_count
    var kvdim = seer.config.kv_dim()
    var ctx = seer.config.context_length
    var oracle = expected_generated()
    print("A030 fixture loaded: layers", nlayers, "head_dim", hdim, "ctx", ctx)
    # --- Config A: prefill, 8-token prompt, per-token forward_pass ---
    var rates_a = List[Float64]()
    for trial in range(6):
        var kv = KVCache(ctx, kvdim, pool, nlayers)
        var nxt = 0
        var t0 = monotonic_ns()
        for pos in range(8):
            nxt = forward_pass(tokens8, seer, pool, kv, pos, nlayers, hdim, nheads, DeviceTopology(1), blocks)
        var t1 = monotonic_ns()
        if nxt != 265:
            raise Error("A030: prefill8 last output differs from oracle")
        if trial > 0:
            var r = Float64(8) * 1000000000.0 / Float64(t1 - t0)
            rates_a.append(r)
            print("A030_RESULT config=prefill8_per_token trial=", trial, "elapsed_ns=", t1 - t0, "tokens_per_s=", r)
    print("A030_MEDIAN config=prefill8_per_token tokens_per_s=", median_of(rates_a))
    # --- Config B: prefill, 64-token prompt, per-token forward_pass ---
    var rates_b = List[Float64]()
    var last64_per_token = 0
    for trial in range(6):
        var kv = KVCache(ctx, kvdim, pool, nlayers)
        var nxt = 0
        var t0 = monotonic_ns()
        for pos in range(64):
            nxt = forward_pass(tokens64, seer, pool, kv, pos, nlayers, hdim, nheads, DeviceTopology(1), blocks)
        var t1 = monotonic_ns()
        last64_per_token = nxt
        if trial > 0:
            var r = Float64(64) * 1000000000.0 / Float64(t1 - t0)
            rates_b.append(r)
            print("A030_RESULT config=prefill64_per_token trial=", trial, "elapsed_ns=", t1 - t0, "tokens_per_s=", r)
    print("A030_MEDIAN config=prefill64_per_token tokens_per_s=", median_of(rates_b))
    # --- Config C: prefill, 64-token prompt, batched (one call) ---
    var rates_c = List[Float64]()
    for trial in range(6):
        var kv = KVCache(ctx, kvdim, pool, nlayers)
        var t0 = monotonic_ns()
        var nxt = forward_pass_batched(tokens64, seer, pool, kv, 0, 64, nlayers, hdim, nheads, DeviceTopology(1), blocks)
        var t1 = monotonic_ns()
        if nxt != last64_per_token:
            raise Error("A030: batched prefill output differs from per-token")
        if trial > 0:
            var r = Float64(64) * 1000000000.0 / Float64(t1 - t0)
            rates_c.append(r)
            print("A030_RESULT config=prefill64_batched trial=", trial, "elapsed_ns=", t1 - t0, "tokens_per_s=", r)
    print("A030_MEDIAN config=prefill64_batched tokens_per_s=", median_of(rates_c))
    print("A030 parity: batched == per-token last token", last64_per_token)
    # --- Config D: decode, 32 greedy steps after 8-token prefill ---
    var rates_d = List[Float64]()
    for trial in range(6):
        var kv = KVCache(ctx, kvdim, pool, nlayers)
        var seq = tokens8.copy()
        var nxt = 0
        for pos in range(8):
            nxt = forward_pass(seq, seer, pool, kv, pos, nlayers, hdim, nheads, DeviceTopology(1), blocks)
        var gen = List[Int]()
        gen.append(nxt)
        var t0 = monotonic_ns()
        for step in range(32):
            seq.append(nxt)
            nxt = forward_pass(seq, seer, pool, kv, 8 + step, nlayers, hdim, nheads, DeviceTopology(1), blocks)
            gen.append(nxt)
        var t1 = monotonic_ns()
        for i in range(32):
            if gen[i] != oracle[i]:
                raise Error("A030: decode token differs from oracle")
        if trial > 0:
            var r = Float64(32) * 1000000000.0 / Float64(t1 - t0)
            rates_d.append(r)
            print("A030_RESULT config=decode32 trial=", trial, "elapsed_ns=", t1 - t0, "tokens_per_s=", r)
    print("A030_MEDIAN config=decode32 tokens_per_s=", median_of(rates_d))
    # --- Config E: AesirEngine facade, end-to-end generate_tokens ---
    var engine = AesirEngine(path, knowledge_capacity=1)
    var rates_e = List[Float64]()
    for trial in range(6):
        var t0 = monotonic_ns()
        var result = engine.generate_tokens("One day, Timmy went to", 32)
        var t1 = monotonic_ns()
        if result.prompt_token_count != 8 or result.generated_token_count() != 32:
            raise Error("A030: facade counts differ")
        for i in range(32):
            if result.token_ids[i] != oracle[i]:
                raise Error("A030: facade token differs from oracle")
        if trial > 0:
            var r = Float64(32) * 1000000000.0 / Float64(t1 - t0)
            rates_e.append(r)
            print("A030_RESULT config=facade_e2e_gen32 trial=", trial, "elapsed_ns=", t1 - t0, "tokens_per_s=", r)
    print("A030_MEDIAN config=facade_e2e_gen32 tokens_per_s=", median_of(rates_e))
    print("A030_BENCH: PASS")
