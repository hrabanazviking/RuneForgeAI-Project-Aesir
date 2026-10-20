# Exact declared GGUF source axes

Date: 2026-10-20. Published-first contract:
`HAILO10H_SOURCE_STORAGE_PROVENANCE_AUDIT.md` at `84361f4`.
Parent: `TASK_hailo10h_source_neutral_semantics.md`.
The owner's broad ordinary-model/Hailo-only scope is unchanged.

## Implementation and consumer

The existing PackedGGUF directory parser now retains each admitted tensor's
exact declared one/two-dimensional axes in an owned `tensor_shapes` index.
`tensor_shape(name)` returns a copied list and checks that its rank/positive
axes agree with the current PackedTensor descriptor. Missing names, missing
shape entries and inconsistent mutable descriptor/index state raise.

`[N]` remains distinct from `[N,1]`; `[1,N]` and general matrices retain declared
GGUF axis order. There is no rank inference from row count, implicit transpose
or dtype relabeling. `PackedTensor` constructor/fields and existing columns/
rows/offsets/kinds/byte counts/overlap/alignment validation remain unchanged.
The shape inspector consumes this public value API and closes mappings before
printing. Returned shape values survive index mutation and source close.

This repairs information loss for the loader's current admitted ranks. Higher
ranks, other types and formats remain implementation work toward broad support,
never permanent hardware eligibility restrictions. The index and descriptors
are mutable descriptive values, not an immutable source identity or certificate
of mathematical/physical layout. Safetensors full-rank axes remain separate
until the planned tagged storage/config/name integration.

## Verification

All28 methods/669 native child calls pass:

| Suite | Methods | Calls | Accepted / expected refusal |
|---|---:|---:|---:|
| Explicit source-shape fixtures/API | 6 | 104 | 56 / 48 |
| Existing source inventory | 6 | 16 | 8 / 8 |
| Existing semantic graph | 9 | 56 | 14 / 42 |
| Typed boundary / frozen baseline comparison | 7 | 493 | 243 / 250 |

The new fixture writer independently encodes explicit directory rank/axes and
bytes. Tests distinguish vectors from matrices with one row for several widths,
all six admitted storage kinds,35 seeded mixed collections/directory orders,
Unicode/NUL/control names, singleton axes and general matrices. Copies do not
alias the source or each other. Eight inconsistent index/descriptor mutations
per representative shape, missing names, bad ranks/extents, duplicates and
truncated files refuse without printing a successful partial result. File
bytes remain unchanged. Read-only syscall traces show mapping cleanup before
stdout and no Hailo/CUDA/HailoRT/GGML/ioctl access.

Rebuilt inventory/semantic/typed inspectors and APIs preserve prior behavior.
The full typed suite again compares30 complete graph fixtures to the frozen
pre-refactor binary from `6ec0593`. New source shapes do not change graph output,
metadata semantics, lifetime or storage namespace. Baseline/current binary
SHA-256 values and full invocation receipts are retained under
`evidence/gguf-source-shapes-2026-10-20/`.

Initial test-API compile failures are retained: argv StringSpan needed an owned
String dictionary key; List literal initialization needed the current Mojo API.
Final builds are warning-free. The whole historical master/CI is still not
verified; the last observed implementation CI at `2134a37` failed its historical
master compilation step and skipped later gates. Observe this slice's published
SHA independently. No test here performs a model/layer/attention forward,
external compilation, program upload, device reset or firmware/kernel change.

## Next connection

Use retained source axes in tagged full-shape storage with original name and
backing-file provenance. Recheck container-specific dtype/row rules and preserve
actual axes before any explicit semantic alias/orientation mapping. Complete
ordinary config/index and rotary/name facts are still needed. Numerical Hailo
instruction/configuration generation, physical precision/packing/placement,
upload/activation/result/cleanup and broad model execution remain open.
