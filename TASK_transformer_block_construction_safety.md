# Task: TransformerBlock Construction Safety

## Authorization

Volmarr instructed Project A.E.S.I.R. to repair all non-working code and push
each completed step to the actual `main` branch. This runtime-safety slice may
change Transformer block construction, copying, tests, and their synchronized
documentation. It authorizes no file deletion, model deletion, historical
record deletion, or unsupported capability promotion.

## System Statement

`TransformerBlock` currently manufactures zero-sized weight tensors backed by
address `1` whenever a required GGUF tensor is absent. Its three-argument
constructor creates the same sentinel-bearing object and `copy()` depends on
that constructor. These paths produce runnable-looking blocks whose first
real use can dereference invalid memory instead of reporting an incomplete
model at the construction boundary.

## Owning Domain

- `aesir_engine/core/inference.mojo` — construction and copy invariants
- `aesir_engine/tests/test_inference.mojo` — executable regression evidence
- `aesir_engine/core/INTERFACE.md` and `aesir_engine/tests/INTERFACE.md` — API
  and test contracts
- `docs/bugs/` — durable defect record
- capability ledger, TODO, roadmap, changelog, and devlog — synchronized truth

## Desired End State

1. Loader-backed construction rejects invalid dimensions and every missing or
   empty required layer tensor with a precise error.
2. No `TransformerBlock` constructor or copy path manufactures an address-1
   tensor.
3. The legacy three-argument overload remains present but is explicitly
   non-runnable and fails closed.
4. `copy()` constructs a complete block directly from validated source fields.
5. Executable tests prove missing-tensor rejection, empty-tensor rejection,
   legacy-constructor rejection, valid construction, copying, and the existing
   synthetic forward pass.
6. Active documentation states the fail-closed boundary without promoting the
   broader inference capability.

## Invariants

- Never dereference, retain, or emit address `1` from a Transformer block.
- Required model weights fail at construction rather than during inference.
- Preserve the legacy overload as a compatibility error boundary; do not
  silently create a fake or partially initialized runtime object.
- A copied block carries all metadata and weight views from its valid source.
- No file, function, model, fixture, asset, or historical record is deleted or
  moved.
- `CAPABILITY_LEDGER.md` remains the maturity authority.

## Verification Plan

- focused construction-contract assertions inside the inference test case
- complete master suite with the intentional real-model skip unchanged
- native engine build and CLI help smoke test
- repository consistency, artifact, fixture, and documentation validators
- `git diff --check`
- hosted GitHub Actions on `main`

## Completion Boundary

This slice makes Transformer block construction and copying fail closed. It
does not validate every GGUF architecture-specific matrix dimension, certify
numerical model quality, remove unrelated sentinel uses, or promote full
inference beyond its current ledger status.

## Implementation Evidence

- `_required_block_weight()` rejects absent, empty, null, and address-1 layer
  tensors before a `TransformerBlock` can exist.
- The loader-backed constructor validates layer index, head dimension, and head
  count, then resolves all nine required tensors through that boundary.
- The three-argument constructor remains present but always raises a stable
  non-runnable error; it no longer creates any tensor.
- `copy()` uses a module-private complete-state token and copies only the
  metadata and validated tensor views of an existing block.
- The synthetic inference case proves missing, empty, sentinel, and legacy
  rejection plus valid construction/copy and the existing forward result.
- The broader memory-safety capability remains `missing`; unrelated unsafe
  pointer paths are outside this slice.
