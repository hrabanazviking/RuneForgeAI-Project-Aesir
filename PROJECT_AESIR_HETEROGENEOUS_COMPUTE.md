# Project Aesir Heterogeneous Compute Architecture

**Status:** Proposed Architecture Specification\
**Project:** RuneForgeAI -- Project Aesir\
**Suggested repository path:**
`docs/architecture/HETEROGENEOUS_COMPUTE.md`\
**Purpose:** Define a capability-driven, memory-aware hardware
abstraction and execution architecture that allows Aesir to use CPUs,
discrete GPUs, integrated/shared-memory GPUs, NPUs, and multiple
accelerator backends individually or together.

------------------------------------------------------------------------

## 1. Executive Summary

Project Aesir should not treat an AI system as having one "GPU." It
should treat the machine as a **pool of compute devices, memory domains,
interconnects, and capabilities**.

A modern machine may simultaneously contain:

-   a CPU with large system RAM,
-   an NVIDIA discrete GPU with limited but very fast VRAM,
-   an AMD integrated GPU sharing system RAM,
-   an NPU,
-   multiple discrete GPUs,
-   or an Apple Silicon CPU/GPU sharing unified memory.

Aesir should discover these resources at runtime, describe them through
a common capability model, benchmark or estimate their useful
performance, and construct an execution plan for each model.

The central principle is:

> **Do not ask "Which GPU should run this model?" Ask "What compute,
> memory, and data paths exist on this machine, and what is the best way
> to map this workload onto them?"**

This architecture is intended to make Aesir especially effective on
heterogeneous and resource-constrained hardware while also scaling
upward to workstation and datacenter accelerators.

------------------------------------------------------------------------

## 2. Goals

### 2.1 Primary Goals

Aesir SHOULD:

1.  Run on systems with no accelerator.
2.  Run efficiently on NVIDIA CUDA hardware.
3.  Run on AMD GPUs through ROCm/HIP where supported.
4.  Provide Vulkan compute as an important cross-vendor fallback.
5.  Support Apple Silicon through Metal and/or MLX-capable execution
    paths.
6.  Recognize shared/unified-memory architectures as first-class systems
    rather than unusual edge cases.
7.  Use multiple heterogeneous devices when doing so is beneficial.
8.  Place model weights, KV cache, activations, and auxiliary workloads
    according to actual hardware capabilities and memory pressure.
9.  Degrade gracefully when a preferred backend is unavailable.
10. Preserve the Ollama-compatible external API regardless of the
    internal execution plan.
11. Remain usable on small edge systems such as Raspberry Pi and Jetson
    devices.
12. Permit future accelerator backends without redesigning the
    model-serving layer.

### 2.2 Non-Goals

The first implementation does NOT need to:

-   provide perfect tensor parallelism across unrelated GPU vendors;
-   combine every detected accelerator automatically;
-   outperform vendor-specific inference engines on their own ideal
    hardware;
-   implement custom kernels for every GPU architecture;
-   guarantee ROCm support on AMD devices AMD itself does not support;
-   treat raw theoretical FLOPS as sufficient for scheduling.

The architecture should permit these capabilities later without
requiring a rewrite.

------------------------------------------------------------------------

## 3. Design Philosophy

### 3.1 Capability-Based, Not Vendor-Based

Bad abstraction:

``` text
if NVIDIA:
    ...
elif AMD:
    ...
elif Apple:
    ...
```

Preferred abstraction:

``` text
Device:
    compute_api
    architecture
    memory_domain
    usable_memory
    bandwidth
    supported_dtypes
    supported_operations
    zero_copy_capability
    peer_access
    estimated_compute
    measured_performance
```

Vendor and model names remain useful metadata, but scheduling decisions
should primarily depend on capabilities.

Two AMD GPUs can differ more meaningfully than two devices from
different vendors. The same applies to NVIDIA generations, integrated
versus discrete Radeon hardware, and Apple Silicon generations.

------------------------------------------------------------------------

## 4. Core Architectural Layers

``` text
┌───────────────────────────────────────────────────────┐
│               Ollama-Compatible API                  │
├───────────────────────────────────────────────────────┤
│                 Aesir Model Router                   │
├───────────────────────────────────────────────────────┤
│          Heterogeneous Execution Planner             │
├───────────────────────────────────────────────────────┤
│ Device Registry │ Memory Planner │ Policy Engine     │
├───────────────────────────────────────────────────────┤
│             Capability Abstraction Layer             │
├───────────────────────────────────────────────────────┤
│ CPU │ CUDA │ HIP/ROCm │ Vulkan │ Metal/MLX │ Future │
├───────────────────────────────────────────────────────┤
│                   Physical Hardware                  │
└───────────────────────────────────────────────────────┘
```

