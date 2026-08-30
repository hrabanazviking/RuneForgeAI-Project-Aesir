# Task: GPU-2 Production CUDA Resource Ownership

## Authorization

Volmarr instructed Project A.E.S.I.R. to proceed with GPU-2 after GPU-1 added
truthful MAX CUDA enumeration and compatible-device selection. This task
authorizes one real CUDA resource-lifecycle slice: a selected device context,
conservative memory budgets, owned device and pinned-host F16 buffers, explicit
host/device transfers, synchronization, scope-based cleanup, deterministic
budget tests, an opt-in physical hardware proof, documentation, commits,
pushes to the real GitHub `main`, and hosted CPU CI observation.

It does not authorize GPU GEMM, RMSNorm, attention, model-weight placement,
model inference, CLI GPU enablement, multi-GPU execution, NPU claims,
performance claims, dependency upgrades, raw-pointer ownership transfer, or
deletion of any existing file, function, data, model, fixture, asset, or
history.

## System Statement

GPU-0 proved the locked Mojo 1.0.0 / MAX 26.5.0 toolchain can create temporary
host/device buffers, copy data, launch a physical kernel, and synchronize.
GPU-1 proved the engine can enumerate and select the observed CUDA device.
Those proofs are isolated: the engine still has no resource object that binds a
selected `PhysicalDevice` to a persistent MAX context, applies explicit memory
budgets, owns F16 staging/device buffers, or exposes truthful transfer and
synchronization operations.

The legacy `CUDAGate.allocate_vram()`, raw-pointer transfer functions, and GPU
compute gateways deliberately fail closed. They must not be converted into
unsafe pointer APIs that discard MAX ownership and lifetime information.

## Observed MAX Ownership Contract

The locked MAX accelerator API provides:

- `DeviceContext(device_id, api="cuda")`, representing one accelerator stream;
- `enqueue_create_buffer[DType.float16](elements)`, returning an owned,
  reference-counted `DeviceBuffer` in GPU global memory;
- `enqueue_create_host_buffer[DType.float16](elements)`, returning owned pinned
  host memory;
- `enqueue_copy()` for asynchronous H2D and D2H copies on the context stream;
- `synchronize()` as the host/device completion boundary; and
- `Deinitable` buffer/context lifecycles. `DeviceBuffer.__deinit__()` schedules
  its owned free on the stream after prior uses complete.

MAX buffers retain their owning context and copy by incrementing a reference
count. GPU-2 will therefore use a move-only project wrapper and scope-based
cleanup. It will not invent a manual `released` flag or claim memory is freed
while reference-counted aliases may still exist.

## Owning Domain

- `aesir_engine/core/cuda_resources.mojo` — selected CUDA context, budgets,
  F16 allocation ownership, transfer, synchronization
- `aesir_engine/core/cuda_gate.mojo` — discovery remains here; raw-pointer and
  compute compatibility surfaces remain fail-closed
- `aesir_engine/core/INTERFACE.md` — public resource and lifecycle contract
- `aesir_engine/tests/test_cuda_resource_budget.mojo` — CPU-only injected
  budget and admission invariants
- `aesir_engine/tests/test_gpu_resources.mojo` — opt-in physical resource proof
- `aesir_engine/tests/run_all.mojo` — deterministic budget tests only
- `aesir_engine/tests/INTERFACE.md`, `aesir_engine/tests/README.md` — commands
  and evidence boundaries
- `docs/ARCHITECTURE.md`, `docs/DOMAIN_MAP.md` — ownership and dependency flow
- `TODO.md`, `CAPABILITY_LEDGER.md`, `DEVLOG.md` — current status and continuity

## Desired End State

1. Add a pure, copy-safe `CUDAResourceBudget` that tracks device and pinned-host
   byte limits and reservations without probing hardware.
2. Reject nonpositive element counts, byte multiplication overflow, zero
   budgets, requests exceeding either remaining budget, incompatible devices,
   non-CUDA records, and context/device identity mismatch.
3. Add a move-only `CUDAF16Allocation` that owns one MAX device buffer and one
   pinned-host staging buffer of the same positive length.
4. Add a move-only `CUDADeviceResources` session that owns the selected CUDA
   `DeviceContext`, selected physical-device identity, and conservative budget.
5. Reserve both budgets only after validating the entire request, then allocate
   through the session context. Commit accounting only after both MAX
   allocations succeed.
6. Expose bounds-checked host staging access, explicit upload and download, and
   a required synchronization method without exposing an owning raw pointer.
7. Keep budget accounting monotonic for the session. GPU-2 does not implement a
   reusable allocator or pretend that dropping one wrapper immediately returns
   bytes to a project pool.
8. Prove repeated upload/download identity over multiple allocations and
   rounds on the selected physical CUDA device.
9. Prove scope exit and a newly created session can allocate and transfer again
   without stale-context or stale-buffer failure.

## Invariants

- `CUDAGate` remains the sole CUDA discovery adapter.
- Runtime-neutral discovery records remain in `core/mimir_well.mojo`.
- The new resource module depends on topology records and MAX; topology does
  not depend on the resource module.
- Default `DeviceTopology` construction remains side-effect-free.
- No GPU resource is constructed in the hosted CPU master suite.
- No hardcoded GPU model, device count, runtime ID, memory total, or positive
  production device record enters the resource implementation.
