# Original dynamic decoder graph and position-source lowering

Date:2026-10-21. Phase2 of TASK_hailo10h_dynamic_decoder_integration.md;
phase1aa804cf and HAILO10H_MOJO_DYNAMIC_SOURCE_HISTORY.md are verified.
Publish this exact contract before graph production edits. All204 current Mojo
source identities and67 accepted controls are frozen in dynamic-graph-baseline.
Broad ordinary source models and Hailo-only LLM execution remain the target.

## Explicit API and source-preserving extent validation

Add build_dynamic_decoder_semantic_plan overloads with the existing tagged source,
then either DenseDecoderParameters or DecoderGeometry+DecoderScalars, followed by
DecoderGraphPolicy,bias,activation,session,window,DynamicDecoderHistory before,
query,past,capacity. Keep every old constructor/signature/complete output unchanged.
Do not extend DecoderScalingPolicy's accepted kinds to bypass missing ownership.
Dynamic history is a distinct explicit path; explicit_scaling and explicit_dynamic
are mutually exclusive. New dynamic builders require session/window ownership.

Split geometry validation internally so the old entrypoints continue to enforce
capacity<=parameters.source_context with their existing diagnostics. The new path
retains all dimension/head/source/rotary/product validations and requires the
history policy reference to equal the unchanged typed source_context. Its capacity
bound is the explicit policy limit; require0<=past<=capacity<=limit and
0<query<=capacity-past before addition. Source context stays positive evidence,
not an allocation ceiling substituted into the new history. Never inflate it.

Before source movement or snapshots validate before against past/source.policy.work,
then advance it for query/capacity. Require exact word equality between policy.theta
and the selected rotary_scalar:binary32 for the DenseParameters path or the
independent32/64 DecoderScalars word for the explicit-scalar path. Factor width
is independent. Source-derived policy retains its64 words; requested32 semantics
require an explicitly selected invocation policy and remain distinct from the
source64 projection. Do not silently narrow or overwrite raw source words.

Add SemanticPlan fields explicit_dynamic:Bool,dynamic_source_context:Int,
dynamic_before:DynamicDecoderHistory,dynamic_after:DynamicDecoderHistory,
dynamic_work:Int. Add independent copies of those fields to PrimitiveRecipes.
Legacy fields are false,0,unique-empty history,unique-empty history,0. Add empty
policy/history constructors and equality helpers solely for optional empty state:
zero scalar widths/bits,zero numeric fields,empty strings/lists,work0. They are
never accepted as explicit positive policy/history inputs. Nonempty stray state
on old plans/recipes must refuse. Bounded equality precedes no unbounded copying.

Logical dynamic_work is128+before_history_charge+after_history_charge+
64*rotary_operation_count, where rotary_operation_count=2*enabled_layer_count.
Bound the count/division and each sum against source.policy.work before copies or
multiplication. This is descriptor work, not a physical-memory measurement.
Retain the complete before/after invocation history, including equal contexts.
NoPE flags do not erase context intent or introduce fake identity rotary nodes.

## A produced index range, not a shape-only position assumption

The existing positions tensor is an unproduced external input, and several
consumers hard-code producer=-1. That cannot establish the actual index range
used to select a dynamic basis. Only on the new dynamic path, emit a source
position_range operation before embedding:zero inputs,empty weight,no alias,
output named positions,shape[query],producer0,integer index semantics
positions[i]=past+i for0<=i<query. Tokens remain an external input. No host vector
or allocation proportional to numeric capacity is constructed by the compiler.

Add position_start:Int=-1 as an optional trailing operation/emit field, preserving
old positional constructors. Only position_range uses position_start=past; all
other operations retain-1. Its shape/product determines count and maximum index
past+query-1 with checked bounds. Add dynamic_position_at(plan,index)->Int as an
isolated integer accessor:validate the range producer and dynamic state, require
0<=index<query, return past+index. No model/layer/attention data is evaluated.
Arbitrary/custom source position-ID behavior remains required implementation work,
not a permanent eligibility restriction or permission to assume an input is valid.

