# Ordinary per-layer rotary facts and native intent contract

Date: 2026-10-20. Parent: `TASK_hailo10h_ordinary_semantic_adapter.md`.
Previous implementation: `c154052`, tagged semantic consumers verified on both
branches. This document establishes source interpretation and the next bounded
native API; it does not establish numerical execution.

## Licensed public declaration and interpretation

The existing pinned Transformers Apache-2.0 license at commit
`8cb5963cc22174954e7dca2c0a3320b7dc2f4edc` was checked before downloading the
pinned SmolLM3 documentation and versioned rendered configuration declaration.
Hashes are under `evidence/ordinary-layer-semantics-2026-10-20/`. Raw documents
are retained in the external work study; no model implementation or checkpoint
was downloaded/copied/translated. An incidental link to a training-config page
was navigated but is not a source for these facts or code.

The [v4.57.1 public SmolLM3Config declaration](https://huggingface.co/docs/transformers/v4.57.1/en/model_doc/smollm3)
defines no_rope_layers as an integer mask:1 selects rotary position encoding,
0 selects a NoPE layer. The name must not cause inversion. An omitted/null mask
uses the configured NoPE interval. Attention layer types are independent data;
full_attention does not imply rotary encoding. Bias flags apply to projection
layers, and cache use is an explicit configuration value. These declaration
facts do not specify source rotary component pairing or physical device layout.

An [upstream maintainer clarification](https://github.com/huggingface/transformers/issues/43756#issuecomment-3855799460)
confirms the 25% NoPE interpretation and the actual repeating1/1/1/0 config.
The issue's initial allegation is not evidence of an inverted source contract.
Its later discussion resolved the naming confusion; Aesir will use the public
declaration, not translate a proposed implementation change from an issue.

Applied to the already pinned ordinary config
`a07cc9a04f16550a088caea529712d1d335b0ac1`, the36 entries mean27 rotary and9
NoPE layers. Zero-based NoPE indices are3,7,11,15,19,23,27,31,35. This is an
independent metadata calculation, not an evaluated model. Actual values retained
include tie_word_embeddings=true,use_cache=false,pretraining_tp=2, both bias
flags=false, rope_theta=5000000, rope_scaling=null, all layer_types=full_attention
and max_window_layers=28. Hidden/head dimensions suggest128 components per head;
this inference still requires actual projection shape/orientation checks.

## Audited current graph gap

The current SemanticPlan emits rope_query and rope_key unconditionally in each
layer. DenseDecoderParameters has no per-layer mask or owned original config.
Its output-weight fallback is inherited GGUF behavior, not proof of ordinary
tied-output rules. Source-to-device rotary pairing remains an explicit gate.
Tagged storage now handles namespace/axes/files correctly; a configuration
adapter still needs actual semantic changes rather than renamed weight keys.

## Exact first implementation contract: owned layer intent

Implement `smidr/decoder_layers.mojo` with:

- `DecoderLayerPolicy(layers,entries,work)` with explicit positive bounds.
- Move-only `SourceDecoderLayers`, owning an independent SourceConfiguration
  snapshot, model_type, layer_count, declared_rope_flags, effective rope_enabled,
  source layer_types, no_rope_layer_interval, use_sliding_window, raw window
  fields, field_origins and unresolved semantic notes. Preserve every original
  configuration field/value, including unknown fields and unused mask tails.
- `source_decoder_layers(config,policy)` using the existing strict JsonParser
  for individual raw values. Keep backing byte owners alive; do not implement a
  second JSON grammar. Initial SmolLM3 mask semantics come from the declarations
  above. Other architectures remain required importer work, never a permanent
  eligibility rule or permission to substitute a vendor catalog.
- `validate_decoder_layers(intent,policy)` and `decoder_layer_uses_rope(intent,i)`
  recheck mutable owned state, bounds, flags, lengths and source-derived/default
  provenance. A query is a semantic metadata lookup, not a numerical operation.

Check raw types exactly: model_type string, positive integer layer count and
interval, mask integer0/1 entries (not booleans), optional string-array layer
types, explicit boolean window flag and positive/null window values. The public
mask declaration permits at least layer_count entries: preserve its entire
bounded declared list while effective flags use exactly the actual layers.
Absent/null mask generation must record its documented origin. Preserve raw
unknown/window/scaling/bias/tie/cache/training metadata; do not use this intent
as an architecture/alias/physical-layout or executable-program certificate.

Never invent a sliding-window layer pattern. Preserve explicit layer_types;
missing patterns whose derivation is not yet established remain explicit
unresolved work. Preserve all window facts even if use_sliding_window is false.
An inspector must expose that source data and effective flags separately, with
execution/complete-architecture/physical-layout flags false. Connect an actual
owned indexed/unindexed collection's config to the API in native checks.

Publish the next precise graph integration contract after this owned intent is
verified: make per-layer rotary omission explicit, retain source layout gates,
establish ordinary aliases/orientation and tie/bias/window/norm/activation/scaling
semantics, and compare all existing GGUF graph/lifetime fields. Do not feed the
ordinary intent through the old GGUF-only recipe or drop unimplemented modifiers.
No model/layer/attention forward, external compiler or device program is allowed
as a substitute for this work. All actual LLM execution remains on Hailo-10H.

Acceptance: independent raw JSON types/escapes/duplicates, explicit/default/null/
long-tail masks, interval boundaries, source snapshots, bounds/overflow/mutation
and ownership checks, public-config27/9 result, actual collection integration
and source-config/semantic regressions. This is a bounded step within the fixed
broad-model target. Numerical instruction/configuration, precision/packing/
placement/upload/activation/results/cleanup remain required parallel work.
