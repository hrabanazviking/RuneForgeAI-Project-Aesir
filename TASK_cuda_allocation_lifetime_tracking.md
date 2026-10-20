# AES500-021 — CUDA allocation lifetime tracking contract

## Objective

Define an auditable ownership and accounting contract for `CUDADeviceResources`
and move-only `CUDAF16Allocation` before changing CUDA resource behavior. The
current design has a session budget and an allocation counter; it does not yet
publish per-allocation identity, release accounting, or an explicit distinction
between object lifetime and asynchronous stream completion. This slice documents
the contract only. It does not change allocation or reuse behavior.

## Owner and boundary

- Primary owner: `aesir_engine/core/cuda_resources.mojo`.
- Interface owner: `aesir_engine/core/INTERFACE.md`.
- Existing focused consumers: `aesir_engine/tests/test_gpu_resources.mojo` and
  `aesir_engine/tests/test_gpu_gemm.mojo`.
- Include host-pinned and device F16 buffers created as one logical allocation,
  the selected `DeviceContext`, queued upload/download work, and conservative
  session budget accounting.
- Exclude general allocator telemetry, process-wide device accounting, pool
  reuse, arbitrary raw-pointer ownership, allocator performance claims, and
  inference-path allocation redesign.

## Inputs and observable outputs

Inputs are a validated selected CUDA device, explicit device and pinned-host
limits, positive F16 element count, and operations that enqueue copies or
synchronize the owning context. Observable outputs are allocation success or
explicit failure, the exact logical allocation count/byte reservation, data
transfer completion, and logical owner destruction, known wrapper/executor pending-work count, and
explicit stream completion status under the library's documented rules.

## Invariants to prove before implementation

1. Each successful logical F16 allocation owns exactly one matched host buffer
   and one device buffer, bound to one validated context and stable device ID.
2. A failed partial allocation releases every resource it acquired and restores
   the exact reservation once; it cannot increment success counters.
3. A returned allocation has a unique stable identity suitable for live-state
   accounting; identity cannot be reused while an earlier owner is live.
4. Owner destruction accounting is separate from bytes reserved by policy and
   bytes reusable by the underlying MAX allocator. It must not decrement the
   monotonic budget or imply pool/driver reuse.
5. The tracker reports known pending wrapper/executor operations at owner
   destruction, but is not a safety guard. Direct raw-buffer use can bypass it;
   no async teardown guarantee is inferred from host object drop.
6. Moves preserve one owner and one identity. Copies or double-release are
   rejected by the type/API contract.
7. Allocation failure, transfer failure, synchronization failure, and teardown
   failure remain distinguishable. No failed operation silently reports a
   completed release or restored reusable capacity.
8. Accounting is bounded and checked for integer overflow, duplicate identity,
   unknown release and underflow before mutation.

## Acceptance evidence for this contract slice

- Source inspection pins current behavior and identifies which invariants are
  already guaranteed by move-only Mojo ownership/MAX `Deinitable` resources and
  which require a later implementation or external-library evidence.
- The follow-on implementation slice must not begin until the stream completion
  semantics and exact lifetime owner are resolved. If the dependency cannot
  guarantee safe release, retain resources until an explicit synchronization
  fence succeeds and expose a failure state rather than claiming release.
- The next baseline slice records current counters, failure rollback, transfer
  behavior and teardown observations without modifying production code.
- The contract does not assert that underlying allocator memory is returned to
  the driver or immediately reusable when a logical owner drops.

## Required follow-on sequence

AES500-022 baseline evidence is captured in
`docs/evidence/cuda-allocation-lifetime-baseline-2026-10-10/`. AES500-023 defines the narrow interface
and negative cases. AES500-024 implements the bounded ledger in
`TASK_cuda_allocation_lifetime_implementation.md`. AES500-025 adds adversarial
executable evidence; AES500-026 checks the
adjacent GEMM owner end to end; AES500-027 exercises hostile failure and cleanup
paths; AES500-028 obtains independent review; AES500-029 synchronizes interface,
ledger and operating docs; AES500-030 performs the pinned build, test, push and
exact-head hosted release gate.

No runtime, production device, memory-reuse, leak-freedom, crash-recovery or
performance claim is made by this contract document.

## Accepted bounded outcome

The implementation and evidence chain are recorded in
`TASK_cuda_allocation_lifetime_implementation.md`,
`TASK_cuda_allocation_lifetime_integration.md`, and the four receipts under
`docs/evidence/cuda-allocation-lifetime-*-2026-10-10/`. AES500-028's independent
review confirms the synchronous single-host-thread tracker behavior and the
per-GEMM owner/pending assertions. It does not establish arbitrary copy/double
release behavior outside the exercised Mojo ownership paths, concurrent tracker
mutation, or release safety after failed asynchronous operations. AES500-030
remains the pinned release gate.
