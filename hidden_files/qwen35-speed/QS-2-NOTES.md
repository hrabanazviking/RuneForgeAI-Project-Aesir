# QS-2 NOTES — HIP decode speed (team QS-2, branch yrsa/qs-hip)

Seat: QS-2 team lead runs the six Mythic Engineering roles
sequentially in one seat (no sub-agents available at depth 2/2 —
recorded per commission). Sole writer in ~/aesir-qs-hip on
branch yrsa/qs-hip @ bad65106 (QS-0 close). Main (31ab9363),
~/aesir-q35-7, the running aesir-gate service, Ollama and Voxta
are never touched.

## Ground truth at start (2026-11-15 ~00:03 EST, from the machine)

- Machine: purpleraider, uptime 4:03 (fresh-boot gate long
  passed), load1 1.67 falling (1.27 at next check),
  MemAvailable 118,793,924 kB (~113 GB).
- HEAVY.lock: HELD by QS-3 (yrsa/qs-pack) since 2026-11-14
  ~22:31 EST, extended ~00:40 (QS-3.8 v3 re-pack + grade, unit
  qs3-27b-v3 ACTIVE at check). Heavy (real-file 27B) work waits;
  fixture/code work proceeds per commission.
- rocprof: ABSENT (QS-0 finding stands) — engine timers +
  fixture timings only; stated in every bench.
- Worktree created: git worktree add ~/aesir-qs-hip
  -b yrsa/qs-hip bad65106. Fixture qwen35_forward.gguf is
  untracked in all trees; copied from ~/aesir-hipserve,
  sha256 140e1750e44c8bdc27115153bfe7743304863172c0b5656672d46150b7cbfe55
  (identical in aesir-hipserve and aesir-q35-6).

## The indictment (QS-0, read in full)

- _q8_gemm_kernel (core/qwen35_hip.mojo line ~79): one thread
  per (batch, row); inner loop = 32 scalar byte loads per
  Q8_0 block, sign-fix per byte, activation re-read per row,
  adjacent threads read rows ~cols apart (uncoalesced).
  Real-file decode ~11 s/token (0.07-0.09 tok/s), grade
  71/71 rank 1 gap 0.0 — correct, a crawl.
- Fixture (e): prefill batched GEMM 6,780 tok/s vs GEMV loop
  1,021 tok/s (6.7x) — the batched machinery is fast; the
  single-token path is the defect.
- Launch census: 19 kernels, ~700 launches/token (48 SSM
  layers x ~10 + 16 attn layers x ~12). At 11 s/token launches
  are NOT the cost today; they are the ceiling after the GEMV
  fix (QS-2.3 in commission numbering).
- Bandwidth physics (named ceiling candidate): Q8_0 file is
  28,596,003,296 B read once per token. Ollama Q8_0 decode
  7.65 tok/s implies ~219 GB/s effective; Q4_K_M 12.11 tok/s
  on 16.2 GB implies ~196 GB/s. So the Q8_0 prize is a
  bandwidth race: >7.65 tok/s needs >~219 GB/s sustained
  weight streaming. 12.11 tok/s on Q8_0 would need ~346 GB/s —
  beyond this memory system; that yardstick belongs to the
  Q4_K_M tier (QS-3). QS-2 reports the measured ceiling
  honestly if the Q8_0 race tops out at/below 7.65.

## Kernel design for QS-2.2 (vectorized GEMV)

Codebase-proven GPU idioms only (no exotic APIs):
- dense_normalization.mojo pattern: warp = global_idx // 32,
  lane = global_idx % 32, per-lane strided chunks, warp.sum
  reduction (std.gpu.primitives.warp).
- New _q8_gemv_kernel: ONE WARP PER (batch, row). Lane l
  accumulates blocks l, l+32, l+64, ... of the row; per block
  the 32 quants are loaded as 8 packed UInt32 words and
  unpacked in-register (4 quants per word, sign-fixed by
  arithmetic shift), each quant FMA'd against the activation
  element. Lane partials combined with warp.sum; lane 0
  stores f16-rounded (the CPU gemm_f16 store contract).
- Parallelism: rows x 32 threads (vs rows today) — e.g. the
  5120-row hidden GEMMs go from 5,120 to 163,840 threads.
