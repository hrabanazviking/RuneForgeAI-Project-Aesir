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

## Session + fixture serve (step 5)

- NEW aesir_engine/qwen35_hip_session.mojo: Qwen35HipSession, a
  ControlledTextSession over Qwen35HipExecutor mirroring the
  CPU session's contract (reset semantics, snapshot-based exact
  prefix reuse at committed turn boundaries, structured/tool
  refused). Prefill = batched GEMM (step-4 choice). Sampling is
  host-side over device logits through the CPU sampler itself
  (sample_token_from_logits + replay_rng), so serve sampling
  semantics are the CPU session's by construction. Snapshots
  store the executor state image + KV prefix image; restore is
  the executor byte-copy seam. Tokenizer via a resident
  AesirEngine used only for encode/decode.
- ADMISSION (native_serve.mojo): qwen35 + --accel hip admitted
  ONLY under --experimental-qwen35; without it the serve
  refuses by name ("Qwen 3.5 HIP serve requires
  --experimental-qwen35 in Q35-6; native HIP admission is not
  claimed", exit 1 proven, q35-6-refusal-noexperimental.log).
  Other accelerations for qwen35 refuse with the updated
  CPU/experimental-HIP message. NativeModelPlan admission is
  unchanged (Q35-4a truth); the ripple probe header + final
  line record the Q35-6 serve-level lift, assertions r1-r5
  unchanged, probe ALL PASS (q35-6-ripple.log).
- IN-PROCESS HIP SESSION (q35-6-hipsession.log): ALL PASS.
  R1/R2 on one device-resident state (POS1=72, POS2=106);
  reset reproduces R1 exactly; fresh session reproduces both;
  stateless text-extension after reset restored the turn-1
  snapshot (STATELESS_REUSED=72 == POS1) with reply == R2.
  Snapshots compose with the HIP session, not only the
  executor seam.
- HTTP FIXTURE SERVE (q35-6-bench.log, :18435, context 512,
  MemoryMax 32G unit): ALL PASS. /health: backend "hip",
  session_residency true, exact_prefix_reuse true WITH detail
  "snapshot-based at committed turn boundaries only",
  experimental_admission true, weight_load_mode
  "q8_0_resident". Resident T1 == in-process R1; T2 == R2
  with usage prompt 90 / reused 72 / evaluated 18. Stateless
  resend after an intervening session: reused 72 (snapshot
  restore), reply == R2. Port free after; MemAvailable
  ~124 GB before and after.
- REGRESSIONS (full driver q35-6-full.log, all rebuilt from
  this tree): engine compile exit 0; Q35-1 ALL PASS, Q35-2
  ALL PASS, Q35-3a ALL PASS, Q35-3r ALL PASS, Q35-4a session
  ALL PASS, Q35-5 snapshot ALL PASS, ripple ALL PASS, HIP
  executor test ALL PASS. CPU numerics unmoved (no CPU-path
  files touched by this slice).
- Build note: the HIP session test first failed to build with
  "unable to locate module 'loader'" from core/qwen35_hip --
  the Q35-1 anchoring lesson: a direct loader import now
  anchors the package root in both the session module and
  its test.

## Q35-6b — real-file grade (DONE, PASS)

Driver: aesir_engine/tests/grade_qwen35_hip_q35_6b.mojo (banked
parity_battery rank/gap; CPU comparator = banked Q35-3b v2 CSVs).
Real file Qwen3.8-27B Q8_0 (28,596,003,296 B), fenced 96G units.

- GEN WITNESS (P0, 40 tokens): HIP GEN IDS token-identical to the
  banked Q35-3b CPU GEN IDS (11751 13 271 ... 3478 3521); text ==
  the llama.cpp-agreeing witness text. Wall 8:49 (construction +
  5-token prefill + 40 decode), max RSS 25.6 GB.
- GRADE P0: 4/4 CPU-argmax rank 1 in HIP, gap 0.0, agreement 4/4.
- GRADE P1: 18/18 rank 1, gap 0.0, agreement 18/18 (3:54).
- GRADE P5: 49/49 rank 1, gap 0.0, agreement 49/49 (12:33, RSS
  29.4 GB) — including pos 32, the CPU-vs-llama near-tie position
  (HIP argmax 430 == CPU argmax 430, gap 0.0).
- TOTAL: 71/71 graded positions rank 1 gap 0.0 vs the corrected
  CPU path. Per-forward pace at real scale ~11 s (naive byte-load
  GEMV; see risks).

## Q35-6b — real-file serve: T1 PASS, T2 anomaly (INVESTIGATED)

HTTP serve (hip, ctx 4096, --experimental-qwen35, 96G fence):
/health truthful (backend hip, residency true, exact_prefix_reuse
true + snapshot detail, experimental true, q8_0_resident).
T1 PASS: reply == prefix of CPU R1, wall 343.93 s (23 prefill +
12 gen). T2: resident reuse fired (prompt 45, reused 35, eval 10)
but the reply repeated T1's answer ('The capital of France is
**Paris**.') instead of the CPU R2 language answer.

Investigation (all logs q35-6b-*):
- In-process session debug reproduced it (resident route, ctx
  4096, max_tokens 6): T2 gen [198 69267 25 271 760 6511];
  stream verified correct (23 prompt + 6 gen + 10 delta ids).
- Executor bisects, all bit-exact (state + KV images, 0.0):
  chunk@start>0 vs singles (fixture AND real), chunk@0 (T1
  pattern) vs singles (real), snapshot readbacks interposed
  (probe == control).
- Executor-level replication of the session's exact call
  sequence reproduced the T2 output exactly; variant with the
  T2 delta as singles reproduced it too. So neither the chunk,
  the readbacks, nor the session bookkeeping is the cause: the
  continuation is what this executor (== CPU numerics, graded)
  produces for THIS stream.
- Working explanation (test running): the bench truncated T1
  mid-sentence (6/12 tokens vs Q35-4b's 32). On a stream whose
  assistant turn is cut mid-sentence, the appended bare user
  delta is answered as a re-answer of the last complete
  question. Q35-4b's CPU T2 followed a 32-token T1. The HIP
  session at max_tokens=32 is being run to confirm parity.

## Q35-6b T2 anomaly — RESOLVED (no defect)

The long-T1 test (log q35-6b-t2long.log) settles it: HIP
session, T1 at max_tokens=32 == CPU R1 exactly (pos 55, the
Q35-4b POS1), resident T2(12) == '\nAssistant:\n\nThe primary
language spoken in Paris is **' — the CPU R2 continuation.
The earlier re-answer came from truncating T1 mid-sentence
(6/12 tokens): on that stream the model re-answers the last
complete question; executor bisects (chunk vs singles at both
scales, T1-pattern chunk, readback probe, sequence replication,
delta-as-singles variant — logs q35-6b-chunk*.log,
q35-6b-readback.log, q35-6b-seq*.log, q35-6b-t1chunk.log) are
all bit-exact or exactly reproducing, i.e. the device follows
the CPU numerics on every stream; the stream was the variable.
Bench fixed to the Q35-4b shape (T1 max_tokens=32) and rerun.

## Q35-6b — real-file HIP serve (DONE, ALL PASS)

Serve: real 27B via Qwen35HipSession, :18435, ctx 4096,
max-tokens 48, --experimental-qwen35, MemoryMax 110G driver /
96G serve unit. Bench q35_6b_bench.py (log q35-6b-bench.log):
- /health: backend hip, residency true, exact_prefix_reuse
  true (snapshot detail), experimental_admission true,
  weight_load_mode q8_0_resident. CAPS PASS.
- T1 (max 32): reply == CPU R1 EXACTLY (55 total, reused 0),
  wall 785.41 s.
- T2 resident: prompt 65, reused 55, evaluated 10; reply ==
  CPU R2 prefix ('The primary language spoken in Paris is
  **'), wall 305.68 s.
- Intervening different-session request: 200, 196.74 s.
- Stateless resend: snapshot restore reused 55, reply ==
  resident T2 exactly, wall 304.26 s. ALL PASS.
- Serve VmHWM peak 30,055,972 KB (~30.1 GB). Port free after;
  MemAvailable back to ~125 GB.
- Pace: ~14 s/forward under sibling QC-5 compile contention
  (~11 s uncontended in-process grade runs); decode ~0.07-0.09
  tok/s, completion-by-wall ~0.04 tok/s. The naive byte-load
  GEMV is the bottleneck (Q35-7 performance risk, named).

## LEDGER entry draft (for coordinator merge)

Q35-6 HIP execution for qwen35 — DONE. Fixture: corrected CPU
reference re-established (H1: prior HIP test sampled with
GenerationConfig defaults; pinned banked config), device
defects D1 (tiled q/k broadcast in _delta_kernel) + D2 (ring
shift race -> stage/commit via ring_tmp) fixed; trajectory
inside/at Q35-3a (c) band (s 0.0007150769, conv 0.0078125,
logits one f16 ulp over at rank 1 gap 0.0); greedy == corrected
CPU reference; batched prefill chosen (6.7x: 9.43 ms vs 63.16
ms at 64 tok). Qwen35HipSession (snapshot-composing,
CPU-mirrored contract) + experimental serve admission for
qwen35+hip (refusal without --experimental-qwen35 proven).
Fixture serve bench ALL PASS (resident reuse 72, stateless
snapshot reuse == resident reply). Q35-6b real 27B: grade
71/71 positions CPU-argmax rank 1 gap 0.0 (P0/P1/P5, incl. the
P5 pos-32 near-tie), 40-token greedy token-identical to the
banked llama.cpp-agreeing witness; HTTP serve ALL PASS
(health truth, T1 == CPU R1, resident T2 reused 55 + R2
prefix, stateless restore == T2, VmHWM 30.1 GB). T2 truncated-
T1 anomaly investigated to ground: model behavior on a
mid-sentence-truncated stream, not a defect (bisects all
bit-exact). Regressions Q35-1/2/3a/3r/4a/5 + ripple ALL PASS,
engine compile exit 0. Risks for Q35-7: naive GEMV bandwidth
(~11-14 s/token at 27B), native (non-experimental) admission
unclaimed, min_p/repeat_last_n unclaimed on qwen35 sampling,
F-4b-1/F-4b-2 carry-over.
