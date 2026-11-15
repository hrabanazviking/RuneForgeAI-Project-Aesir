# OR-2 — MLX + MLX-LM: The Unified-Memory Exemplar

## 1. Header

| Field | Value |
|---|---|
| Name | MLX (core array framework) + MLX-LM (LLM package on top of it) |
| Vendor / steward | Apple Machine Learning Research, `ml-explore` organisation |
| Licence | MIT License — for both `mlx` and `mlx-lm` (verified in both GitHub repository sidebars, accessed 2026-11-15) |
| First release | MLX: 5 December 2023. MLX-LM was split out as its own repository in March 2025 (repo created 2025-03-11); the LLM code lived in MLX examples before that |
| Languages | Core in C++; public APIs in Python (primary), C++, C, and Swift that mirror each other closely. MLX-LM itself is Python |
| Backends (as of this writing) | Metal on Apple silicon (the design centre); CUDA on Linux; CPU on macOS and Linux. The unified-memory story in this dossier is the Metal/Apple-silicon path unless stated otherwise |
| Versions seen while researching | MLX documentation at 0.32.4; MLX-LM at 0.32.2 on PyPI (16 October 2026, requires Python 3.11+). Secondary deep-dives pinned MLX 0.32.3 / MLX-LM 0.32.0–0.32.2 — knob names below were cross-checked across those |
| Links | `https://github.com/ml-explore/mlx` · `https://github.com/ml-explore/mlx-lm` · Docs: `https://ml-explore.github.io/mlx/` · Models: Hugging Face organisation `mlx-community` |
| As of | 2026-11-15 (all web sources accessed 2026-11-15) |
| Dossier | OR-2, Ollama Research Forge, commissioned by Volmarr 2026-11-15. Clean-room: written in our own words from public sources; no code reproduced |

**Essence.** MLX is what a machine-learning framework looks like when it is designed *starting from* one physical memory pool shared by CPU and GPU, instead of being ported onto one. Arrays have no device residence; operations have a device (a stream). Evaluation is lazy, so the runtime sees a whole graph before it dispatches anything, and can fuse, elide, and schedule across CPU and GPU without ever copying a buffer. MLX-LM is the deliberately thin LLM layer on top — loading, KV caches, prompt caching, quantization, sampling, batching, speculative decoding, and a small OpenAI-style server — and it is the clearest working reference we have for how a model runner should behave when "VRAM" does not exist as a separate place. That is exactly why it matters for our fleet: the ASUS ROG Flow Z13 (purpleraider, AMD Strix Halo) is the same architectural bet in non-Apple clothing.

---

## 2. The unified-memory premise

### 2.1 One pool, several processors

On Apple silicon the CPU, GPU, and (via Core ML, not directly via MLX) the Neural Engine sit on one SoC and address one pool of LPDDR memory. There is no PCIe bus between system RAM and graphics RAM because there is no separate graphics RAM. MLX's documentation states the model plainly: when you create an array you do not specify a location; you specify the device *when you run an operation*, and any supported device can operate on any array without moving it.

Three consequences follow, and MLX-LM inherits all of them:

1. **Model size stops being a VRAM question and becomes a total-memory question.** A 128 GB Mac can hold a model that no single consumer discrete GPU can, because the GPU can address most of the machine's RAM (subject to the wired/working-set limits in §3.4 and §5). Capacity is the headline win.
2. **Placement becomes a scheduling decision, not a data-movement decision.** Small, dispatch-overhead-bound work can run on the CPU while a dense matmul runs on the GPU, on the *same buffers*. MLX's own unified-memory documentation gives a toy split (a large matmul on GPU, a long chain of tiny exponentials on CPU) measured on an M1 Max at roughly 1.4 ms split versus 2.8 ms GPU-only. The point is not the toy; it is that the split costs no copies, only a dependency edge.
3. **The bottleneck moves, it does not disappear.** Decode of a dense model is, to first order, "read all the weights once per token." On a unified machine that read competes for one memory bus with everything else — CPU work, the OS, the display, other processes. Bandwidth, not FLOPS and not capacity, sets tokens per second once the model fits. The working approximation used across the Apple-silicon community is: ceiling tok/s ≈ bandwidth (GB/s) ÷ resident model size (GB).

### 2.2 What it removes

- **Host-to-device and device-to-host copies** for weights, activations, and KV cache, and the synchronisation stalls that usually accompany them.
- **The duplicate-residency tax.** In a discrete-GPU runner the same weights often exist twice during load (once in host RAM, once in VRAM) and the KV cache must live in the scarcer pool even when host RAM is empty. In MLX there is one residency.
- **The offload cliff as a placement problem.** "Layers on GPU vs CPU" in llama.cpp-style offloading is largely a workaround for two pools. With one pool, the remaining question is which *processor* should execute an op, which is cheaper to change and to get wrong.
- **Explicit transfer APIs in user code.** There is no equivalent of moving a tensor to a device. This is a real API-simplification win: an entire class of "wrong device" errors cannot be expressed.

### 2.3 What it costs

- **Shared bandwidth contention.** CPU and GPU reads draw on the same bus. Co-executing CPU+GPU work does not create bandwidth; at decode time, where the GPU alone can already saturate the bus, splitting work across units adds nothing. An independent 2026 study of intra-operator CPU+GPU splitting on MLX (FusionML, arXiv:2607.22785) found exactly this boundary: splitting helped *prefill* (compute-denser) by roughly 1.15–1.38× in its Llama-shaped tests, and did not help decode, which stayed bandwidth-bound. Treat that as one researcher's replicated-but-not-peer-reviewed result, not an Apple claim.
- **Shared capacity contention.** The model, the KV cache, the OS, and the user's other applications all draw on the same gigabytes. There is no protected VRAM island. Memory pressure is a whole-machine event (§5).
- **No cheap "spill" tier.** On a discrete system, overflowing VRAM can spill to host RAM at PCIe cost — painful but bounded. On a unified system, overflowing means the OS pages to SSD or compresses memory; performance degrades in a much less predictable, system-wide way.
- **Residency must be managed explicitly.** Because the GPU works best on pages that stay resident, macOS/MLX expose *wired* (pinned, non-pageable) memory controls. Unified memory removes copies, then reintroduces a pinning discipline. This is the single most transferable lesson for Strix Halo (§7).

### 2.4 How lazy evaluation + the graph model exploit it

MLX operations do not compute when called. They record nodes in a dynamically built graph; computation happens on `mx.eval(...)`, on `mx.async_eval(...)`, or implicitly when a value is actually read (printing, `.item()`, conversion to NumPy, using a scalar for control flow).

On a unified machine this laziness buys four specific things:

1. **Whole-subgraph scheduling.** Because nothing has run yet, the scheduler sees dependencies across CPU and GPU streams together and inserts the cross-stream dependency itself. The programmer declares *where* each op runs (its stream); the runtime orders them.
2. **Dead-work elision and memory avoidance.** Outputs never evaluated are never materialised. The docs' own model-loading pattern depends on this: instantiate a model (nominally float32, nothing computed), then replace its weights with float16 weights, and peak memory reflects only the second state — an eager framework would have paid for both.
3. **Fusion headroom.** A recorded graph is the substrate `mx.compile` optimises (§3.3). Elementwise chains that would each have round-tripped unified memory become one kernel and one pass over the data — on a bandwidth-bound machine, halving traffic is equivalent to doubling the bus for that chain.
4. **Overlap via asynchronous evaluation.** `mx.async_eval` starts evaluation and returns, so Python can build the *next* graph while the GPU executes the current one. MLX-LM's generation loop depends on this to keep the decode pipeline fed; the MLX docs still mark `async_eval` experimental, which is worth noting as a maturity signal.

The cost of laziness is also real: graphs that are never periodically evaluated grow without bound (the docs warn explicitly about training loops that forget to evaluate — memory "blows up" because the graph, not the data, accumulates), and any value-dependent control flow forces a synchronising evaluation mid-graph.

---

## 3. MLX core design

### 3.1 Arrays

