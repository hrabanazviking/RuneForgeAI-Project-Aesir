# Aesir Z13 Forge — Wave Plan

Campaign: Project Aesir on purpleraider (ASUS ROG Flow Z13, AMD Strix Halo).
Roadmap: `docs/AESIR_Z13_MASSIVE_ROADMAP.md` — 216 slices, A-001…A-216,
24 waves of 9. Filed at commit 00a66e35 (2026-11-11).

## Layout (all on purpleraider)

- Main checkout (banking seat): `/home/volmarr/aesir-forge` (branch `main`)
- Team worktrees: `/home/volmarr/aesir-team-01` … `/home/volmarr/aesir-team-09`,
  branches `yrsa/aesir-team-NN`, each with its own `CAMPAIGN_STATE.md` and
  `hidden_files/` logs. Never share a checkout between teams.
- Structure: 9 teams × (1 lead + 6 Mythic Engineering sub-agents) = 63 workers.
  Each team works ONE slice at a time, in roadmap order.

## Slice queue

Slices are taken strictly in roadmap order (A-numbers ascending) and bank
only in roadmap order. Wave 1 assignments:

| Team | First slice |
|---|---|
| team-01 | A-001 |
| team-02 | A-002 |
| team-03 | A-003 |
| team-04 | A-004 |
| team-05 | A-005 |
| team-06 | A-006 |
| team-07 | A-007 |
| team-08 | A-008 |
| team-09 | A-009 |

After a team's slice banks, it takes the next unbuilt slice in order.

## Muster order (spawn-staggering law)

Probe with team-01 FIRST. Then muster 2–3 additional teams per keeper tick
(team-02+03, then 04+05, then 06+07, then 08+09) — never launch all teams at
once (platform rate limits, 2026-11-06 lesson). A team counts as mustered
when its lead is live on its assigned slice in its own worktree.

## Banking rules (per slice, in roadmap order, on purpleraider)

1. Full test suite green in the team's worktree (counts read back from log
   files, never memory; the fast gate A-035/A-080 applies once those exist —
   until then the repo's E-MASTER suite is the gate).
2. Merge the team branch into the main checkout (`~/aesir-forge`).
3. `git fetch` + remote-diff before any push.
4. Push explicit refspec `HEAD:refs/heads/main` — never force-push.
5. Verify the remote moved with `git ls-remote`.
6. Append the slice entry to `PROJECT_MEMORY_MAP.md` and update this file
   (banked count + next assignments). One slice per commit,
   subject `A-NNN: <title>`.

## Hard bounds

- NO Docker, ever. Native installs only.
- Never touch any README.md.
- Trust only disk: counts come from git + test-runner logs on purpleraider.
- Raw-oracle discipline for all correctness work (roadmap law 3); comparator
  artifacts are a verdict class (law 4); accelerator-visible ≠ accelerator-run
  (law 6) — every accelerator claim needs device-execution evidence.
- Never leave a discovered bug unfixed: fix inside the slice's scope, or
  record it as the immediate next work in the team's CAMPAIGN_STATE.md.
- Pause only at the Forge pause-lines (data destruction, irreversible
  infrastructure, cost, public publishing beyond this repo's own pushes,
  sending as Volmarr, exposing secrets, weakening security).

## State

