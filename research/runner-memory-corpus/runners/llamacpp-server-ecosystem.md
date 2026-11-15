# OR-2 — The llama.cpp Server Ecosystem: The Constellation Around llama-server

| Field | Value |
|---|---|
| Scope | The server frontends, proxies, routers and packaged distributions that grew around `llama-server` and the ggml core — **not** llama.cpp / ggml themselves |
| Companion dossier | `llamacpp-ggml.md` in this same `runners/` folder — the core engine, GGUF, quantisation, backends, and the slots / KV-cache internals in depth. This dossier points inward to it and does not repeat it. |
| Centrepieces | `llama-server` (ggml-org/llama.cpp, `tools/server/`), llama-swap (`mostlygeek/llama-swap`), LocalAI (`mudler/LocalAI`) |
| Also surveyed | text-generation-webui / TextGen (`oobabooga/textgen`, formerly `text-generation-webui`) at public-fact level; Open WebUI's llama.cpp connection as a consumer example; the official and community packaging channels |
| Licences (verified, see §1.3) | llama.cpp / llama-server: **MIT** · llama-swap: **MIT** · LocalAI: **MIT** (brand assets excluded) · TextGen: **AGPL-3.0** (secondary sources, see note) |
| Dossier date | As of **2026-11-15** |
| Sources accessed | 2026-11-15 (see §8 for the full list with dates) |
| Clean-room note | This dossier describes architecture, behaviour and design ideas in our own words. No source code is reproduced and no documentation text is copied beyond short factual labels: endpoint paths, flag names, config keys and project names. |

**Essence.** For most people, llama.cpp is never experienced as a library or a command-line completion tool. It is experienced as an HTTP endpoint someone else wrapped around it. `llama-server` itself set the pattern — a dependency-light C/C++ HTTP server, a native API that exposes the engine honestly, and an OpenAI-compatible surface that is deliberately “good enough” rather than claimed-perfect — and then the ecosystem did the rest of the product work the core refused to do: llama-swap added multi-model swapping behind one port without touching inference at all, LocalAI absorbed *every* modality and *every* major backend behind one API, chat frontends such as text-generation-webui and Open WebUI turned the server into a consumer product, and packagers turned a CMake build into a Homebrew formula, a Winget package, a container image and a one-line installer. The shape is the lesson. llama.cpp stayed an engine because a constellation was allowed — and able — to form around a stable, permissively licensed, single-binary server surface. Ollama made the opposite bet, absorbing model management, registry, API translation and serving into one product. Neither bet is free. This dossier maps what each layer actually adds, what it costs, and where a new Go runner should draw its own boundary.

---

## 1. Scope, method and licence verification

### 1.1 What is in and what is out

**In scope:**

- `llama-server` as a *server surface*: its API families, its operating modes, its management endpoints, and its limits — not its inference internals.
- The built-in **router mode** for multiple models, as documented in the current `tools/server/README.md` (accessed 2026-11-15).
- The **proxy / supervision layer**, with llama-swap as the type specimen.
- **LocalAI** as the maximalist pole: one API over many backends and many modalities, substantially built — historically and still — on llama.cpp-family backends.
- The **long tail at pattern level**: frontends that embed or drive `llama-server`, one-click and container distributions, and OS packaging. This is a pattern survey, not a catalogue; no attempt is made to enumerate every fork, GUI or Docker image.
- What the ecosystem's shape teaches a Go runner about where to stop.

**Out of scope (covered elsewhere in the corpus):**

- ggml graph execution, quantisation formats, backend kernels, sampler chains and KV-cache design — see the companion llama.cpp / ggml dossier.
- Ollama, LM Studio, vLLM, SGLang and the other runners as products in their own right — each has its own dossier. They appear here only as contrasts or as backends / consumers inside this ecosystem.
- Benchmarks. No performance claim in this dossier comes from our own measurement; where a source gives a number (ports, defaults, gallery counts) it is cited as a documented fact, not a benchmark.

### 1.2 Method

Primary sources were read directly on 2026-11-15: the current `llama-server` README in `ggml-org/llama.cpp` (`tools/server/README.md`, ~4,350 lines in the rendered view), the GitHub repository pages and READMEs for llama-swap and LocalAI, and the Hugging Face announcement of router-mode model management (published 2025-12-11). Secondary sources — DeepWiki code summaries, independent setup guides and comparisons — were used only to cross-check, to date features, and for the long-tail pattern survey, and are marked as secondary in §8. Star counts, release counts and version numbers below are the values shown on the repository pages at access time; they move daily and should be re-checked before being quoted elsewhere.

A note on dates that matters for §2.4: in this corpus's timeline, router mode is **not** brand-new at the dossier date. It was announced in December 2025, roughly eleven months before 2026-11-15, and by the access date it is documented at length in the main server README — with presets, memory-aware unloading, model download / deletion endpoints and a server-sent-events channel. Treat it as a settled, documented feature of current `llama-server`, not a preview. Flag names and preset semantics should still be re-verified with `--help` on the exact build in hand, because llama.cpp ships continuously.

### 1.3 Licences — verified per piece

| Piece | Licence | How verified (2026-11-15) |
|---|---|---|
| llama.cpp, including `llama-server` | MIT | Companion dossier verified both ggml-org repo sidebars and LICENSE files; consistent across every secondary source read for this dossier. |
| llama-swap | MIT | GitHub repository header for `mostlygeek/llama-swap` read directly: “License: MIT License (MIT)”; the GitHub API licence object in search results agrees (`spdx_id: MIT`). |
| LocalAI | MIT, with a brand carve-out | GitHub repository header for `mudler/LocalAI` read directly: “License: MIT License (MIT)”. Its README states the LocalAI name, logo and mascot art are *not* covered by the MIT licence and are governed by a separate brand-usage file. The code licence and the brand licence must not be conflated. Downloaded *models* and *backends* carry their own licences. |
| text-generation-webui / TextGen | AGPL-3.0 | **Secondary-verified only in this pass.** Multiple independent 2026 reviews and licence guides consistently report AGPL-3.0 for `oobabooga/textgen` (formerly `text-generation-webui`). The primary GitHub licence header was not re-opened in this pass, so treat the fact as high-confidence but marked accordingly. The distinction matters: unlike the MIT pieces above, AGPL network-copyleft is a real constraint for anyone hosting a modified version as a service. |
| Open WebUI (mentioned as a consumer) | Not verified in this pass | Named only for its documented llama.cpp connection behaviour. No licence claim is made for it here. |

The pattern is itself a finding: the three load-bearing pieces of this ecosystem are all MIT. That is not an accident of taste — it is why commercial products, competing frontends and hostile forks can all legally wrap the same server without negotiation. See §6.

---

## 2. llama-server itself: the server surface