The API layer should never need to know whether inference is occurring
on CUDA, an AMD APU, Apple unified memory, CPU-only hardware, or a
mixture.

------------------------------------------------------------------------

## 5. Device Discovery

At startup, Aesir should enumerate all usable compute devices.

Example:

``` text
AESIR HARDWARE DISCOVERY

CPU0
  AMD Ryzen ...
  RAM domain: SYSTEM
  available memory: 51.2 GiB

GPU0
  NVIDIA GeForce RTX ...
  backend: CUDA
  memory domain: DEDICATED
  usable VRAM: 7.4 GiB

GPU1
  AMD Radeon Integrated Graphics
  backends:
    HIP: available/unsupported/unknown
    Vulkan: available
  memory domain: SHARED_SYSTEM
  usable shared allocation: dynamically determined
```

Discovery SHOULD gather:

-   vendor
-   device name
-   PCI/device identifier where applicable
-   architecture/gfx target/compute capability
-   driver version
-   backend availability
-   total memory
-   currently free memory
-   safe working-set estimate
-   dedicated versus shared memory
-   memory bandwidth, if known
-   CPU↔device transfer characteristics
-   device↔device transfer characteristics
-   supported numerical formats
-   backend-supported operations
-   concurrency capabilities
-   power state where available
-   thermal information where available
-   peer-to-peer support
-   unified/managed-memory support

------------------------------------------------------------------------

## 6. Common Device Descriptor

Conceptual structure:

``` toml
[[device]]
id = "gpu.amd.0"
type = "gpu"
vendor = "amd"
architecture = "rdna"
backend = ["hip", "vulkan"]

[device.memory]
model = "shared_system"
total_bytes = 68719476736
safe_allocatable_bytes = 42949672960
zero_copy_cpu_access = true

[device.compute]
fp32 = true
fp16 = true
bf16 = "probe"
int8 = true

[device.features]
unified_memory = true
peer_to_peer = false
```

Values should support states such as:

``` text
true
false
unknown
unsupported
probe-required
```

Aesir should avoid assuming a feature merely because a vendor or
architecture normally possesses it.

------------------------------------------------------------------------

## 7. Memory Domains

Memory architecture should be modeled independently from compute
architecture.

Suggested domains:

``` text
SYSTEM_RAM
DEDICATED_VRAM
SHARED_SYSTEM
UNIFIED_MEMORY
MANAGED_MEMORY
REMOTE_MEMORY
```

### 7.1 Dedicated VRAM

Typical discrete NVIDIA and AMD GPUs.

Advantages:

-   high bandwidth;
-   low accelerator latency;
-   optimized vendor runtimes.

Disadvantages:

-   capacity may be small;
-   CPU↔GPU copies can be expensive;
-   a model may not fit.

### 7.2 Shared-System Memory

Typical integrated GPUs/APUs.

CPU and GPU use system RAM as part of the same physical memory
environment.

Advantages:

-   potentially much larger accessible capacity than low-VRAM discrete
    GPUs;
-   reduced need for traditional VRAM staging in suitable execution
    models;
-   excellent target for edge systems;
-   interesting for large quantized models.

Disadvantages:

-   bandwidth is normally much lower than high-end dedicated VRAM;
-   CPU and GPU contend for memory bandwidth;
-   firmware and driver restrictions may limit usable allocations;
-   advertised system RAM is NOT equivalent to GPU-usable model
    capacity.

### 7.3 Apple Unified Memory

Apple Silicon should be treated as a specialized unified-memory
architecture.

MLX explicitly operates around Apple Silicon unified memory, where CPU
and GPU can operate on arrays from the same shared memory pool without
conventional explicit CPU↔GPU tensor movement.

Aesir should therefore avoid pretending Apple unified memory is simply
"large VRAM." Its data movement characteristics are fundamentally useful
to the scheduler.

### 7.4 AMD Unified/Managed Memory

HIP supports managed/unified-memory mechanisms, but availability and
behavior vary by architecture, kernel, HMM support, XNACK configuration,
and ROCm support status.

Therefore:

> Aesir MUST probe AMD memory capabilities at runtime rather than infer
> them solely from the presence of an AMD GPU.

------------------------------------------------------------------------

## 8. AMD APU / Integrated GPU Strategy

AMD integrated GPUs are strategically important to Aesir.

They represent inexpensive hardware where:

-   CPU cores are available;
-   GPU compute is available;
-   large system-memory pools may exist;
-   both processors may access the same physical memory environment.

This is strongly aligned with Aesir's edge-compute philosophy.

