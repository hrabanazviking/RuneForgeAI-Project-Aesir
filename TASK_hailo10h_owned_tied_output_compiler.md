# Resolve present tied output through retained ordinary source ownership

Date:2026-10-23. Publish before production implementation. Parent:
`TASK_hailo10h_source_compiler_plan.md`;controlling scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Design:`docs/HAILO10H_TIED_OUTPUT_GRAPH_DESIGN_2026-10-23.md`.

## Exact original implementation scope

Only these old production files may change:
`smidr/semantic_plan.mojo`,`smidr/bias_graph.mojo`,
`smidr/expanded_graph.mojo`,`smidr/owned_ordinary_compiler.mojo`,
`smidr/tools/semantic_plan.mojo`.
Add original`smidr/source_weight_sharing.mojo`and
`smidr/owned_tied_output_compiler.mojo`,plus scoped inspector/test leaves.
Zero old test edits. No source parser,constant decoder,hash,dtype converter,
numerical recipe,operation mathematics,device interface or storage arithmetic
body may be copied or replaced.

Introduce typed owned source-weight sharing records and an empty default policy.
Store copied intent and checked work on SemanticPlan. Thread an optional empty
default through the existing full source-scalar decoder builder and the existing
owned ordinary `_ordinary_plan`composition. Historical constructors/entrypoints,
default plan fields,old JSON,math choices and refusal messages must remain exact.
Only nonempty sharing adds new conditional diagnostic fields. Reuse the one
existing builder and all source modifier/scalar/bias/activation/session/window/
scaling/rotary adapters;do not duplicate their implementations.

Initially qualify at most one relation:present output to selected embedding.
Validate positive bounded provenance/work,exact source names and compatible
tag/kind/axes/full shape/elements/spans before copying caller intent. The target
must be actually used by an operation. Reject cycles,self-relations,duplicates,
unknown/extra aliases,unconsumed targets and stray empty-policy state. A common
original source-set validator must require exact coverage by actual operation
uses plus the explicit checked relation. Do not insert fake operation uses or
mark unused weights as directly consumed. Wire it into semantic and bias checks.
Retain all existing producer,shape,edge,bias and last-use validation.

Expand a distinct ordinary source-constant reference for each retained alias
name before final source-weight lifetime finalization. Keep every original
binding and full packed byte count;the existing complete expanded-storage
validator must pass unchanged. Do not deduplicate physical source weights or
weaken its source/value/map/byte/lifetime checks. No new device-fit claim.
All numerical recipe operations and scalar words remain unchanged.

Extend existing guarded semantic operation selection to compare sharing intent,
charge and coverage before a component read. Existing empty-policy compiler
paths must reject a forged nonempty sharing state. New pure mathematical
sharing descriptors remain structural input assumptions,never byte-identity
credentials or authority to submit executable work.

## New owned compiler branch and actual source qualification

New movable indexed/unindexed wrappers retain an existing owned ordinary binding,
ExpandedGraph,owned compilation request,sharing intent and explicit positive
total comparison/chunk bounds. Compose existing factories. Reuse the published
`compare_owned_indexed_tensors`/`compare_owned_unindexed_tensors`and their full
actual binding refresh/schema guards;never trust an editable returned equality
flag or claimed hash. Reuse existing request comparison/admission,graph expansion,
operation selection and binding component readers.

Before graph construction and every guarded static operation read,freshly derive
the existing qualified source tie/output decision and compare the complete two
stored representations. Require a tied decision with both names present,equal
raw bits and compatible layouts. Preserve exact source origins/defaults,
schemas,files,spans,names and unresolved notes. Construct sharing only from that
freshly checked source/request decision. Refuse unequal bytes or contradictory
tying;leave wider conversion/architecture semantics as required compiler work.
Do not flip tying,treat the source as untied or remove its output tensor.

Before selecting retained components,rebuild actual sharing/graph intent and
compare every consumed policy/request/source/operation/sharing field against
the retained graph. Reuse existing scalar/recipe/rotary validators and complete
source comparisons. Source owners stay retained;copied result windows survive
close. New wrappers close their owned binding with existing error semantics.
No new fd duplicate,raw OS interface,path/proc/label reopen,remap or source rewrite.

This branch is an internal Aesir loader/compiler capability. It is not a special
model-conversion workflow,user compilation requirement or model eligibility rule.
Historical entrypoints keep their current behavior,including four tied duplicate
fixture refusals;the new qualified entry admits actual equal duplicate sources.
Missing formats,architectures,operators and alias kinds remain required work
toward broad ordinary unmodified model support100%.

## Pre-code and native acceptance

Actual698 source/84 Python copies,152 immutable controls,compiler identity and
closed-input never-executed composition probe are frozen under
`docs/evidence/tied-output-contract-2026-10-23/`. Reverify all actual copies and
controls and freeze a new baseline immediately before production.
Recompute the complete affected qualified consumer closure after implementation;
link every affected qualified control and every new/auxiliary test consumer
with final source/test copies before any acceptance execution. Being in the
import census does not authorize running unqualified model/device entrypoints.

Use independent tiny indexed/unindexed ordinary fixtures with genuine equal
duplicate payloads across all3 current representations,both same/different
shards,partial tails and exact bound edges. Verify complete source/alias/scalar/
policy/recipe/expanded graphs,actual operation uses,both source-constant mappings,
full packed-byte/lifetime accounting and independently checked raw/F32 component
windows. Compare the mathematical operations against a separately retained
embedding-only structural reference without dropping either real input binding
from the qualified graph. No host model/layer/attention forward may run.

Cover untied,absent-output,unequal-duplicate,kind/shape differences and every
source modifier currently handled by the ordinary compiler. Keep unsupported
variants explicit work. Check both rotary pairings,query/KV geometry,source
scalars,bias flags,NoPE,session/windows/scaling and original files changed after
ownership. Preserve complete old stdout/stderr/exit/handled messages with full
file/directory restoration and independent fault-log comparisons.

Mutate every alias name,target,provenance,work,policy,bound,source intent,retained
comparison result,semantic use and expanded source map/value/count/lifetime.
Require fresh raw-byte revalidation or refusal before any wrong component read.
Test cycles,duplicate/extra names,missing targets,forged empty/nonempty policies,
forged source extents/seals,caches,moves/close and reported copy/hash/read/close
failures,each followed by fresh success. Keep independent owned descriptions
and windows across close. Retain every failed build/test/audit attempt.

Audit actual PID/fd-generation/map/hash/read/cleanup joins and all supporting
source identities. Inspect ELF dependencies separately. No device access,
network,inference runtime or outside compiler effects. No fabricated return or
omitted opaque trace. Scope acceptance to actual observed source-sharing
reconciliation and mathematical lowering. It is not generic artifact identity,
complete architecture admission,numerical H10H configuration,placement or model
execution. Actual packing/CCW/transport/activation/results/cleanup remain active
under`TASK_hailo10h_numerical_encoding_sources.md`;no invented opcode,device write,
DFC,external machine,vendor-artifact prerequisite or host/CUDA/cloud inference.
Verify -> publish Hailo -> exact remote head/tree -> preserve concurrent owner
work and fast-forward main -> verify clean checkouts -> continue automatically.
