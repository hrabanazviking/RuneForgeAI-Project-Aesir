# QS-1 NOTES — CPU-resident speed (team lead seat, QS-1)

Seat: ONE worker running the six Mythic Engineering roles
sequentially (coordinator / architect / builder / tester /
grader / banker) — no sub-agents available at depth 2/2;
recorded per commission. Tree: ~/aesir-qs-cpu, branch
yrsa/qs-cpu @ bad65106 (QS-0 close). Live gate (PID 5932,
:18434, ~/aesir-q35-7) is a bench target only, never touched.
Ollama/Voxta untouched. No Docker. No README edits.

## QS-1.0 AUDIT (2026-11-15 ~00:05-00:20 EST, code read on this tree)

Machine at start: up 4:03, load1 1.67 falling to 1.15,
MemAvailable 113 GB. HEAVY.lock HELD by QS-3 (yrsa/qs-pack,
QS-3.8 v3 re-pack quantize running, unit qs3-27b-v3) — all
heavy work below waits for the lock; light/code work proceeds.

Real shapes (Q35-1 census, MAP): 64 blocks (48 SSM + 16
full-attn), hidden K=5120, FFN 17408, vocab 248320, SSM inner
6144, qkv 10240x5120, gate 6144x5120, alpha/beta 48x5120,
ssm_out 5120x6144, attn q 12288x5120, k/v 1024x5120, o
5120x6144, ffn 17408x5120 + 5120x17408, LM head 248320x5120.
Total ~25.6 GMAC/token, ~28.5 GB packed Q8_0 read per token.
At the QS-0 baseline 2.14 tok/s that is ~55 GB/s effective;
Ollama Q8_0 7.65 tok/s implies ~218 GB/s class int8-dot work.

### Finding 1 — decode ALREADY routes to the GEMV (QS-0 mechanism corrected)
- gemm_f16 dispatches Q8_0 weights to gemm_q8_0
  (core/compute.mojo), which routes A.rows==1 to
  _gemm_q8_0_gemv_worker (fused width-16 SIMD) and rows>1 to
  _gemm_q8_0_fast_worker (fast_range).
- Serve decode: Qwen35CPUSession.next_chunk ->
  AesirEngine._forward_position -> forward_pass_qwen35 ->
  Qwen35Block.forward with a 1-row x -> every GEMM is rows==1
  -> GEMV. Engine _run_generation decode loop likewise uses
  _forward_position. There is NO batched-decode leak in the
  session or engine generation loops.
- The only _forward_batch uses are prefill chunks in
  begin_turn / _run_generation (final chunk included, which
  is prefill by construction). QS-0's 86.27% fast_range share
  is a WINDOW artifact: the profiled p500 stream run spent
  116.6 s in prefill (435 tok, dense 24-thread fast_range
  work) vs decode whose GEMV work is memory-bound and whose
  per-token par_for spawn churn (below) is taxed ~5x by
  perf-dwarf (stream decode 0.40 vs plain 2.14 tok/s).
  fast_range IS the prefill furnace (QS-1.2 stands); the
  decode problem is inside the GEMV path + dispatch, not
  routing. QS-1.1 is therefore executed as: prove the route
  (done, above), then attack the GEMV path's own costs.

### Finding 2 — fast_range already dequant-once + width-16 (A-042)
_gemm_q8_0_fast_range decodes each output row ONCE per call
into an F32 scratch (width-16 loads) and reuses it across all
batch rows. Remaining defects, in expected-impact order:
 (a) the dot does sum += (a*w).reduce_add() per 16-wide chunk
     — a horizontal reduction per 16 MACs per row. Fix:
     vector-accumulate (acc += a*w) with ONE final reduce per
     (output,row), plus 4-row register blocking so each
     scratch vector is loaded once per 4 A rows.
 (b) pthread spawn per par_for call (thread_par.c uses
     pthread_create per chunk, no pool): prefill pays it
     ~450x per chunk; decode pays it ~450x per TOKEN.
 (c) weights re-dequantized per chunk (cap 256): at 256 rows
     dequant is ~1/256 of dot work — negligible; NOT a fix
     target. Honest dead end, recorded.

