# OR-2 — ONNX Runtime GenAI (ORT GenAI)

**Name:** ONNX Runtime Generative AI — usually shortened to ONNX Runtime GenAI, ORT GenAI, or OGA  
**Licence:** MIT — verified 2026-11-15. The repository, its source-file headers, and its package metadata all carry the MIT licence attributed to Microsoft. The underlying ONNX Runtime is also MIT-licensed. Individual execution providers pulled in at runtime (for example Qualcomm QNN) carry their own vendor licences and terms, separate from the GenAI licence itself.  
**Core language / bindings:** C++ core with a C API. Documented language surfaces as of late 2025: Python, C#, C/C++, Java, and Objective-C (the last two aimed mainly at mobile). Distribution is per-provider: separate Python wheels and NuGet packages exist for the base/CPU build, CUDA, DirectML, and Windows ML (WinML) variants, among others.  
**Project links:** Repository: `microsoft/onnxruntime-genai` on GitHub. Documentation: `onnxruntime.ai/docs/genai`. Model-builder guidance is linked from the docs site to the repository.  
**As of:** 2026-11-15. Version line in view at that date: the 0.10 series (0.10.0, 10 Oct 2025 on PyPI) with 0.11.0 appearing 13 Nov 2025. The project itself labels the API as preview / 0.x and subject to change — that warning appears in its own config reference.  
**Reader note:** Written for Yrsa engineering an improved Ollama in Go. The comparisons to GGUF / llama.cpp / Ollama are from that engineering angle.

**Essence in one paragraph:** ORT GenAI is not a server and not an application. It is the missing generative loop that plain ONNX Runtime never had — tokenisation glue, the autoregressive step loop, logits processing, search and sampling, and KV-cache bookkeeping — packaged as an embeddable library that sits on top of ONNX Runtime and inherits all of ONNX Runtime's execution providers. You ship it *inside* your product, you feed it a folder containing an ONNX graph plus a `genai_config.json`, and it generates text (and, for supported architectures, speech / vision-language output). Its strategic value is not raw speed on a single well-supported GPU; it is breadth: the same library shape reaches Windows GPUs via DirectML / Windows ML, NVIDIA via CUDA, Intel via OpenVINO, Qualcomm NPUs via QNN, AMD NPUs via Vitis AI, and browsers / other GPUs via WebGPU, with CPU always present as the fallback.

---

## 1. Why this pole of the field matters

Most runners in this corpus take one of two shapes:

- a **daemon / server** you talk to over HTTP (Ollama, vLLM, llama.cpp server), or
- a **standalone executable / app** that owns the whole experience.

ORT GenAI is a third shape: a **library pole**. The host application owns the UI, the process lifetime, the model download, and the policy. GenAI owns only the generation loop. Microsoft's own products exploit exactly that shape — the GenAI README (accessed 2026-11-15) states that it powers Foundry Local, Windows ML, and the Visual Studio Code AI Toolkit. That is the design lesson, independent of whether a Go runner ever links ONNX Runtime itself.

---

## 2. Architecture

### 2.1 Layering

Three layers, bottom to top:

1. **ONNX Runtime (ORT) core.** A graph executor. It loads an ONNX graph, partitions it among execution providers (EPs), applies graph optimisations, allocates tensors, and runs forward passes. On its own it knows nothing about tokens, prompts, or stopping conditions — one call is one forward pass.

2. **The GenAI layer.** A comparatively thin C++ library over ORT that adds everything autoregressive generation needs:
   - a **Model** abstraction: loads the folder, reads `genai_config.json`, creates the ORT session(s) with the configured providers, and knows the model's architecture type, vocabulary, context length, and special token ids;
   - a **Tokenizer** abstraction (backed by ONNX Runtime Extensions tokeniser machinery): encode, decode, batched encode, and a streaming decoder that emits text fragment by fragment;
   - **GeneratorParams**: the per-request bundle — input ids / inputs, plus the search options;
   - a **Generator**: the stateful object that owns one generation's KV state and search state and advances it step by step;
   - a **Search / sampling** component inside the Generator: given logits, apply penalties and pick the next token(s) according to the configured policy (see §5);
   - pre- and post-processing for non-pure-text architectures (vision, speech / Whisper-style encoder-decoder models are first-class model types in the config, not hacks).

3. **The host application.** Anything from a five-line Python script to Foundry Local to a full IDE extension. The host chooses between two levels of control that GenAI deliberately offers side by side:
   - **High level:** a single `generate()`-style call on the Model that runs to completion and returns token sequences.
   - **Low level:** create a Generator and drive it manually — compute logits, generate the next token, check `is_done()`, stream from the tokeniser — which is what any interactive chat UI needs.

That two-level offer is not accidental duplication. It is the library acknowledging that batch jobs and interactive products need the same engine at different granularities.

Multi-model structure is also explicit in the config: a model may be a single decoder graph, an encoder + decoder pair, or a **pipeline** of sub-graphs (embedding, vision, speech, decoder), each with its own file, its own session options, and flags for whether it runs on the prompt phase, on the token-generation phase, or both. The config reference documents this pipeline form directly.

### 2.2 The execution-provider model — what it buys

