# OR-2 Deep-Dive Addendum — Ollama's Own Internals: Scheduling, Memory Estimation, and Context Handling

**Campaign:** Ollama Research Forge (commissioned by Volmarr, 2026-11-15)
**Document:** OR-2, paired reading of the Ollama Memory Forge's own base codebase
**Companion dossiers:** `runners/ollama.md` (architecture-level, pinned to v0.33.1–v0.35.0 readings) and `runners/llamacpp-kv-internals.md` (llama.cpp tag v1.0.0, wave 29)

**Clean-room statement:** This dossier describes design and behaviour in our own words, from reading Ollama's public source. No source code is reproduced. The only verbatim material is short factual labels: parameter names, environment-variable names, endpoint paths, version numbers, file and component names, and log-message topics.

---

## 1. Identity and version stamp

| Field | Value |
|---|---|
| Project | Ollama (ollama/ollama) |
| Release read | **v0.40.16**, published 2026-11-09 |
| Date of reading | **2026-11-15** |
| Fleet version (campaign records) | 0.40.16 on purpleraider |
| Delta, fleet vs. current stable release | **Zero.** The fleet version *is* the current stable release at the date of reading. |
| Newer code in the repo | A pre-release, v0.40.17-rc0 (2026-11-10), exists. It is not the reading target; where its release notes were visible they are flagged as pre-release evidence only. |
| Primary files read in full or in load-bearing part | `server/sched.go`, `server/routes.go`, `server/prompt.go`, `llm/server.go`, `llm/llama_server.go`, `envconfig/config.go`, `api/types.go` |

Everything below is stated about v0.40.16 unless explicitly marked otherwise. Where a claim from the earlier `runners/ollama.md` dossier could not be re-verified at this tag, it is marked **unverified** rather than repeated as fact.

### 1.1 What changed since the banked architecture dossier

The banked dossier flagged two open questions: whether the new-engine "measured scheduling" survived into the v0.40.x line, and how GGUF requests are routed now that the engine inversion completed. Both are answered from source in §3 and §4 below. The short version:

- For GGUF models, Ollama at v0.40.16 is a **Go control plane wrapped around a pinned upstream llama-server subprocess**. Its own pre-load memory number is a deliberately rough heuristic; real measurement happens *after* the subprocess starts, by parsing the subprocess's log output.
- Layer placement — the decision the Memory Forge cares most about — is **not made by Ollama at all** on the default path. It is delegated to llama.cpp's own fit machinery inside the subprocess.
- The two-layer silent-truncation finding from the banked dossier **still holds**, with three corrections detailed in §5.3.

---

## 2. Architecture today (v0.40.16)

### 2.1 The three serving paths

Reading the scheduler and the runner-construction code, a model request at v0.40.16 is served by exactly one of three paths:

1. **GGUF via llama-server subprocess (the default, and the fleet's path).** The header comment on the runner constructor in `llm/server.go` states the rule plainly in substance: all GGUF models are served via the upstream llama-server subprocess. Ollama spawns one subprocess per loaded model (per distinct runner configuration — see §4.5), on a private loopback port, and talks HTTP to it. There is no embedded llama.cpp library path for GGUF in this release.
2. **MLX (Apple Silicon, safetensors models).** If the model's manifest marks it as MLX, the scheduler constructs a separate MLX client (`mlxrunner`) instead, bypassing every piece of GGUF machinery described in this dossier: no VRAM prediction, no placement selection, no llama-server flags. Truncation is also disabled for MLX models at the routes layer. MLX internals were **not read** for this dossier and are marked unverified in §9.
3. **Cloud/remote models.** Out of scope for this dossier; noted only because the routes layer branches for them before any local scheduling happens.

### 2.2 Which path serves a GGUF chat request

Within the GGUF path there are **two chat sub-paths**, and which one a given model takes is decided per model in the routes layer (`chatModeForModel` in `server/routes.go`):

- **Native mode (the common case).** If the model has no Ollama-side renderer, parser, Harmony handling, or Go template layer, the request is handled by the native chat handler: Ollama performs message-level truncation (§5.2), then forwards the message list to the runner's chat method, which posts it to llama-server's `/v1/chat/completions` endpoint. llama-server applies the model's own chat template. Ollama never sees the rendered prompt on this path.
- **Rendered mode.** Models with an explicit Ollama renderer, a Go template, Harmony support, or a parser are rendered to a prompt string in Go, and the request goes through the completion endpoint (`/completion` on llama-server) instead. `/api/generate` requests and embedding-style completions also travel this completion path.

This split matters enormously for context handling, because **the two sub-paths truncate differently** (§5). A fork that patches only one of them has patched only half the product.

### 2.3 Component map (behavioural)

| Component | File(s) | Owns |
|---|---|---|
| HTTP API + request shaping | `server/routes.go` | Option resolution and precedence, the VRAM-tier default context, chat-mode selection, native message truncation, the deprecated `context` array handling |
| Prompt rendering + rendered-path truncation | `server/prompt.go` | Go-side chat-template rendering and message-level truncation for the rendered path |
| Scheduler | `server/sched.go` | Load/unload decisions, placement selection, batch auto-sizing, mmap defaults, keep-alive expiry, eviction, OOM recovery |
| Runner abstraction | `llm/server.go` | The runner interface; train-context capping; KV-cache-type plumbing |
| llama-server wrapper | `llm/llama_server.go` | Subprocess launch flags, completion-path prompt shifting, request forwarding, log-parsed memory accounting, the pre-spawn VRAM predictor |
| Configuration | `envconfig/config.go` | Every `OLLAMA_*` default cited in this dossier |
| API types | `api/types.go` | Request/response shapes, option defaults, the `context` array, `truncate`/`shift` fields |

### 2.4 The subprocess contract

The wrapper launches a **single llama-server binary that dynamically loads GPU backend libraries** (selected via library path / backend-path environment), rather than one binary per vendor. The launch is deliberately minimal: Ollama sets the model path, a private loopback host/port, disables the web UI and network access, and then sets only the flags it has an opinion about (§4.4). Everything else — most importantly **GPU layer count, thread count, and flash-attention enablement — is left to llama-server's own auto-detection**. Log verbosity is raised specifically so that the wrapper can parse buffer-allocation lines back out of the subprocess's output for memory accounting (§6.3).

---

## 3. Question 3 first: the 2026 inversion, as the code stands

(The assignment's question order is preserved in §§4–8; this section answers Question 3 early because every other answer depends on it.)

### 3.1 What the inversion actually settled into

The banked dossier recorded a migration in progress: Ollama's original in-process Go runner (with its own llama.cpp binding) being replaced by pinned upstream llama-server, alongside a new Go-native engine effort that introduced *measured* scheduling — exact per-model memory measurement replacing estimates — in the September 2025 period.

At v0.40.16, from source, the settled state is:

- **The subprocess design won for GGUF.** The constructor's own documentation states that all GGUF models go through the upstream llama-server subprocess. The scheduler's runner factory is the llama-server constructor. There is no surviving in-process GGUF engine path in the files read.
- **The Go-native engine work survives as the MLX path**, a separate client for safetensors/MLX models on Apple Silicon — a different model format and a different operating system from the fork's target (a GGUF model on a 6 GB NVIDIA card under Linux). It does not serve a GGUF chat request.
- **"Measured scheduling" did not survive as a pre-load mechanism for GGUF.** What the GGUF scheduler uses before spawning is a rough estimator (§6.1) whose own source comment describes it as intentionally conservative and approximate. Measurement exists, but it is **post-load accounting**: after the subprocess starts, Ollama parses its log lines to learn what was actually allocated, and uses those parsed numbers to correct its view of free memory for the *next* decision (§6.3). The distinction is load-bearing for the fork: any design that assumes Ollama *knows* a model's footprint before loading it is assuming something this codebase does not do.

### 3.2 Consequence for the fork

The Memory Forge is not modifying a self-contained engine. It is modifying a **control plane whose most consequential decisions are either heuristic (its own predictor) or delegated (llama.cpp's fit)**. The surfaces where the fork's memory work must land are therefore:

1. the predictor and the gates that consume it (`llm/llama_server.go`, `server/sched.go`);
2. the flag set passed to the subprocess (`llm/llama_server.go`);
3. the truncation/shift code in *both* the routes layer and the wrapper (`server/routes.go`, `server/prompt.go`, `llm/llama_server.go`);
4. or, more radically, the subprocess boundary itself.

Patching only the scheduler's policy constants would leave the predictor's systematic errors (§6.2) and llama.cpp's independent fit decisions untouched.

---

## 4. Question 1: Scheduling

All behaviour in this section is from `server/sched.go` unless another file is named.

### 4.1 Shape of the scheduler

The scheduler is a single-goroutine event loop fed by channels: pending requests, finished requests, expiry notices, and unload completions, each queue sized by `OLLAMA_MAX_QUEUE` (default 512). It keeps a map of loaded runners keyed by model-plus-configuration identity (§4.5). Two structural facts shape everything else:

- **Only one model loads at a time.** A single "active loading" slot serialises loads. Requests for *already-loaded* models proceed in parallel with a load; requests needing a new load queue behind it.
- **The pending queue is strictly FIFO with no priorities**, and the loop blocks on the request it is currently satisfying — including waiting for another runner to finish unloading — before looking at the next one. A large model evicting a busy model therefore head-of-line blocks every load queued behind it.

### 4.2 How many models may be resident

`OLLAMA_MAX_LOADED_MODELS` defaults to 0, meaning automatic: **three models per GPU** (a named constant, `defaultModelsPerGPU = 3`, multiplied by the number of discovered GPUs, minimum one GPU's worth). On the fork's single-GPU target that is three resident models by default — a default written for machines with far more memory than 6 GB, restrained in practice only by the fit gate in §4.3.

### 4.3 The load decision, step by step

When a request needs a model that is not resident (or not resident with matching options):

1. **Refresh the world.** GPU list and system information are re-read, and free space is recomputed from the *parsed actual* usage of resident runners (§6.3) rather than trusting driver-reported free memory — the source comments note that CUDA's free reporting lags reality, so the smallest defensible value is used.
2. **Predict.** For GGUF, the scheduler loads only the model's metadata, computes the predicted context (§5.1), and runs the pre-spawn VRAM predictor (§6.1).
3. **Place.** A placement function chooses between a single GPU, a group of GPUs sharing one backend library, or CPU, and may rewrite the main-GPU option (§4.4).
4. **Auto-size the batch.** If the batch size is automatic, it is chosen from the predicted footprint and the available memory (§4.6).
5. **Pre-flight fit gate.** When this load is *additional* (another model is already resident), full residency is required, the user has not explicitly requested partial offload, and GPUs exist: **if the prediction plus batch allowance exceeds 80% of the memory available for placement, the load does not start**. Instead the scheduler is told to evict — it expires a resident runner, waits for the unload to complete, and loops. The 80% figure is commented in source as deliberate headroom.
6. **Spawn and load.** The subprocess is started and the model loaded. Failure handling is layered (§4.7).

The first model loaded into an empty server is *not* subject to the 80% pre-flight gate (the gate requires an already-resident model); it is allowed to attempt a partial fit, and failure is handled after the fact.

### 4.4 GPU vs CPU placement — and who counts layers

Placement (`selectLlamaServerPlacement` in `server/sched.go`) is a **device-set choice, not a layer choice**:

- If there is at most one GPU, or the user set `num_gpu = 0`, the discovered device set passes through unchanged (the zero case being CPU-only serving).
- If the user set an explicit main GPU, the scheduler finds the best matching physical GPU across backend groups — preferring a discrete card, then the device with most available memory — and pins the model to that single device. The option is rewritten so the subprocess is later told, in effect, "no split, this main GPU."
- Otherwise, if the spread-models setting (`OLLAMA_SCHED_SPREAD`) is off and a prediction exists, the scheduler looks for the **best single GPU that fits**: a GPU qualifies only if the prediction is at most **80% of that device's available memory**; among qualifying devices it prefers discrete over integrated, then largest available memory. If one qualifies, the model is pinned to that one GPU.
- If no single GPU qualifies, the model is offered to the **best GPU group** — all devices of one backend library, preferring a group containing a discrete GPU, then the group with most available memory — and llama-server spreads layers across that group as it sees fit.

**Layer offload counting is not Ollama's.** With the default `num_gpu` value of −1 (dynamic), the wrapper passes *no* layer-count flag at all; llama-server's own fit machinery (on by default upstream, and tunable through Ollama via the `LLAMA_ARG_FIT` / `LLAMA_ARG_FIT_TARGET` environment passthroughs documented in `envconfig/config.go`) decides how many layers go where. Only an explicit user `num_gpu` produces a layer-count flag, and `num_gpu = 0` produces an explicit zero. Ollama learns the outcome afterwards by parsing the subprocess's "offloaded X/Y layers" log line. Any fork feature that needs to *decide* layer placement must either drive that flag explicitly, drive llama.cpp's fit target, or replace the boundary — it cannot adjust a counting routine in Ollama, because there isn't one.

**Available-memory accounting** has two deliberate corrections worth naming:

- For an integrated GPU, available memory is the *smaller* of system free memory and GPU free memory.
- When summing availability across devices, shared/integrated memory is capped by live system free memory, because the integrated device's reported free figure is a stale baseline. (Discrete cards' free memory is summed as reported, then corrected by the parsed-usage pass in step 1 above.)
- Separately, the per-device figure shown in load logging subtracts the configured GPU overhead (`OLLAMA_GPU_OVERHEAD`) and the device's minimum memory. Note that **`OLLAMA_GPU_OVERHEAD` defaults to 0 bytes** — the "overhead" allowance exists as a knob but ships unpopulated.

### 4.5 Runner identity: what counts as "the same model"

A resident runner is reused only if it *needs no reload*, decided by a deep comparison of the effective runner options. The comparison has several behaviours the fork must know:

- **Automatic values are adopted, not compared.** If both the resident runner and the incoming request are using automatic context length, the request silently adopts the resident runner's actual context length instead of forcing a reload. The same adoption applies to automatic batch size and automatic mmap. This is the escape hatch that keeps the VRAM-tier default (§5.1) from restarting the model on every request.
- An unset `num_gpu` is normalised on both sides before comparison.
- **A context-shift mismatch alone forces a full model reload** (§5.4), as do changed adapter or projector files.
- An unhealthy runner (health ping fails) forces reload.
- MLX models skip the options comparison entirely.

The consequence, well known to Ollama operators and confirmed in source: **changing `num_ctx` (or shift, or adapters) between requests restarts the model.** The context window is part of the runner's identity, not a per-request property. This is the exact behaviour IDEA-LEDGER #17 (window as capacity, not runner identity) is written against.

### 4.6 Parallel requests per model: `num_parallel` semantics

- The value comes from `OLLAMA_NUM_PARALLEL`, **default 1** at v0.40.16 (`envconfig/config.go`). It is a *server-wide* setting, not per-request and not per-model.
- Non-completion models (embedding models) are **forced to 1** regardless of the setting. (The banked dossier's claim of eleven architecture families forced to 1 at v0.34.4 was **not re-verified** at v0.40.16; the only forced-1 rule found in the scheduler is the non-completion rule. See §9.)
- The total context handed to llama-server is **`num_ctx × num_parallel`** (§5.1): parallelism is bought with context memory, divided by llama.cpp into per-sequence shares per the paired dossier.
- Concurrency is enforced twice over on the completion path: llama-server's own slot count, and an **Ollama-side weighted semaphore of size `num_parallel`** in the wrapper, acquired per completion, chat, and embedding call. A request beyond the parallel limit waits on the semaphore, inside an already-accepted HTTP request — it is not rejected at the API.
- Special case: "decision" (whole-prompt classification-style) models are launched with a fixed high parallelism and llama-server's unified-KV mode with its RAM cache disabled — evidence that Ollama's authors treat the default slot configuration as wrong for at least one workload class.

### 4.7 Failure and OOM behaviour

Load-time and run-time failure handling is more elaborate at v0.40.16 than the banked dossier recorded:

- **Automatic context step-down (one step).** If a load runs out of memory *and* the context length was automatic (no request, model, or environment pin), the scheduler reduces the context once — the step function goes to 32,768 if above it, else to 4,096 if above that, else gives up — and retries the load. A pinned context gets **no** step-down: the user's number is treated as an instruction, and the load simply fails.
- **Evict-all retry.** If a load OOMs while other models are resident, the scheduler can expire *all* of them, wait, and retry once. A per-request flag prevents this from looping.
- **"Too large" honesty.** If a first (non-full-required) load reports that full residency is required, the error surfaced is that the model is too large for system memory.
- **Runtime OOM is contagious.** If a *completion* reports an out-of-memory error at run time, the scheduler expires **all** loaded completion runners, not just the one that faulted.

### 4.8 Keep-alive and expiry mechanics

- The keep-alive duration comes from `OLLAMA_KEEP_ALIVE`, **default 5 minutes** (`envconfig/config.go`), overridable per request. A negative duration means *never unload* (represented internally as the maximum duration); zero means unload immediately.
- Expiry is reference-counted. When a runner's in-flight count falls to zero, a timer is set for the session duration; a subsequent request reuses the runner and the timer is reset when that request finishes. If the timer fires while the runner is somehow busy again, expiry re-queues itself on a short (10 ms) loop until the runner is idle.
- **Eviction choice** (`findRunnerToUnload`): runners are sorted by session duration ascending — so *pinned/never-expire runners sort last* — then by model key. An idle runner is preferred. If none is idle, the shortest-duration runner is selected anyway: its duration is zeroed and it is expired **once its references drain** — the scheduler does not kill a runner mid-generation.
- **Unload waits for memory to actually come back.** On discrete GPUs, unload polls for up to 5 seconds (every 250 ms) until at least **75% of the runner's VRAM** has been recovered before the unload is considered complete and waiting loads proceed. This is a named, deliberate margin: a quarter of the memory is allowed to still be in flight when the scheduler moves on.
- `ollama ps` reports each runner's parsed size/VRAM, its actual context length, and its expiry time — the ground truth operators are expected to check, since so many of the values above are resolved silently.

### 4.9 mmap defaults — the scheduler second-guesses the user

A behaviour new since the banked dossier: the scheduler itself can **disable memory-mapping**, marking the change as "automatic" so it does not trigger reloads, when it judges mmap harmful. The named reasons include: CPU-only placement; Windows with CUDA; Metal with partial offload; and a Linux host-pressure case — all-discrete GPUs, model expected to fit, but system free memory smaller than model size plus already-mapped resident models plus a headroom of **the larger of 8 GB or a tenth of total RAM**. An explicit user `use_mmap` always wins. On the launch line this becomes a load-mode flag to the subprocess; Linux integrated-GPU CUDA/ROCm placements separately get a direct-I/O load mode.

### 4.10 Automatic batch sizing

When `num_batch` is automatic and the model is a completion model, the scheduler sizes the generation batch itself, from context size and memory pressure:

- Named tiers: constrained 256, default 512, medium 1,024, large 2,048.
- CUDA without flash attention: 256 when the effective context exceeds 4,096 and some CUDA device has at most 8 GiB, else 512.
- Otherwise by context: above 32,768 → 2,048; above 4,096 → 1,024; else 512 — then stepped *down* while a fit test fails. The fit test requires the prediction to be within the 80% availability threshold, applies **batch-specific headroom — large batches must fit in 60% of available memory, medium in 75%** — and requires the batch's own memory allowance (next bullet) to fit in what the threshold leaves.
- The batch allowance itself (`llm/llama_server.go`) is a step function: batches of 2,048 or more carry a **2 GiB** allowance, 1,024 or more carry **768 MiB**, smaller batches carry **zero**. The source describes this as a conservative extra allowance above the default batch. It is one of only two places where anything resembling compute/graph memory enters Ollama's arithmetic at all (§6.2).


---

## 5. Question 2: Context handling — the `num_ctx` path and where truncation actually happens

### 5.1 The `num_ctx` path, API → runner → llama.cpp

1. **Request.** `num_ctx` arrives as a runner option on `/api/generate` or `/api/chat` (or not at all).
2. **Resolution** (`modelOptions` in `server/routes.go`). Precedence, highest first: **request option → Modelfile parameter → environment (`OLLAMA_CONTEXT_LENGTH`, folded into the API defaults) → VRAM tier**. If nothing anywhere sets it, the server computes a default once at startup from total discovered VRAM (overhead subtracted per device): **at least ~47 GiB → 262,144; at least ~23 GiB → 32,768; otherwise 4,096**. The thresholds sit slightly below the round 48/24 GiB figures, per the source comment, to absorb reporting differences. The chosen tier is logged once at startup ("vram-based default context"). On the fork's 6 GB target the tier is unambiguously the bottom one: **4,096**.
3. **"Automatic" is a tracked property.** A context counts as automatic only if neither request nor model set it *and* the environment variable is unset. This flag later decides OOM step-down eligibility (§4.7) and reload adoption (§4.5). An environment pin therefore behaves like a user pin in both places — a subtlety operators miss.
4. **Floor.** The scheduler floors the context at **4**, and at **2,048 for vision/projector models**, before any load.
5. **Train cap.** At runner construction (`llm/server.go`), the context is capped at the model's trained context length from its GGUF metadata, with a warning logged. The advertised model-card context is never exceeded, whatever was requested.
6. **Multiplication.** The context handed to the scheduler's predictor, and to the subprocess as its `-c` value, is the train-capped per-sequence context **multiplied by `num_parallel`**. Per the paired llama.cpp dossier, llama-server then treats that total as a pool (unified mode) or divides it per sequence (non-unified) — Ollama does not control which, except for the decision-model special case (§4.6).
7. **Write-back.** After a successful load, the runner's authoritative actual context length is written back into the request's options, and prompt-length checks elsewhere in the routes layer clamp against the runner's *actual* length. `ollama ps` exposes this actual value.

So the number the user typed is, by the time it reaches llama.cpp: tier-substituted if absent, floored, train-capped, and multiplied by parallelism. Four separate transformations, one log line (at startup, for the tier only).

### 5.2 Layer 1: message-level truncation (routes/prompt layer)

Layer 1 exists in **two parallel implementations** at v0.40.16, one per chat sub-path (§2.2). Both were read for this dossier.

**Native path** — `truncateNativeChatMessages` (`server/routes.go`):

- Runs only if truncation is enabled (the request's `truncate` field defaults to true when unset), the context is positive, and there is more than one message. MLX models never reach it (truncation is forced off for them earlier).
- It tries candidate starting points from the front of the conversation. For each candidate, it collects **all system-role messages that appear before that point** and re-prepends them, renders the surviving suffix through llama-server's template application, tokenises, and adds a flat **768 tokens per image** for projector models. The first starting point whose rendered length fits within `num_ctx` wins.
- If *no* starting point fits — including the case where the last message alone is too long — it keeps **just the last message, plus the system messages**. There is no further fallback at this layer.
- The only record is a **debug-level** log line whose field reports how many messages were dropped. Nothing is added to the API response.

**Rendered path** — `chatPrompt` (`server/prompt.go`):

- The same algorithm, independently implemented: drop from the front, re-collect system messages from the skipped prefix, render via the Go template/renderer, tokenise, add 768 tokens per image (its own source comment calls the image figure a heuristic to be replaced), keep at least the last message.
- Two divergences from the native twin worth recording: the fit comparison uses the resolved options context directly; and its debug log line's "truncated" field reports the number of messages *remaining*, not the number dropped — the two implementations do not even log the same quantity.

**Behavioural summary of Layer 1:** whole messages only; system messages are immortal (re-collected from any dropped prefix); the newest message is immortal (kept even if it alone overflows); everything between is expendable, silently, at debug log level. For the fork's character-chat workload this is the layer that amputates the middle of a long conversation while preserving its framing — and it is also the layer that guarantees an oversized *final* message passes through untouched to fail (or be shifted) downstream.

### 5.3 Layer 2: token-level shift — and the verdict on the two-layer finding

**Where it lives now.** The token-level mechanism the banked dossier described has moved fully into Ollama's own wrapper: `completionPromptForRequest` in `llm/llama_server.go`, on the **completion path only** (rendered chat and `/api/generate`). Behaviour:

- Skipped entirely if the request disabled truncation, if media is attached, if the context is degenerate, or — a cheap pre-check — if the prompt *string* is shorter than the context (character count standing in for token count).
- Otherwise the prompt is tokenised and compared against a limit of **`num_ctx` − 1**. If it fits, it passes untouched.
- If it does not fit and **context shift is disabled**, the request fails loudly: HTTP 400, with a message advising the user to shorten the prompt, adjust the context length, or use a longer-context model.
- If it does not fit and **shift is enabled**, the wrapper performs the shift itself, before llama-server ever sees the prompt: it preserves the first `num_keep` tokens (the request option; default **4**, with one added when the tokeniser adds a beginning-of-sequence token), then discards from the middle so that the result fits a shifted limit computed as **`num_ctx` minus roughly half of the non-kept remainder** — in the source's own framing, matching the old in-process runners' first context shift: keep `num_keep`, free roughly half of what remains. The only record is a **warning-level** log line giving the limit, the original length, the keep count, and the new length. No API field reports it. This matches the externally observed log line in the wild (`truncating input prompt`, limit/prompt/keep/new) reported against 0.40.14.

**The native chat path has no Layer 2 in Ollama.** Verified directly: the native chat method builds its llama-server request by converting messages and posting them to `/v1/chat/completions` with prompt caching on and `n_keep` forwarded — there is no tokenisation, no length check, and no shift in Ollama on this path. Whatever happens to an over-long native-chat prompt happens **inside llama-server**: its own context-shift machinery if the subprocess was launched with shifting enabled (same resolved flag, passed as a launch argument with the keep count), or llama-server's prompt-too-large rejection per the paired dossier. The single oversized final message that Layer 1 deliberately passes through (§5.2) lands exactly here.

**Generation-time shifting** is a third, distinct mechanism: llama-server's in-generation context shift, gated by the same resolved shift flag passed at launch. It is not Ollama code, but Ollama decides whether it exists for a given runner.

> **Verdict on the banked two-layer finding: STILL HOLDS at v0.40.16, with three corrections.**
>
> 1. **Layer 1 confirmed, and doubled.** Message-level, system-preserving, last-message-immortal, 768-tokens-per-image, debug-log-only — confirmed in both implementations (`server/routes.go`, `server/prompt.go`). The banked dossier described one implementation; there are two, and they diverge slightly (including in what their log fields mean).
> 2. **Layer 2 confirmed in formula, relocated in ownership.** The keep-`num_keep` (default 4), free-half-the-remainder shift with a warning-level log and a 400 when shift is off — confirmed. But at v0.40.16 the first cut is made by **Ollama's own Go wrapper on the completion path**, pre-emptively, not by llama-server; and the native chat path bypasses it entirely, delegating to llama-server's shift-or-reject.
> 3. **The shift default is now family-dependent.** See §5.4. The banked dossier's framing — shift as a single legacy default, `shift: false` as the opt-in loud failure — is no longer the whole truth.

### 5.4 Shift vs truncate: how the two switches are actually wired

The API exposes both fields on generate and chat requests (`api/types.go`): `truncate` — truncate chat history messages if the rendered prompt exceeds the limit; `shift` — shift history when hitting the limit instead of erroring. As wired at v0.40.16:

- **`truncate` defaults to true** (an unset field means truncate). It gates Layer 1 (both implementations) and Layer 2's existence. Setting it false disables both layers on the completion path — an over-long completion prompt then goes to llama-server as-is. It is forced off for MLX models regardless.
- **`shift` defaults to true at the API layer** (handlers pass "unset means true" down with every request), **but** the scheduler resolves the final value per model: an explicit request value wins; otherwise the default is whether the model *supports* context shift, which at this tag is **every GGUF family except `deepseek2`** (checked against both the model's family and its family list). For non-GGUF models the scheduler leaves shift off.
- The resolved shift value is part of runner identity: **flipping it reloads the model** (§4.5).
- The resolved value drives three things at once: the wrapper's Layer-2 behaviour (§5.3), the subprocess's `--context-shift` launch argument (with `--keep` when `num_keep` > 0), and hence llama-server's generation-time shifting.

Net behaviour for the fleet's workload: a typical GGUF chat model runs with **truncate on, shift on** — over-long histories are message-amputated at debug level, then token-shifted at warning level, and the user is told nothing in either case. A `deepseek2`-family model runs with **shift off by default** — the same over-long completion prompt is an HTTP 400. Same API, same client code, opposite failure philosophy, decided by model family. The fork's disclosure work (IDEA-LEDGER #6) and anchor work (#2) both have to reckon with this asymmetry: there is no single "Ollama truncation behaviour" to patch, there are at least four (two Layer-1 twins × shift on/off), plus llama-server's own behaviour underneath the native path.

### 5.5 `num_predict` bounding

One adjacent context behaviour worth banking: Ollama's unbounded generation value (−1) is translated for llama-server as **ten times the context length** (`llm/llama_server.go`). Generation is therefore never truly unbounded against the subprocess, and a "run until stop" request on a small context has a hard token ceiling of 10× that context.

---

## 6. Question 4: Memory estimation honesty

### 6.1 The pre-spawn predictor, exactly as designed

`PredictServerVRAM` (`llm/llama_server.go`) is the only number Ollama has before it spawns the subprocess. Its source comment is candid in substance: it estimates VRAM without spawning, using model file size as a proxy for weights plus a rough KV estimate, and is **intentionally conservative — it overestimates to avoid VRAM contention**. Behaviourally, the estimate is:

- **Weights = the total on-disk size of the model file(s)**, all shards, plus the projector file's size where its metadata is present.
- **KV cache = 2 (keys and values) × layer count (GGUF block count) × KV head count × head dimension × total context (already multiplied by `num_parallel`) × 2 bytes.**
  - The KV head count used is the **minimum across layers**, defaulting to 1 if the metadata yields zero.
  - The head dimension is **derived**: total embedding length divided by the *maximum* head count.
  - The 2 bytes is a hard-coded **f16** assumption.
- **Total = weights + KV. Nothing else is in the formula.**

### 6.2 Where the estimate diverges from reality

Against what the corpus's memory dossiers establish a real allocation contains, the divergences are systematic, in both directions:

| Reality | Predictor's treatment | Direction of error |
|---|---|---|
| KV cache type. `OLLAMA_KV_CACHE_TYPE` can set q8_0 or q4_0 (a single global value applied to *both* K and V at launch), halving or quartering real KV bytes. | Always priced at **f16**. The configured type is never consulted. | **Over-estimate** whenever quantised KV is in use — on the fork's target, exactly the configuration IDEA-LEDGER #3 prescribes. Consequence: needless evictions and refused co-residency. |
| Hybrid / sliding-window architectures, whose layers have different head counts and whose windowed layers cost window-sized, not context-sized, cache (paired dossier §6.5). | Minimum head count across layers × full context × every layer. | **Under-estimate** for models whose early layers are cheap and later layers are not; mis-priced in a model-specific, un-auditable way. |
| MLA-style and other non-standard attention, where head dimension is not embedding ÷ heads. | Head dimension derived by that division. | Either direction, architecture-dependent. |
| Compute/graph buffers, output and rotation buffers, layer-input buffers. | **Absent from the formula.** Enter only via the batch step-allowance (0 / 768 MiB / 2 GiB, §4.10) and implicitly via the 80%/60%/75% gates. | **Under-estimate**, worst exactly at small batch (allowance zero) where small cards live. |
| CUDA context, driver reservation, display/compositor memory, fragmentation. | Absent. The only related knob, `OLLAMA_GPU_OVERHEAD`, defaults to **0**. | **Under-estimate** on any display-attached machine — the corpus's worked case prices this at 0.9–1.1 GiB on a 6 GB card. |
| Draft/speculative models, projector runtime buffers beyond file bytes. | Absent (projector *file* bytes only). | Under-estimate for multimodal and draft configurations. |
| mmap page cache / repacked weight buffers making resident weight memory differ from file size. | File size taken as weight memory. | Either direction; the post-load accounting contains an explicit correction for the mmap double-count, which is internal evidence the proxy is known-crude. |

The safety margins that are supposed to absorb all of this are the named percentages: the **80%** pre-flight and single-GPU-fit thresholds, the **75%/60%** batch headrooms, and the **75% VRAM-recovery** threshold at unload. They are global constants, not per-model or per-device calibrations, and they are asked to cover errors that §6.2 shows are *structural* (wrong KV type, wrong head geometry) rather than noise. A constant margin cannot correct a wrong formula; it can only make its failures rarer and less predictable.

### 6.3 Post-load accounting: measurement by log-scraping

After spawn, the wrapper learns reality by **parsing llama-server's own log lines** (a dedicated writer with pattern matchers for per-backend buffer-size lines — model, KV, compute, output, rotation, layer-input, recurrent-state — plus the offloaded-layers line, fit-overflow lines, and per-device free-memory lines). From these it builds total and per-GPU sizes, with a correction that trims file-backed mapped spans so mmap'd weights are not double-counted, and a rule that a fully-offloaded model reports its total as its VRAM. These parsed numbers feed the scheduler's free-space recomputation (§4.3) and `ollama ps`.

The fragility is structural and acknowledged in the code's own fallbacks:

- **If no buffer lines are parsed, both total and VRAM fall back to the model file size** — the same proxy the predictor used — with only a debug-level log.
- If GPUs exist but no per-device VRAM was parsed, load emits a warning that VRAM accounting will be inaccurate — and then proceeds with the inaccurate accounting.
- The whole channel depends on an upstream subprocess's human-readable log format remaining stable across the pinned llama.cpp bumps that land every release or two (v0.40.17-rc0 already bumps it again).

### 6.4 The corpus's worked 6 GB case, priced through this machinery

Take the corpus's worked case (`memory/kv-cache-design.md` §7.2, via IDEA-LEDGER #3): an 8B-class Q4_K_M model, ≈5,018 MiB of weights, on the 6,144 MiB RTX 2060 Max-Q. The corpus's honest budget: headless reserve ≈512 MiB leaves ≈614 MiB for KV — ≈4,912 tokens at f16, ≈9,246 at q8_0; display-attached, the reserve grows to 0.9–1.1 GiB and the f16 budget collapses to ≤≈2,000 tokens.

Priced through v0.40.16's machinery instead:

- The tier system assigns `num_ctx` = 4,096 (bottom tier) — the *only* point where the machinery's answer and the corpus's answer roughly agree, and they agree by coincidence of tier granularity, not by computation.
- The predictor prices the load as ≈5,018 MiB + f16 KV at 4,096 total context. If the operator does the right thing for this card and sets q8_0 KV, the predictor **still charges f16** — the load looks ~2× more KV-expensive than it is. For a *first* load this changes little (the 80% gate doesn't apply); for any *second* model it can trigger an eviction that reality didn't require.
- Nothing in the prediction reserves anything for the display, the CUDA context, or compute buffers; the batch allowance at this context size is the 512-batch step — **zero**. The gap between prediction and reality is left for llama.cpp's fit (inside the subprocess, after the decision that mattered) and for the OOM recovery paths (§4.7) to absorb.
- If the operator instead *raises* `num_ctx` toward what q8_0 makes possible (≈8,192) and pins it, they simultaneously (a) double the predictor's f16 KV charge, making co-residency and fit-gate outcomes worse on paper, and (b) **disable the OOM step-down** by pinning — removing the one recovery that would have saved the load if reality disagreed.

The honest summary: on the fork's exact target hardware, Ollama's estimation system is **simultaneously over-conservative in the term it computes (KV, priced at the wrong type and geometry) and silent on the terms it doesn't (buffers, context, display)**. Its margins are percentages of the wrong number.

---

## 7. Question 5: Session and prefix handling in Ollama proper

### 7.1 There is no session

Ollama proper holds **no conversation state**. No session object, no conversation identifier, no server-side history. Each chat request carries its full message list; the only "session" material the server ever adds is the model's own baked-in messages and system prompt, prepended by the routes layer when the request doesn't already start with them. Model lifetime and session lifetime are the same accidental thing — the runner stays resident for keep-alive, and its subprocess state is whatever llama.cpp happens to retain — which is precisely the coupling IDEA-LEDGER #11 (decouple model lifetime from session lifetime) and #1 (a resident session object with token-level residency) are written against.

### 7.2 The `/api/generate` `context` array, as implemented

The legacy `context` array (`api/types.go`: an integer array "returned from a previous call", documented as keeping "a short conversational memory") is **deprecated and implemented as text round-tripping**:

- On receipt, the handler logs a **warning that the context field is deprecated and will be removed**, detokenises the array back into *text*, and **prepends that text to the newly rendered prompt**. Source comments in both the native and rendered branches mark it for imminent removal. If a context is supplied, the model's baked-in messages are not added. Raw mode rejects template/system/context combinations outright.
- On completion, the response's returned array is produced by **tokenising the full text of prompt-plus-generation**. It is a re-encoding of text the client mostly already has — not a handle to KV state, not a reference into the subprocess, and with no guarantee that re-submitting it reproduces the same tokenisation boundaries the model actually used.

In other words the array survives as a compatibility shim whose implementation actively discards the only thing that would make it valuable (token-level state), at a warning log per use. The chat endpoint never had an equivalent. Any client still built on it — and long-running character-chat front-ends are exactly the clients that historically were — is building on a deprecated text echo.

### 7.3 Prefix reuse: what actually happens above llama.cpp

- Ollama sets **`cache_prompt: true` unconditionally** — on every completion request and, verified in this reading, on every native chat request as well (the chat request builder hard-codes it). Cached-token counts come back from llama-server's timings and are surfaced in Ollama's metrics as `prompt_eval_cached_count` on both paths.
- That is the entirety of Ollama's involvement. The reuse itself is llama.cpp's: per the paired dossier, per-slot last-prompt exact-prefix matching inside the subprocess, plus llama-server's RAM prompt cache — which Ollama **does not configure** for normal models (no cache-reuse or cache-size flags are passed; only the decision-model special case touches the RAM cache, disabling it). Whatever the pinned llama-server build's defaults are, those are what the fleet runs. (Which llama.cpp build v0.40.16 pins was **not established** in this reading — §9.)
- There is **no cross-request, cross-model, or content-addressed caching in Ollama proper**: no hash-chained or radix prefix structure (IDEA-LEDGER #5), no sharing between the parallel slots of one runner beyond what llama.cpp does internally, and no persistence of any prefix state across a runner reload — and reloads, per §4.5, are triggered by option changes as mundane as flipping `shift`.

### 7.4 Net assessment for the fork's workload

For a single user holding long character chats on one small card, Ollama's session/prefix story at v0.40.16 is: stateless API, deprecated text-echo context, unconditional prompt-cache flag into someone else's per-slot exact-prefix cache, and a resident-context guarantee of exactly nothing — every turn's history is re-sent, re-rendered (or re-templated), re-truncated by Layer 1's judgement of what fits, and re-matched against a slot cache that a reload can silently void. Volmarr's standing laws — character anchor un-pushable, resident context never reprocessed — are not merely unimplemented here; the architecture has no place where they *could* be implemented without the fork adding the session layer itself. That is IDEA-LEDGER #1's entire premise, confirmed from the base code.

---

## 8. Strengths and weaknesses (as a base for the Memory Forge)

### Strengths

- **Operational maturity of the load lifecycle.** Reference-counted residency, drain-before-evict, VRAM-recovery waiting, OOM step-down/evict-all/retry layering, runtime-OOM containment — this is hard-won, real-world scheduling behaviour that a from-scratch runner would take a long time to re-earn.
- **Honest failure at the boundaries it chooses.** The 400 for an over-long prompt with shift off, the "model too large" error, and the deprecation warning on the `context` array are all genuinely informative — proof the codebase *can* surface truth when it decides to.
- **Post-load accounting exists at all.** Parsed actuals correcting driver-reported free memory is the right instinct, and `ollama ps` exposes actual context and sizes to operators.
- **Clean delegation boundary.** The subprocess design means the fork can, in principle, change engines, flags, or fit behaviour without forking llama.cpp itself.
- **Escape hatches are real.** Explicit `num_gpu`, `use_mmap`, pinned `num_ctx`, per-request keep-alive, and the llama.cpp fit passthroughs all genuinely override the automation.

### Weaknesses

- **The predictor is structurally wrong, not just imprecise** (§6.2): f16-only KV pricing, minimum-head geometry, derived head dimension, zero buffer/context/display terms, global-percentage margins asked to absorb structural error.
- **The decisions that matter most are delegated or duplicated.** Layer placement belongs to llama.cpp's fit; Layer-1 truncation exists twice with divergent logging; Layer 2 exists on one chat path and not the other.
- **Silence as the default failure mode.** Truncation at debug level, shifting at warning level, no response fields for either, cached counts exposed but dropped/truncated counts never. The API's successful responses are indistinguishable between "saw everything" and "saw half of it".
- **Context is runner identity.** Option changes reload the model; the window cannot be treated as capacity over a resident session (against IDEA-LEDGER #17).
- **Family-dependent failure philosophy.** `deepseek2` errors where everything else silently shifts (§5.4).
- **Measurement by log-scraping** (§6.3): the accounting channel is regexes over an upstream tool's prose, with file-size fallbacks.
- **Defaults sized for other machines.** Three resident models per GPU, 262k/32k context tiers, zero GPU overhead — reasonable on a workstation, unexamined on a 6 GB laptop card.
- **No session layer** (§7): the fork's central features have nowhere to attach.

---

## 9. What the fork keeps vs replaces — labelled judgment

*This section is the dossier author's judgment, written for the Ollama Memory Forge campaign. It is not a description of upstream behaviour. IDEA-LEDGER references are to the ledger's permanent entry numbers (fourth cut, 2026-11-15).*

### Keep

- **The scheduler's lifecycle skeleton** — reference counting, drain-before-evict, recovery waiting, layered OOM response (§4.7–4.8). Replace its *inputs* (the predictor), not its shape. This is the substrate IDEA-LEDGER #31 (one residency arbiter + admission) should be built as a reform of, not a rival to.
- **The subprocess boundary itself**, at least initially: it is the cheapest place to gain honest accounting — a fork-controlled wrapper can demand structured memory reporting from its own runner builds instead of scraping logs (§6.3), which IDEA-LEDGER #51 (stage-priced loads with per-model/device load records) requires.
- **Post-load actuals as the free-space truth** — the instinct behind §6.3's corrections is IDEA-LEDGER #44's measurement law already half-implemented; keep the data flow, replace the channel.
- **`ollama ps`-style exposure of actuals** — actual context, actual sizes, expiry — extended, per #6, to everything the system does to a prompt.

### Replace

- **The VRAM predictor, wholesale** → IDEA-LEDGER #12 (budget from measured per-model KV rate + measured placement) and #50 (the four-number context rule: trained / scaled / allocated / *usable* — the predictor currently conflates all four). KV must be priced at the *configured* type, per architecture geometry, with buffer/context/display terms named rather than margined away (§6.2, §6.4).
- **The single global KV type and its f16 pricing** → #3 (q8_0 KV by default on small cards, K and V priced and chosen separately, per model).
- **Both Layer-1 implementations and the wrapper's Layer 2** → #2 (a pinned, non-truncatable anchor segment — the current `num_keep` default of 4 tokens is the anti-anchor) and #6 (loud disclosure of every truncation, eviction, and reuse count, in the response, not the log). One truncation site, one policy, no family-dependent silent/loud split (§5.4).
- **Runner-identity context** → #17 (window as capacity over a resident runner) and #11 (model lifetime decoupled from session lifetime).
- **The absent session layer** → #1 (resident session object with token-level residency), #7 (post-history anchor slot, composed never stored), #10 (session persistence). §7 shows there is nothing to refactor here — this is greenfield inside the fork, and the deprecated `context` array should be treated as a removal candidate, not a foundation.
- **Per-slot last-prompt prefix reuse as the ceiling** → #5 (hash-chained/radix prefix cache). The unconditional `cache_prompt` flag stays; what it feeds must grow.
- **Hard-coded placement rules** → #52 (placement as a scorer pipeline) and #53 (placement as optimisation over weights/KV/compute as separate tensor kinds), driving llama.cpp's fit explicitly rather than abdicating to it (§4.4).
- **Contiguous per-sequence KV assumptions inherited from the subprocess defaults** → #4 (block/paged allocation in one pre-sized arena) is the ledger's longer-term answer; at minimum the fork should choose the subprocess's KV mode deliberately (cf. the decision-model special case, §4.6) rather than inherit it.
- **Automatic batch sizing's zero-allowance small end** → fold into #12/#51: on a 6 GB card the batch/graph term is not a rounding error, and a step function that prices it at zero below batch 1,024 (§4.10) is how "fits on paper" becomes OOM in practice. #18 (chunked prefill) is the related lever for the prefill side.

### The three most consequential findings for the fork

1. **The fork's base does not contain the decisions the campaign cares most about.** Layer placement is llama.cpp's, the pre-load memory number is a self-described rough heuristic, and real measurement is post-hoc log-scraping. A Memory Forge that patches scheduler policy alone inherits all three. The load-bearing surfaces are the predictor, the placement/batch gates, and the subprocess flag set (§3.2).
2. **Truncation is four behaviours, not one** — two Layer-1 twins, a wrapper Layer 2 on the completion path only, llama-server's own shift-or-reject under the native path — with a family-dependent default deciding silent-shift vs HTTP 400. The anchor and disclosure work (#2, #6) must be designed against the full matrix in §5 or it will protect one path and leak through the other.
3. **There is no session.** Every premise of the fork's character-chat design (resident context, un-pushable anchor, never reprocess) requires building the layer Ollama never had (§7), while the one legacy mechanism that gestures at it — the `context` array — is a deprecated text echo already marked for removal. Budget the campaign accordingly: the memory work is a reform; the session work is a construction.

---

## 10. Unverified questions

Marked honestly, per the assignment. None of these were guessed at anywhere above.

1. **MLX path internals** — the `mlxrunner` client's scheduling, memory estimation, context/truncation, and prefix behaviour were not read. Everything in this dossier is the GGUF path unless stated.
2. **The llama.cpp build pinned at v0.40.16** — not established. (v0.40.17-rc0's notes indicate a bump to b12257, implying v0.40.16 pins something earlier.) This determines which llama-server defaults — RAM prompt cache size, unified-KV defaults — the fleet actually runs (§7.3).
3. **Architecture families forced to `num_parallel = 1`** — the banked dossier claimed eleven families at v0.34.4. At v0.40.16 the only forced-1 rule found in the scheduler is for non-completion models. Whether a family list survives elsewhere (routes or model configuration) was not verified; the claim should be treated as stale until re-checked.
4. **The `/v1/responses` truncation behaviour** — secondary release-notes summaries state that v0.40.16 made the Responses route respect truncation instead of silently truncating by default. The OpenAI/Responses compatibility routes were not read for this dossier; the claim is recorded, not verified.
5. **GPU discovery internals** — the `discover` package's enumeration and free-memory sources were read only through their scheduler-facing outputs.
6. **Rendered-vs-native Layer-1 equivalence in edge cases** — both implementations were read and agree in algorithm; whether they agree token-for-token on templated edge cases (tool calls, thinking blocks, multi-image histories) was not exhaustively traced.

---

## 11. Sources

All source reading was performed on **2026-11-15** against the public ollama/ollama repository at **tag v0.40.16** (release published 2026-11-09; the current stable release and the fleet's running version at the date of reading). A pre-release v0.40.17-rc0 (2026-11-10) exists and was used only as flagged secondary evidence.

Primary files read (paths within the repository at the tag above):

- `server/sched.go` — scheduler: load decisions, placement, batch auto-sizing, mmap defaults, expiry, eviction, OOM handling.
- `server/routes.go` — option resolution, VRAM-tier default context, chat-mode selection, native message truncation, `context` array handling, handlers' truncate/shift defaults.
- `server/prompt.go` — rendered-path prompt construction and message truncation.
- `llm/server.go` — runner construction, train-context cap, KV-type plumbing.
- `llm/llama_server.go` — subprocess launch, completion-path prompt shifting, native chat forwarding, batch memory allowance, log-parsed memory accounting, the pre-spawn VRAM predictor.
- `envconfig/config.go` — environment defaults: keep-alive, parallelism, queue and model limits, GPU overhead, KV cache type, flash attention, spread, fit passthroughs.
- `api/types.go` — request/response types, option defaults, `context`/`truncate`/`shift` field documentation.

Corpus-internal sources:

- `runners/ollama.md` (this corpus) — the architecture-level dossier whose two-layer truncation finding §5.3 verifies and corrects.
- `runners/llamacpp-kv-internals.md` (this corpus, llama.cpp v1.0.0) — slot/KV behaviour beneath the subprocess boundary.
- `synthesis/IDEA-LEDGER.md` (this corpus, fourth cut, 2026-11-15) — entries cited by permanent number in §9.
- `memory/kv-cache-design.md`, `memory/gpu-memory-internals.md` (this corpus) — the worked 6 GB case used in §6.4.

*End of OR-2.*
