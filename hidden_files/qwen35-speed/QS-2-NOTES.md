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