### 8.1 Do Not Reserve All RAM for the GPU

On a 64 GiB system, Aesir must NOT assume:

``` text
GPU capacity = 64 GiB
```

Instead:

``` text
safe_model_budget =
    physical_ram
  - operating_system_reserve
  - Aesir_runtime_reserve
  - KV_cache_reserve
  - user_safety_margin
  - active_application_pressure
```

The resulting allocation might be substantially smaller than total RAM.

### 8.2 Dynamic Shared-Memory Budget

Example:

``` text
Physical RAM:              64 GiB
OS + applications reserve:  8 GiB
Aesir safety reserve:       4 GiB
KV/context reserve:         8 GiB
Emergency headroom:         4 GiB
---------------------------------
Potential weight budget:   40 GiB
```

This is an illustration, not a fixed policy.

The planner should monitor memory pressure and adjust.

### 8.3 Backend Preference

For an AMD integrated GPU:

``` text
1. Native ROCm/HIP backend, when supported and benchmarked as healthy
2. Vulkan backend
3. CPU SIMD backend
4. Experimental/community backend only when explicitly enabled
```

ROCm support should never be assumed for every Radeon or Ryzen APU. AMD
publishes explicit compatibility information, and unsupported hardware
may still work through community or alternative paths.

------------------------------------------------------------------------

## 9. Backend Abstraction

A backend is an execution implementation, not a device identity.

Proposed interface:

``` text
Backend
 ├── probe()
 ├── enumerate_devices()
 ├── query_capabilities(device)
 ├── estimate_memory(model, config)
 ├── supports_op(op)
 ├── supports_dtype(dtype)
 ├── allocate()
 ├── load_tensor()
 ├── execute_graph()
 ├── synchronize()
 ├── benchmark()
 └── release()
```

Initial backend families:

``` text
CPU
CUDA
HIP/ROCm
Vulkan
Metal
MLX
```

Possible future backends:

``` text
OpenCL
SYCL
OpenVINO
DirectML
WebGPU
NPU/vendor runtimes
remote Aesir nodes
```

The design should permit multiple backends to be compiled or loaded
dynamically.

------------------------------------------------------------------------

## 10. Backend Selection

Selection should use scoring rather than a fixed vendor chain.

Conceptually:

``` text
score =
    compatibility
  + model_fit
  + measured_bandwidth
  + measured_compute
  + operation_coverage
  + memory_efficiency
  - transfer_penalty
  - contention_penalty
  - thermal_penalty
  - instability_penalty
```

A backend with theoretically greater compute may lose if:

-   the model constantly crosses PCIe;
-   its memory is too small;
-   required operations fall back to CPU;
-   its driver is unstable;
-   another device provides zero-copy access;
-   it is thermally throttled.

------------------------------------------------------------------------

## 11. Hardware Profiling

Static hardware specifications are not enough.

Aesir should maintain a small local hardware profile containing measured
characteristics.

Example:

``` json
{
  "device": "gpu.amd.0",
  "backend": "vulkan",
  "memory_bandwidth_score": 0.61,
  "matmul_q4_score": 0.74,
  "fp16_score": 0.68,
  "transfer_cpu_to_gpu_gbps": 38.2,
  "stable": true
}
```

Benchmarks should be:

-   short;
-   cached;
-   rerunnable;
-   versioned by driver/backend version;
-   invalidated after meaningful hardware/software changes.

This allows Aesir to learn the actual machine rather than rely
exclusively on vendor tables.

------------------------------------------------------------------------

## 12. Execution Planner

The execution planner receives:

``` text
Model
Model format
Quantization
Context requirement
Batch size
Latency/throughput policy
Detected devices
Memory state
Backend capabilities
Hardware benchmark profile
```

It produces:

``` text
ExecutionPlan
```

Example:

``` yaml
plan:
  weights:
    transformer_layers_0_7: cuda:0
    transformer_layers_8_31: amd-vulkan:0

  kv_cache:
    location: system-shared

  embeddings:
    device: cpu:0

  sampling:
    device: cpu:0

  policy:
    objective: balanced
```

The exact split mechanisms will depend on the underlying inference
engine. The architecture should permit such planning even before every
combination is executable.

------------------------------------------------------------------------

## 13. Execution Modes

### Mode A: Single Best Device

``` text
MODEL → RTX GPU
```

Use when the complete model and runtime state comfortably fit.

### Mode B: GPU + CPU Offload

``` text
FAST GPU
  ↓
remaining layers
  ↓
SYSTEM RAM / CPU
```

Useful when dedicated VRAM is insufficient.

### Mode C: Shared-Memory APU

``` text
SYSTEM RAM
 ├── CPU
 └── AMD iGPU
```