An execution provider is ORT's plug-in for one hardware family. At session creation the graph is partitioned: each node is offered to the providers in priority order; a provider claims the nodes it can run, with its own kernels and memory; unclaimed nodes fall to the next provider, and ultimately to CPU, which implements the full ONNX operator set.

What that buys, concretely:

- **One graph format, many accelerators.** The application code does not change between a CUDA workstation, a DirectX 12 laptop GPU, and a Snapdragon NPU laptop. Only the provider list in the session options / `genai_config.json` changes.
- **Vendor kernels without forking the runner.** NVIDIA, Intel, Qualcomm, AMD and Microsoft each maintain their provider; improvements land in the provider, not in GenAI.
- **A system-level distribution channel on Windows.** Windows ML can supply a shared, OS-managed ONNX Runtime and dynamically download the vendor EP that matches the machine, so an app does not have to bundle every vendor binary itself. Microsoft Learn documents this behaviour for Windows ML (accessed 2026-11-15).
- **CPU is always a real target, not an error path.** The CPU provider is complete, which makes ARM boards, VMs, and CI runners viable — slow, but functionally identical.

### 2.3 The execution-provider model — what it costs: the provider lottery

The same partitioning is the system's central weakness, and the dossier task names it correctly: **a model is only as fast as its weakest fallback.**