### Finding 3 — GEMV path costs (decode, QS-1.1's real targets)
 (a) Single SIMD accumulator per output: acc += lo; acc += hi
     is one dependent FMA chain over 320 blocks (K=5120).
     Split into 2 independent accumulators (even/odd blocks),
     summed at the end — same lane-grouped fast-path class.
 (b) par_for spawn churn: ~450 GEMM calls/token, each
     spawning up to 24 pthreads (default threads = 32-8 = 24,
     A-041 choke-guard). A-041 proved spawn overhead destroys
     small dispatches; at 27B shapes each dispatch is large
     but 450 joins/token still cost real ms. Candidate fix
     (QS-1.3): persistent worker pool in thread_par.c behind
     the same aesir_par_for signature.
 (c) A-041 scaling law (GEMV 45M MAC fixture): curve flat
     after 16 threads; 24 = ~90% of 32-thread peak. Default
     24 already sits at the measured knee; QS-1.3 re-measures
     at real 27B shapes (8/16/24/28/32) before changing it.

## Plan (slices as commissioned)
- QS-1.1 GEMV split-accumulator + route proof; micro-bench
  (bench_qs1_gemm) + real-file grade (198-record standard,
  grade_qwen35_oracle_q35_3b vs q35-3b-comp.csv) + gen bench.
- QS-1.2 fast_range vector-accumulate + 4-row blocking;
  same grade + prefill bench (batch mode / forward_batch
  timing at 435/1743-token class prompts in-process).
- QS-1.3 threading as measured: pool if spawn cost proves
  out in the micro-bench; thread-count default from the
  real-shape sweep; dead ends recorded.

## QS-1 MICRO-BENCH (bench_qs1_gemm, synthetic packed weights,
## real shapes, production gemm_q8_0 dispatch, median of reps;
## QS-3 single-core quantize running throughout — noted as a
## contention source; checksums = output sums, rounding class)

BASELINE (pristine bad65106 kernels + spawn shim), threads=24:
 QS1SPAWN par_for no-op dispatch: 210-310 us per call
 GEMV rows=1: FFN 5120x17408 0.763-0.794 ms | QKV 5120x10240
 0.509-0.540 | GATE 5120x6144 0.421-0.422 | OUT 6144x5120 0.416-0.446
 FAST rows=32 FFN 17.864 ms | rows=256 FFN 132.737 | rows=256
 QKV 80.611
 Per-token GEMM estimate from these cells: ~272 ms/token;
 serve decode 2.14 tok/s = 467 ms/token (QS-0) — the ~195 ms
 gap is spawn churn (~450 calls x ~0.21 ms = ~95 ms) +
 delta recurrence + attention + norms + sampling.

QS-1.1 GEMV split-accumulator (2 accumulators, 2-block unroll):
 FFN 0.683 (-14%) | QKV 0.457 (-15%) | GATE 0.355 (-16%) |
 OUT 0.351 (-21%). Checksums agree to ~1e-4 rel (f16 class).

QS-1.2 fast_range vector-accumulate + 4-row blocking:
 rows=32 FFN 17.864 -> 6.939 ms (2.57x) | rows=256 FFN
 132.737 -> 57.245 (2.32x) | rows=256 QKV 80.611 -> 38.861
 (2.07x). GEMM-only prefill ceiling at rows=256 efficiency
 ~398 GMAC/s vs 172 baseline.

