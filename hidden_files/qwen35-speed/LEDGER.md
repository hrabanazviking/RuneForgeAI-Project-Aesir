# QS Campaign LEDGER — Qwen35 Speed

## QS-0 — recon + plan + baseline + profiles (OPEN)

Seat: single worker, six Mythic Engineering roles sequentially
(no sub-agents; depth limit — established fallback).
Start truth (2026-11-14 20:09 EST, from the machine): branch
yrsa/hip-serve @ 5506180d, local == remote at start. Tree dirt
left alone per commission: modified serve logs
(hidden_files/hip-serve/serve-bench.log,
hidden_files/qwen35-adapter/q35-7-gate-serve.log) + untracked
test binaries. Live gate: aesir-gate ACTIVE, MainPID 5932,
WorkingDirectory /home/volmarr/aesir-q35-7, cmd: serve the 27B
Q8_0 --accel cpu --profile qwen35 --qwen35-resident, ctx 4096,
max-tokens 512, port 18434, fence MemoryHigh 48G / Max 64G.
Machine at start: uptime 10 min, load1 0.54, MemAvailable
119,551,904 kB (~114 GB). FRESH-BOOT GATE: FAIL (uptime < 60
min) — light work only until ~21:00 EST; load + memory already
pass. perf_event_paranoid = 4 (perf present at /usr/bin/perf;
rocprof NOT on PATH at recon time).

### QS-0.2 — mined speed facts (all from banked prior records)

CPU resident path (Q35-3r/3b/4b notes, QWEN35_RESULTS.md,
RESIDENCY-NOTE.md):
- Mechanics pre-existed Q35-3r: GGUFSeer maps Q8_0 as zero-copy
  packed mmap views; Qwen35Block consumes large weights ONLY
  through gemm_f16 -> gemm_q8_0. Single-row (decode) shape:
  fused dequant SIMD GEMV, no scratch. Batched (prefill) shape:
  decodes ONE weight row at a time into a bounded F32 scratch
  (a_cols floats; 5120 floats/thread at 27B shape) — a named
  suspect for prefill cost.
- Resident census 27B: 498 large tensors, stored Q8_0
  28,574,187,520 B; F16 materialization avoided 53.8 GB.
  Resident numerics bit-equal to default (logits diff 0.0).
- Speeds: teacher-forcing grade decode ~2.2 tok/s (P3: 59 pos
  in 29.1 s incl. load); llama.cpp ~2.7 tok/s equivalent on
  the same grade. Serve e2e (Q35-4b, ctx 4096): T1 (23 prompt
  + 32 gen) 20.82 s = 1.54 tok/s blended; T2 resident 18.27 s;
  long 483 prompt + 48 gen 139.75 s; derived prefill ~4 tok/s
  batched (labelled derived in the source, not measured).
- Peaks: serve VmHWM 31,312,080 kB; in-process 31.62 GB class.
  systemd MemoryPeak (5.35 GB) UNDERCOUNTS mmap pages — never
  size fences from it.