- **Fallback is partitioning, not failure.** If a provider cannot run an operator — wrong dtype, unsupported shape, a custom attention variant it does not pattern-match — those nodes silently run elsewhere, usually CPU. The output stays correct. The latency does not. A graph that is 95% on an NPU by node count can still have the majority of its floating-point work on CPU if the heavy nodes are the ones that fell back. This failure mode is well documented in the QNN ecosystem in particular: field reports describe a single unsupported normalisation op quietly moving a large share of FLOPs to CPU, visible only in an ORT profiling trace, with roughly tripled tail latency as the only symptom (independent practitioner write-up, accessed 2026-11-15 — treat the specific numbers as anecdotal, the mechanism as documented ORT behaviour).
- **Models are effectively built per provider.** NVIDIA's own deployment documentation for ORT GenAI (accessed 2026-11-15) states the point plainly in substance: a GenAI model exported for one EP is generally not portable to another; moving backends means re-exporting / rebuilding for that target. The builder takes the target provider as an input (`-e cpu`, `-e dml`, `-e cuda`, …) and the choice changes activation dtypes and graph details — an INT4 build for DirectML carries FP16 activations, the CPU build of the same weights carries FP32 activations. So "one graph, many accelerators" is true at the API level and only half-true at the artefact level. You ship a *family* of builds of the same model.
- **Capability matrices differ in the small print.** DirectML historically lacking an 8-bit path (noted in NVIDIA's Model Optimizer deployment docs), QNN preferring static shapes and fixed KV shapes, providers differing on which attention fusions they recognise — none of this surfaces in the GenAI API. It surfaces as "same model, same prompt, wildly different speed on two laptops."
- **Version coupling.** The GenAI wheel, the ORT version it was built against, the provider package, the GPU/NPU driver, and the model build must all be mutually compatible. The per-provider package split (separate wheels for base, CUDA, DirectML, WinML) exists precisely because this matrix cannot be collapsed into one artefact.

For a Go runner, §9 returns to this: the abstraction is worth stealing, the *silence* about fallback is not.

---

## 3. The model path: ONNX as interchange, and the convert-first world

### 3.1 ONNX vs GGUF — two different bets

| Axis | ONNX (ORT GenAI) | GGUF (llama.cpp / Ollama) |
|---|---|---|
| Origin | Industry interchange format from the framework era; a serialised computation graph (protobuf) plus external weight data | Single-purpose format designed for one engine family's local inference |
| What the file contains | The *graph* — operators, shapes, dtypes — plus weights. The runner must interpret the graph | Weights plus metadata in a layout the engine maps and consumes directly; the architecture logic lives in the engine's code |
| New architecture cost | In principle: export the graph, no new engine code. In practice: the builder / config must know the model type, and providers must support the ops used | New engine code for the architecture, then cheap conversion of weights |
| Quantisation lives | In the graph itself — quantised operators / packed weight nodes (e.g. 4-bit matmul forms) with scales, chosen at build time for a target provider | In the weight tensors, in engine-native quant formats the kernels are written against |
| Portability | Across runtimes and vendors — that is the entire point | Across machines running the same engine family |
| Friction | Conversion is a project: export, optimise, quantise, validate, per target provider | Download and run; conversion is a solved, one-command community pipeline |

Neither bet is "better" in the abstract. ONNX buys vendor reach and embeddability in exchange for conversion friction and provider variance. GGUF buys immediacy and predictable performance in exchange for the engine having to implement every architecture and every backend itself.

### 3.2 The model builder

GenAI ships its model-building tooling inside the Python package. The documented flow (Phi-2 / Phi-3 tutorials, onnxruntime.ai, accessed 2026-11-15):

1. Start from a Hugging Face checkpoint — downloaded by id, or from local weights; the tutorials also note conversion from GGUF as an input route.
2. Invoke the builder as a Python module, naming three things that together define the artefact: the **model**, the **precision** (`-p`), and the **target execution provider** (`-e`). The canonical tutorial example builds Phi-2 at INT4 for CPU.
3. The builder emits a **folder**, not a single file. The folder is the unit GenAI loads, and typically contains:
   - the graph file (`model.onnx`) and its external weights file (`model.onnx.data`),
   - `genai_config.json` (see §3.3),
   - tokeniser / processor files copied from the source checkpoint.

Supported precisions in the builder, as documented across the builder and its Olive integration: FP32, FP16, BF16, INT8, and INT4. The architecture roster is broad and growing — the current README support matrix (accessed 2026-11-15) lists, among others, Llama, Mistral, Phi (language and vision), Qwen (language and vision), Gemma, DeepSeek, Granite, Nemotron, OLMo, ChatGLM, ERNIE, gpt-oss, SmolLM3, and Whisper for speech — with the honest caveat that "listed" and "equally good on every provider" are different claims.

### 3.3 `genai_config.json` — the contract in the folder

This file deserves attention because it *is* the interface between the model artefact and the runtime. As documented in the official config reference (accessed 2026-11-15), it has two top-level sections:

- **`model`** — architecture type, vocab size, context length, BOS/EOS/PAD ids, and for the decoder: hidden size, head counts, layer count, the graph filename, session options (threading, memory arena, profiling, provider options and provider list), and — critically — the **names of the graph inputs and outputs**, including the patterned names for past keys/values in and present keys/values out (see §5.2).
- **`search`** — the default generation policy: sampling / beam parameters and KV-buffer behaviour (see §5.1). Defaults in the file can be overridden per request from code.

Design consequence: GenAI does not hard-code one model's tensor names. Any ONNX graph that can be described by this contract can be driven by the loop. The cost is that a hand-brought model with a mismatched config fails in confusing ways, and the model section is explicitly documented as "do not edit unless you brought your own model."

### 3.4 Quantisation routes

As documented across the GenAI builder, Microsoft's Olive toolchain, and AMD's Quark documentation (all accessed 2026-11-15):

- **RTN (round-to-nearest)** — the builder's built-in, calibration-free weight-only quantisation. Fast to produce, reasonable quality, the default route for the tutorial INT4 builds (community CPU builds are commonly described as INT4 RTN with a block size, e.g. block-32).
- **AWQ (activation-aware weight quantisation)** — calibration-based INT4; available through Olive / AutoAWQ and through AMD Quark (documented configuration: UINT4, group 128, asymmetric, FP16 activations) and then exported through the GenAI builder. Better quality retention than RTN at the same bit width, at the cost of a calibration dataset and a GPU-class build machine.
- **GPTQ** — the other major calibration-based route, integrated via Olive / AutoGPTQ, quantising to 8/4/3/2 bits in principle, 4 in practice for this use.
- **INT8 routes** — static (calibrated) and dynamic quantisation from ONNX Runtime's own quantisation tooling, plus weight-only INT8 forms. Provider support varies (see the DirectML caveat in §2.3).
- **Vendor / newer routes** — NVIDIA Model Optimizer (INT4 AWQ and FP8-style flows for its providers) and FP8 / NVFP4 experiments appear in the builder's loader code and tests. As of 2026-11-15 these should be read as *emerging*, not as the stable documented path. *[Marked as forward-looking: based on builder source structure, not on stable-release documentation.]*

### 3.5 The friction, stated plainly

A convert-first world means:

- **Time and expertise before first token.** Download → (maybe quantise, with calibration data) → export per provider → validate numerics → ship a folder. GGUF's world is: download one file.
- **One artefact per target.** Multiply the above by CPU / CUDA / DirectML / QNN for a fleet like Volmarr's.
- **Catalogue lag.** Someone must do the conversion work for each new model release. This is why Microsoft's Foundry Local catalogue (see §6) is small and curated while GGUF catalogues are vast and community-driven — the formats impose different labour economics. It is a structural fact, not a competence judgement on either side.
- **Validation burden.** A bad export can be silently *wrong-ish* (degraded quality) rather than broken, so serious use needs perplexity / output checks per build — labour the GGUF pipeline mostly centralised long ago.

---

## 4. Hardware / provider matrix (as documented, with honest gaps)

Provider list below is GenAI's own: the `genai_config.json` provider-options reference (accessed 2026-11-15) enumerates **cuda, DML, NvTensorRtRtx, OpenVINO, QNN, WebGPU, VitisAI**, with **CPU as the default** when no provider is named. ORT core supports more providers than GenAI documents as targets — the gap between the two lists is itself a finding.

| Provider | Hardware | Platform | Status / character as documented | Honest gaps |
|---|---|---|---|---|
| CPU | x86-64, ARM64 | Windows, Linux, macOS | Always available; complete operator coverage; the reference fallback | Slow for large models; INT4 RTN builds are the realistic CPU configuration |
| CUDA | NVIDIA GPUs | Windows, Linux | First-class; separate CUDA package; CUDA-graph capture option documented in package material | Version coupling to CUDA / cuDNN; model build is CUDA-targeted |
| DirectML (DML) | Any DirectX 12 GPU — AMD, Intel, NVIDIA, Qualcomm | Windows only | The broad-Windows-GPU path; separate DirectML package; historically the main GenAI GPU story on Windows | Microsoft now places DirectML in *sustained engineering* and steers new Windows work to Windows ML (documented in ORT install docs and Microsoft Learn, accessed 2026-11-15); no 8-bit path per NVIDIA deployment docs |
| Windows ML (WinML) | CPU / GPU / NPU via dynamically downloaded EPs | Windows 11 24H2+ for the dynamic-EP model | The strategic Windows successor: OS-shared ORT, per-vendor EPs delivered by the platform; GenAI has a dedicated WinML package (0.11.0, Nov 2025) | New and moving; behaviour depends on OS build and driver state outside the app's control |
| NvTensorRtRtx (TRT-RTX) | NVIDIA RTX GPUs | Windows (primarily) | TensorRT-based provider for RTX-class cards, listed in GenAI's provider options | Narrower hardware scope than plain CUDA; another per-target build |
| OpenVINO | Intel CPU / GPU / NPU | Windows, Linux | Intel's provider; the Intel NPU route | Quality of the LLM experience is Intel-stack-dependent; less GenAI-specific documentation than CUDA/DML |
| QNN | Qualcomm Hexagon NPU (Snapdragon X Elite / X Plus on Windows; Snapdragon mobile) | Windows on ARM, Android / Linux | The Copilot+ PC NPU path. Windows ML documents require Snapdragon X Elite/Plus silicon with a minimum Hexagon driver version | The most constrained provider: prefers static shapes; documented ecosystem limits include fixed KV-cache shapes (a 4096-token NPU context ceiling reported in Qualcomm support material — vendor-forum sourcing, treat as indicative not contractual); silent CPU fallback risk is highest here (§2.3); models typically need QNN-specific preparation / context binaries |
| Vitis AI | AMD NPUs (Ryzen AI) | Windows | Listed in GenAI provider options; AMD's Ryzen AI software stack ships ORT GenAI as its LLM runtime surface | Smallest public documentation footprint of the listed providers; AMD-specific model builds ("hybrid" models in AMD's material) |
| WebGPU | GPUs reachable via WebGPU / Dawn, incl. Apple Silicon via Metal underneath | Cross-platform, incl. browser-adjacent hosts | Listed in GenAI provider options; Foundry Local uses the WebGPU path on Apple Silicon (see §6) | Youngest provider; feature coverage trails CUDA; some model features documented as not loading under WebGPU in builder notes |
| CoreML | Apple Neural Engine / GPU / CPU | macOS, iOS | A mature **ORT core** provider — but **not enumerated in GenAI's provider-options reference** as of access date | Do not assume GenAI-on-CoreML is a documented, supported combination; Apple's practical GenAI route in Microsoft's stack is WebGPU. This is the matrix's most commonly overstated cell |

