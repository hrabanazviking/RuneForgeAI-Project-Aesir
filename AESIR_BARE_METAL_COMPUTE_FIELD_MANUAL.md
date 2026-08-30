# Project Aesir Bare-Metal Compute Hardware & Driver Field Manual

**Status:** Research / Architecture Reference  
**Project:** RuneForgeAI – Project Aesir  
**Suggested repository path:** `docs/hardware/AESIR_BARE_METAL_COMPUTE_FIELD_MANUAL.md`  
**Research date:** 2026-08-30  
**Scope:** CPUs, GPUs, integrated GPUs, NPUs, AI accelerators, memory architectures, kernel drivers, userspace runtimes, execution APIs, capability discovery, low-level scheduling, model-placement strategy, diagnostic commands, and backend integration guidance for Project Aesir.

---

# 0. Purpose

Project Aesir is intended to run local AI efficiently across unusually broad hardware. That requires more than a list of GPU brands.

Aesir needs to understand the complete **bare-metal execution stack**:

```text
Model / Graph / Tensor Operations
        ↓
Aesir execution planner
        ↓
Aesir backend abstraction
        ↓
Userspace runtime / compiler / inference library
        ↓
Kernel driver
        ↓
IOMMU / virtual memory / interconnect
        ↓
Physical compute architecture
        ↓
Physical memory hierarchy
```

A GPU, NPU, or CPU cannot be understood correctly by looking at only one layer.

For example:

```text
Physical device: AMD Radeon iGPU
Kernel driver:   amdgpu
Runtime option:  HIP / ROCm
Runtime option:  Vulkan
Runtime option:  OpenCL
Runtime option:  DirectML on Windows
LLM engine:      llama.cpp / GGML
Memory model:    shared system RAM
```

Each combination can expose different features and different performance.

The principal rule of this document is therefore:

> **Aesir must identify physical architecture, driver stack, runtime backend, memory topology, precision capabilities, and measured behavior independently.**

---

# 1. Core Hardware Identity Model

Aesir SHOULD represent every compute device with at least the following identity layers.

```yaml
device:
  physical:
    vendor:
    family:
    architecture:
    model:
    device_id:
    revision:
    integrated: true|false
    numa_node:
    pci_address:

  driver:
    kernel_driver:
    driver_version:
    firmware_version:
    userspace_driver:
    userspace_version:

  runtimes:
    - api:
      version:
      device_target:
      status:

  memory:
    model:
    total:
    free:
    safe_available:
    bandwidth:
    cpu_visible:
    coherent:
    unified_addressing:
    page_fault_migration:

  compute:
    scalar_isa:
    vector_isa:
    matrix_isa:
    subgroup_width:
    fp64:
    fp32:
    tf32:
    fp16:
    bf16:
    fp8:
    fp4:
    int8:
    int4:
    sparse_acceleration:

  topology:
    host_link:
    pcie_generation:
    pcie_width:
    peer_links:
    peer_access:
    iommu:
```

Never collapse these into a single string such as:

```text
"AMD GPU"
```

That loses almost everything Aesir needs.

---

# 2. Universal Capability Categories

Aesir should normalize vendor-specific hardware into common capability categories.

## 2.1 Compute

```text
SCALAR
SIMD_VECTOR
SIMT_GPU
MATRIX_TILE
TENSOR_CORE
NPU_GRAPH
DSP_VECTOR
SPECIALIZED_AI_ARRAY
```

## 2.2 Memory

```text
PRIVATE_REGISTER
LOCAL_SHARED
DEVICE_GLOBAL
DEDICATED_VRAM
HOST_PINNED
SYSTEM_RAM
SHARED_SYSTEM
UNIFIED_MEMORY
MANAGED_MEMORY
HOST_MAPPED
DEVICE_SRAM
HBM
REMOTE_MEMORY
```

## 2.3 Execution Model

```text
CPU_THREADS
GPU_GRID
GPU_SUBGROUP
COMMAND_QUEUE
GRAPH_EXECUTION
STATIC_NPU_GRAPH
DYNAMIC_NPU_GRAPH
STREAM_EXECUTION
DATAFLOW
```

## 2.4 Scheduling

```text
HOST_SCHEDULED
DEVICE_SCHEDULED
FIRMWARE_SCHEDULED
GRAPH_COMPILED
JIT_COMPILED
AOT_COMPILED
```

---

# 3. Universal Precision Matrix

Aesir must probe precision support rather than infer it from vendor names.

Useful formats:

| Type | Typical AI role |
|---|---|
| FP64 | scientific workloads, rarely useful for LLM inference |
| FP32 | compatibility / accumulation |
| TF32 | NVIDIA matrix acceleration with FP32-like range |
| BF16 | training/inference, large exponent range |
| FP16 | common GPU inference/training |
| FP8 | modern accelerator inference/training |
| FP6 | emerging specialized accelerator format |
| FP4 | emerging ultra-low precision |
| INT32 | accumulators, indexing |
| INT16 | quantized DSP/NPU operations |
| INT8 | common NPU/GPU quantization |
| UINT8 | vision / quantized inference |
| INT4 | LLM weight quantization |
| INT2 | experimental/extreme quantization |
| binary | specialized inference |

Aesir should store:

```text
supported
accelerated
emulated
unsupported
unknown
```

These are not equivalent.

A device can accept BF16 syntactically while executing it slowly through conversion.

---

# 4. CPU Architecture: x86-64

x86-64 remains an essential Aesir backend because CPU inference is universal and system RAM is often the largest memory pool.

## 4.1 Important SIMD generations

```text
SSE2       128-bit
SSE4.x     128-bit
AVX        256-bit
AVX2       256-bit integer + floating point
FMA        fused multiply-add
AVX-512    512-bit vector family
VNNI       neural-network integer dot-product instructions
BF16       BF16 acceleration extensions
FP16       native FP16 extensions on newer CPUs
AMX        matrix/tile accelerator extensions
```

Aesir MUST probe individual CPU features.

Linux:

```bash
lscpu
grep -m1 '^flags' /proc/cpuinfo
```

Useful programmatic mechanisms:

```text
CPUID
getauxval where applicable
compiler CPU feature APIs
```

Do not compile one universal binary requiring the newest ISA.

Recommended:

```text
baseline binary
+ runtime dispatch
+ architecture-specific kernels
```

---

# 5. Intel CPU AI Features

## 5.1 AVX2

Still one of the most important minimum targets for performant x86 LLM inference.

Useful for:

- quantized matrix kernels;
- dequantization;
- vectorized sampling;
- embedding operations;
- tokenizer helpers.

## 5.2 AVX-512

AVX-512 is a family of extensions, not one capability.

Important subfeatures can include:

```text
AVX512F
AVX512BW
AVX512DQ
AVX512VL
AVX512VNNI
AVX512_BF16
AVX512_FP16
```

Do not treat `AVX512F` as proof of every AVX-512 feature.

## 5.3 Intel DL Boost / VNNI

VNNI accelerates integer dot-product workloads used heavily by quantized inference.

Aesir should prefer kernels aware of:

```text
INT8 dot products
INT8 → INT32 accumulation
```

## 5.4 Intel AMX

Intel Advanced Matrix Extensions provide:

```text
tile registers
tile configuration
tile load/store
TMUL matrix operations
```

Intel documents AMX as a matrix acceleration architecture centered on tile registers and tile matrix multiply.

Important Aesir implications:

- AMX is not merely wider AVX.
- OS support is required to save/restore tile state.
- libraries such as oneDNN may provide a safer first integration path.
- AMX can be extremely useful for BF16 and INT8 inference where supported.
- capability detection must include OS enablement, not only CPUID.

Recommended Aesir abstraction:

```yaml
matrix_engine:
  type: AMX
  supported_types:
    - bf16
    - int8
  os_enabled: true
```

---

# 6. AMD Zen CPU AI Features

AMD Zen CPUs should be handled as their own performance family rather than assuming Intel tuning applies optimally.

Important generations for Aesir include modern:

```text
Zen 2
Zen 3
Zen 4
Zen 5
later Zen derivatives
```

## 6.1 AVX2

Widely useful across Ryzen and EPYC systems.

## 6.2 AVX-512

Zen 4 introduced AVX-512 capability using internal 256-bit execution paths for many operations.

Later Zen generations improve vector execution characteristics.

Aesir should care about **measured kernel throughput**, not only instruction width.

A CPU reporting AVX-512 does not guarantee identical AVX-512 performance to another CPU.

## 6.3 AOCL

AMD Optimizing CPU Libraries provide AMD-tuned math and numerical libraries.

Potential Aesir value:

```text
BLAS
FFT
math primitives
architecture-specific CPU optimization
```

Aesir should still retain portable CPU kernels because AOCL availability should not become mandatory.

---

# 7. ARM CPU Architecture

ARM is critical for:

```text
Raspberry Pi
Jetson
Android
Apple Silicon CPU cores
Ampere servers
embedded Linux
automotive hardware
```

## 7.1 NEON / Advanced SIMD

NEON is the most common SIMD baseline for modern ARM AI inference.

Characteristics:

```text
128-bit SIMD
vector arithmetic
integer operations
floating point
common optimized inference kernels
```

For Raspberry Pi-class hardware, excellent NEON kernels matter enormously.

## 7.2 SVE

Scalable Vector Extension introduces vector-length-agnostic programming.

Rather than compile assuming one vector width, code can adapt to implementation-defined widths.

Aesir should expose:

```yaml
vector_isa:
  name: SVE
  vector_bits: runtime_detected
```

## 7.3 SVE2

Extends SVE concepts with capabilities useful beyond HPC, including broader integer/DSP-style operations.

## 7.4 SME / SME2

Arm Scalable Matrix Extension introduces matrix-oriented capabilities layered on scalable vector concepts.

Potential future Aesir role:

```text
matrix multiply
AI kernels
high-efficiency CPU-side inference
```

Arm documentation explicitly positions SME as a matrix-processing extension building on SVE/SVE2 concepts.

---

# 8. RISC-V CPU Architecture

RISC-V is strategically relevant for future edge Aesir systems.

Important extensions:

```text
V       Vector extension
Zve*    embedded vector subsets
B       bit manipulation family
vendor matrix / AI extensions
```

