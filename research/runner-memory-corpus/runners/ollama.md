# OR-2 Deep Dossier: Ollama

> Research Forge campaign — commissioned by Volmarr, 2026-11-15.
> Written for a future expert reader who will engineer an improved Ollama fork.
> Clean-room note: this dossier describes architecture, behaviour and ideas in our own words. No source text or code is reproduced beyond short factual labels (parameter names, endpoint paths, version numbers). Ollama's own licence is recorded in §1.

## 1. Header

- **Name:** Ollama
- **Licence:** MIT License, copyright held by Ollama (the company). The licence file is unchanged in substance from the first release through the versions examined for this dossier. The engines underneath carry their own MIT licences: llama.cpp / GGML (copyright the ggml authors) and, where used, Apple's MLX (MIT). Model weights carry separate, per-model licences shipped beside the weights in the library; Ollama's licence does not govern the weights.
- **Language(s):** The control plane, CLI, HTTP server, scheduler and model management are written in Go. Inference itself is not Go tensor code in the current shipping design: GGUF models are executed by a bundled C/C++ program (upstream `llama-server`, built on llama.cpp / GGML); safetensors models on Apple Silicon are executed by an MLX runner. Earlier eras differed — see §2.3 for the full engine timeline, including a period (2025 to mid-2026) when a substantial set of models was implemented in Go directly over GGML.
- **Repository:** `github.com/ollama/ollama`
- **Site / docs:** `ollama.com`, model library at `ollama.com/library`, documentation at `docs.ollama.com`, blog at `ollama.com/blog`
- **First release:** v0.0.1, 2023-07-08. Repository created 2023-06-26, initially under the founder's personal account.
- **As of:** 2026-11-15. Version-sensitive claims are pinned to the tags they were read at. The deepest source-level readings available to this dossier are at v0.33.1 (truncation analysis, released 2026-08-26) and v0.34.4 / v0.35.0 (architecture and defaults history, September 2026). Documentation pages were re-read live on 2026-11-15; the context-length page carries an update stamp of 2026-11-12. Where docs and shipping code disagree, this dossier says so explicitly — with Ollama, that happens often enough to be a design lesson in itself.

**Essence.** Ollama is a local model manager and inference server modelled deliberately on the Docker workflow its founders knew from building Kitematic / Docker Desktop: a registry you `pull` from, a declarative packaging file (the Modelfile, analogous to a Dockerfile), content-addressed local storage, and one-command execution (`ollama run <model>`). A Go daemon listens on loopback port 11434, exposes both a native REST API and OpenAI- and Anthropic-compatible dialects, and delegates actual token generation to a per-model runner subprocess. Its optimisation target has never been datacentre throughput; it is time-to-first-token for a single user on a single, often memory-constrained, consumer machine, with zero configuration. Almost every strength and every weakness in this dossier follows from that choice.

---

## 2. Architecture

### 2.1 The two-process split: Go control plane, runner subprocess

The single most important architectural fact: **the Go server does not perform inference.** It is a control plane. Its jobs are:

1. HTTP routing and request translation (native API, OpenAI-compatible layer, Anthropic-compatible layer).
2. Model registry work: pulling, pushing, creating, copying, showing, listing and deleting models; resolving a model name/tag to a local blob.
3. Scheduling: deciding whether a requested model is already resident, whether it fits in memory, which device(s) it should occupy, and when an idle resident model must be evicted to make room.
4. Runner lifecycle: locating the correct runner binary for the detected accelerator, spawning it as a child process on a private loopback port, health-checking it until ready, proxying completions to it, and terminating it when its keep-alive expires.
5. Prompt preparation: rendering the chat template, applying message-level truncation (see §4.3), and forwarding the rendered prompt to the runner.

The runner subprocess does everything tensor-shaped: weight loading, KV-cache allocation, prompt evaluation, sampling and token generation, streaming results back over its private HTTP interface using server-sent events.

This subprocess boundary has oscillated over the project's life (in-process via cgo → subprocess → in-process as a library → subprocess → own engines → subprocess again; see §2.3), but the current design is firmly subprocess-based for GGUF models. The benefits are real and worth stealing: a crashing or hanging inference engine does not take down the management server; runner binaries can be built per-accelerator (CUDA, ROCm, Vulkan, Metal/CPU variants) and selected at runtime; the Go binary stays free of CGO fragility. The costs are also real: every request crosses an extra HTTP serialisation hop on loopback, runner startup is a process spawn plus a health-poll loop rather than a function call, and some llama-server capabilities (its own API key, its own TLS) are simply not passed through by the parent — the runner listens on loopback with neither, because the parent assumes loopback *is* the security boundary.

On Windows, spawned runners are attached to a Job Object so that terminating the parent cannot orphan GPU-holding children. That detail matters for any fork: runner leaks are VRAM leaks.

### 2.2 Server layout (conceptual)

From the public source structure, the responsibilities divide roughly as follows (described functionally, not as a file listing to copy):

- **Routing layer** — the HTTP route table. Native routes live under `/api/…`; OpenAI routes under `/v1/…` are, importantly, *the same native handlers behind a translating middleware* (see §7.3 — this implementation choice explains several compatibility gaps). Two guards sit in front of every route: a CORS/origin check and, while bound to loopback, an allowed-host check that rejects requests whose Host header is not local (a defence against DNS-rebinding-style browser tricks). Neither guard authenticates a user; there is no local API key system (see §7.5).
- **Scheduler** (`server/sched.go` in the public tree) — owns the set of resident runners, reference counts, the pending-request queue, eviction, and the reload decision when a request's options differ from the resident runner's options.
- **LLM-server abstraction** (`llm/` in the public tree) — a single interface behind which sit the concrete runner implementations: the upstream `llama-server` wrapper for GGUF models, the MLX client for safetensors models on Apple Silicon, and an image-generation path. The scheduler talks only to the interface and never knows which engine is behind it.
- **Discovery** — GPU/device enumeration: vendor, total memory, free memory. Its numbers feed both the context-tier decision (§4.1) and the layer-placement decision (§5.3).
- **Model store** — an OCI/Docker-style content-addressed blob store under the models directory (`~/.ollama/models` on macOS, `/usr/share/ollama/.ollama/models` for the Linux system install, `%USERPROFILE%\.ollama\models` on Windows; relocatable via `OLLAMA_MODELS`), with manifests mapping a human tag to weight blobs, template, parameters and licence layers.

### 2.3 Engine lineage: llama.cpp, the Go-native engine, MLX — and back

This is the section where stale secondary writing is most dangerous, because Ollama has had **three distinct engine eras**. A dossier frozen in any one era misdescribes the others.

**Era 1 — llama.cpp wrapper (July 2023 – late 2024).** Ollama began as, in its first README's own framing, a fast inference server in Go powered by llama.cpp. The integration mechanism flipped several times in the first year alone: compiled in via cgo bindings (v0.0.1), run as a separate server-example process (from v0.0.18, September 2023), linked back in-process as a library (January–April 2024), then returned to subprocess execution (from v0.1.32, April 2024). Throughout, the division of labour was stable: GGML is the tensor library; llama.cpp builds model graphs on GGML; Ollama wraps both with management and serving ergonomics.

**Era 2 — Ollama's own engine, in Go over GGML (late 2024 – May 2026).** The break began with Llama 3.2 Vision (v0.4.0, November 2024), which shipped on an Ollama-written runner, and became a stated strategy with Gemma 3 (v0.6.0, March 2025) and the public announcement of 2025-05-15, "Ollama's new engine for multimodal models." The reasoning given at the time, paraphrased: llama.cpp treated multimodal models as a separate text decoder plus a separate vision encoder glued together by model-specific orchestration code, and that glue was becoming the bottleneck for correctness as multimodal releases accelerated. By calling GGML directly from Go, each model could be a self-contained implementation owning its own projection layer and its own attention peculiarities (the announcement names Gemma 3's sliding-window attention and Llama 4's chunked attention and 2-D rotary embeddings as cases where a faithful per-model implementation mattered, and warns that an approximately-right attention implementation degrades output progressively over long contexts). During this era, newly onboarded model families ran on the Go engine while the long tail of older families continued on llama.cpp beside it. The September 2025 scheduling overhaul (§5.4) initially applied only to new-engine models.

