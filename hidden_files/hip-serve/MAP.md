# HIP-Serve Work Map — Project Aesir serving on gfx1151

Seat: worktree `/home/volmarr/aesir-hipserve`, branch `yrsa/hip-serve`, base
31ab9363 (main at A-127 banked, 127 of 216). Rules for this line: branch only,
never push to main; Ollama and Voxta are untouchable; all bench numbers carry a
machine-load note (contention honesty).

## Where the serve proof stands (verified 2026-11-14)

- The `aesir` binary builds on this box (campaign AMD matrix form, gfx1151 +
  shim libs) and `gemma4-e2b:latest` is imported in the catalog, hash-verified.
- `aesir serve` cannot bind here yet: the only serve path is the native one
  (`cli/native_serve.mojo` → `dispatch_native_serve`), and the native sessions
  (`core/llama3_cuda.mojo`, `core/gemma4_cuda.mojo`) are CUDA-only.
  `cli/native_settings.mojo` accepts only auto/cuda. On the Z13 the serve dies
  at device admission: no CUDA runtime, no CPU fallback.
- HIP kernels exist in the grading line (`core/hip_gemv.mojo`,
  `hip_q4k_gemv.mojo`, `hip_attention_norms.mojo`, `hip_memory.mojo`,
  `hip_transfer.mojo`, `rocm_pin.mojo`) — but there is no HIP *session*: no
  file implements the ControlledTextSession contract over HIP. That port is
  the gating work for everything below (slices HS-1/HS-2).

## Memory methods for fast chats

Design requirements from Volmarr (2026-11-14), drawn from the Voxta and
SillyTavern clean-room studies (workspace dossiers `studies/voxta/03`,
`studies/voxta/04`, `studies/sillytavern/02`, `studies/sillytavern/03`). The
enemy, measured on the Ollama road this morning: Voxta resends the whole
conversation every turn and Ollama re-evaluates it from cold — a 14,712-token
prompt cost 52.1 s of prompt evaluation before the first word.

### 1. Persistent sessions with KV reuse

Requirement: a served chat session keeps its KV resident across turns; the
stable prefix (system + character + standing context) is evaluated once; each
later turn evaluates only its new tokens. Every serve bench must include a
second-turn measurement on the same session: tokens actually evaluated on
turn 2 vs turn 1.

What exists today:
- `core/prompt_prefix.mojo` — `reusable_prompt_prefix(cached, prompt)`: the
  longest exact token prefix shared by the resident stream and a new prompt
  (the final prompt token always recomputes, so logits are fresh). Pure,
  device-independent, unit-tested (`tests/test_prompt_prefix.mojo`).
- The **Llama3 CUDA session** wires it end to end: `reset()` (called by the
  serve between requests) copies the committed token stream into
  `cached_tokens` and leaves the KV in place; the next turn skips forward
  evaluation for every reused position and counts them in
  `reused_prompt_tokens`. Proven by `tests/test_cuda_prompt_prefix.mojo`
  (turn 2 reuses prompt_tokens − 1; a diverged history reuses only the shared
  head). The serve advertises this as `exact_prefix_reuse` in its
  capabilities response, on by default (`--no-prefix-cache` disables it).
  The session also exposes `conversation_tokens()` / `restore_conversation()`
  — a committed conversation's KV can be suspended and restored.
- Responses already report `prompt_tokens` and prefill/decode timings, so
  evaluated-on-turn-N = prompt_tokens − reused_prompt_tokens is measurable
  per turn with no new instrumentation.

What is missing:
- The **Gemma4 CUDA session** has committed-token bookkeeping and `reset()`,
  but no cached stream and no reuse — every turn is cold. (This matters: the
  first model Voxta would meet is gemma4-e2b.)
- The **CPU facade** creates a fresh `KVCache` inside every generation call;
  `generate_session` wraps a cold run with SessionContext bookkeeping only.
- **`core/session.mojo` SessionManager does not hold KV.** SessionContext is
  bookkeeping — id, cancellation, TTL timestamps, `active_tokens`,
  `max_context`, and a `session_kv_offset` field that no KV storage reads.
  The manager registers/gets/releases contexts and evicts expired ones
  (max 16), but there is no per-session KV arena behind it. True
  multi-session residency (several chats warm at once) does not exist.
- No HIP session exists at all (see head of this map), so none of the above
  runs on the Z13 today.

### 2. Stable-order memory injection