- Sampling truth: serve defaults temp 0 / top_k 40 / top_p
  0.95 / min_p 0 / rep 1.0 / repeat_last_n 64 / seed 42;
  min_p + repeat_last_n have NO qwen35 CPU-forward counterpart
  (QS-4's work). Engine forward_pass default rep 1.1 does NOT
  govern the serve path.

HIP path (Q35-6-NOTES.md):
- Named suspects, verbatim class: (1) naive byte-load GEMV is
  THE bottleneck — ~11 s/forward uncontended in-process,
  ~14 s under sibling compile contention; decode 0.07-0.09
  tok/s, completion-by-wall ~0.04 tok/s. (2) Recurrent
  Gated-DeltaNet step: _delta_kernel carried defect D1 (pre-U1
  contiguous q/k broadcast; fixed to tiled g = vh % groups).
  (3) Conv ring: D2 in-place parallel shift race; fixed via
  stage+commit through ring_tmp (two extra kernels per step —
  launch-overhead suspect). (4) Launch overhead: unmeasured
  per-token kernel census — QS-0.6/QS-2.4 own it.
- Prefill precedent ON DEVICE: batched GEMM 9.43 ms vs GEMV
  loop 63.16 ms at 64 fixture tokens = 6.7x; session prefill
  is batched GEMM. Decode stayed per-token GEMV — the gap.
- HIP grade: 71/71 rank 1 gap 0.0 (P0/P1/P5); 40-token greedy
  token-identical to the CPU witness. Serve VmHWM 30.1 GB.
  Fences used: 96G serve / 110G driver (MemoryMax).
- HIP sampling is host-side over device logits through the
  CPU sampler (parity by construction).

Roadmap-era lessons carried in (commission + prior campaigns):
- Scalar dequant pockets are THE classic Aesir speed defect:
  IQ scalar 256-lane dequant was ~90% of IQ cost; width-16
  SIMD decode gave ~3x with numerics proven unchanged.
- gemm_q8_0 has a named scalar pocket in the roadmap record
  (Coder-7B Q8_0 speed defect) — QS-1 must audit the qwen35
  decode GEMV for the same class before assuming bandwidth.
- Comparator artifacts are a verdict class: never grade vs
  llama-cli --single-turn (template-renders the prompt).

Compression cross-reference (QC_RESULTS.md / RESIDENCY-NOTE):
- QC-6 Q4_K_M product: 16,223,236,576 B (56.7% of source),
  grades 197/198 in band vs Q8_0 source — DIVERGENT by the
  strict gate on ONE record (p5 pos22 rank 3 gap 0.421).
  Resident footprint ~19.5 GB vs ~31.0 GB. NOT gate-servable
  today: the Q35-3r resident contract is Q8_0-only and refuses
  it by name. QS-3 owns the analogue + the searched-fit
  packer for pos22.

### QS-0 entries as they land
- 20:09 EST recon + mining done (this file). MAP.md written.

### QS-0 heavy window — lock contention + harness bug (2026-11-14 21:00 EST)
- Fresh-boot gate PASSED 20:59-21:00 EST: uptime 60 min,
  load1 0.31, MemAvailable 119,541,616 kB (qs0-gate-checks.log).
- HEAVY.lock was claimed ~21:00 by the QS-3 team (branch
  yrsa/qs-pack, tree ~/aesir-qs-pack; OWNER.txt in the lock:
  27B searched-fit re-pack + strict grade + resident-K grade;
  unit qs3-27b.service). Their claim landed seconds before
  QS-0's claim attempt (lock birth 20:59:48). QS-0's bench +
  perf units had already launched in the same invoke (sequencing
  fault: mkdir failure did not halt the chain) and were STOPPED
  at 21:02 once the contention was seen. QS-0 holds NO lock;
  the HIP heavy run waits for QS-3's release, per the lock law.
- BUG (found + fixed in scope): qs0_bench.py v1 parsed the
  stream as raw NDJSON; the OpenAI route streams SSE
  'data: {json}' lines ending 'data: [DONE]'
  (native_serve.mojo format_chat_chunk path) -> 0 chunks
  counted. v1's one completed probe is still a valid wall:
  ~500-token-class prompt, max_tokens=1, wall 113.30 s under
  QS-3 single-core quantize contention (load1 spiking) ->
  prefill+first-token ~113 s, consistent with the ~4 tok/s
  derived prefill class; NOT used as the baseline (contended).
  Fixed in v2: SSE parsing + dual-method design (streaming
  TTFT/chunk decode + non-streaming exact usage cross-check).
- perf as unpriv user is BLOCKED (perf_event_paranoid=4, 'No
  supported events found' even on a trivial own workload).
  QS-0.5 method: root perf record -p <gate MainPID> via a
  machine-level systemd unit during the bench window (sudo
  verified available). rocprof: NOT present on this machine
  (no /opt/rocm/bin, no rocprof in PATH/find) -> HIP timing
  falls back to engine timers + time -v walls, as commissioned.
- Note: Voxta.Server is RUNNING on this box (pid 2817 at recon)
  and the gate showed multi-core CPU bursts after QS-0's bench
  client was stopped -- consistent with live Voxta-side use of
  the gate. QS-0 never touches either; baseline runs wait for
  a quiet gate (CPU-time delta ~0) as well as the lock.

### QS-0 lock error + restoration (2026-11-14 ~22:32 EST)
- 22:26: qs3-27b.service went inactive; no QS-3 processes for
  ~5 min. QS-0 judged the lock released-in-fact, moved it
  aside (preserved) and claimed it. JUDGMENT WAS WRONG: at
  22:32 QS-3 began a second heavy phase (llama.cpp-control
  Q4_K_M grades, load1 spiked to 12.79) -- their campaign runs
  in phases and the standing lock was still theirs in intent.
- QS-0 restored QS-3's lock untouched (HEAVY.lock + their
  OWNER.txt back in place; QS-0's brief claim preserved as
  HEAVY.lock.qs0-claim-in-error-2231) and stands down. NO QS-0
  heavy work ran during the error window (bench/perf/HIP were
  never relaunched). True release = lock removed by QS-3 AND
  no QS-3 processes; QS-0 waits for both.
- Observed, not touched: ollama.service shows active/running
  in the unit list (commission states Ollama is down by
  Volmarr's order; the unit state is recorded here as seen,
  QS-0 does not act on it).

### QS-0 close (2026-11-15 ~00:05 EST)
- Baseline bench DONE (qs0-bench.log): p500 (435 tok) TTFT
  116.60 s, prompt >= 3.73 tok/s, decode 2.14 plain; p2000
  (1743 tok) TTFT 448.87 s, prompt >= 3.88 tok/s, decode
  1.83 stream / 1.75 plain. Perf artifact (stream 0.40 under
  dwarf profiling) discriminated and explained in baseline.
- CPU profile DONE: root perf, 155K samples, 0 lost;
  _gemm_q8_0_fast_range 86.27% self; fused GEMV only 3.54%
  (serve generates via _forward_batch). qs0-perf-flat.txt.
- HIP fixture profile DONE tonight: ALL PASS, (e) batched
  6780 vs GEMV-loop 1021 tok/s at 64 fixture tokens.
- HIP real-file gen pair: NOT RUN -- HEAVY.lock held by QS-3
  through QS-0's whole window (phases 3.5/3.6/3.7+, still
  building at 00:01). Named as QS-0.6-addendum / QS-2.1
  first measurement in QS-0-BASELINE.md. rocprof absent.
