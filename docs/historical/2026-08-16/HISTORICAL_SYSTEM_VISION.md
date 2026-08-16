# Project Aesir: System Vision

> *"A system that knows its own boundaries and honors its own memory cannot be broken by chaos."*  
> — **Sigrún Ljósbrá, The Skald**

---

## 🎯 Primary Purpose & Vision for the Current Slice (Slice 14: Autonomous Swarm Agents & Enterprise Mesh Cluster Matrix)

Project Aesir is designed to be the fastest, leanest, and most resource-efficient bare-metal LLM inference engine in existence, acting as a seamless **drop-in replacement for Ollama** (`localhost:11434`), **llama.cpp**, **ExLlamaV3**, and **ONNX Runtime**.

It eliminates bloated dynamic runtimes, heavy Python/C++ library stacks, and runtime memory fragmentation by implementing everything in native **Mojo**.

In **Slice 14**, Project Aesir establishes the Autonomous Swarm Agents & Enterprise Mesh Cluster Matrix, enabling multi-node swarm orchestration, peer liveness tracking, dynamic VRAM load balancing, distributed task routing, and REST endpoint parity. The sovereign matrix provides the Swarm Node Role Sigil (`SwarmNodeRole`), Peer Node Descriptor (`PeerNode`), Peer Node Registry (`PeerRegistry`), Task Dispatcher (`TaskDispatcher`), Sovereign Swarm Cluster Orchestrator (`SwarmCluster`), Swarm REST API endpoints (`/api/swarm/nodes`, `/api/swarm/join`, `/api/swarm/dispatch`, `/api/swarm/status`), `aesir swarm` CLI subcommands (`join`, `list`, `status`, `dispatch`), core engine facade integration (`aesir.mojo`), and proving suite (`tests/test_swarm_cluster.mojo`):

1. **The Swarm Node Role Sigil (`core/swarm.mojo` - `SwarmNodeRole`):** Zero-cost integer discriminant representing enterprise cluster node authority roles: LEADER (0), WORKER (1), RELAY (2).
2. **The Peer Node Descriptor (`PeerNode`):** State and capacity telemetry container tracking node ID, network address, authority role, VRAM capacity/usage, active model catalog runes, and liveness status.
3. **The Peer Node Registry (`PeerRegistry`):** Sovereign peer catalog managing liveness heartbeats, node enrollment, and dynamic scout for the least-loaded peer node based on free VRAM capacity.
4. **The Swarm Task Dispatcher (`TaskDispatcher`):** Dynamic workload router balancing model inference tasks across connected cluster peer nodes.
5. **The Sovereign Swarm Cluster Orchestrator (`SwarmCluster`):** Master swarm orchestrator coordinating mesh connection rites (`join_mesh`), inter-node liveness pulses (`heartbeat_pulse`), and load-balanced distributed inference dispatch (`dispatch_distributed_inference`).
6. **Swarm REST Route Dispatcher (`server/api.mojo`):** Bare-metal API endpoints serving mesh topology status (`/api/swarm/nodes`, `/api/swarm/status`), node join handshake (`/api/swarm/join`), and workload dispatch routing (`/api/swarm/dispatch`).
7. **Bifrost CLI Swarm Terminal Suite (`cli/commands.mojo`):** Native `aesir swarm` subcommand suite (`join`, `list`, `status`, `dispatch`) executing mesh connection, cluster inventory inspection, and distributed inference routing.
8. **Integrated Sovereign Engine Facade (`aesir.mojo`):** Engine facade integration instantiating `SwarmCluster` active during runtime operations.
9. **Autonomous Swarm Proving Suite (`tests/test_swarm_cluster.mojo`):** Verification suite testing node role discriminants, peer node metrics, registry load balancing, and cluster task dispatch.

---

## 🏛️ System Core Capabilities