**Fleet reading for Volmarr (our analysis, not a vendor claim):**

- **Windows F15 (NVIDIA, RTX-class):** CUDA build is the straightforward path; TRT-RTX is the interesting experiment.
- **Z13 (AMD, Ryzen AI NPU + integrated GPU):** the GenAI-relevant providers are DirectML / WinML for the GPU and Vitis AI for the NPU. This is precisely the class of machine where the provider lottery bites — NPU coverage for a given LLM graph is partial by design, and the fallback accounting (§9) matters more than the headline provider name.
- **ARM Pi (Linux ARM64, CPU only):** CPU provider only. Viable for small INT4 models (see §7), with no NPU story from GenAI on that hardware.

---

## 5. Runtime behaviour

### 5.1 The Generator loop and search / sampling

One generation, at the low level, is a loop the host can see:

1. Build `GeneratorParams` from the Model; set input ids (or multimodal inputs on the Generator for non-LLM models in newer API revisions).
2. Create a `Generator`, which allocates KV state sized from the search options — notably, the documented semantics of `max_length` are that it *determines how much KV-cache memory is allocated*.
3. Repeat until done: compute logits (one ORT forward pass), then generate the next token(s) under the search policy; optionally stream decoded text after each step.
4. Termination on EOS, on `max_length`, or on the search policy's stopping rules.

The **search configuration** (from `genai_config.json` defaults, overridable per request) as documented in the config reference:

- **Mode selection by combination**, documented explicitly:
  - *Greedy:* `num_beams = 1`, `do_sample = false`.
  - *Beam search:* `num_beams > 1`, `do_sample = false`, and `past_present_share_buffer` must be *false* (beams need separate buffers — a small, revealing coupling between search policy and memory layout).
  - *Sampling:* `do_sample = true`, with `top_k`, `top_p` (nucleus), and `temperature`.
- **Logits processing:** repetition penalty, no-repeat-ngram size, min/max length, length penalty and early stopping for beams, a random seed (`-1` = random device). `diversity_penalty` is present in the schema and documented as *not supported* — an honest fossil worth noting: the schema is wider than the implementation.
- **Guidance / grammar:** current GenAI material describes grammar specification for tool calling — constrained decoding driven by a grammar, surfaced through the Generator parameters. This is the library growing toward agentic use, and it lives, correctly, in the search/policy layer rather than in the graph.