Weights remain in the shared memory environment where supported.

### Mode D: Heterogeneous Discrete + Integrated

``` text
RTX GPU VRAM
     │
     ├── high-value layers / kernels
     │
SYSTEM RAM
     │
     ├── AMD integrated GPU
     └── CPU
```

This is an important experimental Aesir target.

### Mode E: Multiple Discrete GPUs

``` text
GPU0 ── GPU1 ── GPU2
```

Support layer splitting first. More communication-intensive tensor
parallelism should be optional and capability/interconnect aware.

### Mode F: Apple Unified Memory

``` text
UNIFIED MEMORY
 ├── Apple CPU
 └── Apple GPU
```

Planner optimizes operations without assuming conventional VRAM
transfers.

### Mode G: CPU-Only Edge

``` text
MODEL
 ↓
Quantized CPU kernels
 ↓
ARM/x86 SIMD
```

Aesir must always retain a strong CPU path.

------------------------------------------------------------------------

## 14. Heterogeneous NVIDIA + AMD Execution

A machine containing an NVIDIA discrete GPU and AMD integrated GPU
should not automatically disable one device.

Example:

``` text
NVIDIA RTX
  8 GiB fast VRAM
  CUDA

AMD iGPU
  large shared system-memory pool
  HIP or Vulkan

CPU
  same system RAM
```

Aesir should consider:

``` text
Tier 0: NVIDIA VRAM
Tier 1: AMD shared GPU-accessible memory
Tier 2: CPU/system execution
```

However, splitting across vendors is only useful when transfer costs do
not erase the compute gain.

Therefore the planner must measure or estimate:

``` text
CUDA ↔ system transfer cost
AMD iGPU ↔ system access cost
CUDA ↔ AMD effective transfer path
per-layer compute time
synchronization overhead
```

### 14.1 First Implementation

Do NOT begin with fine-grained cross-vendor tensor parallelism.

Start with coarse partitioning:

``` text
layers 0..N       → CUDA
layers N+1..M     → AMD or CPU
```

Coarse layer boundaries minimize cross-device communication.

### 14.2 Later Implementation

Possible later strategies:

-   operation-specific routing;
-   expert placement for Mixture-of-Experts models;
-   asynchronous prefetch;
-   speculative decoding on a secondary device;
-   draft model on iGPU, target model on dGPU;
-   embeddings on iGPU;
-   reranker on iGPU;
-   speech workloads on secondary accelerator;
-   background memory processing on otherwise idle hardware.

------------------------------------------------------------------------

## 15. Multi-Model Scheduling

Heterogeneous hardware becomes even more useful when Aesir runs multiple
AI components.

Example:

``` text
RTX CUDA GPU
    └── primary LLM

AMD integrated GPU
    ├── embedding model
    ├── reranker
    └── draft/speculative model

CPU
    ├── tokenizer
    ├── sampling
    ├── database
    └── lightweight agents

NPU
    └── speech/vision model when supported
```

This can outperform forcing every workload through the fastest
accelerator because it reduces contention and uses otherwise idle
silicon.

------------------------------------------------------------------------

## 16. Speculative Decoding as a Heterogeneous Feature

A particularly attractive Aesir strategy is:

``` text
AMD iGPU → small draft model
RTX GPU  → larger target model
```

The iGPU proposes tokens while the discrete GPU verifies them.

This transforms the integrated GPU from "slow secondary graphics" into a
potentially useful inference coprocessor.

The scheduler should benchmark whether this improves real tokens/second
before enabling it automatically.

------------------------------------------------------------------------

## 17. Mixture-of-Experts Models

MoE models create another opportunity.

Instead of requiring every expert to occupy the fastest VRAM:

``` text
frequently used experts → fast dedicated GPU
less frequently used experts → shared/system memory
routing → CPU or GPU
```

Future Aesir planners may use observed expert frequency to migrate
experts dynamically.

Conceptually:

``` text
HOT EXPERTS  → RTX VRAM
WARM EXPERTS → AMD shared memory
COLD EXPERTS → system RAM
```

This should be treated as a later optimization, not an MVP requirement.

------------------------------------------------------------------------

## 18. KV Cache Placement

KV cache should be independently placeable from model weights.

Possible locations:

``` text
dedicated GPU VRAM
shared/unified memory
system RAM
split across layer-owning devices
```

Planner inputs:

``` text
context length
KV datatype
batch size
available memory
memory bandwidth
backend support
```

Aesir should avoid consuming scarce dedicated VRAM with enormous KV
caches when moving the cache elsewhere permits significantly more useful
model weights to remain on the accelerator.

------------------------------------------------------------------------

