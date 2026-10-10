# CUDA allocation lifetime GEMM integration — 2026-10-10

AES500-026 extends the opt-in physical GPU-3 GEMM probe to inspect the
allocation tracker at the integration boundary.

## Bound run

- Source revision before this evidence commit: `0823a7bf3eab247dd12a34a2ae369f76b94dc76c`.
- Test source after AES500-028 review hardening:
  `aesir_engine/tests/test_gpu_gemm.mojo`, SHA-256
  `78c4dee86cb15343fcc22f12895a10d8fc3a3be01dc60b54bc147533f08ed748`.
- Toolchain: Mojo 1.0.0 (`ed45d567`), invoked through `pixi`.
- Command: `pixi run mojo run --target-accelerator sm_75 aesir_engine/tests/test_gpu_gemm.mojo`.
- Device: NVIDIA GeForce RTX 2060 with Max-Q Design, stable ID
  `cuda:max-id:0`.
- Complete stdout SHA-256:
  `1b2718b44f393827a7cafb530291daaa178445f8a57bad64923155d661aec315`.
- AES500-028 rerun: after adding the per-execution live-count assertion, the
  physical probe was rerun from the source hash above. Fresh stdout at
  `/tmp/aes500-026/gpu3-review.stdout` has the same SHA-256; the added assertion
  does not print another line.

## Observed result

GPU-3 passed with the 2x3x4 exact shape and 17x19x23 varied shape, three
executions per shape, exact max error 0.0, varied max error 0.0009613037,
transactional budget rejection, gateway shape/storage rejection, and no
reallocation during executor reuse. At executor creation the test observed
three distinct owner IDs, logical live count 3, and logical live bytes equal to
the plan's three-buffer byte total. Each successful GEMM returned with all
three pending-work counters at zero after the executor's successful context
synchronization; the tracker also remained at three live owners immediately
after every execution. After both executor scopes, the existing end-of-probe check
observed zero live owners and six fenced owner destructions.

The retained output is a bounded result receipt; the full raw stdout is
machine-local at `/tmp/aes500-026/gpu3.stdout` and is not required to reproduce
the run.

## Limits

This proves the synchronous physical GEMM path on the named GPU and toolchain.
It does not prove concurrent host access, asynchronous teardown safety, an
implicit destruction fence, physical allocator reuse, driver memory return, or
performance.
