# AES500-071 — RuneTensor 2D layout contract

## Objective

Specify the layout semantics of the existing `RuneTensor` descriptor and
separate them from future generic-rank or arbitrary-stride capabilities.

## Existing owner and inputs

- Owner: `aesir_engine/core/mimir_well.mojo::RuneTensor`.
- Checked factory arguments: `rows`, `cols`, typed data pointer, quantization
  flag and quantization format. The constructor validates dimensions, product
  overflow and null/address-1 pointer values; quantization metadata is copied
  and is not validated by this boundary.
- Descriptor state: `rows`, `cols`, product `size`, pointer and quantization
  metadata. The checked factory rejects nonpositive dimensions, wrapped product,
  and null/address-1 pointer values. The ordinary initializer remains an
  explicitly unchecked internal view constructor.

## Layout invariant

- Rank is exactly two.
- For logical scalar indexing, the descriptor denotes a contiguous row-major
  matrix.
- Implied element strides are `(cols, 1)`: element `(r, c)` is at linear
  element offset `r * cols + c`.
- `size` is the checked product `rows * cols` only for checked construction.
- `get_checked` and `set_checked` validate coordinates before delegating to the
  existing raw indexing operations.

## Exclusions

This contract does not add stride fields, arbitrary strides, views/slices, or
rank-generic shapes. It does not prove allocation capacity, pointer provenance,
alignment, lifetime, aliasing, synchronization, or quantized packed-storage
interpretation. Raw `get`/`set` remain unchecked, and downstream pointer
arithmetic is not migrated by this contract.

## Acceptance

This is a documentation-only contract slice. `git diff --check` verifies the
patch. The baseline slice will capture existing `RuneTensor` constructor,
indexing and checked-access behavior under the pinned Mojo toolchain before any
implementation change. Existing owner-level evidence includes
`pixi run mojo run -I aesir_engine aesir_engine/tests/test_kv_cache.mojo`.

## Future stride extension boundary

Any later explicit-stride capability requires a separate contract for stride
units, accepted positive/negative/zero values, reachable-span arithmetic,
overflow, and validation against a real backing allocation before storage or
indexing changes are implemented.

## AES500-074 implementation refinement

The source implementation centralizes the existing scalar row-major address
formula in a private `_linear_offset(r, c)` helper used by both raw `get` and
`set`. It stores no stride state and adds no bounds, allocation, or quantized
packed-storage behavior. Checked coordinate methods continue to perform the
coordinate validation before using raw indexing.