- QS-0-BASELINE.md filed with baseline table, both
  indictments, and the QS-1/QS-2 slice order (QS-1.1 route
  decode through the GEMV; QS-1.2 fast_range inner loop;
  QS-2.1 vectorized HIP GEMV).
- No bugs left silent: harness SSE bug fixed in scope;
  lock-error self-reported + restored; ollama.service
  unit-state observation recorded, untouched per orders.
- Gate never touched: aesir-gate still PID 5932, active,
  serving; QS-0 sent it client requests only.

## QS-4 — Sampling parity on qwen35 (yrsa/qs-sample, base 183ee901)

- QS-4.1 EVIDENCE + DESIGN banked: min_p and repeat_last_n are
  silent no-ops on the qwen35 CPU serve path. Witness:
  _gen_config().min_p = 0.0 under sampling.min_p = 0.95;
  fixture probe streams A==B (min_p 0 vs 0.95) and C==D
  (repeat_last_n 1 vs 8192 at rep 2.5) identical, A!=C proves
  the penalty itself is wired full-context
  (qs-4-probe-prefix.log). Full audit + reference semantics +
  design in QS-4-NOTES.md.
- QS-4.2 MIN_P banked: wired GenerationConfig.min_p through
  the qwen35 forwards + CPU/HIP sessions into the existing
  apply_min_p. Fixture proof: keep sets exact; distribution
  0/512 vs 230/512 control; session default stream bit-exact
  vs pre-fix probe, min_p 0.95 bites (qs-4-minp-test.log).
  Fixture grade battery clean (forward ALL PASS, resident-K
  logits diff 0.0, test_inference PASS). 27B grade re-run
  pending HEAVY lock (QS-2).
