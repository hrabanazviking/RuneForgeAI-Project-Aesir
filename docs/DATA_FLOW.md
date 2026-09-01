# Project Aesir: Target Data Flow Architecture

> **Status boundary — 2026-08-30:** This is a target flow map. The supported
> executable flow is the local CPU GGUF path plus built-in download and native
> CUDA chat for Gemma 4 E4B Q4_K_M and Llama 3 Stheno Q4_K_S.
> See [CURRENT_STATUS.md](CURRENT_STATUS.md);
> do not infer active server, RAG, swarm, or multi-device execution from the
> diagrams below.

> *"To navigate complexity, one must see the whole terrain and trace every thread from source to fate."*  
> — **Védis Eikleið, The Cartographer**

---

## 🌊 Target Lifecycle Across Planned Subsystems

This document preserves the intended multi-subsystem sequence. It is not an
executable trace. The runnable paths include CPU GGUF inference, verified public
Hub downloads and persistent native CUDA chat for the two admitted profiles.
Compatibility APIs, durable resilience and Swarm transport remain unsupported. See
[`CAPABILITY_LEDGER.md`](../CAPABILITY_LEDGER.md) before treating any arrow below
as implemented.

For Stheno: pinned Hub bytes → verified local GGUF → packed metadata/tensors and
Llama 3 BPE → one device upload → persistent 32-layer CUDA/F16-KV session →
greedy token ID → UTF-8 decoder → durable transcript. Later turns append to the
same KV state. Admission rejects oversized prompts without truncating history;
generation stops explicitly when remaining context cannot hold more output.

