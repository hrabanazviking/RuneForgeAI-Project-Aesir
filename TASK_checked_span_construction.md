# AES500-061 — checked span construction contract

## Objective

Define one reusable arithmetic admission boundary for bounded half-open spans.
It must reject invalid ranges before callers form pointer offsets, allocate,
enqueue work, or mutate state.

## Owner and proposed interface

- Primary owner: new `aesir_engine/core/checked_span.mojo` module.
- Value: `CheckedSpan`, carrying `start`, exclusive `end`, and `length`.
- Factory: `checked_span(start: Int, length: Int, capacity: Int) raises -> CheckedSpan`.
- Unit: caller-defined integer units; all three inputs must use the same unit.

## Invariants

- `capacity`, `start`, and `length` are nonnegative.
- `start <= capacity` and `length <= capacity - start`.
- The exclusive end is computed only after those checks, as `start + length`.
- Accepted values satisfy `0 <= start <= end <= capacity` and
  `end - start == length`.
- Zero-length spans are valid, including `[capacity, capacity)`.
- Invalid inputs fail before pointer arithmetic, allocation, work enqueue, or
  mutation. Subtraction-first admission prevents overflowing an unchecked
  `start + length` expression.

## Explicit exclusions

This arithmetic value does not prove backing allocation ownership or actual
capacity, pointer validity or alignment, element-size conversion, aliasing or
disjointness, lifetime, synchronization, or GPU access bounds. This contract
does not migrate existing span checks or change tensor/cache behavior.

## Existing context

`RuneTensor.checked()` in `aesir_engine/core/mimir_well.mojo` admits positive
tensor dimensions and a non-sentinel pointer but does not prove allocation
capacity. `KVCache` has separate shape arithmetic. `dense_buffers.mojo` has
checked arithmetic local to its scratch layouts; fused attention and packed
kernel paths also retain owner-specific span gates. Later slices must inspect
these individually before any migration.

## Acceptance

This contract slice is documentation-only. `git diff --check` verifies patch
format. The later baseline slice records the pinned Mojo toolchain and current
span-check behavior. A future CPU-only focused test is planned at
`aesir_engine/tests/test_checked_span.mojo`, followed by
`pixi run mojo run aesir_engine/tests/run_all.mojo` when implementation and
integration slices are reached.