QS-1.3 persistent pool (thread_par.c, same aesir_par_for
contract; chunk 0 on caller; spawn-failure chunks fall to
caller; pool failure degrades to the original spawn body;
dispatches serialized; nested call from a worker runs serial):
 QS1SPAWN 210-310 us -> 40 us (first sweep), 16.7 us in the
 thread sweep at 24. GEMV with pool: QKV 0.457 -> 0.185 |
 GATE 0.355 -> 0.111 | OUT 0.351 -> 0.164 | FFN 0.683 -> 0.639.
 Prefill rows=256 QKV 38.861 -> 34.207; FFN 256 flat (57.2,
 compute-bound). Checksums BIT-IDENTICAL to pre-pool patched
 run on every cell (pool changes no arithmetic).
 Thread sweep (GEMV, pooled, median ms) 8/16/24/28/32:
 FFN 0.845/0.788/0.751/1.278*/0.649 (*contention outlier),
 QKV 0.362/0.285/0.183/0.302/0.276, GATE 0.207/0.178/0.187/
 0.142/0.175, OUT 0.343/0.150/0.186/0.174/0.211. No rung
 dominates; 24 (the A-041 choke-guard default, 8 logical
 CPUs = 4 physical cores left for the desktop) stays the
 default. DECISION: thread default unchanged; the pool is
 QS-1.3's landed change.

UNIT GUARD: driver_qs1_parity — A-042 dyadic case, patched
fast_range == patched gemv_range == serial _gemm_q8_0_range
BITWISE: PASS.

PENDING (needs HEAVY.lock + load1<1.5): real-file grade
(198-record standard vs q35-3b-comp.csv, driver grade_qs1),
batch-mode cross-checks, gen timing pair, fenced serve bench
on :18436 (qs1_bench.py against my own build), thread sweep
re-take in the quiet window.

## QS-1 HEAVY WINDOW (2026-11-15 01:28-02:05 EST, lock held by QS-1)
Gate conditions at claim: up 5:28, load1 1.46, MemAvailable
122 GB. QS-2 ran a HIP grade at 01:45 WITHOUT the lock and
QS-sample built concurrently — contamination noted per leg.

### GRADE (grade_qs1, 198-record standard vs q35-3b-comp.csv)
198/198 IN BAND (rank_comp <= 2 AND gap < 1.0), 197 rank-1.
The single non-rank-1 record is the same one Q35-3b v2 had:
p5 pos32 rank 2 gap 0.015. VERDICT: FAITHFUL — the patched
kernels + pool reproduce the banked v2 profile exactly.
Batch cross-checks (batched vs per-token, same process):
p0 next-token agree (11751), final-logits max_abs_diff
0.0117; p3 agree (271), diff 0.03125 — the Q35-3 f16-ulp
class. Gen pair (load differenced): (11.09-4.82)/16 =
2.55 tok/s in-process decode at ctx ~25, 24 threads.
Thread scaling of decode (gen pair differenced): T=1 0.68,
T=8 1.73, T=24 2.55 tok/s.

### FORWARD ISOLATION (bench_qs1_forward, real file, 450 tok)
PREFILL_BATCH_CAP = 256 (batched path confirmed live).
Per-token prefill 2.44 tok/s (409 ms/tok); BATCHED prefill
5.96 tok/s (168 ms/tok), same next token (271); decode 16
steps after batched prefill 2.24 tok/s at ctx ~466.
GEMM share of batched prefill from micro-bench ~= 65 ms/tok
=> ~100 ms/tok of the batched path is NON-GEMM serial work
(conv1d + delta recurrence per row, per-row attention,
norms, embeds). NAMED NEXT CAUSE for prefill (QS-1.4
candidate): SIMD the delta recurrence + conv in
forward_batched/forward — per-element i-ascending order can
be preserved while vectorizing over the state width, i.e.
bit-identical f32 state math.

### FENCED SERVE BENCH (my build, :18436, ctx 4096, qs1_bench.py)
vs QS-0 live-gate baseline (same harness/prompts):
 p500: prompt >= 3.80 tok/s (base 3.73), decode stream 1.52
 (base stream 0.40 was perf-taxed, not comparable), decode
 plain 1.84 (base 2.14 — this leg overlapped my own 35 s
 mojo build; contaminated, flagged, not hidden).
 p2000: prompt >= 4.41 (base 3.88, +14%), decode stream
 2.30 (base 1.83, +26%), decode plain NOT MEASURED (plain
 wall 392.2 s < stream TTFT 395.3 s breaks the harness
 formula; reported as the artifact it is).