RISC-V hardware is highly variable.

Therefore Aesir MUST use runtime hardware feature discovery rather than assuming all 64-bit RISC-V devices provide vectors.

Suggested state:

```text
RV64 scalar only
RV64 + V
RV64 + V + vendor AI extension
```

Aesir should initially target portable CPU execution and add vectorized backends as ecosystem maturity increases.

---

# 9. CPU Memory Topology

CPU performance depends on memory hierarchy as much as instruction capability.

Aesir should discover:

```text
L1 data cache
L2 cache
L3 / LLC
NUMA nodes
RAM channels
memory type
memory bandwidth
huge page availability
```

For LLM inference, large model weights often make token generation memory-bandwidth bound.

Thus:

```text
fast AVX-512 + slow memory
```

may lose to:

```text
slower vector ISA + much greater memory bandwidth
```

Aesir should benchmark representative matrix/dequant kernels.

---

# 10. NUMA-Aware CPU Execution

On multi-socket or chiplet-heavy systems:

```text
CPU ↔ local RAM
```

is often faster than:

```text
CPU ↔ remote NUMA RAM
```

Aesir should expose:

```text
NUMA node
CPU affinity
memory affinity
accelerator proximity
```

Linux discovery:

```bash
lscpu
numactl --hardware
ls /sys/devices/system/node/
```

Model memory should preferably be allocated close to the threads or accelerator consuming it.

---

# 11. NVIDIA GPU Architecture

NVIDIA GPU compatibility is strongly associated with **CUDA Compute Capability**.

Important architecture families encountered by Aesir may include:

```text
Pascal
Volta
Turing
Ampere
Ada
Hopper
Blackwell
Rubin-era hardware
Jetson variants
```

Do not schedule merely by marketing architecture.

Record:

```text
compute capability
SM version
VRAM
memory bandwidth
tensor-core formats
driver version
CUDA runtime version
```

Official CUDA documentation states that Compute Capability identifies supported features and hardware parameters.

---

# 12. NVIDIA Execution Hierarchy

Conceptually:

```text
Grid
 └── Thread Block
      └── Warp
           └── Thread
```

The traditional NVIDIA warp is 32 threads.

Important memory levels:

```text
registers
shared memory
L1
L2
global VRAM
constant memory
texture/cache paths
host pinned memory
managed memory
```

Aesir does not need to implement CUDA kernels immediately, but its capability model should preserve the information needed for optimized backends.

---

# 13. NVIDIA Tensor Cores

Tensor cores support architecture-dependent matrix formats.

Depending on generation, acceleration may include combinations of:

```text
FP16
BF16
TF32
INT8
INT4
FP8
newer low-precision formats
structured sparsity
```

Aesir must probe runtime/library support.

Do not infer a precision mode solely from “tensor cores present.”

Recommended representation:

```yaml
matrix_engine:
  type: nvidia_tensor_core
  formats:
    fp16: accelerated
    bf16: accelerated
    tf32: accelerated
    fp8: probe
    int8: accelerated
    int4: probe
```

---

# 14. NVIDIA Driver Stack

Linux stack typically resembles:

```text
Aesir
 ↓
CUDA runtime / driver API
 ↓
libcuda
 ↓
NVIDIA kernel driver
 ↓
GPU firmware / hardware
```

NVIDIA now provides official open GPU kernel module source for supported Linux GPUs, but userspace CUDA components remain part of the NVIDIA software stack.

Important distinction:

```text
NVIDIA open kernel modules ≠ Nouveau
```

Aesir diagnostics should identify the loaded driver.

Linux:

```bash
lspci -k
lsmod | grep -E 'nvidia|nouveau'
nvidia-smi
```

---

# 15. NVIDIA Driver / CUDA Versioning

CUDA compatibility has several versions:

```text
kernel driver version
CUDA driver API capability
installed CUDA toolkit
runtime library version
application-linked runtime
cuBLAS version
cuDNN version
```

Never report only:

```text
CUDA installed: yes
```

Instead:

```yaml
cuda:
  driver_supported_version:
  toolkit_version:
  runtime_version:
  cublas_version:
  cudnn_version:
```

A newer toolkit can require a sufficiently recent driver.

---

# 16. NVIDIA Management APIs

## 16.1 NVML / nvidia-smi

Useful data:

```text
GPU model
UUID
PCI address
VRAM use
temperature
power
clock
utilization
compute mode
MIG state where available
```

Example:

```bash
nvidia-smi
nvidia-smi -q
nvidia-smi --query-gpu=name,uuid,memory.total,memory.free,temperature.gpu,power.draw --format=csv
```

## 16.2 DCGM

For datacenter systems, NVIDIA DCGM provides deeper management and telemetry including topology and NVLink state.

Aesir can optionally integrate NVML first and DCGM later.

---

# 17. NVIDIA Memory Technologies

Possible NVIDIA memory/interconnect configurations:

```text
GDDR
HBM
PCIe
NVLink
NVSwitch
Unified Virtual Addressing
CUDA managed memory
pinned host memory
BAR1 / CPU-visible mappings
MIG partitions
```

Aesir should distinguish:

```text
physical VRAM
free VRAM
allocatable VRAM
CPU-visible aperture
managed memory capability
peer memory accessibility
```

---

# 18. NVIDIA MIG

Multi-Instance GPU can partition supported GPUs into isolated logical instances.

Aesir should treat each MIG instance as a distinct schedulable device rather than assuming access to the entire physical GPU.

Store:

```text
parent GPU
MIG UUID
instance memory
compute allocation
```

---

# 19. NVIDIA Jetson

Jetson devices differ fundamentally from desktop NVIDIA GPUs.

Typical Jetson architecture:

```text
ARM CPU
+
NVIDIA GPU
+
shared physical system memory
+
video / vision accelerators
```

Jetson Orin therefore combines:

```text
ARM64 CPU execution
CUDA GPU execution
shared memory constraints
embedded power envelopes
JetPack software stack
```

Important Aesir lesson:

> A Jetson GPU may use CUDA while its memory topology behaves much more like an integrated/unified-memory edge platform than a PCIe desktop GPU.

Aesir should not reuse desktop VRAM assumptions.

Probe:

```text
JetPack version
L4T version
CUDA version
TensorRT version
available RAM
power mode
GPU clocks
```

Useful commands often include:

```bash
cat /etc/nv_tegra_release
tegrastats
nvpmodel -q
```

when present.

---

# 20. AMD GPU Architectural Families

Important AMD families:

```text
GCN
RDNA
RDNA2
RDNA3
later RDNA generations
CDNA
CDNA2
CDNA3
CDNA4
```

Consumer GPUs and datacenter compute GPUs differ significantly.

Aesir should capture AMD's compiler target identifier:

```text
gfx900
gfx906
gfx908
gfx90a
gfx1030
gfx1100
gfx1101
gfx942
...
```

The exact `gfx*` target matters because compiled GPU kernels target specific instruction architecture behavior.

AMD HIP documentation explicitly notes that GFX targets encode instruction compatibility and scheduling characteristics.

---

# 21. AMD Wavefronts

AMD's SIMT grouping is a **wavefront**.

Historically many GCN/CDNA workloads use wave64, while RDNA architectures heavily use wave32 and can support architecture-dependent behavior.

Aesir should not hardcode:

```text
AMD subgroup = 64
```

Probe subgroup/wave capabilities through the active runtime.

This matters for:

```text
reductions
attention kernels
shuffles
matrix kernels
occupancy
```

---

# 22. AMD Linux Driver Stack

The Linux `amdgpu` kernel driver supports modern AMD GPU architectures including GCN/RDNA/CDNA families.

Typical stack:

```text
Aesir
 ↓
HIP / Vulkan / OpenCL userspace
 ↓
Mesa RADV or AMD ROCm userspace components
 ↓
amdgpu kernel driver
 ↓
GPU
```

Important point:

> One kernel driver can support several radically different userspace compute stacks.

Aesir must identify both.

Linux:

```bash
lspci -k
lsmod | grep amdgpu
cat /sys/module/amdgpu/version 2>/dev/null
```

---

# 23. AMD ROCm

ROCm is AMD's compute platform containing:

```text
HIP
compilers
math libraries
communication libraries
profilers
debuggers
system management
AI libraries
```

ROCm support is explicitly hardware and OS dependent.

Aesir MUST NOT assume:

```text
amdgpu loaded → ROCm supported
```

Instead:

```text
amdgpu kernel support
+
ROCm userspace installed
+
device recognized
+
gfx target supported
+
required libraries functional
```

must be evaluated independently.

---

# 24. HIP

HIP provides a CUDA-like C++ runtime and kernel programming model.

Advantages for Aesir:

- relatively familiar CUDA-like abstractions;
- useful for AMD native compute;
- supported by upstream AI frameworks;
- enables vendor-tuned matrix libraries.

Probe tools can include:

```bash
rocminfo
hipconfig
```

Store:

```yaml
hip:
  runtime_version:
  device_visible:
  gfx_target:
  unified_memory:
  managed_memory:
  peer_access:
```

---

# 25. AMD ROCm Hardware Support State

Aesir should use support categories:

```text
OFFICIALLY_SUPPORTED
SUPPORTED_WITH_LIMITATIONS
RUNTIME_DETECTED
COMMUNITY_WORKING
EXPERIMENTAL
UNSUPPORTED
UNKNOWN
```

This is especially important for:

```text
consumer Radeon
mobile Radeon
Ryzen APUs
older GCN hardware
new hardware preceding stable software support
```

The scheduler may prefer Vulkan over HIP when HIP is detected but unstable.

---

# 26. AMD Integrated GPUs / APUs

An AMD APU may provide:

```text
Zen CPU cores
Radeon iGPU
shared DDR/LPDDR memory
possibly XDNA NPU
```

This is extremely interesting for Aesir.

Potential architecture:

```text
SYSTEM RAM
 ├── CPU
 ├── Radeon GPU
 └── NPU
```

Not every device has equal access semantics, but the physical memory pool is much less isolated than discrete VRAM.

Aesir should collect:

```text
physical RAM
reserved UMA frame buffer
dynamic GPU-addressable memory
GTT
HMM availability
IOMMU state
memory bandwidth
number of memory channels
```

---

# 27. AMDGPU Memory Domains

Important concepts:

```text
VRAM
GTT
GART
GPU virtual memory
CPU-visible VRAM
buffer objects
page migration
HMM
```

On discrete GPUs:

```text
VRAM = fast dedicated memory
GTT = system-memory-backed GPU-addressable region
```

On APUs, topology differs and system memory plays a much larger role.

Linux AMDGPU exposes relevant driver information through DRM/sysfs interfaces.

---

# 28. AMD Unified / Managed Memory

HIP can expose managed/unified memory facilities on supported systems.

Behavior can depend on:

```text
GPU architecture
HMM
kernel version
XNACK support
ROCm version
IOMMU configuration
```

Do not treat managed memory as guaranteed zero-copy.

Aesir should benchmark:

```text
page migration cost
host access
GPU access
oversubscription behavior
```

---

# 29. AMD SMI

AMD System Management Interface is the preferred modern monitoring/management API.

Useful:

```bash
amd-smi
```

Potential metrics:

```text
device identity
power
temperature
clock
memory
utilization
PCIe state
```

Aesir should use AMD SMI where available, while retaining sysfs fallbacks.

---

# 30. AMD Matrix Hardware

Modern AMD compute architectures contain matrix acceleration capabilities whose exact supported datatypes vary by generation.

Possible formats across product generations include:

```text
FP64
FP32
FP16
BF16
INT8
FP8
low-precision AI formats on newer Instinct
```

Aesir should rely on:

```text
runtime query
library capability
gfx target
benchmark
```

rather than maintaining one permanent hardcoded table.

---

# 31. AMD Instinct / CDNA

Instinct GPUs are especially relevant for rented Aesir validation.

Characteristics can include:

```text
large HBM capacity
very high memory bandwidth
matrix cores
ROCm-first software stack
multi-GPU fabrics
server-focused management
```

Examples of compiler targets include:

```text
gfx90a  CDNA2 / MI200-class
gfx942  CDNA3 / MI300-class
```

For Aesir, datacenter AMD validation should test:

```text
HIP correctness
large model placement
BF16/FP16
low precision
multi-GPU
peer access
HBM capacity
```

---

# 32. Vulkan Compute

Vulkan is strategically important because it can provide GPU compute across:

```text
AMD
NVIDIA
Intel
Qualcomm
ARM Mali
other vendors
Windows
Linux
Android
```

Vulkan 1.x is an explicit low-level graphics and compute API.

Important capabilities:

```text
compute queues
storage buffers
device memory heaps
subgroups
FP16/int8 extensions
cooperative matrix extensions where available
timeline synchronization
device groups
external memory
```

Aesir should consider Vulkan a **portable GPU backend**, not merely a weak fallback.

---

# 33. Vulkan Device Discovery

Useful tool:

```bash
vulkaninfo
```

Important fields:

```text
deviceName
vendorID
deviceID
deviceType
apiVersion
driverVersion
memoryHeaps
memoryTypes
subgroup properties
shaderFloat16
shaderInt8
cooperative matrix extensions
```

Aesir should cache the extension set because Vulkan capability is extension-driven.

---

# 34. Vulkan Memory Model

Vulkan exposes explicit memory heaps and memory types.

Aesir should identify:

```text
DEVICE_LOCAL
HOST_VISIBLE
HOST_COHERENT
HOST_CACHED
```

On discrete GPUs:

```text
DEVICE_LOCAL
```

often means VRAM.

On integrated GPUs, the same physical RAM can appear through device-local and host-visible combinations.

This provides Aesir a way to recognize shared-memory-like topology without assuming it from vendor/model.

---

# 35. Vulkan Subgroups

Subgroups map to hardware SIMD/SIMT execution groups.

Subgroup size can vary.

Aesir should query:

```text
subgroup size
supported stages
supported subgroup operations
```

Do not assume:

```text
NVIDIA = 32
AMD = 64
Intel = fixed width
```

when writing portable kernels.

---

# 36. Vulkan Cooperative Matrix

Modern Vulkan extensions provide cooperative matrix functionality designed for matrix/tensor acceleration.

When available, this may expose vendor hardware analogous to:

```text
tensor cores
matrix cores
XMX-like units
```

Aesir should query, not infer.

Potential high-performance Vulkan LLM backend path:

```text
SPIR-V
+
subgroups
+
cooperative matrix
+
quantized kernels
```

---

# 37. OpenCL

OpenCL remains useful for broad and embedded portability.

OpenCL 3.x uses a feature-driven model where many capabilities are optional.

Important features:

```text
buffers
images
command queues
work groups
subgroups
SVM
SPIR-V support depending implementation
FP16 extensions
integer dot product extensions
```

Aesir should treat OpenCL feature detection as mandatory.

Tool:

```bash
clinfo
```

---

# 38. OpenCL Shared Virtual Memory

SVM categories include forms such as:

```text
coarse-grained buffer SVM
fine-grained buffer SVM
fine-grained system SVM
```

This can be useful on shared-memory devices.

However:

```text
SVM support != identical physical memory performance
```

Benchmarking still matters.

---

# 39. SYCL

SYCL provides modern C++ heterogeneous programming.

Important concepts:

```text
device discovery
queues
buffers/accessors
Unified Shared Memory
subgroups
backend interoperability
```

SYCL is especially relevant to Intel GPUs but can target other ecosystems through implementations/plugins.

Aesir should view SYCL as:

```text
portable execution abstraction
```

rather than:

```text
Intel-only API
```

---

# 40. SYCL Unified Shared Memory

USM categories commonly distinguish:

```text
host allocations
device allocations
shared allocations
```

Aesir should inspect actual device support.

A shared USM allocation does not imply every platform uses identical cache/coherence behavior.

---

# 41. Intel GPU Architecture

Intel GPU families relevant to Aesir include:

```text
integrated Xe graphics
Xe-LP
Xe-HPG / Arc
Xe-HPC / datacenter GPUs
newer Xe generations
```

Intel exposes several programming layers:

```text
Level Zero
SYCL / oneAPI
OpenCL
Vulkan
OpenVINO
DirectML on Windows
```

Aesir should enumerate each independently.

---

# 42. Intel Level Zero

Level Zero is a low-level API designed to expose accelerator hardware capabilities.

Concepts include:

```text
drivers
devices
contexts
command queues
command lists
memory
events
modules
kernels
device properties
```

For Aesir, Level Zero is valuable for precise Intel GPU discovery even when inference executes through a higher-level backend.

---

# 43. Intel Level Zero Sysman

Sysman exposes device management information including:

```text
PCI state
fabric links
frequency
throttling
power
energy
temperature
RAS
health
```

This is excellent input for Aesir's adaptive scheduler.

Potential use:

```text
if thermal throttling rises:
    reduce workload
    move auxiliary model
```

---

# 44. Intel GPU Execution

Intel GPU execution width and hardware organization vary by architecture.

Aesir should query:

```text
subgroup sizes
EU/Xe-core properties where exposed
local memory
global memory
XMX/matrix capability
supported precisions
```

Do not hardcode one SIMD width for all Intel GPUs.

---

# 45. Intel XMX / Matrix Engines

Modern Intel GPUs may provide matrix acceleration exposed through oneAPI/OpenVINO/library paths.

Aesir should record:

```text
matrix hardware present
supported datatype
backend exposing it
```

A Vulkan backend may expose different matrix capability than Level Zero/SYCL.

Again:

```text
physical capability
≠ runtime capability
```

---

# 46. Intel OpenVINO

OpenVINO is one of the most useful cross-device inference frameworks for Intel hardware.

Potential device targets:

```text
CPU
GPU
NPU
AUTO
MULTI
HETERO
```

For Aesir this is especially interesting because OpenVINO already performs graph-level device abstraction.

It can become:

```text
Aesir backend = OpenVINO
```

while Aesir retains higher-level routing and memory policy.

---

# 47. Intel NPU

Intel client NPUs are low-power AI accelerators integrated into Core Ultra-class systems.

The Linux ecosystem includes the Intel NPU driver, while OpenVINO exposes NPU inference support.

Important characteristics:

```text
low power
graph-oriented
operator support constraints
compiled models
device-specific backend
```

NPUs should not be treated like general-purpose GPUs.

---

# 48. Intel NPU Scheduling Rules

Aesir should prefer Intel NPU for workloads such as:

```text
embeddings
small vision models
speech models
background classifiers
small transformer components
```

only when operator support and model compilation succeed.

Large autoregressive LLM generation may or may not be the ideal use depending on hardware generation and runtime support.

Aesir should test rather than assume.

---

# 49. AMD XDNA NPU / Ryzen AI

Ryzen AI systems can contain:

```text
Zen CPU
Radeon iGPU
XDNA NPU
```

AMD Ryzen AI software provides tools and runtimes targeting the NPU and integrated GPU.

Current software paths include ONNX-oriented execution and AMD runtime components.

Linux support involves XDNA driver/XRT infrastructure.

Aesir must record:

```text
XDNA generation
kernel driver
firmware
XRT/plugin version
Ryzen AI runtime version
supported graph formats
quantization requirements
```

---

# 50. XDNA Linux Stack

Conceptually:

```text
Aesir
 ↓
ONNX / runtime integration
 ↓
XRT / XDNA plugin
 ↓
XDNA kernel driver
 ↓
NPU firmware
 ↓
XDNA hardware
```

AMD's open XDNA driver project explicitly supports XRT on XDNA devices.

Aesir should check device node / driver presence separately from model runtime availability.

---

# 51. Apple Silicon Architecture

Apple Silicon combines:

```text
ARM CPU cores
Apple GPU
Apple Neural Engine
shared unified memory
media engines
system-level accelerators
```

This is a fundamentally heterogeneous SoC.

For Aesir, it should never be represented as:

```text
CPU + GPU with copied VRAM
```

The unified memory architecture is central.

---

# 52. Apple Unified Memory

Apple MLX is explicitly designed around unified memory.

CPU and GPU can operate on arrays in the same unified memory system without the conventional explicit host↔VRAM copy model.

Aesir should record:

```text
physical unified memory
memory pressure
GPU-recommended working set where available
wired memory
swap pressure
```

Avoid allocating nearly all physical memory simply because the GPU can address it.

---

# 53. Apple Metal

Metal is Apple's low-level graphics/compute API.

Relevant features:

```text
compute command encoders
buffers
textures
threadgroups
SIMD groups
Metal Performance Shaders
GPU family feature sets
unified memory property
```

Aesir Metal integration can be:

```text
direct kernels
GGML Metal backend
MLX backend
MPS-backed framework
```

---

# 54. Apple MLX

MLX is especially interesting for Project Aesir because it is designed specifically for Apple Silicon.

Key Aesir-relevant concepts:

```text
unified memory
CPU/GPU arrays
lazy execution
NumPy-like API
C++ API
machine-learning primitives
distributed capabilities
```

Aesir should consider MLX a first-class Apple backend rather than forcing every Mac through a generic API.

---

# 55. Apple MPS

Metal Performance Shaders provides optimized compute primitives.

PyTorch's MPS backend uses Metal/MPS to accelerate operations.

Potential role:

```text
framework compatibility backend
```

but Aesir should prefer lower-overhead/native LLM paths when available.

---

# 56. Apple Neural Engine

The Apple Neural Engine is primarily accessed through higher-level Apple frameworks such as Core ML.

Important constraint:

> Apple does not expose the ANE as a CUDA-style general compute GPU.

Therefore Aesir's ANE strategy should be graph/runtime-based.

Possible path:

```text
Aesir
 ↓
Core ML model
 ↓
Core ML compute-unit selection
 ↓
ANE / GPU / CPU as chosen by framework
```

---

# 57. Core ML

Core ML can schedule compatible model operations across Apple compute resources.

Aesir should expose ANE use as:

```text
graph backend
```

rather than a raw device kernel backend.

Useful workloads:

```text
vision
speech
embeddings
compact neural networks
converted transformer components
```

---

# 58. Qualcomm Snapdragon Compute

Modern Snapdragon platforms can include:

```text
Oryon or ARM CPU
Adreno GPU
Hexagon NPU/DSP
shared LPDDR memory
```

This makes them excellent future Aesir edge targets.

---

# 59. Qualcomm Hexagon NPU / DSP

Hexagon provides AI acceleration with specialized tensor/vector capabilities.

Qualcomm AI Engine Direct / QNN is a principal software route.

Important components can include:

```text
QNN APIs
Hexagon backend
HTP
DSP/vector hardware
model conversion / graph compilation
```

Aesir should treat Hexagon as a graph accelerator rather than a general GPU.

---

# 60. Qualcomm Adreno GPU

Potential APIs:

```text
Vulkan
OpenCL on supported stacks
Android NNAPI-mediated paths
DirectML on Windows Snapdragon systems where supported by platform
```

For Aesir, Vulkan/OpenCL can provide a more portable route than vendor-private GPU APIs.

---

# 61. Windows on Snapdragon

Windows Snapdragon systems are particularly interesting because one machine may expose:

```text
ARM64 CPU
Adreno DirectX 12 GPU
Hexagon NPU
```

Possible Aesir backends:

```text
CPU ARM64
DirectML
ONNX Runtime QNN EP
OpenCL/Vulkan where available
```

Qualcomm has demonstrated local AI application acceleration through its NPU software stack.

---

# 62. MediaTek NeuroPilot

MediaTek SoCs commonly combine:

```text
ARM CPU
Mali/Immortalis GPU depending platform
MediaTek APU
shared memory
```

NeuroPilot provides MediaTek's AI software environment.

Aesir strategy:

```text
prefer standard portable runtime
fall back / enhance with NeuroPilot where available
```

Store:

```text
SoC model
APU generation
NeuroPilot SDK/runtime version
supported model format
operator support
```

---

# 63. ARM Mali / Immortalis GPUs

These GPUs are common in Android and embedded systems.

Possible compute paths:

```text
Vulkan
OpenCL depending vendor driver
Android NNAPI indirectly
```

Aesir should not require desktop-style GPU runtimes.

Probe:

```text
Vulkan device
OpenCL platform
memory heap model
subgroup capabilities
```

---

# 64. Rockchip NPUs

Rockchip SoCs such as RK3588-class hardware include dedicated NPUs.

The modern software stack includes:

```text
RKNPU kernel driver
RKNN runtime
RKNN Toolkit2
RKLLM Runtime
```

Rockchip's RKNN LLM ecosystem is directly relevant to Aesir.

---

# 65. Rockchip Driver Stack

Conceptually:

```text
Aesir
 ↓
RKLLM / RKNN Runtime
 ↓
librknnrt
 ↓
RKNPU kernel driver
 ↓
Rockchip NPU
```

The RKNPU kernel driver handles communication with the NPU hardware.

Aesir should record:

```text
NPU core count
driver version
runtime version
firmware
RKNN model version
```

Operator/model compatibility should be treated as graph capability.

---

# 66. Hailo Accelerators

Hailo edge AI devices use the Hailo software stack.

Important components:

```text
HailoRT runtime
PCIe driver
firmware
compiler / model conversion tools
device CLI
```

HailoRT provides device management, inference, statistics, and event access.

Aesir should treat Hailo devices as specialized graph accelerators.

Good candidates:

```text
vision
classification
detection
embeddings if supported
auxiliary models
```

---

# 67. Google Coral / Edge TPU

Coral historically centered around Edge TPU inference.

The ecosystem is evolving toward standards-based tooling and MLIR-based compilation.

Aesir should distinguish:

```text
legacy Edge TPU runtime path
newer Coral platform/toolchain
```

Do not assume an arbitrary transformer can be placed on an Edge TPU.

Model conversion and operator support are fundamental constraints.

---

# 68. Google Cloud TPU

Cloud TPU is not bare-metal consumer hardware, but it belongs in Aesir's broad accelerator abstraction.

Important software concepts:

```text
XLA
PJRT
JAX
PyTorch/XLA
TensorFlow
distributed TPU topology
HBM
matrix units
```

Aesir should not try to emulate CUDA semantics.

Instead implement a graph/compiler backend through:

```text
PJRT / XLA-aware execution
```

for any future remote backend.

---

# 69. PJRT

PJRT is an increasingly important interface for framework-to-accelerator integration.

Aesir should monitor PJRT because it provides a possible abstraction for accelerators using XLA ecosystems.

Potential future backend:

```text
AESIR_BACKEND_PJRT
```

---

# 70. Intel Gaudi

Gaudi accelerators are dedicated AI training/inference devices.

Software stack:

```text
PyTorch integrations
SynapseAI
graph compiler
runtime
TPC kernel library
firmware
driver
```

Gaudi should be modeled separately from Intel GPUs.

Aesir device type:

```text
AI_ACCELERATOR
```

not:

```text
GPU
```

---

# 71. Huawei Ascend

Huawei Ascend hardware uses the CANN software ecosystem.

Stack concepts include:

```text
Ascend driver
firmware
CANN
operator development
framework adapters
MindSpore / PyTorch integrations
```

Modern Ascend systems support multiple AI datatypes depending on accelerator generation.

Aesir integration should be graph/runtime-based.

Possible backend:

```text
AESIR_BACKEND_CANN
```

---

# 72. NXP eIQ / Neutron / Ethos-U

NXP edge processors can expose several accelerator families.

Examples include:

```text
Arm Ethos-U
NXP Neutron NPU
GPU acceleration
CPU acceleration
```

eIQ provides model-development/deployment infrastructure.

These devices are highly operator-constrained compared with GPUs.

Aesir should store an operator-coverage profile.

---

# 73. Arm Ethos-U

Ethos-U targets microcontroller and embedded inference.

Typical properties:

```text
small power envelope
compiled neural networks
tight SRAM / DRAM constraints
operator restrictions
microNPU execution
```

This is not an LLM-first accelerator.

Aesir could use it for:

```text
wake word
small embeddings
classification
sensor models
simple vision
```

while leaving the main LLM on CPU/GPU.

---

# 74. AWS Inferentia / Trainium

Although remote/cloud devices, these demonstrate another accelerator class:

```text
graph compiler
Neuron SDK
device runtime
specialized matrix hardware
distributed execution
```

Potential future Aesir remote backend:

```text
Aesir node → Neuron-based service
```

Aesir should avoid coupling its local hardware abstraction to CUDA semantics so accelerators like these remain possible.

---

# 75. DirectML

DirectML provides a low-level ML abstraction over DirectX 12 compatible GPUs on Windows.

This is strategically valuable because one backend can address GPUs from:

```text
AMD
Intel
NVIDIA
Qualcomm
other DirectX 12 vendors
```

It is particularly useful when vendor-specific compute runtimes are unavailable.

Aesir Windows backend hierarchy might be:

```text
vendor-native backend when excellent
DirectML portable backend
CPU fallback
```

---

# 76. DirectML Caveat

DirectML provides broad hardware compatibility, but it does not automatically mean:

```text
best possible LLM performance
```

Vendor-native kernels may outperform it.

Therefore:

```text
DirectML = broad compatibility
CUDA/HIP/etc. = possible specialized performance
```

Aesir should benchmark both when multiple backends expose the same device.

---

# 77. ONNX Runtime Execution Providers

ONNX Runtime provides an extensible Execution Provider abstraction.

Potential EPs relevant to Aesir include:

```text
CPU
CUDA
TensorRT
OpenVINO
DirectML
CoreML
QNN
other vendor EPs
```

This makes ONNX Runtime attractive for:

```text
embeddings
rerankers
vision
speech
NPU workloads
auxiliary neural networks
```

Aesir's main autoregressive GGUF backend does not need to be ONNX to benefit.

---

# 78. Aesir Multi-Runtime Strategy

Aesir should not force every workload through one runtime.

Recommended:

```text
LLM:
    GGML/llama.cpp-derived backend

Embeddings:
    GGML or ONNX Runtime

Speech:
    specialized native backend / ONNX

Vision:
    ONNX / vendor NPU backend

Reranker:
    ONNX / GPU / NPU

TTS:
    native model runtime

Agent logic:
    CPU
```

This lets Aesir exploit NPUs without contorting the main LLM engine.