`llama-server` is a small, pure C/C++ HTTP server built, per its own README header, on cpp-httplib and nlohmann/json, sitting directly on llama.cpp. It serves a built-in web UI on the same port as its APIs. It binds `127.0.0.1` by default (`--host`); exposing it beyond localhost is an explicit operator choice (`--host 0.0.0.0`, `--api-key`, optional TLS via `--ssl-key-file` / `--ssl-cert-file`). The README's examples are inconsistent about port — the API reference sections use `9931` in their curl examples while Docker and quick-start examples use `8080` — so the honest statement is: the port is whatever `--port` says, and any client integration must not hard-code either number. That inconsistency is worth noting because ecosystem tools *did* hard-code assumptions, and §3's proxies exist partly to hide exactly this kind of friction.

### 2.1 Three API families, one process

As documented, the surface divides cleanly into three families plus operations endpoints:

**a) The native API — the engine, honestly exposed.**

- `POST /completion` — raw completion with the full llama.cpp parameter set: the complete sampler chain, grammar and JSON-schema constraints, logit bias, prompt-cache control (`cache_prompt`), slot assignment (`id_slot`), LoRA selection per request, token probabilities, timings. Explicitly documented as *not* OpenAI-compatible; OpenAI clients are directed to `/v1/completions`.
- `POST /infill` — fill-in-the-middle for code models.
- `POST /tokenize`, detokenisation and embedding-adjacent helpers, `GET /props` (server / model properties), `POST /props` when explicitly enabled.
- Slot operations: `GET /slots`, and save / restore / erase of a slot's prompt cache (`POST /slots/{id}?action=save|restore|erase`, gated by `--slot-save-path`).
- LoRA management: `GET /lora-adapters`, `POST /lora-adapters`.
- `POST /v1/systemone` and the `/tools` endpoint family are also documented — the former a typed “decision model” API (TypeSafe-compatible), the latter explicitly marked internal to the web UI and “do not use in a downstream application”. Their presence shows the native surface is still growing sideways into model classes beyond chat; neither is needed to understand the ecosystem, and both are flagged here so a reader is not surprised by them.

**b) The OpenAI-compatible API — the ecosystem's lingua franca.**

Documented endpoints include:

- `GET /v1/models`
- `POST /v1/completions`
- `POST /v1/chat/completions` (streaming, tool / function calling with `--jinja`, schema-constrained JSON via `response_format`, multimodal content parts — image, audio and video inputs for models that support them, reasoning-field handling)
- `POST /v1/chat/completions/control` (real-time control of an in-flight completion, currently to end a reasoning block early)
- `POST /v1/responses` (the OpenAI Responses API, implemented by conversion to a chat-completions request internally) plus token-counting helpers under `/v1/responses/input_tokens` and `/v1/chat/completions/input_tokens`
- `POST /v1/embeddings` (including, beyond the OpenAI shape, multimodal embedding inputs)
- `POST /v1/rerank` / reranking, when the server is started with `--rerank`
- `POST /v1/audio/speech` for speech-generating models, and the WebSocket `/v1/realtime` endpoint for streaming transcription and realtime conversation with audio-capable models

The README's own disclaimer, paraphrased, is the most important sentence in this section: no strong claim of full OpenAI-spec compatibility is made; in practice it suffices for many applications. Every proxy and frontend in §§3–5 lives inside that gap — close enough that the OpenAI SDK works by changing only the base URL, different enough (context split across slots, ignored `model` field in single-model mode, sampler extensions, template quirks) that a translation / supervision layer earns its keep.

**c) The Anthropic-compatible API.**

- `POST /v1/messages` (streaming via server-sent events; tool use requires `--jinja`)
- `POST /v1/messages/count_tokens`

