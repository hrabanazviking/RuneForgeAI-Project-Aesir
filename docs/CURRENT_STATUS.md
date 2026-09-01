# Current project status

**Current as of 2026-09-01.** This document is the concise operational entry
point for Project A.E.S.I.R. It complements the detailed
[capability ledger](../CAPABILITY_LEDGER.md), which is authoritative for every
capability ID. Dated audits, roadmaps, vision documents, and external reference
guides describe their stated point in time; they do not override this status.

## What works now

Native hardware reporting and model memory planning are connected to both
CUDA sessions, including device selection and automatic profile detection for
CUDA `run`. See [runtime controls and limits](NATIVE_RUNTIME.md).

Project A.E.S.I.R. has a real CPU path and two native CUDA model profiles:

| Capability | Status and evidence |
|---|---|
| CPU inference | A pinned GGUF v3 Llama F16 fixture runs through the native Mojo CPU path. The integration check verifies metadata, tokenizer IDs, 32 greedy tokens, decoded text, stop behavior, a context boundary, and pool restoration. |
| Native CUDA Gemma chat | The dense, text-only `unsloth/gemma-4-E4B-it-GGUF` **Q4_K_M** profile runs through native Mojo CUDA kernels on the observed RTX 4070 Laptop GPU. All 42 layers, packed weights, activations, KV cache, and native token selection remain on the GPU; host code only handles scheduling, tokenization, and I/O. |
| Native CUDA Stheno chat | `bartowski/L3-8B-Stheno-v3.2-GGUF` **Q4_K_S** runs through a separate native 32-layer Llama 3 session, with F16 KV and an 8,192-position context. All 20 roleplay exchanges completed with natural EOS, 5,152 generated tokens and 6,514 context positions used. The [unedited conversation](evidence/stheno-roleplay-20.md) preserves both its connected story and model continuity imperfections. |
| Built-in Hugging Face download | `aesir pull` downloads public, pinned GGUF artifacts with HTTPS-only redirects, immutable revision, byte-count and SHA-256 validation, and exclusive atomic publication. Both the 4,977,171,584-byte Gemma artifact and 4,692,668,960-byte Stheno artifact were downloaded and verified natively; exact pins are in their guides below. |
| Persistent chat and logs | `aesir chat ... --accel cuda` keeps one native CUDA session loaded across prompts and writes a durable transcript. A checked run completed 20 exchanges with a 16,384-token completion ceiling on each turn, 20 natural EOS stops, 693 generated tokens, and 1,535 context positions. |
| Cooperative cancellation | Both native CUDA sessions support deadlines and Ctrl+C. Generation interruption closes the turn; interrupted prefill requires explicit `/clear`. Both real-model recovery probes pass; no in-flight kernel preemption. |
| Native local HTTP service | Authenticated loopback `serve` executes stateless requests on either loaded CUDA model, with strict HTTP/JSON bounds, I/O/generation deadlines and cooperative shutdown. Both real-model socket tests pass; see [service contract](NATIVE_SERVICE.md). |
| Native recipe catalog | `create`, `list`/`ls`, `show`, `cp`, and `rm`/`delete` use a bounded, restart-safe Mojo catalog. A built-binary harness verifies separate-process persistence and rollback; see the [model-store contract](MODEL_STORE.md). |
| Automated checks | The counted suite reports 170 passed, 0 failed, and 1 explicit external-fixture skip (171 total). Physical CUDA/model checks remain opt-in; hosted CI does not claim GPU execution. |
| CPU K-quant decoding | Q2_K, Q3_K, Q4_K, Q5_K, and Q6_K use canonical GGML packed-byte layouts with complete-block validation and raw known-value regressions. Independent real-row parity covers Q4_K and Q6_K; general full-model compatibility is not claimed. |
| Metadata-bearing host quantization | AutoGPTQ 4/8-bit, AutoAWQ GEMM 4-bit, EXL2 mixed 2/3/4/5/6/8-bit, static SmoothQuant W8A8, and HQQ 4-bit axis=1 have checked host dequantization/GEMM primitives over their real packing metadata. These are bounded primitives, not model-loader or CUDA integration claims. |

