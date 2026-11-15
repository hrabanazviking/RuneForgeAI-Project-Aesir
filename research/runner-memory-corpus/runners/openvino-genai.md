# OpenVINO GenAI — OR-2 Dossier

- **Project:** OpenVINO GenAI (`openvino.genai`), the generative-AI pipeline library built on top of the OpenVINO Runtime
- **Vendor / steward:** Intel, under the `openvinotoolkit` GitHub organisation
- **Licence (verified):** Apache License 2.0 — stated in the repository README's License section and in the `LICENSE` file it links to; source file headers carry the SPDX identifier `Apache-2.0`. Verified 2026-11-15.
- **Languages / bindings:** C++ is the implementation and primary API. Official bindings exist for Python (pybind11, distributed as the `openvino-genai` PyPI package), C (a stable-ABI wrapper used for text generation, vision-language chat, and Whisper samples), and JavaScript / Node.js (N-API wrappers, including `LLMPipeline` text-generation samples). Samples in the repo are organised by language and modality on exactly that split.
- **Links (as read):**
  - Repository: `github.com/openvinotoolkit/openvino.genai`
  - Documentation hub: `openvinotoolkit.github.io/openvino.genai` and the GenAI sections of `docs.openvino.ai` (2025 documentation set, 2025.4 line, used as the reference version for this dossier)
  - Supported-models list: `SUPPORTED_MODELS.md` in the repository root
  - Serving companion: OpenVINO Model Server (OVMS), `github.com/openvinotoolkit/model_server`
  - Conversion companion: Optimum Intel (`optimum-cli export openvino`), NNCF for weight compression
- **As of:** 2026-11-15. All sources accessed 2026-11-15; see §11. Where a fact changed between the 2024 and 2025 documentation sets, both values are given and the drift is flagged rather than silently resolved.
- **Companion dossier:** This file is one half of the corpus's "vendor runtime" pair. Its sibling covers ONNX Runtime GenAI. The two are contrasted only at the level of public fact in §2 and §7; neither dossier depends on the other.

## Essence

OpenVINO GenAI is not a model server and not a training framework. It is a thin, embeddable library of ready-made generative pipelines — one object per task (`LLMPipeline` for text, `VLMPipeline` for vision-language, `WhisperPipeline` for speech recognition, diffusion and speech-synthesis pipelines beside them) — layered over Intel's graph compiler and runtime. The user converts a Hugging Face checkpoint once, offline, into OpenVINO's Intermediate Representation (IR), optionally compressing the weights with NNCF at export time; at run time a pipeline object loads the whole converted folder (model, tokenizer, detokenizer, default generation config), compiles it for a single named device — `"CPU"`, `"GPU"`, or `"NPU"` — and owns the generation loop: tokenisation, sampling, chat history, streaming, speculative decoding, and, on CPU and GPU, a continuous-batching scheduler with a paged KV cache. Its reason to exist is the Intel estate: Xeon and Core CPUs (where it is genuinely competitive), Intel integrated and Arc discrete GPUs, and the NPUs in Core Ultra laptops — three very different pieces of silicon behind one API and one device string. That unification is both its best idea and the source of its sharpest compromises, because the three devices do not actually behave alike, and the NPU in particular imposes a static-shape, compiled-blob regime that leaks through the abstraction (§4). For a Go runner being designed from scratch, GenAI is most valuable as two lessons at once: a clean pipeline-API ergonomics study, and a worked example of what designing for an NPU-shaped memory regime does to every other layer of a runtime.

---

## 2. Architecture

### 2.1 The four layers

Public documentation and Intel's own workflow guides consistently describe the same stack, and keeping the layers separate explains most of GenAI's behaviour:

1. **Optimum Intel (offline, Python).** The Hugging Face integration. Its export command loads a PyTorch (or already-quantised) checkpoint, traces/converts it, and writes IR. It is needed to *prepare* models, not to run them — the GenAI README is explicit that Optimum is not required at run time.
2. **OpenVINO IR (on disk).** The converted model: an `.xml` file describing graph topology (operations and edges, with tensor shapes and types recorded on the ports) and a `.bin` file holding the weights and binary constants the XML refers to by offset. A GenAI model folder contains more than one such pair: the main decoder model plus separate tokenizer and detokenizer IR models, alongside JSON configuration including the default generation config. Tokenisation therefore runs inside OpenVINO (via the bundled `openvino-tokenizers`) rather than in host-language code — one reason the library advertises that it needs no external dependencies to run a generative model.
3. **OpenVINO Runtime (per-device compilation).** The runtime reads IR and compiles it for one device through that device's plugin: graph transformations, kernel selection, and memory planning happen at load time, on the user's machine, for the specific silicon present. Compilation is therefore a real, sometimes slow, start-up cost (extreme on NPU — §4.4), and compiled results can be cached to disk.
4. **OpenVINO GenAI (generation layer).** The pipelines. They own everything autoregressive that a raw compiled graph does not: the decode loop, sampling strategies (greedy, temperature / top-k / top-p, grouped beam search), stopping criteria, chat-history handling, streamer callbacks, LoRA adapter selection, speculative decoding, and the continuous-batching scheduler when one is configured.

A useful contrast with the sibling vendor runtime, at public-fact level only: ONNX Runtime GenAI builds on a portable ONNX graph and swaps execution providers underneath it, whereas OpenVINO GenAI builds on a single-vendor compiler whose IR, plugins, and compression toolchain are all Intel's. The first design optimises for breadth of backends; the second for depth on one vendor's hardware. Everything else in this dossier follows from that choice.

### 2.2 The pipeline API design

The API's centre of gravity is a single constructor pattern repeated across tasks:

- Construct a pipeline from a *model directory* and a *device string*. Construction loads the main model, tokenizer, detokenizer, and default generation configuration automatically — there is no separate "load tokenizer, load config, build engine" sequence for the caller to get wrong.
- Call `generate(...)` with a prompt (or, for the other pipelines, an image, an audio buffer, or both), either accepting the model's default generation config, mutating a copy obtained from the pipeline, or passing per-call keyword-style overrides such as a maximum new-token count. Results come back as decoded text (or encoded results with performance metrics attached, if the caller asks at that level).
- For chat, the pipeline offers explicit chat-session handling: starting a chat keeps history inside the pipeline and reuses the KV cache across turns instead of re-prefilling the whole conversation each time; finishing a chat releases that state.
- For streaming, the caller supplies a streamer callback/object that receives subword pieces as they are produced and can signal the pipeline to stop; the same mechanism serves Python, C++, and JavaScript samples.
- LoRA is a pipeline-level concept, not a model-conversion step: multiple adapters can be loaded per model, the active set is selected per generation, and adapters can be blended with coefficients. Release notes for the 2025 line record LoRA support being extended into the speculative-decoding and continuous-batching backends, which matters because it means adapters compose with the fast paths rather than forcing a fallback to the simple path.