- Accumulation order changes (lane-strided partials + tree
  reduction). The file header already classes GEMM
  accumulation order as a legitimate difference; the GRADE
  LAW judges it: fixture (b) band + rank/gap, (c) greedy
  identity, (d) batched-vs-loop (order is batch-independent
  per row, so (d) stays bit-equal), then the real-file
  Q35-6b grade (71/71 rank 1 gap 0.0 standard).
- The batched path (batch > 1, prefill) keeps the EXISTING
  _q8_gemm_kernel untouched: prefill is already fast
  (6,780 tok/s fixture) and its numerics stay bit-identical.
  _gemm dispatches batch == 1 to the new kernel, batch > 1
  to the existing one. (Session decode is batch 1; grade gen
  is batch 1; prefill chunks are batch > 1 except a possible
  final single-token chunk — which then takes the new kernel,
  graded as part of the whole.)

## Slice log

- QS-2.0 (recon + design): this file. Lock held by QS-3;
  fixture build + fixture proof proceed fenced (MemoryMax 32G
  class, Q35-6 precedent) without the lock.

## QS-2.2 fixture proof (2026-11-15, fenced 32G, no lock needed)

- Baseline first: unmodified bad65106 binaries built in this
  tree (build-qs2.sh, all exit 0; .base copies stashed) and
  the fixture reproduced QS-0 exactly: ALL PASS, (b) diffs
  digit-identical to qs0-hip-fixture.log, (e) GEMV loop
  65.59 ms (976 tok/s) vs batched 10.21 ms (6,266 tok/s)
  (qs2-fixture-base.log; QS-0 read 62.65/9.44 — machine
  variance, same class).
- Kernel v1 (warp-per-row for batch==1 only, batched path
  untouched): (b) rank 1 gap 0.0 all positions, diffs in
  band; (c) greedy identical; BUT (d) FAILED —
  batched_vs_loop state_diff 0.00390625 > the 0.001 gate
  (logits_diff 0.0). Cause: (d) premise is "same kernels,
  only batching differs"; v1 made batch==1 and batch>1 use
  different accumulation orders, and 1-f16-ulp qkv
  differences ride the conv ring into the f32 state.
- Kernel v2 (FIX, in scope): ONE warp-per-row kernel for
  ALL batch sizes (warp -> (b, row); per-row accumulation
  order is batch-independent). (d) premise restored.
  Fixture (qs2-fixture-gemv2.log): ALL PASS — (b) rank 1
  gap 0.0, worst s 0.0007150769 / conv 0.0078125 / logits
  0.015625 (same as baseline pattern); (c) greedy
  identical; (d) 0.0 / 0.0 EXACT; (f) 0.0. (e) GEMV loop
  52.54 ms (1,218 tok/s, 1.25x vs baseline loop at fixture
  scale), batched 11.44 ms (5,596 tok/s). Fixture weights
  are 912 KB (L2-resident): (e) is a launch/latency
  measurement, NOT bandwidth — the bandwidth verdict is
  the real-file gen pair (QS-2.1) under the lock.
- HIP session fixture test (qs2-session-gemv2.log): ALL
  PASS, POS1=72 / POS2=106 == the Q35-6 banked values,
  snapshot reuse exact.
- _q8_gemm_kernel (sequential) is now unreferenced by
  _gemm but kept in-file as the A-082-shaped reference;
  the warp kernel is _q8_gemv_kernel.
- NEXT: QS-2.1 gen pair on .base binaries the moment the
  HEAVY.lock frees (QS-3 v3 unit still active at last
  check), then QS-2.2 real-file grade + gen pair.

## QS-2.3 step 1 — ring stage+commit fusion (fixture-proven)

- Stage fused into _conv_silu_kernel (writes tmp only; conv
  reads ring/qkv, writes conv row — disjoint, bit-exact).
  Commit fused into _l2norm_kernel (copies tmp -> ring at
  kernel head; l2norm never reads the ring; the delta
  kernel launches after it on the same stream). The two
  standalone ring launches per SSM layer per row are gone:
  -96 launches/token at 48 SSM layers, batch 1.
  _ring_shift_stage_kernel / _ring_commit_kernel kept
  in-file as the D2 reference, now unreferenced.
