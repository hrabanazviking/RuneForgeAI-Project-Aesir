# Task: Verified Multi-Token Generation

**Status:** Completed and verified on August 14, 2026.
**Parent audit:** `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`  
**Owning domains:** Asgard facade, core inference, tokenizer, CLI, and tests

## Context

The real-GGUF vertical slice established exact first-token parity for one pinned
Llama F16 model. `AesirEngine.generate()` currently processes the complete
prompt but returns only the first greedy token. `generate_stream()` contains a
separate hardcoded five-token loop, does not stop on EOS, does not return token
IDs or a stop reason, and has not been compared with an independent multi-token
oracle.

The next trustworthy capability is not sampling, chat, HTTP compatibility, or
acceleration. It is a small, explicit autoregressive generation state machine
that reuses one KV cache and proves every token in a deterministic sequence.

## System Statement

Project A.E.S.I.R. needs one canonical multi-token generation path owned by the
engine facade. It must prefill a prompt once, advance one token at a time through
the existing configured CPU forward pass, preserve KV state between steps, stop
for defined reasons, and expose enough structured output for exact verification.

## Reference Oracle

### Model

- Repository: `shibatch/stories-converted`
- Revision: `4724c9612ac3278f58aa2dbd4d79457e2672247d`
- File: `stories260K.F16.gguf`
- Size: `601248` bytes
- SHA-256: `57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3`

### Reference runtime

- `llama.cpp` commit: `7e4c0a96880dae4fc4268ad441f8a6446bd5460a`
- Sampling mode: temperature `0` / greedy
- Prompt: `One day, Timmy went to`
- Prompt token IDs: `1 385 328 432 405 263 377 267`
- Requested new tokens: `32`

### Reference generated token IDs

```text
265 282 295 433 335 345 357 426
342 394 261 370 268 414 444 335
261 370 268 414 444 426 291 268
414 444 286 399 262 423 388 269
```

### Reference decoded text

```text
 the park with his mom. They saw a big box with a big box. The box was very small and
```

The full tokenized prompt-plus-completion sequence contains 40 tokens: the 8
prompt tokens followed by the 32 generated tokens above.

## Desired End State

1. One canonical engine method performs prompt prefill and autoregressive decode.
2. The prompt is encoded once with model-controlled BOS behavior.
3. One KV cache is allocated per generation request and reused for all prompt and
   generated token evaluations.
4. Every generated token ID is preserved in order.
5. Text is accumulated from generated tokens only.
6. Generation stops on model EOS, requested length, or context exhaustion.
7. The result records token IDs, decoded text, and a stable stop reason.
8. `generate()` remains the convenient text-returning facade and uses the
   canonical multi-token path.
9. `run_single_shot()` prints the real multi-token result.
10. The pinned 32-token sequence and decoded text exactly match the oracle.

## Public Contract

### `GenerationResult`

The facade owns a structured generation result containing:

- generated token IDs, excluding prompt tokens;
- decoded generated text, excluding EOS/control text;
- stop reason;
- prompt token count; and
- generated token count derivable from the token list.

Stable stop reason strings for this slice:

- `eos` — the model emitted its configured EOS token;
- `length` — the requested new-token count was produced; and
- `context_exhausted` — another evaluated token would exceed the model context.

### Engine methods

- Add a public structured generation method accepting the prompt and requested
  maximum new-token count.
- Preserve `generate(prompt) -> String` as a compatibility facade, now returning
  the text from a 32-token deterministic request.
- Keep `generate_stream()` connected to the same generation mechanics rather
  than maintaining a divergent token loop. This does not claim that the broader
  HTTP server is production-ready.

### CLI

The single-shot CLI defaults to the 32-token proving length and accepts an
optional `--max-tokens N` override for a positive integer. Invalid or missing
values must fail explicitly rather than becoming prompt text.

## Generation Algorithm Invariants

- Prompt length must be positive after tokenization.
- Prompt length must not exceed model context length.
- Requested new-token count must be positive.
- Prompt positions are evaluated exactly once in increasing order.
- The result from the final prompt position is the first generated token.
- Before predicting each later token, the previously generated token is
  evaluated at its actual absolute position.
- A generated EOS ID is recorded as the terminating token ID but is not decoded
  into visible text.
- No position at or beyond the configured context length is evaluated.
- KV memory remains allocated and stable throughout one request.
- Temporary forward-pass workspace is reclaimed after each token by the existing
  `forward_pass()` offset discipline.
- Pool state returns to the persistent runtime boundary after completion.
- Deterministic greedy behavior remains unchanged for this slice.

## Implementation Phases

### Phase 1 — Structured result and one canonical token loop

1. Add `GenerationResult` to `aesir.mojo`.
2. Add the structured generation method.
3. Move prompt prefill, KV construction, EOS checks, context checks, token-list
   progression, decoding, and stop-reason assignment into that method.
4. Make `generate()` delegate to it.

### Phase 2 — Streaming reuse

1. Remove divergent hardcoded five-token generation behavior without deleting
   the public function.