1. **Bare-Metal HTTP Transport & Streaming Current (`BifrostGate`):**
   - High-concurrency POSIX socket server listening on `0.0.0.0:11434`.
   - Full compatibility with Ollama API requests (`/api/generate`, `/api/chat`, `/api/tags`, `/api/version`).
   - **The Bifrost Streaming Current (`send_chunk` / `generate_stream`):** Real-time chunked token streaming with zero intermediate string copies.

2. **Contiguous Memory Pool & Memory Rings (`MimirWell` & `KVCache`):**
   - One-time pre-allocation of workspace memory drawn from the Well of Mimir.
   - Zero-copy tensor slicing via `RuneTensor` wrappers.
   - **The Well's Memory Rings (`KVCache`):** Ring-buffer key-value cache managing per-layer $K, V$ state and deterministic sequence position indexing.

3. **Zero-Allocation Weight Loader & Metadata Seer (`The Runecaster` / `GGUFSeer`):**
   - Direct POSIX `mmap` of GGUF weight files (`F16`, `Q4_K_M`).
   - Binary KV dictionary traversal and tensor byte-offset mapping without copying data from disk to heap.

4. **The Rune Weaver BPE Tokenizer (`RuneWeaver`):**
   - Native Mojo BPE encoding and decoding engine.
   - Maps raw Midgard string prompts to sacred token IDs via GGUF vocabulary lookup, byte-hex formatting (`<0xXX>`), and iterative min-ID pair merging.

5. **Hardware SIMD Acceleration (`The Forge of Nidavellir`):**
   - **The Cleansing Fire (`rmsnorm`):** Vectorized Root Mean Square normalization.
   - **The Threads of Urd (`apply_rope`):** SIMD complex sinusoidal rotary position embeddings.
   - **The Gaze of Odin (`flash_attention_2`):** $QK^T$ dot products fused with online streaming softmax and $V$ accumulation.
   - **The Anvil's Strike (`gemm_f16`):** 32x32 block-tiled SIMD matrix multiplication.
   - **Fast SIMD Activations (`silu`, `geglu`):** Analytic approximations over vector lanes.
   - **Native Q4_K_M Dequantization (`dequantize_q4_k_m`):** On-the-fly 4-bit nibble unpacking during SIMD loads.

6. **End-to-End Inference Engine (`The Loom of Fate`):**
   - Autoregressive sequence generation loop connecting prompt tokenization, transformer block execution, KV cache ring updates, and chunked response streaming.

7. **Masking Seidr (Thinking Token Control):**
   - Configurable thinking token allow/disallow switch (`permit_seidr`).
   - Low-level probability masking (-inf logit) of inner thought tokens (`<|start_thought|>`) when disabled.

8. **Mímisbrunnr Vector Search & RAG Context Augmentation (`MimirStore` & `cosine_similarity`):**
   - Native SIMD vector dot product and norm normalization kernel.
   - Contiguous pre-allocated embedding store in `MimirWell`.
   - Dynamic prompt context augmentation (`[CONTEXT]: ...`) prior to tokenization and transformer block execution.

10. **The NPU Realm Gateway (Heterogeneous Edge Acceleration):**
   - **The Sigil of Edge Realms (`NPUBackendType`):** Six sovereign compute spirits: Hailo-10, Qualcomm Hexagon, ARM NEON, NVIDIA Jetson, Apple Neural Engine, Generic NPU.
   - **The Yggdrasil Root Channel (`NPUBuffer`):** Zero-copy DMA-BUF/ION/AHardwareBuffer wrapper carved from MimirWell — CPU MMU and NPU IOMMU share the same physical frame.
   - **The Iron Thread Strike (`gemm_f16_arm_neon`):** 128-bit NEON GEMM, 8-lane f16, for Cortex-A mobile and Apple Silicon.
   - **The Cleansing Fire of Járnviðr (`rmsnorm_arm_neon`):** 128-bit NEON RMSNorm with f32-widened stability guard, zero additional MimirWell draw.
   - **The Gate of the Nine NPU Realms (`gemm_f16_npu`):** Single-integer dispatch gateway routing all GEMM calls to their sovereign hardware kernel stream.
   - **Heterogeneous Forward Pass (`TransformerBlock.forward`, `AesirEngine`):** `enable_npu` / `target_backend` propagation through all projection layers and the full generation pipeline.