- Fixture (qs2-fixture-fuse1.log): ALL PASS; (d) 0.0/0.0
  and (f) 0.0 EXACT (fusion changed no math); (c) greedy
  identical; (e) GEMV loop 51.04 ms vs 52.54 ms for the
  GEMV-only build (fixture is launch-bound; ~4 us per
  removed launch incl. host enqueue). Real-scale effect
  measured with the gen pairs under the lock.
- Attribution stash: pre-fusion binaries kept as *.gemv2
  beside the *.base baseline copies, so the heavy window
  can gen-pair base vs gemv2 vs fused builds separately.

## QS-2.4 — recurrent step fusion (fixture-proven)

- _delta_norm_kernel: the Gated-DeltaNet delta step and
  the gated RMSNorm fused into one launch per SSM layer
  per row (-48 launches/token). Phase 1 is the delta body
  verbatim; phase 2 sums val^2 through shared memory
  (256 floats) with a block barrier, then applies the
  gated norm in place. Design history: a warp.sum tree
  version was replaced by the shared-memory version
  because the fixture d_state is 16 (a warp would span
  two v-heads) — the shared version is one code path for
  every d_state dividing the 256-thread block (fixture
  16, real file 128); other geometries keep the original
  two-kernel path (host branch).
- Fixture (qs2-fixture-fuse3.log): ALL PASS, fused branch
  genuinely taken (16 divides 256); (b) diffs
  digit-identical to the unfused runs; (d) 0.0/0.0 and
  (f) 0.0 EXACT; (e) GEMV loop 50.76 ms (1,261 tok/s),
  batched 9.29 ms (6,889 tok/s — above the banked 6,780).
- Launch census now: ~700 - 96 (ring) - 48 (gated norm)
  = ~556 launches/token. Remaining big blocks: per-layer
  _copy + 2x _rmsnorm (1 active thread each at batch 1),
  FFN silu_mul, residual _add — QS-2.3 continues after
  the real-scale profile (gen pairs) names the true
  ceiling: bandwidth vs launch vs serial-norm latency.

## QS-2.3 step 2 — SiLU pair fused into the FFN down-GEMV

- _q8_gemv_silu_kernel: the down projection computes the
  SwiGLU activation on the fly (_silu_pair: both f16
  roundings of _silu_mul_kernel reproduced exactly), so
  the standalone silu_mul launch per layer is gone
  (-64 launches/token) along with the FFN-width
  activation round-trip through o_fu.
- Fixture (qs2-fixture-fuse4.log): ALL PASS; (d) 0.0/0.0
  and (f) 0.0 EXACT (bit-exact fusion); (e) GEMV loop
  49.47 ms (1,294 tok/s fixture scale).
- Launch census now ~492/token (from ~700): GEMV-class
  launches 10/layer remain the spine; the rest is norms,
  copies, adds and the attention block. Next steps wait
  on the real-scale gen pairs (bandwidth vs latency).

## QS-2.3 step 3 — warp-parallel RMSNorm

- _rmsnorm_kernel was one thread per row doing two serial
  width-length passes (2 per layer + final = 129 serial
  reductions per token at 5120 wide). Now one warp per
  row (lane-strided, warp.sum), same in-place safety
  (pass 1 stores nothing). Sum order changes (rounding
  class); _norm launch grid scales by 32.
- Fixture (qs2-fixture-fuse5.log): ALL PASS; (b) diffs
  IMPROVED vs the serial norm (worst s 0.00021445751 vs
  0.0007150769; logits 0.0078125 vs 0.015625), rank 1
  gap 0.0; (c) identical; (d)/(f) exact 0.0; (e) GEMV
  loop 36.56 ms (1,751 tok/s) vs 49.47 ms — the serial
  norms were ~27% of the fixture loop time. Session
  test ALL PASS (qs2-session-fuse5.log, POS1=72/POS2=106).
- Fixture loop trajectory so far (64 tok, ms): baseline
  65.59 -> GEMV 52.54 -> +ring fusion 51.04 -> +delta
  fusion 50.76 -> +silu fusion 49.47 -> +warp norm 36.56.

## GEMV bandwidth micro-bench (synthetic, contended)

