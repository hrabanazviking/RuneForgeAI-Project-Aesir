# Complete tagged storage migration into native semantic consumers

Date: 2026-10-20. Parent: `TASK_hailo10h_source_neutral_semantics.md`.
Owner scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Inputs: actual indexed and unindexed owned source/config/storage collections.

Audit all actual source binding consumers and publish the exact typed API /
compatibility/migration plan before code. Current graph inventory is still
GGUF-specific: one global file extent, columns/rows, untagged numeric kind and
canonical GGUF names. Semantic/expanded graph, matrix schedules and storage
checks still use those assumptions or packed_row_bytes directly. New ordinary
collections must not enter that API by casting dtype IDs or relabeling fields.

Implement explicit original format/dtype/full-axis/original-name/backing-file
provenance at the semantic weight boundary and operation-specific checked logical
views. Distinguish source axes from logical matrix/vector dimensions; vector
[N] and one-row matrix[1,N] are different source facts. Per-file extents must
survive multi-shard input. Canonical semantic names need an explicit validated
mapping to original names, not a filename or familiar-name heuristic. Config
bias/tied/rotary/window/architecture facts cannot be defaulted or discarded.

Migrate every affected compiler consumer atomically through published helpers:
semantic graph validation, expanded graph/storage, matrix schedules and live
source byte tiles/static readers where applicable. Retain format-specific live
owners for actual source access; a tagged metadata snapshot is not a live file
or immutable source identity. Container-specific byte arithmetic must dispatch
on explicit tags, never pass safetensors dtype0 to the GGUF kind0 calculator.
Preserve the GGUF adapter's actual exact graph/lifetime behavior and explicit
unresolved layout gates; freeze pre-change binaries and compare complete fields.

Publish the exact narrowing after audit, then implement bounded original Mojo
changes with independent shape/axis/tag/alias/provenance/overflow/ownership/
refusal tests and every affected synthetic compiler regression. Do not run a
CPU/CUDA/cloud model/layer/attention forward. Existing GGUF behavior may remain
one verified recipe while ordinary config adapters earn their actual semantics;
this never reduces the full broad-model target or makes missing coverage a
permanent eligibility restriction. No vendor artifact/compiler prerequisite.

After this binding migration, implement ordinary architecture/config adapters
from established licensed facts, including all modifiers, and continue actual
numerical Hailo encoding/configuration/precision/packing/placement/upload/
activation/results/cleanup. Host graphs and resource fit are not model execution.
