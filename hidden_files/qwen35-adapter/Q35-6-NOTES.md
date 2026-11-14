# Q35-6 — HIP execution for qwen35 (resumption + completion)

Worker note: six Forge roles run sequentially by this single worker
(no sub-agents spawned; depth limit). Disk-first: this file landed
before any code change, and is extended in stages.

## Incident + inheritance

- Prior worker stopped mid-flight by an ordered service stop (no
  fault). Inherited UNCOMMITTED on yrsa/q35-6 @ efa400d6:
  aesir_engine/core/qwen35_hip.mojo (850 lines),
  aesir_engine/tests/test_qwen35_hip_q35_6.mojo (219 lines),
  hidden_files/qwen35-adapter/build-q35-6.sh, built test binaries,
  q35-6-build.log + q35-6-test.log proof logs. All preserved.
- This worker merged origin/yrsa/hip-serve (ff823ef3: Q35-3b U1
  fix, Q35-4b serve proof, Q8-1 compute fix) into yrsa/q35-6 first:
  clean fast-forward, no conflicts, untracked inheritance intact.
- Start-of-slice machine truth: MemAvailable 124256972 kB
  (~124 GB, services down per orders); no aesir/serve process
  running (only host_observer + ksmserver in the grep).

## Prior worker results, as left on disk (q35-6-test.log)

- HIP gate ok (AMD Radeon 8060S Graphics); executor constructed
  on the fixture (4 layers, 3 SSM + 1 attention).
- (b) per-token: pos0 s 1.1e-08 / conv 11.7109375 / logits
  0.015625, rank 1 gap 0.0; pos1 s 1.1316518; pos2 s 1.453681
  (worst); worst logits 1.203125; rank 1 gap 0.0 at all 4 prompt
  positions. Off the Q35-3a (c) band (s 0.0008479953 / conv
  0.0078125 / logits 0.013671875) for s, conv (pos0-1), logits.
- (c) FAILED: in-test cpu_greedy = 1019 675 143 251 365 969 ...
  vs dev_greedy = 1019 675 143 452 111 251 ... — diverged at
  index 3 (the 4th generated token); test raised, so sections
  (d) batched-vs-loop, (e) prefill measurement, (f) snapshot seam
  NEVER RAN. Session admission + regressions never ran.
- The prior report (via coordinator) said device greedy matched
  the THEN-banked Q35-3a CPU greedy exactly. Both can be true:
  the banked reference is external to this test; the in-test CPU
  continuation is the suspect. Diagnosis in the A/B section.

## Audit findings before any rerun (code inspection)

- DEFECT D1 (device, U1 mirror): qwen35_hip.mojo _delta_kernel
  line 384: `var g = vh // Int(v_per_group_arg)` — the PRE-FIX
  contiguous q/k broadcast. Corrected CPU truth (inference.mojo
  lines 2511 + 2777, Q35-3b U1): `g = vh % groups` (TILED).
  Fixture geometry groups=2, v_heads=4: contiguous maps vh
  0,1,2,3 -> g 0,0,1,1; tiled maps -> 0,1,0,1. v-heads 1 and 2
  read the wrong q/k group on device.
- DEFECT D2 (device, conv ring race): _ring_update_kernel
  shifts the conv ring IN PLACE in one parallel launch: thread
  for tap t reads slot t+1 while the thread for tap t+1 is
  storing into it. The CPU (inference.mojo conv block) shifts
  sequentially, tap ascending, so each read precedes the
  overwrite. On device the result is launch-order dependent:
  slots can duplicate the newest row or lose a history row.
  Fits the observed conv_diff 11.7109375 at pos0/pos1 (ring
  content wrong from the first token) while s at pos0 was still
  ~1e-08 (state update at pos0 reads the pre-shift ring: zeros).
- HARNESS DEFECT H1 (test, suspected; A/B to confirm):
  test_qwen35_hip_q35_6 uses `GenerationConfig()` defaults —
  temperature 0.7, repetition_penalty 1.1 (aesir.mojo defaults)
  — so its cpu_next is a SAMPLED token, not argmax. The banked
  harness (test_qwen35_forward_q35_3) pins temperature 0.0,
  repetition_penalty 1.0, top_k 40, top_p 0.9, seed 42 and
  asserts sampled == argmax. Sampling/rep-penalty explains a
  CPU greedy that agrees with device argmax for 3 tokens then
  departs at token 4, while per-token teacher-forced device
  argmax stayed rank 1 gap 0.0 in the CPU logit rows.

