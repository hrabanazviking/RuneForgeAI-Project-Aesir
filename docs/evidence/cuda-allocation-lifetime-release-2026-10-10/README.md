# CUDA allocation lifetime release gate — 2026-10-10

AES500-030 release verification for the bounded AES500-021–029 allocation
lifetime work order. Source revision before this receipt-only change:
`214eb72550d9cb7860566054f50871e2f377d2ee`.

## Local release checks

- Toolchain: pinned Pixi environment, Mojo 1.0.0 (`ed45d567`).
- `python3 scripts/launch.py --build`: passed; executable recorded at
  `.aesir/launch/aesir`.
- `pixi run mojo run --target-accelerator sm_75 aesir_engine/tests/run_all.mojo`:
  191 passed, 0 failed, 1 explicit optional GGUF-fixture skip (192 total).
- Four focused evidence checker suites (CUDA trace, Turing down-projection,
  Turing prefill, fused attention): 66 tests passed.
- `test_gpu_resources.mojo`: physical GPU-2 passed on NVIDIA GeForce RTX 2060
  with Max-Q Design, `cuda:max-id:0`; two sessions and synchronized transfers.
- `test_gpu_gemm.mojo`: physical GPU-3 passed on the same device; exact 2x3x4
  and varied 17x19x23 shapes, three executions each, exact error 0.0 and varied
  maximum error 0.0009613037.
- GPU-3 `--negative-control`: exited 1 at the intentionally injected last-round
  mismatch (`output index 0 in round 2`), as expected.
- `git diff --check` and `python3 scripts/check_doc_drift.py`: passed; only the
  repository's previously known legacy asset/executable/placeholder warnings
  remain.

## Hosted release gate

The release worktree was pushed to
`docs/cross-cutting-500-slice-roadmap`. The exact-head Actions run is checked
after this receipt commit; local evidence does not substitute for hosted CI.
Only the exact pushed revision's completed successful workflow closes the
release gate.

## Claim boundary

These checks cover local builds/tests and the named synchronous paths. They do
not prove concurrent tracker mutation, asynchronous teardown safety, implicit
destruction fences, physical allocator reuse, driver-memory return, or a
broader CUDA capability promotion.
