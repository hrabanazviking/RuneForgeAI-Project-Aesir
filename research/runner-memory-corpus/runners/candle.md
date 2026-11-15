# Candle — OR-2 Dossier

## 1. Header

- **Name:** Candle (repository `huggingface/candle`; core crates `candle-core`, `candle-nn`, `candle-transformers`). Always lower-case in the project's own styling.
- **Licence — verified:** Dual-licensed under **MIT OR Apache-2.0**, at the user's choice. Verification, 2026-11-15: the repository root contains both `LICENSE-MIT` and `LICENSE-APACHE` files; the README carries badges for both licences; crate metadata (crates.io / lib.rs) states MIT/Apache. GitHub's own licence detector reports only "Apache License 2.0" in its sidebar summary, which understates the position — the dual grant in the repo root is the authoritative one. This is the framework licence only; model weights loaded through it carry their own licences.
- **Language:** Rust throughout the framework, its kernels glue, and its examples. Optional Python bindings exist (`candle-pyo3`, built on PyO3) for tooling and experimentation, but no Python is required — or present — in the normal runtime path. CUDA kernels are shipped through dedicated kernel crates (`candle-kernels`, plus `candle-flash-attn` / `candle-flash-attn-v3`); Metal kernels through `candle-metal-kernels`.
- **Links:**
  - Repository: https://github.com/huggingface/candle
  - Documentation book: https://huggingface.github.io/candle/
  - API documentation: https://docs.rs/candle-core/latest/candle_core/
  - Installation guide: https://huggingface.github.io/candle/guide/installation.html
- **As of:** 2026-11-15. Repository state when read: created 2023-06-19, ~21,300 stars, ~2,730 commits, actively moving. The project publishes crates to crates.io rather than GitHub releases (the repo shows no GitHub releases and versioning lives in the crates); sources read during this study reference the 0.9 line in downstream projects and 0.11 in a 2026 training study, so treat any single version number as a snapshot, not a stable platform.
- **Essence:** Candle is a **machine-learning framework, not a model runner and not a serving system**. It provides tensors, a device abstraction, neural-network building blocks, a library of pre-implemented model architectures, and loaders for the common weight formats — and then stops. It has no HTTP server, no request scheduler, no continuous batching, no paged KV cache, and no opinion about how concurrent users share a GPU. Its stated reason to exist is the opposite end of the problem: to make *serverless inference possible* by shrinking the framework until a model can ship as one small native binary with no Python interpreter attached. This corpus studies it anyway — indeed, studies it closely — for two reasons. First, it is the substrate under mistral.rs (banked separately in this corpus), so everything mistral.rs is and is not traces back to decisions made here. Second, it is the clearest worked example in the field of a *minimalist tensor framework* strategy: what a from-scratch tensor layer actually owes a runner built on top of it, what it pointedly refuses to provide, and what that refusal costs and buys. For a team designing its own tensor layer in Go, Candle is the reference case for "how small can the core be while still being useful?"

## 2. Design philosophy

### 2.1 The founding complaint

Candle's own FAQ (README, read 2026-11-15) gives three reasons to use it, and together they are the whole philosophy:

1. **Serverless inference.** Full frameworks — the FAQ names PyTorch — are very large, which makes starting instances on a cluster slow. Candle aims at lightweight binaries that start fast and ship small.
2. **Remove Python from production.** Python overhead hurts performance, and the CPython Global Interpreter Lock is called out by name as a source of production pain. A Rust runtime has neither an interpreter in the loop nor a GIL.
3. **The surrounding ecosystem was already Rust.** Hugging Face had already built two load-bearing pieces of its stack as Rust crates — `safetensors` for weights and `tokenizers` for tokenization. A Rust tensor framework completes a pure-Rust inference stack with no foreign-function boundary in the middle of it.

Everything else about the design follows from those three commitments. Candle is what you get when the deployment shape — one small, fast-starting, self-contained binary — is treated as the primary design constraint, ahead of research flexibility and ahead of raw kernel supremacy.

### 2.2 Minimal core, familiar surface

The workspace is deliberately split into small crates so a consumer depends only on what it uses:

- `candle-core` — the tensor type, devices, dtypes, core operations, storage backends, and the quantized-tensor machinery (including the GGUF/GGML readers).
- `candle-nn` — layers, norms, losses, optimizers, and the `VarBuilder` mechanism for loading named weights into a model definition.
- `candle-transformers` — pre-implemented model architectures (the "model zoo": Llama family, Mistral/Mixtral, Gemma, Phi, Qwen, Falcon, StarCoder, Mamba, RWKV, Whisper, Stable Diffusion, BERT, T5, vision models, and more, per the README's feature list).
- Supporting crates: `candle-kernels` (CUDA), `candle-metal-kernels` (Metal), `candle-flash-attn` and `candle-flash-attn-v3` (FlashAttention integrations), `candle-onnx` (ONNX model evaluation), `candle-datasets`, `candle-pyo3` (Python bindings), `candle-examples`, and the WASM example/test crates.

The API surface is intentionally PyTorch-shaped — the README's own cheatsheet is a two-column PyTorch↔Candle translation table (creation, indexing, reshape, matmul, device and dtype moves, safetensors save/load). The bet is that familiarity is a feature: a researcher who knows PyTorch can read Candle model code immediately, while the compiled artifact underneath behaves nothing like PyTorch at deployment time.

### 2.3 Execution model: eager, define-by-run

Candle executes eagerly in the PyTorch sense: each operation dispatches to the selected backend when it is called, and model code is ordinary Rust control flow. There is no graph-capture compiler, no TorchScript/XLA-style optimisation pass, and no separate "compiled model" artefact in the documented core offering (book and README, as of 2026-11-15). Autograd exists but is opt-in and narrow: gradient tracking attaches to `Var` tensors, a backward pass over the recorded operations produces gradients, and `candle-nn` supplies optimizers (AdamW among them). Training is therefore *possible* and demonstrably done — the book has training material and downstream projects train small models — but it is not the design centre. The honest positioning, repeated across independent tours of the project read for this dossier, is **inference-first**: training works, the inference path is where the engineering weight sits.

### 2.4 The deliberate omissions, and what they buy

What Candle leaves out is as load-bearing as what it includes:

- **No autograd-first design centre.** PyTorch's architecture orbits the training loop: a huge autograd engine, distributed-training machinery, and an op zoo sized for research. Candle keeps a small autograd sufficient for fine-tuning-scale work and spends its complexity budget elsewhere.
- **No giant op zoo.** The op set covers what the implemented model zoo needs, plus the extension points to embed user-defined kernels (FlashAttention being the showcase example). Consumers who need an op Candle lacks must compose it, write a kernel, or wait — downstream projects maintain extension crates (e.g. `candle-ext`, which re-implements PyTorch functions missing from Candle) precisely because the core declines to grow one.
- **No serving layer at all.** Nothing in the workspace schedules requests, batches sequences, manages a KV cache for multiple tenants, or speaks HTTP. See §4 — this omission is the single most instructive fact in the dossier.
- **No Python-first ecosystem.** There is no equivalent of the PyTorch hub/zoo/torchvision sprawl, no plugin registry of community ops, and no promise that a research repo's code will "just run." Model support means someone wrote the architecture in Rust inside `candle-transformers` or a downstream crate.

What the omissions buy, concretely:

- **Binary size and cold start.** A Candle application is a native binary linking only the crates and backends it enabled. Against a PyTorch deployment (interpreter + framework wheels + CUDA libraries, hundreds of megabytes before weights), this is the difference between a serverless-friendly artefact and one that needs a warm pool. (The project states this as a goal rather than publishing a maintained size table; treat specific byte counts in third-party blogs as anecdotes, not project data.)
- **Embedding.** Because it is a library of crates with a small core, Candle can be linked *into* another program — a CLI, a desktop app, a server, a browser via WASM — instead of being a runtime the program must be hosted by. mistral.rs's library-first shape is inherited directly from this.
- **Auditability.** A small core is one a small team can actually read. For a from-scratch reimplementation effort, the relevant comparison is not feature count but *surface a maintainer must understand end-to-end*; Candle is sized for that in a way PyTorch is not.
- **Compile-time backend selection.** Backends are Cargo features (`cuda`, `cudnn`, `mkl`, `accelerate`, `metal`). A CPU-only build carries no GPU code at all, which keeps CI builds and small deployments honest about what they contain.

The cost side of the ledger is §7's weakness list; the short version is that every omission becomes somebody else's work — usually the runner author's.

## 3. Tensor layer

### 3.1 Backends

As documented in the README feature list and the book's installation guide (read 2026-11-15):

| Backend | Status in the project's own docs | Notes |
|---|---|---|
| CPU | First-class, "optimized" | Optional Intel MKL on x86 (`mkl` feature) and Apple Accelerate on macOS (`accelerate` feature) for faster BLAS; a pure-Rust GEMM path otherwise. This is the backend the serverless story is built on. |
| CUDA | First-class | Via `candle-kernels` and cudarc; optional cuDNN (`cudnn` feature) for further speedups; multi-GPU distribution via NCCL; FlashAttention v2 (and a v3 crate) as embeddable custom kernels; an opt-in `cutile` feature for JIT-compiled CUDA kernels written in Rust. |
| Metal | Supported | Via the dedicated `candle-metal-kernels` crate; `Device::new_metal(0)` is a peer of the CUDA constructor in the API. Apple Silicon is a real target, not an afterthought. |
| WASM | Supported as a *target* | Models compile to `wasm32-unknown-unknown` and run in the browser (see §6.2). This is CPU execution inside the browser sandbox, not a distinct GPU backend. |
| WGPU / WebGPU | **Not documented — no such backend** | Worth stating plainly because it is commonly assumed: as of 2026-11-15, Candle's own README and book list no WGPU/WebGPU backend. Portable-GPU-via-wgpu is the rival Rust framework Burn's strategy, not Candle's. Candle reaches Apple GPUs through Metal directly and browsers through WASM CPU execution. Any claim of a Candle WGPU backend should be treated as unverified until it appears in the project's own docs. |

The device abstraction is the PyTorch-shaped one: a `Device` value (CPU, CUDA ordinal, Metal ordinal) is threaded through tensor creation and model loading, and moving a model between devices is a matter of constructing it against a different device. Model code is written once against this abstraction — which is exactly the property a runner wants to inherit, and exactly where the runner also inherits the framework's ceiling (§4.3).

### 3.2 Dtype system

`candle-core`'s `DType` enum (docs.rs, read 2026-11-15) is a closed, non-exhaustive enum of fourteen variants:

- Integers: `U8`, `U32`, `I16`, `I32`, `I64`.
- Floats: `F32`, `F64`, `F16`, `BF16`.
- Sub-byte and microscaling floats, reflecting the modern quantization era: `F8E4M3` (FP8), `F6E2M3` and `F6E3M2` (MX6 formats), `F4` (MX4), and `F8E8M0` (scale-only FP8 variant).

Two observations matter for a Go reimplementation. First, the ordinary dtype system and the *quantized* dtype system are separate worlds: block-quantized GGUF weights do not live in `DType` at all, but in the quantized module's own type system (§3.3). Second, the presence of MX/FP8 formats in the core enum shows the core is still growing toward datacentre quantization formats — the "minimal" core is a moving target, expanding where model publishers push it.

### 3.3 The quantized module and GGUF

`candle-core` contains a `quantized` module providing `QTensor`/`QStorage` (quantized tensor storage), a quantized matmul path (`QMatMul` in the transformers support code), and file readers for both GGUF (`quantized/gguf_file.rs`) and the legacy GGML format (`quantized/ggml_file.rs`). The quantization block types are llama.cpp's: the README states plainly that quantization support uses "the llama.cpp quantized types," and the shipped quantized examples run Llama (7B/13B/70B and chat/code variants), Mistral 7B, Mixtral 8×7B, Zephyr, OpenChat, and Qwen3 MoE models from GGUF files.

What this means, precisely:

- **Candle can load and run a GGUF file.** The quantized example (`candle-examples/examples/quantized`) is a first-party, maintained demonstration of exactly that: the same file the llama.cpp ecosystem produces and consumes, executed by a completely independent Rust tensor engine.
- **Quantized weights stay quantized.** The point of the `QTensor` path is that block-quantized weights participate in matmul in their compressed form (with dequantization fused into the kernel path), rather than being expanded to dense F16 at load. That is what makes a 7B-at-4-bit model a ~4 GB resident instead of a ~14 GB one.
- **GGUF support is a reader's bridge, not a conversion pipeline.** Candle does not need GGUF — its home format is safetensors (§3.4) — but by reading GGUF it inherits the entire community catalogue of pre-quantized models without asking publishers to re-export anything.

Ecosystem consequence, stated carefully: GGUF began as llama.cpp's private format. Every independent engine that reads it — Candle, and through Candle mistral.rs, among others — converts it from "llama.cpp's format" into "the local-inference interchange format." Candle's adoption is one of the strongest signals in that shift, because Hugging Face is the publisher-side institution of the ecosystem: the Hub's own framework reading the community's format legitimises the format. The reverse flow exists too — GGUF files are overwhelmingly converted *from* safetensors originals — so the practical ecosystem is bilingual, with safetensors as the publisher format and GGUF as the quantized-distribution format. A new runner that reads only one of the two is choosing to be locked out of half the catalogue.

### 3.4 Safetensors as home format

Safetensors is Candle's native weight format in every meaningful sense:

- The README's save/load cheatsheet uses `candle::safetensors::save` / `load` as the canonical operations.
- `VarBuilder` — the mechanism by which model definitions pull named weights — is most commonly constructed over memory-mapped safetensors files (`from_mmaped_safetensors`), giving lazy, zero-copy-ish loading straight from the publisher's artefact.
- The format is itself a Hugging Face Rust crate, so Candle's loader and the Hub's distribution format are the same technology family: no conversion step exists between "download from the Hub" and "run."

The loader is not exclusively safetensors: the documented format list is **safetensors, npz, ggml/GGUF, and PyTorch checkpoint files**, plus ONNX evaluation through `candle-onnx`. But the centre of gravity is unmistakable — safetensors is home, GGUF is the honoured guest, and everything else is legacy tolerance.

## 4. What a runner must add on top

This is the section the corpus exists for. Candle draws the framework/runner boundary with unusual clarity, because it provides *nothing* above the level of "execute this model's forward pass." mistral.rs — a complete, competitive runner — is the worked example of everything that had to be built on top. (Details of mistral.rs itself are in its own dossier; here it is used only as the measuring instrument.)

### 4.1 The missing middle: everything between a forward pass and a service

To turn Candle into a serving system, mistral.rs had to build, from scratch:

- **A sequence engine and scheduler.** A notion of a *sequence* (one generation in progress), admission control, and a scheduler loop that decides which sequences advance on each step. Candle has no concept of a request.
- **Continuous batching.** Merging many in-flight sequences into shared forward passes, with sequences joining and leaving mid-generation. Candle executes the batch you hand it; deciding what the batch *is*, step by step, is runner work.
- **Paged KV cache.** A separate crate (`mistralrs-paged-attn`) implementing PagedAttention-style block-managed KV storage with CUDA and Metal kernels, plus prefix caching on top of it. Candle provides KV-cache *primitives* inside model code (models keep their own caches as tensors), but nothing resembling a shared, paged, multi-tenant KV allocator.
- **Sampling and stopping.** Logits processing, temperature/top-k/top-p sampling, repetition penalties, stop sequences, grammar/structured-output constraints — all runner-side.
- **A serving layer.** An HTTP server with OpenAI-compatible (and later Anthropic-compatible) APIs, streaming responses, metrics, and a CLI. Candle ships no server of any kind.
- **Model-loading intelligence.** Architecture detection, chat-template handling, tokenizer wiring, quantization selection, and in-situ quantization (quantizing a safetensors checkpoint *while it loads*, because Candle's quantized path consumes pre-quantized files).
- **Its own kernels where the substrate ran out.** mistral.rs maintains its own quantization crate and paged-attention kernels precisely at the points where Candle's kernel library was insufficient for serving-grade performance. The substrate's gaps become the runner's kernel-writing obligations.

The pattern generalises beyond mistral.rs: the README's own "useful external resources" list is a catalogue of other people building the missing layers — `candle-vllm` and `vllm.rs` (serving platforms), `atoma-infer` (FlashAttention2 + PagedAttention + multi-GPU serving), `kalosm` (a higher-level local-model framework), `candle-lora` (LoRA support the core lacks), `candle-sampling` (sampling the core lacks). The ecosystem's shape *is* the boundary: a small core, and a ring of projects each re-supplying a piece of runner.

### 4.2 The boundary, contrasted

- **Against ggml/llama.cpp:** ggml is also "just" a tensor library, but it grew up *inside* a runner. Its ecosystem's centre of gravity is inference-shaped — KV-cache handling, quantization formats, and sampling live close to the core, and llama.cpp's serving machinery is a thin layer over assumptions the library already makes. A builder on ggml inherits more runner-shaped decisions (and more runner-shaped constraints). A builder on Candle inherits a cleaner, more general tensor layer — and must make every serving decision themselves.
- **Against PyTorch:** PyTorch ships an ecosystem, not a library: the framework, the autograd engine, distributed training, a model zoo culture, and a gravitational field that pulls serving systems (vLLM, SGLang) into building *on* it while constantly fighting its generality. Building a runner on PyTorch means inheriting enormous capability and enormous weight simultaneously, plus a Python host. Candle is the deliberate opposite trade: almost no inherited weight, almost no inherited serving capability.

### 4.3 The inherited ceiling

The boundary cuts both ways. A runner on Candle inherits Candle's kernel depth as its performance ceiling: where Candle lacks a fused kernel or an op, the runner composes slower paths or writes kernels itself (§4.1, last bullet). It also inherits Candle's backend matrix — no WGPU route to portable GPU coverage, Metal and CUDA as hand-maintained kernel crates — and its dtype/quantization coverage. Choosing a substrate is choosing which gaps you will personally fill. mistral.rs's history (its own paged-attention and quantization crates) is the empirical price list for Candle's minimalism.

## 5. Performance character

Candle publishes no maintained, official benchmark suite in the documentation read for this dossier — an absence worth recording in itself, since it means most circulating "Candle speed" numbers are downstream, anecdotal, or stale. What can be stated with sources:

- **The design target is deployment shape, not leaderboard throughput.** The project's own claims are about binary size, cold start, and removing interpreter overhead (§2.1), not about beating specialised engines at tokens/second. Independent tours consistently position it the same way: at its best where the constraint is a small static binary and sub-second cold starts, with GPUs optional (Redline Software tour, 2026-10-03).
- **CPU inference of quantized small models is a first-class, feasible mode** — that is the serverless premise, and the quantized examples exist to demonstrate it. Decode speed in this regime is memory-bandwidth-bound like every other engine's; Candle does not repeal physics, and no source read claims it beats llama.cpp at llama.cpp's own game on CPU.
- **The substrate's ceiling, once a runner is built, is respectable but uneven.** The clearest public numbers are mistral.rs's (v0.8.2 CUDA benchmark report, reproduced in its README; hardware: NVIDIA GB10, B200, H100 SXM; 256 generated tokens; means across prompt/decode depths 128–16384): running *on Candle*, mistral.rs's Q8 prefill beat llama.cpp's GGUF Q8_0 on every listed model/hardware pair (e.g. Gemma 4 E4B on B200: 27,705.6 vs 11,992.4 tokens/s prefill; decode 241.4 vs 194.4 tokens/s), while at BF16 against vLLM it won some comparisons and lost others badly — notably large-MoE BF16 prefill (Gemma 4 26B-A4B on B200: 3,467.3 vs vLLM's 28,532.8 tokens/s). Read correctly, these are *system* numbers for mistral.rs-plus-Candle, not Candle numbers — but they locate the substrate's character precisely: quantized paths are strong; unquantized large-model paths, where kernel depth and graph-level optimisation dominate, are where a minimal framework's thin kernel library shows.
- **Kernel depth is the ceiling.** Candle's CUDA story leans on cuBLAS/cuDNN-class libraries plus a modest set of custom kernels and FlashAttention integrations; it has nothing comparable to the years of per-architecture fused-kernel tuning inside TensorRT-LLM or the ggml ecosystem's CPU kernels. Where a workload is one big matmul, Candle is competitive by construction (it calls the same BLAS). Where a workload is a hundred small ops per token, eager per-op dispatch with a thinner fusion story costs real throughput. (This paragraph is analysis synthesised from the architecture and the benchmark pattern above; it is marked as such, not quoted from a source.)
- **Training performance is the weak flank, with receipts.** A 2026 single-author experience report (arXiv, accessed via search 2026-11-15) describes pretraining a ~0.4B model end-to-end on Candle 0.11 — proving the training path *works* — while cataloguing five Candle defects encountered on the way, including fused kernels that silently produced no gradient, and concludes the author moved training to PyTorch while keeping Rust for serving. Single-source and single-author: treat as a credible field report, not a verdict. It aligns with, and is best read as evidence for, the project's own inference-first positioning.
- **WASM performance is real but bounded.** The browser demos (§6.2) run small models at usable speeds on CPU-in-WASM. One 2026 community experiment (single anecdote, Node 24 on an Apple M5, matmul microbenchmarks) found a wasm64 build of `candle-core` 0.11 roughly 3.5× slower than the wasm32 build — a data point about the immaturity of the >4 GB browser path, not about Candle's mainstream targets.

**Summary judgement:** competitive for its class — small-to-mid models, quantized weights, CPU and single-GPU inference, embedded contexts. Not the tool that wins a datacentre throughput shootout, and not trying to be.

## 6. Ecosystem position

### 6.1 Hugging Face's Rust beachhead

Candle is one piece of a deliberate, multi-year Hugging Face strategy: rebuild the *infrastructure layer* of the ML stack in Rust, piece by piece, while the research layer stays in Python. The family, as it stands in the sources read:

- `safetensors` — the safe, mmap-friendly weight format that displaced pickle across the Hub.
- `tokenizers` — the fast Rust tokenization library used well beyond Rust (it ships Python bindings and is a de-facto standard).
- `candle` — the tensor framework that lets the other two be *used* without Python anywhere in the process.
- The Hub client ecosystem (`hf-hub` and friends) — model download and caching in Rust.

The strategic read (analysis, marked as such): each piece is independently adoptable, each makes the next more valuable, and together they give Hugging Face a deployment story — serverless, edge, browser, embedded — that a Python-only stack structurally cannot offer. Candle's minimalism is partly taste and partly strategy: a small framework is one a small team inside HF can maintain indefinitely alongside its Python flagship, without it needing to *beat* PyTorch at PyTorch's game.

### 6.2 The WASM / browser story

WASM support is a headline feature in the README, and it is demonstrated, not aspirational: first-party browser demos, hosted on HF Spaces and running entirely client-side, cover Whisper (speech recognition), LLaMA2 / llama2.c (text generation), T5, Phi-1.5/Phi-2, YOLO (detection/pose), BLIP (captioning), and Segment Anything (segmentation). The build path is documented (`rustup target add wasm32-unknown-unknown`, build with `trunk`, serve locally). The constraints are the browser's, not Candle's: the classic wasm32 4 GB memory ceiling bounds model size, models must be small or aggressively quantized, and execution is CPU-bound inside the sandbox (§5, last bullet, for the wasm64 frontier). Even so, this is a capability almost no other serious framework offers as a first-party path, and it is a direct consequence of the minimal-core design: there is no interpreter to port.

### 6.3 Who builds on it

Documented builders (README external-resources list and project pages, read 2026-11-15):

- **mistral.rs** — the flagship downstream: a full LLM serving engine (see its own dossier). The proof that the substrate can carry a serious runner.
- **candle-vllm** and **vllm.rs** — vLLM-style serving platforms on Candle, by overlapping authorship with mistral.rs.
- **atoma-infer** — inference-at-scale library adding FlashAttention2, PagedAttention, and multi-GPU support.
- **kalosm** — a higher-level Rust framework for local models (controlled generation, vector stores, transcription) built on Candle.
- **candle-lora** — LoRA fine-tuning support conforming to the `peft` reference behaviour.
- A long tail of smaller pieces: `candle-sampling`, `candle-einops`, `candle-ext`, `candle-video`, optimizers collections, tutorials, and ports of educational material (`llms-from-scratch-rs`, `gpt-from-scratch-rs`).
- **Language bindings outward:** `red-candle` exposes Candle to Ruby; `candle-pyo3` exposes it to Python. The direction of travel is notable — other languages binding *to* the Rust core, rather than the core being a binding to something else (the `tch-rs` model, whose README contrast Candle's FAQ draws explicitly: bindings to libtorch are "extremely versatile, but they bring in the entire torch library into the runtime").

## 7. Strengths / weaknesses

### Strengths

- **Deployment shape is best-in-class for a general framework.** One native binary, no interpreter, no GIL, feature-flagged backends, fast cold start. For serverless, edge, CLI, and embedded inference, nothing in the PyTorch family competes on this axis.
- **Genuinely small, readable core.** A small team can hold the whole tensor layer in mind — the property that makes it a useful reference design for a from-scratch reimplementation.
- **PyTorch-shaped API.** Lowers the porting cost for model code and the reading cost for researchers; the model zoo in `candle-transformers` doubles as a set of reference implementations.
- **Format bilingualism.** Safetensors-native *and* a real GGUF reader with llama.cpp's quantization types — both halves of the modern model catalogue load without conversion (§3.3–3.4).
- **Backend breadth where it counts.** CPU (with MKL/Accelerate), CUDA (with NCCL multi-GPU, cuDNN, FlashAttention), Metal, and a WASM target cover the realistic deployment map for local and embedded inference.
- **Institutional backing with a coherent strategy.** Maintained by Hugging Face as part of its Rust infrastructure family (§6.1); the surrounding crates (safetensors, tokenizers, Hub clients) are shared, maintained technology, not per-project reimplementations.
- **Memory safety in the host layer.** Rust's guarantees remove whole fault classes from the framework and everything built on it (GPU kernel internals remain unsafe-boundary code, as everywhere).

### Weaknesses

- **It is not a runner, and the gap is large.** Scheduling, batching, paged KV, sampling, serving — all downstream work (§4). Anyone budgeting a Candle-based product must budget the runner too; mistral.rs's multi-year, multi-crate effort is the honest estimate of that cost.
- **Kernel depth trails the specialists.** Thin fused-kernel coverage versus TensorRT-LLM/vLLM on CUDA and versus ggml on CPU; large unquantized models expose it (§5).
- **Training is second-class.** Autograd exists and works, but the path is young, the distributed-training story is minimal next to PyTorch's, and field reports document sharp edges (§5). Do not choose Candle to train frontier models.
- **No portable-GPU backend.** No WGPU/WebGPU path (§3.1): AMD/Intel GPU coverage outside CUDA/Metal is essentially CPU fallback, where Burn's wgpu strategy is stronger.
- **Op coverage is zoo-driven.** If the model zoo doesn't need an op, the op may not exist; downstream extension crates exist precisely to patch this (§2.4).
- **Moving, pre-1.0-feeling surface.** Rapid crate versioning (0.9 → 0.11 across recent sources), no GitHub release train, and documentation that lags the code in places (the book's model list trails the README's). Consumers pin versions and expect churn.
- **No official benchmark suite.** Performance claims must be re-derived per workload and hardware; the project does not maintain the numbers that would settle comparisons (§5).

## 8. IDEAS TO STEAL for a Go runner

Each idea is stated with its expected gain and its cost/risk for an improved Ollama written in Go. These are recommendations synthesised from the sections above, not claims about Candle.

### 8.1 Minimal-core discipline: make the tensor layer boring

**The idea.** Hold the tensor core to a small, stable contract — a tensor type, a device abstraction, a closed dtype set, and only the ops the shipped model zoo actually needs — and push everything else (sampling strategies, exotic ops, serving features) into separate packages that the core does not know about. Candle's crate split is the template: `candle-core` stays small because `candle-transformers`, the examples, and the downstream ring absorb the growth.

**Gain.** A core small enough to be fully tested, fully understood, and ported per-backend without heroics. In Go specifically, a boring core is what makes per-architecture kernel work (the Aesir-style problem) tractable: the surface each backend must implement stays countable. It also keeps the binary and cold-start advantages that are half the reason to leave the Python/Ollama-shaped world at all.

**Cost/risk.** The discipline is social, not technical: every missing op becomes a downstream patch crate (Candle's ecosystem is littered with them), and the core team must keep saying no. Budget for an official "extensions" home from day one, or the ecosystem fragments into incompatible private forks of the core.

### 8.2 Format bilingualism: read GGUF and safetensors natively, from day one

**The idea.** Treat the two formats as co-equal inputs, not as a native format plus a converter. Safetensors for the publisher/HF world (mmap loading, per-tensor access, BF16/F16 originals); GGUF for the quantized local world (single-file, self-describing, the entire community catalogue of Q4_K_M-class artefacts). Candle's architecture — safetensors as home, a real quantized GGUF reader in the core — is the proof this is a framework-level feature, not a runner afterthought: the quantized tensor type has to exist in the core for GGUF support to be efficient rather than a dequantize-on-load shim.

**Gain.** The whole public model catalogue becomes addressable with zero conversion step, in both directions of quality: full-precision originals for GPU serving, community quants for laptops. It also future-proofs the runner against format politics — whichever format a future model family ships first, the runner already speaks it.

**Cost/risk.** Two parsers, two metadata dialects, two tensor-naming conventions to keep in permanent sync with two upstream ecosystems (the Hub's and llama.cpp's). The GGUF side additionally imports llama.cpp's quantization block zoo as a permanent maintenance obligation — every new K-quant/I-quant variant is a kernel you now owe. This is real, recurring work, and it is the price of the catalogue.

### 8.3 Embedding-first API shape

**The idea.** Design the runner's engine as a library first and a server second: an in-process API (load model → submit prompt → stream tokens) that the CLI, the HTTP server, and third-party programs all call, with the server as a thin shell over it. This is Candle's deepest structural gift to mistral.rs — because the substrate was a library, the runner could be one too, and mistral.rs consequently ships as a Rust crate, a Python package, a CLI, and a server from one codebase.

**Gain.** For a Go runner this is nearly free and unusually valuable: Go binaries are already single-artifact and embeddable, and an Ollama-class tool gains whole product categories — in-process use by other Go programs, test harnesses that run the real engine without HTTP, desktop apps linking the engine directly — without a second implementation. It also disciplines the architecture: anything the server needs must exist as a clean library call, which prevents server logic from rotting into the engine.

**Cost/risk.** Library-first means API stability becomes a commitment earlier than a server-only project faces it; breaking the embedding API breaks downstream programs, not just a REST contract you control. It also tempts scope creep toward "framework" generality — the Candle lesson cuts both ways, and the Go runner should embed *a runner*, not grow a general ML framework underneath itself.

### 8.4 (Supporting) Compile-time backend selection

**The idea.** Mirror Cargo features with Go build tags: a CPU-only build contains no CUDA/Metal code paths at all; each accelerator is an opt-in build variant. **Gain:** honest small binaries for edge/CI, and per-backend builds that can be tested in isolation. **Cost/risk:** a build-variant matrix to keep green, and runtime hardware detection must be designed so the "wrong" binary fails with a clear message rather than a silent CPU fallback.

## 9. Sources

All sources accessed 2026-11-15. Primary sources first; claims in this dossier rest on the primary sources wherever a claim matters, with secondary sources used for positioning and field reports and flagged as such in the text.

**Primary (project's own):**

- Candle repository — README (features, crate structure, FAQ, model zoo, file formats, licence badges), repository file listing (dual `LICENSE-MIT` / `LICENSE-APACHE` in root; crate layout incl. `candle-metal-kernels`, `candle-flash-attn-v3`, `candle-wasm-examples`), and repo metadata (created 2023-06-19; ~21.3k stars; Apache-2.0 per GitHub's detector). https://github.com/huggingface/candle
- Candle book — introduction (backend list, model list, format list, serverless positioning). https://huggingface.github.io/candle/
- Candle book — installation guide (CUDA/MKL feature setup). https://huggingface.github.io/candle/guide/installation.html
- `candle-core` API docs — `DType` enum (fourteen variants incl. FP8/MX formats). https://docs.rs/candle-core/latest/candle_core/enum.DType.html
- mistral.rs repository — README (v0.8.2 CUDA benchmark tables vs llama.cpp and vLLM on GB10/B200/H100 SXM; feature list evidencing what the runner layer adds: continuous batching, PagedAttention, ISQ, serving APIs). https://github.com/EricLBuehler/mistral.rs

**Secondary (independent tours, comparisons, field reports):**

- "Candle: Pure-Rust LLM Inference in Production," Redline Software blog, 2026-10-03 — crate/backend/format tour; inference-first positioning; deployment-shape assessment. https://blog.redlinesoft.net/posts/candle-pure-rust-llm-inference/
- "Candle: A Minimalist Rust ML Framework with Fast Demos like Whisper and LLaMA2," BrightCoding, 2025-09-29 — design-philosophy summary and limitations list (used only where consistent with primary sources).
- "Training a Language Model End-to-End in Rust: An Experience Report," arXiv, 2026 — single-author field report on Candle 0.11 as a training backend (five defects catalogued; author moved training to PyTorch, kept Rust serving). Treated as one credible field report, not a benchmark verdict. https://arxiv.org/html/2609.25008v1
- DeepWiki's generated documentation of the Candle repository (GGUF/GGML reader structure under `candle-core/src/quantized/`; crate dependency notes) — used for file-level structure only, cross-checked against the primary repo listing. https://deepwiki.com/huggingface/candle
- Community WASM experiment report (wasm64 `candle-core` 0.11 matmul timings, Node 24, Apple M5), VibingTalk, 2026-10-21 — single anecdote, cited as such in §5.

**Verification notes:**

- **Licence:** dual MIT/Apache-2.0 verified from the repo root licence files and crate metadata; GitHub's sidebar shows only Apache-2.0 and should not be relied on alone.
- **WGPU:** the absence of a WGPU/WebGPU backend was verified against the project's own README feature list and book introduction as of 2026-11-15; absence claims are inherently as-of-date claims.
- **Performance:** Candle maintains no official benchmark suite in the sources read; all numbers in §5 are downstream system numbers (mistral.rs) or explicitly-labelled anecdotes, with hardware and methodology stated.
