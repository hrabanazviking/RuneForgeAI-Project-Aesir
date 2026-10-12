## Slice 131 — Inspect backend enums, validation, and dispatch (complete; scope conflict found)

The repository exposes a reserved NPU backend identifier and an NPU-unavailable stub, but the current fallback backend policy is unsuitable for the owner’s Hailo-only mission: armvegr/backend.mojo documents that AUTO and CPU requests resolve to BACKEND_CPU, while explicit NPU requests raise an error that recommends CPU/AUTO. This is an intentional historical NO-GO fallback policy, not a Hailo implementation. It would violate the current requirement that Project Æsir perform no Pi CPU LLM inference.

Required correction before any runtime work: the active product path must fail closed unless a Hailo backend is ready; it must not silently or explicitly route an LLM request to the CPU. This slice makes no source edit because the permitted Hailo architecture is still an owner decision and the current roadmap branch is documentation-only.

Evidence: armvegr/backend.mojo; CAPABILITY_LEDGER.md entries H139 and SMIÐR Phase-D; owner instruction in this task.
