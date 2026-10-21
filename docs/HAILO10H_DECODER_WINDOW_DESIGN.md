# Original per-layer causal window integration contract

Date:2026-10-21. Parent TASK_hailo10h_ordinary_window_semantics.md. Owner scope:
HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. Publish before production changes.
Qualified public facts: HAILO10H_ORDINARY_WINDOW_AUDIT.md. This is original
mathematical compiler work; no numerical Hailo execution is claimed by design.

## Owned policy and source projection

Add DecoderWindowPolicy(Copyable,Movable): windows:List[Int], origin:String,
provenance:String, work:Int. Exactly one width/layer:0 means full causal,
positive means a window of that many keys including the current position.
origin is source or invocation; provenance is nonempty UTF8. All widths are
nonnegative Int; IntMax is permitted without allocation proportional to width.
Exact logical work charge129*layers+UTF8(origin)+UTF8(provenance), checked with
remaining-budget arithmetic before list growth/copies. Require layers>0,
work>0,work<=source.policy.work and charge<=work. Unique empty optional state:
windows[],origin/provenance empty,work0. Deep policy copies and full equality.

source_decoder_windows(architecture,provenance,work) validates the complete
original owned architecture/layer/config state first. It derives a fresh source
policy without removing raw fields, origins, dormant modifiers or unresolved
notes. For qualified SmolLM3 source fields:

- An explicit non-null layer_types list is authoritative for this projection;
  full_attention→0, sliding_attention→positive source sliding_window. Preserve
  conflicts with flags as raw facts; do not overwrite the explicit list.
- Absent/null types use qualified generation: a true use_sliding_window flag,
  non-null positive sliding_window and an effective NoPE bit select sliding;
  all other generated layers are full. max_window_layers is retained unchanged
  and is not a generation threshold for this pinned constructor behavior.
- Explicit sliding type with no positive window cannot produce this mathematical
  policy; report the missing source semantics precisely. Unknown type/architecture
  semantics remain required implementation, never permanent eligibility rules.
- Raw absent/null/default origins remain distinct in the architecture. A policy
  origin says source projection occurred, not that every source field was present.

Generic invocation policies are explicit mathematical choices. They must never
silently substitute for unresolved ordinary source semantics or certify an
ordinary model adapter. Source and caller owners remain independently inspectable.

## Semantic API, session and graph

Add typed DenseParams and Geometry+Scalars builder overloads with graph,bias,
activation,session,window policies before query,past,capacity. Require explicit
session for explicit window policy. Preserve all older overloads and unique
empty default window state. Add SemanticPlan explicit_window, owned window_policy
and exact window_work; PrimitiveRecipes owns independent matching snapshots.

Keep existing source projection/bias/rotary/Q/K/V selection, cache-return mode,
formal exports, context capacity and all scalar words. full_prefix still has
past0 and no persistent cache/append/views. cached_append retains complete prior
cache bases/views. This slice selects masks; it does not evict/compact caches,
change capacity products, physical storage or formal returned K/V contents.

For window0 retain the exact existing causal_mask operation and old topology.
For positive window select causal_window_mask with the same scores and positions
inputs, output identity and [heads,query,past+query] shape. A mask policy validator
must run before any consumer indexes widths. Session validation selects the
expected mask kind only after validating the window owner; legacy state with
stray fields refuses. Bind the selected numeric width independently in each
SemanticOperation.window_tokens field, with optional trailing constructor/emit
argument default0. Positive source-mask width must equal the owned per-layer
policy; every other source operation has0. This detects positive-to-positive
policy mutations before lowering, rather than silently reinterpreting an already
constructed graph. Serialize this source operation metadata only in explicit
window schema6; complete older outputs remain unchanged. Exact per-layer mask identity, producer/consumer/source
edges, counts, no bypass/duplicate, outputs and lifetimes must be rederived.

## Original mathematical recipe

Lower each causal_window_mask to three original abstract operations. Input0 is
scores[heads,query,total] real; input1 is positions[query] index. Recipe owns the
positive window_tokens metadata and full source inputs/input_values mapping.

1. prefix_key_indices: no inputs, index[total], values0..total-1.
2. causal_window_predicate: positions and indices, predicate[query,total].
   Valid iff key<=absolute_query_position AND
   absolute_query_position-key<window_tokens. Check the causal relation before
   subtracting, avoiding signed overflow. At runtime positions equal past plus
   query index and are valid nonnegative positions inside the admitted context.