2. Reuse the same token progression and stop rules.
3. Preserve current transport calls while clearly avoiding new HTTP-compatibility
   claims.

### Phase 3 — CLI connection

1. Make single-shot generation return 32 tokens by default.
2. Parse optional `--max-tokens N` before prompt assembly.
3. Reject zero, negative, missing, and nonnumeric values.
4. Print only real generated text as the response payload.

### Phase 4 — Verification

1. Extend the external-fixture test to execute the canonical engine generation
   path.
2. Compare all 32 generated IDs exactly and in order.
3. Compare the full decoded text exactly.
4. Verify the `length` stop reason.
5. Add focused tests for EOS-stop logic and context-stop logic where they can be
   isolated without inventing model output.
6. Re-run the first-token assertions as regression protection.
7. Run the complete existing proving suite.
8. Build a clean CLI binary.
9. Run the built CLI with the reference model and prompt.

### Phase 5 — Living documentation and audit

1. Update `aesir_engine/INTERFACE.md`.
2. Update affected CLI and tests interface/readme documents.
3. Update `TODO.md` and `DEVLOG.md` with only verified claims.
4. Mark this task completed only after every acceptance gate passes.
5. Audit the final diff for hardcoded local paths, model weights, secrets,
   generated binaries, and unrelated changes.

## Expected Files

- `aesir_engine/aesir.mojo`
- `aesir_engine/cli/commands.mojo`
- `aesir_engine/cli/repl.mojo`
- `aesir_engine/tests/test_real_gguf.mojo`
- `aesir_engine/tests/test_inference.mojo` or a focused new generation test if
  isolated stop-policy coverage requires it
- `aesir_engine/INTERFACE.md`
- `aesir_engine/cli/INTERFACE.md`
- `aesir_engine/tests/INTERFACE.md`
- `aesir_engine/tests/README.md`
- `TODO.md`
- `DEVLOG.md`
- this task document

If another file is required, its inclusion must be reported before expanding
the implementation boundary.

## Constraints

- Mojo remains the only runtime language.
- No model weights are committed.
- The current verified GGUF loader and first-token behavior remain intact.
- The existing `generate(prompt) -> String` entry point remains available.
- No public function or file is deleted without Volmarr's approval.
- No stochastic sampler is introduced in this task.
- No chat template is introduced in this task.
- No quantized, GPU, NPU, multi-device, HTTP-server, or RAG claims are expanded.
- No benchmark number is published.
- External reference binaries and model files remain outside the repository.
- The full existing suite must still pass, while its known truth-semantics debt
  remains separately tracked by the reality audit.

## Acceptance Criteria

- The structured result reports exactly 32 generated token IDs for the reference
  request.
- All 32 IDs exactly match the pinned oracle sequence.
- Decoded text exactly matches the pinned oracle text.
- Stop reason is `length` for the 32-token reference request.
- EOS terminates generation without adding EOS text to the visible response.
- Context exhaustion prevents any out-of-range KV-cache write/evaluation.
- One KV cache is reused across prompt and generation positions.
- The first generated token remains ID `265`, decoded as ` the`.
- The CLI default produces the verified 32-token text.
- `--max-tokens 1` preserves the previous one-token result.
- Invalid `--max-tokens` input fails explicitly.
- Full existing suite passes.
- External real-model integration passes.
- Clean Mojo build succeeds.
- Final working tree contains no model weight or built-binary additions.

## Explicit Non-Goals

- stochastic sampling;
- repetition/frequency/presence penalties;
- chat templates;
- general byte-fallback stream decoding beyond what is needed by the pinned
  generated sequence;
- batching;
- concurrent sessions;
- server conformance;
- performance optimization;
- quantized inference;
- accelerator execution;
- semantic RAG; and
- claims of production readiness.

These remain separately identified in the complete reality audit.

## Completion Evidence

The implementation satisfied every acceptance gate in this task:

- `GenerationResult` reports generated IDs, generated text, prompt count, and a
  stable terminal reason.
- `AesirEngine.generate_tokens()` owns one prompt-prefill and autoregressive
  path with one per-request KV cache.
- `generate()` and `generate_stream()` delegate to the canonical mechanics.
- The external fixture matched all 32 pinned token IDs and the exact pinned
  decoded text.
- The one-token regression remained ID `265`, text ` the`.
- A real 128-token prompt produced one legal output token and then stopped with
  `context_exhausted`, proving that position 128 was not evaluated.
- The isolated stop-policy test proved EOS precedence and EOS text exclusion at
  the generation boundary.
- The CLI default produced the exact 32-token completion.
- `--max-tokens 1` produced the exact one-token completion.
- Missing, zero, negative, nonnumeric, and overflowing CLI values exited
  nonzero with explicit errors.
- The full existing suite passed.
- The opt-in real-GGUF integration passed.
- A clean Mojo CLI build passed.
- The final audit found no committed fixture weights, local absolute paths,
  secrets, or newly tracked binaries.

The completion does not expand any explicit non-goal or supersede the findings
in `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`.