Introduce one shared position-role validator:old plans require the exact external
position role; dynamic plans require the unique position_range producer, matching
start/count/output/shape/products/empty inputs/weight and valid lifetime. Use it
in semantic window, session, rotary recipe and cache-layout checks. Do not relax
all producer checks or rely only on the tensor's name. The new producer is part
of the mathematical graph; actual device index generation remains unverified.

## Source Q/K metadata and history semantics

Add optional trailing dynamic_reference:Int=0,dynamic_selected:Int=0,
dynamic_factor:ScalarWord(0,0) to SemanticOperation and its emitter. Set them only
on selected rope_query/rope_key operations, from the validated before.policy and
after selected context. Their old scaling fields remain empty. Other operations,
including position_range, masks and all NoPE projections, keep unique zero dynamic
metadata. Exact theta is already bound through the plan's rotary scalar and policy.

validate_plan_dynamic_state runs before window/scaling/session consumers can use
new state. Legacy state/operation fields must be empty. Dynamic validation replays
before, rederives after and exact work, checks source-context and scalar-word
coupling, and independently validates the unique range and every selected Q/K
producer, source weight, optional bias input, position edge, shape/product/order,
NoPE selection and metadata. Reject missing/duplicate/bypassed/stray nodes.
Recompute all source last uses, exports and persistent/alias lifetimes rather
than trusting mutable metadata. Avoid recursive guard calls:use bounded pure
policy/source-role checks inside the dynamic guard, then existing consumer guards.

Cached append preserves initialized-prefix cache bases, new K/V writes and views.
Old keys keep their declared insertion histories; they are not transformed or
relabeled as if all used the current context. Existing cache-return preference
never discards supplied past. Full-prefix retains past0,no persistent cache/append/
view and its existing activation export rules. Both modes remain supported targets.
A typed history still does not prove actual external cache bytes, immutable source
identity or full-prefix decoder equivalence; keep those execution gates explicit.

Add dynamic_context_output(plan)->DynamicRotaryContext, validated and available
regardless of return_cache, containing reference,current selected,limit. The caller
must retain the same validated policy/model binding when using this context for
a fresh empty-prefix history. Add dynamic_cache_history_output(plan):after.copy()
only when return_cache=1, otherwise the unique empty sentinel. Full-prefix/cache-
return false still has context output, but exports no numerical K/V or fake cache
history. Internal after is a compiler declaration, not a data-cache allocation.

## Original dynamic numerical recipes

Require explicit RotaryLoweringPolicy for new dynamic lowering/expansion, just as
for source scaling. Pairing, theta words, partial-tail assembly and source axes
stay explicit. Extend PrimitiveRecipe with the same three numeric dynamic fields;
legacy/other recipes are zero. Every expanded step of a selected rotary recipe
retains its exact dynamic metadata, independent of the policy snapshots.

Keep the existing rotary_inverse_frequency real[pairs] operation. Immediately
insert two mathematical steps, even when selected==reference or factor==1:

1. dynamic_rotary_gain:zero tensor inputs,real[1] output. It denotes
   g=1+factor*(selected-reference)/reference with exact integer context ratio and
   exact metadata factor word. No implicit source64-to32 conversion.
2. dynamic_rotary_frequency:inputs[base_frequency,gain],real[pairs] output. Pair j
   denotes base_frequency[j]*g^(-2*j/(d-2)); pair0 is exactly1 and bypasses the
   singular exponent, including d=2. Use the verified rational coefficient rule.

rotary_angles consumes the generated positions and adjusted frequency; the rest
of the original rotation recipe is unchanged. Each dynamic Q/K recipe has15
operations, compared with13 default/14 linear. No frequency array is computed on
the host and no physical opcode or rounding mode is inferred from these names.
Higher-width source domains, NoPE and untouched rotary tails remain represented.

