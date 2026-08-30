# Current project status

**Current as of 2026-08-30.** This document is the concise operational entry
point for Project A.E.S.I.R. It complements the detailed
[capability ledger](../CAPABILITY_LEDGER.md), which is authoritative for every
capability ID. Dated audits, roadmaps, vision documents, and external reference
guides describe their stated point in time; they do not override this status.

## What works now

Project A.E.S.I.R. has two real local inference paths:

| Capability | Status and evidence |
|---|---|
| CPU inference | A pinned GGUF v3 Llama F16 fixture runs through the native Mojo CPU path. The integration check verifies metadata, tokenizer IDs, 32 greedy tokens, decoded text, stop behavior, a context boundary, and pool restoration. |
| Native CUDA Gemma chat | The dense, text-only `unsloth/gemma-4-E4B-it-GGUF` **Q4_K_M** profile runs through native Mojo CUDA kernels on the observed RTX 4070 Laptop GPU. All 42 layers, packed weights, activations, KV cache, and greedy token selection remain on the GPU; host code only handles scheduling, tokenization, and I/O. |
| Built-in Hugging Face download | `aesir pull` downloads a public, pinned GGUF artifact with HTTPS-only redirects, immutable revision, byte-count and SHA-256 validation, and exclusive atomic publication. The accepted Gemma artifact is 4,977,171,584 bytes and has SHA-256 `85a896a047553e842f25297ee5b031d64ff30147d9c4af17b1e4b394cd1fab87`. |
| Persistent chat and logs | `aesir chat ... --accel cuda` keeps one native CUDA session loaded across prompts and writes a durable transcript. A checked run completed 20 exchanges with a 16,384-token completion ceiling on each turn, 20 natural EOS stops, 693 generated tokens, and 1,535 context positions. |
| Automated checks | The counted suite reports 147 passed, 0 failed, and 1 explicit external-fixture skip (148 total). GitHub Actions passed the master suite, native build, fail-closed control, provenance, and documentation checks on commit `bf5254a`. |

The reproducible commands, exact model pin, evidence boundaries, and hardware
observations are in [GEMMA4_CUDA.md](GEMMA4_CUDA.md).

## Current limits

- CUDA support is **one dense, text-only Gemma 4 E4B Q4_K_M profile** on the
  observed NVIDIA/WSL2 setup. It is not general GGUF, multimodal, MoE,
  multi-GPU, NPU, AMD, Intel, Metal, or cross-platform accelerator support.
- CUDA errors fail the session. There is no CPU model fallback and no external
  inference backend. GPU utilization was observed as high as 100%; utilization
  is variable and is not a constant-use guarantee.
- Sampling is deterministic greedy. Temperature, top-k, top-p, penalties,
  grammar-constrained generation, speculative decoding, batching, and
  production serving have no acceptance evidence for this CUDA profile.
- The 16,384 setting is a maximum number of new tokens, not evidence that a
  16,384-token response has been generated and independently validated. The
  accepted conversation used a 32,768-token context configuration.
- There is no independent full-model logit-parity proof, throughput/latency
  benchmark, hardware CI runner, authentication, resumable/authenticated Hub
  transfer, model-store registration, or production-service readiness claim.
- OpenAI, Ollama, llama.cpp, ONNX, EXL2, RAG execution, Swarm, and NPU paths
  remain scaffolded, partial, or fail closed as specified by the ledger.

## Practical use

Use Linux or WSL2 with the locked Pixi environment, an NVIDIA driver, and
enough free VRAM. Build, download, and chat using the commands in
[GEMMA4_CUDA.md](GEMMA4_CUDA.md). The downloader requires `curl` and
`sha256sum`; the model and logs intentionally remain outside Git.

## Reading the rest of the repository

- [Capability ledger](../CAPABILITY_LEDGER.md): canonical maturity and evidence
  boundaries for individual capabilities.
- [TODO](../TODO.md): active work, ordered by evidence needs.
- [Gemma CUDA guide](GEMMA4_CUDA.md): supported native CUDA workflow.
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
4. Build one complete, secure service/API path before claiming compatibility or
   production readiness.
