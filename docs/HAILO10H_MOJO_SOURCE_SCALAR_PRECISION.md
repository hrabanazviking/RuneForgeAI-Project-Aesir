# Exact source scalar words through native mathematical lowering

Date:2026-10-21. Published-before-code design c5158d8:
docs/HAILO10H_SOURCE_SCALAR_PRECISION_DESIGN.md. Parent:
TASK_hailo10h_source_scalar_precision.md. Broad ordinary source-model support
and Hailo-only LLM execution remain the fixed target.

## Implemented boundary

Original ScalarWord retains32/64-bit source representation and exact UInt64 words.
DecoderScalars owns epsilon/base and bounded provenance; admission charges exact
logical work2+UTF8 bytes before copying. Positive finite words are validated in
their source width, without narrowing64 to32. A separate ordinary factory validates
the existing complete architecture owner and projects bitcast64 scalar words;
that original owner retains its raw fields, qualified origins and unresolved
modifiers. This selected projection is not a complete ordinary model adapter.

DecoderGeometry and a new builder overload separate dimensions from scalar
representation. SemanticPlan owns explicit scalar state and unavailable legacy
Float32 slots; bitwise positive-zero guards detect contamination. Legacy mode
resolves its current live Float32 field only when the selected operation needs it.
Existing standalone norm/embedding APIs therefore keep working. New explicit
source values never pass through a rounded compatibility number.

RMSNorm and rotary recipes retain source tag/word descriptors, with one owned
scalar/provenance snapshot per recipe bundle. Old32-bit mirrors are exact for
width32, and unavailable for width64. Expanded emission carries descriptors and
storage validates plan state, source roles, retained snapshots, every scalar
attribute/mirror and exact rotary rederivation. Shapes, maps, aliases and
hypothetical activation storage remain unchanged. Source width does not set
activation/device arithmetic width or certify a placed scalar/table arena.

Legacy native inspector outputs remain unchanged. Explicit source schemas use
version2 and null unavailable Float32 values, together with exact source words.
The new diagnostic shows all raw ordinary fields and remaining notes alongside
explicitly synthetic graph geometry. It denies ordinary model admission and
hardware execution; no scalar word is a device numerical capability claim.

## Verification

Thirty-two native entrypoints rebuild warning-free. Seventeen suites pass
**108 methods/2996 native calls**: the new4-method/132-call suite has72 accepted
calls and60 expected refusals;104 methods/2864 regression calls retain prior
rotary, NoPE, tagged source/compiler, cache and constant-reader coverage.

New checks preserve exact binary64 minimum/subnormal/maximum constants, ordinary
1e-6, neighboring values collapsed by Float32, mixed32/64 encodings, huge/small
bases and raw ordinary fields/notes. Twenty complete legacy outputs match, and
ten full normalized graph/storage comparisons remove only declared source scalar
metadata. Existing regressions retain108 full frozen consumer comparisons,
18 rotary legacy comparisons and40 complete NoPE graphs. All source/binary
identities stay unchanged through acceptance. Native trace has zero connect
calls, no Hailo device open and no Torch library. No numerical model is executed.

Evidence: docs/evidence/source-scalar-precision-2026-10-21/. Full raw outputs
and binaries remain in the external task work archive with exact identities;
compact published evidence includes final commands/logs, per-call identities,
representative complete compiler output and source metadata trace.

Initial broad helper extraction left a legacy wrapper referring to an unavailable
variable; the first build failure is preserved and the wrapper was corrected.
No external implementation was copied/translated. New production code imports
original Aesir modules and Mojo standard facilities only; no external compiler,
model runtime, DFC, vendor artifact or user conversion dependency was introduced.

These are source constant and mathematical compiler checks. Full ordinary
modifier/architecture/format integration, immutable source identity, physical
precision/packing/placement, actual Hailo numerical instruction/register/program
configuration, upload/activation/result/cleanup and source-model execution remain
open. Retaining binary64 never requires binary64 device arithmetic or a permanent
source eligibility restriction. Continue those actual gaps automatically after
verify/publish/both-head verification. No CPU/CUDA/cloud model/layer/attention
forward or inference proxy was invoked.

Whole-repository consistency remains failing:18187 diagnostics,
17862 baseline plus325 retained receipt-path diagnostics. No new
nonreceipt diagnostic after shifted Markdown line normalization. Ledger census:
107 verified/152 total, no duplicate ID. This is scoped native acceptance;
no historical-master/full-repository pass or hardware numerical proof is claimed.
