# Original owned rotary scaling compiler contract

Date:2026-10-21. Parent TASK_hailo10h_ordinary_scaling_semantics.md. Fixed owner
scope HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. Publish before production edits.
Qualified primary/configuration/constant facts: HAILO10H_ORDINARY_SCALING_AUDIT.md.
This slice adds selected mathematical source semantics. It cannot certify a
complete ordinary adapter, numerical precision, context extension quality or
Hailo execution. Broad support remains the fixed target. Other variants and
architectures are continuing implementation work, never permanent eligibility
restrictions. No DFC, external compiler/machine or special user conversion.

## Owned policy and exact representations

Add DecoderScalingPolicy(Copyable,Movable): kind:String, factor:ScalarWord,
origin:String, provenance:String, work:Int. Initial implemented kinds default
and linear. default requires the exact positive unity value in binary32 or
binary64; linear requires a finite positive factor, including values below1
as explicit mathematical choices. Factor representation is independent of base
representation: preserve every original width/bit, without implicit narrowing.
origin is invocation, source:absent, source:null, source:modern or source:legacy.
provenance is nonempty UTF8. Logical descriptor charge is exactly
160+UTF8(kind)+UTF8(origin)+UTF8(provenance). Check positive work, work no larger
than source.policy.work, and every remaining-budget addition before copies.
Use existing ScalarWord validation (including zero upper bits for binary32).
The unique empty optional state has empty strings, factor(width0,bits0),work0.
Provide empty/equality/charge/validation helpers and deep independent copies.
No work or allocation grows with a factor's numerical magnitude.

## Qualified source projection

source_decoder_scaling(architecture,provenance,work) validates the entire original
SourceDecoderArchitecture/layer/config owner before deriving a policy. Keep
caller-owned complete raw/default/dormant/unresolved fields untouched. No source
normalization, unresolved-note deletion or numerical model admission occurs.

For the currently qualified SmolLM3 configuration interpretation:

- Absent rope_scaling yields kind default, binary64 unity, origin source:absent.
  Explicit null yields the same mathematics with distinct origin source:null.
- An object is independently parsed with the existing strict SourceConfig parser
  under the architecture's bounded bytes/field/work/depth policies. Its complete
  raw source was already validated; duplicate decoded keys, malformed nested
  JSON, trailing data, invalid UTF8 and bounds still refuse. Parser admission
  charges its own4*bytes+fields separately from the selected descriptor charge.
- A present legacy type selects the kind and origin source:legacy, including a
  conflict with rope_type, matching the pinned public constructor observation.
  Otherwise require a string rope_type and origin source:modern. Preserve both
  original selectors and any disagreement in the complete raw source owner.
- Selected default uses exact binary64 unity. A factor or variant-specific/custom
  key remains raw/dormant source evidence; the selected default mathematics does
  not silently consume it. Selected linear requires a JSON number factor that
  parses to finite positive binary64; preserve its resulting64-bit word exactly.
  Boolean/string/null/missing/nonfinite/nonpositive factors refuse this projection.
- Missing/unknown selectors and other variants report precisely that their
  source lowering remains implementation work. Successful external constructors
  with warnings are not mathematical admission. pretraining_tp, custom fields,
  training/inference intent and all other modifiers stay unresolved and retained.

This projection selects one mathematical rule from a qualified source profile.
Generic invocation policies express caller choices; they do not resolve an
ordinary model's remaining semantics. Never substitute invocation default when
source projection refuses. The inspection tool must retain and serialize the
complete original source and continue reporting ordinary_model_admitted false.

## Semantic ownership and source-operation binding

Add new DenseDecoderParameters and DecoderGeometry+DecoderScalars builder
overloads with graph,bias,activation,session,window,scaling policies before
query,past,capacity. Preserve every existing overload and complete output.
Require explicit session/window ownership for the new combined path; these are
mathematical choices, not a new source-model format requirement. Add explicit_scaling,
owned scaling_policy and exact scaling_work to SemanticPlan and matching owned
PrimitiveRecipes snapshots. Validate before copying policy state.

Bind selected kind and complete factor word independently on each enabled
rope_query/rope_key SemanticOperation. Add optional trailing constructor/emit
metadata arguments after existing window_tokens, preserving all old call sites.
Every other source operation has the unique empty scaling metadata state.
Disabled NoPE layers have no rotary source operations. Positive-to-positive
factor mutations, changed kind/width/representation and policy drift must refuse
before consumers reinterpret an existing graph. Both Q and K must agree with
policy; require exactly two rotary operations per enabled layer, none per NoPE
layer, and exact original activation/positions/output identities, axes/products,
producer order, weights, storage roles and lifetimes. Validate indices and bounded
operation/tensor counts before access. Do not alter epsilon/base words, masks,
cache input modes/exports, capacity, bias, activation, projection or source weights.

A shared scaling-state validator must run before every relevant semantic,
cache/matrix/storage/bias/activation/session/window and recipe consumer. Preserve
legacy validation diagnostics wherever no new invalid state exists. Legacy plans
with stray scaling fields or operation metadata refuse. Avoid recursive guard
cycles. All complete older semantic outputs remain unchanged.

## Original mathematical lowering

