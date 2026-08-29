# Project Aesir: Target Data Flow Architecture

> *"To navigate complexity, one must see the whole terrain and trace every thread from source to fate."*  
> — **Védis Eikleið, The Cartographer**

---

## 🌊 Target Lifecycle Across Planned Subsystems

This document preserves the intended multi-subsystem sequence. It is not an
executable trace. The current verified path is local single-shot CPU GGUF
inference; persistent model operations, network downloads, compatibility APIs,
physical accelerators, durable resilience, and Swarm transport are absent. See
[`CAPABILITY_LEDGER.md`](../CAPABILITY_LEDGER.md) before treating any arrow below
as implemented.

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
    participant Guard as ErrorGuard (core/error_guard.mojo)
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
    else cmd == "pull" (HuggingFace Hub model tag hf.co/...)
        Disp->>HFSeer: is_hf_tag(model_tag) & parse_hf_repo(model_tag)
        Disp->>HFSeer: build_download_url(repo_id, filename)
        Disp->>HFSeer: download_hf_model(repo_id, filename)
        HFSeer->>CDN: Bare-metal HTTPS weight stream (SmolLM, MobileLLM, Llama-3.2, Qwen2.5, Gemma-2-2B, Phi-3.5-mini)
        CDN-->>HFSeer: Weight bytes stream
        HFSeer-->>Disp: Model weights written to local disk & MimirWell
        Disp->>Store: create_model(norm_repo, modelfile_content) [Register model in RuneModelStore catalog]
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

    Note over Engine, Gate: Autoregressive Checkpointing & Self-Healing Loop (Slice 12)
    loop Token-by-Token Generation Loop (0..max_gen_tokens)
        Engine->>Vault: save_checkpoint(pos, prompt_token_count)
        Inference->>Guard: validate_pointer(logits_ptr) & bounds_check(pos, max_seq_len)
        Inference->>Inference: forward_pass(current_tokens, seer, well, kv_cache, pos, topology)
        Inference->>Guard: sanitize_logits(logits_ptr, vocab_size) [Cleanse NaN / Inf values to -65504.0]
        
        alt Runtime Interrupt / Panic Signal Detected
            Sup->>Bus: publish_event("INFERENCE_CRASH", panic_msg)
            Sup->>Vault: restore_checkpoint() -> last_valid_token_pos
            Sup->>Bus: publish_event("RECOVERY_COMPLETE")
            Sup-->>Engine: Resume generation from checkpoint position without dropping socket
        end

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

0b. **HuggingFace Hub Model Stream Downloading & Catalog Inscription (`HuggingFaceSeer` — Slice 13):**
    - When `aesir pull` is invoked with a HuggingFace model tag (`hf.co/org/model`, `huggingface.co/org/model`, `org/repo`), `HuggingFaceSeer.is_hf_tag()` identifies the repository realm.
    - `parse_hf_repo()` normalizes tag strings by stripping `hf.co/` and `huggingface.co/` prefixes.
    - `build_download_url()` constructs direct CDN download endpoints (`https://huggingface.co/.../resolve/main/model.gguf`).
    - `download_hf_model()` streams model weights directly into local storage and `MimirWell` memory substrate for mobile & edge models (SmolLM, MobileLLM, Llama-3.2, Qwen2.5, Gemma-2-2B, Phi-3.5-mini).
    - Upon successful download, `cli/commands.mojo` calls `RuneModelStore.create_model()` to register the new model manifest into the sovereign model catalog.

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
    - `dispatch_http_route()` handles Ollama, OpenAI v1 REST, and llama.cpp Server HTTP endpoints.

5f. **Constrained Generation GBNF Logit Masking (Slice 11):**
    - `GBNFGrammar.apply_grammar_mask()` applies zero-allocation logit masks directly onto raw memory pointer.

5g. **Speculative Draft Verification Loop (Slice 11):**
    - `SpeculativeEngine.verify_tokens()` runs parallel rejection sampling across draft tokens.

5j. **ErrorGuard Pointer Alignment, Bounds & Logit Sanitization Gate (Slice 12):**
    - Prior to vector operations, `ErrorGuard.validate_pointer(ptr)` verifies non-null pointer alignment.
    - `ErrorGuard.bounds_check(index, max_len)` verifies zero-copy tensor slicing indices remain strictly within limits.
    - Following forward pass logit projection, `ErrorGuard.sanitize_logits(logits_ptr, count)` scans float16 values and replaces non-finite values (NaN, Inf, overflow) with safe scalar bound $-65504.0$.

5k. **Autoregressive State Checkpointing & Self-Healing Recovery Pipeline (Slice 12):**
    - Prior to each step in the token generation loop, `StateVault.save_checkpoint(token_pos, prompt_token_count)` records an atomic recovery anchor.
    - If a runtime interrupt or panic occurs, `SelfHealingSupervisor` catches the event, publishes `INFERENCE_CRASH` to `AesirEventBus`, calls `StateVault.restore_checkpoint()`, resets `KVCache` to the last valid token offset, and publishes `RECOVERY_COMPLETE`.
    - Generation resumes seamlessly without closing socket descriptors or corrupting model weight memory.

5l. **Autonomous Swarm Mesh Discovery, Load Balancing & Task Dispatching Path (Phase 14):**
    - `SwarmCluster.join_mesh(leader_address)` establishes connection to the mesh leader, instantiates a new `PeerNode` with node identity, IP, port, role (`SwarmNodeRole.WORKER`), and VRAM capacity metrics, and registers the node in `PeerRegistry`.
    - `SwarmCluster.dispatch_distributed_inference(model, prompt)` queries `PeerRegistry.get_least_loaded_node()`, which calculates `vram_free_mb()` across all active (`is_alive == True`) peer nodes and selects the node with maximum free VRAM reservoir.
    - `TaskDispatcher.dispatch_to_node()` routes the inference workload to the selected target node and increments active task metrics.

6. **Token Sampling & Thought Masking:**
   - Next token probability distribution evaluated from logits.
   - If `permit_seidr == False`, reasoning tokens (`<|start_thought|>`) are forced to $-\infty$.

7. **String Decoding & Streaming Response (`BifrostGate.send_chunk_static`):**
   - Token ID decoded to text via `RuneWeaver.decode(next_token)`.
   - Transmitted immediately over socket via `send_chunk_static()`.


