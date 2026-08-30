# Task: GPU-3 Real CUDA F16 GEMM Gateway

## Authorization

Volmarr instructed Project A.E.S.I.R. to proceed with GPU-3 in full after
GPU-0 proved physical MAX CUDA kernel reachability, GPU-1 added truthful device
discovery and selection, and GPU-2 added selected-device resource ownership,
budgets, transfers, synchronization, and lifecycle evidence. This task
authorizes the complete GPU-3 vertical slice: one reusable production CUDA F16
GEMM executor, an actual Mojo GPU kernel, explicit engine-facing dispatch,
CPU-only planning and failure tests, opt-in physical parity and negative-control
proofs, documentation reconciliation, commits, pushes to the real GitHub
`main`, and hosted CPU CI observation.

It does not authorize Transformer/model integration, persistent model-weight
placement, public CLI GPU activation, RMSNorm or attention kernels, Tensor Core
or MMA claims, multi-GPU execution, NPU execution, performance claims,
dependency upgrades, unsafe raw-pointer ownership transfer, or deletion of any
existing file, function, data, model, fixture, asset, or history.

## System Statement

The repository can select a real CUDA device and create project-owned MAX F16
resources on it, but no A.E.S.I.R. production compute gateway launches a CUDA
GEMM. The existing `gemm_f16_gpu(A, B, C, realm)` path reaches
`CUDAGate.launch_gemm_cuda()` and then fails closed. Its signature carries
neither a selected `PhysicalDevice` nor an owning `CUDADeviceResources`
session, so enabling it implicitly would discard the identity, lifetime,
budget, and error boundaries established by GPU-1 and GPU-2.

GPU-3 must add a new explicit selected-resource gateway. The legacy realm-only
gateway remains fail-closed until a later model-integration slice owns resource
creation and weight placement at the correct lifetime.

## Observed Matrix and MAX Contracts

The current host GEMM contract is:

- `A` has shape `[M, K]`;
- `B` has shape `[N, K]`, with each output-feature weight row stored
  contiguously;
- `C` has shape `[M, N]`; and
- each result is the dot product of `A` row `m` and `B` row `n`.

The production CUDA implementation must preserve that convention exactly. It
must not silently reinterpret `B` as `[K, N]` merely because that layout is
common in external GEMM APIs.

The locked Mojo 1.0.0 / MAX 26.5.0 boundary already exercised by GPU-0 through
GPU-2 provides owned `DeviceContext`, `HostBuffer`, and `DeviceBuffer` values,
asynchronous copies, `enqueue_function`, device-buffer-derived pointer origins,
and explicit synchronization. GPU-3 will borrow device pointers only while the
owning allocations remain alive. Kernel scalar dimensions use fixed-width
device-passable integers rather than host-width `Int` values.

## Owning Domain and Files

- `aesir_engine/core/cuda_compute.mojo` — CUDA GEMM plan, fixed-shape executor,
  kernel, transfer/launch/synchronization sequence, and internal pointer borrows
- `aesir_engine/core/cuda_resources.mojo` — transactional three-allocation
  admission and truthful budget/accounting rollback on construction failure
- `aesir_engine/core/compute.mojo` — explicit engine-facing CUDA GEMM wrapper;
  the older realm-only gateway remains unsupported
- `aesir_engine/core/INTERFACE.md` — public plan, executor, and dispatch contract
- `aesir_engine/tests/test_cuda_gemm_plan.mojo` — hardware-independent shape,
  arithmetic, launch, and admission tests
- `aesir_engine/tests/test_gpu_gemm.mojo` — opt-in physical execution, parity,
  reuse, and deliberate mismatch proof
- `aesir_engine/tests/run_all.mojo` — deterministic plan tests only
- `aesir_engine/tests/INTERFACE.md`, `aesir_engine/tests/README.md` — commands
  and exact evidence boundaries
- `docs/ARCHITECTURE.md`, `docs/DOMAIN_MAP.md` — ownership and dependency flow
- `TODO.md`, `CAPABILITY_LEDGER.md`, `DEVLOG.md` — present truth and continuity

## Desired End State

1. Add a copy-safe CUDA GEMM plan that validates positive `M`, `K`, and `N`,
   the established tensor shapes, every element-count multiplication, exact
   F16 byte requirements, device ABI limits, and a nonzero bounded launch grid
   without opening hardware.
2. Add a real CUDA kernel in the core domain. Each in-range thread computes one
   `C[m, n]`, reads only validated A/B spans, accumulates the K reduction in
   F32, and writes one F16 result.
3. Add a move-only, fixed-shape CUDA F16 GEMM executor that owns its A, B, and C
   pinned-host/device allocation pairs for its entire usable lifetime.
4. Construct all three allocations through one selected
   `CUDADeviceResources` session. Reject the total request before allocation
   when either device or pinned-host budget is insufficient.
5. If executor construction fails after a partial allocation, release the
   scoped MAX owners and restore project budget and successful-allocation
   accounting to the exact pre-construction state.
