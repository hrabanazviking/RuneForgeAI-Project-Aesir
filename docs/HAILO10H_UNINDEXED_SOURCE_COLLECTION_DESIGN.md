# Ordinary unindexed weight file and config connection

Date: 2026-10-20. Task: `TASK_hailo10h_unindexed_source_collection.md`.
Owner scope remains `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
No model index/manifest, source conversion or outside compiler is required.

Expose read_unindexed_source_collection(root,weight_label,config_label,
root_policy,config_policy,fd_policy,collection_policy) and a native inspector.
The labels identify ordinary files beneath an opened root, with no suffix/
vendor catalog/name-pattern eligibility filter. The existing format/header
parser establishes current source container/dtype metadata; missing source
format/dtype/architecture coverage remains implementation work.

Return a distinct owned unindexed collection containing root/config/shard
metadata, aggregate counts and explicit absent-index provenance. Do not fill an
index-shaped record and pretend it came from a model file. Inspector fields
must state index_present=false and index_tensor_binding_verified=false, alongside
semantic/identity/fit/execution false flags. Actual header-derived names/axes/
spans are retained without invented canonical aliases or architecture defaults.

Reuse consumed positional JSON and source-header readers, owned root admission
and the tagged source projection. Factor shared configuration/shard admission
and aggregate policy helpers with the indexed loader; preserve its public API,
complete output and exact matching behavior. Every file/root closes on success/
error; no source mapping or tensor payload/model evaluation is introduced.
No phantom index lookup/open or user-generated index file is permitted.

The result has exactly one admitted source shard, which may contain zero or
more current-format tensors. Metadata bytes = config bytes + source prefix/
header bytes. Logical work = metadata bytes + one source label + actual tensor
count + sum(ranks), with no charge for nonexistent indexed entries. Positive
aggregate shard/tensor/metadata/payload/work and underlying root/config/header
policies remain caller-supplied and checked before growth. The whole actual
payload span is counted, not evaluated or certified as hardware memory fit.

Independent fixtures compare full tagged storage/config to indexed loading of
the same actual files and separate existing source readers. Cover scalar/empty/
full-rank/current dtype inputs, Unicode/NUL original tensor names and Unicode
file labels, arbitrary config raw modifiers, copied ownership, exact policies,
missing/malformed/special/escaping inputs and repeated/late cleanup. Traces prove
only real config/weight files open, no index attempt, source mmap/payload read or
device access. Regress indexed and shared readers after helper factoring.

After verified publication, continue the source-neutral semantic/storage/config
adapter audit and implementation under its parent. All broad model families,
formats/operators and actual numerical Hailo precision/packing/placement/program
encoding/upload/result/cleanup remain required. This direct ordinary-file
loader is a source input connection, never source-model execution completion.