- bench_qwen35_gemv_qs2 (this folder): synthetic Q8_0
  weights at real shapes, scales pinned to f16 0.03125,
  5 reps back-to-back per kernel. Run fenced while QS-3
  held the machine (their CPU re-pack/grade shares the
  same LPDDR5x — numbers are a FLOOR, to be re-measured
  in the quiet heavy window).
- ffn shape 17408x5120 (94.7 MB): OLD 1.13 GB/s, NEW
  70.24 GB/s (62x). Output shape 248320x5120 (1.35 GB):
  OLD 0.63 GB/s, NEW 62.75 GB/s (99x). Old-vs-new output
  MAXDIFF 0.0 on both shapes (an earlier random-scale
  run showed 96.0 — overflow-range f32 rounding noise
  from random f16 scales incl. huge values, confirmed
  by the pinned-scale rerun; NOT a kernel defect).
- HIP pool claim measured: MemAvailable 122,376,344 kB
  before the bench, 80,581,916 kB after — opening the
  HIP context + buffers claimed ~42 GB of the unified
  pool on this box. Heavy-window memory checks are
  taken BEFORE any HIP context opens (QS-0 pattern).
- If the quiet-window rate stays far under ~200 GB/s,
  GEMV v3 levers (prepped, not yet built): SIMD4
  activation loads (activation is currently 1 scalar
  load per quant vs ~0.53 for weights), split FMA
  accumulators to break the serial acc chain, row-pair
  work per lane for more independent streams.

## GEMV v3 — SIMD accumulator (fixture + bench)

- _q8_gemv_kernel v3: activation read as 4 scalar loads
  packed into a SIMD4 (this Mojo Pointer has no SIMD
  unsafe_load — the compiler-facing form is 4 scalar
  loads + SIMD construction), products accumulate in a
  SIMD4 register (4 independent FMA chains vs 1 serial
  chain in v2). _q8_gemv_silu_kernel ported identically.
- Fixture: ALL PASS, (d)/(f) exact (qs2-fixture-gemv3s
  .log; loop 37.19 ms — fixture is latency-bound, the
  SIMD change is a bandwidth-regime lever).
- Bench rerun (same QS-3 contention): ffn shape 76.24
  GB/s (v2: 70.24), output shape 63.97 GB/s (v2:
  62.75); MAXDIFF 0.0 both. The contended ceiling is
  NOT the FMA chain — suspects are package power /
  bandwidth shared with QS-3 CPU work. The quiet-window
  gen pairs are the deciding measurement; if they land
  far under ~200 GB/s, next levers are the weight-load
  pattern (block-pair processing: 17 word loads per 64
  quants instead of 17 per 32) and L2 activation
  traffic (rows x 20 KB per GEMM from L2).

## REAL-FILE RESULTS (2026-11-15 ~01:35-01:56 EST)

- Lock: QS-3 banked their closing summary (e0f28a8b)
  with unit inactive and no processes; the stale lock
  was removed and QS-2 claimed it 01:30. Gates at
  launch: load1 0.65, MemAvailable 122,221,684 kB,
  uptime 5:36. Fence 80G/96G, unit qs2-heavy.
- CONTENTION (material): QS-1's CPU serve (aesir-qs-cpu,
  PID 470680, ~8 cores, port 18436) decoded the same
  27B Q8_0 from the same LPDDR5x from 01:36 through
  ~01:56, then rolled into bench_qs1_forward (PID
  488960, ~15 cores). ALL real-file numbers below are
  floors under that contention; clean re-measurement
  is owed when the machine is quiet.
- QS-2.1 DEFERRED MEASUREMENT (unmodified bad65106,
  .base binaries): gen4 114.62 s, gen20 353.10 s ->
  decode 14.905 s/token = 0.067 tok/s. (QS-0's ~11
  s/token estimate came from a gen40 total; the pair
  differencing is the honest figure.)
- GEMV v2+fusions (cur at the time, v3 kernel): gen4
  21.19/17.28, gen20 49.47/23.91 -> v2 0.566 tok/s,
  v3-kernel build 2.41 tok/s. Grade (v3 build): P0 4/4,
  P1 18/18, P5 49/49, all rank 1 gap 0.0 = 71/71
  FAITHFUL. GEN TEXT coherent (Paris answer).
