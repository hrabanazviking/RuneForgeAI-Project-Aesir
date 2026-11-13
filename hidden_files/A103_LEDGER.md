# A-103 LEDGER — Mid-run device failure re-planning (team-27)

- slice: A-103 (Wave 12, Heterogeneous scheduling)
- date: 2026-11-13 (EST), host: purpleraider (ASUS ROG Flow Z13, gfx1151 / XDNA 2)
- team: team-27 (1 lead + 6 Mythic Engineering sub-agents, all mustered, no rate limit)
- worktree: /home/volmarr/aesir-team-27, branch yrsa/aesir-team-27
- base: 2bddc175 (banked main, 101 of 216, A-101 closure; ls-remote verified by the keeper)
- A-102 NOT based on (seat-only at build time; union reconciles at banking, per precedent)

## Claim under test
A device error during generation re-plans the remaining work onto the
survivors (roadmap A-103 acceptance; extends A-079 to the planner level).

## Built
- aesir_engine/core/failure_replan.mojo — pure re-planner over the banked
  A-100 placement planner: GenerationPlan / PlannedStep,
  survivor_registry (failed runtime marked absent; GPU loss removes
  HIP+Vulkan, NPU loss removes XRT, CPU loss removes CPU),
  replan_remaining (committed prefix untouched, in-flight step discarded
  and re-planned, failed class refused, DEVICE_NONE fails closed,
  bounded audit AUDIT_MAX=128), run_failure_drill (injected failure,
  deterministic A-066/A-079 step model, second failure fails closed).
- aesir_engine/tests/test_failure_replan_a103.mojo — 7 cases (replan.*),
  standalone main prints A103_CHECK 7/7.
- run_all.mojo: +7 cases registered, finish pin 622 -> 629.
- docs/bench/A103_FAILURE_REPLAN.md — bench/evidence doc.

## Drill evidence (measured, from logs)
- Standalone: A103_CHECK 7/7, exit 0
  (hidden_files/a103/standalone_check.log sha256 c4a2680aa4650364f58d707cf2571b538310d1d00864f53667f19f39a5081d05)
- GPU loss drill: VK_ERROR_DEVICE_LOST at step 2 of 6 — completes,
  tokens == uninterrupted control exactly, 0 steps executed on the
  failed GPU after the loss, audit covers steps 2..5.
- NPU loss drill: KERNEL_TIMEOUT at step 0 of 3 — completes, tokens ==
  control exactly; capped + overlap prefill re-plan NPU -> GPU/Vulkan.
- GPU re-plan unit case: moved == 2 exactly (attention, decode GEMV
  spill to CPU); capped prefill stays on NPU survivor with A-099
  fallback named; sampling / small GEMM unmoved.
- Fail-closed: CPU loss on embedding lookup (DEVICE_NONE) — 0 tokens;
  second failure — prefix == first 4 control tokens; mis-targeted
  drill fails closed; invalid counts fail closed; failure after the
  final commit is NO_REMAINING.

## Suite (E-MASTER, solo on purpleraider, seat gate A-102 finished first)
- hidden_files/a103/team_suite.log sha256 9126ed7a83507460e27ffe78b6d755d577c39ffb9f62f153626dc4539840a3e8
- Counts read from the log: 626 passed / 1 failed / 2 skipped / 629 total.
- Sole failure: gguf.tensor_directory_interface (pre-existing J-022),
  signature unchanged. No named intermittent fired.
- Baseline on 2bddc175 was 619/1/2 of 622; 626 = 619 + 7 new, all 7
  replan.* cases PASS. Verdict: GREEN-TO-BASELINE.

## Bugs found and fixed in-slice
1. Test-design bug (mine, caught by the standalone run): the GPU-loss
   unit case asserted moved >= 3; the correct count is exactly 2 —
   sampling and the small GEMM were already on CPU and the capped
   prefill was already on the NPU survivor. Assertion corrected to
   moved == 2 with the reasoning recorded in the test. No engine bug.
2. Mojo conformance fix during build: List fields are not
   ImplicitlyCopyable — GenerationPlan / ReplanResult / DrillResult
   declared Copyable only with .copy() in their constructors
   (the A-079 ConversationState pattern).

## Honesty bounds
No new device-execution claim: the re-planner decides, it does not
execute on an accelerator. The drill grades re-planning arithmetic
over the deterministic step model (A-066/A-079 discipline); live
device-lost proof remains A-079's shim-level proof on RADV.

## Files
- aesir_engine/core/failure_replan.mojo (sha256 89b929ebd46da8357f7564b9710e68f579d995af2ace2ddf5b2c264ec88dc6a8 at install)
- aesir_engine/tests/test_failure_replan_a103.mojo
- aesir_engine/tests/run_all.mojo (pin 629)
- docs/bench/A103_FAILURE_REPLAN.md
- hidden_files/a103/standalone_check.log, hidden_files/a103/team_suite.log
- hidden_files/run_a103_suite.sh
