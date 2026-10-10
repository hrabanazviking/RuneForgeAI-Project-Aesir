# AES500-381 — secret and prompt redaction audit

## Objective and owner

Audit service stdout/stderr, HTTP error responses, and credential diagnostics
for exposure of API keys and submitted prompts. The owners are native serve,
local protocol, and service integration tests.

## Invariants

- Do not log bearer credentials, rejected credential values, or request bodies.
- Error responses do not echo credentials, prompt bodies, or internal engine
  details. Successful generation responses may contain generated content by
  design; that is an API response, not a diagnostic log.
- Tests use unique canary strings in a rejected bearer header and malformed
  request body, then inspect both response payloads and complete service logs.
- The audit does not claim secrecy against process-memory inspection, terminal
  capture by the caller, GPU memory inspection, shell history, or an operator
  who can read local files.

## Acceptance and exclusions

Extend the opt-in native service probe with unique credential/prompt canaries,
assert they are absent from rejection payloads and service logs, run static
docs/truth checks, and record the GPU-fixture requirement if the live service
probe cannot run here. Do not add a generic redaction filter that might conceal
diagnostics; prevent sensitive fields from entering logs.

## Follow-on roadmap status

AES500-391..400 is tracked in
[`ROADMAP_AESIR_500_SLICES.md`](ROADMAP_AESIR_500_SLICES.md). The provider
baseline refresh gate is recorded separately in
[`docs/evidence/provider-baseline-refresh-2026-10-10.md`](docs/evidence/provider-baseline-refresh-2026-10-10.md);
it was not refreshed because the local Ollama service and registered model
artifact were unavailable.
