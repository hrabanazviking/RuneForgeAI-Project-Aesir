# Native semantic frontend dependency audit and next contract

Date: 2026-10-20. Contract: `TASK_hailo10h_source_neutral_semantics.md`.
Controlling scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
This is an audit/design receipt, not new source-model execution evidence.

## Existing coupling established from project source

| Boundary | Current actual dependency |
|---|---|
| `semantic_plan.mojo:read_dense_semantic_plan` | Opens PackedGGUF, inventories it, validates Llama metadata/modifiers/types, derives dimensions and emits the whole mathematical graph in one routine. |
| `SemanticPlan.source` | Owns the current `SourceTensorInventory`; its bindings have columns/rows and an untagged GGUF source-kind integer, not a neutral storage descriptor. |
| Mathematical graph | Requires decoder dimensions, head/KV/key/value/rotary widths, source context, numerical parameters, layout annotation, embedding vocabulary and checked canonical weight names/shapes. Actual device layout/RoPE pairing remains an unresolved gate. |
| Matrix schedules / expanded storage | Call GGUF `packed_row_bytes(binding.source_kind,columns)`; source-kind numeric values are not interchangeable with safetensors dtype IDs. |
| Source byte tile / GGUF static readers | Require an actual PackedGGUF owner and compare its live bindings. A separately built safetensors inventory cannot be passed to them by relabeling names or dtype integers. |
| Safetensors inventory/static readers | Own full source axes and names, file spans and source dtype IDs; do not contain architecture, model config/index, canonical weight aliases or a semantic graph. |

These input readers are useful connected file primitives, but safetensors is
not yet connected to the semantic/expanded graph or matrix compiler. A model
configuration adapter and tagged storage/name provenance are still required.
The existing source layout annotation is preserved even when unfamiliar; it
must not silently become a supported physical layout during this refactor.

## Narrow first implementation contract: typed decoder parameters

Implement owned `DenseDecoderParameters` and a mathematical graph builder that
consumes those values plus the existing owned inventory/session extents. Move
GGUF metadata decoding/type/modifier validation into an adapter that constructs
the parameters. Keep `read_dense_semantic_plan` as the compatible GGUF entry
point delegating to that builder. Parameter fields include layers, hidden,
feed-forward, query/KV head counts, key/value/rotary dimensions, vocabulary,
source context, Float32 RoPE base/RMS epsilon and source layout annotation.
Retain the existing exact numerical parameter values and layout annotation.
No floating model math or device operation is performed.

Validate typed dimensions, products, finite/positive numerical parameters,
source-context/session bounds, embedding/vocabulary agreement and exact used
weight set independently of container parsing. Recheck descriptive inventory
shape/byte extents for direct typed callers; do not treat a mutable snapshot as
an immutable backing-file certificate. Canonical graph names, tied-output
behavior, operation order, indices, every shape/producer/last-use/cache alias,
weights and unresolved gates must remain identical for existing valid GGUF
fixtures. Keep known/unknown metadata semantics and field-type checks in the
GGUF adapter, including scaled-RoPE/extra-weight refusals. An unfamiliar source
layout annotation must retain the existing unresolved gate, not be erased.

This first phase separates configuration parsing from graph construction. Its
storage inventory remains explicitly GGUF-specific. Do not claim it connects
safetensors semantics or migrate dtype integers into the wrong namespace.
The following phase must establish tagged storage/full shape/original name
provenance and ordinary config/index/weight aliases from licensed public field
facts before a safetensors semantic adapter is implemented. Other architectures
need their actual operation semantics; no recipe-name relabeling is sufficient.

Verification: direct typed API positive/negative/owned cases; independent exact
complete-graph comparisons between compatible GGUF entry point and typed builder;
existing semantic/primitive/expanded/storage/matrix/tile regressions using only
synthetic host structures. No CPU/CUDA/cloud model/layer/attention forward,
external compiler, specially compiled model or guessed numerical program.
Publish verified narrow code and continue actual Hailo encoding, configuration,
precision/packing/placement/transport/result dependencies alongside frontend
breadth. The owner's broad ordinary-model target is unchanged.
