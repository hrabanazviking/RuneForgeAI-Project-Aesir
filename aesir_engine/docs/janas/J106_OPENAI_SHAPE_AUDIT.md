# J-106 — Server: OpenAI-Shape Audit

**Slice:** J-106 (Part VII — The Tool Family, J-099–J-118), Project Aesir Janas clean-room road.
**Roadmap text:** "Server: OpenAI-shape audit. Aesir's HTTP API audited against the OpenAI chat-completions shape Janas's server follows: the diff list (fields honoured, ignored, refused), each closed or consciously kept."
**Owns (J-099 census):** rows **T11** (the field-level diff of the OpenAI chat-completions core), **T12** (the wider OpenAI surface: close-or-keep per route, incl. the live serve's 404-vs-501-class question), **T13** (embeddings endpoint), **T14** (`cached_tokens` accounting in usage objects), **T16** (security manners: TLS disposition), **T17** (grammar-held / schema output), **T19** (speech-to-text routes — REFUSED-candidate; "J-106 answers its routes in the honest refusal class"), and **T20** (the unwired J-049 server-placement parity layer: "wire it or file why not"). Per the **J-014 GATE NOTE**: "J-106 audits Janas's full documented server surface with the speech routes kept out by this gate's refusal" — the speech routes are answered in the refusal class, never built or audited as a pipeline.
**Base:** branch `yrsa/janas-j106` in fresh worktree `~/workspace/aesir-janas-j106`, from `yrsa/janas-j105` tip `fde780603396066b410a4c32995326e9f09c0464` (ls-remote verified at slice start: remote `yrsa/janas-j106` absent — the duplicate guard; remote `yrsa/janas-j105` == that hash). **Origin/main observation (recorded, not acted on):** `origin/main` stands at `4ca75cc237de872a7e69777872ec1077f9e93e92` at slice start. This slice does not rebase onto it and does not touch main; the campaign chain continues from the j105 tip, as with every prior slice.
**Clean-room record:** no Janas material was consulted in this slice beyond the road's own already-filed clean-room records — the roadmap text, the J-014 gate note, the J-099 census (rows T11–T20 and its §3 J-106 line), and the Part I census's filed summary of Janas's documented server (CENSUS.md: the `janas-server` row and the wider-surface row, from Janas's public docs). No Janas source code was opened, in this slice or any other. The OpenAI chat-completions shape is a public API shape; its field list is stated from the shape itself. Every design question those records do not answer is answered from Aesir's own architecture and recorded as answered-locally in §8.

---

## 0. Protocol (committed first, before any code was built)

This section was committed before the audit module, the parser/serve wiring, or any test existed. It states what the inspection found, the audit's tables as decision rules, the closures this slice takes, the conscious keeps with their reasons, and the verdict rule for the slice; everything after §0 is filed under these rules and no others.

### 0.1 What exists, and the exact delta (re-verified first-hand in this tree at the base tip)