---

# 79. llama.cpp / GGML as a Foundation

Current llama.cpp supports a very broad backend ecosystem including:

```text
CPU
CUDA
HIP
Vulkan
Metal
SYCL
OpenCL
OpenVINO
CANN
MUSA
Arm KleidiAI
ZenDNN
RPC
```

and supports CPU+GPU hybrid inference.

This is extremely relevant to Aesir.

Aesir should use GGML/llama.cpp as:

```text
low-level inference machinery
```

while adding:

```text
capability intelligence
heterogeneous policy
memory planning
hardware discovery
backend scoring
model routing
persistent optimization profiles
```

---

# 80. Backend versus Physical Device

One physical device may produce several backend candidates.

Example:

```yaml
physical_device: AMD_RADEON_780M

candidates:
  - backend: HIP
    health: experimental
  - backend: Vulkan
    health: healthy
  - backend: OpenCL
    health: healthy
```

Aesir chooses a **device/backend pair**, not merely a device.

This is a critical architectural distinction.

---

# 81. Driver Layer Taxonomy

Aesir should classify drivers:

```text
KERNEL_DRIVER
USERSPACE_DRIVER
RUNTIME
COMPILER
MATH_LIBRARY
MODEL_RUNTIME
MANAGEMENT_API
FIRMWARE
```

Example NVIDIA:

```text
kernel driver      nvidia
userspace driver   libcuda
runtime            CUDA Runtime
compiler           nvcc / NVRTC
math               cuBLAS
model runtime      TensorRT / GGML CUDA
management         NVML
firmware           device firmware
```

Example AMD:

```text
kernel driver      amdgpu
userspace driver   ROCr/Mesa depending backend
runtime            HIP / Vulkan
compiler           clang/LLVM AMDGPU
math               rocBLAS
model runtime      GGML HIP
management         AMD SMI
firmware           linux-firmware blobs
```

---

# 82. Linux Universal Hardware Discovery

Recommended commands:

```bash
uname -a
lscpu
lspci -nnk
lsusb
lsmod
free -h
numactl --hardware
```

DRM devices:

```bash
ls -l /dev/dri/
ls -l /sys/class/drm/
```

Accelerators may also expose:

```text
/dev/accel/*
vendor device nodes
PCIe character devices
```

Aesir should enumerate by APIs first and sysfs second.

---

# 83. Linux PCIe Topology

Useful:

```bash
lspci -tv
lspci -vv
```

Aesir should capture:

```text
PCIe generation
link width
current link speed
maximum link speed
NUMA node
IOMMU group
```

Why?

A GPU capable of 1 TB/s internal bandwidth can still suffer when frequently exchanging tensors through a slow PCIe link.

---

# 84. PCIe Transfer Model

Approximate effective cross-device cost:

```text
transfer_time =
    latency
  + bytes / effective_bandwidth
```

But Aesir should measure, because actual bandwidth depends on:

```text
PCIe generation
lane width
root complex
NUMA location
IOMMU
pinned memory
copy engine
concurrent traffic
power state
```

---

# 85. PCIe Generations

Theoretical per-lane signaling grows by generation, but Aesir should never schedule from theoretical marketing values alone.

Record:

```text
negotiated link generation
negotiated width
measured H2D
measured D2H
measured D2D
```

---

# 86. Peer-to-Peer GPU Access

Possible technologies:

```text
CUDA P2P
NVLink
AMD XGMI
PCIe peer access
Level Zero peer access
Vulkan device groups / external memory
```

For every pair `(A,B)` Aesir should store:

```yaml
peer:
  accessible:
  direct:
  bandwidth:
  latency:
  atomics:
```

Multi-GPU scheduling should be topology-aware.

---

# 87. IOMMU

The IOMMU affects DMA and memory mapping.

Aesir generally should not alter system IOMMU configuration automatically.

But diagnostics may record:

```text
enabled
disabled
passthrough mode
IOMMU group
```

because some accelerator/runtime behavior can depend on it.

---

# 88. Unified Virtual Addressing versus Unified Physical Memory

These concepts must not be confused.

## Unified virtual addressing

CPU and GPU can use a coordinated virtual address space.

## Unified physical memory

CPU and GPU share the same physical memory pool.

A discrete CUDA GPU may have UVA while still possessing separate VRAM.

Apple Silicon has a unified physical memory architecture.

AMD APUs use shared system memory but runtime semantics vary.

Aesir should store both independently.

---

# 89. Zero Copy

“Zero copy” can mean several different things:

```text
host memory mapped into device address space
shared physical memory
pinned memory
coherent shared memory
unified allocation
driver-managed migration
```

Aesir should not expose one boolean called:

```text
zero_copy = true
```

Better:

```yaml
memory_access:
  same_physical_memory:
  host_visible:
  device_visible:
  coherent:
  migration_required:
  page_fault_supported:
```

---

# 90. Memory Bandwidth as a Primary LLM Metric

Autoregressive token generation frequently behaves as a memory-bandwidth-heavy workload.

Approximate intuition:

```text
tokens/sec ∝ useful memory bandwidth / bytes read per token
```

This is not exact, but it explains why:

```text
large model + slow DDR
```

can be much slower than:

```text
same model + HBM
```

even when both technically fit.

Aesir should benchmark effective model-kernel bandwidth.

---

# 91. Shared Memory Capacity versus Speed

Large shared memory creates **capacity**, not automatically high throughput.

Example:

```text
64 GiB DDR5 shared with iGPU
```

may permit a much larger model than:

```text
8 GiB GDDR6 discrete GPU
```

but the discrete GPU may be far faster for the subset that fits.

This creates the fundamental Aesir optimization problem:

```text
capacity tier
+
bandwidth tier
+
compute tier
```

must be scheduled jointly.

---

# 92. Quantization and Hardware

Quantization support should be separated into:

```text
storage format
dequantization format
matrix execution format
accumulator format
```

Example:

```text
weights: Q4_K
dequantize: FP16
matrix engine: FP16
accumulate: FP32
```

or:

```text
weights: INT8
matrix engine: INT8
accumulate: INT32
```

Do not equate “4-bit model” with native INT4 matrix hardware.

---

# 93. Hardware-Native Low Precision

Aesir should ask:

```text
Can the backend consume native quantized weights?
Does it dequantize first?
Does the hardware accelerate the dequantized datatype?
Are matrix instructions used?
```

This can explain massive performance differences between backends on identical hardware.

---

# 94. KV Cache Hardware Placement

KV cache may use:

```text
FP16
BF16
FP8
quantized formats
```

depending engine/backend.

Aesir should optimize KV separately from weights.

Possible plans:

```text
weights in VRAM
KV in VRAM
```

or:

```text
weights split VRAM/system
KV in system shared memory
```

or:

```text
model on GPU
KV partially offloaded
```

---

# 95. Context Length and Memory Planning

A model that fits at 4K context may fail at 128K.

Plan key MUST include:

```text
model
quantization
context
batch
parallel sequences
KV format
```

Hardware profile alone is insufficient.

---

# 96. Memory Safety Reserve

Recommended concept:

```text
safe_allocatable =
    reported_available
  - fixed_reserve
  - dynamic_reserve
  - runtime_overhead
  - fragmentation_margin
```

For unified/shared memory:

```text
system survival reserve
```

must also be maintained.

Aesir should prioritize avoiding host swapping/OOM over squeezing in one more layer.

---

# 97. Linux Swap and Unified Memory

On shared-memory systems, excessive allocation can trigger swap.

This can catastrophically reduce inference performance.

Aesir should observe:

```text
MemAvailable
swap use
major page faults
PSI memory pressure
```

Linux sources:

```text
/proc/meminfo
/proc/vmstat
/proc/pressure/memory
```

---

# 98. Memory Pressure Feedback

Aesir should maintain pressure state:

```text
GREEN
YELLOW
ORANGE
RED
```

Example:

```text
GREEN:
  >20% safe headroom

YELLOW:
  reduce caches

ORANGE:
  stop optional models

RED:
  unload secondary models / replan
```

Thresholds should be configurable and empirically tuned.

---

# 99. Thermal / Power Telemetry

Useful metrics:

```text
temperature
junction temperature
power draw
clock
throttling state
fan
energy consumed
```

Potential APIs:

```text
NVIDIA NVML
AMD SMI
Intel Sysman
Linux hwmon
Apple system metrics where accessible
embedded SoC sysfs
```

Power matters strongly for Aesir's edge/nomadic use cases.

---

# 100. Sustained Performance

Aesir should distinguish:

```text
cold benchmark
30-second throughput
5-minute sustained throughput
battery throughput
thermal-throttled throughput
```

A laptop GPU that wins a 5-second benchmark may lose after heat saturation.

---

# 101. NPU Architecture Principle

NPUs usually differ from GPUs in several ways:

```text
less general programming
graph compilation
strict operator support
preferred tensor layouts
fixed quantization requirements
small local SRAM
DMA-managed external memory
firmware scheduling
```

Therefore Aesir needs a **graph compatibility compiler stage**.

---

# 102. NPU Capability Representation

Recommended:

```yaml
npu:
  graph_formats:
    - onnx
  supported_ops_hash:
  dynamic_shapes:
  max_tensor_rank:
  quantization:
    int8: true
    int4: false
  local_sram:
  external_memory:
  compiler_version:
  firmware_version:
```

Operator support can change with runtime version.

---

# 103. NPU Compilation Cache

NPU models often require expensive AOT compilation.

Aesir should cache compiled artifacts keyed by:

```text
model hash
device architecture
compiler version
firmware version
quantization
shape profile
```

Never reuse compiled binaries blindly across incompatible device generations.

---

# 104. NPU Fallback Partitioning

For partially supported graphs:

```text
supported subgraph → NPU
unsupported ops     → CPU/GPU
```

This can be useful, but boundary transfer costs may dominate.

Aesir should measure whole-model latency, not count accelerated operations.

---

# 105. Aesir Hardware Backend Classes

Suggested enum:

```text
CPU_NATIVE
GPU_CUDA
GPU_HIP
GPU_VULKAN
GPU_OPENCL
GPU_LEVEL_ZERO
GPU_SYCL
GPU_METAL
GPU_DIRECTML
APPLE_MLX
NPU_OPENVINO
NPU_QNN
NPU_XDNA
NPU_COREML
NPU_RKNN
NPU_HAILO
NPU_NEUROPILOT
NPU_EIQ
ACCEL_GAUDI
ACCEL_CANN
ACCEL_PJRT
REMOTE_RPC
```

---

# 106. Device Capability Fingerprint

Create stable fingerprint from:

```text
vendor/device PCI ID
architecture
revision
driver version
firmware version
runtime backend/version
memory topology
important feature bits
```

Do not use marketing name alone.

---

# 107. Hardware Benchmark Fingerprint

Benchmark cache key:

```text
device fingerprint
+
backend
+
kernel implementation version
+
model quantization family
+
power profile
```

This prevents stale benchmark decisions after driver/backend upgrades.

---

# 108. Correctness Probe

Every backend/device pair must pass:

```text
allocation
buffer copy
basic matrix operation
synchronization
deterministic reference comparison
large allocation
repeated allocation/free
long-running kernel
```

before receiving:

```text
HEALTHY
```

---

# 109. Backend Health State

Recommended:

```text
NOT_PROBED
AVAILABLE
HEALTHY
DEGRADED
EXPERIMENTAL
UNSTABLE
BROKEN
UNSUPPORTED
DISABLED_BY_USER
```

This is especially useful for marginal ROCm/Vulkan/OpenCL hardware.

---

# 110. Device Score

Conceptual:

```text
score =
    compatibility_score
  + throughput_score
  + capacity_score
  + bandwidth_score
  + energy_efficiency_score
  + stability_score
  + topology_score
  - transfer_cost
  - memory_pressure_cost
  - thermal_cost
```

Weights depend on policy.

---

# 111. Aesir Policy Profiles

```text
FASTEST
LOWEST_LATENCY
MAX_THROUGHPUT
LARGEST_MODEL
LOWEST_POWER
QUIET
BATTERY
BALANCED
MAX_COMPATIBILITY
MANUAL
```

`QUIET` can deliberately avoid hot discrete GPUs.

---

# 112. Heterogeneous Role Scheduling

Rather than splitting every model:

```text
Primary LLM       → fast GPU
Draft LLM         → integrated GPU
Embeddings        → NPU
Reranker          → NPU/iGPU
TTS               → CPU/NPU
STT               → secondary GPU/NPU
Database          → CPU
Tokenizer         → CPU
```

This is often easier and faster than cross-vendor tensor splitting.

---

# 113. Cross-Vendor Layer Splitting

If supported by the underlying engine:

```text
Layer group A → CUDA
Layer group B → HIP/Vulkan
```

Aesir must evaluate transfer boundaries.

Initial rule:

> Prefer the fewest cross-device boundaries possible.

One large split is generally safer than alternating devices layer-by-layer.

---

# 114. Speculative Decoding Hardware Mapping

Excellent heterogeneous use:

```text
small draft model → iGPU/NPU/CPU
large target      → dGPU
```

Measure:

```text
draft tokens/sec
acceptance rate
verification cost
synchronization cost
net tokens/sec
```

Enable only if net improvement is positive.

---

# 115. Mixture-of-Experts Mapping

Potential future plan:

```text
router              → fast device
hot experts          → fast VRAM
warm experts         → shared memory
cold experts         → system RAM / second GPU
```

Track expert frequency and migrate over time.

This is a natural application of Aesir's memory-tier architecture.

---

# 116. Hardware Discovery API Design

Suggested internal interfaces:

```text
discover_physical_devices()
discover_kernel_drivers()
discover_runtime_backends()
associate_backends_to_devices()
probe_memory_topology()
probe_compute_features()
probe_management_interfaces()
benchmark_device_backend_pair()
```

This ordering matters.

---

# 117. Device Association Problem

One device may be described differently by:

```text
PCI
CUDA
Vulkan
OpenCL
HIP
SYCL
DirectML
```

Aesir needs to unify them.

Preferred keys:

```text
PCI domain:bus:device.function
vendor/device ID
UUID where vendor provides stable UUID
LUID on Windows
registry/device identifiers
```

Use heuristics only as fallback.

---

# 118. Linux Device Association

Possible identifiers:

```text
PCI BDF
DRM render node
sysfs path
vendor/device ID
CUDA UUID
ROCm unique ID
Vulkan PCI extensions
```

Mapping example:

```text
0000:01:00.0
 ↔ /dev/dri/renderD128
 ↔ CUDA device 0
 ↔ Vulkan physical device 1
```

---

# 119. Windows Device Association

Useful Windows concepts:

```text
DXGI adapter LUID
PCI hardware ID
DirectML device
vendor runtime device
WMI/PnP identity
```

Aesir should use adapter LUID where APIs expose it.

---

# 120. macOS Device Association

Apple Silicon normally presents one integrated GPU complex.

Useful APIs can expose Metal devices and unified-memory properties.

Aesir should still distinguish:

```text
CPU
GPU
ANE/CoreML
```

as execution resources even though they share the SoC.

---

# 121. Driver Version Is Part of Performance

A backend may change dramatically with:

```text
kernel driver
userspace runtime
compiler
shader compiler
math library
firmware
```

Aesir plan cache MUST invalidate after meaningful version change.

---

# 122. Firmware Matters

NPUs and modern GPUs often depend heavily on firmware.

Store when accessible:

```text
firmware version
microcode version
device boot firmware
```

For specialized accelerators, runtime/firmware mismatch can prevent model execution.

---

# 123. Kernel Driver versus Runtime Support

Example:

```text
Linux recognizes GPU
```

means only:

```text
kernel driver attached
```

It does not prove:

```text
ROCm works
CUDA works
Vulkan compute works
LLM backend works
```

Aesir diagnostics should show each layer.

---

# 124. Example Aesir Hardware Doctor Output

```text
PHYSICAL DEVICE
  AMD Radeon 780M
  PCI: 0000:65:00.0
  Architecture: RDNA3
  Memory: shared system

KERNEL
  amdgpu: loaded
  status: healthy

HIP
  runtime: installed
  gfx target: detected
  model test: failed
  state: DEGRADED

VULKAN
  driver: RADV
  compute: available
  FP16: yes
  subgroup: supported
  model test: passed
  state: HEALTHY

OPENCL
  platform: available
  model test: not run

SELECTED
  Vulkan

REASON
  Vulkan passed correctness and benchmark tests.
  HIP runtime detected but failed model validation.
```

---

# 125. Example NVIDIA + AMD Laptop Plan

```text
CPU:
  64 GiB system RAM
  AVX2/AVX-512 capability as detected

NVIDIA dGPU:
  8 GiB GDDR
  CUDA
  very high bandwidth

AMD iGPU:
  shared system RAM
  Vulkan/HIP candidate

PLAN:
  primary transformer layers → NVIDIA
  overflow layers            → AMD shared backend
  KV cache                    → shared/system pool if supported
  tokenizer/sampling          → CPU
  embeddings                  → AMD iGPU
```

Then benchmark against:

```text
CUDA + CPU
CUDA + AMD
AMD only
CPU only
```

Choose empirically.

---

# 126. Hardware Classes Aesir Should Test

## Tier A: CPU

```text
x86 SSE/AVX2
x86 AVX-512
Intel AMX
AMD Zen
ARM NEON
ARM SVE
ARM SME
RISC-V Vector
```

## Tier B: Consumer GPU

```text
NVIDIA GeForce
AMD Radeon
Intel Arc
Apple GPU
Qualcomm Adreno
Mali/Immortalis
```

## Tier C: Datacenter GPU / accelerator

```text
NVIDIA datacenter
AMD Instinct
Intel Gaudi
Intel datacenter GPU
Huawei Ascend
Google TPU
```

## Tier D: NPU

```text
AMD XDNA
Intel NPU
Apple ANE
Qualcomm Hexagon
Rockchip RKNPU
Hailo
NXP Neutron/Ethos-U
MediaTek APU
Coral
```

---

# 127. Recommended Aesir Backend Priority by Platform

These are defaults only.

## Linux NVIDIA

```text
CUDA
Vulkan
CPU
```

## Linux AMD officially ROCm-supported

```text
HIP
Vulkan
OpenCL
CPU
```

## Linux AMD unsupported/marginal ROCm

```text
Vulkan
HIP experimental
OpenCL
CPU
```

## Windows generic GPU

```text
vendor native backend
DirectML
Vulkan
CPU
```

## Intel Linux

```text
SYCL/Level Zero or OpenVINO
Vulkan
OpenCL
CPU
```

## Apple Silicon

```text
MLX / Metal
Core ML for compatible auxiliary graphs
CPU
```

## Android Qualcomm

```text
QNN for compatible NPU workloads
Vulkan/OpenCL GPU
CPU
```

## Rockchip

```text
RKLLM/RKNN
Vulkan/OpenCL GPU where useful
CPU
```

---

# 128. Portable CPU Libraries

Potential libraries:

```text
GGML kernels
oneDNN
AOCL
BLAS implementations
Arm KleidiAI
architecture-specific intrinsics
```

Aesir should allow runtime dispatch.

No single CPU library should be mandatory.

---

# 129. oneDNN

oneDNN provides optimized primitives across modern CPU/GPU architectures and performs CPU ISA dispatch.

It is useful for:

```text
BF16
INT8
AVX-512
AMX
Intel GPU/SYCL paths
```

Aesir could use it for auxiliary graphs or selected kernels.

---

# 130. Arm KleidiAI

Arm KleidiAI is designed around optimized AI kernels for Arm CPUs.

Since llama.cpp has support for Arm KleidiAI integration, this is relevant for:

```text
Raspberry Pi
ARM servers
Android-class CPUs
```

Aesir should benchmark against generic GGML NEON kernels.

---

# 131. GPU BLAS / Math Libraries

Possible vendor libraries:

```text
NVIDIA cuBLAS / cuBLASLt
AMD rocBLAS / hipBLASLt
Intel oneMKL / oneDNN
Apple MPS
```

Aesir should not bind its architectural model to any one library.

Instead:

```text
backend capability → matrix provider
```

---

# 132. Attention Kernels

Attention performance depends on:

```text
precision
head dimension
context length
memory bandwidth
shared/local memory
subgroup operations
matrix hardware
kernel fusion
```

A backend that wins GEMM benchmarks may not win attention.

Aesir benchmark suite should include actual transformer kernels.

---

# 133. Flash Attention Capability

Store:

```text
available
backend implementation
supported head sizes
supported precisions
context constraints
```

Do not assume every GPU benefits from the same flash-attention kernel strategy.

---

# 134. Sparse Acceleration

Some accelerators expose structured sparsity acceleration.

Aesir should represent:

```text
sparse format
ratio
supported datatypes
library/runtime requirement
```

Do not advertise sparsity acceleration unless the model and kernel actually exploit it.

---

# 135. Model Format versus Hardware

Aesir should separate:

```text
model storage format
runtime tensor format
hardware execution format
```

Example:

```text
GGUF Q4_K_M
 ↓
GGML quantized tensor
 ↓
backend-specific dequant/matmul
 ↓
FP16 tensor core
```

or:

```text
ONNX INT8
 ↓
NPU compiler
 ↓
device-native quantized graph
```

---

# 136. Compiler Backends

Potential compiler systems relevant to Aesir:

```text
LLVM
NVRTC
HIPRTC
SPIR-V toolchain
Metal shader compiler
XLA
MLIR
OpenVINO compiler
QNN compiler
RKNN converter
Hailo compiler
CANN compiler
SynapseAI graph compiler
```

Compiler version should be captured when precompiled artifacts are cached.

---

# 137. MLIR

MLIR is strategically interesting because it is designed for reusable compiler infrastructure across heterogeneous compute.

Aesir does not need to adopt MLIR immediately, but future custom graph compilation could use it to reduce vendor-specific compiler duplication.

---

# 138. SPIR-V

SPIR-V is a portable intermediate representation used in Vulkan and related ecosystems.

Potential Aesir advantage:

```text
one shader/kernel IR
→ multiple Vulkan vendors
```

but vendor tuning remains important.

---

# 139. Dynamic Backend Plugins

Recommended architecture:

```text
libaesir_backend_cuda
libaesir_backend_hip
libaesir_backend_vulkan
libaesir_backend_metal
libaesir_backend_openvino
...
```

Benefits:

```text
optional dependencies
smaller core
runtime backend discovery
vendor stack isolation
easier experimental support
```

---

# 140. Backend ABI

Minimal plugin ABI:

```text
backend_init()
backend_version()
enumerate_devices()
query_device()
allocate()
free()
copy()
compile_or_load_model()
execute()
synchronize()
query_metrics()
shutdown()
```

For NPU graph backends:

```text
compile_model()
query_operator_support()
```

should be optional extension functions.

---

# 141. Backend Isolation

Unstable vendor runtimes can crash processes.

Aesir should eventually support:

```text
in-process backend
isolated worker process
remote worker
```

Experimental ROCm or NPU backends could run in a worker process so a driver/runtime fault does not kill the server.

---

# 142. Crash Health Learning

If backend crashes repeatedly:

```text
HEALTHY
→ DEGRADED
→ UNSTABLE
→ auto-disabled for current hardware fingerprint
```

Aesir can preserve the reason and allow user override.

---

# 143. Hardware Database

Optional local/community database schema:

```text
vendor
device ID
marketing name
architecture
gfx/SM/Xe target
memory type
known runtimes
known good versions
known bad versions
benchmark summaries
```

Runtime probing remains authoritative.

Database = hints, not truth.

---

# 144. Version Pinning Philosophy

Never hardcode:

```text
"ROCm 6 = supported"
```

or:

```text
"CUDA 12 required forever"
```

Instead implement compatibility predicates:

```text
backend reports API version
engine reports minimum
driver reports supported range
```

Current software versions move quickly.

---

# 145. Linux GPU User Permissions

GPU access often depends on groups/device permissions.

Common DRM access can involve:

```text
render
video
```

Aesir Doctor should diagnose:

```text
device exists
but current user lacks permission
```

without recommending reckless permission changes automatically.

---

# 146. Containers Are Not Required Architecturally

Aesir's hardware abstraction should work directly on bare metal.

Containers may be supported by others, but should never be a fundamental dependency of the compute architecture.

Bare-metal detection should be the reference implementation.

---

# 147. Cross-Platform Diagnostics

Aesir commands:

```bash
aesir hardware list
aesir hardware topology
aesir hardware drivers
aesir hardware runtimes
aesir hardware memory
aesir hardware benchmark
aesir hardware doctor
aesir hardware export
```

---

# 148. `aesir hardware export`

Produce machine-readable report:

```json
{
  "schema": 1,
  "physical_devices": [],
  "drivers": [],
  "runtimes": [],
  "memory_domains": [],
  "topology": [],
  "benchmarks": []
}
```

This will be invaluable for bug reports.

---

# 149. Privacy

Hardware reports should avoid:

```text
hostnames
serial numbers
MAC addresses
usernames
filesystem paths containing personal information
```

unless explicitly requested.

PCI IDs and GPU UUIDs should be optionally redacted for shared bug reports.

---

# 150. Benchmark Design

Microbenchmarks:

```text
H2D transfer
D2H transfer
D2D transfer
memory bandwidth
FP16 GEMM
BF16 GEMM
INT8 GEMM
Q4 dequant+matmul
attention
softmax
RMSNorm
RoPE
```

Macrobenchmarks:

```text
prompt processing
token generation
TTFT
KV growth
long context
multi-user throughput
```

---

# 151. Energy Benchmark

Where telemetry exists:

```text
joules/token
tokens/joule
average watts
peak watts
```

This is especially useful for laptops and edge nodes.

Fastest may not be best.

---

# 152. Noise-Aware Benchmark

Optional platform policy can infer fan/thermal behavior.

Aesir could eventually measure:

```text
temperature
fan RPM where exposed
power
```

and select a quieter backend.

This is particularly valuable for always-on local AI.

---

# 153. Multi-Node Aesir

Once local hardware is abstracted into capability descriptors, the same format can describe remote nodes.

```text
NODE A:
  RTX GPU

NODE B:
  Raspberry Pi

NODE C:
  Mac

NODE D:
  AMD Instinct rental
```

Remote topology simply introduces:

```text
network bandwidth
network latency
authentication
```

as another interconnect.

---

# 154. Remote Memory Is a Memory Tier

Conceptually:

```text
local VRAM
local shared RAM
local CPU RAM
remote node accelerator memory
remote storage
```

Aesir's memory planner can eventually use the same cost model.

---

# 155. Capability Negotiation

Remote Aesir nodes should advertise:

```text
hardware fingerprint
available models
backend health
memory
current load
power policy
```

The router can decide where a request should run.

---

# 156. Hardware Research Test Matrix

For each newly tested platform record:

```text
OS
kernel
driver
runtime
device
architecture
memory
backend
model
quantization
context
prompt t/s
generation t/s
power
peak memory
correctness
notes
```

This should become a public table in the Aesir repository.

---

# 157. AMD Test Matrix

Minimum:

```text
Ryzen APU + Vulkan
Ryzen APU + HIP where possible
Radeon RDNA discrete + Vulkan
Radeon RDNA discrete + HIP
Instinct CDNA + HIP
```

This validates the capability abstraction across radically different AMD devices.

---

# 158. NVIDIA Test Matrix

Minimum:

```text
older CUDA-capable GPU
RTX laptop GPU
modern RTX desktop/cloud
Jetson Orin
large datacenter GPU
```

Validate:

```text
compute capability
memory topology
CUDA driver compatibility
Tensor Core precision
managed/shared memory differences
```

---

# 159. Intel Test Matrix

```text
x86 CPU AVX2
x86 AVX-512
Xeon AMX
Intel integrated GPU
Intel Arc
Intel NPU
```

Backends:

```text
CPU
SYCL/Level Zero
Vulkan
OpenVINO
NPU
```

---

# 160. ARM / Edge Test Matrix

```text
Raspberry Pi 5
Jetson
Android Snapdragon
Rockchip RK3588
NXP board
```

This ensures Aesir's architecture is not accidentally desktop-only.

---

# 161. Apple Test Matrix

```text
base M-series
Pro
Max
Ultra
newer Neural-Accelerator-equipped Apple GPU generations
```

Measure:

```text
unified memory pressure
MLX
Metal
Core ML auxiliary models
CPU/GPU mixed execution
```

---

# 162. What Aesir Should NOT Assume

Never assume:

```text
all AMD GPUs support ROCm
all NVIDIA GPUs support the same tensor formats
all Intel GPUs use the same subgroup width
all integrated GPUs have unlimited RAM
unified memory means zero cost
Vulkan means slow
NPU means faster
AVX-512 means identical performance
more TOPS means faster LLM generation
model fitting means model is usable
```

---

# 163. TOPS Is Not Enough

NPU marketing frequently emphasizes TOPS.

TOPS alone does not reveal:

```text
datatype
sparsity assumptions
memory bandwidth
operator support
compiler quality
autoregressive latency
usable model size
```

Aesir should never schedule from TOPS alone.

---

# 164. FLOPS Is Not Enough

Likewise, GPU FLOPS do not determine LLM tokens/sec.

Important:

```text
memory bandwidth
quantized kernel quality
attention implementation
cache
driver/runtime overhead
context size
batching
```

---

# 165. Memory Capacity Is Not Enough

A 64 GiB shared-memory APU may fit a large model but run it slowly.

A 24 GiB discrete GPU may run a smaller model dramatically faster.

Aesir needs multi-dimensional scoring.

---

# 166. Backend Coverage Is Not Enough

A backend claiming support for an operation may implement it through:

```text
slow fallback
CPU fallback
shader emulation
datatype conversion
```

Aesir's benchmark validates whether support is useful.

---

# 167. Aesir Hardware Knowledge Levels

For each device/backend pair:

```text
LEVEL 0 IDENTIFIED
LEVEL 1 INITIALIZED
LEVEL 2 CAPABILITIES PROBED
LEVEL 3 CORRECTNESS PASSED
LEVEL 4 BENCHMARKED
LEVEL 5 LONG-RUN STABLE
LEVEL 6 COMMUNITY VERIFIED
```

