# Project Aesir ThunderKittens + HipKittens Integration and Clean-Room Research Plan

**Project:** Project Aesir
**Purpose:** GPU inference acceleration, hardware research, and clean-room architecture development
**Target Accelerators:** NVIDIA and AMD GPUs
**External Research/Tooling Projects:** ThunderKittens and HipKittens
**Primary Implementation Philosophy:** Hardware-aware, modular, clean-room, original Aesir code

---

## 1. Mission

Project Aesir should be able to use **ThunderKittens** and **HipKittens** as optional external acceleration tools while remaining architecturally independent from both.

At the same time, Aesir should use them as research subjects for understanding high-performance GPU inference techniques, especially:

* Tensor-operation scheduling
* Tile design and tile movement
* Tensor Core / matrix-core utilization
* Register utilization
* Shared-memory utilization
* GPU memory hierarchy management
* Memory-traffic reduction
* Asynchronous memory movement
* Compute/memory overlap
* Kernel fusion
* Persistent kernels
* Megakernels
* GPU-resident scheduling
* Attention kernels
* GEMM/GEMV kernels
* Quantized inference
* Prefill optimization
* Decode optimization
* Multi-GPU execution
* Hardware-specific scheduling

The ultimate goal is **not to reproduce ThunderKittens or HipKittens**.

The goal is to understand the engineering principles demonstrated by them and use those principles to design **original Aesir mechanisms suited to Aesir's own architecture, Mojo implementation, model runtime, hardware router, and edge-computing goals.**

---

## 2. Core Principle

```text
Study behavior.
Study hardware.
Study algorithms.
Study measurements.
Study design principles.

Do NOT translate implementation code.

Then design the Aesir solution independently.
```

Aesir should learn from the *why* rather than reproduce the *how*.

---

## 3. Architectural Goal

Aesir should eventually support an execution architecture resembling:

```text
                     PROJECT AESIR
                          │
                          ▼
                  Model Runtime / API
                          │
                          ▼
                    Compute Graph
                          │
                          ▼
                  Aesir Operator IR
                          │
                          ▼
                  Hardware Dispatcher
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
     CPU Backend      NVIDIA Backend    AMD Backend
         │                │                │
         │          ┌─────┴─────┐    ┌─────┴─────┐
         │          │           │    │           │
         ▼          ▼           ▼    ▼           ▼
      Native      Native       TK   Native       HK
      Aesir       Aesir      Adapter Aesir     Adapter
         │          │           │    │           │
         └──────────┴───────────┴────┴───────────┘
                          │
                          ▼
                       Hardware
```

ThunderKittens and HipKittens therefore become **optional execution providers**.

They must never become the definition of Aesir's internal architecture.

---

## 4. Backend Independence Rule

Aesir's core must know concepts such as:

```text
GEMM
GEMV
Attention
RMSNorm
RoPE
Softmax
Activation
Quantization
Dequantization
KV Cache
Tensor Copy
Tensor Transform
MoE Dispatch
```

It should **not** require the core runtime to understand:

```text
ThunderKittens-specific internal objects
HipKittens-specific internal objects
CUDA-specific scheduling structures
HIP-specific scheduling structures
TK internal scheduling abstractions
HK internal scheduling abstractions
```

Those concepts belong behind backend boundaries.

Example:

```text
Aesir Attention Request
         │
         ▼
Capability Router
         │
 ┌───────┼───────────┐
 │       │           │
 ▼       ▼           ▼
CPU    NVIDIA       AMD
        │            │
   ┌────┴────┐  ┌────┴────┐
   ▼         ▼  ▼         ▼
Native      TK Native      HK
```

---

## 5. ThunderKittens Adapter

Create an optional module conceptually similar to:

```text
backends/
└── nvidia/
    ├── native/
    └── thunderkittens/
```

The ThunderKittens adapter should be responsible for:

* Detecting whether ThunderKittens support is available.
* Detecting supported NVIDIA GPU architecture.
* Compiling or loading compatible kernels.
* Translating Aesir tensor metadata into adapter-compatible calls.
* Managing kernel invocation.
* Returning results to Aesir.
* Reporting supported operations.
* Reporting supported precisions.
* Reporting hardware limitations.
* Reporting initialization failures cleanly.
* Falling back to native Aesir GPU or CPU implementations.

The adapter should be a **bridge**, not an architectural dependency.

---

## 6. HipKittens Adapter

Create a parallel AMD structure:

```text
backends/
└── amd/
    ├── native/
    └── hipkittens/
```

Responsibilities should mirror the NVIDIA adapter at the conceptual level:

```text
Aesir Operator
      │
      ▼
HipKittens Adapter
      │
      ▼
HIP / AMD GPU
```

However:

> Do not require the AMD implementation to imitate the NVIDIA implementation.

Aesir should allow AMD and NVIDIA to use fundamentally different execution strategies.

The common interface represents **what operation must happen**.

The backend determines **how that operation should happen on its hardware**.

---

## 7. Capability-Based Dispatch

Avoid simplistic routing such as:

```text
if NVIDIA:
    ThunderKittens
else if AMD:
    HipKittens
```

Use a capability system instead.

Example:

```text
Operation:
    attention_decode

Shape:
    batch = 1
    heads = 8
    head_dim = 128
    sequence = 8192

Precision:
    BF16

Hardware:
    NVIDIA GPU

Available implementations:
    Aesir Native CUDA
    ThunderKittens
    Reference CPU

Benchmark database:
    TK = 42 µs
    Native = 51 µs

Selected:
    TK
```

Different shapes may select different implementations.

---

## 8. Backend Capability Registry

Each backend should describe itself through metadata.

Conceptual representation:

```text
BackendCapabilities {
    vendor
    architecture
    operation
    data_types
    quantization_formats
    min_shape
    max_shape
    preferred_shapes
    memory_requirements
    workspace_requirements
    deterministic
    experimental
    benchmark_score
}
```

Aesir can then dynamically select an implementation.

---

## 9. Fallback Chain

Every external acceleration path should fail gracefully.

Example:

```text
ThunderKittens kernel
        ↓ failure / unsupported shape

Aesir NVIDIA kernel
        ↓ unavailable

Generic GPU implementation
        ↓ unavailable

Aesir CPU implementation
```

External acceleration must never make a model unusable merely because a specialized backend cannot execute one operation.

---

## 10. Clean-Room Research Architecture

The clean-room process should have **three separated stages**.

```text
STAGE A
External Research
      │
      ▼
STAGE B
Abstract Technical Specification
      │
      ▼
STAGE C
Independent Aesir Implementation
```

The separation between these stages is important.

---

## 11. Stage A: Research Environment

Create a dedicated research area:

```text
research/
└── gpu-kernel-study/
    ├── thunderkittens/
    ├── hipkittens/
    ├── papers/
    ├── hardware/
    ├── benchmarks/
    └── observations/
```

This area is **not Aesir implementation code**.

It contains research notes only.

Researchers may study:

* Papers
* Documentation
* Public presentations
* Public architectural descriptions
* Performance graphs
* Profiling results
* Hardware manuals
* GPU specifications
* Public API behavior
* Published benchmark results
* Experiments run against the external projects
* High-level algorithms
* Mathematical descriptions

Source provenance should be recorded for every research note.

---

## 12. Research Question Format

Do not write:

```text
ThunderKittens performs X using this code:
<implementation>
```

Instead write:

```text
Research Question:
How can memory transfers overlap tensor computation?

Observed principle:
Producer work and compute work can execute in overlapping
pipelines when the hardware permits it.

Hardware reason:
Memory latency can otherwise leave compute resources idle.

Possible Aesir research direction:
Investigate whether Aesir can independently construct a
hardware-specific asynchronous producer/consumer scheduler.
```

