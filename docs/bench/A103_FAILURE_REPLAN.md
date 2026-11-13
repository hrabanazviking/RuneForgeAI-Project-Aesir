# A-103 — Mid-run device failure re-planning

Slice A-103 (Wave 12, Heterogeneous scheduling). A device
error during generation re-plans the remaining work onto
the survivors. Acceptance: injected failure drill passes
(extends A-079 to the planner level). **Verdict: PASS —
the drill completes on the survivors with final tokens
exactly equal to the uninterrupted control for GPU-loss
and NPU-loss injections; fail-closed paths (no survivor,
second failure, mis-targeted drill) all hold the committed
prefix intact** (suite cases replan.* in
tests/test_failure_replan_a103.mojo; standalone check
A103_CHECK 7/7, log hidden_files/a103/standalone_check.log).

## What was built

`aesir_engine/core/failure_replan.mojo`: a pure re-planner
over the banked A-100 planner. A generation is a
GenerationPlan (one PlannedStep per step). On a device
error, `replan_remaining` re-decides every uncommitted step
through `plan_op` on a survivor registry — the A-009
registry with the failed runtime marked absent (GPU loss
removes HIP + Vulkan, NPU loss removes XRT, CPU loss
removes the CPU). The A-079 recovery laws, restated at the
planner level:

1. The committed prefix is never consulted or altered; the
   in-flight step of the failure is discarded and re-planned.
2. The failed device gets no further work: the survivor
   registry cannot place on it, and the re-planner refuses
   any decision that still names the failed class.
3. One re-plan per run: a second failure after a re-plan
   ends the run FAILED_CLOSED, prefix intact (the planner
   form of A-079's single-failover law).
4. A remaining step no survivor can take (DEVICE_NONE)
   fails the re-plan closed, naming the step.
5. NPU decisions made by a re-plan keep their A-099 CPU
   fallback in the decision record; an NPU failure degrades
   through the ordinary planner rules on the survivors
   (the A-098 optimum among survivors wins).
6. Every re-planned step appends one audit line (old -> new
   placement, error named); the audit is capped at 128
   lines with an explicit truncation line.

Requests carry their A-076 governor context in their flags
(power_capped / overlap_available); a re-plan re-decides
with the same flags the original plan used.

## The injected-failure drill

`run_failure_drill` executes a plan through the shared
deterministic step function (the A-066/A-079 greedy
discipline: every device path produces the same token for
the same committed prefix). The named device errors BEFORE
its step commits; the tail is re-planned; execution resumes
on the survivors. Graded assertions (all in the suite
cases):

| Drill | Injection | Result |
|---|---|---|
| GPU loss | VK_ERROR_DEVICE_LOST at step 2 of 6 | completes; tokens == control exactly; 0 steps on the failed GPU after the loss; audit covers steps 2..5 |
| NPU loss | KERNEL_TIMEOUT at step 0 of 3 | completes; tokens == control exactly; capped + overlap prefill move NPU -> GPU/Vulkan (the A-098 survivor optimum) |
| GPU re-plan (unit) | loss after 1 commit of 6 | attention + decode GEMV spill GPU -> CPU (moved == 2 exactly); capped prefill stays on the NPU survivor with its A-099 fallback named; sampling / small GEMM unmoved on CPU |
| CPU loss | CPU_FAULT on an embedding-lookup step | FAILED_CLOSED (no survivor: plan_op returns DEVICE_NONE); 0 tokens committed by the drill |
| Second failure | GPU loss at 2, CPU_FAULT at 4 | FAILED_CLOSED; committed prefix == first 4 control tokens exactly |
| Mis-targeted drill | named device does not own the fail step | FAILED_CLOSED, named as mis-targeted |
| Edges | failure after final commit; invalid completed count; survivor registry shape | NO_REMAINING; FAILED_CLOSED; only the failed device changes in the survivor registry; the original registry is not mutated |

## Honesty bounds

This module decides and re-decides; it does not execute on
any accelerator, and this slice makes NO new device-
execution claim. The drill's equality claim is over the
deterministic step model (the campaign's A-066/A-079
modelling discipline), graded on the re-planning
arithmetic: survivor placement, prefix integrity, and
exact token equality with the uninterrupted control. The
live-device device-lost proof remains A-079's (the real
A-013 shim forced-failure on RADV); A-103 extends its
contract to the planner level, as the roadmap names it.
Every placement the re-planner makes is an A-100 decision
from the banked measured tables (A-094/A-096/A-097/A-098),
with the A-099 fallback contract and the A-017 delegate
unchanged.
