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
