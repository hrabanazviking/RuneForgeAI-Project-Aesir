# Ordinary source configuration into actual native decoder semantics

Date: 2026-10-20. Parent: `TASK_hailo10h_source_neutral_semantics.md`.
Owner scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Previous receipt: `docs/HAILO10H_MOJO_SEMANTIC_STORAGE.md`.

Audit the existing decoder recipe and ordinary raw configuration fields against
licensed pinned public configuration, tensor naming/orientation and mathematical
rotary/attention declarations. Use documentation and declared interfaces; do not
copy/translate an external model implementation or evaluate a model. Existing
public metadata/config/index facts are preserved under docs/evidence. Resolve
per-layer rotary/NoPE meaning, rotary component pairing/layout and tensor
orientation explicitly before treating the ordinary names as GGUF semantics.
Preserve all source modifiers and unknown fields; unsupported semantics are
implementation work, never permanent model eligibility restrictions.

Publish the exact owned typed configuration/alias/graph API and compatibility
contract before code. Ordinary source files/config must load directly through
Aesir's indexed/unindexed owned collections and tagged per-file bindings, with
no external compiler, DFC, user conversion or vendor artifact prerequisite.
Tie decisions come from actual config facts, not an absent lm_head heuristic.
Biases, norm/activation/scaling, grouped heads, context/window and per-layer
rotary/architecture modifiers must not be erased or silently defaulted. Preserve
GGUF graph/lifetime behavior, original source facts and unresolved physical gates.

Implement bounded original Mojo steps after their exact facts/design are
published. Verify independent synthetic config/shape/alias/graph/ownership/
refusal/overflow cases and complete affected compiler regressions. Do not run a
CPU/CUDA/cloud LLM, layer or attention forward. Host structures and memory fit
are not numerical source-model execution. Continue actual Hailo arithmetic
encoding, precision/packing/placement/configuration/upload/activation/results/
cleanup work under the numerical contracts. Commit/publish each verified slice,
verify remote branches and automatically advance toward the fixed broad target.

2026-10-20 first narrowing: docs/HAILO10H_ORDINARY_LAYER_SEMANTICS.md
records licensed public mask facts and the exact owned decoder-layer intent API.
Implement TASK_hailo10h_decoder_layer_intent.md next, then integrate the actual
ordinary graph/aliases/modifiers and numerical backend under the same target.
