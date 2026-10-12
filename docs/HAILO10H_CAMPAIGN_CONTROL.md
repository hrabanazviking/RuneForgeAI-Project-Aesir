# Æsir Hailo campaign control

This file records owner-authorized scope and technical controls for the Hailo-10H campaign. Decisions about project architecture remain with the owner.

## Slice 021 — owner-approved Hailo-only mission (complete)

The user explicitly directs the roadmap toward running Project Æsir LLMs on the Hailo-10H and excludes development of Project Æsir Pi CPU inference at this time. This campaign therefore treats Hailo-10H as the only LLM execution target. No CPU fallback, CPU shadow LLM inference, or CPU-serving work is authorized. Ordinary Pi orchestration remains allowed.

Evidence: user instruction recorded in this task; `docs/HAILO10H_MISSION.md`; `docs/HAILO10H_NO_CPU_INFERENCE.md`.

## Slice 022 — Pure Mojo runtime policy (complete)

Æsir's shipped execution path remains native Mojo under the repository's engineering doctrine. Python remains test-only where existing policy allows it. This slice adds no Python runtime dependency and no CPU inference implementation.

Evidence: ENGINEERING_DOCTRINE.md, AGENT_ONBOARDING.md, and the Hailo mission constraints.