- NumPy-shaped API by design: shapes, dtypes, broadcasting, slicing, reductions. Higher layers (`mlx.nn`, `mlx.optimizers`) deliberately echo PyTorch so model code ports with mostly mechanical changes.
- Arrays are *values in shared memory*, not residents of a device. An array carries no `.to(device)` semantics; device choice lives on the operation/stream. Secondary analyses describe the cross-device "transfer" accurately as a cache-flush/fence, not a byte copy — that phrasing is an interpretation, but it matches the documented behaviour.
- Dtypes include the usual float/int family plus bfloat16/float16, and the quantized storage schemes in §4.4 are built from array primitives (`mx.quantize` / dequantize) rather than being a separate tensor type.
- Function transformations compose: automatic differentiation (`grad`, `value_and_grad`), vectorisation (`vmap`), and `compile` can wrap each other's outputs. This JAX-like composability is a design choice, not an accident — MLX cites NumPy, PyTorch, JAX, and ArrayFire as inspirations in its README.

### 3.2 Dynamic graphs

Unlike a static-graph framework, MLX builds the graph dynamically on every call path actually taken. Changing input shapes does not, by itself, trigger the kind of slow recompilation associated with static compilation pipelines (compilation via `mx.compile` is opt-in and cached separately, §3.3). Debugging stays close to eager Python: you can print an intermediate and it simply evaluates that subgraph.

### 3.3 Compilation — `mx.compile`

- First call to a compiled function traces it with placeholder inputs, simplifies the graph (merging common work, folding constants, removing no-ops), fuses fusible elementwise chains into generated Metal kernels, and caches the result.
- Recompilation is triggered by changes in input shape/rank, dtype, or number of inputs. `shapeless=True` opts a function out of shape specialisation where its kernels allow it, at the price of breaking any logic that secretly depends on shapes.
- Compiled functions must be effectively pure. State (model parameters, optimizer state, RNG state) is handled explicitly by declaring captured `inputs=` / `outputs=` collections — a discipline MLX-LM and training code both rely on.
- Tracing caveats are JAX-like: you cannot evaluate/print an array inside a traced function, and Python side effects run at trace time.
- Documented magnitude: the MLX compilation docs benchmark their `gelu` example on an M1 Max at 15.5 ms uncompiled versus 3.1 ms compiled (≈5×), because the whole activation chain collapses to one kernel. That is a best-case elementwise example from Apple's own docs, not a whole-model figure.
- Scope limit, stated in secondary deep-dives and consistent with the docs: matmul and attention already ship as hand-tuned fused kernels; `mx.compile` mainly eats the "long tail" of small ops *between* them. CPU-side compilation helps less than GPU-side.

### 3.4 Streams and devices

