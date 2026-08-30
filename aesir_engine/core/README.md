# Core Domain: The Forge of Nidavellir & The Waters of Mímisbrunnr

## Domain Overview
The `core` domain houses the mathematical engine room and memory management layer of Project Aesir. The legacy host primitives remain useful for the CPU slice; the native Gemma and Llama 3 CUDA sessions are separate, bounded runtime paths.

- **`mimir_well.mojo` (The Waters of Mímisbrunnr):** Manages the CPU workspace and lightweight borrowed tensor descriptors. Generic NPU/GPU buffers remain host descriptors.
- **`gemma4_cuda.mojo` / `gemma4_kernels.mojo`:** Own the supported CUDA profile's device buffers, packed weights, KV cache, and transformer kernels for dense text-only Gemma 4 E4B Q4_K_M.
- **`llama3_cuda.mojo` / `llama3_kernels.mojo`:** Own dense Llama 3 8B Stheno CUDA inference, F16 KV, adjacent-pair RoPE, SiLU and scaled GQA. Reuse packed matvec/norm primitives; cap output by remaining 8K context without truncating history.
- **`compute.mojo` (The Forge of Nidavellir):** Executes host Mojo SIMD primitives. Its generic NPU/GPU gateways remain bounded and do not replace the specialized Gemma CUDA session.

## Key Invariants
- `native_hardware.mojo`, `inference_memory.mojo` and `runtime_plan.mojo` own
  Linux resource observations, checked native model memory counts and CUDA
  device selection. The facade exports these; CLI only formats their results.
- Persistent tensor workspaces are carved from `MimirWell`; lists, strings, and
  temporary values still allocate elsewhere in generation.
- Compute loops operate directly on `RuneTensor` pointers, but their complete
  safety, numerical breadth, and allocation behavior remain hardening work.
- SIMD operations execute directly on `RuneTensor` data pointers via `unsafe_load` / `unsafe_store`.