Requirement: whatever memory/context a session injects is assembled in a
stable order, under a token budget, append-stable across turns, so the cached
prefix never churns. (Voxta renders recalled entries in a fixed order for
exactly this reason — reordering recalled memory each turn destroys prefix
caching; SillyTavern admits lore under a percentage-of-context budget,
whole entries only.)

What exists today: the serve injects exactly one standing block — the
`system` text (Modelfile/config default, per-request override) — passed to
`session.begin_turn(prompt, system, tokens)` ahead of the composed history.
It is stable by construction. There is no server-side recall/lore injection
in the serve layer today; assembly lives in clients (Voxta).

What is missing: a written injection contract for this layer, and enforcement
when server-side injection arrives (anchor, future recall): fixed block
order, budgeted admission of whole blocks only, and per-turn reuse counters
logged so any prefix churn is visible and attributable to the block that
changed.

### 3. Post-history anchor slot

Requirement: a block re-asserted AFTER the conversation history on every
turn — the unpushable character anchor (set by hand in Voxta this morning;
SillyTavern's card format reserves the same slot as
`post_history_instructions`, rendered last before generation).

What exists today: nothing at the serve layer. `native_settings` and the
request parsers know `system` (head) only; the gates compose
history → prompt → `begin_turn`, with no tail slot.

Design sketch (addition, slice HS-5): a serve-level `post_history` string,
sourced from the Modelfile/config with a per-request override field on the
chat gates, appended by the serve at turn-composition time — after the
composed history, before generation — never written into the stored history
and never part of the session's committed stream, so it is re-asserted fresh
each turn at full strength. Because it sits after the history, prefix reuse
(§1) still covers the entire history before it; its own tokens are evaluated
each turn, which is the intended cost of an anchor that cannot be pushed
out. A prompt-inspection view (the serve's settings/status surface) should
show it in final position.

### Slice plan

- **HS-1 — HIP session for one family.** Port the ControlledTextSession
  contract to a HIP session, Llama3 first (its session already carries
  prefix cache + conversation restore; Gemma4 second). Reuse the grading
  line's `core/hip_*` kernels. Gate: model loads on gfx1151; single-turn
  output graded against the CPU oracle under the campaign's raw-oracle
  discipline.
- **HS-2 — Serve binding.** `native_settings` accepts `hip`;
  `dispatch_native_serve` gains the HIP admission path; `serve_loaded`
  (already generic over ControlledTextSession) is unchanged. Gate:
  `aesir serve` binds a free port on the Z13 and answers both gates
  (Ollama-shaped + OpenAI) with the HIP session.
- **HS-3 — Two-turn KV bench (the §1 bench).** Scripted two-turn chat on one
  session, append-only history. Report per turn: prompt_tokens,
  reused_prompt_tokens, evaluated = prompt − reused, prefill ms, and the
  machine-load note. Gate: turn-2 evaluated tokens are a small fraction of
  turn-1 on the shared history. Baseline to beat: Ollama re-evaluating
  ~14.7k tokens per turn through Voxta.
- **HS-4 — Gemma4 prefix cache.** Port cached-stream + reuse from the
  Llama3 session into the Gemma4 session, with a test twin of
  `test_cuda_prompt_prefix`. Gate: gemma4-e2b reuses its prefix on turn 2.
- **HS-5 — Post-history anchor option.** Per the §3 sketch: config +
  per-request field, composition at the serve, status-surface visibility.
  Gate: in a context-full bench chat the anchor is present in final
  position on every turn and the character holds identity.
- **HS-6 — Real session residency.** Give SessionManager per-session KV
  arenas keyed by `session_kv_offset` in the HIP session layer:
  register/get/release with the existing TTL eviction, slot limits, LRU
  pressure relief. Gate: two interleaved sessions keep separate warm
  prefixes; eviction of one does not disturb the other.
- **HS-7 — Stable-order injection contract.** Per §2: fixed order, budgeted
  whole-block admission for any server-side injected block; reuse counters
  in the per-turn log. Gate: a mid-chat injected-block change shows reuse
  loss only from that block onward, zero before it.

## This pass (2026-11-14)

Delivered: this map, from a full audit of the session/serve source and the
four study sections named above. No code changed. The conditional minimum
implementation — session KV persistence via SessionManager — does not
trigger: SessionManager holds no KV today (§1), so there is nothing to
switch on; the working reuse mechanism is the Llama3 CUDA session's prefix
cache, which cannot execute on this AMD box until HS-1/HS-2 land. HS-1
through HS-7 are the follow-on work, in order.