This converts an implementation observation into a **general engineering problem**.

---

## 13. Clean-Room Role Separation

For the strongest internal separation, use distinct roles.

### Researcher

Allowed to inspect external implementation details when necessary for research.

Produces only:

* Behavioral descriptions
* Mathematical descriptions
* Hardware observations
* Performance results
* Algorithmic concepts
* Requirements
* Problems discovered
* Abstract diagrams

The researcher must **not** place copied implementation code in Aesir design documents.

### Specification Author

Consumes research findings.

Produces:

```text
Aesir requirement
Aesir constraints
Input/output behavior
Performance objective
Hardware objective
Correctness tests
Benchmark criteria
```

The specification should describe the problem without prescribing external implementation structure.

### Aesir Implementer

Receives only the clean specification.

The implementer designs original Mojo/CUDA/HIP or other Aesir code.

The implementer should not consult the external source implementation while writing the corresponding Aesir mechanism.

---

## 14. AI-Agent Clean-Room Workflow

Because Project Aesir is heavily AI-assisted, clean-room boundaries should also apply to coding agents.

Use separate agent contexts.

```text
Research Agent
     │
     ▼
Research Notes
     │
     ▼
Specification Agent
     │
     ▼
Clean Specification
     │
     ▼
Implementation Agent
     │
     ▼
Original Aesir Code
```

The **Implementation Agent must not receive external source code**.

Its context should contain only:

* Aesir source code
* Hardware documentation
* Aesir specifications
* Mathematical formulas
* Test requirements
* Benchmark requirements
* Public API requirements where interoperability demands them

This prevents accidental source-to-source translation by an AI coding agent.

---

## 15. Forbidden Clean-Room Behaviors

Do not:

* Copy source code.
* Translate CUDA code into Mojo.
* Translate HIP code into Mojo.
* Rewrite external functions line by line.
* Preserve external variable naming.
* Preserve external class hierarchy.
* Reproduce unusual implementation structure unnecessarily.
* Copy comments.
* Feed external implementation files directly to the Aesir coding agent.
* Ask an AI agent to "rewrite this ThunderKittens kernel in Mojo."
* Ask an AI agent to "port this HipKittens implementation."
* Recreate an implementation by making superficial syntax changes.
* Copy benchmark harness code when an independent harness can be written.

A clean-room implementation should arise from the **problem specification**, not the external source text.

---

## 16. Allowed Research Questions

Good questions include:

```text
Why does this strategy improve arithmetic intensity?

What causes this kernel to become memory-bound?

Which part of the GPU pipeline is idle?

How does tile size affect register pressure?

Why does this workload benefit from asynchronous memory movement?

Why does this strategy work on NVIDIA but not AMD?

When does fusion eliminate intermediate memory traffic?

When does fusion increase register pressure too much?

When does a persistent kernel outperform repeated launches?

Which operations benefit from GPU-resident scheduling?

What characteristics make decoding different from prefill?

What hardware capability enables this scheduling strategy?

Can Aesir solve the same hardware problem using a different mechanism?
```

These questions produce transferable knowledge rather than copied implementation.

---

## 17. Research Track A: Tensor Scheduling

Study how modern GPU kernels divide work among:

* Threads
* Warps
* Waves
* Thread blocks
* Compute units / SMs
* Producers
* Consumers
* Memory workers
* Compute workers

Focus on:

```text
Load
    ↓
Transform
    ↓
Compute
    ↓
Accumulate
    ↓
Store
```

Then investigate overlap:

```text
Time →

Load A ─────────┐
                Compute A ─────────┐
Load B ─────────┘                  Store A
                Compute B ─────────┐
Load C ────────────────────────────┘
```

Aesir research objective:

> Develop an original hardware-aware scheduler capable of overlapping memory movement and arithmetic without requiring identical scheduling semantics across NVIDIA and AMD.

---

## 18. Research Track B: Tile Management

Study the general principle of breaking tensors into hardware-friendly tiles.

