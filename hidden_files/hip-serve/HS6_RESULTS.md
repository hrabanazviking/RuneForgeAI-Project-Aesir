# HS-6 results — session residency with token-level stateful composition

Date: 2026-11-14. Branch `yrsa/hip-serve`. Builds on HS-1…HS-5.

## The seam problem this slice closes

The HS-1 probe proved: an identical resent prompt reuses prompt−1 exactly,
but any resend that extends past a generation seam loses ~6 tokens at the
seam, because the resent STRING is re-tokenized and the join point
tokenizes differently than the original generation did. No string-level
cache can fix that; the fix is to never re-tokenize the prior conversation.

## What shipped

- `core/session_residency.mojo` — pure continuation predicate
  `resident_delta(...)`: returns the new user message iff the request's
  retained messages equal the resident store verbatim, extended by exactly
  [assistant == the reply the server generated] + [user: new message];
  "" for every other shape (edited history, foreign assistant text,
  missing echo, empty store).
- `server/openai.mojo` — requests may carry a top-level `session_id`
  (1..256 bytes, bounded); `_parse_messages` additionally retains the
  user/assistant message list (`msg_roles`/`msg_contents`) alongside the
  composed chat prompt.
- `cli/native_serve.mojo` — the serve keeps ONE resident conversation
  (the serve is single-session by design): id, system prompt, message
  list, generated reply. On an OpenAI chat/completions request that
  continues it (same id, same system, llama3/qwen3 profile, and the
  resident position + delta + requested output fits the context), the
  serve SKIPS `session.reset()`: the engine session's committed token
  stream and KV stay exactly where the last turn left them, and
  `begin_turn(delta, "", …)` appends only the new user message at the
  current position. The post-history anchor (HS-5) still applies to the
  delta. Usage accounting adds the resident base back:
  `prompt_tokens += resident_base`, `reused_prompt_tokens = resident_base`.
  Any non-continuing request invalidates residency BEFORE its turn;
  Ollama and native generations clear it too; a fresh successful
  session-carrying request re-seeds it. Failure semantics: a generation
  error with an unhealthy session stops the service (existing behavior),
  so resident state can never silently outlive a poisoned session.
  `/health` advertises `"session_residency":true`.
- Scope honesty: residency is wired for the Llama3-family session
  (llama3/qwen3 profiles). The Gemma4 session composes system+prompt in
  one string, so a system-less delta append is not proven there; Gemma
  requests use the stateless path with the HS-4 prefix cache.

## Proof

- Pure predicate test `tests/test_session_residency.mojo` PASS standalone
  (log `session-residency-test.log`, RUN_EXIT=0): exact continuation
  yields the delta; edited history, wrong reply echo, missing echo, and
  empty store all yield "". Registered in run_all as
  `serve.session_residency_delta`.
- Live bench `hs6_bench.py` (log `hs6-bench.log`), gate = llama3-3b on
  HIP, ctx 8192, fenced 24G/32G:
  - Phase A (stateless resend): A2 prompt 49, reused 28, **evaluated 21**.
  - Phase B (resident, `session_id`): B2 prompt 54, **reused 37 (the
    entire prior conversation), evaluated 17** — the 17 are only the new
    user message's own framing + content; ZERO prior tokens re-evaluated,
    so the seam loss is gone by construction. Wall 160 ms vs A2's 183 ms.
  - Phase C (control — same session id, edited history): fell back to the
    resend path, evaluated 22 ≈ A2. The fallback is honest and automatic.
  - Honest scale note: in this short bench the HS-1 prefix cache already
    reuses most of an identical resend, so the resident win is structural
    rather than dramatic in absolute tokens: the resident evaluated count
    is independent of conversation length and immune to prefix divergence,
    while the stateless count grows whenever the resent string diverges
    anywhere before the seam.
- Engine rebuilt clean (ENGINE_BUILD_EXIT=0); the standard gate was
  restarted on the new binary and verified (/health ready,
  session_residency true).

## Kobold dossier gap

`~/workspace/your_files/studies/koboldcpp/` still does not exist on the
coordinator VM (clone in flight elsewhere), so no Kobold KV patterns were
folded into this design; the design follows Aesir's own session internals.
If the dossier lands later, a reconciliation pass can compare.
