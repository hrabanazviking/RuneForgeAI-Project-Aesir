# mistral.rs — OR-2 Dossier

## 1. Header

- **Name:** mistral.rs (stylised `mistral.rs`; crates and CLI binary are `mistralrs`)
- **Licence — verified:** MIT. The repository `LICENSE` file read directly on 2026-11-15 is the standard MIT text, copyright 2024 Eric Buehler. This is the engine licence only; model weights loaded by it carry their own licences.
- **Languages:** Rust as the implementation language throughout the engine, server, and kernels glue. A Python package (`pip install mistralrs`) and a Rust crate are both first-class SDKs wrapping the same core; the Python layer is a binding, not a separate Python inference runtime.
- **Links:**
  - Repository: https://github.com/EricLBuehler/mistral.rs
  - Documentation: https://docs.mistralrs.dev/
  - Quantization types reference: https://docs.mistralrs.dev/reference/quantization-types/
  - Paged-attention guide: https://docs.mistralrs.dev/guides/perf/paged-attention/
  - Quantize-a-model guide: https://docs.mistralrs.dev/guides/quantization/quantize-a-model/
- **As of:** 2026-11-15. Current release line discussed in the sources read is v0.9.5, with v0.8.2 as the most recent fully published CUDA benchmark report in the README.
- **Essence:** mistral.rs is a single-process, non-Python inference engine written in Rust on top of Hugging Face's Candle tensor framework, designed to be equally at home as an embedded library, a one-shot CLI chat program, and a continuously batched HTTP server. Its distinguishing bets are threefold: one unified pipeline abstraction covers text, vision, audio, speech, image-generation and embedding models; almost any Hugging Face checkpoint can be quantized *while it loads* instead of requiring a pre-converted file; and the datacentre techniques of paged attention, continuous batching and prefix caching are defaults on consumer CUDA and Apple Silicon hardware, not datacentre-only options. It is not affiliated with Mistral AI — the name is historical, from its earliest supported model family.

> Naming warning for future readers: searches for "Mistral" overwhelmingly return Mistral AI the company and its models. Every claim in this dossier is about Eric Buehler's `mistral.rs` engine unless explicitly stated otherwise.

## 2. Architecture: life on top of Candle

### 2.1 What Candle gives it, and what that costs

Candle is Hugging Face's minimalist machine-learning framework for Rust: a tensor core (`candle-core`), neural-network building blocks (`candle-nn`), and per-backend kernel crates for CUDA and Metal, plus CPU execution with optional Intel MKL or Apple Accelerate BLAS. It natively understands safetensors weights, the Hugging Face Hub, and the Rust `tokenizers` stack, and it has no Python interpreter, no GIL, and no PyTorch dependency in the runtime path.

Building on Candle buys mistral.rs:

- **A device abstraction for free.** One `Device` concept spans CPU, CUDA and Metal, so model code is written once and dispatched per backend. mistral.rs inherits Candle's ceiling as well as its floor — see §4.3.
- **A safetensors-first world.** Hugging Face checkpoints load in their published form. There is no mandatory conversion step analogous to converting a checkpoint to a single runtime-specific file before first use.
- **Embeddability.** Because the whole stack compiles to native Rust, the engine can be linked into another Rust binary, shipped as a Python wheel with no Python-side tensor code, or run as a standalone CLI/server binary from an installer script. Cold start is a native binary start, not an interpreter-plus-framework import.
- **Memory safety in the host layer.** Scheduling, cache bookkeeping, HTTP handling and model loading are ordinary Rust, which removes a class of use-after-free and data-race faults that C/C++ and C-extension stacks must police manually. This says nothing about correctness inside custom GPU kernels, which remain unsafe-boundary code.

What it does *not* inherit is a mature, hardware-vendor-tuned kernel library comparable to PyTorch's or ggml's decade of per-architecture tuning. Where Candle lacks an operation or a fused kernel, mistral.rs must write its own (its quantization crate and paged-attention crate are exactly that), fall back to a slower composed path, or wait for upstream. Several performance asymmetries in §7 trace back to this.

Internally the codebase is split into focused crates, in our own summary: a core engine crate (pipelines, scheduler, sequences, sampling), a quantization crate implementing a common quantized-linear interface and the on-disk Universal Quantized File Format (UQFF), a paged-attention crate with CUDA/Metal kernels, a server crate built on the Axum web framework, an MCP client crate, and the thin Rust/Python SDK crates.

### 2.2 Request flow and the pipeline abstraction

The runtime shape, reconstructed from the documentation and API references read, is a classic channel-fed engine loop:

1. A front door — CLI, HTTP handler, or SDK call — submits a request to a central router object.
2. The router forwards it over a Rust multi-producer/single-consumer channel to the engine that owns the requested model. Multi-model serving is therefore routing between engine instances, not a special mode inside one engine.
3. The engine, running on its own thread/task, turns the request into a *sequence* — the unit that tracks tokens, state (waiting, running, finished, aborted, swapped/preempted in the paged path), sampling parameters, multimodal inputs and the response channel.
4. A scheduler repeatedly selects which sequences advance, allocating or reclaiming KV-cache blocks when paging is active.
5. The model's pipeline executes one step — prefill chunk or decode step — over the selected batch, then sampling turns logits into next tokens, honouring per-sequence stop conditions, penalties and constraints.
6. Response chunks stream back to the caller until a finish condition is met.

The key abstraction is the **pipeline trait**: a single interface that a model family implements once and that the engine, scheduler, sampler and server then treat uniformly. Documented pipeline kinds include a normal text pipeline, a vision/multimodal pipeline, a speculative-decoding pipeline wrapping a draft and a target loader, an any-MoE pipeline that can graft mixture-of-experts structure onto a dense base, plus diffusion, speech and embedding variants that have accreted as model categories were added. A companion **loader trait** separates *how a checkpoint on disk becomes a pipeline* (plain safetensors loader, GGUF loader, UQFF loader, speculative pair loader) from *how the resulting model runs*.