Investigate:

* Tile dimensions
* Register tiles
* Shared-memory tiles
* Tensor-core-compatible tiles
* Wave-friendly tiles
* Tile reuse
* Tile lifetime
* Tile swizzling
* Bank conflicts
* Alignment
* Coalesced loads
* Register pressure
* Occupancy

Create an Aesir abstraction tentatively called:

```text
AesirTile
```

But design it independently around Aesir requirements.

Possible conceptual metadata:

```text
AesirTile {
    shape
    dtype
    layout
    storage_class
    alignment
    lifetime
}
```

Do not reproduce another project's tile API.

---

## 19. Research Track C: Feeding Matrix Hardware

Study how modern GPUs feed specialized matrix hardware.

NVIDIA examples conceptually include Tensor Cores.

AMD provides corresponding matrix-computation hardware.

Research:

* Operand layout
* Tile size
* Accumulator behavior
* Pipeline latency
* Precision
* Quantization
* Register requirements
* Shared-memory requirements
* Matrix instruction throughput
* Instruction issue behavior
* Dependencies
* Synchronization

Aesir objective:

```text
Aesir Matrix Engine
        │
        ├── NVIDIA implementation
        ├── AMD implementation
        └── future accelerators
```

The interface should express matrix operations.

Hardware backends determine how those operations reach the underlying matrix units.

---

## 20. Research Track D: Memory Traffic

For inference, arithmetic is only half the battle.

Measure:

```text
HBM / VRAM traffic
L2 traffic
shared-memory traffic
register traffic
KV-cache traffic
weight traffic
activation traffic
intermediate tensors
```

For every operation calculate approximately:

```text
bytes moved
operations performed
arithmetic intensity
reuse opportunities
temporary allocations
```

Create an Aesir metric:

```text
Useful Compute / Bytes Moved
```

Use it when evaluating new kernels.

---

## 21. Memory-Traffic Reduction Principles

Investigate independent Aesir implementations of:

* Tensor reuse
* Weight reuse
* KV reuse
* Tile reuse
* Shared-memory caching
* Register reuse
* Eliminating intermediate tensors
* Operation fusion
* Persistent weights where practical
* Persistent KV metadata
* Reduced precision
* Quantized memory paths
* Prefetching
* Asynchronous transfer
* Layout-aware movement

The design question should always be:

> Can Aesir avoid moving this data at all?

The cheapest memory transaction is the one that never happens.

---

## 22. Research Track E: Kernel Fusion

Start with simple fusion opportunities.

Example:

```text
RMSNorm
   ↓
Linear
```

Potentially:

```text
RMSNorm + Projection
```

Then investigate:

```text
QKV Projection
+ RoPE
+ KV Cache Write
```

And:

```text
Linear
+ Bias
+ Activation
```

Compare:

```text
Kernel A
   ↓ VRAM
Kernel B
   ↓ VRAM
Kernel C
```

against:

```text
Fused Kernel ABC
```

Measure:

* Launch overhead
* VRAM round trips
* Register pressure
* Shared-memory pressure
* Occupancy
* Code complexity
* Shape sensitivity

Fusion should be benchmark-driven, not ideological.

Sometimes several small kernels will outperform one enormous kernel.

---

## 23. Research Track F: Megakernels

Megakernels deserve their own Aesir research program.

Traditional model execution:

```text
CPU
 │
 ├── launch kernel
 ├── launch kernel
 ├── launch kernel
 ├── launch kernel
 └── launch kernel
```

Research alternative:

```text
CPU
 │
 └── launch GPU program
          │
          ├── operation
          ├── operation
          ├── operation
          ├── synchronization
          ├── operation
          └── operation
```

The GPU remains active and coordinates larger portions of inference itself.

---

## 24. Aesir Megakernel Research Name

Tentative internal research subsystem:

```text
Aesir Forge
```

Concept:

```text
Aesir Forge
    │
    ├── Work Queue
    ├── Operation Descriptors
    ├── Tensor Descriptors
    ├── Dependency Graph
    ├── GPU Scheduler
    └── Execution Workers
```

The name is optional.

The architecture must be original.

---

## 25. Aesir GPU Instruction Stream

One possible research direction is an Aesir-specific compact device work description.

For example:

```text
AESIR_OP_GEMM
AESIR_OP_RMSNORM
AESIR_OP_ROPE
AESIR_OP_ATTN
AESIR_OP_GEMV
AESIR_OP_ACT
AESIR_OP_COPY
```

This should **not** reproduce another project's instruction representation.

Instead derive it from Aesir's own model graph and runtime needs.

Possible flow:

```text
Model Graph
     │
     ▼
Aesir IR
     │
     ▼
Execution Plan
     │
     ▼
GPU Work Stream
     │
     ▼
Persistent Executor
```

---

## 26. Prefill and Decode Must Be Treated Differently

Do not assume one kernel strategy is optimal for both.

### Prefill

Often involves larger matrix operations and significant parallelism.

Research:

* GEMM throughput
* Attention throughput
* Large tile sizes
* Compute saturation
* Quantized matrix operations
* Large KV-cache writes

### Decode

Often involves:

* Small batch sizes
* GEMV-like operations
* KV-cache reads
* Memory bandwidth limitations
* Launch overhead
* Synchronization overhead
* Small dynamic workloads

Research separately.

Aesir's router should be able to choose completely different execution strategies for prefill and decode.

---

## 27. Black-Box Comparative Benchmarking

ThunderKittens and HipKittens should also serve as external benchmarks.

Aesir does not need their source implementation to learn from behavior.

Benchmark:

```text
same GPU
same tensor shapes
same dtype
same model
same context
same batch
same operation
same warmup
same input distribution
```

Compare:

```text
Aesir Native
ThunderKittens / HipKittens
Vendor library
Reference implementation
```

Record:

* Latency
* Throughput
* Tokens/sec
* TFLOP/s where meaningful
* Memory bandwidth
* VRAM use
* GPU occupancy
* Power
* Temperature
* Clock speed
* Cache behavior
* Launch overhead

A performance gap then becomes a research question.

Example:

```text
External kernel: 35 µs
Aesir kernel:    58 µs

Question:
Where are the missing 23 µs?

Possible causes:
    memory traffic
    synchronization
    occupancy
    tile geometry
    launch overhead
    register pressure
    pipeline bubbles
```

This is far more useful than merely copying code.

---

## 28. Benchmark Integrity

GPU benchmarking is extremely sensitive to methodology.

Create one Aesir benchmarking standard covering:

* Warm-up iterations
* Measurement iterations
* Random seeds
* Input distributions
* Cache conditions
* Clock state
* Thermal state
* GPU power state
* Precision
* Compiler flags
* GPU architecture
* Driver version
* Runtime version
* Context length
* Batch size

Store the entire environment with benchmark results.

Example:

```text
benchmarks/
└── gpu/
    ├── methodology.md
    ├── nvidia/
    ├── amd/
    ├── operations/
    └── models/
```

---

## 29. Profiling Pipeline

For NVIDIA evaluate tools such as:

```text
Nsight Systems
Nsight Compute
CUDA profiler interfaces
hardware counters
```

For AMD evaluate:

```text
rocprof
ROCm profiling tools
hardware counters
```

Convert the findings into vendor-neutral metrics whenever possible:

```text
compute utilization
memory utilization
cache hit rate
occupancy
register pressure
stall reason
pipeline utilization
memory latency
kernel launch latency
```

---

## 30. Hardware Knowledge Database

Create:

```text
hardware/
└── gpu/
    ├── nvidia/
    ├── amd/
    └── concepts/
```

Document hardware principles independently of external kernel libraries.

Topics:

```text
SM / CU organization
warp / wave behavior
register files
shared memory / LDS
L1
L2
HBM / VRAM
Tensor Cores / matrix units
asynchronous copies
barriers
occupancy
thread-block scheduling
chiplets
NUMA effects
interconnect
```

This hardware knowledge should become the real foundation of Aesir's optimization work.

---

## 31. Cross-Vendor Comparative Research

Every major optimization should ask:

```text
What is universal?

What is NVIDIA-specific?

What is AMD-specific?

What is architecture-generation-specific?
```

Example:

```text
GENERAL PRINCIPLE
Overlap memory and compute.

NVIDIA IMPLEMENTATION
Architecture-specific mechanism A.

AMD IMPLEMENTATION
Architecture-specific mechanism B.

AESIR
Common scheduling objective with independent
backend-specific realization.
```

This prevents Aesir from becoming CUDA architecture wearing an AMD costume. 🐈⚡

---

## 32. Aesir Optimization Knowledge Format

For every discovery create a structured record.

```text
Optimization:
Reduce intermediate tensor writes

Problem:
Separate operations repeatedly materialize tensors in VRAM.

General Principle:
Data reuse can reduce memory bandwidth demand.

Relevant Hardware:
All GPUs.

Vendor Differences:
Implementation mechanism varies.

Aesir Hypothesis:
Fuse selected operator chain.

Experiment:
Implement independent prototype.

Baseline:
Existing Aesir kernels.

Success Metric:
Lower latency without unacceptable occupancy loss.

Result:
TBD.
```

This builds an original Aesir optimization knowledge base.

---

## 33. Provenance Ledger

Maintain:

```text
research/PROVENANCE.md
```

Each entry should record:

```text
Date
Topic
Researcher/agent
External resources consulted
Type of resource
General principles extracted
Aesir specification produced
Implementation agent
Implementation commit
Benchmark evidence
```

Example:

```text
Topic:
Asynchronous memory/compute overlap

Sources:
GPU vendor documentation
Academic papers
ThunderKittens research material
HipKittens research material

Extracted principle:
Independent memory and arithmetic work may be pipelined.

Clean specification:
AESIR-GPU-SCHED-004

Implementation:
Designed independently from specification.

Aesir commit:
<commit>
```

---

## 34. Clean Specification Repository

Create:

```text
specs/
└── gpu/
    ├── scheduling/
    ├── tiles/
    ├── memory/
    ├── tensor/
    ├── fusion/
    ├── megakernel/
    ├── attention/
    ├── gemm/
    └── quantization/
```

Specifications should be implementation-neutral.

---

## 35. Experiment Repository

Create:

```text
experiments/
└── gpu/
    ├── nvidia/
    ├── amd/
    ├── scheduling/
    ├── memory/
    ├── fusion/
    └── megakernel/
```

Experiments should not immediately become production Aesir code.

Promote an experiment only after:

```text
correctness
+
repeatable performance improvement
+
maintainability
+
hardware compatibility analysis
```

---

## 36. Correctness Comes Before Speed

Every optimized kernel must be checked against a trusted reference.

Test:

* Random tensors
* Edge shapes
* Large values
* Small values
* Zero values
* Different sequence lengths
* Different batches
* Different head dimensions
* Different precisions
* Quantized models
* Long-context behavior

Optimization that silently damages model output is not optimization.

---

## 37. Numerical Tolerance Framework

Aesir should define expected tolerances for:

```text
FP32
BF16
FP16
FP8
INT8
INT4
other quantized formats
```

Tests should distinguish:

```text
bit-identical
numerically equivalent
model-quality equivalent
incorrect
```

---

## 38. First External Integration Milestone

Do **not** start with megakernels.

Start with one simple operator.

Recommended:

```text
GEMM
```

Milestone:

```text
Aesir tensor
     │
     ▼
Backend Router
     │
     ▼
TK/HK Adapter
     │
     ▼
External kernel
     │
     ▼
Aesir tensor
```

Prove:

* Interface works.
* Build system works.
* Errors propagate.
* Correct backend is selected.
* Fallback works.
* Results are correct.
* Benchmarking works.

---

## 39. Second Integration Milestone

Add:

```text
Attention
```

Test separately for:

```text
prefill
decode
causal attention
different context lengths
different head dimensions
```

---

## 40. Third Integration Milestone

Expand capability routing to:

```text
GEMM
GEMV
Attention
RMSNorm
RoPE
selected quantized operations
```

Only expose operations that provide measurable value.

Aesir does not need to wrap every external kernel.

---

## 41. Native Aesir Research Milestones

Parallel to external integration:

```text
Phase 1
Baseline native kernels

Phase 2
Tile-aware kernels

Phase 3
Asynchronous memory movement

Phase 4
Hardware-aware scheduling

Phase 5
Simple fusion

Phase 6
Advanced fusion

Phase 7
Persistent execution experiments

Phase 8
GPU-resident scheduling

Phase 9
Aesir megakernel experiments

Phase 10
Automatic execution-plan optimization
```

---

## 42. Runtime Auto-Tuning

Eventually Aesir should benchmark different implementations.

Example:

```text
GEMM shape X:

Aesir Native 1 = 44 µs
Aesir Native 2 = 37 µs
ThunderKittens = 31 µs

Choose ThunderKittens.
```

Another shape:

```text
Aesir Native 1 = 12 µs
Aesir Native 2 = 10 µs
ThunderKittens = 14 µs

Choose Aesir Native 2.
```

Cache result:

```text
hardware + driver + operation + shape + dtype
                        │
                        ▼
                  best implementation
```

---

## 43. Performance Knowledge Cache

Possible database:

```text
~/.aesir/performance.db
```

Key:

```text
GPU
architecture
driver
backend
operation
shape
dtype
quantization
batch
context
```

Value:

```text
latency
throughput
memory
confidence
sample_count
```

Aesir gradually learns the fastest execution strategy for the machine it inhabits.

---

## 44. Compile-Time + Runtime Optimization

Aesir should eventually support both.

### Compile-Time

Determine:

* Static tensor shapes
* Supported operations
* Fusion opportunities
* Constant weights
* Quantization layouts

### Runtime

Determine:

* Actual sequence length
* Batch size
* KV-cache state
* GPU memory availability
* Competing workloads
* Current hardware
* Measured backend speed

---

## 45. Long-Term Aesir Model

The eventual system could become:

```text
                  PROJECT AESIR
                       │
                Model Graph / IR
                       │
             Optimization Planner
                       │
             Hardware Capability DB
                       │
                  Cost Model
                       │
                Execution Plan
                       │
       ┌───────────────┼───────────────┐
       │               │               │
       ▼               ▼               ▼
      CPU            NVIDIA           AMD
       │               │               │
    Native       Native / TK      Native / HK
                       │
                       ▼
                 GPU Scheduler
                       │
              Fused / Persistent
                 Execution
```

---

## 46. Important Architectural Rule

**ThunderKittens and HipKittens are tools in Aesir's forge. They are not the forge itself.**

Project Aesir must remain capable of operating without either.

This preserves:

* Portability
* Architectural independence
* Edge-device support
* Future hardware support
* Research freedom
* Native Mojo development
* Aesir's unique identity

---

## 47. Licensing and IP Boundary

Before distributing an adapter or linking external components:

* Review the current licenses of external dependencies.
* Preserve required notices.
* Keep third-party code clearly separated.
* Record dependency versions.
* Do not claim third-party code as Aesir code.
* Do not assume that "clean-room" automatically resolves every possible copyright, patent, licensing, or contractual concern.

Clean-room engineering is a development discipline, not a magic legal shield.

For major commercial distribution, obtain appropriate legal review.

---

## 48. Documentation Files to Create

Recommended additions:

```text
docs/
├── GPU_BACKEND_ARCHITECTURE.md
├── GPU_CAPABILITY_ROUTER.md
├── GPU_BENCHMARK_STANDARD.md
├── GPU_PROFILING_GUIDE.md
├── GPU_CLEAN_ROOM_POLICY.md
├── GPU_RESEARCH_METHOD.md
├── GPU_TILE_RESEARCH.md
├── GPU_MEMORY_RESEARCH.md
├── GPU_FUSION_RESEARCH.md
├── GPU_MEGAKERNEL_RESEARCH.md
├── THUNDERKITTENS_ADAPTER.md
└── HIPKITTENS_ADAPTER.md

research/
├── PROVENANCE.md
├── thunderkittens/
├── hipkittens/
├── nvidia/
├── amd/
└── comparative/

specs/
└── gpu/

experiments/
└── gpu/
```

---

## 49. Initial Research Sequence

Recommended order:

```text
1. Establish clean-room policy.

2. Establish provenance ledger.

3. Define backend interface.

4. Define capability registry.

5. Build benchmark framework.

6. Integrate ThunderKittens experimentally.

7. Integrate HipKittens experimentally.

8. Benchmark GEMM.

9. Benchmark attention.

10. Profile memory traffic.

11. Study tile behavior.

12. Study tensor/matrix hardware utilization.

13. Study compute/memory overlap.

14. Study NVIDIA scheduling strategies.

15. Study AMD scheduling strategies.

16. Compare what principles transfer across vendors.

17. Produce clean Aesir specifications.

18. Build independent native Aesir experiments.

19. Introduce kernel fusion.

20. Explore persistent kernels.

21. Explore GPU-resident scheduling.

22. Begin Aesir megakernel research.

23. Add runtime auto-tuning.

24. Add performance database.

25. Feed discoveries back into Aesir's optimizer.
```

---

## 50. Success Criteria

This research program succeeds when Aesir can:

* Use ThunderKittens where beneficial.
* Use HipKittens where beneficial.
* Operate without either.
* Run native Aesir implementations.
* Select backends by capability and measured performance.
* Learn which implementation works best for a particular workload.
* Treat NVIDIA and AMD as genuinely different architectures.
* Reduce unnecessary GPU memory traffic.
* Improve matrix-unit utilization.
* Improve prefill throughput.
* Improve decode latency.
* Fuse operations when beneficial.
* Experiment with persistent GPU execution.
* Experiment with original Aesir megakernels.
* Document the intellectual provenance of new optimizations.
* Demonstrate that native Aesir implementations were independently designed.

---

## 51. Core Clean-Room Rule

The central rule for all contributors and AI agents is:

> **Do not ask how to reproduce another project's implementation. Ask what hardware problem that implementation is solving, describe that problem independently, and then ask how Project Aesir should solve it.**

That distinction should guide the entire research program.

---

## 52. Final Vision

ThunderKittens and HipKittens should serve Project Aesir in **three different roles**:

```text
             ┌────────────────────┐
             │ ThunderKittens /   │
             │    HipKittens      │
             └─────────┬──────────┘
                       │
          ┌────────────┼─────────────┐
          │            │             │
          ▼            ▼             ▼
   EXECUTION TOOL   BENCHMARK     RESEARCH
                                     │
                                     ▼
                               General Principles
                                     │
                                     ▼
                              Clean Specification
                                     │
                                     ▼
                           Original Aesir Research
                                     │
                                     ▼
                           Native Aesir Technology
```

The most important outcome is not merely making Aesir compatible with fast external kernels.

The deeper goal is for Aesir to **learn enough about the hardware to eventually create its own high-performance solutions**.

ThunderKittens can teach lessons from NVIDIA hardware.

HipKittens can teach lessons from AMD hardware.

Vendor documentation can explain the silicon.

Profilers can reveal what the silicon is actually doing.

Benchmarks can tell Aesir whether an idea worked.

And from those ingredients, Project Aesir can forge its own architecture.

**Study broadly. Specify cleanly. Implement independently. Measure everything.**