```mermaid
sequenceDiagram
    autonumber
    participant CLI as Terminal Invocation (main.mojo)
    participant Disp as Dispatcher (cli/commands.mojo)
    participant Store as RuneModelStore & Parser (cli/manifest.mojo)
    participant HFSeer as HuggingFaceSeer (loader/huggingface.mojo)
    participant CDN as HuggingFace CDN (https://huggingface.co/...)
    participant Gate as BifrostGate (server/api.mojo)
    participant Engine as AesirEngine (aesir.mojo)
    participant Swarm as SwarmCluster (core/swarm.mojo)
    participant Sup as SelfHealingSupervisor (core/supervisor.mojo)
    participant Bus as AesirEventBus (core/event_bus.mojo)
    participant Vault as StateVault (core/state_vault.mojo)
    participant Guard as Optional ErrorGuard helper (not wired into generation)
    participant Tokenizer as RuneWeaver (loader/tokenizer.mojo)
    participant GGUF as GGUFSeer (loader/gguf.mojo)
    participant Memory as MimirWell / KVCache / Topology (core/mimir_well.mojo)
    participant Inference as Loom of Fate (core/inference.mojo)
    participant Compute as Nidavellir Kernels (core/compute.mojo)

    Note over CLI, Disp: Terminal Invocation & Subcommand Dispatch (Slice 9, Slice 13 & Phase 14)
    CLI->>Disp: dispatch_command(cli_args)
    alt cmd == "serve"
        Disp->>Gate: BifrostGate(11434).start() [Start server daemon]
    else cmd == "run" (single-shot or REPL)
        Disp->>Engine: RuneREPL.run_repl() / run_single_shot()
    else cmd == "create"
        Disp->>Store: create_model(name, modelfile_content) -> parse_modelfile()
    else cmd == "pull" (public pinned GGUF)
        Disp->>HFSeer: validate repo, revision, filename and output
        HFSeer->>CDN: HTTPS-only bounded transfer
        CDN-->>HFSeer: temporary artifact bytes
        HFSeer->>HFSeer: verify exact size/SHA-256; publish exclusively
        HFSeer-->>Disp: completed output path
    else cmd == "swarm" (Phase 14 Swarm Subcommand)
        Disp->>Swarm: join_mesh() / dispatch_distributed_inference() / status
    else cmd == "list" / "ps" / "rm" / "cp" / "show" / "push"
        Disp->>Store: Query / Mutate ModelManifest catalog
    end

    Note over Gate, Swarm: Swarm REST API Endpoints (Phase 14)
    alt path in [/api/swarm/nodes, /api/swarm/join, /api/swarm/dispatch, /api/swarm/status]
        Gate->>Gate: dispatch_http_route(path)
        Gate-->>Gate: Format Swarm JSON Response (status, nodes, leader, target_node)
    end

    Note over Engine, Bus: Resilience Initialization & Heartbeat Pulse (Slice 12)
    Engine->>Sup: SelfHealingSupervisor() [Activate process guardian]
    Engine->>Bus: AesirEventBus() [Initialize Pub/Sub bus]
    Sup->>Bus: pulse_heartbeat() -> publish_event("HEARTBEAT")

    Note over Engine, Memory: Initialization & Compressed Weight Loading (Slice 10)
    Engine->>Memory: MimirWell(size_bytes) [Pre-allocate contiguous pool]
    Engine->>Memory: DeviceTopology(num_devices) [Map compute realms & devices; detect_edge_npus() & detect_gpu_realms()]
    Engine->>GGUF: mmap_and_load(pool, weaver) [mmap GGUF model file & parse tensor metadata]
    loop Quantized Tensors in Model
        GGUF->>GGUF: GGMLType.to_compressed_format(tensor.type) -> CompressedFormatType
        GGUF->>Compute: dequantize_compressed_tensor(format, raw_bytes, out_f16, num_elements)
        Compute-->>Memory: Unpacked f16 weight slab stored zero-copy in MimirWell
    end
    Engine->>Memory: MimirStore(max_docs, dim, pool) [Pre-allocate document/vector store]

    Note over Gate, Engine: Streaming Request Phase (generate_stream)
    Gate->>Engine: generate_stream(prompt, client_fd)

    Note over Engine, Compute: RAG Context Augmentation Phase
    alt knowledge_base.count > 0
        Engine->>Memory: search_knn(query_emb, top_k=3)
        loop Document Candidates (0..count-1)
            Memory->>Compute: cosine_similarity(query_emb, doc_emb)
            Compute-->>Memory: similarity score (SIMD float32 scalar)
        end
        Memory-->>Engine: List[String] top_k context strings
        Engine->>Engine: Prepend context: "[CONTEXT]: ...\n" + prompt
    end

    Note over Engine, Compute: BPE Encoding & Fixed-Capacity Cache Setup
    Engine->>Tokenizer: encode(active_prompt) [Iterative BPE merge + byte fallback <0xXX>]
    Tokenizer-->>Engine: token_ids: List[Int]
    Engine->>Memory: KVCache(max_seq_len, hidden_dim, pool, num_layers)

    Note over Engine, Gate: Legacy CPU generation path; no automatic recovery
    loop Token-by-Token Generation Loop (0..max_gen_tokens)
        Inference->>Inference: forward_pass(current_tokens, seer, well, kv_cache, pos, topology)
        
        alt permit_seidr == False
            Engine->>Engine: Mask thought tokens (<|start_thought|>) to -inf
        end

        Inference-->>Engine: next_token (Argmax sampled ID)
        Engine->>Tokenizer: decode(next_token)
        Tokenizer-->>Engine: token_text: String
        Engine->>Gate: send_chunk_static(client_fd, JSON chunk {"response": token_text, "done": false})
    end

    Engine->>Gate: send_chunk_static(client_fd, JSON chunk {"response": "", "done": true})
```

---

## 📍 Detailed Data Transformation Steps (Slice 6 to Slice 13)

0. **CLI Subcommand Invocation Flow (`main.mojo → cli/commands.mojo` — Slice 9):**
   - Binary execution collects arguments from `std.sys.argv()`.
   - `main.mojo` passes argument slice to `cli.commands.dispatch_command(args)`.
   - Command dispatcher routes to target subcommand handler (`serve`, `run`, `create`, `list`, `ps`, `rm`, `cp`, `show`, `pull`, `push`, `stop`).

0b. **Hugging Face Public Pinned-GGUF Download (`HuggingFaceSeer`):**
    - `aesir pull` accepts explicit repository, immutable revision, filename,
      output, expected size, and SHA-256 arguments.
    - The downloader uses checked argv execution, HTTPS-only redirects, bounded
      transfers/ranges, digest validation, and exclusive atomic publication.
    - It supports one public GGUF artifact at a time and does not register a
      model, populate `MimirWell`, authenticate, upload, or resume.

