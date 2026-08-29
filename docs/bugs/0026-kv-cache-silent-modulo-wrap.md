# Bug 0026: KVCache Silently Wraps Without Chronological Read Semantics

## Symptom

`KVCache.append()` maps every non-negative position through
`pos % max_seq_len`, but both slice functions expose only the physical prefix.
Writing position `max_seq_len` therefore overwrites token zero while reads still
present that slot as the oldest chronological token.

## Expected

The current contiguous cache accepts only positions in
`[0, max_seq_len)`. Capacity overflow raises before memory mutation unless and
until a complete sliding-window contract provides eviction and chronological
reordering.

## Invariant Violated

A logical token position must not silently alias an earlier position. Returned
slice row order must match chronological token order.

## Repair Contract

- Reject negative and out-of-capacity append positions.
- Remove modulo slot selection.
- Validate pointer-backed cache construction.
- Prove full-capacity fill, overflow rejection, and non-mutation.
- Replace active ring-buffer claims with the fixed-capacity contract.
