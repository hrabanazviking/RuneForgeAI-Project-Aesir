# CUDA allocation lifetime implementation — 2026-10-10

AES500-024 adds a session-local allocation ID and an ArcPointer-backed logical
owner ledger to GPU-2 resources and GPU-3 GEMM allocations. GPU-2 budget remains
monotonic; this ledger does not return budget or represent MAX pool/driver memory.

## Bound physical evidence

- MAX 26.5.0, Mojo 1.0.0 (`ed45d567`).
- NVIDIA GeForce RTX 2060 with Max-Q Design, stable ID `cuda:max-id:0`.
- `aesir_engine/core/cuda_resources.mojo` SHA-256:
  `236adc4df718abcac4902f4a0c89e1de848d04632fe1a2a4b30afd2b40353966`.
- `aesir_engine/core/cuda_compute.mojo` SHA-256:
  `59961bc52e5e108fb47818a24e91c9a692e236c8c753099f64e500184d544ed5`.
- GPU-2 binary SHA-256:
  `701422aefd0a7e60329b63bc17a57c48179e9dce29abfa05afb94a171c4c267b`.
- GPU-3 binary SHA-256:
  `08e6b09927159b3fd72615eb4f942907efde173a589e19ecee84297bb0d52a84`.

Both opt-in probes returned 0. GPU-2 created two allocations per session,
completed three synchronized upload/download rounds per allocation, rejected
invalid and over-budget requests without changing live-owner accounting, and
reported zero logical owners after each scope. Its final stdout SHA-256 is
`be0347a61ddc8537269e0b6c41805822d0592aa0824befbedd223f06de23ca22`.

GPU-3 ran exact 2x3x4 and tail 17x19x23 GEMM shapes for three executions each.
After both moved executors left scope, its assertions observed zero logical live
owners, six fenced owner destructions, zero known unfenced destructions, zero
live bytes and no accounting error. The existing numerical gate reported exact
max error 0.0 and tail max error 0.0009613037. Its final stdout SHA-256 is
`1b2718b44f393827a7cafb530291daaa178445f8a57bad64923155d661aec315`.

## Validation and limits

The full Mojo master suite passed with 190 passed, 0 failed and 1 skip for the
absent optional external GGUF fixture. The focused CUDA trace Python contracts
passed 74 tests; the documentation drift and whitespace checks passed.

The tracker IDs are unique only within one `CUDADeviceResources` session. Its
ArcPointer extends tracker lifetime, but tracker payload mutation is not
thread-safe. Pending work is observed only through allocation transfer methods
and the native GEMM executor; direct public `device_buffer` use can bypass that
counter. `fenced_owner_destroyed` means no known tracked operations remained
when the Mojo wrapper owner was destroyed. It does not claim async teardown
safety, underlying allocator reuse, CUDA driver free-memory changes, concurrent
use, failure recovery or production readiness. Full logs and private run receipt
remain outside Git.
