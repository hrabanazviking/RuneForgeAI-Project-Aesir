# Project A.E.S.I.R. Real GPU/NPU Execution Gameplan

**Date:** 2026-08-29  
**Branch:** `main`  
**Planning baseline:** `92816a1`  
**Canonical capability owners:** `AES-ACC-003`, `AES-ACC-004`,
`AES-ACC-006`, `AES-ACC-008`, and `AES-ACC-009`

## 1. Outcome

The target is not an accelerator-themed API. The target is an inference engine
that can select a physically observed device, own its resources, move or map
data under a proved memory contract, execute computation on that device,
synchronize, return correct results, recover cleanly from failures, and prove
the entire path on named hardware.

The first implementation target will be **single-device NVIDIA CUDA execution
on the locally observed RTX 2060 Max-Q**. The first target is intentionally
narrow: establish one complete, honest, hardware-proved path before generalizing
the design to AMD, Apple, Intel, or an NPU vendor.

GPU completion requires an end-to-end model path, not only a sample GEMM. NPU
completion requires a supported vendor deployment artifact and real graph
execution; a generic `RuneTensor` GEMM API cannot be treated as a portable NPU
contract.

## 2. Current Truth

### 2.1 Repository boundary

| Surface | What exists now | What is still missing |
|---|---|---|
| CUDA, Metal, Intel, AMD gates | Dynamic-library loadability probes and fail-closed placeholders | Device enumeration, owned contexts, device allocation, transfers, kernels, synchronization, cleanup |
| NPU gate | Selected runtime-library probes and fail-closed placeholders | Supported vendor SDK adapters, physical discovery, compiled artifacts, I/O bindings, execution, synchronization, cleanup |
| `DeviceTopology` | Logical `host:N` partitions and empty accelerator lists | Stable device identities, capabilities, error metadata, multi-backend accumulation |
| `GPUBuffer` / `NPUBuffer` | Host F16 views carved from `MimirWell` | Device ownership, address-space identity, allocator/context association, valid lifetime and release |
| `gemm_f16_gpu()` / `gemm_f16_npu()` | Dispatch names and checked unsupported errors | Genuine accelerator work |
| Transformer inference | CPU tensor pipeline with accelerator flags threaded through GEMM call sites | Persistent device-resident weights, activations, KV cache, and all required device operators |
| Sharding | Sequential host partitioning and reduction | Device placement, asynchronous work, collectives, reconstruction, failure propagation |
| CLI/config | Accelerator intent vocabulary; single-shot runtime rejects non-CPU requests | Discovery-backed selection, explicit device choice, verified `auto`, offload policy |
| CI | CPU-only hosted verification | Trusted GPU/NPU hardware runners and retained proof artifacts |

The capability ledger therefore remains authoritative: `AES-ACC-003`,
`AES-ACC-004`, `AES-ACC-006`, `AES-ACC-008`, and `AES-ACC-009` are `missing`.
The existing fail-closed tests are valuable negative evidence, but they are not
accelerator execution evidence.

### 2.2 Live development-host snapshot

The following was observed on 2026-08-29 and is a target-selection fact, not a
portable project guarantee:

- Linux `x86_64`, kernel `7.0.0-30-generic`;
- NVIDIA GeForce RTX 2060 with Max-Q Design, compute capability 7.5, 6 GiB;
- NVIDIA driver `595.84`;
- `nvidia-smi` successfully enumerates the GPU;
- `libcuda.so` and `libcudart.so` are loadable;
- AMD Renoir graphics and DRM render nodes are visible, but the unversioned
  `libamdhip64.so` expected by the current gate is not loadable;
- `libze_loader.so.1` is loadable, but that does not establish an Intel GPU;
- `libhailort.so` is not loadable and no Hailo device node was observed;
- the project is locked to Mojo `1.0.0` and MAX `26.5.x`.

This makes CUDA the correct first physical proof target. AMD, Level Zero, and
all NPU tracks stay unverified until their own device APIs enumerate supported
hardware.

## 3. Definition of Real Execution

An accelerator slice is real only when one executable run proves every item
below:

1. The runtime identifies a physical device through the backend's supported
   API, including stable identity, type, driver/runtime version, memory, and
   relevant capabilities.
2. The process creates an owned device context, queue/stream, and any required
   library or compiled-model handles.
3. The device allocator returns memory associated with that device and context;
   the runtime records byte size, alignment, type, owner, and release state.
