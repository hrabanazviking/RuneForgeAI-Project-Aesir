# Actual indexed shard collection connection

Date: 2026-10-20. Parent contract: `TASK_hailo10h_shard_collection.md`.
Inputs now implemented: owned index/config metadata, actual model-root regular
fds, same-descriptor safetensors header inventory and tagged storage projection.
Fixed broad-model scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Next original implementation

Expose a native owned sharded-source collection API and inspector consuming a
model root plus relative ordinary index/config labels and explicit policies.
Labels are source metadata; this API does not ask users to generate a manifest,
convert weights or compile a model. Later importer dispatch must also cover
ordinary single-file/unindexed inputs and other formats; this indexed slice
must never become a permanent model prerequisite or architecture restriction.

Admit both JSON files through the existing owned root and consume those same
fds with exact bounded owned JSON bytes before calling the existing borrowed
index/config parsers. No lexical preflight followed by a pathname reopen.
Extend the metadata-file interface with positional owned-fd reads, native close
on success/error and exact extent/lookahead/recheck. Preserve existing path
reader callers/behavior and their fault evidence. Factor shared read arithmetic
where useful; do not duplicate JSON grammar. Keep original descriptive labels/
paths in the collection separately from immutable identity, which is not earned.

Enumerate distinct weight_map labels automatically in their first encountered
order, open each once beneath the same model-root fd, and consume it with the
new safetensors fd reader. No payload weights or source mapping are needed for
this storage metadata stage. Retain each shard's metadata in its own namespace.
Factor/reuse the existing safetensors-to-tagged-storage projection behind a
published interface so no path-based storage reader reopens the admitted file.
Keep source dtype IDs/container tags/full axes/span arithmetic unambiguous.

For every actual tensor, require an exact original index name mapped to that
same original label; reject missing/misdirected/extra actual names and duplicate
global names. Every indexed name must be present in its designated shard.
Do not guess architecture aliases, transpose axes or infer a missing output
weight from a familiar name. Tied-weight/rotary/window/bias semantics belong to
the later full config adapter, retaining all raw modifiers now. Compare optional
index total_size to the checked sum of actual tensor payload-byte extents,
excluding file prefixes/headers. Empty consistent collections are representable.

Use separate positive aggregate shard/tensor/metadata-read/payload-byte/logical-
work policies with checked sums before allocation/growth. Existing root attempt/
path/source extent and each JSON/header/storage parser policy remain explicit.
Work units must have a documented formula; do not describe them as CPU deadlines
or complete instruction accounting. Late mismatch/parse/admission errors close
every admitted descriptor/root without partial successful collection output.

## Independent acceptance

Tiny generated multi-shard/index/config fixtures cover reused labels, Unicode/
NUL tensor names, full axes/scalars/empties, all current floating source dtypes,
per-shard metadata collisions, totals and config raw modifier preservation.
Independently compare complete collection fields/spans to source headers and
existing storage output. Check missing/extra/misdirected/global duplicate names,
malformed late shard, index-size mismatch, root escape/special-file refusal,
exact aggregate policy edges/overflow, owned snapshots and repeated late-error
cleanup. Traces must show only actual JSON and referenced shard opens, same-fd
prefix/header reads, no source mmap/payload reads or device access.

Regress shared metadata fd/path readers and inventory/constants/tagged storage/
index/config/root after changes. No model/layer/attention forward, outside model
compiler, special conversion, catalog-only substitute, guessed device opcode or
model execution certificate. After publication, continue semantic storage/config
architecture integration and actual numerical Hailo execution under the same
broad target. This collection metadata gate is a required input connection,
never completion of that target.