## 19. Memory Pressure Management

The memory manager should continuously distinguish:

``` text
TOTAL
ALLOCATED
AVAILABLE
SAFE_AVAILABLE
RESERVED
RECLAIMABLE
```

`SAFE_AVAILABLE` is the important value.

Aesir should never attempt to consume all reported shared/unified
memory.

Possible policy:

``` text
safe_available =
    available_memory
    × configurable_safety_factor
```

For shared-memory systems, Aesir should additionally maintain an OS
survival reserve.

------------------------------------------------------------------------

## 20. Runtime Replanning

Execution plans should eventually be mutable.

Example:

``` text
User launches a memory-heavy application
        ↓
system memory pressure rises
        ↓
Aesir detects pressure
        ↓
planner reduces model/cache footprint
        ↓
layers/cache migrate or model reload occurs
```

Conversely:

``` text
memory becomes available
        ↓
Aesir may increase acceleration/offload
```

Initial versions can perform replanning only between requests or model
loads. Live migration can come later.

------------------------------------------------------------------------

## 21. User Policies

Automatic behavior should remain controllable.

Example configuration:

``` toml
[compute]
policy = "auto"

[compute.devices]
allow_cpu = true
allow_cuda = true
allow_rocm = true
allow_vulkan = true
allow_metal = true

[compute.memory]
system_reserve_gib = 8
shared_memory_max_percent = 70

[compute.scheduler]
objective = "balanced"
```

Objectives:

``` text
fastest
lowest_latency
highest_throughput
largest_model
lowest_power
lowest_memory
balanced
manual
```

For nomadic/edge operation, `lowest_power` can become a genuinely
important mode.

------------------------------------------------------------------------

## 22. Graceful Fallback Chain

Failure must not automatically mean inference failure.

Example:

``` text
ROCm requested
    ↓
ROCm device unsupported
    ↓
try Vulkan
    ↓
Vulkan unavailable
    ↓
try optimized CPU
    ↓
CPU succeeds
```

Aesir should report:

``` text
Preferred backend: ROCm
Status: unsupported on detected GPU
Fallback backend: Vulkan
Inference: available
```

This is much better than:

``` text
ERROR: GPU unsupported
```

------------------------------------------------------------------------

## 23. Backend Health

Each backend/device pair should maintain health state:

``` text
UNKNOWN
HEALTHY
DEGRADED
UNSTABLE
DISABLED
UNSUPPORTED
```

Repeated crashes should reduce scheduler preference.

Example:

``` text
AMD HIP backend:
    crashes = 2
    state = UNSTABLE

AMD Vulkan backend:
    crashes = 0
    state = HEALTHY

Scheduler selects Vulkan.
```

A user can still force an unstable backend for testing.

------------------------------------------------------------------------

## 24. Capability Cache

Hardware probing should generate a persistent capability record.

Suggested location:

``` text
~/.aesir/hardware/
```

Example:

``` text
hardware.json
benchmarks.json
backend-health.json
```

Cache key should include:

``` text
device identifier
driver version
backend version
Aesir version
kernel/OS information where relevant
```

A driver update should trigger revalidation.

------------------------------------------------------------------------

## 25. Device Roles

Rather than simply declaring a device active/inactive, Aesir can assign
roles:

``` text
PRIMARY_INFERENCE
SECONDARY_INFERENCE
DRAFT_MODEL
EMBEDDINGS
RERANKING
VISION
SPEECH
BACKGROUND_AGENT
MEMORY_PROCESSING
IDLE
```

Example:

``` text
RTX 4070      → PRIMARY_INFERENCE
AMD iGPU      → DRAFT_MODEL + EMBEDDINGS
CPU           → TOKENIZER + DATABASE
```

This makes heterogeneous hardware useful even when splitting one model
across devices is inefficient.

------------------------------------------------------------------------

## 26. Relationship to llama.cpp / GGML

Aesir should reuse proven lower-level mechanisms where practical rather
than reinvent every kernel.

Current llama.cpp architecture demonstrates several useful concepts:

-   multiple accelerator backends can coexist;
-   devices can be enumerated at runtime;
-   model layers can be distributed across GPUs;
-   automatic fitting can account for device memory;
-   CUDA, HIP, Vulkan, Metal and other backends can coexist in the
    broader GGML ecosystem.

Aesir should build a higher-level hardware intelligence layer around
such capabilities.

Aesir's differentiator should be:

``` text
discovery
+ capability reasoning
+ hardware profiling
+ memory policy
+ heterogeneous scheduling
+ model routing
+ edge optimization
```

rather than duplicating every vendor kernel.

------------------------------------------------------------------------

## 27. Backend Priority Is Workload-Specific

