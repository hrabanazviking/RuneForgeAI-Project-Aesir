# OR-2 — MLC-LLM and MLCEngine: The Compile-Anywhere Pole

- **Project:** MLC-LLM (Machine Learning Compilation for Large Language Models); its runtime is **MLCEngine**. The browser sibling is **WebLLM**, covered in §5 of this dossier.
- **Steward / origin:** The MLC community — initiated by members of CMU Catalyst, UW SAMPL, SJTU, OctoML and the wider Apache TVM community, per the project README. Carnegie Mellon University's Catalyst group lists it as one of its research projects.
- **Repositories:** https://github.com/mlc-ai/mlc-llm · https://github.com/mlc-ai/web-llm
- **Documentation:** https://llm.mlc.ai/docs/get_started/introduction.html (docs home: llm.mlc.ai/docs) · WebLLM blog and docs via blog.mlc.ai
- **Licence — verified:** **Apache License 2.0.** Verified three ways on 2026-11-15: the repository carries an Apache-2.0 licence badge linking to its LICENSE file; independent licence audits record the GitHub source as Apache-2.0 / SPDX Apache-2.0; and the MLC Chat app built on it is likewise described as Apache-2.0 per the same repository. Apache TVM, the compiler underneath, is also Apache-2.0. There is no proprietary surround comparable to TensorRT-LLM's: the closed pieces in any given deployment are the platform GPU drivers and vendor libraries MLC code-generates against or dispatches to (CUDA / cuBLAS / CUTLASS on NVIDIA, Metal on Apple, and so on), not MLC-LLM itself. Model weights keep their own licences, as everywhere.
- **Languages:** Python first — model definitions, the compilation pipeline, and the `MLCEngine` / `AsyncMLCEngine` Python API are Python. The portable runtime core underneath is C++ (the TVM runtime plus the engine loop), loaded as a native shared library. Host-language bindings are thin shells over that core: JavaScript / TypeScript for WebLLM, Swift for iOS, Kotlin (over a Java/JNI bridge) for Android, plus a REST server and a chat CLI. Building the Android package additionally needs Rust, but only to cross-compile the Hugging Face tokenizers — a build dependency, not a runtime language.
- **As of:** 2026-11-15. All claims below are tied to sources read on that date; §10 lists them with access dates. Where a claim rests on a secondary summary rather than MLC's own docs or blogs, that is said in place.

**Essence.** MLC-LLM answers a different question from every other runner in this corpus. Ollama and llama.cpp ask: *how do we load one portable file and run it well enough anywhere?* TensorRT-LLM asked: *how fast can this model run on this one NVIDIA GPU if everything is decided in advance?* MLC-LLM asks: *how do we avoid writing the runner N times at all?* Its answer is a compiler. A model is defined once, in Python, lowered through Apache TVM's Relax intermediate representation, and the compiler — not a human kernel team — generates the GPU code for each target: CUDA for NVIDIA, Metal for Apple, Vulkan for AMD / Intel / Steam Deck-class hardware, ROCm for AMD datacentre cards, OpenCL for Android phone GPUs, and WGSL-through-WebGPU plus WebAssembly for the browser. A single C++ engine core, MLCEngine, then runs the compiled artifact everywhere, presenting the same OpenAI-style `chat.completions.create` surface in Python, JavaScript, Swift, Kotlin and over REST. That is the broadest device story in the field by a wide margin, and it is bought with the field's heaviest toolchain: a model does not simply *load* in MLC-LLM, it *compiles* — just-in-time on first run by default, or ahead of time into a per-target model library — and the compiler stays in the dependency graph in a way it never does for a GGUF runtime. §2 and §6 are about exactly what that trade costs, because for Volmarr's cross-platform law it is the most instructive trade in the corpus: MLC-LLM is what maximal portability looks like when portability is the compiler's job rather than the file format's job.

---

## 2. The compilation model

### 2.1 TVM Unity and Relax as the intermediate layer

MLC-LLM is built on **Apache TVM Unity**, the current architectural direction of Apache TVM. In our own summary of the TVM material read for this dossier:

- The central object is the **IRModule**: one container that holds the model's computational graph, the tensor programs that implement its operators, and calls out to external libraries, all together. Everything — importing, optimising, scheduling, building — is a transformation of an IRModule.
- The high-level language inside the IRModule is **Relax**, TVM's successor to its older Relay graph IR. Relax was designed for the things LLM inference does that a classic static graph compiler handles badly: symbolic (dynamic) shapes, because sequence length and batch size are not known until a request arrives; first-class representation of KV-cache-like runtime objects; and cross-level optimisation, where a graph-level decision and a kernel-level schedule are reasoned about in the same system.
- The low-level language is **TensorIR**: a schedule separates *what* an operator computes from *how* it is tiled, ordered and mapped onto threads for a specific device. Change the schedule and the same definition retargets; the algorithm does not change.
- Scheduling help comes from two places. **MetaSchedule** is TVM's automated search: it proposes candidate schedules, measures them on the real target hardware, and keeps the winners, guided by a learned cost model. Newer GPU flows also use TVM's lightweight default-schedule path (DLight in the TVM tutorials read). Either way, the tuning knowledge lives in the compiler's search, not in a hand-maintained kernel table.
- The workflow is explicitly **Python-first and interactive**: model architectures are written in a PyTorch-like Relax frontend (`tvm.relax.frontend.nn`), inspected as TVMScript, transformed pass by pass, and only then built for a target. MLC-LLM's own model zoo — Llama, Mistral / Mixtral, Phi, Qwen, Gemma and many more families — is written this way, once per architecture, not once per architecture per backend.

That last point is the whole bet. In ggml, portability is achieved by a human writing a kernel family per backend and a runtime that picks among them. In MLC-LLM, portability is achieved by a human writing the model *once* and a compiler deriving the per-backend kernels. The engineering effort does not disappear; it moves from kernel authorship into compiler infrastructure — which is why the project's health is inseparable from TVM's health (§6.2).

### 2.2 The three-stage pipeline, as documented

MLC-LLM's own introduction describes the flow every deployment follows, whether the user sees it or not:

1. **Weight conversion.** A Hugging Face checkpoint is converted into MLC format with `gen_config` (producing the model's MLC configuration, including its conversation template and chosen quantization) followed by `convert_weight`. Quantization is applied *here*, to the weights themselves (§4). The converted weights are a directory of shards plus config — they are backend-independent. The same converted weights feed a CUDA build and a WebGPU build.
2. **Model compilation.** `compile` takes that configuration and a `--device` target and produces a **model library**: a native artifact for the target — a shared library (`.so`) on Linux, a dynamic library (`.dylib`) on macOS, a `.dll` on Windows, a `.wasm` module for the web, a `.tar` bundle for iPhone / Android packaging. This is where TVM lowers the Relax program, generates or selects kernels, applies dynamic-shape-aware memory planning, and — on CUDA — can rewrite the execution for CUDA Graph capture. The docs describe two optimisation levels in general use, with the higher level characterised as the more extreme optimisation setting.
3. **Runtime.** MLCEngine loads the model library plus the converted weights and serves requests. The library contains the *code*; the weights stay a separate, loadable payload. That separation matters (§2.4): a fine-tune of a supported architecture can reuse an existing library and ship only new weights.

Compilation happens in one of two modes:

- **Just-in-time (JIT), the default for desktop chat / Python / serve.** On first launch the engine downloads pre-converted weights (the `HF://mlc-ai/...-MLC` identifiers in every example), compiles the library for the local GPU, caches both weights and library on disk, and only then opens the chat. The docs put the first-run wait for the introductory 8B example at roughly one to two minutes; independent practitioner write-ups report far longer compiles — tens of minutes — for from-scratch builds of 3B-class models on some targets. Both can be true: JIT-compiling a cached, well-trodden configuration on a fast desktop is a different experience from a cold cross-compile for a phone. The honest summary is that first-run cost is *minutes, variable, and target-dependent*, and zero thereafter because of the cache.
- **Ahead-of-time (AOT), the required mode for web and mobile.** The developer compiles explicitly, ships the library inside the app or hosts it for download, and the end device never runs the compiler at all. This is also the mode the docs recommend for *reduced-dependency* deployment generally: ship the library, drop the toolchain.

### 2.3 What "compile" means here — against TensorRT-LLM and against ggml

Three runners in this corpus use the word very differently, and the dossier was asked to keep them distinct:

| | MLC-LLM | TensorRT-LLM (classic line; see its dossier for the current PyTorch-backend shift) | ggml / llama.cpp (Ollama's engine) |
|---|---|---|---|
| What is compiled | The model's operator graph, lowered per target into a model library of generated / selected kernels | The whole model into a serialised engine for one GPU architecture, one precision, one shape envelope | Nothing model-specific. A general runtime binary is compiled once, by its developers |
| When | JIT on first run (desktop) or AOT by the distributor (mobile / web) | Explicit build step before any serving | At software build time only; a model is *loaded*, never compiled |
| Artifact keyed to | Model architecture + quantization + target backend (device class) | Model + weights + precision + GPU architecture + parallelism + shape envelope | Nothing — one GGUF file is the artifact, portable across all supported hardware |
| Shape handling | Symbolic shapes in Relax; memory planned dynamically-shape-aware at compile time; requests of varying length run on one library | Shapes outside the built envelope are refused; the envelope is a compile-time ceiling | Shapes are a runtime matter entirely |
| Cost of a new model | Convert weights; compile a library per target you ship | Convert checkpoint; build an engine per configuration you serve | Drop in a file |
| Cost of a new device class | In principle: a TVM code-generation target. In practice: target bring-up, tuning and packaging (§7) | Not applicable — one vendor | A human-written backend, once, shared by all models |

Two nuances keep this honest. First, MLC-LLM's library is **less rigid than a classic TensorRT engine**: it is not keyed to one set of weights (fine-tunes reuse it), not keyed to a maximum-batch / maximum-length envelope in the same hard way (symbolic shapes are the point of Relax), and not keyed to a single GPU SKU — a CUDA library serves a range of NVIDIA cards, a Vulkan library a range of Vulkan devices. Second, it is **far more rigid than a GGUF**: it *is* keyed to architecture, quantization and backend, so the artifact matrix in §2.4 is real. MLC-LLM sits between the two poles — compilation as a *per-target code-generation* step, not compilation as a *per-deployment freezing* step. That middle position is precisely what makes it interesting for a Go runner (§9).

### 2.4 The model-library / prebuilt-packages distribution model — and its friction

Because end users cannot reasonably compile for phones and browsers, MLC-LLM is, in practice, a **prebuilt-artifact ecosystem**:

- The MLC organisation publishes pre-converted, pre-quantized weights on Hugging Face under the `mlc-ai` account (the `...-q4f16_1-MLC` naming is ubiquitous). The desktop JIT path downloads these and compiles only the library locally.
- WebLLM publishes a **prebuilt model list**: a curated registry of model records, each pointing at hosted converted weights plus a hosted model library (for the web, the WASM library), so a web page can name a model identifier and fetch both halves. Multiple weight variants of one architecture can share a single library.
- The mobile apps (MLC Chat for iOS and Android) are built by a `package` step: a package-configuration file lists the models to include, each model is compiled into its binary library, and the runtime plus tokenizers are bundled alongside. The Android documentation is explicit that a physical phone is required — there is no meaningful emulator path, because the app needs a real mobile GPU — and that the demo package referenced in the docs was built for a specific flagship (a Samsung S23 with a Snapdragon 8 Gen 2) with a named NDK version. That specificity is typical, not exceptional.
- The Python side is distributed as **nightly, pre-release wheels** from the project's own wheel index, split by accelerator stack: separate packages for CPU, for specific CUDA generations, and for specific ROCm generations, with Vulkan support carried inside the Linux packages. Installation documentation recommends an isolated conda environment. There is no single "install MLC-LLM" artifact; there is a matrix, and picking the wrong cell is a common first failure.

The friction this creates is structural, and worth naming plainly:

1. **Combinatorial surface.** Artifacts multiply across (model architecture × quantization × target backend ×, for wheels, CUDA/ROCm version). Curation, not compilation, becomes the bottleneck: the prebuilt lists cover the popular families well and everything else not at all, and a model outside the list means entering the convert-and-compile pipeline yourself.
2. **Two-artifact coherence.** Weights and library must match — architecture, quantization and config version together. A mismatched pair does not degrade; it fails, and (per practitioner reports) sometimes fails with opaque TVM-side errors rather than a clean "wrong library" message.
3. **First-run latency as a user experience.** JIT hides the pipeline but not its cost. A chat command that compiles for minutes before the first token is a fundamentally different first impression from Ollama's download-and-run, and it recurs whenever the cache is invalidated by a version change.
4. **Nightly-first distribution.** A project whose recommended install is a nightly wheel is telling you its release cadence honestly: the ground moves. §7.3 takes up what that means for anyone building *on* MLC-LLM rather than merely using it.

---

## 3. Runtime: MLCEngine

### 3.1 One core, many shells

MLCEngine, released as the project's centrepiece in June 2024, is described by its authors as a single engine for both cloud serving and local deployment, with full OpenAI API support in both worlds. The architecture, in our words:

- A **portable C++ engine core** owns the serving loop: request admission, batching, KV-cache management, sampling, grammar-constrained generation, and dispatch into the compiled model library.
- **Language shells** wrap the core without reimplementing it. Python gets `MLCEngine` (synchronous, single-stream by design) and `AsyncMLCEngine` (asynchronous, the documented recommendation for concurrent requests). JavaScript gets the same engine class inside WebLLM, including a service-worker variant that keeps the engine alive across page navigations. Swift (iOS) and Kotlin (Android) mirror the Python API's shape, using their languages' native async-streaming idioms. The REST server exposes the same surface over HTTP at `/v1/chat/completions`.
- The **API contract is the OpenAI chat-completions shape everywhere** — the same `engine.chat.completions.create` call, with streaming, in every language. The June 2024 launch post stresses this was a deliberate design act: one development experience, ported, rather than five similar ones.
- **Structured generation lives in the core, not in any shell.** The engine maintains a grammar state machine per request and constrains decoding to valid JSON, either generally or against a caller-supplied JSON schema. Because it is core functionality, JSON mode works identically on a server, a phone and in the browser — an early, concrete payoff of the one-engine design, and a pattern §9 returns to.

### 3.2 Modes: one engine, three resource postures

The engine constructors and the server accept a **mode** — `local`, `interactive`, or `server` (default `local`) — which the Python documentation defines precisely: the mode presets request concurrency and KV-cache token capacity, and therefore GPU memory footprint.

- `interactive`: concurrency of one, small KV capacity — a single conversation on a personal device.
- `local`: low concurrency, low KV capacity — personal use that may overlap a few requests, tuned to leave memory alone.
- `server`: concurrency and KV capacity pushed to what the GPU can hold — a dedicated serving card.

This is a small feature with a large idea inside it: *the same binary admits it is running in different worlds by changing its resource posture, not its code.* A personal runner needs exactly this honesty — a laptop co-resident with the user's desktop is not a small datacentre — and MLC-LLM's three named postures are the cleanest statement of it in the corpus (§9.2).

### 3.3 Batching: continuous, in the server posture

The launch material lists **continuous batching** among the engine's core serving techniques, alongside speculative decoding, and the October 2024 performance follow-up analyses it in the now-standard terms: requests are batched together for processing, finished work leaves and new work joins without waiting for a static batch to drain, and throughput rises with concurrency at the cost of per-request latency. The synchronous Python engine explicitly does *not* batch (documented); batching is the async engine's and the server's behaviour.

Two implementation details from the October 2024 write-up deserve recording because they are compiler-specific advantages, not generic serving lore:

- **Kernel dispatch by batch shape.** For large-concurrency steps the engine dispatches matrix multiplication to vendor libraries (cuBLAS / CUTLASS on CUDA); for concurrency of one or a few requests it uses compiler-generated matrix-*vector* kernels, which the authors report as several times faster than the library kernel for that shape. A runtime with fixed kernels cannot make this swap per step; a compiler-backed engine can generate both and choose.
- **Overhead discipline.** The engine loop runs on a dedicated thread, with tokenization, HTTP and other frontend work on other threads, so CPU work overlaps GPU computation; the authors put residual CPU overhead at roughly 3% of batch decoding time in their measurements. CUDA Graph capture — enabled by a compiler rewrite pass over the statically memory-planned graph — is credited with up to about a tenth of latency in multi-GPU settings.

Tensor parallelism is supported out of the box (a shard-count override at config, engine or server level), demonstrated at launch on two RTX 4090s under CUDA and on two AMD 7900 XTX cards under ROCm — a pairing no NVIDIA-only engine can show.

### 3.4 KV cache: paged management — verified, with limits on detail

The dossier was asked to verify the KV-cache design rather than assume it. What the primary sources read actually establish:

- The June 2024 MLCEngine launch post names the engine's memory techniques explicitly: **paged KV management, common prefix caching, and cascade inference**, with attention computed via the FlashInfer library on CUDA and via compiler code generation on other platforms. Paged management and prefix caching are therefore *verified as shipped engine features*, in the project's own words, at launch.
- The FlashInfer paper (MLSys 2025; covered in depth elsewhere in this corpus and only referenced here) independently confirms the integration from the other side: FlashInfer is integrated into MLC-Engine, and its composable KV-cache formats were implemented *within* MLCEngine under a prefix-caching configuration, evaluated on shared-prefix workloads. In plain terms: the KV cache is stored in blocks that attention kernels can address through page-table-like structures, and blocks belonging to a shared prefix can be represented once, at a coarser granularity, rather than duplicated per request.
- **What could not be verified from the sources read:** the exact page/block size, the eviction policy under memory pressure, whether prefix caching is keyed by token-prefix hashing or by an explicit radix structure, and whether any of this is active in the `local` / `interactive` modes or is a server-mode behaviour. The public documentation read describes modes in terms of KV *capacity*, not KV *policy*. This dossier therefore records paged management + prefix caching as present and FlashInfer-backed on CUDA, and marks the finer mechanics **unverified** rather than importing vLLM's design by analogy. The designs are cousins — both descend from the PagedAttention line of work — but cousinhood is not identity, and the corpus's standard is to say so.

### 3.5 How one engine serves desktop, phone and browser

The trick is that almost nothing changes except the compiled library and the shell:

- **Desktop / server:** the Python package or REST server JIT-compiles (or loads a prebuilt) library for CUDA / ROCm / Vulkan / Metal and runs the full engine, modes and batching included.
- **Phone:** the app distributor AOT-compiles the library (Metal for iOS, OpenCL for Android in the documented mobile paths), packages it with the C++ runtime and tokenizer, and the Swift / Kotlin shell presents the same chat-completions calls. The engine runs in its low-concurrency posture because the device demands it, not because it is a different engine.
- **Browser:** WebLLM (§5) is, in the project's own framing, a *specialised web backend of MLCEngine* — the same engine concept compiled to WASM + WebGPU, with a JavaScript shell and a worker-thread boundary the native shells do not need.

The honest caveat is that "same engine" means *same core code and same API*, not *same feature availability at the same scale*: continuous batching across dozens of requests is a server-posture behaviour, speculative decoding was characterised on H100 servers, and a phone running one conversation is exercising a thin slice of the core. The unification is real at the level of code and contract; the capabilities scale with the posture. For a personal runner, that is the right kind of unification to copy (§9.1).

---

## 4. Quantization

### 4.1 The naming scheme is the design

MLC-LLM's quantization codes are the most self-documenting in the corpus. Per the project's quantization documentation, a weight-only code has the form **`qAfB(_id)`**:

- `A` — bits used to store the **weights** (0 meaning "not quantized — stored at the activation precision").
- `fB` — the floating-point precision of **activations / computation**, B bits.
- `_id` — an identifier distinguishing algorithms that share the same bit-widths (grouping scheme, symmetry, or an imported method such as AWQ).

So `q4f16_1` reads directly as: 4-bit weights, 16-bit float compute, algorithm variant 1 — which the docs identify as the standard **group quantization** (weights divided into groups, each group carrying its own scale, in the lineage of the 4-bit inference-scaling and LUT-GEMM work the docs cite as the default algorithm's basis). And `q0f16` reads as: no weight quantization at all, plain FP16 — the reference configuration. The name tells a user the two numbers that determine file size and the one that determines arithmetic, with no marketing suffixes. Compare GGUF's `Q4_K_M`, where the letter grades encode *which layers got extra bits* — more expressive about quality policy, less transparent about the basic contract. Both are defensible; MLC's is easier to reason about mechanically, which suits a compiler ecosystem where the code is an input to code generation, not just a label.

### 4.2 The documented menu (as of the docs read, 2026-11-15)

Weight-only:

- `q0f16` — FP16, unquantized. `q0f32` — FP32, unquantized.
- `q3f16_1` — 3-bit group-quantized weights, FP16 compute.
- `q4f16_1` — 4-bit group quantization, FP16 compute. The production default across the prebuilt ecosystem; nearly every `mlc-ai` Hugging Face identifier and every WebLLM prebuilt record uses it.
- `q4f32_1` — 4-bit weights, FP32 compute. Exists chiefly for targets without fast FP16 shader support — WebLLM's fallback for WebGPU adapters lacking the `shader-f16` feature is the concrete case (§5.3).
- `q4f16_ft` — a 4-bit variant in the FasterTransformer weight layout, named in the introductory documentation.
- `q4f16_awq` — **AWQ** (activation-aware weight quantization) in MLC form. The quantization documentation flags it explicitly as **not stable**, and practitioner sources repeat the warning. AWQ support therefore exists, is first-class enough to have its own code, and is *not* presented by the project as production-ready — a nuance a summary that merely lists "AWQ: yes" would miss.

Weight-and-activation:

- FP8 modes `e4m3_e4m3_f16` and `e5m2_e5m2_f16`, **CUDA only**: both weights and activations are carried in FP8 (in the two standard exponent/mantissa splits), layer outputs are produced in FP16 and requantized. These modes need a **calibration** pass: a specially compiled calibration model is run over a dataset (ShareGPT is the documented example) to collect activation statistics and fix the quantization parameters in the weights file in place, after which the inference model is compiled. Calibration is a workflow, not a flag — three distinct build/run phases in the docs.

### 4.3 Quantization × compilation: the interaction that defines MLC-LLM

In a GGUF runtime, quantization is a property of a *file*; the same runtime loads Q4, Q5 or Q8 files interchangeably, and kernels dequantize on the fly. In MLC-LLM, quantization is a property of the **build**:

1. The quantization choice is fixed at `gen_config` time and written into the model configuration.
2. `convert_weight` physically rewrites the weights into the quantized, grouped, backend-ready layout.
3. `compile` generates kernels *for that quantization* — the dequantization arithmetic, group sizes and compute dtype are baked into the generated code and its memory plan.

Consequences, stated plainly:

- **Changing quantization means reconverting and recompiling.** There is no runtime flag that turns a `q4f16_1` deployment into a `q3f16_1` one. Each (model × quantization) pair that a distributor ships is its own converted weight set *and* its own library per target.
- **The compiler can optimise what a runtime must keep general.** Because the quant format is known at code-generation time, dequantization can be fused into the generated matrix kernels with the exact group structure, rather than dispatched through a generic per-format kernel table. This is the quant-side version of the §3.3 dispatch advantage.
- **The ecosystem narrows.** The practical quantization menu for a prebuilt model is whatever the `mlc-ai` organisation (or another distributor) chose to convert — overwhelmingly `q4f16_1`, with `q4f32_1` where FP16 shaders are unavailable. GGUF's long tail of per-model quant variants has no equivalent here, because every variant costs a build, not just a file conversion.

---

## 5. WebLLM: the browser as a first-class target

*WebLLM is a separate repository and npm package (`@mlc-ai/web-llm`), but it is a backend of MLCEngine, not an independent engine, and is therefore covered here as commissioned.*

### 5.1 What it is

WebLLM, launched June 2024 with a peer-reviewed paper following (arXiv:2412.15803), is a JavaScript framework that runs LLM inference **entirely inside a web page**: no server, no API key, no installation. Its authors summarise it as fast (native GPU acceleration through the browser), private (100% client-side computation), and convenient (zero environment setup). It exposes the same OpenAI-style API as every other MLCEngine shell — streaming, logit controls, JSON mode (general and schema-constrained, implemented in the WASM portion of the library), and preliminary function-calling support at launch — so a web application written against a cloud endpoint can, in the intended happy path, swap the endpoint for a local engine object.

### 5.2 How it works

- **Two compiled components per model**, produced by the ordinary MLC-LLM pipeline at *compile time* (by the model distributor, never in the browser): the converted/quantized weights, and a **model library in WASM form**. Inside that library, the GPU kernels are WGSL shaders (WebGPU's shading language) for prefill and decode, and the non-kernel logic — tokenization support, the grammar machinery for JSON mode — is WebAssembly code.
- **At run time**, the browser translates WGSL to whatever the native GPU speaks (Metal, Direct3D, Vulkan), so one WebGPU library serves all GPU vendors — WebGPU itself acts as a second portability layer underneath TVM's.
- **Execution is kept off the UI thread.** The engine runs inside a Web Worker or Service Worker; the page-side object (`ServiceWorkerMLCEngine` and its plain-worker counterpart) forwards OpenAI-style requests by message-passing and streams tokens back. The service-worker variant is designed to persist across pages and reloads, so the model is not reloaded onto the GPU for every navigation. A Chrome-extension variant applies the same pattern.
- **Weights and library are downloaded once and cached locally** (the launch post states this directly). Repository-level summaries of WebLLM's cache implementation describe two browser storage backends — the Cache API by default and an IndexedDB-backed cache selected by an application-configuration flag — holding weights, tokenizer files and the WASM library. This dossier treats the two-backend detail as *secondary-source* (a code-derived wiki summary, read 2026-11-15), while the download-once-and-cache behaviour itself is primary-source.

### 5.3 The privacy / local story — and its honest limits

The privacy claim is strong because it is architectural, not promissory: after the initial download of weights and library from a model host, inference involves no network at all. Prompts never leave the device because there is nowhere in the design for them to go. For embedding a capable assistant into a web application whose users cannot be asked to trust (or pay for) a backend, that is a genuinely new capability, and WebLLM remains the reference implementation of it.

The limits are equally architectural, and the dossier records them as documented behaviour, not as criticism:

1. **The download is the product's weight.** A 1.7B model at 4-bit is roughly a gigabyte; a 4B roughly 2.3 GB (practitioner-measured figures for Qwen3 builds, read 2026-11-15). First visit means asking a user to fetch that, on their bandwidth, before any value is shown. Prebuilt guidance for web deployment advises against 7B-and-up models in production for exactly this reason, independent of speed.
2. **Browser storage is a quota, not a disk.** Cached models live under the origin's browser storage quota, which is a browser-decided share of disk and is evictable under storage pressure in the default (best-effort) mode. A "downloaded model" in a browser is a cache entry with good manners, not an installed file; applications must handle its disappearance.
3. **WebGPU maturity is the gate.** WebGPU shipped first and most completely in Chromium (Chrome / Edge 113+). Safari added support in its 18 generation; Firefox's support lagged behind a flag for an extended period. A WebLLM deployment's real device matrix is therefore *the intersection* of "has a GPU" with "has a current Chromium-class browser" — wide, but not the universality the browser platform promises in the abstract. Feature detection is mandatory, documented practice: check for an adapter, and check for the `shader-f16` feature to decide between `q4f16` and `q4f32` builds.
4. **GPU memory inside a tab is capped and shared.** The browser's per-context GPU limits, not the card's specification, bound model size and KV cache. The practical prebuilt range tops out at small models for broad deployment; larger records exist in the registry but assume desktop-class hardware.
5. **Performance tax is real but bounded** — see §8.3: roughly four-fifths of native on the same machine, per the project's own measurements. The tax buys zero-install reach.

### 5.4 Model support in the browser

WebLLM's prebuilt registry (accessed via its `prebuiltAppConfig` model list) covers, per the repository README read for this dossier, the Llama 3 / Llama 2 families and Hermes fine-tunes, Phi 3 / 2 / 1.5, Gemma 2B-class models, Mistral 7B-class models and fine-tunes, and the Qwen2 family from 0.5B to 7B, with later families (Llama 3.2, Qwen 2.5 / Qwen3, SmolLM-class models) appearing in the 2026-era registry summaries. Custom models follow the standard rule of the whole ecosystem: convert your weights with MLC-LLM, reuse the architecture's existing WASM library if one exists, compile your own only if the architecture itself is new. The browser inherits both the breadth and the curation bottleneck of §2.4, unchanged.

---

## 6. Device breadth audit

### 6.1 The supported matrix, as documented

The README support matrix (as reproduced in repository-derived summaries read 2026-11-15) and the deployment documentation together give:

| Environment | NVIDIA | AMD | Apple | Intel | Mobile / other GPUs |
|---|---|---|---|---|---|
| Linux / Windows (desktop & server) | CUDA, Vulkan | ROCm, Vulkan | — | Vulkan | — |
| macOS | — | Metal (discrete GPUs) | Metal (Apple Silicon) | Metal (integrated GPUs) | — |
| Web browser | WebGPU + WASM | WebGPU + WASM | WebGPU + WASM | WebGPU + WASM | WebGPU + WASM (any WebGPU GPU) |
| iOS / iPadOS | — | — | Metal (A-series and M-series) | — | — |
| Android | — | — | — | — | OpenCL (Qualcomm Adreno, Arm Mali) |

Plus: a CPU path exists (CPU wheels are published; CPU-only operation is documented as possible and, as everywhere, slower), and tensor-parallel multi-GPU serving is supported on CUDA and ROCm.

Read that table against the rest of the corpus. No other dossier has an Android row, an iOS row, or a browser row. TensorRT-LLM's matrix has one vendor; vLLM's is datacentre-first with community edges; llama.cpp is the only rival in breadth, and it reaches phones as a *library port*, not as a packaged engine with phone-native shells. MLC-LLM is also the only runner here where **AMD is a first-class citizen twice over** — ROCm for compute-style deployment and Vulkan for everything else — and where exotic targets are demonstrated rather than merely plausible: the June 2024 launch post's validated list includes an RTX 4090, a Jetson Orin, a T4 in Colab, a 7900 XTX, a **Steam Deck** (running an 8B model through Vulkan precisely because its driver support is limited), and an **Orange Pi** single-board computer. For Volmarr's standing cross-platform law — Windows, macOS, Linux x86-64 *and* Linux ARM — MLC-LLM is the one project in the field whose supported matrix already contains every cell of that law, plus the phones and the browser besides. Linux ARM is not a porting project here; it is a demonstrated target class (ARM mobile GPUs via OpenCL, ARM boards, Apple Silicon via Metal).

### 6.2 The honest cost of breadth

Breadth this wide is not free, and the sources read support a fair characterisation of its three costs:

1. **Per-target tuning and bring-up.** A TVM code-generation target existing is not the same as it performing. Each backend needs its schedules validated, its packaging built, its quirks absorbed (the Android OpenCL path is documented in secondary reviews as working well on some vendors' GPUs and unreliably on others — Google Pixel devices with limited OpenCL support are the named example). The TapML research line from the same community — a testing/debugging methodology paper reporting the deployment of 105 models across 27 architectures on 5 emerging platforms over two years as MLC-LLM's default development method — is best read as evidence of how much *process* emerging-platform support consumes even with a compiler doing the code generation.
2. **Package sprawl.** §2.4's matrix is the user-visible symptom: nightly wheels per CUDA generation and per ROCm generation, separate mobile packaging flows per OS (with their own SDK, NDK and toolchain requirements — the Android docs require a named NDK and JDK ≥ 17; the iOS flow requires Apple's Metal toolchain components), and per-target model libraries for every model a distributor ships. Every cell is small; the grid is large, and someone must build, test and host all of it.
3. **Version churn and the TVM dependency.** This is the known community theme the dossier was asked to verify, and it verifies — with a precise shape:
   - MLC-LLM does not depend on a stable, released TVM in the way a library depends on, say, a released compiler. It carries TVM as a **submodule** (`3rdparty/tvm`) tracking the Unity development line, and its own distribution is **nightly-first**. The user is therefore always on a coordinated pair of moving codebases.
   - TVM itself has been through a generational transition (Relay → Relax → Unity) whose seams show in the public record: TVM forum threads show learners and MLC-LLM users hitting version-mismatch failures — wheels built for one Python, a `USE_LLVM` build flag silently off producing an opaque serialisation assertion deep in a model build, tutorials referencing the retired IR. These are 2023–2025 forum artefacts, and this dossier cites them as *evidence of a recurring failure class* (build-configuration and version-skew errors surfacing far from their cause), not as a claim about any specific current version.
   - Building from source is correspondingly heavy — secondary guides put a full source build at roughly half an hour to an hour — which is why the nightly wheels exist, which is why the wheel matrix exists. The sprawl and the churn are the same cost seen from two sides.
   
   Fairness requires the other half: this is the *normal* price of riding a research-grade compiler stack that is itself still consolidating, the MLC team absorbs most of it on users' behalf via the prebuilt ecosystem, and the alternative — hand-written kernels per backend — has its own, larger, permanent cost that llama.cpp's contributor base pays instead. The finding is not "TVM is painful, avoid"; it is "**MLC-LLM's portability is rented from a compiler project whose stability curve it does not control**", and any adopter inherits that exposure.

---

## 7. Performance character

*All numbers below carry their hardware and source. MLC-LLM's own figures are vendor-reported by the project team; independent figures are labelled as such.*

### 7.1 Server, on NVIDIA datacentre hardware

The project's October 2024 characterisation (CMU / MLC blog) is the most careful public benchmark the team has published:

- **Setup:** Llama 3 8B in FP16 on one NVIDIA H100 SXM; Llama 3 70B in FP8 on four H100 SXM (tensor-parallel); ShareGPT-derived requests, 500 requests per run, fixed concurrency swept from 1 to 64; compared against SGLang v0.3.1.post2 and vLLM v0.6.1.post2 of the same period.
- **Headline behaviour:** on the *low-latency* portion of the throughput–latency curve — the region where each user still receives on the order of 100 tokens/second — MLCEngine matched or led the comparison engines at several thresholds. Concretely for the 8B case: holding roughly 100 tok/s per user, the engine sustained about 30 concurrent users for roughly 3,000 tok/s aggregate output on the single H100.
- **Speculative decoding:** with an 8B FP8 draft model proposing for the 70B FP8 target (draft length 3), latency in the low-latency regime fell by **more than 25%** in the team's summary, with the benefit shrinking as concurrency pushes the system from memory-bound toward compute-bound — the expected shape.
- **Mechanisms credited:** FlashInfer attention; per-shape kernel dispatch (§3.3); static, dynamic-shape-aware memory planning eliminating runtime allocation; CUDA Graphs (up to ~10% multi-GPU latency); the dedicated engine thread keeping CPU overhead near 3% of decode time.

Read fairly, this establishes MLCEngine as a *credible* server engine in the low-latency regime on H100s in late 2024 — not a toy that also runs on servers. It does not establish datacentre supremacy: the comparison is the team's own, on versions now superseded on all sides, and the framing deliberately selects the latency-sensitive region where a compiler engine's per-shape kernels shine, rather than the maximum-throughput region where vLLM and SGLang have historically been strongest.

### 7.2 Local and Apple hardware

- An independent comparative study of local runtimes on Apple Silicon (arXiv:2511.05502; Mac Studio, M2 Ultra with 192 GB unified memory; Qwen 2.5 family; prompts from hundreds to ~100k tokens) found, in its own summary: MLX achieved the highest sustained generation throughput; **MLC-LLM delivered consistently lower time-to-first-token at moderate prompt sizes and the strongest out-of-the-box inference feature set** (it credits MLC-LLM with paged KV caching, AWQ/GPTQ-family quantization support, built-in REST serving and cross-platform SDKs); llama.cpp was most efficient for lightweight single-stream use; Ollama prioritised ergonomics and lagged on throughput and TTFT. That is a flattering-but-bounded verdict from outside the project: not the fastest on Apple's own turf (Apple's own MLX is), but the most complete, and quickest to first token in its tested band.
- Practitioner reports on phones (secondary, single-device, treat as indicative): a Llama 3.2 3B model at `q4f16_1` on an iPhone 15 Pro reported at roughly 25 tok/s prefill and 18 tok/s decode by one mobile-deployment write-up. Numbers in this class — high-teens tokens per second for 3B models on flagship phones — recur across the mobile sources read and are consistent with the hardware's memory bandwidth; they are not project-verified benchmarks.

### 7.3 The browser tax, measured

WebLLM's own measurements are the cleanest "cost of a portability layer" numbers in the corpus:

- The June 2024 launch post compares WebGPU (WebLLM) against native Metal (MLC-LLM), both compiled by the same pipeline, on an **M3 Max MacBook Pro**, 4-bit models, 64 prefill tokens and 128 decode tokens: WebGPU preserved **up to 85%** of native decode performance.
- The WebLLM paper's evaluation, as summarised in secondary coverage read for this dossier, puts the figure at **up to 80%** of native throughput on the same device class, with absolute numbers of roughly **41 tok/s decoding Llama 3.1 8B** and roughly **71 tok/s on Phi-3.5 mini**, both 4-bit, on the M3 Max. The two percentages (85% launch-post peak vs 80% paper headline) come from different runs and model mixes; this dossier reports both rather than averaging them into a false precision.

### 7.4 The general pattern

Synthesising §7.1–§7.3: **MLC-LLM is competitive nearly everywhere and peak almost nowhere.** On NVIDIA datacentre cards it is a strong low-latency engine but not the throughput champion; on Apple Silicon it loses raw throughput to Apple's own MLX while winning on features and TTFT; in the browser it pays a ~15–20% tax to WebGPU and has no rival at all; on Android and exotic ARM hardware it is frequently the *only* compiled option. Its performance story is the shape of its mission: the metric it optimises is not tokens-per-second on the best hardware, but *acceptable tokens-per-second on all the hardware, from one codebase*. A reader choosing a server engine for H100s should read the vLLM, SGLang and TensorRT-LLM dossiers first. A reader choosing an engine that must also ship on a phone, a Pi-class board and a web page has exactly one dossier that fits, and it is this one.

---

## 8. Strengths and weaknesses

### Strengths

1. **Breadth without reimplementation.** One model definition, one engine core, one API contract — desktop, server, iOS, Android, browser. Nothing else in the corpus is close (§6.1).
2. **A genuinely unified engine, not a family of ports.** Continuous batching, paged KV with prefix caching, speculative decoding, structured JSON generation and tensor parallelism were built once, in the core, and the June 2024 launch explicitly frames cross-pollination (server techniques reaching local deployments) as the design goal achieved.
3. **Compiler leverage where it actually pays.** Per-shape kernel selection (library GEMM vs generated GEMV), fused dequantization for the exact quant format, static memory planning, CUDA Graph capture — optimisations that require knowing the model at build time, obtained without TensorRT-style per-deployment engine freezing (§2.3).
4. **AMD and non-NVIDIA dignity.** ROCm *and* Vulkan paths, demonstrated multi-GPU ROCm serving, Intel via Vulkan, Mali and Adreno via OpenCL. For heterogeneous fleets this is the only engine whose non-NVIDIA support is architectural rather than aspirational.
5. **The browser tier exists and is good.** WebLLM's ~80–85%-of-native, fully private, zero-install inference is a capability no other project in the corpus offers in any form.
6. **Openness.** Apache-2.0 throughout its own stack, public benchmarks with setups described, peer-reviewed systems papers behind the web engine and its attention library.
7. **Self-describing quantization names** (§4.1) and a small, legible configuration surface (three engine modes, one device flag) relative to the power underneath.

### Weaknesses

1. **The compiler is a runtime dependency in practice.** Even JIT users pay compile-on-first-run; distributors pay it per target; everyone inherits TVM version coupling (§6.2). This is the project's foundational cost and it touches every other weakness below.
2. **Artifact matrix and curation bottleneck.** Prebuilt coverage is excellent for popular families and absent elsewhere; stepping off the prebuilt list means operating a compiler pipeline, not downloading a file (§2.4). The GGUF ecosystem's long tail has no counterpart.
3. **Nightly-first distribution.** Recommended installs are pre-release nightly wheels split by CUDA/ROCm generation, in a conda environment. For a personal runner whose entire value proposition is "it just runs", this is the anti-pattern, faithfully documented.
4. **Opaque failure surface.** When builds fail, they tend to fail inside TVM — configuration and version-skew errors surfacing as deep assertions (§6.2). Debugging requires compiler literacy that running a model should not require.
5. **Quantization menu is narrow in practice and partly unstable in promise.** The shipped ecosystem is essentially `q4f16_1` (plus `q4f32_1` where shaders demand it); AWQ is present but flagged not stable by the project itself; FP8 is CUDA-only and calibration-gated (§4.2).
6. **Peak performance is someone else's.** On the hardware each specialist engine targets, the specialist usually wins (§7.4). MLC-LLM's buyer is purchasing reach, and should know that is the purchase.
7. **Documentation and versioning drift.** The docs tree read for this dossier still carries a 0.1.0 version label while describing the current engine; key serving mechanics (KV policy details, §3.4) are asserted in launch material but not specified in the reference docs. A fast-moving research codebase shows through its documentation.

---

## 9. Ideas to steal for a Go runner

*Context for this section: Yrsa is engineering an improved Ollama in Go, under Volmarr's standing cross-platform law (Windows / macOS / Linux x86-64 and Linux ARM). Each idea states the gain and the cost or risk, as commissioned. "Steal" means adopt the design idea in our own words and code — clean-room throughout, as with the whole corpus.*

### 9.1 One engine core, thin per-platform shells — the cross-platform law in runner form

**The idea.** MLCEngine's deepest decision is not the compiler; it is the *shape*: a single core owning batching, KV, sampling and grammar, wrapped by shells so thin they mostly translate idioms (async streams in Swift, workers in JavaScript), all presenting one OpenAI-shaped contract.

**Gain for a Go runner.** Go is arguably better positioned for this than the C++/Python split MLC-LLM lives with: one Go core compiles natively to every target in Volmarr's law from a single codebase, with the platform variation isolated in small build-tagged backend drivers (Metal, CUDA, Vulkan, CPU/ARM) behind one internal interface. The contract-first discipline — every shell, including the CLI and the HTTP server, calling the *same* `chat.completions`-shaped internal API — prevents the classic personal-runner rot where the CLI, the server and the app slowly become three engines.

**Cost / risk.** The discipline is the cost: every feature must be designed core-first and shell-second, which is slower per feature than hacking it into the frontend that needs it. And a single core means a single core's bugs ship everywhere at once. Mitigation is process, not architecture: the core gets the tests; the shells get smoke tests.

### 9.2 Compile-at-install, bounded to kernel selection — not whole-graph artifacts

**The idea, adapted.** MLC-LLM proves that *knowing the model and the device together* unlocks real wins (per-shape dispatch, fused dequantization, static memory planning). It also proves that materialising that knowledge as a per-(model × quant × device) compiled library creates the artifact matrix that dominates its operational cost. The steal is the knowledge without the artifact: at **model-install time** (or first load), a Go runner can probe the actual device, select and cache the best *pre-existing* kernels for that device class and quant format, record the choice in a small sidecar manifest, and plan KV/workspace memory against the probed budget — a bounded, minutes-free, seconds-scale "compilation" whose output is a selection record, not a binary.

**Gain.** Most of the practical benefit MLC-LLM gets from compilation on personal hardware — right kernel for the shape, right memory plan for the device, no per-request discovery cost — with none of the distribution matrix: models stay single portable files, devices stay interchangeable, and a cache invalidation costs a re-probe, not a rebuild.

**Cost / risk.** The ceiling is lower: a selection among existing kernels can never beat a kernel *generated* for the exact operator fusion a specific model needs, and MLC-LLM's GEMV-vs-GEMM dispatch shows the gap is real at batch size 1 — the personal-runner case. The honest expectation is "most of the win on common shapes", and the design must resist scope creep toward actual code generation, which is the first step back into §6.2's world.

### 9.3 Named resource postures (the `local` / `interactive` / `server` pattern)

**The idea.** Three named modes that preset concurrency and KV capacity, making the engine admit what world it is in (§3.2).

**Gain.** For a personal runner this is close to free and immediately valuable: a posture switch is how the same binary behaves politely on a laptop the user is also typing on, and greedily on a dedicated box, without a dozen exposed knobs. It also gives support and benchmarking a vocabulary — "reproduce it in server posture" means something.

**Cost / risk.** Postures hide real parameters; when a posture is wrong for a user's machine, they need an escape hatch to the underlying numbers or the feature becomes a cage. Ship postures as presets over visible settings, never as replacements for them.

### 9.4 The browser as a legitimate target tier

**The idea.** WebLLM reframes the browser from "a place to run a demo" to a *deployment tier with its own honest constraints*: prebuilt small models, download-once caching, worker-isolated execution, feature detection for GPU capabilities, and an explicit performance tax (~15–20%) accepted in exchange for zero-install, fully private inference.

**Gain for a Go runner.** Two distinct gains. First, *architectural*: designing the engine API so that a WASM/WebGPU tier is *possible later* costs little now — it mostly means keeping the core free of assumptions that only native processes satisfy (no filesystem-shaped model APIs, streaming by message-sized chunks, capability negotiation instead of device-name checks). Second, *product*: a browser tier is the only distribution channel with literally no install friction, and for a personal runner it is the natural "try it / share it" surface.

**Cost / risk.** This is a *tier*, not a port: WebGPU's maturity matrix (§5.3) means the tier serves Chromium-class browsers well and others poorly, storage is evictable, and models must be small. Budget it as a separate, smaller product surface sharing the core contract — the moment it is promised as "the runner, in a tab, at full size", it will disappoint. Note also that Go-to-WASM carries its own runtime weight; the tier is a reason to keep the core's hot loop behind a clean backend interface, not a commitment to ship it first.

### 9.5 Smaller steals, briefly

- **Grammar/JSON mode in the core** (§3.1): structured generation as an engine responsibility, inherited by every shell for free. Gain: agents and tooling work identically everywhere. Cost: a grammar engine is a real component to build and keep correct.
- **Weights/library separation** (§2.2): fine-tunes of a known architecture ship as weights-only against a shared runtime description. The Go analogue — architecture descriptors versioned separately from weight files — makes a future fine-tune ecosystem cheap. Cost: a versioning discipline for descriptors, enforced forever.
- **Self-describing quantization names** (§4.1): encode weight bits and compute dtype in the quant identifier itself. Gain: mechanical reasoning by tools and humans; no lookup tables. Cost: renaming an established scheme is a migration; adopt the *principle* for any new formats rather than renaming inherited GGUF ones.

### 9.6 What NOT to import

**A compiler dependency as a runtime dependency.** This is the dossier's single clearest negative lesson. MLC-LLM's every operational wound — first-run compile waits, nightly-wheel matrices, TVM version coupling, opaque build failures, per-target artifact grids — traces to one decision: *the thing that runs the model is produced by a research compiler stack that must therefore be present, current and correctly configured wherever models are built or first run.* A Go personal runner's founding promise is the opposite: a static binary and a portable model file, working on a machine that has never seen a toolchain. Import MLC-LLM's *knowledge* (kernel selection, memory planning, posture design, one-core-many-shells) and its *ambition* (every device in the law, plus the browser tier in time). Do not import its *supply chain*. The moment our runner needs a compiler present to serve a first token, we have rebuilt MLC-LLM with extra steps and a smaller community.

Also not to import: **nightly-first distribution** (a personal runner ships releases or it ships apologies) and **curation-by-central-registry as the only path** (prebuilt lists are a fine convenience and a poor gate; a runner must load a user's own file without asking a registry's permission — the property that made GGUF's long tail possible).

---

## 10. Sources

All sources accessed 2026-11-15. Primary sources are MLC project material; secondary sources are labelled.

**Primary — MLC-LLM documentation (llm.mlc.ai):**

- Introduction to MLC LLM — three-phase workflow, JIT compilation, model-library formats per platform, device selection, quantization and conversation-template overview. https://llm.mlc.ai/docs/get_started/introduction.html
- Python API (MLCEngine / AsyncMLCEngine) — OpenAI completeness, synchronous vs asynchronous batching behaviour, engine modes `local` / `interactive` / `server` and their concurrency / KV-capacity semantics, tensor-parallel configuration. https://llm.mlc.ai/docs/deploy/python_engine.html
- Configure Quantization — the `qAfB(_id)` scheme, the documented mode list including `q4f16_awq` (not stable), FP8 weight-activation modes and the calibration workflow, the default group-quantization algorithm's cited basis. https://llm.mlc.ai/docs/compilation/configure_quantization.html
- Android SDK documentation — package flow, physical-device requirement, NDK/JDK/Rust build requirements, TVM-as-submodule layout. https://llm.mlc.ai/docs/deploy/android.html

**Primary — MLC project blogs (blog.mlc.ai):**

- "MLC-LLM: Universal LLM Deployment Engine with ML Compilation", 2024-06-07 — MLCEngine launch: one engine for cloud and local, OpenAI-style API in REST / Python / Swift / Kotlin / JavaScript, continuous batching, speculative decoding, paged KV management, common prefix caching, cascade inference, FlashInfer on CUDA, multi-GPU on CUDA and ROCm, validated device list (RTX 4090, Jetson Orin, T4, 7900 XTX, Steam Deck, Orange Pi), the three server modes. https://blog.mlc.ai/2024/06/07/universal-LLM-deployment-engine-with-ML-compilation.html
- "WebLLM: A High-Performance In-Browser LLM Inference Engine", 2024-06-13 — WebLLM architecture (service-worker engine, WGSL kernels + WASM non-kernel code, compile-time production of weights + WASM library, download-once caching), OpenAI-style API and JSON mode in the browser, WebGPU vs native Metal on M3 Max (up to 85% of native). https://blog.mlc.ai/2024/06/13/webllm-a-high-performance-in-browser-llm-inference-engine
- "Optimizing and Characterizing High-Throughput Low-Latency LLM Inference in MLCEngine", 2024-10-10 (also published via CMU) — H100 benchmark setup and results (Llama 3 8B FP16 on 1×H100, 70B FP8 on 4×H100, ShareGPT, vs SGLang v0.3.1.post2 and vLLM v0.6.1.post2), ~30 concurrent users at ~100 tok/s per user for ~3,000 tok/s aggregate (8B), speculative decoding latency reduction >25%, FlashInfer integration, GEMM/GEMV dispatch, memory planning, CUDA Graphs, ~3% CPU overhead. https://blog.mlc.ai/2024/10/10/optimizing-and-characterizing-high-throughput-low-latency-llm-inference and https://www.cs.cmu.edu/~csd-phd-blog/2024/low-latency-llm-serving/

**Primary — repositories and project material:**

- mlc-ai/mlc-llm repository README — mission, Apache-2.0 licence badge, TVM Unity basis, supported-platforms summary, CMU Catalyst / UW SAMPL / SJTU / OctoML origins. https://github.com/mlc-ai/mlc-llm
- mlc-ai/web-llm repository README — companion-project status, built-in model families, `prebuiltAppConfig` model list, custom-model flow. https://github.com/mlc-ai/web-llm
- WebLLM paper, arXiv:2412.15803 — in-browser engine design; evaluation retaining up to ~80% of native performance (absolute M3 Max figures as reported in the secondary coverage below).
- FlashInfer paper, MLSys 2025 (proceedings.mlsys.org) — FlashInfer's integration into MLC-Engine and the implementation of composable KV-cache formats within MLCEngine under prefix caching; referenced here only for the KV design verification in §3.4, as FlashInfer has its own dossier in this corpus.

**Secondary — independent and community sources (used for corroboration, cost characterisation and practitioner figures, and labelled as secondary wherever relied on):**

- Comparative study of MLX, MLC-LLM, llama.cpp, Ollama and PyTorch MPS on Apple Silicon, arXiv:2511.05502 — Mac Studio M2 Ultra setup; MLC-LLM's TTFT and feature-set findings (§7.2).
- Apache TVM Unity / Relax material (tvm.apache.org tutorials and TVM community writing on the Relay → Relax → Unity evolution) — IRModule, Relax, TensorIR and MetaSchedule background for §2.1.
- Apache TVM discussion forum threads (2023–2025) — version-skew and build-configuration failure examples cited in §6.2 as a failure class. https://discuss.tvm.apache.org
- TapML paper, arXiv:2404.09151 — MLC-LLM's emerging-platform testing methodology; 105 models / 27 architectures / 5 platforms over two years (§6.2).
- Repository-derived summaries (DeepWiki) of mlc-ai/mlc-llm and mlc-ai/web-llm — support-matrix reproduction (§6.1) and WebLLM cache-backend detail (§5.2), treated as secondary throughout.
- Independent reviews and practitioner write-ups read 2026-11-15 (a local-AI tool review of MLC-LLM last verified 2026-11-08; a 2026 MLC-LLM setup guide; mobile-deployment practitioner blogs) — nightly wheel matrix by CUDA/ROCm generation, source-build and per-target compile time ranges, Android OpenCL reliability caveats, phone tokens/second indications, WebLLM model download sizes. Used only where the dossier marks figures as indicative or practitioner-reported.

**Unverifiable from sources read (recorded, not filled in):** MLC-Engine's KV page/block size, eviction policy, and prefix-cache keying mechanism; whether prefix caching and speculative decoding are active in `local` / `interactive` modes; current stable-release versioning of MLC-LLM (the documentation tree read carries a 0.1.0 label while describing the current engine, and distribution is nightly-first, so no single "current version" claim is made anywhere in this dossier).
