# Bug Report: MimirWell Dynamic Allocation and Leak

**Bug ID**: 0001
**Title**: Dynamic memory allocation and leak on memory exhaustion
**Component**: `core/mimir_well.mojo`
**Status**: Resolved

## Description
The `MimirWell` struct is explicitly designed to forbid dynamic allocation during inference, preserving a contiguous block of VRAM/RAM. However, in the `allocate` function, if the memory is exhausted, the system dynamically allocated a 0-sized memory block (`alloc(Layout[Scalar[f16]](count=0))`) and leaked it (`unsafe_leak()`) before returning it. This violates the engine's invariant and creates a memory leak on every failed allocation.

## Fix Applied
I replaced the dynamic allocation and leak with a simple return of a null pointer (`Pointer[...](unsafe_from_address=0)`).

## Mythic Engineering Rite Completed
Additive fix applied. The invariant is now strictly enforced.
