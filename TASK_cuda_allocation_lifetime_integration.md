# CUDA allocation lifetime tracking: GEMM integration

## Slice

AES500-026 — integration evidence for the session-local logical allocation
tracker introduced by AES500-024 and hardened by AES500-025.

## Scope

Exercise the adjacent GPU-3 reusable F16 GEMM executor while its three
`CUDAF16Allocation` owners are live. Prove distinct owner IDs, exact logical
registration count/bytes at creation, zero pending work before execution, zero
pending work after each successful context synchronization, retention of all
three logical owners immediately after each GEMM returns, and the final
post-scope owner-destruction state. Continue to validate numerical output and
resource reuse using the existing physical probe.

## Acceptance

- The selected GPU-3 physical probe passes for exact and varied shapes over all
  configured rounds.
- Every accepted GEMM returns with all three pending-work counts at zero.
- Tracker count and byte totals match the executor's three buffers at executor
  creation; owner IDs are pairwise distinct. All three owners remain counted
  immediately after each successful GEMM, and the existing probe verifies the
  final post-scope state.
- Existing output parity, fixed allocation count, and session cleanup evidence
  continue to pass.
- Preserve the boundary: this is synchronous integration evidence for the
  declared executor and device. It does not prove concurrent host access,
  implicit destruction fences, raw pointer safety, allocator reuse, or driver
  memory return.

## Commands

Run the opt-in probe on a compatible selected device:

```sh
pixi run mojo run --target-accelerator sm_75 aesir_engine/tests/test_gpu_gemm.mojo --gpu-3
```

Run the full local suite and repository documentation checks before release.

## Evidence

Physical stdout, toolchain, selected-device identity, source hashes, and the
bounded result belong in
`docs/evidence/cuda-allocation-lifetime-integration-2026-10-10/README.md`.
