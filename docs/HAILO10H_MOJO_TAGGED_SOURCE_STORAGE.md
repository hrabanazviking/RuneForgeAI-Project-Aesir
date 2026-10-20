# Tagged ordinary-source storage and provenance

Date: 2026-10-20. Published-first contract:
`TASK_hailo10h_tagged_source_storage.md` at `2df4e90`.
Controlling scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Connected implementation

Original `smidr/source_storage.mojo` connects the existing GGUF and safetensors
readers to owned `SourceStorageTensor` / `SourceStorageInventory` values. The
native storage inspector consumes those values and emits schema1 metadata.
Each tensor retains container tag, original dtype integer in that container's
namespace, exact original name/path, full source axes/order, element count and
absolute-in-file offset/byte count. File/data extents and safetensors string
metadata are retained separately. GGUF's general typed metadata remains with
its existing parser/semantic adapter; the storage catalog does not fabricate
architecture or claim to serialize every GGUF configuration field.

GGUF shapes use the newly retained declared axes and explicit
`gguf_fastest_axis_first`; safetensors retains `row_major_outermost_first`,
including scalars and zero axes. Original names are not replaced by canonical
compiler aliases. Container tags select byte arithmetic: GGUF kind0 means F32,
whereas the existing safetensors reader's kind0 means F16. Both namespaces keep
their real values; no integer cast creates a format conversion.

`source_storage_bytes` checks exact element counts and format-specific dtype/
packed-row rules. `validate_source_storage` checks bounds, source extents,
minimum header offsets, name uniqueness, per-entry container/path consistency,
axis order, byte counts and spans. Original paired heapsort sorts scratch spans
by start then end in O(n log n); zero spans precede positive spans at the same
start. Overlaps/interior empty spans refuse. Safetensors must cover all payload
bytes; GGUF may retain alignment holes/unused tail bytes. Descriptors remain in
original parsed order. Returned snapshots/copies own their storage.

`gguf_source_storage` requires a live owner. Its path wrapper closes on success
and errors. Safetensors reuses the existing owned inventory reader, which closes
before projection. No second file parser, numerical conversion or model runtime
was added. Existing SourceTensorBinding/semantic/matrix/cache/static readers
remain explicitly GGUF-specific and have not gained a false safetensors route.

## Policies and proof limits

All descriptor count/rank/work policies are positive. New work units are
`n*(2*ceil(log2(n))+3) + sum(source ranks)`, checked before descriptor projection
and scratch sorting; these are metadata-work units, not CPU instruction counts
or a wall-clock deadline. Storage is linear in descriptors/axes and source-name/
path metadata. The safetensors path also applies all five existing parser
header/count/rank/work/depth policies before projection.

The GGUF path first runs the unchanged existing PackedGGUF parser. Its current
one/two-rank admission, type/row/count policies and quadratic parser overlap
check still apply before the new catalog bounds. The new work policy does not
retroactively bound that legacy parse. Broader rank/type coverage and parser
scalability remain implementation work, never permanent model eligibility
restrictions. Mutable file/path descriptors do not authenticate backing files
or source identity. This validator is not a complete container re-parser.

## Independent verification

All46 methods/1340 native child calls pass:

| Suite | Methods | Calls | Accepted / expected refusal |
|---|---:|---:|---:|
| New tagged storage catalog | 7 | 452 | 367 / 85 |
| Existing GGUF inventory | 6 | 16 | 8 / 8 |
| Exact GGUF source axes | 6 | 104 | 56 / 48 |
| Existing semantic graph | 9 | 56 | 14 / 42 |
| Typed/frozen baseline graph | 7 | 493 | 243 / 250 |
| Existing safetensors inventory | 11 | 219 | 109 / 110 |

New exact field/byte fixtures cover six GGUF kinds, rank-one versus one-row
matrices, all three current safetensors dtypes, scalars, empties, full axes,
Unicode/NUL/control names and metadata. Existing per-format inventories are
invoked against the same source bytes to cross-check projections. Fifty seeded
source collections and independent static product/packed-byte arithmetic pass.
The paired-sort oracle covers equal starts, empty spans, permutations, seeded
collections and2000 entries. Direct API checks cover copied ownership, closed
GGUF owners, container/dtype reinterpretation, provenance, counts/ranks/work,
negative/overflow products and offsets, byte mismatch, duplicates, overlap,
interior empty spans, coverage and source tails. Exact policy boundaries pass.

Sources remain unchanged; success/error traces retain read-only mapping and
cleanup with no Hailo/CUDA/HailoRT/GGML/ioctl access. Existing safetensors tests
also use the previously licensed pinned isolated format oracle and five legacy
header-only calls; no value-loader/model forward is run. Typed regression
again checks30 complete graphs against the pre-refactor baseline.

Evidence: `evidence/tagged-source-storage-2026-10-20/`. Initial missing-raises
compilation failure, unused initializer warning and missing legacy-test argument
are preserved. The initializer was removed and complete commands rerun; final
catalog/API builds are warning-free. No negative evidence was promoted to a
pass. Last observed implementation CI (`42f3360`, run39423865164) failed its
historical-master compile step; this is not a full CI pass. Observe this new
published SHA separately.

## Remaining full-model work

This connects ordinary files to tagged storage metadata. It does not connect
safetensors/config/shards to complete model semantics or establish physical
layout/precision, immutable identity, numerical Hailo instructions, original
program upload/activation/results/cleanup or broad model execution. Complete
semantic consumer migration, config/index/alias/orientation/rotary facts and
implementation remain required. All execution/fingerprint/fit flags stay false.
The broad ordinary-model target, Aesir-owned Mojo translation and Hailo-only LLM
execution remain fixed. No external compiler, artifact prerequisite, special
user conversion, inference proxy or guessed device instruction was introduced.