11. **Universal Multi-GPU & Hardware Accelerator Realm Matrix:**
   - **The Sigil of Universal GPU Realms (`GPURealmType`):** Ten sovereign compute spirits: CUDA, ROCm/HIP, OneAPI Xe, MUSA, SUPA, MACA, DCU, Mali OpenCL, Adreno, PowerVR.
   - **The Bifrost Physical Stream Channel (`GPUBuffer`):** Zero-copy physical GPU buffer carved directly from MimirWell.
   - **The Universal GPU Realm Scout (`DeviceTopology.detect_gpu_realms`):** Topology scan registering all ten GPU hardware realms into living memory.
   - **The Gateway of the Ten GPU Realms (`gemm_f16_gpu`):** Zero-overhead single-integer discriminant routing matrix operations to specialized SIMD kernels.
   - **Eastern GPGPU & Mobile SIMD Kernels (`gemm_f16_gpgpu_vector`, `gemm_f16_mobile_opencl`):** 16-wide GPGPU SIMT and 8-wide mobile OpenCL vector kernels.
   - **The Cleansing Stream of Alfheim (`rmsnorm_gpu`):** Vectorized RMSNorm across GPU realms with f32 numerical widening.
   - **Universal GPU Forward Pass & Engine Controls (`TransformerBlock.forward`, `AesirEngine`):** `enable_gpu_realm` and `target_gpu_realm` configuration across all model projections and generation loops.

12. **Complete Ollama Terminal Command Suite & Drop-In Replacement:**
   - **The Bifrost Command Dispatcher (`dispatch_command`):** Native Mojo routing across 12 subcommands (`serve`, `run`, `pull`, `push`, `create`, `list`, `ps`, `rm`, `cp`, `show`, `stop`, `help`).
   - **Modelfile Directive Parser (`Modelfile`, `parse_modelfile`):** Parser for `FROM`, `PARAMETER`, `SYSTEM`, `TEMPLATE`, `LICENSE`, `MESSAGE` runestones.
   - **The Scroll & Vault of Mímisbrunnr (`ModelManifest`, `RuneModelStore`):** Manifest metadata, SHA-256 digests, and catalog store.
   - **Interactive REPL Chat Current (`RuneREPL`):** Streaming terminal chat with `/set`, `/show`, `/clear`, `/bye` slash commands.

13. **Universal Compressed LLM Format Matrix:**
   - **The Sigil of Universal Compressed Formats (`CompressedFormatType`):** Discriminated integer tag supporting 21 sub-byte, integer, and block-compressed formats without dynamic allocation.
   - **The Runestone Converter (`to_compressed_format`):** Direct translation of GGUF/GGML format IDs into sovereign compressed format runes.
   - **The Gateway of Universal Dequantization (`dequantize_compressed_tensor`):** Zero-overhead dispatch gateway invoking specialized SIMD dequantization routines.
   - **Specialized Dequantization Kernels:** On-the-fly SIMD nibble unpacking for `Q2_K`–`Q8_1`, `GPTQ 4-bit/8-bit`, `AWQ 4-bit`, `ExLlamaV2 (EXL2)`, `HQQ`, and `SmoothQuant INT8`.