Design consequences worth noting:

- **New model families are additive.** Supporting a new architecture means adding a loader plus a pipeline implementation; the HTTP API, batching, prefix caching, LoRA selection, tool calling and metrics do not need to know it exists. The project claims 45+ architectures across text, multimodal, speech, image-generation and embedding categories, with the supported-models reference generated from the loader registry so the docs cannot silently drift from the code — a small but telling discipline.
- **Auto-detection is part of the architecture, not a convenience script.** Architecture, weight format, quantization config and chat template are inferred from the checkpoint's own metadata (`config.json`, GGUF metadata, quantization config) with flags available to override. The user's contract is essentially "name a Hugging Face repo or a file"; the loader registry does the rest.
- **Multimodality is not a sidecar.** Vision, audio and video encoders, projectors (including separate GGUF projector files), and speech output are inputs and outputs of pipelines, so the same scheduler and prefix cache handle a request that mixes text and images. Prefix caching is explicitly documented as working for multimodal prefixes.
- **Sampling and constraint logic live outside the model.** A central sampler owns temperature, top-k, top-p, min-p, frequency/presence/repetition penalties, stop sequences and maximum length, and the engine integrates grammar-constrained generation (via llguidance) and reasoning/thinking parsers as pipeline-adjacent services. A model implementation never re-implements sampling.

*Speculation, marked as such:* the pipeline uniformity is also the project's main scaling risk. A trait wide enough to cover autoregressive text, block-diffusion generation, speech synthesis and image diffusion will accumulate optional capabilities that only some pipelines honour — the documentation already shows this pattern, e.g. features that work for safetensors loads but are refused for certain GGUF architectures, and cache behaviours that differ for hybrid recurrent/attention models. Uniformity is real at the request/scheduler level and leakier at the feature-matrix level.

### 2.3 In-situ quantization (ISQ) as a design

ISQ is mistral.rs's signature idea and deserves treatment as a design philosophy, not just a format list (§5 has the menu).

**The problem it attacks.** In a pre-converted ecosystem, quantization is a publishing act: someone must convert a checkpoint ahead of time, host every size variant, and the user can only run sizes someone bothered to publish. New model releases lag their quantized editions by hours to days, and an unusual size (say 5-bit or 6-bit) may never exist.

**The mistral.rs answer.** Quantization is a *load-time transformation*. The user names an ordinary full-precision (or higher-precision) checkpoint and a target — a bit width (`--quant 4`), an exact format (`--isq q4k`), or `auto` — and the loader quantizes each layer as it streams it in, so the full-precision model never needs to be resident all at once. Three refinements make it a system rather than a trick:

1. **Prebuilt-first, quantize-as-fallback.** On the CLI, a bit-width request first looks for an already-quantized artefact — a UQFF file in a community repository for safetensors models, or the matching file in a GGUF repository — and only falls back to doing ISQ itself when no match exists. `--isq` exists precisely to skip that lookup and force local conversion. The SDKs invert the default: they always quantize locally unless handed a UQFF explicitly.
2. **Pay once, keep the result.** An ISQ result can be saved as a UQFF file, turning an expensive first load into a fast artefact for later loads and for other users. UQFF is thus best understood as the cache format of the ISQ system, not as a competing publishing format.
3. **Hardware-relative meaning of a number.** A bare bit width is deliberately *not* a format. On Metal, `4` resolves to the affine AFQ4 format tuned for Apple Silicon; on CUDA and CPU it resolves to the GGML Q4K format; `8` resolves to AFQ8 versus Q8_0 respectively; `5` is Q5K everywhere. The user expresses an intent ("about 4 bits, best for my machine") and the engine owns the mapping. Embeddings and output heads are automatically held at higher precision than the bulk of the model under aggressive settings (for example a Q4K body keeps Q6K embeddings/head; an AFQ4 body keeps AFQ6), because those tensors are disproportionately quality-sensitive.
4. **Escape hatches for experts.** A per-layer *topology* file can override the format layer by layer; an importance matrix (imatrix, from a file or built from a calibration text at load time) improves low-bit K-quant quality; a MoE-specific organisation mode can quantize only the experts while leaving shared layers dense; and a running server can even be re-quantized in place through an administrative endpoint, with the honest caveat that going back up in bit width cannot restore precision already discarded.

The cost side is equally structural: every cold load pays conversion time and download size for the *original* weights (a BF16 download to produce a 4-bit resident model), low-bit results without calibration are naive round-to-nearest-style conversions rather than calibration-optimised GPTQ/AWQ artefacts, and reproducibility depends on the engine version doing the conversion. §8 returns to this trade.

## 3. Scheduling and batching

### 3.1 Continuous batching as the default posture

mistral.rs performs continuous batching by default on all devices: sequences join and leave the running batch at step boundaries rather than waiting for a whole static batch to finish. The serving default is up to 32 concurrent sequences (`--max-seqs 32` for `serve` and both SDKs; `run` defaults to 1, matching its interactive purpose), and requests beyond the limit queue.

An important qualification, stated plainly in the project's own tuning guide: without paged attention — that is, on CPU, or with paging explicitly off — batching only groups sequences of equal length, so raising the concurrency limit helps much less. The strong form of continuous batching in mistral.rs is inseparable from the paged path below.

### 3.2 Paged attention: implementation and current state

**Verified current state (2026-11-15):** paged attention is implemented in a dedicated crate with CUDA and Metal kernels, is available on CUDA and Apple Silicon for supported models, and — the headline change in v0.9.5 — is now the *default on supported Metal models* as well as on CUDA, with automatic memory planning shared across CLI and SDKs. On CPU, and for models without paged support, the engine uses a conventional per-request contiguous cache instead. The default block size recorded in the API documentation is 32 tokens.

Mechanics, in the standard paged design as mistral.rs documents it:

- The KV cache is one shared pool of fixed-size blocks. A sequence acquires blocks as it grows and returns them on completion; logical contiguity is maintained through a per-sequence block table rather than physical contiguity, which removes the worst-case pre-reservation waste of contiguous caches.
- Blocks are shareable: sequences beginning with the same tokens can point at the same physical blocks, which is the mechanism underneath prefix caching on the paged path.
- Every CUDA build ships FlashInfer kernels for paged decode; optional FlashAttention v2 (compute capability 8.0+) or v3 (Hopper) builds accelerate prefill. Paging works without either.
- On CUDA, decode steps are additionally captured as CUDA graphs and replayed, removing most per-token kernel-launch overhead — particularly valuable for small models where launch cost is a large fraction of a token's time. Graph capture failure degrades gracefully to un-graphed execution with a warning.
- When the pool is exhausted, the engine preempts: a running sequence is paused and its work recomputed later. A Prometheus counter (`mistralrs_paged_preemptions_total`) exposes this, and the tuning guidance treats a climbing counter as the signal to lower concurrency or enlarge the cache. Note the chosen preemption strategy is recomputation rather than swapping blocks to CPU RAM, at least as documented; sequence states include a swapped state in the codebase's vocabulary, but the user-facing guides describe pause-and-recompute behaviour.

### 3.3 Prefill/decode interleaving

Scheduling is chunked-prefill based. Defaults from the tuning guide:

| Knob | Default | Meaning |
|---|---|---|
| `--max-num-batched-tokens` | 4096 | Total token budget per step across prefill and decode |
| `--max-prefill-chunk-tokens` | 512 | How much of a new prompt is ingested per step |
| `--max-decode-steps-before-prefill` | 8 | Decode steps guaranteed to running sequences before prefill work is admitted |

The trade being managed is explicit: larger prefill chunks improve time-to-first-token for newcomers and worsen inter-token latency for streams already running; the decode-steps floor does the reverse. Working memory is reserved from `--max-seqs` and `--max-num-batched-tokens` *before* the KV pool is sized, so both knobs indirectly shrink the cache (§4.2).

Speculative decoding exists as a dedicated pipeline kind with a draft/target pair. Its real-world value in mistral.rs is questionable on current evidence — see the independent benchmark in §7.3, where enabling a drafter made mistral.rs slower at every draft length tested.

### 3.4 Prefix caching

**Verified current state:** prefix caching is on by default, including for multimodal prompts, and is observable as reduced time-to-first-token on the second and later requests sharing a prefix.

Its semantics split by path, and the documentation is unusually candid about the split:

- **Paged path, standard transformers:** there is effectively no separate prefix store to size. Any prefix whose blocks still live in the KV pool is reused; eviction is simply pool pressure. A `--prefix-cache-n` value does not limit reuse here — only setting it to `0` (off) changes behaviour.
- **Non-paged path:** the setting counts finished requests whose caches are retained (default 16).
- **Hybrid attention/recurrent models** (e.g. Qwen3.5, Granite 4.0 families): the setting counts saved recurrent states, and the engine may silently keep fewer than the default 16 to fit memory. One documented gap: on Metal, Qwen3.5 hybrid models do not yet reuse the cache for repeated identical prompts — hit counts stay at zero there.

For a future implementer, this is the honest shape of prefix caching in a multi-architecture engine: one user-visible switch, three different mechanisms underneath.

## 4. KV cache and memory

### 4.1 Two cache implementations

The engine carries both a normal per-request cache and the paged cache behind a common wrapper, selected by device, model support and user flags (`--paged-attn off` forces the normal path). Everything in §3.2–3.4 about block sharing, preemption and graph capture belongs to the paged side; the normal side is simpler, works everywhere including CPU, and batches poorly (§3.1). Sliding-window and hybrid architectures maintain their own cache shapes inside this framework — hybrid models carry recurrent state alongside attention KV, which is why their prefix-cache and memory behaviour diverges.

An FP8 KV-cache option (`--pa-cache-type f8e4m3`) stores cached keys/values in E4M3 FP8 at half the bytes of BF16, doubling the token capacity of a given pool budget, independently of how the weights themselves are quantized. It is documented as unavailable for multi-head latent attention models such as DeepSeek V3.

### 4.2 Memory sizing behaviour

Memory planning is automatic and, since v0.9.5, unified across entry points. The default algorithm, as documented:

1. Load the weights.
2. Reserve working/activation memory implied by the concurrency and batched-token settings.
3. Reserve headroom for the rest of the system: 5% of GPU memory (minimum 1 GiB) on discrete GPUs; 25% (maximum 16 GiB) on unified-memory devices — so a 64 GiB Mac plans around a 48 GiB ceiling. Memory already consumed by other applications at startup shrinks the budget further.
4. Give everything remaining to the KV pool.

