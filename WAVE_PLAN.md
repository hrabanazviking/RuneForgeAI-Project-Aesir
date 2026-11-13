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

- Banked: **81 of 216** (A-001..A-081). A-081 banked at the
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
  (A-073..A-081) is COMPLETE.**
- Seat gate after this banking: A-081 (seat_gate_a081.log, sha256 59f3d879...) 578 passed / 1 failed / 2 skipped / 581 total, EXACT, sole failure J-022 (the slice adds no run_all cases, pin unchanged), launched solo. Previous gate (A-080, seat_gate_a080.log): 578/1/2 of 581 exact, all 6 equivalence.* cases PASS. Previous gate (A-079, seat_gate_a079.log): 572/1/2 of 575 exact, budget_live PASS after the reorder fix (history in the A-079 PROJECT_MEMORY_MAP row). Previous gate (A-078, seat_gate_a078.log):
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
  bank (keeper flow): A-082 - next to bank (team-12 commit
  62de1014, HIP Q8_0 GEMV, already built and tested);
  A-083 (team-13 commit 0742431b) built and awaiting
  banking in order; teams 14+15 (A-084/A-085) muster next.
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
- Teams 14-27: not yet created; muster 2-3 per tick in order on later ticks.
- Note: the 9-team layout text above is the original Wave 1 layout and is superseded by this expansion for team count; slice order and banking rules are unchanged.