14. **Universal Multi-Engine Ecosystem Matrix:**
   - **The OpenAI Protocol Bridge (`OpenAIGate`):** Formats `/v1/chat/completions`, `/v1/models`, `/v1/embeddings` JSON and SSE streams.
   - **Universal llama.cpp HTTP Parity (`dispatch_http_route`):** Native routing for `/completion`, `/tokenize`, `/detokenize`, `/infill`, `/props`, `/health`, `/slots`, `/metrics`.
   - **The Rune of Structural Constraints (`GBNFGrammar`):** Zero-allocation logit masking for EBNF, JSON Schema, and regex formal grammars.
   - **The Vision of Future Runes (`SpeculativeEngine`):** Speculative draft token sampling and parallel target verification loops.
   - **The Vision of the ONNX Graph (`ONNXModelSeer`):** Protocol buffer graph parser mapping ONNX tensor initializers to `MimirWell`.
   - **Multi-Engine CLI Terminal Dispatchers (`dispatch_llama_cli`, `dispatch_exl2_cli`, `dispatch_onnx_cli`):** Terminal CLI parity for llama.cpp, ExLlamaV3, and ONNX tools.

15. **Sovereign Resilience, Self-Healing, Multi-Threading & Crash Recovery Matrix:**
   - **The Shield of Invariance (`ErrorGuard`):** Defensive pointer alignment gate, slice bounds checker, and f16 NaN/Inf logit sanitizer (-65504.0 f16 floor).
   - **The Vault of Unbroken State (`StateVault`):** Zero-allocation KV cache and prompt position checkpointing for <1 ms self-healing session recovery.
   - **The Current of Module Whispers (`AesirEventBus`):** Asynchronous Pub/Sub messaging bus routing `HEARTBEAT`, `MODEL_LOADED`, `INFERENCE_CRASH`, and `RECOVERY_COMPLETE` event pulses.
   - **The Multi-Threaded Forge (`RuneThreadPool`):** Worker thread pool executing parallel GEMM tiled matrix multiplication and background pipeline tasks.
   - **The Undying Guardian (`SelfHealingSupervisor`):** Heartbeat monitoring and panic recovery supervisor keeping socket channels active across runtime fault events.

16. **HuggingFace Hub Integration & Bare-Metal Model Downloading Matrix:**
   - **The Sovereign Repository Scout (`HuggingFaceSeer`):** Direct HuggingFace Hub repository scout and weight stream downloader for edge & mobile models (SmolLM, MobileLLM, Llama-3.2, Qwen2.5, Gemma-2-2B, Phi-3.5-mini).
   - **The Repository Normalization Rune (`parse_hf_repo`):** Uri tag normalizer stripping `hf.co/` and `huggingface.co/` prefixes into canonical `org/repo` runes.
   - **The Realm Discriminant Rune (`is_hf_tag`):** Uri discriminant checking repository prefixes and `org/repo` namespace patterns.
   - **The Bifrost Stream URL Builder (`build_download_url`):** Direct CDN download URL endpoint resolver.
   - **The Stream Downloader & Weight Inscription (`download_hf_model`):** Bare-metal streaming weight downloader with automatic `RuneModelStore` catalog registration.
   - **Bifrost CLI Command Integration (`cli/commands.mojo`):** Drop-in `aesir pull hf.co/...` subcommand execution.

17. **Autonomous Swarm Agents & Enterprise Mesh Cluster Matrix:**
   - **The Swarm Node Role Sigil (`SwarmNodeRole`):** Zero-cost integer discriminant representing node authority roles (LEADER, WORKER, RELAY).
   - **The Peer Node Descriptor (`PeerNode`):** Preserves state, identity, socket endpoints, and VRAM capacity metrics for mesh peers.
   - **The Peer Node Registry (`PeerRegistry`):** Sovereign peer catalog managing liveness heartbeats and least-loaded node scouts based on free VRAM.
   - **The Swarm Task Dispatcher (`TaskDispatcher`):** Dynamic load balancer routing distributed inference workloads across the cluster.
   - **The Sovereign Swarm Cluster Orchestrator (`SwarmCluster`):** Enterprise mesh orchestrator managing peer registration, leader join protocols, and distributed task execution.
   - **Swarm REST API Parity (`dispatch_http_route`):** Native HTTP endpoints for `/api/swarm/nodes`, `/api/swarm/join`, `/api/swarm/dispatch`, `/api/swarm/status`.
   - **Bifrost CLI Swarm Commands (`cli/commands.mojo`):** Drop-in CLI subcommands `aesir swarm join`, `aesir swarm list`, `aesir swarm status`, and `aesir swarm dispatch`.