Two overrides exist and are mutually exclusive: an exact cache size (`--kv-cache 8GiB` or `--kv-cache 65536tokens`, where a byte budget is the total across all of the model's GPUs, and an unsatisfiable request fails the load rather than silently shrinking), or a global cap (`--gpu-memory-utilization 0.9`, under which weights, working memory and cache together stay below the fraction and the cache takes the residue). In multi-model serving the budget is split between models in proportion to their `--max-seqs` values.

Two practical readings. First, this is vLLM-style "use what is left" planning transplanted into a local runner — the user rarely sizes a cache by hand. Second, it is fragile at the margins: the independent test in §7.3 found that on an 8 GiB card, sizing by memory fraction caused mistral.rs to reserve roughly 300 MiB of multimodal encoder memory per running sequence and then refuse requests with HTTP 503 memory-pressure errors, while an explicit token-sized cache worked. Automatic planning is only as good as its per-model overhead estimates.

Context length is bounded by the pool as well as by the model's trained/configured limit; the engine exposes controls to check, raise or cap it, but no cache setting can conjure tokens the pool cannot hold.

### 4.3 Device support matrix — and the ggml comparison

| Backend | Status in mistral.rs (via Candle) | Notes |
|---|---|---|
| CPU (x86-64, ARM) | Supported everywhere | Pure-Rust GEMM by default; MKL on x86-64 or Accelerate on macOS optional. Thread count auto-selected (one per physical core; one per performance core on Apple Silicon and heterogeneous Linux). Optional Linux CPU pinning/masking via environment variables. |
| NVIDIA CUDA | Primary GPU backend | Minimum compute capability 5.3 per project docs. FlashAttention v2 needs Volta–Ada class hardware (SM 7.0–8.9 via the Candle bindings; the paged guide states the `flash-attn` build at CC 8.0+), v3 needs Hopper (SM 9.0). FlashInfer paged-decode kernels in every CUDA build. cuDNN available. Multi-GPU via tensor parallelism (NCCL), layer/device mapping, and multi-node modes. CUDA graphs for decode. |
| Apple Metal | Primary Apple backend | Native kernels including the AFQ quantization family designed for it; paged attention default since v0.9.5; SDPA eager path rather than FlashAttention (the FlashAttention libraries are CUDA-only). Unified-memory planning as in §4.2. |
| Everything else | Not supported | No Vulkan, ROCm/AMD, SYCL/oneAPI, or WebGPU backend in the Candle stack mistral.rs builds on. |

**What this buys versus ggml's breadth.** ggml (llama.cpp's substrate, and therefore Ollama's) runs essentially anywhere: CUDA, Metal, Vulkan (which is its AMD and much of its Intel/embedded road), ROCm, SYCL, and CPU variants for every architecture that matters. mistral.rs runs in fewer places but integrates more deeply where it does run: one Rust device model, paged kernels, graph capture and quantization formats are co-designed per backend rather than spread thin. The concrete costs of the narrow matrix are: AMD GPU users are excluded entirely (for Volmarr's fleet this is not academic — the Strix Halo machine that dominates his current hardware work has no mistral.rs GPU path at all); Intel GPU users likewise; and older or exotic hardware that Vulkan would have covered falls back to CPU. The concrete gain is engineering focus — AFQ exists because Metal is a first-class citizen rather than one backend among nine, and paged attention shipped on Metal unusually early for the same reason.

Device mapping within the supported world is flexible: models can be split across multiple GPUs by layer mapping or tensor parallelism, and can spill between GPU and CPU (the `tune` tool labels such splits "Hybrid"), which is how oversized models remain loadable on small cards at a speed penalty.

## 5. Quantization breadth

### 5.1 The menu

mistral.rs's claim is breadth across *both* pre-quantized ecosystems and its own load-time conversion. Summary from the quantization reference and guides read:

**Loadable pre-quantized formats**

| Family | Variants / bits | Where it runs | Notes |
|---|---|---|---|
| GGUF / GGML | Legacy Q4_0, Q4_1, Q5_0, Q5_1, Q8_0, Q8_1; K-quants Q2_K–Q6_K, Q8_K storage | CPU, CUDA, Metal | Loaded as-is; per-file selection by bit width or exact label. **IQ formats (IQ1/IQ2/IQ3/IQ4 families) do not load** — the single largest compatibility gap versus llama.cpp/Ollama. |
| GPTQ | Typically 4-bit, also 2/3/8-bit ecosystem artefacts | CUDA-oriented kernels (CPU paths exist in the quant crate) | Detected from checkpoint config; no flag needed. Pre-quantized only — ISQ cannot produce GPTQ. |
| AWQ | Typically 4-bit | CUDA-oriented | As GPTQ: config-detected, load-only. |
| FP8 checkpoints | E4M3, per-tensor or block-scaled (incl. 128×128 block scale with dynamic activation scaling on Hopper via a CUTLASS W8A8 path) | CUDA primarily; portable FP8 providers elsewhere; a CPU-only F8Q8 variant exists | Checkpoint's scale tensors and exclusion lists are honoured as published. NVFP4 checkpoints are also listed as config-detected loads. |
| BitsAndBytes | 4-bit and 8-bit | CUDA | Load support for the HF training-ecosystem format. |
| MXFP4 | 4-bit microscaling | CUDA and Metal; no CPU | Kernel availability depends on build and GPU. |
| HQQ | hqq4, hqq8 | CPU, CUDA, Metal | Also producible by ISQ. |
| UQFF | Any ISQ type, serialised | All backends | The project's own format; the artefact ISQ produces and consumes (§2.3). |

**Producible by ISQ at load time:** the K-quants (Q2K–Q6K, Q8K where the backend supports it — notably not in CUDA builds for Q8K), legacy Q4_0/Q4_1/Q5_0/Q5_1/Q8_0 (Q8_1 not in CUDA builds), the AFQ family (AFQ2/3/4/6/8), FP8, HQQ4/HQQ8 and F8Q8 (CPU). In other words, ISQ's output menu and the GGUF load menu substantially overlap, which is what makes "download the BF16 original, run it as Q4_K" a coherent promise.

### 5.2 The philosophy

Three principles organise the menu:

1. **Load anything, convert what is missing.** The engine refuses as little as possible: safetensors in any supported precision, GGUF, GPTQ/AWQ/FP8/NVFP4 as published, or a full-precision checkpoint plus a size intent. The only hard refusal of note is the IQ family — significant because the smallest, most aggressive community GGUFs (the ones that make very large models fit consumer memory) are disproportionately IQ builds. A user whose library is built around IQ quants will find mistral.rs cannot open their files, full stop.
2. **One numeric intent, many physical formats.** The bit-width shorthand and `auto` mode (§2.3) mean most users never learn the format zoo; experts can name exact formats, per-layer topologies, imatrix data and MoE-only organisation when they want control. `mistralrs tune` closes the loop by estimating, from config files alone before any large download, each format's size, memory share, fittable context and a quality label (8-bit "near-lossless" down to 2/3-bit "degraded"), and printing a ready-to-run recommended command.
3. **Quality guardrails by default.** Automatic higher precision for embeddings and heads, imatrix support at low bit widths, and topology overrides all push against the naive failure mode of uniform aggressive quantization — at the cost of a resident size slightly larger than the headline bit width suggests.

