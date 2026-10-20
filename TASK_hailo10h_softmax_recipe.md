# Stable softmax primitive recipe

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`.

Extend the original primitive recipe pass to the source graph's last-axis
softmax. Emit max reduction, broadcast subtraction, exponential, sum reduction
and broadcast division with exact source IDs, local shapes/domains/lifetimes.
Carry explicit activation preconditions: no NaN/+infinity, at least one finite
value per row, with masked -infinity allowed. Runtime validation/enforcement
belongs to the future device implementation; a compiler recipe must not claim
it has checked runtime values that it has never received.

Use only standalone tiny probability-vector/matrix fixtures in test oracles,
including masked -infinity, large finite logits, repeated values and unequal
row shapes. Verify exact graph coverage, zero masked probabilities and row sums
against an independent high-precision reference. Do not execute source model,
attention/layer or CPU/CUDA/cloud LLM forward. Production remains Mojo IR
construction only. Preserve existing RMSNorm/SiLU evidence and regressions.

Numerical tolerance, finite-precision overflow/subtraction/reduction behavior,
exp approximation/underflow, division, actual device placement, CCW encoding,
upload and hardware result remain gates. Recompute storage after real recipe
integration rather than reusing the original schedule's hypothetical peak.
Publish verified changes and proceed automatically to the next source-model
compiler/device gap. Only the owner can revise the Hailo source-model target.