---

## 📈 System Milestones & Roadmap

```mermaid
timeline
    title Project Aesir System Evolution
    Phase 1 : Core Architecture : BifrostGate Socket Server : MimirWell Memory Pool : AesirEngine Facade [COMPLETED]
    Phase 2 : Math Kernels & Quantization : Tiled GEMM : Fused Flash Attention-2 : Q4_K_M Dequantization [COMPLETED]
    Phase 3 : Complete LLM Forward Pass & GGUF Parsing : The Loom of Fate : The Runecaster KV Parser : RMSNorm & RoPE [COMPLETED]
    Phase 4 : Production Tokenizer & KV Cache : BPE Tokenizer Dictionary : Ring-Buffer KV Cache : Streaming Response Pipeline [COMPLETED]
    Phase 5 : External Knowledge & SIMD Vector Search : SIMD Cosine Similarity : MimirStore Vector Pool : RAG Context Augmentation [COMPLETED]
    Phase 6 : Multi-GPU Orchestration & Shard Matrix : Device Topology Mapping : Column/Row Tensor Sharding : All-Reduce Sum & Sharded GEMM [COMPLETED]
    Phase 7 : NPU Realm Gateway : NPUBackendType Edge Spirits : NPUBuffer Zero-Copy DMA-BUF : NEON gemm_f16_arm_neon & rmsnorm_arm_neon : gemm_f16_npu Dispatcher [COMPLETED]
    Phase 8 : Universal Multi-GPU & Accelerator Realm Matrix : GPURealmType Sigils : GPUBuffer Zero-Copy Channel : gemm_f16_gpu Dispatcher : Eastern & Mobile SIMD Kernels [COMPLETED]
    Phase 9 : Complete Ollama Terminal Command Suite & Drop-In Replacement : Bifrost Command Dispatcher : Modelfile Inscription Reader : Vault of Mímisbrunnr Catalog : RuneREPL Chat Current [COMPLETED]
    Phase 10 : Universal Compressed LLM Format Matrix : CompressedFormatType Sigils : GGMLType Converter : dequantize_compressed_tensor Gateway : 21 Format Kernels [COMPLETED]
    Phase 11 : Universal Multi-Engine Ecosystem Matrix : OpenAIGate REST Bridge : llama.cpp HTTP Endpoint Parity : GBNFGrammar Constrained Generation : SpeculativeEngine Draft Verification : ONNXModelSeer Protocol Parser [COMPLETED]
    Phase 12 : Sovereign Resilience & Self-Healing Matrix : ErrorGuard Pointer/Logit Sanitizer : StateVault State Snapshotting : AesirEventBus Decoupled PubSub : RuneThreadPool Parallel Workers : SelfHealingSupervisor Undying Guardian [COMPLETED]
    Phase 13 : HuggingFace Hub Integration & Mobile Downloader : HuggingFaceSeer Repo Scout : parse_hf_repo Tag Normalizer : build_download_url CDN Resolver : Mobile & Edge Model Downloader [COMPLETED]
    Phase 14 : Autonomous Swarm Agents & Enterprise Mesh Cluster : Distributed Peer Nodes : Dynamic Model Load Balancing : Sovereign Swarm Orchestration [COMPLETED]
    Phase 15 : Production Benchmarking & Custom VRAM Footprint Optimization : End-to-End Throughput Profiling : Sub-Byte KV Cache Compression : Extreme VRAM Footprint Reduction [NEXT]
```

---

## ⚡ Performance Targets

- **Latency:** Sub-millisecond TTFT (Time To First Token) for local models.
- **Memory Footprint:** Up to 80% reduction in memory overhead compared to standard dynamic inference engines.

- **Dependencies:** 0 external C/Python libraries. Strictly libc syscalls and standard Mojo compiler tooling.
