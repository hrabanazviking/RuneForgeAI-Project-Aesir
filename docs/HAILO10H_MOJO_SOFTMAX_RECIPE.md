# Stable last-axis softmax recipe

Date: 2026-10-19. Contract: `TASK_hailo10h_softmax_recipe.md`.

The original Mojo primitive pass now expands source softmax into five explicit
IR operations: last-axis maximum, broadcast subtraction, exponential, last-axis
sum and broadcast division. Reduction results retain the input rank with the
last axis replaced by one. Source operation/input/output IDs, all local shapes,
products, dependencies and lifetimes are preserved. No production arithmetic
executor, source-model forward or device call is added.

Each recipe now carries runtime preconditions. RMSNorm and SiLU require finite
inputs. Softmax excludes NaN and positive infinity, allows masked negative
infinity, and requires at least one finite input in each last-axis row. The
compiler has no runtime values to validate; these are explicit future device
runtime obligations. They are not asserted as already enforced. Shifted
exponentials are nonpositive for the declared mathematical domain.

## Verification

The same two native Mojo tools build warning-free. Run:

```sh
python3 tests/test_hailo_primitive_recipes.py --binary ../primitive-recipes --graph-binary ../semantic-plan --api-binary ../recipe-api --strace /usr/bin/strace --evidence docs/evidence/softmax-recipe-2026-10-19
```

Seven methods pass, **44 native child calls**: thirteen recipe inspectors,
thirteen source-graph inspectors, seventeen API refusals and one ownership
check. RMSNorm/SiLU structure, bindings, exact source epsilon bits, primitive
math and owned values are rechecked. Additional softmax checks cover exact
operations/edges/reduction shapes/preconditions/lifetimes, source operation
coverage, malformed weight/shape/lifetime, and cached-session last-axis sizes.
All fixture source hashes remain unchanged; the trace opens no Hailo node or
CUDA/HailoRT library.

Five tiny isolated primitive fixtures (112 scalars) pass against 80-digit
Decimal references: the prior three RMSNorm matrices and SiLU vector plus a
40-element softmax fixture. Softmax has eight rows of width five, negative
infinity masks, repeated/unequal values, finite logits from -1000 to +10000,
exact zero masked probabilities and row sums near one. The reference directly
uses high-precision exp(x)/sum(exp(x)), independently of max subtraction.
Test-only enforcement rejects NaN/+infinity/all-masked rows before evaluating
the tiny oracle. No model/layer/attention path is evaluated; synthetic inputs
are unrelated to source-model weights. Evidence:
`docs/evidence/softmax-recipe-2026-10-19/`.

## Scope and next work

The recipe is a mathematical expansion, not verified device numerics. Backend
precision, finite subtraction/reduction overflow, exp approximation/underflow,
division, special-value behavior, resource placement, CCWs and upload remain
open. Executable/device/fingerprint and recomputed-lowered-storage flags stay
false. Prior evidence is preserved under its original receipt and directory.

Next, merge the owned local recipes into the complete source graph, retaining
remaining operations and explicit source-weight/predicate references; recalculate
lifetimes and storage on that actual expanded schedule. Do not use the old
unexpanded schedule's peak as a complete lowered resource result. The fixed
source-model execution goal and all-Hailo LLM boundary are unchanged.