Gain is a one-element ephemeral real value, live until adjustment. The original
frequency lives until adjustment; adjusted frequency until angles. Derive all
local lifetimes and source/global maps independently. No factor tensor, phantom
persistent constant, shared numerical evaluation or hidden cache rephasing is
introduced. Store exact source inputs and independent recipe snapshots.

## Expansion and storage consumers

Pass position_range through expansion as domain=index,storage=activation, with
its exact source tensor/output and start metadata; it is no longer external index
storage. Preserve weight/alias mapping and source operation ownership. Add the
same optional trailing start/dynamic fields to ExpandedOperation/emit. Only the
range has a start; only selected rotary recipe steps have dynamic metadata.
Independent expansion guards rederive recipes, snapshots, operation/value domains,
all local/global edges, source maps, shape/products and every global last use.

ExpandedStorage admits exactly the validated index-domain range producer, the
new scalar/vector real operations and their exact operand domains/shapes/arity.
Do not globally allow arbitrary operations to produce indices. Positions use
index_width and the existing internal-index timeline; gain and adjusted frequency
use activation_width and real timelines. The range is temporary, not input bytes;
its lifetime spans actual rotary/mask consumers. Prefix key indices/predicates
retain existing window rules. Cached storage uses real capacity; full-prefix
still performs no phantom capacity*KV stride/product/budget admission.

Semantic StorageEstimate must also charge the new produced positions at
index_width. Preserve its old eight-argument constructor via an explicit
compatible initializer, adding optional trailing index_live_bytes,
peak_temporary_bytes,temporary_peak_step fields. Legacy index timeline is empty
and temporary peak defaults to the old activation peak/step. Dynamic real and
index timelines are separate; total uses max(real_live+index_live), not the sum
of independent peaks. Existing activation_live/peak fields describe real values.
New dynamic descriptors show both timelines and the combined peak. Recompute
sizes,births/deaths,last uses and release order independently. No hardware fit,
actual index packing, allocator or physical placement is certified by this math.

All semantic/cache/matrix/storage/bias/activation/session/window and numerical
recipe consumers must reach the dynamic guard. Keep legacy diagnostics and full
outputs unchanged. Graphs with mutated metadata may not bypass a guard through
an older consumer API.

## Descriptors and acceptance

Only the explicit dynamic path uses schema8. It includes typed configured context,
complete before/after policy/history and charge, context output, conditional cache
history output, range producer/start and numeric dynamic Q/K/recipe/global fields.
Old schemas1..7 remain byte-for-byte unchanged. All source raw/default/null/legacy/
custom/training/unresolved fields remain available in the ordinary inspector;
ordinary_model_admitted and device_execution_verified remain false. New graph
storage output includes internal-index and combined temporary memory scenarios.

Rebuild the full affected import closure and new inspectors from one unchanged
source snapshot. Verify both scalar API variants and independent widths, actual
ordinary/indexed headers plus explicit GGUF mathematical scenarios, both session
modes/return flags, mixed NoPE/bias/activations/windows, partial tails and width2.
Compare all complete frozen legacy outputs. Independently derive positions,
histories, all15-step recipes/maps/domains/lifetimes, cache extents and real/index
storage timelines. Include growth beyond source context, retained peaks exceeding
current capacity, reset/equality, the noncoalescing history, unallocated large
full-prefix capacities, exact/short work and overflow boundaries. Mutate every
source/snapshot/start/range/word/recipe/domain/alias/export/accounting field and
exercise refusal/fresh-success cleanup with actual header/fd traces. No model,
layer or attention forward and no payload evaluation or inference-library oracle.

Publish verified implementation, exact remote tree/heads and FFmain, then continue
remaining architecture/format/scaling/training coverage and actual numerical Hailo
widths/packing/placement/register/CCW/configuration/program delivery/activation/
results/cleanup. Broad support is100%target. No outside compiler/machine, special
conversion, precompiled prerequisite, inference proxy or invented instruction.