4. Inputs reach device-visible memory through an explicit transfer or a
   backend-specific shared-memory contract.
5. A kernel or compiled graph executes on the selected physical device.
6. Completion is synchronized through the backend's queue, event, fence, or
   job primitive.
7. Outputs are read back or consumed by the next device operator without being
   misrepresented as host memory.
8. Results meet declared CPU-reference tolerances, including shape, logits,
   token IDs, and end-to-end generation for the supported model slice.
9. Normal exit and every injected failure release resources exactly once.
10. Logs and test artifacts name the device, backend, software versions, model
    fixture, command, result, and timing source.
11. A trusted hardware runner can reproduce the result.
12. The capability ledger, TODO, interfaces, tests, task record, and DEVLOG are
    reconciled in the same verified commit.

## 4. Substitutes That Are Forbidden

The following must never satisfy an accelerator acceptance gate:

- loading a runtime library without enumerating a physical device;
- returning a hard-coded device count or reading only PCI/OS names;
- using a `MimirWell` host pointer as if it were a device pointer;
- running CPU SIMD beneath a GPU/NPU function name;
- silently falling back to CPU after an explicit accelerator request;
- measuring a no-op, transfer-only path, or sample kernel as model inference;
- treating Linux `mmap` as GPU/NPU zero-copy;
- treating host sharding or sequential loops as multi-GPU execution;
- accepting a generated, guessed, renamed, or unproven model artifact;
- using the first backend's hardware evidence to promote another backend;
- committing invented benchmarks, device logs, fixtures, binaries, or CI
  results;
- adding empty backend files, placeholder functions, duplicate tests, or
  future-facing manifests solely to make the tree look complete.

## 5. Architecture Decisions Before Backend Code

### 5.1 Split host tensors from device tensors

`RuneTensor` remains a checked host-memory view. A device pointer must never be
stored in `RuneTensor.data` and later dereferenced by host code.

Add an accelerator-owned tensor family with these minimum facts:

- backend and physical device identity;
- context/allocator identity;
- opaque allocation handle or device pointer;
- element type, dimensions, strides, byte size, and alignment;
- allocation generation and released/not-released state;
- host visibility and mapping mode;
- last-writer queue/event ownership;
- explicit copy or mapped-view methods;
- destructor/close behavior that is idempotent and testable.

Host and device tensors may share shape validation utilities, but must not share
an unchecked pointer representation.

### 5.2 Create one device-runtime contract

Introduce a small core contract covering:

- runtime initialization and shutdown;
- physical discovery;
- device selection by stable ID;
- context and stream/queue creation;
- allocation and release;
- host-to-device, device-to-host, and device-to-device copy;
- events, synchronization, and elapsed-time measurement;
- kernel/module/graph load;
- device error translation;
- capability queries;
- memory and execution telemetry.

The contract must use explicit `raises` boundaries and checked byte arithmetic.
Every backend-specific error retains its native numeric code plus a stable
A.E.S.I.R. error category.

### 5.3 Use the installed MAX accelerator library for the common GPU path

For Mojo/MAX `26.5.x`, the preferred GPU implementation route is the
`max.gpu` host/device API: owned device contexts, device buffers, copies,
compiled Mojo kernels, streams, and events. This avoids maintaining four unsafe
handwritten foreign-function tables for functionality already supplied by the
locked accelerator runtime.

The first code slice must compile and run a minimal `max.gpu` device-buffer and
kernel program against the exact lockfile. If the stable package cannot support
the standalone engine boundary, record the exact missing API and use one
vendor-specific bridge for that missing function only. Do not mix CUDA Runtime
and Driver API ownership in one context without an explicit interoperability
contract.

Existing `CUDAGate`, `AMDGate`, `MetalGate`, and `IntelGate` become thin policy
and identity adapters over the common runtime where supported. Their public
fail-closed behavior remains until each adapter passes its hardware gate.

### 5.4 Treat NPUs as compiled-graph providers

NPUs do not share a portable arbitrary-pointer GEMM model:

- HailoRT executes Hailo Executable Format artifacts through VDevices and
  configured inference streams/models.
- Apple exposes Neural Engine selection through Core ML compute-unit policy,
  not a supported public low-level `AppleNeuralEngine.framework` GEMM ABI.
- Intel NPU execution should use OpenVINO's `NPU` plugin and compiled models,
  not infer support from a guessed driver library filename.
