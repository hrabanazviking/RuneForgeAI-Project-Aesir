# Native compute work guidance

Read INTERFACE.md, README.md, the capability ledger and AI.rules.part2.md before
editing. Compute owns kernels/session plans; loader owns validated GGUF spans;
CLI owns configuration/transport. No provider substitution belongs in core.

Format equations belong in packed_quantization.mojo. Keep scalar kernels as
references. Block projections require admitted alignment/extents and preserve
arithmetic/reduction order. Prepared descriptors are built after validation.
Prefix reuse is bounded to exact positions/tokens in one owning model/session,
with fresh final logits and rebuilt sampler history. Keep poisoned-session,
reset, cancellation and serialized mutation semantics intact.

Run independent real-weight parity and physical cached/fresh equivalence before
deployment. Compilation, synthetic checks or fluent answers do not promote broader
model/hardware support. Rebuild after Mojo edits; benchmark with other GPU work
idle and retain failures. See project-root docs/NATIVE_PERFORMANCE.md for evidence,
commands, memory/control semantics and context-recreation limits.

Dense normalization uses four-value register tiles at admitted 128/3072/4096
widths; preserve lane summation and in-place/disjoint ownership. Quant byte
arithmetic may narrow only within the proved small range; addresses remain wide.
Expanded physical parity and the independent RMS checker are required. Use the
fail-closed benchmark comparator rather than trusting reported summary medians.
See project-root docs/NATIVE_EFFICIENCY.md.

For four-token prefill, read project-root docs/NATIVE_LONG_TOKENS.md. Keep
DenseBufferLayout checked before allocation, per-token live spans disjoint and
scores/logits shared only after queued consumers. Never expose future KV inside
a tile. Only synchronized tiles commit; failures poison reuse. Batch four defaults
only to the exercised strict 3B profile. Preserve batch one and scalar references.
Full native sequential/tiled logits are regression evidence, not an external
whole-model oracle. Poll deadlines at at most four-token prefill boundaries.

The optional packed_matrix candidate is physically exercised only by its probe.
It is slower at batch4 and must not replace default projections. See the project
root docs/NATIVE_MATRIX_CANDIDATE.md for predeclared budgets, bounded shared memory
and selected independent real-weight coverage. Full-model integration stays open.

The optional Turing gate uses explicit PTX6.5/sm_75 to correct the pinned
RTX2060 target's PTX6.3 incompatibility with m16n8k8. Keep it isolated; do not
patch installed libraries, locks, drivers or generated PTX. Read project-root
docs/NATIVE_TURING_MMA.md. Exact synthetic output proves only the physical
primitive; real-weight F16 quality and full-model speed remain open.

The optional packed Turing matrix passes fixed native/selected-independent
primitive budgets only after split-weight F16 refinement. It is slower in all
28 measured cases. Keep defaults/references; read project-root
docs/NATIVE_PACKED_TURING_MATRIX.md for activation-conversion limits and next
shared-staging gates. Never turn a primitive precision pass into model quality.