- Banked: **92 of 216** (A-001..A-092). A-092 banked at the
  seat 2026-11-13 (team-22 commit 71af26b0 cherry-picked
  as b3930f78, +0 run_all cases, pin stays 610; NPU
  hello-compute - first AIE kernel execution in this
  project: IRON/mlir-aie matmul 64x64x64 i16->i32 exact
  vs CPU oracle on the real XDNA 2 (ert_cmd_state 4
  COMPLETED, 4096/4096 exact, 0 sentinels, identical
  checksum 3/3 runs); VTD archive fetched, xrt-smi
  validate all PASSED; toolchain stood up with no
  system packages and no Docker; seat gate 607/1/2 of
  610 exact on run 2 solo, sole failure J-022 (run 1:
  605/3/2 with BOTH named intermittents, log preserved);
  full note in PROJECT_MEMORY_MAP). A-091 banked at the
  seat 2026-11-13 (team-21 commit f41f1878 cherry-picked
  as 35094bbb, doc-only slice, +0 run_all cases, pin
  stays 610; XDNA 2 capability census - every claim
  marked OBSERVED vs DOCUMENTED: OBSERVED aie2p
  topology 6x8, Total Columns 8 via sudo xrt-smi;
  DOCUMENTED 32 compute tiles (48 total DERIVED only);
  memlock wall re-verified; validate blocked (VTD
  archive absent = A-092 first step); no NPU compute
  run or claimed; seat gate 607/1/2 of 610 exact on
  run 4 solo, sole failure J-022 (runs 1-2 state_vault
  intermittent, run 3 stream_async intermittent, logs
  preserved); full note in PROJECT_MEMORY_MAP).
  A-090 banked at the
  seat 2026-11-13 (team-20 commit 12570d2e cherry-picked
  clean as f9c56f72, doc-only slice, +0 run_all cases,
  pin stays 610; HIP instability verdict - HIP is NOT
  integrated (A-085/A-086 stand), no soak was run or
  claimed, the instability evidence is filed as the
  verdict in docs/bench/A090_HIP_INSTABILITY_VERDICT.md;
  none of the A-085 re-open criteria met; seat gate
  607/1/2 of 610 exact solo, sole failure J-022; full
  note in PROJECT_MEMORY_MAP). **Wave 10 (A-082..A-090)
  is COMPLETE.**
  A-089 banked at the
  seat 2026-11-13 (team-19 commit 6fadfbcc cherry-picked
  as 6aec2156 with the run_all union composed at banking,
  pin 605 -> 610; HIP error semantics - core/hip_errors.mojo
  maps every HIP error code into the taxonomy (33 mapped
  codes), all four HIP gateways rewired to the per-code
  table, unmapped codes fail closed to INT-001; 5
  errors.hip_* cases all PASS incl. fault injection per
  mapped code; seat gate 607/1/2 of 610 exact on run 2
  solo, sole failure J-022 (run 1: 605/3/2 with BOTH named
  intermittents, log preserved); full note in
  PROJECT_MEMORY_MAP).
  A-088 banked at the
  seat 2026-11-13 (team-18 commit 3f74bab6 cherry-picked
  as a473831f, doc+bench only, +0 run_all cases, pin
  stays 605; HIP zero-copy measurement - A-064 Vulkan
  residency STAYS for static weights, HIP managed not
  better for residency (alloc ~400x cheaper on the
  residency path, GPU+CPU-write parity at 64 MiB); new
  sub-case rule: no CPU-read buffer on the flags-7
  residency type (0.21-0.23 GB/s vs 33-42 GB/s managed/
  cached); A-085 verdict untouched; seat gate 602/1/2
  of 605 exact on run 2 solo, sole failure J-022 (run 1:
  601/2/2 with the named intermittent
  gpu.amd_hip_stream_async_round_trip, log preserved);
  full note in PROJECT_MEMORY_MAP).
  A-087 banked at the
  seat 2026-11-13 (team-17 commit 174aa363 cherry-picked
  as d971c736 with the run_all union composed at banking,
  pin 600 -> 605; ROCm install reproducibility - the
  A-005 install as a scripted, pinned, native setup:
  scripts/install_rocm_z13.sh (--check/--dry-run/--apply),
  core/rocm_pin.mojo pin table for all nine pinned
  packages, 5 rocm_repro.* cases all PASS; proof read-only:
  --check twice both CONVERGED pins=9 drift=0, --dry-run
  0 pending changes, --apply NOT run; seat gate 602/1/2
  of 605 exact solo, sole failure J-022; full note in
  PROJECT_MEMORY_MAP).
  A-086 banked at the
  seat 2026-11-13 (team-16 commit 973a5ba5 cherry-picked
  as 36fd574a with the unions composed at banking, pin
  594 -> 600; winner integration - the banked A-085
  verdict applied at the seat to the live registry
  (observe_backend_registry): Vulkan first-class, HIP
  probe-only; registry, doctor, placement and selection
  reflect the verdict, the injectable builder stays
  verdict-parametric; 6 gpu_winner.* cases cover pending
  + both decided states, all PASS; seat gate 597/1/2 of
  600 exact on run 3, solo, sole failure J-022; full
  note in PROJECT_MEMORY_MAP).
  A-085 banked at the
  seat 2026-11-13 (team-15 commit 134bcc13 cherry-picked
  as 872798d7, doc-only slice, +0 run_all cases, pin
  stays 594; the bake-off - Vulkan PRIMARY GPU road,
  HIP PARKED probe-only with 4 written re-open criteria,
  never silently dropped; Q4_K GEMV per-call Vulkan
  faster at every shape on the real gfx1151 device,
  both roads inside the filed parity band; seat gate
  591/1/2 of 594 exact on run 2, solo, sole failure
  J-022; full note in PROJECT_MEMORY_MAP).
  A-084 banked at the
  seat 2026-11-13 (team-14 commit ef9b8965 cherry-picked
  as b68acac2 with the unions composed at banking, pin
  589 -> 594; HIP attention + norms - RMSNorm bit-exact,
  RoPE worst 1.19e-06, attention worst 1.79e-07 vs the
  filed 1e-4 bound on the real gfx1151 device, three
  per-op dispatch-evidence counters; seat gate 591/1/2
  of 594 exact on run 2, solo, sole failure J-022;
  full note in PROJECT_MEMORY_MAP).
  A-083 banked at the
  seat 2026-11-13 (team-13 commit 0742431b cherry-picked
  as ef184af7 with the run_all union composed at banking,
  pin 586 -> 589; HIP Q4_K GEMV - parity inside the filed
  f16-rounding band at all 5 bench shapes on the real
  gfx1151 device, dispatch-evidence counter counts only
  completed device dispatches; seat gate 586/1/2 of 589
  exact on the fourth run, solo, sole failure J-022;
  full note in PROJECT_MEMORY_MAP).
  A-082 banked at the
  seat 2026-11-13 (team-12 commit 62de1014 cherry-picked
  as 2ea0c1d5 with the run_all union composed at banking,
  pin 581 -> 586; HIP Q8_0 GEMV - parity BIT-EXACT vs the
  CPU oracle on the real gfx1151 device, dispatch-evidence
  counter counts only completed device dispatches; seat
  gate 583/1/2 of 586 exact, sole failure J-022; full
  note in PROJECT_MEMORY_MAP).
  A-081 banked at the
  seat 2026-11-13 (team-11 commit 31d88a29 cherry-picked
  clean as 3e7ad295, +0 run_all cases, pin stays 581;
  HONEST NEGATIVE Part III gate - GPU path NOT declared
  primary, GPU 1.497 vs CPU 6.958 tok/s on the pinned 8B
  Q4 fixture; seat gate 578/1/2 of 581 exact, sole
  failure J-022; full note in PROJECT_MEMORY_MAP).
  A-080 banked at the
  seat 2026-11-13 (team-10 commit 2a1c2eec cherry-picked
  as 161d07ab with the run_all union composed at banking,
  pin 575 -> 581; seat gate 578/1/2 of 581 exact, sole
  failure J-022; full note in PROJECT_MEMORY_MAP).
  A-079 banked at the
  seat 2026-11-13 (team-03 commit c4b43c6f cherry-picked
  as 30e46c64 with the run_all union composed at banking,
  pin 568 -> 575, plus the budget-reorder fix 058a5b68 -
  team-03 6755114f composed at the seat; seat gate
  572/1/2 of 575 exact, sole failure J-022; full note in
  PROJECT_MEMORY_MAP). A-078 banked at the
  seat 2026-11-12 (team-02 commit 31b304d3 cherry-picked
  as 34c9deaa with the run_all union composed at banking,
  pin 561 -> 568; GPU fuzz - seeded reproducible fuzzing
  of the GPU path vs the CPU oracle under raw-oracle
  discipline: SYNTH 256 rows faithful 219 / near-tie 19 /
  noise 18 / real 0, SAMPLE greedy + sampling 96/96 each,
  REAL 147 positions all comparator-artifact class with
  top-1 agreeing at every position, GEN exact 32/32).
  A-077 banked at the
  seat 2026-11-12 (team-01 commit 13994069 cherry-picked
  as 1e49bacb, +5 cases, run_all pin 556 -> 561;
  GPU soak - one hour of continuous decode on the GPU
  path: 3600 s of decode, 4590 steps, 4584 generated,
  9 KV resets, 0 non-finite lanes, 0 errors, live buffers
  pinned at 32 / 574,545,936 bytes in every progress line
  and restored exactly at close, 881,280 Q4_K dispatches;
  decode-phase RSS slope +6.3..+13.5 MiB/h inside the
  pre-filed +/-16 MiB/h band; GPU temp peak 85 C).
  A-076 banked at the
  seat 2026-11-12 (team-03 commit 0000b175 cherry-picked
  as b99b702b with the run_all union composed at banking,
  pin 549 -> 556; GPU memory pressure - GpuPressureGovernor
  pre-dispatch routing contract: spillable overflow spills
  to CPU, non-spillable refuses MEM-003 before any GPU
  allocation, degradation logged and bounded; real 25.8 GB
  balloon squeeze flipped routing and recovered clean).
  A-075 banked at the
  seat 2026-11-12 (team-02 commit fa0078ef cherry-picked
  as b96c9c14, run_all pin 543 -> 549; accumulation
  policy - every reduction accumulates in FP32, FP16/
  BF16 lawful only as storage, ratified by logit-gap
  measurement and pinned in core/accum_policy.mojo).
  A-074 banked at the
  seat 2026-11-12 (team-01 commit c8aaefdc cherry-picked
  as d769885c, +0 cases, run_all pin stays 543;
  subgroup reductions - the A-073-ledger Vulkan
  1.1+/subgroup migration executed as the slice first
  step (instance 1.1, subgroup-size-control, required
  subgroup size 32 plumbing in the buffer shim);
  attention_decode 8.6-9.1x, strided 8.6x, prefill
  6.4x adopted; softmax an honest negative (+1.6..2.2%,
  overlapping) reverted byte-identical). A-073 banked at the
  seat 2026-11-12 (team-03 commit cherry-picked
  as 7879e143, +0 cases, run_all pin stays 543;
  wavefront-32 tuning - re-scoped from the roadmap
  Wavefront-64 title per the A-027 Part I gate device
  evidence (gfx1151 wavefront is 32); Q8_0 GEMV/GEMM
  pair workgroup 256 -> 64 moved together so the A-068
  bitwise invariant holds, q8_0_gemm -4.4..-8.4% in
  all four interleaved A/B series, every other kernel
  an honest negative left byte-identical; SPIR-V
  regenerated only via the A-055 pipeline, exactly
  the 2 Q8 hashes changed). A-072 banked at the
  seat 2026-11-12 (team-02 commit f650f01b cherry-picked
  as a2cabb5c with the run_all union composed at
  banking, pin 537 -> 543; continuous batching v1).
  A-071 banked at the
  seat 2026-11-12 (team-01 commit 0b7496dd cherry-picked
  as 46cefc41 with TWO run_all unions composed at
  banking - import block and pin 531 -> 537; decode and
  shim auto-merges verified composed; async dispatch).
  A-070 banked at the
  seat 2026-11-12 (team-03 commits acba480f + b59731a4
  cherry-picked as 54fcb61e + eb254362 with the run_all
  union composed at banking, pin 525 -> 531; lawful CPU
  assist). A-069 banked at the
  seat 2026-11-12 (team-02 commit 59ed5a9e cherry-picked
  clean as 6a0b96dc, base == seat HEAD, no unions needed:
  run_all pin 518 -> 525 as committed, shader manifest
  22 -> 25 kernels, all 22 prior SPIR-V hashes
  byte-identical; chunked prefill). A-068 banked at the
  seat 2026-11-12 (team-01 commit 943fa87b, finished and
  committed by a fresh lead mustered by the keeper after
  the first lead stopped post-suite, cherry-picked as
  c1e29e88 with FOUR unions composed at banking: shader
  manifest 16 + 19 -> 22 kernels, generated header 22
  arrays verified, SPIR-V pipeline pins -> 22, shim
  composed (seat shim + A-068 IQ-array deletions and
  header repoints applied as a patch + GEMM section
  appended after the A-066 tail), run_all pin 512 ->
  518; GPU prefill GEMM). A-067 banked at the
  seat 2026-11-12 (team-03 commit 78e0ace9 cherry-picked
  as 1355c7dd with the run_all union, pin 505 -> 512;
  real-model GPU decode on the pinned Llama-3.1-8B
  Q4_K_M fixture, copied into the seat fixtures dir and
  sha256 re-verified so the seat gate ran for real).
  A-066 banked at the
  seat 2026-11-12 (team-02 commit ee393126 cherry-picked
  clean as 259a9510; full decode loop on GPU, run_all pin
  501 -> 505 at banking, shader manifest 13 -> 16 kernels,
  all 13 prior SPIR-V hashes byte-identical). A-065 banked at the
  seat 2026-11-12 (team-01 commit 524cf9dd cherry-picked
  as d250ff9f; one full layer on GPU, run_all pin unioned
  496 -> 501 at banking, no shim change, no new shader).
  A-064 banked at the
  seat 2026-11-12 (team-04 commit 9afa3dc2 cherry-picked
  as cd6ad47b; GPU weight residency, run_all pin unioned
  491 -> 496 at banking, no shim change). A-063 banked at the
  seat 2026-11-12 (team-03 commit 404109e7 cherry-picked
  as 25e0c829; Vulkan sampling, run_all pin 485 -> 491,
  shader manifest 12 -> 13 kernels, all 12 prior kernel
  hashes byte-identical). A-062 banked at the
  seat 2026-11-12 (team-06 commit c8e6cd0f cherry-picked
  as eda188ef; Vulkan decode attention + SPIR-V dedup and
  12-kernel shader registration, run_all pin unioned
  480 -> 485 and vulkan_buffer_shim.c composed at banking:
  four hand-embedded GEMV arrays removed, call sites
  repointed to the generated header, A-059 IQ / A-060
  RMSNorm+RoPE / A-061 elementwise+softmax sections
  intact). A-061 banked at the
  seat 2026-11-12 (team-02 commit fdbbfba4 cherry-picked
  as 43c1e902; Vulkan elementwise + softmax, run_all pin
  unioned 474 -> 480 and vulkan_buffer_shim.c composed at
  banking: seat shim + A-061 elementwise/softmax block
  appended, A-060 RMSNorm/RoPE sections intact). A-060
  banked at the
  seat 2026-11-12 (team-05 commit 8de19201 cherry-picked
  as bb41ed4a; Vulkan RMSNorm + RoPE, run_all pin unioned
  468 -> 474 and vulkan_buffer_shim.c composed at banking:
  seat shim + A-060 RMSNorm/RoPE block appended, A-059 IQ
  sections intact). A-059 banked at the
  seat 2026-11-12 (team-01 commit 2d555a80 cherry-picked
  as 944bccc2; Vulkan IQ GEMV, run_all pin unioned
  463 -> 468 and vulkan_buffer_shim.c composed at banking:
  seat shim + A-059 IQ block appended, A-058 Q6/Q5 sections
  intact). A-058 banked at the
  seat 2026-11-12 (team-09 commit f397e1c6 cherry-picked
  as 278199de; Vulkan Q6_K + Q5_K GEMV, run_all pin unioned
  458 -> 463 and vulkan_buffer_shim.c composed at banking:
  seat shim + A-058 Q6/Q5 block appended, A-057 Q4_K section
  intact). A-057 banked at the
  seat 2026-11-12 (team-08 commit 056bf09d cherry-picked
  as 066eca4f; Vulkan Q4_K GEMV, run_all pin unioned
  455 -> 458 and vulkan_buffer_shim.c composed at banking).
  A-056 banked at the seat 2026-11-12 (team-07 commit
  45ba57e6 cherry-picked as 99323c17; Vulkan Q8_0 GEMV,
  run_all pin unioned 450 -> 455 at banking).
  A-055 banked at the seat 2026-11-12 (team-04 commit
  5d96a54b cherry-picked as c86433da; SPIR-V build
  pipeline, pin 445 -> 450).
  **Wave 3 (A-019..A-027) is COMPLETE. Wave 4
  (A-028..A-036) is COMPLETE. Wave 5 (A-037..A-045)
  is COMPLETE. Wave 6 (A-046..A-054) is COMPLETE.
  Wave 7 (A-055..A-063) is COMPLETE. Wave 8
  (A-064..A-072) is COMPLETE. Wave 9
  (A-073..A-081) is COMPLETE. Wave 10
  (A-082..A-090) is COMPLETE.**
