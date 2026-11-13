# CAMPAIGN_STATE - team-27 (Aesir Z13 forge)

- Team: team-27 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-27, branch yrsa/aesir-team-27
- Base: 2bddc175 (banked main, 101 of 216, A-101 closure;
  ls-remote verified by the keeper). Branch reset --hard onto
  the base before building; A-102 (seat-only) not based on.
- Assigned slice: A-103 - Mid-run device failure re-planning
  (Wave 12, Heterogeneous scheduling). Acceptance: a device
  error during generation re-plans remaining work onto
  survivors; injected failure drill passes (extends A-079
  to the planner level).
- Status: A-103 DONE 2026-11-13 (see outcome below).
  Committed on the team branch only; the keeper banks at the
  seat in roadmap order after A-102. Never merge or push
  from this worktree. Never touch README.md. No Docker, ever.
- Suite baseline on this base: 619 passed / 1 failed /
  2 skipped / 622 total; sole failure pre-existing
  gguf.tensor_directory_interface (J-022); known
  intermittents: resilience.state_vault_rejects_growth,
  gpu.amd_hip_stream_async_round_trip,
  gguf.weight_residency_gpu_visibility,
  memory.budget_live_meminfo_pressure.
- Raw-oracle discipline for all correctness work;
  accelerator-visible is not accelerator-run - every
  accelerator claim needs device-execution evidence on the
  real XDNA 2 / gfx1151. This slice makes NO new device-
  execution claim (see outcome).

## Team-27 outcome 2026-11-13 - A-103 DONE (PASS, filed)
- 6 Mythic Engineering sub-agents mustered, no rate limit
  (planner analyst, fault-injection designer, raw-oracle
  reviewer, API designer, bench/evidence designer,
  regression hunter; their checklists shaped the build).
- Built on banked surfaces only: A-100 placement planner
  (plan_op), A-079 device-lost laws restated at planner
  level, A-099 NPU fallback contract, A-017 policy delegate
  (unchanged, inside plan_op), A-086 winner registry (via
  the planner's GPU backend rule), A-076 governor context
  carried in request flags. A-102 spillover NOT depended on.
- Deliverable: aesir_engine/core/failure_replan.mojo -
  GenerationPlan + survivor_registry + replan_remaining +
  run_failure_drill. Laws: committed prefix untouched;
  in-flight step discarded and re-planned; failed device
  gets no further work (survivor registry + refusal guard);
  one re-plan per run (second failure fails closed);
  DEVICE_NONE fails closed naming the step; bounded audit.
- Drill evidence: standalone A103_CHECK 7/7 (exit 0).
  GPU loss (VK_ERROR_DEVICE_LOST @ step 2/6) completes with
  tokens == control exactly, 0 steps on the failed GPU
  after the loss; NPU loss (KERNEL_TIMEOUT @ 0/3) completes
  exactly, prefill re-plans NPU -> GPU/Vulkan; GPU re-plan
  moved == 2 exactly (attention + GEMV spill to CPU, capped
  prefill stays on the NPU survivor with its A-099 fallback
  named); CPU-loss / second-failure / mis-targeted drills
  all fail closed with the prefix intact.
- Suite (solo, after the A-102 seat gate finished):
  626 passed / 1 failed / 2 skipped / 629 total, read from
  hidden_files/a103/team_suite.log (sha256 9126ed7a...);
  sole failure J-022, no intermittent fired; all 7 new
  replan.* cases PASS; finish pin 622 -> 629.
  GREEN-TO-BASELINE.
- Bugs found/fixed in-slice: (1) my test asserted moved>=3;
  the correct count is exactly 2 (sampling/small GEMM were
  already CPU, capped prefill already NPU) - assertion
  fixed to moved == 2 with reasoning in the test. (2) List
  fields are not ImplicitlyCopyable - the three List-bearing
  structs are Copyable-only with .copy() constructors
  (A-079 pattern). No engine bug found.
- Evidence: hidden_files/A103_LEDGER.md +
  docs/bench/A103_FAILURE_REPLAN.md +
  hidden_files/a103/standalone_check.log +
  hidden_files/a103/team_suite.log.