6. Make the executor reusable. Each execution validates the live tensor shapes,
   stages A and B, uploads them, launches the kernel on the selected context,
   downloads C, synchronizes before host reads, and copies every output back to
   the caller's `RuneTensor`.
7. Add an explicit engine-facing `gemm_f16_cuda` route that requires a mutable
   owned executor. It must never discover a device, invent a memory budget, or
   create a hidden global context.
8. Keep `gemm_f16_gpu(..., realm)` and `CUDAGate.launch_gemm_cuda()` fail-closed.
   Their signatures cannot satisfy the selected-resource contract.
9. Prove exact results for binary-exact small cases and bounded F16 error for
   broader deterministic shapes, including a launch-tail shape whose output
   count is not divisible by the thread-block width.
10. Prove repeat execution through the same executor and repeated process
    execution on the selected physical CUDA device.
11. Prove invalid shapes, arithmetic overflow, insufficient budgets, launch
    bounds, and deliberately corrupted expectations fail explicitly and
    nonzero where applicable.

## Execution Dataflow

The production dependency direction is:

`PhysicalDevice` selection → `CUDADeviceResources` → fixed-shape CUDA GEMM
executor → `gemm_f16_cuda` → caller-owned `RuneTensor` output.

Within one execution, data moves:

caller A/B tensors → bounds-checked pinned staging → owned device A/B buffers →
CUDA F16-input/F32-accumulation kernel → owned device C buffer → pinned staging
→ synchronized caller C tensor.

There is no host GEMM fallback inside this route. Any unavailable context,
invalid plan, failed transfer, failed launch, failed synchronization, or output
copy error propagates as an error.

## Invariants

- `CUDAGate` remains the sole CUDA discovery adapter.
- `CUDADeviceResources` remains the selected-context and budget owner.
- The CUDA compute module may depend on runtime-neutral tensors and CUDA
  resources; discovery/topology code must not depend on CUDA compute.
- Tensor dimensions and allocation counts are validated before any unsafe load,
  store, pointer borrow, transfer, or launch.
- The kernel never receives a host-width `Int` argument.
- A borrowed device pointer never outlives its owned `DeviceBuffer`.
- Host reads of downloaded output occur only after synchronization succeeds.
- Executor creation is accounting-transactional; execution does not allocate.
- Successful executor accounting remains monotonic for the owning GPU-2
  session, matching GPU-2's conservative no-pool-reuse contract.
- The hosted CPU master suite never constructs a GPU context or requires CUDA.
- Physical hardware tests remain opt-in and are never represented as hosted
  hardware CI.
- No positive GPU device, model name, runtime ID, memory total, benchmark, or
  machine-specific path is hardcoded into production logic.
- A basic CUDA GEMM kernel is not described as a Tensor Core, MMA, cuBLAS, or
  optimized production-performance path.
- Model inference, logits, tokens, CLI GPU mode, RMSNorm, attention, KV cache,
  and persistent model weights remain host-only or fail-closed after GPU-3.
- `AES-ACC-009` remains `missing`; pinned staging and explicit copies are not
  direct mmap-to-GPU zero-copy.
- Metal, Intel, AMD, and NPU backends remain unpromoted.
- No existing project file or data is deleted.

## Verification Plan

### Hardware-independent gates

- Compile and run plan tests for representative valid shapes, exact A/B/C
  element and byte counts, launch-tail rounding, and reusable fixed-shape
  admission.
- Reject zero/negative dimensions, every A/B/C shape mismatch, multiplication
  overflow, fixed-width kernel ABI overflow, zero/overflow launch grids, and
  insufficient device or pinned-host budgets.
- Prove transactional budget helpers preserve their pre-attempt values when a
  three-buffer admission or injected construction step fails.
- Register only these pure cases in `tests/run_all.mojo`.

### Physical CUDA gates

- Discover and select the physical CUDA device through the production GPU-1
  path, then create the GPU-2 resource session with explicit caller budgets.
- Execute a small hand-calculable binary-exact matrix and compare every result
  with an independently calculated host F32 reference converted to F16.
- Execute deterministic unequal/tail shapes, including an output count not
  divisible by the block size and a K dimension not aligned to SIMD-friendly
  widths. Compare every output with documented absolute and relative F16 error
  bounds and report the maximum observed error.
- Reuse the same executor for at least three different input rounds without
  allocating again or changing its resource count.
- Run the physical proof in at least three independent processes.
- Run `test_gpu_gemm.mojo --negative-control` after real execution and require
  the deliberate expected-value corruption to exit nonzero.
- Re-run GPU-2 resource ownership, GPU-1 discovery, and GPU-0 reachability,
  including their applicable negative controls.

### Repository gates

- Run the complete counted CPU master suite and verify its totals.
- Build the native CLI into a temporary path outside the repository.
- Run the deliberate fail-closed master-runner control.
- Run documentation-drift, repository-artifact, fixture-provenance, fixture
  manifest, and diff checks.
- Push each coherent verified implementation checkpoint to `main` and observe
  hosted CPU CI for the exact final revision.

