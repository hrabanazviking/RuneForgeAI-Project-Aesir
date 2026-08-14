# Project Aesir - TODO

## Immediate Tasks
- [ ] **Missing Buildout Functions:** Create a massive staged plans to fix All Issues Addressed in PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md 
- [x] **Implement Tensor Math Kernels:** Build out the actual linear algebra implementations for Tiled Matrix Multiplication (GEMM) utilizing Mojo's tensor capabilities and hardware acceleration.
- [x] **Fused Flash Attention-2 Integration:** Implement the fused kernel for attention scores, softmax, and value aggregation in a single pass.
- [x] **Expand GGUFSeer:** Add support for quantized formats like `q4_k_m` directly into the bare-metal loading logic.
- [ ] **RuneWeaver Improvements:** Optimize the BPE tokenizer for edge cases and multilingual tokens.
- [x] **Testing:** Expand unit tests — full suite covers GEMM, Flash Attention-2, SiLU, GeGLU, Q4_K_M dequantization, GGUFSeer, and RuneWeaver.
- [x] **Truth-Bearing GGUF Vertical Slice:** Validate a real GGUF v3 Llama F16 model, map matrix weights zero-copy, convert F32 norms, load tokenizer metadata, execute grouped-query CPU inference, and return one genuine CLI token with pinned `llama.cpp` parity.

## Immediate Tasks
- [x] **RMSNorm:** Implement Root Mean Square Layer Normalization kernel.
- [x] **RoPE (Rotary Position Embeddings):** Implement RoPE in `core/compute.mojo` for position-aware attention.
- [x] **Full GGUF Tensor Metadata Parsing:** Walk the KV dictionary and tensor info entries to load real model weights.
- [x] **Inference Pipeline (Forward Pass):** Wire together the kernels into a full LLM forward pass: embed → RMSNorm → Attention → FFN → decode.
- [x] **RuneWeaver Production Tokenizer:** BPE vocabulary loading from GGUF & greedy BPE pair merge loop.
- [x] **Ring-Buffer KV Cache:** Pre-allocated zero-allocation $K,V$ cache in `MimirWell` for single-token autoregressive generation.
- [x] **Streaming Pipeline:** Bare-metal chunked response streaming in `BifrostGate` (`server/api.mojo`).
- [x] **Mímisbrunnr (External Knowledge Base):** Bare-metal SIMD cosine similarity & zero-copy RAG vector search in `MimirWell`.
- [x] **Multi-GPU Orchestration:** Multi-device `DeviceTopology` and column/row tensor sharding across GPUs (`gemm_f16_sharded`, `all_reduce_sum`).
- [x] **NPU Realm Gateway:** Hailo-10, Qualcomm Hexagon, ARM NEON, Jetson Nano, Apple Neural Engine, Android/iOS support (`NPUBackendType`, `NPUBuffer`, `gemm_f16_npu`).
- [x] **Universal Multi-GPU & Hardware Accelerator Realm Matrix:** NVIDIA CUDA, AMD ROCm HIP, Intel Xe, Moore Threads MUSA, Biren SUPA, MetaX MACA, Hygon DCU, ARM Mali OpenCL, Qualcomm Adreno, Imagination PowerVR (`GPURealmType`, `GPUBuffer`, `gemm_f16_gpu`, `gemm_f16_gpgpu_vector`, `gemm_f16_mobile_opencl`, `rmsnorm_gpu`).
- [x] **Complete Ollama Terminal Command Suite:** Drop-in Ollama CLI replacement supporting `serve`, `run`, `pull`, `push`, `create` (Modelfile parser), `list`/`ls`, `ps`, `rm`/`delete`, `cp`, `show`, `stop`, `help` (`cli/modelfile.mojo`, `cli/manifest.mojo`, `cli/repl.mojo`, `cli/commands.mojo`).
- [x] **Universal Compressed LLM Format Matrix:** Bare-metal SIMD support for 21 format types: Q2_K, Q3_K_S/M/L, Q4_0, Q4_1, Q4_K_S/M, Q5_0, Q5_1, Q5_K_S/M, Q6_K, Q8_0, Q8_1, GPTQ 4-bit/8-bit, AWQ 4-bit, ExLlamaV2 (EXL2), HQQ, SmoothQuant INT8 (`CompressedFormatType`, `dequantize_compressed_tensor`, `GGMLType.to_compressed_format`).
- [x] **Universal Multi-Engine Ecosystem Matrix (Ollama, llama.cpp, ExLlamaV3 & ONNX Parity):** OpenAI v1 REST API (`/v1/chat/completions`, `/v1/models`), llama.cpp HTTP API (`/completion`, `/tokenize`, `/detokenize`, `/infill`, `/props`, `/health`, `/slots`, `/metrics`), GBNF Grammar logit masking (`GBNFGrammar`), Speculative decoding draft verification (`SpeculativeEngine`), ONNX model graph parsing (`ONNXModelSeer`), and multi-engine CLI dispatchers (`llama-cli`, `llama-server`, `llama-bench`, `exl2`, `onnx`).
- [x] **Sovereign Resilience & Self-Healing Matrix:** Self-healing supervisor (`SelfHealingSupervisor`), StateVault checkpointing, inter-module event bus (`AesirEventBus`), multi-threaded worker pool (`RuneThreadPool`), and defensive pointer/logit sanitization (`ErrorGuard`).
- [x] **HuggingFace Hub Integration & Bare-Metal Model Downloading Matrix:** HuggingFace Hub repository resolver, URI tag normalizer, CDN stream URL builder, and weight stream downloader supporting mobile & edge models (SmolLM, MobileLLM, Llama-3.2, Qwen2.5, Gemma-2-2B, Phi-3.5-mini) (`loader/huggingface.mojo`, `cli/commands.mojo`, `tests/test_huggingface.mojo`).
- [x] **Autonomous Swarm Agents & Enterprise Mesh Cluster Matrix:** Distributed peer node roles (LEADER, WORKER, RELAY), PeerNode state & VRAM capacity metrics, PeerRegistry dynamic load balancer, TaskDispatcher router, and SwarmCluster orchestrator (`core/swarm.mojo`, `cli/commands.mojo`, `server/api.mojo`, `tests/test_swarm_cluster.mojo`).


## Future Expansions
- [ ] **Multi-Token Generation:** Extend the verified real-model path with EOS handling, context limits, sampling controls, and chat templates.
- [ ] **Quantized Real-Model Inference:** Connect supported GGML quantized tensor layouts to validated end-to-end execution; format discriminants and synthetic kernels alone do not establish model compatibility.
- [ ] **Production Benchmarking & Custom Memory Tuning:** Hardware profiling & VRAM footprint optimization.
- [ ] **Low-Precision Quantization (INT4/INT8 NPU):** Native NPU integer quantization kernels for Hailo-10 & Hexagon.


