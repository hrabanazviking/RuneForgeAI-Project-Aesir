# Compatibility claim policy

Compatibility describes an exact surface and tested environment. A command
name, route shape, shared field name, accepted model filename, or successful
single request does not establish ecosystem compatibility by itself.

## Claim owners

- `docs/API_SUPPORT_MATRIX_V1.md` owns the current local HTTP route and field
  subset for native, OpenAI-shaped and Ollama-shaped service modes.
- `CAPABILITY_LEDGER.md` owns present-tense capability status and evidence
  boundaries for runtime behavior.
- The request/response vectors under `scripts/fixtures/` and their independent
  contract harness own executable wire examples. Passing them proves only the
  listed vectors against the tested build.
- Model-family support is owned by model/profile evidence and exact GGUF
  identity, not an API compatibility label.

## Rules for adding or changing a claim

1. Name the provider, mode, route/command, accepted fields and exact tested
   version/build. State rejected and untested behavior beside the claim.
2. Update the support matrix, capability ledger, independent fixture and
   executable contract in the same change. Preserve old fixtures when behavior
   changes intentionally, or record why a compatibility break is required.
3. Keep authentication, streaming, model identity, context, sampling, errors,
   token counts and lifecycle semantics explicit. Do not infer full-provider
   parity from route overlap or model-name equality.
4. Require tests against a real client/SDK release before claiming that named
   client works. Synthetic HTTP tests establish local framing and schema rules,
   not ecosystem interoperability.
5. Do not use “drop-in,” “fully compatible,” or “replacement” unless the
   explicitly named scope has representative end-to-end client, model,
   lifecycle and failure evidence. Prefer the exact support-matrix row.

## Current boundaries

The current HTTP surface is the subset in the API matrix. Native generation is
authenticated; Ollama-shaped mode is loopback-only and unauthenticated. Neither
mode claims complete provider parity. Tool calls, multimodal inputs, remote
access, full Ollama model management and broad SDK compatibility remain outside
the verified subset unless a specific matrix row and evidence are added.

This policy governs wording and evidence. It does not promise compatibility
stability across releases; any stability/versioning promise requires a separate
release decision under [`VERSIONING.md`](VERSIONING.md).