1. **POSIX Network Reception & API Endpoints (`BifrostGate`):**
   - Sockets accept incoming HTTP connections via `await_request()`.
   - Parses prompt text or embedding payload requests.
   - Handles `/api/embeddings` formatting via `send_embeddings_response` / `send_embeddings_response_static`.

2. **RAG Vector Search & Prompt Augmentation (`MimirStore` & `cosine_similarity`):**
   - When prompt is received, `AesirEngine` checks `knowledge_base` (`MimirStore`).
   - Executes `knowledge_base.search_knn(query_vector, 3)` using SIMD `simd_w_f16` cosine similarity.

3. **Rune BPE Encoding (`RuneWeaver`):**
   - Prompt text converted to token IDs (`encode`).

4. **Memory Pool Offset Slicing & Fixed-Capacity KV Cache (`MimirWell`, `KVCache` & `DeviceTopology`):**
   - `MimirWell` allocates Key and Value buffers for `KVCache`.
   - Descriptors are zero-copy slice-offsets from `MimirWell.base_ptr`.

5. **Multi-Device Forward Pass & Layer Execution (`core/inference.mojo`):**
   - `forward_pass()` iterates through `TransformerBlock` layers.
   - Dispatches single-device, multi-device sharded (`topology.num_devices > 1`), NPU Edge Gateway (`use_npu == True`), or Universal GPU Realm Matrix (`use_gpu_realm == True`) GEMM kernels.

5d. **Universal Compressed LLM Format Matrix Dequantization Path (Slice 10):**
    - `GGUFSeer.mmap_and_load` maps GGML quantization IDs to `CompressedFormatType`.
    - Dispatches `dequantize_compressed_tensor` to unpack weights to float16 slab zero-copy.

5e. **Universal Multi-Engine REST API Routing & Protocol Bridge (Slice 11):**
    - `dispatch_http_route()` recognizes reserved Ollama, OpenAI, llama.cpp, and Swarm paths but returns HTTP 501; live inference uses the separate authenticated native service.

5f. **Constrained Generation GBNF Logit Masking (Slice 11):**
    - `GBNFGrammar.apply_token_grammar_mask()` checks actual decoded candidate text for the bounded boolean/number subset before masking logits; the token-ID-only API raises unsupported.

5g. **Speculative Draft Verification Loop (Slice 11):**
    - `SpeculativeEngine.evaluate_acceptance()` computes a validated sequential probability-ratio acceptance prefix from caller-observed probabilities and draws; draft/target execution, residual sampling and KV mutation are unavailable.

5j. **Optional ErrorGuard Helpers (Slice 12):**
    - `ErrorGuard.validate_pointer(ptr)` rejects only null and address-one sentinels; it proves neither alignment nor ownership.
    - `ErrorGuard.bounds_check(index, max_len)` tests one integer bound.
    - `ErrorGuard.sanitize_logits(logits_ptr, count)` replaces Float16 NaN/Inf values in a valid caller-owned span and raises on sentinel pointers or nonpositive counts.
    - These helpers are unit-tested but are not wired into the current CPU or native CUDA generation loops.

5k. **Local Position Markers and Unavailable Recovery (Slice 12):**
    - `StateVault` can independently persist a strict, restart-safe record containing token position, prompt count, timestamp, and a non-cryptographic corruption checksum.
    - The generation loops do not automatically write or consume these markers. `SelfHealingSupervisor` catches no panic and its recovery method rejects without mutation.
    - No KV, model, sampler, process, thread, or socket state is restored.

5l. **Local Swarm Descriptors and Unavailable Network Path (Phase 14):**
    - `PeerRegistry` validates caller-supplied node records and can select among records marked live using their declared free VRAM.
    - Join, leave, heartbeat transport, discovery, remote dispatch, and distributed inference are not implemented; those entry points reject without mutating cluster state.

6. **Token Sampling & Thought Masking:**
   - Next token probability distribution evaluated from logits.
   - If `permit_seidr == False`, reasoning tokens (`<|start_thought|>`) are forced to $-\infty$.

7. **String Decoding & Streaming Response (`BifrostGate.send_chunk_static`):**
   - Token ID decoded to text via `RuneWeaver.decode(next_token)`.
   - Transmitted immediately over socket via `send_chunk_static()`.


