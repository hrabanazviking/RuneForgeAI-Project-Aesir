# Core Domain: The Forge of Nidavellir & The Waters of Mímisbrunnr

## Domain Overview
The `core` domain houses the mathematical engine room and memory management layer of Project Aesir.

- **`mimir_well.mojo` (The Waters of Mímisbrunnr):** Manages one contiguous host-memory workspace (`MimirWell`) and lightweight borrowed tensor descriptors (`RuneTensor`). NPU/GPU buffers are host descriptors only.
- **`compute.mojo` (The Forge of Nidavellir):** Executes host Mojo SIMD experiments and activation primitives. NPU/GPU gateways explicitly reject execution; hardware names are reserved configuration values.

## Key Invariants
- Persistent tensor workspaces are carved from `MimirWell`; lists, strings, and
  temporary values still allocate elsewhere in generation.
- Compute loops operate directly on `RuneTensor` pointers, but their complete
  safety, numerical breadth, and allocation behavior remain hardening work.
- SIMD operations execute directly on `RuneTensor` data pointers via `unsafe_load` / `unsafe_store`.
