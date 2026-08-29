# Task: GPU-1 Truthful Physical Device Discovery

## Authorization

Volmarr instructed Project A.E.S.I.R. to proceed with GPU-1 after GPU-0 proved
that locked Mojo 1.0.0 / MAX 26.5.0 can execute a real kernel on the observed
NVIDIA RTX host. This task authorizes truthful CUDA device discovery,
engine-topology integration, deterministic injected discovery tests, an opt-in
physical discovery test, evidence and interface updates, commits, pushes to the
real GitHub `main`, and hosted CI observation. It does not authorize GPU buffer
ownership for inference, transfer dispatch, GEMM, model execution, enabling a
GPU CLI route, NPU claims, or deletion of any existing file or data.

## System Statement

GPU-0 proved the MAX accelerator API reaches one physical CUDA device, but
`CUDAGate.get_device_count()` still returns zero and `DeviceTopology` cannot
retain an observed physical device. Its current sequential GPU probes also
clear `gpu_realms` before each backend, so a later empty probe erases an earlier
positive result. The Metal probe maps Metal to the unrelated
`ARM_MALI_OPENCL` discriminant. These behaviors prevent truthful engine-facing
discovery even though the toolchain boundary is now known.

## Observed Architecture and API Contract

- Owning domain: `aesir_engine/core/` hardware and topology boundary.
- `GPURealmType` is the existing configured-backend discriminant.
- `DeviceTopology` owns configured logical host partitions and observed
  accelerator collections.
- `CUDAGate` owns the CUDA runtime boundary and all CUDA-specific discovery.
- MAX 26.5 publicly provides `DeviceContext.number_of_devices(api="cuda")`,
  per-index `DeviceContext(device_id, api="cuda")`, `name()`, `api()`, `id()`,
  `get_api_version()`, `get_memory_info()`, `get_attribute()`, and
  `is_compatible()`.
- MAX `DeviceContext.id()` is the available runtime device identifier. This
  slice will not invent a vendor UUID that the selected public Mojo API does not
  expose.

## Owning Files

- `aesir_engine/core/mimir_well.mojo` — physical-device records and topology
- `aesir_engine/core/cuda_gate.mojo` — selected MAX CUDA discovery adapter
- `aesir_engine/core/INTERFACE.md` — public discovery contracts
- `aesir_engine/tests/test_hardware_discovery.mojo` — CPU-only injected tests
- `aesir_engine/tests/test_gpu_discovery.mojo` — opt-in physical RTX proof
- `aesir_engine/tests/test_cuda_realm.mojo` — truthful count boundary
- `aesir_engine/tests/run_all.mojo` — deterministic injected cases only
- `aesir_engine/tests/INTERFACE.md` — test invocation and evidence boundary
- `docs/ARCHITECTURE.md`, `docs/DOMAIN_MAP.md` — current topology ownership
- `TODO.md`, `CAPABILITY_LEDGER.md`, `DEVLOG.md` — continuity and status truth

## Desired End State

1. Add copy-safe `PhysicalDevice` and `DeviceCapabilities` records with backend,
   backend-local index, MAX device ID, stable selection string, name, API,
   compatibility, driver/API version, memory, compute capability, SM count,
   and thread-limit fields derived from the selected runtime.
2. Add explicit discovery status categories for success, unsupported runtime,
   no device, incompatible driver, unsupported architecture, missing compiler
   tool, permission failure, and unclassified probe failure.
3. Enumerate every CUDA device reported by MAX and retain every successfully
   inspected record in backend-index order.
4. Make `CUDAGate.get_device_count()` return the observed MAX count without
   treating a loadable library as a physical device.
5. Let `DeviceTopology` apply either production results or explicitly injected
   test snapshots, accumulate rather than erase observed devices, deduplicate
   realm tags, and select by backend-local index or stable ID.
6. Give Apple Metal its own additive realm discriminant instead of reporting it
   as ARM Mali.
7. Keep default construction side-effect-free and keep CPU-only test results
   deterministic through injected records rather than positive production
   fakes.
8. Add an opt-in physical test that proves the engine discovery record matches
   the observed RTX device and MAX runtime facts.

## Invariants

- Public GPU allocation, transfer, RMSNorm, GEMM, and inference remain
  fail-closed.
- `--accel cuda` remains rejected before model loading.
- `AES-ACC-008` remains `missing`.
- `AES-ACC-003` may move only as narrowly justified by real local discovery and
  negative tests; no execution claim follows from discovery.
- Non-CUDA backend execution and discovery statuses remain unpromoted.
- Default `DeviceTopology(...)` construction performs no physical probe.
- Hosted CPU CI does not require or pretend to have an accelerator.
- No hardcoded GPU model, count, memory total, compute capability, runtime ID,
  or positive test fixture enters production discovery.
- No generated binary, hardware dump, cache, model, or runtime state is
  committed.
- No existing file, function, model, fixture, asset, or history is deleted.

## Verification Plan

- Compile and run injected success, accumulation, deduplication, stable
  selection, invalid-record, duplicate-ID, and every failure-status case in the
  counted CPU suite.
- Run the opt-in production discovery test on the observed RTX host and compare
  its fields with direct `gpu-query` / vendor observations.
- Prove an unknown backend index and stable ID fail nonzero or raise at the
  named boundary.
- Re-run GPU-0 reachability to ensure discovery integration did not break real
  context/buffer/kernel execution.
- Re-run the complete master suite, native CLI build, deliberate fail-closed
  control, repository truth/artifact checks, fixture checks, and diff checks.
- Push the verified implementation to `main` and observe hosted CPU CI.

## Completion Boundary

GPU-1 ends when the engine topology can truthfully enumerate and select the
observed CUDA device through MAX while CPU-only tests exercise the same
admission logic with clearly injected snapshots. GPU-2 will own long-lived
production contexts, buffers, transfers, synchronization objects, budgets, and
cleanup. GPU-3 will own the first A.E.S.I.R. GPU GEMM.
