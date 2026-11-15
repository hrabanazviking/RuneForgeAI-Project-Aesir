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
