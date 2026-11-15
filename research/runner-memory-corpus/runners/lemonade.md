# OR-2 — AMD Lemonade

**Name:** Lemonade — AMD's local AI server. Repository organisation `lemonade-sdk`; the server daemon is `lemond`, the user-facing command is `lemonade`. AMD's earlier material also expands the name as "LLM-Aide"; current material does not use that expansion and it should be treated as a historical gloss, not a product name.
**Licence:** Apache License 2.0 — verified 2026-11-15. The repository is described as Apache 2.0 in the GitHub README as carried by multiple independent mirrors and reviews read for this dossier, and every secondary source that states a licence states Apache 2.0; no conflicting licence claim was found. **Important boundary:** the Apache 2.0 licence covers Lemonade itself. The engines Lemonade downloads and orchestrates carry their own licences — llama.cpp, whisper.cpp, stable-diffusion.cpp and Kokoro are separately licensed open-source projects, and the FastFlowLM NPU kernel binaries are **not** open source at all (see §3.5). "Lemonade is Apache 2.0" must never be read as "everything Lemonade runs is Apache 2.0."
**Core language / bindings:** The server is implemented in **C++** (lightweight native code is a stated design goal in AMD's developer article, accessed 2026-11-15), with the bundled desktop/web app in **React** — the current README line is "Built with C++ (server) and React (app)". A **Python SDK** ships alongside (`pip install lemonade-sdk`; a high-level Python API with a `from_pretrained`-style entry point is documented in AMD's Ryzen AI documentation). Client access is language-agnostic: any OpenAI client library (Python, C++, Java, C#, Node.js, Go, Ruby, Rust, PHP are listed in the README) pointed at the local base URL.
**Project links:** Repository: `lemonade-sdk/lemonade` on GitHub. Site and documentation: `lemonade-server.ai`. Contact: `lemonade@amd.com` (listed in the repository). Companion repositories named in sources read: `lemonade-sdk/ryzenai-server` (the ONNX Runtime GenAI NPU/hybrid backend server, §3.3) and `ROCm/FastFlowLM` (the NPU runtime, §3.2 — moved under AMD's ROCm organisation in 2026; older links use the standalone FastFlowLM organisation).
**As of:** 2026-11-15. Version line in view at that date is unusually fast-moving and changed versioning schemes mid-life: the 10.x line ran through early–mid 2026 (10.0 in March 2026 brought Linux NPU support; 10.6.0 was dated 21 May 2026 in a review read for this dossier), the 11.x line ran through mid–late 2026 (11.0 on 15 July 2026 brought the Apple Silicon Metal backend; 11.8.1 on 28 August 2026), and by autumn 2026 releases had moved to calendar versioning on a roughly weekly cadence (v2026.44.1 on 28 October 2026; candidate v2026.46.0 in early November 2026). Exact patch-level currency matters less than the cadence itself, which is a finding (§7).
**Reader note:** Written for Yrsa engineering an improved Ollama in Go. Lemonade is the vendor reference for the exact hardware class at the centre of Volmarr's fleet — the Strix Halo machine (ASUS ROG Flow Z13, Ryzen AI Max+ 395) that the corpus's unified-memory dossier (`memory/unified-memory.md`) uses as its living case study.

**Essence in one paragraph:** Lemonade is not an inference engine. It is an **orchestration server**: a small C++ daemon that detects what silicon a PC actually has, downloads and launches the right specialist engine for each model as a subprocess — llama.cpp for GGUF models on CPU/GPU, FastFlowLM for models compiled for the AMD XDNA2 NPU, ONNX Runtime GenAI (via the Ryzen AI server) for ONNX models on NPU or in NPU+iGPU hybrid mode, whisper.cpp for transcription, stable-diffusion.cpp for images, Kokoro for speech — and presents all of them behind one local port speaking three API dialects at once (OpenAI, Anthropic, and Ollama). Its reason to exist is AMD's hardware-fragmentation problem: ROCm versus Vulkan versus NPU, each with its own install ritual, is exactly the friction a vendor server can absorb. Its strategic novelty for this corpus is that it is the first mainstream local runner in the field map with a **real, shipping NPU path** — and studying that path shows, concretely, what the corpus's compiled-blob finding (`memory/npu-memory-and-dataflows.md` §6) predicts: the NPU path works, but only for a curated catalogue of models pre-converted into a device-specific format, at the price of closed kernel binaries and a second model universe parallel to GGUF.

---

## 1. Why this pole of the field matters

Every other runner in this corpus makes one of two bets. Ollama and its kin bet on **one engine family** (llama.cpp/GGUF) stretched across every GPU vendor. vLLM/SGLang bet on **one serving architecture** (continuous batching on data-centre GPUs). ORT GenAI and OpenVINO GenAI bet on **one graph format** (ONNX / OpenVINO IR) partitioned across vendor execution providers.

Lemonade bets on **none of those unities**. Its unity is at the *server* layer only:

- many engines, each kept as its own upstream binary;
- many model formats, each native to its engine (GGUF, FLM/Q4NX, ONNX);
- one daemon, one port, one model-management surface, one API family.

That is a genuinely different point in the design space, and it is the point a *hardware vendor* would choose: AMD does not need the world to standardise on one AMD format; it needs every popular engine to run *well on AMD silicon* with the setup pain removed. For our Go runner — which must serve NVIDIA, AMD, Apple and CPU machines from one codebase — Lemonade is the worked example of the "router over engines" architecture, including its failure modes (§7). It is also the only dossier subject that runs models on the NPU sitting idle in Volmarr's Z13, which makes §3 the most directly actionable section in the file.

---

## 2. Architecture

### 2.1 The server shape

As documented in the README and the Hugging Face community technical post (a contributor's walkthrough of the 2026.44/45 line, accessed 2026-11-15), Lemonade has three user-visible parts:

1. **`lemond` — the HTTP server daemon.** It listens on **port 13305 by default** (configurable via `--port` / `LEMONADE_PORT` in the CLI documentation as summarised by reviewers). It owns model loading and unloading, reads each model's **recipe** (see §2.3) to decide which engine serves it, starts that engine, and routes requests to it. The web/desktop app is served by `lemond` itself (at `/app` in current versions). An independent hands-on test of v10.0.1 (accessed 2026-11-15) found the internal shape to be literally a router process proxying to per-engine server processes on their own internal ports — i.e. the daemon is a supervisor and reverse proxy, not a monolith that linked the engines in-process.
2. **`lemonade` — the CLI.** Pull, run, list, delete and manage models; inspect backends (`lemonade backends`, earlier `lemonade recipes`); set configuration; benchmark; and *launch other tools against the local server* — `lemonade launch claude` starts Claude Code pointed at a local model, with equivalents for other coding agents documented. This "launcher for agents" posture is unusual among runners and returns in §5 and §8.
3. **The desktop and web apps.** A Model Manager UI for browsing/installing/organising the catalogue, plus built-in chat, image, transcription and speech pages. AMD's developer article positions the desktop app as the "central control center" for local AI development; functionally it is a client of the same daemon.

**Process isolation is a documented design property:** every engine runs as a **separate subprocess**, so a crash in one engine does not take down the others or the router. Engines are **installed automatically on demand** — on a fresh install, the first chat request downloads the appropriate llama.cpp build for the detected hardware and starts it. The same on-demand download pattern applies to the NPU backends (a hands-on test records `lemonade run Qwen3-8B-Hybrid` automatically downloading the RyzenAI server, ~542 MB, on first use).

### 2.2 One port, three API dialects (plus two more)

The single most-copied fact about Lemonade in secondary coverage — and it is confirmed by the primary README and the contributor walkthrough — is that the same port answers in several API formats simultaneously:

| API surface | Representative endpoints (as documented) | Who it is for |
|---|---|---|
| OpenAI-compatible | `/v1/chat/completions`, `/v1/responses`, `/v1/embeddings`, `/v1/audio/transcriptions`, `/v1/audio/speech`, `/v1/images/generations` | OpenAI SDKs, Open WebUI, Continue, n8n, AnythingLLM, Dify, OpenHands, VS Code tooling |
| Anthropic-compatible | `/v1/messages` | Claude Code and other Anthropic-SDK clients |
| Ollama-compatible | `/api/chat`, `/api/generate`, `/api/tags`, … | Applications that auto-detect or hard-code Ollama (docs note setting the client port to 13305) |
| OpenAI Realtime (WebSocket) | `ws://localhost:13305/v1/realtime` | Live microphone transcription clients |
| MCP | `POST /mcp` | MCP clients; tools include `lemonade_chat`, `lemonade_transcribe_audio`, `lemonade_generate_image` (a review of the late-2026 line lists six MCP tools) |
| Lemonade's own management API | model load/unload/health/config endpoints (e.g. `GET /v1/health` lists loaded models) | The CLI, the apps, and embedders (§5.3) |

Authentication is **off by default**: an API key is only checked if the operator sets one (`LEMONADE_API_KEY` in the contributor walkthrough). One independent review (accessed 2026-11-15) additionally notes the repository carried no security policy at review time and that docs tell WebSocket clients to pass the key in the URL. For a localhost-only personal server this posture is conventional (Ollama's is similar); for anything bound beyond localhost it is a gap the operator must close themselves. *[Assessment: our reading of the documented defaults, not an AMD claim.]*

Two further routing features are documented in the current README line:

- **Cloud offload (experimental).** Lemonade can route to any OpenAI-compatible cloud provider (Fireworks, OpenAI, OpenRouter, Together are named) alongside local models — a hybrid local/cloud registry inside the same server.
- **A model router.** The 11.5-era release (July 2026, per a features roundup accessed 2026-11-15) "completed the Lemonade Router", which evaluates each request and sends it to the most suitable installed local model, with optional cloud fallback. Treat the router's *policy quality* as unverified — no independent evaluation of its choices was found; only its existence is documented.

### 2.3 Recipes: how backend selection actually works

The selection unit in Lemonade is the **recipe**: each registered model carries a recipe that names its engine and backend, and `lemond` serves the model through that recipe. The user-facing consequences, as documented:

- **Per-model routing is the default.** A GGUF model's recipe points at llama.cpp; an FLM model's recipe points at FastFlowLM; an ONNX hybrid model's recipe points at the Ryzen AI server. The client neither knows nor chooses — it names a model, the recipe decides the silicon.
- **Per-hardware availability is computed at runtime.** `lemonade backends` (earlier `lemonade recipes`) prints exactly which engine/backend combinations are available *on this machine*, after hardware detection. Backends can be installed explicitly (`lemonade backends install llamacpp:rocm` is the documented shape) or are auto-installed on first use.
- **The llama.cpp backend itself is multi-flavoured.** One engine, several builds: `vulkan` (the portable default — AMD iGPU/dGPU, Intel, and ARM64 on Linux per the support matrix), `rocm` (AMD GPUs supported by ROCm, including gfx1151 Strix Halo), `cuda` (NVIDIA Turing or newer), `metal` (Apple Silicon), and a plain CPU/`system` build. Which one a given machine gets is a detection result, overridable in configuration (the Docker guide's example sets `"llamacpp": {"backend": "rocm"}` in `config.json`).
- **Overrides pass through.** Hands-on testing confirms llama.cpp arguments can be forwarded (`--llamacpp-args`, e.g. KV-cache types, `--no-mmap`, context size), so the abstraction does not confiscate the engine's own knobs — an important honesty property (§8).
- **Context sizing defaults to "as large as fits".** A reviewer of the 11.x line notes the default context setting is `-1` — the server computes the largest window that fits device memory rather than silently truncating at a small fixed default. *[Secondary-source claim about a default; plausible and consistent with the hardware-detection philosophy, but not re-verified against a primary config reference for this dossier.]*

### 2.4 The backend matrix (text generation)

Consolidated from the README support matrix as carried by the contributor walkthrough and independent reviews (all accessed 2026-11-15). "Engine" is Lemonade's term for the orchestrated runtime; "backend" is the hardware flavour within it.

| Engine | Model format | Devices | OS (as documented) |
|---|---|---|---|
| llama.cpp | GGUF | CPU (x86_64/ARM64); GPU via Vulkan, ROCm, CUDA, Metal | Windows, Linux, macOS |
| FastFlowLM (`flm`) | FLM (Q4NX, §3.2) | AMD XDNA2 NPU only | Windows, Linux |
| Ryzen AI LLM (`ryzenai-llm`) | ONNX (AWQ INT4 builds) | XDNA2 NPU alone, or NPU+iGPU hybrid | **Windows only** |
| vLLM | Safetensors (HF checkpoints) | Strix Halo iGPU | Linux — **experimental** |
| ONNX Runtime | ONNX | CPU (text classification) | Windows — experimental/guest tier |

Non-LLM engines under the same daemon: whisper.cpp and Moonshine (speech-to-text; CPU/Vulkan/ROCm/Metal, plus NPU on Windows), Kokoro (text-to-speech; CPU/Metal) with an experimental alternative TTS backend, stable-diffusion.cpp (image generation; all GPU flavours), plus experimental audio-generation, 3D-generation (TRELLIS) and classification backends, and community llama.cpp forks targeting Strix Halo. The breadth is real, but note the tiering language in Lemonade's own matrix — several entries are explicitly marked *experimental* or *guest* backends. The stable core is: llama.cpp everywhere, FastFlowLM for NPU, Ryzen AI LLM for Windows NPU/hybrid.

### 2.5 Multi-model residency

Lemonade's residency model is **per-modality LRU**: by default it keeps one loaded model *per type* (LLM, embedding, reranking, transcription, image, TTS, classification), each type with its own least-recently-used cache, so loading an image model does not evict the chat model. `max_loaded_models` can raise the per-type allowance (the documented example keeps two LLMs warm). AMD's developer article states the general claim as "run multiple models simultaneously, limited only by available RAM". The contributor walkthrough demonstrates four models (TTS, transcription, chat, image) loaded at once on a 24 GB discrete card, with the chat model's speed unchanged after the image model loaded — and also records the failure flavour: when models do not fit, the Windows driver spills part of the allocation to shared system memory and everything gets much slower *while still reporting as loaded*. That spill behaviour is a unified/shared-memory pathology our own corpus knows well (`memory/unified-memory.md` §1, point 4): residency without an explicit budget degrades silently instead of failing loudly. *[The four-model demonstration is a contributor's own test on their hardware, reported in a personal post — credible as an existence proof, not as a benchmark.]*


---

## 3. The NPU path

This is the section Lemonade exists for, and it is also the section where public writing — including some of AMD's own secondary coverage — most often blurs two different systems into one. There are **two distinct NPU paths** in Lemonade, with different runtimes, different model formats, different execution shapes, and different OS support. Keeping them apart is the dossier's main factual contribution.

### 3.1 The hardware gate

Both paths require an **AMD XDNA2 NPU**: Ryzen AI 300 series (Strix Point), Ryzen AI 400 series, Krackan/Kraken Point, and the Ryzen AI Max series (Strix Halo) are the families named across the sources. The XDNA2 NPU is rated at **50 TOPS** in the configuration in Strix Halo and Strix Point parts most often cited (some Ryzen AI marketing cites up to 60 TOPS for the architecture's top configuration — the discrepancy is a bin/configuration matter in the sources, not resolved by any primary document read here). **XDNA1 NPUs (Ryzen 7000/8000/200 series) are not supported** for LLM inference by either path; on those machines Lemonade falls back to GPU (Vulkan) or CPU. There is no Intel or Qualcomm NPU path in Lemonade at all — NPU in this product means AMD XDNA2, full stop.

### 3.2 Path one: FastFlowLM (`flm`) — the NPU as the whole computer

FastFlowLM is a dedicated inference runtime for XDNA2 NPUs, with an Ollama-shaped user experience (`flm run <model>`, `flm serve`, `flm pull`-style model management; inside Lemonade it appears as the `flm` recipe/backend). Its history matters for trust: it began as an **independent project**, was brought in by AMD in July 2026 (per trade-press reporting accessed 2026-11-15), and its repository now lives under AMD's **ROCm** organisation as `ROCm/FastFlowLM`, reaching version 1.0 in August 2026 and 1.0.12 by late October 2026. The runtime binary itself is small (~17 MB per the same reporting).

**Execution shape: NPU-only.** FastFlowLM runs the whole model — prefill, every layer, decode, LM head — on the NPU. It does **not** split work with the GPU. (This is the point secondary coverage most often gets wrong; see §3.4.) The value proposition is therefore not peak speed but **a second, independent accelerator**: the GPU stays free, power draw is low (the project claims better than tenfold power-efficiency advantage over GPU alternatives — *[vendor/project claim via trade press, not independently measured in sources read]*), and concurrent NPU+GPU operation is the intended deployment (§6.3).

**The artefact regime — this is a compiled-blob path.** FastFlowLM does not load GGUF. Its native model package (suffix **NPU2** in catalogue names) is a directory containing, per the community tooling documentation read for this dossier:

- `model.q4nx` — the weights in FastFlowLM's **Q4NX** format: 4-bit-quantised weights (the catalogue model cards list **Q4_1** quantisation for the Qwen3 family) packed for the NPU;
- `model.q4nx.xbin` — the **xclbin**: the compiled kernel binary for the XDNA2 device, i.e. the device-specific compiled artefact;
- `config.json`, `tokenizer.json`, `tokenizer_config.json`, and optionally a chat template — the metadata shell.

Three properties of this regime deserve emphasis, because they are exactly the properties the corpus's compiled-blob analysis predicts (`memory/npu-memory-and-dataflows.md` §6):

1. **The kernels are closed.** Community documentation states plainly that custom-converted models never ship their own xclbins "because they are closed source binaries; the kernel symlink always comes from the official model it matches." The underlying AMD/Xilinx NPU software stack (IRON, MLIR-AIE, RyzenAI-SW) is open source; FastFlowLM's model-execution layer on top of it is not. A converted model can only run if its architecture and size match an **officially shipped kernel set** — the catalogue is, in effect, the compiler's coverage list.
2. **Conversion is a vendor-side act.** Turning an arbitrary checkpoint into a Q4NX package requires AMD's converter (kept upstream in the AMD project); the community's tooling (`flm-add` and a community Q4NX converter) exists to *register pre-converted* packages and to convert within the envelope the official kernels allow. This is structurally identical to OpenVINO's NPU export and QNN's context-binary flow: quantise and compile first, run second, and only inside the shapes the compiler blesses.
3. **The NPU is a single-tenant device in practice.** A community packaging project for Strix Halo notes that FastFlowLM holds an **exclusive NPU lock** while a model is loaded — one NPU workload at a time. Combined with per-modality residency on the GPU side, the practical topology is: one NPU model resident, doing background-class work, while the GPU serves the foreground model.

**Catalogue and context limits, as documented.** The FastFlowLM model catalogue (fastflowlm.com model cards, accessed 2026-11-15) lists converted builds of the Qwen3 family (0.6B–8B at Q4_1), Qwen3-VL, Qwen2.5, Llama 3.x (1B/3B/8B class), Phi-4-mini, Gemma 3 and Gemma 4 families, DeepSeek-R1 distillations, gpt-oss builds, LFM2/LFM3, Whisper for transcription, embedding models, and — by the 1.0.x line — vision-language-action and semantic-router decision models. The pattern is unmistakable: **small-to-mid models, heavily weighted to ≤8B for pure NPU execution**, with larger MoE entries (e.g. a 35B-A3B) appearing where active parameters stay small. Context limits are **per model, not one number**: catalogue cards show maxima from 32k tokens (several Qwen3 NPU2 builds; LFM3-1.7B at 32k) through 64k (a tool-use build, 32k by default) up to **256k** on some entries (a 35B-A3B vision MoE lists 256k max / 32k default; the widely repeated "FastFlowLM supports up to 256k context" line traces to the 0.9.35-era documentation and describes the *ceiling across the catalogue*, not a guarantee for any given model). Newer "core"-backend entries describe **paged KV**: the runtime keeps the KV cache in 4096-token pages grown on demand, sends long prompts in `max_prefill_len` (4096-token) chunks, and packs weights on every load (no packed-weight cache beside the source file in that backend). *[The core-backend details come from FastFlowLM's own model-card documentation as crawled 2026-11-15; they describe a developer-preview backend beside the NPU2 line, and the two should not be conflated.]*

**Linux reality.** Linux NPU support via FastFlowLM shipped with Lemonade 10.0 in March 2026, and by the 11.0 line (July 2026) the FLM backend **auto-installs on Linux** instead of requiring manual setup, per release coverage. The independent Strix Halo field report (April 2026, §6.3) shows what "manual" meant just before that: enabling IOMMU passthrough, discovering the in-tree `amdxdna` driver could not bind to the shipped NPU firmware protocol, and **building the XDNA driver stack and XRT from AMD source** (DKMS module, four RPMs) before `flm validate` would pass. Lemonade's own Linux NPU documentation (referenced from the repo as `docs/flm_npu_linux.html` in code-index material) encodes the same prerequisites as a checklist: XDNA2 present (Strix Point / Strix Halo / Kraken Point named), NPU firmware ≥ 1.1.0.0, `amdxdna` driver active (kernel 7.0+ or the DKMS build), and a validation step (`run_flm_validate`) executed before any model load. The direction of travel is clearly toward turnkey; the distance already travelled on Windows is longer (§7.3).

### 3.3 Path two: Ryzen AI LLM (`ryzenai-llm`) — ONNX Runtime GenAI, NPU-only and hybrid

The second path is the older AMD stack, and it is where ONNX Runtime GenAI enters Lemonade. AMD's Ryzen AI software documentation (accessed 2026-11-15) describes the stack plainly: the Lemonade SDK's Python API and server interface are built **on top of** native ONNX Runtime GenAI (OGA) libraries or llama.cpp; OGA provides the NPU execution modes, llama.cpp provides GPU-only execution. Inside Lemonade this path is packaged as a separately downloaded backend server (`lemonade-sdk/ryzenai-server`, auto-downloaded on first use — the ~542 MB RyzenAI-Server v1.7.0 download in the hands-on test) requiring the Ryzen AI software installation (Ryzen AI 1.7.0 in the tested configuration).

OGA on Ryzen AI documents **three execution modes** (Ryzen AI LLM deployment overview, accessed 2026-11-15):

| Mode | Framework | Compute allocation | Documented purpose |
|---|---|---|---|
| NPU-only | ONNX Runtime GenAI | NPU exclusively, prefill and decode | Maximum NPU utilisation while preserving the GPU |
| Hybrid | ONNX Runtime GenAI | **Dynamic NPU + iGPU partitioning** | Interactive inference with optimal prefill/decode performance — AMD's own summary says hybrid mode "uses both the NPU and iGPU to achieve the best TTFT and TPS during the prefill and decode phases" |
| NPU (FastFlowLM) | FastFlowLM | NPU | The out-of-box, NPU-first runtime (§3.2), listed by AMD as a peer mode |
| GPU | llama.cpp | Dedicated GPU execution | High-throughput generation |

**The artefact regime is ONNX, with the same compiled-shape character.** Hybrid/NPU models are published by AMD on Hugging Face under the `amd` organisation (e.g. `amd/Phi-4-mini-instruct-onnx-ryzenai-1.7-hybrid`; a Phi-3.5-mini build carries the full dialect in its name: AWQ, group-128, INT4, asymmetric, BF16/FP16 activations, `ryzen-strix`). Models are **version-locked to the Ryzen AI release**: the Ryzen AI 1.6 release notes warn that hybrid models published with earlier releases are **not compatible** with 1.6 and must be replaced with the 1.6 builds. Context in this path has historically been tight — the 1.6 notes celebrate an improvement "from 2K to 4K" for hybrid models — orders of magnitude below the FastFlowLM catalogue's headline numbers, and a concrete illustration that "context support" in a compiled regime is a property of each compiled artefact, not of the runtime. *[The 2K→4K figure is from the Ryzen AI 1.6 release notes (Nov 2025) as crawled; later releases may have raised it — no higher hybrid-context figure was verified in a primary AMD source for this dossier, and the gap is flagged rather than filled.]*

**OS limit: Windows only.** Every source that breaks out OS support for `ryzenai-llm` lists Windows alone. On Linux, Lemonade's NPU story is FastFlowLM or nothing. The hybrid execution mode — the most architecturally interesting NPU feature in the whole product — is therefore, as documented in late 2026, a **Windows feature**.

### 3.4 Untangling "hybrid": three claims, only one mechanism

Secondary writing about Lemonade repeatedly states a clean story: *"prefill runs on the NPU, decode runs on the GPU."* Read against the primary documentation, that sentence is:

- **True** as a description of the **OGA hybrid mode** (§3.3): dynamic NPU+iGPU partitioning explicitly aimed at best time-to-first-token (prefill) and best tokens-per-second (decode). AMD's Ryzen AI documentation is the source, and the mechanism belongs to ONNX Runtime GenAI, not to Lemonade itself.
- **False** as a description of **FastFlowLM** (§3.2), which executes the entire model on the NPU. When a review attributes the prefill/decode split to "the FastFlowLM backend", it has merged the two paths.
- **Misleading** as a description of **Lemonade-the-server**, which does not itself split anything: it *routes whole models* to engines, and the splitting (where it exists) happens inside one of those engines.

The distinction is not pedantry. A Go runner copying "Lemonade's hybrid trick" needs to know the trick lives in a vendor's ONNX execution provider with per-model compiled artefacts — it is not a scheduling policy a router can adopt for arbitrary GGUF models (§8.4).

A second, independent hands-on data point keeps the hybrid claim honest: the EVO-X2 tester who ran `Qwen3-8B-Hybrid` (AWQ ONNX, via the Ryzen AI server) measured **0.44 s time-to-first-token and 24.0 tokens/s** generation — TTFT notably fast, decode well below what the same machine's GPU achieves on much larger models (§6.2). Hybrid buys startup latency, not throughput. That is consistent with AMD's own framing (best TTFT *and* TPS *for that execution mode's class*), and inconsistent with any reading of hybrid as a free lunch.

### 3.5 The licence and openness boundary, stated once

- Lemonade server/CLI/apps: **Apache 2.0** (verified, header).
- llama.cpp / whisper.cpp / stable-diffusion.cpp / Kokoro backends: open source under their own licences, downloaded as separate builds.
- FastFlowLM: the orchestration code and CLI are reported as **MIT** in trade-press coverage of the 1.0 release, which also reports the NPU-accelerated binary kernels as "free for any use including commercial". An earlier independent overview reported the kernels as proprietary binaries where "non-commercial use is free". **These two characterisations conflict on the commercial term**, and no primary licence text for the kernel binaries was read for this dossier. What is *not* in dispute across any source: the kernel binaries (xclbins) are **closed, precompiled, and shipped only for officially supported models**. For planning purposes our runner should treat the NPU kernel layer as a **closed vendor dependency with unverified commercial terms** until the licence text itself is read. *[Flagged unverifiable — see the report note.]*
- Ryzen AI / OGA path: ONNX Runtime GenAI is MIT (see `runners/onnx-runtime-genai.md`), but the Ryzen AI software stack, its execution provider and its published hybrid models carry AMD's own terms and release-locking (§3.3).

---

## 4. Strix Halo / Ryzen AI Max support

### 4.1 What AMD claims, in AMD's own Lemonade material

AMD's principal Lemonade article (Ryzen AI and Radeon article, published 2025-11-13, updated Oct 2026; accessed 2026-11-15) places Strix Halo in a four-row device table: **Ryzen AI Max+ 395, NPU + integrated GPU, 64–128 GB RAM, ROCm backend, scenario "on-device chatbot"**. Its Strix Halo showcase is capacity, stated in full:

- The 128 GB Max+ 395 runs models "from compact 1B parameter models to large-scale systems like Mistral Large", using llama.cpp with flexible GGUF quantisation.
- The worked example is **Meta's Llama 4 Scout 109B** — a mixture-of-experts model with **17B active parameters** — whose full 109B must reside in memory, "making the Ryzen AI Max+ 395's 128 GB RAM essential". Vision and MCP support are noted; Open WebUI is the suggested front end.
- The same article's mid-tier showcase, Qwen3-Coder-30B, is listed for Radeon *and* Strix Halo — a ~30B coding model as the halo machine's "demanding but normal" workload.

AMD's unified-API developer article (Feb 2026, accessed 2026-11-15) adds the platform claims in general form: automatic configuration of NPU/GPU/CPU backends per computer, multiple models simultaneously "limited only by available RAM", and thorough testing/optimisation for AMD hardware as the backing vendor's promise. A later AMD product blog (Muse Glimmer 30B, Aug 2026 testing, accessed 2026-11-15) positions Lemonade as the *integration* path for a new 30B model on Max+ systems — "bringing the model into an application through a local, OpenAI-compatible API delivered through an embeddable binary" of approximately 4 MB — with the performance numbers themselves measured in llama.cpp, not in Lemonade (§6.1).

Secondary AMD-ecosystem material (not the Lemonade articles themselves) adds the familiar platform figures: up to **96 GB of the 128 GB pool assignable to the GPU**, and driver support (Adrenalin 25.8.1+) for models up to **128B parameters at 4-bit on Windows** (FP16 topping out around 32B). Both are consistent with the unified-memory dossier's account of the GTT/mapping budget (`memory/unified-memory.md` §2.2) and are cited here as *reported platform properties*, not as Lemonade documentation.

### 4.2 What AMD does *not* claim — the bandwidth silence

Read the two AMD Lemonade articles for a bandwidth number, a tokens-per-second number, or a memory-clock figure. **There are none.** AMD's public Lemonade case for Strix Halo is built entirely from:

1. **capacity** (128 GB; 109B resident),
2. **compatibility** (one installer; OpenAI API; every modality), and
3. **presence** (NPU + iGPU + CPU all usable through one server).

That silence is itself evidence, and it points the same way as the corpus's unified-memory dossier: on a **256-bit LPDDR5X-8000** interface the theoretical ceiling is

```
8,000 MT/s × 32 bytes = 256 GB/s theoretical  (~215 GB/s reported sustained)
```

(arithmetic as in `memory/unified-memory.md` §2.1; the ~215 GB/s sustained figure is secondary-reported, not AMD-published). Decode of a dense model reads its resident weights once per token, so the ceiling on generation is approximately `bandwidth ÷ weight bytes`:

| Model class (4-bit, dense unless noted) | Resident weights (approx.) | Ceiling at 256 GB/s | Ceiling at ~215 GB/s | What is actually reported (§6) |
|---|---|---|---|---|
| 8B dense | ~5 GB | ~51 tok/s | ~43 tok/s | iGPU 48–61 tok/s class figures for 8B models sit *at/above* the naive sustained ceiling — see note below |
| 30B dense | ~17–19 GB | ~13–15 tok/s | ~11–13 tok/s | Dense ~27B at Q4 reported 11–12 tok/s — **respects the ceiling** |
| 70B dense | ~40–43 GB | ~6 tok/s | ~5 tok/s | 4.7–4.9 tok/s measured — **respects the ceiling**, at ~75–80% of theoretical |
| 109–120B MoE (17B / ~5B active) | ~60–70 GB resident, only active experts read per token | set by *active* bytes, not resident bytes | — | ~50–56 tok/s — **respects the ceiling** once active parameters are the denominator |

*[Our arithmetic, from the corpus's roofline method (`memory/memory-wall-and-roofline.md`). Weight sizes are the commonly reported file sizes for the named quantisations in the sources read; treat the table as order-of-magnitude engineering, not measurement. The 8B row's apparent excess over the sustained ceiling is a known artefact of mixing sources: the 48–61 tok/s figures come from a secondary roundup without per-test quantisation/KV detail, and small-model decode also benefits from cache residency of parts of the working set; we report the tension rather than smoothing it.]*

**Reading, stated plainly:** every *independently measured* Strix Halo number found for this dossier respects the 256 GB/s ceiling, and the dense-model numbers respect it tightly — which is what a bandwidth-bound machine looks like. AMD's Lemonade marketing respects it too, but by **omission and by example selection**: the showcase models are a MoE whose active footprint is 17B (Scout 109B) and a 30B coder — never a dense 70B, whose ~5 tok/s would tell the bandwidth story out loud. The one AMD-published Strix Halo *speed* number in the sources read (Muse Glimmer 30B, up to 24 tok/s, §6.1) exceeds the naive dense-30B ceiling of ~13–15 tok/s — and its own footnote discloses why: it was measured with **speculative decoding enabled** (dFlash), which amortises each weight read over several accepted tokens. That is a legitimate technique and an honestly footnoted claim; it is not a bandwidth violation, and it must not be quoted without its footnote.

### 4.3 The fleet relevance, without varnish

For Volmarr's Z13 specifically, Lemonade's documented Strix Halo support means: the vendor's own server treats gfx1151 as a first-class ROCm target (it is literally in the ROCm support matrix), the NPU in the machine is addressable by two different runtimes, and the 128 GB pool is the product's headline scenario. It also means the machine inherits every UMA pathology the corpus has already documented first-hand — BIOS carve-out versus GTT budget fights, Vulkan shared-memory spill under driver 26.3.1 (§6.2), and backend *detection* failing on UMA hardware (§7.2) — because Lemonade sits on top of the same driver stack, not above it. Vendor reference does not mean vendor immunity.


---

## 5. Model management and the developer SDK angle

### 5.1 Catalogue, pull, and the three format universes

Model management mirrors Ollama's ergonomics deliberately:

- **CLI:** `lemonade list` (installed/available), `lemonade pull <model>`, `lemonade run <model>` (pull-load-chat in one motion), delete operations alongside. Model names are catalogue names with the format baked in — e.g. `Gemma-4-E2B-it-GGUF`, `Qwen3-8B-Hybrid`, `Whisper-Large-v3-Turbo`, `kokoro-v1`, `SDXL-Turbo` — so the name itself tells the recipe which engine will serve it.
- **Built-in catalogue / registry:** a curated model library browsable in the Model Manager (web/desktop) and listable from the CLI, spanning GGUF, FLM and ONNX builds across all modalities. New models land in the catalogue by release (release coverage shows catalogue additions as headline features, e.g. a 30B GGUF added in the 11.6 line).
- **Bring-your-own from the Hub:** any GGUF repository on Hugging Face can be pulled by name with an optional quantisation tag (`lemonade pull unsloth/gpt-oss-20b-GGUF:Q4_K_M` in the contributor walkthrough), and ModelScope is a second documented source. **Source is retained** for custom pulls, so future updates can re-check the origin. Lemonade appears in Hugging Face's own "Use this model" menu beside llama.cpp, Ollama, vLLM and SGLang, and Hub pages for `ryzenai-npu` / `ryzenai-hybrid`-tagged models generate Lemonade commands directly.
- **Shared cache:** models are stored in the **standard Hugging Face cache layout** and Lemonade honours `HF_HOME` / `HF_HUB_CACHE` — a model another Hub tool already downloaded is not downloaded again. This is a small decision with large goodwill and disk consequences, and it contrasts with runners that keep a private store.
- **Quantisation choice is catalogue-mediated, and that cuts both ways.** `lemonade pull` delivers the catalogue's chosen build; the EVO-X2 tester records that pulling a 35B GGUF delivered **Q4_K_XL only, with no way to specify Q6_K or Q8_0** through the pull path, and that using a custom GGUF required a custom-path procedure they found under-documented. The Hub-pull route (with explicit `:Q4_K_M`-style tags) partially answers this in later versions, but the default experience trades Ollama-style quant browsing for vendor-chosen defaults. *[Single-tester report on v10.0.1; later behaviour may differ — flagged as versioned evidence.]*

The structural point for our corpus: Lemonade manages **three parallel model universes** (GGUF for llama.cpp, Q4NX packages for FastFlowLM, release-locked ONNX builds for Ryzen AI) behind one list/pull/run surface. The surface hides the fragmentation from casual users and cannot hide it from anyone who asks "why is this model NPU-only / Windows-only / unavailable at the quant I want" — the answer is always a property of which universe the model was built for.

### 5.2 The CLI as an agent launcher

A documented, distinctive behaviour: `lemonade launch claude` (and equivalents for other coding agents — Codex, OpenCode, Pi and Junie are named in the contributor walkthrough) loads a chosen local model, points the agent at the local Anthropic-compatible endpoint, and starts it, with pass-through for the agent's own arguments. Aider additionally has a native `lemonade/` provider prefix via LiteLLM, and Continue lists Lemonade as a provider, per the coding-tools coverage read for this dossier. In effect the runner ships **first-party adapters for the agent ecosystem** rather than waiting for each agent to add it. For a Go runner competing for the same desktop, this is a distribution lesson, not just a feature (§8.6).

### 5.3 Embeddable Lemonade and the Python SDK — the "backend for other apps" posture

Lemonade is explicitly offered in **two flavours** (README, accessed 2026-11-15):

1. **Lemonade Server** — the installed service described in §2.
2. **Embeddable Lemonade** — "a portable binary you can package into your own application to give it multi-modal local AI that auto-optimizes for your user's PC", run as a subprocess (`lemond ./` in the embeddable guide's shape), with **zero Lemonade installers, branding, or telemetry** in the host product. Release notes ship per-OS embeddable archives beside the server installers (Windows x64 zip, Ubuntu x64 tarball, and siblings). AMD's Glimmer blog quantifies the embeddable binary at **approximately 4 MB** *[vendor figure]* — the engines and models are still downloaded on demand; 4 MB is the router, not the stack.

Alongside it, the **Python SDK** (`lemonade-sdk` on PyPI) offers the high-level API documented in AMD's Ryzen AI docs: install the package plus a backend extra (the documented example: `pip install lemonade-sdk[llm-oga-hybrid]` followed by a `lemonade-install --ryzenai hybrid` step), then load models through a `from_pretrained`-style call naming a Hub model id, or drive the server through its REST interface from any language. AMD's own application examples (the Morphik AI document assistant in the Lemonade article) are third-party apps built on exactly this posture.

**Assessment:** this is Lemonade's most strategically distinctive decision. Ollama also became an embed-by-daemon in practice, but Lemonade *products* the embedding: a named artefact, a guide, a no-branding/no-telemetry promise, and a vendor blog that sells "turn a model from an agent you run into an application feature". The runner is positioned as **infrastructure other developers ship**, with the end-user server as its showcase. §8.5 prices this idea for our Go runner.

### 5.4 Installation surface

Documented routes (README + contributor walkthrough + reviews, accessed 2026-11-15): Windows MSI (also `winget install AMD.LemonadeServer`; stable Windows installers are code-signed, release candidates are not), macOS `.pkg`, Ubuntu PPA (`ppa:lemonade-team/stable`) and Snap, Debian `.deb`, Fedora `.rpm`, Arch package, Docker/OCI image (`ghcr.io/lemonade-sdk/lemonade-server`), and the Python package for the SDK. The spread is genuinely broad — broader than most runners in this corpus — with the caveat in §7.3 about which routes carry the full (NPU-inclusive) stack.

---

## 6. Performance character

All numbers below carry their provenance. **Vendor numbers are AMD's, measured by AMD, on AMD-chosen configurations, and are labelled as such. Independent numbers are labelled with their tester and hardware. Nothing in this section was measured by us.**

### 6.1 Vendor numbers (AMD-published)

AMD's Lemonade articles proper publish **no throughput numbers at all** (§4.2) — the only AMD-published speed figures found in Lemonade-adjacent material are:

- **Muse Glimmer 30B (dense, preliminary model build), llama.cpp Vulkan + dFlash speculative decoding, Windows:** up to **24 tokens/s** on Ryzen AI Max+ 395 (128 GB, Variable Graphics Memory set to 64 GB, GMKtec EVO X2, Adrenalin 26.7.1) and up to **53 tokens/s** on a single Radeon AI PRO R9700. *[Vendor claim, AMD testing Aug 2026, footnotes SHO-77 / RPW-537 in the original; "up to", average generation throughput over ≥3 runs, speculative decoding on — quote only with those conditions. The workload is llama.cpp; Lemonade is the integration path in that article, not the measured engine.]*
- **Hybrid-mode qualitative claim:** AMD's Ryzen AI documentation claims hybrid (OGA) execution achieves "the best TTFT and TPS during the prefill and decode phases" among its execution modes. No figures accompany the claim in the material read.
- **Second-hand vendor figures** (reported by secondary guides, **not** verified in an AMD primary source for this dossier, and recorded here only so they are not mistaken for independent measurements): NPU time-to-first-token **2.3× faster** than GPU-only on Ryzen AI 300-series; a Llama 3.2-3B on NPU at ~28 tokens/s at under 2 W; FastFlowLM project claims of >10× power-efficiency advantage. *[Treat all three as unverified vendor-origin claims.]*

### 6.2 Independent numbers: through-Lemonade overhead, and Vulkan vs ROCm

The most useful independent Lemonade-specific testing found is the EVO-X2 series (GMKtec EVO-X2, Ryzen AI Max+ 395 / Radeon 8060S gfx1151, 64 GB UMA, Lemonade v10.0.1 with bundled llama.cpp b8460, AMD driver 26.3.1; accessed 2026-11-15):

- **Router overhead ≈ zero.** Qwen3.5-35B-A3B through Lemonade (Q4_K_XL, ctx 4096): **57.9 tok/s**, versus direct llama-server runs at 53.7 (Q6_K) and 54.9 (Q4_K_M) tok/s under different quantisations — the tester explicitly declines to claim a Lemonade speed *advantage* (quantisations differ) and concludes the developer claim of "equivalent to raw llama.cpp" holds: the router is a proxy, inference is llama-server's.
- **With tuned pass-through args** (`--cache-type-k/v q8_0 --no-mmap`, ctx 65536): **63.5 tok/s** on the same model family — the headroom is in llama.cpp configuration, reachable through Lemonade's override path.
- **Vulkan vs ROCm on the same machine (48 GB VRAM / 16 GB system BIOS split):** Vulkan (mmap) **46 tok/s** with 7.1 GB spilled into shared memory and only 0.8 GB system RAM remaining; ROCm **37.8 tok/s** with 3.3 GB shared and 6.7 GB remaining. Vulkan is ~18% faster and, on this driver, memory-sick; ROCm is slower and stable, and is the tester's recommendation for multi-model operation. The shared-memory spill is attributed to Vulkan's memory placement under driver 26.3.1 specifically — a driver-pathology data point, not a Lemonade defect, but Lemonade users meet it *through* Lemonade's default Vulkan path.
- **Four models at once (ROCm):** 35B LLM + Whisper-Small (NPU) + Kokoro TTS + Flux image model concurrently: LLM held **37.7 tok/s** (vs 37.8 solo), ~10 GB VRAM and ~5 GB system RAM to spare. The omni-modal residency claim (§2.5) survived contact with hardware in this test.
- **NPU hybrid (same tester):** Qwen3-8B-Hybrid, §3.4 — 0.44 s TTFT, 24.0 tok/s.

A matched-protocol Vulkan-vs-ROCm study on the same chip class (independent, llama.cpp direct, Qwen3-Coder-30B-A3B Q4_K_S; accessed 2026-11-15) corroborates the split personality: ROCm ~21% faster at prompt processing (1,345 vs 1,115 tok/s at 512 tokens), Vulkan ~25% faster at generation (97.7 vs 73.7 tok/s); on a 122B MoE the pattern repeats (ROCm prefill 340–523 tok/s vs Vulkan 285–374; generation 21.3 vs 22.9 tok/s). **Backend choice on Strix Halo is a workload choice** — prefill-heavy (long prompts, short answers, RAG) favours ROCm; decode-heavy (chat, codegen) favours Vulkan — which is precisely why a router that picks per model *and exposes the override* is the right architecture, and why any single-default benchmark of "Lemonade speed" is meaningless without its backend named.

### 6.3 Independent numbers: the NPU measured against the GPU

The Strix Halo NPU field report (independent, April 2026, Fedora, FastFlowLM built from source; accessed 2026-11-15) is the only end-to-end NPU-vs-GPU comparison on the exact Z13-class hardware found for this dossier:

| Test | NPU (FastFlowLM) | iGPU (llama.cpp Vulkan) | Reading |
|---|---|---|---|
| Llama-3.2-1B decode | **39.5 tok/s** (TTFT 0.65 s; prefill 83.6 tok/s) | — | Respectable for a 1B on a low-power block |
| ~8B head-to-head: TTFT | **2.22 s** (Qwen3-8B) | 5.12 s (Qwen3.5-9B) | NPU ~2.3× faster to first token (tester notes GPU figure is inflated by the model's thinking-mode overhead) |
| ~8B head-to-head: decode | 8.2 tok/s | **19.7 tok/s** | GPU ~2.4× faster sustained |
| Concurrent NPU+GPU (same models, interleaved) | decode −5.8%, TTFT +14.9% | decode −14.1%, TTFT +18.7% | **1.42× wall-time speedup** vs sequential; NPU barely notices contention (own execution pipeline), GPU pays the shared LPDDR5X bus |
| Whisper-Large-v3-Turbo | short audio 0.78 s (**9.8× realtime**); long audio 2.33 s | 0.93 s / 1.87 s | NPU wins short, GPU wins long, both 15–26× faster than CPU |

The tester's conclusion is the correct engineering summary of the whole NPU proposition: **the NPU's value is not speed, it is a second, contention-free worker.** Background agent tasks (summarisation, extraction, classification, transcription) were re-routed to a 4B NPU model in their production setup precisely so they stopped competing with the foreground GPU model. Community Strix Halo llama.cpp figures (Strix Halo Guide log, via secondary roundups) fill in the GPU-side context on 128 GB machines: gpt-oss-120B (MXFP4) ~55–56 tok/s, Qwen3.6-35B-A3B ~62.6 tok/s (Vulkan), dense Llama 3.1 70B Q4_K_M **4.7–4.9 tok/s** — the bandwidth ceiling of §4.2 made visible.

### 6.4 Character, in one paragraph

Lemonade adds no measurable overhead to the engines it orchestrates; its performance *is* its backends' performance, plus the quality of its routing defaults. On AMD hardware those defaults are well-chosen for the common case (Vulkan for portable GPU decode, ROCm where its prefill/stability wins, NPU for small resident models), and the pass-through of engine flags preserves the expert's headroom. The honest limits are the platform's, not the server's: LPDDR5X bandwidth caps dense-model decode on Strix Halo regardless of who serves it, and the NPU is a low-power sprinter for TTFT and background work, not a throughput engine.

---

## 7. Strengths and weaknesses

### 7.1 Strengths

1. **The only shipping NPU path in the mainstream local-runner field.** Two of them, in fact (§3). Whatever their limits, they run today on hardware our fleet owns, while every other runner in this corpus leaves the XDNA2 block idle.
2. **Routing without confiscation.** Per-model recipes, runtime hardware detection, on-demand engine installation — *and* documented pass-through of engine-native flags. Abstraction with an escape hatch is the correct shape (§2.3).
3. **API breadth as compatibility strategy.** OpenAI + Anthropic + Ollama dialects on one port, plus MCP and Realtime surfaces, means existing tools — including Ollama-only tools and Claude Code — work unmodified. Each dialect is cheap; the sum is a moat.
4. **Omni-modal residency that demonstrably works.** Per-modality LRU with simultaneous LLM+ASR+TTS+image operation verified independently (§6.2), where competitors typically require separate servers per modality.
5. **Vendor backing with community form.** AMD engineers contribute optimisations for Ryzen AI/Radeon/Strix Halo; the project is Apache 2.0, community-maintained in the open, ~5,700 GitHub stars by September 2026 (review figure), and present in Hugging Face's own model menu. The ROCm/Vulkan/NPU setup pain it absorbs is real, recurring, and previously borne by every user individually.
6. **The embeddable posture** (§5.3): a named, documented, no-branding binary for other apps to ship — a distribution channel most runners never build.
7. **Cross-vendor in practice, not just in principle.** The same server now runs on NVIDIA (CUDA), Intel (Vulkan), Apple Silicon (Metal) and ARM64 — reviewers document genuinely preferring one control plane across mixed fleets, accepting a small peak-throughput trade for portability. AMD built its own-hardware showcase and accidentally built a credible neutral server.

### 7.2 Weaknesses

1. **Youth, and the churn that comes with it.** The release cadence is weekly-class with **breaking changes sections in the notes** (a late-2026 review counts 411 open issues and a failing main-branch build badge at review time; August 2026 saw three releases in two weeks, one existing mainly to fix its predecessor). Ollama's ecosystem — model library breadth, third-party integrations, sheer operational folklore — is years deeper. Lemonade's own backend builds **lag upstream engines**, per community reports: a brand-new model architecture may need a hand-built llama.cpp before Lemonade can serve it.
2. **Management-layer bugs on exactly our hardware.** The v10.0.1 EVO-X2 test found: the router proxy not answering chat requests at all in that configuration; `lemonade recipes` returning 500 errors because **backend detection failed to recognise the Radeon 8060S** — the tester attributes this to discrete-GPU detection logic meeting a UMA APU, i.e. Lemonade's hardware inventory mis-reading the flagship platform it exists to serve; and NPU detection itself flipping with BIOS memory-split settings. *[Versioned evidence (v10.0.1, driver 26.3.1); later versions may have fixed each item. The class of bug — detection logic assuming discrete-GPU topology — is the durable lesson.]*
3. **The NPU's fine print.** Closed kernel binaries with conflicting public licence characterisations (§3.5); a curated catalogue instead of arbitrary models; an exclusive NPU lock; the hybrid mode confined to Windows and to release-locked ONNX builds with historically small contexts (§3.3); Linux NPU setup that, until the recent auto-install work, required building a driver stack from source (§3.2). The NPU path is real and simultaneously the most fragile, most encumbered path in the product.
4. **Defaults that can hurt.** Catalogue pulls that fix the quantisation (§5.1); Vulkan as default GPU path on a driver generation with a shared-memory spill pathology (§6.2); authentication off by default with no repository security policy at review time (§2.2). Each is defensible alone; together they mean the careful operator still has homework.
5. **Two model universes' worth of fragmentation, owned.** GGUF users, FLM users and ONNX-hybrid users of the *same server* share almost no artefacts. When a model exists in only one universe, its hardware/OS support is that universe's — a support matrix users experience as arbitrary ("this 8B runs on the NPU on Windows but not Linux; that one runs everywhere but only on GPU") because, structurally, it is.
6. **Documentation drift.** Port numbers, CLI names (`lemonade-server` → `lemonade`; `recipes` → `backends`), base-URL shapes (`/v1` vs `/api/v1`) and version schemes all changed across the sources read — sometimes within a single review's own citations. Fast-moving projects tax their own documentation; Lemonade is currently paying that tax visibly.

### 7.3 The platform posture: Windows-first, honestly reassessed

The historical shape is unambiguous: Lemonade grew out of AMD's Ryzen AI software stack, which is a **Windows stack** — the OGA hybrid path, the one-click installer story, the Ryzen AI driver ecosystem, and the first NPU support all landed on Windows first, and the hybrid engine remains Windows-only. Early Linux support meant GPU-only (Vulkan/ROCm) with the NPU dark.

The late-2026 state is materially better and should not be described with the old sentence: Linux gained NPU support via FastFlowLM in March 2026 (10.0), auto-installation of that backend by July 2026 (11.0), first-class packages for five Linux routes, and an experimental vLLM backend that is Linux-only and Strix Halo-specific. macOS went from absent to a Metal backend in 11.0. The accurate current statement is: **Windows is the reference platform where every feature exists; Linux is a full citizen for GPU work and a recent, still-hardening citizen for NPU work; macOS is a GPU-only newcomer.** For a fleet whose Strix Halo machine runs Linux (our Z13 runs Kubuntu), the practical consequence is that the single most interesting Lemonade feature (hybrid) is unavailable and the second (FLM NPU) is the newest code in the product. *[Assessment synthesised from the OS columns of the documented backend matrices and the dated release evidence above.]*

---

## 8. Ideas to steal for a Go runner

Each idea is stated with its gain and its cost/risk, priced for Yrsa's improved Ollama in Go specifically.

### 8.1 The recipe: bind the execution plan to the model, not to the request

**Steal:** a per-model recipe record — engine, backend flavour, format, device class, default context policy — resolved once at registration/pull time and stored with the model. Requests name a model; the recipe routes.
**Gain:** routing becomes data, not code paths; adding a backend is adding recipes, not surgery; per-model quirks (this build needs ROCm, that one needs `--no-mmap`) live in one auditable place; the Ollama-compatible surface stays clean because dialect handlers never make hardware decisions.
**Cost/risk:** recipe registries rot — Lemonade's catalogue-mediated defaults (§5.1) show the failure mode where the registry's choice replaces the user's. Mitigation: recipes must be *overridable in the open* (user config beats catalogue beats auto-detection, in that precedence, always logged).

### 8.2 Hardware detection as a first-class, inspectable setup step

**Steal:** a `backends`-style command and a startup validation pass that enumerate, in plain language: devices found, driver/firmware versions, which backends are therefore available, which are installable, and *why* any expected device is missing (the FastFlowLM validation checklist — device present, firmware floor, driver active — is the model).
**Gain:** the single largest support burden in local inference is "it silently used the CPU". Detection-as-a-surface converts silent wrongness into a readable verdict before the first token; it is also the natural place to enforce our fleet's hard lessons (UMA budget checks, freshly-booted-machine restraint) at startup.
**Cost/risk:** detection logic is itself a bug farm — Lemonade's UMA mis-detection (§7.2) happened in exactly this layer, on its own flagship hardware. Budget for detection to be *wrong sometimes*: it must degrade to "device usable via engine's own probing" rather than "device declared absent", and its output must be versioned and loggable for bug reports.

### 8.3 Multi-backend routing behind one API — with subprocess isolation

**Steal:** the supervisor shape: one daemon, engines as child processes with their own ports/lifetimes, the daemon as router + lifecycle manager + health checker. In Go this maps naturally (process supervision, context-cancellable children, a small internal registry), and it lets the runner wrap llama.cpp-class engines *today* while keeping the door open to native engines later.
**Gain:** crash isolation (documented Lemonade property), independent engine upgrades, per-engine resource accounting, and the freedom to ship a Vulkan build and a ROCm build side by side instead of choosing at compile time.
**Cost/risk:** you inherit every child's operational surface — port collisions, zombie processes, version skew between router and engine builds (Lemonade's bundled-llama.cpp lag, §7.2, is this cost made visible). The router must pin and record exact engine builds per release, and "equivalent to raw engine" overhead must be *tested*, as Lemonade's testers tested it, not assumed.

### 8.4 A bounded NPU compiled path — entered with eyes open

**Steal, in bounded form:** a curated fast path for a small set of popular small models, compiled per NPU family (on AMD: via FastFlowLM's catalogue; architecturally: the compiled-blob pattern of `memory/npu-memory-and-dataflows.md` §6), offered for **background-class work** — summarisation, classification, transcription, short-TTFT assistants — while the GPU path remains the product. The independent evidence (§6.3) says this is where the NPU actually pays: not throughput, but a second worker that does not contend.
**Gain:** use of silicon every competitor leaves idle; concurrent NPU+GPU operation measured at 1.42× wall-time on interleaved agent workloads; low-power always-on assistance on laptops.
**Cost/risk:** the full compiled-blob bill — per-model × per-device compilation, closed vendor kernels with licence terms to verify *from the licence text* before any commercial shipment (§3.5), static context buckets, catalogue-as-coverage support burden, exclusive-device locking, and (on AMD/Linux) a young driver stack. Enter through **one** vendor stack and **one** model family, with coverage criteria written down, or do not enter. And never market the catalogue as the hardware's capability — the corpus's Possibility Law discipline (§6 of the NPU dossier) applies to our own claims first.

### 8.5 The prefill/decode split — steal the *measurement*, not the mechanism

**Do not steal directly:** OGA-style hybrid execution is a vendor execution-provider mechanism over per-model compiled ONNX artefacts (§3.4); a GGUF router cannot adopt it as a policy.
**Steal instead:** the *phase-aware routing mindset* it proves out — prefill and decode have different physics (compute-bound vs bandwidth-bound), different backends win each phase even *within* the GPU (§6.2: ROCm prefill, Vulkan decode), and time-to-first-token is a separate product metric from tokens-per-second. A Go runner can act on this today without any NPU: expose TTFT and decode rate separately in its API and benchmarks, choose GPU backend defaults by workload class, and evaluate speculative decoding (the honest mechanism behind AMD's one big Strix Halo number, §4.2) as the decode-side lever.
**Cost/risk:** phase-aware defaults complicate the support story ("why is my long-prompt job on a different backend than my chat?") — answer with §8.2's inspectability, not with silence.

### 8.6 Ship the adapters: agent launchers and dialect breadth as distribution

**Steal:** (a) simultaneous OpenAI + Anthropic + Ollama dialects on one port; (b) first-party `launch`-style commands for the major coding agents; (c) presence in the ecosystems' own menus (Hub "Use this model", Continue's provider list, Aider's provider prefixes).
**Gain:** every existing tool becomes a client without negotiation; the Anthropic dialect in particular converts Claude Code — the agent our own fleet uses daily — into a local-model front end. Distribution through other tools' menus is worth more than any single feature.
**Cost/risk:** each dialect is a compatibility surface that drifts (Anthropic's message format and Ollama's API both evolve); dialect handlers must be thin translations over one internal request model, with contract tests per dialect, or the three surfaces become three products.

### 8.7 Per-modality residency with an explicit memory budget

**Steal:** Lemonade's per-type LRU residency (one warm model per modality by default, raisable per type) — **corrected by our own UMA law**: residency decisions must be made against an explicit, user-visible memory budget for the whole pool, with eviction *before* allocation crosses it, because on unified memory the alternative to eviction is not an error, it is a system-wide OOM or a silent shared-memory spill (§2.5, `memory/unified-memory.md` §1).
**Gain:** the omni-modal single-server experience (chat + transcription + TTS + image without reloads) is a genuine product differentiator, independently verified as workable (§6.2).
**Cost/risk:** multi-model residency multiplies every other risk in this list (more engines warm, more driver paths live, more memory pinned). The budget must count *all* resident engines together — per-modality caches that each assume they own the machine will, together, take the machine.

### 8.8 The embeddable posture: design the runner to be shipped *inside* other apps

**Steal:** a named embeddable artefact — the daemon as a subprocess with a documented lifecycle, no branding, no telemetry, a stable local API — offered from the start, not retrofitted. Pair it with the shared-cache courtesy (§5.1: honour the standard Hub cache instead of a private store) so embedding apps and standalone use reinforce rather than duplicate each other.
**Gain:** the runner becomes infrastructure; other developers' products become its distribution; AMD's own application examples show vendors and indie apps both taking this path. For a Go runner the fit is unusually good: a single static binary is a better embeddable artefact than a C++ daemon plus on-demand engine downloads.
**Cost/risk:** embedders freeze your API — the management surface becomes a public contract with versioning obligations — and "no telemetry" plus "auto-downloads engines/models on first use" is a combination host apps must be able to govern (offline enterprise hosts will demand pre-seeded artefacts). Design the download/seeding story for embedders explicitly, or the posture is a slogan.

---

## 9. Sources

All sources accessed **2026-11-15**. Vendor sources are AMD's; independent sources are labelled. Where a claim in this dossier rests on a single secondary source, the text says so at the claim.

**Primary / vendor**

- AMD, "Ryzen AI and Radeon are ready to run LLMs Locally with Lemonade Software", amd.com developer technical article. Published 2025-11-13; updated 2026-10-06. Device table (Strix Halo: Max+ 395, 64–128 GB, ROCm), Llama 4 Scout 109B on 128 GB, Qwen3-Coder-30B scenarios, OpenAI-API positioning. https://www.amd.com/en/developer/resources/technical-articles/2025/ryzen-ai-radeon-llms-with-lemonade.html
- AMD, "Lemonade by AMD: A Unified API for Local AI Developers", amd.com developer technical article. Published 2026-02-10. C++ implementation, automatic backend configuration, multi-model claim, engine list, desktop app, ecosystem integrations. https://www.amd.com/en/developer/resources/technical-articles/2026/lemonade-for-local-ai.html
- AMD, "Run Meta Muse Glimmer 30B on AMD Ryzen AI Max Agentic PCs and Radeon GPUs", amd.com blog, Aug 2026 testing. Vendor performance footnotes SHO-77 / RPW-537; Lemonade embeddable ~4 MB claim. https://www.amd.com/en/blogs/2026/run-meta-muse-glimmer-30b-on-amd-ryzen-ai-max-and-radeon-gpus.html
- AMD Ryzen AI Software documentation (ryzenai.docs.amd.com), LLM deployment overview and release notes lines 1.5–1.9 as crawled 2026-11-15. Execution-mode table (NPU-only / Hybrid / FastFlowLM / GPU), OGA foundation of the Lemonade SDK interfaces, hybrid-model release-locking and 2K→4K context note (1.6 notes). https://ryzenai.docs.amd.com
- Lemonade repository README, `lemonade-sdk/lemonade` (GitHub), as carried by full-text mirrors read 2026-11-15 (the live GitHub page itself was read via its mirrored renderings). Apache 2.0, C++ (server) + React (app), two flavours (Server / Embeddable), supported-configurations matrix, port 13305 base URL, model formats GGUF/FLM/ONNX, HF/ModelScope pulls. https://github.com/lemonade-sdk/lemonade
- FastFlowLM model catalogue and model cards, fastflowlm.com (Qwen family pages as crawled 2026-11-15). Q4_1 quantisation, per-model context maxima (32k–256k), core-backend paged-KV and prefill-chunking notes. https://fastflowlm.com/docs/models/qwen/
- ROCm/FastFlowLM release notes (v1.0.11, v1.0.12) via release mirrors, Oct 2026. Catalogue growth, prefix caching, context defaults. https://github.com/ROCm/FastFlowLM

**Independent / community (all accessed 2026-11-15)**

- Bekhouche (contributor), "Lemonade: one local server for LLMs, speech, images and NPUs", Hugging Face blog (personal post, versions 2026.44.1/45.3 tested). Daemon/CLI/app structure, subprocess isolation, dialect table, per-modality LRU, four-model residency test, Hub integration, embeddable and launch commands. https://huggingface.co/blog/Bekhouche/lemonade-one-local-server-for-llms-speech-images
- "Running LLMs on the AMD NPU with Lemonade Server", sleepingrobots.com, 2026-04-09. Strix Halo Linux NPU bring-up (IOMMU, amdxdna/XRT source build), NPU-vs-GPU and concurrent benchmarks, Whisper comparison, agent task routing. https://sleepingrobots.com/dreams/lemonade-server-npu-strix-halo/
- "Running Lemonade on Strix Halo (EVO-X2): Vulkan Shared Memory Leaks and ROCm Stability", lilting.ch, Apr 2026 (v10.0.1). Router-overhead, Vulkan-vs-ROCm memory behaviour, hybrid Qwen3-8B test, four-model ROCm test, router/recipes/UMA-detection bugs, pull quantisation limit. https://lilting.ch/en/articles/lemonade-strix-halo-verification
- "AMD's Lemonade Local AI Server Bundles GPU, NPU, and Multi-Modal Inference Under One Roof", lilting.ch, 2026-04-03. Backend matrix synthesis, HN reaction, FastFlowLM proprietary-kernel reporting (0.9.35 era). https://lilting.ch/en/articles/amd-lemonade-local-ai-gpu-npu-server
- "llama.cpp: Vulkan vs ROCm on Strix Halo", soothill.io, 2026-08-03. Matched-protocol prefill/generation backend comparison on gfx1151. https://www.soothill.io/blog/2026/08/03/llamacpp-vulkan-vs-rocm-strix-halo/
- "FastFlowLM 1.0 Lands Inside AMD's ROCm", Hardware Busters, 2026-08-11. AMD adoption of FastFlowLM (July 2026), ROCm organisation move, runtime size, licence characterisation of kernels (see §3.5 conflict). https://hwbusters.com/news/fastflowlm-1-0-lands-inside-amds-rocm-a-17mb-runtime-that-finally-puts-ryzen-ai-npus-to-work/
- `flm-add` project documentation, PyPI (accessed 2026-11-15). Q4NX package anatomy (`model.q4nx`, xclbin), closed-kernel statement, registry mechanics. https://pypi.org/project/flm-add/
- Lemonade reviews and roundups used for corroboration and version/cadence evidence: PromptQuorum Lemonade review (updated Sep 2026; Apache 2.0, ~5,700 stars, three-engine summary); AICoderScope Lemonade-as-backend guide (2026-08-29; 11.x release cadence, triple-dialect usage); AnchorTerminal Lemonade review (Oct 2026; weekly calendar-versioned releases, MCP tools, security-policy observation); AIFoss Lemonade review (2026-06-07; v10.6 state); RunAIHome Lemonade guide (2026-05-28; secondary reporting of vendor TTFT/power figures — used only as flagged second-hand vendor claims); XDA Developers Lemonade portability piece (2026-07-07; cross-vendor single-control-plane experience); Strix Halo community benchmark compilations (Strix Halo Guide log via SpecPicks roundup, Oct 2026; gpt-oss-120B and dense-70B figures). URLs as returned by search and recorded in the research notes for this dossier.

**Corpus cross-references (internal, for the reader)**

- `memory/unified-memory.md` — the 256 GB/s LPDDR5X ceiling, GTT/budget law, and the Z13 case study that §4 reads AMD's claims against.
- `memory/npu-memory-and-dataflows.md` §6 — the compiled-blob regime (OpenVINO NPU, QNN context binaries, Hailo) that §3 shows FastFlowLM and the Ryzen AI ONNX path both instantiate.
- `runners/onnx-runtime-genai.md` — the execution-provider model underneath Lemonade's `ryzenai-llm` path (§3.3), including the provider-lottery warning that applies verbatim to hybrid models.
- `runners/openvino-genai.md` — the Intel-side NPU regime (static shapes, blob caching, AoT export) whose shape §3.2 mirrors on AMD silicon.
