# Original per-layer source windows and mathematical mask lowering

Date:2026-10-21. Exact pre-code design5a24ade, index accounting clarification
ee5d1d9 and numeric source-operation width binding8149d68 were published before
their production changes. Design:docs/HAILO10H_DECODER_WINDOW_DESIGN.md.
Broad ordinary-model support and Hailo-only LLM execution remain fixed.

## Original implemented boundary

DecoderWindowPolicy owns one nonnegative width/layer, source/invocation origin,
UTF8 provenance and work. Zero selects full causal behavior; positive widths
include that many keys through the current query position. IntMax does not
allocate proportional to width. Exact logical charge129*layers+UTF8(origin)+
UTF8(provenance) is checked with remaining-budget arithmetic before policy
copies/source list growth. Optional empty state is unique. All source raw/default/
dormant/unresolved facts remain owned and inspectable.

The source projector validates the complete architecture before selecting the
qualified pinned SmolLM3 configuration pattern. Explicit layer_types survives
flag disagreement. Absent/null types use the qualified flag/non-null-window/NoPE
combination. max_window_layers remains retained and does not silently become
another model's generation threshold. Missing/unknown semantics are future
implementation work, never permanent model eligibility restrictions. Metadata
constructor permissiveness cannot certify a numerical model adapter.

New typed/source-scalar overloads own window/session/bias/activation/graph choices.
Positive source masks have independently bound numeric width; positive-to-positive
policy changes cannot reinterpret an existing graph. Full causal paths retain
existing operations/topology. Both session modes, formal returned K/V contents,
cache regions, capacity, source projection identities and scalar words remain.
Window masking does not evict/compact persistent caches or establish physical fit.

A positive mask lowers to three original mathematical operations: bounded prefix
key indices, causal/window predicate and negative-infinity selection broadcast
over heads. The isolated relation tests causality before subtracting indices,
avoiding signed overflow. Local/global index/predicate/real domains, shape/products,
source mappings, primitive metadata and lifetimes are rederived independently.
These names describe mathematics, never Hailo opcodes or a host attention kernel.

Temporary prefix indices are ephemeral index-domain activations, charged at the
caller-supplied index width with a distinct index_live_bytes timeline. Peak
activation storage sums real, predicate and temporary index timelines. External
input accounting stays separate. Policy/recipe snapshots, source-width coupling,
source constants, no-bypass and domain/lifetime checks migrate session, bias,
activation, cache, matrix and storage consumers. ExpandedOperation, SemanticOperation
and storage-result positional constructors preserve older calls with optional
trailing fields. Only explicit window output uses schema6 and new descriptors;
complete older JSON stays unchanged. Source32/64 words remain exact.

## Acceptance

Fifty-eight entrypoints rebuild without diagnostics under one unchanged188-file
Mojo snapshot. Twenty-three suites pass 154 methods/5455 native child calls. New seven
methods/725 calls comprise226 accepted and
499 expected refusals. Eight complete frozen ordinary
outputs and16 complete frozen GGUF outputs match after removing only explicit
window/schema metadata. Both modes/return choices, source32/64, all-full and
mixed windows, source/default/dormant fields and hypothetical storage pass.

The suite independently checks2720 native integer admissions, six IntMax boundary
results and four invalid-index refusals, against arithmetic sets and the pinned
public119-row oracle. Source projection reproduces46 public configuration cases
while retaining complete original fields. Exact/short/UTF8/overflow budgets,
57 mutation variants across both scalar/mode/return paths, all compiler consumers,
large unallocated capacity and caller/recipe ownership checks pass.

Eight ownership traces cover160 in-process refusal/fresh-construction cycles.
Source/binary/oracle identities, all58 diagnostics,23 suite logs, run identities,
two complete representative traces and the full external archive census are in
docs/evidence/decoder-window-2026-10-21/. No failed/preliminary artifact contributes
to these acceptance totals.

Acceptance evaluates graph, byte, storage and integer relations only. It does not
compute projections, attention, a layer or a model. Complete raw source files
remain unchanged; ownership/refusal/fresh-construction cycles verify same-descriptor
header reads and actual close counts with no payload mmap, Hailo device or ioctl.
Qualified public configuration/index oracles remain isolated test evidence, not
an external implementation, runtime or user compilation prerequisite.

## Retained preliminary evidence

An early source-field test requested fields rather than the existing fields_raw
serialization. A focused run passed source/ownership/mutation checks but two
counts omitted the output projection and doubled the native integer grid. Corrected
complete compatibility/index probes pass; both failed and corrected logs remain.
An unavailable fixture helper was replaced by the established independent GGUF
fixture generator before those final probes. A full regression run also reached the new shared recipe-identity guard before
its older rotary guard. The same corrupted identity was refused correctly; the
legacy test now permits that exact earlier diagnostic only for that exact case,
while retaining all return-code/stdout/refusal checks. The failed run is preserved
and all23 suites rerun from fresh evidence paths. None counts as final acceptance.

Review additionally found a positive-width policy could otherwise reinterpret an
existing mask. The numeric source-operation binding contract was published on both
branches before adding the field and mismatch tests. Unused window weight state is
also checked against its empty default. Final acceptance requires all rebuilt
binaries and188 Mojo source files to match one unchanged snapshot, rather than
mixing the preliminary binaries with later source changes.

## Fixed broad-target frontier

This verifies original source/mathematical compiler support and hypothetical
storage, not complete ordinary architecture/scaling/training/activation coverage,
immutable source identity, actual device numerical precision/packing/placement,
CCW/register/configuration generation, original upload/activation/results/cleanup,
physical fit or source-model execution. All remain required implementation toward
broad model support. No DFC, outside compiler/machine, special conversion,
vendor-precompiled prerequisite, proxy or CPU/CUDA/cloud LLM inference was added.

Whole-repository consistency remains failing:baseline21025/current22059;
all1034 added diagnostics concern retained window receipt paths,
with no new nonreceipt issue after Markdown line normalization. Ledger census112
verified/157 unique IDs; nine historical strict-schema diagnostics are unchanged.
Targeted local acceptance passes. No historical-master, whole-repository or
hosted-CI pass is claimed.
