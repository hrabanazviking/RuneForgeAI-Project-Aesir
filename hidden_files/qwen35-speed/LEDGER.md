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
