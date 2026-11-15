# QS-0 BASELINE — Qwen3.8-27B Q8_0 on the live Aesir gate

Measured 2026-11-14 night on purpleraider. All numbers from logs
in this folder (qs0-bench.log, qs0-perf-flat.txt,
qs0-hip-fixture.log, qs0-gate-checks.log) or the banked prior
records cited in LEDGER.md. Nothing from memory.

## Configuration (as running; QS-0 changed nothing)

- Serve: transient unit aesir-gate, PID 5932, ./.aesir/aesir
  serve <27B Q8_0 GGUF> --accel cpu --profile qwen35
  --qwen35-resident --context 4096 --max-tokens 512
  --timeout-ms 900000 --port 18434, fence MemoryHigh 48G /
  MemoryMax 64G, WorkingDirectory ~/aesir-q35-7 (untouched).
- Health (qs0-bench.log): backend cpu, weight_load_mode
  q8_0_resident, model_variant qwen35-27B, session_residency
  true, exact_prefix_reuse snapshot-based, prefill_batch 1.
- Sampling: serve defaults (temp 0, top_k 40, top_p 0.95,
  min_p 0 unclaimed on this path, rep 1.0, seed 42 class).
- Machine: 32 cores, MemAvailable 119.5 GB at gate check;
  fresh-boot gate passed 21:00 EST (uptime 60m, load1 0.31).
- Concurrency honesty: QS-3's single-core quantize ran during
  the bench window (1 of 32 cores + page-cache traffic);
  Voxta.Server is up on the box. The p500 STREAM row ran under
  root perf record (dwarf) and is taxed by it -- see notes.

## Baseline table (live gate, end-to-end, ctx 4096)

Method: qs0_bench.py v2 -- streaming (SSE) for TTFT + chunk
decode, non-streaming twin for exact usage counts. Prompt
tok/s = prompt_tokens / TTFT (TTFT includes the first decode
step, so it is a LOWER bound on pure prefill rate).

| prompt | prompt_tokens | TTFT | prompt tok/s | decode tok/s | wall (gen 128) |
|---|---|---|---|---|---|
| ~500 class | 435 | 116.60 s | >= 3.73 | 2.14 (plain) | 176.05 s plain |
| ~2000 class | 1743 | 448.87 s | >= 3.88 | 1.83 stream / 1.75 plain | 514.29 s stream |

- p500 stream decode read 0.40 tok/s UNDER perf-dwarf
  profiling; the unprofiled p2000 stream read 1.83 and the
  p500 plain read 2.14 -- the 0.40 is a profiling artifact,
  not a streaming-route defect (discriminated by design).
- reused_prompt_tokens = 0 on both plain runs (unique
  prompts; no snapshot reuse contaminated prefill).
- Serve-side elapsed_ms agrees with client walls (427395 ms
  vs 427.40 s on the profiled stream run; gate serve log).
- Completion counts: 128/128 (p500), 123/128 (p2000, model
  hit a stop token early -- normal).

## Yardstick gaps (the campaign's targets)

- Prompt: Aesir ~3.8 tok/s vs Ollama 136.61 tok/s = ~35x gap.
- Decode: Aesir ~1.8-2.1 tok/s vs Ollama Q8_0 7.65 = ~4x gap;
  vs Ollama Q4_K_M 12.11 = ~6x gap.
- In-process grade decode (Q35-3b) was ~2.2 tok/s: the serve
  is NOT leaving anything on the table vs the engine path --
  both ride the same GEMM body (profile below).

## CPU profile indictment (QS-0.5)

Method: unpriv perf is BLOCKED (perf_event_paranoid=4). Root
perf record -p 5932 -F 99 -g --call-graph dwarf via a machine
unit during the p500 window: 155K samples, 0 lost
(qs0-perf-flat.txt / qs0-perf-top.txt). Shares are relative
and valid; absolute bench speed under profiling is taxed
(see the 0.40 artifact above) -- never quote profiled walls
as baseline.

Flat self-time, all else < 1%:
1. core::compute::_gemm_q8_0_fast_range -- 86.27% SELF.
   The BATCHED Q8_0 GEMM body is the entire furnace: it
   serves prefill AND (via _forward_batch) the serve's
   generation steps. Per Q35-3r's audit it dequantizes one
   weight row at a time into a bounded F32 scratch -- the
   decode-once design pays full dequant cost inside the
   inner loop at serve shapes.
2. _forward_batch self 4.93% (children 9.95%): the serve
   session forwards everything through the batch path.
