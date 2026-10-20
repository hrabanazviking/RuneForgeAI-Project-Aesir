# SMIÐR source compiler boundary

`source_inventory.mojo` exposes move-only `SourceTensorInventory` and value
`SourceTensorBinding` descriptors. `read_source_inventory(path)` owns a bounded
read-only GGUF parse; `inventory_from_source(source)` borrows an existing live
parse. Only checked value descriptors escape. Neither verifies source identity
for subsequent reopening; hashing/revalidation is a later runtime requirement.

`semantic_plan.mojo` exposes move-only `SemanticPlan`, typed `SemanticTensor`
and `SemanticOperation` values, checked positive shape multiplication and
`read_dense_semantic_plan(path, query_tokens, past_tokens, context_capacity)`.
The current incremental importer constructs dense Llama decoder graph semantics
without importing a backend registry or invoking model execution. Other
architectures/modifiers are named importer work, never a hardware allowlist.

Linear source columns are input width, rows output width. Tensor lifetimes are
inclusive operation indices; -1 means external/preexisting storage and
len(operations) is the retained-output/session-end sentinel. Persistent KV base
tensors span the graph. Append views alias those bases and never own additional
storage. Query and KV heads, key and value dimensions and query/past/capacity
are distinct. Required runtime values/preconditions and unresolved layout,
RoPE, precision, quantization, resource and device-program gates must be carried
forward; the inspector reports each proof flag false.

These are host compiler structures, not executable programs or hardware fit
certificates. Do not pass their JSON or legacy COMPUTE_UNKNOWN/SMIDR-CFG
payloads to a device as compute. Evidence and complete limitations:
`docs/HAILO10H_MOJO_SOURCE_INVENTORY.md` and
`docs/HAILO10H_MOJO_SEMANTIC_PLAN.md`.

`storage_estimate.mojo` exposes `StorageAssumptions`, `StorageEstimate`, checked
byte arithmetic and `estimate_storage(plan, policy)`. The policy must explicitly
supply widths/alignment, aggregate device-weight/workspace bytes, budget and
provenance. Owning tensors are counted once; persistent aliases own zero bytes.
The returned timeline/peak is aggregate live byte volume, not a placed arena or
hardware fit certificate. There is no inference admission or allocation path.
See `docs/HAILO10H_MOJO_STORAGE_ESTIMATE.md` for exact interpretation and proof.

`context_actions.mojo` exposes a tagged, owned `ContextAction(kind, timestamp,
values)` and exact bounded `encode_context_action` / `decode_context_action`.
Kinds 0/3/27/35 only; field order, ownership, range checks and independent
public-header evidence are in `docs/HAILO10H_MOJO_CONTEXT_ACTIONS.md`. This byte
primitive is neither a CCW/numerical program nor an hRPC upload payload. No
device/syscall access or submission consumer exists in this codec slice.

`primitive_recipes.mojo` exposes `PrimitiveRecipes`, owned local
`PrimitiveRecipe`/`RecipeValue`/`RecipeOperation` values and
`lower_primitive_recipes(plan)`. RMSNorm and SiLU are expanded into mathematical
IR; untouched source operation IDs remain named. No production arithmetic is
evaluated. Exact source bindings/scalar bits, local reference conventions,
shape/lifetime evidence and unresolved device/precision/storage gates are in
`docs/HAILO10H_MOJO_PRIMITIVE_RECIPES.md`.

The primitive pass additionally expands last-axis softmax. Every recipe now
carries runtime preconditions; masked -infinity is allowed only with at least
one finite value per row and no NaN/+infinity. They are obligations, not already
validated runtime data. Current regression/softmax evidence:
`docs/HAILO10H_MOJO_SOFTMAX_RECIPE.md`. Expanded graph/storage integration is
contracted in `TASK_hailo10h_expanded_graph.md`.

`expanded_graph.mojo` exposes move-only `ExpandedGraph` owning the original
semantic plan/recipes plus global `ExpandedValue`/`ExpandedOperation` values.
`expand_semantic_graph(plan)` consumes the source plan, splices recipes into
global IDs and recomputes lifetimes. All weight constants are explicit and
deduplicated; predicates/index values and KV aliases are explicit. This is IR,
not device lowering or storage qualification. Complete conventions/evidence:
`docs/HAILO10H_MOJO_EXPANDED_GRAPH.md`.

`expanded_storage.mojo` exposes `ExpandedStorageAssumptions`,
`ExpandedStorageEstimate`, `validate_expanded_storage_graph` and
`estimate_expanded_storage`. Predicate width and all other byte assumptions,
aggregate pools/budget and provenance are explicit. Source constants/KV views
are not duplicate allocations. Exact global last uses and typed roles are
validated before checked event accounting. This remains a hypothetical live
byte volume, never hardware fit/admission. Evidence and complete limits:
`docs/HAILO10H_MOJO_EXPANDED_STORAGE.md`.

`source_float_constants.mojo` exposes move-only `FloatingConstantWindow`,
integer half/BF16-to-binary32 bit conversion, `read_floating_constants` over a
live PackedGGUF owner with an explicit host bound, and a path wrapper returning
only copied bindings/bits. This is source representation decoding, not device
precision/packing or numerical inference. Payload rules, exhaustive 16-bit
pattern evidence and identity/concurrency limits:
`docs/HAILO10H_MOJO_SOURCE_FLOAT_CONSTANTS.md`.