**Era 3 — return to upstream llama-server for GGUF, MLX for Apple Silicon (June 2026 – present, as of this dossier).** On 2026-05-29 a change removing the vendored GGML backend, the CGO runner and the Go model implementations was merged, so that GGUF models are served exclusively by a pinned upstream `llama-server` subprocess (with a small Ollama-side compatibility/patch layer applied at build time); it shipped in v0.30.0 (tagged 2026-06-01) alongside Vulkan becoming enabled by default. Separately, MLX — Apple's array framework — arrived as a preview engine on Apple Silicon in v0.19.0 (March 2026) and became the default engine on Apple Silicon for the architectures it supports in the v0.40.0 line (September 2026), leaving, in the project's own commit language of that period, the MLX runner as effectively the only remaining Go-side inference runner.

**What this means for a fork, stated plainly:** as of 2026-11-15, "Ollama is a wrapper around llama.cpp" is *again* substantially true for GGUF models on Windows and Linux — but by a different mechanism than in 2023 (a pinned, separately built `llama-server` subprocess rather than linked code), and it is *not* true on Apple Silicon for MLX-supported models. Any claim in older tutorials that Ollama's Go engine is the future, or that Ollama merely shells out to llama.cpp, is era-bound. Verify against the tag you actually fork.

*Verification note:* the Era-3 transition is established by the merge record and release history as synthesised in the dated history source in §10, cross-checked against multiple independent October–November 2026 comparisons that agree on the v0.30 return and the MLX default. This dossier did not independently re-read the full v0.40 source tree file-by-file; treat fine-grained claims about which individual model families route to which engine at v0.40.x as **not fully verified** and check the routing code at your fork point.

### 2.4 Platforms and backends

Documented support as of late 2026: macOS, Windows and Linux, plus an official container image. Acceleration paths: NVIDIA via CUDA (documented floor: compute capability 5.0+ with recent drivers; the oldest generations need a newer driver branch), AMD via ROCm on Linux (and historically more constrained on Windows — the FAQ still carries a note that Windows/Radeon defaults to a single loaded model due to VRAM-reporting limits in an older ROCm), Intel and other GPUs via Vulkan (enabled by default since v0.30 where the backend is installed), Apple Silicon via Metal historically and MLX by default now for supported models, and CPU-only execution everywhere. Cross-platform reach is a genuine strength: the same Modelfile, the same API and the same model tag work across all of them, which is precisely the property our own cross-platform law demands.

### 2.5 The cloud appendage

Since August–September 2025 Ollama also operates hosted "cloud models": tags that a signed-in local instance proxies to Ollama's datacentres for models too large for the local machine, later priced per token (tiers announced August 2026). This is architecturally separable — the local server needs no account and no key — but not entirely inert by default: the local server fetches a recommended-models list and the cloud catalogue from ollama.com at startup and periodically thereafter (roughly every four hours), with requests signed by the installation's generated key pair. A documented local-only mode (`OLLAMA_NO_CLOUD=1`, or the equivalent server config flag) disables cloud models, web search and those fetches. A fork that values a quiet network posture should default this off, or at least make the fetches visible; stock Ollama does not surface them in the UI.

---

## 3. Scheduling & batching

### 3.1 The request path

A generation request arrives at the Go server, is translated if it came in on a compatibility route, and is handed to the scheduler. The scheduler resolves the model, then:

1. If a compatible runner for that model (with matching load-time options — see §3.4) is already resident, the request is attached to it.
2. If not, the scheduler must load: it checks whether the model can fit alongside current residents; if memory is insufficient, incoming requests **queue** while resident models are given the chance to go idle and be unloaded to make room. Queued requests are processed in arrival order.
3. Once a runner exists, the request occupies a **slot** (see §3.2) for the duration of prompt evaluation plus generation, streaming tokens back through the Go server to the client.

The queue is bounded by `OLLAMA_MAX_QUEUE`, default **512**; beyond it the server rejects new requests with HTTP 503. Note the precise semantics reported in the source-level history: the bounded queue principally holds requests *waiting for a model to load*; it is not a general admission-control system for generation work.

### 3.2 Slots, not continuous batching

Ollama's concurrency unit is the **slot**: room for one in-flight request, created when the runner starts. `OLLAMA_NUM_PARALLEL` sets slots per loaded model. Its history is itself instructive — concurrency arrived experimentally in v0.1.33 (April 2024) and by default in v0.2.0 (July 2024) with an auto-selected slot count; the auto count was lowered in April 2025; and since v0.10.0 (July 2025) the default is simply **1**, with the project stating the intent that parallelism thereafter be explicit rather than dynamically guessed.

The crucial implementation fact: **a slot costs a whole context window of KV cache.** The runner is started with a total context of `num_ctx × num_parallel`, partitioned among slots. The FAQ's own arithmetic: a 2K window with 4 parallel requests becomes an 8K allocation. Weights are loaded once; only the cache multiplies. This is slot-partitioned serving in the llama.cpp tradition — it is *not* continuous batching in the vLLM sense. There is no global paged block pool shared across requests, no iteration-level admission of new requests into a running batch, and no preemption-and-resume of a running sequence to free memory under pressure. Each slot independently prefills and decodes; total throughput therefore scales far less gracefully than a paged-attention server. Independent measurement on identical hardware and weights (RTX 3090 24 GB, 4-bit Gemma-family 12B, Ollama 0.34.4 vs a paged-attention server, September–October 2026 readings reported in §10) found single-request decode within roughly 10% between the two systems, but aggregate throughput at 16 concurrent requests roughly **3.6× higher** on the paged server. That is the honest shape of the trade: at concurrency 1, Ollama gives up almost nothing; at concurrency 16, it gives up a great deal.

Two slot exceptions are documented in source-level readings: embedding models are forced to a single slot, and a named set of (eleven, at v0.34.4) architecture families — including several vision/multimodal families — are likewise held to one slot regardless of configuration, with a warning logged.

### 3.3 Multi-model residency

The second concurrency axis is how many *different* models may be resident at once: `OLLAMA_MAX_LOADED_MODELS`, default **3 × the number of GPUs** (3 for CPU inference), provided each fits in available memory. On GPU inference, a new model must fit completely in VRAM to load concurrently alongside residents. Residency is reference-counted and keep-alive governed (§5.2); under memory pressure the scheduler's remedy is to wait for, then force, the unloading of idle residents — not to partially evict a busy one.

Multi-GPU placement follows a fit-first rule: if a model fits entirely on any single GPU it is placed there (avoiding interconnect traffic); only a model that fits on no single GPU is spread across all of them. A spread override exists for operators who prefer distribution. The September 2025 scheduling work (§5.4) specifically improved the mismatched-GPU case.

### 3.4 The reload trap: options are part of runner identity

A resident runner is keyed not just by model but by its load-time options, compared by deep equality. `num_ctx` is one of those options. Consequence: two clients alternating between different explicitly-set context sizes for the same model force an **unload–reload cycle on every alternation** — full weight re-read, full KV reallocation, seconds of latency, paid by everyone sharing the host. There is one narrow escape: if *both* the resident runner and the incoming request are using the automatic (unset) context, the request adopts the resident value instead of forcing a reload. The practical law for client authors, and a design smell for fork authors: on a shared Ollama host, either everybody pins the same `num_ctx`, or nobody pins one. A fork should treat context size as a runner *capacity* (allocate a maximum, serve smaller windows inside it) rather than as runner *identity* — see §9.

### 3.5 What Ollama does not schedule

No priorities, no fairness between clients, no per-client quotas, no deadlines, no preemption. The queue is FIFO. For its intended single-user setting this is defensible simplicity; for any shared deployment it is the first thing that must change.

---

## 4. KV cache & context

This is the most consequential section for our fork. Ollama's context handling contains both its best small-machine instincts and its single worst behaviour.

### 4.1 `num_ctx` semantics — and the three disagreeing defaults

`num_ctx` is the size, in tokens, of the context window the runner allocates for a request: system prompt, conversation history, tool definitions, retrieved documents and the response being generated all share this one budget. It is a ceiling fixed when the runner starts, not a meter that grows on demand. The KV cache — two tensors (keys and values) per layer, per KV head — is allocated for the full window up front, which is why the window size *is* the memory decision (arithmetic in §5.5).

