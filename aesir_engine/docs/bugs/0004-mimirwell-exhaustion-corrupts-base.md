# Bug Report: MimirWell Exhaustion Returns Base Pointer (Memory Corruption)

**Bug ID**: 0004
**Title**: `MimirWell.allocate` returns `base_ptr` on pool exhaustion, corrupting base tensors
**Component**: `core/mimir_well.mojo`
**Status**: Resolved

## Description
When the `MimirWell` memory pool is exhausted (`self.offset + elements > self.capacity`), `MimirWell.allocate()` previously printed a fatal log and returned `self.base_ptr`. Returning `self.base_ptr` meant that any subsequent tensor write operations would overwrite the memory starting at index 0 of the pool, corrupting model weights or initial embeddings.

## Fix Applied
Updated `MimirWell.allocate()` to return a null pointer (`Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=0)`) when memory is exhausted, preventing pool corruption.

## Mythic Engineering Rite Completed
Additive fix applied to maintain memory safety invariants.