- A **stream** is an ordered queue of work for one device. Every operation accepts a `stream=` argument (a stream, or a device meaning that device's default stream). `mx.new_stream(device)` creates additional streams; a `with mx.stream(...)` block sets the ambient stream; `mx.synchronize()` waits.
- Devices exposed to user code are `mx.cpu` and `mx.gpu`. The GPU device maps to Metal on Apple silicon and to CUDA on supported Linux — the *array* model survives the backend change, but the unified-memory guarantee does not: on a discrete NVIDIA card the CUDA backend is back in a two-pool world. [Our assessment: MLX's portability story is "same API, different physics," and code that assumes zero-copy will still run but stop being free.]
- Dependencies between streams are inferred from array dependencies; independent work on different streams can run concurrently. One subtle, research-grade caveat: the FusionML study (§2.3) reports that a CPU-stream op consuming a *not-yet-materialised* GPU result inside one evaluation graph serialises the graph — cross-stream concurrency was observed only when the CPU op's inputs were already materialised, which the author worked around with an explicit eager boundary. We could not verify this against Apple's own docs; treat it as a reported scheduler behaviour to test, not a documented contract.
- MLX is **not thread-safe** at the `mx.eval` level — concurrent evaluations from multiple threads are a known source of Metal assertion failures, cited in a 2026 multi-agent KV paper referencing MLX GitHub issues. MLX-LM's server design (single generation stream / serialised scheduler thread) is shaped by this. Any runner borrowing MLX's design should borrow this constraint consciously.

### 3.5 Memory accounting — the four knobs (verified)

MLX exposes unusually honest memory introspection and four distinct limits. Conflating them is the most common source of "MLX used too much memory" confusion, so they are separated here. Names and defaults below are from the MLX 0.32.x documentation and API reference, cross-checked against two independent 2026 deep-dives pinned to 0.32.0–0.32.3.

**Introspection**

- `mx.get_active_memory()` — bytes in live arrays (excludes the reusable cache).
- `mx.get_cache_memory()` — bytes held in MLX's freed-buffer cache, kept for reuse.
- `mx.get_peak_memory()` / `mx.reset_peak_memory()` — high-water mark of active memory.
- `mx.device_info()` — reports, among other things, `max_recommended_working_set_size` (the system's wired working-set recommendation) and total memory size.

**Limits**

| Knob | Layer | Meaning | Default / behaviour |
|---|---|---|---|
| System wired limit (`iogpu.wired_limit_mb` sysctl) | macOS | OS-level cap on how much memory the GPU stack may wire (pin). Readable via `max_recommended_working_set_size`; commonly ≈75% of installed RAM, varying by machine | Set by macOS; raise with `sudo sysctl iogpu.wired_limit_mb=N` (MB, must stay below total RAM; lost on reboot unless persisted). MLX-LM's README documents this exact remedy for large models |
| `mx.set_wired_limit(n)` | MLX process | How much memory MLX asks to keep resident/wired for its allocations. Requires macOS 15+ to take effect | Default 0. Requesting more than the system limit is an error. Must not be changed while an `async_eval` may be in flight — MLX-LM's wired-limit context manager synchronises first |
| `mx.set_memory_limit(n)` | MLX process | Guideline budget for graph evaluation allocations | Secondary sources reading the 0.32.x docs/source give the default as the smaller of 1.5× the recommended working set and 95% of installed RAM; the docstring reportedly states only the 1.5× part. Exceeding it with no RAM left raises rather than paging gracefully |
| `mx.set_cache_limit(n)` + `mx.clear_cache()` | MLX process | Cap on (and manual emptying of) the pool of freed buffers MLX retains for reuse | Cache limit starts equal to the memory limit. This cache is why "active" and "resident" diverge: freed buffers stay resident until the cache is cleared or pressure forces release |

A Metal-specific environment variable, `MLX_METAL_RESIDENCY_REFRESH_INTERVAL_MS` (MLX 0.32.4 env-var docs), periodically re-requests residency for wired allocations to work around macOS dropping residency while the GPU idles — default off. Its existence is a tell: on this platform, *staying* resident is an active process, not a state.

### 3.6 Distributed (brief, because it matters for §7)

`mx.distributed` provides collective communication with multiple backends. The newest is **JACCL**, Apple's RDMA backend for Thunderbolt 5 on macOS 26.2+, alongside MPI and TCP/ring options. RDMA over Thunderbolt lets one Mac read another's memory with latency reported by MLX-adjacent sources as dropping from ~300 µs (TCP path) to under 50 µs (MLX PR figures) — exo, the cluster front-end built on MLX distributed, claims ~3 µs in its own materials; the discrepancy is unresolved in public sources and we report both rather than picking one. Four-machine full-mesh Thunderbolt clusters (six cables for four nodes, no switch exists) are the practical ceiling today. This is unified memory's logic extended across a cable: once copies are free inside a box, the next prize is making the *interconnect* feel like memory too.

---

## 4. MLX-LM as a runner

MLX-LM describes itself in one line — generating text and fine-tuning LLMs on Apple silicon with MLX — and stays close to that scope. It is a library plus command-line tools, not a daemon-first product like Ollama.

### 4.1 Model loading

- Models are identified by Hugging Face repo id or local path. `load()` returns `(model, tokenizer)`; weights are safetensors plus a `config.json` carrying architecture and, for quantized checkpoints, the quantization recipe (mode, bits, group size). There is no GGUF path in MLX-LM; GGUF models belong to the llama.cpp world and do not load here directly.
- The `mlx-community` Hugging Face organisation hosts the pre-converted catalogue — a secondary guide counted 5,828 models there on 2026-11-02; treat the exact count as a snapshot, the order of magnitude (several thousand, most pre-quantized at multiple bit widths) as the durable fact.
- Conversion is a first-class tool, not an afterthought: `mlx_lm.convert` pulls a Hugging Face checkpoint, optionally quantizes it (§4.4), writes a local MLX checkpoint, and can upload it back to the Hub in one command. This convert-and-redistribute loop is how the catalogue above came to exist.
- Loading exploits laziness (§2.4): weights can be loaded/replaced before anything is evaluated, so dtype/quantization swaps do not double peak memory.
- Fine-tuning (LoRA and full, including on quantized bases) ships in the same package. For a runner dossier the relevant point is architectural: training and inference share the array framework, the cache code, and the memory model — there is no separate inference-only fork to drift.

### 4.2 KV cache design

This is the heart of MLX-LM as a runner. Per layer, per sequence, the cache is an object; a full prompt cache is a list of per-layer caches built by a `make_prompt_cache(model, ...)` helper that respects model-specific cache needs. Verified cache families in upstream MLX-LM (from the README, the generation/cache code as summarised by DeepWiki's source-indexed docs, and the server/generate flags):

| Cache type | What it is | When it is used |
|---|---|---|
| Standard growing KV cache | Appends new K/V each step; allocation grows with sequence length rather than being pre-reserved for the full context window | Default for ordinary attention layers |
| Rotating KV cache | Fixed-size ring; oldest positions are overwritten once full | `--max-kv-size n` on generate/chat/server. Bounds RAM at a direct quality cost — the README's own framing is "512 uses very little RAM but worse quality; 4096+ uses more, better quality." This is a sliding-window *retention* policy, not attention masking |
| Quantized KV cache | K/V stored quantized (see `--kv-bits` below), dequantized on use in attention | Long contexts where cache bytes, not weight bytes, dominate. In the server, enabling KV quantization currently disables batched serving (requests run one at a time) and attention over it is not the fused path — a real, documented trade, not a free win |
| Batched KV cache | Stacks/merges per-sequence caches along a batch axis, with left-padding and extract/merge operations | Used by the batch generator (§4.5) so several sequences share one forward pass |
| State / arrays cache | Non-KV recurrent state for hybrid and linear-attention / state-space layers (e.g. the gated-delta layers in Qwen3.5-family hybrids) | Models whose layers do not all have KV semantics. Important consequence: such caches are not always *trimmable* or prefix-rollback-able, which has bitten speculative decoding (§4.5) and exact-prefix reuse (§4.3) in practice |
| Cache list / composite | A per-layer heterogeneous container mixing the above | Hybrid architectures generally |

Design observations that matter for us:

- **Grow-on-demand, not pre-allocation.** Independent comparisons note MLX-LM does *not* reserve the full context window's cache up front (llama.cpp historically does for its `n_ctx`). Friendlier on a shared workstation, harder to reason about as a hard guarantee: the bill arrives token by token, and arrives as system memory pressure (§5) rather than a clean allocation failure.
- **Chunked prefill is a separate knob from the cache.** `--prefill-step-size` (default 2048 tokens) controls how many prompt tokens are processed per evaluation step. Smaller steps lower peak memory (notably the attention score matrix, which scales with step × context, especially over a quantized cache) at some prompt-processing speed cost. This is the main lever for fitting long prompts into a tight unified budget without shrinking the cache itself.
- **Quantized-KV start point.** The generation code supports converting a cache to its quantized form only after a configurable number of initial tokens (`quantized_kv_start` in the API summaries), keeping the earliest context — which includes the attention-sink region — at full precision. [Design-level reading of API summaries; exact default not verified from primary docs.]
- **Trimmability is a first-class property.** Speculative decoding needs to *rewind* a cache by a few tokens when draft tokens are rejected; prompt reuse needs to roll back to a prefix. Caches expose whether/how they can be trimmed, and features compose only when the cache supports it. This is a small API decision with large downstream consequences — see Idea S-6 in §9.
- **No PagedAttention equivalent found.** We searched specifically for a paged/block-table KV cache in upstream MLX-LM and found none: allocation is per-sequence and contiguous-ish (growing/rotating), sharing happens at whole-prefix granularity (§4.3), not at fixed-size block granularity as in vLLM. Third-party projects add exotic caches on top (40+ compression/eviction schemes in one PyPI library alone), which confirms the cache is *pluggable*, but paging itself is not an upstream MLX-LM feature as of 2026-11-15. Absence claims are fragile; this one is stated as "not found in the sources read," not "proven not to exist."

### 4.3 Prompt cache / prefix reuse

MLX-LM has *three* distinct prefix-reuse mechanisms, often conflated:

1. **File-based prompt cache.** `mlx_lm.cache_prompt` runs a prompt through the model once and saves the resulting KV state to a `.safetensors` file. `mlx_lm.generate --prompt-cache-file ...` then treats that file's contents as a prefix: the supplied prompt continues from it, and even the model identity is read from the cache file. This is a deliberate, user-managed artifact — closer to a compiled artifact than to transparent caching.
2. **In-process persistent cache.** The chat REPL keeps one prompt cache alive across turns, appending incrementally (resettable by the user). Multi-turn dialogue therefore re-prefills only the new suffix.
3. **Server LRU prompt cache with a prefix trie.** `mlx_lm.server` keeps an in-memory cache (implementation summarised from source as an LRU fronting a token-prefix trie) that finds the longest cached token prefix for a new request and reuses it. Controls: `--prompt-cache-size` (default **10** distinct caches) and `--prompt-cache-bytes` (byte budget). Responses report reuse (`cached_tokens` in usage details), so the hit is observable rather than rumoured.

Measured magnitude, with context: one user's 32 GB Mac running MLX-LM 0.32.2 (blog, 2026-11-08, self-described small-sample numbers) saw a ~3,100-token conversation take 29.5 s cold and 1.4 s on the next turn with 3,121 cached tokens reported. The same source is equally valuable for the failure mode (§5.2) and for a sharp edge: re-sending an *identical, restarted* prompt did **not** hit (0 cached tokens) on a hybrid model whose recurrent layers could not roll back to a shorter prefix — prefix reuse matched *continuations*, not restarts, in that configuration. Prefix caching on hybrid architectures is not the same problem as on pure-attention models, and any design we borrow must say which one it solves.

### 4.4 Quantization (design level)

**Storage modes** (MLX core `mx.quantize`, 0.32.4 docs — the table is factual labels, restated):

| Mode | Group size | Bits | Scale | Bias/zero-point |
|---|---|---|---|---|
| `affine` (default) | 32 / 64 (default) / 128 | 1, 2, 3, 4 (default), 5, 6, 8 | Same dtype as input, per group | Yes |
| `mxfp4` | 32 (fixed) | 4 | 8-bit power-of-two (E8M0), per group | No |
| `mxfp8` | 32 (fixed) | 8 | E8M0, per group | No |
| `nvfp4` | 16 (fixed) | 4 | FP8 (E4M3), per group (plus the format's per-tensor scale in practice) | No |

Arithmetic worth internalising: default affine 4-bit with group 64 stores a 16-bit scale *and* a 16-bit bias per 64 weights, i.e. 4 + 32/64 = **≈4.5 bits per weight** — the same effective weight as llama.cpp's Q4_K_M class, despite the different layout. MXFP4's single 8-bit scale per 32 gives ≈4.25 bpw. "4-bit" is a family, not a number.

**Methods that choose the rounding** (`mlx_lm.convert` and sibling tools):

- **Round-to-nearest (data-free).** `mlx_lm.convert -q` with no dataset. Fast, deterministic, runs on the machine that will serve the model. The bulk of the `mlx-community` catalogue (names ending `-4bit`, `-8bit`, etc.) is this.
- **AWQ** — activation-aware: scale/clip weights before rounding, protecting channels that activations make salient. Ships as its own tool in the package; secondary summaries of its docs give 32 calibration samples as the default.
- **GPTQ** — layer-wise error-compensating rounding: quantize progressively, adjusting not-yet-quantized weights to minimise the layer's output error on calibration inputs.
- **DWQ (Distilled Weight Quantization)** — the most MLX-native idea of the set: keep the *original* model as a teacher and fine-tune only the non-quantized parameters (scales, biases, and other unquantized weights) so the quantized student's outputs match. Secondary summaries give 1,024 calibration samples as its default and note it needs both models resident — on a unified machine that is a capacity question, not a copy question.
- **Dynamic / mixed precision** — estimate per-layer sensitivity and assign more bits to sensitive layers. The community ecosystem extends this into named mixed recipes (e.g. giving the first/last layer bands, selected projections, and the LM head more bits — a scheme one upstream issue describes as mirroring the intent of Q4_K_M). An upstream MLX-LM issue (July 2026, closed as completed August 2026) proposed exactly such pre-tuned per-layer recipes plus an FP8 KV cache option, reporting its decode measurements on an M2 Ultra (see §6) — we cite it as a proposal-with-measurements, not as settled upstream behaviour for every model.

**KV quantization** is a separate axis from weight quantization: `--kv-bits` (2/4/8 in the guides; 8 with group size 64 described as near-lossless in community testing) with `--kv-group-size`. Weight bits decide whether the model *fits and how fast decode reads*; KV bits decide how *long* a context fits beside it. On a unified machine both draw on the same pool, so the two knobs are really one budget split two ways (§5, §9).

### 4.5 Generation, batching, speculative decoding

- Entry points: `generate` (one-shot), `stream_generate` (token-by-token responses with prompt/generation token counts and peak-memory reporting), and a lower-level `generate_step` generator that the rest is built on.
- **Batching.** A `BatchGenerator` separates prompt-processing batches from generation batches and steps them together — in serving terms, continuous/in-flight batching rather than static batching: finished sequences leave and waiting ones join. Server defaults reported consistently across 2026 sources: `--decode-concurrency 32`, `--prompt-concurrency 8`. Batching and KV quantization currently exclude each other in the server (quantized-KV requests are served one at a time).
- **Speculative decoding.** A smaller draft model proposes several tokens; the target verifies them in one forward pass; rejected suffixes are rewound via cache trimming. Requires a trimmable cache (see §4.2) and, in upstream, a same-tokenizer draft/target pair. Independent work in 2026 both extends this (cross-tokenizer "universal assisted generation") and exposes its edges: one careful benchmark on an M-series Mac found a 0.8B draft more than doubling a 27B target's decode (17.9 → 39.2 tok/s, code prompts, 4 draft tokens) *only after patching* MLX-LM to handle a hybrid model's non-trimmable state cache, with peak memory rising from ~16 GB to ~22–24 GB for the privilege. Speculation on unified memory is never free: the draft model's weights are resident in the same pool.
- **Sampling/processors** are ordinary callables (sampler + ordered logits processors), and tool calling in the server is handled by per-model-family parsers for the OpenAI `tools` shape.

### 4.6 Server surface

`mlx_lm.server`:

- OpenAI-style HTTP API on `127.0.0.1:8080` by default: `/v1/chat/completions`, `/v1/completions`, `/v1/models`, plus `/health` in recent versions.
- Defaults that bite: `max_tokens` **512** and temperature 0.0 unless overridden per-request or at launch. More agent sessions have been "mysteriously truncated" by the 512 default than by any model failure, per the server guides.
- No imposed context truncation of its own: the model's context and your RAM are the limits, with prefill chunking (§4.2) keeping ingestion peaks down.
- Security posture, in the project's own judgement as paraphrased by every guide that quotes its server doc: basic checks only, **not recommended for production**, no API-key authentication. Keep it on loopback. This honesty is itself a design datum: MLX-LM is a research/local runner whose server is a convenience, and downstream products (LM Studio, Ollama, and various third-party MLX servers) exist precisely to harden this layer.
- Adapters (LoRA) and a draft model can be selected per server/per request, which makes one resident base model serve several personalities — cheap on unified memory because the base weights exist exactly once.

---

## 5. Memory management specifics

### 5.1 Budgeting a unified pool

A working MLX-LM budget on a Mac is, in order:

```
usable ≈ min(system wired recommendation, what you raise it to)
resident = weights (quantized size on disk ≈ in RAM)
         + KV cache (tokens × per-token KV bytes, at chosen kv-bits)
         + prompt-cache LRU (bounded by count AND bytes — if you set them)
         + activations / prefill chunk peak (prefill-step-size × context effects)
         + MLX buffer cache (freed-but-retained, up to cache limit)
         + everything else on the machine (OS, apps, display)
```

Two properties distinguish this from CUDA-style budgeting:

1. **The ceiling is soft until it is catastrophic.** CUDA allocation failure is a clean, early, attributable error at a known boundary (this process, this device, N bytes of VRAM). Unified overflow is mediated by the OS memory-pressure system: compression, then paging to SSD, then pressure-driven kills. You get gradual slowdown first and a dead process later, with the cause smeared across the whole machine.
2. **Retained caches are invisible unless you look.** MLX's buffer cache (§3.5) and MLX-LM's prompt-cache LRU both hold memory that is *logically free and physically resident*. `get_active_memory()` can look calm while the machine is under pressure from cache + cache. Any honest dashboard needs active, cache, peak, *and* prompt-cache bytes side by side.

### 5.2 Under pressure — what actually happens (evidence)

- **The prompt cache can eat the machine.** The 32 GB Mac field report (§4.3) records `mlx_lm.server` dying with a Metal "insufficient memory" command-buffer failure after its prompt cache grew to **7.4 GB on top of 16 GB of weights**. Fixes applied there: cap `--prompt-cache-bytes`/`--prompt-cache-size`, quantize KV (`--kv-bits 8`), and shrink `--prefill-step-size` to 512. The same report notes the byte cap was not strict in its logs (observed 3.2 GB and 4.95 GB against 2 GB and 4 GB limits) — budget prompt caches with headroom, not to the byte. [Single-user field report, MLX-LM 0.32.2; treat the overshoot as a warning to verify, not a measured defect rate.]
- **Large-model wiring is the intended escape hatch.** MLX-LM's README (macOS 15+) says large-relative-to-RAM models are slowed by paging and that MLX-LM will wire the model's and cache's memory to keep it resident; if you see its "model requires more than the wired limit" warning, raising the *system* wired limit (`iogpu.wired_limit_mb`, sized above the model but below total RAM) is the documented fix. Wiring trades the whole machine's flexibility for this process's determinism: wired memory cannot be reclaimed by macOS, and at least one independent long-context guide reports wiring buying no measurable speed while risking a hard hang on an already-full machine. Both can be true — wiring helps when paging was the problem and hurts when capacity was.
- **Pressure-aware shedding exists downstream.** A third-party MLX serving stack describes a two-level guard we consider the right shape (and cite as a pattern, not an upstream feature): at macOS *warning* pressure, return MLX's buffer cache and drop shallow prompt-cache snapshots (≈1.7 GB on its 27B example) while keeping conversations' prefixes; at *critical*, empty the prompt cache entirely. Shedding order — reusable buffers first, derived caches second, weights never — is the transferable idea.

### 5.3 Comparison vs CUDA-style explicit VRAM

| Dimension | CUDA / discrete VRAM (e.g. Ollama on NVIDIA) | MLX / unified pool |
|---|---|---|
| Capacity boundary | Fixed VRAM size; hard, known in advance | Total RAM minus OS reservation and wired policy; soft, machine-dependent |
| Failure mode | Allocation error, early and attributable | Compression → paging → pressure kill; late and diffuse |
| Residency | Weights copied in; one residency in VRAM (+ host copy transiently) | Single residency, addressable by CPU and GPU |
| KV cache home | VRAM, competing only with other GPU tenants | Same pool as weights, OS, and user apps |
| Multi-model | Swap = re-copy over PCIe | Swap = page/wire decisions; weights may already be resident |
| Tuning knobs | Context length, batch, offload fraction | Wired limit, memory limit, cache limit, prompt-cache bytes, prefill step, KV bits — more knobs, all interacting |
| Measurement | `nvidia-smi`-style per-device accounting | Must compose active + cache + peak + pressure state; no single number suffices |

[Speculation, marked as such:] the CUDA model's great virtue is *legibility* — a runner can promise "this fits" and be right. Unified runners cannot honestly make that promise without also budgeting the rest of the machine, which is why §9's admission-control ideas matter more on UMA than anywhere else.

---

## 6. Performance character

### 6.1 The physics first: bandwidth table (Apple-published figures, as compiled by multiple 2026 sources)

| Chip tier | M1 | M2 | M3 | M4 | M5 |
|---|---|---|---|---|---|
| Base | 68 GB/s | 100 | 100 | 120 | 153 |
| Pro | 200 | 200 | 150 | 273 | 307 |
| Max | 400 | 400 | 400 (300 on binned die) | 546 (410 binned) | 614 (460 binned) |
| Ultra | 800 | 800 | 819 | — (no M4 Ultra) | 1,228 |

Caveats that change buying/benchmarking conclusions: tier beats generation (an M2 Max at 400 GB/s out-decodes a base M4 at 120 GB/s by a wide margin); binned Max dies carry a real ~25% bandwidth penalty hidden behind the same chip name; capacities run from 16 GB (base M1) to 512 GB (Ultra class). Strix Halo comparison point: ~256 GB/s theoretical (256-bit LPDDR5X-8000), ~215 GB/s measured under load per a 2026 setup guide — i.e. our Z13 sits between Apple Pro and Max tiers on bandwidth while offering Max/Ultra-class capacity. Decode expectations should be set accordingly.

### 6.2 Where MLX wins

- **Bandwidth-bound decode, when the comparison engine treats the GPU as discrete.** An independent M2 Ultra study (192 GB, 800 GB/s; work-in-progress preprint, March 2026) measured MLX token generation at ~85% of theoretical bandwidth utilisation and ~53% faster than llama.cpp on the same hardware. Community comparisons across M3/M4 machines commonly report MLX 30–50% ahead of llama.cpp Metal for equivalent dense models — directionally consistent, methodologically loose. The honest summary: MLX is usually the fastest *general* engine on Apple silicon for single-stream decode, by a margin that varies with model and quantization, and the margin comes from kernel quality (fused attention, tuned GEMM) plus zero-copy, not from zero-copy alone.
- **Prefill on newer silicon.** MLX can use the M5 family's GPU Neural Accelerators; Ollama's MLX announcement (§7.3) is built around prefill gains there.
- **Long-prompt reuse.** Where the workload is an agent loop re-sending a growing transcript, the prompt-cache machinery (§4.3) dominates raw kernel speed: reusing ~3,100 cached tokens turned a ~29.5 s turn into ~1.4 s in the field report cited above. No kernel optimisation competes with not doing the work.
- **Capacity-shaped wins.** Models in the 70B–200B+ class at 4-bit simply have no discrete-consumer-GPU comparison on a 128–512 GB Mac; "wins by being the only thing that runs" is a real category on UMA.

### 6.3 Where MLX loses

- **Kernel/ecosystem maturity vs CUDA.** Two decades of CUDA libraries, FlashAttention variants, and serving stacks (vLLM/SGLang-class batching, paging, multi-GPU) have no full MLX equivalent. MLX-LM's batching is respectable for local serving; it is not a datacentre throughput engine, and its server says so itself.
- **Prefill is GEMM-bound, and GEMM is where maturity shows.** The M2 Ultra study found prefill time dominated by quantized GEMM in the linear projections (~57.6% of time) rather than attention (~6.7%) — optimisation effort aimed at attention alone misses the bottleneck on this platform.
- **Speculative decoding is not a generic win here.** The same study found prompt-lookup speculation at 0.85–1.00× on its models because a batched verification pass on a bandwidth-bound machine yields far less than its theoretical multiplier (measured 1.79–2.57× batch efficiency vs ~5× assumed). Speculation pays when drafts are cheap *and* verification is compute-rich; UMA decode is neither by default. (Contrast §4.5's patched 2.2× result — model, prompt type, and draft fit decide, which is precisely the point.)
- **Small machines and small models.** On a 24 GB M4 mini (ComputingForGeeks, November 2026, three-run medians, same Qwen3.5-9B class model), Ollama's default tag generated 27.3 tok/s, raw MLX-LM 21.3, LM Studio's MLX engine 20.1 — and Ollama's separate `-mlx` tag only 16.1. The winner's edge was attributed to its built-in multi-token-prediction drafting, not to "MLX vs not." Lesson: at this scale, *features* (drafting heads, cache policy, defaults) beat *engine labels*, and any benchmark without the exact tag/quant/draft configuration is noise.
- **Portability.** MLX-format checkpoints run in the MLX ecosystem (MLX-LM, LM Studio's MLX engine, Ollama's MLX runner, third-party servers). They do not run in llama.cpp, and GGUF does not run in MLX-LM. The CUDA backend widens where MLX *code* runs; it does not make the checkpoint ecosystem cross-vendor.

### 6.4 Reported numbers, with hardware context (no number without its machine)

| Claim | Hardware / config | Source type |
|---|---|---|
| Prefill 1,154 → 1,810 tok/s; decode 58 → 112 tok/s; up to 1,851 / 134 with int4 | Ollama 0.18 (Q4_K_M) → 0.19 MLX (NVFP4), Qwen3.5-35B-A3B, M5-family, tested 2026-03-29. **Quantization differs between the two arms** — read as "new stack + new format" gain, not pure engine gain | Ollama's own MLX announcement |
| Decode 57.8 → 111.4 tok/s | M4 Max 64 GB, Qwen3.5, Ollama pre/post MLX preview | Independent test as summarised by a 2026 review site; primary post not re-read for this dossier |
| ~230 tok/s on an "optimized 7B" | High-end M-series, 4-bit, warm prompt cache, batch 1 — exact chip not pinned in the citing source | arXiv-cited figure via a comparison blog; weakest sourcing in this table, included only to flag its circulation |
| GELU chain 15.5 ms → 3.1 ms with `mx.compile` | M1 Max | Apple MLX docs (best-case fusion example) |
| CPU/GPU split toy 2.8 ms → 1.4 ms | M1 Max | Apple MLX docs (illustrative, contrived by their own admission) |
| Prompt-cache turn 29.5 s → 1.4 s | 32 GB Mac, MLX-LM 0.32.2, ~3.1k-token conversation | Single-user field report |
| Speculative decode 17.9 → 39.2 tok/s, peak RAM 16 → 22–24 GB | M-series Mac (27B 4-bit target + 0.8B draft, patched MLX-LM) | Independent benchmark blog, Aug 2026 |

---

## 7. The transfer lesson — unified memory on non-Apple hardware

MLX's value to us is not "run this on the Z13" (we cannot — there is no ROCm/HIP MLX backend, and the CUDA backend does not change that). Its value is as a *worked example* of every decision a UMA runner must make, made by a team that only had to solve the UMA case. Below: the two other living UMA cases, then the lessons.

### 7.1 AMD Strix Halo — our Z13 (purpleraider)

**The hardware.** Ryzen AI Max+ 395: 16 Zen 5 CPU cores, Radeon 8060S iGPU (40 CUs, gfx1151), XDNA NPU, and up to 128 GB of LPDDR5X on a 256-bit bus (~256 GB/s theoretical). Architecturally this is Apple-silicon-shaped: one pool, several processors, bandwidth modest relative to capacity.

**How the pool is actually divided on Linux** (from 2026 community setup guides and the Framework/Strix Halo wiki ecosystem, cross-checked):

- Keep the BIOS UMA framebuffer *small* (512 MB is the common recommendation — it is only the display reservation).
- The iGPU's compute reach is governed by **GTT** (Graphics Translation Table) — kernel-managed, on-demand mappings of system memory for the GPU — sized via `amdgpu.gttsize` (MB) and/or the TTM page limits (`ttm.pages_limit`, `amdttm` on some kernels; naming has shifted across kernel versions, which itself is an operational hazard).
- Typical community targets on 128 GB machines: ~96 GB via Windows' Variable Graphics Memory, ~105–115 GiB of GTT on Linux, leaving the rest for the OS. Guides warn of instability pushing GTT much past ~108 GB in some configurations.
- Backend note: on this iGPU, Vulkan (RADV) is the low-friction default for llama.cpp-class engines and matches or beats ROCm at ordinary contexts in community testing; tuned ROCm builds pull ahead on long-context prompt processing (one guide claims ~3×). [Community consensus as reported, not our measurement.]

**Our own facts — labelled as ours.** From our campaign records (memory log, 2026-11-14): on purpleraider, at Volmarr's order, the unified-memory graphics pool cap was set to **100 GiB** in the boot configuration — deliberately *down* from the earlier tuning's ~124 GiB sprawl — and verified live after Volmarr's own clean restart, with the boot line carrying `amdgpu.gttsize=102400` and `ttm.pages_limit=26214400`, and ~124 GB MemAvailable reported post-boot. The reason for capping *below* the maximum is the MLX lesson in §5 applied in reverse: an uncapped graphics pool had let pinned model/graphics memory flood the machine in the 2026-11-14 desktop OOM events (our records note swap sat at zero because pinned graphics memory does not drain to swap). 100 GiB is an admission-control decision, not a hardware limit.

**The parallel, stated plainly:**

| Apple / MLX | Strix Halo / Linux |
|---|---|
| System wired limit (`iogpu.wired_limit_mb`, ≈75% default) | GTT size + TTM page limits (no sane default for LLM work; hand-set) |
| `mx.set_wired_limit` (process asks to stay resident) | ROCm/Vulkan allocations resident in GTT; pinned memory invisible to swap |
| macOS memory pressure (compress → page → kill) | Linux OOM / memcg kills; KDE "memory shortage" alerts that, in our own 2026-11-12 incident, fired for caged test processes while the machine had 111 GiB available — pressure signalling is as misleading here as there |
| MLX buffer cache + prompt-cache LRU as hidden residents | Page cache + retained KV + multiple runners' pools as hidden residents |

### 7.2 Intel UMA

Intel is two different stories wearing one label:

- **Classic iGPU UMA (most Core / Core Ultra systems):** CPU and iGPU share system DDR/LPDDR, with the graphics driver historically able to claim up to a large fraction (often ~50%+) of RAM on demand. The physics is UMA; the *software contract* is not — there is no Intel equivalent of MLX's unified array model with first-class wired/memory/cache limits exposed to a runner, and LLM stacks reach the iGPU through Vulkan/SYCL/oneAPI paths of varying maturity. Capacity is whatever the laptop shipped (commonly 16–32 GB), which caps ambition before bandwidth does.
- **Lunar Lake (Core Ultra 200V, 2024):** the true Apple-shaped experiment — LPDDR5X-8533 *on-package*, 16 or 32 GB only, ~120–136 GB/s class bandwidth, Xe2 iGPU + 48-TOPS-class NPU on one SoC. Intel publicly treated on-package memory as a one-off and returned to off-package memory for successors on margin grounds (reported from Intel's own earnings-call remarks). Transfer lesson: UMA's benefits are real and *still* lose to bill-of-materials economics when memory cannot be tiered/upgraded — a constraint Apple absorbs because it sells the whole machine. [Bandwidth figure is the commonly reported class figure; we did not verify it against an Intel datasheet for this dossier.]

[Speculation:] the industry pattern is that UMA wins where one vendor owns the whole stack (Apple; AMD APUs in fixed appliances/consoles) and stalls where memory is a separately priced commodity (mainstream Intel laptops). Runner design should therefore treat UMA as a *deployment target class*, not as the universal future.

### 7.3 Ollama's own MLX move — the validation event

Timeline, from Ollama's announcement and release reporting:

- **v0.19, 30–31 March 2026 (preview):** Ollama on Apple silicon gains an MLX-based runner. Launch scope was narrow — one accelerated family (Qwen3.5-35B-A3B, in an NVFP4 coding variant), a stated requirement of **more than 32 GB of unified memory**, and headline numbers in §6.4. The announcement also introduced three cache behaviours that are *Ollama's own*, layered on MLX: cache reuse across conversations (shared system prompts/tool schemas hit instead of recomputing), "intelligent checkpoints" (snapshots at chosen prompt positions so branching agent conversations re-prefill less), and eviction that protects shared prefixes while dropping older branches. Those three are, in effect, §4.3's trie/LRU idea productised for agent loops.
- **v0.30, May 2026 (reported as the stable line):** MLX engine stabilised and broadened to more models/hardware, per secondary release coverage.
- **v0.40.0, 25 September 2026 (default):** on Apple silicon, any architecture Ollama's MLX runtime supports runs on MLX *automatically*; the rest fall back to the llama.cpp path transparently. Models can carry both MLX (safetensors) and GGUF variants under one name; runner preference on macOS/arm64 is MLX → llama.cpp → ggml (reversed elsewhere), `ollama ps` gains a RUNNER column, and `--runner` can force a choice. Later 0.40.x patches broadened the MLX-supported list further. A reported side effect of the transition: background conversion of older GGUF downloads, keeping the original as backup — disk usage roughly doubling for migrated models until cleaned. [The v0.40 details come from multiple secondary reports reading the same release notes; we did not re-read the full GitHub release text for this dossier, and the "disk doubling" framing is one report's headline — the underlying keep-the-original behaviour is corroborated by the v0.40.2 notes as quoted.]

Why this matters beyond Apple: Ollama — the most conservative, compatibility-first local runner — concluded that on UMA hardware the winning move was not to optimise its discrete-shaped engine harder, but to *adopt the UMA-native engine* and demote the old one to fallback. That is the strongest available market evidence for §9's direction.

### 7.4 What MLX's design teaches any runner on UMA machines

1. **Name the pool, budget the pool.** One number ("VRAM") is replaced by an explicit, multi-part budget (weights / KV / prefix cache / transient / OS headroom) with a knob per part. MLX's four limits (§3.5) are the template.
2. **Residency is a request, renewed, not a state.** Wired limits, residency refresh, and pressure-triggered shedding all treat "staying in fast memory" as continuous work.
3. **Grow lazily, chunk the peaks.** Lazy evaluation, grow-on-demand KV, and chunked prefill all push in one direction: never allocate or compute the worst case before you must.
4. **Cache policy *is* memory policy.** On UMA, a prompt cache is not a performance garnish; it is a resident tenant competing with weights. It needs byte budgets, eviction that understands sharing, and pressure-triggered shedding — in that order.
5. **Placement ≠ movement.** Once copies are free, CPU/GPU work-splitting becomes a scheduling experiment you can actually afford to run — with the honest caveat (§2.3) that bandwidth-bound decode will not reward it.

---

## 8. Strengths / weaknesses

### Strengths

- **Conceptual cleanliness.** One memory model, one array abstraction, no device-transfer API surface. Model code reads like NumPy; runner code reasons about one pool.
- **Lazy graph + compile is the right substrate for UMA.** Fusion directly saves the scarcest resource (bandwidth); elision directly saves the second scarcest (resident bytes).
- **Memory introspection is first-class.** Active/cache/peak counters and named limits make UMA's softness *measurable*, which is most of the way to making it manageable.
- **KV/prompt-cache design is pragmatic and layered.** Growing, rotating, quantized, and batched caches; file-based, session, and server-LRU prefix reuse — each layer is simple, and the composition covers most local workloads.
- **Quantization breadth in one toolchain.** Data-free conversion for the many, calibrated methods (AWQ/GPTQ/DWQ/dynamic) for the careful, microscaling formats (MXFP4/MXFP8/NVFP4) for the new models — all emitting the same checkpoint shape.
- **Ecosystem gravity.** Several thousand pre-converted community models, adoption by LM Studio and Ollama, Swift bindings for native apps, and a distributed/RDMA path that no other local stack matches on this hardware.
- **Honest scoping.** The server's "not for production" stance and the docs' warnings (graph growth, wired-limit hazards) make the sharp edges findable before they cut.

### Weaknesses

- **Apple-first, Apple-most.** The design centre is one vendor's SoC line. The CUDA backend exists, but the unified guarantees, the tuned kernels, and the community catalogue do not travel with it. There is no AMD/ROCm path at all.
- **Serving maturity.** No paged KV allocation found upstream; batching excludes quantized KV; the bundled server lacks authentication and production hardening; thread-safety constraints force serialised scheduling. Datacentre-style multi-tenant serving is out of scope and it shows.
- **Soft failure modes.** UMA pressure failure is gradual, system-wide, and hard to attribute (§5). MLX gives you the counters, but the *policy* (admission, shedding, per-tenant budgets) is left to whoever builds on it — most don't, and then a prompt cache eats a 32 GB machine.
- **Hybrid-model friction is live.** Recurrent/state layers break assumptions (trimmability, prefix rollback, speculation) that pure-attention code makes silently. Several 2026 field reports and patches trace back to exactly this seam.
- **Defaults that surprise.** 512-token server cap; prompt-cache byte limits that are (per one field report) approximate; wired-limit advice that can hang a full machine if applied blindly. Each is documented *somewhere*; none is guarded at the point of use.
- **Benchmark folklore.** "MLX is X% faster" circulates with the hardware, quant, and draft configuration stripped off — §6.4's table is an attempt to reattach them, and several widely repeated figures could only be sourced second-hand.

---

## 9. Ideas to steal

Each idea states the mechanism, the expected gain, and the cost/risk. Gains are directional unless a measured figure is cited above. Audience tags: **[UMA]** Ollama-on-UMA generally · **[Z13]** our Strix Halo campaign · **[KV]** KV residency in a shared pool.

### For Ollama-on-UMA generally

**S-1. Adopt MLX's four-limit vocabulary as the runner's own budget model. [UMA]**
Mechanism: expose and log four separate numbers — system graphics-pool cap, process residency request, evaluation/allocation budget, reusable-buffer cache cap — instead of one "memory used" figure. On Apple that maps to §3.5 directly; on Linux/AMD it maps to GTT cap, pinned allocation, allocator budget, and page/buffer cache.
Expected gain: diagnosability. Most UMA "OOMs" become "this specific budget, this specific tenant" events, which are fixable by policy instead of by reboot.
Cost/risk: low engineering cost; real risk is cosmetic — exposing knobs users can mis-set (see S-3's guardrail).

**S-2. Byte-budgeted, sharing-aware prefix cache as a first-class tenant. [UMA][KV]**
Mechanism: Ollama's 0.40 direction (cross-conversation reuse, intelligent checkpoints, shared-prefix-protecting eviction) generalised: an LRU-over-prefix-trie with *both* a count cap and a byte cap, checkpoint snapshots at branch points (end of system prompt, end of tool schema, turn boundaries), and per-response `cached_tokens` reporting.
Expected gain: the largest single win available for agent workloads — order-of-magnitude turn latency cuts on long transcripts (§4.3: ~29.5 s → ~1.4 s in the cited field case).
Cost/risk: the cache is a resident tenant that *will* eat the machine if the byte cap is soft (§5.2). Requires strict accounting and pressure shedding (S-4) to be safe. Hybrid models need a defined fallback when prefixes cannot roll back.

**S-3. Wired/residency requests with a seatbelt. [UMA][Z13]**
Mechanism: when a model is large relative to the pool, the runner requests residency for weights + active KV (MLX-LM's wiring behaviour), sized from the *measured* model, capped at a conservative fraction of the pool, and released on unload. Refuse, loudly, to wire above the system recommendation without an explicit user override.
Expected gain: eliminates paging collapse for big-model serving; turns "slow for unknown reasons" into deterministic performance.
Cost/risk: wired memory is unreclaimable and can hang a loaded machine (reported independently). The seatbelt *is* the feature; an unguarded version of this idea is a liability.

**S-4. Two-level pressure shedding, in a fixed order. [UMA][KV]**
Mechanism: subscribe to OS memory-pressure signals; at *warning*, drop reusable buffer caches and shallow prefix snapshots; at *critical*, empty the prefix cache; never shed weights or active generations. (Shape borrowed from a third-party MLX server's guard, §5.2.)
Expected gain: converts hard kills into graceful slowdowns; buys back gigabytes (its reference case: ~1.7 GB at warning level on a 27B) exactly when they matter.
Cost/risk: needs platform pressure APIs on each OS (macOS pressure notifications; Linux PSI/memcg on the Z13) — real per-platform work, and shedding races with in-flight evaluation must be serialised (MLX's own wired-limit rule — synchronise before changing limits — applies here too).

**S-5. Chunked prefill as an admission knob, auto-sized to headroom. [UMA]**
Mechanism: `--prefill-step-size` generalised: choose the prefill chunk from *current* free pool (smaller when tight), rather than a fixed 2048. Especially important over a quantized KV cache, where the attention score matrix (step × context) can exceed the memory the quantization saved.
Expected gain: long prompts fit in tight budgets without user tuning; peak memory becomes a controlled variable instead of an emergent one.
Cost/risk: smaller chunks cost prompt-processing speed; an auto-sizer needs honest peak accounting (S-1) or it will guess wrong confidently.

### For our Z13 unified-memory campaign

**S-6. Treat the 100 GiB cap as policy v1, and instrument it like MLX would. [Z13]**
Mechanism: keep our verified 100 GiB GTT cap (`amdgpu.gttsize=102400` / `ttm.pages_limit=26214400`, ours, 2026-11-14) as an explicit *admission budget*, and log its four analogues per run: GTT cap, pinned/resident bytes, allocator high-water, and reusable cache (page cache + retained KV). Our 2026-11-12 false-alarm incident (memcg-caged probes triggering desktop "low memory" alerts with 111 GiB free) shows our pressure *signals* need the same disaggregation MLX gives its counters.
Expected gain: the next memory incident gets a named tenant and a number, not a photograph of a KDE dialog.
Cost/risk: mostly bookkeeping; risk is spending campaign time on telemetry instead of throughput. Keep it to counters that already exist (`mem_info_gtt_*`, PSI, per-process RSS) before building anything.

**S-7. Make trimmability and rollback explicit properties of every cache we design. [Z13][KV]**
Mechanism: MLX-LM's seam (§4.2) as a rule for Aesir/Ollama work on the Z13: any KV/state cache declares `trimmable`, `prefix-rollback-able`, and `quantizable-after-N` up front; speculative decoding, prefix reuse, and branching are enabled per-model only when the declaration supports them — instead of failing at runtime (as upstream speculation did on hybrid caches) or silently missing (as prefix reuse did on a hybrid model).
Expected gain: an entire class of hybrid-architecture (Qwen3.5-class) runtime failures becomes a load-time capability matrix.
Cost/risk: requires honesty from model definitions; a wrong declaration is worse than none, so declarations need a conformance test per architecture.

**S-8. Prefill/decode asymmetry in scheduling experiments. [Z13]**
Mechanism: when trialling CPU+iGPU work-splitting on Strix Halo (Zen 5 cores + 8060S sharing one bus — the direct analogue of MLX's CPU/GPU streams), aim the split at *prefill* and keep decode GPU-only, per the FusionML boundary (§2.3) and the GEMM-dominance finding (§6.3). Measure bandwidth utilisation first; if decode is already near the bus ceiling (~215 GB/s measured class figure for this platform), no split can help it.
Expected gain: avoids burning campaign slices re-discovering a bandwidth wall; focuses split experiments where a 1.15–1.38×-class prefill gain is physically plausible.
Cost/risk: the cited boundary is one unreviewed study on Apple silicon; treat as a prior, verify on gfx1151 before generalising. [Speculation until measured on our hardware.]

### For KV residency when the pool is shared

**S-9. Reprice KV residency: on UMA, keeping a cache is cheaper than recomputing it — until pressure says otherwise. [KV]**
Mechanism: in a discrete runner, resident KV is priced against scarce VRAM, so eviction is aggressive. In a unified pool with zero copy cost, a dormant conversation's KV costs only its bytes — no transfer to "bring it back," because it never left. Policy consequence: default to *retaining* more prefixes for longer (bounded by S-2's byte budget and S-4's shedding), and make disk persistence (MLX-LM's safetensors prompt-cache files) the *second* tier, not the first — the reverse of VRAM-era instincts.
Expected gain: multi-turn and multi-branch agent workloads keep their warm state without PCIe-style reload penalties; the economics favour breadth of retention.
Cost/risk: retained KV is retained *bandwidth-irrelevant but capacity-real* memory; on a 32 GB machine the §5.2 incident is the counter-example. Retention breadth must scale with pool size, not be a constant.

**S-10. Quantize the cache late, and the sink never. [KV]**
Mechanism: adopt the `quantized_kv_start` pattern: early tokens (system prompt, attention-sink region) stay full-precision; the cache converts to quantized form (8-bit first; 4-bit with eyes open) only past a token threshold, with group size as a recorded part of the cache's identity. Pair with S-5 so the prefill peak does not eat the saving.
Expected gain: most of the capacity benefit of KV quantization (2–4×) with the quality-sensitive head of the context protected; long contexts fit beside weights that already fill most of the pool.
Cost/risk: in current MLX-LM serving, quantized KV disables batching and loses the fused attention path — a throughput tax that may exceed the capacity gain for multi-user serving. Steal the *policy*, verify the kernel cost on our stack before adopting the mechanism wholesale.

**S-11. One pool, one arbiter: a single residency arbiter for weights, KV, and prefix cache. [KV][UMA][Z13]**
Mechanism: instead of weights, per-request KV, and the prefix cache each allocating independently against a soft ceiling (the structure that produced §5.2's 7.4 GB surprise), route all three through one arbiter that knows the pool budget (S-1), applies admission (a new request may shrink the prefix cache, never the reverse by accident), and owns shedding order (S-4).
Expected gain: the failure mode changes from "machine died under combined load" to "request queued / prefix evicted," which is the difference between a local tool and a reliable one.
Cost/risk: this is the largest engineering item on this list — a real allocator/policy layer, with deadlock and fairness questions MLX-LM itself has not had to answer at multi-tenant scale. [Speculation:] it is also, in our judgement, the single highest-leverage piece of original work an "improved Ollama for UMA" could do, precisely because neither MLX-LM nor Ollama's current design fully attempts it.

---

## 10. Sources (all accessed 2026-11-15)

**Primary — Apple / MLX project**

1. MLX GitHub repository (`ml-explore/mlx`) — README (features, unified memory model, authorship), repository metadata (MIT, created 2023-11-28). https://github.com/ml-explore/mlx
2. MLX-LM GitHub repository (`ml-explore/mlx-lm`) — README (loading, conversion, rotating KV cache, prompt caching, prefill step size, large-model wiring and `iogpu.wired_limit_mb` guidance), repository metadata (MIT, created 2025-03-11). https://github.com/ml-explore/mlx-lm
3. MLX documentation, v0.32.4 — landing page; *Unified Memory*; *Lazy Evaluation*; *Compilation* (incl. M1 Max GELU figures); *Memory Management* API index; *Environment Variables* (residency refresh). https://ml-explore.github.io/mlx/
4. MLX documentation — `mlx.core.quantize` API page (modes table: affine / mxfp4 / mxfp8 / nvfp4, group sizes, bits). Via search-indexed docs page, 0.32.4.

**Primary — Ollama**

5. Ollama blog, "Ollama is now powered by MLX on Apple Silicon in preview" (v0.19; tested 2026-03-29; Qwen3.5-35B-A3B NVFP4 vs Q4_K_M figures; >32 GB requirement; cache reuse / intelligent checkpoints / smarter eviction). https://ollama.com/blog/mlx

**Secondary — MLX / MLX-LM deep-dives and guides (used for knob defaults, server behaviour, cache internals; cross-checked where they overlap)**

6. LLM Deep Dive, "Lazy graphs, compile and streams in MLX" and "Serving from a Mac with mlx_lm.server" (pinned MLX 0.32.3 / MLX-LM 0.32.x; four memory limits; server concurrency and LRU details). llmdeepdive.com, updated Oct–Nov 2026.
7. DeepWiki source-indexed MLX-LM pages — Prompt Caching; Advanced Features; Batch Generation; Speculative Decoding (cache classes, `LRUPromptCache`/`PromptTrie`, `BatchKVCache`, trim semantics). deepwiki.com/ml-explore/mlx-lm, generated Sep 2026.
8. "MLX LM Guide: Run, Serve and Convert Models on a Mac" (MLX-LM 0.32.2, PyPI 2026-10-16; server defaults; prompt-cache controls; AWQ/GPTQ/DWQ tooling; mlx-community count 5,828 on 2026-11-02). refusalrate.com.
9. "MLX LM Server as a Local Backend…" (MLX-LM 0.31.3; 512-token default; production warning). aicoderscope.com, Sep 2026.
10. D-Central, "LLM Quantization Formats Compared" (MLX-LM learned-quantization summaries: AWQ/DWQ/GPTQ/dynamic, sample-count defaults as documented there). d-central.tech, 2026.
11. MLX-LM upstream issue #1450, "Decode performance optimizations for MLX-LM inference" (mixed-bit recipes, FP8 KV proposal, M2 Ultra 137 GB measurements; opened Jul 2026, closed Aug 2026). github.com/ml-explore/mlx-lm/issues/1450.

**Field reports and benchmarks**

12. Vorona, "Local LLMs on a 32 GB Mac: MLX, Qwen, and Making OpenCode Work With Them" (MLX-LM 0.32.2; prompt-cache 7.4 GB incident; 29.5 s → 1.4 s cached turn; hybrid prefix-miss observation). blog.vorona.me, 2026-11-08.
13. ComputingForGeeks, "Ollama vs LM Studio vs MLX on Mac: M4 24 GB Benchmark" (Qwen3.5-9B; Ollama 27.3 / MLX-LM 21.3 / LM Studio 20.1 tok/s; MTP drafting attribution). computingforgeeks.com, Nov 2026.
14. Karnam, "Speculative Decoding on Apple Silicon" (Qwen3.8-27B + 0.8B draft, 17.9 → 39.2 tok/s after patching hybrid-cache trimmability; peak 16 → 22–24 GB). adityakarnam.com, Aug 2026.
15. AtomGradient, "Demystifying LLM Inference Optimization on Apple Silicon" (M2 Ultra 192 GB; ~85% bandwidth utilisation; ~53% vs llama.cpp; prefill GEMM 57.6% vs attention 6.7%; speculation 0.85–1.00×). Work-in-progress preprint, Mar 2026.
16. Mohite, "FusionML: Prefill, Not Decode" (CPU+GPU co-execution boundaries; lazy-graph serialisation claim). arXiv:2607.22785, Jul 2026.
17. Bandwidth compilations: LLMCheck "Apple Silicon Memory Bandwidth & LLM Speed (M1–M5)" (Oct 2026, corrected table incl. no-M4-Ultra note); corroborated by CanItRun and RunLocalAI hardware tables. llmcheck.net.

**Ollama MLX timeline (secondary reporting of release notes)**

18. Typilot, "Ollama 0.40: MLX Now Default on Apple Silicon" (v0.40.0, 2026-09-25; v0.40.4 by 2026-10-12). typilot.com.
19. OllamaHerd, "MLX vs Ollama (2026)" (v0.19 Mar 2026 format-based routing; v0.40 default; RUNNER column; no `OLLAMA_MLX` env var). ollamaherd.com.
20. LLMCheck, "Ollama MLX on Mac (0.40+)" (runner preference order in v0.40.6 source as reported; M4 Max 19%/4% same-Mac test). llmcheck.net.
21. DevelopersDigest, "Ollama 0.40 on Mac: MLX by Default, Disk Space Doubled" (background conversion keeping originals, per v0.40.2 notes as quoted). developersdigest.tech, Oct 2026.
22. Gingter, "Ollama Goes MLX" (v0.19 preview analysis; ~1.6× prefill / ~2× decode framing). gingter.org, Apr 2026.

**Non-Apple UMA**

23. Codersera, "Run Local LLMs on AMD Strix Halo (Ryzen AI Max+ 395)" (128 GB LPDDR5X, ~256 GB/s theoretical / ~215 measured; Windows VGM 96 GB; Linux BIOS 512 MB + GTT sizing; Vulkan vs ROCm character). codersera.com, 2026.
24. Zyvop, "Running Llama.cpp on AMD Strix Halo" (gfx1151; ~115 GiB GTT-accessible in their setup; VRAM/GTT/TTM explainer). zyvop.com, 2026.
25. Framework Community thread on Strix Halo GTT commands under Fedora 43 (`amdgpu.gttsize`, `ttm.pages_limit` naming variance; ~105–108 GB working targets). community.frame.work, Nov 2025–2026.
26. Lunar Lake: Wikipedia architecture summary (on-package LPDDR5X-8533, 16/32 GB) and Tom's Hardware reporting of Intel's on-package-memory reversal (margin rationale, earnings-call remarks). Accessed via search results, 2026-11-15.
27. Mac clustering / RDMA: AlphaSignal and MLX.app cluster explainers (macOS 26.2 RDMA over Thunderbolt 5; JACCL; exo speedups 1.8×/3.2×; latency figures as reported — see §3.6 discrepancy note). Aug–Oct 2026.

**Ours (not web sources)**

28. Volmarr/Yrsa campaign records, memory log 2026-11-14: purpleraider Z13 graphics-pool cap set to 100 GiB at Volmarr's order (down from ~124 GiB), verified live post-restart (`amdgpu.gttsize=102400`, `ttm.pages_limit=26214400`, ~124 GB MemAvailable); and 2026-11-12: KDE low-memory alerts traced to memcg-caged test processes with 111 GiB machine-available. Cited in §7.1 as our own facts.

---

*End of OR-2 dossier. Companion dossiers in this series cover llama.cpp/GGML, Ollama itself, and vLLM; cross-references to their findings belong in the synthesis, not here.*
