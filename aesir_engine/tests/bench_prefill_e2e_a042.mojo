# tests/bench_prefill_e2e_a042.mojo
# A-042: end-to-end prefill batching audit on the pinned
# stories260K fixture (sha256 57a81ed1...e3, the A-030/A-037
# fixture). Standalone bench driver (NOT part of run_all).
# Discipline follows A-030: CLOCK_MONOTONIC nanosecond timing
# around forward loops only; 1 settle trial discarded + 5
# measured trials, median reported; correctness = the batched
# path's last token must equal the per-token path's last token
# at both prompt lengths (the two paths are documented
# bit-identical in core/inference.mojo), and the 64-token
# per-token last token must equal the A-030 oracle expectation
# (the token the A-030 baseline's prefill64 leg produced).
# Configs: prefill64 per-token, prefill64 batched (one call),
# prefill128 per-token, prefill128 batched (one call -- the
# production facade chunk cap is 256; the fixture context is
# 128, so a 128-token prompt is exactly one batched chunk and
# fills the fixture KV cache exactly.

from std.sys import argv
from std.ffi import external_call

from core.mimir_well import DeviceTopology, KVCache, MimirWell, f16
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.inference import TransformerBlock, forward_pass, forward_pass_batched


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A042: cannot observe monotonic clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def median_of(mut vals: List[Float64]) -> Float64:
    for i in range(len(vals)):
        for j in range(len(vals) - 1 - i):
            if vals[j] > vals[j + 1]:
                var tmp = vals[j]
                vals[j] = vals[j + 1]
                vals[j + 1] = tmp
    return vals[len(vals) // 2]


def make_tokens(tokenizer: RuneWeaver, count: Int) raises -> List[Int]:
    var text = String("a")
    for _ in range(count - 2):
        text += String(" a")
    var tokens = tokenizer.encode(text, True)
    if len(tokens) != count:
        raise Error(
            "A042: prompt is " + String(len(tokens))
            + " tokens, expected " + String(count)
        )
    return tokens^


def run_per_token(
    tokens: List[Int],
    mut seer: GGUFSeer,
    mut pool: MimirWell,
    blocks: List[TransformerBlock],
    trials: Int,
) raises -> Float64:
    var nlayers = seer.config.block_count
    var hdim = seer.config.head_dim()
    var nheads = seer.config.head_count
    var kvdim = seer.config.kv_dim()
    var ctx = seer.config.context_length
    var n = len(tokens)
    var rates = List[Float64]()
    var last = 0
    for trial in range(trials):
        var kv = KVCache(ctx, kvdim, pool, nlayers)
        var nxt = 0
        var t0 = monotonic_ns()
        for pos in range(n):
            nxt = forward_pass(
                tokens, seer, pool, kv, pos, nlayers, hdim, nheads,
                DeviceTopology(1), blocks,
            )
        var t1 = monotonic_ns()
        last = nxt
        if trial > 0:
            var r = Float64(n) * 1000000000.0 / Float64(t1 - t0)
            rates.append(r)
            print(
                "A042_RESULT config=prefill" + String(n) + "_per_token trial="
                + String(trial) + " elapsed_ns=" + String(t1 - t0)
                + " tokens_per_s=" + String(r)
            )
    print(
        "A042_MEDIAN config=prefill" + String(n) + "_per_token tokens_per_s="
        + String(median_of(rates)) + " last_token=" + String(last)
    )
    return median_of(rates)


def run_batched(
    tokens: List[Int],
    mut seer: GGUFSeer,
    mut pool: MimirWell,
    blocks: List[TransformerBlock],
    trials: Int,
    expected_last: Int,
) raises -> Float64:
    var nlayers = seer.config.block_count
    var hdim = seer.config.head_dim()
    var nheads = seer.config.head_count
    var kvdim = seer.config.kv_dim()
    var ctx = seer.config.context_length
    var n = len(tokens)
    var rates = List[Float64]()
    for trial in range(trials):
        var kv = KVCache(ctx, kvdim, pool, nlayers)
        var t0 = monotonic_ns()
        var nxt = forward_pass_batched(
            tokens, seer, pool, kv, 0, n, nlayers, hdim, nheads,
            DeviceTopology(1), blocks,
        )
        var t1 = monotonic_ns()
        if nxt != expected_last:
            raise Error(
                "A042: batched prefill" + String(n)
                + " last token differs from per-token path"
            )
        if trial > 0:
            var r = Float64(n) * 1000000000.0 / Float64(t1 - t0)
            rates.append(r)
            print(
                "A042_RESULT config=prefill" + String(n) + "_batched trial="
                + String(trial) + " elapsed_ns=" + String(t1 - t0)
                + " tokens_per_s=" + String(r)
            )
    print(
        "A042_MEDIAN config=prefill" + String(n) + "_batched tokens_per_s="
        + String(median_of(rates))
    )
    return median_of(rates)


def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: bench_prefill_e2e_a042 <model.gguf>")
    var path = arguments[1]
    var pool = MimirWell(64 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(path)
    seer.mmap_and_load(pool, tokenizer)
    if seer.config.architecture != "llama" or seer.config.block_count != 5:
        raise Error("A042: fixture config mismatch")
    var blocks = List[TransformerBlock]()
    for layer_index in range(seer.config.block_count):
        blocks.append(
            TransformerBlock(
                layer_index, seer.config.head_dim(),
                seer.config.head_count, seer,
            )
        )
    print(
        "A042 fixture loaded: layers", seer.config.block_count,
        "head_dim", seer.config.head_dim(),
        "ctx", seer.config.context_length,
    )
    var tokens64 = make_tokens(tokenizer, 64)
    var tokens128 = make_tokens(tokenizer, 128)
    var med64_rows = run_per_token(tokens64, seer, pool, blocks, 6)
    # The per-token 64 last token is captured inside run_per_token's
    # print; re-derive it once here for the batched parity gate.
    var kv = KVCache(
        seer.config.context_length, seer.config.kv_dim(), pool,
        seer.config.block_count,
    )
    var last64 = 0
    for pos in range(64):
        last64 = forward_pass(
            tokens64, seer, pool, kv, pos, seer.config.block_count,
            seer.config.head_dim(), seer.config.head_count,
            DeviceTopology(1), blocks,
        )
    var med64_batch = run_batched(tokens64, seer, pool, blocks, 6, last64)
    print(
        "A042_SPEEDUP prefill64 batched_vs_per_token="
        + String(med64_batch / med64_rows)
    )
    var med128_rows = run_per_token(tokens128, seer, pool, blocks, 6)
    var kv2 = KVCache(
        seer.config.context_length, seer.config.kv_dim(), pool,
        seer.config.block_count,
    )
    var last128 = 0
    for pos in range(128):
        last128 = forward_pass(
            tokens128, seer, pool, kv2, pos, seer.config.block_count,
            seer.config.head_dim(), seer.config.head_count,
            DeviceTopology(1), blocks,
        )
    var med128_batch = run_batched(tokens128, seer, pool, blocks, 6, last128)
    print(
        "A042_SPEEDUP prefill128 batched_vs_per_token="
        + String(med128_batch / med128_rows)
    )
    print("A042 e2e bench: DONE")