The reproducible commands, exact model pin, evidence boundaries, and hardware
observations are in [GEMMA4_CUDA.md](GEMMA4_CUDA.md) and
[STHENO_CUDA.md](STHENO_CUDA.md).

## Current limits

- CUDA support covers **dense, text-only Gemma 4 E4B Q4_K_M and Llama 3 8B
  Stheno Q4_K_S profiles** on the
  observed NVIDIA/WSL2 setup. It is not general GGUF, multimodal, MoE,
  multi-GPU, NPU, AMD, Intel, Metal, or cross-platform accelerator support.
- CUDA errors fail the session. There is no CPU model fallback and no external
  inference backend. GPU utilization was observed as high as 100%; utilization
  is variable and is not a constant-use guarantee.
- Native CUDA chat supports seeded temperature/top-k/top-p/min-p sampling,
  repetition penalties and explicit reset/settings controls. The GPU sampler
  matches 896 independent reference decisions; see [runtime controls](NATIVE_RUNTIME.md).
  Grammar-constrained generation, speculative decoding, batching and production
  serving remain unverified for these CUDA profiles.
- The 16,384 setting is a maximum number of new tokens, not evidence that a
  16,384-token response has been generated and independently validated. The
  accepted conversation used a 32,768-token context configuration.
- Stheno's 8,192-position context includes the whole conversation and replies.
  Its 8,192-new-token ceiling is bounded by remaining context, with an explicit
  `context_exhausted` stop and no silent history truncation.
- There is no independent full-model logit-parity proof, throughput/latency
  benchmark, hardware CI runner, resumable/authenticated Hub transfer,
  content-addressed model-byte ingestion, or production-service readiness claim.
  The recipe catalog does not copy or measure the GGUF referenced by a Modelfile.
- GPTQ 4-bit/8-bit, AWQ GEMM 4-bit, EXL2 mixed-bit, static SmoothQuant W8A8,
  and HQQ 4-bit axis=1 now have checked format-compatible host
  dequantization/GEMM primitives with explicit packed weights, scales,
  grouping, padding, and permutation metadata. Model-file loading, tensor
  attachment, CUDA dispatch, and full-model execution remain unfinished. Other HQQ
  variants, dynamic SmoothQuant variants, IQ/extreme quantization, OpenAI, Ollama,
  llama.cpp, ONNX, RAG execution, Swarm, and NPU paths remain partial or fail
  closed as specified by the ledger.

## Practical use

Use Linux or WSL2 with the locked Pixi environment, an NVIDIA driver, and
enough free VRAM. Build, download, and chat using the commands in
[GEMMA4_CUDA.md](GEMMA4_CUDA.md) or [STHENO_CUDA.md](STHENO_CUDA.md).
The downloader requires `curl` and
`sha256sum`; weights, binaries and raw runtime logs intentionally remain outside
Git. The readable Stheno conversation is published unchanged as Markdown evidence.

## Reading the rest of the repository

- [Capability ledger](../CAPABILITY_LEDGER.md): canonical maturity and evidence
  boundaries for individual capabilities.
- [TODO](../TODO.md): active work, ordered by evidence needs.
- [Gemma CUDA guide](GEMMA4_CUDA.md): supported native CUDA workflow.
- [Stheno CUDA guide](STHENO_CUDA.md): Llama 3 download, roleplay and 8K limits.
- [Model-store guide](MODEL_STORE.md): durable recipe operations and limits.
- [Configuration guide](CONFIGURATION.md): strict JSON schema and runtime ownership.
- [DEVLOG](DEVLOG.md): chronological implementation record.
- `docs/historical/` and dated audits: preserved context, not current runtime
  assertions. Older architecture, hardware, performance, protocol, and vision
  documents may describe desired systems that are still unimplemented.

## Next work that would materially broaden support

1. Independently verify full-model logits and longer generation/context runs.
2. Add performance measurements and a hardware CI strategy for the native CUDA
   profile.
3. Generalize model admission only with per-architecture loader, tokenizer,
   kernel, and parity evidence.
4. Add content-addressed model-byte ingestion and measured SHA-256/size to the
   durable recipe catalog.