- Device and pinned-host byte limits are caller-provided policy, validated
  against the selected live device where appropriate.
- Asynchronous transfers are never presented as host-visible completion before
  `synchronize()` succeeds.
- A failed validation or allocation does not consume project budget.
- Raw device pointers, if borrowed internally in a later kernel slice, must not
  outlive the owned MAX buffer. GPU-2 exposes no ownership-taking pointer API.
- Existing GPU GEMM, RMSNorm, inference, and `--accel cuda` paths remain
  fail-closed.
- `AES-ACC-008` remains `missing`; resource ownership alone is not engine GPU
  execution.
- `AES-ACC-009` remains `missing`; pinned staging plus explicit copies is not
  direct mmap-to-GPU zero-copy.
- Non-CUDA backends remain unpromoted.
- No existing project file or data is deleted.

## Verification Plan

- Compile and run CPU-only tests for exact byte accounting, overflow,
  nonpositive sizes, device/pinned-host over-budget requests, transactional
  reservation, and monotonic remaining-capacity reporting.
- Compile and run an opt-in physical test using the GPU-1 selected device.
- On physical hardware, allocate at least two unequal F16 resources through one
  long-lived session, perform repeated H2D/D2H identity transfers, synchronize,
  and compare every element with independently generated host values.
- Prove invalid and over-budget physical requests fail before allocation and do
  not change accounting.
- Exit the session scope, open a new session, and repeat allocation/transfer to
  prove there is no stale resource failure.
- Re-run GPU-1 discovery and GPU-0 kernel reachability, including their negative
  control.
- Re-run the complete master suite, native CLI build, deliberate fail-closed
  runner, repository truth/artifact checks, fixture checks, and diff checks.
- Push the verified implementation to `main` and observe hosted CPU CI.

## Capability Boundary

GPU-2 may add executable evidence for real CUDA context, buffer, transfer,
synchronization, and lifecycle ownership on the observed host. It does not
promote `AES-ACC-008`, because no A.E.S.I.R. production compute or inference
gateway uses those resources. GPU-3 owns the first real engine CUDA F16 GEMM and
CPU-reference parity.

## Completion Boundary

GPU-2 ends when one selected CUDA device can be opened through a project-owned
resource session, two-budget F16 allocations and transfers survive repeated
physical execution, failure paths preserve accounting, cleanup follows MAX
ownership semantics, all CPU gates pass, and hosted CI is green.

## Implementation Evidence

- `core/cuda_resources.mojo` adds `CUDAResourceBudget`,
  `CUDAF16Allocation`, `CUDADeviceResources`, and pure selected-device policy
  admission.
- The resource wrapper retains MAX ownership types rather than leaking an
  owning raw pointer. It is move-only at the project layer.
- Successful F16 allocations reserve equal device and pinned-host byte spans.
  Validation and allocation failure paths preserve or roll back accounting.
- Each allocation exposes bounds-checked host staging access, explicit upload,
  explicit download, and explicit synchronization.
- Session construction checks the selected discovery record against the live
  CUDA context ID, API, compatibility, total memory, and current free memory.
- Successful budget accounting remains monotonic for the session; cleanup is
  driven by the MAX context/buffer `Deinitable` lifecycle at scope exit.

## Physical Verification Record

The opt-in `test_gpu_resources.mojo` selected the GPU-1 record for the observed
NVIDIA GeForce RTX 2060 with Max-Q Design. In each of two successive resource
session scopes it allocated 257-element and 1025-element paired F16 resources,
then completed three synchronized H2D/D2H identity rounds per allocation.

The same run proved zero-element and over-budget requests fail without changing
reserved bytes or successful allocation count. A deliberate mismatch at index
0 in session 1, allocation 1, transfer round 2 exited `1`.

## Truth Boundary After Implementation

GPU-2 proves selected-context ownership, budgeted F16 device/pinned-host
resources, explicit transfers, synchronization, and repeatable scope cleanup on
one observed MAX CUDA host. It does not prove a GPU compute gateway, GEMM,
model inference, CLI activation, generalized CUDA support, mmap zero-copy,
multi-GPU, NPU execution, performance, or hardware CI. `AES-ACC-008` and
`AES-ACC-009` remain `missing`; GPU-3 owns the first real engine CUDA F16 GEMM.

## Regression Verification

- GPU-2 physical resource proof: three independent processes passed.
- GPU-2 `--negative-control`: intended transfer mismatch exited `1`.
- GPU-1 physical discovery regression: passed.
- GPU-0 physical affine-kernel regression: passed.
- GPU-0 `--negative-control`: intended kernel mismatch exited `1`.
- CPU master suite: 140 passed, 0 failed, 1 skipped, total 141.
- Native Mojo CLI build: passed in a temporary directory outside the repository.
- Deliberate fail-closed master-runner control: intended failure exited nonzero.
- Documentation drift, artifact prevention, fixture provenance, fixture
  manifest, and diff checks: passed. Only the existing approval-blocked legacy
  artifact warnings remain; GPU-2 deleted nothing.

## Final Status

GPU-2 is complete at the resource ownership and transfer boundary. The next
slice is GPU-3: one real engine CUDA F16 GEMM with independent CPU-reference
parity. No public CUDA execution route is enabled by GPU-2.
