# Task: Strategy5 owned trace interface contract

## Slice and dependency

AES500-013 defines the typed fixture capability, range labels, collection schema
and exact ownership contract for strategy5 tracing. It follows the accepted fresh
unprofiled source baseline in AES500-012. This slice is interface-only; implementation,
physical tracing, scoring and production selection remain later slices.

## Contract

- The fixture exposes `small_tracing=False` by default and seals the constructor
  capability against drift. It requires strategy5.
- Tracing is mutually exclusive with `small_controls`, control-capable replay,
  strategy4 controls and borrowed strategy4 tracing. Enabled controls refuse before
  control state mutation. Unsupported strategies remain mutation-free.
- The collector preserves one complete synchronized `aesir.fixture.prefill`
  parent. Each small-attention tile enqueue owns one nested same-thread child named
  `aesir.attend.small.b4` or `aesir.attend.small.b32`. No child exists for scalar
  single-token attention. Strategy4 keeps its existing `aesir.attend.fused.*`
  namespace and semantics.
- One child corresponds to one tile enqueue and exactly28 successful layer kernel
  launches. Every launch must correlate through successful CUDA runtime API
  activity to the actual small-attention kernel and canonical grid `(24,batch,1)` /
  block `(128,1,1)`. Preserve full asynchronous intervals.
- The trace collector emits all source-bound vectors/state/cache/input IDs, actual
  rotary/elementwise/down/small/closed-fused/scalar counts and guards. It never
  enables strategy4 projection-stage labels.
- Complete-session process/device/runtime/kernel/resource ownership validates
  before range selection. The full source5/current model/current binary/CSV/report/
  SQLite evidence is rehashed after validation.
- GPU/API durations remain diagnostic. No occupancy, spill, root-cause, speedup,
  provider, general-device or runtime-selection claim is part of the interface.

## Acceptance

Interface docs identify owners, schemas, boundaries and unsupported claims. Tests
for later code must include stale/drifted capability, unsupported combos before
mutation, absent/duplicate/wrong/overlapping/foreign-thread labels, launch count,
kernel-prefix/geometry mismatch, incomplete correlations and tamper/interruption
retention. This contract does not mark physical tracing accepted.