## Capability Decision

`AES-ACC-008` may move from `missing` to `partial` only after the production
core gateway launches this real kernel through GPU-2-owned resources and the
physical parity, error, and repeatability gates pass. That narrow promotion
would mean meaningful GPU execution dispatch exists for one explicit CUDA F16
GEMM executor on the observed MAX host.

GPU-3 cannot make `AES-ACC-008` `verified`. Model integration, persistent
weight placement, logits/token parity, public configuration and CLI activation,
broader hardware coverage, and hardware CI are still absent. The capability
ledger and TODO must state those remaining boundaries without implying that one
kernel makes general inference GPU-backed.

## Completion Boundary

GPU-3 is complete only when a caller can explicitly bind a validated shape to a
selected GPU-2 resource session, reuse the resulting executor to perform real
CUDA F16 GEMM, receive synchronized results in the existing `RuneTensor`
layout, and pass independent physical CPU-reference comparison and deliberate
failure controls. All hardware-independent gates, native build, repository
truth checks, pushes, and hosted CPU CI must also pass.

The next separate slice after GPU-3 is real-model integration: persistent CUDA
weight placement and one Transformer GEMM path with logits/token parity. That
work is not smuggled into this kernel-and-gateway contract.

## Implementation Evidence

- `core/cuda_gemm_plan.mojo` adds hardware-independent checked products,
  exact F16 bytes, Int32 kernel ABI bounds, launch-tail planning, tensor-shape
  admission, and dual remaining-budget checks.
- `CUDAResourceBudget.reserve_f16_batch3()` atomically reserves the exact A, B,
  and C device/pinned-host total. `CUDAF16GemmExecutor.create()` restores the
  reservation if any MAX construction or initial synchronization fails and
  commits three allocations only after all owners exist.
- `core/cuda_compute.mojo` adds the reusable move-only executor and the genuine
  CUDA kernel. Each in-range thread computes one output cell for the established
  `A[M,K] × B[N,K] → C[M,N]` layout using F16 inputs and F32 accumulation.
- `gemm_f16_cuda()` is the explicit production-core gateway. It requires a
  selected-resource executor and performs no discovery, hidden allocation,
  implicit global-context creation, or host fallback.
- Every execution validates live shapes, plain-F16 storage, element counts,
  pointers, device identity, and context compatibility; then it stages A/B,
  enqueues H2D, launches, enqueues D2H, synchronizes, and publishes C.
- A copy, launch, or synchronization exception marks the executor unusable and
  records the failure message; later calls reject rather than reusing a
  potentially faulted stream. Pre-launch validation rejection remains retryable.
- The older realm-only `gemm_f16_gpu()` and `CUDAGate.launch_gemm_cuda()` remain
  fail-closed because their signatures cannot satisfy the ownership contract.

## Physical Verification Record

The opt-in production proof selected the GPU-1 record for the observed NVIDIA
GeForce RTX 2060 with Max-Q Design through MAX 26.5. Three independent process
executions each completed:

- three rounds of binary-exact `2×3×4` GEMM with maximum error `0.0`;
- three rounds of unaligned `17×19×23` GEMM with maximum error
  `0.0009613037` against the independent host F32 calculation;
- shape and quantized-storage rejection before execution;
- insufficient pinned-host budget rejection without reservation or allocation
  count mutation; and
- reuse of each executor without execution-time allocation.

The physical command was:

```bash
MODULAR_NVPTX_COMPILER_PATH=/usr/bin/ptxas pixi run mojo run aesir_engine/tests/test_gpu_gemm.mojo
```

The same command with `--negative-control` changed one independent expectation
after genuine GPU execution, raised `GPU-3 exact GEMM mismatch at output index
0 in round 2`, and exited `1`.

GPU-2 resource ownership, GPU-1 discovery, and GPU-0 reachability positive
regressions passed. GPU-2 and GPU-0 deliberate negative controls both exited
`1` at their expected mismatch boundaries.

## Hardware-Independent Verification Record

Four GPU-3 plan cases joined the counted master suite and prove exact counts and
launch rounding, tensor-shape rejection, overflow/Int32 ABI rejection, and
atomic three-buffer budget reservation/rollback. The full suite reports 144
passed, 0 failed, 1 explicitly skipped, total 145.

## Capability Result

`AES-ACC-008` is now `partial`. That status is scoped to one real reusable
CUDA F16 GEMM through explicit project ownership on the observed host.
Persistent device-resident model weights, Transformer execution, logits/token
parity, remaining operators, CLI activation, Tensor Core/MMA execution,
generalized CUDA and other GPU backends, performance, and hardware CI remain
unproved. `AES-ACC-009` remains `missing`.

## Final Status

GPU-3 is complete at the explicit production-core CUDA GEMM boundary. Planning
landed in `b2dcae8`, the real executor/kernel/gateway in `3210de6`, and physical
gateway rejection hardening in `a9d7928`; every checkpoint was pushed to the
real GitHub `main`. GPU-4 is the next slice.