## 6. Serving surface

Design-level summary; this is not an API reference.

- **Protocols.** The server (`mistralrs serve`, default port 1234 in the quickstart) exposes an OpenAI-compatible `/v1` API — Chat Completions and the newer Responses API, plus embeddings — and, alongside it, Anthropic-compatible `/v1/messages` and token-counting endpoints, explicitly so that coding agents built for either ecosystem (the docs name Claude Code and Codex) can run against a local model unmodified. A built-in web UI is served at `/ui` by default (disable with `--no-ui`), and Prometheus metrics are exposed at `/metrics` with per-request counts and latency labelled by method, route and status, including the paged-attention preemption and prefix-cache counters referenced in §3.
- **Sampling controls.** Per request: temperature, top-k, top-p, min-p, frequency/presence/repetition penalties, maximum tokens/length, stop sequences, and seed-style determinism controls where the underlying request schema supports them. Grammar-constrained and structured output is a first-class request feature (JSON-schema-style constraints enforced during sampling, with a strict-schema tool mode), as are reasoning controls for thinking models (including the ability to disable thinking via chat-template arguments — which, per §7.3, matters more than it should).
- **Tool use — two tiers.** Tier one is conventional: the model emits tool calls against caller-supplied schemas, with grammar enforcement, and the caller executes them. mistral.rs additionally offers dispatch variants — POSTing tool calls to a caller-provided URL, or invoking Python/Rust callbacks in the SDKs. Tier two is a server-side agentic runtime: the server itself can execute tools and feed results back in a loop, with built-in web search (embedding-ranked), persistent Python code-execution sessions, persistent shell sessions with sandboxing/approval controls, session management, uploadable reusable "Skills" bundles referenced from Responses requests, OpenAI-compatible file uploads (`/v1/files`) that can be attached to requests and mounted into code/shell sessions, and an MCP client that imports external tool servers over process, HTTP or WebSocket transports.
- **Multi-model and adapters.** Several models can be served by one process with runtime load/unload and per-request model routing (§2.2, §4.2). LoRA and X-LoRA adapters are supported with per-request adapter selection, including on GGUF bases for architectures whose weight layout permits it — with documented refusals for several major families (llama, mistral3, deepseek2, glm4 GGUF layouts are named as incompatible), in which case the safetensors checkpoint must be used.

*Reading:* the serving surface has visibly outgrown "local runner with an HTTP flag". The agentic runtime in particular is a product bet — mistral.rs wants to be the local backend that agent frameworks talk to — and it expands the maintenance and security surface (shell execution, code execution, file mounts) far beyond what a pure inference engine needs. That is a deliberate trade, and §8 scores it as both.

## 7. Performance character

All numbers below carry their hardware and source. Two families of evidence exist: the project's own published benchmarks, and one detailed independent comparison. They tell different halves of the story.

### 7.1 Vendor numbers: v0.8.2 CUDA report (as republished in the README)

Method as stated by the project: mean tokens/second across prompt lengths and decode depths from 128 to 16,384 tokens, decode measured over 256 generated tokens, full commands and host metadata in the linked release report. Hardware: NVIDIA GB10, B200, and H100 SXM — datacentre/flagship parts, not consumer cards.

**Q8 prefill, mistral.rs UQFF Q8 vs llama.cpp GGUF Q8_0 (tokens/s):**

| Model | Hardware | mistral.rs | llama.cpp | Ratio |
|---|---|---:|---:|---:|
| Gemma 4 E4B | GB10 | 7,395.7 | 3,973.7 | ~1.86× |
| Gemma 4 E4B | B200 | 27,705.6 | 11,992.4 | ~2.31× |
| Gemma 4 E4B | H100 SXM | 26,220.6 | 11,702.1 | ~2.24× |
| Gemma 4 26B-A4B | GB10 | 2,947.0 | 2,178.5 | ~1.35× |
| Gemma 4 26B-A4B | B200 | 12,725.3 | 8,503.4 | ~1.50× |
| Gemma 4 26B-A4B | H100 SXM | 12,362.3 | 8,055.1 | ~1.53× |

**Q8 decode, same pairing (tokens/s):** mistral.rs leads in all six cells but modestly — e.g. E4B on B200 241.4 vs 194.4 (~1.24×), E4B on GB10 44.1 vs 40.5 (~1.09×), 26B-A4B on GB10 46.8 vs 46.4 (~1.01×).

