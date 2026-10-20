# Source-bound primitive mathematical recipes

Date: 2026-10-19. Contract: `TASK_hailo10h_primitive_recipes.md`.

## Implemented compiler pass

`smidr/primitive_recipes.mojo` borrows the typed source semantic graph and emits
owned local arithmetic IR for RMSNorm and SiLU. It retains source operation,
input/output IDs, source norm weight name and exact binding, exact source
Float32 epsilon bits, integer normalization width, local shapes/domains,
dependencies, producer/last-use indices and an exported result. Other source
operations remain explicitly listed and unexpanded. No execution backend,
numerical kernel, model forward, source weight decoding or device API is called.

RMSNorm expands to seven operations: input product, last-axis sum, division by
the exact integer width, epsilon addition, reciprocal square root, row scaling
and source-vector scaling. This expresses epsilon inside the square root,
matching the existing project decoder semantics. It does not subtract a mean.
SiLU expands to nine operations using exp(-abs(x)), reciprocal(1 + that value),
a negative-input sigmoid branch, nonnegative comparison, selection and input
multiplication. For finite real inputs the exponential argument is nonpositive;
there is no exp of a large positive value. Predicates have an explicit separate
logical domain. Neither recipe selects hardware precision or an approximation.

Local value 0 references the source input; RMSNorm local value 1 references the
source vector. Remaining local values are operation results. Producer -1 means
an external reference. Lifetimes are inclusive operation indices, with
len(operations) retaining the exported result. Returned shapes/bindings are
owned values, independent of later mutations to the source graph.

The pass rechecks selected operation arity/IDs/dependencies, shape equality and
products, RMSNorm matrix rank/positive finite epsilon, source weight shape and
file extent, and the absence of a spurious SiLU source weight. Source graph
IDs remain references to the original compiler artifact; source identity is
still not hash-certified for a subsequent file reopen.

## Verification

Mojo 1.1.0 builds are warning-free:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/primitive_recipes.mojo -o ../primitive-recipes
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_recipe_api.mojo -o ../recipe-api
python3 tests/test_hailo_primitive_recipes.py --binary ../primitive-recipes --graph-binary ../semantic-plan --api-binary ../recipe-api --strace /usr/bin/strace --evidence docs/evidence/primitive-recipes-2026-10-19
```

Six methods pass, **39 native child calls**: twelve recipe inspectors, twelve
source-graph inspectors, fourteen malformed graph/weight/parameter refusals and
one direct ownership proof. Exact recipe kinds/edges, every shape/product/domain
and lifetime, remaining operation partition, source binding/epsilon bits,
multilayer sessions, unequal value dimensions and a quantized-source fixture
are checked independently. Every synthetic source hash remains unchanged.
A syscall trace shows read-only parsing without Hailo/CUDA/HailoRT access.

Four isolated tiny primitive arithmetic fixtures compare a test-only emitted-IR
interpreter with Python Decimal at 80 digits: three RMSNorm matrices and one
SiLU vector, 72 output scalars total. Weights/numbers are synthetic test values,
not source-model weights or activations. Large finite SiLU inputs include
-1000 and +1000. The interpreter evaluates only one primitive at a time. It
never follows model/layer/attention edges or executes a CPU shadow LLM. The
production binary emits recipes without evaluating arithmetic.

Evidence: `docs/evidence/primitive-recipes-2026-10-19/`.

## Open gates

These checks establish a mathematical expansion and compiler structure.
They establish no device numerical precision, tolerance, reduction ordering,
RMS square overflow behavior, rounding, denormals, special-value policy or
transcendental approximation. The Float64/Decimal primitive oracle does not
certify an fp16/int8 Hailo implementation. Quantized source vectors still need
an independently verified conversion/layout recipe.

All executable/device/fingerprint proof flags are false. The earlier storage
scenario covers the unexpanded schedule; `lowered_storage_recomputed:false`
prevents treating it as the complete lowered resource plan. Expanded schedule
placement, actual CCWs/register encoding, program upload/activation and real
numerical Hailo execution remain open. Next: stable last-axis softmax recipe,
then additional source primitives and actual hardware lowering toward the
unchanged broad source-model target.

## Mathematical provenance

Original graph construction uses mathematical definitions and the project's
own normalization convention. No external implementation or paper text/figure
is copied. Paper abstract definitions and arXiv distribution notices were read:
[RMSNorm, Zhang and Sennrich](https://arxiv.org/abs/1910.07467),
[SiLU, Elfwing, Uchibe and Doya](https://arxiv.org/abs/1702.03118).