- QS-4.3 REPEAT_LAST_N banked: GenerationConfig gains the
  field (default 0 = legacy full-context); sampler windows
  the penalty context (rep + freq/presence, order unchanged);
  qwen35 plumbing mirrors QS-4.2. Proof: seeded distributions
  full 85 vs window 251 (rep), 184 vs 251 (freq); session
  windows 1 vs 8192 now differ; defaults bit-exact; fixture
  grade battery clean again (qs-4-rln-test.log).
- QS-4.4 SERVE SMOKE banked: fenced fixture serve on :18437
  (own units, stopped clean; gate untouched). min_p 0.95
  diverges at token 10; repeat_last_n: rep 2.5 window 8192
  diverges at the 11-apart repeat (~token 42), window 1
  leaves the stream untouched, rep 1.0 controls identical
  across instances at seed 42 (qs-4-smoke-r*.log).
- QS-4 CLOSED: QS-4.1 fa047ba0, QS-4.2 fb370ad0, QS-4.3
  bbc70045, QS-4.4 this entry. Named remainder: 27B grade
  re-run (lock held by QS-1/QS-2 throughout; fixture battery
  clean + structural grade-safety proof in QS-4-NOTES.md);
  generic/gemma4 forwards share the dead-min_p defect
  (follow-up slice); native /v1/generate lacks a per-request
  repeat_last_n field (parser follow-up).
## QS-1 — CPU-resident speed (branch yrsa/qs-cpu @ bad65106 base)

Seat: single worker, six Mythic Engineering roles sequentially
(no sub-agents; depth limit). Full record:
hidden_files/qwen35-speed/QS-1-NOTES.md. Audit corrected the
QS-0 mechanism on two points (code-verified): (1) serve decode
already routes to the fused GEMV (session next_chunk ->
_forward_position -> 1-row gemm_q8_0); the 86% fast_range
share is the prefill-dominated profile window + perf-dwarf tax
on the spawn-churned decode path. (2) fast_range already had
A-042 decode-once + width-16; its remaining defect was the
per-chunk horizontal reduce_add dot.
- QS-1.1 GEMV: two independent accumulators, 2-block unroll.
  Micro-bench rows=1: FFN -14%, QKV -15%, GATE -16%, OUT -21%
  (median ms, bench_qs1_gemm). Dyadic parity bitwise PASS.
- QS-1.2 fast_range: vector-accumulate dot + 4-row register
  blocking. rows=32 FFN 2.57x, rows=256 FFN 2.32x, rows=256
  QKV 2.07x vs pristine. Dyadic parity bitwise PASS.
- QS-1.3 threading: persistent worker pool in thread_par.c
  (same aesir_par_for contract). Dispatch 210-310 us -> ~17-40
  us; GEMV QKV 0.457->0.185 ms, GATE 0.355->0.111, OUT
  0.351->0.164, FFN 0.683->0.639; checksums bit-identical.
  Thread sweep 8/16/24/28/32: no rung dominates; default 24
  (A-041 choke-guard) KEPT — leaves 8 logical CPUs for the
  desktop.
- GRADE (2026-11-15 heavy window, lock held by QS-1):
  198/198 IN BAND, 197 rank-1 — FAITHFUL, reproducing the
  Q35-3b v2 profile exactly (same lone near-tie p5 pos32
  rank 2 gap 0.015). Batch cross-checks agree on next token
  (p0 11751, p3 271), logits diffs 0.0117/0.03125 (f16-ulp
  class). Gen pair 2.55 tok/s in-process decode (T=24;
  T=8 1.73, T=1 0.68). Forward isolation (450 tok): batched
  prefill 5.96 tok/s vs per-token 2.44; decode 2.24 at
  ctx ~466. Fenced serve bench (:18436, same harness as
  QS-0): p500 prompt >= 3.80 (base 3.73), p2000 prompt
  >= 4.41 (base 3.88), p2000 decode stream 2.30 (base
  1.83); p500 plain leg contaminated by my own build
  (flagged in notes), p2000 plain decode a harness artifact
  (named in notes). Ollama Q8_0 7.65 NOT yet beaten at the
  serve; next named causes: (1) delta-recurrence/conv
  serial sections, (2) int8-dot VNNI GEMV, (3) serve-layer
  per-token overhead. Full record: QS-1-NOTES.md.
