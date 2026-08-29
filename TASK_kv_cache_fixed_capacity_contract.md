# Task: KVCache Fixed-Capacity Contract

## Authorization

Volmarr instructed Project A.E.S.I.R. to repair all non-working code and push
each completed step to the actual `main` branch. This Stage 1 slice may change
KV-cache bounds, tests, and synchronized active documentation. It authorizes no
file deletion, model deletion, historical-record deletion, or capability
promotion.

## System Statement

`KVCache.append()` reduces every non-negative position modulo `max_seq_len`,
while `get_k_slice()` and `get_v_slice()` always expose the physical prefix in
index order. The result is not a chronological ring buffer: a write at capacity
silently overwrites token zero and subsequent reads cannot reconstruct logical
order. Active comments and tests nevertheless describe ring rotation.

## Owning Domain

- `aesir_engine/core/mimir_well.mojo` — cache storage and bounds
- `aesir_engine/core/inference.mojo` — inference-stage terminology
- cache tests and master-suite integration — executable evidence
- active architecture/data-flow/domain documentation — public contract
- capability ledger, TODO, roadmap, devlog, and bug record — synchronized truth

## Desired End State

1. `KVCache` is explicitly a contiguous, fixed-capacity chronological prefix.
2. `append()` accepts only `0 <= pos < max_seq_len`; capacity overflow raises
   before mutating cache memory.
3. Pointer-backed construction validates dimensions and rejects null/address-1
   storage just like the arena-backed public boundary.
4. Executable tests fill a cache, reject the first out-of-capacity append, and
   prove the original first token remains unchanged.
5. Active code and documentation stop describing the implementation as a ring
   buffer; preserved historical/target text remains clearly non-current.
6. Paged or chronological wraparound stays unimplemented and unclaimed.

## Invariants

- Cache positions never alias through implicit modulo arithmetic.
- A failed append does not alter any key/value cell.
- Slice rows remain chronological positions `[0, seq_len)`.
- No public constructor returns a cache with invalid dimensions or sentinel
  storage.
- No file, function, model, fixture, asset, or historical record is deleted or
  moved.
- `CAPABILITY_LEDGER.md` remains the maturity authority.

## Verification Plan

- fixed-capacity fill/overflow/non-mutation regression
- existing multi-step inference cache accumulation
- 132/0/1 master suite and native build
- intentional fail-closed negative control
- repository consistency and fixture-policy validators
- `git diff --check`
- hosted GitHub Actions on `main`

## Completion Boundary

This slice makes the current fixed cache honest and safe. It does not implement
sliding-window attention, chronological ring reordering, page allocation,
PagedAttention, batching, or concurrent-session cache ownership.
