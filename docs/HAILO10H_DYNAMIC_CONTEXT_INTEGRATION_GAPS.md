# Source context and invocation extent integration boundary

Date:2026-10-21. Follows original standalone dynamic context/coefficient
implementationce43d0f. Broad ordinary models and Hailo-only execution remain fixed.

## Observed current coupling

Current ordinary scaling inspector constructs DecoderGeometry.source_context from
the retained architecture's max_position_embeddings. validate_decoder_geometry
requires context_capacity<=source_context, alongside positive query and bounded
past+query. Existing source words are correctly retained, but this single bound
also prevents testing a dynamic selected frequency context above the configured
baseline through that graph path. A larger cache bound must not be substituted
into the original source field to make validation pass.

Five actual frozen scaling-graph calls use a two-layer synthetic ordinary header
fixture with configured context8, raw dynamic factor2 and nested original context4.
The one positive control selects an explicit invocation default recipe with
query1/capacity8; it does not admit the source dynamic variant. Its complete
original source snapshot remains present and ordinary_model_admitted=false.

| Invocation | Observed existing boundary |
|---|---|
| Explicit default, query1/capacity8 | Mathematical graph accepted |
| Explicit default, query1/capacity9 | Session/context extent refused |
| Explicit default, query9/capacity9 | Session/context extent refused |
| Explicit dynamic, query1/capacity8 | Unimplemented scaling policy refused |
| Explicit dynamic, query9/capacity9 | Session/context extent refused first |

All five traces contain exactly two synthetic weight-header reads; every request
ends within the declared header extent. No payload read, network connect, ioctl,
model/layer/attention execution or device operation occurs. No production code
changes or new executable capability are claimed by this audit. Exact scripts,
results, negative errors, trace audit, original archive identities and frozen
manifests are under evidence/dynamic-integration-gap-2026-10-21/. Raw fixture and
full traces stay outside Git. All199 source hashes/65 accepted controls are frozen:
the previous64 binaries are retained and the new accepted probe copied separately.

## Required original integration decisions

The next exact pre-code contract must keep at least these meanings distinct:

- The untouched configured source context, its default/source origin and any
  separate raw original-context field. A qualified family/version rule selects
  the dynamic baseline; a generic field name alone does not select it.
- The invocation's actual position range and initialized past extent.
- Current cache allocation capacity and an explicit mathematical index bound.
- The retained frequency context before and after selection. A retained peak can
  exceed a later short invocation's cache capacity; capacity is not its identity.
- The source-bound exact theta/factor words, rotary width/pairing, NoPE selection
  and insertion-basis provenance of previously stored keys.

Preserve old constructor signatures, complete outputs and conservative bounds.
Add an explicit context-aware path that can represent source-qualified dynamic
growth without overwriting original source evidence or silently changing old
admission. Such mathematical permission does not certify trained quality,
physical memory fit, device precision or execution. Cached mode still charges
actual allocated extents; full-prefix mode must not acquire phantom capacity
products. Do not force retained frequency state to equal a cache allocation size.

The contract must state whether each cache segment retains its insertion basis
or a separately authorized mathematical transform occurs. The pinned source
observations support insertion history at the ordinary append boundary; they do
not justify silent whole-cache rephasing or full-prefix decoder equivalence.
Require independent snapshots/revalidation at semantic, recipe, expanded, cache,
matrix and storage consumers, with exact maps/domains/lifetimes/accounting and
mutation/refusal/recovery acceptance. No native source integration code may be
written before that exact contract is published. No full-prefix-only permanent
restriction, outside compiler or special model conversion is introduced.

Continue TASK_hailo10h_dynamic_decoder_integration.md. Actual Hailo numerical
widths/packing/placement/register/CCW/configuration, program delivery/activation/
results/cleanup and source-model execution remain open under the parallel
numerical-encoding work order. No new encoding field or unsafe hardware path
was established in this slice; never invent opcodes.

Local consistency remains failing:baseline23296, late tracked-log receipt
23297, corrected current23296. The zero-byte native build receipt was
renamed from build.log to build-diagnostics.txt, preserving identical bytes, Git
history and outside originals. The runtime-state artifact diagnostic is removed.
No new nonreceipt issue after Markdown line normalization; ledger114/159 unchanged.
No whole-repository or hosted-CI pass is claimed.