- Seat gate after this banking: A-092 (seat_gate_a092.log, sha256 f6cf8780...) 607 passed / 1 failed / 2 skipped / 610 total, EXACT on run 2 solo, sole failure J-022 (+0 run_all cases, pin unchanged; run 1: 605/3/2 with BOTH named pre-existing intermittents - gpu.amd_hip_stream_async_round_trip and resilience.state_vault_rejects_growth - log preserved as seat_gate_a092_run1_bothintermittents.log). Previous gate (A-091, seat_gate_a091.log, sha256 77e52bac...) 607 passed / 1 failed / 2 skipped / 610 total, EXACT on run 4 solo, sole failure J-022 (doc-only slice, pin unchanged; runs 1-2: 606/2/2 with the named intermittent resilience.state_vault_rejects_growth, logs preserved as seat_gate_a091_run1/run2_statevaultflake.log; run 3: 606/2/2 with gpu.amd_hip_stream_async_round_trip, log preserved as seat_gate_a091_run3_streamasyncflake.log - the named intermittents rotating, A-083 pattern). Previous gate (A-090, seat_gate_a090.log, sha256 851b7f65...) 607 passed / 1 failed / 2 skipped / 610 total, EXACT solo, sole failure J-022 (doc-only slice, pin unchanged). Previous gate (A-089, seat_gate_a089.log, sha256 8a8d51ac...) 607 passed / 1 failed / 2 skipped / 610 total, EXACT on run 2 solo, sole failure J-022, all 5 errors.hip_* cases PASS (run 1: 605/3/2 with BOTH named pre-existing intermittents - gguf.weight_residency_gpu_visibility and resilience.state_vault_rejects_growth - log preserved as seat_gate_a089_run1_bothintermittents.log). Previous gate (A-088, seat_gate_a088.log, sha256 45ddf82a...) 602 passed / 1 failed / 2 skipped / 605 total, EXACT on run 2 solo, sole failure J-022 (doc+bench slice, pin unchanged; run 1: 601/2/2 with the named pre-existing intermittent gpu.amd_hip_stream_async_round_trip, log preserved as seat_gate_a088_run1_streamasyncflake.log). Previous gate (A-087, seat_gate_a087.log, sha256 930ed9bd...) 602 passed / 1 failed / 2 skipped / 605 total, EXACT solo, sole failure J-022, all 5 rocm_repro.* cases PASS. Previous gate (A-086, seat_gate_a086.log, sha256 58b6ee81...) 597 passed / 1 failed / 2 skipped / 600 total, EXACT on run 3, launched solo, sole failure J-022, all 6 gpu_winner.* cases PASS (run 1: 596/2/2 with the named pre-existing intermittent gguf.weight_residency_gpu_visibility, log preserved as seat_gate_a086_run1_weightresidencyflake.log; run 2: 596/2/2 with the named pre-existing intermittent resilience.state_vault_rejects_growth, log preserved as seat_gate_a086_run2_statevaultflake.log). Previous gate (A-085, seat_gate_a085.log, sha256 175385ba...) 591 passed / 1 failed / 2 skipped / 594 total, EXACT on run 2, launched solo, sole failure J-022 (doc-only slice, pin unchanged; run 1: 589/3/2 with BOTH named pre-existing intermittents - resilience.state_vault_rejects_growth and gpu.amd_hip_stream_async_round_trip - log preserved as seat_gate_a085_run1_bothintermittents.log). Previous gate (A-084, seat_gate_a084.log, sha256 61267494...) 591 passed / 1 failed / 2 skipped / 594 total, EXACT on run 2, launched solo, sole failure J-022, all 5 gpu.hip_attn_norms_* cases PASS (run 1: 590/2/2 with the named pre-existing intermittent resilience.state_vault_rejects_growth, log preserved as seat_gate_a084_run1_statevaultflake.log). Previous gate (A-083, seat_gate_a083.log, sha256 77c519ab...) 586 passed / 1 failed / 2 skipped / 589 total, EXACT on the fourth run, launched solo on a quiet machine, sole failure J-022, all 3 gpu.hip_q4k_gemv_* cases PASS (runs 1-3 ran 585/2/2 with one named pre-existing intermittent each, logs preserved as seat_gate_a083_run1/run2/run3). Previous gate (A-081, seat_gate_a081.log, sha256 59f3d879...) 578 passed / 1 failed / 2 skipped / 581 total, EXACT, sole failure J-022 (the slice adds no run_all cases, pin unchanged), launched solo. Previous gate (A-080, seat_gate_a080.log): 578/1/2 of 581 exact, all 6 equivalence.* cases PASS. Previous gate (A-079, seat_gate_a079.log): 572/1/2 of 575 exact, budget_live PASS after the reorder fix (history in the A-079 PROJECT_MEMORY_MAP row). Previous gate (A-078, seat_gate_a078.log):
  565 passed / 1 failed / 2 skipped / 568 total,
  exact on run 4 (runs 1-2: 564/2/2 with the extra
  memory.budget_live_meminfo_pressure intermittent,
  logs preserved as seat_gate_a078_run1_mempressure.log
  and seat_gate_a078_run2_mempressure.log; run 3: 564/2/2
  with the extra resilience.state_vault_rejects_growth
  intermittent instead, log preserved as
  seat_gate_a078_run3_flake.log - the named intermittent
  pair trading places across runs, never both in the
  accepted run). Sole failure the pre-existing
  gguf.tensor_directory_interface (J-022 drift), skips the
  2 pre-declared. Known intermittents (proven pre-existing
  at base b62b1481 by the A-055 base bisect, NOT caused by
  these slices): gguf.weight_residency_gpu_visibility
  (A-055 ledger bug B1) and
  resilience.state_vault_rejects_growth (bug B2) - neither
  appeared in the accepted gate run.
