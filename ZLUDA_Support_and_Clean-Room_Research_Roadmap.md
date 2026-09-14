# Project Aesir ZLUDA Support and Clean-Room Research Roadmap

**Project:** Project Aesir
**Roadmap Type:** Independent companion roadmap
**Primary Subject:** ZLUDA compatibility, cross-vendor GPU execution, and clean-room research
**Relationship to Existing Work:** Additive only
**Status:** Research and architecture roadmap

---

## 1. Purpose

This roadmap defines how Project Aesir can:

1. Support ZLUDA as an optional compatibility technology.
2. Execute compatible CUDA-oriented workloads on supported non-NVIDIA hardware when practical.
3. Benchmark ZLUDA execution against native Aesir, ROCm/HIP, HipKittens, CUDA, and ThunderKittens paths.
4. Study the architectural ideas demonstrated by ZLUDA using a strict clean-room methodology.
5. Use those lessons to improve Aesir's own hardware abstraction, intermediate representation, compilation, runtime dispatch, compatibility, caching, and fallback systems.
6. Research the areas where ZLUDA intersects conceptually with ThunderKittens and HipKittens.
7. Keep all native Aesir implementations independently designed.

This roadmap does **not** replace, rewrite, merge with, or supersede the existing ThunderKittens/HipKittens roadmap.

The plans should remain independent.

```text
Existing Roadmap
ThunderKittens + HipKittens
        │
        ├── Native NVIDIA kernel research
        ├── Native AMD kernel research
        ├── Scheduling
        ├── Tiling
        ├── Matrix hardware
        ├── Fusion
        └── Megakernels


This Roadmap
ZLUDA
        │
        ├── CUDA compatibility
        ├── PTX translation research
        ├── IR lowering
        ├── Cross-vendor execution
        ├── Runtime mediation
        ├── Library compatibility
        ├── Compilation caching
        └── Compatibility fallback
```

Where the two roadmaps overlap, they may exchange **research findings and benchmark results**, but neither roadmap changes the scope or architecture of the other.

---

## 2. Core Architectural Rule

ZLUDA should be treated as an **optional compatibility provider**.

It must never become a mandatory dependency of Project Aesir.

Aesir must continue operating when ZLUDA is:

* Not installed.
* Unsupported by the hardware.
* Unsupported by the operating system.
* Unable to execute a particular CUDA workload.
* Slower than a native implementation.
* Disabled by the user.
* Incompatible with a particular kernel or library.

The fundamental rule is:

> **Native execution remains preferred when an appropriate native implementation exists. ZLUDA provides an additional compatibility path, not the definition of Aesir's GPU architecture.**

---

## 3. High-Level Architecture

Aesir should conceptually support:

```text
                         PROJECT AESIR
                              │
                              ▼
                       Model Runtime
                              │
                              ▼
                         Aesir IR
                              │
                              ▼
                    Capability Router
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
       CPU                  NVIDIA                 AMD
        │                     │                     │
        │              ┌──────┴──────┐       ┌──────┴─────────┐
        │              │             │       │                │
        ▼              ▼             ▼       ▼                ▼
    Aesir CPU     Aesir CUDA   ThunderKittens Native ROCm  HipKittens
                                                    │
                                                    │
                                             compatibility
                                                    │
                                                    ▼
                                                  ZLUDA
                                                    │
                                                    ▼
                                                AMD GPU
```

ZLUDA should be located **behind Aesir's capability router**.

The model runtime should not need to know whether a compatible workload ultimately executed through:

* Native CUDA.
* ThunderKittens.
* Native ROCm/HIP.
* HipKittens.
* ZLUDA.
* CPU fallback.

---

## 4. ZLUDA's Role in Aesir

ZLUDA should serve three distinct roles.

```text
                         ZLUDA
                           │
            ┌──────────────┼──────────────┐
            │              │              │
            ▼              ▼              ▼
       Compatibility     Benchmark       Research
          Provider        Target         Subject
```

### 4.1 Compatibility Provider

Allow compatible CUDA-oriented workloads to execute on supported non-NVIDIA hardware when no preferable native implementation exists.

### 4.2 Benchmark Target

Compare translated execution against native implementations.

### 4.3 Research Subject

Study the principles involved in translating one GPU software ecosystem onto another.

These roles should remain conceptually separate.

---

## 5. Proposed Aesir Backend Structure

Recommended project organization:

```text
backends/
├── cpu/
│   └── native/
│
├── nvidia/
│   ├── native/
│   └── thunderkittens/
│
├── amd/
│   ├── native/
│   └── hipkittens/
│
└── compatibility/
    └── zluda/
```

The location under `compatibility/` is intentional.

ZLUDA is not equivalent to a native AMD backend.

---

## 6. ZLUDA Provider Interface

Create an internal Aesir abstraction similar to:

```text
CompatibilityProvider
```

Conceptually:

```text
CompatibilityProvider {
    detect()
    initialize()
    enumerate_capabilities()
    probe_workload()
    prepare()
    execute()
    synchronize()
    collect_diagnostics()
    benchmark()
    shutdown()
}
```

This interface should be designed around **Aesir's requirements**, not around ZLUDA's internal class or module structure.

---

## 7. ZLUDA Capability Descriptor

A ZLUDA provider should report capabilities through structured metadata.

Example concept:

```text
ZludaCapabilities {
    available
    version
    host_os
    gpu_vendor
    gpu_architecture
    cuda_runtime_compatibility
    ptx_capabilities
    library_capabilities
    supported_precisions
    known_limitations
    experimental_features
}
```

