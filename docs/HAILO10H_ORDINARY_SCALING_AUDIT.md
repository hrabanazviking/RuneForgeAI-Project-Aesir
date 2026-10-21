# Ordinary scaling configuration qualification

Date:2026-10-21. Parent TASK_hailo10h_ordinary_scaling_semantics.md. Fixed scope:
HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. This is public-interface/configuration
qualification only; no native scaling or numerical Hailo execution capability.

## Pinned license and oracle boundary

The previously reviewed Apache-2.0 Transformers4.57.1 license is unchanged:
SHA25677fd4710def9ec3c0f6225800e0235f15a425abd4a8b03559127fcd782612049.
Configuration module SHA2564fec68b228fec767ddc8f8cd4c40f8eaf374c3c44bf38c0cf1618382c7731cdf.
Forty-eight public SmolLM3Config calls use only metadata constructors. No Torch,
model module, weights, tensors, layer/attention/model forward, network connection
or Hailo device. The isolated library is a test oracle, never a runtime/user
prerequisite. No external implementation was copied or translated into Aesir.

[Versioned SmolLM3 declaration](https://huggingface.co/docs/transformers/v4.57.1/model_doc/smollm3)
names default/linear/dynamic/yarn/longrope/llama3 scaling and variant-dependent
factors, context references, attention scale and frequency arrays. These public
selectors are implementation dependencies, not a permanent model eligibility
list. They do not define every architecture's interpretation or device formats.
An attempted versioned Llama documentation lookup was unavailable and supplies
no evidence for this audit. In particular no inference rule for SmolLM3's
pretraining_tp extension is inferred from another architecture.

## Observed constructor facts

All48 inputs produce metadata, including cases emitting validation warnings.
Inputs cover omitted-equivalent null/default scaling, legacy and modern selector
keys, conflicting selectors, integer/float/zero/negative/string factors, unknown
selectors, variant fields, custom nested metadata and pretraining_tp1/2/null.
Complete original input, caller-after and selected result are retained per case.

Legacy type adds rope_type in the caller dictionary. With conflicting
{type:linear,rope_type:dynamic}, the tested constructor selects linear and also
overwrites the caller's rope_type. Native raw source facts must therefore remain
owned independently of any derived selector; constructor-normalized dictionaries
cannot stand in for the original model file. This observes one pinned interface;
it is not a universal precedence rule for every model family/version.

Unknown future selectors, invalid/non-numeric factors and custom keys can warn
and still yield metadata. Constructor success is not mathematical or numerical
model validity. Do not promote these warning-bearing cases to an executable
adapter merely because object construction succeeds. pretraining_tp1/2/null is
retained as metadata; its training/inference execution implications remain open.

## Isolated linear inverse-frequency constants

A separate licensed static-constant probe calls only public default and linear
inverse-frequency initializers, with model/module/attention forwards blocked.
It uses48 tiny cases across rotary widths2/4/6/8, bases10000/2000000/5000000 and
factors1/1.5/2/8. All120 returned linear Float32 words equal independently rounded
default-frequency/factor words; reported attention multiplier is1.0 in every
case. The independent real formula differs by at most3.2083e-7 relative due to
these external Float32 computations. This is qualified reference behavior, not
native/source64 or device numerical acceptance. No weights or model module.

[Position Interpolation, Chen et al., arXiv2306.15595v2](https://arxiv.org/abs/2306.15595v2)
describes linear down-scaling of positions. This motivates an original mathematical
frequency/position scaling contract; it supplies no Hailo instruction, memory
layout or inference quality proof for Aesir. The source formula and the external
Float32 reference must remain distinct from actual device precision/rounding.
Other scaling variants/context transitions and architecture semantics remain
required work. Test-only Transformer/Torch module/license identities and full
constant vectors are retained; no external implementation is copied/translated.

## Required next original work

Qualify the actual mathematical definitions and isolated constant/index behavior
for each scaling variant, including context-dependent transitions, partial rotary
widths, attention scaling, arrays and scalar-word precision. No projection/layer/
attention/model forward may be used. Publish an exact original owned policy/API,
source/default/legacy/modern/unknown field provenance, source operation/recipe/
consumer/domain/lifetime/storage and independent acceptance contract before code.
Preserve every raw/default/dormant/unresolved fact and all existing complete
outputs; freeze the verified compiler controls first. No source conversion or
separate user compilation workflow is introduced.

Missing formats/architectures/operations remain implementation work toward broad
support. All actual LLM execution stays on Hailo-10H. Device precision/packing/
placement, numerical CCW/register/configuration generation, program delivery/
activation/results/cleanup and source-model execution remain open. Another bounded
public numerical-encoding scan returned unrelated/excluded leads and established
no new instruction fields; it is not counted as compiler or hardware progress.

## Local verification boundary

All retained audit inputs/results match their recorded SHA256 identities.
Whole-repository consistency remains failing: baseline22059/current22073;
all14 new diagnostics concern retained audit receipt paths, with no
new nonreceipt issue after Markdown line normalization. No native source code
changed. The already published window acceptance remains154 methods/5455 calls
and58 clean builds; these audit probes add no native capability or device proof.