The pipeline family, as listed in the GenAI API reference read for this dossier, includes at minimum: `LLMPipeline` and its explicit sibling `ContinuousBatchingPipeline` for text; `VLMPipeline` for vision-language models (LLaVA, MiniCPM-V, InternVL, Qwen-VL families among the documented examples); `WhisperPipeline` for speech recognition (with a newer unified ASR pipeline appearing in later samples); `Text2ImagePipeline`, `Image2ImagePipeline`, and an inpainting pipeline for diffusion models (Stable Diffusion 1.5/2.1/XL, LCM, Flux families among the documented examples); `Text2SpeechPipeline` (SpeechT5 in the README's account); and RAG-oriented `TextEmbeddingPipeline` and a text-rerank pipeline. This breadth is deliberate: GenAI is a *pipelines library*, not an LLM library with extras bolted on.

Two design consequences deserve emphasis for the corpus's purposes:

- **One object owns the whole life cycle.** There is no scheduler object, cache object, or tokenizer object in the normal user's path. Configuration that a serving system would expose as first-class objects (see §3) is folded into an untyped property bag passed at construction (a dict in Python, an `AnyMap` in C++). That is superb ergonomics for embedding and noticeably weaker for operability: misspelt or device-inappropriate keys are a run-time matter, not a type error.
- **The model directory is the unit of deployment.** Because the folder carries model + tokenizer + detokenizer + defaults together, "which model is this and how does it tokenise" can never drift apart — at the price of every model being a bespoke converted artefact rather than a file any other runtime can read (the GGUF exception is covered in §2.4).

### 2.3 The device abstraction: what it buys, what it costs

Devices are named by short strings — `"CPU"`, `"GPU"`, `"NPU"` — passed to the pipeline constructor, and the documented promise is that moving a workload between CPU and GPU requires no other code change. Around that core, the underlying runtime offers three virtual devices worth naming because GenAI inherits them:

- **`AUTO`** — a proxy device that selects a real device for the compiled model rather than binding the caller to one.
- **`HETERO:<device>,<device>,...`** — the heterogeneous plugin: one graph is split across several devices, with earlier devices taking priority and later ones acting as fallback for operations the earlier ones cannot run. The Model Server documentation gives the canonical form `HETERO:GPU,CPU`. OpenVINO automatically divides the network between the listed devices.
- **`MULTI`** — the multi-device plugin, which distributes *separate inference requests* across devices in parallel (a throughput device, not a graph-splitting one).

**What the abstraction buys.** A single binary and a single model folder can target a Xeon server, a laptop iGPU, and a laptop NPU; fallback via `HETERO` means an unsupported operator degrades to CPU instead of failing; and embedding applications can defer the hardware decision to run time or to the end user's machine. For Intel's actual customer base — enterprises with mixed fleets of Intel machines — this is the whole point.

**What it costs.** Three costs recur throughout this dossier and are worth stating once, plainly:

1. *Compilation is per-device and not free.* The same IR compiles differently, at different speeds, with different failure modes, on each plugin. Start-up latency and cache management (§4.4) become part of the runtime's real API surface whether it wants them or not.
2. *Capabilities are not uniform behind the string.* Continuous batching exists on CPU/GPU and not on NPU (§3, §4); sampling breadth has historically been narrower on NPU; context handling on NPU is static-shape (§4.3). The device string type-checks everywhere while meaning different things in different places. The abstraction is honest about *where* code runs and quietly dishonest about *what will work* when it gets there.
3. *Tuning is a stringly-typed property bag.* Device-specific performance hints, cache directories, and NPU context budgets are all passed as named properties in the same untyped map. That keeps the constructor signature stable across devices, and makes discoverability and validation the documentation's problem instead of the compiler's.

### 2.4 Model sources and the GGUF side door

The normal model source is Hugging Face via Optimum Intel export (§5 covers the compression choices made at that moment). Intel also publishes pre-converted, pre-compressed models on Hugging Face under its own organisation (for example INT4-compressed Llama, Mistral, and Qwen variants, including NPU-tuned channel-wise builds), which can be exported/passed through without the user choosing quantisation parameters.

Separately, GenAI 2025.2 added a *preview* GGUF reader: `LLMPipeline` can read a GGUF file and construct the OpenVINO graph on the fly at initialisation, targeting GPU inference in the documented examples. The 2025.2-era limitations recorded in Intel's own blog are material: conversion of GGUF tokenizers to OpenVINO format was not yet supported in that release, and Qwen3 GGUF support was explicitly work-in-progress. As of the sources read, GGUF is best characterised as an interoperability side door under active construction, not a second native format — the IR folder remains the format the rest of the system (caching, NPU compilation, Model Server) is built around.

### 2.5 Supported models (shape, not the list)

The authoritative list is the repository's `SUPPORTED_MODELS.md`, which the README itself annotates with the caveat that listed models "can work, but were not tried yet" in some cases — i.e. the list mixes validated and expected-to-work entries, and per-device validation is narrower than the headline list, dramatically so for NPU (§4.3). The families documented across the sources read include: Llama (2, 3.x, 3.2 vision), Qwen (2, 2.5, 3, including VL and embedding/reranker variants), Phi (3, 3.5, 4, including multimodal), Mistral, Gemma, DeepSeek-R1 distillations, GPT-OSS (preview MoE support validated on CPU/GPU in the 2025.4 notes), Whisper (tiny through large), LLaVA / MiniCPM-V / InternVL vision-language families, Stable Diffusion and Flux image families, and SpeechT5. Model support should be treated as a fast-moving compatibility matrix, not a fixed property of the runtime.

---

## 3. Scheduling

GenAI contains *two* execution regimes for LLMs, and which one a given `LLMPipeline` instance uses is decided at construction:

- **The default (stateful) pipeline** — one generation at a time in the simple mental model, with the KV cache held as internal state of the compiled model (§4.1). Chat sessions, streaming, beam search, and speculative decoding live here.
- **The continuous-batching (CB) pipeline** — selected by supplying a `SchedulerConfig` in the pipeline's construction properties (exposed directly as the `ContinuousBatchingPipeline` class in the API reference). This is the serving-oriented component, also used as the engine inside OpenVINO Model Server (§6). It is available on CPU and GPU; the Model Server documentation states flatly that the NPU works only with the stateful servable type, and nothing in the GenAI sources read contradicts that split.

### 3.1 The continuous-batching design, as documented

The CB pipeline's public configuration surface (`SchedulerConfig` in the API reference) is explicitly described in its own documentation as containing "vLLM-like settings", and the resemblance is structural, not cosmetic:

- **Paged KV blocks.** The scheduler manages the KV cache as a pool of fixed-size blocks: the config exposes both a block count (`num_kv_blocks`) and a total cache budget in gigabytes (`cache_size`), plus a block-size setting. Memory is committed per block as sequences grow instead of being reserved for maximum length up front — the standard paged-attention argument, adopted wholesale.
- **Token-budget scheduling.** `max_num_batched_tokens` caps the total tokens processed in one scheduler step (counting tokens across all sequences, not sequences themselves), and `max_num_seqs` caps how many sequences are actively scheduled. The Model Server's graph configuration gives `max_num_batched_tokens` a default of 256 and `max_num_seqs` a default of 256, with guidance that the latter should not exceed the former.
- **Prefix caching.** An opt-in flag retains computed KV blocks after sequences finish so that a later request sharing a prompt prefix (the classic case: a chat history resent every turn, or a shared system prompt) reuses them instead of re-evaluating. The scheduler documentation is unusually candid about the memory semantics: with prefix caching on, blocks are *not released* when a sequence ends; they can be overwritten when the cache limit is reached, and maximum RAM use is bounded by `cache_size` / `num_kv_blocks`. In the Model Server's performance-tuning guidance, prefix caching for the chat-style endpoint defaults to on.
- **Preemption under pressure.** The Model Server reference describes the failure behaviour when a statically-sized cache fills: running requests may be preempted to free cache for others, a preempted request's cache must be recomputed when it is rescheduled, and a single request that alone exhausts a too-small cache is terminated before reaching its stopping criteria. Dynamic allocation (cache size 0 in the server config) instead grows the pool as required, trading the hard bound for protection against preemption — with the documented risk of consuming all available RAM under unrestricted concurrency and long contexts.
- **Tooling.** The repository ships continuous-batching benchmark and accuracy tools, including a cache-visualisation utility that inspects block allocation, prefix-cache hits, and eviction events over time — evidence that the block manager is treated as a real, inspectable subsystem rather than an internal detail.

### 3.2 Chunked prefill: present, under another name

GenAI does not expose a setting literally called "chunked prefill" in the sources read. The equivalent mechanism is **Dynamic Split Fuse**, listed in the Model Server's overview as one of the GenAI library's headline serving techniques alongside continuous batching and paged attention, and exposed in `SchedulerConfig` as `dynamic_split_fuse` ("whether to split prompt / generate to different scheduling phases"), enabled by default in the Model Server configuration.

In substance this is the Sarathi / DeepSpeed-FastGen family of scheduling: long prompts are split into chunks sized against the per-step token budget and fused into steps alongside other sequences' decode tokens, so one large prefill cannot monopolise an iteration and stall every concurrent decode. The tuning guidance confirms the mechanism from the negative side: with Split Fuse *disabled*, `max_num_batched_tokens` should be raised to the model's maximum context length, because an unsplit prompt must then be processed fully in one step. With it enabled, the default budget of 256 tokens per step favours short contexts and high concurrency, and raising the budget (4096, 8192, up to context length) is the documented lever for improving first-token latency. Any comparison with runtimes that advertise "chunked prefill" should map the term onto Split Fuse rather than reporting the feature as absent.

### 3.3 Speculative decoding and its relatives

GenAI documents three distinct acceleration schemes that are easy to conflate and should not be:

1. **Classic draft-model speculative decoding.** A smaller draft model proposes several tokens autoregressively; the main model validates them in one pass and corrects from the first mismatch. In the API this is a construction-time arrangement: a draft model object is created from its own model folder *and its own device string*, a `SchedulerConfig` (with a cache size) is supplied, and the generation config sets how many tokens the draft proposes per round (`num_assistant_tokens`, 5 in the documented example). Draft and main models may sit on different devices. The 2025 release notes record LoRA support being added to this path.
2. **Prompt lookup decoding.** A draft-free variant that proposes candidate continuations by matching n-grams already present in the prompt — well suited to summarisation, editing, and RAG-style workloads where the output copies the input. The 2025.0 notes introduce it as improving second-token latency for predefined-prompt use cases, and the 2025.4 notes record it gaining LoRA support.
3. **NPU-oriented speculative decoding.** The 2025.4 release notes record an SDPA-based speculative decoding implementation used for NPU — i.e. on the device where the standard CB machinery does not exist, speculative execution had to be built in a form compatible with the NPU's static-shape regime (§4.3). Intel also publishes small purpose-built draft models for this ecosystem (a FastDraft model for Phi-3-mini on NPU is referenced in later release-note summaries). **[Marked as release-note-level evidence: the dossier did not read a full design document for the SDPA variant, only its announcement.]**

What the sources read do *not* document for the as-of version is a Medusa/EAGLE-style multi-head speculative scheme in the mainline GenAI API; later (2026) release summaries describe EAGLE-3 and multi-token-prediction support, but those postdate the 2025.4 reference line used here and are noted only to prevent a false "never supported" claim. Within the as-of frame: draft-model speculative decoding and prompt lookup are the documented schemes.

### 3.4 Other scheduler-level features

- **KV cache eviction** (§4.2) is configured through the same `SchedulerConfig`, making lossy cache shrinking a scheduler policy rather than a model property.
- **Sparse attention during prefill** is likewise a scheduler option (`use_sparse_attention` plus a sparse-attention config), with modes and retained-token parameters exposed in the Model Server's reference.
- **Grouped beam search** is supported in the generation config (beam count, beam groups, diversity penalty), a reminder that the pipeline serves classic decoding strategies alongside sampling — serving systems built purely around sampling often drop this, and GenAI does not.

---

## 4. KV Cache and Memory

This is the section where GenAI is most instructive for the corpus, because it contains *three* different KV regimes under one API, selected by device and scheduler choice.

### 4.1 The stateful regime (default pipeline)

Decoder models are exported as **stateful** models by default: the KV cache is held inside the compiled model as internal state, rather than being exposed as explicit past-key-value inputs and outputs that the host shuttles back and forth each step. The export flag to disable this exists for legacy code expecting explicit KV tensors and is documented as potentially slower. Consequences:

- The cache lives wherever the compiled model lives — on-device, managed by the runtime, invisible to the caller. There is no host-side KV tensor to copy, pin, or accidentally retain.
- The mental model is session-like: one compiled model instance carries one evolving context (chat mode reuses it across turns), and resetting context is an operation on the pipeline, not a matter of dropping a tensor.
- The cost is opacity and inflexibility: the caller cannot inspect, share, offload, or fork the cache, and concurrency means multiple compiled instances or a move to the CB pipeline. Stateful execution optimises the single-user embedded case GenAI was designed for, and it shows.

### 4.2 The paged regime (continuous batching, CPU/GPU)

Under CB, the cache becomes an explicitly budgeted, shared resource (§3.1): a block pool sized in gigabytes or blocks, allocated per sequence as it grows, optionally retained for prefix reuse, subject to preemption when oversubscribed. Two further memory controls belong here:

- **KV cache precision.** The runtime accepts a KV-cache precision setting (exposed through plugin configuration, e.g. `KV_CACHE_PRECISION` set to `u8` in Model Server export examples). Storing keys and values in 8-bit unsigned form roughly halves cache size versus FP16, plus a small per-group scale overhead. The arithmetic that makes this matter, worked in an independent deep-dive checked against the current documentation (see §11): a Llama-class 8B model (32 layers, 8 KV heads, 128-dimensional heads, FP16) spends 128 KiB of KV per token, so one 4,096-token sequence costs 0.5 GiB of cache and a 32k context costs 4 GiB *per sequence* — as large as the INT4 weights themselves. Cache precision and cache budget are therefore first-order capacity decisions, not tuning trivia, and GenAI's design treats them that way by surfacing both in the scheduler/server config.
- **Lossy eviction.** Both the GenAI README and the scheduler config document a KV token-eviction algorithm that prunes less-impactful tokens to shrink the cache during long generations. The Model Server reference exposes its configuration in detail: a protected start segment, a protected recent window, a maximum cache size, an optional SnapKV-style observation window, and a "KV-Crush" component with configurable anchor-point behaviour and budget, plus aggregation modes that score token importance cumulatively or normalised by token lifetime. This is a deliberate accuracy-for-memory trade, off unless configured, and it is the only regime in GenAI where the cache is allowed to *forget* mid-generation by design.

### 4.3 The NPU regime: static shapes and compiled blobs

The NPU path is a different memory world, and the documentation is commendably explicit about it. The governing facts, all from the GenAI-on-NPU guide (2025.4 line):

- **Static-shape execution.** The LLM pipeline for NPU "leverages the static shape approach", trading flexibility for execution performance. Two budgets define the compiled shape: `MAX_PROMPT_LEN` (default **1024** tokens) and `MIN_RESPONSE_LEN` (default **128** tokens in the 2025.4 guide; the 2024 guide said 150 — the drift itself is a warning that these defaults move between releases). **Maximum context is defined as the sum of the two.** Chat history accumulates inside that same budget, so long conversations require raising `MAX_PROMPT_LEN` at construction — i.e. at compile time.
- **Padding economics.** By default, a short prompt costs the same time-to-first-token as a full-length one, because the compiled graph is shaped for the maximum; the unused prompt budget converts into generation headroom (the guide's own example: a 30-token prompt against the defaults can generate up to 1024 + 128 − 30 = 1122 tokens). Static shape does not waste the *budget*, but it does waste the *latency* — prefill pays for tokens that were never sent.
- **Dynamic prefill, partially, from 2025.3.** A chunking mechanism (`NPUW_LLM_PREFILL_CHUNK_SIZE`, default 1024) activates automatically when `MAX_PROMPT_LEN` exceeds the chunk size, and the `PREFILL_HINT` property defaults to `DYNAMIC` from 2025.3 (set it to `STATIC` to restore the older behaviour). Note what this is and is not: it chunks *prefill execution* to support longer prompts; it does not turn the NPU pipeline into the CB pipeline, and generation remains shaped by the compiled budgets.
- **Generation hints.** `GENERATE_HINT` selects `FAST_COMPILE` (default; faster compilation, lower performance) or `BEST_PERF` (slower compilation, best performance) — a compile-time/performance trade exposed as a user-facing knob because on NPU it is large enough that hiding it would be worse.
- **Weights must arrive in NPU form.** Export for NPU *requires* symmetric 4-bit compression (INT4 or NF4), a ratio of 1.0 (maximise the 4-bit share), and either channel-wise (`--group-size -1`) or group-wise (`--group-size 128`) quantisation (§5). NF4 is supported only on Core Ultra Series 2 (Lunar Lake) NPUs and later. There is no "run the FP16 model on the NPU and see" path.
- **Host memory pressure is real.** The guide warns that Core Ultra Series 2 systems may need **more than 16 GB of RAM** to process prompts longer than 1024 tokens with models over 7B parameters (Llama-2-7B, Mistral-7B, Qwen-2-7B named) — compilation and staging, not just weights, consume host memory.
- **Sampling breadth (flagged drift).** The 2024 NPU guide stated the NPU pipeline supports greedy decoding only, requiring sampling to be disabled. The 2025.4 NPU guide read for this dossier does not repeat that restriction in the sections retrieved, and 2025.4 adds SDPA-based speculative decoding for NPU. The honest summary is: NPU decoding options have historically been much narrower than CPU/GPU, the gap was closing across 2025, and any design depending on the current state must verify it against the exact release in use. **[Unverifiable to a single current sentence from the sources read — see the report note.]**
- **Whisper is the exception that proves the rule.** Whisper on NPU (supported since 2024.5, tiny through large) carries no NPU-specific export requirements in the guide — an encoder-decoder transcription model with bounded audio input fits the static regime without the open-ended-context problem that makes LLMs hard there.

### 4.4 Compiled-blob caching and ahead-of-time compilation

Because NPU compilation happens on the fly and "may take substantial time", the NPU pipeline documents a two-level answer that generalises beyond NPU as a design pattern:

- **Cache directory.** A `CACHE_DIR` property enables the standard OpenVINO compiled-model cache; a `CACHE_MODE` hint chooses whether the cached blob *includes* weights (`OPTIMIZE_SPEED` — faster loading, larger blob) or *excludes* them (`OPTIMIZE_SIZE` — a "weightless" blob that requires the original model to be present at load). A legacy NPU-specific weightless cache option exists but has been superseded by the device-neutral mechanism since 2025.1, per the guide.
- **Ahead-of-time export/import.** `EXPORT_BLOB` + `BLOB_PATH` writes the compiled model to an explicit location; later runs import from the same path. Weightless import additionally needs the original weights path or model object, and is specifically optimised to use less memory than regular compilation. Blobs can be encrypted with caller-supplied callbacks; in weightless mode the whole blob is encrypted, in full-weight mode everything except the weights is.

The memory story in one sentence: on NPU, *the compiled form is the resident form* — weights live inside (or alongside) a device-specific compiled blob shaped for a fixed context budget, KV lives inside that compiled world's fixed shapes, and the system's answer to slow compilation is to make the compiled artefact itself a cacheable, exportable, encryptable file. That is a coherent regime, and §10 argues it is the most transferable idea in the whole dossier.

### 4.5 Per-device summary

| Aspect | CPU | GPU (Intel iGPU / Arc) | NPU (Core Ultra) |
|---|---|---|---|
| Pipeline regimes | Stateful + continuous batching | Stateful + continuous batching | Stateful only |
| KV allocation | Paged block pool under CB; internal state otherwise | Same as CPU; cache resides in device/shared memory | Fixed by compiled shape (`MAX_PROMPT_LEN` + `MIN_RESPONSE_LEN`) |
| KV precision control | `u8` cache precision documented | Same | Governed by compiled model; no CB-style cache knobs |
| Prefix caching | Yes, under CB | Yes, under CB | Not as a CB feature; chat history reuse within the session budget |
| Compilation | Per-device compile at load; cacheable | Per-device compile at load; cacheable | Slow on-the-fly compile; blob cache / AoT export is the documented remedy |
| Weight format freedom | Broad (FP32/FP16/INT8/INT4/NF4) | Broad | Symmetric INT4/NF4 only, ratio 1.0 |

---

## 5. Quantization

### 5.1 Where quantisation happens

Quantisation in the OpenVINO world is overwhelmingly an **export-time** decision made by NNCF (Intel's Neural Network Compression Framework) as driven through Optimum Intel — not a load-time flag on the pipeline. The pipeline runs whatever precision the IR folder contains. This is the opposite end of the design spectrum from runtimes that ship one file and pick a kernel per device at load, and it explains both GenAI's performance (the graph, scales, and layouts are all baked for the target class) and its friction (changing your mind about precision means re-exporting).

### 5.2 The documented option space

- **Weight formats:** `fp32`, `fp16`, `int8`, `int4`, `nf4`. Models larger than 1B parameters are compressed to INT8 **by default** on export — a user who exports without thinking gets an 8-bit model, which is either a thoughtful default or a silent surprise depending on one's philosophy; the dossier notes it because it affects reproducibility of any benchmark that does not state its export flags.
- **Symmetry:** symmetric compression (no zero-points) versus asymmetric. Symmetric is slightly less accurate and is *required* for NPU.
- **Granularity:** group-wise with group size 128 (the general documented recommendation) versus channel-wise (group size −1), which generally performs best and costs the most accuracy; group quantisation is recommended for smaller models (up to roughly 4–5B) and channel-wise tends to win for larger ones, per the NPU guide's guidance, which is stated generally enough to apply beyond NPU.
- **Mixed precision via ratio:** a ratio below 1.0 leaves a fraction of layers at a higher backup precision to recover accuracy. At INT4, the embedding table and final projection are compressed to INT8 rather than INT4 by default (they are the most error-sensitive layers) unless the exporter is told to compress all layers.
- **Data-free vs data-aware.** The default compression is data-free. NNCF additionally provides data-aware methods that use a calibration dataset (Wikitext-2 in the documented examples): **AWQ** and **scale estimation** are exposed as export flags and are specifically recommended stacked together for channel-wise models; **GPTQ** is available both as an NNCF data-aware method (the slowest export path, per the independent deep-dive's summary of the documentation) and as an *import* path — Hugging Face checkpoints already quantised with GPTQ (INT4) can be converted with their quantisation preserved, no additional optimisation step needed.
- **Runtime complements.** Two dynamic techniques sit below the export decision: dynamic quantisation of activations for 4/8-bit MatMuls, and KV-cache quantisation (§4.2). A Whisper-specific path also exists: static INT8 quantisation with a calibration set (LibriSpeech samples in the README example) via a dedicated quantisation mode at export.

### 5.3 Hybrid and split execution — what is actually documented

The task framing for this dossier asked about "hybrid device execution (e.g. GPU+NPU splits)". The honest finding from the sources read:

- **Graph-level splitting exists in the runtime** via `HETERO` (§2.3): a network's operations are divided across the listed devices by capability and priority, with fallback. This is a general OpenVINO mechanism, documented for Model Server targets in forms like `HETERO:GPU,CPU`, and inherited by anything running on the runtime.
- **GenAI's documented LLM-level splits are narrower and more specific:** (a) speculative decoding with draft and main models on *different devices* (the documented example uses CPU for both, with GPU noted as usable); (b) the NPU pipeline's own prefill/generate hint split, which tunes the two phases' compilation strategies on one device; (c) `AUTO` device selection.
- **A first-class, documented "run this LLM split across GPU+NPU" GenAI feature was not found** in the sources read. Given unified memory on Core Ultra parts the idea is natural, and later ecosystem work may exist, but as of the sources read it should be reported as *not a documented GenAI capability*, not assumed. **[Flagged as a negative finding — absence from the documentation set read, not proof of absence from the codebase.]**

---

## 6. Serving and Embedding Surface

### 6.1 Embedding (the library as shipped)

GenAI itself ships as a library, full stop: PyPI wheel / archive install for the C++ side, `pip install openvino-genai` for Python. It has no built-in HTTP server, no request queue beyond the CB pipeline's scheduler, no multi-model management, and no tenancy concepts. Its serving-relevant surface is exactly: the pipelines (§2.2), the CB scheduler (§3), performance metrics returned on generation results (the API exposes raw and summarised perf-metric structures, including token counts and timing, and Whisper-specific variants), and the streamer mechanism. An application that needs an endpoint writes the endpoint.

Language coverage for embedding, consolidated: **C++** (primary, headers per pipeline), **Python** (full pipeline parity in samples), **C** (stable ABI; text generation, vision-language, and Whisper samples), **JavaScript/Node.js** (N-API; text generation samples, with more pipelines added across 2025–2026 release notes). For a Go runner the relevant observation is the *pattern* — a C ABI as the portability layer under idiomatic per-language wrappers — rather than any specific binding.

### 6.2 OpenVINO Model Server (the serving path)

The documented serving story is a separate product, **OpenVINO Model Server (OVMS)**, which embeds the GenAI library and exposes it over HTTP. Public facts from its documentation:

- Text generation is exposed through **OpenAI-compatible endpoints** (`chat/completions`, `completions`, and in the 2026 reference also `responses`), implemented as a MediaPipe graph whose LLM calculator runs the GenAI pipeline in cycles and streams response chunks back.
- The server distinguishes **servable types** that mirror §3's split exactly: language-model and vision-language servables each come in *Continuous Batching* and *Stateful* flavours, plus a stateful-only omni servable. The choice is inferred: target device `NPU` always selects Stateful; any other device selects Continuous Batching. Stateful servables ignore most CB configuration.
- Server configuration (`graph.pbtxt` node options) is the `SchedulerConfig` surface wearing a protobuf coat: maximum batched tokens, cache size in GB (0 = dynamic), maximum sequences, Split Fuse toggle, device, plugin config string, prefix-caching toggle, cache-eviction config, plus endpoint-level limits (best-of limit, max-tokens limit) and optional reasoning/tool-call parsers with tool-guided generation.
- OVMS also serves classic (non-generative) models and supports the runtime's device machinery (`AUTO`, `HETERO`, `MULTI`, GPU/NPU accelerator configuration), which is how the "one server for the Intel estate" story is assembled.

The architectural takeaway for the corpus: Intel deliberately keeps the *library* minimal and puts *serving* in a sibling server that consumes it — the same library/server separation Ollama collapses into one binary. Neither is obviously right; §10 returns to this.

### 6.3 Relationship to the rest of the Intel stack

GenAI sits between Optimum Intel / NNCF (above it, at export time) and the OpenVINO Runtime plugins (below it, at run time), and beside OVMS (which hosts it). It is also worth recording that OpenVINO appears as an execution provider inside ONNX Runtime and as a backend inside llama.cpp in the wider ecosystem — evidence that Intel treats the runtime, not GenAI specifically, as the reusable substrate. GenAI is the opinionated generative layer Intel offers on top of its own substrate; third parties are free to (and do) build different generative layers on the same runtime.

---

## 7. Hardware Reality

**Where it genuinely wins, as documented and as fairly characterised:**

- **Modern Intel CPUs, especially Xeon.** The CPU plugin exploits AVX-512 and AMX where present, weight compression maps well onto CPU memory bandwidth, and the CB pipeline turns a Xeon box into a credible multi-user LLM server without any accelerator. For the large installed base of Intel-only servers, GenAI is frequently the *only* first-party-optimised path, which in practice matters more than peak benchmarks.
- **Intel integrated GPUs.** On Core and Core Ultra machines the iGPU shares system memory, so an INT4 8B-class model runs on the GPU without a discrete card's VRAM ceiling; the device string makes trying it a one-word change. This is the AI-PC scenario Intel's documentation is organised around, and it is real: the alternative on the same hardware is usually a generic backend treating the iGPU as an afterthought.
- **Arc discrete GPUs.** The Arc A770-class cards are a documented, showcased target (the repo README's own demo image shows Llama 3.2 running on an Arc A770). Independent measurements (§8) show GenAI extracting substantially more from an A770 than generic SYCL paths on the same card.
- **Core Ultra NPUs, for their intended niche.** The NPU's win is not raw speed (§8) but *offload*: sustained generation on a low-power block that leaves CPU and GPU free, inside the static-shape regime's limits. For always-available background inference on a laptop, that trade is coherent.

**Where it does not win:**

- **NVIDIA discrete GPUs.** GenAI has no CUDA path; the runtime's NVIDIA support exists only as a contrib plugin referenced by the Model Server docs (usable via `HETERO:NVIDIA,CPU`), which is a compatibility story, not a performance one. Anyone with an NVIDIA card has better first-party options, and Intel's materials do not seriously contest this.
- **AMD hardware.** No AMD GPU or NPU path was found in the GenAI documentation read. (The broader OpenVINO runtime's CPU plugin is an x86-first codebase with some ARM support in the wider toolkit, but GenAI's documented LLM story is Intel CPU/GPU/NPU.) On AMD silicon — including the Ryzen AI / Strix Halo class of machines — GenAI is simply not the tool.
- **Non-Intel NPUs generally.** The NPU support is Intel's NPU (Core Ultra, via its driver stack; the guides call for a recent NPU driver, 32.0.100.3104 or newer in the troubleshooting notes). There is no abstraction here that reaches Qualcomm, AMD, or Apple neural engines.
- **Anything that needs the newest model architecture this week.** The export-and-validate pipeline (Optimum support, GenAI pipeline support, per-device validation) lags raw PyTorch/GGUF ecosystems for brand-new architectures; MoE support, for example, was still labelled preview for named models in the 2025.4 notes.

---

## 8. Performance Character

**Reading rule for everything in this section:** Intel's published LLM numbers for OpenVINO are measured on Intel parts, typically against Hugging Face Transformers or llama.cpp running on the *same Intel parts*, at batch size 1 for client scenarios unless stated otherwise. They answer the question "how well does Intel's stack use Intel silicon", not "how does this silicon compare with another vendor's". Numbers below carry their hardware context, per corpus law.

### 8.1 Intel-published figures (vendor frame)

- **Xeon throughput.** Intel's Llama 3.2 solutions article (tests run by Intel in September 2024, OpenVINO nightly 2024.5-era build) reports Llama 3.2 3B, 1024 input / 128 output tokens, reaching **619 tokens/second on 5th Gen Xeon** and **1122 tokens/second on Xeon 6 (P-core)**, with P99 next-token latency under 50 ms. Read as: small model, server CPU, throughput-oriented configuration — a demonstration that CPU serving is a real product surface for this stack, not a fallback.
- **Xeon vision latency.** The same article reports Llama 3.2 11B Vision (single image + short query, 128 output tokens, BF16) on a two-socket Xeon 6 P-core platform at **29 ms next-token latency**.
- **AI-PC latency.** The same article's client figures (Core Ultra 9 288V laptop, built-in Arc graphics, 32 GB LPDDR5, Windows 11, batch size 1) are presented as latency graphs for Llama 3.2 1B and 3B on the iGPU and on an Arc A770 16 GB; the text of the article does not state the graphed millisecond values, so this dossier does not quote any. **[Deliberately unquoted: graph-only data.]**

### 8.2 Independent spot measurements (single-machine frame)

Two independent measurements, included because they show the *shape* of GenAI's performance rather than its marketing point, both on Intel integrated/Arc hardware and both single-machine, single-model exercises — not population estimates:

- On an **Arc A770 16 GB**, a community benchmark collection (March 2026 measurements, summarised October 2026) reports Qwen3-8B decoding at **45.5 tokens/second via OpenVINO INT4 versus 21.0 tokens/second via llama.cpp SYCL (Q4_K_M)** on the same card, and Qwen3-14B at 23.3 versus 14.7 tokens/second. On Intel's own discrete GPUs, in other words, the vendor runtime's lead over the generic backend is large — the mirror image of the usual NVIDIA story.
- On a **Core Ultra 7 255H (Arc 140T iGPU)** laptop, a November 2026 hands-on comparison of a 2B model found OpenVINO prefill on an empty context nearly **3× faster** than a llama.cpp SYCL setup (2263 vs 800 tokens/second), with the advantage essentially gone by 8k context (529 ± 162 vs 503) and reversed at 16k–32k, and decode advantages small throughout (29.6 vs 27.4 tokens/second at empty context). The same write-up found a from-scratch GenAI FP16 export of a different 2B model markedly slower than SYCL — a reminder that export choices (§5) dominate outcomes and that "OpenVINO" is not one performance number.

### 8.3 Character summary

Synthesising the vendor and independent frames (this paragraph is the dossier's characterisation, marked as such): GenAI's performance profile is *prefill-strong and Intel-relative*. Its compiler does its best work on prompt processing and on extracting throughput from Intel CPUs and Arc GPUs that generic backends underuse; its decode rates on client parts are competitive rather than dominant, because decode is memory-bandwidth-bound and Intel client memory systems are shared and modest; its NPU rates are unremarkable as raw tokens/second and defensible only as tokens/second-per-watt and as offload; and its results are unusually sensitive to export-time decisions (precision, granularity, ratio), so any single-number comparison that does not state its export flags should be discounted. Against Hugging Face Transformers on the same Intel CPU, Intel's framing is a large win; against llama.cpp on the same Intel GPU, the honest range from the sources read runs from "roughly tied on decode, ahead on prefill" (iGPU, small model) to "roughly 2× on decode" (Arc discrete, 8B INT4) — always read per-model, per-device, per-export.

---

## 9. Strengths and Weaknesses

### Strengths

1. **One API across CPU, iGPU, discrete GPU, and NPU** — with a single model folder and a one-word device change for the common cases. Nobody else in the corpus covers the Intel estate this completely, because nobody else is Intel.
2. **Pipeline ergonomics.** The one-object design (§2.2) is the shortest path in the corpus from "I have a model" to "I am generating, streaming, and chatting", with tokenizer, detokenizer, and defaults bundled and LoRA as a run-time concept.
3. **A real serving scheduler inside the library.** Paged KV blocks, token-budget scheduling, Split Fuse, prefix caching, preemption semantics, and cache eviction are all present, documented, configurable through one struct, and shared with the production server (OVMS) rather than reimplemented there.
4. **The NPU regime exists at all.** Whatever its constraints, GenAI is the corpus's worked example of LLM inference on a laptop NPU with a complete story: export rules, compiled-blob caching, AoT compilation, context budgeting, and (from 2025.4) speculative decoding adapted to the device.
5. **Export-time compression depth.** NNCF's option space (symmetry, granularity, ratio-based mixed precision, AWQ, scale estimation, GPTQ import and method) is more complete than most runtimes' load-time quantisation menus, and pre-compressed official models remove the burden for popular checkpoints.
6. **Apache-2.0, open development, broad pipeline family** — LLM, VLM, Whisper/ASR, diffusion, TTS, embeddings, reranking under one licence and one install.

### Weaknesses

1. **The device abstraction leaks.** CB availability, sampling breadth, context mechanics, and compile behaviour all differ by device behind an identical constructor (§2.3, §4.5). Users learn the differences from documentation and failure, not from the API.
2. **Conversion friction.** Every model is an export project: Optimum + NNCF + version-pinned Transformers (the NPU guide pins exact versions and warns newer Transformers await support), substantial host RAM for conversion, and per-device re-validation. The GGUF side door (§2.4) is an admission of this cost and, as of the sources read, still a preview with named gaps.
3. **Stringly-typed configuration.** The property-bag constructor makes device-specific tuning undiscoverable and unvalidatable at compile time in every binding.
4. **NPU constraints are severe for general chat.** A default compiled context budget of 1024 + 128 tokens, padding-priced time-to-first-token in static mode, INT4-symmetric-only weights, long compiles, and >16 GB host RAM warnings for 7B-class long-prompt work make the NPU a specialist device wearing a generalist's device string.
5. **No serving layer in the box.** Anything network-facing requires adopting OVMS and its MediaPipe-graph configuration model — a second, quite different system to learn — or writing a server from scratch.
6. **Single-vendor ceiling.** The stack's excellence is bounded by Intel's silicon roadmap and driver quality (the guides' troubleshooting sections lean on driver updates); on NVIDIA or AMD hardware the dossier in §7 applies in full.
7. **Documentation drift.** Material defaults differ between the 2024 and 2025 doc sets (the `MIN_RESPONSE_LEN` default, Whisper stateful requirements, caching mechanisms) — a real operational hazard for a system whose behaviour is this configuration-sensitive, and a caution for any corpus (including this one) citing it.

---

## 10. Ideas to Steal for a Go Runner

Each idea is stated with its gain and its cost/risk, per corpus convention. All are patterns, re-expressible in Go; nothing here requires Intel hardware to be worth copying.

### 10.1 Treat the compiled artefact as a first-class, cacheable file (the NPU lesson)

**The idea.** GenAI's NPU answer to slow compilation — cache the compiled blob, offer weightless vs full-weight variants, support ahead-of-time export to an explicit path, allow encryption callbacks — generalises into a principle: *whatever your runner derives expensively from a model (compiled graphs, dequantised layouts, tokeniser tables, KV plans), give it a content-addressed on-disk cache with an explicit export/import path.* The weightless/full-weight split is the subtle part: a small blob that rebinds to weights on disk loads fast and stays honest about where the bytes live; a full blob is portable at the price of duplication. Offer both, keyed by (model hash, device, shape budget, version).

**Gain.** Start-up latency becomes a solved, measurable problem instead of a per-launch tax; deployments can pre-compile in CI; the cache key forces the runner to *name* every input that actually affects execution — which is also the correct reproducibility story.

**Cost / risk.** Cache invalidation bugs become correctness bugs (a stale blob silently running old shapes); the key must include everything that matters (device, driver-relevant version, budgets) and nothing that doesn't, or the cache either poisons or never hits. Budget real engineering for it.

### 10.2 Budget context like the NPU does: static-shape honesty as a design teacher

**The idea.** The NPU regime's core discipline — context = an explicit, compile-time budget (`MAX_PROMPT_LEN` + `MIN_RESPONSE_LEN`), with the arithmetic of what fits *stated in the documentation in one line* — is worth importing even into a fully dynamic runner, as an accounting layer: every session declares a prompt budget and a generation budget up front; the runner prices memory from those numbers (weights + KV-per-token × budget × sessions) and *refuses or queues* work that exceeds the machine, instead of discovering it via OOM mid-generation. GenAI's worked KV arithmetic (128 KiB/token for an 8B-class model in FP16; §4.2) shows how quickly honesty gets uncomfortable — which is exactly why it is valuable.

**Gain.** Capacity planning becomes arithmetic, not vibes; multi-session fairness is enforceable; the "how big a model can I run" question gets a computed answer per machine. It also makes the dynamic machinery (paging, prefix caching) a *performance* optimisation layered over a *correctness* budget, rather than the only thing standing between the user and an OOM.

**Cost / risk.** Static budgets waste resources when sessions under-use them (the NPU's padded TTFT is the extreme form). Mitigate by keeping budgets as *admission control* while allocation stays dynamic underneath — steal the accounting, not the padding.

### 10.3 One pipeline object, three modes: generate / stream / chat

**The idea.** Copy the ergonomics, not the implementation: a single `Pipeline` value constructed from (model, device, options) that exposes one-shot generation, a streaming generation (channel- or callback-based, with a stop signal flowing *back* from consumer to producer, as GenAI's streamer does), and a chat session that retains history and KV across turns — with generation configuration obtained from the pipeline, mutated, and passed back, so defaults live in exactly one place (the model artefact).

**Gain.** The embedding API a Go user actually touches stays tiny; the three modes share tokenisation, sampling, and stopping logic by construction; chat's KV reuse is the default rather than a hand-rolled optimisation every application rediscovers.

**Cost / risk.** A fat object tempts fat configuration (see §10.5). Keep the object's *methods* few and push serving concerns (queues, tenants, HTTP) into a separate layer, as Intel does with OVMS — the library/server split is part of the idea, not an accident of it.

### 10.4 Paged KV with a gigabyte-denominated budget, prefix retention, and honest preemption

**The idea.** Adopt the CB scheduler's public shape wholesale: KV as a block pool configured by *total gigabytes* (a number a user can reason about) with block counts derived internally; a per-step token budget plus a sequence cap; opt-in prefix-block retention with documented semantics ("blocks are not released; they are overwritten under pressure; the budget is the bound"); and preemption that recomputes rather than swaps, with termination — not corruption or deadlock — as the documented last resort for a request that cannot fit.

**Gain.** This is the vLLM-validated design, and GenAI's contribution to it is presentational: gigabyte budgets and candid retention semantics are easier to operate than raw block counts. A Go runner gets serving-grade memory behaviour without inventing a second, incompatible vocabulary.

**Cost / risk.** Paging machinery is the most complex code in any runner (block tables, sharing, eviction interplay); prefix retention interacts with eviction and with privacy (one tenant's retained prefix blocks are another's side channel in multi-tenant settings — gate retention per session/tenant, not globally).

### 10.5 Configuration: steal the property bag's flexibility, refuse its stringliness

**The idea.** GenAI's untyped property map is what lets one constructor serve three radically different devices — and it is also §9's weakness 3. The stealable version for Go: a typed options struct per device family behind a common minimal constructor, with unknown/irrelevant options rejected at construction, and device capability differences (CB support, sampling modes, context mechanics) exposed as *queryable capability values* on the constructed pipeline rather than as documentation.

**Gain.** Keeps the one-object ergonomics of §10.3 while making the abstraction's leaks (§2.3) visible in code: a caller can ask the pipeline what it supports instead of learning from a failed generation.

**Cost / risk.** More API surface to design up front, and capability queries can become a compatibility matrix of their own. The discipline is to expose capabilities as data (booleans, limits, enums) — never as per-device method sets that recreate the leak as a type hierarchy.

### 10.6 Speculative decoding with independently-placed draft and target

**The idea.** GenAI's construction — draft model as its own object with its own device string, proposal count in the generation config, scheduler cache shared — maps cleanly onto heterogeneous laptops: draft on the fast/low-power block, target on the big one, or both on one device when that's what's available. Add GenAI's second scheme, prompt lookup, which needs no draft model at all and wins exactly on the copy-heavy workloads (editing, summarisation, RAG grounding) that local runners disproportionately serve.

**Gain.** Two independent levers for latency, one of which (prompt lookup) is nearly free to implement and model-independent.

**Cost / risk.** Draft/target tokeniser and vocabulary must match, acceptance rates are workload-dependent, and on memory-shared client machines the draft's weights compete with the target's KV for the same RAM — the §10.2 budget must price the draft in, or speculative decoding becomes an OOM generator with good benchmarks.

### 10.7 Lossy KV eviction as an explicit, off-by-default policy object

**The idea.** GenAI's eviction config — protected start segment, protected recent window, hard maximum, importance-scored pruning in between — is the right *shape* for long-context degradation: named, bounded, and honest that it trades accuracy for memory. A Go runner should offer it as a policy value attached to a session, never as a global silent behaviour.

**Gain.** Very long sessions degrade gracefully instead of dying at the context wall; the protected-start/protected-recent structure preserves exactly the tokens (system prompt, current focus) whose loss is most visible.

**Cost / risk.** Any eviction is a silent quality change if unreported: surface eviction events in the session's metrics (tokens pruned, at what lengths) so a user debugging a "the model forgot" report can see the mechanism. GenAI's cache-visualisation tooling (§3.1) is the model here — inspectability is part of the feature.

---

## 11. Sources

All sources accessed **2026-11-15**. The reference version throughout is the OpenVINO **2025** documentation set (2025.4 line) unless a source is explicitly identified as the 2024 set or as a later summary; discrepancies between sets are flagged in the text where they occur.

**Primary — project and documentation:**

1. OpenVINO GenAI repository README (`openvinotoolkit/openvino.genai`, master) — essence, pipeline family, optimisation methods, continuous-batching and OVMS relationship, install paths, licence statement (Apache 2.0), per-pipeline Python/C++ examples including Whisper and Text2Speech, supported-models pointer.
2. OpenVINO GenAI documentation — "Text Generation Using LLMs" (use-cases site) — `LLMPipeline` construction and auto-loading behaviour, generation-config workflow, grouped beam search, speculative-decoding example with `SchedulerConfig` and draft model.
3. OpenVINO GenAI documentation — "OpenVINO GenAI on NPU" (2025 set) — NPU export requirements (symmetric INT4/NF4, group sizes, ratio), static-shape budgets and defaults, dynamic prefill chunking (2025.3), prefill/generate hints, compiled-blob caching and AoT export/import, blob encryption, host-RAM warning, Whisper-on-NPU notes, driver troubleshooting.
4. OpenVINO GenAI documentation — "Inference with OpenVINO GenAI" (2025 set, general + earlier NPU material) — pipeline introductions across modalities; earlier statement of greedy-only NPU decoding (flagged in §4.3 as drift).
5. GenAI API reference (2025/2026 doc sets) — `LLMPipeline` constructors (device string, scheduler-config property), `SchedulerConfig` parameter list (token budget, KV blocks, cache size in GB, Split Fuse, prefix caching semantics, eviction and sparse-attention options), pipeline class inventory.
6. OpenVINO documentation — OpenVINO IR format — IR as `.xml` topology + `.bin` weights pair.
7. OpenVINO Release Notes (2025 set) — 2025.4 (dated 1 December 2025 in the notes): SDPA-based speculative decoding for NPU, prompt-lookup LoRA support, GGUF fix notes, MoE preview validations, pipeline additions; 2025.0: prompt lookup introduction.
8. Intel OpenVINO blog — "OpenVINO GenAI Supports GGUF Models" — GGUF reader preview in 2025.2, on-the-fly graph construction, tokenizer-conversion and Qwen3-GGUF limitations.
9. OpenVINO Model Server documentation — "Efficient LLM Serving" reference (2026 set, used for the server's config surface) — servable types and the CPU/GPU-CB vs NPU-Stateful rule, LLM calculator, cache-size / prefix-caching / preemption semantics, eviction-config structure, Split Fuse scheduling guidance; "How to serve LLM models with Continuous Batching via OpenAI API" demo (2025 set) — OpenAI-compatible endpoints, export with KV-cache precision `u8`, cache-size examples; target-device documentation — `HETERO` / `AUTO` / `MULTI` plugins, GPU/NPU accelerator configuration, contrib NVIDIA plugin note.
10. Optimum Intel / OpenVINO documentation — "Inference with Optimum Intel" and weight-compression guidance (2025 set) — default INT8 compression above 1B parameters, INT4 export, GPTQ-checkpoint preservation, dynamic activation quantisation and KV-cache quantisation, AWQ / scale-estimation data-aware flow.

**Secondary — analysis and independent measurement:**

11. S. Belgavi, "OpenVINO for LLMs, in depth" (October 2026, checked against current Optimum Intel and GenAI documentation per its own methods note) — four-layer stack summary, stateful-by-default export behaviour, INT4 embedding/lm-head INT8 default, worked 8B KV arithmetic (128 KiB/token FP16; 0.5 GiB per 4k sequence; `u8` cache roughly halving it). Used for arithmetic and cross-checking, not as authority over Intel's docs.
12. Intel, "Llama with Intel Artificial Intelligence Solutions" (Llama 3.2 article; tests by Intel, September 2024) — Xeon 3B throughput figures (619 / 1122 tok/s), Xeon 6 vision next-token latency (29 ms), AI-PC test configuration. Vendor frame per §8.1.
13. Community Arc benchmark summary (measurements March 2026, summarised October 2026) — Arc A770 Qwen3-8B/14B OpenVINO INT4 vs llama.cpp SYCL decode rates. Single-source, community frame per §8.2.
14. Independent hands-on comparison, Core Ultra 7 255H / Arc 140T (November 2026) — OpenVINO vs llama.cpp SYCL prefill/decode across context lengths for a 2B model; GenAI FP16 export counter-example. Single-machine frame per §8.2.

**Not relied upon:** search-result snippets for releases after the 2025.4 reference line (2026.x feature announcements such as EAGLE-3 / multi-token-prediction speculative decoding) were seen during research and are mentioned in §3.3 only to bound a negative claim; no dossier assertion rests on them.

---

*Dossier OR-2 — OpenVINO GenAI. Written for the Ollama Research Forge corpus (RuneForgeAI-Ollama-Experiments), for readers engineering an improved Ollama in Go. Clean-room: all prose is original synthesis of the public sources above; no documentation text or code is reproduced beyond short factual labels (class names, property names, flag names, and default values) necessary to identify the mechanisms described.*