3. _gemm_q8_0_gemv_worker (fused width-16 SIMD decode GEMV)
   self only 3.54%: the FAST decode path exists and is
   nearly unused by the serve -- single-row calls route to
   it (compute.mojo gemm_q8_0 A.rows==1 branch), but the
   qwen35 session's generation goes through _forward_batch.
4. Thread churn: clone3/start_thread children ~60% of the
   fast_worker stacks = par_for spawns per GEMM call;
   kernel clone3 self ~2.4%. Real but second-order vs (1).
5. Delta-net, attention, norms, sampling: each < 1% -- NOT
   the CPU problem at these shapes. (perf_event inherit
   lines ~3% are the profiler's own tax on thread spawns.)

## HIP profile indictment (QS-0.6)

rocprof: NOT present on this machine -> engine timers +
source audit + fixture phase timings (method per commission).
Fixture harness rerun tonight on this tree: ALL PASS
(qs0-hip-fixture.log), banked numbers reproduced exactly:
- (e) prefill 64 tok: GEMV loop 62.65 ms (1021 tok/s) vs
  batched GEMM 9.44 ms (6780 tok/s) -- batched is 6.7x.
- Real-file HIP decode (Q35-6b, banked): ~11 s/token
  uncontended, 0.07-0.09 tok/s; grade 71/71 rank 1 gap 0.0.
  Tonight's real-file gen-timing pair (n=4 vs n=20, load
  differenced out) did NOT run: the HEAVY.lock was held all
  night by QS-3's phased campaign (QS-3.5 -> 3.6 -> 3.7 ->
  further phases; their OWNER.txt extensions are the record)
  and the pair is a true second 27B load -- unambiguously
  heavy, no carve-out. NAMED BLOCKER, next work: run
  run-qs0-hip.sh's gen section as QS-0.6-addendum the first
  window the lock is free, or fold it into QS-2.1's first
  measurement (same harness, same differencing). The HIP
  indictment above does not depend on it: it stands on the
  fixture phase timings (tonight), the source audit, and
  the banked Q35-6b real-file numbers.
Source audit (aesir_engine/core/qwen35_hip.mojo):
1. _q8_gemm_kernel (line 79): one thread per output row;
   inner loop loads ONE BYTE at a time (unsafe_load per lane,
   32 scalar loads per block), sign-fixes per byte, no
   vector loads, no coalescing (adjacent threads read rows
   ~cols apart), activation re-read per row. This is the
   naive byte-load GEMV Q35-6 named -- the HIP furnace,
   the exact analogue of the roadmap-era scalar pockets.
2. Kernel census: 19 kernels; per SSM layer per token ~10
   launches (gemms, conv_silu, ring stage+commit = 2,
   l2norm, delta, gated_norm, copies) and ~12 per attention
   layer -> ~700 launches/token at 64 layers (48 SSM + 16
   attn). At ~11 s/token, launch overhead is NOT the main
   cost today; it becomes the ceiling after (1) is fixed.
3. Recurrent delta step (_delta_kernel) + conv ring: D1/D2
   defects were fixed in Q35-6; the ring still costs two
   extra kernels per SSM layer per token (stage + commit).
4. Header lesson in-file: HIP context creation ~13-16 ms
   per call shaped the executor design -- per-token context
   churn is already avoided; launches are the residue.

## Recommended slice order (QS-1 / QS-2)

QS-1 (CPU) first -- the gate runs CPU today, and the
indictment is singular:
- QS-1.1 ROUTE DECODE THROUGH THE GEMV: make the qwen35
  serve/session generation path issue single-position
  forwards that reach _gemm_q8_0_gemv_range (or split
  _forward_batch's tail positions), keeping batched
  fast_range only for true prefill. Expected: decode from
  ~2 toward the GEMV's proven class; re-grade FAITHFUL.
- QS-1.2 FAST_RANGE INNER LOOP: the prefill furnace (86%).
  Vectorize the Q8_0 dequant inside fast_range (width-16
  SIMD precedent) and/or dequantize each weight row ONCE
  per call into the scratch instead of per batch row --
  audit first, then fix; target prompt tok/s from ~3.8
  toward Ollama's 136.61.
- QS-1.3 par_for thread churn: persistent worker pool or
  coarser partitioning if (1)/(2) leave it exposed.
QS-2 (HIP) second:
- QS-2.1 Vectorized/coalesced Q8 GEMV (uint32 loads, one
  warp per row class) against _q8_gemm_kernel as-is.
- QS-2.2 Fuse ring stage+commit into conv; then a launch
  census re-take; QS-2.3 delta-step fusion if it surfaces.
QS-3/QS-4 as planned in MAP.md (QS-3 is already running in
its own tree tonight). QS-5/QS-6 unchanged.