Aesir should never assume support merely because ZLUDA is installed.

Capabilities should be probed or explicitly registered.

---

## 8. Supported Execution Modes

Aesir should investigate multiple ZLUDA integration modes.

### Mode A: External Application Compatibility

```text
Aesir
  │
  ▼
CUDA-oriented application
  │
  ▼
ZLUDA
  │
  ▼
AMD GPU
```

This is useful for:

* External inference utilities.
* Benchmark programs.
* CUDA-only research tools.
* Compatibility testing.
* Third-party AI programs.

This should be the safest initial integration target.

---

### Mode B: CUDA Plugin Compatibility

```text
Aesir
  │
  ▼
Plugin Manager
  │
  ▼
CUDA-oriented plugin
  │
  ▼
ZLUDA
  │
  ▼
AMD GPU
```

This could eventually allow an Aesir extension written primarily for CUDA to function on compatible AMD systems.

This must remain optional and capability-tested.

---

### Mode C: Operator Compatibility

A more advanced possibility:

```text
Aesir Operator
       │
       ▼
No native AMD implementation
       │
       ▼
Compatible CUDA implementation exists
       │
       ▼
ZLUDA provider
       │
       ▼
AMD GPU
```

This should be considered experimental until correctness and performance are demonstrated.

---

### Mode D: Research Harness

```text
CUDA/PTX Test
      │
      ├──────────────► NVIDIA CUDA
      │
      └──────────────► ZLUDA / AMD
                           │
                           ▼
                       Compare
```

The research harness should compare:

* Correctness.
* Numerical behavior.
* Compilation.
* Runtime behavior.
* Performance.
* Memory use.
* Unsupported features.

---

## 9. Backend Selection Priority

Do not define one universal ordering.

The router should make decisions based on capability and benchmark evidence.

A typical AMD preference could begin as:

```text
Native Aesir AMD
       │
       ▼
HipKittens
       │
       ▼
Other native ROCm/HIP provider
       │
       ▼
ZLUDA compatibility
       │
       ▼
CPU fallback
```

But benchmarking may alter the order for individual operations.

Example:

```text
Operation A:

HipKittens       18 µs
Native Aesir     21 µs
ZLUDA CUDA       29 µs

Select HipKittens.
```

Another case might produce:

```text
Operation B:

ZLUDA CUDA       14 µs
Native Aesir     23 µs
HipKittens       Unsupported

Select ZLUDA.
```

Routing should remain empirical.

---

## 10. Never Assume Compatibility

Every CUDA workload should pass through a compatibility probe.

Conceptually:

```text
CUDA workload
      │
      ▼
Inspect requirements
      │
      ├── Runtime API requirements
      ├── PTX requirements
      ├── Library requirements
      ├── Precision requirements
      ├── Architecture assumptions
      └── Memory requirements
      │
      ▼
ZLUDA compatibility assessment
      │
   ┌──┴───┐
   │      │
Supported Unsupported
   │      │
   ▼      ▼
Execute  Fallback
```

---

## 11. Compatibility Confidence Levels

Aesir should classify ZLUDA paths.

Suggested states:

```text
UNKNOWN
PROBING
EXPERIMENTAL
SUPPORTED
BENCHMARKED
PREFERRED
DEGRADED
UNSUPPORTED
BROKEN
```

This prevents an experimental translated kernel from silently becoming a production default.

---

## 12. Clean-Room Research Mission

The research objective is **not to recreate ZLUDA**.

The objective is to understand the engineering principles behind cross-vendor GPU compatibility.

Key questions include:

* How can an intermediate GPU language be represented independently?
* How can one instruction model be lowered toward another hardware architecture?
* How should unsupported operations be represented?
* How should runtime APIs be mediated?
* How should external libraries be substituted?
* How should compiled kernels be cached?
* How should architecture differences be exposed?
* How can compatibility failures fall back safely?
* How can translated execution remain observable and debuggable?
* How should numerical differences be validated?
* How should capability discovery work?
* How should compilation and runtime errors be classified?

---

## 13. Strict Clean-Room Boundary

The same clean-room principle used elsewhere in Aesir should apply here.

```text
External Project
      │
      ▼
Research
      │
      ▼
General Principle
      │
      ▼
Clean Specification
      │
      ▼
Independent Aesir Design
      │
      ▼
Original Aesir Code
```

Never use:

```text
External source code
      │
      ▼
AI code translator
      │
      ▼
"Original" Aesir code
```

That workflow is prohibited.

---

## 14. Research Roles

### Research Agent

May study:

* Documentation.
* Papers.
* GPU specifications.
* Public architectural descriptions.
* Public API behavior.
* Benchmark behavior.
* Compiler output.
* Profiling results.
* Public source code when necessary for research.

Produces only abstract findings.

---

### Specification Agent

Receives research findings and writes clean specifications describing:

* Problem.
* Required behavior.
* Inputs.
* Outputs.
* Constraints.
* Correctness expectations.
* Performance objectives.
* Hardware assumptions.
* Failure behavior.

It should not reproduce implementation structure.

---

### Implementation Agent

Receives:

* Aesir code.
* Aesir specifications.
* Vendor documentation where appropriate.
* Hardware documentation.
* Mathematical definitions.
* Tests.
* Benchmark requirements.

It must not receive ZLUDA implementation code when independently implementing an analogous Aesir feature.

---

## 15. Forbidden Clean-Room Actions

Do not:

* Translate ZLUDA Rust code into Mojo.
* Translate ZLUDA C/C++ code into Mojo.
* Convert ZLUDA functions line by line.
* Copy unusual data structures.
* Preserve internal naming.
* Copy compiler passes.
* Copy comments.
* Duplicate source organization without independent justification.
* Feed ZLUDA source files directly into an Aesir implementation agent.
* Ask an AI to "port this ZLUDA component to Aesir."
* Ask an AI to "rewrite ZLUDA in Mojo."
* Reproduce algorithms from source merely by changing syntax.

The question must always become:

> **What problem is being solved, and how should Aesir solve that problem independently?**

---

## 16. Clean-Room Research Track A: GPU Intermediate Representations

One of the most valuable ZLUDA-related research areas is intermediate representation.

Study conceptually:

```text
High-Level GPU Program
        │
        ▼
Intermediate Representation
        │
        ▼
Optimization
        │
        ▼
Hardware-Specific Representation
        │
        ▼
Machine Code
```

Research topics:

* Instruction semantics.
* Type representation.
* Address spaces.
* Memory operations.
* Atomic operations.
* Synchronization.
* Control flow.
* Function calls.
* Kernel entry points.
* Vector operations.
* Floating-point modes.
* Architecture capabilities.
* Metadata.
* Debug information.

Aesir should use this knowledge when designing its **own IR**.

---

## 17. Aesir IR Research Direction

Possible future pipeline:

```text
Model
  │
  ▼
Aesir Graph IR
  │
  ▼
Aesir Tensor IR
  │
  ▼
Aesir Device IR
  │
  ├────────► CPU lowering
  │
  ├────────► NVIDIA lowering
  │
  ├────────► AMD lowering
  │
  └────────► Future accelerator lowering
```

The Aesir Device IR should not attempt to imitate PTX.

It should represent the operations **Aesir needs**.

---

## 18. Clean-Room Research Track B: PTX Semantics

PTX should be studied as a public GPU intermediate-language specification.

Research should focus on semantics rather than ZLUDA implementation.

Topics:

```text
thread hierarchy
memory spaces
barriers
atomics
vector operations
floating point
integer operations
predication
control flow
addressing
special registers
warp-oriented concepts
matrix operations
architecture capability levels
```

The goal is not:

> Build Aesir PTX.

The goal is:

> Understand what a mature GPU intermediate language must express.

---

## 19. Clean-Room Research Track C: IR Lowering

Research the general compiler problem:

```text
Source IR
   │
   ▼
Semantic normalization
   │
   ▼
Target-independent transformations
   │
   ▼
Target-specific lowering
   │
   ▼
Machine-oriented IR
```

Aesir research questions:

* Which operations should remain abstract longest?
* Which operations should be lowered early?
* Where should architecture-specific decisions occur?
* How should unsupported operations be identified?
* How should numerical semantics survive lowering?
* How should optimization passes communicate assumptions?

---

## 20. Clean-Room Research Track D: Runtime Compatibility

A compatibility system requires more than kernel translation.

Research:

```text
Application
     │
     ▼
Expected Runtime API
     │
     ▼
Compatibility Layer
     │
     ▼
Native Runtime API
```

General concepts:

* Device discovery.
* Context creation.
* Streams.
* Events.
* Synchronization.
* Memory allocation.
* Memory copies.
* Module loading.
* Kernel launches.
* Device properties.
* Errors.
* Resource lifetime.

Possible Aesir lesson:

> Hardware-facing runtime APIs should sit behind stable Aesir capability interfaces.

---

## 21. Clean-Room Research Track E: Library Mediation

AI software often depends on libraries rather than raw kernels.

Concept:

```text
CUDA application
      │
      ▼
Expected CUDA library
      │
      ▼
Compatibility mediation
      │
      ▼
Native vendor library
```

Study the general problem of mapping:

```text
Interface A
    ↓
Semantic adapter
    ↓
Interface B
```

Research dimensions:

* Argument translation.
* Handle management.
* Descriptor conversion.
* Data layouts.
* Precision support.
* Algorithm selection.
* Workspace requirements.
* Error mapping.
* Capability mismatches.
* Performance differences.

---

## 22. Aesir Library Broker

A future Aesir concept could be:

```text
Aesir Library Broker
        │
        ├── NVIDIA libraries
        ├── AMD libraries
        ├── ThunderKittens
        ├── HipKittens
        ├── ZLUDA compatibility
        └── Native Aesir
```

The broker should select functionality by capabilities rather than by brand name alone.

---

## 23. Clean-Room Research Track F: Compilation Cache

Translated or JIT-compiled GPU code should not be unnecessarily rebuilt.

Research:

```text
Source
  │
  ▼
Compiler
  │
  ▼
Target Binary
  │
  ▼
Cache
```

Cache keys may need to consider:

```text
source hash
compiler version
backend version
GPU architecture
driver
optimization configuration
precision
feature flags
```

Aesir should investigate an original compilation cache.

Possible location:

```text
~/.aesir/kernel-cache/
```

---

## 24. Cache Integrity

Cached GPU binaries must never be blindly trusted.

Validate:

* Architecture.
* Driver compatibility.
* Compiler version.
* Backend version.
* Build flags.
* Kernel specification.
* Hashes.
* ABI version.

If uncertain:

```text
invalidate
   ↓
recompile
```

Correctness is more important than avoiding compilation.

---

## 25. Clean-Room Research Track G: Compiler Diagnostics

A cross-hardware system needs excellent errors.

Bad:

```text
Kernel failed.
```

Good:

```text
AESIR_GPU_TRANSLATION_FAILURE

Operation:
attention_decode

Requested backend:
ZLUDA

GPU:
AMD <architecture>

Reason:
Required instruction capability unavailable.

Fallback:
HipKittens attention backend selected.
```

Aesir should develop structured diagnostics for:

* Compilation failure.
* Unsupported instruction.
* Unsupported library.
* Unsupported precision.
* Runtime mismatch.
* Architecture mismatch.
* Numerical validation failure.
* Performance rejection.

---

## 26. Clean-Room Research Track H: Correctness Translation

Translation must preserve semantics, not merely produce executable code.

Research:

* Floating-point rounding.
* Denormal handling.
* Atomics.
* Memory ordering.
* Barrier semantics.
* Warp/wave assumptions.
* Integer overflow behavior.
* Conversion rules.
* Approximation instructions.
* Matrix precision.
* Undefined behavior.

A translated kernel that runs but produces incorrect tensors is a failed translation.

---

## 27. Numerical Equivalence Framework

Classify results:

```text
EXACT
NUMERICALLY_EQUIVALENT
MODEL_EQUIVALENT
DEGRADED
INCORRECT
```

Evaluate with:

```text
absolute error
relative error
ULP difference
model logits
token sequence stability
attention output
long-context stability
```

---

## 28. ZLUDA Benchmark Matrix

Every important workload should ideally have several paths.

```text
                    NVIDIA                AMD
                      │                    │
         ┌────────────┴─────────┐    ┌─────┴─────────────┐
         ▼                      ▼    ▼                   ▼
    Native CUDA        ThunderKittens Native ROCm/HIP HipKittens
                                               │
                                               ▼
                                             ZLUDA
```

Where possible, compare:

1. CPU reference.
2. Native CUDA.
3. ThunderKittens.
4. Native Aesir NVIDIA.
5. Native ROCm/HIP.
6. HipKittens.
7. Native Aesir AMD.
8. ZLUDA-translated CUDA.

---

## 29. Translation Tax Metric

Create an Aesir metric:

```text
Translation Tax
```

Example:

```text
Native AMD kernel:
100 µs

Equivalent CUDA through ZLUDA:
118 µs

Translation Tax:
18%
```

But also measure when translated execution unexpectedly performs well.

Translation may occasionally expose optimization opportunities or use highly optimized underlying libraries.

Never assume the translated path must be slower.

Measure it.

---

## 30. Compatibility Value Metric

Performance alone does not describe ZLUDA's usefulness.

A kernel that runs at 85% of native performance may still be extremely valuable if the alternative is:

```text
unsupported
```

Therefore evaluate:

```text
Compatibility Value =
availability
+ correctness
+ performance
+ maintenance reduction
```

---

## 31. ThunderKittens Intersection Research

The existing ThunderKittens roadmap remains unchanged.

This roadmap may independently research one important question:

> **What happens when highly NVIDIA-specific CUDA optimization encounters a cross-vendor compatibility layer?**

This is a research question, not an expected production architecture.

---

## 32. ThunderKittens Through ZLUDA

Possible experimental path:

```text
ThunderKittens kernel
        │
        ▼
CUDA / PTX
        │
        ▼
ZLUDA
        │
        ▼
AMD
```

This path must **not** be assumed to work.

ThunderKittens may depend heavily on NVIDIA-specific hardware characteristics.

The research value comes from identifying where portability breaks.

---

## 33. ThunderKittens/ZLUDA Research Questions

Investigate:

* Which CUDA constructs translate cleanly?
* Which architecture-specific operations fail?
* Which scheduling assumptions depend on NVIDIA warps?
* Which memory patterns remain portable?
* Which tensor operations depend directly on NVIDIA matrix hardware?
* Which optimization principles survive translation?
* Which optimizations become harmful on AMD?
* Which kernels execute correctly but poorly?
* Which kernels cannot be represented meaningfully on the target architecture?

The answer "this should never be translated" is a valid research result.

---

## 34. Portability Classification

Classify CUDA kernels by portability.

```text
LEVEL 0
Generic GPU computation

LEVEL 1
CUDA runtime dependent

LEVEL 2
CUDA library dependent

LEVEL 3
PTX-specific

LEVEL 4
NVIDIA architecture optimized

LEVEL 5
NVIDIA-generation-specific
```

The higher the level, the less suitable the workload may be for transparent translation.

This classification could help Aesir choose between:

```text
translate
replace
recompile
route elsewhere
reject
```

---

## 35. HipKittens Intersection Research

HipKittens provides something extremely important to the ZLUDA research program:

> A native AMD comparison point.

Conceptually:

```text
Same conceptual operation
          │
    ┌─────┴─────┐
    │           │
    ▼           ▼
CUDA kernel   HipKittens
    │           │
    ▼           │
 ZLUDA          │
    │           │
    └─────┬─────┘
          ▼
        AMD GPU
```

This allows Aesir to compare:

```text
translated NVIDIA-oriented execution
vs.
native AMD-oriented execution
```

---

## 36. ZLUDA vs. HipKittens Research Questions

Measure:

* Execution latency.
* Compilation latency.
* Memory bandwidth.
* LDS/shared-memory usage.
* Register pressure.
* Occupancy.
* Wave utilization.
* Matrix-unit utilization.
* Cache behavior.
* Memory transactions.
* Synchronization cost.
* Power consumption.
* Numerical behavior.

The goal is to understand:

> Where does hardware-native restructuring become more valuable than compatibility translation?

---

## 37. The Translation Boundary

A major research objective should be discovering this boundary:

```text
                CUDA-compatible workload
                         │
                         ▼
                 ZLUDA works well
                         │
                         ▼
               increasing specialization
                         │
                         ▼
                 translation weakens
                         │
                         ▼
              native AMD implementation
                  becomes preferable
```

Aesir should learn to recognize that boundary automatically.

---

## 38. Compatibility-to-Native Migration

One particularly valuable future feature would be gradual migration.

Example:

```text
CUDA Plugin
   │
   ▼
Entire plugin via ZLUDA
   │
   ▼
Profile
   │
   ▼
Identify hotspot
   │
   ▼
Replace hotspot with native AMD implementation
   │
   ▼
Remaining CUDA continues through ZLUDA
```

Eventually:

```text
90% translated
      ↓
70%
      ↓
30%
      ↓
0%
```

This could make hardware portability incremental rather than all-or-nothing.

---

## 39. Hybrid Execution Research

Investigate whether an Aesir workload could safely contain:

```text
native AMD operator
        ↓
ZLUDA operator
        ↓
HipKittens operator
        ↓
native AMD operator
```

Research requirements include:

* Tensor ownership.
* Memory compatibility.
* Stream interoperability.
* Synchronization.
* Device pointers.
* Event semantics.
* Lifetime management.
* Error propagation.

Do not implement hybrid execution until memory and synchronization semantics are understood.

---

## 40. Tensor Residency

One central performance question is:

> Can tensors remain resident on the GPU while execution changes between providers?

Bad:

```text
AMD GPU
   ↓
Host
   ↓
ZLUDA
   ↓
AMD GPU
   ↓
Host
   ↓
HipKittens
   ↓
AMD GPU
```

Desired:

```text
AMD VRAM
   │
   ├── ZLUDA operation
   │
   ├── Native operation
   │
   └── HipKittens operation
```

Avoid unnecessary host round trips.

---

## 41. Unified Aesir Device Memory

Long-term research should explore an Aesir-owned abstraction:

```text
AesirDeviceBuffer
```

Conceptual metadata:

```text
device
allocation
size
alignment
ownership
backend_visibility
dtype
layout
lifetime
synchronization_state
```

Different execution providers could operate on the same logical allocation when interoperability permits.

---

## 42. Provider Boundary

External providers must never own Aesir architecture.

The relationship should remain:

```text
Aesir
  │
  ▼
Provider Adapter
  │
  ▼
External Technology
```

Not:

```text
External Technology
        │
        ▼
     Aesir Core
```

---

## 43. JIT Compilation Research

ZLUDA-related study should include the broader JIT compilation problem.

Research:

```text
IR
 │
 ▼
specialization
 │
 ▼
optimization
 │
 ▼
architecture lowering
 │
 ▼
machine code
```

Possible specialization dimensions:

* GPU architecture.
* Tensor shape.
* Head dimension.
* Sequence length.
* Precision.
* Quantization.
* Batch.
* Tile geometry.
* Memory layout.

---

## 44. Ahead-of-Time vs. Just-in-Time

Aesir should eventually support both when beneficial.

### Ahead-of-Time

Best for:

* Known kernels.
* Stable architectures.
* Packaged releases.
* Fast startup.

### Just-in-Time

Best for:

* Shape specialization.
* New GPUs.
* Dynamic workloads.
* Experimental kernels.
* Auto-tuning.

A hybrid model may be strongest.

---

# 45. Translation Cache Research

A future workflow could be:

```text
CUDA/PTX workload
      │
      ▼
Compatibility compiler
      │
      ▼
AMD binary
      │
      ▼
Aesir cache
      │
      ▼
future execution
```

Aesir should investigate whether provider-specific compiled artifacts can be indexed through its general cache infrastructure without assuming ownership of the external compiler.

---

## 46. Compile-once Profiling

Compilation time can obscure inference benchmarks.

Track separately:

```text
cold startup
warm startup
first compilation
cached compilation
steady-state inference
```

Never mix compilation latency with token-generation latency unless measuring end-user startup performance.

---

## 47. Aesir Performance Database Integration

The existing concept of a performance database can include ZLUDA.

Possible record:

```text
GPU:
AMD architecture X

Operation:
attention_prefill

Shape:
...

Provider:
ZLUDA

Source backend:
CUDA implementation Y

Compile time:
...

Warm latency:
...

Correctness:
validated

Confidence:
high
```

---

## 48. Automatic Provider Selection

Eventually:

```text
Request
   │
   ▼
Aesir Cost Model
   │
   ├── correctness
   ├── compatibility
   ├── measured latency
   ├── memory requirements
   ├── compile cost
   ├── current GPU
   └── workload shape
   │
   ▼
Selected Provider
```

ZLUDA becomes one candidate among many.

---

## 49. Failure Recovery

A compatibility failure should not necessarily terminate inference.

Example:

```text
ZLUDA launch
     │
     ▼
Unsupported kernel
     │
     ▼
Mark combination unsupported
     │
     ▼
Invalidate route
     │
     ▼
Select native AMD fallback
     │
     ▼
Continue inference
```

Cache the failure so Aesir does not repeatedly retry a known-incompatible path.

---

## 50. Negative Capability Database

Aesir should remember what does **not** work.

Example:

```text
GPU:
gfxXXXX

Provider:
ZLUDA

Kernel:
foo_attention

Configuration:
head_dim = 256

Result:
unsupported

Reason:
instruction capability

Retry:
false
```

Negative knowledge can save considerable startup time.

---

## 51. Research Provenance

Create:

```text
research/zluda/PROVENANCE.md
```

Every research finding should record:

```text
date
research question
sources consulted
hardware used
software versions
observed behavior
general principle extracted
clean specification generated
Aesir experiment created
benchmark result
implementation commit
```

---

## 52. Recommended Research Directory

```text
research/
└── zluda/
    ├── README.md
    ├── PROVENANCE.md
    ├── architecture/
    ├── ptx/
    ├── llvm/
    ├── runtime/
    ├── libraries/
    ├── compilation/
    ├── caching/
    ├── correctness/
    ├── diagnostics/
    ├── benchmarks/
    ├── thunderkittens-intersection/
    ├── hipkittens-intersection/
    └── clean-specifications/
```

---

## 53. Recommended Documentation

```text
docs/
├── ZLUDA_SUPPORT.md
├── ZLUDA_BACKEND_ARCHITECTURE.md
├── ZLUDA_COMPATIBILITY_POLICY.md
├── ZLUDA_CLEAN_ROOM_POLICY.md
├── ZLUDA_BENCHMARK_STANDARD.md
├── ZLUDA_DIAGNOSTICS.md
├── ZLUDA_FALLBACK_POLICY.md
├── ZLUDA_CACHE_POLICY.md
├── ZLUDA_PLUGIN_COMPATIBILITY.md
├── ZLUDA_SECURITY_CONSIDERATIONS.md
└── ZLUDA_KITTENS_INTERSECTION.md
```

---

## 54. Recommended Specifications

```text
specs/
└── compatibility/
    └── zluda/
        ├── provider-interface.md
        ├── capability-model.md
        ├── routing.md
        ├── error-model.md
        ├── cache.md
        ├── memory-interoperability.md
        └── benchmark-protocol.md
```

---

## 55. Recommended Experimental Code

```text
experiments/
└── zluda/
    ├── detection/
    ├── runtime/
    ├── ptx/
    ├── libraries/
    ├── inference/
    ├── llama/
    ├── tensor-sharing/
    ├── cache/
    ├── thunderkittens/
    └── hipkittens/
```

Experimental code should not automatically become production code.

---

## 56. Benchmark Models

Use several workload classes.

## Tiny Synthetic Tests

For:

* Compiler correctness.
* Instructions.
* Memory operations.
* Synchronization.

### Operator Tests

For:

* GEMM.
* GEMV.
* Attention.
* RMSNorm.
* RoPE.
* Activations.
* Quantized operations.

### Small Language Models

For:

* End-to-end validation.
* Rapid iteration.

### Larger Models

For:

* Memory pressure.
* Long context.
* Real inference behavior.

---

## 57. Prefill vs. Decode

Benchmark separately.

```text
PREFILL
large parallel workload
matrix-heavy
compute-heavy

DECODE
small repeated workload
memory-sensitive
launch-sensitive
KV-cache-sensitive
```

A compatibility layer may behave very differently between these phases.

---

## 58. Quantization Research

Test translation behavior for:

```text
FP32
FP16
BF16
FP8
INT8
INT4
mixed precision
```

Where unsupported, the provider should report lack of capability rather than silently changing precision.

---

## 59. Model Quality Validation

End-to-end testing should compare:

```text
reference logits
generated tokens
perplexity
long-context stability
attention output
sampling behavior
```

Performance wins do not justify corrupted model behavior.

---

## 60. Security Boundary

Compatibility technologies that interact with binaries, libraries, runtime loading, or process environments require explicit trust boundaries.

Aesir should:

* Never execute arbitrary discovered binaries automatically.
* Require explicit plugin registration.
* Validate file paths.
* Record backend provenance.
* Distinguish trusted and untrusted providers.
* Avoid silently modifying unrelated processes.
* Keep compatibility execution scoped to Aesir-managed workloads.

---

## 61. Dependency Boundary

ZLUDA should remain external.

Recommended conceptual model:

```text
Project Aesir
     │
     ▼
Aesir ZLUDA Adapter
     │
     ▼
Installed ZLUDA
```

Avoid copying ZLUDA source into the Aesir repository.

This keeps:

* Provenance clear.
* Upgrades manageable.
* Clean-room boundaries understandable.
* Licensing boundaries cleaner.
* Native Aesir code independent.

---

## 62. License Discipline

Before distributing integration components:

1. Verify the current ZLUDA license.
2. Verify licenses of any redistributed components.
3. Preserve required notices.
4. Document external dependencies.
5. Keep third-party code separate.
6. Record versions.
7. Do not assume compatibility with one component grants redistribution rights for everything around it.

Clean-room development and open-source licensing are related concerns, but they are not the same concern.

---

## 63. Phase 0: Policy and Architecture

Deliverables:

* [ ] `ZLUDA_CLEAN_ROOM_POLICY.md`
* [ ] `ZLUDA_BACKEND_ARCHITECTURE.md`
* [ ] `ZLUDA_COMPATIBILITY_POLICY.md`
* [ ] `research/zluda/PROVENANCE.md`
* [ ] Provider interface specification.
* [ ] Capability descriptor specification.
* [ ] Fallback policy.
* [ ] Benchmark methodology.

No performance work should begin before these boundaries exist.

---

## 64. Phase 1: Environment Detection

Implement:

```text
detect ZLUDA
detect AMD GPU
detect compatible runtime
detect provider version
detect available libraries
report capabilities
```

Success condition:

> Aesir can accurately say whether ZLUDA execution is available without attempting model inference.

---

## 65. Phase 2: Minimal Compatibility Test

Start with the smallest possible CUDA workload.

Example:

```text
vector add
```

Validate:

```text
input
  ↓
CUDA workload
  ↓
ZLUDA
  ↓
AMD
  ↓
result
  ↓
CPU reference comparison
```

Success condition:

> The complete Aesir → ZLUDA → AMD execution path works and produces validated output.

---

## 66. Phase 3: Memory Operations

Test:

* Allocation.
* Free.
* Host-to-device copy.
* Device-to-host copy.
* Device-to-device copy.
* Synchronization.
* Streams.
* Events.

This phase is mandatory before AI operators.

---

## 67. Phase 4: GEMM

Use matrix multiplication as the first AI-oriented test.

Compare:

```text
ZLUDA CUDA
Native ROCm/HIP
Aesir native AMD
HipKittens where applicable
CPU reference
```

Measure:

* Correctness.
* Cold compilation.
* Warm latency.
* Throughput.
* Memory.
* Power.
* Stability.

---

## 68. Phase 5: Inference Operators

Expand to:

```text
GEMV
RMSNorm
RoPE
Softmax
Activation
Attention
KV-cache operations
Quantized matrix operations
```

Each operator should receive an individual compatibility record.

---

## 69. Phase 6: Small Model Inference

Run a small transformer end to end.

Measure:

```text
model load
prefill
time to first token
decode
tokens/sec
VRAM
compilation
cache reuse
correctness
```

---

## 70. Phase 7: External CUDA AI Workloads

Test selected CUDA-oriented tools through Aesir's compatibility harness.

The goal is not to support everything.

The goal is to understand:

* What works.
* What fails.
* Why it fails.
* What can safely fall back.

---

## 71. Phase 8: HipKittens Comparison

For equivalent AMD workloads:

```text
ZLUDA-translated CUDA
          vs.
HipKittens-native AMD
```

Profile both.

Document where native redesign matters.

This phase directly feeds Aesir's routing heuristics.

---

## 72. Phase 9: ThunderKittens Compatibility Experiments

Only after basic ZLUDA functionality is stable.

Test carefully selected ThunderKittens kernels.

Classify outcomes:

```text
works correctly
works slowly
partially supported
compile failure
runtime failure
architecture incompatible
```

Do not make ThunderKittens-through-ZLUDA a required production path.

Its primary value is research.

---

## 73. Phase 10: Translation Boundary Model

Use accumulated benchmark data to build a heuristic model:

```text
generic CUDA
      │
      ▼
translation attractive

moderately specialized
      │
      ▼
benchmark required

architecture optimized
      │
      ▼
native backend preferred

generation-specific
      │
      ▼
translation rejected
```

---

## 74. Phase 11: Automatic Routing

Teach Aesir to choose between:

```text
native AMD
HipKittens
ZLUDA
CPU
```

based on:

* Capability.
* Correctness history.
* Benchmark history.
* Shape.
* Precision.
* Model.
* GPU architecture.

---

## 75. Phase 12: Hybrid Provider Research

Experiment with keeping tensors resident while switching between:

```text
ZLUDA
native AMD
HipKittens
```

Do not promote this to production until memory interoperability and synchronization are proven.

---

## 76. Phase 13: Aesir IR Lessons

Review all research findings.

Ask:

* What should Aesir's IR express?
* What should remain hardware-independent?
* Where should lowering occur?
* What needs capability metadata?
* What needs explicit memory semantics?
* What needs numerical semantics?

Then update **Aesir's own IR specification**, not ZLUDA-derived code.

---

## 77. Phase 14: Independent Aesir Compiler Research

Only after clean specifications exist.

Potential research areas:

```text
Aesir Graph IR
     ↓
Tensor IR
     ↓
Device IR
     ↓
target-specific lowering
```

Possible targets:

```text
CPU
NVIDIA
AMD
future accelerators
```

Any implementation should originate from Aesir specifications and hardware documentation.

---

## 78. Phase 15: Performance Learning

Integrate ZLUDA into Aesir's performance knowledge system.

Conceptually:

```text
Aesir runs workload
       │
       ▼
tries valid providers
       │
       ▼
benchmarks
       │
       ▼
records winner
       │
       ▼
future runs use best route
```

---

## 79. Phase 16: Self-Optimizing Compatibility

Long-term goal:

```text
New AMD GPU detected
       │
       ▼
Aesir discovers capabilities
       │
       ▼
benchmarks native + compatibility paths
       │
       ▼
builds local performance profile
       │
       ▼
selects optimal providers
```

The system adapts to the hardware instead of relying entirely on hardcoded assumptions.

---

## 80. Cross-Roadmap Knowledge Exchange

The existing Kittens roadmap and this roadmap may exchange only clearly abstract findings.

Example:

```text
ThunderKittens Research
"Tile reuse reduces memory traffic"
          │
          ▼
Aesir Knowledge Base


HipKittens Research
"AMD requires different scheduling"
          │
          ▼
Aesir Knowledge Base


ZLUDA Research
"Compatibility becomes weaker with
increasing hardware specialization"
          │
          ▼
Aesir Knowledge Base
```

The shared knowledge base contains principles, not copied implementation.

---

## 81. Three-Way Research Model

Together, the projects illuminate different dimensions.

```text
                     GPU EXECUTION RESEARCH
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
 ThunderKittens          HipKittens             ZLUDA
          │                   │                   │
          ▼                   ▼                   ▼
 NVIDIA-native           AMD-native          Cross-vendor
 optimization            optimization        compatibility
          │                   │                   │
          └───────────────────┼───────────────────┘
                              ▼
                       AESIR RESEARCH
                              │
                              ▼
                   Original Architecture
```

