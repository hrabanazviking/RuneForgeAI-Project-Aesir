# Explicit decoder graph policy: audited migration contract

Date:2026-10-20. Contract: `TASK_hailo10h_decoder_graph_policy.md`.
Prior layer intent is verified/published on both branches at `b30fdc9`.
Owner scope remains `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
No new model or numerical execution is established by this design.

## Actual audited dependencies

semantic_plan currently combines a GGUF recipe gate, parameter validation and
mathematical construction. Every layer emits rope_query/rope_key; the output
weight is selected from GGUF name presence. cache_layout additionally requires
k_rotary as the key-cache writer and validates its rope_key producer, key
projection and positions. A mask-only change to the graph would break that
consumer. Primitive/expanded/storage/matrix passes traverse actual graph edges,
producers and counts; expanded_storage's index-domain rule applies only when a
rotary/causal operation is present. No other production hardcoded rotary writer
or fixed decoder operation index was found by the current source search.

## Exact typed API and compatibility

Add owned Copyable/Movable DecoderGraphPolicy(rope_enabled:List[Int],
output_weight:String,provenance:String). SemanticPlan gains an independently
owned decoder_policy. Its general-purpose constructor retains an empty policy
placeholder, allowing existing standalone matrix/primitive test graphs; a
complete decoder builder and cache planner require a complete valid policy.

Expose build_decoder_semantic_plan(source,parameters,policy,query,past,capacity)
as the source-neutral typed mathematical builder. It validates the current
complete tagged SourceTensorInventory and DenseDecoderParameters, then exact
mask length=parameters.layers, integer0/1 entries, nonempty bounded provenance
and explicit nonempty output-weight identity. Bound mask/provenance growth using
the admitted source metadata policy and layer evidence before copying. Output
weight must exist and match hidden/vocabulary shape; all source weights must
still be consumed. Do not infer tied output from an absent name in this API.

Keep build_dense_semantic_plan and read_dense_semantic_plan as compatible GGUF
wrappers. Recheck their existing GGUF recipe/parameters before generating an
all-one mask and making the existing GGUF-only output selection. Delegate to the
new typed builder. Existing inspectors keep their schema/fields unchanged;
complete old GGUF output must remain identical. A separate explicit-policy
inspector/API can expose policy and graph together. The new API is not an
ordinary configuration adapter, source-layout proof or model eligibility test.

When a flag is0, omit both rotary operations and their result tensors. Consume
the actual unrotated query/key projection tensors in attention/cache append.
Retain positions for causal masking. Recalculate all IDs, producers, last uses,
cache aliases, expanded mappings/storage and schedule dependencies through the
existing construction machinery. Preserve source dimensions, numerical parameter
bits, output-weight identity, source layout annotation and unresolved gates.

Cache planning validates the owned explicit policy. Select k_rotary/rope_key
only for a rotary layer; select the direct k/linear projection for NoPE. Validate
append input identity and the proper writer's source projection, shape,
dependency and lifetime. Rotary writers retain their checked key/positions
operands. Direct writers require the actual checked key projection. Never infer
NoPE from a missing tensor name, silently fall back, or add a fake rotary node.
Value-cache behavior and relative address assumptions remain compatible. Reject
mutated mask/length/provenance, mismatched writers/projections/positions/shape/
producer/alias/lifetime and missing output bindings. Migrate graph and cache
consumers atomically; audit any additional affected client before editing.

## Source intent and remaining architecture work

A validated SourceDecoderLayers can supply the mask for the corresponding typed
recipe. Keep its whole owned config and all unresolved modifiers; extracting a
mask does not establish ordinary dimensions, aliases/orientation, component
pairing, bias/tie/window/scaling/norm/activation semantics. Direct synthetic typed
callers must label their provenance honestly. The actual ordinary model adapter
must earn every one of those facts before invoking a complete model recipe.
Other architectures/operations remain implementation work toward broad support.
No outside compiler, DFC, vendor artifact or special user conversion is required.

## Independent acceptance

Freeze current inspectors/binary hashes before code. Compare every field from
all-one GGUF graphs and all affected inspectors with frozen outputs. Independently
transform reference graph structure for varied masks, removing rotary nodes and
rewiring actual projections, then reindex producers/last-use/aliases and compare
complete output. This is a structural oracle, never a numerical model forward.
Cover all-rotary, all-NoPE, mixed/periodic masks, tied/untied explicit output,
GQA/head dimensions, sessions, tags/shards/axes and owned/mutated policies.

Verify actual cache key writers in both branches, exact append identities,
source input shape/dependency/weight checks, NoPE-relative addresses and refusal
of inconsistent state. Run all semantic/typed/recipe/expanded/storage/cache/
matrix/byte regressions using synthetic structures. No CPU/CUDA/cloud model,
layer or attention forward. Publish the verified slice, verify both remote heads
and automatically continue actual ordinary architecture adapters and numerical
Hailo encoding/configuration/precision/packing/placement/upload/activation/
results/cleanup toward the unchanged broad-model target.