- Qualcomm uses QNN/SNPE deployment contracts and requires an SDK-specific
  backend, context, graph, and target runtime.

Create one `NPUProvider` lifecycle contract for artifact compatibility,
input/output metadata, binding, submit, wait, cancel where supported, and
release. Vendor bridges may use a small versioned C ABI when a stable Mojo
binding is unavailable. The bridge must expose no raw vendor C++ objects.

`gemm_f16_npu()` stays fail-closed unless a specific provider supports a
compiled MatMul proof artifact. End-to-end NPU inference uses the provider graph
API rather than pretending GGUF weights can be submitted directly.

### 5.5 Keep CPU as oracle, not hidden fallback

Backend selection has three distinct states:

- **configured:** requested by user or config;
- **runtime-loadable:** necessary libraries/components can initialize;
- **physically supported:** a compatible device and required features were
  observed and passed the appropriate proof level.

An explicit accelerator request fails before model mutation or inference if any
required state is absent. `auto` may select only a backend whose end-to-end
model slice is verified; otherwise it selects the verified CPU path and reports
that decision honestly.

## 6. Required Corrections to Existing Surfaces

These corrections precede positive hardware claims:

1. Add an `APPLE_METAL` GPU realm without renumbering existing public values.
   `ARM_MALI_OPENCL` must never route to `MetalGate`.
2. Make topology probes append/deduplicate results. Today each GPU probe clears
   the prior list, so an all-backend probe cannot retain multiple discoveries.
3. Replace backend-only lists with physical device records. Multiple devices of
   the same backend must remain distinguishable.
4. Make Metal availability require an Apple platform and a real Metal device;
   loading `libobjc.dylib` is not Metal discovery.
5. Make CUDA use one coherent runtime route and real device API results.
6. Make AMD resolve supported versioned libraries and confirm
   `hipGetDeviceCount`; a DRM node alone is insufficient.
7. Make Intel enumerate Level Zero drivers and GPU devices; loader presence is
   insufficient and current Level Zero guidance begins with `zeInitDrivers`.
8. Remove private/guessed library names from positive NPU detection.
9. Preserve `ARM_NEON` for API compatibility but classify it as CPU SIMD, not a
   physical NPU.
10. Preserve `JETSON_NVIDIA` for compatibility but route supported Jetson GPU
    work through CUDA. A future TensorRT DLA provider must be labeled DLA, not
    generic NPU.
11. Keep `GENERIC_NPU` configuration-only until a registered provider owns it.
12. Align `target_npu` values with implemented provider IDs and artifact
    compatibility; `hailo8` cannot imply `HAILO_10` support.
13. Replace `GPUBuffer`/`NPUBuffer` host-view naming at new call sites with
    explicit `HostBufferView`; preserve old descriptors only as compatibility
    surfaces until separate deletion approval exists.
14. Keep `rmsnorm_gpu()` fail-closed until a real device RMSNorm exists. Its
    current future path would call host `rmsnorm()` after CUDA discovery begins
    succeeding.
15. Prevent accelerator dispatch from accepting host `RuneTensor` values except
    in the deliberately named proof/staging boundary.
16. Leave the current multi-device inference branch disabled until its GQA
    partitioning, reconstruction, attention ownership, and KV layout are
    redesigned.

## 7. File and Ownership Map

The exact names may be adjusted during the first contract slice, but ownership
must remain this explicit.

