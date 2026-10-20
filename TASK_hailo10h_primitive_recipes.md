# Source-operation primitive recipes

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`; owner target unchanged.

Consumer: an original Mojo compiler pass over the typed source semantic graph,
inspected through a native host tool and later consumed by actual device
lowering. Expand RMSNorm and SiLU into explicit arithmetic recipes without
executing a model or calling a CPU/CUDA/inference backend. Retain source
operation/input/output IDs, source weight bindings, scalar parameters, local
shapes, dependencies and local lifetimes. Keep unexpanded operations named.

RMSNorm recipe: squared inputs, last-axis sum, division by the exact integer
width, source epsilon addition, reciprocal square root, broadcast scaling and
source-vector multiplication. Epsilon retains its exact source Float32 bits.
This is the existing decoder's epsilon-inside-square-root mathematical contract.
Actual finite-precision overflow/rounding/reduction policy remains unresolved.

SiLU recipe: use exp(-abs(x)), reciprocal(1 + exp(-abs(x))) and a sign select
to form sigmoid before multiplication by x. This avoids requiring exp of a
large positive argument for finite x. Represent comparison results explicitly
as predicates. Backend precision, special values, underflow and approximation
policies remain explicit numerical acceptance gates, not guessed support.

Acceptance: structural independent checks of every recipe value, operation,
shape, source binding and lifetime; tiny standalone arithmetic fixtures only
for these primitives, including zero, mixed signs, large finite SiLU values
and non-default norm epsilon. Such test oracles never execute a full model,
layer or attention path. Production emits IR only, no host numerical kernel.
Test malformed graph/weight/shape/parameter refusals and ownership. Existing
storage estimates remain pre-recipe scenarios until recomputed for the lowered
schedule; do not reuse them as complete lowered resource qualification.

A mathematical recipe is not a chip opcode, CCW program, placed arena or
verified Hailo operation. No artifact submission until actual program encoding
and upload/activation are established. Continue that interface research under
the parent contract and preserve all negative findings and historical work.
