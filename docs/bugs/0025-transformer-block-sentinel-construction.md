# Bug 0025: TransformerBlock Construction Retains Invalid Sentinel Weights

## Symptom

The GGUF-backed `TransformerBlock` constructor substitutes a zero-sized
`RuneTensor` backed by address `1` for each missing layer tensor. The legacy
three-argument constructor creates nine of those tensors, and `copy()` first
constructs that invalid object before overwriting its fields.

## Expected

A runnable transformer block exists only when every required layer weight has
positive dimensions and a usable pointer. Incomplete construction fails with a
precise error before inference or copying can dereference invalid memory.

## Suspected Domains

- core inference construction
- GGUF layer-weight validation
- explicit copy semantics

## Invariant Violated

Address `1` is never a usable tensor address. Missing required model state must
fail at the owning construction boundary rather than become a runnable-looking
object.

## Reproduction

1. Construct `GGUFSeer("dummy.gguf")` with no layer tensors.
2. Call `TransformerBlock(0, 4, 4, seer)`.
3. Before repair, observe a returned block whose nine weights have size zero
   and data address `1`.
4. Call `TransformerBlock(0, 4, 4)` and observe the same invalid state without
   any loader involvement.

## Repair Contract

- Validate layer metadata at loader-backed construction.
- Require all nine layer tensors to be present, non-empty, and non-sentinel.
- Keep the legacy signature as an explicit non-runnable error boundary.
- Copy complete validated state without constructing a sentinel-bearing block.
- Prove each rejection and the valid construction/copy path in the master suite.