| Path | Required responsibility |
|---|---|
| `aesir_engine/core/device_runtime.mojo` | Backend-neutral device IDs, properties, errors, contexts, streams/events, and runtime contract |
| `aesir_engine/core/device_tensor.mojo` | Opaque owned device allocation and checked tensor metadata |
| `aesir_engine/core/device_pool.mojo` | Persistent weights, workspace arena, KV allocations, budgets, deterministic release |
| `aesir_engine/core/gpu_runtime.mojo` | `max.gpu` initialization, common GPU buffers, copies, events, kernel compile/load/launch |
| `aesir_engine/core/gpu_kernels.mojo` | Correctness-first F16 GEMM and later device operators |
| Existing `*_gate.mojo` GPU files | Backend identity, capability policy, error translation, explicit support status |
| `aesir_engine/core/npu_provider.mojo` | Compiled-artifact provider lifecycle and binding contract |
| `aesir_engine/core/npu_gate.mojo` | Provider registry and selection; no guessed positive discovery |
| `aesir_engine/native/` | Only necessary, versioned C/Objective-C++ vendor bridges with build ownership |
| `aesir_engine/core/mimir_well.mojo` | Host memory remains host memory; topology migrates to physical records |
| `aesir_engine/core/compute.mojo` | Host compute plus explicit host/device dispatch boundaries |
| `aesir_engine/core/inference.mojo` | CPU executor and accelerator executor selection; no per-call hidden staging |
| `aesir_engine/core/accelerator_executor.mojo` | Device-resident model state, operator scheduling, KV cache, teardown |
| `aesir_engine/loader/gguf.mojo` | Checked host mapping and explicit device staging plan |
| `aesir_engine/aesir.mojo` | Runtime creation, selected backend, model load, generation ownership |
| `aesir_engine/config.mojo` | Stable backend/device/offload schema and validation |
| `aesir_engine/cli/` | Discovery/status output, user selection, honest fallback/error text |
| `aesir_engine/tests/` | CPU-only contract tests plus separately tagged physical tests |
| `.github/workflows/` | CPU CI and isolated trusted hardware workflows |
| `scripts/` | Hardware evidence validator and artifact-schema checks |

No new file is created until its first real behavior, owner, test, and interface
change land in the same slice.

## 8. Staged GPU Work Plan

### GPU-0 — Lock the contract and prove toolchain reachability

- Pin the exact Mojo/MAX APIs used by the runtime.
- Compile a minimal program using the locked `max.gpu` package.
- On the RTX host, prove context creation, device identity, one device buffer,
  one round-trip copy, one kernel launch, synchronization, and cleanup.
- Record driver, runtime, Mojo/MAX, GPU, command, and output metadata.
- Keep all public A.E.S.I.R. accelerator entry points fail-closed during this
  spike.

**Exit gate:** a disposable proof executable runs on the physical RTX device
and a checked task record identifies the exact production APIs to wrap.

### GPU-1 — Implement truthful physical discovery

- Add `PhysicalDevice` and `DeviceCapabilities` records.
- Enumerate through the selected runtime and retain all observed devices.
- Add stable selection by backend-local index and stable ID where available.
- Distinguish unsupported runtime, no device, incompatible driver, unsupported
  architecture, missing compiler/tool, and permission failures.
- Correct the topology accumulation and Metal realm errors listed above.
- Preserve CPU-only tests through injectable discovery adapters; do not fake
  positive hardware in production discovery.

**Exit gate:** `AES-ACC-003` has local RTX discovery evidence and negative
tests, while other backends remain unpromoted.

### GPU-2 — Implement ownership, buffers, copies, and synchronization

- Create owned `DeviceContext`, `DeviceStream`, `DeviceEvent`, `DeviceBuffer`,
  and `DeviceTensor` wrappers.
- Add checked allocation counts and byte-overflow guards.
- Add synchronous proof copies, then asynchronous copies with explicit events.
- Define destructor/close ordering and make repeated close safe.
- Track allocated bytes and enforce a configured memory budget.
- Inject allocation, copy, sync, and device-lost errors and prove cleanup.

**Exit gate:** random byte and F16 round trips pass on RTX hardware; leak and
double-free tests pass; host code cannot dereference device memory.

### GPU-3 — Implement the first genuine F16 GEMM

- Add a correctness-first Mojo GPU GEMM with the repository's exact matrix
  convention: `A[M,K]` times logical transposed weight storage `B[N,K]` gives
  `C[M,N]`.
- Handle tails, small generation shapes, alignment, and non-multiple sizes.
- Accumulate F16 products in F32 where required by the numerical contract.
- Prove actual launch and synchronization using device events and output
  readback.
- Compare deterministic and randomized matrices to CPU F32 and verified CPU
  engine references with documented tolerances.
- Retain all current shape and unsupported-backend errors.

**Exit gate:** physical CUDA GEMM parity, invalid-shape tests, failure cleanup,
and a hardware evidence artifact pass. Only the narrow proved CUDA dispatch may
move from `missing` toward `partial`.

### GPU-4 — Make model memory genuinely device-resident

- Build a model staging plan from validated GGUF tensor spans.
- Stage supported F16 weights once during engine initialization.
- Record host source span, device allocation, dtype, shape, checksum/provenance,
  and lifetime for every staged tensor.
