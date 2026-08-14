# Core Domain: The Forge of Nidavellir & The Waters of Mímisbrunnr

## Domain Overview
The `core` domain houses the mathematical engine room and memory management layer of Project Aesir.

- **`mimir_well.mojo` (The Waters of Mímisbrunnr):** Manages single contiguous VRAM/RAM allocation (`MimirWell`) and lightweight zero-copy tensor descriptors (`RuneTensor`).
- **`compute.mojo` (The Forge of Nidavellir):** Executes hardware-accelerated SIMD kernels: 32x32 block-tiled GEMM, fused Flash Attention-2, SiLU/GeGLU activations, and native Q4_K_M dequantization.

## Key Invariants
- Zero heap allocation during inference.
- Zero dynamic string or object creation in compute loops.
- SIMD operations execute directly on `RuneTensor` data pointers via `unsafe_load` / `unsafe_store`.
