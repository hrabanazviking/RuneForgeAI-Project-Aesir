# Core Domain: The Forge of Nidavellir & The Waters of Mímisbrunnr

## Domain Overview
The `core` domain houses the mathematical engine room and memory management layer of Project Aesir. The legacy host primitives remain useful for the CPU slice; the native Gemma CUDA session is a separate, bounded production path.

- **`mimir_well.mojo` (The Waters of Mímisbrunnr):** Manages the CPU workspace and lightweight borrowed tensor descriptors. Generic NPU/GPU buffers remain host descriptors.
- **`gemma4_cuda.mojo` / `gemma4_kernels.mojo`:** Own the supported CUDA profile's device buffers, packed weights, KV cache, and transformer kernels for dense text-only Gemma 4 E4B Q4_K_M.
- **`compute.mojo` (The Forge of Nidavellir):** Executes host Mojo SIMD primitives. Its generic NPU/GPU gateways remain bounded and do not replace the specialized Gemma CUDA session.

## Key Invariants
- Persistent tensor workspaces are carved from `MimirWell`; lists, strings, and
  temporary values still allocate elsewhere in generation.
- Compute loops operate directly on `RuneTensor` pointers, but their complete
  safety, numerical breadth, and allocation behavior remain hardening work.
- SIMD operations execute directly on `RuneTensor` data pointers via `unsafe_load` / `unsafe_store`.
