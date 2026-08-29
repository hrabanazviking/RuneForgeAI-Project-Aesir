# Task: PagedKVCache Fail-Closed Boundary

## Authorization

Volmarr instructed Project A.E.S.I.R. to continue making all code real and push
each step to GitHub `main`. This slice may harden the existing `PagedKVCache`
API, add regression evidence, and synchronize active documentation. It
authorizes no deletion of files, functions, models, assets, or history.

## System Statement

`PagedKVCache` claims non-contiguous page-table storage, virtual-token mapping,
allocation, and fragmentation elimination. It actually embeds one contiguous
`KVCache` and adjusts a `free_blocks` counter. It has no page table, allocation
map, ownership state, eviction, sharing, or logical-to-physical translation;
`free_block()` can also double-free and grow the counter beyond capacity.

## Desired End State

1. The API remains present but cannot construct a runnable fake paged cache.
2. Construction and block methods fail with stable `not implemented` errors.
3. Executable tests prove fail-closed behavior.
4. Active architecture and ledger text identify the class as a reserved API,
   while true PagedAttention stays `missing` and on the roadmap.

## Invariants

- Counter arithmetic is never presented as page allocation.
- No caller can obtain a fabricated block index.
- The verified contiguous `KVCache` remains unchanged.
- No public function or historical record is deleted.
- No capability status is promoted.

## Verification Plan

- construction rejection in counted cache tests
- 132/0/1 master suite, native build/help, negative control
- repository and fixture validators
- hosted CI on `main`

## Completion Boundary

This slice removes fabricated success. It does not implement page tables,
eviction, sharing, block ownership, or PagedAttention execution.
