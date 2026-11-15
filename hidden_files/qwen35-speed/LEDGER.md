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