- Add a persistent device workspace and device KV cache budget.
- Reject a model before partial activation if it cannot fit the configured
  budget; clean up partial staging.
- Keep CPU `mmap` alive only for its declared lifetime and never call the staged
  copy “zero-copy.”

**Exit gate:** a pinned real F16 GGUF loads into tracked GPU allocations,
releases cleanly, and can execute one real model projection with logit parity.

### GPU-5 — Complete the single-device transformer operator set

Implement and prove, in dependency order:

1. F16 projection GEMMs for Q, K, V, output, FFN up/gate/down, and logits;
2. RMSNorm;
3. RoPE;
4. KV-cache append and checked slice access in device memory;
5. GQA attention/online softmax with causal masking;
6. SiLU and FFN elementwise multiply;
7. residual additions;
8. final normalization and logits.

Keep operator-level CPU parity tests for boundary shapes, GQA head ratios,
sequence positions, and context capacity. Do not copy activations to the CPU
between operators except in explicitly tagged debug/parity mode.

**Exit gate:** one complete transformer block and then the complete pinned model
remain device-resident across a token step and match CPU logits/tokens.

### GPU-6 — Connect generation, configuration, and the CLI

- Replace Boolean accelerator flags with an explicit execution plan.
- Add backend, device, memory budget, offload policy, and diagnostic fields.
- Support `cpu`, `cuda`, and verified `auto` first. Parse other backend names but
  reject them with precise observed-state errors until proved.
- Make `num_gpu_layers` real only after hybrid CPU/GPU layer ownership and
  transfer boundaries have parity tests; otherwise require all-or-none.
- Print selected physical device and proof level once at startup.
- Add device metadata to `ps`, status, and generation reports only where those
  commands have real state owners.
- Preserve explicit-request failure before model mutation.

**Exit gate:** the native CLI runs the pinned model on the RTX GPU and produces
the same verified token sequence as CPU; explicit invalid/unavailable choices
fail closed.

### GPU-7 — Harden and measure

- Add cancellation at queue-safe boundaries.
- Prove OOM, bad device, incompatible architecture, kernel compilation failure,
  launch failure, timeout, device loss, and teardown during partial init.
- Validate concurrent engine policy; serialize access until safe multi-stream
  ownership is proved.
- Measure warmup separately from steady-state execution.
- Report tokens/second, time to first token, per-token latency, peak device
  bytes, host-device bytes, and power/temperature where reliable.
- Record raw samples and environment metadata; publish no performance claim
  from a debug build or single unlabelled run.

**Exit gate:** accelerator execution is stable under repeated generation and
fault injection, and benchmark records pass the evidence schema.

### GPU-8 — Extend one backend at a time

After CUDA is complete, use the same common contract and independent hardware
gates:

1. **AMD GPU:** MAX GPU path where supported; HIP discovery/capability evidence
   and physical AMD runner required.
2. **Apple Metal:** add `APPLE_METAL`; use MAX/Metal on Apple silicon; add a
   macOS lock/platform and physical Mac runner.
3. **Intel GPU:** Level Zero discovery plus a supported kernel execution route;
   loader-only evidence is rejected.
4. **ARM Mali/OpenCL and other enum realms:** separate projects only when a
   supported runtime, compiler, hardware, and model proof exist.

Each backend starts `missing`, passes discovery, memory, GEMM, model, cleanup,
and CI gates independently, and gets its own ledger evidence.

## 9. Staged NPU Work Plan

### NPU-0 — Correct the taxonomy and provider boundary

- Separate CPU SIMD, GPU, DLA, and NPU identities without renumbering existing
  compatibility values.
- Replace guessed/private library probes with provider initialization.
- Define artifact metadata: vendor, architecture, compiler/runtime versions,
  source model identity, input/output names, dtypes, shapes, checksum, and
  compatibility range.
- Define provider lifecycle: discover, open, validate artifact, bind inputs and
  outputs, submit, wait, cancel if supported, collect telemetry, release.
- Make unsupported dynamic shapes, operators, dtypes, and artifacts fail before
  execution.

**Exit gate:** no enum or loadable library can create a positive NPU result
without a physical provider and compatible compiled artifact.

### NPU-1 — Select the first physically controlled vendor

Select only after all of these are available:

- physical device under project control;
- redistributable runtime/driver and accessible official API contract;
- supported model compiler/exporter;
- a legally usable, checksum-pinned deployment artifact;
- an independent CPU or vendor oracle;
- repeatable hardware test access.