---

## 82. Questions Aesir Should Ask Continuously

For every workload:

```text
Can it run?

Is it correct?

Is it native?

Is translation appropriate?

How much does translation cost?

Would native redesign be faster?

Can memory remain resident?

Can the operation be fused?

Does architecture specialization break portability?

Can Aesir route around the limitation?

What principle can Aesir learn from this?
```

---

## 83. What ZLUDA Should Not Become

ZLUDA should not become:

* A mandatory AMD backend.
* A replacement for HipKittens.
* A replacement for native ROCm/HIP.
* A replacement for Aesir's native AMD development.
* A replacement for ThunderKittens.
* A substitute for hardware-aware optimization.
* A reason to assume CUDA is universal.
* A dependency of Aesir's core model runtime.
* A shortcut around clean-room engineering.

---

## 84. What ZLUDA Should Become

Within Aesir, ZLUDA can become:

* A compatibility provider.
* A CUDA workload bridge.
* A research tool.
* A translation benchmark.
* A portability experiment.
* A fallback mechanism.
* A migration mechanism.
* A source of compiler architecture questions.
* A source of runtime architecture questions.
* A valuable comparison against native AMD execution.

---

## 85. Definition of Success

This roadmap succeeds when Project Aesir can:

* Detect ZLUDA reliably.
* Report ZLUDA capabilities.
* Execute supported workloads through it.
* Reject unsupported workloads cleanly.
* Fall back automatically.
* Benchmark translated execution.
* Compare translated CUDA against native AMD execution.
* Compare ZLUDA paths against HipKittens.
* Experiment with ThunderKittens compatibility without depending on it.
* Record positive and negative capability data.
* Cache appropriate compiled artifacts.
* Maintain numerical correctness.
* Keep external providers isolated from Aesir's core.
* Preserve strict clean-room provenance.
* Extract architectural lessons without copying implementation.
* Feed those lessons into original Aesir IR and runtime research.

---

## 86. Long-Term Architecture

A mature Aesir could eventually resemble:

```text
                         PROJECT AESIR
                              │
                              ▼
                         Model Graph
                              │
                              ▼
                           Aesir IR
                              │
                              ▼
                    Optimization Planner
                              │
                              ▼
                      Capability Router
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
         CPU                NVIDIA               AMD
          │                   │                   │
          │          ┌────────┴────────┐   ┌──────┴────────┐
          │          │                 │   │               │
          ▼          ▼                 ▼   ▼               ▼
        Native     Native       ThunderKittens Native  HipKittens
                                                 │
                                      ┌──────────┴──────────┐
                                      │                     │
                                      ▼                     ▼
                              Native execution       ZLUDA compatibility
                                      │                     │
                                      └──────────┬──────────┘
                                                 ▼
                                          Performance DB
                                                 │
                                                 ▼
                                          Best Execution
```

---

## 87. Long-Term Compiler Vision

The deepest lesson Aesir may eventually take from this research is the value of separating:

```text
WHAT must be computed
```

from:

```text
HOW a particular machine computes it
```

A possible future:

```text
                         Aesir Model
                              │
                              ▼
                         Graph IR
                              │
                              ▼
                        Tensor IR
                              │
                              ▼
                        Device IR
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
             CPU            NVIDIA           AMD
              │               │               │
              ▼               ▼               ▼
           Machine         Machine         Machine
            Code            Code            Code
```

Compatibility providers such as ZLUDA remain available around this architecture when existing software expects another ecosystem.

Aesir therefore gains both:

```text
native execution
       +
compatibility execution
```

rather than being forced to choose one philosophy.

---

## 88. Guiding Principle

The central principle of this roadmap is:

> **Use ZLUDA when compatibility is valuable. Study ZLUDA when its engineering reveals broader ideas. Benchmark it against native execution. Never confuse translation with native optimization. Never copy implementation when a principle can instead be understood and independently engineered.**

---

## 89. Relationship to the Existing Kittens Roadmap

The final boundary is explicit:

```text
THUNDERKITTENS / HIPKITTENS ROADMAP
        │
        │ Native kernel optimization research
        │
        └────────────────────────────┐
                                     │
                                     ▼
                              Shared Principles
                                     ▲
                                     │
        ┌────────────────────────────┘
        │
        │ Cross-vendor compatibility research
        │
ZLUDA ROADMAP
```

Neither roadmap replaces the other.

Neither roadmap absorbs the other.

Neither roadmap should be rewritten merely because discoveries occur in the other.

They are **parallel research programs** that occasionally exchange validated, abstract engineering knowledge.

---

## 90. Final Research Philosophy

Project Aesir should approach ZLUDA from three perspectives simultaneously:

```text
USE IT
when it gives Aesir useful compatibility.

MEASURE IT
to understand the actual cost and value of translation.

STUDY IT
to understand cross-vendor compiler and runtime problems.
```

Then:

```text
ABSTRACT THE LESSON
        │
        ▼
WRITE A CLEAN SPECIFICATION
        │
        ▼
DESIGN AN AESIR SOLUTION
        │
        ▼
IMPLEMENT IT INDEPENDENTLY
        │
        ▼
BENCHMARK IT
        │
        ▼
KEEP IT ONLY IF IT IS BETTER
```

That cycle allows ZLUDA, ThunderKittens, HipKittens, vendor documentation, academic research, and hardware profiling to act as **teachers** without becoming the architecture of Project Aesir.

The final architecture remains Aesir's own.

**Compatibility where useful. Native execution where superior. Clean-room research everywhere. Measure everything.**
