# Explicit two-input rotary mathematical lowering

Date:2026-10-21. Contract before code. Parent:
TASK_hailo10h_ordinary_rotary_modifiers.md. Defaults published on both branches
eb20613. Broad ordinary source-model target and Hailo-only execution unchanged.

## Evidence and current compiler dependency

The current typed rope_query/rope_key nodes have activation and position inputs.
PrimitiveRecipe has only one mapped source input; expanded graph hardcodes local0
and optional norm-weight1. It leaves rotary opaque. Storage accepts the opaque
position operand as index, but lacks an explicit angle-construction index rule.
A full ordinary source adapter cannot safely assume a component pairing from
shape, safetensors format or the GGUF source_layout string.

Licensed isolated static public-callable observations under4.57.1 establish
split-half pairing for that qualified SmolLM3 interface. Five vector cases and18
frequency cases, module/license identities and initial negative results are in
`evidence/rotary-static-facts-2026-10-21/`. A global Module.forward prehook
rejected any forward; none occurred. No model or weights were instantiated.
The final syscall trace records no connect/Hailo open. Default static frequency
observations differ from ideal real exponent by up to2.9196e-7; this is not a
backend precision certificate. No external implementation was copied/translated.
The abstract mathematical rotation concept is described by
[RoFormer](https://arxiv.org/html/2104.09864v5). The original implementation below
is derived independently from the elementary two-dimensional rotation identity.

## Exact API and compatibility

Add owned Copyable RotaryLoweringPolicy(pairing,provenance,max_recipes,work).
Pairing is explicitly adjacent or split_half; no default basis. Provenance must
be nonempty. Old lower_primitive_recipes(plan) and expand_semantic_graph(plan)
retain exactly their outputs and opaque rotary nodes. New overloads taking the
explicit policy expand rotary in addition to the existing norm/SiLU/softmax.
No source format/model name automatically selects a basis.

PrimitiveRecipe gains owned source_inputs and input_values, preserving singular
source_input for compatibility. Existing unary recipes map source input to local0;
norm vector retains local1. Rotary maps activation to local0, positions to local1.
It also retains rotary_dim, exact existing semantic Float32 rope_base bits,
explicit pairing and copied provenance. No silent Float64 source-config narrowing:
ordinary scalar-to-typed-plan precision reconciliation remains required work.
The current typed source base is used exactly; policy cannot override it.
ExpandedOperation carries the same rotary metadata, zero/empty for old operations.
Existing tool schemas stay unchanged; a new opt-in inspector exposes the metadata,
source/local/global mappings and recomputed storage. Old outputs must match fully.

## Original mathematical recipe

For activation [Q,H,D], index positions [Q], even R<=D, P=R/2 and positive finite
base b, use13 explicit operations,15 values including the two source inputs:

1. rotary_inverse_frequency: no inputs, real[P], component j denotes b**(-2*j/R).
2. rotary_angles: positions and frequency, real[Q,P], angle[t,j]=position[t]*freq[j].
3. cos and4.sin: real[Q,P].
5. rotary_first and6.rotary_second: activation -> real[Q,H,P], gather explicit pairs.
7. multiply_rotary_cos(first,cos),8.multiply_rotary_sin(second,sin),
9.subtract: rotated first, all real[Q,H,P].
10.multiply_rotary_sin(first,sin),11.multiply_rotary_cos(second,cos),
12.add: rotated second, all real[Q,H,P].
13.rotary_assemble(first',second',original activation): real[Q,H,D]; scatter into
explicit pairs and copy components>=R unchanged. No inference from physical axes.

Adjacent pairs=(2*j,2*j+1); split_half pairs=(j,j+P). Both use
first'=first*cos-second*sin, second'=first*sin+second*cos. Broadcast angles only
across heads. Q/K can have different head counts; NoPE yields no rotary recipe.
These names are mathematical IR operators, never invented device opcodes.
The inverse-frequency node is an explicit symbolic compiler constant definition,
not a source weight, cached table, host numerical kernel or placed device table.

## Admission, ownership and validation

Before recipe allocation, validate pairing/provenance/positive policies, scan
source operations, enforce actual rotary count<=max_recipes. Charge exact coarse
work=len(source.operations)+count*(128+pairing.UTF8+provenance.UTF8), using checked
sums/products, <=work. This is a conservative descriptor-work unit, not bytes or
hardware fit. No array of Q*H*D numerical data is allocated. Source operation and
all shape products remain checked; malformed arity/IDs/order/lifetimes/source
weights/aliases/persistent outputs reject. Positions must be the actual external
positions tensor, rank1/query length and producer-1; input/output [Q,H,D] exact,
head count by query/key role, valid rotary extent/base. Returned descriptors and
policy strings own their storage; source mutation cannot alter snapshots.

Expanded graph maps every source input explicitly, preserves index domain and
recomputes all producers/last uses/source exports/KV aliases. Storage recognizes
only rotary_angles operand0 as index. All new intermediates are produced real
activations, so existing hypothetical storage accounting charges them by their
actual shapes/lifetimes; no uncounted constant arena is asserted. Validate all
rotary expansion kinds/edges/shapes/metadata/mappings against independently
rederived selected recipes before estimating; reject stale or fabricated rotary
metadata, stray metadata on nonrotary nodes and an opaque rotary under an enabled
policy. Preserve old general storage validation and complete legacy outputs.

## Acceptance / next step

Independently assert every recipe/local/global edge, shape/product/domain and
inclusive lifetime for both bases, R<D tails, unequal Q/K heads, NoPE masks,
multiple sessions/layers and source representations. Tiny synthetic single-
primitive vectors only: compare both bases against independent 2x2 rotation,
plus qualified static oracle cases, and check identity/tail/norm properties.
Never execute model/layer/attention math. Add exact policy work boundaries,
overflow/malformed source/derived graph refusals, copies/ownership and actual
source read-only syscall checks. Freeze current compiler tools and compare full
legacy output; rebuild all affected recipe/expanded/storage/downstream consumers.
Retain failures and raw evidence. No capability claim until final acceptance.

Source modifier adaptation, architecture/format breadth, numerical device widths,
approximations, packing, placement, actual Hailo instruction/register/configuration,
upload/activation/results/cleanup remain open. No model files, DFC, external
compiler/machine, user conversion, vendor artifact or inference proxy prerequisite.
After this slice publish/verify, continue those gaps automatically.
