# Project A.E.S.I.R.: What Works Right Now

**Current-capabilities snapshot: September 16, 2026**

> A.E.S.I.R. changes quickly. This file is intentionally dated. It is a human-readable snapshot, not a permanent compatibility promise. `CAPABILITY_LEDGER.md` remains the repository's authoritative evidence ledger.

## Quick answer

Project A.E.S.I.R. is no longer only a design or proof-of-concept repository. It can run real local AI inference through native Mojo CPU/CUDA code, hold interactive GPU chat sessions, manage a durable local model catalog, download and verify pinned model files, inspect models, reason about hardware/memory fit, expose local HTTP generation APIs, and speak a useful early subset of Ollama's API.

It is still experimental. Its strongest end-to-end accelerator support is currently NVIDIA CUDA on Linux/WSL2, and several ambitious future systems in the repository are not yet connected to production inference.

## Currently usable capabilities

### 1. Native CPU inference

A pinned GGUF v3 Llama F16 fixture executes through the native Mojo CPU path. The project's integration checks cover metadata, tokenizer behavior, generation, stop behavior, context boundaries, and memory-pool restoration.

This CPU path is important as a reference implementation and correctness foundation. It should not be interpreted as a claim that every GGUF LLM already runs on the CPU backend.

### 2. Native NVIDIA CUDA inference

A.E.S.I.R. has physically exercised native CUDA text-inference paths rather than forwarding inference to an external engine.

Verified/project-evidenced work includes Gemma 4 and Llama 3/Stheno CUDA sessions, with newer model-family work adding Qwen support and physical Qwen 3 verification across Q4_K_M, Q5_K_M, and Q6_K test targets documented in the current README.

The runtime contains hardware detection, device selection, model/profile detection, memory planning, GPU-resident session state, tokenization/framing, sampling, and model-specific/family-specific execution machinery.

### 3. Persistent interactive CUDA chat

Supported CUDA models can remain loaded while the user sends multiple prompts. The chat runtime supports:

- seeded sampling
- temperature
- top-k
- top-p
- min-p
- repetition penalties
- reset/settings controls
- cooperative Ctrl+C cancellation
- generation deadlines
- durable conversation/transcript work
- newer exact-token conversation save/load behavior
- newer `/model` switching across supported native CUDA families

### 4. Terminal Home interface

The CLI now includes a friendlier terminal entry point:

```bash
aesir home --model-store .aesir/models
```

Home is intended to make common actions discoverable rather than requiring a user to memorize the complete command set. Current README documentation describes chat, catalog browsing, diagnostics, and repair preview through this interface.

### 5. Verified-build launcher

The repository has launch tooling that separates building from normal offline launch.

Linux/WSL:

```bash
python3 scripts/launch.py --build
python3 scripts/launch.py --check
python3 scripts/launch.py
```

The launcher verifies the prepared executable against source/build information and refuses stale or mismatched builds rather than silently running them.

### 6. Windows PowerShell to WSL launch bridge

A Windows user with a prepared WSL2 environment can use:

```powershell
./scripts/launch.ps1 -Build
./scripts/launch.ps1 -Check
./scripts/launch.ps1
```

This is a Windows launcher into the Linux/WSL A.E.S.I.R. runtime, not a claim of native Windows inference.

### 7. Native model store

A.E.S.I.R. has a restart-safe content-addressed model store. Important working operations include:

```bash
aesir create NAME --modelfile Modelfile --model ./model.gguf
aesir verify NAME
aesir list
aesir show NAME
aesir cp SOURCE DESTINATION
aesir rm NAME
aesir gc
aesir alias SHORTNAME NAME
aesir favorite NAME
aesir aliases
aesir favorites
```

Stored model bytes are measured and addressed using SHA-256. Identical model bytes can be shared rather than blindly duplicated inside the protected store. The catalog has transactional/locking work designed to survive separate CLI processes and concurrent writers.

### 8. Pinned Hugging Face downloads

The CLI can download pinned public Hugging Face model artifacts while validating revision, expected byte count, and SHA-256 information. Current development also includes resumable pinned download work.

This is intentionally stricter than treating "the download completed" as proof that the expected model was received.

### 9. GGUF inspection

The current README exposes:

```bash
aesir inspect <model> --format json
```

This provides versioned, read-only GGUF metadata/layout evidence. Inspection deliberately does not claim that a model will execute successfully or fit the selected hardware.

### 10. Hardware and memory-fit explanation

The runtime has hardware reporting and memory planning. September 16 work added an explicit explanation path for fit decisions with stable reason information and byte-level accounting for required memory, available memory, reserve, usable memory, deficit, and headroom.

The README points users toward:

```bash
aesir compute explain
```

This is planning evidence, not a guarantee that every otherwise-unknown architecture can run.

### 11. `aesir doctor`

The newer diagnostic command checks local A.E.S.I.R. conditions such as CUDA, storage integrity, disk visibility, local listeners, and model compatibility without requiring an Internet connection for the diagnostic itself.