What the default is depends on which of Ollama's own surfaces you read — a genuine, verified inconsistency, not a summariser's error:

| Source | Stated default |
| --- | --- |
| Modelfile reference (read 2026-11-15) | 2048 |
| FAQ (read 2026-11-15) | 4096 |
| Context-length docs page + shipping code since Feb 2026 | Tiered by detected VRAM (below) |

The shipping behaviour, established from source at multiple tags: an unspecified-context fallback of 2048 was raised to 4096 in April 2025; then commit of 2026-02-02 (shipped in v0.15.5) replaced the flat default with a **VRAM tier chosen once at server startup**, by summing detected VRAM across devices (minus a per-device overhead allowance):

| Total detected VRAM | Default `num_ctx` |
| --- | --- |
| ≥ 47 GiB | 262,144 |
| ≥ 23 GiB and < 47 GiB | 32,768 |
| < 23 GiB, or CPU-only | 4,096 |

The thresholds sit deliberately just below 48/24 GiB to absorb reporting differences, so a single 24 GB card lands in the 32K tier, while the 6 GB consumer card at the centre of our campaign lands firmly in the **4,096** tier. Two smaller cards sum into a higher tier. The decision is announced exactly once, in a startup log line; nothing in any API response reports it. The ground truth on a running system is the `CONTEXT` column of `ollama ps` (equivalently `context_length` in `GET /api/ps`).

Precedence, highest first: (1) per-request `options.num_ctx` on the native API; (2) a Modelfile `PARAMETER num_ctx` baked into the model name; (3) the server-wide `OLLAMA_CONTEXT_LENGTH` environment variable; (4) the VRAM tier, when none of the above is set. Two clamps apply regardless: the requested window is capped at the model's trained context length as recorded in its GGUF metadata, and floored at a small minimum (with a higher floor, 2048, reported for vision-capable models). Asking for more than the runner can honour is silently reduced, never refused.

One further behaviour, easy to miss: if a load with an *automatic* window fails out-of-memory, the scheduler retries once at the next lower tier (262144 → 32768 → 4096). An *explicitly pinned* window gets no such mercy — the load simply fails. Automatic mode is forgiving but unpredictable; pinned mode is predictable but brittle. Our fork should offer a third option: pinned with declared step-down (see §9).

Finally, Ollama's own current guidance is that workloads needing large context — web search, agents, coding tools — should be set to **at least 64,000 tokens**. Hold that beside the 4,096 default a sub-24 GiB machine actually receives: the gap between the documented recommendation and the shipped default, on exactly the consumer hardware Ollama targets, is the root cause of a large fraction of "the local model is stupid / forgetful" reports in the ecosystem.

### 4.2 Context is per-runner, not per-conversation

There is no server-side conversation object. The native chat endpoint is stateless (§7.2): the client resends the full message array on every turn, the server re-renders the chat template on every turn, and the window is a property of the *runner*, shared by whichever slot the request lands in. Changing `num_ctx` between turns of one conversation therefore means a different runner (§3.4) — the conversation has no continuity the server knows about. Everything that feels like "session memory" in Ollama is an illusion maintained by the client resending history plus the prefix-reuse mechanism of §4.4. This statelessness is clean, portable and fork-friendly — and it is also why the resident-session ideas in §9 are an addition Ollama has deliberately never made.

### 4.3 Overflow: two truncation layers that behave in opposite ways

When the rendered prompt exceeds the window, Ollama does not error by default. It trims — in **two successive layers with opposite treatment of the system prompt**, characterised from Go source at v0.33.1 in the analysis cited in §10. This is the dossier's most load-bearing finding, so it is stated in full.

**Layer 1 — message-level truncation (Go server, before the runner).** If a chat request contains more than one message and its rendered form exceeds the window, whole messages are dropped from the *front* of the conversation. Two protections apply: every message with the system role found in the dropped span is collected and re-prepended, so system messages survive by design; and the final message is always kept. Images, where present, are budgeted at a fixed token allowance each. The event is logged only at debug level, which is below the default log level — on a stock server, layer 1 leaves no trace. It can be disabled with `truncate: false` on the native API (for GGUF models truncation defaults on; readings indicate it is turned off for MLX models).

**Layer 2 — token-level context shift (runner boundary).** If the prompt *still* exceeds the window (limit: `num_ctx − 1`), a context shift discards a contiguous block from the *middle* of the token stream. Only the first `num_keep` tokens are preserved from the head — and `num_keep` defaults to **4** (effectively 5 where the tokeniser adds a beginning-of-sequence token). At this layer the system prompt enjoys no protection at all: beyond its first few tokens, it is discarded along with everything else in the excised block. Worse, the first shift does not free merely the overflow; it frees roughly **half the window**. The limit formula preserves `num_keep` plus about half the remaining window, so at `num_ctx` 4096 a 12,000-token prompt is delivered to the model as its first ~5 tokens plus its last ~2,046 tokens — the middle ~9,950 tokens vanish. The same halving applies at larger windows (≈16,387 tokens survive a first shift at 32K). Layer 2, unlike layer 1, logs at warning level, so the line *is* present in a stock server log — but **no field, header or finish-reason in any API response reports either layer**. The client receives a fluent HTTP 200 answer computed from a prompt it did not send. Layer 2 can be converted into a loud failure with `shift: false` on the native API, which makes an over-long prompt return HTTP 400 instead. Neither `truncate` nor `shift` exists on the OpenAI-compatible schema, so compatibility-route clients cannot even ask for the loud failure (§7.3).

The design verdict is unavoidable: layer 1 is a reasonable, system-preserving policy undermined by debug-only logging; layer 2 is a legacy llama.cpp-era shift policy whose head-preservation (4 tokens) is calibrated for raw completion prompts, not for chat prompts carrying a persona — and the two layers composed together mean the *effective* contract is "your system prompt survives until it suddenly, catastrophically doesn't." For a character-driven workload this is the single most important behaviour to redesign. See §9(b).

### 4.4 Prefix reuse: present, automatic, narrow

Ollama is often described as having "no prefix caching." That is wrong, but the truth is narrower than a modern prefix-cache design:

- Every generation request the Go server sends its `llama-server` runner carries the runner's prompt-caching flag set true. The runner (llama.cpp semantics) compares the incoming prompt with the prompt previously processed *in that slot* and skips re-evaluating the longest common token prefix, evaluating only the differing suffix. Native responses expose the effect indirectly through prompt-evaluation counts and timings (including, in current API readings, a count of prompt tokens served from cache).
- The reuse is therefore **per-slot, last-prompt, exact-token-prefix** reuse. It is not a multi-entry prefix tree, not shared across slots, not shared across models, and not persisted: unloading the runner (keep-alive expiry, eviction, restart) destroys it. Ollama sets none of the underlying server's additional cache-reuse tuning (for example the chunked KV-shift reuse that can salvage partially-matching prefixes); those knobs stay at the bundled server's defaults.
- Historically the flag was coupled to the `shift` option (one boolean doing two jobs); a mid-2026 change decoupled prompt caching into its own optional request field while keeping the default on. Public API documentation lagged the implementation — a recurring Ollama pattern worth noting: the docs are not a complete specification of the server.
- The practical conditions for a hit are strict: same resident runner, same slot, byte-identical rendered prefix. Any change to the system prompt, tool set, template, or an early history edit invalidates everything after it. Append-only conversation discipline (§9(a)) is what turns this narrow mechanism into a large real-world saving: in an append-only chat, each new turn reuses everything except the newest exchange, so prefill cost per turn collapses from O(history) to O(new tokens).

There is no equivalent documented reuse guarantee on the MLX path; treat MLX prefix behaviour as **not verified** by this dossier.

### 4.5 KV-cache dtype and Flash Attention

Two memory levers are exposed server-wide:

- **Flash Attention** is used automatically where the backend and device support it (it moved from opt-in flag to automatic during late 2025); `OLLAMA_FLASH_ATTENTION=1/0` forces it on or off. Beyond speed, it is the gate for cache quantisation.
- **KV-cache quantisation** via `OLLAMA_KV_CACHE_TYPE`: `f16` (default), `q8_0` (about half the cache memory, described by the project as having a very small, usually unnoticeable precision cost), and `q4_0` (about a quarter of the memory, with a small-to-medium precision cost that grows more noticeable at large contexts). The project cautions that models with many grouped-query heads can be more sensitive to cache quantisation. The setting is global, not per-model or per-request — a fork should make it per-model at minimum.

