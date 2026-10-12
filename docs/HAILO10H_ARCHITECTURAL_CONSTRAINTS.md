# Hailo-10H campaign architectural constraints

**Roadmap Slice 010 — carry forward Æsir's Hailo design requirements**

The project's existing engineering and MÍMISBRUNNR documents define a
Mojo-native, local inference engine and a specific Hailo ambition. Those
requirements remain in force for this campaign unless the project owner
explicitly revises them:

- All LLM inference in scope executes on Hailo-10H. Pi CPU LLM work, CPU
  inference fallbacks, and CPU shadow inference are excluded.
- Shipped Æsir engine code remains Mojo-native; Python may be used for tests
  only where existing project policy allows it.
- The Hailo path must not require HEF artifacts, the proprietary Hailo Dataflow
  Compiler, or a Hailo runtime/library linked into or required by Æsir.
- Existing CPU and CUDA inference paths are out of scope and are not to be
  extended as alternate outcomes for a Hailo blocker.
- The application remains local; no cloud inference is introduced.

These constraints make direct Hailo execution a substantial feasibility risk.
Hailo's documented GenAI path is based on compiled model artifacts and a
HailoRT-backed service/runtime. It is useful as a comparison point, but it does
not satisfy the project's no-HEF/no-vendor-runtime design by itself. Do not
silently substitute that integration for Æsir's stated architecture.

## Feasibility gate

Before implementation depends on raw device execution, establish whether the
Hailo-10H exposes a technically and legally viable interface for the project's
required no-HEF/no-DFC Mojo path. Record confirmed facts, unknowns, and a
go/no-go recommendation with evidence. A no-go means the Hailo-only campaign is
blocked pending an owner decision; it does not authorize CPU inference or
relaxation of the architecture.

## Slice 010 acceptance

- The original Mojo-native and Hailo-specific design constraints are recorded.
- Hailo-Ollama/HailoRT is not presented as an approved implementation path.
- Vendor model tables are labeled as reference measurements only.
- Feasibility failure routes to a decision/blocker, never to CPU LLM work.