3. select_negative_infinity: scores and predicate; real[heads,query,total].
   Broadcast the same predicate over heads. Retain valid scores and replace
   invalid entries by mathematical negative infinity. This is a mathematical
   domain, not a device representation or opcode.

Recipe-local products/lifetimes are exact. All input positions/keys metadata
remain index-domain; predicate is separate and never charged as real storage.
Result retains source last uses and existing softmax preconditions. At least the
current key is in every valid row for positive window; no scores/softmax/attention
are evaluated in acceptance. Full causal operations remain unlowered exactly as
before in this slice. Device precision/transcendental/configuration stays open.

Add dedicated window_tokens metadata to PrimitiveRecipe and ExpandedOperation
(default0 for every old path). Preserve the old ExpandedOperation positional
constructor with an optional trailing field. Preserve exact source/recipe/global snapshots,
inputs, shapes, domain and lifetime validation. Recompute expected recipe state
rather than trusting serialized metadata. Expanded storage validates the new
index/predicate/broadcast roles and exact hypothetical byte timelines. Internal
prefix indices are ephemeral activation storage in the index domain, charged by
index_width and a separate index_live_bytes timeline; they are neither external
input_bytes nor real-domain activation bytes. activation_live_bytes and its peak
sum real, predicate and internal index timelines. Preserve the old storage-result
positional constructor via an optional trailing index timeline. Serialize that
new timeline only for explicit window output; legacy complete JSON is unchanged.
Cache,
matrix, semantic storage, bias/activation/session guards must validate window
state before relying on the selected mask; no recursive guard cycle.

## Serialization and compatibility

Only explicit window output uses schema6, reporting owned policy/charged_work
and recipe/global window metadata. Existing session schema5 and older complete
outputs must remain byte/JSON identical, with no stray new metadata. An explicit
all-full policy must match the prior session output after removing only explicit
window/schema descriptors. Source scalar32/64, session mode/return/exports,
projection/bias/activation and rotary representations remain exact.

## Required independent acceptance

Before code copy all51 verified entrypoints with modes/hashes as frozen controls.
Archive the complete178-file current Mojo source manifest and exact commands.
Rebuild every affected shared-import consumer plus new tool/API/ownership probes
from one unchanged source snapshot. Preserve all failed/preliminary artifacts.

- Real owned ordinary tiny source headers: explicit/full/sliding/mixed patterns,
  missing/null/default fields, true/false flags, dormant positive windows,
  max_window_layers, masks, malformed/unknown inputs and exact source ownership.
- Independent bounded integer predicate sets at window1,below/equal/above total,
  IntMax; past0/nonzero and query1/multiple. Boundary at q-W is excluded and
  q-W+1 included. Never evaluate model/layer/projection/attention forwards.
- Exact source/source32/64/recipe/global maps, formal cache exports, score and
  positions identity, source counts, runtime assumptions and every local/global
  shape/product/lifetime/storage sum. No physical cache-compaction claim.
- Policy empty/flag/origin/width/count/provenance/work/overflow mutations; source
  default/derived mutations; mask bypass/kind/edge/source/output mutation; recipe
  metadata/local/global/input/domain/lifetime/source snapshot mutation; all
  downstream consumers must refuse. Invalid sessions must still refuse first.
- Mutate caller policy/list/provenance/geometry/scalars/source inputs after
  construction; prove independent resulting plan and recipe snapshots. Repeated
  refused→fresh-success cycles with fd close/header-read/unchanged-byte traces,
  no model payload mmap, device/library inference or network access.
- Complete frozen prior session ordinary/GGUF outputs, both session modes and
  return choices, explicit all-full normalized comparisons and the existing
  source/recipe/cache/matrix/storage regression closure across51 rebuilt
  predecessors. Publish targeted
  counts without claiming whole-repository or hosted CI success.

Broad ordinary formats/architectures/activations/scaling/training semantics,
immutable source identity and numerical Hailo precision/packing/placement/
register/CCW encoding/upload/activation/results/cleanup remain required work.
No DFC, outside compiler/machine, special conversion or inference proxy. Only
Hailo-10H performs LLM execution. No guessed device instructions or host metadata/
resource-fit evidence can close that boundary. Verify, publish, sync main and
continue automatically.
