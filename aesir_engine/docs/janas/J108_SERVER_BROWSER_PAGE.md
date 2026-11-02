# J-108 — Server: The Browser Page

**Slice:** J-108 (Part VII — The Tool Family, J-099–J-118), Project Aesir Janas clean-room road.
**Roadmap text:** "Server: the browser page. A minimal try-it chat page served by the server itself (Janas ships one); built under the Cyber-Viking design law, no framework weight, the page is a tool not a product."
**Owns (J-099 census):** row **T15** (server — served browser chat page: ABSENT at the census, "No `text/html` anywhere in `cli/` or `server/`; the server serves no page"), with the Origin exception J-099 §3 pre-registered for this slice: "J-108 (browser page): T15 — the minimal served try-it page (**its Origin exception lands with T16's discipline**)." T16 is the security-manners row (Host checked, Bearer constant-time in native mode, Origin/Referer/Sec-Fetch-Site refused 403, loopback IPv4 only); J-106 K9 kept TLS absent on exactly that discipline.
**Builds on:** J-106's audit (`core/openai_audit.mojo`: the served/refused/kept route tables — 8 served at the base — and the field tables the page must honour: chat 31 fields 8/5/18 after J-107, completions 19 fields 8/2/9; roles system/developer/user/assistant honoured) and J-107's stream protocol (`core/stream_progress.mojo`: SSE framing, the `prefill_progress` extension event, the `stream_options.include_usage` usage chunk, `[DONE]` last).
**Base:** branch `yrsa/janas-j108` in fresh worktree `~/workspace/aesir-janas-j108` (sparse: `aesir_engine` + `hailbru`), from `yrsa/janas-j107` tip `68c78d6c2cde4c42ba575e153e3049edb7aed940` (ls-remote verified at slice start: remote `yrsa/janas-j108` absent — the duplicate guard; remote `yrsa/janas-j107` == that hash; origin/main observed at `4ca75cc237de872a7e69777872ec1077f9e93e92`, not rebased onto, not touched).
**Clean-room record:** no Janas material was consulted in this slice beyond the road's own already-filed clean-room records — the roadmap text, the J-099 census rows T15/T16, the J-106 audit doc, and the J-107 doc. The Janas documentation states only that its server ships a browser chat page; it does not specify the page's internals, route, or behaviour, so every such question here is answered from Aesir's own architecture and recorded as answered-locally in §8. No Janas source code was opened, in this slice or any other.

---

## 0. Protocol (committed first, before any code was built)

This section was committed before the page layer, the head-layer exception, the serve wiring, or any test existed. It states what the inspection found, the page and its security shape as decision rules, the closures this slice takes, the leg it consciously does not take, and the verdict rule for the slice; everything after §0 is filed under these rules and no others.

### 0.1 What exists, and the exact delta (re-verified first-hand in this tree at the base tip)