There should be no universal ordering such as:

``` text
CUDA > ROCm > Metal > Vulkan > CPU
```

Instead:

``` text
BackendScore(model, device, workload, system_state)
```

For example, Vulkan might outperform an unsupported or unstable HIP
configuration on a particular Radeon APU.

CPU may outperform an iGPU for a small operation after synchronization
overhead is included.

Apple GPU may be ideal for one graph while CPU execution is better for
another operation over the same unified-memory data.

------------------------------------------------------------------------

## 28. Testing Matrix

Aesir should maintain a public compatibility matrix.

Suggested categories:

  Class             Example        Purpose
  ----------------- -------------- --------------------------
  x86 CPU           Ryzen/Core     CPU baseline
  ARM CPU           Raspberry Pi   edge baseline
  NVIDIA consumer   RTX            CUDA consumer
  NVIDIA mobile     RTX Laptop     constrained CUDA
  NVIDIA Jetson     Orin           ARM + CUDA
  AMD APU           Ryzen Radeon   shared-memory AMD
  AMD Radeon        RX series      discrete consumer AMD
  AMD Instinct      MI series      ROCm datacenter
  Apple Silicon     M-series       unified-memory Metal/MLX
  Vulkan-only       various        portable fallback

------------------------------------------------------------------------

## 29. Compatibility Levels

Avoid binary "supported/not supported" labels.

Use:

``` text
LEVEL 0 – detected
LEVEL 1 – backend initializes
LEVEL 2 – model loads
LEVEL 3 – inference passes correctness tests
LEVEL 4 – benchmark validated
LEVEL 5 – production validated
```

Example:

``` text
AMD Ryzen 780M / Vulkan
Compatibility: Level 4

AMD Ryzen 780M / HIP
Compatibility: Level 2 Experimental
```

This provides much more useful information to users and developers.

------------------------------------------------------------------------

## 30. Correctness Before Performance

Every backend must pass identical inference correctness tests.

Tests should verify:

``` text
model load
tokenization consistency
logit sanity
deterministic-mode tolerance
context growth
KV cache correctness
quantization correctness
long generation
repeated load/unload
memory cleanup
OOM recovery
backend fallback
```

Performance benchmarking occurs only after correctness.

------------------------------------------------------------------------

## 31. Benchmark Suite

Aesir should benchmark at least:

``` text
model load time
prompt processing tokens/sec
generation tokens/sec
time to first token
peak memory
steady memory
CPU utilization
GPU utilization
power usage when available
thermal behavior
cross-device transfer bandwidth
```

Tests should include several model sizes and quantizations.

Example classes:

``` text
~1B
~3B
~8B
~14B
~30B
~70B
```

Large classes should only run when memory permits.

------------------------------------------------------------------------

## 32. Automatic Plan Search

A later planner can experimentally test a small number of valid plans.

Example:

``` text
PLAN A
100% CUDA

PLAN B
70% CUDA + 30% CPU

PLAN C
60% CUDA + 40% AMD iGPU

PLAN D
AMD iGPU only
```

Run a short benchmark.

Then:

``` text
winner = maximum useful_tokens_per_second
subject to memory and stability constraints
```

Store the result for that model/hardware combination.

This gives Aesir a form of local empirical hardware adaptation without
machine learning being required.

------------------------------------------------------------------------

## 33. Plan Cache

Suggested:

``` text
~/.aesir/plans/
```

Key:

``` text
model hash
quantization
context size class
hardware fingerprint
driver fingerprint
Aesir version
```

Example:

``` json
{
  "model": "example-32b-q4",
  "objective": "balanced",
  "plan": {
    "cuda_layers": 18,
    "amd_layers": 22,
    "kv": "shared"
  },
  "measured_tps": 11.4
}
```

Aesir can reuse a proven plan rather than search on every startup.

------------------------------------------------------------------------

## 34. Telemetry Philosophy

Hardware optimization data should be local by default.

Aesir does not need cloud telemetry to learn a machine.

Optional anonymous compatibility submissions could later allow the
community to build a hardware database, but they should be explicitly
opt-in.

Potential shared data:

``` text
device model
backend
driver version
Aesir version
compatibility level
benchmark score
```

Never require model prompts or user content.

------------------------------------------------------------------------

## 35. Proposed Internal Modules

Suggested logical modules:

``` text
aesir/
└── compute/
    ├── discovery
    ├── capability
    ├── devices
    ├── memory
    ├── backends
    │   ├── cpu
    │   ├── cuda
    │   ├── hip
    │   ├── vulkan
    │   ├── metal
    │   └── mlx
    ├── benchmark
    ├── planner
    ├── scheduler
    ├── health
    └── policy
```

