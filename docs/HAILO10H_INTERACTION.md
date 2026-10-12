# Æsir on Hailo-10H — user and interaction loop

**Roadmap Slice 002 — complete**

## Primary user

The primary user is the local Æsir keeper/operator: the person running Project Æsir on their own machine, selecting a supported local model, and submitting prompts through Æsir's CLI or local server interface. This follows the repository's local-runtime mission and architecture. The operator is not assumed to be a general consumer using an unspecified assistant product.

## Intended interaction loop

1. The operator starts Æsir and selects a locally available model that has a verified Hailo-10H execution path.
2. Æsir validates the request and model metadata, reads the model/tokenizer data, and prepares the prompt on the host.
3. Æsir submits every LLM computation required for generation to the Hailo-10H. Host code may perform request control, tokenization, sampling, and response formatting; it must not execute LLM layers or silently substitute CPU inference.
4. Æsir receives token/results from the accelerator, decodes and formats the response, and returns it to the caller through the CLI or local server.
5. Æsir reports model/device provenance and makes failures visible. If Hailo is absent, unsupported, or unverified, it refuses inference with an actionable error.

## Evidence boundary

The repository architecture documents a local CLI/server-to-engine flow, model loading, tokenization, generation, and output streaming. Hailo dispatch is not implemented: the Hailo enum is reserved, the NPU path is missing, and the prior H111 gate is NO-GO. Therefore steps 1–5 describe the target interaction contract, not a currently working Hailo journey. No CPU LLM path is introduced or authorized by this slice.

## Acceptance

- Primary user is grounded in the local-engine/operator model from repository documentation.
- The request → host preparation → Hailo-only LLM execution → response loop is explicit.
- Missing or unverified Hailo inference fails closed.
- Intended behavior is distinguished from current capability.
- No CPU LLM inference, CPU fallback, or product assumption from the discarded generic roadmap is included.

Evidence reviewed: `AGENT_ONBOARDING.md`, `ENGINEERING_GOALS_AND_BOUNDARIES.md`, `ARCHITECTURE.md`, `CAPABILITY_LEDGER.md`, and `docs/smidr/PHASE_D_GATE.md`.
