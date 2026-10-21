# Original source activation policy and mathematical recipes

Date:2026-10-21. Publish before code. Active child:
TASK_hailo10h_decoder_activation_policy.md. Bias arithmetic is verified on both
branches c7a94b5. Fixed broad source-model/Hailo-only execution scope remains
docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.

## Qualified interface/math facts

The pinned4.57.1 selector interface maps silu, gelu and relu to distinct
activation classes. GELUActivation's default act object is exactly Torch's
functional gelu callable; no activation module forward was called. gelu_new,
gelu_fast, quick_gelu and relu2 select other classes: their numerical semantics
must not be inferred from their names or silently aliased to default GELU.

PyTorch2.11 documents GELU's default approximation as none, with Gaussian-CDF
semantics. Its tanh choice is explicitly a different approximation. SiLU is
x*sigmoid(x); ReLU is max(0,x). Eight isolated functional primitive vectors
check136 finite-real scalar outputs against independent real identities in
binary32/64. Default/tanh GELU differ by about0.0004123 on these samples.
Module/direct-forward guards exclude model/layer/attention evaluation, and
traces show no connection, Hailo device or source-weight load. Signed zero,
NaN/infinity, transcendental approximations and hardware arithmetic remain open.
The separately reviewed Apache2 and Torch BSD/bundled license hashes were
checked before the final primitive probe imported those packages.

Primary declarations:
[GELU](https://docs.pytorch.org/docs/2.11/generated/torch.nn.GELU.html),
[SiLU](https://docs.pytorch.org/docs/2.11/generated/torch.nn.SiLU.html),
[ReLU](https://docs.pytorch.org/docs/2.11/generated/torch.nn.ReLU.html).
Exact isolated test program, output, audit and license/module identities:
evidence/activation-primitive-facts-2026-10-21/. No external implementation is
copied/translated and no external package becomes a production dependency.

## Exact original owned API

Add DecoderActivationPolicy(Copyable,Movable): kinds:List[String],
provenance:String, work:Int. Initial mathematical identifiers are silu,
gelu_erf and relu. One identifier per layer is required. Work must be positive
and no greater than source.policy.work. Charge128*layers+provenance.UTF8+
sum(kind.UTF8), with checked arithmetic and admission before allocation/copy.
The unique empty optional policy has empty list/provenance and work0. Other
functions/approximations remain implementation work, never permanent model
eligibility restrictions or authority to narrow the owner's target.

Add source_decoder_activations(architecture,provenance,work), which validates the
existing complete owned SourceDecoderArchitecture, then projects qualified
silu→silu, gelu→gelu_erf and relu→relu into a repeated owned per-layer list.
Retain the original owner, raw selector, default/source origins, all unknown
fields and unresolved modifiers; do not rewrite it or claim a complete ordinary
adapter. Unknown/other selectors must remain explicitly unresolved work.

Add build_decoder_semantic_plan overloads for DenseDecoderParameters and for
DecoderGeometry+DecoderScalars, followed by existing DecoderGraphPolicy,
DecoderBiasPolicy, new DecoderActivationPolicy and query/past/capacity. Keep
existing overloads unchanged. SemanticPlan gains explicit_activation, an owned
activation_policy and charged activation_work. Legacy construction retains false,
the exact empty state and0. Existing old gate_silu names/operations stay identical.
Explicit alternate kinds use corresponding gate_gelu_erf/gate_relu nodes after
the selected source bias and before the gate/up multiplication. Preserve actual
source32/64 words and all graph shape/session/output decisions.

Validate exactly one selected gate activation per layer, with the correct
linear/bias source input, shape/product, consumer and producer/last uses. Reject
stray legacy state, changed policy/accounting, unknown kinds, wrong source role,
omitted/duplicate activation, bypassed activation and stale graph state. Add the
same state guard to actual cache/matrix/semantic-storage consumers so unchanged
shapes cannot conceal a substituted activation.

## Mathematical primitive/expanded contract

Existing SiLU lowering stays unchanged. Original gelu_erf lowering uses the
finite-real identity0.5*x*(1+erf(x/sqrt(2))): five typed operations
multiply_inverse_sqrt_two, erf, add_one, multiply and multiply_half. The algebraic
sqrt(2) and rational half are defined by these mathematical operation semantics;
do not round them into a hidden source Float32 constant or invent device bits.
Original relu lowering emits maximum_zero. These are mathematical primitives,
not Hailo opcodes or evidence of supported device transcendental arithmetic.

Every new recipe preserves the full activation input/output mapping and real
domain, with explicit finite-real/precision-unqualified preconditions. It has
no source weight, epsilon, rotary base or divisor. PrimitiveRecipes owns the
activation-policy/work snapshot. Expanded/storage validation compares it with
the source owner and exactly rederives new recipes, source/local/global edges,
metadata/domains and lifetimes. No in-place alias or hidden cache allocation.
Explicit activation descriptors use schema4 alongside existing scalar/bias
metadata; all legacy schemas and complete outputs remain unchanged.

## Acceptance and automatic continuation

Freeze current consumers. Independently verify per-layer mixed choices, source
selector projection/defaults, bias-before-activation order, complete graph and
recipe mappings, all lifetimes/storage, exact work limits and source32/64 metadata.
Exercise copied-input independence, retained/derived mutations, invalid/missing
roles/flags/kinds/policies, overflow and refusal/recovery/cleanup. Use only tiny
isolated single-primitive numerical checks; no full model, decoder layer or
attention forward. Rebuild all affected consumers and compare complete frozen
legacy outputs. Preserve negative and concurrent work.

Publish verified code/evidence, verify both branch heads and continue ordinary
scaling/window/cache/training/full graph semantics plus actual numerical Hailo
encoding/precision/packing/placement/configuration/upload/activation/results/
cleanup. No DFC, outside compiler/machine, user conversion or vendor-compiled
model prerequisite. No host graph or primitive oracle certifies hardware fit,
device execution or completion of the fixed broad source-model objective.
