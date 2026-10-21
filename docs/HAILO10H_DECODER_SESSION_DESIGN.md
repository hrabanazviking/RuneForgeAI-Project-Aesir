# Original cache/session policy and cache-output lifetimes

Date:2026-10-21. Pre-code contract for
TASK_hailo10h_ordinary_cache_semantics.md. Activation implementation d5d70ff
is verified on both branches. Broad ordinary source-model support and Hailo-only
LLM execution remain fixed. Publish this design before production changes.

## Audited distinction

The [versioned public SmolLM3 interface](https://huggingface.co/docs/transformers/v4.57.1/model_doc/smollm3)
describes use_cache in terms of returning past key/value state and describes
unprocessed input when a past cache is supplied. This declaration does not
specify Aesir's physical allocation or prove every reference implementation
behavior. Source cache-return preference, invocation input mode and physical
storage must remain distinct. A false source preference must not silently become
an instruction to discard supplied past state or a claim that no internal storage
can exist. Aesir defines the following explicit mathematical session modes.

Current original code retains the source boolean/origin and unresolved note.
SemanticPlan always constructs persistent external KV tensors and append views;
logits is its only formal result. Source/expanded lifetime checks retain only
logits, persistent storage and source weights through graph end. CacheLayout
requires two persistent regions per layer. These facts require a coordinated
migration before an ordinary cache field is claimed handled. No model, layer or
attention forward was evaluated for this audit and no external implementation
is copied or translated.

## Exact owned policy/API

Add DecoderSessionPolicy(Copyable,Movable): mode:String, return_cache:Int,
source_return_cache:Int, return_origin:String, provenance:String, work:Int.
Both flags are0/1. Mode is cached_append or full_prefix. Return origin is source
or invocation; source origin requires both flags equal. The source flag records
the retained configuration preference, independently of the selected mode.

Exact logical charge is128*layers+2+mode.UTF8+return_origin.UTF8+provenance.UTF8.
Require positive layers/work, work<=source.policy.work, nonempty provenance and
checked charge before owned policy copies or export-list allocation. Validate
actual source layer evidence in the graph builder. The unique optional empty
state has empty strings, both flags0 and work0. Missing session/architecture
coverage remains implementation work, never permanent model eligibility rules.

Add source_decoder_session(architecture,mode,return_override,provenance,work).
Validate the complete original architecture. Override -1 inherits its retained
use_cache boolean and source origin;0/1 explicitly selects invocation origin.
No other override is accepted. Preserve the full original architecture, raw
fields/default origins and unresolved notes; this selected projection is not a
complete ordinary adapter. The invocation supplies the mode explicitly; do not
derive it from the source return flag. Bounds apply before copying caller state.

Add DenseDecoderParameters and DecoderGeometry+DecoderScalars builder overloads
with existing graph, bias and activation policies, then DecoderSessionPolicy,
query/past/capacity. Keep all old signatures/behavior. SemanticPlan adds owned
explicit_session, session_policy, session_work and cache_exports:List[Int].
Legacy state is false/empty/0/empty. PrimitiveRecipes retains independent copies
of that complete snapshot. Cache exports contain exactly K,V for each layer in
ascending layer order when return_cache=1, otherwise empty; no duplicates.

## Exact graph modes

cached_append preserves existing cache bases, append operations, view names,
query/past/capacity axes and source projection/bias/rotary dependencies. Its
cache exports, when requested, are the keys_view/values_view outputs. Persistent
bases remain internal session inputs even when return_cache=0; the explicit mode
and initialized-prefix preconditions explain their use. A source return flag
alone neither creates nor removes those inputs.

full_prefix requires past=0. Query input is the complete prefix with positions
0..query-1; capacity remains an explicit context bound. Build no persistent KV
base, append operation or alias/view. Feed selected post-bias/rotary K and selected
post-bias V directly to causal attention, with total=query. Return_cache=1 exports
these exact K,V activation IDs; return_cache=0 exports none. No new numerical
primitive or host attention computation is introduced. Avoid computing unallocated
capacity*KV memory extents; retain all real query/head/feature products and source
context/session bounds. Do not certify numerical cache-reuse equivalence or
hardware precision from graph/index structure alone.

All cache exports live through graph end. Add a bounded source export helper and
migrate bias, activation, semantic storage, expanded emission/storage and cache
lifetime checks together. Validate session state before other consumer checks
that use its export list. Source/session validation must rederive exact selected
K/V producers, source weights/shapes, norm/bias/rotary inputs, GQA consumption,
mode/past/append/base/alias constraints, export order and all source last uses.
Reject stray legacy state, missing/duplicate/substituted exports, bypasses,
changed policies/accounting and incompatible input modes.

## Consumers, descriptors and compatibility

Matrix and semantic-storage consumers apply the same session guard. Expanded
validation compares the owned recipe snapshot, source/global export mappings and
last uses. Global cache exports are derived from validated source_to_global;
no second mutable export map or hidden allocation. Full-prefix returned cache
activations use the caller's activation-width storage scenario; this is not a
physical cache encoding or host serialization contract.

CacheLayout gains mode:String with default cached_append. Preserve its existing
constructor's positional arguments with an optional trailing mode. Cached layouts
retain all existing region/address rules; exported views may now live through
end. A validated full_prefix layout has no persistent regions and total_bytes=0,
positive geometry/source extent and the explicit assumed policy. Validate this
empty layout as a distinct mode, never as a missing cached layout. Do not perform
phantom capacity/stride products or pool admission for nonexistent regions.
Every address lookup on it refuses by the empty region bound. Returned mode,
geometry, regions, source IDs, totals and mutations must be checked.

Only explicit session JSON uses schema5, with session_policy and cache_exports:
source IDs in semantic/recipe descriptors and mapped global IDs in expanded
output. Preserve scalar/bias/activation metadata and source32/64 words. Adjust
only explicit full-prefix runtime preconditions to omit initialized past-cache
requirements. All old complete outputs remain unchanged. New cached_append with
return_cache=0 must match its activation-only predecessor after removing only
the declared session/schema metadata.

## Acceptance and continuation

Forty-six current executable controls are frozen with copy2, original modes and
SHA256s before code; manifest in evidence/decoder-session-contract-2026-10-21/.
Verify both modes, flags/default/override origins, mixed NoPE/bias/activations,
independent K/V widths, source32/64 words and actual ordinary/GGUF source fixtures.
Recompute exact graph/recipe/source/global exports, all last uses, hypothetical
storage timelines and cache address/zero-region behavior independently. Include
large unallocated capacities, exact/short work bounds, overflow, malformed and
mutated policy/producer/export/alias/consumer state, copied inputs/snapshots,
read-only source descriptors and refusal/recovery cleanup. Rebuild all affected
consumers plus new entrypoints from an unchanged snapshot; compare complete
frozen outputs. Isolated index/address/constant primitives only: no model/layer/
attention forward or CPU/CUDA/cloud LLM inference.

Publish each verified slice, verify Hailo/main heads and continue remaining
activation/window/scaling/training/full ordinary graph work and actual numerical
Hailo configuration/encoding/packing/placement/program delivery/activation/results/
cleanup. No DFC, outside compiler/machine, user conversion, compiled-model
prerequisite or inference proxy. This contract and a host graph do not establish
source-model execution, physical fit or completion of broad model support.