Serve gains are real but smaller than in-process gains:
the session/serve layer + first-request effects + the
non-GEMM serial share bound them. Decode does NOT yet beat
Ollama Q8_0 7.65 tok/s — coordinator report carries the
measured numbers, not a claim. Next named causes, in order:
(1) delta-recurrence/conv serial sections (~100 ms/tok of
prefill; a large share of decode's non-GEMM ~200 ms/tok),
(2) int8-dot (VNNI) GEMV — the only known road from the F32
dequant class (~140-300 GB/s effective) to Ollama's
~218 GB/s class, (3) serve-layer per-token overhead audit
(in-process 2.55 vs serve-stream 2.30 at best).
Bugs found+fixed in scope: bench key charset (base64 key
rejected by the serve validator -> alphanumeric key), stale
failed transient unit blocking the qs1-serve name
(reset-failed), qs1_bench p2000 plain-decode formula
artifact (named, not fixed — QS-0 harness semantics kept
for comparability). One bench key value reached the
qs1-bench unit journal via set -x during the failed start;
the key was rotated before the successful run and the key
file is never committed.

## QS-1.4 — delta-recurrence SIMD (forward(), decode path)
Width-16 SIMD over the state width j for the four recurrence
loops (decay / mem / rank-1 update / readout), per-element
ascending-i order preserved; scalar body kept as fallback
for d_state % 16 != 0. forward_batched carries a DIFFERENT
recurrence copy (not identical text) and is NOT touched by
this slice — its vectorization is the named follow-on.
Evidence:
- GRADE: re-run CSVs BYTE-IDENTICAL to the QS-1.1-1.3 run
  (git status clean on all six) — 198/198 FAITHFUL, and the
  f32 state math is bit-identical in practice.
- Gen pair x3 runs: 0.334 s/tok = 3.00 tok/s decode
  (pre-1.4: 0.392 / 2.55). Stable across repetitions.
- Forward driver run 2: batched prefill 6.13 tok/s (was
  5.96), decode-16 at ctx ~466 flat (2.25 vs 2.24),
  per-token prefill 2.21 vs 2.44 in run 1 (unexplained;
  thermal/codegen hypotheses named, not resolved).
- SERVE BENCH RUN 2 (QS-1.4 build, :18436, QS-0 harness):
  p500 prompt >= 6.04 (run 1: 3.80; QS-0 base 3.73),
  decode_plain 2.43 (base 2.14), decode_stream 1.26
  (outlier; inverts across runs — environment-dominated);
  p2000 prompt >= 5.29 (base 3.88), decode_stream 2.28
  (run 1: 2.30; base 1.83), decode_plain 0.97 (formula
  artifact class as run 1 — plain wall includes its own
  slower prefill; not a decode read).
  Run 1's flat p500 TTFT (114.5 s) did not reproduce: with
  the recurrence still scalar in forward_batched, the
  run-2 TTFT improvement is attributed to run 1's
  first-request/cold-serve effects + transient contention
  (recorded in run 1's entry), NOT to QS-1.4. The serve
  prompt rate now matches the in-process batched rate
  (5.96-6.13) at p500 and sits 12% under it at p2000.
FINAL QS-1 SERVE VERDICT (same harness, QS-0 -> QS-1.4):
 prompt p500 3.73 -> 6.04 tok/s (+62%); p2000 3.88 -> 5.29
 (+36%). Decode: 1.83 -> 2.28-2.30 stream at p2000 (+25%);
 plain cross-check 2.14 -> 2.43 (+14%); in-process 3.00.
 Ollama Q8_0 gen 7.65 tok/s: NOT beaten. Remaining named
 causes: (1) forward_batched recurrence/conv SIMD (the
 QS-1.4 pattern applied to the batched copy), (2) VNNI
 int8-dot GEMV/GEMM (the Ollama-class road), (3) serve
 stream-path variance audit (stream reads invert across
 runs under live gate/Voxta sharing of memory bandwidth).
