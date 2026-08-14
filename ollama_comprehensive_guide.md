# Ollama Comprehensive Documentation and Reverse Engineering Guide

Ollama is a lightweight, extensible framework for building and running large language models locally. This document is a deep-dive reverse engineering of the Ollama codebase, detailing its entire feature set, CLI commands, API protocols, internal architectures, and future integration possibilities.

---

## 1. Command Line Interface (CLI)

The `ollama` CLI is the primary entry point for users. It is built using the `cobra` command framework in Go and interfaces directly with the Ollama REST API.

### `ollama serve` (or `start`)
Starts the Ollama daemon. This process manages model loading, GPU VRAM allocation, and the REST API.
*   **Environment Variables**:
    *   `OLLAMA_HOST`: IP/Port to bind the server (default `127.0.0.1:11434`).
    *   `OLLAMA_MODELS`: Path to store downloaded models (blobs) and manifests.
    *   `OLLAMA_KEEP_ALIVE`: Default duration to keep models loaded in VRAM (default `5m`).
    *   `OLLAMA_MAX_LOADED_MODELS`: Limit concurrent loaded models to prevent OOM.
    *   `OLLAMA_NUM_PARALLEL`: Max concurrent requests processed simultaneously.
    *   `OLLAMA_NO_THINK`: **(Custom Feature)** When set to `true`, aggressively scrubs the reasoning/thinking output from reasoning models to save tokens and time.
    *   `OLLAMA_DEBUG`: Enables verbose trace logging (`OLLAMA_DEBUG=1`).
    *   `OLLAMA_FLASH_ATTENTION`: Enables Flash Attention support in `llama.cpp` for faster inference.
    *   `OLLAMA_KV_CACHE_TYPE`: Sets the quantization format for the context KV cache (e.g., `q8_0`, `f16`).

### `ollama run`
Runs an interactive session or single generation with a model.
*   **Flags**:
    *   `--format json`: Forces the model to output JSON (Structured Outputs).
    *   `--keepalive <duration>`: Keeps the model in VRAM after generation.
    *   `--think`: Controls whether models that support `<think>` tags emit reasoning (true/false, or "high/medium/low").
    *   `--verbose`: Displays metrics like tokens-per-second, prompt evaluation time, and load duration.

### `ollama create`
Builds a new model from a `Modelfile`. Similar to `docker build`.
*   **Flags**:
    *   `-f, --file <file>`: Specify a custom Modelfile location.
    *   `-q, --quantize <level>`: Automatically quantizes FP16/FP32 models to GGUF quantization levels (e.g., `q4_K_M`, `q8_0`).

### Other Core Commands
*   `ollama pull <model>`: Downloads a model and its layers concurrently from the Ollama Registry.
*   `ollama push <model>`: Uploads a local model to the registry (requires `ollama signin`).
*   `ollama list` / `ls`: Shows installed models, size, and modification date.
*   `ollama ps`: Shows currently *loaded* models, their memory footprint, and which GPU they are on.
*   `ollama rm <model>`: Deletes a model manifest and orphan blobs.
*   `ollama show <model>`: Displays system prompts, templates, Modelfile, and parameters.
*   `ollama launch <integration>`: Launches third-party apps like `claude`, `chatgpt`, `vscode`, or `cline`.

---

## 2. API Protocols and Interfaces

Ollama exposes two parallel API surfaces on port `11434`: The Native API and the OpenAI Compatibility Layer.

### Native Ollama REST API (`/api/`)
*   `POST /api/generate`: Single-turn generation. Accepts `model`, `prompt`, `system`, `template`, `format`. Returns token stream or single block.
*   `POST /api/chat`: Multi-turn conversational endpoint. Accepts `messages` array. Includes native support for `tools` and `tool_calls`.
*   `POST /api/embeddings`: Returns vector embeddings for a given string or array of strings.
*   `POST /api/create`, `POST /api/pull`, `POST /api/push`: Blob management and model lifecycle operations.

### OpenAI Compatibility Layer (`/v1/`)
Ollama implements a shim that translates OpenAI API requests into Ollama requests, allowing tools like LangChain, Autogen, and OpenAI SDKs to use local models transparently.
*   `POST /v1/chat/completions`: Emulates OpenAI chat endpoint. Supports `tools`, `response_format` (JSON schemas), and `stream`.
*   `POST /v1/completions`: Legacy OpenAI text completion API.
*   `POST /v1/embeddings`: Emulates OpenAI embeddings format.
*   `GET /v1/models`: Maps Ollama models to OpenAI's model listing schema.

### Internal Features & Protocols
*   **Structured Outputs**: Ollama supports forcing models to output JSON. When `format` is passed a JSON Schema, Ollama injects Grammars into `llama.cpp` to strictly enforce the output schema token-by-token.
*   **Tool Calling**: Ollama native and OpenAI APIs support function calling. The server renders the tool descriptions into the system prompt and uses a `builtinParser` to detect when the model emits a tool call, blocking the output and converting it into a `ToolCall` API object.

---

## 3. Internal Architecture & Reverse Engineering