The architectural point for §9: **search is a policy object separate from the model execution.** The Model runs the graph; the Generator's search decides what token comes next. The two evolve independently.

### 5.2 KV handling: past/present as graph I/O — the decision that shapes everything

In ORT GenAI, the KV cache is not a private data structure hidden inside an engine. Because the underlying executor is a *graph* executor, the cache is part of the graph's interface:

- The graph takes, per layer, **past** key and value tensors as named inputs (the config carries name *patterns* for them, e.g. past key/value names parameterised by layer index).
- The graph returns, per layer, **present** key and value tensors as named outputs, alongside logits.
- GenAI's job between calls is bookkeeping: hold the present tensors, feed them back as the next step's past, grow the sequence dimension, and manage the attention mask and position bookkeeping that go with them.

Why this shapes everything:

1. **Shapes are contractual.** Sequence dimensions, head counts, and layer counts are in the config and in the graph signature. A provider that wants static shapes (QNN) can demand fixed past/present shapes — hence fixed context ceilings on NPUs. A provider comfortable with dynamic shapes (CUDA, CPU) can grow freely. *The same logical cache has different physical freedom per provider, and the graph signature is where that difference is decided — at model-build time, not at runtime.*
2. **Buffer sharing is an explicit option.** `past_present_share_buffer` lets past and present share one backing buffer so the cache is updated in place rather than copied between distinct tensors each step — a direct memory-bandwidth optimisation, exposed in config because its correctness depends on the search mode (it must be off for beam search, per §5.1).
3. **Multi-turn reuse falls out naturally — and is productised downstream.** Because the Generator owns the cache as state, keeping the Generator alive across turns means only new tokens are processed. AMD's Ryzen AI material (accessed 2026-11-15) builds a documented feature on exactly this: KV-cache reuse across conversation turns via GenAI's continuous-decoding surface, including a rewind operation that moves the cache pointer back to an earlier position to branch a conversation. Note the terminology trap: AMD's "continuous decoding" (cache persistence across turns) is **not** "continuous batching" (interleaving different requests) — see §5.3.
4. **Contrast with GGUF engines.** In llama.cpp the cache is an engine-internal allocation with engine-chosen layout (including optional cache quantisation). That invisibility is a feature for users and a constraint for embedders. GenAI's graph-visible cache is the opposite trade: more exposed surface, more chances to mismatch config and graph — and more ability for a host or a provider to do something clever with the state.

### 5.3 Batching: what is documented, and what is not

Honesty required here, because this is where GenAI is most often over-described by association with vLLM-class servers.

- **Documented, stable surface (as of 2026-11-15):** batched generation. `batch_size` in the search options is "number of sequences to generate in parallel"; the tutorials demonstrate encoding a batch of prompts and generating for all of them together. This is *static* batching: a fixed set of sequences, advanced in lockstep, sharing one graph execution per step.
- **Not documented as a GenAI feature in the stable docs accessed:** vLLM-style **continuous / in-flight batching** (admitting and retiring *independent requests* at token granularity under a scheduler) and **PagedAttention**-style paged KV allocation. GenAI is a library for embedding, historically used with one interactive session per process; it does not present itself as a multi-tenant serving engine, and its config reference contains no scheduler, queue, or paging concepts.
- **Forward-looking signals:** builder source on the main branch contains options referring to dynamic batching and paged attention (maximum batch size, maximum scheduled tokens, a paged-attention flag written into an engine section of the config). *[Speculation / unverified for stable releases: these were seen in builder source listings during research, not in the stable documentation as of 2026-11-15. Do not cite GenAI as having shipped continuous batching on this evidence.]* If they land, they land first where the serving pressure is — Foundry Local sharing one loaded model between several local tools is exactly the workload that wants request interleaving, and third-party accounts of Foundry Local describe interleaved handling of concurrent local clients. Treat product-level descriptions as behaviour reports about Foundry Local, not as GenAI API documentation.

**Bottom line for the Go runner:** for throughput-serving ideas, study vLLM. From GenAI, study *session* semantics — persistent generators, cache reuse, rewind — which are the batching-adjacent features an interactive local runner actually needs.

---

## 6. Where it is actually used

Behaviour-level, from public sources accessed 2026-11-15:

