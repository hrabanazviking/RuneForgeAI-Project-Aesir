# Æsir Hailo campaign control

This file records owner-authorized scope and technical controls for the Hailo-10H campaign. Decisions about project architecture remain with the owner.

## Slice 021 — owner-approved Hailo-only mission (complete)

The user explicitly directs the roadmap toward running Project Æsir LLMs on the Hailo-10H and excludes development of Project Æsir Pi CPU inference at this time. This campaign therefore treats Hailo-10H as the only LLM execution target. No CPU fallback, CPU shadow LLM inference, or CPU-serving work is authorized. Ordinary Pi orchestration remains allowed.

Evidence: user instruction recorded in this task; `docs/HAILO10H_MISSION.md`; `docs/HAILO10H_NO_CPU_INFERENCE.md`.

## Slice 022 — Pure Mojo runtime policy (complete)

Æsir's shipped execution path remains native Mojo under the repository's engineering doctrine. Python remains test-only where existing policy allows it. This slice adds no Python runtime dependency and no CPU inference implementation.

Evidence: ENGINEERING_DOCTRINE.md, AGENT_ONBOARDING.md, and the Hailo mission constraints.

## Slice 023 — No HEF, DFC, or vendor-runtime requirements (complete)

This campaign preserves the existing explicit architecture requirements: do not create, read, or require HEF artifacts; do not install or invoke the proprietary Hailo Dataflow Compiler; and do not link, dlopen, or require HailoRT/Hailo-Ollama as Æsir runtime dependencies. The feasibility risk is accepted as a possible blocker, not silently resolved by relaxing these constraints.

Evidence: docs/HAILO10H_ARCHITECTURAL_CONSTRAINTS.md and the repository's MÍMISBRUNNR architectural laws.

## Slice 024 — Clean-room research and license gate (complete)

Vendor drivers, HailoRT, and other third-party implementations may be studied only under the repository's clean-room procedure: check license and study permissions first, record sources and intent, extract general concepts rather than code, and independently design any Æsir implementation. Do not copy or mechanically translate source. If the needed protocol/configuration cannot be derived within these boundaries, record the blocker.

Evidence: ENGINEERING_GOALS_AND_BOUNDARIES.md, DEPENDENCY_POLICY.md, docs/plunder/.

## Slice 025 — Vendor GenAI examples are reference evidence only (complete)

Official Raspberry Pi/Hailo LLM documentation, Hailo GenAI Model Zoo, and Hailo-Ollama can establish what the vendor-supported Hailo-10H path requires. They do not establish an Æsir-compatible implementation: the current documented path uses Hailo model artifacts and vendor runtime components that conflict with Slice 023. Do not install or invoke those components as a workaround.

Evidence: docs/HAILO10H_OS_SOFTWARE_IDENTITY.md and docs/HAILO10H_MODULE_MEMORY_EVIDENCE.md; official source links are recorded there.

## Slice 026 — Permitted host responsibilities (complete)

The Pi may run operating-system and ordinary application work: request parsing, file and model-metadata reading, tokenization, process/device orchestration, non-content diagnostics, and response formatting. Host-side work must not compute transformer layers or model logits. Any generation sub-operation whose classification is unclear must be resolved by evidence and architecture review before implementation; it must not become hidden CPU inference.

Evidence: docs/HAILO10H_COMPONENT_BOUNDARIES.md and docs/HAILO10H_NO_CPU_INFERENCE.md.

## Slice 027 — Prohibited inference routes (complete)

This campaign does not develop CPU LLM execution, CPU fallback, CPU shadow inference, CPU model serving, CUDA LLM execution, or cloud inference. Existing CPU/CUDA code remains untouched. On missing/unverified Hailo capability, Æsir reports an error and does not dispatch model execution elsewhere.

Evidence: docs/HAILO10H_INFERENCE_POLICY.md, docs/HAILO10H_NO_CPU_INFERENCE.md, and docs/HAILO10H_NETWORK_ASSUMPTIONS.md.
