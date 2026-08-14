# Bug Report: `shard_split_cols` Dynamic Heap Allocation and Memory Leak

**Bug ID**: 0013
**Title**: `shard_split_cols` allocates heap memory and leaks pointers during multi-device matrix partitioning
**Component**: `core/mimir_well.mojo`
**Status**: Resolved

## Description
In `core/mimir_well.mojo`, when `shard_split_cols` is called on a 2D matrix (`T.rows > 1`), it splits column dimensions by allocating new heap memory per shard:
```mojo
var allocation = alloc(Layout[Scalar[f16]](count=T.rows * shard_cols))
var ptr = allocation^.unsafe_leak()
```
Because `shard_split_cols` is called during the multi-device forward pass in `core/inference.mojo` (splitting key slices, value slices, output weights, and FFN down weights across devices), this creates two major invariant violations:
1. **Dynamic Memory Allocation in Inference Path**: Bypasses `MimirWell` by calling system `alloc()`.
2. **Unbounded Heap Memory Leak**: Leaks the heap memory using `unsafe_leak()` on every single token generation step without ever calling `unsafe_free()`.

## Recommendation for the Forge Worker
Refactor column partitioning to draw slice memory directly from `MimirWell` or pass caller-provided pre-allocated shard destination buffers, maintaining zero-copy or zero-dynamic-allocation invariants across the Bifrost Shard Matrix.

## Mythic Engineering Rite Completed
Resolved by The Forge Worker (Eldra Járnsdóttir / Eiríkr Járnhönd): Updated `shard_split_cols` for 2D matrices (`T.rows > 1`) to allocate slice buffer memory directly from `MimirWell` via `well.allocate(T.rows * shard_cols)`, ensuring zero dynamic heap allocations and zero memory leaks.