Separately, models whose architectures use local attention (sliding-window or chunked attention) can allocate cache for only a portion of the nominal window on the layers that use it — the new-engine announcement gives Gemma 3's sliding window as the worked example, where faithful per-model attention implementation converts directly into either a larger usable window or more concurrency on the same memory. The general lesson survives the engine change: *cache cost is a property of the attention pattern, not just of `num_ctx`, and a runner that models it per-layer can offer windows a naive allocator cannot.*

---

## 5. Memory management

### 5.1 Loading: memory-mapping by default

Models load through memory mapping unless told otherwise. The load-time options include `use_mmap` (default: mapped — the operating system pages weights in on demand, so only touched pages become resident, load is fast, and a model larger than free RAM can still start) and `use_mlock` (default off — when on, mapped pages are locked against swapping, trading RAM flexibility for latency stability). This pair, inherited from llama.cpp practice, is well judged for consumer machines: first load is cheap, the OS page cache does useful work across runner restarts, and the failure mode of disabling mmap on an oversized model is explicit (it simply will not load if it exceeds RAM). Storage is blob-based (§2.2), so the mapped file is the canonical weight blob itself — no unpack step, no second copy.

### 5.2 Residency: keep-alive semantics

A loaded model stays resident for its keep-alive after the last request: default **5 minutes**, settable globally (`OLLAMA_KEEP_ALIVE`) or per request (`keep_alive` on the native generate/chat/embed routes), as a duration string, a seconds count, `0` (unload immediately after responding), or any negative value (never unload — pin indefinitely). An empty request to the generate or chat endpoint preloads a model without generating, which is the supported warm-up path; `ollama stop` (or a request with `keep_alive: 0`) unloads on demand.

The interaction that matters: **keep-alive is also the prefix-cache lifetime** (§4.4) and the session-continuity lifetime, though Ollama documents it purely as a model-lifetime control. Let a companion-style workload idle past five minutes and the next turn pays full model load (if evicted) and full prompt prefill (always, once the runner is gone). Pinning with a negative keep-alive is the stock workaround, at the cost of permanently holding the VRAM.

### 5.3 GPU offload: fit-first, partial offload as a normal state

Ollama decides layer placement at load: it accounts for weights, KV cache (window × slots) and compute scratch, then places as many layers on the GPU as fit, leaving the remainder on the CPU in system RAM. Partial offload is a first-class, observable outcome — `ollama ps` reports the split in its `PROCESSOR` column (`100% GPU`, `100% CPU`, or a percentage split) — not an error. The per-request/Modelfile lever is `num_gpu`, the number of layers to place on GPU(s); left alone, the scheduler's fit calculation governs. Multi-GPU follows §3.3's fit-on-one rule before spreading.

Partial offload's cost profile must be stated honestly: layers on the CPU are evaluated on the CPU, and token generation — which touches every layer per token — slows roughly in proportion to the CPU-resident fraction, often severely. The current docs' advice ("for best performance… avoid offloading the model to CPU") is correct; the value of partial offload is that an oversized model *runs at all*, not that it runs well.

### 5.4 Memory estimation: from heuristic to measured (new-engine line)

Before September 2025, placement decisions rested on heuristic estimates of a model's memory requirement, and the failure mode was familiar: over-estimation wasted VRAM (layers left on CPU unnecessarily), under-estimation crashed loads. The "New model scheduling" release (2025-09-23) replaced estimation with **measurement** for new-engine models: the engine determines the exact requirement before running, so placement packs the GPU tightly without over-allocating. The project's own worked example, on a single RTX 4090 (24 GB class card), running a 12B Gemma-family model at 128K context: layers on GPU rose from 48/49 to 49/49, VRAM used rose from 19.9 GiB to 21.4 GiB, and generation speed rose from 52.02 to 85.54 tokens/s — a ~64% gain from packing alone, with no change to the model or the maths. A second, two-RTX-4090 image-input example showed prompt evaluation rising from 127.84 to 1,380.24 tokens/s alongside full layer placement, though that figure bundles vision-model placement effects and should not be read as a pure scheduling gain. At the time, models still on the llama.cpp path kept the old estimates; how completely the measured approach survived the 2026 return to `llama-server` (whose own allocator now does the placing) is **not fully verified** from public sources — a fork-point check.

### 5.5 The arithmetic every operator must do

Cache bytes per token ≈ 2 (K and V) × layers × KV heads × head dimension × bytes per element, multiplied by slots. For a Llama-3.1-8B-class model at `f16` that is on the order of 128 KiB per token: ~0.5 GiB at 4K, ~4 GiB at 32K, ~16 GiB at the full 128K the model advertises — *on top of* ~5 GiB of 4-bit weights. This single equation explains most of Ollama's defaults: the 4K tier is what makes an 8B model plus cache fit a 6–8 GB card at all, and `q8_0`/`q4_0` cache quantisation (§4.5) is the difference between a 16K and a 32K usable window on such a card. Any fork UI that exposes `num_ctx` without showing this arithmetic live is repeating Ollama's central usability failure.

### 5.6 Failure behaviour under pressure

When a new model cannot fit, requests queue (§3.1) rather than failing; when a load itself runs out of memory in automatic-context mode, the one-step-down retry (§4.1) applies; resident idle models are evicted to make room for queued loads. Historical over-allocation crashes were the explicit motivation for the 2025 scheduling rework and are reported as significantly reduced for the models it covered. There is no graceful degradation *within* a running generation — no cache shrinking, no slot preemption — so a host that admits a load it cannot sustain discovers it at load time or not at all.

---

## 6. Quantization & formats

### 6.1 GGUF is the native tongue

The library's models ship as **GGUF** — the single-file format from the llama.cpp ecosystem bundling weights, tokeniser and model metadata (including the trained context length that caps `num_ctx`, §4.1). Library tags select size and quantisation together (for example a named size at its default quant, or an explicit quant suffix). The ecosystem's workhorse quant is the 4-bit K-quant family (Q4_K_M is the conventional default recommendation across the llama.cpp world: roughly half the size of 8-bit with modest quality cost), with the full ladder available from near-lossless 8-bit down to aggressive 2–3-bit and importance-matrix variants for those who accept the quality trade. Exact per-tag quant assignments vary by model family and over time; verify on the tag page rather than assuming.

Two import facts matter for a fork:

- **Ollama does not quantise GGUF on import** (current import documentation): you prepare the quant with llama.cpp's quantise tooling, then import the finished file. (An older `ollama create --quantize` path existed for safetensors-sourced models, supporting a small set of output types; the two statements are era- and source-format-specific, and the current docs' position governs GGUF.)
- Hugging Face GGUF repositories can be run directly by reference (`ollama run hf.co/<user>/<repo>`) without authoring a Modelfile — an underappreciated distribution feature.

### 6.2 Safetensors and adapters

A Modelfile's `FROM` can also name a directory of **safetensors** weights for supported architectures (the documented list centres on the Llama, Mistral/Mixtral, Gemma and Phi families), covering both foundation models and fused fine-tunes; on Apple Silicon these are the models that route to the MLX engine. LoRA-style adapters import via `ADAPTER`, in either safetensors (against a matching base; non-quantised adapters recommended, since quantisation schemes differ across training frameworks) or GGUF form (converted with llama.cpp's LoRA converter, against the same base the adapter was trained on). Architecture coverage for direct adapter import is narrower than for fused models — for families outside the list, the fused-model route is the documented path.

### 6.3 The Modelfile system

The Modelfile is a small declarative, case-insensitive instruction file — the packaging layer that turns "weights" into "a named, configured model." Instructions (current reference, read 2026-11-15):