---

# 168. Minimum Hardware Descriptor Example

```toml
[[device]]
id = "gpu0"
class = "gpu"
vendor = "amd"
architecture = "rdna3"
integrated = true
kernel_driver = "amdgpu"

[device.memory]
model = "shared_system"
physical_total_gib = 64
safe_available_gib = 40
host_visible = true
device_visible = true

[[device.backends]]
name = "hip"
state = "experimental"
target = "gfx1103"

[[device.backends]]
name = "vulkan"
state = "healthy"
subgroup_size = 32
```

---

# 169. Full Heterogeneous Descriptor Example

```yaml
system:
  ram_gib: 64
  numa_nodes: 1

cpu:
  vendor: AMD
  architecture: Zen
  isa:
    avx2: true
    avx512f: probe

devices:
  - id: nvidia0
    class: gpu
    memory:
      type: dedicated_vram
      gib: 8
    backend:
      cuda:
        healthy: true

  - id: amd0
    class: gpu
    integrated: true
    memory:
      type: shared_system
    backend:
      hip:
        healthy: false
      vulkan:
        healthy: true

planner:
  selected:
    primary: nvidia0/cuda
    secondary: amd0/vulkan
    cpu: enabled
```

---

# 170. Reference Driver / Runtime Map

| Hardware | Kernel / low-level driver | Main userspace runtime(s) |
|---|---|---|
| NVIDIA GPU Linux | NVIDIA kernel module | CUDA, Vulkan, OpenCL |
| AMD GPU Linux | amdgpu | HIP/ROCm, Vulkan, OpenCL |
| Intel GPU Linux | i915/xe depending generation/platform | Level Zero, SYCL, Vulkan, OpenCL |
| Apple GPU | Apple OS drivers | Metal, MLX, MPS |
| Intel NPU | Intel NPU kernel driver | OpenVINO |
| AMD XDNA | XDNA kernel driver | XRT / Ryzen AI stack |
| Qualcomm Hexagon | platform driver/firmware | QNN / AI Engine Direct |
| Rockchip NPU | RKNPU | RKNN / RKLLM |
| Hailo | Hailo PCIe/device driver | HailoRT |
| Huawei Ascend | Ascend driver | CANN |
| Intel Gaudi | Gaudi driver | SynapseAI |
| NXP NPU | platform drivers | eIQ |
| MediaTek APU | platform stack | NeuroPilot |

---

# 171. Recommended Aesir Implementation Order

## Stage 1

```text
CPU capability detection
CUDA
HIP
Vulkan
Metal
memory topology
```

## Stage 2

```text
OpenVINO
Intel GPU
Apple MLX
DirectML
```

## Stage 3

```text
AMD XDNA
Intel NPU
Qualcomm QNN
Rockchip RKLLM
```

## Stage 4

```text
Hailo
NXP
MediaTek
CANN
Gaudi
PJRT
```

---

# 172. Why Vulkan Should Be Early

Vulkan gives Aesir a single low-level compute route spanning many consumer GPUs.

This is particularly important for:

```text
AMD APUs with awkward ROCm support
Intel integrated GPUs
mobile GPUs
older consumer GPUs
Windows/Linux cross-platform
```

It provides enormous compatibility leverage per engineering effort.

---

# 173. Why NPU Support Should Be Modular

NPU ecosystems are fragmented and graph-centric.

Putting them in the core LLM backend would create complexity.

Instead:

```text
Aesir NPU plugin API
+
ONNX/graph conversion
+
workload role scheduler
```

This lets NPUs contribute immediately without requiring arbitrary GGUF execution.

---

# 174. Why CPU Must Remain First-Class

CPU is:

```text
always available
largest memory access domain
fallback path
control processor
often efficient for small models
excellent for tokenization/sampling
```

Aesir should never treat CPU execution as merely a failure mode.

---

# 175. Why Integrated GPUs Matter

Integrated GPUs are becoming increasingly capable while sharing large memory pools.

They are especially interesting for:

```text
large quantized models
low-power inference
secondary model execution
speculative decoding
embeddings
portable systems
```

This is one of the areas where Aesir can differentiate strongly.

---

# 176. Research Sources

The following primary/upstream sources should be treated as living references. Hardware support changes rapidly, so Aesir should probe runtime capabilities rather than freeze this document into permanent assumptions.

## NVIDIA

- CUDA Programming Guide  
  https://docs.nvidia.com/cuda/cuda-programming-guide/
- CUDA Toolkit  
  https://developer.nvidia.com/cuda/toolkit
- CUDA release notes  
  https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/
- NVIDIA SMI documentation  
  https://docs.nvidia.com/deploy/nvidia-smi/
- NVIDIA DCGM  
  https://docs.nvidia.com/datacenter/dcgm/
- NVIDIA open GPU kernel modules  
  https://github.com/NVIDIA/open-gpu-kernel-modules

## AMD

- ROCm documentation  
  https://rocm.docs.amd.com/
- ROCm compatibility matrix  
  https://rocm.docs.amd.com/en/latest/compatibility/compatibility-matrix.html
- HIP documentation  
  https://rocm.docs.amd.com/projects/HIP/
- AMD SMI  
  https://rocm.docs.amd.com/projects/amdsmi/
- Ryzen AI Software  
  https://ryzenai.docs.amd.com/
- AMD XDNA driver  
  https://github.com/amd/xdna-driver
- AMD AOCL  
  https://www.amd.com/en/developer/aocl.html

## Linux kernel GPU drivers

- Linux GPU driver documentation  
  https://docs.kernel.org/gpu/
- AMDGPU documentation  
  https://docs.kernel.org/gpu/amdgpu/

## Intel

- Intel Xe GPU architecture / oneAPI optimization guide  
  https://www.intel.com/content/www/us/en/docs/oneapi/optimization-guide-gpu/
- Level Zero specification  
  https://oneapi-src.github.io/level-zero-spec/
- OpenVINO  
  https://docs.openvino.ai/
- Intel NPU driver  
  https://github.com/intel/linux-npu-driver
- Intel AMX  
  https://www.intel.com/content/www/us/en/products/docs/accelerator-engines/what-is-intel-amx.html
- oneDNN  
  https://uxlfoundation.github.io/oneDNN/

## Apple

- Metal  
  https://developer.apple.com/metal/
- Core ML  
  https://developer.apple.com/documentation/coreml
- Apple Machine Learning  
  https://developer.apple.com/machine-learning/
- MLX  
  https://ml-explore.github.io/mlx/
- MLX repository  
  https://github.com/ml-explore/mlx

## Khronos

- Vulkan specification  
  https://registry.khronos.org/vulkan/
- OpenCL specification  
  https://registry.khronos.org/OpenCL/
- SYCL specification  
  https://registry.khronos.org/SYCL/

## Microsoft

- DirectML  
  https://learn.microsoft.com/windows/ai/directml/dml

## ONNX Runtime

- Execution Providers  
  https://onnxruntime.ai/docs/execution-providers/

## Qualcomm

- Qualcomm AI Engine Direct  
  https://www.qualcomm.com/developer/software/qualcomm-ai-engine-direct-sdk
- Hexagon NPU  
  https://www.qualcomm.com/processors/hexagon

## Rockchip

- RKNN Toolkit2  
  https://github.com/airockchip/rknn-toolkit2
- RKNN LLM  
  https://github.com/airockchip/rknn-llm

## Hailo

- Hailo AI Software Suite  
  https://hailo.ai/products/hailo-software/hailo-ai-software-suite/
- HailoRT  
  https://github.com/hailo-ai/hailort

## NXP

- eIQ Toolkit  
  https://www.nxp.com/design/design-center/software/eiq-ai-development-environment/
- i.MX Machine Learning documentation  
  https://docs.nxp.com/

## MediaTek

- NeuroPilot  
  https://neuropilot.mediatek.com/

## Google / OpenXLA

- Coral  
  https://coral.ai/
- XLA  
  https://openxla.org/xla
- Cloud TPU  
  https://cloud.google.com/tpu

## Intel Gaudi

- Gaudi documentation  
  https://docs.habana.ai/

## Huawei Ascend

- Ascend documentation  
  https://www.hiascend.com/en/document
- CANN  
  https://www.hiascend.com/eng/cann

## llama.cpp / GGML

- llama.cpp  
  https://github.com/ggml-org/llama.cpp
- build/backends documentation  
  https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md

---

# 177. Final Architectural Rules for Project Aesir

The entire field manual can be reduced to these rules.

1. **Detect hardware, do not guess it.**
2. **Identify architecture separately from vendor.**
3. **Identify kernel driver separately from userspace runtime.**
4. **Treat every device/backend combination as a separate execution candidate.**
5. **Treat memory topology as a primary hardware characteristic.**
6. **Distinguish shared physical memory from unified virtual addressing.**
7. **Probe precision acceleration rather than assuming datatype support.**
8. **Benchmark useful kernels, not theoretical FLOPS/TOPS.**
9. **Measure cross-device transfer cost before heterogeneous scheduling.**
10. **Use NPUs as graph accelerators, not fake GPUs.**
11. **Keep CPU execution first-class.**
12. **Prefer coarse heterogeneous partitioning before fine-grained splitting.**
13. **Use secondary accelerators for auxiliary models when splitting is inefficient.**
14. **Invalidate optimization profiles after driver/runtime changes.**
15. **Cache compiled NPU/accelerator artifacts by exact hardware/runtime fingerprint.**
16. **Preserve a safe OS memory reserve on shared/unified-memory systems.**
17. **Monitor thermal, power, and memory pressure during sustained inference.**
18. **Prefer measured sustained throughput over short peak benchmarks.**
19. **Expose the scheduler's reasoning to the user.**
20. **Make every accelerator optional so Aesir always retains a viable fallback.**

The guiding principle remains:

> **Aesir should understand the whole machine as a living topology of compute engines, memory pools, runtimes, and data paths, then build the execution plan that best uses what is actually present.**

That architecture allows a humble edge computer, a mixed-vendor laptop, a Mac with unified memory, a Jetson, a Ryzen AI system, a GPU workstation, or a rented datacenter accelerator to all become variations of the same underlying Aesir compute model.