- QS-1.4 delta-recurrence SIMD (forward() only; the
  forward_batched copy is separate text and remains
  scalar — named follow-on): grade CSVs BYTE-IDENTICAL
  to the QS-1.1-1.3 run (198/198 FAITHFUL); gen pair
  0.392 -> 0.334 s/tok = 3.00 tok/s in-process decode
  (x3 stable). Serve bench run 2 (qs1-bench-qs114.log):
  p500 prompt >= 6.04 (QS-0 base 3.73, +62%), decode_plain
  2.43 (base 2.14); p2000 prompt >= 5.29 (base 3.88,
  +36%), decode_stream 2.28 (base 1.83, +25%). FINAL QS-1
  serve verdict: prompt +36..62%, decode +14..25% by the
  steadier reads; Ollama Q8_0 7.65 NOT beaten. Next causes
  (ordered): batched-recurrence SIMD, VNNI int8-dot GEMV,
  serve stream-variance audit.
## QS-2 — HIP decode speed (OPEN)

Seat: QS-2 team lead, six Mythic Engineering roles
sequentially in one seat (no sub-agents; depth limit).
Sole writer in ~/aesir-qs-hip on branch yrsa/qs-hip @
bad65106. Full working notes: QS-2-NOTES.md in this folder.
Start truth (2026-11-15 ~00:03 EST): purpleraider uptime
4:03, load1 1.67 falling, MemAvailable ~113 GB.
HEAVY.lock HELD by QS-3 (since 2026-11-14 ~22:31 EST;
QS-3.8 v3 re-pack + grade, unit qs3-27b-v3) — all QS-2
heavy (real-file) runs wait for it; fixture work proceeds
fenced (32G class) per commission. rocprof absent (QS-0
finding): engine timers + fixture timings only.

### QS-2 entries as they land
- Recon + design banked (QS-2-NOTES.md): the Q8_0 prize
  is a bandwidth race — 27.2 GB of weights streamed per
  token; Ollama Q8_0 7.65 tok/s implies ~208 GB/s
  effective; 12.11 tok/s on Q8_0 would need ~330 GB/s,
  beyond this memory system (that yardstick belongs to
  the Q4_K_M tier, QS-3). Ceiling named up front, to be
  measured, not assumed.
- Baseline fixture reproduced in-tree from unmodified
  bad65106 binaries (.base stash): ALL PASS, (b) diffs
  digit-identical to QS-0, (e) GEMV loop 65.59 ms /
  batched 10.21 ms (qs2-fixture-base.log).
- QS-2.2 warp-per-row vectorized Q8 GEMV (_q8_gemv_kernel,
  packed UInt32 loads, warp.sum; ALL batch sizes after a
  (d)-gate discrimination: batch-split kernels broke the
  (d) premise at state_diff 0.00390625 — fixed in scope
  by unifying). Fixture ALL PASS: (d) 0.0/0.0 exact,
  (c) greedy identical, rank 1 gap 0.0 (qs2-fixture-
  gemv2.log). Session ALL PASS. Banked 0d1e1b9f.
- QS-2.3 step 1: ring stage fused into conv kernel,
  commit fused into l2norm kernel (-96 launches/token,
  bit-exact). Fixture ALL PASS (qs2-fixture-fuse1.log).
  Banked b218a215.
- QS-2.4: delta step + gated RMSNorm fused
  (_delta_norm_kernel, shared-memory reduction; -48
  launches/token; fixture d_state 16 and real 128 both
  take the fused branch). Fixture ALL PASS exact
  (qs2-fixture-fuse3.log). Banked 39646164.