- `FROM` (required) — an existing model name/tag, a GGUF file (absolute path, Modelfile-relative path, or a wildcard matching split shards), or a safetensors directory.
- `PARAMETER` — default run parameters, overridable per request. The surface includes: `num_ctx`, `num_predict` (generation cap; default −1, unbounded), `num_keep` (§4.3), `temperature` (default 0.8), `top_k` (40), `top_p` (0.9), `min_p`, `seed`, `stop` (repeatable), `repeat_last_n` (64), `repeat_penalty` (the documented default has itself moved over time — 1.1 historically, 1.0/off in current docs and, since an August 2026 release, in the sampler default for models that set none; another small lesson in pinning behaviour explicitly), plus load/hardware options exposed through the API options object rather than the Modelfile table: `num_gpu`, `num_thread`, `use_mmap`, `use_mlock`, NUMA toggles, and newer speculative-decoding controls such as a draft-token count where a draft model or embedded multi-token-prediction tensors are available.
- `TEMPLATE` — the full chat template, in Go template syntax, with system/prompt/response variables. The template is part of the model package, which is why the same weights can behave as different products.
- `SYSTEM` — a baked-in system message.
- `MESSAGE` — baked-in example history (system/user/assistant roles) for few-shot steering.
- `ADAPTER` — an adapter to layer over the `FROM` base (§6.2).
- `LICENSE` — licence text carried with the package.
- `REQUIRES` — minimum Ollama version.
- `CAPABILITY` — declares an additional capability for a GGUF/MLX model (current reference gives the decision-model capability as the example).

`ollama create <name> -f Modelfile` builds the package into the blob store; `ollama show --modelfile <model>` prints any model's effective Modelfile, which is the fastest audit tool in the ecosystem. The design lesson is strong: **configuration travels with the artifact.** The corresponding weakness: because a Modelfile parameter is part of runner identity (§3.4) and of model identity, "the same model with a bigger window" is a *different named model* — the ecosystem's standard workaround for the OpenAI-route `num_ctx` gap (§7.3) is to mint `mymodel-32k` variants, and registries fill with window-size clones of identical weights.

### 6.4 What is not exposed

No per-layer quantisation control, no mixed-precision authoring, no KV-cache type in the Modelfile (it is a server-global environment setting, §4.5), no way to declare a memory budget or a priority in the package. The parameter surface is a *generation* surface; the *resource* surface lives in environment variables and per-request options, split across three places with the precedence quirks of §4.1.

---

## 7. API & session handling

### 7.1 The native API

One HTTP server, default `127.0.0.1:11434` (rebindable via `OLLAMA_HOST`; the official container image binds all interfaces — see §7.5). The API is not strictly versioned; the project commits to backwards compatibility with deprecations announced in release notes. Principal routes:

- **Generation:** `POST /api/generate` (single prompt string; streaming by default, newline-delimited JSON), `POST /api/chat` (message array with roles; supports tools, structured output via `format` as `json` or a JSON schema, a `think` control for reasoning models, `options`, `keep_alive`, `truncate`, `shift`).
- **Embeddings:** `POST /api/embed` (input as a string or list of strings; optional truncation control, dimensions, `keep_alive`, `options`) — the current endpoint, superseding the older `/api/embeddings`.
- **Model management:** `POST /api/pull`, `POST /api/push`, `POST /api/create`, `POST /api/copy`, `DELETE /api/delete`, `GET /api/tags` (local models), `POST /api/show` (full model information including Modelfile, parameters, template, capabilities), `GET /api/ps` (resident models with size, VRAM size, context length and expiry), `GET /api/version`. An empty generate/chat request preloads a model (§5.2).
- **Responses carry their own telemetry:** total duration, load duration, prompt-evaluation count and duration (with cache-served prompt tokens distinguished in current readings), generated-token count and duration. This is genuinely good design — every response is a small benchmark — and it is the only sanctioned way to *detect* prefix reuse and, indirectly, window problems (a prompt-evaluation count that stops growing as your prompt grows is the truncation tell).

Official Python and JavaScript client libraries wrap this API; a large third-party SDK ecosystem wraps it again.

### 7.2 Statelessness and the `context` parameter lineage

The server keeps **no session state** (§4.2). The lineage of the one apparent exception is worth recording because tutorials still teach it:

- The original `/api/generate` design returned a `context` field: an opaque array of token IDs encoding the conversation so far, which the client passed back on the next request to continue without resending text. It was, in effect, a client-carried KV handle.
- As the chat endpoint (which resends explicit `messages`) became canonical, the token-array mechanism was deprecated: current API readings mark the generate `context` field **deprecated**, and the chat endpoint never adopted it — chat history is the message array, re-rendered and re-truncated (§4.3) on every call.
- The modern continuation cost is therefore paid in re-rendering plus prefix reuse (§4.4), not in server-side session objects. A fork that wants true resident sessions (§9(a)) is consciously reversing this design decision and should understand what it buys back: Ollama's statelessness is why any client, in any language, with nothing but the message log, can pick up a conversation on a fresh server with zero migration.

### 7.3 The OpenAI-compatible layer — a subset with one structural hole

Under `/v1`: chat completions, text completions, embeddings, model listing, and a Responses route (added in the v0.13.x line; stateless form only — no server-side previous-response chaining). Chat completions support streaming, JSON mode, reproducible-output seeding, base64 vision input, tool calling and reasoning controls. Documented non-support includes, among others: `logprobs` (listed as unsupported in the compatibility docs; some secondary readings differ by version — treat as version-sensitive), `tool_choice`, `logit_bias`, the `user` field, `n > 1`, and image URLs (base64 only).

The structural hole is context control. Implementation fact (§2.2): the `/v1` routes are the native handlers behind a translating middleware whose request type has **no `num_ctx`, `truncate` or `shift` field at all**. A client that sends them has them silently discarded during JSON decoding — not rejected, not defaulted by the server with malice, simply never seen; the middleware forwards only a small fixed set of generation options (stop, max-tokens→`num_predict`, temperature, seed, frequency/presence penalties, top-p). Every `/v1` request therefore runs at the automatic/Modelfile/server-env window (§4.1), cannot request loud failure on overflow, and receives no truncation signal. Ollama's own compatibility documentation acknowledges the missing context-size control and prescribes the Modelfile workaround. A community request for a context parameter on this route has been open since 2024, and a pull request forwarding `num_ctx` was opened in June 2026 and remained unmerged in the readings available to this dossier. For the large population of tools that speak only OpenAI dialect (coding agents prominently among them), this is Ollama's most consequential compatibility defect — it converts the §4.1 default-window problem from "configurable" to "invisible."

An Anthropic-compatible Messages route (`/v1/messages`) arrived in v0.14.0 (January 2026), supporting messages, streaming, system prompts, tools, vision and thinking, with `tool_choice` again among the unsupported pieces. A further specialised route for "decision" models (returning choices/probabilities/scores rather than text) appeared in v0.35.0 (September 2026); it is noted here for completeness as evidence of surface-area growth, not analysed further.

### 7.4 Streaming, tools, structured output

Native streaming is newline-delimited JSON objects ending in a final object with `done` set and the telemetry of §7.1; the compatibility layers stream in their dialects' server-sent-event forms. Tool calling (July 2024) works on both native and OpenAI routes; structured outputs (December 2024) constrain generation to a JSON schema via `format`. Thinking-model control (`think`, May 2025) exposes reasoning traces where the model supports them. These are competently implemented and broadly compatible — the API surface is not where Ollama is weak, except for §7.3's hole and §7.5.

### 7.5 Security posture: loopback is the authentication

The local API **requires no authentication** — documented, deliberate, and defended by the maintainers on the record (February 2025: no near-term plan for a server API-key system; use a VPN or a reverse proxy). The mitigations are the loopback default bind, the origin check and the Host-header check (§2.2). The exposure record shows how that posture ages: a severe model-download path flaw (CVE-2024-37032, disclosed June 2024; fixed within days of report, but described by its researchers as especially dangerous in container installs, where the server runs as root and the image binds all interfaces by default) and a January 2026 internet scan by security researchers counting on the order of 175,000 publicly reachable Ollama hosts across 130 countries, nearly half with tool-calling enabled — each one configuration change away from its owner. The underlying `llama-server` supports API keys and TLS; Ollama passes neither through. For our fork this is a clear, evidence-backed mandate: authentication and TLS are first-class, on by default for any non-loopback bind, and the container image must not silently widen the bind.

---

## 8. Strengths / weaknesses

