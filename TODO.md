# Project Aesir - TODO

## Immediate Tasks
- [x] **Implement Tensor Math Kernels:** Build out the actual linear algebra implementations for Tiled Matrix Multiplication (GEMM) utilizing Mojo's tensor capabilities and hardware acceleration.
- [x] **Fused Flash Attention-2 Integration:** Implement the fused kernel for attention scores, softmax, and value aggregation in a single pass.
- [x] **Expand GGUFSeer:** Add support for quantized formats like `q4_k_m` directly into the bare-metal loading logic.
- [ ] **RuneWeaver Improvements:** Optimize the BPE tokenizer for edge cases and multilingual tokens.
- [x] **Testing:** Expand unit tests — full suite covers GEMM, Flash Attention-2, SiLU, GeGLU, Q4_K_M dequantization, GGUFSeer, and RuneWeaver.

## Future Expansions
- [ ] **Mímisbrunnr (External Knowledge Base):** Integrate RAG support seamlessly into `MimirWell` memory pool.
- [ ] **Multi-GPU Orchestration:** Enable sharding tensors across multiple local GPUs without degrading inference speed.
- [ ] **RoPE (Rotary Position Embeddings):** Implement RoPE in `core/compute.mojo` for position-aware attention.
- [ ] **RMSNorm:** Implement Root Mean Square Layer Normalization kernel.
- [ ] **Full GGUF Tensor Metadata Parsing:** Walk the KV dictionary and tensor info entries to load real model weights.
- [ ] **Inference Pipeline (Forward Pass):** Wire together the kernels into a full LLM forward pass: embed → RMSNorm → Attention → FFN → decode.
