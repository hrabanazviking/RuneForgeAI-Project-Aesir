# Project A.E.S.I.R. in Plain English

**Easy introduction for non-technical readers**  
**Snapshot date: September 16, 2026**

> This document describes Project A.E.S.I.R. as it exists on the date above. A.E.S.I.R. is developing quickly, so newer repository documentation may supersede details here.

## What is Project A.E.S.I.R.?

Project A.E.S.I.R. (**Advanced Edge System for Interface and Response**) is an experimental program for running AI models locally on your own computer.

The easiest way to understand it is to compare it with familiar local-AI software such as Ollama. An application asks for an AI response, the local inference engine loads the AI model and performs the enormous amount of math needed to produce the answer. A.E.S.I.R. is being built to become that underlying engine.

The unusual part is how A.E.S.I.R. is being built. Its inference runtime is written in **Mojo** and is intended to work close to the hardware instead of depending on a large Python AI software stack. The long-term goal is an efficient, hardware-aware engine that can eventually make good use of many kinds of computers and accelerators, especially consumer and edge hardware.

A.E.S.I.R. is **not finished software for ordinary end users yet**. It is an active experimental engineering project. However, it has already crossed the important line from design documents and prototypes into running real AI models through its own native inference paths.

---

## What does "local AI" mean?

Many AI services send your request over the Internet to computers in a data center. Local AI instead runs the model on hardware you control.

In the parts of A.E.S.I.R. that are currently verified, the model is loaded from local storage and inference happens locally. That can eventually provide benefits such as offline use, privacy, independence from a hosted inference service, and the ability to choose your own models.

A.E.S.I.R. does **not** currently claim to support every computer, every model, or every AI application.

---

## What is an AI model in this project?

Think of an AI model as a very large collection of learned numerical information plus an architecture that describes how to use it.

A.E.S.I.R. works with **GGUF** model files in its currently verified model paths. GGUF is a popular file format for distributing models intended for local inference.

A.E.S.I.R. can inspect GGUF information, store model files in its own local model catalog, verify their contents, and run specific supported model families through native CPU or NVIDIA CUDA paths.

---

## What is actually working right now?

As of **September 16, 2026**, the repository contains real working implementations for a growing set of capabilities.

### Real native inference

A.E.S.I.R. has a verified native Mojo CPU reference path using a pinned Llama GGUF fixture. It also has native NVIDIA CUDA inference paths that have physically run real Gemma, Llama 3/Stheno, and more recently Qwen-family test models on the project's exercised NVIDIA hardware.

The CUDA paths keep the important inference work on the GPU rather than calling Ollama, llama.cpp, a hosted AI API, or a Python inference framework to secretly generate the answer.

### Interactive local chat

A.E.S.I.R. can keep a supported CUDA model loaded and hold an interactive chat session. It supports sampling controls such as temperature, top-k, top-p, min-p, seeds, and repetition controls on the verified CUDA chat paths.

It also supports conversation save/load behavior, model selection, aliases, favorites, and model switching in the newer CLI work.

### A friendlier terminal Home screen

The built application now has a terminal-oriented Home interface:

```text
aesir home --model-store .aesir/models
```

It provides an easier entry point for chat, model catalog browsing, diagnostics, and repair preview instead of requiring users to remember every command.

### Local model catalog

A.E.S.I.R. has a native content-addressed model store. In plain language, this means it can keep a local catalog of installed models and identify stored model bytes by a cryptographic SHA-256 fingerprint.

The model-store tools can currently create/import entries, list models, show information, verify stored bytes, copy catalog entries, remove entries, garbage-collect unreferenced model data, create aliases, and mark favorites.

### Model downloading

A.E.S.I.R. has native tooling for pinned Hugging Face GGUF downloads. The download path validates expected file size and SHA-256 information before treating a pinned artifact as verified. Newer work also includes resumable pinned downloads.

### Hardware and memory planning

A.E.S.I.R. can report hardware information and estimate whether a model fits available memory. New September 16 work added more explicit explanations of memory-fit decisions, including required, available, reserved, usable, deficit, and headroom byte counts.

This is important because "will this model fit on my GPU?" is one of the most common practical problems in local AI.

### Model inspection

The CLI can inspect GGUF model information without pretending that inspection proves the model can execute successfully:

```text
aesir inspect <model> --format json
```

The September 16 implementation also versions the native layout evidence it reports.

### Diagnostics

The `aesir doctor` command checks useful local conditions such as CUDA, model storage integrity, disk visibility, local listeners, and model compatibility. It is designed to remain useful offline.

### Local AI server

A.E.S.I.R. can run a local HTTP inference service backed by a loaded native CUDA model.

It has its own authenticated local API and an initial **Ollama-compatible mode**. The Ollama-compatible mode currently implements model/version discovery plus non-streaming text generation and chat for the supported service path.

It also has OpenAI-compatible text API work in the current runtime.

This is a major architectural step because other programs can eventually use A.E.S.I.R. as their AI engine instead of needing to know how A.E.S.I.R. performs inference internally.

---

## What does "Ollama compatible" mean here?

It does **not** yet mean "A.E.S.I.R. can replace every Ollama feature."

It means A.E.S.I.R. already understands part of the same local HTTP language used by Ollama clients. The currently documented Ollama-compatible service includes:

- version information
- installed-model discovery
- model information
- text generation
- chat
- common generation settings

Important pieces are still being developed, including streaming responses, embeddings, additional model-management endpoints, tool calling, multimodal messages, and broader concurrency/lifecycle behavior.

Full application compatibility is therefore a development target, not a current blanket claim.

---

## Why Mojo?

Mojo is a systems-oriented programming language designed for high-performance computing and AI workloads.

A.E.S.I.R.'s native inference runtime uses Mojo so that the project can work much closer to CPUs and accelerators while retaining a higher-level programming model than writing the entire engine in low-level GPU assembly or C/C++.

The long-term hope is that this helps A.E.S.I.R. become portable across increasingly diverse hardware without turning the project into a pile of unrelated inference engines.

---

## What is CUDA?

CUDA is NVIDIA's GPU computing platform. A GPU contains a huge number of small computing resources that are well suited to the matrix and vector calculations used by AI models.

A.E.S.I.R.'s most capable physically verified inference paths today use NVIDIA CUDA. That does **not** mean the project intends to remain NVIDIA-only. AMD, Intel, Apple, NPUs, heterogeneous execution, and multi-device work are longer-term goals, but they should not be confused with currently verified support.

---

## What is quantization?

AI models can be extremely large. Quantization stores model numbers using fewer bits so models consume less memory and can often run faster.

A.E.S.I.R. contains substantial work around GGML/GGUF quantization formats, including checked K-quant decoding and experimental/host primitives for several additional quantization families.

Some quantization code is verified as a mathematical primitive without yet being connected to complete model execution. The repository's Capability Ledger is the authority for that distinction.

---

## What is the KV cache?

While an AI writes a response, it needs to remember mathematical information from earlier tokens. That working memory is commonly called the **KV cache**.

The currently used CPU/CUDA model sessions use preallocated contiguous KV storage. A.E.S.I.R. also has a separate checked host paged-KV pool that can manage pages for multiple logical sequences, but that paged system is not yet the live attention cache for normal model execution.

That distinction matters: having a component implemented is not the same thing as claiming the entire future architecture is already connected.

---

## What makes A.E.S.I.R. different from a simple AI demo?

A.E.S.I.R. is being developed as an **inference runtime and local-AI backend**, not merely a script that loads one model and prints text.

Around inference itself, the project is developing:

- model storage and verification
- hardware discovery
- memory planning
- model-family detection
- tokenization
- quantization support
- GPU kernels
- persistent chat sessions
- sampling
- configuration and model recipes
- diagnostics
- local HTTP serving
- Ollama-compatible APIs
- OpenAI-compatible APIs
- safe local launch tooling
- Windows-to-WSL launch support
- testing and evidence tracking

The goal is for these pieces to form reusable infrastructure for applications rather than remaining disconnected experiments.

---

## Can I use it instead of Ollama today?

**For experiments with A.E.S.I.R.'s currently supported service surface, yes. As a complete general-purpose Ollama replacement, no, not yet.**

The current Ollama-compatible server is useful enough to test real clients that only need its implemented endpoints and non-streaming generation. It is not yet a complete replacement for all Ollama features or all applications built around Ollama.

A major future compatibility goal is to make polished applications able to use A.E.S.I.R. without needing application-specific inference code.

---

## Can I run it on Windows?

The current practical Windows path is **Windows 11 + WSL2**. A PowerShell launcher is included to enter the prepared WSL environment and launch the verified local A.E.S.I.R. build.

This is not the same as a native Windows Mojo binary. The current documented inference environment remains Linux/WSL-oriented.

---

## Can I run it on AMD, Intel, Apple Silicon, a phone, or an NPU?

Those directions are part of the broader project vision, but the answer for ordinary supported use **today is not yet**.

The strongest current accelerator evidence is the NVIDIA CUDA path. The project deliberately separates future architecture from verified present capability.

---

## Is A.E.S.I.R. production ready?

No. It is experimental software under rapid development.

The local server is deliberately loopback-only and is not presented as an Internet-facing, multi-user production service. Model-family coverage, hardware coverage, performance benchmarking, concurrency, embeddings, multimodal support, and other areas are still growing.

---

## Where should technical readers go next?

Start with these repository documents:

1. `README.md` for the main project overview.
2. `CAPABILITY_LEDGER.md` for the authoritative evidence-backed capability status.
3. `docs/NATIVE_RUNTIME.md` for native inference details.
4. `docs/NATIVE_SERVICE.md` for the local HTTP/Ollama-compatible service.
5. `docs/MODEL_STORE.md` for local model management.
6. `docs/LOCAL_LAUNCH.md` for Linux/WSL/Windows launch behavior.
7. `BEST_IN_CLASS_GAMEPLAN.md` for the active ordered implementation campaign.

For a dated practical snapshot written for ordinary users, see `HOW_TO_USE_PROJECT_AESIR_RIGHT_NOW_2026-09-16.md` and `PROJECT_AESIR_WHAT_WORKS_NOW_2026-09-16.md` in this directory.

---

## The one-sentence version

**Project A.E.S.I.R. is an experimental native-Mojo engine for running local AI models directly on your own hardware, and it is evolving from a working low-level inference engine into a practical backend that ordinary AI applications can eventually use.**
