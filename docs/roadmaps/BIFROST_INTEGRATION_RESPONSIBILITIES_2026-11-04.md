# Project A.E.S.I.R.: Optional Local Inference Backend for Second Brain

**Date:** 2026-11-04  
**Repository:** `hrabanazviking/RuneForgeAI-Project-Aesir`  
**Implementation status:** Roadmap only; no application code modified.

## Relationship to the master roadmap

- **Canonical roadmap:** https://github.com/hrabanazviking/bifrost-viewer/blob/main/docs/roadmaps/BIFROST_SECOND_BRAIN_MASTER_EXPANSION_ROADMAP_2026-11-04.md
- **Local full copy:** [BIFROST_SECOND_BRAIN_MASTER_EXPANSION_ROADMAP_2026-11-04.md](BIFROST_SECOND_BRAIN_MASTER_EXPANSION_ROADMAP_2026-11-04.md)
- **Status:** Proposed work, not existing functionality. Confirm actual current installed state and protect existing data before writing code.
- **Ownership:** Bifröst Viewer coordinates the Second Brain. Skein and Skry own their APIs. Integrations must use documented, authenticated contracts and cannot assume direct PostgreSQL access.
- **Security:** Public Markdown only. No actual keys, OAuth client secrets, vault values, database passwords, user documents, personal account identifiers, logs, private state paths or private URLs.
- **Compatibility:** Preserve existing code behavior, published interfaces, licenses and attribution. Changes should be opt-in, reversible and regression-tested.

## Goal

Allow Bifröst/Skein to use A.E.S.I.R. as a local model provider when tested and supported, without coupling the inference engine to document storage.

## Repository-specific engineering responsibilities

1. Expose inference capabilities through a stable model provider contract, with model/version/capability, structured JSON, token usage, cancellation and health.
2. Preserve separate embedding-space identity: native chat acceleration does **not** justify silently replacing existing `nomic-embed-text` vectors.
3. Benchmark hardware-specific inference latency, VRAM, GPU/CPU backpressure and structured extraction reliability on representative Second Brain tasks.
4. Support bounded request queues, predictable cancellation and model unload/release for owner-controlled Pause for Quiet.
5. Offer explicit fallback to tested local Ollama or approved remote providers; never auto-spend money.
6. Keep A.E.S.I.R. usable on its own, with no required knowledge database, Bifröst or Kista.
7. Provide synthetic test prompts only; no personal corpus data, provider keys or runtime traces in public Git.

## Engineering and security gates

- [ ] One simulated Skein extraction request produces valid structured output through a public adapter.
- [ ] Model cancellation releases heavy work and reports actual completion state.
- [ ] Baseline A.E.S.I.R. tests still pass with integration disabled.

## Delivery sequence

1. Read this repository's own architectural rules, domain boundaries and current source before editing.
2. Audit installed and unpublished development work; never assume a feature is absent simply because it is missing from the current public default branch.
3. Design a versioned optional integration through published API contracts; preserve baseline behavior.
4. Implement synthetic fixtures, unit tests, integration tests, timeouts and permission checks.
5. Test disconnection, false/stale results, recovery and security canaries.
6. Document capability level and deployment directions without secrets; require owner approval before live rollout.

**Canonical authority:** The primary Bifröst Viewer roadmap above resolves conflicts; individual source code and verified deployed evidence establish what is actually implemented.