### The Go / C++ Boundary (`llama-server`)
Ollama is not a pure Go application. It wraps `llama.cpp`. However, instead of using CGO (which causes complex memory panics), Ollama compiles `llama.cpp` as a standalone web server called `llama-server`.
*   When Ollama loads a model, it launches a hidden `llama-server` subprocess locally (e.g., on `127.0.0.1:xxxxx`).
*   Ollama's Go API acts as an intelligent HTTP proxy, parsing the client requests, formatting the prompt, and relaying them to the hidden `llama-server` process.

### Hardware Discovery (`discover/` and `runner/`)
Ollama dynamically detects host hardware at runtime to allocate memory efficiently.
*   It ships with compiled dynamic libraries (`.so` or `.dylib`) for different runners: `cpu`, `cuda`, `rocm` (AMD), and `metal` (Apple Silicon).
*   During model load, Ollama inspects available VRAM. If VRAM is insufficient to load all model layers, Ollama splits the layers (Partial Offloading). The bottom layers go to VRAM, and the top layers stay in system RAM (processed by the CPU).

### The Scheduler (`server/sched.go`)
This is the "Brain" of Ollama's concurrency model.
*   If a request comes in and the model is not loaded, the scheduler finds an idle GPU, starts `llama-server`, and waits for it to become ready.
*   If a request comes in for a *new* model but VRAM is full, the scheduler forcefully evicts the oldest loaded model to free up space.
*   It supports **Continuous Batching**: multiple parallel API requests for the same model are interleaved at the token-generation level by the backend `llama-server` to maximize GPU utilization.

### GGUF Parsing (`fs/gguf/`)
Ollama parses the binary header of `.gguf` files natively in Go *before* loading them. This allows the CLI to instantly read metadata (like model parameters, context sizes, and architecture) without needing to spin up the heavyweight C++ engine.

### Token Interception & Parsers (`thinking.Parser` and `model/parsers`)
Ollama parses the token stream in real-time as it arrives from `llama-server`.
*   **Reasoning Models (DeepSeek, Gemma):** Ollama intercepts the stream to separate "thinking" tokens from "response" tokens. It identifies tags (e.g., `<think>`) and assigns them to a separate `message.thinking` API field.
*   **Custom Interceptor (`OLLAMA_NO_THINK`):** We successfully reverse-engineered this pipeline to inject a global `res.Message.Thinking = ""` fail-safe right before the data is streamed over the TCP socket, ensuring reasoning models can be forced into standard instruction-following mode without leaking thoughts to the UI.

---

## 4. Integration Ecosystem

Ollama acts as a foundational daemon for local AI workflows.

*   **Web UIs**: Open WebUI, AnythingLLM, and Odysseus use the `/v1/chat/completions` API to provide a ChatGPT-like interface.
*   **Developer Tools**: VS Code extensions (Cline, Continue.dev) interface via the REST API to provide code auto-completion.
*   **Agentic Frameworks**: AutoGen, CrewAI, and LangGraph use Ollama's Tool Calling capabilities to build autonomous agents.
*   **Vector Databases**: ChromaDB and Milvus use Ollama's `/api/embeddings` to build local RAG (Retrieval-Augmented Generation) pipelines.

---

## 5. Future Feature Recommendations (Roadmap)

To elevate Ollama from a consumer tool to an enterprise-grade AI infrastructure, the following features should be architected:

1.  **Dynamic LoRA Hot-Swapping**
    *   *Problem*: Currently, applying a LoRA adapter requires modifying the Modelfile and recompiling a new model.
    *   *Solution*: Extend the `/api/generate` and `/api/chat` schemas to accept an array of `adapters` at inference time. `llama.cpp` supports applying LoRAs per-request without reloading the base weights.

2.  **Multi-Node Distributed Inference**
    *   *Problem*: Ollama handles multi-GPU on a single machine, but cannot split models across a network cluster.
    *   *Solution*: Implement MPI (Message Passing Interface) or RPC to shard layer calculations across multiple Ollama instances running on different IP addresses over a local network.

3.  **Built-in Vector Database & Native RAG**
    *   *Problem*: Users must set up Python, LangChain, and Chroma to "chat with their documents."
    *   *Solution*: Embed a lightweight vector store (like `hnswlib` or SQLite `vec`) directly inside the Ollama daemon. Add an `/api/ingest` endpoint to accept PDFs/text, and an `/api/query` endpoint that automatically retrieves context before generating a response.

4.  **Advanced API Rate-Limiting and Authentication**
    *   *Problem*: Ollama runs without authentication, making it dangerous to expose to the internet.
    *   *Solution*: Introduce `OLLAMA_API_KEY`, API usage quotas, and Role-Based Access Control (RBAC) internally using Go middleware.

5.  **P2P Model Sharing**
    *   *Problem*: Downloading 70B models from the central Ollama registry is slow and centralized.
    *   *Solution*: Implement a BitTorrent-like chunk sharing protocol natively in the daemon, allowing nodes on the same network (or internet) to seed model layers to each other.