- Queue: teams take slices in roadmap order as theirs
  bank (keeper flow): A-093 - next to bank (team-23,
  building; two leads stopped incomplete on the probe
  transfer, third lead restarted with the on-device
  authoring road); then A-094 (team-24, mustered);
  then A-095 (team-25, mustered, preparatory work
  until A-094 lands).
  A-066 closed the A-065 KV-append gap
  (kv_append kernel, bit-exact).
  Sole failure in every suite =
  pre-existing gguf.tensor_directory_interface J-022 drift
  (roads A-165 primary / A-121); skips = the 2 pre-declared.
- A-063 next work (recorded in its ledger, NOT fixed at
  banking): (1) non-finite logit sanitization owed by the
  first engine-integration slice feeding raw logits to
  VulkanSampling; (2) build_shaders.py IQ-source glob
  drift - the next pipeline-regenerating slice dedups the
  IQ kernels into the generated header per the A-062
  precedent.
- A-007 caveat: unprivileged xrt-smi is blocked by RLIMIT_MEMLOCK
  (8192 kB vs the 64 MiB locked map XRT wants) - NPU tools run via
  sudo until Volmarr rules on raising the user memlock limit;
  xrt-smi validate needs the Xilinx VTD archive, first step of A-092.

## Expansion to 27 teams (Volmarr order 2026-11-13 ~05:59 EST)