Use the previously explicit adjacent/split_half basis. For rotary width d,
pair index j in0..d/2-1, base theta and absolute position p, unscaled inverse
frequency is theta^(-2*j/d). default retains that frequency. linear uses
frequency/factor, so angle is p*theta^(-2*j/d)/factor. Both policies have attention
multiplier1 and the existing unchanged real rotation/partial-tail assembly.
These are abstract real operations; actual device rounding, trigonometry and
representation remain unqualified. No model/layer/attention forward is evaluated.

Retain the complete13-operation default rotary recipe. For linear, insert one
rotary_frequency_scale operation immediately after rotary_inverse_frequency,
before rotary_angles: one real input[pairs], one real output[pairs], division by
the recipe's exact bound positive factor word. Even factor1 retains this explicit
operation. The scaled frequency replaces only the frequency input to angles.
Position input remains index[query]; no rounding/casting of positions is added.
Rotary pairing, theta, source Q/K input/output maps and assembly remain unchanged.
No frequency arrays, cache products or host allocations grow with factor/context
magnitudes. Do not materialize source activations, scores or weights in acceptance.

Recipe and ExpandedOperation own selected scaling kind/factor metadata. Preserve
old constructors with optional trailing arguments. All operations within each
rotary recipe retain matching metadata; other recipes/global operations have
empty metadata. Source/recipe/global maps and policy snapshots must be independently
recomputed and checked, including unused fields, domains, names, exact local/global
operation ordering, input/result maps, products, last-use values and storage roles.
An explicit scaling plan requires an explicit RotaryLoweringPolicy when lowered
or expanded; no basis is guessed. Semantic/cache/matrix inspection still works
without numerically lowering its rotary operations.

Expanded storage admits rotary_frequency_scale only with its exact single real
vector input/output and matched factor metadata. Charge the extra ephemeral
real[pairs] product by existing activation_width; no weight, index, predicate,
persistent-cache or alias charge is invented. Recompute every timeline and peak.
Explicit default keeps the old operation topology and all timelines. The new
linear topology adds one operation/product; scalar factor remains recipe metadata,
not a phantom tensor or allocated device buffer.

## Serialization and compatibility

Only explicit scaling uses schema7. Serialize policy/charge, source-operation,
recipe and global kind/factor(width,bits) metadata, while retaining existing
source scalar/window/session/bias/activation descriptors. Legacy schema6/window,
schema5/session and older full outputs must remain identical without stray new
keys. Explicit default matches the complete frozen window output after removing
only schema/scaling descriptors. Test both source64 and requested32 base/epsilon
paths independently from factor32/64, all-NoPE/mixed/all-enabled layers, both
session modes and cache-return flags. All raw/default/source origins stay visible.

## Required independent acceptance

Before this contract,58 verified compiler entrypoints and all188 current Mojo
source identities were frozen in decoder-scaling-baseline outside production.
Retain source/mode/binary hashes and complete baseline JSON outputs. Rebuild the
entire affected shared-import closure and new source/API/tool/ownership probes
from one unchanged final source snapshot. Preserve preliminary failures/binaries.

- Tiny ordinary files: absent/null/default/linear source objects, legacy/modern/
  conflicts, custom nested/dormant fields, factors integer/float/below1/large/tiny,
  exact64 source words, unknown variants, malformed/duplicate objects, missing/
  wrong-type/nonfinite/nonpositive factors and mutated complete source owners.
- Independent pure constant/index oracle: arbitrary-precision real formula and
  the pinned48-case/120-word external Float32 constants, preserving the distinction
  between real semantics, external rounding and device precision. Never compare
  transformed activations or execute any layer/attention/model forward. Verify
  descriptor mapping and boundary pair indices/absolute positions without
  allocating capacity/factor-sized arrays. No native numerical-execution claim.
- Exact default13/linear14 operation recipes, selected Q/K counts, both bases,
  partial rotary tails, source32/64 and factor32/64 words, large unallocated
  capacities, local/global edges/domains, lifetimes, cache/matrix/storage results.
- Empty/flag/origin/kind/factor/work/provenance/UTF8/overflow mutations; source
  metadata/policy/rotary bypass/extra/edge/shape/producer/weight/storage mutations;
  retained recipe/global/unused metadata/snapshot/map/domain/order/lifetime/storage
  mutations must refuse, including every shared downstream consumer.
- Mutate caller/source/scalar/policy state after construction and verify independent
  plan/recipe snapshots. Repeated refused-to-fresh-success cycles must close all
  root/config/weight descriptors, perform only admitted header reads, preserve
  original bytes and avoid payload mmap, inference libraries, network/device/ioctl.
- Complete frozen GGUF/window/ordinary outputs, explicit-default normalization,
  all prior154-method/5455-call targeted compiler tests and the58 rebuilt predecessor
  entrypoints. Report actual new counts only after acceptance; no whole-repository,
  historical-master or hosted-CI success claim.

Dynamic/YaRN/LongRoPE/Llama3/partial/context/attention scaling, architecture/training
semantics and all other formats/operations remain continuing work. Keep the
physical numerical program path active under TASK_hailo10h_numerical_encoding_sources.md:
actual widths/packing/placement/register/CCW/configuration, original upload,
activation/results/cleanup remain open. No guessed opcodes or unsafe device probes.
Only Hailo-10H executes LLMs. Host parsing/internal compilation/orchestration and
isolated tiny constant/index oracles are allowed. Verify, publish, verify both
remote heads, sync main and continue automatically.
