# AES500-082 — Allocation ownership baseline

## Identity and reproduction

- Slice: AES500-082, allocation ownership records — baseline.
- Repository commit before this receipt: `aa47a2c0f3c620d65dec2acde63d50d05a24e3ff`.
- Toolchain: Mojo 1.0.0 (`ed45d567`), from `pixi run mojo --version`.
- Source owner: `aesir_engine/core/mimir_well.mojo`.
- Census command: `rg -n 'MimirWell\(|\.allocate\(|\.reset\(|reset_kv_cache\(|Pointer\[Scalar\[f16\]|RuneTensor\[' aesir_engine/core aesir_engine/tests --glob '*.mojo'`.
- Census output was captured during this task at `/tmp/aes500-082-pointer-inventory.txt` (891 matches; local scratch, not a repository artifact).

## Source observations

- `MimirWell` stores `base_ptr`, element `capacity`, and current `offset`; its
  constructor allocates and leaks the backing allocation into a raw pointer and
  its deinitializer frees that pointer.
- `allocate(elements)` returns `base_ptr.unsafe_offset(offset)` and advances
  `offset`. It records no per-allocation start, length, ID, or descriptor.
- `reset()` sets offset to zero. `reset_kv_cache(start)` admits
  `0 <= start <= offset` and rewinds to that point. Neither method carries a
  generation or invalidates external pointer values.
- `RuneTensor` is declared `Copyable`, explicitly copies its raw pointer, and
  exposes raw get/set plus `copy()`. `checked()` checks positive dimensions,
  product overflow, and null/address-1 only; it does not check arena provenance
  or live capacity.
- KV cache slices build new `RuneTensor` values from `unsafe_offset` pointers.
  The resulting descriptors therefore do not carry an arena allocation ID.
- Core runtime code uses `reset_kv_cache` to return temporary per-layer
  workspace to a saved arena offset, including on an error path. This confirms
  rewinds are live behavior, not only test helpers.
- `MimirWell` has no explicit `Copyable` declaration or custom copy initializer
  in the inspected definition. This source observation alone does not establish
  all compiler-enforced move/borrow/lifetime guarantees.

## Existing focused evidence and gaps

- `aesir_engine/tests/test_mimir_well.mojo::test_mimir_well_allocation` checks
  offset advancement for two positive allocations and `reset_kv_cache` back to
  the original offset. It does not assert exact returned addresses, full
  non-overlap ranges, capacity edges, wrong-owner behavior, stale-pointer
  invalidation, or reset/reallocate ABA behavior.
- `aesir_engine/tests/test_memory_refinements.mojo::test_mimir_well_telemetry`
  checks reported byte telemetry and that `reset()` restores reported free
  capacity. It does not dereference retained pointers after reset.
- AES500-085 adds `memory.allocation_bounds` to `run_all.mojo`. It asserts that
  two allocations of 3 and 5 F16 elements have exactly adjacent typed-pointer
  addresses, that their final offset equals the eight-element pool capacity,
  and that zero, negative, and oversized requests reject without mutating the
  arena offset. The tested rejection paths do not rely on integer address
  conversion or dereference stale pointers.
- Existing tensor tests and constructors pass raw pointers directly; their
  presence proves the API permits such views, not that their storage belongs to
  a specific arena or remains live.
- No baseline command in this slice attempted use-after-reset, use-after-free,
  or double-deinit behavior. Those would require a dedicated safe memory
  contract and are not inferred here.

## Disposition

The baseline confirms that allocation provenance and lifetime are not
represented in these types. Stable owner identity, copy/move behavior for the
arena, alias policy, and reset invalidation remain design prerequisites. No
source or test code changed during AES500-082; AES500-085 later adds the focused executable checks described below.

## AES500-085 focused evidence update

The test suite extension records current allocator boundaries only. The exact
master command is `pixi run mojo run --target-accelerator sm_89
aesir_engine/tests/run_all.mojo`; observed result is 194 passed, zero failed,
one skipped, 195 total, exit 0. It does not establish pointer ownership,
capacity provenance for arbitrary tensors, stale-pointer invalidation, or
overflow safety of the allocator's `offset + elements` expression.