The current host does not satisfy this gate. No first NPU backend is selected by
this plan merely to fill an enum.

### NPU-2 — HailoRT candidate track

If Hailo-10H hardware and a supported model artifact are obtained:

- enumerate with HailoRT rather than a filesystem or `dlopen` guess;
- create and own a VDevice;
- validate and load the exact HEF artifact;
- query input/output stream metadata and validate all bindings;
- configure the inference model/network group;
- allocate host/device-visible I/O under HailoRT's supported contract;
- submit asynchronous inference, wait for the job, and propagate vendor status;
- compare outputs to the artifact's reference oracle;
- release configured model/network, HEF, streams, and VDevice in documented
  order;
- record HailoRT, firmware, device architecture, HEF compiler, and artifact
  versions.

Do not claim that a GGUF file can run on Hailo. Compilation to a supported HEF
is a separate provenance-controlled build process.

### NPU-3 — Intel NPU candidate track

- use OpenVINO device discovery and `NPU` plugin capabilities;
- read/convert a supported model, compile it for `NPU`, and validate compiled
  model/runtime requirements;
- create requests/tensors, bind inputs/outputs, execute, wait, and release;
- version or invalidate compiled-model caches because compatibility across
  OpenVINO versions is not guaranteed;
- compare the exact graph against CPU/OpenVINO reference output;
- keep Intel GPU Level Zero and Intel NPU OpenVINO identities separate.

### NPU-4 — Apple Neural Engine candidate track

- implement a small Objective-C/Swift-compatible Core ML bridge on macOS;
- load a signed/checksummed Core ML model with
  `cpuAndNeuralEngine`/appropriate compute-unit policy;
- inspect model input/output constraints and execute predictions;
- report requested compute policy separately from observed performance;
- never probe or bind private Apple Neural Engine frameworks;
- keep Apple Metal GPU execution as a separate backend.

Because Core ML may schedule across allowed compute units, provider proof must
use supported Apple diagnostics and must not overclaim per-operator ANE
placement when the public API does not expose it.

### NPU-5 — Qualcomm QNN candidate track

- require the exact redistributable QNN SDK and target device first;
- pin backend, system/context binary, graph, skeleton/RPC requirements, and SoC;
- expose a small stable bridge for backend/device/context/graph ownership;
- validate tensors, execute, synchronize, translate errors, and release in SDK
  order;
- record DSP/HTP target and artifact compiler provenance;
- test on the named Snapdragon/Hexagon hardware, never an x86 library stub.

### NPU-6 — Integrate a supported model slice

- choose either full-model execution or a precisely bounded subgraph offload;
- budget conversion boundaries and prevent per-token transfer thrashing;
- keep tokenizer/sampler ownership explicit;
- compare graph outputs, logits where exposed, token IDs, and generated text;
- prove cancellation/restart and artifact incompatibility behavior;
- enable CLI selection only for the exact verified provider/artifact family.

**Exit gate:** `AES-ACC-006` can be promoted only for the named provider and
model/artifact scope. Other NPU values remain missing.

## 10. Quantization and Model Compatibility

The first GPU model proof stays on the already verified F16 GGUF slice. This
separates accelerator correctness from unresolved quantized-format work.

After F16 end-to-end GPU parity:

1. complete upstream-exact Q4_K_M loader/layout parity;
2. stage quantized weights with exact byte-span metadata;
3. implement one fused or explicitly dequantizing device GEMM;
4. compare decoded tensors, logits, tokens, text, memory, and transfers against
   authoritative oracles;
5. add each further quantization format independently.

No generic quantization dispatcher may imply GPU/NPU support from CPU kernels or
format metadata alone.

## 11. Zero-Copy and Memory-Mapping Rule

`AES-ACC-009` remains missing during ordinary staged device copies.

An achievable contract is backend-specific:

- CPU file `mmap` plus host-to-device copy is **staged loading**;
- CUDA registered/pinned host memory is **pinned staging**, not direct
  file-to-VRAM zero-copy;
- unified/shared memory is named as such and requires residency/synchronization
  evidence;
- DMA-BUF/imported memory requires a real exported handle, compatibility,
  ownership, mapping, cache-coherency, and lifetime proof;
- Apple shared storage is a Metal storage-mode contract, not a universal GPU
  mmap claim;
