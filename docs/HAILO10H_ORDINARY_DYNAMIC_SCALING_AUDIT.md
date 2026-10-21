# Dynamic rotary constant and context qualification

Date:2026-10-21. Follow-up after published default/linear implementation5626f2d.
Fixed scope: broad ordinary models owned by Aesir and Hailo-only LLM execution.
No native dynamic scaling, complete model adaptation or numerical device result.

## Bounded licensed oracle

The already reviewed pinned Transformers4.57.1 Apache-2.0 and Torch2.11.0+cpu
license identities remain unchanged from the ordinary scaling audit. Only the
public dynamic inverse-frequency initializer is invoked, on tiny widths2/4/6/8.
Module SHA25655cc0c8cb76f592ab178b4662adcbdf4ad5012bb0b4249c0a96603141f18e9ac.
No external implementation body was copied/translated into Aesir. The external
library is test-only, never a user/runtime/compiler prerequisite. Module/model/
attention forwards are blocked; no model module, weights, network, Hailo, CUDA or
NVIDIA device/library is used. Full syscall trace and original scripts/results
stay outside Git with exact identities, including the preliminary script whose
exception scope was tightened before qualification.

192 static initializer cases vary widths, bases10000/2000000, factors1/2,
configured context16, absent/present original_max_position_embeddings8 and
length None/0/15/16/17/32.144 calls yield432 Float32 words;48 calls at width2
raise ZeroDivisionError inside the public initializer before returning words.
These are initializer failures, not evidence that such a model cannot fit or
execute on Hailo-10H. They must not become permanent eligibility restrictions.
An original mathematical treatment of this edge remains implementation work.

## Observed mathematical boundary

For the tested widths greater than2, outputs agree with the independently
constructed real candidate

frequency(j) = theta^(-2*j/d) * g^(-2*j/(d-2)),
g = factor*max(length,configured_context)/configured_context-(factor-1),

where absent length uses the configured context. The worst measured relative
difference is3.4248169908430164e-7, reflecting external Float32 behavior. This
qualifies these isolated observations, not a universal architecture rule or
Hailo rounding/packing format. All attention multipliers are1.0. None/0/15/16
produce identical words; increasing context length changes the higher pair
frequencies even for factor1 in these calls. The optional original-context field
has no observed effect in this pinned initializer grid. Its raw source value
must remain independently retained; no inference about other families/wrappers
is warranted.

[Versioned SmolLM3 declaration](https://huggingface.co/docs/transformers/v4.57.1/model_doc/smollm3)
exposes dynamic scaling and source modifier fields. A declaration/constructor
alone does not establish whole-model runtime or cache-transition semantics.
The independent candidate and external Float32 words are retained separately.
No layer, projection, attention scores, cached model state or model is evaluated.

## Required next original qualification

Dynamic scaling makes frequency selection depend on context. A static initializer
is not a cache state machine. Before native implementation, qualify source
original/configured/effective contexts, context growth/shrink, partial rotary
widths and the relationship between already stored K values and a changed basis.
Do not silently reuse old-basis cached keys under new frequencies or assume
stateless calls certify a model's intended transition. Original toy index/constant/
rotation-identity oracles may qualify a mathematical contract; model/layer/
attention forwards remain excluded. No full-prefix-only permanent restriction
or alteration of broad support is authorized.

Publish an exact original owned source/policy/API/recipe/consumer/domain/lifetime/
storage/cache-basis and independent acceptance contract before dynamic production
changes. Preserve current complete outputs and exact source scalar/factor words.
Freeze the accepted64 compiler controls first. Other variants, architecture and
training semantics remain required work. Numerical Hailo widths/packing/placement,
register/CCW/configuration generation, original program delivery/activation/results/
cleanup and source-model execution remain open; no invented opcodes or unsafe
hardware probes may substitute for that work.

## Frozen controls and next task

All64 accepted entrypoints and197 current Mojo source identities are frozen
before further code. Parent TASK_hailo10h_ordinary_scaling_semantics.md and
child TASK_hailo10h_dynamic_scaling_semantics.md remain active. No new native
capability ID, model validity, context-extension quality or hardware result is
claimed. Exact scripts/results/negative/trace/control identities are retained
under docs/evidence/ordinary-dynamic-scaling-2026-10-21.

Local consistency remains failing:baseline23254/current23292;
all38 added diagnostics are retained research-receipt paths, with no
new nonreceipt issue after Markdown line normalization. No native code changed;
accepted161-method/6387-call/64-build compiler evidence and113/158 ledger census
remain unchanged. No whole-repository or hosted-CI pass is claimed.
