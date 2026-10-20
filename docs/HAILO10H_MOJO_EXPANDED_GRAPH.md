# Integrated expanded source graph

Date: 2026-10-19. Contract: `TASK_hailo10h_expanded_graph.md`.

`smidr/expanded_graph.mojo` now consumes the owned semantic source plan,
constructs its primitive recipes, and splices them into one deterministic
owned graph. All source tensors map to explicit global values. Every expanded
operation retains source operation/local recipe step, exact integer width and
epsilon bits, source weight name, and runtime preconditions. Remaining
unexpanded operations are still listed. The original source metadata/bindings
and standalone recipes stay owned by the returned graph, without file pointers.

Source weights become explicit global constant references. Matrix references
use logical [output rows, input columns], norm vectors use [width]; physical
packed kind/layout stays in the retained source binding. Each source name is
referenced once, including shared embedding/output weights. These are source
constant references, never activation allocations or a device packing recipe.
Real, predicate and index values are distinct. K/V append views keep explicit
aliases to whole-session persistent bases. Both residual chains and exported
logits retain their dependency edges.

Global producer and inclusive last-use indices are recomputed from the
expanded sequence. Constants and persistent K/V bases span the graph; exported
logits live through the end sentinel. The graph has 45 operations per layer
plus nine global operations for the currently expanded recipes. One default
layer has 54 operations and 70 values; tied-weight fixtures use one fewer
constant. The old source schedule's storage estimate is not reused.

The pass checks source/global/local mapping completeness, output uniqueness,
input availability, source lifetimes, shape products, constant extents/roles,
external index domains, persistent lifetime and cache view geometry. It emits
IR only, without a host arithmetic executor, model/layer forward or device API.

## Verification

Mojo 1.1.0 builds are warning-free:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/expanded_graph.mojo -o ../expanded-graph
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_expanded_api.mojo -o ../expanded-api
python3 tests/test_hailo_expanded_graph.py --binary ../expanded-graph --source-binary ../semantic-plan --recipe-binary ../primitive-recipes --api-binary ../expanded-api --strace /usr/bin/strace --evidence docs/evidence/expanded-graph-2026-10-19
```

Five methods pass, **45 native calls**: ten expanded graph inspectors, ten
source inspectors, ten standalone recipe inspectors, thirteen malformed API
refusals, one ownership check and one byte-identical deterministic rerun.
Independent checks translate every source and local edge to global IDs,
compare every constant binding/scalar/domain/shape, verify alias and residual
preservation, and brute-force recompute all last uses. They cover two layers,
prefill/decode/cached chunks, unequal value widths, tied/separate output weights,
non-default epsilon and a packed quantized-source fixture. No numerical model
or primitive math is evaluated by this integration suite.

Refusals cover invalid/duplicate outputs, unmapped/expired source inputs,
unknown external domains/index shapes, truncated persistent lifetimes,
self/oversize aliases, missing/out-of-range weights, orphan source tensors and
missing exports. The ownership test returns the graph across a function scope,
then independently mutates retained source/recipe metadata while global values
remain unchanged. Every source fixture hash is unchanged. The read-only trace
contains no Hailo node or CUDA/HailoRT access. Evidence:
`docs/evidence/expanded-graph-2026-10-19/`.

## Open gates

Executable/device/fingerprint and recomputed-expanded-storage flags remain
false. Runtime preconditions are retained obligations, not values already
validated on Hailo. The pass does not select precision, unpack/convert weights,
normalize source layout/RoPE, place resources, emit CCWs or establish upload/
activation. Mathematical graph integration is not executable device lowering.
Next: checked storage accounting for this expanded schedule, with an explicit
predicate width and no charges duplicated for source constants or KV views.
Actual hardware resource and numerical acceptance remain separate gates toward
the same broad owner source-model/Hailo-10H target.