- **No page exists (T15, re-verified).** A tree search finds no `text/html` in `aesir_engine/`; `cli/native_serve.mojo`'s `serve_loaded` dispatch answers JSON on every route. `GET /` falls through J-106's route table to the standing 404 (`route_verdict` returns KEPT_404 for it).
- **The serve can already send a page-shaped response.** `local_response(code, body, ollama, content_type, preserve_body)` in `cli/native_serve.mojo` passes a caller-chosen content type through on a 200 and always adds `Cache-Control: no-store` + `X-Content-Type-Options: nosniff`. The smallest honest serving shape is therefore one new dispatch branch in `serve_loaded` setting `status = 200`, `body = <page>`, `content_type = "text/html; charset=utf-8"` — no new transport, no static-file machinery, no restructuring.
- **The head layer makes a browser page impossible as it stands (the slice's real delta).** `server/local_protocol.mojo`'s `LocalHTTPHead` (a) sets status 403 whenever an `Origin`, `Referer`, or `Sec-Fetch-Site` header is present, at any value (T16's manner: the surface was built for non-browser clients, which send none of these), and (b) in native mode sets 401 unless the request carries the exact constant-time Bearer key. Real browsers send `Sec-Fetch-Site` on navigations and fetches, `Origin` on POST fetches, and `Referer` on both — and a browser navigation cannot present an `Authorization` header at all. So under the standing rules a browser could neither load a page from this server nor call its API from that page, in **either** mode (the Ollama mode drops only the Bearer rule, not the browser-header rule). J-099 §3 foresaw exactly this and assigned the exception to this slice under T16's discipline (§0.2).
- **The API the page may call, exactly (J-106 as amended by J-107).** `POST /v1/chat/completions` with `model`, `messages` (roles system/developer/user/assistant; the final message must be user), `stream`, `stream_options.include_usage`, `max_tokens`/`max_completion_tokens`, and the sampling fields — everything else is refused by name and the page must not send it. The streamed form (J-107) is SSE: an optional role chunk, `prefill_progress` extension events (`data: {"event":"prefill_progress",...}`), content chunks (`choices[0].delta.content`), an optional usage chunk (empty `choices`, caller-observed counts) when `include_usage` was set, then `data: [DONE]`; a failure after the stream starts arrives as `data: {"error":{"message":...,"type":...}}`, and a failure before it as the standing `{error:{code,message}}` JSON with its HTTP status. `GET /v1/models` lists the loaded/catalogued model names. Errors and refusals are shown to the operator plainly, never hidden or retried silently.
- **No model name may be baked into the page.** The page is a compile-time constant string: it carries no model name, no key, no user data. It learns the model from `GET /v1/models` at runtime and keeps the conversation only in page memory.

### 0.2 The T16 exception (narrow, pre-registered here, in T16's own discipline)

The exception changes **which values** of the browser headers are refused, never **whether** cross-site requests are refused:

- **Origin:** refused 403 iff present and not exactly the serving origin — `http://127.0.0.1:<port>` or `http://localhost:<port>` for the port this service listens on. (A page served from this origin sends exactly that value on its fetches; any other site's origin — including another loopback port — is refused exactly as before.)
- **Referer:** refused 403 iff present and not the serving origin itself and not under it (origin + `/...`). The page's own fetches refer from the page's URL, which is the serving origin + `/`.
- **Sec-Fetch-Site:** refused 403 iff present and not `same-origin` or `none`. (A fetch from the served page states `same-origin`; a direct navigation states `none`; another loopback port's page states `same-site` and stays refused.)
- **The page document's own authentication:** a browser navigation cannot present a Bearer header, so `GET /` — and only that exact method+path — does not require the Bearer key in native mode. The page is a compile-time constant containing no model data, no key, and no user data; the Host check (the DNS-rebinding guard) still applies to it; every data route keeps the Bearer rule unchanged, and the page's API calls present the key the operator types into the page (held in page memory only, sent only to this origin's API, never stored). This is recorded here as a conscious, narrow decision, flagged in the worker record for the keeper's review; if it is ever judged wrong, the revert is the single condition in `LocalHTTPHead` — the page then still loads in the no-auth Ollama mode, and native mode loses browser access, which is the honest price statement.
- Headers absent (every non-browser client) are unaffected, byte for byte. Cross-site values are refused exactly as before. No CORS header is added anywhere: a cross-origin script still cannot read any response from this service.

The three value rules live as pure functions in the page layer (§0.3) so the head layer executes tested decisions instead of growing its own string logic.

### 0.3 The page layer (the pure layer)

A new pure module, **`aesir_engine/core/browser_page.mojo`**, following the road's established shape (pure logic, unit-tested at the lightest target; hosts execute the decisions; no socket or session lives here):

- **The route:** `is_browser_page_request(method, path)` — true iff `GET` + `/` exactly (answered-locally, §8: `/` is the page's route; no second alias is served).
- **The document:** `browser_page_html()` — the whole page as one string (§0.4's contract), and `browser_page_content_type()` — `text/html; charset=utf-8`.
- **The origin discipline:** `browser_origin_allowed(origin, port)`, `browser_referer_allowed(referer, port)`, `browser_fetch_site_allowed(value)` — §0.2's three rules, each decidable from the header value and the serving port alone.

### 0.4 The page contract (Cyber-Viking design law, made measurable)

The standing design law, applied to a tool page: the page is a tool, not a product — the primary task (type a message, send it, read the answer) must be obvious in ~3 s; no generic app with runes pasted on (this page carries **no runes and no ornament at all** — the deliberate, recorded choice: ornament would have no measurable job here); every themed element needs a measurable job (the single accent colour's job is to mark the one primary action, Send); coherent in grayscale (status is always words, never colour alone); usable at 125–200 % text scaling (fluid layout, no fixed-height clipping); body text in the 14–18 px band (16 px); controls ≥ 44 × 44 px targets. Concretely, and testably:

- **Self-contained:** one HTML document, inline `<style>` and inline `<script>`, **zero external references** — no `http://` or `https://` string anywhere in the document, no CDN, no webfont, no image; the favicon is an empty `data:,` URI so the browser does not even fetch one. **Size bound: the whole document ≤ 24,576 bytes** — "no framework weight" as a number.
- **Calls only the audited shape (§0.1):** `GET /v1/models` to name the model (a plain text input holds the result, editable, so a failed list call degrades to typing the name, with the failure shown); `POST /v1/chat/completions` with `model` + `messages` (the conversation held in page memory: user/assistant turns, final turn user) + `stream`; when streaming, `stream_options: {"include_usage": true}` so a usage chunk, if it arrives, can be shown as counts. Nothing else is sent.
- **Streaming handled as J-107 filed it:** SSE `data:` lines parsed incrementally; `prefill_progress` events update the status line in words ("Reading the prompt: 42%"); `delta.content` appends to the answer; the usage chunk renders its caller-observed counts as one plain line; `[DONE]` ends the turn; a streamed `error` event and a pre-stream HTTP error both land in the status line verbatim (`Error: <server message>`), never swallowed.
- **Honest states, in words:** the status line always states the page's state as text (`Ready`, `Sending…`, `Reading the prompt: N%`, `Error: …`, `Done — prompt X tokens, completion Y tokens` when usage was observed; no invented counts when none arrived).
- **Safety by construction:** transcript and answer text are inserted with `textContent` only — the document contains no `innerHTML` at all — so neither the operator's text nor the model's can become markup.
- **Controls:** a labelled message box, a labelled API-key field (password type; native mode's key; unused in Ollama mode, where the field may be left empty — a 401 answer is shown plainly with the hint to paste the key), a Stream checkbox (default on), a Send button (the one accent-coloured control, ≥ 44 px), a Clear button (empties the in-page transcript and history; sends nothing). Every input has a `<label>`; the transcript region is `aria-live="polite"`.

### 0.5 The closures (each closed in scope, wired, and tested)

- **P1 — the page layer.** §0.3's module: the document, the route predicate, the content type, the three origin rules.
- **P2 — the head exception.** `server/local_protocol.mojo`'s `LocalHTTPHead` executes §0.2: the three browser-header checks call the layer's rules with the serving port; the Bearer check skips exactly the page request (via the layer's predicate). No other head behaviour changes (Host, length, content-type, method, framing rules untouched).
- **P3 — the serve wiring.** `cli/native_serve.mojo`'s `serve_loaded` gains one branch — `GET /` → 200 + `browser_page_html()` + the HTML content type — served in both modes (the chat route it calls exists in both), placed with the other GET routes before the 501/404 fallthrough; the serve's host-contract comment block gains the page paragraph with §0.2's honesty note kept in the tree.
- **P4 — the audit flip.** J-106's route table gains the page: `served_route_names()` gains `GET /` (8 → **9 served**; refused 6 and kept families 8 unchanged), the module header gains the J-108 evolution note, and J-106's suite is updated only for the route-table expectations (count + the `GET /` verdict), as J-107 updated it for its flip.

### 0.6 Verdict rule for this slice (pre-registered)

The slice **passes** iff all of the following hold, each filed:

(a) **Page layer:** `test_browser_page` PASSes at the lightest target: the route predicate (exact `GET /` only — wrong method, `/chat`, `//`, `/index.html` all false); the content type; the document invariants (doctype first, inline style + script, **zero** `http://`/`https://` substrings, no `innerHTML`, `textContent` used, the audited endpoints and the J-107 stream vocabulary present — `/v1/models`, `/v1/chat/completions`, `prefill_progress`, `[DONE]`, `include_usage` — the design-law numbers present: 16 px body text, a ≥ 44 px control rule, labelled inputs, `aria-live`); the size bound (≤ 24,576 bytes, and > 2,048 so the check is not vacuous); the origin rules (the serving origin in both spellings allowed at the serving port; the same spelling at another port refused; any other origin refused; referer at/under the origin allowed, elsewhere refused; fetch-site `same-origin`/`none` allowed, `same-site`/`cross-site` refused).
(b) **Head exception:** `test_local_protocol`, extended only with this slice's cases, PASSes: cross-site Origin/Referer/Sec-Fetch-Site still 403; same-origin browser headers on an authenticated API POST still 200; `GET /` without a key in native mode 200 while `GET /health` without a key stays 401; the page via a cross-site fetch-site value still 403.
(c) **Audit flip:** `GET /` is SERVED in the route table, the served count is 9, and `test_openai_audit` — updated only for the route-table expectations — PASSes at its other filed counts unchanged (chat 8/5/18, completions 8/2/9 after J-107).
(d) **Wiring compilation:** a staging driver importing `cli/native_serve` whole compiles and runs (the J-105/J-106/J-107 precedent for serve-surface wiring).
(e) **Inspect:** `docs/janas/j108_inspect.py` re-derives the load-bearing claims and PASSes: the layer's rules and document invariants against the tree; the head exception's narrowness (the three rule calls + the single page predicate in the Bearer condition); the serve branch (route, content type, placement before the fallthrough); the audit flip; the doc's tallies against the module; the test output's tallies; repo hygiene (no README, no `.gguf` in the slice diff, diff == the expected file set). Every FAIL is disposed in the doc, never hidden.
(f) **The live browser leg is not part of the pass rule:** no CUDA device exists on this VM and the VM memory gate (MemAvailable > 5,500 MB) bars inference — a live leg (the serve started on a real model; the page loaded in a real browser over loopback in both modes; a message sent non-streamed and streamed; a ≥ 1,024-token prompt's progress reaching the status line; the 401-without-key state shown plainly in native mode; a cross-site Origin probe still 403) is filed DEFERRED-WITH-REASON with its exact recipe in §5, re-cited at the **J-118 Part VII gate**.

**Honesty classes.** The page document's invariants, the route predicate, and the origin rules are **PROVEN** by the unit suite where it passes. The head exception's and the serve branch's composition are **PROVEN (inspection sense)** from the tree plus the compile driver's whole-module compilation and the head suite's status cases. Any real browser's behaviour against the live serve — page rendering, fetch/SSE handling in a browser engine, the live 401 flow — is **NOT PROVEN** by this slice and is named in §9.

**No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk.**

*(§§1–10 are filed below from the build, under this protocol.)*

## 1. Headline

**The server now serves its own try-it chat page.** `GET /` answers one self-contained HTML document (**9,576 bytes**, inline style and script, zero external references, no framework) from a new pure layer, `core/browser_page.mojo`, wired as a single branch in `serve_loaded` in both modes. The page calls only the J-106-audited shape — `GET /v1/models` to name the model, `POST /v1/chat/completions` with `model`/`messages`/`stream` (plus `stream_options.include_usage` when streaming) — and speaks J-107's stream vocabulary: `prefill_progress` events land in the status line as words, streamed errors and pre-stream HTTP errors are shown verbatim, and a usage chunk renders as plain counts. The slice's real delta is the one J-099 pre-registered: the head layer's browser-header refusal (T16) now refuses **by value** through the page layer's origin rules — exactly the serving origin passes, cross-site values stay 403 — and the Bearer rule exempts exactly the page document (a browser navigation cannot present a key; the page is a constant with no secrets; every data route keeps the rule). J-106's audit gains the page: **9 served** routes (field tables unmoved). **Unit suites: `test_browser_page` 8/8 groups PASS; neighbours `test_openai_audit` 7/7 (flipped route table), `test_local_protocol` PASS (extended only with this slice's head cases); the native-serve compile driver PASS; inspect filed in §6.** The **live browser leg is DEFERRED-WITH-REASON** (no CUDA device on this VM; MemAvailable below the 5,500 MB gate throughout; purplelongship yielded to the 204 road's S-104), re-cited at the **J-118 Part VII gate**. No README touched. Hailo untouched/parked. No Docker.

## 2. The diff this slice closes (J-099 row T15 + the T16 exception)

| Item | Before J-108 | After J-108 |
|---|---|---|
| Served browser page (T15) | ABSENT — no `text/html` anywhere; `GET /` falls through to the standing 404 | `GET /` → 200 + the page document as `text/html; charset=utf-8`, both modes; J-106's route table: **9 served** |
| The page document | — | One constant string in `core/browser_page.mojo`: 9,576 bytes, inline style + script, zero external references (no `http://`/`https://` substring), empty `data:,` favicon, no model name/key/user data baked in |
| What the page calls | — | Only the audited shape: `GET /v1/models`; `POST /v1/chat/completions` (`model`, `messages`, `stream`; `stream_options.include_usage` when streaming). Refusals/errors shown verbatim |
| Stream handling on the page | — | J-107's vocabulary: progress events → status words; `delta.content` appended; usage chunk → counts line; `[DONE]` ends; streamed `error` events shown |
| Origin / Referer / Sec-Fetch-Site (T16) | Any value → 403 (no browser could load or use any page, in either mode) | Refused **by value** via the page layer's rules: Origin exactly the serving origin; Referer at/under it; Sec-Fetch-Site `same-origin`/`none`. Cross-site — incl. another loopback port (`same-site`) — stays 403; absent headers unaffected; no CORS header added |
| Bearer rule, native mode | Every request, incl. any page navigation (which cannot present one) | Unchanged for every data route; `GET /` — the constant page document only — is exempt (Host check still applies). The page's API calls present the operator's typed key |
| Transcript safety | — | `textContent` only; the document contains no `innerHTML` at all |

## 3. What was built

- **`aesir_engine/core/browser_page.mojo`** (new): `is_browser_page_request(method, path)` (GET + `/` exactly); `browser_page_html()` (the whole document as one constant — its text carries no backslash anywhere, so the literal is byte-for-byte what is served); `browser_page_content_type()`; the origin discipline `browser_origin_allowed` / `browser_referer_allowed` / `browser_fetch_site_allowed` (the serving origin in both loopback spellings, at the serving port). The header carries the contract, the design-law numbers, and the host contract.
- **`aesir_engine/server/local_protocol.mojo`**: `LocalHTTPHead` imports and executes the layer's rules — the three browser-header branches decide by value with the serving port; the Bearer condition skips exactly `is_browser_page_request(...)`. Host, length, content-type, method, and framing rules untouched.
- **`aesir_engine/cli/native_serve.mojo`**: one dispatch branch (`GET /` → 200 + document + HTML content type) placed with the GET routes before the 501/404 fallthrough, served in both modes; the host-contract comment block gains the page paragraph with §0.2's reasoning kept in the tree.
- **`aesir_engine/core/openai_audit.mojo`**: `GET /` joins `served_route_names()` (9 served); the header gains the J-108 evolution note. Field tables untouched.
- **The page itself** (in the layer): header + status line (`role="status"`, always words) + transcript (`aria-live="polite"`); labelled Model / API key (password) / Message fields; Send (the one accent-coloured control), Load models, Clear; Stream checkbox default on. Loads the model list on open and on demand, degrading to a typed name with the refusal shown. Conversation held in page memory as user/assistant turns; an errored turn is removed from the history it sends (it received no answer) while staying visible in the transcript beside the error. Clear empties page state and sends nothing.
- **`aesir_engine/tests/test_browser_page.mojo`** (new): 8 groups (§6). **`aesir_engine/tests/test_openai_audit.mojo`**: updated only for the route-table flip (count 9, the `GET /` verdict, header note). **`aesir_engine/tests/test_local_protocol.mojo`**: `test_local_http` extended only with the §0.6(b) head cases.

## 4. Per-surface state after this slice

| Surface | Page | Browser headers | Bearer (native mode) | Live state |
|---|---|---|---|---|
| `GET /` | 200, the document, `text/html; charset=utf-8`, both modes | Same-origin values pass; cross-site 403 | Exempt (the document only; Host still checked) | Wiring compile-proven; live NOT PROVEN (§5) |
| `POST /v1/chat/completions` (+ all data routes) | — (JSON, as before) | Same rule by value — the page's fetches pass, cross-site stays 403 | Required, unchanged | Unchanged |
| Non-browser clients (curl, SDKs) | — | Send none of the three headers: unaffected, byte for byte | Unchanged | Unchanged |
| Cross-origin web pages | Cannot read any response (no CORS header added); their API calls 403 on the header rules before auth is even judged | Refused | — | By construction |

## 5. Deferred — the live browser leg (DEFERRED-WITH-REASON, exact recipe)

**Why deferred:** VM MemAvailable ~3.2–3.6 GB at build time (gate: 5,500 MB) and no CUDA device on the VM, so no live serve can run here; purplelongship was not used at all (the 204 road's S-104 was live there; yielded under the coordination law). A page's real test is a browser engine's behaviour — fetch, SSE reading, rendering — which no unit suite here can supply.

**Exact recipe** (device-capable worker, purplelongship quiet window; re-cited at the **J-118 Part VII gate**):

1. **Gate checks first:** read the 204 heartbeat (`~/workspace/model-tests/ROADMAP_204_STATE.md`), confirm no live run and the box reachable; record loadavg, Tctl, MemAvailable, GPU idle (VRAM ~1 MiB) at start/end. One heavy run at a time. Fetch `yrsa/janas-j108` on-box; verify the tree against the banked tip.
2. **Raw probes (curl, before any browser):** `GET /` → 200 + `text/html; charset=utf-8` + the document byte-identical to `browser_page_html()`; `GET /` with `Origin: http://127.0.0.1:9999` → 403; an authenticated API POST with `Origin: http://example.com` → 403 and with the serving Origin → its normal answer; in native mode `GET /health` without the key → 401 while `GET /` without it → 200.
3. **Browser leg (a real browser on the box, both modes):** open the page; the model list loads (Ollama mode unauthenticated; native mode after pasting the key, with the pre-key 401 shown plainly first); send one message non-streamed and one streamed; with a ≥ 1,024-token prompt the status line shows the read's progress in words before the answer completes; the streamed turn's usage line matches the non-streamed twin's counts. **Ids first:** both turns' generated ids vs the same requests made by curl, token for token — any divergence is a page/wiring defect, never a number to file quietly; then teacher-forcing rank + logit gap against the ggml **CPU** comparator on the raw prompt (never `llama-cli --single-turn`).
4. **Design-law spot checks at the same sitting:** the page at 200 % text scaling (no clipped controls, primary task still obvious), in a grayscale screenshot (status readable as words), and with the network panel confirming zero external requests.
5. **Filing:** results in an addendum on the measuring slice's branch, machine state per run, captures filed beside it; `test_browser_page` registration in `tests/run_all.mojo` with the counted-run pin re-accounted in the same leg (J-031 §10 pattern). J-117's web-page example rides this page — its live proof is this recipe's step 3, re-cited there.

## 6. Evidence

Filed in full in `docs/janas/j108_test_output.txt` (VM, lightest target; staging builds byte-identical to the road's: `libaesir_par.so` sha256 `2082ce3f…` from the pinned `thread_par.c`):

- **`test_browser_page` — 8/8 groups PASS:** route predicate; content type; document shape; document calls (only the audited shape, J-107 vocabulary); document hygiene (zero external references, `textContent` only, no backslash); design law (16 px text, 44 px targets, labels, status region); size bound (actual **9,576** bytes, inside 2,048 < n ≤ 24,576); origin discipline (both spellings at the serving port allowed; other ports, https spelling, foreign origins, lookalike referers, `same-site`/`cross-site` refused).
- **`test_openai_audit` — 7/7 PASS** at the flipped route table (9 served incl. page + retrieve; field tables unchanged at chat 8/5/18, completions 8/2/9).
- **`test_local_protocol` — PASS** (both filed sections; the HTTP group now includes the J-108 cases: page without key 200, `/health` without key still 401, POST `/` without key still 401, direct navigation 200, cross-site navigation/Origin/Referer/fetch-site 403, same-origin browser API call 200).
- **Native-serve compile driver — PASS** (`cli/native_serve` imported whole: the page branch, the audit import, and the head-layer import chain all compile together).
- **Inspect — `docs/janas/j108_inspect.py`:** re-derives the layer's rules, extracts the document from its literal and re-checks every invariant against the extracted bytes (incl. the extracted size matching the filed test output), the head exception's narrowness, the serve branch's placement before the fallthrough, the audit flip, the doc/suite/output tallies, and repo hygiene (diff == the expected 11-file set). Its tally is filed in `j108_inspect_output.txt`.
- **Not rebuilt, named:** `test_stream_progress`, `test_prompt_progress` (no exercised file changed), `test_multi_engine` (its surface untouched — the J-107 precedent names it the same way).

## 7. Environment

- /tmp stood at 100 % full (pre-existing) for the whole slice; nothing was deleted. `TMPDIR` was redirected to `~/workspace/.verify-tmp/j108stage` throughout; staging and builds live under `~/workspace/.verify-tmp/j108{stage,build}`.
- The intermittent Errno 122 write wall did not appear in this slice: the worktree add, the sparse checkout, all commits, and all builds completed without a retry.
- VM MemAvailable ~3.5 GB at dispatch, ~3.2–3.6 GB during the builds — below the 5,500 MB inference gate throughout; lightest compiles and pure-logic runs only, one at a time. No inference, no live server, no browser driven.
- purplelongship not used at all: the 204 road's S-104 was live there at dispatch (its 03:32 EST heartbeat) and the slice needed no heavy run by design.
- A `git fetch origin` in this campaign can report a pre-existing stray-ref error (`bad object refs/heads/yrsa/c4.txt`, recorded at J-106/J-107); pushes and ls-remote are unaffected. This slice did not fetch and did not touch the ref (shared-repo write, outside scope).

## 8. Answered-locally (the clean-room record)

Janas's public documentation states only that its server ships a browser chat page; it does not document the page's route, contents, or protocol. Every such question was answered from Aesir's own architecture, and is recorded here:

- **Q: At which route does the page live?** `GET /` — the serve's root, the address an operator types. No alias is served (`/chat`, `/index.html` stay strangers): one route, one document, nothing to drift.
- **Q: Which API does the page use — the native `/v1/generate`, the Ollama routes, or the OpenAI routes?** The OpenAI chat route: it is the audited surface (J-106), exists in both modes, and carries J-107's streaming progress + usage the page wants to show. The page sends only fields the audit honours.
- **Q: How does the page authenticate in native mode?** The operator pastes the service key into the page; it is held in page memory only and sent as the Bearer header on API calls. The page document itself is exempt from the Bearer rule (§0.2) — the recorded price: anyone who can reach the loopback port can fetch a constant document that contains no secrets; the Host check still binds it to the loopback names.
- **Q: Does the page need its own progress protocol?** No — J-107 already filed one; the page consumes `prefill_progress` events and the usage chunk exactly as served, and renders them as words and counts, inventing neither.
- **Q: Ornament — runes, glow, ceremony?** None. The Cyber-Viking law's Prime Directive (every themed element needs a measurable job; cut ornament before touching information architecture) leaves a tool page with exactly one themed decision: a single accent colour whose job is to mark the one primary action (and the focus outline, so keyboard position is visible). The page must stay coherent in grayscale, and it does — status is words, roles are labels, the accent is never the only signal.

## 9. NOT PROVEN

- **Any live behaviour:** no live server was started and no browser was driven in this slice. The page's rendering, its fetch/SSE handling in a real browser engine, the live 401-then-key flow, and any generated text through the page are NOT PROVEN; §5's recipe is the proof path, re-cited at the J-118 gate.
- **Browser variance:** the head rules were graded against the header values the protocol names (`same-origin`/`none`, the two origin spellings). A specific browser's exact header set on every navigation class (prerender, restore, translation proxies) was not measured; the rules refuse unknown values, so an unlisted value degrades to a plain 403 the operator can see, never to a silent allowance.
- **The page against a second model/profile:** the document is model-agnostic by construction (names come from `/v1/models`), but no second profile's list or stream was exercised — the live leg's step 3 grades the wave profiles it names.
- **J-117's web-page example** rides this page but is not built here; its execution proof is §5 step 3, owned by J-117/the gate.

## 10. Files

New: `aesir_engine/core/browser_page.mojo`, `aesir_engine/tests/test_browser_page.mojo`, `aesir_engine/docs/janas/J108_SERVER_BROWSER_PAGE.md`, `aesir_engine/docs/janas/j108_inspect.py`, `aesir_engine/docs/janas/j108_inspect_output.txt`, `aesir_engine/docs/janas/j108_test_output.txt`. Edited: `aesir_engine/server/local_protocol.mojo` (the head exception), `aesir_engine/cli/native_serve.mojo` (the page branch + host-contract comment), `aesir_engine/core/openai_audit.mojo` (the route flip + evolution note), `aesir_engine/tests/test_openai_audit.mojo` (route-table expectations only), `aesir_engine/tests/test_local_protocol.mojo` (the J-108 head cases only). Campaign copies of the doc, inspect script, and both outputs are filed sha-identical in `~/workspace/model-tests/janas/`. No README touched. Hailo untouched/parked.