### Strengths (evidence-tied)

1. **Zero-to-tokens ergonomics that defined a category.** One install command, one `run` command, automatic device detection, automatic layer placement, a curated library. The Docker-style mental model (pull / run / ps / rm, Modelfile as Dockerfile) transferred an existing skill set wholesale. Adoption evidence: the repository passed ~180,000 stars by autumn 2026, and Ollama became the default backend other tools test against first.
2. **Packaging discipline.** Weights + template + parameters + system prompt + licence as one named, content-addressed artifact (§6.3) makes configurations reproducible and auditable (`ollama show --modelfile`) in a way ad-hoc GGUF folders never are.
3. **Honest partial offload.** Models too big for the GPU still run, with the split printed in `ollama ps` (§5.3). On consumer hardware this "runs slowly" beats "does not run" for most users most of the time.
4. **Measured memory placement (new-engine line).** The 2025 exact-measurement scheduling produced large, published, hardware-specified gains (52.02 → 85.54 tok/s on an RTX 4090 in the project's own example, §5.4) purely from packing — proof the team optimises the right layer when it focuses.
5. **Small, stable, dialect-rich API.** Native + OpenAI + Anthropic surfaces, per-response telemetry, streaming, tools, structured output (§7). The backwards-compatibility commitment has largely held since 2023.
6. **Cache-economy levers exist.** KV quantisation to ~½ / ~¼ memory (§4.5), automatic Flash Attention, mmap loading (§5.1) and prefix reuse (§4.4) are all present and, when configured, effective.
7. **Permissive licence, portable implementation.** MIT throughout the stack, Go control plane, per-accelerator runner binaries, macOS/Windows/Linux parity (§2.4).

### Weaknesses (evidence-tied)

1. **Silent prompt truncation, in two layers, unreported to the caller** (§4.3). The gravest defect. Layer 2 preserves 4 head tokens and frees half the window; no response field discloses either layer. For persona-carrying and records-sensitive workloads this is disqualifying without the native-API `shift: false` workaround — which the compatibility route cannot even express.
2. **Default window vs documented need.** 4,096 tokens by default on all sub-24 GiB hardware while the project's own guidance demands ≥64,000 for agents/coding (§4.1); three official surfaces state three different defaults. Users blame models for a server policy.
3. **The OpenAI route discards context control entirely** (§7.3) — by implementation structure, not by policy statement — and the fix has sat unmerged while the ecosystem standardised on that route.
4. **Slot-partitioned concurrency does not scale** (§3.2): a whole window of KV per slot, no paged sharing, no continuous batching, no preemption; ~3.6× aggregate-throughput deficit at concurrency 16 in independent same-hardware readings. Correct for one user; a ceiling for any team deployment.
5. **Options-as-identity reload thrash** (§3.4): alternating `num_ctx` values unload and reload the model per request.
6. **No authentication, no TLS, dangerous container default** (§7.5), with a measured six-figure population of exposed instances as the consequence.
7. **Documentation lags and contradicts the code** as a pattern, not an accident: the 2048/4096/tiered defaults (§4.1), prompt-caching fields shipped before they were documented (§4.4), defaults (slots, repeat penalty) changed in releases without the FAQ following. Operators cannot trust the docs as a specification.
8. **Engine churn.** Three engine eras in three years (§2.3) stranded optimisations (measured scheduling initially new-engine-only), reintroduced previously-fixed classes of bugs during the Go-engine period according to contemporary comparisons, and make any dated tutorial suspect. Stability of the *interface* was preserved; stability of the *implementation* was not.
9. **Global, not per-model, resource policy.** KV-cache type, Flash Attention forcing and keep-alive defaults are server-wide environment settings (§4.5, §5.2); a host serving a chat model and an embedding model cannot give them different cache economies without separate processes.
10. **Default network chatter** (§2.5): periodic signed fetches to the vendor by a nominally local tool, off only via an opt-out flag most users will never find.

---

## 9. IDEAS TO STEAL — for our improved-Ollama work

Each idea is marked with the problem it addresses (per the campaign's four target concerns), expected gain, and cost/risk. Gains are judgement estimates grounded in the mechanisms documented above, not measurements; they are labelled as such.

### (a) Resident sessions / no reprocessing of resident context

**A1. Promote the conversation to a server-side session object.** Give a session an ID, hold its rendered token prefix and KV state in the runner across turns, and let clients send only the new turn. Ollama today resends, re-renders and re-truncates the whole history per turn and recovers the cost only through per-slot last-prompt prefix reuse (§4.2, §4.4).
*Expected gain:* prefill per turn falls from O(history) to O(new tokens) *guaranteed*, not conditionally; template-render and truncation bugs stop being per-turn risks; enables everything in (b). For a long companion conversation at 16–32K of history, this is the difference between seconds of prefill per reply and near-zero. *Cost/risk:* statefulness reintroduces everything Ollama's statelessness avoided — session expiry, migration, multi-client ownership, crash recovery. Mitigate by making sessions an *optimisation layer over* the stateless API: a session is a cache of a message log the client still owns and can replay to rebuild it.

**A2. Widen prefix reuse from last-prompt-per-slot to a multi-entry prefix cache.** Keep several recent prefixes (hashed by token sequence, LRU-evicted), shared across slots for the same model, with reuse reported per response (tokens reused / tokens evaluated).
*Expected gain:* multi-branch clients (retries, regenerations, tool loops that fork) stop paying full prefill per branch; shared system prompts across concurrent users are computed once. *Cost/risk:* KV blocks for cached prefixes consume the scarcest resource (VRAM); needs the block accounting of C2 below. llama.cpp's own chunked KV-shift reuse shows partial-prefix salvage is feasible in this engine family.

**A3. Persist hot KV across runner restarts (disk-backed prefix store).** Serialise the KV for a named session's stable prefix to fast local storage at unload; reload it instead of re-evaluating on the next session open.
*Expected gain:* removes the cold-start prefill cliff after keep-alive expiry or reboot — for a 32K persona-plus-history prefix, seconds-to-tens-of-seconds per cold open (hardware-dependent). *Cost/risk:* KV tensors are large (use the §5.5 arithmetic: ~4 GiB for 32K at f16 on an 8B-class model; quantised cache types shrink this proportionally), version-fragile across model/runner changes, and must be invalidated on any prefix change. Store quantised, checksum against model blob + template hash.

**A4. Decouple model lifetime from session lifetime.** Ollama fuses them (§5.2): unload the model and the conversation's computed state dies. Hold session KV in system RAM (or in the A3 store) independently, so model eviction for a second model does not destroy the first model's sessions.
*Expected gain:* multi-model hosts (chat + embeddings + a second persona) stop thrashing each other's context. *Cost/risk:* RAM pressure and a more complex scheduler; requires the scheduler to reason about two resources (weights residency, session residency) instead of one.

### (b) A character anchor that cannot be pushed out

**B1. Pin the anchor as a distinct, non-truncatable segment.** Replace Ollama's two accidental layers (§4.3) with an explicit segment model: a request is `[anchor][history][new]`, where the anchor segment (persona/system) is declared pinned. Truncation policy applies to history only, oldest-first, and the anchor is *never* subject to token-level shift: `num_keep` becomes "the whole anchor," not 4 tokens.
*Expected gain:* eliminates the catastrophic failure mode in which a long conversation silently amputates the persona to 5 tokens — the exact failure our workload cannot tolerate. This is the highest-value single change in this dossier relative to its cost. *Cost/risk:* a pinned anchor permanently consumes window; cap anchor size (e.g. ≤ 25% of window) and reject oversize anchors loudly at session creation.

**B2. Fail loudly, always, and report in-band.** Any truncation, shift, or window clamp returns structured disclosure in the response (segments dropped, tokens dropped, effective window), on *every* route including compatibility routes (as an extension field where the dialect allows, and via response headers where it does not). Default `truncate`/`shift` equivalents to *error* for pinned-anchor sessions.
*Expected gain:* converts a silent integrity failure into an observable, alertable event; client UIs can warn the user instead of gaslighting them. *Cost/risk:* breaks clients that assume any 200-shaped success; gate behind session type, not globally.

**B3. Anchor-aware middle management.** When history must shrink, summarise-or-drop whole turns (layer-1 style, system-preserving) before ever touching tokens inside a turn; never excise the middle of a rendered prompt (layer-2 style) in chat mode. Reserve token-shift for raw completion mode, where it was born.
*Expected gain:* degradation becomes graceful and semantically coherent (older turns fade; the current exchange and the persona remain intact). *Cost/risk:* whole-turn dropping loses information in larger units; a rolling summary segment (itself pinned, second tier) softens this at the cost of a summarisation call.

**B4. Budget the window in the open.** Session creation takes an explicit allocation — anchor tokens, reserved generation tokens, history tokens — and the server rejects or renegotiates allocations that do not fit, instead of Ollama's allocate-then-silently-trim.
*Expected gain:* capacity planning becomes deterministic on a known card (see C1); no runtime surprises. *Cost/risk:* more API surface; keep a zero-config default path that derives the budget from the VRAM tier.

### (c) Memory efficiency on a 6 GB consumer GPU

Context: a 6 GB card sits in Ollama's bottom tier (4,096 window, §4.1). A 7–8B model at Q4_K_M (~4.5–5 GiB) plus a 4K f16 cache (~0.5 GiB, §5.5) plus compute scratch barely fits — which is why the tier exists. The headroom must come from the cache and from packing, not from wishing.

**C1. Default to quantised KV on small cards: `q8_0` below a VRAM threshold, `q4_0` as an explicit economy mode.** Ollama ships both but defaults to f16 everywhere (§4.5).
*Expected gain:* q8_0 halves cache cost — the same 6 GB card affords ~8K instead of ~4K at equal quality risk the project itself calls usually unnoticeable; q4_0 affords ~16K with a more real, context-dependent quality cost. This is the cheapest large win available: pure policy, no new code paths. *Cost/risk:* cache quantisation requires Flash Attention support on the backend; quality impact grows with grouped-query-head count and context length — expose it per model, not globally (fixing weakness §8.9 at the same time).

**C2. Allocate KV in blocks against actual use, not window × slots up front.** Ollama reserves the full window per slot at runner start (§3.2), so a 4-slot 32K configuration reserves 128K of cache even if every conversation is 3K long. A block allocator that grows a session's cache as it actually fills (the paged-attention lesson, adapted to llama.cpp-family kernels) converts reserved-but-unused cache into usable window or usable slots.
*Expected gain:* on the 6 GB card, the practical effect is one *real* 12–16K session instead of four reserved 4K slots nobody uses — or the same session plus an embedding model resident. Judgement estimate: 2–4× effective context capacity at low concurrency. *Cost/risk:* this is the deepest surgery in the list; it touches the runner's allocator. A cheaper approximation captures much of it: start slots at a small window and *grow the runner* (restart with a larger allocation only when a session actually approaches its cap, preserving KV via A3-style serialisation).

**C3. Exploit attention-pattern-aware allocation.** Charge each layer's cache according to its real pattern (full vs sliding-window vs chunked), as Ollama's own new-engine work demonstrated for Gemma-class sliding windows (§4.5).
*Expected gain:* model-dependent; for sliding-window-heavy architectures the saving is a large fraction of nominal cache at long windows — potentially the difference between fitting and not fitting at 16K on 6 GB. *Cost/risk:* requires per-architecture correctness; an approximately-right attention implementation degrades output progressively (the new-engine announcement's own warning). Implement per model family with parity tests, or not at all.

**C4. Steal the measured-placement scheduler.** Replace heuristic memory estimation with pre-load measurement of the exact requirement (weights + cache + scratch), as in the September 2025 rework (§5.4), and use the recovered slack for one more GPU layer or a larger window.
*Expected gain:* the project's own published example gained ~64% generation speed from packing alone on a 24 GB card; on a 6 GB card the same precision is what decides whether the last layers spill to CPU — and CPU spill is the steepest speed cliff in the system (§5.3). *Cost/risk:* measurement must be per-(model, window, slots, cache-type) and cached; stale measurements after driver/backend changes must self-invalidate.

**C5. Make the small-card defaults coherent.** On a <8 GiB card: one slot, quantised KV, mmap on, pinned model for the active session (negative keep-alive scoped to the session, not forever), and a window chosen from the §5.5 arithmetic *for the specific model* — shown to the user as a number with its cost, not hidden in a startup log line.
*Expected gain:* removes the two stock small-card failure modes (mystery 4K truncation; second-model load evicting the first mid-conversation). *Cost/risk:* policy complexity; encode as a named "small-GPU profile" so it is one decision, not six.

### (d) Speed

**D1. Protect the prefix, reap the prefill.** The largest speed lever for conversational workloads is not decode optimisation; it is not re-evaluating history (A1/A2). Append-only discipline on the client (never mutate an early message; corrections go in new turns) keeps hit rates near-total.
*Expected gain:* for a 20K-token history with a 300-token new turn, prefill work falls by ~98% on cache hit — judgement arithmetic from §4.4's mechanism, consistent with the order of magnitude in the scheduling blog's prompt-evaluation example. *Cost/risk:* none at the protocol level; requires client cooperation and honest per-response reuse reporting to verify.

**D2. Keep the model fully GPU-resident or accept the cliff knowingly.** Every layer spilled to CPU taxes every generated token (§5.3). On small cards prefer, in order: quantised KV (C1) to buy back VRAM, then a smaller quant of the *weights*, before accepting layer spill.
*Expected gain:* avoiding even a small CPU-resident fraction typically matters more than any sampler or batching tweak; treat `ollama ps`'s processor split as a performance alarm, as the current docs themselves advise. *Cost/risk:* lower weight quantisation costs output quality; make the trade visible per model.

**D3. Speculative decoding where the architecture offers it.** Current Ollama exposes draft-token controls for separate draft models and for embedded multi-token-prediction tensors (§6.3). On a memory-bandwidth-bound consumer GPU, a good draft path is one of the few remaining large decode multipliers.
*Expected gain:* workload-dependent; judgement estimate 1.3–2× decode on draft-friendly (predictable, low-entropy) text, near 1× on high-entropy text. *Cost/risk:* draft weights consume the same scarce VRAM (see C-budget); acceptance-rate telemetry is essential to avoid shipping a slowdown disguised as a feature.

**D4. Remove reload thrash from the hot path.** Treat window size as capacity, not identity (§3.4): one runner allocated at the session's declared maximum serves all smaller requests; differing sampler options never force a reload (they are per-request already — keep them that way); differing windows queue onto the resident runner instead of replacing it.
*Expected gain:* eliminates multi-second reload stalls in mixed-client deployments entirely. *Cost/risk:* the resident runner holds the maximum window's cache reservation — pair with C2's grow-on-demand allocation to avoid paying it idly.

**D5. Keep the subprocess, cut its ceremony.** Retain Ollama's crash-isolating runner subprocess (§2.1) but replace per-request HTTP proxying of tokens with a shared-memory or pipe transport for the completion stream, and replace health-poll startup with an explicit readiness signal.
*Expected gain:* judgement estimate: small per-token latency savings, meaningful time-to-first-token savings on runner start (poll intervals are coarse). *Cost/risk:* platform-specific transport code across Windows/macOS/Linux/ARM — spend this only after D1–D4, which are larger and portable.

**D6. Batch the prefill you cannot avoid.** When prefill is unavoidable (cold session, document ingestion), ensure the runner processes it in large batches with Flash Attention on, and schedule ingestion as one request rather than many small ones (each small request re-pays fixed costs and, on the compatibility route, risks independent truncation).
*Expected gain:* prompt-evaluation throughput is batch-sensitive by an order of magnitude in the project's own published example (§5.4); treat that figure as an upper bound bundling other effects. *Cost/risk:* large-batch prefill spikes scratch memory — on 6 GB, cap batch size by the C4 measurement, not by a constant.

### Cross-cutting steals (not in the four target areas, too good to omit)

- **Per-response telemetry as a first-class contract** (§7.1) — copy it, extend it with reuse and truncation disclosure (B2).
- **Configuration travels with the artifact** (§6.3) — keep the Modelfile idea; add resource declarations (window budget, cache type, anchor policy) to the package so a model *means* the same thing on every host, fixing the tier-portability hazard in which identical packages silently run at 4K on one site and 256K on another (§4.1).
- **Auth and TLS on by default for any non-loopback bind** (§7.5) — the negative lesson, learned from Ollama's exposure record at no cost to us.
- **Pin every default in the package or the session, and version the defaults themselves.** Ollama's history (§8.7, §8.8) shows defaults are API: they change behaviour under existing users. A fork should treat a default change as a breaking change, announced and logged at startup *and* per response until acknowledged.

---

## 10. Sources

All sources accessed 2026-11-15 unless a different reading date is stated in the text. Primary sources are Ollama's own; secondary source-level analyses are used only where they read the public source at a named tag, and are marked as such.

**Primary — Ollama documentation and site**

1. Ollama Local FAQ — docs.ollama.com/faq. Read 2026-11-15. Source for: 4096 stated default and `OLLAMA_CONTEXT_LENGTH`; `ollama ps` processor split; preload and `keep_alive` semantics (5-minute default, `0`, negative pin); `OLLAMA_MAX_QUEUE` default 512 and 503 behaviour; concurrency model (`OLLAMA_MAX_LOADED_MODELS` default 3 × GPUs, `OLLAMA_NUM_PARALLEL` default 1, memory scaling as parallel × context); single-GPU-fit placement rule; Flash Attention forcing; `OLLAMA_KV_CACHE_TYPE` (`f16` default, `q8_0` ≈ ½ memory, `q4_0` ≈ ¼ memory, Flash-Attention gate, GQA sensitivity note); model storage locations; loopback bind and `OLLAMA_HOST`.
2. Ollama Context length — docs.ollama.com/context-length (page updated 2026-11-12). Read 2026-11-15. Source for: context defined as maximum tokens in memory; ≥64,000-token recommendation for web search, agents and coding tools; larger context costs more memory; verify via `ollama ps`. (The VRAM tier table itself is stated on this page per multiple concordant secondary readings and the shipping code; the text fetch available to this dossier rendered the page without its tier table — see verification note below.)
3. Ollama Modelfile reference — github.com/ollama/ollama, docs/modelfile.mdx. Read 2026-11-15. Source for: instruction set (`FROM`, `PARAMETER`, `TEMPLATE`, `SYSTEM`, `LICENSE`, `MESSAGE`, `REQUIRES`, `CAPABILITY`); parameter table and defaults as printed there (including the stale `num_ctx` default of 2048 and `repeat_penalty` default of 1.0); GGUF and safetensors `FROM` forms including split-GGUF wildcards; Go template syntax.
4. Ollama README — github.com/ollama/ollama. Read 2026-11-15. Source for: positioning, install routes, REST API existence, Python/JavaScript libraries, and the "Supported backends: llama.cpp" credit.
5. Ollama blog, "Ollama's new engine for multimodal models" — ollama.com/blog/multimodal-models, 2025-05-15. Read 2026-11-15. Source for: prior reliance on llama.cpp; rationale for the Go-over-GGML engine (per-model self-containment, own projection layer); accuracy concerns (image batching, positional metadata); image caching; per-model causal-attention configuration; Gemma 3 sliding-window and Llama 4 chunked-attention / 2-D RoPE examples.
6. Ollama blog, "New model scheduling" — ollama.com/blog/new-model-scheduling, 2025-09-23. Read 2026-11-15. Source for: estimation → exact measurement; reduced OOM crashes; multi-GPU and mismatched-GPU improvements; `nvidia-smi` / `ollama ps` agreement; worked examples (RTX 4090, 12B Gemma-family at 128K: 52.02 → 85.54 tok/s, 48/49 → 49/49 layers, 19.9 → 21.4 GiB; dual-RTX-4090 image input: 127.84 → 1,380.24 tok/s prompt evaluation, 43.15 → 55.61 tok/s generation); initial applicability to new-engine models, with the supported-model list as of that date.
7. Ollama blog index — ollama.com/blog. Read 2026-11-15. Source for: dating of the new app (2025-07-30), cloud models, web search, and later MLX-era announcements used in the timeline.

**Secondary — source-level analyses at named tags (used for code behaviour docs do not state)**

8. "Ollama num_ctx: Why Long Prompts Get Silently Truncated" — particula.tech, published 2026-08-27; analysis read from Go source at tag v0.33.1 (released 2026-08-26). Read 2026-11-15. Source for: VRAM-tier commit (2026-02-02) and thresholds (47/23 GiB, overhead subtraction, startup log line); `num_ctx` precedence and clamps; OpenAI-middleware field dropping (no `num_ctx`/`truncate`/`shift` in the decoded request type; at most seven forwarded options); layer-1 message truncation (system re-collection, last-message protection, 768-token image allowance, debug-only logging, inconsistent kept/dropped log fields); layer-2 context shift (`num_keep` 4/5, half-window free, worked 12,000→2,051 example at 4K, warning-level log, 400 with `shift: false`); slot context multiplication; reload deep-equality and the automatic-context escape; automatic-window OOM step-down (262144 → 32768 → 4096) and its absence for pinned windows.
9. "A short history of Ollama" — research.strata2signal.com, published 2026-10-02, updated 2026-10-08; every claim read 2026-09-30 / 2026-10-01 from Ollama's blog, release notes, documentation and source at named tags (principally v0.34.4, checked against v0.35.0). Read 2026-11-15. Source for: engine timeline (cgo → subprocess → library → subprocess → own engines → llama-server at v0.30.0 via the 2026-05-29 merge; MLX preview v0.19.0 and default in the v0.40.0 line); defaults timeline (concurrency 2024–2025, window 2048 → 4096 → tiered, Flash Attention to automatic, repeat penalty 1.1 → 1.0 in August 2026); `cache_prompt: true` on generation requests and the absence of prompt-cache flag tuning; queue semantics; no-auth posture, maintainer statements (February 2025), container bind behaviour, CVE-2024-37032 summary, January 2026 exposure scan (~175,108 hosts); periodic signed fetches and local-only opt-outs; same-hardware Ollama-vs-paged-server readings (RTX 3090 24 GB, ~10% single-request decode gap, ~3.56× aggregate gap at concurrency 16) from its companion bench page as summarised therein.
10. Runner/scheduler architecture readings — DeepWiki's Ollama runner pages and a v0.30.8-grounded runner walkthrough (github.com/rumitvn/ollama-book), surfaced and read 2026-11-15. Source for: runner subprocess mechanics (per-accelerator binary selection, private loopback port, health polling, log-derived placement reporting), the scheduler-to-runner interface, Windows Job Object supervision, and the post-v0.30 routing (GGUF → llama-server; safetensors → MLX/image paths).
11. Prompt-caching mechanics note — github.com/Aswanidev-vs/Mai, research findings on Ollama/llama.cpp `cache_prompt` (2026). Read 2026-11-15. Source for: `cache_prompt` decoupling change (June 2026) and default-on behaviour; documentation lag on the field; keep-alive as the practical cache-lifetime control.
12. Concordant October–November 2026 comparisons and guides (LM Studio / vLLM / llama.cpp comparisons; `OLLAMA_NUM_PARALLEL`, context-length and API references) surfaced in search and read 2026-11-15. Used only to cross-check the v0.30 return to llama-server, the MLX default, the `/v1` endpoint inventory (including the stateless Responses route and the Anthropic Messages route), the `/api/embed` supersession of `/api/embeddings`, and the deprecation of the generate `context` field. No load-bearing claim in this dossier rests solely on these.

**Verification limits (explicit)**

- The VRAM tier values, thresholds and precedence are established by source 8 (code at v0.33.1) and source 9 (code at v0.34.4) agreeing with each other and with the context-length page as quoted by multiple independent readings; this dossier's own text fetch of that page rendered without the tier table, so the table is verified at one remove (code + concordant quotation), not by direct sight of the live page.
- Engine routing per model family at v0.40.x, and the survival of measured (§5.4) scheduling into the llama-server era, are **not fully verified** — see §2.3 and §5.4.
- MLX-path prefix reuse and truncation behaviour are **not verified**; §4.3/§4.4 describe the GGUF/llama-server path, with the MLX truncation exception noted from source 9.
- No benchmarks were run for this dossier. Every number herein is a reported number with its hardware context, from sources 6 and 9 principally.