**BF16 vs vLLM** is where the report becomes genuinely informative, because the project publishes its losses. Prefill on the small E4B is roughly parity (GB10 5,838.9 vs 5,812.9; B200 43,547.8 vs 39,431.2 in mistral.rs's favour; H100 35,852.2 vs 39,293.7 against it), and E4B decode favours mistral.rs in all three cells (e.g. B200 202.6 vs 196.2). But on the MoE model, Gemma 4 26B-A4B at BF16, prefill collapses: 592.2 vs vLLM's 3,878.6 on GB10, 3,467.3 vs 28,532.8 on B200, 2,766.0 vs 26,295.9 on H100 — roughly **0.07×–0.15× of vLLM** — while its decode stays within ~0.72×–1.16×. A BF16 MoE prefill path that is an order of magnitude behind is a real, self-reported defect, presumably in expert-routing/prefill kernel efficiency at full precision (the Q8 MoE prefill numbers above are healthy, which localises the problem).

### 7.2 Vendor numbers: Metal, v0.5.0 era

From the project's v0.5.0 announcement as summarised in secondary reporting: Apple M3 Max, 8-bit models, generation (TG) and prompt-processing (PP) tokens/s.

| Model | Engine | TG | PP |
|---|---|---:|---:|
| Llama 3.2 3B 8-bit | mistral.rs | 71.44 | 1,116.60 |
| | llama.cpp | 76.87 | 1,532.91 |
| | MLX | 94.61 | 1,422.47 |
| Llama 3.1 8B 8-bit | mistral.rs | 37.94 | 606.36 |
| | llama.cpp | 39.20 | 736.68 |
| | MLX | 44.22 | 670.71 |

Reading: on Apple Silicon, mistral.rs is in the same class but consistently third — within ~3–7% of llama.cpp on generation for the 8B, ~19–27% behind on prompt processing, and clearly behind Apple's own MLX. The same release claimed a ~30× reduction in ISQ queuing/startup time on Metal, which is an experience improvement (time to a usable quantized model) rather than a throughput claim.

### 7.3 Independent numbers: six engines on an 8 GiB RTX 3050

An independent, fully documented comparison (xbill9/gemma4-dev; mistral.rs v0.9.5, CUDA + FlashAttention build) ran Gemma 4 E2B on Google's QAT 4-bit weights, exact Q4_0 GGUF for mistral.rs and llama.cpp, on a single RTX 3050 OEM (8 GiB, sm_86) in an i7-5820K desktop, greedy decoding, identical prompts and load sweeps for all engines.

- **Single request:** mistral.rs 118.9 end-to-end tokens/s — statistically with the leaders (vLLM 121.1, SGLang 119.9, a bespoke PyTorch engine 118.9, llama.cpp 108.8). Single-stream decode is *not* mistral.rs's problem.
- **Under concurrency (128 in / 512 out, no drafter):** at 64 simultaneous requests, aggregate output was vLLM 1,651, SGLang 1,711, llama.cpp 633, **mistral.rs 308 tokens/s** — and mistral.rs's aggregate was already flat at ~308 from 8 requests upward. Crucial context: in that rig mistral.rs could only be configured to hold 4 concurrent requests (fixed 8,192-token cache, 1,024 batched tokens per step; §4.2 describes the memory-fraction failure that forced this), so the ceiling is partly a configuration/memory-planning artefact on a small card rather than a proven kernel limit. Even discounted, it demonstrates that mistral.rs's serving defaults and memory planner are tuned for larger memories and degrade awkwardly at 8 GiB.
- **Speculative decoding:** the E2B drafter *slowed* mistral.rs to 0.72× at its best setting (85.8 vs 118.9 tokens/s) and lost at every draft length, while vLLM gained 1.90× and llama.cpp 1.35×. Acceptance rates were comparable across engines (~62% at one token), so the loss is verification overhead in mistral.rs's speculative path, not draft quality.
- **Quality:** GSM8K 0.9030 (best of the six, all within noise) and BFCL tool-calling 0.9150 — the engine is numerically sound; its deficits are throughput-under-load and configuration, not correctness. One usability trap recorded: mistral.rs defaults to thinking-on for Gemma 4 where the other engines default off, which silently cost ~10× evaluation time and truncated answers until disabled per request.

### 7.4 Credibility assessment — our honest reading

- The vendor CUDA report is *better than average* vendor practice: named hardware, named opponent builds/formats, a stated averaging method, a linked full report, and the inclusion of a table (BF16 MoE prefill) in which the project loses by an order of magnitude. Claims of large Q8 *prefill* wins over llama.cpp (~1.4–2.3×) are plausible in direction — prefill is compute-bound GEMM work where a well-tuned stack with graph capture and modern kernels can genuinely beat llama.cpp's more decode-optimised Q8_0 path — but the margins should be treated as best-case: flagship hardware, the project's own UQFF format against GGUF, and a young model family (Gemma 4) whose llama.cpp support was itself new.
- Decode claims are modest and therefore believable (~1.0–1.25× over llama.cpp at Q8; mixed parity with vLLM at BF16 on a dense model).
- No vendor claim of high-concurrency serving superiority survives the independent test. On consumer memory sizes, vLLM and SGLang scale to several times mistral.rs's aggregate throughput, and mistral.rs's speculative pipeline is currently a pessimisation. Anyone quoting mistral.rs as "faster than vLLM" without qualifiers is repeating marketing, not evidence.
- Net character: **fast single-stream engine, competitive prefill on NVIDIA flagships, ordinary-to-weak batched serving on small hardware, immature speculative decoding.** For a local-first runner — Ollama's actual workload — the single-stream and prefill profile matters more than the 64-request profile, which is why the engine remains interesting despite §7.3.

## 8. Strengths and weaknesses

### Strengths

1. **Lowest-friction path from "a Hugging Face repo exists" to "it is running quantized on my machine."** Auto-detection plus ISQ plus `tune`/`auto` removes the conversion-and-publishing pipeline entirely (§2.3, §5.2). No other runner studied in this campaign makes quantization a load-time user intent in this way.
2. **Genuine pipeline uniformity.** One engine, scheduler, sampler, cache and API serve text, vision, audio, video, speech, diffusion and embedding models across 45+ architectures, with per-request LoRA and multi-model routing (§2.2).
3. **Datacentre serving mechanics on consumer hardware.** Paged attention by default on both CUDA *and* Metal, continuous batching, chunked prefill, block-sharing prefix caching, FP8 KV cache and CUDA-graph decode in a single local binary (§3, §4).
4. **Format ecumenism.** GGUF, GPTQ, AWQ, FP8/NVFP4, BitsAndBytes, HQQ, MXFP4, AFQ and its own UQFF in one loader (§5.1) — broader *kind* coverage than llama.cpp (GGUF-centric) or vLLM (GPU-quant-centric), even with the IQ hole.
5. **Embeddability and deployment shape.** Native Rust core with Rust and Python SDKs, an installer-script CLI, and no Python runtime requirement — the easiest studied engine to embed inside another application.
6. **Dual-protocol serving.** OpenAI and Anthropic APIs from one process, plus metrics and a web UI, makes it a drop-in local backend for existing agent tooling (§6).
7. **Documentation honesty.** The guides state their own limitations inline (hybrid-model prefix gaps, Metal cache misses, preemption signals, IQ refusal, GGUF+LoRA refusals). This dossier relied on that candour repeatedly.

### Weaknesses

1. **No AMD or Intel GPU path** (§4.3). Candle's CUDA/Metal/CPU matrix is the engine's matrix. For fleets with AMD hardware — including Volmarr's primary AI machine — mistral.rs is a CPU engine.
2. **IQ-format GGUFs do not load** (§5.1). The most aggressive community quants, often the *only* way a large model fits a given machine, are refused. This is a hard compatibility wall, not a performance caveat.
3. **Batched serving does not scale like vLLM/SGLang**, and memory planning misbehaves on small cards (§7.3, §4.2). The engine's serving story is strongest at low concurrency.
4. **Speculative decoding currently hurts** on the one independent measurement available (§7.3).
5. **BF16 MoE prefill is an order of magnitude behind vLLM** by the project's own numbers (§7.1) — full-precision MoE users are poorly served until that path is fixed.
6. **ISQ's costs are structural** (§2.3): full-size downloads, conversion time on every cold load (mitigated, not eliminated, by UQFF caching), and naive-conversion quality at low bit widths versus calibration-built GPTQ/AWQ/IQ artefacts.
7. **Single-maintainer gravity and pace risk.** The project is closely identified with one author and ships features at a pace (new model families, an agentic runtime, two API protocols, skills/files subsystems) that necessarily thins review and testing per feature; the §7.3 traps (thinking-on default divergence, memory-fraction 503s) are the visible symptoms. *This is an assessment of project shape from the sources read, not a claim about any individual's capacity.*
8. **Scope creep as attack/maintenance surface.** Shell execution, code execution, file mounting and web search inside an inference server (§6) are features a pure runner does not need to secure. An adopter who only wants inference inherits that surface anyway.

## 9. Ideas to steal for a Go runner

Written for an improved Ollama-class runner in Go. Each idea states the expected gain and the cost/risk of transplanting it. None of this requires copying mistral.rs code or design text — these are behaviours and contracts, re-implementable from first principles.

### 9.1 ISQ-style load-time quantization as the primary user experience

**Steal:** the contract, not the formats. Let the user say `run <model> --quant 4` (or `auto`) against an *unquantized or higher-precision* source and have the loader quantize layer-by-layer during streaming load, never materialising the full-precision model; resolve the bare number to the best physical format for the detected backend; hold embeddings and head at higher precision automatically; offer a `tune`-style dry run that estimates size/context/quality from config metadata before downloading; and cache the result in a local artefact format so the conversion is paid once.

**Expected gain:** eliminates the publish-every-size bottleneck that defines the GGUF ecosystem's lag and gaps; any model on the Hub becomes runnable at any supported size on day one; `auto` gives non-expert users a correct-by-construction answer to "what fits my machine?", which is the single most common local-inference question. For Ollama specifically, this turns the library from a catalogue of prebuilt sizes into a capability.

**Cost/risk:** a real quantizer suite must be built and validated per format in Go (K-quants first; imatrix support for low bits is where quality is won); cold-load latency and full-size downloads will generate user complaints unless the artefact cache and prebuilt-first lookup (check for an existing converted blob before converting) ship in the same release; naive low-bit quality must be labelled honestly, as mistral.rs's "degraded" tier is, or trust erodes. Rollout risk is moderate and incremental — it can debut for one format family behind the existing prebuilt path.

### 9.2 Pipeline uniformity: one sequence/scheduler/sampler contract for every model kind

**Steal:** the architectural discipline of §2.2 — a single internal pipeline interface (step over a batch of sequences; sample under shared parameters; report capabilities) with per-family loaders translating on-disk formats into that interface, a registry from which supported-model documentation is *generated*, and all cross-cutting features (batching, prefix caching, adapters, tool calling, metrics, grammar constraints) implemented once against the interface rather than per model.

**Expected gain:** multimodal support stops being a fork of the text path — vision/audio inputs become sequence payload, so scheduling, caching and the HTTP API extend without redesign; new architectures land faster because only loader + forward code is new; generated support docs end the chronic drift between "models we claim" and "models that load".

**Cost/risk:** the interface must be designed against the hardest cases early (hybrid recurrent state, diffusion's non-autoregressive steps, MoE routing) or it will leak exactly as mistral.rs's does (§2.2 speculation); capability flags per pipeline are unavoidable and must be surfaced in errors, not hidden. In Go, the equivalent is a small interface plus explicit capability struct — cheap to build, expensive to retrofit, so the value is highest if adopted before the next model-family expansion.

### 9.3 Paged attention in a non-datacentre binary — with honest small-memory behaviour

**Steal:** a block-pooled KV cache (fixed-size blocks, per-sequence block tables, block sharing for prefix reuse) as the *serving* cache on GPU backends, automatic pool sizing from post-load free memory with explicit headroom rules per memory type (small fixed reserve on discrete VRAM; a large capped reserve on unified memory), an exact-size override that fails loudly instead of silently shrinking, preemption-by-recompute with an exposed counter, and chunked-prefill scheduling knobs (per-step token budget, prefill chunk size, decode-step floor) with the documented defaults of §3.3 as a starting point.

**Expected gain:** this is the difference between "concurrent requests mostly waste reserved cache" and real continuous batching on a home GPU: more simultaneous sessions per GiB, shared system-prompt prefixes paid once, and graceful degradation (preemption) instead of out-of-memory refusal. It directly serves the multi-agent future — many small local sessions against one runner — that a single-user contiguous cache serves badly.

**Cost/risk:** this is the most expensive idea here. Paged attention needs block-table-aware attention kernels per backend (in a Go runner, that means work in the underlying tensor layer — ggml-side or a new kernel path — not in Go orchestration code); the kernel tax for indirection is real (the original PagedAttention literature reports a slower attention kernel bought back many times over by batch capacity); and mistral.rs's own 8 GiB failure mode (§4.2, §7.3) is the cautionary tale — per-sequence overhead estimates and admission control must be tested on the *smallest* supported card, not the flagship. Sequence the work: block pool + sharing first (prefix wins arrive immediately), preemption and graph-style launch optimisation later.

### 9.4 Smaller thefts worth naming

- **`tune` before you download:** config-only size/context estimation with a printed ready-to-run command (§5.2). Gain: kills the download-then-OOM loop. Cost: days, not months. No excuse not to.
- **Prebuilt-first, convert-as-fallback resolution order** (§2.3): preserves today's fast path for popular sizes while making every other size possible. Gain: ISQ (§9.1) can ship without regressing anyone's first-run experience.
- **Prefix-cache semantics documented per mechanism** (§3.4): whatever the implementation, publish what is actually reused (blocks vs finished requests vs recurrent states). Gain: users can reason about their TTFT; support load drops.
- **Re-quantization honesty:** mistral.rs states plainly that re-quantizing upward cannot restore lost precision (§2.3). Any runner offering size switching should copy the sentence's spirit into its own docs.

## 10. Sources

All sources accessed 2026-11-15. Vendor sources are the project's own repository and documentation; independent sources are marked.

1. mistral.rs repository README (master, crawled 2026-11-15) — essence, feature set, v0.9.5/v0.8.2 release notes, v0.8.2 benchmark tables, SDK and installer shape. https://raw.githubusercontent.com/EricLBuehler/mistral.rs/master/README.md
2. mistral.rs `LICENSE` file (master, read directly 2026-11-15) — MIT licence verification. https://raw.githubusercontent.com/EricLBuehler/mistral.rs/master/LICENSE
3. Paged attention guide, mistral.rs documentation — default-on state for CUDA/Metal, memory-budget algorithm and headroom rules, `--kv-cache` / `--gpu-memory-utilization` semantics, FP8 KV cache, multi-model budget split, FlashInfer/FlashAttention and CUDA-graph notes. https://docs.mistralrs.dev/guides/perf/paged-attention/
4. Throughput tuning guide, mistral.rs documentation — `--max-seqs` defaults, chunked-prefill knobs and defaults, prefix-cache semantics per path, CPU threading/affinity, non-paged batching limitation. https://ericlbuehler.github.io/mistral.rs/guides/perf/throughput-tuning/
5. Quantize a model guide, mistral.rs documentation — `--quant`/`--isq` resolution order, UQFF lookup and fallback, ISQ layer-streaming behaviour, bit-width guidance and quality labels, hardware format mapping, imatrix/calibration, MoE-only quantization, in-place re-quantization, `tune` and `auto`. https://docs.mistralrs.dev/guides/quantization/quantize-a-model/
6. Quantization types reference, mistral.rs documentation — ISQ type catalogue (AFQ, K-quants, legacy GGML, FP8, MXFP4, HQQ), numeric shorthand table, sensitive-tensor precision policy, GPTQ/AWQ load behaviour. https://6acd09c9.mistralrs-docs.pages.dev/reference/quantization-types/
7. Run GGUF models guide, mistral.rs documentation — GGUF file selection by bit width, IQ-format refusal, projector/tokenizer asset discovery, GGUF re-quantization via ISQ, GGUF+LoRA restrictions. https://ericlbuehler.github.io/mistral.rs/guides/models/run-gguf/
8. DeepWiki architectural summaries of EricLBuehler/mistral.rs (generated from the repository; treated as secondary) — crate layout, engine/scheduler/pipeline request flow, scheduler variants, sequence states, FlashAttention integration and feature-flag hardware ranges, quantization-format hardware table. https://deepwiki.com/EricLBuehler/mistral.rs and subpages.
9. docs.rs, `mistralrs-core` API documentation — paged-attention configuration (default block size 32), scheduler and pipeline type names, multi-engine routing description. https://docs.rs/mistralrs-core/latest/mistralrs_core/
10. Hugging Face blog, mistral.rs v0.5.0 announcement, as summarised in secondary reporting (Undercode News, 2025-03-24) — M3 Max benchmark table versus llama.cpp and MLX, Metal ISQ startup improvement claim. Primary figures attributed to the project's own announcement; treated as vendor numbers. https://huggingface.co/blog/EricB/mistralrs-v0-5-0 (via https://undercodenews.com/mistralrs-v050-a-game-changer-for-llm-inference/)
11. **Independent:** xbill9, "Six Serving Engines, One 8 GB GPU: Gemma 4 E2B on an RTX 3050" (gemma4-dev rig, mistral.rs v0.9.5) — single-request parity, concurrency sweep, speculative-decoding regression, memory-planning failure mode, GSM8K/BFCL quality results; full rig and raw runs published with the article. https://mlh.forem.wtf/gde/six-serving-engines-one-8-gb-gpu-gemma-4-e2b-on-an-rtx-3050-ad7
12. Candle background: Hugging Face Candle framework overviews (RedlineSoft tour, 2026-10-03, and DeepWiki crate/backend summaries) — crate layout, CPU/CUDA/Metal backend structure, BLAS options, safetensors/HF-Hub integration. https://blog.redlinesoft.net/posts/candle-pure-rust-llm-inference/ and https://deepwiki.com/dandenkijin/candle

### Unverifiable / not established in this pass

- No independent benchmark of mistral.rs ISQ *quality* (perplexity or task scores versus calibration-built GPTQ/AWQ/IQ artefacts at matched bit widths) was found; §5's quality discussion rests on the project's own guardrails and labels, not on measured equivalence.
- No independent high-concurrency benchmark on large-memory hardware (24 GiB+) was found; §7.3's serving ceiling is explicitly an 8 GiB, 4-concurrent-sequence configuration and must not be generalised beyond the caveat given there.
- Exact current status of block *swapping* (versus recompute-only preemption) could not be settled from user-facing documentation; the guides describe pause-and-recompute, while codebase vocabulary includes a swapped sequence state. Recorded as documented-behaviour-only in §3.2.
- Release cadence, contributor counts and support responsiveness were not investigated and no claim about them is made beyond the project-shape observation in §8.
