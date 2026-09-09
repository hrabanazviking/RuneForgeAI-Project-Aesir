# PROJECT AESIR ONE-WINDOW IMPLEMENTATION SPRINT

**Date:** September 9, 2026  
**Goal for Today:** Make Project Aesir practically usable as a standalone local Gemma 4 E2B Q4_K_M runtime with a 16,384-token maximum context and an Ollama-compatible local API.

**Sprint status:** Core goal completed on `codex/gemma4-e2b-offline-sprint`.
Native E2B CUDA inference, persistent 16K chat, the session-backed TUI, durable
`gemma4-e2b:latest` resolution, and all five required non-streaming Ollama
endpoints passed. OpenAI compatibility and NDJSON streaming remain optional
follow-up work. See
[`docs/evidence/gemma4-e2b-offline-sprint-2026-09-09.md`](docs/evidence/gemma4-e2b-offline-sprint-2026-09-09.md).

## Primary Goal

Make Project Aesir practically usable today as a standalone local Gemma 4 E2B
Q4_K_M runtime with a 16,384-token maximum context and an Ollama-compatible
local API.

Do not redesign the whole project. Preserve existing verified E4B and Llama 3
behavior and all existing tests.

## Priority Order

Priority order is strict:

### 1. Add Native Gemma 4 E2B Q4_K_M CUDA Support

Add native text-only Gemma 4 E2B Q4_K_M CUDA support by parameterizing the
existing Gemma4 CUDA implementation rather than copying the entire engine.

#### E2B Target Architecture

- 35 layers
- hidden size 1536
- FFN/intermediate size 6144
- 8 attention heads
- 1 KV head
- global head dimension 512
- local head dimension 256
- 20 shared-KV layers
- sliding window 512
- full attention every fifth layer
- vocabulary 262144
- runtime context cap for this milestone: 16384

Preserve E4B support.

### 2. Make Persistent E2B CUDA Chat Work

Make persistent E2B CUDA chat work at 16384 context using the existing
sampling, cancellation, tokenizer, and session infrastructure.

### 3. Connect the Existing Terminal TUI to Native CUDA Chat

Connect the existing terminal TUI to native CUDA chat. Do not add ncurses,
Python, Textual, or another runtime dependency. Minimum TUI must provide:

- model/profile
- CUDA backend
- context used/max
- token speed if measurable
- interactive prompt entry

Preserve:

- `/help`
- `/show`
- `/clear`
- `/set`
- `/bye`

### 4. Add Ollama Compatibility Mode

Add an Ollama compatibility mode on `127.0.0.1:11434` using the existing native
HTTP service and durable model catalog.

Implement, in this order:

```text
GET  /api/version
GET  /api/tags
POST /api/show
POST /api/generate
POST /api/chat
```

Support `stream:false` first. If all tests pass and time remains, implement Ollama
NDJSON streaming using the existing `session.next_chunk()` generation loop.

Map Ollama generation options where native equivalents already exist:

- `num_ctx`
- `temperature`
- `top_k`
- `top_p`
- `min_p`
- `seed`
- `repeat_penalty`

Do not claim support for parameters that are not implemented.

### 5. Resolve Model Names Through the Durable Model Store

Model names should resolve through the existing durable model store where
possible, so clients can request `gemma4-e2b:latest` rather than filesystem paths.

### 6. Add OpenAI Compatibility If Time Remains

If time remains after Ollama compatibility is verified, wire the existing
OpenAI compatibility structures to:

```text
GET /v1/models
POST /v1/chat/completions
```

## Explicit Non-Goals for This Sprint

- multimodal
- vision
- audio
- E2B contexts above 16384
- NPU
- AMD
- multi-GPU
- embeddings
- tool calling
- speculative decoding
- cloud models
- full Ollama pull
- Ollama create/delete/copy
- concurrency
- daemonization
- unrelated refactors

## Verification Gates

- Existing counted master suite remains green.
- Existing E4B and Llama3 paths remain intact.
- Real E2B Q4_K_M model loads on CUDA.
- At least a multi-turn E2B conversation succeeds.
- `/api/tags` discovers the installed E2B model.
- `/api/generate stream:false` produces valid Ollama-shaped JSON.
- `/api/chat stream:false` produces valid Ollama-shaped JSON.
- context 16384 is honored and invalid oversized requests fail explicitly.
- clean Mojo build succeeds.

## Commit Discipline

Commit each independently verified milestone so a later failure cannot destroy
earlier working progress.

Do not spend significant time updating broad vision documents until the runtime
milestones above work.
