# Task: Checked RuneTensor Boundary

## Authorization

Volmarr instructed Project A.E.S.I.R. to continue making all code real and to
push every completed step to the actual `main` branch. This Stage 1 slice may
add a checked tensor-construction boundary, migrate untrusted loader/cache
callers, add regression tests, and synchronize active documentation. It
authorizes no file, function, model, asset, fixture, or historical-record
deletion.

## System Statement

`RuneTensor.__init__()` is a non-raising raw view constructor used throughout
hot paths and explicit copy operations. Active TODO and ledger text currently
claim that this constructor validates positive dimensions, shape-product
overflow, and null/address-1 pointers, but it performs none of those checks.
Changing the constructor to `raises` would break non-raising view/copy paths and
hundreds of internal call sites, including tests that deliberately construct
invalid descriptors to verify downstream gates.

## Owning Domain

- `aesir_engine/core/mimir_well.mojo` — tensor descriptor and checked boundary
- `aesir_engine/loader/gguf.mojo` — untrusted model-file mapping
- cache constructors — untrusted pointer/dimension admission
- memory and loader tests — executable boundary evidence
- interface, ledger, TODO, roadmap, devlog, and bug record — synchronized truth

## Desired End State

1. The existing raw constructor remains available and is explicitly documented
   as an internal unchecked view constructor.
2. `RuneTensor.checked()` rejects nonpositive dimensions, overflowed shape
   products, and null/address-1 pointers before returning a descriptor.
3. GGUF tensor mapping and public pointer-backed cache construction use the
   checked boundary.
4. Executable tests prove valid construction and each rejection without unsafe
   dereference.
5. Active claims distinguish checked admission from raw internal view creation.

## Invariants

- No untrusted pointer or shape crosses into model/cache runtime state through
  the raw constructor.
- Existing explicit copy/view operations remain non-raising and allocation-free.
- Invalid descriptors used by negative tests remain local and are never
  presented as valid runtime tensors.
- Shape overflow is detected before a wrapped element count is trusted.
- No public API is deleted; existing valid behavior remains compatible.
- `CAPABILITY_LEDGER.md` remains the maturity authority.

## Verification Plan

- focused checked-construction boundary assertions
- loader/cache regression coverage
- 132/0/1 master suite and native build/help smoke test
- intentional fail-closed negative control
- repository consistency and fixture-policy validators
- `git diff --check`
- hosted GitHub Actions on `main`

## Completion Boundary

This slice makes untrusted tensor admission real and truthful. It does not make
raw pointer views memory-safe, add compile-time lifetimes, validate every
internal pointer span against its allocation owner, or promote the broader
memory-safe-failure capability.

## Implementation Evidence

- `RuneTensor.checked()` rejects nonpositive dimensions, wrapped shape products,
  and null/address-1 pointers before returning a view.
- The existing initializer now documents its unchecked internal-view contract
  and remains non-raising for copies and slices.
- All three GGUF mapping branches and both public cache storage paths use
  checked admission.
- The counted cache test proves valid admission and dimension, overflow, and
  sentinel rejection without dereferencing invalid memory.
- Active interface, ledger, TODO, roadmap, and architecture text now separate
  checked admission from still-open allocation-span and lifetime proof.