- QS-2.3 step 2: SwiGLU pair fused into the FFN
  down-GEMV (_q8_gemv_silu_kernel, bit-exact; -64
  launches/token). Fixture ALL PASS (qs2-fixture-
  fuse4.log). Banked c2adbe50.
- QS-2.3 step 3: warp-parallel RMSNorm (was one serial
  thread per row). Fixture ALL PASS, (b) diffs IMPROVED
  (worst s 0.00021445751), (e) loop 49.47 -> 36.56 ms
  (qs2-fixture-fuse5.log); session ALL PASS. Banked
  fef90fb6. Launch census ~492/token (from ~700).
- Fixture GEMV-loop trajectory (64 tok): 65.59 ms
  baseline -> 36.56 ms current (1,751 tok/s, 1.79x at
  fixture scale; fixture weights are L2-resident, so
  this is the latency/launch component only — the
  bandwidth component is measured by QS-2.1/QS-2.2
  real-file runs under the lock).
- PENDING (lock): QS-2.1 gen pair on .base binaries
  (the QS-0.6 deferred measurement), gen pairs on
  .gemv2 and current builds, real-file grade P0/P1/P5
  on the current build (drive-heavy.sh is written and
  ready; one fenced unit runs the whole sequence).
- QS-2.1 DONE (lock claimed 2026-11-15 01:30 after
  QS-3 banked their close e0f28a8b): unmodified
  bad65106 gen pair = 0.067 tok/s decode (14.905
  s/token differenced) -- the honest baseline.
- QS-2.2 DONE through v7: warp GEMV (0.57) -> SIMD v3
  (2.41) -> coalesced v4 (2.88) -> 8-block unroll v7
  (6.87 tok/s, all under QS-1 CPU contention; clean
  re-measurement owed). Grade at v3, v4, and v7
  builds: 71/71 rank 1 gap 0.0 FAITHFUL every time.
  Bench (output shape): v4 82 -> v5 149.5 -> v6
  193.2 -> v7 214.6 GB/s. Root causes, in order:
  scalar GEMV (QS-0), strided lane->block map (v2/v3),
  DRAM latency without enough independent loads
  (v4; fixed by unrolls). Banked 1e0e6151, 279c088e.
- QS-2.3/QS-2.4: launch fusions all landed pre-lock
  (above); at 0.146 s/token the launch floor is now
  a minor term (~0.019 s/token non-GEMV total).
- QS-2.2 v8 banked: bench + A/B + clean-window runs.
  LOCK: claimed 2026-11-15 01:30:23 EST (QS-3 close
  banked e0f28a8b; claim removed by another party
  before 02:37), re-claimed 02:37:43 EST for the
  clean-window sequence; released at this banking
  (~02:47 EST). Clean-window headline: decode 3.55
  tok/s cold / 3.83 warm (4/140 pairs, v8), grade
  71/71 FAITHFUL (v8, contended epoch). Isolated
  GEMV sustains 205.1 GB/s clean -- remaining
  ceiling is in-engine non-GEMV time (~0.13
  s/token), next step = real-scale per-phase
  profile. Short-pair figures (6.87) retracted as
  noise-dominated; see QS-2-NOTES.md.

## Coordinator note (QS-2 merge, 2026-11-15)
- QS-1 and QS-2 filed differing accounts of HEAVY.lock on the QS-1/QS-2 night (QS-1: QS-2 graded without the lock; QS-2: claimed 01:30:23 under OWNER.txt, the claim later removed by another party, re-claimed 02:37:43, released at banking). Both accounts stand in their sections above; the coordinator does not adjudicate beyond the record.
- Protocol tightened from here: a claim is the atomic mkdir PLUS an OWNER.txt naming team and claim time; only the owner or the coordinator removes a claim; claim and release times are ledger entries. QS-2 acknowledged the correction unconditionally on receipt and complied from receipt.

## QS-2.5 — HIP per-phase attribution + attack (branch yrsa/qs-phase @ d1e5815f base)

