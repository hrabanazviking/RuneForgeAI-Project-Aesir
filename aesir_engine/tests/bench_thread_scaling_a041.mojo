"""A-041 bench: thread scaling law for CPU decode.

Two measurements per process run; the runner varies AESIR_THREADS
per process (the production knob), so each run exercises the real
dispatch path end to end:

- DECODE: the A-037 census fixture (stories260K.F16.gguf, sha256
  pinned by the runner) driven exactly like A-037/A-030: 8-token
  canonical prefill + 32 greedy decode steps per rep through
  forward_pass, KV arena recycled per rep via
  MimirWell.reset_kv_cache(mark), every rep oracle-exact vs the
  pinned llama.cpp token IDs (raw-oracle discipline, CPU vs CPU).
  The runner sets AESIR_PAR_MIN_WORK=1 for this part's processes
  so the small model's dispatches actually engage the thread
  layer (production default 2^20 would keep this fixture serial;
  that engagement fact is itself filed in the A-041 doc).
- GEMV: an engaged-regime dispatch -- one f32 matvec of
  K=4096 x N=11008 (45,088,768 MACs, above the production
  engagement threshold) partitioned by output columns via
  par_for, the same partition contract as the GEMM kernels.
  Median of timed reps; checksum accumulated serially in the
  serial order, so it must be identical at every thread count.
"""
from std.sys import argv
from std.ffi import external_call
from std.memory import alloc
from core.mimir_well import DeviceTopology, KVCache, MimirWell, f16
from core.parallel import par_cpu_count, par_for, par_thread_count
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.inference import TransformerBlock, forward_pass


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A041 clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def median(mut xs: List[Int]) -> Int:
    for i in range(1, len(xs)):
        var v = xs[i]
        var j = i - 1
        while j >= 0 and xs[j] > v:
            xs[j + 1] = xs[j]
            j -= 1
        xs[j + 1] = v
    return xs[len(xs) // 2]


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


def _gemv_range(
    input_addr: Int64,
    matrix_addr: Int64,
    output_addr: Int64,
    k: Int,
    n: Int,
    col_lo: Int,
    col_hi: Int,
):
    var input = Pointer[Float32, MutUntrackedOrigin](
        unsafe_from_address=Int(input_addr)
    )
    var matrix = Pointer[Float32, MutUntrackedOrigin](
        unsafe_from_address=Int(matrix_addr)
    )
    var output = Pointer[Float32, MutUntrackedOrigin](
        unsafe_from_address=Int(output_addr)
    )
    for j in range(col_lo, col_hi):
        var acc = Float32(0)
        for kk in range(k):
            acc += input.unsafe_load(kk) * matrix.unsafe_load(kk * n + j)
        output.unsafe_store(j, acc)


def _gemv_worker(ctx_addr: Int64, start: Int64, end: Int64):
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    _gemv_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(start),
        Int(end),
    )


def run_gemv() raises:
    comptime K = 4096
    comptime N = 11008
    comptime REPS = 25
    var input = alloc[Float32](K)
    var matrix = alloc[Float32](K * N)
    var output = alloc[Float32](N)
    var state: UInt64 = 0xA041
    for i in range(K * N):
        state = state * 6364136223846793005 + 1442695040888963407
        matrix.unsafe_store(
            i, Float32(Int(state >> 40) & 0xFF) / Float32(255.0) - Float32(0.5)
        )
    for i in range(K):
        state = state * 6364136223846793005 + 1442695040888963407
        input.unsafe_store(
            i, Float32(Int(state >> 40) & 0xFF) / Float32(255.0) - Float32(0.5)
        )
    var ctx = alloc[Int64](5)
    ctx.unsafe_store(0, Int64(Int(input)))
    ctx.unsafe_store(1, Int64(Int(matrix)))
    ctx.unsafe_store(2, Int64(Int(output)))
    ctx.unsafe_store(3, Int64(K))
    ctx.unsafe_store(4, Int64(N))
    var work = Int64(K) * Int64(N)
    var chunks = 0
    for _ in range(3):
        chunks = par_for[_gemv_worker](Int64(Int(ctx)), N, work)
    var times = List[Int]()
    for _ in range(REPS):
        var t0 = monotonic_ns()
        chunks = par_for[_gemv_worker](Int64(Int(ctx)), N, work)
        times.append(monotonic_ns() - t0)
    var checksum = Float32(0)
    for j in range(N):
        checksum += output.unsafe_load(j)
    print(
        "A041_GEMV K=", K, " N=", N, " chunks=", chunks,
        " median_ns=", median(times), " checksum=", checksum,
    )
    ctx.unsafe_free()
    input.unsafe_free()
    matrix.unsafe_free()
    output.unsafe_free()


def run_decode(path: String, reps: Int) raises:
    var pool = MimirWell(64 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(path)
    seer.mmap_and_load(pool, tokenizer)
    var tokens8 = tokenizer.encode("One day, Timmy went to", True)
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
    var nlayers = seer.config.block_count
    var hdim = seer.config.head_dim()
    var nheads = seer.config.head_count
    var kvdim = seer.config.kv_dim()
    var ctx_len = seer.config.context_length
    var oracle = expected_generated()
    var total_tokens = 0
    var t_all0 = monotonic_ns()
    for _rep in range(reps):
        var mark = pool.offset
        var kv = KVCache(ctx_len, kvdim, pool, nlayers)
        var seq = tokens8.copy()
        var nxt = 0
        for pos in range(8):
            nxt = forward_pass(
                seq, seer, pool, kv, pos, nlayers, hdim, nheads,
                DeviceTopology(1), blocks,
            )
        var gen = List[Int]()
        gen.append(nxt)
        for step in range(32):
            seq.append(nxt)
            nxt = forward_pass(
                seq, seer, pool, kv, 8 + step, nlayers, hdim, nheads,
                DeviceTopology(1), blocks,
            )
            gen.append(nxt)
        for i in range(32):
            if gen[i] != oracle[i]:
                raise Error("A041 decode token differs from oracle")
        total_tokens += 32
        pool.reset_kv_cache(mark)
    var elapsed = monotonic_ns() - t_all0
    print(
        "A041_DECODE reps=", reps, " total_tokens=", total_tokens,
        " elapsed_ns=", elapsed,
        " tokens_per_s=",
        Float64(total_tokens) * 1000000000.0 / Float64(elapsed),
    )


def main() raises:
    var arguments = argv()
    if len(arguments) != 3:
        raise Error("usage: bench_thread_scaling_a041 <model.gguf> <reps>")
    print(
        "A041_BENCH par_cpu_count=", par_cpu_count(),
        " par_thread_count=", par_thread_count(),
    )
    run_gemv()
    run_decode(arguments[1], Int(atol(arguments[2])))
    print("A041_BENCH: PASS")
