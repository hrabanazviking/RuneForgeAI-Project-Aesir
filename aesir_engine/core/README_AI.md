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

Shared Turing staging uses optional16/32/64-row CTAs, all-thread barriers and
bounded10560-byte padded F16 operand storage. All three primitive gates pass;
rows64/batch32 earns up to1.92x shape-specific speed, but V and every batch4
shape still lose. Preserve direct/reference paths and full-model/control gates.

Wider optional64/128-column staging passes four complete primitive gates but
loses to the prior32-column choice. Keep the32-column default, bounded41280-byte
maximum and explicit geometry. Test ordinary F32 activation precision before
full-model integration; binary-fraction inputs cannot establish that gate.

Two ordinary native final-layer captures now pass fixed projection budgets for
all1,990,656 outputs and2520 selected independent dots. Read project-root
docs/NATIVE_TURING_ACTIVATIONS.md for source/repetition limits. This does not
replace complete-model precision, causal state, control or provider gates.

Unscaled input residual modes1/2 pass captured-input and original independent
model budgets but miss their stricter .0005 native-model RMS target. Do not promote
either or expose a failed speed score. Read project-root
docs/NATIVE_TURING_ACTIVATION_RESIDUAL.md; next measure scaled corrections.
## Scaled residual experiment

The optional staged Turing kernel supports explicit precision3/4 at rows64/width32
with the same bounded shared storage. Both residual operands scale by4096 before
F16 storage; zero-accumulator correction products rescale before F32 addition.
Legacy0/1/2 and normal inference stay unchanged. Complete original and tighter
numerical gates still decide acceptance; read
../../docs/NATIVE_TURING_SCALED_RESIDUAL.md before refining or integrating.

Optional batched fixture wrappers call public inline llama_rope_transform and
llama_cache_cell, avoiding reuse of enqueued kernel entry points. Preserve old
entry bodies, exact arithmetic and caller span/causality admission. No production
dispatch change. Read ../../docs/NATIVE_TURING_BATCHED_ROPE_CACHE.md.

The optional strided RMS sibling and public residual/SiLU cell helpers preserve
existing entry definitions. Caller admission owns disjoint rows, finite validated
weight metadata and exact arithmetic/replay gates. Read
../../docs/NATIVE_TURING_BATCHED_ELEMENTWISE.md before changing or integrating.

Header reuse is an explicit compile-time cache_headers=False experiment with a
separate rows64/width32/precision0 entry. All original staged F32 bits pass, but
target batch32 FFN timings lose, so keep False. No register/occupancy cause is
proved. Read ../../docs/NATIVE_TURING_BLOCK_HEADERS.md before refinement.

The separate128-row CTA experiment preserves original entries and accumulation,
with maximum19008 shared bytes/256 threads and guarded ceil input work for batch4.
Initial256 fails physical launch and is rejected before model/GPU in the collector.
Keep old runtime selection. Read ../../docs/NATIVE_TURING_LARGE_ROWS.md.

Down-only128 now passes ordinary captured-F32 projection gates, with every new/
original bit and actual accepted source/native/original byte preserved. This
leaves full model/cache/state and later control/replay/provider gates open.
Read ../../docs/NATIVE_TURING_DOWN_ACTIVATIONS.md before selecting the candidate.

## Optional bounded token-partition primitive

Separate packed_turing_partition owns original format12/13/14, row64/128, token8/16,
logical4/8/16/32 and width32; one 2D enqueue owns disjoint token rows, original
ordered high/residual MMA and both barriers. Checked complete spans precede launch.
Harness final parameters default0 and refuse conflicting legacy candidates. Full
native/candidate/selected-original MMA vectors, UInt32 bits, guards, pinned independent
dots and840 rotated records gate any primitive ratio. Original MMA down128 applies
only to canonical down batch32; staged64 elsewhere. Model key/value four-reference
is the separate native owner. New marker/dispatch parser is default-closed, requires
explicit CLI and actual binary hash before/after; complete failures retain metrics
and atomically clear ratios. Seven hostile contracts plus physical gates remain
separate from hosted compile/master190/one skip. No runtime/model selection change.
Read ../../docs/NATIVE_TURING_TOKEN_PARTITION.md.

## Optional bounded small-score attention primitive

Separate `fused_small_attention.mojo` reuses original complete span admission,
then visible<=1536 independently of actual KV capacity<=4096. `attend_small[batch]`
keeps original24/8/128 GQA math/barriers/128-thread grid and no global workspace;
16384→6144 static shared bytes are observed over all2178 profiled kernels.
No model/runtime selector change. `test_small_fused_attention.mojo` owns exclusive
0600 CSV/actual PID/33 cases/17 pure refusals/full F32 bits/immutable inputs/exact
guards/660 warmed rotated samples. Startup wait precedes CUDA and is unscored.
`check_small_fused_attention.py` covers every output with pinned Float64 CPU and
fixed budgets; profiled mode clears scores. `check_small_attention_resources.py`
binds all full plain/profile bits and CPU source identity to complete launch/resource
counts/PID/binary/five artifact hashes. New analyzer fused_primitive flag requires
resources and excludes all model/range flags; old schemas stay.10+8 hostile contracts
join CI. Read project-root operation at project-root docs/NATIVE_SMALL_FUSED_ATTENTION.md before
changing bounds/math; whole-model/state/production/provider gates remain separate.

## Explicit small-score whole-model prefill

Final small_attention=False is an exclusive test-only strategy5 requiring original
fused/down128/rotary/elementwise precision0 and no control/trace capabilities.
Count4/32 enqueue attend_small; singles remain original. Separate small/fused/scalar
counters reset.12 state/allocation-preserving refusals include a valid native replay
plan; restore rejects5 before owner mutation. No original0..4 or normal selection
change. New probe exports all513024 F32 per owner/IDs/full cache/4352 guards/32
records and own exact bits. Explicit reader allow_small/CLI--small-attention require
actual current binary and accepted default4 source CSV/report/binary/full fixed CPU/
prior3 byte/cache/ID/counter proof. Every current value/cache/ID and tile count binds;
unchanged independent zero-GPU F32-expanded oracle reruns. Every after-hash/numeric/
source/nonfinite failure clears all scores, retains exclusive reports. Seven hostile
contracts join CI; read project-root docs/NATIVE_SMALL_ATTENTION_MODEL.md. New mode
controls/replay/tracing/generation/runtime/context/device/provider gates stay open.

## Explicit small-score causal generation

Optional5 now retains full96 native-forced greedy/seeded frames/12312576 values
per owner, source5 initial F32 bytes, independent fixed CPU budgets, exact own
UInt32 replay/sample/history/draws/state/4352 guards. Actual small56/1008 and
down28/924 stay; fused0 is mandatory and scalar original queries advance28 per
generated token. Strict accepted-small helper requires actual model5 CSV/report/
binary, full parsed/recomputed four-case vectors/cache/IDs/counts/timings/fixed
CPU and complete source4 predecessor proof; typed integer totals/counters/IDs.
Explicit exclusive small source triplet plus current binary/SHA and all eight
after-fences bind. Defaults/old loaders reject5. Twelve hostile contracts/master190/
one skip/all seven builds pass before serial GPU/CPU. Read project-root
docs/NATIVE_SMALL_ATTENTION_DECODE.md. No speed score or normal selection.
Next sealed owning-context replay5, then separate controls/tracing and broader
runtime/context/device/concurrency/soak/provider gates.
