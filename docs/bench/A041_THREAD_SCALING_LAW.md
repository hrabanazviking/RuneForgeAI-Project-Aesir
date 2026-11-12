# A-041 -- Thread scaling law (Z13, purpleraider)

Slice A-041, team-09, branch yrsa/aesir-team-09, base 56d5606f
(A-039 banked, 39 of 216). Wave 5. Roadmap: "Decode scaling
1->32 threads measured; the choke-guard default (leave headroom
for the machine's other work) chosen from the curve. Acceptance:
scaling table filed; default thread policy implemented + tested."
This slice also carries the A-037 census row C-008 fix (the
census doc names A-041 as C-008's home): thread/env config is no
longer re-read per dispatch.

## Fixture and method
- Bench: aesir_engine/tests/bench_thread_scaling_a041.mojo.
  One process per rung; the runner varies AESIR_THREADS per
  process, so every rung exercises the production dispatch path
  (core.parallel.par_for -> thread_par.c shim) end to end.
  Median of 3 trials per rung (2 for the production rows).
- DECODE: the A-037 census fixture stories260K.F16.gguf, sha256
  57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3
  (verified in-worktree), driven exactly like A-037/A-030:
  8-token canonical prefill + 32 greedy decode per rep through
  forward_pass, KV arena recycled per rep, every rep oracle-exact
  vs the pinned llama.cpp token IDs (raw-oracle discipline, CPU
  vs CPU). 25 reps per run in the sweep. These rows run with
  AESIR_PAR_MIN_WORK=1 so the small model's dispatches actually
  engage the thread layer; with the production threshold they
  stay serial (see the PROD rows), which is itself part of the
  law below.
- GEMV: the engaged regime -- one f32 matvec K=4096 x N=11008
  (45,088,768 MACs, above the production engagement threshold of
  2^20), partitioned by output columns via par_for, the GEMM
  kernels' own partition contract. Median of 25 timed reps per
  run. Checksum accumulated serially in the serial order; it was
  1113.8164 at every rung of every run, before and after the
  fix -- threaded results are identical to serial.
- Machine: purpleraider (AMD Ryzen AI Max+ 395, 16 cores / 32
  logical CPUs, SMT pairs (n, n+16), 2 L3 domains). CPU execution
  only; gfx1151 is the compile target, no accelerator execution
  is claimed. Evidence: hidden_files/a041_sweep_before.log and
  hidden_files/a041_sweep_after.log (identical protocol run on
  the pre-fix and post-fix code; the two curves agree in shape
  at every rung, which is the sweep's stability check).

## Scaling table (post-fix code, medians)

GEMV dispatch (engaged regime):

| Threads | Median ms | Speedup | Efficiency |
|---|---|---|---|
| 1 | 69.952 | 1.00x | 100.0% |
| 2 | 37.394 | 1.87x | 93.5% |
| 4 | 20.398 | 3.43x | 85.7% |
| 6 | 15.060 | 4.64x | 77.4% |
| 8 | 12.493 | 5.60x | 70.0% |
| 12 | 8.945 | 7.82x | 65.2% |
| 16 | 7.286 | 9.60x | 60.0% |
| 20 | 7.915 | 8.84x | 44.2% |
| 24 | 7.102 | 9.85x | 41.0% |
| 28 | 6.311 | 11.08x | 39.6% |
| 32 | 6.433 | 10.87x | 34.0% |
| default (=24) | 7.204 | 9.71x | -- |

(The 20-thread median sits above the 16-thread one in both the
before and after sweeps -- a reproducible plateau wobble in the
16-24 band, not a monotone step; the band as a whole is flat.)

Decode, threads forced to engage (AESIR_PAR_MIN_WORK=1),
aggregate tok/s (32 decode tokens counted per rep; the span
also contains the 8-token prefill and arena reset):

| Threads | tok/s | vs serial |
|---|---|---|
| 1 | 16028.4 | 1.00x |
| 2 | 1398.5 | 0.087x |
| 4 | 758.5 | 0.047x |
| 6 | 442.6 | 0.028x |
| 8 | 308.8 | 0.019x |
| 12 | 185.5 | 0.012x |
| 16 | 133.8 | 0.008x |
| 24 | 85.5 | 0.005x |
| 32 | 62.8 | 0.004x |

Decode, production threshold (AESIR_PAR_MIN_WORK unset):
default (24 threads) 16050.8 tok/s; explicit 32 threads
16078.6 tok/s -- statistically the serial rate, because this
fixture's per-dispatch work is below the engagement threshold
and the thread count is never paid for.

## The law
1. Engaged dispatches scale, with a knee. A 45M-MAC GEMV speeds
   up near-linearly to 8 threads, reaches 9.60x at 16 (60%
   efficiency), and then flattens: the whole 16-32 band buys at
   most ~15% more speed while efficiency falls to ~34%. Past 16
   threads the workload is increasingly memory/SMT-bound (the
   second SMT sibling adds little on this part).
2. Small dispatches must never thread. Forcing this fixture's
   sub-threshold decode dispatches onto threads is catastrophic
   at EVERY count >= 2 (11x slower at 2, ~250x slower at 32):
   the shim spawns fresh POSIX threads per par_for call, and a
   decode step issues hundreds of small dispatches. The
   engagement threshold (AESIR_PAR_MIN_WORK, default 2^20 MACs)
   is therefore not a tuning nicety -- it is the guard that
   keeps decode serial where serial is fastest, and production
   decode rate is independent of the thread count (PROD rows).
3. Choke-guard default = 24 on this machine. The default only
   governs dispatches big enough to engage, so it is chosen
   from the GEMV curve: 24 threads deliver ~90% of the 32-thread
   peak (7.10 ms vs 6.43 ms medians) while leaving a quarter of
   the machine -- 8 logical CPUs, 4 physical cores -- for the
   machine's other work, per the roadmap's choke-guard charge.
   The implemented rule (core.parallel.par_default_threads):
   all CPUs on a 1-2 CPU machine; otherwise CPUs minus a
   quarter (at least 1 reserved), capped at 32. An explicit
   AESIR_THREADS always wins over the default, exactly as
   before. Implemented in core/parallel.mojo
   (par_default_threads + par_resolve_threads) and pinned by
   tests/test_thread_scaling.mojo (cpu.thread_scaling_*).

## C-008 fix (A-037 census row, 12.81% of decode cycles)
Before this slice, every par_for dispatch re-read the thread
config through syscalls: aesir_par_cpu_count ran sysconf ->
__get_nprocs -> sysfs opens (kernel subtotal 9.42% of cycles)
and core::parallel::_env_int re-parsed getenv values (user
subtotal 3.39%). Now thread_par.c caches all of it for the
process lifetime: sysconf runs once, and AESIR_THREADS /
AESIR_PAR_MIN_WORK are parsed once into a snapshot served by
aesir_par_threads_env / aesir_par_min_work_env. The parse in the
shim replicates _env_int's semantics exactly (digits only;
unset/empty/non-digit -> 0; the >100000000 early return kept).
_env_int itself is unchanged for its remaining one-shot callers
(AESIR_VNNI, AESIR_PREFILL_BATCH -- neither is per-dispatch).
The one contract that could have broken -- in-process knob
changes (J-039 thread trials) -- is preserved explicitly:
thread_topology's set_thread_knobs / clear_thread_knobs now call
par_refresh_config() after every setenv/unsetenv, and the
readback tests pass against the cached layer.

Proof, three ways:
- Counters: the shim counts real sysconf probes and env parses.
  Tests assert probes stay at 1 and env reads do not grow across
  1000 getter calls, and that a raw setenv without refresh
  changes nothing while par_refresh_config() serves the new
  value immediately after.
- Profile: the A-037 census was re-run with its own unmodified
  driver and method (perf record -F 997 -g, 1200 reps,
  oracle-exact, A041_BENCH run 16078.0 tok/s) on the fixed code
  (hidden_files/a041_perf_report_nochildren.txt, sha256
  85ea62cb5209e2a64175c597d502354fdb503e40018f9f6050e8a135fd3f7b61;
  perf.data sha256
  5d62dd262ac196265b9369a60c9d782fb8874ba3b786b3ce6312f325e6a038b2).
  Every C-008 member symbol of the A-037 table --
  kernfs_iop_permission, kernfs_dop_revalidate, sysfs_kf_seq_show,
  kernfs_fop_open, link_path_walk, __read_nocancel,
  read_sysfs_file, _env_int, getenv, __strtoull -- is absent from
  the new report; the only config symbol left is
  aesir_par_cpu_count itself at 0.08% self-time (the cached
  getter's own frame). Grouped C-008 share: 12.81% -> ~0.08%.
  Absolute rates are NOT compared across the two profile
  windows (machine boost/load state differed; shares are the
  census method's own currency).
- No behavior change elsewhere: the before/after sweeps above
  ran the identical bench on both code states; GEMV checksums
  and decode oracle IDs were identical at every rung.

Verdict: A041_SCALING: PASS -- scaling table filed from
on-device logs, choke-guard default implemented + tested,
C-008 closed.