- NPU shared buffers follow the selected vendor's documented import API.

Promote `AES-ACC-009` only after measuring actual copies/page migration and
proving teardown and synchronization on one named backend. Otherwise document
the staging copy honestly and leave zero-copy unsupported.

## 12. Multi-GPU Comes After Single-GPU Correctness

Before enabling `num_devices > 1`:

- define physical placement for every weight, activation, and KV shard;
- correct GQA Q/K/V partitioning and head ownership;
- define row/column parallel reconstruction;
- select a real collective mechanism or explicit peer-copy reduction;
- prove peer capability, device-to-device transfers, streams/events, ordering,
  cancellation, and device-loss propagation;
- prevent a partial result from being presented after one shard fails;
- compare one-device and multi-device logits/tokens;
- measure scaling and transfer volume on at least two physical GPUs.

Host sharding remains a separate verified CPU capability. `AES-ACC-004` cannot
inherit its status.

## 13. Test and Evidence Matrix

| Layer | CPU-only CI | Physical accelerator gate |
|---|---|---|
| Discovery | Parser/error/injected-adapter tests; no fabricated positives | Actual device identity and capability query |
| Ownership | Arithmetic, invalid state, double-close, injected failure | Allocate/release loops and memory-accounting stability |
| Transfer | Bounds, overlap policy, zero-length policy | H2D/D2H/D2D round-trip and event ordering |
| Kernel | Shape/tolerance/reference harness | Actual launch, sync, parity, tail shapes |
| Model staging | Tensor-span and budget tests | Persistent weights and partial-init cleanup |
| Operator | CPU reference corpus | Device output parity for every required op |
| End to end | Pinned CPU GGUF oracle | Same model/prompt/logits/tokens on named device |
| Failure | Injected status codes | OOM, bad device, incompatible binary, device loss where safely reproducible |
| Performance | Evidence-schema validation only | Raw warm/cold samples with environment metadata |
| NPU artifact | Manifest/schema/compatibility negatives | Vendor compiler/runtime/device execution and oracle |

Hardware tests must be opt-in locally and required on protected hardware
workflows before a capability promotion. A normal CPU GitHub-hosted job must
never synthesize a positive accelerator result.

## 14. Hardware CI Design

1. Keep the existing unprivileged CPU workflow required for every change.
2. Add isolated workflows per backend and runner label.
3. Never expose hardware-runner secrets to untrusted fork pull requests.
4. Build from a clean checkout and locked dependencies.
5. Record device/runtime/driver/compiler/model identifiers before tests.
6. Run discovery, memory, kernel, model parity, cleanup, and negative tests.
7. Upload a small text/JSON evidence record, not model weights or proprietary
   compiled artifacts unless redistribution is explicitly allowed.
8. Validate evidence schema and reject missing metadata or zero executed cases.
9. Require the relevant hardware job for backend capability promotion.
10. Treat unavailable hardware as `skipped/external prerequisite`, never pass.

## 15. Error and Recovery Contract

Every backend maps native failures into one of these stable categories while
retaining native detail:

- runtime missing or incompatible;
- no physical device;
- permission/access failure;
- unsupported device/architecture/feature;
- invalid device selection;
- invalid shape/dtype/layout/alignment;
- arithmetic overflow or allocation-budget violation;
- host or device out of memory;
- transfer failure;
- kernel/graph compile or artifact incompatibility;
- launch/submit failure;
- synchronization timeout/failure;
- cancellation;
- device lost/reset required;
- cleanup failure.

Recovery may retry only operations documented as safe and idempotent. Device
loss invalidates the associated context, allocations, events, compiled kernels,
and model state. The engine must either recreate the complete state under a
documented policy or fail the request; it must not continue with stale handles.

## 16. Commit-and-Push Sequence

Every numbered slice is committed, pushed to `origin/main`, and observed in CI
before the next high-risk slice begins:

1. task contract — already committed as `92816a1`;
2. this dated gameplan and task completion evidence;
3. exact-version MAX GPU reachability task and proof record;
4. device-runtime types and CPU-only contract tests;
5. real CUDA discovery and RTX hardware evidence;
6. device buffer/copy/synchronization ownership;
7. genuine CUDA F16 GEMM and parity;
8. GGUF weight staging and device memory budget;
9. one full transformer block on GPU;
10. full single-token model step on GPU;
11. multi-token generation and CLI/config selection;
12. fault injection, repeated-run cleanup, and trusted hardware CI;
13. benchmark evidence after correctness;
14. each additional GPU backend as its own discovery-to-model series;
15. NPU provider contract and taxonomy correction;
16. each selected NPU vendor as its own artifact-to-model series;
17. multi-GPU only after the single-GPU exit gate;
18. backend-specific zero-copy only after measured proof.

