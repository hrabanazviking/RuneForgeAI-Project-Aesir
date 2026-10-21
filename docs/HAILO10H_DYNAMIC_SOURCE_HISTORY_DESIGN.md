# Original source-bound dynamic context and insertion history

Date:2026-10-21. Phase1 of TASK_hailo10h_dynamic_decoder_integration.md.
Publish this exact contract before native changes. Broad ordinary source support
and Hailo-only LLM execution remain fixed. This phase binds the original source
and context primitive; graph/cache data operations remain the next phase.

## Why retain invocation boundaries

The qualified retained-context selector uses maximum position plus one, with a
reset strictly below the configured reference. Equal context records cannot be
coalesced without losing invocation information. Example:reference8, initial
retained32, first prefix4 resets to8, then append to prefix8 retains8. One merged
record ending8 would instead retain32 from the initial state. Preserve every
append boundary, including repeated equal selected contexts. This is an original
integer state/history rule, not a host model or cache-data execution experiment.

## Exact owned policy and source projection

Add smidr/dynamic_decoder_policy.mojo and
smidr/source_dynamic_decoder.mojo, with source-independent mathematical values:

DynamicDecoderPolicy(Copyable,Movable):factor:ScalarWord,theta:ScalarWord,
reference:Int,limit:Int,origin:String,reference_origin:String,provenance:String,
work:Int. Its implied kind is dynamic. Require1<=reference<=limit; independent
positive finite32/64 factor/theta words, with no narrowing. Origin invocation
requires reference_origin=invocation. Origins source:modern/source:legacy require
both scalar widths64 and reference_origin=source or documented_default:32768.
Other qualified families/defaults are future adapters, not model eligibility
restrictions. All strings are owned values. Exact logical policy charge is
256+UTF8(origin)+UTF8(reference_origin)+UTF8(provenance). Require nonempty
provenance, work>=charge and work<=source_work before owned copies; no quantity
proportional to factor, numeric context or width is allocated.

validate_dynamic_decoder_policy(p,source_work) returns that exact charge.
same_dynamic_decoder_policy compares every field, including scalar words/work.

source_dynamic_decoder_policy(architecture,limit,provenance,work) validates the
complete original SourceDecoderArchitecture and projects the qualified SmolLM3
configuration intent. Require a non-null rope_scaling object, strict bounded
nested JSON, and an explicit dynamic selector/factor. Legacy type is authoritative
when present, as already qualified for this family; otherwise use rope_type.
Absent/null/other selectors are not silently treated as dynamic. Preserve their
raw facts and leave existing default/linear projection unchanged. Use _number
for a finite positive binary64 factor, bitcast its exact word, and independently
bitcast retained rope_theta. The reference and reference_origin come from retained
max_position_embeddings and its exact architecture origin. Do not substitute the
nested original_max_position_embeddings, a cache capacity or an invocation index
limit into the original source value. Keep all original/raw/default/null/custom/
legacy/training/unresolved fields in the caller's complete owner.

validate_source_dynamic_decoder_policy(architecture,p) rederives this projection
and compares every field; it also revalidates the full architecture. Caller-chosen
limit/provenance/work remain explicit inputs, not purported immutable source
facts. A mathematically valid changed source factor/theta/reference/origin must
still fail this source binding check. The source projection does not select rotary
width/pairing or certify any partial-width consumer, whole architecture or model.

## Exact append-history API and bounds

DynamicDecoderHistory(Copyable,Movable):policy:DynamicDecoderPolicy,
initial_selected:Int,end_tokens:List[Int],selected_contexts:List[Int],work:Int.
The initial retained frequency context is explicitly supplied, not inferred from
cache capacity or use_cache. It may exceed the size of a later short invocation's
cache allocation. Require reference<=initial_selected<=limit. Empty lists mean
an initialized zero-token mathematical prefix, not an uninitialized data cache.

