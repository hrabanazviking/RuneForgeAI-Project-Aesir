# Tagged storage through native semantic consumers

Date: 2026-10-20. Contract: `TASK_hailo10h_semantic_storage_migration.md`.
Design published to both branches at `37fddac` before implementation:
`HAILO10H_SEMANTIC_STORAGE_DESIGN.md`. Owner scope remains
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. This slice verifies compiler input
and structure; numerical Hailo source-model execution remains unfinished.

## Implemented boundary

SourceTensorInventory now owns canonical-to-original SourceStorageTensor
provenance and a SourceFileExtent map in addition to the compatible logical
five-integer projections. Explicit aliases must completely cover each appended
storage inventory one-to-one. Original names, full source axes, axis order,
format/dtype namespace and actual descriptive file path/size/data offset survive.
No familiar-name or filename heuristic supplies a model architecture.

SourceSemanticPolicy has positive configurable files/tensors/rank/work bounds;
compatibility defaults are4096/1048576/64/134217728. New descriptor validation
charges n*(files+2*ceil(log2(n))+5)+files+sum(ranks), checked before traversal/
growth. These are semantic metadata work units, not measured CPU cycles or a
new bound on pre-existing container parser admission. Individual binding checks
admit the currently implemented one/two-axis operation views. Scalar, empty and
higher-rank source facts remain in the existing full-shape storage inventory;
their missing operation views remain implementation work toward broad support.

Every current semantic consumer now uses the tagged checks: dense graph,
RMSNorm recipes, expanded graph/storage, hypothetical storage, cache projections,
matrix schedules and live source byte tiles. Source dtype arithmetic dispatches
on the format tag. GGUF kind0 is F32; safetensors kind0 is F16. Safetensors [R,C]
gets logical rows R/columns C; its vector [C] differs from matrix [1,C]. GGUF
keeps exact fastest-axis-first axes and its historical singleton vector/matrix
view behavior. Per-file overlaps/names, safetensors complete payload coverage,
aggregates, paired key sets, aliases and mutable descriptive fields are checked.

Single-file source summary fields and existing GGUF JSON outputs remain
compatible. Multi-file summary size is the checked sum of file sizes and its
summary data offset is -1; it is never used as a flat address space. Matrix
schedules retain only the selected file's extent plus an owned tagged source
snapshot. Returned recipes and source byte tiles also retain owned provenance.
The live GGUF byte reader checks explicit tag, actual owner/path, original name,
full axes and descriptor/extent before copying bytes. Original GGUF-only floating/
Q4/Q5/Q6 readers keep their live owner and existing result ABI. No untagged
projection alone is an admissible semantic reference.

The new semantic_storage inspector exposes complete tagged metadata. Actual
indexed and unindexed owned file collections feed the append API under explicit
aliases in native acceptance checks. This is no ordinary architecture adapter:
configuration semantics are still required. The current complete dense graph
adapter remains the verified GGUF recipe. Standalone synthetic ordinary linear,
embedding and RMSNorm structures prove the migrated consumers accept their
actual tagged storage; they perform no numerical evaluation.

## Independent verification

Twenty-six final native executables build on Mojo1.1.0. The cache pair was
rebuilt cleanly after removing an unused local; final build logs are clean.
The new seven-method suite passes **312 native calls:270 accepted,42 refused**.
It includes **108 complete pre-change/post-change output comparisons** across
nine frozen inspectors and12 GGUF fixtures (216 of those312 calls). Original
binary hashes, final binary/source hashes and complete run records are retained.
Fixtures cover all current GGUF kinds, tied outputs, unfamiliar layout annotation,
varied sessions and exact original singleton source axes in separate role checks.

Independent ordinary fixtures cover F16/BF16/F32 namespace collisions, Unicode/
NUL/empty source names, explicit aliases, different shard-local offsets in
separate backing files, mixed formats, exact vector/matrix roles, per-file bounds,
coverage, duplicates, work boundaries, overflow, mutations and owned results.
Actual ordinary root/config/weight and index/config/shard reads connect to the
new binding boundary without an architecture assertion. Traces show no device
access or native inference library. Existing isolated constant oracles remain
static test-only representation checks under their already recorded licenses.

All affected compiler/static regressions also pass:

| Suite | Methods | Native calls |
|---|---:|---:|
| Existing source inventory |6|16|
| Semantic graph |9|56|
| Typed decoder |7|493|
| Hypothetical source storage |7|61|
| Primitive recipes |7|44|
| Expanded graph |5|45|
| Expanded storage |7|88|
| Matrix tiles |7|860|
| Source byte tiles |5|286|
| Cache layout |6|89|
| Floating constants |6|64|
| Q4 constants |8|57|
| Q5/Q6 components |7|88|
| New tagged semantic boundary |7|312|
| **Total** |**94**|**2559**|

Initial tuple-type syntax and move-only List iteration build errors are retained.
The first full run's six failures were old expected error-prefix assertions:
invalid descriptors now fail earlier with SourceInventory errors. Acceptance,
nonzero exit and empty-success-output requirements remain; the assertions now
recognize that checked boundary. The complete initial evidence is preserved.
New refusal checks additionally reject signal termination. No model/layer/
attention forward, outside model compiler, device numerical program or physical
resource qualification was run or claimed.

Repository consistency was already failing10631 issues at the pre-slice tree:
534 older repository/schema/interface/CI issues plus10097 literal machine paths
in preserved earlier receipts. New evidence is retained verbatim and may add the
same receipt-path diagnostics. Whole-repository CI remains separately red at
historical master compilation; targeted success does not imply a green master.
Final checker output reports11357 issues =10631 baseline +726 new receipt-path
diagnostics. No new production/test source-path or ledger-count diagnostics
remain; the ledger summary is synchronized. Output accompanies this receipt.

## Automatic next slice

`TASK_hailo10h_ordinary_semantic_adapter.md` now contracts ordinary configuration,
name/orientation/rotary facts and the exact native adapter design before code.
All actual modifiers, bias/tie rules, per-layer rotary/window/architecture facts
must survive. The existing SmolLM3 config must not be relabeled as an every-layer
RoPE Llama model. Broader source ranks/dtypes/operations and numerical Hailo
precision/packing/placement/instruction/configuration/upload/activation/results/
cleanup remain required work. No DFC, specially compiled model or outside
compilation machine is a product prerequisite. Broad model support is unchanged.