Example through the launcher:

```bash
python3 scripts/launch.py -- doctor --model-store .aesir/models --json
```

### 12. Native authenticated local HTTP service

A.E.S.I.R. can load a supported native CUDA model and expose a bounded local HTTP service on loopback. Its native authenticated mode includes key generation, strict request bounds, generation deadlines, cooperative shutdown, and local-only binding.

This is useful for local clients. It is **not** currently an Internet-facing or multi-tenant server.

### 13. Initial Ollama-compatible service

A.E.S.I.R. can currently launch an Ollama-compatible loopback mode on `127.0.0.1:11434` for a supported loaded model.

The documented compatibility surface includes:

```text
GET  /api/version
GET  /api/tags
POST /api/show
POST /api/generate
POST /api/chat
```

Generation/chat currently require `"stream": false`.

Recognized Ollama generation options currently include:

```text
num_ctx
num_predict
temperature
top_k
top_p
min_p
seed
repeat_penalty
```

This is enough for meaningful client compatibility experiments, but it is not full Ollama parity yet.

### 14. OpenAI-compatible text API work

The current project README reports working OpenAI-compatible model-discovery and text-generation routes on the native loopback service. This provides a second compatibility direction for applications in addition to Ollama-style APIs.

### 15. Native model recipes and configuration layering

Recent September work connects stored native recipes and explicit JSON configuration into chat/service startup settings.

The current precedence model allows native defaults, JSON configuration, stored recipes, explicit service/CLI flags, and request-level settings to be resolved deliberately rather than allowing one request to accidentally mutate the defaults of the next.

### 16. Quantization infrastructure

The project contains checked support at several different maturity levels.

The important distinction is that **a verified quantization primitive is not automatically a verified complete-model backend**.

Current repository evidence includes canonical GGML K-quant decoding work for Q2_K through Q6_K, real-row parity work for selected formats, host-side metadata-aware primitives for several other quantization systems, and extreme-quant host primitives. The Capability Ledger should be consulted before interpreting any of these as end-to-end model support.

### 17. Host paged-KV infrastructure

A checked `PagedKVCache` exists for bounded host-side logical/physical page management, including allocation, exhaustion, release, reuse, and initialization guards.

Normal CPU/CUDA model attention still uses contiguous KV buffers. GPU paged attention, prefix sharing, copy-on-write, eviction, and scheduler integration are future work.

## Important things that do NOT work completely yet

As of this snapshot, do not assume complete support for:

- arbitrary GGUF models
- every Gemma/Llama/Qwen variant
- AMD GPU inference
- Intel GPU inference
- Apple Metal inference
- NPU inference
- multi-GPU execution
- heterogeneous CPU+GPU+NPU scheduling
- production Internet serving
- multiple simultaneous inference requests
- batching
- full Ollama replacement behavior
- Ollama NDJSON streaming
- Ollama embeddings
- Ollama pull/create/delete/copy compatibility through the HTTP service
- tool/function calling through the Ollama compatibility API
- multimodal/vision messages
- general RAG execution
- complete automatic use of every quantization primitive
- speculative decoding
- broad cross-platform performance claims

Some of these areas have designs, scaffolding, partial components, or roadmaps. That is different from a verified working capability.

## What has changed since the older September 2 status document?

The repository has moved quickly since `docs/CURRENT_STATUS.md` was dated September 2. The current README and recent commits document additional work including:

- model-family compatibility registry work
- initial dense Qwen GGUF support
- physical Qwen 3 verification across multiple K-quants
- automatic tokenizer selection
- expanded model-name resolution
- initial Ollama-compatible service
- OpenAI-compatible text APIs
- path-free TUI model selection
- aliases and favorites
- `/model` hot switching
- exact-token conversation save/load
- resumable pinned downloads
- `aesir doctor`
- terminal Home interface
- verified-build/offline launcher work
- Windows PowerShell/WSL launch bridge
- native recipe/configuration layering
- service sampling-default fixes
- versioned native layout inspection evidence
- more explicit memory-fit explanations

This dated document exists partly because the older concise status file no longer tells the whole September 16 story.

## Best source of truth

When documents disagree, use this order:

1. `CAPABILITY_LEDGER.md` for evidence-backed capability maturity.
2. Current implementation/tests and the newest relevant runtime documentation.
3. `README.md` for the latest broad project narrative.
4. This dated September 16 snapshot for an easy human overview.
5. Older dated reports/roadmaps as historical context only.

## Bottom line

On September 16, 2026, A.E.S.I.R. can genuinely be used as an experimental native local-AI runtime on its supported paths. It can run real models, chat, manage models, inspect hardware/model information, expose local inference APIs, and begin impersonating familiar local-AI service protocols.

The next leap is not proving that A.E.S.I.R. can generate text. It already can. The next leap is broadening model/hardware coverage and making the runtime sufficiently compatible, convenient, and complete that ordinary applications can rely on it.
