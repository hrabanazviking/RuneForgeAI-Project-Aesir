# ADR 0002: Zero-Allocation Memory Pool (MimirWell)

## Status
Accepted

## Context
Dynamic memory allocation (`malloc`, heap allocations) during the LLM forward pass causes non-deterministic latency spikes, heap fragmentation, and cache misses.

## Decision
We mandate that memory allocation occur exactly ONCE during system startup (`MimirWell`). Workspace RAM/VRAM is pre-allocated as a single contiguous memory block. All tensors (`RuneTensor`) are created as lightweight descriptors wrapping zero-copy offsets into this block.

## Consequences
- **Positive:** Guaranteed zero heap allocations during the active inference loop. Completely predictable VRAM utilization. Maximum cache line alignment.
- **Negative:** Pool capacity must be sized at launch. Exceeding capacity causes a hard engine abort rather than dynamic expansion.
