# Bug 0027: RuneTensor Validation Claim Does Not Match Its Constructor

## Symptom

Active TODO and capability-ledger text say `RuneTensor` validates positive
dimensions, shape overflow, invalid spans, and null/address-1 pointers. Its only
constructor assigns `rows * cols` and the pointer without checking any input.

## Expected

Untrusted loader/cache inputs pass through a checked constructor that rejects
invalid shapes and pointers. Low-level raw views remain explicitly labeled
unchecked rather than inheriting a false safety claim.

## Suspected Domains

- core tensor descriptors
- GGUF tensor mapping
- cache pointer admission
- capability evidence governance

## Invariant Violated

Public evidence must identify the actual enforcing boundary. An unchecked raw
view cannot be described as validating inputs it merely stores.

## Repair Contract

- Add a checked, raising tensor-admission function without breaking raw copies.
- Detect nonpositive dimensions and wrapped products before trusting `size`.
- Reject null/address-1 pointers.
- Migrate GGUF and public cache pointer boundaries.
- Keep allocation-span/lifetime validation open until owner evidence exists.
