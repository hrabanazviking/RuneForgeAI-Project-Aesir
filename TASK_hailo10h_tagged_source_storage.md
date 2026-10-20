# Tagged ordinary-source storage and provenance

Date: 2026-10-20. Parent: `TASK_hailo10h_source_neutral_semantics.md`.
Facts: `docs/HAILO10H_SOURCE_STORAGE_PROVENANCE_AUDIT.md`.
Exact admitted GGUF axes are now verified in
`docs/HAILO10H_MOJO_GGUF_SOURCE_SHAPES.md`. Owner scope remains
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Consumer: native compiler input inspection and subsequent checked semantic
binding. Current SemanticPlan/MatrixSchedule still carry GGUF-specific
SourceTensorBinding, also used by cache/expanded storage and Q4/Q5/Q6 readers.
Changing its implicit-copy field layout without migrating those callers would
break ownership and silently mix namespaces. Audit all consumers before any
migration; preserve existing APIs and graph output in this bounded first phase.

Implement original owned full-shape storage descriptors over the existing live
PackedGGUF and SafetensorsLoader/read-inventory APIs. Keep explicit container
and dtype namespace together, original name, caller-provided backing file/path,
exact source axes/order, element count and absolute-in-file byte offset/count.
Retain file/data extents and safetensors string metadata separately from tensor
entries. Do not invent architecture, aliases or rotary layout from file kind.
Return independent copied values and close path-wrapper mappings on every path.
Keep GGUF declared fastest-axis-first values and safetensors row-major axes
explicit; no silent transpose, flattening, rank inference or numeric dtype cast.
Current parser dtype/rank coverage is incremental work, never a fixed target cap.

Provide checked descriptor arithmetic and file-span validation selected by the
container tag. GGUF uses the established packed-row/block rules and admitted
rank information; safetensors uses its own F16/BF16/F32 IDs and checked scalar/
zero-axis/full-rank products. Preserve scalar/empty semantics and exact source
names, including embedded NUL; path strings follow existing path admission.
Do not turn a descriptive path or mutable snapshot into a file identity proof.
Bound descriptor work/counts/ranks using explicit policies, reuse parser bounds,
and avoid adding an unbounded quadratic cross-check to a larger tensor catalog.
Check duplicate names, bytes/overflow/extents/overlap at the exposed boundary.

Connect the values to a native storage inspector for real ordinary-source
metadata, with an explicit output schema and false execution/fingerprint/fit
flags. Verify its GGUF projection against existing inventory and exact declared
shape APIs; verify safetensors fields against independent format fixtures and
existing inventory. No compiler/graph compatibility or architecture support
claim follows from a storage catalog alone. Existing graph/matrix/static readers
must not accept a safetensors descriptor by pretending it is GGUF. A full
semantic-storage migration and config/index/alias/orientation adapters follow
with their own complete consumer updates after established field facts.

Verification: independent exact per-format fields/byte arithmetic, collisions
where the same numeric dtype means different source widths, rank-one versus
rank-two GGUF, scalars/zero axes/arbitrary admitted safetensors ranks, all current
kinds, Unicode/NUL names, original path/name provenance, ownership and close/error
cleanup. Exercise bad container/dtype/shape/count/offset/overflow/overlap/bounds
and mutated direct inputs, with deterministic no-partial-result refusals.
Rebuild parser/inventory/source-shape/typed semantic regressions as applicable.
Use static synthetic bytes only, no CPU/CUDA/cloud model/layer/attention forward.
No external compiler, special user conversion, vendor artifact prerequisite,
guessed instruction/register, device write/reset or firmware/kernel change.
Publish verified original code then advance config/index/semantic integration
and actual numerical encoding/configuration/placement/upload/result work.
