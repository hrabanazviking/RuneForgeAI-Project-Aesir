# HS-5 Results — serve-level post-history anchor slot (2026-11-14)

## What changed
- New pure module `core/post_history.mojo`:
  - `resolve_post_history(request, present, configured)` — a present
    per-request field wins (an explicitly empty value disables the anchor
    for that turn); otherwise the serve-configured anchor applies.
  - `apply_post_history(prompt, anchor)` — returns the composed prompt with
    the anchor in final position; the caller's prompt is never mutated.
- `cli/native_settings.mojo`: `NativeSettings` gains `post_history` /
  `has_post_history`, resolved from the Modelfile recipe parameter
  `post_history`, the serve flag `--post-history`, and recorded in
  `--show-settings` JSON. 64 KiB bound enforced.
- `cli/native_serve.mojo`: `serve --post-history <text>`; the anchor flows
  into `serve_loaded` and is applied at composition time in all three
  generation gates — OpenAI chat/completions and native `/v1/generate`
  accept a per-request `post_history` override; the Ollama gate applies
  the configured anchor (its request schema carries no override field).
  `/health` capabilities gain `post_history_configured`.
- `server/openai.mojo`: `post_history` request field parsed, 64 KiB bound.

## Proof
- Pure tests `tests/test_post_history.mojo` PASS standalone
  (`hidden_files/hip-serve/post-history-test.log`, RUN_EXIT=0) and are
  registered in the Grand Proving as `serve.post_history_resolution` and
  `serve.post_history_application`. They prove: resolution precedence,
  anchor lands after the history, and the stored history string is never
  mutated and never contains the anchor.
- Live (llama3-3b on HIP, gate started with
  `--post-history "Always answer in exactly one short sentence."`):
  - `/health` reported `"post_history_configured":true` (and `false`
    again after the standard gate was restored).
  - Turn 1: prompt_tokens 53, reused 0.
  - Turn 2 (client resent history WITHOUT any anchor in it):
    prompt_tokens 103, **reused_prompt_tokens 40** — reuse stops exactly
    where turn 1's anchor sat; the anchor is re-evaluated fresh in final
    position rather than carried inside the stored history. Turn 2's
    reply was a single short sentence.
  - Per-request override on `/v1/generate`
    (`"post_history":"Answer with a single word."`): reply "Blue".
- Engine rebuilt clean (build-hs5.log, ENGINE_BUILD_EXIT=0); the live
  gate was restored to the standard runbook configuration afterwards and
  verified healthy.
