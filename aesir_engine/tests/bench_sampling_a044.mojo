# tests/bench_sampling_a044.mojo
# A-044: CPU sampling cost proof -- direct batch-timed microbench of
# sample_token_from_logits (standalone, NOT in run_all). Timer reads
# are OUTSIDE the timed loops (two phase_now_ns calls per config
# trial), so per-call cost is sampler work only, with timer overhead
# amortised over thousands of calls. Token-time denominator comes
# from the real engine runs filed alongside (A-036 phase bench:
# sample_ns / generation time; A-037 census token rate).
# Configs: greedy (the engine standard-run path) and stochastic
# (temp 0.8, top_k 40, top_p 0.95) plus stochastic-untruncated
# (temp 1.0, no top_k/top_p), at vocab 512 (stories260K fixture
# vocab, token_embd rows) and vocab 32000 (realistic LLM scale).
# Logits are deterministic synthetic F16: spread in [-4, 4] with a
# unique peak 10.0 at index 37, so greedy must return 37 exactly
# and every stochastic candidate falls within the 15.0 threshold
# window (worst-case candidate count == vocab, labelled as such).
from std.memory.alloc import alloc, Layout
from std.memory import Pointer
from core.compute import MutUntrackedOrigin
from core.mimir_well import f16
from core.phase_timing import phase_now_ns
from core.sampler import RuneRNG, sample_token_from_logits


def _fill(vocab: Int) -> Pointer[Scalar[f16], MutUntrackedOrigin]:
    var ptr = alloc(Layout[Scalar[f16]](count=vocab)).unsafe_leak().unsafe_origin_cast[MutUntrackedOrigin]()
    for i in range(vocab):
        var h = (i * 2654435761) % 1000
        ptr.unsafe_store(i, Scalar[f16](Float32(h) / Float32(125.0) - Float32(4.0)))
    ptr.unsafe_store(37, Scalar[f16](10.0))
    return ptr


def _trial_greedy(ptr: Pointer[Scalar[f16], MutUntrackedOrigin], vocab: Int, reps: Int, trial: Int) raises:
    var rng = RuneRNG(42)
    var sink = 0
    var t0 = phase_now_ns()
    for _ in range(reps):
        sink += sample_token_from_logits(ptr, vocab, Float32(0.0), 40, Float32(1.0), Float32(1.0), List[Int](), rng)
    var elapsed = phase_now_ns() - t0
    if sink != 37 * reps:
        raise Error("A044 greedy sink wrong")
    print("A044_MEASURED config=greedy vocab=", vocab, " trial=", trial, " reps=", reps, " elapsed_ns=", elapsed, " per_call_ns=", elapsed // Int64(reps), " sink=", sink)


def _trial_stoch(ptr: Pointer[Scalar[f16], MutUntrackedOrigin], vocab: Int, reps: Int, trial: Int, top_k: Int, top_p: Float32, temp: Float32, label: String) raises:
    var rng = RuneRNG(1234)
    var sink = 0
    var t0 = phase_now_ns()
    for _ in range(reps):
        sink += sample_token_from_logits(ptr, vocab, temp, top_k, top_p, Float32(1.0), List[Int](), rng)
    var elapsed = phase_now_ns() - t0
    if sink < 0:
        raise Error("A044 stoch sink wrong")
    print("A044_MEASURED config=", label, " vocab=", vocab, " trial=", trial, " reps=", reps, " elapsed_ns=", elapsed, " per_call_ns=", elapsed // Int64(reps), " sink=", sink)


def main() raises:
    var p512 = _fill(512)
    var p32000 = _fill(32000)
    for t in range(3):
        _trial_greedy(p512, 512, 20000, t)
    for t in range(3):
        _trial_greedy(p32000, 32000, 2000, t)
    for t in range(3):
        _trial_stoch(p512, 512, 2000, t, 40, Float32(0.95), Float32(0.8), String("stoch_topk40_topp95"))
    for t in range(3):
        _trial_stoch(p32000, 32000, 5, t, 40, Float32(0.95), Float32(0.8), String("stoch_topk40_topp95"))
    for t in range(3):
        _trial_stoch(p512, 512, 2000, t, 0, Float32(1.0), Float32(1.0), String("stoch_untruncated"))
    for t in range(3):
        _trial_stoch(p32000, 32000, 200, t, 0, Float32(1.0), Float32(1.0), String("stoch_untruncated"))
    print("A044_BENCH: PASS")