Each implementation slice includes:

- a scoped `TASK_*.md` or bug reproduction;
- implementation and narrow tests;
- master suite, native build, negative control, consistency validators, and
  `git diff --check` as applicable;
- interface, ledger, TODO, task, and DEVLOG reconciliation;
- a reviewable commit with no unrelated generated artifacts;
- push to the real `main` branch and hosted/hardware CI observation.

## 17. Capability Promotion Gates

| Capability | Minimum evidence for promotion |
|---|---|
| `AES-ACC-003` | Physical API enumeration, stable device records, capabilities/errors, and named-hardware tests |
| `AES-ACC-008` | One backend's owned context/memory/transfers/kernel/sync/cleanup plus real-model parity and hardware CI |
| `AES-ACC-006` | One vendor NPU provider, compatible compiled artifact, real submit/wait/output parity/cleanup, and hardware CI |
| `AES-ACC-004` | Correct physical placement, collectives, GQA/KV ownership, failure handling, parity, and scaling on multiple GPUs |
| `AES-ACC-009` | Backend-specific mapping/import contract, measured copy/migration behavior, synchronization/lifetime proof, and hardware evidence |

Promotion scope must name the exact backend, hardware family, software versions,
model/format slice, precision, and known limits. “GPU supported” or “NPU
supported” is too broad until all separately named tracks pass.

## 18. Completion Checklist

The GPU/NPU program is complete only when:

- [ ] configuration, discovery, and physical selection are distinct;
- [ ] host and device address spaces cannot be confused;
- [ ] contexts, queues, buffers, events, kernels/graphs, and model state have
      explicit ownership;
- [ ] all required transformer operators execute on the selected GPU without
      hidden CPU work under GPU labels;
- [ ] one supported NPU provider executes its compiled model/graph on physical
      hardware without arbitrary-GGUF claims;
- [ ] CPU reference parity covers operator, logit, token, and text levels;
- [ ] explicit accelerator requests never silently fall back;
- [ ] all initialization and execution failures clean up deterministically;
- [ ] hardware CI reproduces each promoted backend;
- [ ] benchmarks are measured only after correctness and include raw metadata;
- [ ] multi-device and zero-copy claims remain separate until independently
      proved;
- [ ] no fake file, model, fixture, device, benchmark, or status promotion was
      introduced;
- [ ] the canonical ledger and public documentation match executable reality.

## 19. Primary Technical References

Recommendations in this plan were checked against current primary sources:

- [MAX 26.5 release notes and `max.gpu` migration](https://docs.modular.com/releases/v26.5/)
- [Mojo GPU programming fundamentals](https://docs.modular.com/mojo/manual/gpu/fundamentals/)
- [Mojo/MAX GPU system requirements](https://docs.modular.com/mojo/requirements/)
- [NVIDIA CUDA Runtime API](https://docs.nvidia.com/cuda/cuda-runtime-api/index.html)
- [Apple Metal device creation](https://developer.apple.com/documentation/metal/mtlcreatesystemdefaultdevice%28%29)
- [Apple Metal Performance Shaders matrix multiplication](https://developer.apple.com/documentation/metalperformanceshaders/mpsmatrixmultiplication)
- [Level Zero core programming guide](https://oneapi-src.github.io/level-zero-spec/level-zero/latest/core/PROG.html)
- [HailoRT official repository and runtime description](https://github.com/hailo-ai/hailort)
- [HailoRT C inference-pipeline example](https://github.com/hailo-ai/hailort/blob/master/hailort/libhailort/examples/c/infer_pipeline_example/infer_pipeline_example.c)
- [OpenVINO NPU device documentation](https://docs.openvino.ai/2026/openvino-workflow/running-inference/inference-devices-and-modes/npu-device.html)
- [Apple Core ML compute-unit policy](https://developer.apple.com/documentation/coreml/mlcomputeunits)

Vendor documentation and the locked runtime must be rechecked at the start of
each backend task. A later API version is not evidence that the repository's
locked version supplies the same interface.
