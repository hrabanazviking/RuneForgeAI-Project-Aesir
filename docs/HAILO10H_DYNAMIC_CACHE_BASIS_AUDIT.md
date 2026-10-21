# Dynamic context state and cache-basis boundary

Date:2026-10-21. Parent TASK_hailo10h_dynamic_scaling_semantics.md.
Broad ordinary source models and Hailo-only LLM execution remain the target.
This qualifies constants, indices and fixed-number planar identities. It does
not qualify a model, cache implementation, attention calculation or device.

## Pinned public observations

The previously reviewed Transformers4.57.1 Apache-2.0 and Torch2.11.0+cpu
license identities were checked before import. The public frequency-state
decorator was called with a plain constant holder and a constant-reading callback.
No torch Module was constructed, external rotary forward or cache update called,
model module imported or source payload loaded. Model/module and attention entry
points were blocked. Trace:zero network connects, model payload opens and Hailo/CUDA inference
library/device opens. Metadata import opens the model source text three times;
no model module is present in sys.modules. Source-text reads are retained in the
trace and do not establish or require model execution. External implementations were neither
copied nor translated. Exact scripts/results/source identities and negative
archive identities are in evidence/dynamic-basis-2026-10-21/; raw traces outside Git.

48 scenarios/576 callbacks return1728 Float32 frequency words. Configured
contexts8/16, bases10000/2000000, factors1/2, head width8 and initializer fractions
0.5/0.75/1 produce widths4/6/8; nested original-context absent/present4.
The [pinned public decorator](https://github.com/huggingface/transformers/blob/v4.57.1/src/transformers/modeling_rope_utils.py)
retains frequency context across calls. Position maximum plus one determines
observed length, including a two-position noncontiguous probe. Growth updates
context; intermediate shrinkage can retain it; a call strictly below configured
context resets it. Equality after growth retains the larger context. The selected
context agrees with an independently specified twelve-step expectation table.
Frequency candidate error is at most3.497004e-7 relative, with attention factor1.
These external Float32 observations are not source64 or Hailo numerical acceptance.

[Pinned SmolLM3 declarations/implementation](https://github.com/huggingface/transformers/blob/v4.57.1/src/transformers/models/smollm3/modeling_smollm3.py)
initialize retained/original frequency context from configured maximum; optional
nested original-context metadata does not replace that baseline here. Static
inspection shows enabled layers rotate new Q/K before the cache update interface.
The [ordinary non-sliding cache layer](https://github.com/huggingface/transformers/blob/v4.57.1/src/transformers/cache_utils.py)
appends supplied K/V, with no previous-key rephasing at that boundary. These are
source facts, not an executed cache/model experiment or a rule for every cache.
Generic partial-factor initializer support does not establish compatibility with
this full-head rotary consumer. NoPE flags and raw modifier fields stay independent.
The [generic configuration declaration](https://huggingface.co/docs/transformers/v4.57.1/model_doc/smollm3)
does not resolve this family/version-specific distinction by itself.

## Original mathematical distinction

For fixed input pair x, define R(a) as its planar rotation. The identity
R(b-a)R(a)x=R(b)x follows from sine/cosine addition. Our original binary64
fixed-number probe checks144 cases/432 pair identities, growth and shrink,
widths4/6/8, two bases/factors and positions0/1/7/15. Independent complex-number
multiplication checks the result; inverse and norm identities also pass.
Worst absolute error4.440893e-15.216 pairs differ if the old rotation is retained.
No Q/K products, attention scores, weights, layers or source vectors are evaluated.

This identity assumes the unrotated input pair is unchanged. Changing the basis
for a whole decoder can change prior hidden states and downstream projections.
Consequently rephasing stored key vectors alone is not proof of equivalence to
recomputing a complete prefix. Keeping insertion-basis history and intentionally
rephasing fixed vectors are different semantics. Aesir must not silently choose
between them or assert that all stored keys use the current frequency context.

For the bounded real candidate, use
omega(j)=theta^(-2j/d)*[1+f*(S-C)/C]^(-2j/(d-2)).
C is the qualified context baseline, S the selected retained context, d the
rotary width. At pair0, omega is exactly1; it requires no singular exponent.
At d=2 this is the only pair. This defines an original mathematical primitive
without adopting the external initializer's division error as a hardware/model
restriction. It does not certify a previously untested source width2 model.

## Next native boundary

The independently specified constant-space integer selection and rational
exponent scheduling contract is HAILO10H_DYNAMIC_CONTEXT_DESIGN.md. Publish it
before its new standalone Mojo module. That module will not admit dynamic source
models or change existing graph/cache consumers. Full source projection, exact
factor-word and context-state binding, insertion-basis cache provenance, recipes,
consumer/storage/lifetime integration and independent acceptance require a
separate published integration contract before those production changes.
No full-prefix-only permanent restriction is introduced. Other formats,
architectures, variants and actual numerical Hailo configuration/packing/placement/
program delivery/results remain required work. Current161-method/6387-call/64-build
integration evidence remains unchanged; no new source execution capability claimed.

The first state-probe attempt completed its assertions but failed JSON output
because a public state value was a scalar Tensor. It is retained with its trace
and empty result. The corrected probe converts only that report field to int.
