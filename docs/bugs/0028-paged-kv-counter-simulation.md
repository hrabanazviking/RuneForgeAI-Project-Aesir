# Bug 0028: PagedKVCache Simulates Allocation with a Counter

**Resolved 2026-09-01.** `PagedKVCache` now owns real logical page tables,
physical owner maps, translated K/V access, per-layer initialized lengths,
checked exhaustion, release, and reuse. The capability is `partial` because
model attention integration, eviction, prefix sharing/copy-on-write, GPU pages,
and memory-efficiency evidence remain open.

## Symptom

`PagedKVCache` claims non-contiguous blocks and virtual page-table indexing but
contains only one contiguous cache and a decrementing `free_blocks` counter.
It records no allocated set, so duplicate frees can also inflate capacity.

## Expected

Until a real page table, ownership map, translation layer, eviction policy, and
sharing contract exist, the reserved API must reject use instead of returning
fabricated block indices.

## Invariant Violated

Bookkeeping-shaped output is not execution evidence. A missing subsystem must
fail closed at its public boundary.

## Original Repair Contract

The following fail-closed contract governed the period before the 2026-09-01
implementation and is retained as bug history:

- Preserve the API surface.
- Reject construction and block operations with stable unsupported errors.
- Add counted regression evidence.
- Keep PagedAttention status `missing` until a real page manager exists.
