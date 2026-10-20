# AES500-081 — Allocation ownership records contract

## Objective

Decide whether the current `MimirWell` and `RuneTensor` boundaries can support
records that establish allocation ownership. This slice is a contract and
disposition only; it does not add a record type or change allocator behavior.

## Current owner and inputs

- `aesir_engine/core/mimir_well.mojo::MimirWell.allocate(elements)` accepts an
  element count and returns a raw F16 pointer after advancing the arena's bump
  offset, subject to its current capacity comparison. The implementation
  computes `offset + elements` directly; overflow-safe arithmetic for that
  addition is not established.
- `reset()` and `reset_kv_cache(...)` rewind arena state and permit storage to
  be reused. The current offset is allocator state, not a durable allocation
  identity.
- `RuneTensor` stores a raw pointer, 2D shape, and quantization metadata. Its
  checked constructor validates shape arithmetic and null/sentinel addresses,
  but does not establish pointer provenance, allocation capacity, liveness, or
  exclusive ownership.

## Decision

Defer ownership records until the repository has a sound non-reused owner
identity and a reset-aware lifetime mechanism. A record inferred from the
current offset, base address, or pointer is not sufficient: those values can be
reused or can refer to external storage, and the APIs do not presently bind a
tensor to its originating live arena allocation.

AES500-082 will capture the baseline inventory of arena constructors,
allocations, rewind paths, copied pointers and aliases, together with relevant
Mojo copy/move semantics. Any later implementation contract must define how a
live non-copyable owner is identified, how reset invalidates old records,
whether generation exhaustion fails closed, and how validation is tied to the
same owner instance.

## Invariants and exclusions

- No allocation record is created by this slice.
- Existing `allocate`, reset, `RuneTensor`, and slice behavior remains
  unchanged.
- Arithmetic-only spans remain separate from allocation ownership evidence.
- A future record cannot itself free storage, extend lifetime, establish
  exclusivity, prevent aliasing, validate arbitrary strides, prove device
  bounds, or authenticate external pointers.
- Any later record must express units explicitly. The current arena allocator
  accepts F16 scalar elements; byte conversion is two bytes per element only
  where that representation is actually applicable.

## Future acceptance prerequisites

Before implementation, a new contract must show how the owner identity cannot
be copied or reused while records remain observable, and how rewind invalidates
all records issued before it without generation wrap or ABA revival. Once those
prerequisites exist, evidence should cover adjacent ranges, capacity edges,
wrong-owner rejection, stale records after reset and reallocation, fail-closed
generation exhaustion, raw-pointer tensors remaining unproven, and external
pointers being rejected. No deallocation or lifetime extension is implied.

## Acceptance

This is a documentation-only disposition. The Architect's source inspection
must support the decision; the Auditor reviews scope and wording; `git diff
--check` must pass. No code or test behavior changes in this slice.
