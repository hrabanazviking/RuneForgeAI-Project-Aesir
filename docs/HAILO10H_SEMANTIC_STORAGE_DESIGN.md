# Tagged semantic storage migration contract

Date: 2026-10-20. Parent: `TASK_hailo10h_semantic_storage_migration.md`.
Owner scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
This is an implementation contract, not numerical execution evidence.

## Audited consumers and compatibility

The actual consumers are semantic_plan, primitive_recipes, expanded_graph,
expanded_storage, cache_layout, matrix_tiles and source_weight_tiles. The
storage_estimate pass consumes graph lifetimes and aggregate weight bytes;
it does not perform source dtype arithmetic. Tools serialize the old logical
projection. Direct typed decoder and matrix test constructors also construct
that projection. Source float/Q4/Q5/Q6 readers are explicitly GGUF-only live
readers and must retain that owner and dtype namespace. Their five-integer
result descriptors are not admissible standalone semantic source references.

Keep SourceTensorBinding's five-integer ABI as a **logical projection** for
existing diagnostics and GGUF-only static readers. Extend SourceTensorInventory
with a required canonical-name keyed owned storage descriptor map and a
path-keyed owned SourceFileExtent map. Each extent records format, actual
descriptive file size and data offset. Each SourceStorageTensor preserves the
explicit format/dtype namespace, original name/path, full source axes and axis
order. An alias provenance string records the adapter or caller declaration;
it is a declaration, not proof that an architecture recipe is correct.

An untagged projection alone must be refused at every semantic boundary.
Projection fields are rechecked against the tagged descriptor and per-file
extent on each use. Source-kind integers never select a namespace on their
own. This paired API avoids breaking the existing explicitly GGUF static
reader result ABI while requiring provenance in every compiler consumer.

## Exact APIs and checks

`SourceFileExtent(format,source_bytes,data_offset)` is Copyable/Movable.
Inventory adds `storage:Dict[String,SourceStorageTensor]`,
`files:Dict[String,SourceFileExtent]`, `alias_provenance:String` and
`SourceSemanticPolicy(files,tensors,rank,work)` with published finite positive
compatibility defaults. Bounds apply to the new semantic metadata work, not
retroactively to existing container parser admission. Descriptors remain mutable
snapshots; no file fingerprint/immutable identity is implied.

`append_source_storage(inventory,storage,aliases,provenance)` validates an
actual storage inventory and explicit canonical-to-original map, requires
complete one-to-one name coverage, rejects duplicate canonical/original names
within a backing file, and accumulates checked per-file sizes and weight bytes.
It does not guess names or architecture. A failed mutable append invalidates
the destination: construct privately and publish only after success. Existing
GGUF adapter supplies an explicit identity mapping from its live descriptors.

`validate_source_binding(binding,storage,extent)` verifies all tags, axes,
source byte arithmetic, per-file bounds and the exact logical projection.
`validate_source_inventory(inventory)` checks policy, complete paired key sets,
per-file format/name/span consistency, no overlap, aggregates and provenance.
Work charges files, tensors, axes and file-by-tensor validation plus span-sort
upper bounds before traversal/growth. Single-file source_bytes/data_offset
remain byte-for-byte compatible diagnostic summaries. Multiple-file
source_bytes is the checked sum of file sizes, data_offset is -1; neither is
used as a flat address space. Consumers use the selected file extent.

`validate_source_weight(inventory,name,columns,rows,vector)` checks the tagged
binding and its operation-specific logical role. GGUF fastest-axis-first [C]
or [C,R] maps to logical columns C/rows R. Preserve the historical GGUF
singleton vector/matrix view behavior while retaining its exact original rank.
Safetensors outermost-first [R,C] maps to logical columns C/rows R; vector [C]
is distinct from matrix [1,C]. No transpose, flatten or rank guess for other
source axes. Scalar/empty/higher-rank metadata remains representable by the
existing storage inventory; new operation views are implementation work.

MatrixSchedule retains its logical projection and selected extent fields for
compatibility and gains an owned SourceStorageTensor. Its validator dispatches
through the same tagged helper. Live GGUF tiles additionally require the gguf
tag and compare original name/path/full axes, live descriptor and live file
extent before any read. A safetensors schedule cannot enter a GGUF reader by
numeric dtype collision or canonical alias. Format-specific static readers
continue to require their actual live owner.

Every listed semantic consumer migrates in one code slice. Legacy JSON output
remains identical for GGUF fixtures; a separate tagged inspector exposes the
new provenance. The current dense decoder recipe remains explicitly GGUF
until an ordinary configuration adapter establishes all actual architecture,
bias/tie/rotary/window modifiers. Tagged standalone operation schedules can
be tested with explicit synthetic ordinary bindings without claiming a source
model adapter or numerical execution.

## Verification and next work

Freeze the nine pre-change graph/storage/cache/recipe/matrix/tile inspectors
under work/semantic-storage-baseline with hashes before edits. Compare complete
outputs across seeded GGUF fixtures, including singleton ranks, tied outputs,
all current source kinds, unfamiliar layout gates and varied sessions. Rebuild
and run every affected synthetic suite; never execute a model/layer/attention
forward. Add independent tag collision, multi-file overlapping-local-offset,
shape role, alias/name/path/extent/policy/overflow/mutation/owned snapshot tests.
Trace source access and retain failed evidence. Publish the verified slice and
continue ordinary architecture/config adapters and actual Hailo numerical
encoding, precision/packing/placement/upload/activation/results/cleanup.
Broad model support remains the fixed target; current unsupported work remains
open and neither metadata nor resource fit is numerical execution.