initial_dynamic_decoder_history(policy,initial_selected,work,source_work) owns an
independent copy. validate_dynamic_decoder_history(history,past,source_work)
requires equal bounded list lengths, positive strictly increasing ends, final
end=past (empty iff past=0), and every end<=policy.limit. Replay each recorded
end's maximum position end-1 through select_dynamic_context, starting at the
explicit initial retained context. Require every recorded selected_context to
match the replay. This validates a declared insertion history; it does not prove
external cache bytes, model/source immutable identity or hidden-state correctness.

Exact history logical charge is policy_charge+128+128*record_count. Check count
against remaining work using division before multiplication or scans/copies.
Require history.work<=policy.work, and history.work>=charge. No allocations sized
by tokens, selected context, capacity or scalar magnitude. Existing source_work
is an explicit upstream bound and is rechecked on every call.

advance_dynamic_decoder_history(history,query,past,capacity,source_work) first
validates the complete old state. Require query>0,0<=past<=capacity<=policy.limit
and query<=capacity-past before adding. Reserve the exact charge for one more
record before copies. Append end=past+query and its selected context, replayed
from the prior selected context with maximum index end-1. Copy all old records
without coalescing and leave the input unchanged. No capacity<=reference condition
is imposed on this new explicit mathematical history path. Old graph constructors
and their conservative bounds remain unchanged. No prefix-size product is formed.

history_dynamic_rotary_coefficients(history,past,width,pair,source_work) validates
history and returns the original dynamic_rotary_coefficients for its current
selected context. Exact factor/theta words remain in the owned policy; the result
is integer coefficients, never numerical evaluation. Width2/pair0 has the existing
canonical identity. Context selection is not a cache-wide basis tag:old records
keep their insertion contexts; no keys or values are transformed or relabeled.

## Consumer, domain, lifetime and compatibility boundary

Add a new isolated native policy/history probe and a source-header inspector
using existing owned same-fd collection/architecture/projection APIs. Descriptor
formatters emit exact scalar words, policy/history charge and all append records.
The source inspector includes the complete original source descriptor and explicit
ordinary_model_admitted=false,source_graph_integrated=false and
 device_execution_verified=false. It supports both indexed/unindexed header input.

No old production file/test, signature, graph, schema, tensor domain, recipe map,
cache address/allocation, lifetime or storage consumer changes in phase1. These
new source-bound histories are compiler declarations, not actual cache ownership
or numerical inference. No recipe/global tensor or phantom capacity storage is
introduced. Cache flags and NoPE masks stay in the untouched architecture; they
do not erase declared context intent or authorize host forward evaluation.

Phase2 must publish an exact graph integration contract before its own edits:
source-preserving extent policy, position-source binding, factor/context snapshots
on enabled Q/K only, source/recipe/expanded maps and guards, insertion provenance,
real/predicate/index domains and exact lifetimes/storage. It must distinguish
retained-basis append from any separately selected fixed-vector transform; neither
implies full-prefix model equivalence. Broad cached/full-prefix support stays the
target; no permanent fallback or eligibility restriction is introduced.

## Independent acceptance and automatic continuation

All199 current Mojo hashes and65 controls are frozen. Build only new entrypoints
from an unchanged snapshot; prove old hashes/controls untouched. Verify exact
source64 factor/theta/default/legacy/modern/raw provenance, independent invocation
32/64 words, initial/growth/equality/shrink histories, the noncoalescing counterexample,
large signed index domains, exact/short work bounds, malformed source/state and
mutations of every owned derived field. Compare rational coefficients and full
histories with independent Python integer/Fraction expectations. Verify copied
policy/lists/scalars are independent, stale source projection fails, and refusal
followed by fresh success works. Record actual bounded header reads and fd cleanup
with indexed/unindexed source fixtures. Preserve complete frozen inspector outputs
and all preliminary negative/build evidence. No model/layer/attention forward or
payload evaluation, even for testing. External implementations are not copied or
translated; no external library is a native/runtime/user prerequisite.

Publish verified phases, check exact remote tree/heads, FFmain and automatically
continue phase2 and actual numerical Hailo widths/packing/placement/register/CCW/
configuration/delivery/activation/results/cleanup. No device instruction is invented
and no hardware is accessed by this phase. This does not claim source execution.