## CPU A/B verdict (step 1, CPU-only, merged tree)

- Banked harness rebuilt from the merged tree and run fenced
  (MemoryMax 32G): test_qwen35_forward_q35_3 ALL PASS
  (q35-6-cpuab.log). Sections: (a) argmax 758; (c) batched vs
  per-token s 0.0028607845 / conv 0.01171875 / logits 0.015625;
  (d1) exact 0.0; (d2) s 0.0016663075 / conv 0.0078125 /
  logits 0.01171875; (d3) s 0.002854824 / conv 0.01171875 /
  logits 0.021484375.
- CORRECTED CPU REFERENCE (post-U1), prompt [1,3,17,42],
  pinned config (temp 0.0, rep 1.0, top_k 40, top_p 0.9,
  seed 42): greedy 16 = 679 194 893 673 322 687 585 758 136
  104 316 224 916 54 103 47, identical across two runs.
- The prior device sequence (1019 675 143 452 ...) matched the
  PRE-U1 banked greedy: both the old CPU code and the inherited
  device code carried the contiguous broadcast. Post-U1 the
  reference moved; the device must move with it (fix D1).
- HARNESS DEFECT H1 CONFIRMED as the token-4 cause: the prior
  test built GenerationConfig() with defaults temperature 0.7
  and repetition_penalty 1.1 (aesir.mojo lines 127-130), so
  section (c) compared device argmax continuation against a
  SAMPLED CPU continuation (seed-dependent, rep-penalized).
  The two streams also feed different tokens by construction
  after any sample != argmax. First departure at generated
  index 3. Fix: pin the banked config exactly as
  test_qwen35_forward_q35_3 line 97 does, and assert the CPU
  sampled token equals the CPU logit argmax (banked pattern).
- Sections (b) state diffs are NOT explained by H1 (state is
  sampling-independent on a fixed stream): they are device
  defects D1 (U1 mirror) + D2 (ring race). Both fixed below.

## Device audit fixes (step 2) + trajectory rerun (steps 3-4)

- D1 FIXED: _delta_kernel now takes groups and computes
  g = vh % groups (TILED, inference.mojo:2511 citation in code);
  call site passes p.ssm_group_count.
- D2 FIXED: ring shift is now stage + commit through a new
  executor-owned ring_tmp device buffer (_ring_shift_stage_
  kernel writes the shifted ring to tmp; _ring_commit_kernel
  copies it back). No in-place parallel shift remains.
- H1 FIXED (test): pinned banked GenerationConfig (temp 0.0,
  rep 1.0, top_k 40, top_p 0.9, seed 42).
- RERUN (q35-6-test2.log, MemoryMax 32G, MemAvailable ~124 GB
  re-measured in-script, no serve processes): ALL PASS.
  (b) per-token vs corrected CPU: pos0 s 0.00018327683 / conv
  0.0078125 / logits 0.015625; pos1 s 0.00010411441 / conv
  0.0078125 / logits 0.0087890625; pos2 s 0.0007150769 / conv
  0.0078125 / logits 0.008056641; pos3 s 0.00033187866 / conv
  0.00390625 / logits 0.015625. WORST s 0.0007150769 (INSIDE
  the Q35-3a (c) band 0.0008479953), conv 0.0078125 (AT band),
  logits 0.015625 (one f16 ulp above the 0.013671875 band);
  teacher-forcing grade: device argmax rank 1, gap 0.0 at
  every prompt position -- near-tie band passed trivially.
  (c) greedy IDENTICAL to the corrected CPU reference:
  679 194 893 673 322 687 585 758 136 104 316 224 916 54 103 47.
  (d) batched vs GEMV-loop prefill (device vs device): state
  diff 0.0, logits diff 0.0 -- bit-equal on the fixture.
  (e) PREFILL MEASUREMENT (64 tokens, fixture): GEMV loop
  63.158295 ms (1013.3 tok/s) vs batched GEMM 9.429994 ms
  (6786.9 tok/s). CHOICE: batched GEMM prefill (6.7x), the
  session strategy below.
  (f) snapshot seam: state+KV readback -> reset executor ->
  writeback -> continuation logits diff 0.0 (bit-exact).
  Snapshots DO compose with the HIP executor.
