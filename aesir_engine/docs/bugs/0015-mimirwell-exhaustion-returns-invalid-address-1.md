# Bug Report: `MimirWell.allocate` Address 1 Return on Pool Exhaustion and Non-Nullable Pointer Constraint

**Bug ID**: 0015
**Title**: `MimirWell.allocate` returns sentinel `unsafe_from_address=1` on pool exhaustion due to Mojo non-nullable `Pointer` constraint
**Component**: `core/mimir_well.mojo`
**Status**: Resolved

## Description
In `core/mimir_well.mojo`, `MimirWell.allocate()` returns `Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1)` when memory capacity is exhausted (`self.offset + elements > self.capacity`).
In Mojo standard library, `Pointer` enforces a compile-time constraint (`Pointer is non-nullable. To construct a null pointer, use Optional[Pointer] to model nullability.`). Attempting to construct `Pointer(unsafe_from_address=0)` causes a compiler assertion failure. Address `1` is used as a non-null sentinel address across the engine (`GGUFSeer`, `TransformerBlock`, `MimirWell`).

## Recommendation for the Forge Worker
Where sentinel values are required without using `Optional[Pointer]`, sentinel address `1` must be checked explicitly before dereferencing (`ptr.address != 1`), or return `Optional[Pointer[...]]` for nullable allocation APIs.

## Mythic Engineering Rite Completed
Verified by The Auditor (Sólrún Hvítmynd). Documented standard library constraint.
