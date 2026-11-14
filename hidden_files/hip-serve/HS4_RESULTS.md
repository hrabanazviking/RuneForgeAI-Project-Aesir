# HS-4 Results — Gemma 4 session prefix cache (2026-11-14)

## What changed
- `core/gemma4_cuda.mojo`: the Gemma 4 session now carries the Llama 3
  session's exact-prefix discipline — `cached_tokens` snapshot on `reset()`
  (when `prefix_cache` is on), `reusable_prompt_prefix` reuse at the head of
  `begin_turn` (position 0 only, never while an image span is active),
  `reused_prompt_tokens` counted per token and reported through `status()`
  (previously a hard-coded 0). New constructor parameter
  `prefix_cache: Bool = True` mirrors the Llama session.
- `cli/native_serve.mojo`: the Gemma serve branch passes the serve's
  `prefix_cache` flag into the session and advertises it in `/health`
  (previously the Gemma branch silently dropped the flag).

## Proof (physical, gfx1151)
- Test: `aesir_engine/tests/test_hip_gemma4_prompt_prefix.mojo`, built for
  gfx1151, run fenced (MemoryHigh=24G / MemoryMax=32G) against the pinned
  fixture `gemma-4-E2B-it-Q4_K_M.gguf` (3,106,738,272 bytes, sha256
  740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8,
  re-verified before the run).
- Log: `hidden_files/hip-serve/hip-gemma4-prefix-test.log`, RUN_EXIT=0.
- Five cases, cache-disabled vs cache-enabled on one session: identical
  replies either way ("Four", "Four", "Five", the silver-ship sentence
  twice). Repeat turns reuse prompt_tokens − 1; the diverging turn reuses
  only the shared head; disabled cache reuses exactly 0.
- Engine rebuilt with the change (build-hs4.log, ENGINE_BUILD_EXIT=0);
  the live `aesir-gate` serve was restarted on the new binary afterwards
  and verified: `/health` ready (backend hip, exact_prefix_reuse true)
  plus a real chat completion.

## Machine-load note
The test ran while the machine was otherwise quiet (Voxta/Ollama idle,
MemAvailable ≈ 124 GB with the gate stopped). The gate was stopped for
the run and restarted immediately after; no other service was touched.
