# Resolve ordinary omitted/null defaults with a configuration-only oracle

Date:2026-10-20. Parent: TASK_hailo10h_ordinary_rotary_modifiers.md.
Projection bindings are published/verified on both branches at597ab76.
Owner scope remains HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.

## Qualified independent facts

The prior public KV-head signature/prose ambiguity is now resolved for the
versioned SmolLM3 configuration interface by a pinned, isolated4.57.1 oracle.
Its installed license is byte-identical to the previously reviewed Apache-2.0
license (SHA25677fd4710def9ec3c0f6225800e0235f15a425abd4a8b03559127fcd782612049).
Only public configuration constructors were invoked. No external implementation
was copied/translated into Aesir. No model class, weights, tensor, layer or
attention forward was used. Configuration module hash and31 complete input/
output cases are recorded with a syscall trace proving no Torch C library,
network connection or Hailo device. This test oracle is not a production or
user environment dependency.

An initial installed5.7.0 metadata probe imported Torch despite disable flags;
its isolation assertion failed and that evidence is retained. It instantiated
no model or weights. The pinned test environment contains no Torch, TensorFlow
or Flax; the library itself reports only configuration/file utilities available.
There is no inference proxy or external model compiler.

Public4.57.1 class behavior:

- Missing num_hidden_layers uses36.
- Missing num_key_value_heads uses4, even when query heads differ.
- Explicit null num_key_value_heads resolves to query-head count.
- Missing tie_word_embeddings resolves to true; explicit false remains false.
- Explicit null tying remains null; this native update keeps that unresolved.

Constructor permissiveness is not a valid-model oracle: native positive integer,
GQA divisibility, source tensor/shape, policy and numerical gates still apply.
The qualified public declarations are
[SmolLM3Config](https://huggingface.co/docs/transformers/v4.57.1/en/model_doc/smollm3#transformers.SmolLM3Config)
and [PretrainedConfig](https://huggingface.co/docs/transformers/v4.57.1/en/main_classes/configuration#transformers.PretrainedConfig).
Extra probes record automatic attention-type metadata for future work, but this
slice does not implement a window pattern or infer rotary component pairing.

## Exact native change and compatibility contract

Keep all current owned types and original raw source fields. Extend
source_decoder_layers to accept absent num_hidden_layers with36, bounded and
charged before any flag allocation; origin documented_default:36. Explicit
integer/null/type rules and every existing source mask/tail/window gate stay.
Original supplied/default source presence must remain distinguishable.

Extend source_decoder_architecture: inherit checked layer-count origin instead
of hardcoding source. Always derive KV heads: omitted→4 with origin
 documented_default:4; null→query heads with origin source:null_then_query_heads;
positive explicit→source. Apply existing positivity/divisibility checks in all
cases. Do not infer KV count from source tensor ratios. Remove only the obsolete
missing/null KV unresolved note. Existing entry/work formulas still count each
actually derived dimension/origin/note before growth.

Omitted tying adds true with documented_default:true; explicit booleans keep
source origin, explicit null remains absent from flags plus its existing
unresolved note. Projection binding then selects from the resolved source
semantic flag; no file-name fallback is added. A separate tied output still
requires duplicate identity, and every source binding remains retained.

No existing explicit-source output may change. Freeze layer/architecture/
projection inspectors and compare complete explicit cases, including the pinned
config. Existing GGUF graph and nine consumer outputs stay identical. Current
source fingerprint/architecture/modifier/rotary/numerical gates remain false.
No arithmetic device program, special user conversion or external dependency is
introduced. Broad architecture/format support remains required implementation.

## Independent acceptance and next work

Update independent ordinary test expectations to the newly qualified defaults;
preserve their historical negative receipts. Add native checks against frozen
constructor facts, absent/null/explicit distinctions, exact accounting/origins,
GQA invalid-geometry refusals,36-layer allocation bounds, owned/mutated state,
actual projection/header connections and complete old explicit outputs.
Rebuild every changed ordinary consumer/API and run affected compiler regressions.
Retain all raw configuration, inactive/unknown modifiers and negative evidence.

Publish before code. After verify/publish/head verification, automatically return
to actual rotary component pairing, remaining modifiers and original operation
lowering, then complete ordinary source-to-graph and numerical Hailo configuration/
precision/packing/placement/upload/activation/results/cleanup. All LLM execution
stays on Hailo-10H; no CPU/CUDA/cloud model/layer/attention forward, outside
compiler/DFC/machine, vendor artifact or user conversion prerequisite.
