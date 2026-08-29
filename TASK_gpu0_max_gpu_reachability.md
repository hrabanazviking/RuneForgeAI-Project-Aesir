# Task: GPU-0 MAX GPU Reachability Proof

## Authorization

Volmarr instructed Project A.E.S.I.R. to begin the first GPU/NPU slice. Under
`GPU_NPU_REAL_EXECUTION_GAMEPLAN_2026-08-29.md`, the first authorized slice is
GPU-0: prove the locked Mojo/MAX toolchain can reach one physical GPU. This task
authorizes a hardware-only proof program/test, execution on the current NVIDIA
GPU, evidence documentation, interface/test documentation updates, commits, and
pushes to the real GitHub `main` branch. It does not authorize enabling public
GPU inference, changing accelerator capability status, deleting existing code
or data, changing Git settings, or claiming NPU execution.

## System Statement

The repository currently proves only that selected GPU runtime libraries can be
loaded; every public GPU allocation, transfer, discovery, and GEMM entry point
fails closed. The development host independently exposes an NVIDIA GeForce RTX
2060 Max-Q, but `nvidia-smi` output is not A.E.S.I.R. GPU execution. GPU-0 must
cross the real accelerator boundary through the exact locked MAX accelerator
API while leaving public engine gateways unchanged.

## Observed Target Baseline

- GPU: NVIDIA GeForce RTX 2060 with Max-Q Design
- GPU UUID: `GPU-d5a3f671-756e-0c4d-6fdf-2c39161871a3`
- compute capability: 7.5
- device memory reported by the vendor tool: 6144 MiB
- NVIDIA driver: 595.84
- CUDA assembler: 12.4 (`ptxas` 12.4.131)
- Mojo: 1.0.0
- MAX / MAX Core: 26.5.0
- host: Linux x86-64

These values are a dated physical-test target record, not portable project
support or a benchmark.

## Owning Domain

- `aesir_engine/tests/` — isolated physical reachability proof
- `aesir_engine/tests/INTERFACE.md` — invocation and evidence boundary
- `pixi.toml` / `pixi.lock` — exact dependency authority; no upgrade planned
- `TASK_gpu0_max_gpu_reachability.md` — commands, results, and boundary
- `DEVLOG.md` — continuity record

## Desired End State

Using only the locked Mojo/MAX packages, compile and run one hardware-only test
that proves:

1. a MAX GPU device context is created on the physical RTX target;
2. host and device buffers are owned through the MAX lifecycle;
3. known host data is copied to the device and copied back unchanged;
4. a real Mojo GPU kernel is compiled and launched on the device;
5. completion is synchronized before host validation;
6. kernel output matches an independently calculated host expectation;
7. invalid or mismatched output fails nonzero;
8. repeated execution completes without stale-resource failure; and
9. the exact APIs suitable for the later production wrapper are recorded.

## Invariants

- `CUDAGate.get_device_count()` remains zero in this slice.
- `allocate_vram()`, transfers, GPU GEMM, and GPU RMSNorm remain fail-closed.
- `AES-ACC-003` and `AES-ACC-008` remain `missing`.
- The default CPU master suite remains hardware-independent.
- The hardware-only test is not registered in `run_all.mojo` or normal hosted
  CPU CI.
- No generated binary, model, raw hardware dump, cache, or runtime state is
  committed.
- The proof does not claim GEMM, model integration, NPU execution, general CUDA
  support, performance, multi-GPU, or production readiness.
- No existing file, function, fixture, model, asset, or history is deleted.

## Verification Plan

- inspect the exact installed MAX 26.5 Mojo API rather than guessing symbols
- compile the hardware-only proof from a clean source state
- run it repeatedly on the named RTX device
- verify host-to-device-to-host identity and kernel output element by element
- record the exact command and output summary in this task and DEVLOG
- run the CPU master suite, native CLI build, deliberate negative control,
  repository consistency, artifact, fixture, and diff checks
- push the verified slice and observe hosted CPU CI for regression safety

## Completion Boundary

GPU-0 ends at toolchain reachability. It selects a viable production API but
does not connect device discovery or GPU computation to the engine. GPU-1 will
own truthful physical discovery; GPU-2 will own production device resources;
GPU-3 will own the first real A.E.S.I.R. F16 GEMM.