Exact source layout can follow the language and architecture already
used by Aesir.

------------------------------------------------------------------------

## 36. Planner Pseudocode

``` text
function build_execution_plan(model, request, policy):

    devices = discover_devices()

    candidates = []

    for device in devices:
        for backend in device.backends:

            caps = probe(device, backend)

            if not caps.can_load(model):
                continue

            estimate = estimate_execution(
                model,
                request,
                device,
                backend
            )

            score = policy.score(estimate)

            candidates.append(
                SingleDevicePlan(
                    device,
                    backend,
                    score
                )
            )

    heterogeneous =
        generate_safe_heterogeneous_plans(
            model,
            devices,
            policy
        )

    candidates.extend(heterogeneous)

    remove_unhealthy(candidates)
    remove_memory_unsafe(candidates)

    return highest_score(candidates)
```

------------------------------------------------------------------------

## 37. Memory Planner Pseudocode

``` text
function calculate_safe_memory(device):

    if device.memory == DEDICATED_VRAM:
        return free_vram - gpu_reserve

    if device.memory in [SHARED_SYSTEM, UNIFIED_MEMORY]:
        return min(
            backend_reported_safe_limit,
            system_available - os_reserve,
            policy.shared_memory_limit
        )

    return conservative_default
```

------------------------------------------------------------------------

## 38. Cross-Device Cost Model

For devices A and B:

``` text
cost(A → B) =
    synchronization_latency
  + transfer_bytes / measured_bandwidth
  + backend_transition_cost
```

The planner should reject heterogeneous plans where:

``` text
transfer_cost > expected_compute_savings
```

This rule is crucial.

Using more processors is not automatically faster.

------------------------------------------------------------------------

## 39. Edge-Aware Scheduling

Aesir should recognize power and thermal limits.

For laptops and nomadic systems:

``` text
AC_POWER
BATTERY
THERMALLY_CONSTRAINED
LOW_POWER
```

Example:

``` text
On AC:
RTX + AMD + CPU

On battery:
AMD iGPU + CPU

Battery critical:
CPU efficiency mode
```

This can eventually integrate with Aesir's broader system policy.

------------------------------------------------------------------------

## 40. Thermal Adaptation

Sustained inference on laptops can throttle.

Aesir can eventually monitor:

``` text
GPU temperature
CPU temperature
clock reduction
power draw
tokens/sec trend
```

If:

``` text
performance decreases
while
temperature increases
```

the planner may choose a lower-power plan that produces greater
sustained throughput.

Peak benchmark speed should not be confused with sustained inference
speed.

------------------------------------------------------------------------

## 41. API Exposure

Useful endpoint:

``` text
GET /api/hardware
```

Example response:

``` json
{
  "devices": [
    {
      "id": "cuda:0",
      "vendor": "nvidia",
      "memory": "dedicated",
      "status": "healthy"
    },
    {
      "id": "vulkan:amd:0",
      "vendor": "amd",
      "memory": "shared",
      "status": "healthy"
    }
  ]
}
```

Another:

``` text
GET /api/compute/plan
```

could expose the active execution plan for diagnostics.

------------------------------------------------------------------------

## 42. CLI

Suggested commands:

``` bash
aesir hardware list
aesir hardware probe
aesir hardware benchmark
aesir hardware doctor
aesir compute plan MODEL
aesir compute explain MODEL
```

Especially useful:

``` bash
aesir compute explain model.gguf
```

Example:

``` text
Selected: CUDA + shared-memory fallback

Reason:
  CUDA device provides highest measured throughput.
  Model exceeds safe CUDA VRAM budget.
  AMD Vulkan device shares system memory.
  Estimated heterogeneous plan is 31% faster than CPU offload.

Rejected:
  AMD HIP
  Reason: device not supported by installed ROCm runtime.
```

A scheduler that explains itself will be dramatically easier to debug.

------------------------------------------------------------------------

## 43. Hardware Doctor

`aesir hardware doctor` should report:

``` text
✓ CPU backend
✓ CUDA backend
✓ NVIDIA device
✓ Vulkan runtime
✓ AMD Vulkan device
! ROCm installed
✗ AMD device unsupported by current ROCm configuration
✓ shared-memory probe
✓ 41.3 GiB safe model budget

Recommended execution:
CUDA + Vulkan heterogeneous
```

This should become one of Aesir's signature usability features.

------------------------------------------------------------------------

## 44. Implementation Roadmap

### Phase 1 -- Device Abstraction

Implement:

-   common device descriptor;
-   CPU discovery;
-   CUDA discovery;
-   AMD discovery;
-   Vulkan discovery;
-   memory-domain classification;
-   capability reporting.