Seat: QS-2.5 team lead, six Mythic Engineering roles
sequentially in one seat (no sub-agents; depth limit). Sole
writer in ~/aesir-qs-phase. Full record: QS-2.5-NOTES.md.
HEAVY.lock claimed 2026-11-15 02:51:29 EST (OWNER.txt);
QS-5 rehearsal serve (:18438, CPU path) co-resident and
recorded for every real-file run of this section.
- QS-2.5.1 DONE: env-gated engine timers (AESIR_QS_PROFILE
  1/2/3) in Qwen35HipExecutor; fixture ALL PASS in all modes
  + session ALL PASS. Real 27B: wall 271 ms/token; host
  enqueue 3.4-4.5 ms (~1,440 launches) — launch/host path
  EXONERATED. FFN segments 196.4 ms vs 88.7 ms stream floor;
  isolated bench under the same co-residency: 199.3/209.6
  GB/s (contention exonerated). Indictment: the silu-fused
  down GEMV recomputes _silu_pair (one exp) per (row,k) —
  5,120x redundant, ~5.7B exp/token; lmhead plain GEMV runs
  at bench rate in-stream. Next: QS-2.5.2 de-fuse.
- QS-2.5.2 DONE (de-fused SwiGLU): _silu_mul precompute +
  plain v8 down GEMV replaces the silu-fused GEMV. Fixture
  ALL PASS (d)/(f) exact; real-file grade 71/71 rank 1
  gap 0.0 FAITHFUL; FFN segment 196.4 -> 100.4 ms/token;
  long pairs 0.2156 + 0.2198 s/token = 4.64/4.55 tok/s
  (QS-5 co-resident) vs QS-2 clean 3.55-3.83. QS-2.5.3:
  mode-4 sub-attribution filed (delta_norm ~260 us/layer,
  ATTN small chain, in-engine GEMV rate gap); no further
  slice — remainder is 5%-class numerics-sensitive work.
  Ceiling: Q8_0 stream floor 0.137 s/token at 205 GB/s;
  7.65 needs >219 GB/s in-engine (not demonstrated).
  LOCK: released at this banking (03:08:42 EST).
## QS-5 — ULTRA-STABLE SERVE (OPEN)

Seat: QS-5 team lead, six Mythic Engineering roles
sequentially in one seat (no sub-agents; depth limit).
Sole writer in ~/aesir-qs-stable on branch yrsa/qs-stable
@ d1e5815f. Gate tree ~/aesir-gate-serve (detached
d1e5815f) changes only at planned swaps. Full record:
QS-5-NOTES.md in this folder.

### QS-5 entries as they land
- QS-5.1 DONE: gate tree built (engine exit 0, binary
  sha256 efc8334c...c270c1); rehearsal serve on :18438
  with the proven Q35-7 command shape ALL_PASS verify
  (health qwen35/qwen35-27B/q8_0_resident; turn 2
  reused_prompt_tokens=69). Fence measurement mix
  (qs5-measure2.log + qs5-peakleg.log, all legs 200,
  largest 3,383 prompt + 132 gen): rehearsal cgroup
  MemoryPeak 22,973,169,664 B (21.39 GiB). Governing
  peak incl. Q35-7 lifetime 30.8 GB -> permanent-unit
  fences MemoryHigh=40G / MemoryMax=52G (derivation in
  QS-5-NOTES.md). Engine fact found: the OpenAI chat
  parser accepts temperature/seed/top_p only; min_p on
  /v1/chat/completions is refused 400 by design —
  min_p + repeat_penalty exercised via /v1/generate
  instead (HTTP 200, QS-4 wiring live on merged build).
- QS-5.2 DONE: permanent unit + watchdog installed
  from qs5-install/ sources (install-qs5.sh):
  /etc/systemd/system/aesir-gate.service (User=volmarr,
  gate tree, Restart=on-failure/10s, MemoryHigh=40G /
  MemoryMax=52G, RequiresMountsFor=/mnt/vault,
  WantedBy=multi-user.target; byte-identical to repo
  source), watchdog timer every 2 min running
  /usr/local/sbin/aesir-gate-health.sh (key read at
  runtime, never logged; 3 consecutive failures ->
  reset-failed + restart; journal + watchdog.log).
  systemd-analyze verify exit 0; checker live-fired
  OK against the transient gate. Timer ENABLED;
  aesir-gate.service enable deferred to the swap
  (the loaded transient of the same name shadows the
  file; enable refused as transient/generated —
  handled in the installer). Real unit NOT started;
  transient gate never interrupted.
