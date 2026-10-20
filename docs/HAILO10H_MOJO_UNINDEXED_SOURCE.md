# Ordinary single source file and config without an index

Date: 2026-10-20. Design published before code atf69b498:
`HAILO10H_UNINDEXED_SOURCE_COLLECTION_DESIGN.md`; task
`TASK_hailo10h_unindexed_source_collection.md`. Broad model target unchanged.

## Original connected implementation

`read_unindexed_source_collection` now consumes an ordinary root-relative weight
file label and config label plus explicit policies. It opens actual root/config/
source fds and reuses consumed positional JSON/header readers, owned raw config
values and full tagged storage. No generated or supplied index is required.
File labels have no suffix/vendor-catalog pattern filter; the source header
establishes current format admission. The inspector reports index_present=false
and index_tensor_binding_verified=false; it never invents an index-shaped file
record. Semantic/fingerprint/fit/execution flags stay false.

A distinct move-only SourceUnindexedCollection contains config and one admitted
SourceShardFile, original names/full axes/type namespace/path/spans, metadata and
aggregate counters. Configuration/shard loading and policy helpers are shared
with indexed loading, preserving that API/output and strict matching behavior.
All source/config/root descriptors close before a successful result. Source
mappings, payload reads, numerical operations and remote model code are absent.

Positive root/config/header/collection policies remain explicit. Unindexed
metadata bytes = config bytes + source prefix/header bytes. Work = metadata
bytes + one source label + actual tensor count + sum(ranks). There is no charge
for nonexistent indexed entries. Empty tensor collections remain descriptive
metadata. Caller caps and actual source extents are checked; no immutable
identity, memory fit, source architecture or device program is inferred. Current
ARM64/F16/BF16/F32 admission is implementation coverage, not permanent eligibility.

## Independent verification

Four new methods pass178 native calls (135 accept,43 expected refusals).
Thirty seeded plus explicit scalar/empty/full-rank/current-type fixtures and
Unicode/NUL names/Unicode file labels preserve complete storage/config fields.
Two independently loaded results do not share mutable metadata. Thirty-three
complete indexed output comparisons agree with the frozen pre-refactor binary;
unindexed source storage/config agrees with indexed loading of the same actual
files. Adding an unrelated malformed index does not affect direct file loading.

Exact aggregate/root/parser bounds and malformed/missing/special/escaping inputs
refuse. Traces prove exactly the real config/weight opens and closes, no index
attempt, source mmap/payload reads or device access. Twenty malformed-weight
loads interleaved with valid loads match all root/config/source close counts.
Read/changed-size/close faults on both actual input descriptors refuse and close
exactly once. Sources stay unchanged outside isolated synthetic fixture setup.
All new/refactored consumer builds are warning-free.

Rebuilt indexed tools/API pass5 methods/205 calls; seven unchanged shared reader
suites pass53 methods/1916 calls. Full slice: **62 methods/2299 native calls**.
No failed assertion or compile occurred. The legacy binary's already recorded
warning remains historical; it was not rebuilt/reclassified. Evidence/commands:
`evidence/unindexed-source-2026-10-20/`. No LLM/layer/attention forward, outside
compiler, source model download, special conversion or device write occurred.

Prior indexedf69b498 CI runs39467819097/39467769969 fail historical master
compilation; later gates skip. Current slice CI is observed after publication.
Repository consistency reports10631 diagnostics:534 baseline issues plus10097
literal paths in preserved new evidence, with no new production/test source
path issue or ledger-count mismatch named. No full repository pass is claimed.

## Next automatic connection

`TASK_hailo10h_semantic_storage_migration.md` returns to the graph consumers.
They still use GGUF-specific global file extents, columns/rows, numeric dtype
assumptions and canonical names. Safetensors cannot enter by casting those fields.
Complete tagged per-file/full-axis bindings and every affected consumer, then
ordinary config/architecture semantics and actual numerical Hailo execution.
The broad ordinary-model target stays fixed; these are verified input-loading
connections, not source-model execution completion.