- Volmarr ordered the teams working on Project Aesir on purpleraider increased to 27, staggered so a sudden mass start does not kill them. Muster at most 2-3 NEW team leads per keeper tick, in team order, until all 27 flow. If a spawn is refused with a rate limit (429), stop mustering for that tick.
- Seats created only when mustered, each from banked main with its own branch yrsa/aesir-team-NN, CAMPAIGN_STATE.md and hidden_files/.
- 2026-11-13 ~06:20 EST (keeper tick): seats team-10 and team-11 CREATED from banked main 3cfc4370 (78 of 216), verified by git worktree list. team-10 assigned A-080 (Equivalence gate), team-11 assigned A-081 (Part III gate) — the next unassigned slices in roadmap order. A-080/A-081 build in parallel and bank only in roadmap order after A-079 (and after each other).
- 2026-11-13 ~06:52 EST (keeper tick scheduled 06:47): seats team-12 and team-13 CREATED from banked main 3cfc4370 (78 of 216), verified by git worktree list. team-12 assigned A-082 (HIP Q8_0 GEMV), team-13 assigned A-083 (HIP Q4_K GEMV) — the next unassigned slices in roadmap order (Wave 10 opener). CAMPAIGN_STATE.md written + sha256-verified for both (team-12 e8cc06d1..., team-13 60c875bd...), hidden_files/ created. Leads spawned this tick, no 429; both briefed to defer full suites while team-03's probe + budget-reorder work runs solo. Team-03 RESTARTED this tick on the probe + budget-reorder fix road (critical path to unblocking A-079 banking). A-082/A-083 build in parallel and bank only in roadmap order after A-079/A-080/A-081 (and after each other).
- 2026-11-13 ~08:02 EST (keeper tick): A-082 BANKED (82 of 216, closure 82591e7c). A-083 cherry-picked at the seat as ef184af7 (run_all union 586 -> 589, shim counters unioned, shim compiles) but its seat gate ran 585/2/2 three times (runs 1 and 3: resilience.state_vault_rejects_growth; run 2: gpu.amd_hip_stream_async_round_trip - the two named pre-existing intermittents, rotating, all A-083 cases PASS every run; logs preserved as seat_gate_a083_run1/run2/run3). The Z-100 soak probes resumed (STAT R) during runs 2-3, so the gate was NOT re-run further this tick; A-083 banks on the first exact solo gate on a quiet machine. Seats team-14 and team-15 CREATED from banked main 82591e7c (82 of 216), verified by git worktree list. team-14 assigned A-084 (HIP attention + norms), team-15 assigned A-085 (The bake-off) - the next unassigned slices in roadmap order. CAMPAIGN_STATE.md written for both (team-14 sha256 2782cc61..., team-15 sha256 64fa05a0...), hidden_files/ created. Leads spawned this tick; both briefed to defer full suites while heavy shared work is live and never concurrently with a seat gate. Teams 16-27 not yet created; muster 2-3 per tick in order.
- 2026-11-13 ~08:17 EST (keeper tick): A-083 BANKED (83 of 216, closure de415271) - seat gate run 4 exact solo on a quiet machine: 586/1/2 of 589, sole failure J-022, all 3 gpu.hip_q4k_gemv_* PASS (seat_gate_a083.log sha256 77c519ab...). Team-14 and team-15 leads from the 08:02 muster were CANCELLED before finishing (no result); both left real uncommitted work (team-14: hip_attention_norms core + test + shim work in progress; team-15: A085_BAKEOFF.md draft + fresh HIP/Vulkan Q4_K bench logs 08:06) - fresh leads RESTARTED this tick to CONTINUE that work. Seats team-16 and team-17 CREATED from banked main de415271 (83 of 216), verified by git worktree list: team-16 A-086 (Winner integration - preparatory work only until the A-085 verdict banks), team-17 A-087 (ROCm install reproducibility). CAMPAIGN_STATE.md sha256-verified for both (team-16 a0e835cc..., team-17 c67d8f67...), hidden_files/ created, leads spawned this tick, no 429.
- 2026-11-13 ~09:07 EST (keeper tick): A-084 BANKED (84 of 216, closure a2f19330) - seat gate exact on run 2 solo: 591/1/2 of 594, sole failure J-022, all 5 gpu.hip_attn_norms_* PASS. A-085 cherry-picked at the seat as 872798d7.
- 2026-11-13 ~09:35 EST (keeper tick): A-085 BANKED (85 of 216) - seat gate run 2 exact solo: 591/1/2 of 594, sole failure J-022 (run 1: 589/3/2, both named intermittents). Verdict banked: Vulkan PRIMARY, HIP PARKED probe-only. Seats team-18 and team-19 CREATED from banked main (85 of 216) this tick: team-18 A-088 (HIP zero-copy measurement), team-19 A-089 (HIP error semantics).
- 2026-11-13 ~10:35 EST (keeper tick): A-086 BANKED (86 of 216, closure below) - seat gate exact on run 3 solo: 597/1/2 of 600, sole failure J-022, all 6 gpu_winner.* PASS (runs 1-2: 596/2/2 each with one rotating named pre-existing intermittent). Seats team-20 and team-21 CREATED from banked main (86 of 216) this tick: team-20 A-090 (HIP soak or instability verdict, Wave 10 closer), team-21 A-091 (XDNA 2 capability census, Wave 11 opener).
- 2026-11-13 ~11:30 EST (keeper tick): A-087 BANKED (87 of 216, closure below) - seat gate exact solo: 602/1/2 of 605, sole failure J-022, all 5 rocm_repro.* PASS (seat_gate_a087.log sha256 930ed9bd...). A-088 cherry-picked next in order.
- 2026-11-13 ~11:40 EST (keeper tick): A-088 BANKED (88 of 216, closure below) - seat gate exact on run 2 solo: 602/1/2 of 605, sole failure J-022 (run 1: 601/2/2, named intermittent gpu.amd_hip_stream_async_round_trip, log preserved). A-089 cherry-picked next in order.
- 2026-11-13 ~11:50 EST (keeper tick): A-089 BANKED (89 of 216, closure below) - seat gate exact on run 2 solo: 607/1/2 of 610, sole failure J-022, all 5 errors.hip_* PASS (run 1: 605/3/2, both named intermittents, log preserved). Seats team-22 and team-23 CREATED from banked main d67e0773 (88 of 216) this tick: team-22 A-092 (NPU hello-compute), team-23 A-093 (NPU memory sharing). A-090 cherry-picked next in order.
- 2026-11-13 ~12:00 EST (keeper tick): A-090 BANKED (90 of 216, closure below) - WAVE 10 COMPLETE (A-082..A-090). Seat gate exact solo run 1: 607/1/2 of 610, sole failure J-022. Team-22 + team-23 leads spawned this tick (A-092/A-093), no 429. A-091 cherry-picked next in order.
- 2026-11-13 ~12:15 EST (keeper tick): A-091 BANKED (91 of 216, closure below) - seat gate exact on run 4 solo: 607/1/2 of 610, sole failure J-022 (runs 1-3: 606/2/2 each, named intermittents rotating - state_vault x2 then stream_async - logs preserved; A-083 pattern). Wave 11 stands 1 of 9.
- 2026-11-13 ~12:35 EST (keeper tick): A-092 BANKED (92 of 216, closure below) - seat gate exact on run 2 solo: 607/1/2 of 610, sole failure J-022 (run 1: 605/3/2, both named intermittents, log preserved). Wave 11 stands 2 of 9. Team-23 / A-093: second lead also stopped incomplete (timeout, no commit, nothing new on disk); third lead restarted this tick with on-device source authoring (no whole-file transfer through tool calls). Seats team-24 and team-25 CREATED from banked main (92 of 216) this tick: team-24 A-094 (NPU-shaped ops analysis), team-25 A-095 (NPU offload #1, preparatory only until A-094's candidate table lands).
- Teams 26-27: not yet created; muster 2-3 per tick in order on later ticks.
- Note: the 9-team layout text above is the original Wave 1 layout and is superseded by this expansion for team count; slice order and banking rules are unchanged.