**Milestone:** `aesir hardware list`

### Phase 2 -- Backend Health and Fallback

Implement:

-   backend probing;
-   health states;
-   fallback chains;
-   diagnostic explanations.

**Milestone:** unsupported accelerator never unnecessarily prevents CPU
inference.

### Phase 3 -- Memory Planner

Implement:

-   safe VRAM budgets;
-   shared-memory budgets;
-   system reserve;
-   KV estimates;
-   context-aware fitting.

**Milestone:** Aesir automatically determines whether a model safely
fits.

### Phase 4 -- AMD APU Optimization

Implement:

-   HIP capability probing;
-   Vulkan fallback;
-   shared-memory detection;
-   AMD APU benchmark profile;
-   CPU versus iGPU automatic comparison.

**Milestone:** integrated Radeon GPUs become first-class Aesir
accelerators.

### Phase 5 -- Heterogeneous Offload

Implement:

-   coarse layer placement;
-   transfer-cost measurements;
-   CUDA + CPU;
-   CUDA + AMD where backend architecture permits;
-   automatic split benchmarking.

**Milestone:** Aesir can exploit a fast low-VRAM GPU plus a larger
shared-memory accelerator.

### Phase 6 -- Apple Silicon

Implement:

-   Metal device discovery;
-   unified-memory recognition;
-   Metal/MLX backend integration;
-   Apple-specific memory planning.

**Milestone:** Aesir treats Apple unified memory natively rather than
emulating discrete VRAM assumptions.

### Phase 7 -- Workload Roles

Implement:

-   embeddings on secondary device;
-   reranking;
-   speech;
-   vision;
-   draft models;
-   background agent workloads.

**Milestone:** all useful accelerators can contribute even when a single
model should not be split.

### Phase 8 -- Adaptive Planner

Implement:

-   automatic plan search;
-   benchmark cache;
-   plan cache;
-   runtime pressure awareness;
-   power policies.

**Milestone:** Aesir empirically learns the best execution strategy for
a machine.

------------------------------------------------------------------------

## 45. Project Aesir Strategic Advantage

Most inference software begins from:

``` text
Choose a GPU.
Run the model on it.
Offload to CPU if necessary.
```

Aesir should instead begin from:

``` text
Discover the machine.
Understand its memory topology.
Understand every compute device.
Measure useful performance.
Understand the workload.
Construct an execution plan.
Continuously prefer the most effective resources.
```

This matters particularly for inexpensive hardware.

A system with:

``` text
8 GiB discrete VRAM
+ 64 GiB system RAM
+ integrated AMD GPU
+ capable CPU
```

should not be reduced conceptually to:

``` text
8 GiB GPU machine
```

It is a heterogeneous compute system with several memory and execution
resources.

Project Aesir should be designed accordingly.

------------------------------------------------------------------------

## 46. Architectural Principle

> **Aesir should optimize the computer the user actually owns, not the
> ideal accelerator configuration a framework developer expected them to
> own.**

That principle should guide the entire heterogeneous-compute subsystem.

------------------------------------------------------------------------

## 47. References and Upstream Concepts

This specification is informed by current capabilities and architectural
patterns in:

-   AMD ROCm/HIP unified and managed memory;
-   AMD's published ROCm hardware compatibility model;
-   Apple Metal unified-memory device capabilities;
-   Apple MLX unified-memory execution;
-   llama.cpp/GGML multi-backend and multi-device execution.

Useful upstream documentation:

-   AMD ROCm documentation: `https://rocm.docs.amd.com/`
-   Apple MLX unified memory:
    `https://ml-explore.github.io/mlx/build/html/usage/unified_memory.html`
-   Apple Metal `hasUnifiedMemory`:
    `https://developer.apple.com/documentation/metal/mtldevice/hasunifiedmemory`
-   llama.cpp: `https://github.com/ggml-org/llama.cpp`

------------------------------------------------------------------------

## 48. Final Summary

The proposed Aesir compute architecture consists of five central ideas:

1.  **Discover capabilities rather than hard-code vendors.**
2.  **Treat memory topology as seriously as compute throughput.**
3.  **Make shared and unified memory first-class execution
    environments.**
4.  **Use heterogeneous hardware when measured benefit exceeds
    communication cost.**
5.  **Learn the best execution plan empirically and cache it locally.**

The immediate practical target should be a machine containing a CPU, an
NVIDIA discrete GPU, and an AMD integrated/shared-memory GPU. That
configuration provides an excellent development platform for validating
Aesir's central premise: **small and unconventional hardware becomes
substantially more useful when the runtime understands the entire
machine rather than only its primary GPU.**
