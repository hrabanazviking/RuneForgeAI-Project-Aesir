# Next observed-input boundary: ordinary config and index metadata

Date: 2026-10-22. Exact native work order:
`TASK_hailo10h_sealed_source_metadata.md`. Previous native source ownership:
`HAILO10H_MOJO_SEALED_SAFETENSORS_SOURCE.md`, verified at3d3b3a4.

The next new Mojo leaf will keep a sealed observed-byte owner with the existing
SourceConfiguration or SourceShardIndex. It will reuse ONE existing JSON parser
and borrowed regular-byte reader, preserve raw fields/maps/unknown values and
recompute actual full-byte hash claims. The original fd closes before parsing;
no borrowed fd owner, duplicate, label reopen, mapping or old production edit.

The existing metadata reader's8192-byte requests and one EOF lookahead are
explicitly retained, separately from4096-byte copy/hash stages. Policies bound
actual extent before allocation; metadata reads progress or refuse and are
bounded by source_bytes+1 calls. Existing parsed work counters keep their scope.
A byte-owner field supplies cleanup; copied values can outlive close, new reads
must refuse. Global identity/semantic/physical/execution flags remain false.

Before production,666 source/snapshot identities,117 native controls and71
Python inputs/actual copies verify unchanged. A closed-owner move/cleanup probe
builds cleanly and remains unexecuted; it qualifies only type feasibility.
Evidence: `evidence/sealed-metadata-contract-2026-10-22/`.

This contract claims no production implementation, new capability, all-file
atomic snapshot, compiler-artifact binding, numerical device configuration or
source-model execution. Owned ordinary shards/compiler bindings, remaining
formats/architectures/operations and the actual physical numerical backend remain
required work toward the owner's unchanged broad100% ordinary-model target.
