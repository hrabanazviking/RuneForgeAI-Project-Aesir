# A-102 Ledger - Spillover policy

**Slice:** A-102 (Spillover policy), Wave 12 - Heterogeneous
scheduling. Team-26 worktree /home/volmarr/aesir-team-26, branch
yrsa/aesir-team-26, base 1a611172 (banked main, 99 of 216,
seat == ls-remote verified by the lead before building).
Lead + 6 Mythic Engineering sub-agents, no rate limit.

**Roadmap acceptance:** "Capacity pressure spills accelerator
-> CPU per the accelerator-first law, in the open. Acceptance:
oversized-model run (A-049 fixture class) places layers per
policy with the placement logged and reproducible."

## Files

| File | Role |
|---|---|
| `aesir_engine/core/spillover_policy.mojo` | New module: LayerSpec, PlacementPlan, plan_spillover / plan_spillover_live, fnv1a64 log digest. Whole-stack pre-dispatch placement on the banked A-076 GpuPressureGovernor (reused, not re-implemented). |
| `aesir_engine/tests/test_spillover_policy_a102.mojo` | 7 E-MASTER cases (sched.spillover_*). |
| `aesir_engine/tests/bench_spillover_a102.mojo` | Standalone oversized-model run (5 legs). |
| `aesir_engine/tests/run_all.mojo` | +7 cases registered; finish re-pinned 610 -> 617 with the house re-pin comment (union reconciles at banking with A-100/A-101). |
| `docs/bench/A102_SPILLOVER_POLICY.md` | Bench doc with measured results. |
| `hidden_files/run_a102_bench.sh` / `run_a102_suite.sh` | Runners (6-shim staging, gfx1151; fixture sha pinned before/after). |
| `hidden_files/a102_bench.log` / `a102_run_all.log` | Raw evidence logs (on disk; log files are git-ignored in this repo). |

## Policy (as built)

Accelerator-first in stack order (A-017 order; accelerator tier
= A-086 winner, Vulkan/RADV). Fits the room -> GPU
(ACCELERATOR_FIRST). Spillable overflow -> CPU inside the
bounded spill ledger (CAPACITY_SPILL). Non-spillable overflow
or spill past the cap -> whole-plan MEM-003 refusal, simulated
on a scratch governor so a refusal places nothing and moves no
ledger (atomicity is case-proven). Assist door: CPU placement
without capacity pressure only for a layer marked
assist-eligible WITH measured evidence (ASSIST_MEASURED,
charged to the same bounded CPU budget); an unproven claim is
ignored (case-proven). Placement log: header with the exact
inputs, one line per layer, totals footer, FNV-1a digest -
pure function of its inputs.

## A-100 dependency (honest)

A-100 Placement planner (team-27) was building in parallel and
had NOT landed on banked main at build time. A-102 implements
the spillover policy against the banked A-076/A-017/A-086
surfaces only and duplicates no planner work. Integration
point named in the module header: the planner hands an ordered
layer stack + capacity figures to plan_spillover and consumes
PlacementPlan (entries + digest) unchanged.

## Fixture (verified)

Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf, 4,920,739,232 bytes,
292 tensors, 32 layers, sha256
7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c
== the A-067/A-081 pin; verified by the lead directly and by
the bench runner before AND after the run (identical). Read
read-only from the seat fixture path.

## Bench results (hidden_files/a102_bench.log, RUN_EXIT=0)

- Device: Vulkan vendor 4098 (0x1002), type 1, RADV identity
  true - real gfx1151 execution, llvmpipe refused by identity.
- Layer table (loader byte math) sums exactly to the payload
  total 4,912,898,304 bytes.
- Oversized plan (gpu_cap 1 GiB, live avail 127,842,103,296 /
  total 130,454,048,768): GPU 973,963,264 bytes / 6 layers
  (embed + blk.0..4), CPU spill 3,938,935,040 bytes / 28 layers
  (blk.5..31 + output); strict prefix split (bench-asserted).
- Reproducible: identical inputs -> byte-identical log, digest
  3486865965604444507 twice.
- Execution: GPU layer embed span 295,501,824 bytes copied into
  a RADV Vulkan buffer, read back through the device mapping,
  FNV-1a 3509279304991363980 == source; freed to shim baseline.
  CPU layer blk.5 span 122,716,160 bytes, host checksum
  1228005872102039465.
- Roomy control (16 GiB cap): all 34 layers GPU, digest
  3342200304612901917 - spill only under pressure.
- Bench wall 42.26 s, peak RSS 538,864 KiB.

## Suite (hidden_files/a102_run_all.log)

E-MASTER: 614 passed / 1 failed / 2 skipped / 617 total =
baseline (607/1/2/610) + the 7 new cases, all PASS. Sole
failure: pre-existing gguf.tensor_directory_interface (J-022
drift, roads A-165/A-121). No intermittent fired. Concurrency
discipline kept: bench and suite each launched only after ps
showed no other team's suite/seat gate running (team-25 and
team-27 suites were waited out).

## Bugs

None discovered in banked code. One in-slice design correction
before first compile: the refusal path originally accumulated
partial totals/lines while simulating; fixed to reset to
header + refusal line so a refused plan records no placement
(the atomicity the acceptance requires), then case-proven.
Two deprecation warnings (positional __getitem__ on the device
pointer in the device-execution case) match existing repo
idiom; no functional impact, not chased out of scope.

## Banking

Committed on the team branch only, subject "A-102: Spillover
policy". Never merged or pushed. Keeper banks after A-100 and
A-101 in roadmap order.