- **Foundry Local (Microsoft).** Microsoft's local-model runtime for developers: a curated catalogue of ONNX models, a local service exposing an OpenAI-compatible endpoint, and SDKs. Its own documentation and the GenAI README agree that it is built on ONNX Runtime with the GenAI layer running the generation loop. Its hardware selection at startup — QNN NPU, DirectX 12 GPU via WinML/DirectML, CUDA, or CPU fallback — is the provider model productised. Its catalogue's smallness relative to GGUF ecosystems is the convert-first economics of §3.5 made visible.
- **Windows ML / Microsoft Foundry on Windows.** The OS-level story: Windows AI APIs for ready-made features on Copilot+ PCs (NPUs rated 40+ TOPS by Microsoft's definition), Foundry Local for a wider model choice, and Windows ML for bring-your-own-ONNX with platform-delivered execution providers. GenAI is the documented route for running generative models through Windows ML. This positioning — *the NPU in a Windows laptop is reachable by ordinary apps through this stack* — is GenAI's most distinctive real-world role, and the one with no GGUF-world equivalent of comparable official standing.
- **Visual Studio Code AI Toolkit (Microsoft).** Named in the GenAI README as powered by GenAI: model exploration / local inference inside the editor tooling.
- **AMD Ryzen AI software stack.** AMD ships ORT GenAI as the runtime surface for LLM features on Ryzen AI machines, including the KV-reuse behaviour in §5.2 — an example of a *silicon vendor* adopting GenAI as its developer-facing LLM layer.
- **Embeddings in third-party products.** The pattern repeats in smaller tools: .NET local-AI libraries compared against it, Unity packages wrapping its C API, Flutter plug-ins over the same C API, and community OpenAI-compatible servers built on top of it. The C API is the embedding seam all of these use — evidence that the library-first design works as intended.
- **What it is not used as:** a public cloud serving engine, a multi-user hosted API backend, or a training stack. Its centre of gravity is one device, one user, inside someone else's product.

---

## 7. Performance character

**Method note:** ORT GenAI has no single meaningful "speed." Every number is a tuple of (model build, provider, hardware, prompt length, batch). Numbers below carry their tuples; anything without one was excluded.

**Reported numbers:**

1. **Data-centre GPU, head-to-head (Microsoft ISE engineering blog, 2 May 2025).** Phi-3 Mini (ONNX build via the GenAI builder) on an Azure ND96amsr A100 v4 instance (1× A100 80 GB), 256 generated tokens, batch 1, 5 warm-ups / 10 repetitions. Average generation throughput: **≈137.6 tok/s at prompt 16, falling to ≈122.6 tok/s at prompt 2048** for ORT GenAI, versus llama.cpp ≈109.5 → ≈102.0 tok/s and HF Optimum ≈108.3 → ≈99.3 tok/s on the same setup — i.e. GenAI ahead by roughly 1.2–1.3× over llama.cpp in *this* configuration. Read this narrowly: it is Microsoft's own scenario, a Microsoft model in its native ONNX form, on a GPU where CUDA provider maturity is high. It does disprove "GenAI is always slower"; it does not establish a general ranking.
2. **ARM phone / Windows-on-ARM class (Arm Learning Path example output, accessed 2026-11-15).** Phi-3 Mini 4-bit, prompt 64 tokens: time-to-first-token ≈1.79 s, prompt processing ≈35.7 tok/s, **decode ≈6.3 tok/s**. This is the honest shape of CPU/edge-ARM generation for a ~4B model: usable for chat, nowhere near GPU numbers.
3. **Raspberry Pi 5, CPU (community report, accessed 2026-11-15 — low authority, indicative only).** Phi-3 Mini 4K INT4 via GenAI at **≈4 tok/s**, with a Mistral 7B ONNX INT4 build also runnable, slower. Consistent with (2) and with Pi-class GGUF results in the same corpus: on CPU-only ARM, format matters less than memory bandwidth.

**The general pattern (our synthesis of the above plus the provider documentation):**

- **Provider-bound, always.** The same model build family swings from ~6 tok/s (ARM CPU) to ~130 tok/s (A100 CUDA). There is no "GenAI speed"; there is "this provider on this silicon."
- **Rarely the headline winner on NVIDIA enthusiast hardware**, where llama.cpp / vLLM kernels are tuned per-architecture — the A100 result above notwithstanding, since it reflects a favourable model/format pairing as much as engine quality.
- **Often the only option on a given path:** a Snapdragon X NPU under Windows, an Intel NPU via OpenVINO, an AMD NPU via Vitis AI, a DirectX-only Windows GPU with no CUDA — in each case the realistic alternative is usually "CPU" or "nothing," not a faster rival engine. GenAI wins those comparisons by existing.
- **Small-model, short-context, interactive** is its home territory: the workloads its embedding hosts (chat in an app, IDE assistance, on-device RAG) actually present.

---

## 8. Strengths / weaknesses

### Strengths

- **Embeddability is real, not marketing.** A C++ core, a C API, maintained Python/C#/Java/ObjC surfaces, per-provider packages, and a folder-based model contract. Third parties demonstrably build on it (§6).
- **Provider breadth no other single LLM library matches**, especially across *NPUs on Windows*. QNN + Vitis AI + OpenVINO + DirectML/WinML in one API is a unique position.
- **Clean conceptual separations:** graph execution (ORT) vs generation loop (GenAI) vs search policy (Generator's search) vs host application. Each layer is replaceable in principle.
- **The config-as-contract model folder** (`genai_config.json`) makes models self-describing to the runtime, including tensor naming, context length, and default search policy.
- **Multimodal is structural** (encoder/vision/speech sub-graphs, pipeline models), not bolted onto a text loop.
- **MIT licence, Microsoft maintenance, and OS-level distribution** via Windows ML — longevity signals few runners can match.
- **Session semantics for interactive products:** persistent generators, cross-turn KV reuse, and rewind, productised by downstream stacks.

### Weaknesses

- **Convert-first friction** (§3.5): per-provider builds, calibration for good quantisation, catalogue lag, validation burden.
- **The provider lottery** (§2.3): silent partial fallback makes performance unpredictable across machines and hard to debug without profiling traces.
- **Preview-grade API stability.** The project is 0.x, labels its own config API as preview, and has shipped breaking changes between minor versions (documented, e.g., the 0.9 input-setting change and the 0.11 decoding-loop change noted in repository material). Embedders must pin versions and expect migration work.
- **Not a serving engine.** No documented continuous batching / paged KV / multi-tenant scheduling in the stable surface (§5.3). Anyone needing vLLM-class throughput per GPU should not start here.
- **Documentation is uneven across providers.** CUDA and DirectML/WinML paths are well lit; QNN and Vitis AI LLM paths require assembling knowledge from vendor stacks (Qualcomm / AMD) outside the GenAI docs.
- **Schema wider than implementation** in places (e.g. the documented-but-unsupported `diversity_penalty`), and matrix cells (CoreML) that are easy to over-claim.
- **Large dependency gravity.** ORT + provider + driver + GenAI version coupling (§2.3) is the operational price of the breadth.

---

## 9. Ideas to steal for a Go runner

Each idea is stated with its gain and its cost/risk. None requires adopting ONNX or ORT; all are shape-level transfers.

### 9.1 Ship the runner as a library first, with the server as a thin shell

**The idea:** Structure the Go runner as `engine` (a library package with a stable, documented Go API: load model, create session/generator, step, stream) plus a *thin* daemon that is only HTTP + process management over that library. GenAI's entire career — Foundry Local, an IDE toolkit, vendor SDKs, third-party C-API wrappers — rests on the library being the product and every host being replaceable.

**Gain:** Embedding becomes possible (a desktop app, a TUI, a test harness, another Go program) without HTTP; testing gets dramatically easier (drive the Generator in-process); the daemon stops being a single point of architectural gravity. For Volmarr's fleet it also matches how his other tools actually consume models — in-process, on the same machine.

**Cost / risk:** API discipline. A library API is a promise; GenAI's own 0.x breaking changes show the cost of getting it wrong early. Mitigation: version the Go API surface explicitly, keep the internal engine free to move behind it, and treat the daemon's HTTP API and the library API as two separate contracts.

### 9.2 Provider abstraction with loud, accounted fallback

**The idea:** Adopt GenAI/ORT's provider idea — a backend claims the work it can do — but fix its worst behaviour: **account for fallback explicitly and loudly.** Every session should produce a placement report: which layers / ops / tensor classes landed on which backend, what share of estimated FLOPs (or at minimum, of layers and of time in a profiled first run) is *not* on the requested accelerator, and a startup log line a user cannot miss when the NPU/GPU they asked for is doing a minority of the work. "Requested QNN, got 40% QNN / 60% CPU" must be a headline, not a profiling-trace Easter egg.

**Gain:** Kills the single most expensive debugging class in the ORT world (§2.3) before it exists in ours. On a fleet as heterogeneous as Volmarr's — CUDA box, AMD NPU laptop, ARM Pi — placement *is* performance; making it visible makes every other optimisation measurable. It also gives honest status reporting (a standing requirement in this house) something concrete to report.

**Cost / risk:** Requires the engine to *know* its placement, which is easy when kernels are dispatched per-layer in our own code and harder if we ever wrap a third-party engine that hides it. FLOP-share estimation can be gamed by unrepresentative first runs; report both the static placement (which ops went where) and a measured profile, labelled as such. Extra startup latency for profiling should be opt-in after the first run, cached per (model, backend, driver) tuple.

### 9.3 Sampling / search as a pluggable policy object, separate from execution

**The idea:** Copy the Model / Generator / Search separation (§5.1) exactly: the thing that runs the graph never decides the next token. A `SearchPolicy` interface — greedy, beam, top-k/top-p sampling today; grammar-constrained decoding, speculative verification, or house policies tomorrow — receives logits and state, returns the next token(s), and owns penalties, stopping rules, and its own configuration struct (the moral equivalent of the `search` section of `genai_config.json`, stored *with the model defaults* and overridable per request).

**Gain:** Policies become unit-testable without a model (feed synthetic logits); new decoding ideas land without touching kernel code; per-request overrides stop being flag soup threaded through the engine; model folders can ship sane defaults that hosts override, exactly as GenAI's config does. Beam search's buffer constraint (§5.1) also teaches the right lesson early: the policy interface must be able to declare its memory requirements (separate KV buffers per beam) to the session allocator, rather than discovering them at runtime.

**Cost / risk:** An interface boundary on the hottest loop in the system. In Go this is manageable — the policy runs once per token over a logits slice, not per FLOP — but the interface must pass logits by reference and avoid allocation per step, or the abstraction will cost real tokens/second on CPU targets like the Pi. Keep the policy object stateful and preallocated, in the Generator, not reconstructed per token.

### 9.4 (Supporting idea) The self-describing model folder

**The idea:** Whatever format the Go runner adopts, ship models as a folder (or a manifest inside a single file) that *declares* its contract: architecture parameters, context length, special tokens, tensor/layout expectations, default search policy, and per-backend build variants — GenAI's `genai_config.json` pattern (§3.3).

**Gain:** The runtime stops hard-coding per-model trivia; validation ("does this artefact match this engine?") becomes a manifest check with a clear error, instead of a crash or silent quality loss; per-backend variants of one model become a first-class, enumerable thing — which a fleet with four hardware classes needs.

**Cost / risk:** Manifest drift — the file says one thing, the weights do another. Mitigation: generate the manifest in the conversion tool, never by hand; checksum the weights in it; refuse (loudly, per §9.2's philosophy) on mismatch rather than "fixing it up" silently.

---

## 10. Sources

All accessed 2026-11-15. Descriptions are of what each source was used for; claims in the dossier are tied to these sources as cited in-line.

1. **microsoft/onnxruntime-genai — GitHub repository & README** (via search index and raw README mirrors). Library definition (generation loop, logits processing, search/sampling, KV management), high-level vs loop-level API, greedy/beam/top-p/top-k support, repetition penalties, support matrix (architectures; CPU, CUDA, DirectML, NvTensorRtRtx, OpenVINO, QNN hardware), API languages, "powers Foundry Local, Windows ML, and the VS Code AI Toolkit," MIT licence headers, 0.9 / 0.11 breaking-change notes.
2. **ONNX Runtime GenAI documentation — onnxruntime.ai/docs/genai**: Config reference (full `genai_config.json` schema: model/search sections, past/present name patterns, provider-options enumeration — cuda, DML, NvTensorRtRtx, OpenVINO, QNN, WebGPU, VitisAI, CPU default — search combinations, `past_present_share_buffer`, `max_length` determining KV allocation, `diversity_penalty` marked unsupported; API labelled preview). Phi-2 Python tutorial (builder invocation `-m … -e cpu -p int4`, emitted folder contents, `generate()` and manual Generator loop with streaming tokeniser, batched prompts). Build-models page (pointer to the repository builder guide).
3. **Microsoft Learn — Windows AI / Windows ML pages**: running GenAI models with Windows ML (0.x preview status; generation-loop scope incl. grammar for tool calling); Windows ML execution providers (QNN requirements: Snapdragon X Elite/Plus, minimum Hexagon driver); Foundry on Windows overview and FAQ (Windows AI APIs / Foundry Local / Windows ML positioning, Copilot+ PC definition, Foundry Local hardware selection — QNN, DirectML/WinML GPU, CUDA, CPU — and OpenAI-compatible local API; DirectML as low-level DirectX 12 layer).
4. **ONNX Runtime core documentation (install / execution providers)**: per-provider packages (base, `onnxruntime-gpu`, `onnxruntime-directml`, `onnxruntime-qnn`), language install matrix (Python, C#/C/C++, Java, Node.js), DirectML in sustained engineering with WinML recommended for new Windows projects, CPU provider as complete fallback.
5. **NVIDIA Model Optimizer deployment documentation — ONNX Runtime section**: GenAI positioning, provider list, the statement that GenAI models are generally built per execution provider and must be re-exported for a different backend, DirectML 8-bit limitation, flexible sampling description.
6. **AMD documentation & articles**: Quark export guide (AWQ UINT4, group 128, asymmetric, FP16 activations → GenAI builder export, `-p int4 -e dml` producing FP16-activation builds vs `-e cpu` FP32); Ryzen AI article on KV-cache reuse (GenAI continuous-decoding surface, cross-turn cache persistence, `rewind_to()` semantics).
7. **Microsoft Olive documentation**: quantisation techniques (AWQ, GPTQ, RTN, HQQ, static/dynamic), ModelBuilder pass into ORT GenAI (precision set FP32/FP16/BF16/INT8/INT4, `genai_config.json` generation, `--use_ort_genai`).
8. **Microsoft ISE engineering blog (2 May 2025) — RAG with ONNX Runtime GenAI on Windows**: the A100 benchmark table in §7 (hardware, model, methodology, and llama.cpp / Optimum comparisons as published there).
9. **Arm Learning Paths — Phi-3 with ONNX Runtime GenAI (Android / Windows on Arm)**: example performance output in §7 (prompt/decode tok/s, time to first token).
10. **PyPI package histories — onnxruntime-genai, -directml, -winml**: version/date grounding (0.9.0 Aug 2025, 0.10.0 Oct 2025, 0.11.0 Nov 2025) and per-provider, per-platform wheel split.
11. **Independent / community sources (used with lower weight, flagged in text)**: practitioner write-up on silent QNN CPU fallback and profiling-based detection (mechanism, §2.3); Raspberry Pi 5 GenAI report (§7, indicative only); Qualcomm support-forum material on QNN KV-shape limits (§4, indicative only); Foundry Local third-party analyses (§5.3, §6, product behaviour only).

**Unverifiable / not established as of 2026-11-15 (explicit):** shipped continuous batching or PagedAttention in a stable GenAI release (§5.3); GenAI-on-CoreML as a documented supported combination (§4); any cross-provider performance ranking beyond the single-configuration results in §7.

---

*Dossier OR-2, Ollama Research Forge. Clean-room: written in the author's own words from the public sources above; no source text reproduced beyond short factual labels (names, option keys, and parameter names).*