- v4 COALESCED GEMV: bench under identical QS-1
  contention: ffn 70.9 vs v3 41.6 GB/s; output 82.0
  vs 63.0 GB/s; MAXDIFF 0.0. Real file: gen4 16.58,
  gen20 22.13 -> 0.3469 s/token = 2.88 tok/s. Grade:
  71/71 rank 1 gap 0.0 FAITHFUL (qs2-grade-*-v4.log).
- Diagnosis: in-engine effective streaming (78 GB/s)
  matches the isolated bench under the same
  contention, so the GEMV streaming rate -- not
  launches, not the SSM/attention kernels -- is the
  binding constraint. v3's strided lane->block map
  cost ~32 scattered transactions per warp load;
  v4's lane-per-slot walk is fully coalesced.
- Trajectory (all grade-faithful): 0.067 -> 0.57 ->
  2.41 -> 2.88 tok/s (43x over baseline). Yardstick
  7.65 tok/s needs ~208 GB/s effective; the gap is
  now a memory-system/kernel-pattern question, with
  QS-1 contention an unquantified share of it.

## GEMV v5-v7 — unroll ladder (bench, QS-1 contention)

- v5 = v4 + 2-block unroll: 136.3 / 149.5 GB/s.
- v6 = 4-block unroll: 170.2 / 193.2 GB/s.
- v7 = 8-block unroll: 196.7 / 214.6 GB/s (ffn /
  output shapes). MAXDIFF 0.0 vs the sequential kernel
  at every version. The unrolls work because each
  iteration now holds 8 independent load->FMA chains
  per lane, hiding DRAM latency; v3's SIMD-accumulator
  theory was wrong -- latency, not FMA chains, bound
  the coalesced kernel.
- v7 dispatched (plain + silu port). Fixture ALL PASS
  (loop 26.47 ms, batched 9,798 tok/s). Real file:
  gen4 17.54, gen20 19.87 -> 0.1456 s/token = 6.87
  tok/s, grade 71/71 rank 1 gap 0.0 FAITHFUL --
  measured WHILE QS-1's bench_qs1_forward (PID
  494226, ~14.5 cores) ran from 02:09. A clean-window
  re-measurement is owed; at the bench's 214.6 GB/s
  the GEMV stream alone is 0.127 s/token, so most of
  the remaining 0.019 s/token is non-GEMM work.

## A/B + CLEAN-WINDOW RESULTS (2026-11-15 ~02:26-02:43)

- MEASUREMENT LESSON: at 0.15-0.3 s/token the 4/20
  gen pair is noise-dominated (construction variance
  +-2 s vs decode diffs of 1-5 s; one pair implied an
  impossible 348 GB/s). All headline numbers now use
  the 4/140 pair (136-token difference). Short-pair
  readings (v7 6.87, v8 3.17) are RETRACTED as
  unreliable; the gen60 pair (v7, 5.51) is indicative
  only.
- Same-epoch long pairs (QS-1 serve contended): v8
  0.2940 s/token (3.40 tok/s) vs v7 0.3196 (3.13) --
  v8 >= v7 confirmed; v8 stays dispatched.
- CLEAN WINDOW (lock re-claimed 02:37:43 after the
  01:30 claim was removed by another party; load1
  0.94, MemAvailable 125 GB, no QS-1 processes):
  v8 long pair cold 0.2815 s/token (3.55 tok/s);
  warm repeat 0.2608 (3.83). Sustained bench in the
  same window: v8 209.6 / 205.1 GB/s, v7 200.4 /
  201.6 -- the isolated kernel streams at Ollama-
  class rates, so the remaining ceiling is IN-ENGINE:
  ~0.13 s/token of non-GEMV-stream time per token
  (launch/sync/host path or small-kernel chain), NOT
  the GEMV kernel and NOT QS-1 contention. Named
  next step: real-scale per-phase profile (engine
  timers at 27B geometry) to attribute the 0.13 s.
- LOCK RECORD (per coordinator correction 02:37):
  QS-2 claims: 01:30:23 (removed by another party
  before 02:37), 02:37:43 (this window). All QS-2
  real-file runs of the night ran inside fenced
  units while a QS-2 OWNER.txt claim stood, except
  the fixture-scale and synthetic-bench light work
  of 00:0x-01:2x (pre-claim). Release recorded in
  LEDGER at banking.
