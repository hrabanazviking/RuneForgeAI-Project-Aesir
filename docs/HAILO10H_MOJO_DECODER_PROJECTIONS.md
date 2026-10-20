# Owned ordinary source projection bindings

Date:2026-10-20. Task: TASK_hailo10h_ordinary_source_bindings.md.
Exact pre-code API/ownership/bounds contract and metadata narrowing were
published/verified on both branches at352d068:
HAILO10H_ORDINARY_PROJECTION_BINDING_DESIGN.md. Fixed broad owner scope remains
HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.

## Original Mojo implementation

smidr/decoder_projections.mojo exposes DecoderProjectionPolicy(source policy,
work,provenance), move-only SourceProjectionIntent, bind_decoder_projections
and validate_decoder_projections. It independently owns complete ordinary
architecture/layer/config intent, original per-file tensors and arbitrary
metadata, fully tagged canonical SourceTensorInventory, geometric key/value
widths, explicit output decision, unresolved notes, policy and work accounting.
No SemanticPlan or numerical program is returned by this component.

The initial ordinary projection role family maps model embedding/norm, optional
lm_head and nine per-layer attention/FFN/norm weights to their native roles.
Actual tags, dtype namespaces, original names/path/full axes/spans and source
metadata survive. Source files and global names remain distinct. Unknown roles,
source formats/ranks and heterogeneous head recipes raise named implementation
work; inputs remain owned and unchanged. These are current implementation gaps,
never permanent model eligibility rules. Bias/other role coverage remains work.

The adapter reuses the checked tagged source/view factories. It validates actual
embedding/vocabulary, vector norm and all per-layer FFN/projection shapes. Key
width comes from actual Q output/query-head division and the matching K extent;
value width independently comes from V output/KVheads. Output projection input
must match query_heads*value_width. It does not substitute hidden/head arithmetic
for actual projection shapes or overwrite unresolved source KV semantics.

Explicit tie=true selects embedding output. A separately present lm_head is
retained and flagged for unresolved duplicate-tied identity. Explicit tie=false
requires and selects the actual output matrix. Missing/null tying supplies no
output decision, even when a head file exists. No missing-name tie heuristic,
silent source-weight omission, source dtype cast or graph-semantic bypass occurs.
Complete source modifiers and rotary pairing/identity/numerical gates survive.

Projection work reserves128 units per9*layers+3 alias slots,8 per actual tensor,
1 per file, provenance UTF-8 bytes per file and all original name/path bytes.
Each per-file metadata entry and its decoded key/value bytes are charged before
iteration/copying. Counts/evidence/arithmetic are admitted before alias-table
allocation. Existing architecture/source/storage policies separately bound their
validation passes. Derived-field comparison precedes generic validation of mutable
returned source descriptors, preserving those bounds before new hashing/sorting.
Validation rederives the complete binding intent from owned original files and
architecture, comparing every derived decision, tag/axis/binding/extent/policy/
provenance/note. This does not establish immutable backing-file identity.

The native inspector reads actual indexed/unindexed ordinary root/config/header
collections through existing owned descriptors. Its binding API never reopens a
file, reads/maps source payload or accesses a device. A separate test route feeds
actual remotely fetched header snapshots with explicit reported extents and
REMOTE_METADATA_ONLY paths; it explicitly denies local-model admission.

## Acceptance

Seven new methods pass **115 native calls:50 accepted,65 expected refusals**.
Independent oracles compare complete original/canonical tagged bindings, actual
file extents/offsets, metadata/config retention and exact projection accounting.
Coverage includes36 seeded ordinary single/multiple files, mixed F16/BF16/F32,
query/KV/head/value differences, tied/untied/missing/null/duplicate output cases,
source orientation/rank/shape/role failures, exact/short/positive policies,
Unicode/NUL metadata,34 mutation/input refusals, independent owners and40
in-process invalid/valid source-binding cycles.

All326 actual pinned ordinary header tensors pass native role/shape/tag/span
binding, with128 key/value widths and explicit tied output. Only37760 header
bytes were fetched by four206 ranges; no source payload was downloaded or
model evaluated. The metadata-only route remains explicitly distinct from a
locally admitted model or full-file fingerprint.

Actual indexed/unindexed collection and late-output-refusal traces show no
source payload mmap, inference library or device access, with actual descriptor
cleanup. The initial indexed inspector accidentally supplied its file-count cap
to the index schema-field limit; that failure is retained. The corrected
inspector and final API rebuilds are warning-free; all115 final calls pass.

Five unchanged-source regressions pass31 methods/1053 calls: ordinary parameter
7/200, config6/190, layer6/199, graph policy5/152 and semantic storage7/312,
including108 complete frozen consumer comparisons. Source manifests prove old
implementation dependencies unchanged. Full slice: **38 methods/1168 native
calls**. Evidence: evidence/decoder-projections-2026-10-20/.
Whole-repository consistency and historical-master hosted CI are separate gates;
no CPU/CUDA/cloud model/layer/attention forward occurred. Consistency reports
16174 diagnostics:14923 baseline plus1251 new raw receipt-path diagnostics;
no new nonreceipt issue after normalizing shifted historical diagnostic lines.

## Next automatic work

TASK_hailo10h_ordinary_rotary_modifiers.md resolves actual ordinary source rotary
component pairing and remaining norm/activation/scaling/window/cache/training
modifier meaning, auditing the corresponding original mathematical operation
lowering before the complete source-to-graph bridge. Continue actual numerical
Hailo instruction/configuration/precision/packing/placement/upload/activation/
results/cleanup in the same fixed broad target. No DFC, outside compiler/machine,
user conversion or vendor-precompiled artifact becomes a prerequisite.