- **The live service** is `cli/native_serve.mojo`'s `serve_loaded` (J-099 T11): routes `/v1/chat/completions`, `/v1/completions`, `/v1/models`, `/health`, `/health/live`, `/health/ready`, `/v1/generate`, plus Ollama-mode `/api/*` — one resident CUDA session, concurrency 1, loopback IPv4 only, API-key file with constant-time Bearer <redacted> in native mode, Host checked, Origin/Referer/Sec-Fetch-Site refused 403 (`server/local_protocol.mojo`'s `LocalHTTPHead`). `server/api.mojo`'s router is a disconnected scaffold whose dispatch returns 501 for every model-backed route (`legacy_route_response` also names `/infill`, `/tokenize`, `/props`, `/slots`, `/metrics`); it is **not** the live surface and not an audit target beyond recording that fact.
- **The request parser is bounded and fail-closed** (`server/openai.mojo`'s `OpenAIRequest`): at most 16 top-level fields, duplicates refused, and every field it does not honour is refused by name — `raise Error("Unsupported OpenAI request field: " + name)`. It honours `model`, `prompt`, `messages`, `stream`, `max_tokens`, `temperature`, `seed`, `top_p`, `n` (== 1 only), `response_format` (strict Boolean `json_schema` only), `tools` (one zero-arg Gemma function only), `tool_choice` (`"auto"` only). Messages honour only `role` + string `content`; roles `system`/`user`/`assistant` only; the last message must be the user's. **Consequence (the audit's headline): on this surface nothing is silently ignored** — the roadmap's "ignored" column is empty by construction, and every diff row is HONOURED, PARTIAL (a stated subset honoured, the rest refused by name), or REFUSED. This is a stricter manner than the shape's own ignore-what-you-don't-know convention, and the audit keeps it (§8).
- **The documented Janas server shape** (filed census, from public docs only): chat completions with streamed SSE, grammar-held tool arguments, JSON output held to a schema token-by-token, logprobs ≤ 20, `n` replies, penalties, `logit_bias`; raw completions with `echo`, `best_of`, `suffix`; `/infill`; models list; `/health`; a `reasoning_content` separation and the `max_tokens` (answer-only) vs `max_completion_tokens` (incl. reasoning) distinction; a `janas` usage extension carrying context + timing; embeddings from a second small model; speech-to-text from a Whisper model; and the wider surface — Responses, Conversations, Files, Uploads, Batches, Vector Stores, Evals, Assistants, stored completions — 100 of the OpenAI spec's 345 operations served, **every other operation answered 501 with its reason**.
- **The gaps this slice owns, exactly:** (T11) no `max_completion_tokens` (the modern budget field is refused by name today); the `developer` role is refused though the shape aliases it to system; chat responses carry a `cmpl-` id where the shape specifies `chatcmpl-` for chat completions. (T12) the live serve answers every unserved route an indistinguishable **404** — there is no honest 501 class in the live surface, though Janas's documented shape has one and Aesir's own disconnected scaffold had one. (T13) `/v1/embeddings` is one of those 404s; `server/openai.mojo`'s `format_embeddings` is an error-only stub ("without real vector data"); `/health` states `embeddings:false`. (T14) exact prefix reuse exists in the Llama 3 CUDA session (its `reused_prompt_tokens` counter, serve default on, `--no-prefix-cache` to refuse) but **usage objects carry no `cached_tokens`** — the string appears nowhere in `native_serve.mojo` (J-099, re-verified); the Gemma 4 session has no prefix reuse at all; `NativeGenerationStatus` carries no cached count. (T16) no TLS — plain HTTP on loopback is the current stated shape. (T17) schema holding is the strict Boolean form only (non-streaming, greedy-only); general JSON-schema token-by-token holding does not exist; the engine facade's `generate_tokens_with_grammar` still raises "not implemented". (T19) no speech pipeline exists; J-013's refusal stands. (T20) the J-049 parity layer (`core/server_placement.mojo`: session defaults + per-request fields + conformance, unit-proven by `test_server_placement`) is **unwired** — `native_serve.mojo` contains no `server_placement` reference and no `prompt_on` field; the serve flags refuse placement options as unsupported, and the OpenAI parser refuses the placement field names as unsupported fields.
- **Response shape** (`OpenAIGate`): `id`, `object`, `created`, `model`, `choices[0]` (`message{role,content}` or the Gemma `tool_calls` form, `finish_reason` mapped eos→stop, else the session's reason verbatim), `usage{prompt_tokens, completion_tokens, total_tokens}` — all caller-observed, nothing invented (the Gate's own contract). Absent: `logprobs` on choices, `system_fingerprint`, `service_tier`, a usage object on streamed chunks, and any non-standard extension (Janas's `janas` usage extension has no Aesir counterpart on this route; Aesir's timing truth lives on the native `/v1/generate` route's `timings_ms`). **Error shape:** `local_response` answers non-200 as `{"error":{"code":<http int>,"message":<reason phrase>}}` — deliberately never echoing request contents, paths, or driver errors (the serve loop's stated rule); OpenAI's typed `{message,type,param,code}` object differs, and the streamed error events do carry a `type`.

### 0.2 The audit layer (the pure layer)

A new pure module, **`aesir_engine/core/openai_audit.mojo`**, owns the audit as tables and decisions every host shares, following the road's established shape (pure logic unit-tested at the lightest target; hosts execute the decisions; no session or socket is faked):

- **Field tables + verdicts:** `chat_field_names()` (the shape's 31 chat-completions request fields, canonical order) with `chat_field_verdict(name)` → `FIELD_HONOURED` / `FIELD_PARTIAL` / `FIELD_REFUSED`; `completion_field_names()` (19) with `completion_field_verdict(name)`; `message_field_names()` (7) with `message_field_verdict(name)`; `message_role_names()` (6) with `message_role_verdict(name)`. A name outside a canonical list is REFUSED — the parser refuses strangers by name, so table and parser agree on strangers by construction.
- **Route table + verdicts:** `served_route_names()` (8 `"METHOD path"` keys, incl. the `GET /v1/models/{id}` retrieve pattern and Aesir's own health/native additions, listed so the audit's served set is the serve's whole truth), `refused_route_names()` (the 501 class, §0.3 C5), `kept_404_route_families()` (8), `is_model_retrieve(method, path)` (exactly one non-empty segment after `/v1/models/`), and `route_verdict(method, path)` → `ROUTE_SERVED` / `ROUTE_REFUSED_501` / `ROUTE_KEPT_404`.
- **The refusal class's bodies:** `refusal_reason(method, path)` (one plain sentence per refused route, in Aesir's own terms) and `unsupported_route_body(method, path)` (the 501 body in Aesir's standing error shape `{"error":{"code":501,"message":…}}`, the route key escaped by the module's own minimal escaper — the module imports no server module, keeping the layering core-pure as with `chat_manners`).

### 0.3 The closures (each closed in scope, wired, and tested)

- **C1 — `max_completion_tokens` honoured (T11).** `OpenAIRequest` accepts the field (positive, bounded, like `max_tokens`); when both budget fields are sent, `max_completion_tokens` takes precedence, which is the shape's own stated relation (its predecessor is deprecated in its favour). Answered-locally (§8): Aesir's sessions have no reasoning channel, so Janas's answer-only vs reasoning-inclusive distinction collapses to the one completion budget — the field is honoured as that budget, and the collapse is recorded, not silent.
- **C2 — the `developer` role honoured (T11).** The message parser treats `developer` exactly as `system`, the alias the shape defines for it.
- **C3 — `cached_tokens` accounting (T14).** `NativeGenerationStatus` gains a `cached_tokens` count (trailing, defaulted 0, so existing constructors stand): the Llama 3 session's status reports its own `reused_prompt_tokens` for the turn; the Gemma 4 session reports the default 0 — it has no prefix reuse, and 0 is the truth. `OpenAIGate`'s three usage-carrying formatters (chat, raw completion, tool completion) gain a trailing defaulted `cached_tokens` parameter and emit `usage.prompt_tokens_details.cached_tokens`, validated caller-observed like every Gate field (negative refused; a count above the prompt count refused — reuse cannot exceed the prompt). The serve's OpenAI routes pass the status's count. Streamed responses gain no usage object (C-kept K5 below).
- **C4 — `GET /v1/models/{id}` retrieve (T11/T12).** The serve answers the retrieve pattern with the single model object (`OpenAIGate.format_model_object`, the list formatter's one-record sibling) when the id matches a catalog or loaded model under the serve's standing `ollama_model_matches` rule, else the standing 404.
- **C5 — the honest 501 class in the live serve (T12/T13/T19).** Before the standing 404, the serve consults `route_verdict`: a `ROUTE_REFUSED_501` request line answers **501** with `unsupported_route_body`'s reason, body preserved, and `local_response` learns the 501 reason phrase. The class holds exactly the inference-adjacent routes a client of this shape probes: `POST /v1/embeddings` (T13 — no embedding data path exists; a second model kind is not loaded), `POST /v1/audio/transcriptions` + `POST /v1/audio/translations` + `POST /v1/audio/speech` (T19 — refused under the J-014 gate: answered, never built), `POST /v1/responses` (the stateful items surface, kept out), `POST /v1/moderations` (no classifier or held-schema moderation path exists). Method matters: a non-POST request to one of these paths keeps the standing 404.
- **C6 — the `chatcmpl-` id prefix (T11).** The serve's OpenAI branch mints `chatcmpl-aesir-<seq>` on the chat route and keeps `cmpl-aesir-<seq>` on the raw-completions route, the shape's own prefix distinction.

### 0.4 The conscious keeps (each kept with its reason; the full per-row tables are §2's filing)

- **K1 — general JSON-schema holding (T17): KEPT partial.** Only the strict Boolean `json_schema` form is held (non-streaming, greedy-only). Janas holds arbitrary schemas token-by-token incl. bounds/formats/patterns; Aesir's bounded GBNF automaton (`core/grammar.mojo`) exists but no CUDA sampling path holds a general schema, and building one is engine work, not an audit closure. The facade's grammar entry stays "not implemented" and says so. Re-cited at the J-118 gate.
- **K2 — `logprobs` / `top_logprobs`: KEPT refused.** The `ControlledTextSession` contract surfaces text chunks and counts, never per-token log-probabilities; no consumer on this road names them. Refused by name, as today.
- **K3 — `stop` sequences: KEPT refused.** No stop-sequence hook exists in the session contract (EOS / context / cancel / deadline are the stop causes); a parser-side acceptance with no execution would be a silent ignore, which this surface does not do.
- **K4 — penalties and `logit_bias`: KEPT refused.** `NativeSamplingConfig` carries a multiplicative `repetition_penalty` only; the shape's additive presence/frequency penalties are different mathematics and mapping them onto the multiplier would misstate what was asked. `logit_bias` has no sampler hook. Both refused by name; the native/Ollama surfaces keep their own `repeat_penalty` grammar, which is not an OpenAI field and is not claimed as one.
- **K5 — streaming usage (`stream_options`): KEPT refused.** Streamed chunks carry no usage object today; honouring `include_usage` is a stream-protocol change riding J-107's streaming leg, not an audit closure. Non-streamed usage is complete (C3).
- **K6 — `n` > 1, `best_of`, `echo`: KEPT refused/narrowed.** The service is one resident session at concurrency 1; `n` is honoured exactly at 1 and refused above it rather than faked. `echo` would need the prompt echoed from a session that does not hand it back; `best_of` is `n` in a trench coat.
- **K7 — message extras: KEPT refused.** Content parts (arrays, `image_url`) — vision inputs ride the vision path owned elsewhere on the platform, not this text surface; `name`, `tool_calls`, `tool_call_id`, `refusal`, `audio` message fields and the `tool`/`function` roles — the one tool shape here is a declared zero-arg Gemma function answered in one turn; there is no tool-result round trip to carry them.
- **K8 — request metadata fields (`user`, `metadata`, `store`, `service_tier`, `parallel_tool_calls`, `reasoning_effort`, `modalities`, `audio`, `prediction`, `web_search_options`, legacy `functions`/`function_call`): KEPT refused.** Each names a plane this service does not have (accounts, storage, tiers, reasoning channels, web access) or a deprecated duplicate of the PARTIAL `tools` row. Strict refusal-by-name (the surface's standing manner) is kept over the shape's ignore convention (§8).
- **K9 — TLS (T16): KEPT absent, consciously.** The service binds loopback IPv4 only, checks Host, refuses browser-origin headers 403, and requires the key file in native mode; TLS on a loopback-only socket adds certificate machinery for no network exposure. Plain HTTP on loopback is the stated shape (J-099 T16's own wording). If the service ever binds beyond loopback, this keep falls and TLS becomes a defect — recorded as the keep's condition.
- **K10 — the administrative families at 404 (T12): KEPT.** Files, Uploads, Batches, Vector Stores, Evals, Assistants, Images, Fine-tuning stay the standing 404, diverging from Janas's 501-for-everything shape consciously: Aesir has no storage or administration plane at all, so a 501 ("not implemented *yet*") would misdescribe a structural absence; the 501 class (C5) is reserved for routes adjacent to the inference surface this service actually is. Re-cited at the J-118 gate.
- **K11 — the placement request fields (T20): KEPT unwired — filed why-not.** The J-049 parity layer stays a proven pure layer and does **not** get wired into the serve by this slice. Why not, in full in §3: (i) J-049's own host contract is a three-part serve-wide change (argv scan at dispatch, per-parser field claiming in all three request shapes, conformance calls before `session.reset()`), of which the OpenAI parser is only one of three shapes — an audit slice wiring one shape would leave the parity incoherent; (ii) placement is allocation-bound state (J-049's parity rule): on this resident CUDA service every conforming request outcome is the already-executing single-GPU placement, so the wiring's only live effect today is a new refusal path — a change whose entire observable behaviour is refusals wants its own slice and its own live leg, not a ride-along in an audit; (iii) no live serve leg can run under this slice's bounds (§5), so the wiring could not be proven past compilation here, and J-049 already records the layer NOT PROVEN at the live surface. The fields stay refused by name on this route (`prompt_on` and kin are REFUSED rows in §2's table), the J-049 host contract is re-cited verbatim as the recipe in §3, and the disposition is re-cited at the J-118 gate.
- **K12 — error-object shape: KEPT.** Aesir's `{code:<http int>, message:<reason phrase>}` stands against the shape's typed object: the serve's no-echo rule (never request contents, paths, or driver errors) is a security manner (T16's family), and `type`/`param` would either leak or be invented. The streamed error events' `type` is the existing compromise and stands.
- **K13 — a `janas`-style usage extension: KEPT absent.** No non-standard fields are added to OpenAI-shape responses; Aesir's context/timing truth rides its own native route (`timings_ms`, `context_used`) and `/health`, where a client of Aesir's own shape reads it.

### 0.5 Wiring summary (what changes in existing files)

- `server/openai.mojo`: `OpenAIRequest` gains `max_completion_tokens` (C1, precedence at end of parse) and the `developer` role (C2); `OpenAIGate` gains the defaulted `cached_tokens` parameter + `prompt_tokens_details` on the three usage formatters (C3) and `format_model_object` (C4).
- `core/generation_control.mojo`: `NativeGenerationStatus` gains the defaulted trailing `cached_tokens` field (C3).
- `core/llama3_cuda.mojo`: `status()` passes `reused_prompt_tokens` as the cached count (C3). `core/gemma4_cuda.mojo`: untouched — its status keeps the honest default 0.
- `cli/native_serve.mojo`: the OpenAI routes pass `state.cached_tokens` into the three formatters (C3); the models retrieve branch (C4); the 501 branch before the standing 404 + `local_response`'s 501 phrase (C5); the per-route request-id prefix (C6). No Ollama route, native route, session, or loader changes.
- Tests: `tests/test_openai_audit.mojo` (new, standalone lightest target, the standing precedent). Neighbours in the touched files' import graph — `test_local_protocol` (the parser + Gate surface), `test_server_placement` (the T20 layer this slice dispositions), `test_multi_engine` (Gate formatter callers) — are rebuilt from this tree.

### 0.6 Verdict rule for this slice (pre-registered)

The slice **passes** iff all of the following hold, each filed:

(a) **Audit layer:** `test_openai_audit` PASSes at the lightest target: the chat field table (31 fields: 8 HONOURED / 4 PARTIAL / 19 REFUSED, strangers REFUSED); the completion table (19: 8 / 1 / 10); the message tables (2/7 fields honoured; 4/6 roles honoured incl. `developer`); the route table (8 served incl. the retrieve pattern, 6 REFUSED_501, the kept families + strangers + wrong-method at KEPT_404); the refusal bodies (501 + route + a real reason per refused route); the parser closures (C1 precedence, C2, and the kept refusals still refusing); the usage accounting (C3 on all three formatters, the honest-zero defaults, the over-prompt refusal, the status field's default + carry).
(b) **Wiring compilation:** a staging driver importing `cli/native_serve` whole compiles and runs (the J-105 precedent for serve-surface wiring).
(c) **Neighbours:** the suites rebuilt from this tree PASS at their filed counts — `test_local_protocol`, `test_server_placement`, `test_multi_engine` — plus any suite in the touched files' import graph that the build shows affected. Any suite not rebuilt is named with its reason, never silently skipped.
(d) **Inspect:** `docs/janas/j106_inspect.py` re-derives the load-bearing claims and PASSes: the audit module's tables equal their extracted surfaces (the parser's honoured field set + the closures; the message roles in the parser; the serve's route branches incl. the retrieve + 501 branches and the id prefixes; the formatters' `prompt_tokens_details`; the status field and the Llama pass-through; the legacy scaffold's non-liveness left alone); the doc's §2 tables equal the module's tables; the test suite's group structure; the filed test output's tallies; repo hygiene (no README, no `.gguf` in the slice diff, diff == the expected file set). Every FAIL is disposed in the doc, never hidden.
(e) **The live server leg is not part of the pass rule:** no CUDA device exists on this VM and the VM memory gate (MemAvailable > 5,500 MB) bars inference — a live service leg (the serve started on a real model, the routes exercised with real requests: a chat completion with `max_completion_tokens` and a repeated-prefix turn showing `cached_tokens` > 0, the retrieve route, each 501 route, a refused field's 400) is filed DEFERRED-WITH-REASON with its exact recipe in §5, re-cited at the **J-118 Part VII gate**.

**Honesty classes.** The audit tables, refusal bodies, parser closures, and formatter accounting are **PROVEN** by the unit suite where it passes. The wiring's composition (which branch consults the audit, branch order, the id prefixes, the status pass-through) is **PROVEN (inspection sense)** from the tree plus the compile driver's whole-module compilation. Live server behaviour — a real request round trip on any route — is **NOT PROVEN** by this slice and is named in §9.

**No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk.**

*(§§1–10 are filed below from the build, under this protocol.)*

## 1. Headline

**The OpenAI shape is now audited as tested tables, and its six closable gaps are closed.** A new pure module, `core/openai_audit.mojo`, owns the diff as decision rules: the chat-completions field table (31 fields: **8 HONOURED / 4 PARTIAL / 19 REFUSED** — the surface's "ignored" column is empty by construction, because the bounded parser refuses every field it does not honour, by name), the raw-completions table (19: 8/1/10), the message tables (2/7 fields, 4/6 roles), and the route table (8 served, 6 in the new 501 class, the administrative families kept at 404). The closures land wired in the live surfaces: **C1** `max_completion_tokens` honoured with precedence over `max_tokens`; **C2** the `developer` role honoured as the system role it aliases; **C3** `cached_tokens` accounting — the session status carries the turn's reused-prefix count (the Llama 3 session's own counter; Gemma 4 honestly 0) and all three usage formatters emit `usage.prompt_tokens_details.cached_tokens`, validated caller-observed; **C4** `GET /v1/models/{id}` retrieve beside the list route; **C5** the honest **501 class** in the live serve (embeddings, the speech family under the J-014 gate refusal, responses, moderations — 501 with a reason, never an indistinguishable 404; wrong method stays 404); **C6** `chatcmpl-` ids on the chat route, `cmpl-` kept on raw completions. The keeps are conscious and reasoned per row (§2, §0.4 K1–K13), including **T20: the J-049 placement parity layer stays unwired, filed why-not in full in §3** with its host contract re-cited as the recipe. **Unit suite: `test_openai_audit` 7/7 groups PASS; neighbours `test_local_protocol`, `test_server_placement` 17/17, and `test_multi_engine` PASS as filed (§6); the native-serve compile driver PASS (§6); inspect filed in §6.** **The live server leg is DEFERRED-WITH-REASON (§5)** — no CUDA device exists on this VM and MemAvailable stayed below the 5,500 MB inference gate throughout — so real request round trips on any route are **NOT PROVEN** (§9), to be re-cited at the **J-118 Part VII gate**.

## 2. The diff tables (the audit's filing; the module's tables, row for row)

Verdicts: **HONOURED** = the field is parsed and executed as the shape states; **PARTIAL** = a stated subset is honoured and the rest is refused by name; **REFUSED** = refused by name at parse (`Unsupported OpenAI request field: <name>`), never silently ignored. The tables below are the module's tables exactly — the inspect (§6) re-derives both and fails if they drift.

### 2.1 Chat-completions request fields (31)

| Field | Verdict | Note |
|---|---|---|
| `model` | HONOURED | bounded name, matched against the resident model |
| `messages` | HONOURED | bounded array; §2.3/§2.4 govern its objects |
| `temperature` | HONOURED | through the sampling options, validated |
| `top_p` | HONOURED | through the sampling options, validated |
| `seed` | HONOURED | through the sampling options, validated |
| `max_tokens` | HONOURED | positive, bounded |
| `max_completion_tokens` | HONOURED | **C1** — takes precedence over `max_tokens` when both are sent |
| `stream` | HONOURED | SSE chunks; no usage object on chunks (K5) |
| `n` | PARTIAL | honoured exactly at 1; above 1 refused (K6) |
| `response_format` | PARTIAL | strict Boolean `json_schema` form only, non-streaming, greedy-only (K1) |
| `tools` | PARTIAL | one declared zero-arg Gemma function only |
| `tool_choice` | PARTIAL | `"auto"` only, and only with a declared tool |
| `stream_options` | REFUSED | K5 — streaming usage rides J-107's streaming leg |
| `stop` | REFUSED | K3 — no stop-sequence hook in the session contract |
| `presence_penalty` | REFUSED | K4 — additive penalties are different mathematics from the multiplier |
| `frequency_penalty` | REFUSED | K4 — as above |
| `logit_bias` | REFUSED | K4 — no sampler hook |
| `logprobs` | REFUSED | K2 — the session contract surfaces no per-token log-probabilities |
| `top_logprobs` | REFUSED | K2 — as above |
| `user` | REFUSED | K8 — no accounts plane |
| `metadata` | REFUSED | K8 — no storage plane |
| `store` | REFUSED | K8 — no storage plane |
| `service_tier` | REFUSED | K8 — no tiers plane; responses carry no tier field either (K13's family) |
| `parallel_tool_calls` | REFUSED | K8 — the one tool shape is a single declared function |
| `reasoning_effort` | REFUSED | K8 — no reasoning channel (see C1's collapse, §8) |
| `modalities` | REFUSED | K8 — text surface; vision rides its own path (K7's family) |
| `audio` | REFUSED | K8/K7 — no audio plane on this surface |
| `prediction` | REFUSED | K8 — no predicted-output plane |
| `web_search_options` | REFUSED | K8 — no web access plane |
| `functions` | REFUSED | K8 — deprecated duplicate of the PARTIAL `tools` row |
| `function_call` | REFUSED | K8 — deprecated duplicate of the PARTIAL `tool_choice` row |

Any field outside this list — including the J-049 placement names (`prompt_on` and kin, §3) — is REFUSED by the same rule: the parser refuses strangers by name, so the table and the parser agree on strangers by construction.

### 2.2 Raw-completions request fields (19)

The route shares `OpenAIRequest` with the chat route, so the honoured core is the same; the shape's completion-only fields are graded here.

| Field | Verdict | Note |
|---|---|---|
| `model` | HONOURED | as §2.1 |
| `prompt` | HONOURED | string prompt; a messages body on this route is refused |
| `temperature` | HONOURED | as §2.1 |
| `top_p` | HONOURED | as §2.1 |
| `seed` | HONOURED | as §2.1 |
| `max_tokens` | HONOURED | as §2.1 |
| `max_completion_tokens` | HONOURED | C1, as §2.1 |
| `stream` | HONOURED | as §2.1 |
| `n` | PARTIAL | exactly 1, as §2.1 (K6) |
| `suffix` | REFUSED | the FIM/infill question is J-111's; refused here until that slice |
| `echo` | REFUSED | K6 — the session does not hand the prompt back to echo |
| `best_of` | REFUSED | K6 — `n` in a trench coat |
| `logprobs` | REFUSED | K2 |
| `stream_options` | REFUSED | K5 |
| `stop` | REFUSED | K3 |
| `presence_penalty` | REFUSED | K4 |
| `frequency_penalty` | REFUSED | K4 |
| `logit_bias` | REFUSED | K4 |
| `user` | REFUSED | K8 |

### 2.3 Message fields (7)

| Field | Verdict | Note |
|---|---|---|
| `role` | HONOURED | §2.4 governs the values |
| `content` | HONOURED | string content only, bounded and nonempty |
| `name` | REFUSED | K7 — no named-participant plane |
| `tool_calls` | REFUSED | K7 — no tool-result round trip to carry them |
| `tool_call_id` | REFUSED | K7 — as above |
| `refusal` | REFUSED | K7 — no refusal-content plane |
| `audio` | REFUSED | K7 — no audio message plane |

Content parts (arrays, `image_url`) are refused by the same construction: `content` must be a string, and any other message field is refused by name (K7).

### 2.4 Message roles (6)

| Role | Verdict | Note |
|---|---|---|
| `system` | HONOURED | accumulates into the session system text |
| `developer` | HONOURED | **C2** — treated exactly as `system`, the alias the shape defines |
| `user` | HONOURED | the final message must be the user's |
| `assistant` | HONOURED | prior turns ride the transcript |
| `tool` | REFUSED | K7 — no tool-result round trip |
| `function` | REFUSED | K7 — the deprecated form of the same absence |

### 2.5 Routes

| Route | Verdict | Note |
|---|---|---|
| `POST /v1/chat/completions` | SERVED | C3/C6 land here |
| `POST /v1/completions` | SERVED | C3 lands here; `cmpl-` ids kept |
| `GET /v1/models` | SERVED | the list route |
| `GET /v1/models/{id}` | SERVED | **C4** — one model object when the id matches under the serve's standing `ollama_model_matches` rule (catalog or resident), else the standing 404 |
| `GET /health` | SERVED | Aesir's own addition; states `embeddings:false` truthfully |
| `GET /health/live` | SERVED | Aesir's own addition |
| `GET /health/ready` | SERVED | Aesir's own addition |
| `POST /v1/generate` | SERVED | Aesir's native route; timing truth (`timings_ms`) lives here (K13) |
| `POST /v1/embeddings` | REFUSED_501 | **C5/T13** — no embedding data path exists; a second model kind is not loaded; refused honestly, not faked |
| `POST /v1/audio/transcriptions` | REFUSED_501 | **C5/T19** — speech-to-text refused under the J-014 gate: answered, never built |
| `POST /v1/audio/translations` | REFUSED_501 | **C5/T19** — as above |
| `POST /v1/audio/speech` | REFUSED_501 | **C5/T19** — no speech pipeline exists and none is roaded |
| `POST /v1/responses` | REFUSED_501 | **C5** — a stateful items surface; this service is a stateless single-model chat/completions surface |
| `POST /v1/moderations` | REFUSED_501 | **C5** — no classifier model or held-schema moderation path exists |

Method matters: a non-POST request to a 501-class path keeps the standing 404, and a deeper models path (`/v1/models/a/b`) keeps it too. The wider administrative families — `/v1/files`, `/v1/uploads`, `/v1/batches`, `/v1/vector_stores`, `/v1/evals`, `/v1/assistants`, `/v1/images`, `/v1/fine_tuning` — are **KEPT_404** (K10): Aesir has no storage or administration plane at all, so a 501 there ("not implemented *yet*") would misdescribe a structural absence; the 501 class is reserved for routes adjacent to the inference surface this service actually is. The disconnected `server/api.mojo` scaffold (501 for every model-backed route) is not the live surface, was not an audit target beyond recording that fact in §0.1, and is left exactly as it stood.

**Response and error shapes (kept, K12/K13):** chat/raw/tool responses carry `id` (C6 prefixes), `object`, `created`, `model`, `choices`, and `usage` now including `prompt_tokens_details.cached_tokens` (C3). Absent and kept absent: `logprobs` on choices (K2), `system_fingerprint`, `service_tier`, a usage object on streamed chunks (K5), and any non-standard usage extension (K13 — Aesir's context/timing truth rides `/v1/generate` and `/health`). Errors keep Aesir's standing `{error:{code:<http int>, message:<reason phrase>}}` shape — now including the 501 phrase "Not Implemented" — under the serve's no-echo rule (never request contents, paths, or driver errors); the shape's typed `{message,type,param,code}` object stays refused as a design (K12), with the streamed error events' `type` the existing compromise. **TLS (T16) is KEPT absent (K9):** loopback IPv4 only, Host checked, browser-origin headers refused 403, key file required in native mode; if the service ever binds beyond loopback, the keep falls and TLS becomes a defect.

## 3. T20 — the J-049 placement parity layer: filed why-not

**Disposition: KEPT unwired (K11).** The J-049 parity layer (`core/server_placement.mojo`: session defaults + per-request fields + conformance) stays a proven pure layer — its neighbour suite passes 17/17 rebuilt from this tree (§6) — and this slice does **not** wire it into the serve. The placement field names stay REFUSED rows on the OpenAI route (§2.1's stranger rule). Why not, in full:

1. **The host contract is a three-part serve-wide change, and an audit slice wiring one part leaves the parity incoherent.** J-049's own contract (re-cited verbatim below) requires (1) an argv scan at dispatch, (2) per-parser field claiming in **all three** request shapes (native, Ollama, OpenAI), and (3) conformance calls before `session.reset()`. The OpenAI parser is one of three shapes; wiring it alone would make the same request's placement honoured on one route and refused by name on its siblings — a worse surface than today's uniform refusal.
2. **Placement is allocation-bound state (J-049's parity rule), and on this resident CUDA service every conforming request outcome is the already-executing single-GPU placement.** The wiring's only live effect today is therefore a new refusal path (non-conforming requests refused with their reason). A change whose entire observable behaviour is refusals wants its own slice and its own live leg, not a ride-along in an audit.
3. **No live serve leg can run under this slice's bounds (§5), so the wiring could not be proven past compilation here** — and J-049 already records the layer NOT PROVEN at the live surface. An audit that wires what it cannot prove would misstate its own evidence class.

**The recipe, re-cited verbatim from `core/server_placement.mojo`'s host contract, for the slice that takes the wiring (and re-cited again at the J-118 gate):**

> (1) dispatch_native_serve learns the placement + mode flags by scanning its argv with J-036's scan_placement_args() + J-047's scan_mode_args() and resolving with placement_env_inputs() / mode_env_inputs() + resolve_placement_options() / resolve_mode() — today it refuses those flags as unsupported service options, which is the startup half of the gap this slice names. (2) The serve open then calls resolve_server_defaults() (open refusal + quality gate + one precedence resolution), states the resident placement truthfully (for the CUDA service: single gpu for the prompt and reply kinds — the backend=cuda the loop's own banner, health, and readiness documents already state), and calls require_server_defaults_conformance() before serving. (3) Each generation parser claims the four placement field names through apply_server_placement_field() BEFORE its own unknown-field refusal (a claimed name is this surface's; an unclaimed name keeps the parser's standing refusal), then the loop calls resolve_server_request_placement() and require_server_request_conformance() before session.reset(); a refusal answers the request with its reason and leaves the session untouched.

## 4. Machine state for every number

VM (KVM), 4 vCPU, kernel 7.0.0-39-generic. Execution, stated honestly in two hands: the original worker ran **2026-11-02 ~00:3x–01:2x EST** (the §0 protocol commit `feaae2ac`, the audit module, the parser/serve wiring, the test suite, and staging build logs), then stalled mid-slice with the slice unbanked; the completion worker finished it **2026-11-02 ~01:30–02:1x EST** (first-hand re-inspection of the inherited diff against §0, every suite rebuilt and re-run from the final tree, this doc's post-protocol sections, the inspect, campaign copies, banking). MemAvailable: ~4.3 GB at the keeper's dispatch check, ~3.9–4.3 GB during the completion builds — **below the 5,500 MB inference gate throughout: lightest compiles and pure-logic unit runs only, one at a time; NO model inference ran anywhere, and NO live server was started** (the live leg is deferred-with-reason, §5). Builds: Mojo 1.0.0 (ed45d567) from the J-071 worktree's installed env, invoked directly with its pixi activation variables exported by hand, `MODULAR_HOME=$CONDA_PREFIX/share/max` per the env's own `10-activate-max.sh`. The shared staging library was compiled fresh for this slice (`thread_par.c` sha256 `88f19b955be000099238f50fb85938745a21b4cccfb4680e41bccb1bfe76cacd`, library sha256 `2082ce3fa09a5db83ce175c596d9f40d42f731c294a629b94b0b8cfd086c28a8` — byte-identical to the J-100…J-105 staging builds, as expected from the identical source). Staging lived in `~/workspace/.verify-tmp/j106stage`, builds in `~/workspace/.verify-tmp/j106build`, TMPDIR redirected to the staging dir throughout. **purplelongship was NOT used at all** — the 204 road's S-104 runner was live there and was yielded to under the coordination law, and this is a VM-light slice by design. Environment incidents (a transient mojo cache-lock hang on one rebuild and the intermittent home-quota EDQUOT wall on another) are recorded in §7; every filed build and run happened after a successful write probe or a clean retry. Nothing was deleted to free disk.

## 5. Deferred leg — the live server leg (DEFERRED-WITH-REASON)

**Statement: the live server leg is DEFERRED-WITH-REASON.** Per §0.6(e), a live leg requires the serve started on a real model with the routes exercised by real requests. This VM has no CUDA device for the resident sessions (`cli/native_serve.mojo`'s Llama 3 / Gemma 4 CUDA sessions), and the VM memory gate (MemAvailable > 5,500 MB) did not hold during the slice — so no live service was started, and none is claimed. What this slice proves instead is everything up to the socket: the audit tables, refusal bodies, parser closures, and formatter accounting unit-proven (7/7, §6); the wiring's composition inspect-proven (which branch consults the audit, branch order, the id prefixes, the status pass-through, §6); and the compilation of `cli/native_serve` whole, through the staging compile driver rebuilt from this tree (§6) — the same evidence shape J-104/J-105 filed for their wiring.

**Exact recipe, to be re-cited at the J-118 Part VII gate:**

1. **Machine and gate:** run on a machine with a working Aesir CUDA serve session (purplelongship's laptop line, after checking the 204 road's state file shows no live run owning that box; or this VM only if a CUDA device is present and MemAvailable > 5,500 MB immediately before the run).
2. **Start:** start the native serve on a small resident model with the API-key file, loopback only, prefix cache at its default (on).
3. **C1 live:** POST `/v1/chat/completions` with both `max_tokens` and a larger `max_completion_tokens`; observe the completion budget follow `max_completion_tokens` (a reply longer than `max_tokens` would have allowed, bounded by the completion budget).
4. **C2 live:** send a chat whose first message has role `developer`; observe it land as system guidance (the reply follows it) rather than a 400.
5. **C3 live:** send the same long-prefix chat twice; observe the second response's `usage.prompt_tokens_details.cached_tokens` > 0 on the Llama 3 profile, and == 0 on the Gemma 4 profile; repeat with `--no-prefix-cache` and observe 0 on both.
6. **C4 live:** GET `/v1/models/{id}` for the resident model and for a catalog model (observe the single model object), and for an unknown id (observe 404).
7. **C5 live:** POST each of `/v1/embeddings`, `/v1/audio/transcriptions`, `/v1/audio/translations`, `/v1/audio/speech`, `/v1/responses`, `/v1/moderations` (observe 501 with the route's reason in Aesir's error shape); GET `/v1/embeddings` (observe 404 — method matters); POST `/v1/files` (observe 404 — the kept families).
8. **C6 + refusal live:** observe `chatcmpl-` ids on chat responses and `cmpl-` on raw completions; POST a chat carrying `logprobs` (observe the 400 refusal) and one carrying `prompt_on` (observe the 400 refusal — T20's fields stay refused until their own wiring slice, §3).
9. **Filing:** file the request/response transcripts and the machine state in the gate doc at J-118, citing this section.

## 6. Tests and inspect

**Unit suites PROVEN (VM, lightest target)** — full output filed in `j106_test_output.txt`, every line from the completion worker's rebuilds on the final tree:

- **`test_openai_audit` — 7/7 groups ALL PASS** (build exit 0, run exit 0): the chat field table (31: 8/4/19, strangers refused); the completion table (19: 8/1/10); the message tables (2/7 fields, 4/6 roles incl. `developer`); the route table (8 served incl. the retrieve pattern, 6 REFUSED_501, the kept families + strangers + wrong-method at KEPT_404); the refusal bodies (501 + route + a real reason per refused route); the parser closures (C1 precedence in both orders and alone, C2 landing as system, and the kept refusals — `logprobs`, `stream_options` — still refusing by name); the usage accounting (C3 on all three formatters, the honest-zero defaults, the over-prompt refusal, the status field's default 0 + carried count).
- **Wiring compilation PROVEN as filed:** a staging driver importing `cli/native_serve` whole (plus the audit module's refusal rule) compiles and runs — `native serve + openai audit modules compile + import: PASS` (this satisfies §0.6(b) directly).
- **Neighbours rebuilt from this tree, all PASS:** `test_local_protocol` (the parser + Gate surface — its main's two filed PASS lines, exit 0, including its Gemma tool-protocol group, which exercises `format_chat_tool_completion` at its pre-C3 arity through the defaulted parameter); `test_server_placement` **17/17** (the T20 layer this slice dispositions, §3 — rebuilt as a second binary after the first rebuild attempt hung, §7); `test_multi_engine` (Gate formatter callers — all 12 sections PASS, exit 0). No other suite sits in the touched files' import graph that the builds showed affected: `core/generation_control.mojo`'s change is a defaulted trailing field (every existing constructor stands — the neighbour builds through the CUDA session modules prove it), and `tests/run_all.mojo` was not run, per the road's standing precedent under the memory gate (§9).

**Inspect:** `j106_inspect.py` is filed alongside this doc with its output in `j106_inspect_output.txt`; its tally is recorded in the campaign state file entry for J-106 (a doc cannot contain the output of a script that reads the doc — the J-105 precedent files the tally the same way, in its §7; here §7 carries the FAIL disposition rule). It re-derives the load-bearing claims from the tree — the audit module's tables equal their extracted surfaces (the parser's honoured field set + the C1/C2 closures; the message roles in the parser; the serve's route branches incl. the retrieve + 501 branches and the C6 id prefixes; the formatters' `prompt_tokens_details`; the status field and the Llama pass-through, with Gemma's file carrying no cached count; the legacy scaffold's non-liveness left alone); the doc's §2 tables equal the module's tables; the test suite's group structure; the filed test output's tallies; and repo hygiene (no README, no `.gguf` in the slice diff, diff == the expected file set). Every FAIL is disposed in §7, never hidden. The live-server claims are **NOT PROVEN** and are named here as such, as §0's honesty classes require; their full list is §9 and their deferred recipe is §5.

## 7. Defects

- **Defects in the inherited diff: none found.** The completion worker re-inspected the original worker's uncommitted diff against §0 first-hand before building: the audit module's tables match §0.2's stated shapes and counts; C1's precedence is applied after the trailing-content check, exactly where §0.5 puts it; C2 aliases `developer` into the same accumulation as `system` and the refusal message names all four roles; C3's parameter is trailing and defaulted on all three formatters (the pre-existing caller in `test_local_protocol` compiles unchanged — the neighbour run proves it), the over-prompt and negative counts are refused, the status field is trailing and defaulted, the Llama pass-through passes the session's own `reused_prompt_tokens`, and Gemma's file is untouched; C4's branch sits after the list route, uses the standing `ollama_model_matches` rule against catalog then resident, and falls to the standing 404; C5's branch sits immediately before the standing 404 `else`, preserves its body, and `local_response` learned the 501 phrase; C6's prefix is chosen per route. No code was changed by the completion worker.
- **One near-miss examined and cleared (recorded so it is not re-litigated):** the serve's retrieve branch tests `"/" not in wanted` but does not itself refuse an empty id (`GET /v1/models/`), where the audit module's `is_model_retrieve` requires a non-empty segment. The outcomes agree — an empty `wanted` matches no catalog or resident name under `ollama_model_matches` (it could only match a model literally named `:latest`), so the branch answers the same standing 404 the audit rules. The difference is cosmetic (which guard states the refusal), not behavioural; no fix was made, and the live recipe (§5 step 6) grades the unknown-id 404 on the wire.
- **Harness incident (completion worker, not a code defect):** the first `test_server_placement` rebuild hung — the mojo driver sat at zero CPU in a futex wait on the shared transform-cache lock for ~11 minutes and was killed; the immediate retry built in 67 s and ran 17/17. The original worker's staging binary for the same suite (built before the stall) also runs 17/17, so the filed claim rests on two builds of the same tree.
- **Environment incident (pre-existing, nothing deleted):** the intermittent home-quota EDQUOT wall (the J-103/J-104 class) bit once during the completion builds — the first `test_multi_engine` build failed inside the mojo transform cache with "Disk quota exceeded", and a write probe failed again minutes later; after a pause the probe passed and the retry built and ran clean (all 12 sections PASS). No filed number rests on a failed attempt.
- **Inspect:** `j106_inspect.py` ran clean at filing (**38/38 PASS**, `j106_inspect_output.txt`); no FAIL is owed a disposal. (Its one interim FAIL — the expected-file-set check on the first, unfiled run, when `j106_inspect_output.txt` did not yet exist — was an artifact of the run order, not the tree: the filed run, whose output is the file itself, passes that check, per the established pattern.)

## 8. Answered-locally records (clean-room)

Every record below was pre-registered in §0 or arose from the tree during the build; no Janas material beyond the road's own filed records (the roadmap text, the J-014 gate note, the J-099 census rows T11–T20, and the Part I census's filed summary of Janas's documented server) was consulted, and no Janas source code was opened.

- **Q: What does `max_completion_tokens` mean on a service with no reasoning channel?** Answered locally (§0.3 C1): Janas's distinction (answer-only `max_tokens` vs reasoning-inclusive `max_completion_tokens`) collapses to the one completion budget Aesir's sessions have; the field is honoured as that budget with the shape's own precedence, and the collapse is recorded here, not silent.
- **Q: Strict refusal-by-name, or the shape's ignore-what-you-don't-know convention?** Answered locally (§0.1/§0.4 K8): Aesir's standing manner is kept. On a bounded, fail-closed parser, silently ignoring a field a client believes was honoured is the worse failure; refusal by name tells the client exactly what this service is.
- **Q: 501 for everything unserved (Janas's documented shape), or a reserved 501 class?** Answered locally (§0.4 K10): the class is reserved for inference-adjacent routes. Aesir has no storage/administration plane at all, so 501 ("not implemented yet") would misdescribe a structural absence; the administrative families stay 404, consciously diverging from the documented shape, re-cited at the J-118 gate.
- **Q: Where does Aesir's timing/context truth live, if not in a `janas`-style usage extension?** Answered locally (§0.4 K13): on Aesir's own native route (`/v1/generate`'s `timings_ms`, `context_used`) and `/health`. No non-standard fields are added to OpenAI-shape responses.
- **Q: Is the error-object divergence (Aesir's `{code, message}` vs the shape's typed object) a defect?** Answered locally (§0.4 K12): no — kept. The serve's no-echo rule is a security manner (T16's family); `type`/`param` fields would either leak request/driver detail or be invented.
- **Q: Should the disconnected `server/api.mojo` scaffold be the audit's surface (it already answers 501)?** Answered locally (§0.1): no. It dispatches nothing live; the audit grades the live serve (`cli/native_serve.mojo`), and the scaffold is left exactly as it stood.

## 9. NOT PROVEN list

- **Live server behaviour on any route** — a real request round trip (C1's budget on the wire, C2's developer turn, C3's `cached_tokens` > 0 on a repeated prefix, C4's retrieve, C5's six 501s and the method/family 404s, C6's prefixes, a refused field's 400) — **NOT PROVEN.** The leg is **DEFERRED-WITH-REASON** with its exact recipe in §5, to be re-cited at the **J-118 Part VII gate**.
- **General JSON-schema holding (T17, K1)** — only the strict Boolean form is held; arbitrary-schema token-by-token holding is **NOT PROVEN** and not built; the engine facade's grammar entry still raises "not implemented" and says so. Re-cited at the J-118 gate.
- **The T20 wiring (§3)** — the J-049 parity layer at the live surface is **NOT PROVEN** (J-049's own record) and stays unwired by this slice's filed why-not; the disposition is re-cited at the J-118 gate.
- **Any model wall, rate, or speed** — no inference ran anywhere in this slice (§4); nothing here is a model-speed claim.
- **The full counted suite (`run_all`) on this tree and the full CLI binary build (`main.mojo`)** — not run (the road's standing precedent under the memory gate; the new suite is standalone by design, §0.5). The serve surface is proven through the compile driver that imports `cli/native_serve` whole, its neighbours, and the inspect.

## 10. Banking

Filed on `yrsa/janas-j106`: the new pure module `aesir_engine/core/openai_audit.mojo`, the wiring in `aesir_engine/server/openai.mojo` (C1/C2 in `OpenAIRequest`, C3/C4 in `OpenAIGate`), `aesir_engine/core/generation_control.mojo` (C3's status field), `aesir_engine/core/llama3_cuda.mojo` (C3's pass-through), and `aesir_engine/cli/native_serve.mojo` (C3's formatter arguments, C4's retrieve branch, C5's 501 branch + phrase, C6's id prefixes), `aesir_engine/tests/test_openai_audit.mojo` (new), and under `aesir_engine/docs/janas/`: this doc, `j106_inspect.py`, `j106_inspect_output.txt`, `j106_test_output.txt`. Protocol committed first (§0, `feaae2ac`, before any code). **Campaign copies:** sha-identical copies of this doc, the inspect script + its output, and the test output are filed in `~/workspace/model-tests/janas/` (`J106_OPENAI_SHAPE_AUDIT.md`, `j106_inspect.py`, `j106_inspect_output.txt`, `j106_test_output.txt`). Push by explicit refspec (foreground git only) with `git ls-remote` verification that the branch moved, `yrsa/janas-j105` stayed at `fde78060`, and origin/main stayed at the observed `4ca75cc2` (this slice does not touch main); the commit hashes and ls-remote lines are recorded in the campaign state file entry for J-106 (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker. Nothing deleted.
