# Bug 0028: PagedKVCache Simulates Allocation with a Counter

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

## Repair Contract

- Preserve the API surface.
- Reject construction and block operations with stable unsupported errors.
- Add counted regression evidence.
- Keep PagedAttention status `missing`.
