# CAMPAIGN_STATE - team-25 (Aesir Z13 forge)

- Team: team-25 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-25, branch yrsa/aesir-team-25
- Base: 1a611172 (banked main, 99 of 216, A-099 closure)
- Assigned slice: A-101 - Pipeline overlap. Prefill (GPU) in
  parallel with sampling prep (CPU) in parallel with NPU
  assist where enabled. Acceptance: timeline trace showing
  real overlap; end-to-end latency delta filed.
- Status: A-101 DONE 2026-11-13 (see outcome below).
  Committed on team branch only; keeper banks at the seat in
  roadmap order after A-100. Never merge or push from this
  worktree. Never touch README.md. No Docker, ever.
- Suite baseline on this base: 607 passed / 1 failed /
  2 skipped / 610 total; sole failure pre-existing
  gguf.tensor_directory_interface (J-022); known
  intermittents: resilience.state_vault_rejects_growth,
  gpu.amd_hip_stream_async_round_trip,
  gguf.weight_residency_gpu_visibility,
  memory.budget_live_meminfo_pressure.
- Raw-oracle discipline for all correctness work;
  accelerator-visible is not accelerator-run - every
  accelerator claim needs device-execution evidence on the
  real XDNA 2 / gfx1151.

## Team-25 outcome 2026-11-13 - A-104 DONE (MEASURED, filed)
- Slice: A-104 Big-model placement (Wave 12). Base reset --hard to 2bddc175 (banked main, 101/216). 6 Mythic Engineering sub-agents mustered (read-only recon: roadmap, fixtures, planner/governor APIs, bench history, suite, memory accounting), no rate limit.
- Verdict: PASS. Largest sha-pinned real fixture on the machine (Llama-3.1-8B Q4_K_M, sha256 7b064f58...557c, verified before/after; no larger real model exists, nothing downloaded) ran with a GPU/CPU layer split on the real gfx1151 (RADV STRIX_HALO): llama-cli -ngl 16, offloaded 16/33, Vulkan model buffer 2290.21 MiB / host 2395.10 MiB, KV 240 GPU / 272 CPU MiB (total exact 512 MiB), generation 28.2 tok/s vs CPU-oracle 20.7 tok/s, coherent 96-token continuation (coherence-graded; CPU oracle agrees ~40 tokens then diverges in wording, as expected).
- Built: core/big_model_placement.mojo (suffix split solver + full accounting, A-076 pressure budget verbatim, hard pool gate), 6 suite cases placement.big_model_* (all PASS both runs), finish pin 622 -> 628, bench doc docs/bench/A104_BIG_MODEL_PLACEMENT.md, ledger hidden_files/A104_LEDGER.md, logs hidden_files/a104/.
- Suite (solo, after seat_gate_a102 finished): run1 624/2/2/628, run2 624/2/2/628 - sole standing failure J-022 + one rotating named intermittent per run; green-to-baseline.
- Bugs fixed in-slice: initial prefix-fill plan convention contradicted measured executor buffers, solver rewritten to measured suffix convention; stray placeholder fn removed pre-compile; dead first re-run launch detected and relaunched via setsid, never claimed.
- Commit: see git log (subject "A-104: Big-model placement"). Team branch only; keeper banks in roadmap order.

## Team-25 outcome 2026-11-13 - A-101 DONE (MEASURED, filed)
- 6 Mythic Engineering sub-agents mustered, no rate limit.
- Prior lead cancelled with no commit and no A-101 files;
  worktree verified clean of partial WIP and redone cleanly
  on banked main 1a611172 (A-098 verified banked at the seat:
  825b947a plus closure 6e059359).
- Three-leg pipeline measured on device, 3 runs x 21 reps:
  overlapped wall 10,079 / 10,015 / 10,020 us median vs
  serial 18,961 / 19,145 / 18,900 us; end-to-end delta
  8,882 / 9,129 / 8,881 us (46.8 / 47.7 / 47.0 percent).
  Overlap wall tracks the longest leg (CPU sampling prep,
  about 10.0 ms); both device legs fully hidden under it.
- Timeline trace (run 1 rep 0): overlap npu 0.0 to 2,567.2,
  gpu 40.0 to 5,643.0, cpu 222.2 to 10,331.9 us; median
  pairwise overlaps positive for all pairs in all runs
  (NPU-GPU about 2.3 ms, GPU-CPU about 4.8 to 5.1 ms,
  NPU-CPU about 2.3 ms). Device end timestamps come from
  waiter threads on the Vulkan fence and XRT run (a main-
  thread wait-return draft was caught and fixed pre-filing).
- Correctness, every run: NPU exact vs CPU oracle (131,072
  elements, 0 mismatches, 0 sentinels, ert_cmd_state=4,
  checksum 2848816214485251074, device NPU Strix Halo);
  GPU GEMV max abs err 0.000035 (AMD Radeon 8060S Graphics,
  RADV STRIX_HALO); CPU prep checksum 3359139257229004943
  deterministic across all runs.
- Deliverables: core/pipeline_overlap.mojo (timeline model,
  acceptance predicate, plan gated on the A-095 dispatch
  with A-099 degradation); tests/test_pipeline_overlap_
  a101.mojo (6 cases, all PASS); run_all re-pinned 610 to
  616; doc docs/bench/A101_PIPELINE_OVERLAP.md; ledger
  hidden_files/A101_LEDGER.md; logs hidden_files/a101/
  (run{1,2,3}.log, a101_run_all.log sha256 14643ce4...).
- Suite (solo, ps-verified): 613 passed / 1 failed /
  2 skipped / 616 total; sole failure the pre-existing
  J-022 gguf.tensor_directory_interface. Green-to-baseline.
- A-100 dependency filed honestly: A-100 (placement
  planner, team-27) had NOT landed; the plan model uses
  only banked A-017/A-086 surfaces via the A-095 registry.
  No planner duplicated. Keeper reconciles the run_all
  union pin when banking A-100 then A-101 in order.
- Coordination: NPU via sudo -n only; RLIMIT_MEMLOCK
  untouched; no suite ran concurrently with another team.
- Commit: see git log on this branch, subject
  A-101: Pipeline overlap (hash in the keeper report).
