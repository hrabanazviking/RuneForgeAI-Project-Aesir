# Explicit decoder graph and cache policy

Date:2026-10-20. Contract: `TASK_hailo10h_decoder_graph_policy.md`.
Pre-code API/consumer contract was published on both branches at232fdad in
`HAILO10H_DECODER_GRAPH_POLICY_DESIGN.md`. Fixed owner scope remains
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Original Mojo implementation

`semantic_plan.mojo` now owns Copyable/Movable DecoderGraphPolicy with
rope_enabled:List[Int], output_weight:String and provenance:String. Every
SemanticPlan independently owns its policy. The general constructor has an
empty placeholder for existing standalone mathematical graphs. Complete decoder
construction and cache planning require a complete validated policy.

build_decoder_semantic_plan(source,parameters,policy,query,past,capacity) accepts
the checked tagged SourceTensorInventory and the existing mathematical
DenseDecoderParameters. It validates source inventory, dimensions/session,
exact mask length and integer0/1 entries, explicit output binding/shape and
nonempty bounded provenance before copying policy. Layer count is bounded by
source tensor evidence and its admitted tensor policy. Mask entries plus UTF-8
provenance/output-name bytes must fit the admitted source work limit. This is
an allocation bound, not a new claim about architecture or device compatibility.
Every source weight still has to be consumed by the selected recipe.

The source-neutral typed builder does not infer output ties from missing names.
Existing build_dense_semantic_plan/read_dense_semantic_plan preserve their GGUF
recipe gate, all-rotary flags and historical output selection in a wrapper.
Their inspectors retain every existing field and output. This typed API is not
yet the ordinary source configuration/alias/layout/modifier adapter.

A zero mask entry omits both rotary operations and both result tensors. Actual
unrotated Q/K linear results feed attention and cache append. Positions remain
for causal masking. Existing emit/tensor machinery recalculates operation/tensor
IDs, producers, inclusive last uses, persistent lifetimes and aliases. Explicit
source dimensions, floating parameter bits and unresolved layout/precision/
component-pairing gates remain intact.

Cache planning validates the owned policy and explicit output binding/shape.
Rotary keys require the named rope_key writer, checked direct key projection
and actual positions input. NoPE keys require the direct linear key writer;
stray named rotary tensors disagree with that policy. Append identity, source
projection tag/shape/weight, normalization dependency/identity, producer ordering,
ownership and exact projection/writer/position/view lifetimes are checked.
Value-cache behavior and hypothetical relative addresses remain compatible.
No missing-name fallback or fake rotary node is introduced.

Other recipe/expanded/storage/matrix/live-byte consumers traverse actual graph
edges. Their audit found no additional unconditional rotary-writer dependency.
The expanded index-domain rule continues to apply to actual present operations.
The new inspector exercises expansion, expanded/source storage, all linear
schedules and cache regions together with the full semantic graph.

Native inspector: `smidr/tools/decoder_graph_policy.mojo` takes explicit typed
policy plus a GGUF metadata fixture. Test API additionally connects actual
single/multiple safetensors files using explicit synthetic canonical names and
parameters, and a mask from owned ordinary decoder intent. Whole raw config
snapshots and unresolved modifiers survive. None of these test connections
claims a complete ordinary architecture adapter or numerical execution.

## Acceptance

**99 methods/2711 native calls pass**:5 new/152 calls (81 accepted,71 expected
refusals),40 complete new graph comparisons;14 rebuilt regression suites/94
methods/2559 calls, including108 complete frozen consumer comparisons.
Final targeted results and source/binary hashes are under
`docs/evidence/decoder-graph-policy-2026-10-20/`. Independent Python structural
surgery removes selected rotary vertices from frozen complete reference graphs,
rewires actual projections, then independently recomputes IDs, producers,
lifetimes and aliases. It never evaluates a model, layer or attention forward.

Coverage includes all masks for1–4 layers, tied/untied explicit outputs, varied
sessions/value widths, the36-layer periodic27/9 pattern, existing packed source
kinds, actual F16/BF16/F32 safetensors tags/shards/full axes, owned intent/config,
policy ownership/bounds and direct/rotary cache mutation refusals. Cache relative
regions/last addresses and matrix tile counts have independent arithmetic
oracles. Expanded mappings/dependencies/aliases/lifetimes and source storage are
checked independently. Existing nine frozen consumer outputs are compared in
full, alongside all affected compiler/source-byte regressions.

The initial list-construction and inspector dictionary/list compile failures
are retained with the passing initial suite. Additional cache position/norm/
output checks were followed by clean rebuilds and fresh final verification.
No device access, inference library, original program upload, hardware fit or
source-model execution is claimed. Historical master CI/toolchain failures and
whole-repository consistency diagnostics remain separate from targeted results.
Consistency reports13507 diagnostics:12480 baseline plus1027 new raw receipt
path diagnostics, no new nonreceipt issue after normalizing the shifted
preexisting DEVLOG line number. No full repository pass is claimed.

## Next automatic work

Continue `TASK_hailo10h_decoder_architecture_intent.md` under the ordinary
semantic adapter: establish actual dimensions, source aliases/orientation,
output tie/bias, rotary pairing/scaling, norm/activation and window semantics
from licensed public interfaces and retain all unresolved modifiers. The full
numerical Hailo instruction/configuration, precision/packing/placement, original
program upload/activation/results/cleanup path remains required. Broad model
support stays the target; no external compiler or special user conversion is a
prerequisite, and missing coverage remains implementation work.