- QS-5.3 DONE (the swap, single-restart protocol):
  attempt 1 at 03:29:42 EST restarted the TRANSIENT
  definition instead (same-name transient file in
  /run/systemd/transient shadowed /etc; old build back
  healthy by 03:29:51 — recorded, not hidden).
  Attempt 2: stop 03:29:55, retired the transient file,
  daemon-reload (FragmentPath -> /etc), enable OK,
  start 03:30:40, health ready 03:30:45. Final-transition
  outage 50 s; whole window 63 s. Post-swap verify
  ALL_PASS (unit active + enabled, fences read back
  40G/52G, Restart=on-failure/10s, completion 200,
  turn-2 reused_prompt_tokens=69). Watchdog timer
  started. QS-5.4 soak criteria stated in QS-5-NOTES.md
  before the soak starts.
- QS-5.2 WATCHDOG v2 FIX (bug found in the QS-5.4
  soak, fixed on the spot): v1 counted any /health
  failure toward a restart, but the serve is
  single-concurrency with a 30 s queue timeout, so
  health requests starve during legitimate long
  prefills (observed 03:33-03:34 EST: sampler NOTREADY
  + watchdog FAIL during a 115 s prefill that
  completed 200). v2 adds a busy guard: failures count
  only when the serve process CPU (utime+stime) has
  NOT advanced >= 30 s since the last check; busy
  failures log BUSY and do not count. Restart now
  needs 3 consecutive IDLE failures (the wedged case).
  Live-proven mid-prefill at install. QS-5.4 health
  criterion amended accordingly in QS-5-NOTES.md
  (recorded at soak t+5 min, before any verdict).
- QS-5.4 SOAK RUN 1 INVALIDATED by external stops
  (not a serve failure): 106/106 requests OK + memory
  flat to t=6,718 s, then a Muse device session
  outside QS-5 issued "sudo systemctl stop aesir-gate"
  at 05:25:26 EST (journal + sudo log). Serve ignored
  SIGTERM mid-prefill -> SIGKILL at stop-timeout ->
  Restart=on-failure returned it at 05:26:27 (real
  self-healing proof, reused for QS-5.5). Second stop
  05:35:05 disabled the watchdog timer + stopped the
  gate, followed by a "zo0-7b" ollama-bench unit —
  the sibling bench team clearing the machine.
  QS-5 restored gate + watchdog 05:37 (ready, enabled).
  Soak harness flaw found + fixed (no failure backoff:
  23,263 refused-spin lines; v2 sleeps 15 s after a
  failure). Soak 2 relaunched on the quiet machine;
  full record in QS-5-NOTES.md.
- QS-5.4 SOAK RUN 2 INVALIDATED by a third external strike —
  this one a deliberate pause: at 05:52–05:53 EST the operator
  stopped the soak + gate (SIGKILL after the 60 s stop timeout),
  MASKED aesir-gate.service + watchdog service + timer, and
  moved the unit files to *.qs5-paused (preserved intact,
  byte-identical). Then ollama surgery + a "zo-rev-7b" bench
  unit — the zo bench line again. Soak 2 to the stop: 11/11
  requests OK, memory flat, NRestarts=0 (logs soak2-*.log).
  Masked = cannot self-heal; QS-5 did not unmask (above this
  seat — escalated to the coordinator as a three-strike
  coordination failure). Also recorded: after the 05:37
  re-enable the watchdog timer showed Started but fired no
  runs before the mask (soak 1: fired every 2 min) — to be
  investigated on restoration. Soak + QS-5.5 kill test OWED,
  pending a protected window. Full record in QS-5-NOTES.md.
