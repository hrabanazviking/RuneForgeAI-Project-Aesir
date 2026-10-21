# Source scalar words through mathematical graph and recipe lowering

Date:2026-10-21. Publish before code. Parent:
TASK_hailo10h_source_scalar_precision.md. Both branches1489b05; broad ordinary
model support and Hailo-only LLM execution remain fixed.

## Exact source representation API

Add ScalarWord(width:Int,bits:UInt64), with source encodings32 and64. Validation
requires finite positive IEEE binary values;32-bit words must have zero upper
bits. Width0/word0 is the sole empty optional descriptor, never a numerical value.
No conversion to Float32 occurs when validating/retaining a binary64 word.
Add DecoderScalars(epsilon:ScalarWord,rope_base:ScalarWord,provenance:String,
work_limit:Int), Copyable and owned. Its exact logical work charge is
2+provenance.UTF8, admitted before copying under a positive work_limit. A typed
plan additionally requires work_limit<=source.policy.work. This is descriptor
accounting, not device bytes, fit or precision.

A separate source_decoder_scalars(ordinary architecture intent,provenance,limit)
factory validates the existing complete owned architecture under its policy,
then projects exact bitcast binary64 words from rms_norm_eps/rope_theta. It does
not mutate/narrow that owner. The original full raw config, origins and unresolved
modifiers remain in that owner; this selected scalar projection is not a complete
ordinary architecture adapter or source-file identity certificate. Explicit source
scalar APIs can carry other source encodings without a model-name allowlist.

## Typed graph ownership and compatibility

Keep DenseDecoderParameters and existing legacy fields/APIs unchanged. Add
DecoderGeometry containing only its dimensions/context/layout, and a new
build_decoder_semantic_plan(source,geometry,scalars,policy,query,past,capacity)
overload. Share dimension/shape/session/weight/policy admission with the existing
builder; avoid reinterpreting source words as legacy Float32 values.

SemanticPlan gains explicit_scalars:Bool and owned DecoderScalars. Legacy mode
uses empty new state and derives ScalarWord32 from the current live legacy
Float32 field on demand, preserving existing mutation/standalone APIs. Explicit
mode owns/copies the supplied set and keeps legacy Float32 fields at positive
zero as unavailable compatibility slots. Validate those slots bitwise zero;
mathematical consumers must use the scalar resolver, never those slots. No
rounded compatibility number becomes a source constant. All existing shape,
source role, KV/output and operation semantics remain unchanged.

New resolvers validate selected words without narrowing. A shared state check
rejects partial/stray explicit state and validates both explicit words/provenance/
limits. Legacy standalone graphs need only their actually selected scalar: do
not require a rotary base for a standalone norm or scalars for an embedding.

## Primitive and expanded propagation

PrimitiveRecipe gains epsilon_scalar and rotary_base_scalar descriptors. Old
UInt32 epsilon_bits/rotary_base_bits remain mirrors for width32 and zero when
width64/unavailable. PrimitiveRecipes retains one owned explicit scalar snapshot;
provenance is not duplicated per operation. RMSNorm/rotary mathematical lowering
uses the exact descriptor in all source/base checks and emitted attributes.
SiLU/softmax and unrelated nodes keep empty descriptors. No numerical tensor
computation, transcendental or constant conversion is performed by production.

ExpandedOperation carries these descriptors through existing emission/mapping.
Expanded graph/storage validates plan state, retained recipe scalar snapshot and
all operation scalar attributes against the source role. Exact rotary rederivation
also checks stored/expanded word tags/bits. Reject mutated source words, snapshot,
compatibility slots, scalar metadata on unrelated operations and stale mirrors.
Graph shapes, maps, aliases and hypothetical activation storage remain unchanged;
source-word width never implies activation/device arithmetic width or a new arena.

Legacy inspector outputs remain byte-identical. Shared descriptors expose an
explicit version2/schema extension only for explicit-scalar plans; unavailable
Float32 values/words serialize as null, alongside exact source tag/word metadata.
Never display a compatibility zero as a model parameter. A new native inspector
shows original ordinary config/notes, selected scalar source metadata and full
synthetic geometry/recipe/expanded/storage paths. It explicitly denies ordinary
model admission and hardware execution. No caller inference workflow changes.

## Independent acceptance / continuation

Freeze current consumers before edits. Verify binary32/64 exact words including
ordinary1e-6, neighboring values collapsed by Float32, subnormal/minimum/maximum
positive finite64 and bases beyond32 range. Accept source words without requiring
Float32 representability. Refuse wrong width/upper bits/negative/zero/NaN/infinite
values, empty or over-budget provenance, geometry/session/source faults, explicit
state contamination and changed recipe/expanded/source metadata. Check ownership,
exact work boundaries, ordinary factory consistency and source read-only cleanup.

Compare complete old outputs, including all prior scalar/rotary/API cases and
frozen compiler consumers; rebuild all affected entrypoints. Independently check
all norm/rotary source words, mappings/lifetimes and storage paths. Tiny isolated
constant/primitive oracles only, never model/layer/attention forward. Publish
verified code/evidence, verify both branch heads, and continue actual ordinary
modifier/architecture integration and Hailo numerical encoding/configuration,
precision/packing/placement/upload/activation/result/cleanup. No DFC, external
compiler/machine, vendor artifact or special user conversion prerequisite.
