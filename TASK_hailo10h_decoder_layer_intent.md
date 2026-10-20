# Implement owned ordinary decoder layer intent

Date: 2026-10-20. Parent: `TASK_hailo10h_ordinary_semantic_adapter.md`.
Controlling owner scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Exact facts/API/verification contract:
`docs/HAILO10H_ORDINARY_LAYER_SEMANTICS.md`.

Implement the original bounded Mojo decoder_layers API, using the existing owned
raw configuration and strict JSON cursor, preserving all original fields and
source-versus-default provenance. The documented mask uses1=RoPE,0=NoPE; do not
invert it based on its name or discard long declared tails. Derive only documented
interval defaults. Preserve independent layer/window/scaling/tie/bias/cache facts
and explicit unresolved semantics; do not guess a missing attention pattern.

Connect actual ordinary collection configs, verify independent structural/type/
bound/ownership cases and the public pinned27/9 mask plus affected regressions,
commit/publish to the authorized branches, verify remote heads and continue
actual ordinary graph/alias/modifier integration automatically. No external
compiler, special user model conversion, model/layer/attention forward or
numerical device execution claim. All missing architecture/format/backend work
remains required toward the owner's unchanged broad model target.

2026-10-20 acceptance: original owned layer intent and inspector pass19 methods/
701 native calls including199 new,190 config and312 semantic regressions.
Receipt: docs/HAILO10H_MOJO_DECODER_LAYERS.md. Next automatic contract:
TASK_hailo10h_decoder_graph_policy.md. Numerical Hailo execution remains open.