This second compatibility target is a recent-era pattern across the whole field — llama-swap and LocalAI both advertise OpenAI *and* Anthropic surfaces — and it matters for the coding-agent clients (which increasingly speak Anthropic's Messages shape) that now drive a large share of local-server traffic.

**Operations endpoints** cut across the families: `GET /health` (503 while loading, 200 when ready; public even when an API key is set, also reachable as `/v1/health`), `GET /metrics` (Prometheus format, only when `--metrics` is passed), `GET /slots` (only when the slots endpoint is enabled, which is the default). Errors are returned in the OpenAI error envelope shape.

### 2.2 Slots, in one paragraph (pointing inward)

A single-model `llama-server` process serves concurrent requests through a fixed pool of **slots** (`-np` / `--parallel`), with continuous batching across them; the total context (`-c` / `--ctx-size`) is divided among slots unless unified-KV arrangements apply, and each slot carries its own KV state, sampler parameters and prompt cache. That is the whole server-surface fact a reader of *this* dossier needs. The mechanics — KV-cache types, cache reuse and shifting, slot prompt-similarity matching (`--slot-prompt-similarity`), speculative decoding interaction, and why slot count is a VRAM decision — are deep-covered in the companion dossier and in the corpus's memory research, and are deliberately not repeated here. The ecosystem consequence is simpler: **concurrency inside one model is the server's job; concurrency across models was, until router mode, somebody else's job.** That boundary is where §3 begins.

### 2.3 Single-model mode: the original contract

Started with `-m <file.gguf>` (or `-hf <user>/<repo>:<quant>`, or a model URL / Docker-repo reference), the server serves exactly one model. The `model` field in requests is essentially ignored (an `--alias` can set the name clients see). Swapping models means stopping the process and starting another with different flags. Every operational pain the ecosystem addresses follows from this sentence: per-model flags are command-line-only, load times are seconds to minutes, clients hold a port number that changes when the operator changes their mind, and there is no catalogue — there is a file path.

Two mitigations inside the core deserve note because they blur the “core does nothing” story:

- **Idle sleep.** `--sleep-idle-seconds` unloads the model and its KV cache after inactivity and reloads on the next real task; health / props / models / metrics probes do not count as tasks and do not wake it. Status is visible via `/props` as a sleeping state.
- **Hugging Face and cache integration.** `-hf` downloads into the llama.cpp cache (`LLAMA_CACHE`, defaulting under `~/.cache/llama.cpp`), including the multimodal projector when present. The cache becomes, in router mode, a model source in its own right (§2.4).

### 2.4 Router mode: the core absorbs the proxy's job — partially

Router mode is what happens when the ecosystem's most-requested feature is pulled into the core. The Hugging Face announcement (2025-12-11) frames it explicitly as bringing Ollama-style model management to llama.cpp; the current README documents it under “Using multiple models”.

**Activation and architecture.** Start `llama-server` *without* a model argument and it runs as a router: the main process performs no inference itself. It is a dispatcher and lifecycle manager that spawns **one child `llama-server` process per model**, forwards each request to the right child, and isolates failures — a crashed child does not take down the router or the other models. This multi-process choice is the single most important architectural fact in this dossier, because llama-swap (§3) made the *same* choice independently, and LocalAI (§4) made it a third time with gRPC. Three projects, one conclusion: at the server layer, a model is a process.

**Model sources (three, documented in this order):**

1. The **cache** — anything previously fetched with `-hf` is auto-discovered.
2. A **directory** — `--models-dir <path>`: single-file GGUFs sit directly in it; multi-shard and multimodal models go in a subdirectory of their own, with the projector file's name required to start with `mmproj`.
3. A **preset file** — `--models-preset <file.ini>`: see below.

**Routing.** For POST inference endpoints the router reads the `model` field of the JSON body; for GET endpoints (`/props`, `/metrics`, …) and the realtime WebSocket it reads a `model` query parameter. Autoloading is on by default (`--models-autoload`, disable with `--no-models-autoload`, override per-request with an `autoload` query flag): a request for an unloaded model loads it first, then is forwarded.

**Limits and unloading.** `--models-max N` caps simultaneously loaded models (default **4**, 0 = unlimited), evicting least-recently-used first. That cap counts *models, not memory* — a documented trap that independent guides emphasise: four small models and four large models are treated identically until the machine runs out of device memory. The newer `--models-memory-margin N` option addresses it: the router measures each model (by spawning a short-lived metadata-only child per model, which reports a minimum footprint at the smallest `--fit` context and a maximum at the largest fitting context), then, before loading a new model, unloads idle LRU models until the new model's minimum fits with N MiB left free per device. A model actively serving is never unloaded for this; if nothing unloadable remains and it still does not fit, it loads anyway and the child's own `--fit` logic decides. Measurements are exposed in the `memory` field of `GET /models` and via events on the models SSE channel. Host (CPU) memory is treated as unlimited for this logic, multimodal projectors are not yet included in measurements, and a model whose measurement fails is loaded without memory checks — all documented caveats, quoted here because they define how much trust to place in the feature.

**Presets: per-model configuration, declaratively.** The preset file is INI. A `[*]` section sets global defaults; each other section is named for a model and sets keys that are command-line options without their dashes (long form, short form such as `c` or `ngl`, or the `LLAMA_ARG_*` environment-variable name are all accepted). Precedence is: router command line first, then the model's section, then `[*]`. Three keys exist only in presets: `load-on-startup`, `stop-timeout` (grace period before a forced kill on unload, default 10 s), and `dedup-cache-models`. Router-controlled arguments (host, port, API key, HF repo, alias) are stripped or overwritten before a preset is handed to a child, so a preset cannot hijack the router's own surface. Relative file paths in presets resolve as documented relative to the working directory, with absolute paths recommended. This is, in substance, llama-swap's YAML idea (§3) re-expressed in INI inside the core — per-model flags, declared once, applied on every load.

**Management API.** Router mode adds a model-management surface that single-model mode does not have:

- `GET /models` — the catalogue, with per-model `status` (`unloaded`, `loading`, `loaded`, `sleeping`, `downloading`, `incomplete`, plus failure detail with exit code where relevant), the exact child arguments, offline-computed `architecture` (input / output modalities — text, image, audio, video, decisions — readable *without* loading the model), and memory measurements when available. `?reload=1` rescans the sources.
- `GET /v1/models` — the OpenAI-shaped view, fed from each loaded child's own `/v1/models` when loaded.
- `POST /models/load`, `POST /models/unload` — explicit lifecycle control.
- `POST /models` — start a (non-blocking) download of a new Hugging Face model into the cache, with optional sidecars (projector and draft-head kinds); `DELETE /models?model=…` deletes a cached model (preset models cannot be deleted this way; shared files belonging to another cached quant are kept), with a `sidecar` variant to drop one sidecar kind.
- `GET /models/sse` — a server-sent-events stream of `model_status`, `download_progress`, `model_memory`, `model_remove` and `models_reload` events.

**What router mode does *not* do** is equally defining: it only routes llama.cpp children (no vLLM, no Whisper server, no image server behind the same port), it has no request-rewriting filters, no grouping / co-residency matrix beyond the max-count and memory-margin logic, and its configuration, while documented, is younger and has changed across versions — independent guides warn that preset details have shifted between builds. It is the right default for “several GGUFs, one machine, one port, nothing else”. It is not a general AI gateway. That remainder is precisely llama-swap's and LocalAI's territory.

---

## 3. The proxy layer: llama-swap as the type specimen

- Repository: `mostlygeek/llama-swap` — created 2024-10-04; at access (2026-11-15) the GitHub header showed ~6,254 stars, 548 forks, 215 releases, MIT licence, Go.
- Self-description in substance: reliable model swapping for any local OpenAI- / Anthropic-compatible server.

### 3.1 The problem, stated plainly

`llama-server` gives an operator total control over one model's flags and no help at all with the second model. The manual workflow — kill the process, rebuild a command line, wait for the load, repoint every client — does not survive contact with real use, where a coding assistant wants a large instruct model, an autocomplete wants a small fast one, an embedding job wants a third, and all of them expect to talk to *one* stable base URL. llama-swap's answer is to change **who launches the server, not what the server does**.

### 3.2 Design: a supervisor that happens to be a proxy

llama-swap is a single Go binary with, by its own account, zero external dependencies and exactly one configuration file. It listens on one port, and for each incoming request:

1. It extracts the requested model identity — the `model` field of the JSON body for the OpenAI / Anthropic endpoints, a query parameter for the endpoints that need one.
2. It checks whether the upstream process for that model is already running and healthy.
3. If a different model occupies the slot (in the basic configuration), it stops that upstream first — freeing VRAM before the new load begins — then starts the configured command for the requested model on an automatically assigned port (the literal `${PORT}` placeholder in the command is substituted by llama-swap), waits for its health check, and only then proxies the request through.
4. Responses, including streamed server-sent events, are proxied back transparently.

The configuration is the product. A minimal YAML file is a `models:` map from model ID to a single `cmd:` — the full command that starts that model's server, with all of its llama.cpp flags spelled out per model. Everything else is optional and additive:

- **`ttl` and the global TTL.** Per-model idle time-to-live in seconds; `-1` (the default) inherits the global value, `0` means never unload, a positive value unloads after that much idleness and frees the memory. The global default is also `0` — nothing unloads unless the operator says so, a deliberate but sharp-edged default that every guide warns about.
- **Health and unload tuning.** A health-check timeout for slow-loading models (documented default 120 s in the configuration references), and an unload timeout for graceful shutdown.
- **Co-residency control.** The original model was strictly one-at-a-time. Current llama-swap adds two mechanisms, whose naming has evolved across versions (guides written against older releases describe a `groups:` block; the current README describes a `matrix` with a custom swap-logic DSL): in either vocabulary, the operator declares which models may run concurrently and which must evict each other, instead of accepting global one-at-a-time swapping. This exists because the naive default *thrashes* in the most common real topology — a chat agent and a small autocomplete model alternating requests, each evicting the other on every keystroke pause.
- **Request rewriting.** Per-model `filters` can strip parameters, set parameters, and set parameters by ID — the practical use is enforcing sampler or template settings server-side against clients that override model defaults.
- **Aliases and name override.** `aliases` let familiar names (including, pointedly, names shaped like commercial API models) route to local models; a separate option overrides the model name actually sent upstream.
- **Lifecycle hooks, macros, profiles, environment.** Startup hooks can preload models; macros factor repeated command fragments; per-model `env` passes environment variables to the child; runtime **profiles** can switch which model ID routes where without a restart. A `cmdStop` companion command handles upstreams that run under Docker / Podman and need an explicit stop command rather than a signal.
- **Supervision surface.** A web UI with a playground, live token metrics, request / response inspection, manual load / unload and live logs; a `/running` listing; explicit unload endpoints (`POST /api/models/unload`, per-model variant), pause / resume endpoints that unload everything and reject inference until resumed; buffered and streaming log endpoints (combined, proxy-only, upstream-only, HTTP-access, per-model); a `/health` endpoint; Prometheus `/metrics` including system and GPU metrics; optional API keys; and an MCP endpoint exposing its own configuration documentation to agents. Config-file watching allows reload without a full restart in the container deployment.

**Endpoint breadth.** llama-swap does not merely forward chat completions. Its README enumerates passthrough support for the OpenAI completions / chat / responses / embeddings / models / audio (speech, transcription, voices) / realtime / images (generation and edits) endpoints, the Anthropic messages and token-counting endpoints, llama-server-specific endpoints (rerank, infill, native completion, props, models), stable-diffusion.cpp's SDAPI image endpoints, audio.cpp endpoints, and a ComfyUI path. In other words, the proxy learned every dialect its upstreams speak, because a swap layer that only handles chat would force operators to run a second front door for everything else.

**Backend agnosticism is the point.** The README's answer to “do I need llama-server?” is, in substance: no — any OpenAI-compatible server works; llama-server is the original and best-supported upstream, and Python servers such as vLLM or TabbyAPI are recommended to be run via a container so they terminate cleanly on signal. Documented upstreams across the README and guides include llama.cpp and its forks (including ik_llama.cpp in the unified container), vLLM, stable-diffusion.cpp, whisper.cpp, audio.cpp and ComfyUI. llama-swap therefore sits *above* the llama.cpp ecosystem as often as inside it.

**Distribution.** Pre-built binaries for Linux, macOS, Windows and FreeBSD; Homebrew (its own tap), MacPorts and WinGet community packages; and two container families — a “unified” image bundling llama-swap with llama-server, ik_llama-server, stable-diffusion.cpp, whisper.cpp and audio.cpp built from source (CUDA 12, CUDA 13 and Vulkan variants, including arm64 for the CUDA 13 line), and a legacy image that is llama.cpp's own server image with the llama-swap binary copied in. The unified image is the recommended one, and its existence is a §5 pattern in miniature: the distribution *is* the integration work.

### 3.3 What llama-swap proves

- **Process supervision is a separable concern from inference.** llama-swap contains no inference code at all, yet it is, for thousands of operators, the difference between llama.cpp being usable and not. Model lifecycle — start, health-gate, route, idle-unload, evict, log — is a complete product on its own.
- **The swap cost is the design constraint.** Every swap pays a full model load. TTLs, co-residency groups / matrix rules, preload hooks and “keep the embedder resident” recipes in the guides are all, at bottom, ways to avoid paying it at the wrong moment. Any system that swaps processes inherits this physics; §7 returns to it.
- **Config-declared fleets beat imperative scripts.** One declarative file that a second tool (or an agent, via its MCP docs endpoint) can read, diff and regenerate is operationally superior to a folder of shell scripts that start servers — even when the file is longer.
- **Router mode did not kill it.** llama.cpp absorbed the single-backend case (§2.4); llama-swap's remaining advantages are exactly the ones router mode does not claim: heterogeneous backends, request filtering, profiles, and a supervision UI / metrics surface. That is a clean illustration of how a core absorbing a feature *narrows*, rather than eliminates, the ecosystem layer above it. *(Assessment, not a documented claim by either project.)*

---

## 4. LocalAI: the maximalist pole (centrepiece)

- Repository: `mudler/LocalAI` — created 2023-03-18; at access (2026-11-15) the GitHub header showed ~50,370 stars, 4,605 forks, 140 releases, ~10,000 commits, MIT licence (brand assets excluded, §1.3).
- Current release at access: **4.12.1** (October 2026, a security fix for validation of user-supplied URLs), following 4.12.0, 4.11.0 and 4.9.0 in rapid succession — by any public measure (release cadence, commit volume, gallery growth) an actively maintained, fast-moving project.
- Origin, as documented in project histories: started in March 2023 by Ettore Di Giacinto as a Go wrapper around llama.cpp. That origin matters — LocalAI is not a llama.cpp *competitor* that later added support; it is a member of this ecosystem that outgrew its first backend.

LocalAI deserves the centrepiece treatment the brief anticipated: in this survey it is the largest single thing built on the llama.cpp server pattern, and it is the clearest available answer to the question “what happens if you *don't* stop?”

### 4.1 The promise: one API, every modality, any hardware

LocalAI presents itself as a drop-in replacement for the commercial APIs, running entirely on the operator's hardware, GPU optional. A client that speaks to OpenAI — and, in current versions, clients that speak Anthropic's Messages API, ElevenLabs' audio APIs, or Ollama's API — should be able to change only the base URL. Behind that one port it serves, per its README and documentation:

- Text generation and chat (with tool calling and grammar-constrained output)
- Embeddings and reranking
- Image generation and vision / object detection
- Speech-to-text, text-to-speech, voice-activity detection, and a realtime speech-to-speech API
- Video generation, and — in the newest lines — 3D generation, motion / animation, time-series forecasting and PII redaction, among others

plus the platform features that accrete around a server that people run for teams: a web UI, saved agents with tools and MCP (as both client and server), document collections, users / roles / quotas, add-ons, a distributed mode, and P2P inferencing. The README's “what you can do” table at access time is the best evidence of the maximalist pole in action: each release line adds a surface (a decisions API, failover chains, a fleet dashboard, a benchmark command, signed galleries) rather than deepening a single one.

### 4.2 Architecture: a small Go core, backends as separate processes over gRPC

The architecture, as documented on the project site and in code summaries, is the third independent arrival at process isolation (§2.4, §3.2), taken furthest:

1. **The core** is a Go binary (with a React web UI) that owns the HTTP APIs, model configuration, lifecycle and routing. It performs no inference itself.
2. **Backends are separate OS processes** implementing a standard gRPC service (defined in the project's `backend.proto`): health, load-model, predict / predict-stream, embedding, and the modality-specific calls. The core's model loader allocates a free port, spawns the backend process, polls its health RPC, issues the load, and forwards requests. A backend can be written in any language that can serve gRPC — and they are: C++ backends for the ggml-family engines, Python backends for the Transformers / Diffusers / vLLM world, Go backends for lighter utilities.
3. **Backends are distributed as OCI images, pulled on demand.** Since the 3.x line (documented as “since 3.2.0 every backend lives outside the main binary”), a stock installation ships essentially no engines; when a model needs a backend, the matching image is pulled from the **Backend Gallery**, with the variant (CUDA 12, CUDA 13, ROCm, oneAPI/SYCL, Metal, Vulkan, Jetson, CPU) selected from detected hardware. Backend images have been cosign-signed since the 4.3 line. Install / list / upgrade of backends is a CLI operation (`local-ai backends …`) as well as a UI one. The model configuration names an abstract backend (`llama-cpp`); the installed variant directory is hardware-specific — the alias is what makes one model YAML portable across machines.
4. **Models are YAML files plus a Model Gallery.** Each model is a YAML configuration naming its backend, its file(s), context size, GPU layers, templates (chat / completion), and parameters. The **Model Gallery** (browsable at the project's models site; reported at ~1,700 entries in the 4.9-era coverage) distributes pre-configured models: installing a gallery model downloads the weights *and* writes a tuned YAML — templates, stop tokens and tool-calling setup included — which the operator can then edit. Models can equally be run directly from Hugging Face references, from the Ollama OCI registry, from arbitrary OCI registries, or from a YAML URL. The gallery is LocalAI's answer to Ollama's library: breadth and community tail over curation, with configuration quality as the differentiator it advertises (notably, gallery coding models arriving with tool calling already wired).

The llama.cpp backend remains the flagship text backend — the one GGUF models land on by default — alongside, per the current README, **more than 80 backends** in total (secondary coverage from mid-2026 said “more than 60”; the count grew between those readings, which is itself the trend to record). The roster spans vLLM, SGLang, Transformers, MLX / MLX-VLM, whisper.cpp, diffusers / stable-diffusion.cpp and many more, *plus* a growing set of native C++ / GGML engines the LocalAI project now writes itself (its README lists, among others, a from-scratch C++ vLLM-style engine, Parakeet and MOSS speech ports, RF-DETR object detection, TRELLIS 3D, and face / voice analysis engines). At that point LocalAI has stopped being only a wrapper ecosystem and has become an engine author in its own right — while still consuming llama.cpp as a backend. Both facts belong in the record.

Two further architectural notes from the documentation:

- **Distributed mode** separates stateless frontends (sharing state via PostgreSQL and NATS) from generic workers that run per-model backends — a different axis from llama.cpp's own RPC tensor-splitting, which LocalAI's llama.cpp backend can *also* use underneath. The naming collision (“distributed” meaning request distribution at one layer and tensor distribution at another) is a recurring source of confusion in guides.
- **Authentication hardened late.** The 4.9.0 release (August 2026) moved to deny-by-default: every HTTP route requires credentials unless explicitly public, after an external report that unprefixed alias routes had fallen outside the older protected-route matching. Recorded here not as a criticism but as a §7 lesson: a maximal surface accumulates alias routes, and alias routes are where auth coverage goes to die.

### 4.3 The trade: breadth against depth, stated fairly

**What the breadth buys.** One deployment, one auth story, one base URL for an entire local-AI estate: chat, embeddings for RAG, transcription, speech, images. For an organisation standardising on “the OpenAI API, but ours”, nothing else in this dossier offers that. The backend-gallery mechanism is genuinely elegant — hardware-matched engines arriving on demand keeps the base install small while the *catalogue* stays huge, and the gRPC boundary means a broken Python backend cannot corrupt the core.

**What it costs.** *(Assessment, grounded in the documented defaults and structure; LocalAI's own materials present the same facts as features.)*

- **Configuration depth per model is shallower than the native tool's.** A gallery model's context defaults illustrate it: secondary guides against the 4.9-era gallery report bare models defaulting to very small contexts and gallery configs commonly setting 8,192 — far below what the same GGUF would be given by a llama.cpp operator setting `-c` by hand. The YAML *can* raise it; the point is that in a maximalist system, most users run the gallery author's numbers, not the engine's capabilities.
- **The moving parts multiply.** Core + per-backend images + model YAMLs + two galleries (models and backends) is a larger operational surface than a binary and a GGUF folder. Version skew between core, backend image and upstream engine is a standing possibility that a single-binary stack does not have.
- **llama.cpp-specific depth is mediated.** Anything llama.cpp exposes that the gRPC protocol and the YAML schema do not model — exotic sampler chains, slot-cache surgery, per-request LoRA gymnastics — is either passed through by deliberate design or unavailable. A maximalist gateway necessarily serves the *intersection* of its backends well and each backend's *extremes* unevenly.
- **Release velocity cuts both ways.** ~5,000 commits in twelve months (per a November 2026 tracker snapshot) and monthly feature releases mean capabilities arrive fast — and that guides, compose files and gallery references age in months. The archived predecessor model-gallery repository still being copied from old compose files in 2026 is the documented symptom.

**Project health, as public fact.** Created March 2023, still led by its creator with a named maintainer team, ~50k stars, an unbroken release line through 4.12.1, a Discord, a documentation site, a models site, and no paid edition or feature gate under its MIT licence. Whatever judgement a reader makes of the maximalist trade, “abandoned” is not available as one of them.

### 4.4 LocalAI's place in *this* ecosystem

LocalAI is simultaneously (a) the largest consumer of the llama.cpp pattern — a Go core supervising a llama.cpp backend process is llama-swap's shape with a gRPC contract and a gallery attached — and (b) proof that the pattern escapes its origin: most of LocalAI's 80+ backends are not llama.cpp at all. For our purposes it functions as the control experiment for §6: it shows what the “absorb everything into the product” strategy looks like when executed by a permissively licensed open-source project rather than a single-product company, and it shows that even the maximalist ends up with a *small core and external backends* — the maximalism is in the catalogue and the API surface, not in the core binary.

---

## 5. The long tail: frontends, one-click distributions and packaging (pattern level)

No catalogue is attempted. Four recurring patterns cover most of the tail, and the patterns — not the names — are what a new runner will compete with and learn from.

### 5.1 Pattern A: the frontend that drives llama-server as a subprocess

**Type specimen: text-generation-webui, now TextGen** (`oobabooga/textgen`; AGPL-3.0, §1.3). At public-fact level: a long-running (since 2023) local-LLM interface supporting several backends (llama.cpp, its ik_llama.cpp fork variant, Transformers, ExLlama family, TensorRT-LLM), with its own OpenAI- / Anthropic-compatible API. Its llama.cpp integration is documented in code summaries as a wrapper class that **launches the `llama-server` binary as a subprocess on a free local port, translates the UI's settings into llama-server flags, monitors the child's stderr for load progress and errors, and talks to it over its local HTTP API** (native completion / tokenise endpoints). Two loaders historically existed — a direct native path and a Hugging Face-compatible shim that presented the llama.cpp model through a Transformers-shaped interface for extension compatibility — a neat fossil of an era when every extension assumed a Python model object.

The pattern generalises: **Open WebUI** (named here only as a documented consumer) connects to an already-running `llama-server` as an OpenAI-compatible provider, and — tellingly — has grown llama.cpp-specific affordances on top of the generic connection: a provider flag that unlocks a loaded-model indicator, an admin eject action that calls the server's model-unload endpoint, and a management panel that lists, downloads, loads, unloads and deletes models *through* the router-mode management API (§2.4). When a general frontend starts implementing one backend's management endpoints by name, that backend's server surface has become a platform.

Lesson of Pattern A: a documented local HTTP API plus a discoverable binary is an embedding strategy. Nobody signed an integration agreement; the subprocess + HTTP contract was sufficient, twice over, in two different languages and licence regimes.

### 5.2 Pattern B: the all-in-one / one-click distribution

llama-swap's unified container (§3.2), LocalAI's single container that pulls backends on demand (§4.2), the many community Docker compositions that pair `llama-server` with a web UI, and the one-line installers all solve the same problem: **the gap between “a binary that needs flags and a model file” and “a thing a person can run” is filled by whoever ships the defaults.** The official llama.cpp container images (`ghcr.io/ggml-org/llama.cpp`, with `server`, `server-cuda` and further variants) set the base pattern — models mounted as a volume, host explicitly widened to `0.0.0.0` inside the container, a healthcheck against `/health`. Downstream distributions differentiate almost entirely on *which defaults they chose*: which models are pre-pulled, which context size, which UI is bundled, which port is published.

### 5.3 Pattern C: OS and language packaging — the boring, decisive layer

By the access date, llama.cpp's documented distribution channels include: GitHub release binaries (Linux, macOS, Windows, Android, iOS), the official Docker images, Homebrew (macOS and Linux), conda-forge, MacPorts, Winget (`winget install llama.cpp`), Debian packaging, XCFrameworks for Apple platforms, and a project installer served from llama.app that drops a unified `llama` executable (with `llama serve` as the server entry point) into the user's local bin. llama-swap mirrors the pattern at smaller scale (Homebrew tap, MacPorts, WinGet, release binaries for four operating systems). LocalAI ships an install script, a signed / notarised macOS app, and a family of hardware-specific container tags.

Two honest observations:

- **Channels disagree about versions.** An independent September 2026 install guide that tested four channels on the same day found four different builds (nightly from the project installer, the previous stable from Homebrew, a pinnable tag in Docker, whatever was cloned for a source build). “Install llama.cpp” is not a reproducible instruction; “install *this build* from *this channel*” is. Any runner we ship will inherit this problem the moment it has two channels.
- **Packaging is where ARM and edge support becomes real.** Bottles / binaries for Linux arm64 and Apple Silicon, s390x container variants, Jetson-specific LocalAI images — the ecosystem's “runs anywhere” reputation is earned in build matrices and package repositories, not in the engine. This aligns with the corpus's cross-platform findings elsewhere and with Volmarr's standing cross-platform law: portability is a distribution property as much as a code property.

### 5.4 Pattern D: llama.cpp as an ingredient, invisibly

The deepest layer of the tail never mentions llama.cpp in its own marketing: applications that bundle a llama.cpp-derived backend (via the C API, a language binding, or a bundled `llama-server`) and present an unrelated product face. The companion dossier covers bindings and embedders as engine consumers; the server-ecosystem point is narrower — the *server* made a second embedding path available, over HTTP, to products in any language, including products whose authors never compiled C++. KoboldCpp, Jan, LM Studio and Ollama itself are treated in their own dossiers and are not re-surveyed here; they are noted only to mark that the boundary between “ecosystem” and “competitor” in this field is mostly a matter of which layer a product chose to own.

---

## 6. What the ecosystem's shape proves

Six conclusions, each tied to the evidence above. Assessments are marked; the rest is documented fact.

**1. A permissive licence plus a stable server contract is an ecosystem generator.** All three load-bearing pieces are MIT (§1.3). The OpenAI-compatible surface — imperfect by its own admission (§2.1) — was standard *enough* that proxies, frontends and gateways could be built without permission, coordination or a plugin API. llama.cpp never shipped an extension system for servers; HTTP was the extension system. *(Assessment: this, more than any single feature, explains the constellation's size.)*

**2. Value concentrates in three places, none of them inference.** Across §§2–5, the work the ecosystem actually charges attention for is: **model management** (catalogues, galleries, download / cache / delete, per-model configuration — router presets, llama-swap YAML, LocalAI gallery YAML), **API translation** (OpenAI shape, Anthropic shape, ElevenLabs shape, Ollama shape, native shape, all over the same engines), and **supervision** (process lifecycle, health gating, idle unloading, eviction policy, logs, metrics, UIs for all of it). Inference quality and speed — the hard part — is inherited from the core and largely undifferentiated at this layer. A new runner that spends its novelty budget on inference is competing with ggml-org; a runner that spends it on management, translation and supervision is competing with a YAML file and a Go proxy — and should be honest with itself about which contest it entered.

**3. The core stayed minimal because the ecosystem absorbed the product pressure — and then the core absorbed back the one feature everyone needed.** For years, “llama.cpp doesn't manage models” was answered by llama-swap, not by llama.cpp. When the pressure became universal, router mode (§2.4) pulled *exactly that one feature* — multi-model lifecycle for GGUFs — into the core, in the ecosystem's own architectural language (child processes, declarative per-model presets, LRU eviction), while leaving heterogeneous backends, request filtering and team features outside. That is a maintainable boundary in action: absorb what is universal and engine-adjacent; leave what is product-shaped outside.

**4. The two strategies, stated fairly.**

| | llama.cpp + ecosystem (federated) | Ollama (integrated) — and, in open-source form, LocalAI |
|---|---|---|
| Where product surface lives | Distributed: core server + independent proxies, frontends, galleries, packagers | Inside the one product: registry, model library, API, serving, CLI |
| User's first five minutes | Slower: choose a build, a model file, flags; or adopt someone's distribution that chose for you | Faster: one install, one pull command, one API |
| Ceiling for a power user | Higher: every flag, every backend, composable pieces | Lower by design: the product's model of the world is the limit |
| Who fixes a gap | Whoever is annoyed enough, in their own layer, under MIT | The product team, on the product's roadmap |
| Failure mode | Fragmentation: version skew across channels, four installs giving four builds (§5.3), guides rotting | Bottleneck and fork pressure: day-one model support arriving via a fork of the engine rather than upstream coordination (a documented episode in the llama-swap-era guides) |
| Licence / governance risk | Diffuse; no single throat | Concentrated in one vendor / project |

Neither column is the “right” one; they optimise for different users. The federated column optimises for the operator who will compose; the integrated column optimises for the user who will not. LocalAI's existence — integrated product surface, federated backend architecture, MIT throughout — proves the columns are axes, not a binary choice.

**5. Process-per-model won, three times independently.** Router mode, llama-swap and LocalAI all isolate a loaded model in its own OS process supervised by a front process (§§2.4, 3.2, 4.2). The reasons converge: crash isolation, clean VRAM reclamation on exit (the operating system is the only truly reliable GPU-memory garbage collector), independent per-model flags / environments, and the ability to supervise engines written in any language. No surveyed piece loads multiple heterogeneous models into one process as its primary design. That unanimity is the strongest architectural signal in this dossier.

**6. Defaults are the real API.** The ecosystem's lived behaviour is set less by endpoint lists than by defaults: router mode's `--models-max 4` counting models instead of memory, llama-swap's TTL default of “never unload”, LocalAI gallery contexts far below engine capability, llama-server's context divided silently across slots. Every one of those defaults generated guides, issues and workarounds. *(Assessment: for a new runner, reviewing defaults deserves the same gate as reviewing APIs — users experience defaults as the product.)*

---

## 7. Ideas to steal for a Go runner

Each idea states the gain and the cost / risk honestly. “Steal” means adopt the *pattern* in our own design and words; all three source projects are MIT, but this corpus is clean-room regardless — no code is to be lifted.

### 7.1 The swap-proxy as an alternative chassis: supervise processes, don't embed residency

**The idea.** Build the runner's multi-model layer the llama-swap / router-mode way: the daemon owns no model memory itself; it owns a catalogue of declarative per-model launch definitions, spawns one inference process per loaded model on an assigned port, health-gates it, routes by the request's model field, and unloads on policy (TTL, LRU, memory margin). Inference itself stays in the proven engine binary.

**Gain.** Crash isolation and total VRAM reclamation per unload, for free, from the OS. Per-model flags, environments and even *different engine builds* per model (one model on a stable build, one on a nightly, one on a fork) with no linking consequences. The daemon stays small, restartable and upgradable without dropping loaded models' code — only their processes. In Go specifically, this is the language's home turf: process supervision, HTTP proxying and declarative config are exactly what llama-swap demonstrated in Go, at production scale, with one binary.

**Cost / risk — and the honest tension with the resident-session thesis.** The corpus's memory research argues for *resident sessions*: a long-lived conversational context whose KV state, prefix cache and “warm” model are the product's continuity, not disposable cache. A pure swap architecture is in direct tension with that thesis, and the tension must not be elided:

- A process swap **destroys** resident state. KV cache, slot prompt caches and speculative state die with the child. The next request pays full prompt reprocessing on top of full model load. llama-server's slot save / restore (§2.1) can persist a slot's cache to disk, which softens this for a single-model server, but no surveyed proxy treats *session state* as a first-class thing to preserve across swaps — sessions are exactly what their model throws away.
- Swap latency (seconds to minutes on large models) makes “many models, casually interleaved” a fiction unless co-residency rules keep the hot set resident — at which point the design has quietly become a resident system with extra process boundaries, and should be engineered as one (pinned residents, explicit eviction order, state-aware unloading) rather than as a swapper with exceptions.
- The resolution this dossier recommends *(assessment)*: **a two-tier design.** A small set of *resident* models / sessions, held deliberately, state preserved, evicted only by explicit policy; and a *swappable* long tail served by the proxy pattern, where statelessness is honest. Router mode's `load-on-startup` presets, llama-swap's `ttl: 0` (never unload) entries and co-residency matrix, and LocalAI's model-loader caching are all, read closely, the ecosystem groping toward exactly this two-tier shape without naming it. Name it, and design the boundary — what state a resident holds, what an eviction costs, what the user is told — as a product decision, not an accident of TTLs.

### 7.2 Config-declared model fleets

**The idea.** One declarative file (YAML in llama-swap and LocalAI; INI presets in router mode) is the fleet: model ID → engine command / backend → file → per-model parameters → lifecycle policy. The daemon renders it into processes; the file is diffable, generatable, and readable by tooling and agents.

**Gain.** Reproducibility (the fleet is a file, not a history of shell commands), reviewability, and a natural place for per-model truth (context, GPU layers, template, TTL) to live exactly once. Galleries (LocalAI) and preset inheritance (`[*]` globals, llama-swap macros) show how to keep the file DRY as it grows.

**Cost / risk.** Config schemas become public APIs with llama.cpp's own caveat: preset / config details *changed across versions* in both router mode and llama-swap's evolution (groups → matrix). Version the schema from day one, validate with useful errors, and never let the file silently accept a misspelled key — in a system where a typo means “ran on CPU”, silent acceptance is a performance bug factory. A second risk is config drift versus reality: router mode's `?reload=1` rescan and llama-swap's config watching exist because files and running fleets diverge; design the reconciliation story (what happens to a *loaded* model whose entry changed or vanished) before shipping the file format.

### 7.3 Deliberately stop the server surface — and write down where

**The idea.** Choose, in advance, the endpoint families the runner will own (suggested by the evidence: OpenAI-compatible chat / completions / embeddings / models, one native management family, health / metrics) and explicitly *not* own the rest — no image generation, no speech, no team features — leaving those to composition with other servers behind a proxy, exactly as llama-swap composes them.

**Gain.** Every surface not owned is a compatibility promise not made, an auth-alias bug not introduced (LocalAI §4.2), and a release cycle not spent chasing a modality's upstream churn. llama-server's own history shows restraint is survivable: it lacked model management for years and thrived, because the ecosystem could add it outside.

**Cost / risk.** Users will ask, and competitors (LocalAI above all) will answer with breadth. The mitigation is not breadth; it is *composability as a feature*: document the proxy composition, make the runner a well-behaved upstream (clean SIGTERM handling, health endpoint, predictable ports — the exact courtesies llama-swap's README asks of Python servers), and make it a well-behaved citizen behind third-party proxies. A runner that is easy to put behind things needs fewer things inside it.

### 7.4 Smaller steals, each with its price

- **Health-gated routing** (all three projects): never forward to a child that has not answered health. *Price:* health semantics must distinguish loading / ready / sleeping / failed, as router mode's status enum does — a boolean is not enough.
- **Memory-aware eviction over count-aware eviction** (router mode's `--models-memory-margin` and its min / max measurement pass): measure models before they are needed; evict by bytes, LRU among idle only, never evict an actively serving model. *Price:* measurement costs a metadata load per model and is currently documented as incomplete (projectors excluded); treat measurements as estimates with a margin, not truth.
- **Idle sleep as a distinct state from unload** (llama-server §2.3): unloading weights + KV on idle, waking on real work, probes excluded from “work”. *Price:* wake latency lands on the first real request; expose the sleeping state so clients can tell “cold” from “broken”.
- **Offline modality / capability advertisement** (router mode's `architecture` object in `GET /models`, computed without loading): clients should learn what a model *can* do — text, image, audio, decisions — from the catalogue, not by probing it awake. *Price:* offline computation can miss capabilities only a loaded model reports (documented: video); version the object and tolerate unknown values, as the README itself instructs clients to do.
- **Request filters at the proxy** (llama-swap's strip / set parameters): enforce house sampler and template policy server-side instead of trusting every client. *Price:* rewriting requests is a footgun for reproducibility; log every rewrite, and make filters visible in the supervision UI.
- **A supervision surface from the start** (llama-swap's UI / logs / metrics; router mode's SSE channel): running-models list, per-model logs, load / unload events as a stream. *Price:* the supervision API becomes a compatibility surface too — keep it small, and keep it separate from the inference API so it can evolve faster.
- **Backend / model galleries as OCI artefacts** (LocalAI): engines and models as signed, versioned, pull-on-demand images solves hardware-variant distribution elegantly. *Price:* a registry, signing, and a larger supply chain to defend; for a single-engine Go runner this is likely over-scale — the *steal* is the narrower principle (hardware variant selected at install time, recorded, and inspectable), not the full gallery machinery. *(Assessment.)*
- **Deny-by-default authentication, designed in, not retrofitted** (LocalAI 4.9.0 as the cautionary tale): enumerate public routes (health, and nothing else by default) and require credentials everywhere else, including every alias of every route. *Price:* friction for local-only users; answer it with a loopback exemption that is explicit and off when bound to a non-loopback address.

### 7.5 What not to steal

- **The “no strong claims of compatibility” shrug, as a permanent posture.** It was honest and effective for a research-grade engine; a product runner whose pitch is drop-in replacement will be judged against the spec it claims. Claim a *tested subset*, publish the subset, and test it continuously against the official SDKs. *(Assessment.)*
- **One-at-a-time swapping as the only mode.** It is the configuration that generates the thrash guides (§3.2). Ship co-residency from the first version, even if the first version's rule is as simple as “the pinned set plus one swappable slot”.
- **Gallery-scale breadth before depth.** LocalAI can afford 80 backends because llama.cpp afforded it the first one. Sequence matters: one backend, perfectly supervised, beats ten backends at gallery-default quality. *(Assessment.)*

---

## 8. Sources

All sources accessed **2026-11-15**, via text fetch / search. Primary sources are the projects' own documentation and repository pages; secondary sources were used for cross-checking, dating and the pattern survey, and are marked.

**Primary**

1. ggml-org/llama.cpp — `tools/server/README.md` (llama-server feature list, full parameter tables including router options, native / OpenAI-compatible / Anthropic-compatible endpoint references, slot and LoRA endpoints, “Using multiple models” router-mode section with presets, routing, memory-based unloading, `GET /models` / load / unload / download / delete / SSE management API, sleeping-on-idle section, Docker examples). https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
2. mostlygeek/llama-swap — GitHub repository page and README (licence header, repository statistics, feature and endpoint lists, unified / legacy containers, installation channels, configuration overview including `ttl`, filters, profiles, matrix, hooks, and the “How does llama-swap work?” and “Do I need llama-server?” sections). https://github.com/mostlygeek/llama-swap
3. mudler/LocalAI — GitHub repository page and README (licence header and brand carve-out, repository statistics, quick start, “What you can do” table, backend-gallery description, list of project-built native backends, release news through 4.12.1). https://github.com/mudler/LocalAI
4. Hugging Face (ggml-org) — “New in llama.cpp: Model Management” (router-mode announcement, multi-process rationale, quick start, `--models-max` default, preset introduction). Published 2025-12-11. https://huggingface.co/blog/ggml-org/model-management-in-llamacpp

**Secondary (cross-checks, guides, code summaries)**

5. DeepWiki — llama.cpp server summary (API-standard table including Anthropic and Ollama-alias routes, router-mode process model); llama-swap summary (proxy architecture, TTL); LocalAI backend-development and system summaries (gRPC backend protocol, ModelLoader lifecycle, backend languages); text-generation-webui llama.cpp backend summaries (`LlamaServer` subprocess wrapper, loaders). Accessed 2026-11-15 via search results.
6. BigIron — “llama-swap and llama-server Router Mode: Many Models Behind One Endpoint” (2026-09-28; router sources and presets in practice, `--models-max` memory trap, llama-swap TTL / groups practice, cold-start discussion). https://www.bigiron.cc/guides/llama-swap-and-llama-server-router-mode-many-models-behind-one-endpoint
7. Independent llama-swap guides and comparisons (Better Stack Community guide, 2026-05-17; KDnuggets setup guide; ModelsLab and AICoderScope 2026 guides) — configuration, TTL behaviour, groups, installation. Accessed 2026-11-15 via search results.
8. LocalAI coverage and documentation summaries (iThub project profile — Go core, gRPC backends, OCI backend gallery, MIT licence, 4.12.1 release note; AICoderScope LocalAI guide, 2026-08-28 — gallery size, context defaults, 4.9.0 auth change; SumGuy LocalAI guide — backend separation, gallery location, auth deny-by-default; ExploreAI LocalAI profile, updated 2026-10-21 — backend table, YAML configuration). Accessed 2026-11-15 via search results.
9. Open WebUI documentation — “Llama.cpp / Open WebUI” (connecting llama-server as an OpenAI provider; provider-specific loaded-model indicator, eject via the unload endpoint, admin model-management panel). Accessed 2026-11-15 via search results. https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-llama-cpp/
10. Install / distribution surveys — Jacar, “How to install llama.cpp on Linux, macOS and Docker” (four channels tested 2026-09-14, version divergence, Docker `server` image details); Hugging Face llama.cpp / ggml v1.0.0 release coverage (2026-11-13/14; distribution-channel list: release artefacts, Docker, Debian, Homebrew, conda-forge, MacPorts, Winget, XCFramework). Accessed 2026-11-15 via search results.
11. TextGen licence reporting — multiple independent 2026 reviews and self-hosting licence guides consistently reporting AGPL-3.0 for `oobabooga/textgen`. Accessed 2026-11-15 via search results. (Primary licence header not re-opened in this pass — see §1.3.)
12. llama.cpp licence cross-checks — multiple 2026 explainers and the Wikipedia entry reporting MIT for ggml-org/llama.cpp, consistent with the companion dossier's primary verification. Accessed 2026-11-15 via search results.

**Unverifiable / caveats in this pass**

- Exact current version numbers, star counts and gallery / backend counts are snapshots at access time and will have moved; the README-reported LocalAI backend count (“more than 80”) and the mid-2026 secondary count (“more than 60”) differ because the project grew between readings, not because either was misread.
- llama-server's default port could not be stated as a single number from the README alone, because its own sections exemplify both 9931 and 8080 (§2); the `--help` output of a specific build is the authority.
- TextGen's AGPL-3.0 licence is secondary-verified only (§1.3).
- No claim in this dossier rests on running any of these servers; behaviour is as documented, not as measured. A follow-up empirical pass (install, route, swap, evict, observe) is the natural next step before any §7 idea is adopted into a build plan.
