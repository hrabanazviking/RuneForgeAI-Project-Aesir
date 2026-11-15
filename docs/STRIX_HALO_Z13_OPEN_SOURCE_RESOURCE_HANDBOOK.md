# Strix Halo + ASUS ROG Flow Z13 (2025): Open-Source AI & Linux Resource Handbook

**A field guide to the Ryzen AI MAX+ 395, Radeon 8060S, XDNA 2 NPU, Linux enablement, local inference, AI-agent development, performance engineering, and communities**

> **Reviewed:** 2026-11-15  
> **Intended device:** ASUS ROG Flow Z13 (2025), GZ302EA / GZ302 family, AMD Ryzen AI MAX+ 395, Radeon 8060S, up to 128 GB LPDDR5X unified memory  
> **Also relevant to:** Other AMD Strix Halo / Ryzen AI MAX and MAX+ devices, subject to differences in firmware, power limits, ports, and cooling  
> **Primary emphasis:** Native Linux, open-source software, local/private AI, AI-assisted engineering, reproducibility, and safe optimization  
> **Status:** Independent community resource, **not** an AMD/ASUS/Gufo support document; links, hardware-support claims, model availability, and software versions can change rapidly.

**Why this guide exists.** Strix Halo can be an exceptional compact local-AI workstation, but a spectacular hardware specification is not the same as a mature software stack. Kernel support, firmware, memory management, ROCm, HIP, Vulkan, NPU drivers, model-specific kernels, power management, and thermal design all influence what actually works. This guide organizes the projects that make the machine useful, the communities that improve it, and the engineering practices that keep it stable.

The goal is **not** to tell every owner to install everything. In fact, mixing multiple power-control daemons, ROCm stacks, and unofficial memory tweaks is a reliable way to make troubleshooting worse. Instead, choose a conservative, measurable path from **working hardware** to **fast inference** to **higher-level AI agents**.

---

## Contents

1. [The machine and why it is unusual](#1-the-machine-and-why-it-is-unusual)
2. [A map of the software ecosystem](#2-a-map-of-the-software-ecosystem)
3. [Start with authoritative documentation](#3-start-with-authoritative-documentation)
4. [Linux support for the exact ASUS GZ302](#4-linux-support-for-the-exact-asus-gz302)
5. [Strix Halo community toolboxes and setup references](#5-strix-halo-community-toolboxes-and-setup-references)
6. [Specialized inference engines](#6-specialized-inference-engines)
7. [Gufo in depth: the Strix Halo-native path](#7-gufo-in-depth-the-strix-halo-native-path)
8. [AMD GPU programming: ROCm, HIP, Vulkan, and profiling](#8-amd-gpu-programming-rocm-hip-vulkan-and-profiling)
9. [XDNA 2 NPU development: IRON, MLIR-AIE, XRT](#9-xdna-2-npu-development-iron-mlir-aie-xrt)
10. [Image, video, audio, and multimodal AI](#10-image-video-audio-and-multimodal-ai)
11. [Personal AI agents and higher-level development](#11-personal-ai-agents-and-higher-level-development)
12. [Positive communities and places to collaborate](#12-positive-communities-and-places-to-collaborate)
13. [A stability-first Linux checklist](#13-a-stability-first-linux-checklist)
14. [Read-only diagnostics and baseline collection](#14-read-only-diagnostics-and-baseline-collection)
15. [How to benchmark runners fairly](#15-how-to-benchmark-runners-fairly)
16. [A practical adoption roadmap](#16-a-practical-adoption-roadmap)
17. [A contribution playbook for human + AI teams](#17-a-contribution-playbook-for-human--ai-teams)
18. [Security, privacy, and licenses](#18-security-privacy-and-licenses)
19. [Common failure patterns and troubleshooting questions](#19-common-failure-patterns-and-troubleshooting-questions)
20. [Quick-reference resource directory](#20-quick-reference-resource-directory)
21. [Templates: machine profile, benchmarks, and issue reports](#21-templates-machine-profile-benchmarks-and-issue-reports)
22. [Glossary, curation rules, and maintenance](#22-glossary-curation-rules-and-maintenance)

---

## 1. The machine and why it is unusual

### 1.1 Reference hardware

| Component | Reference specification | Why it matters |
|---|---|---|
| APU | AMD Ryzen AI MAX+ 395, *Strix Halo* | CPU, large GPU, and NPU on an unusually integrated platform |
| CPU | 16 Zen 5 cores / 32 threads | Host-side inference, model orchestration, preprocessing, compilation, and development |
| GPU | Radeon 8060S, RDNA 3.5, 40 compute units | HIP/ROCm and Vulkan inference, diffusion and matrix workloads |
| ROCm target | `gfx1151` | Crucial for correct compiler libraries, binaries, kernels, and performance comparisons |
| NPU | AMD XDNA 2 | Separate accelerator accessed through `amdxdna`, XRT, and compiled NPU designs |
| Memory | Up to 128 GB LPDDR5X-8000 unified RAM | Large local model weights and agent workloads without a large discrete-VRAM card |
| Specific portable platform | ASUS ROG Flow Z13 (2025) GZ302 | Chassis-specific firmware, EC, display, detachable keyboard, fans, power and input behavior |
| OS focus | Modern Linux / Kubuntu | Hardware enablement, AMD open drivers, native inference and developer tools |

**Primary specifications:** [AMD Ryzen AI MAX+ 395 product page](https://www.amd.com/en/products/processors/laptop/ryzen/ai-300-series/amd-ryzen-ai-max-plus-395.html), [AMD ROCm GPU specifications](https://rocm.docs.amd.com/en/latest/reference/gpu-specs.html). Device-specific limits can be **lower than the processor's general advertised cTDP**, because a thin tablet chassis has its own thermal and electrical constraints.

### 1.2 Unified memory does not mean “128 GB of dedicated VRAM”

This is perhaps the most important architectural detail to understand:

- CPU and GPU can access memory drawn from the same physical LPDDR5X pool.
- A fixed firmware/BIOS UMA carveout, dynamically mapped GPU allocations, `amdgpu` GTT/GPUVM behavior, process limits, pinned buffers, and ordinary host memory **are different things**.
- A model *fitting in system RAM* does **not** guarantee an inference engine can allocate it, place it efficiently, retain KV cache, or execute every operation on the GPU.
- Excessive pinning or artificially restrictive memory settings can cause allocation failures or system instability.
- The NPU is another accelerator with its own execution and memory constraints; it is not automatically a second GPU.

Start with [AMD's Strix Halo system optimization guide](https://rocm.docs.amd.com/en/latest/reference/system-optimization/rdna3-5.html) (or the [7.2 historical revision](https://rocm.docs.amd.com/en/docs-7.2.0/how-to/system-optimization/strixhalo.html)) before touching kernel memory parameters. Prefer current documentation matching the installed ROCm version.

### 1.3 The four actual performance constraints

1. **Memory capacity:** Can weights, runtime buffers, KV cache, other apps, and the OS fit safely?
2. **Memory bandwidth and locality:** How often are large weights accessed, and is computation actually on the GPU?
3. **GPU kernel quality:** Are operations fused, quantized, parallelized, and compiled for `gfx1151`?
4. **Sustained chassis power/thermals:** Does a fast short benchmark remain fast after 20 to 60 minutes?

The best model runner is model-, quantization-, workload-, context-, and software-version-dependent. Avoid a universal “fastest engine” claim without like-for-like measurements.

---

## 2. A map of the software ecosystem

```text
Higher-level applications and personal agents
  ├── Agent frameworks / coding agents / personal memory
  ├── Local chat and tool-calling applications
  └── Creative AI: image, audio, video, vision
                   │
Model serving / inference engines
  ├── Gufo + supported model extensions
  ├── llama.cpp and Strix Halo-specific forks
  ├── Ollama / LM Studio / Lemonade / vLLM (where supported)
  └── Experimental native engines and multi-node backends
                   │
Compute and compiler runtimes
  ├── ROCm / HIP / tuned RDNA 3.5 kernels
  ├── Mesa RADV / Vulkan compute
  ├── XRT / IRON / MLIR-AIE for the XDNA 2 NPU
  └── CPU execution, memory placement and scheduling
                   │
Linux kernel + linux-firmware + hardware controls
  ├── amdgpu, drm, GPUVM, user/group device access
  ├── amdxdna, /dev/accel/*, firmware
  ├── ASUS WMI / Armoury / HID / ACPI
  └── power, thermal, display, keyboard, audio, suspend
                   │
AMD Ryzen AI MAX+ 395 + ASUS ROG Flow Z13 GZ302
```

A failure at any layer can masquerade as a problem higher up. A model runner cannot compensate for a missing GPU device node or an unstable memory configuration.

---

## 3. Start with authoritative documentation

| Reference | What to read it for | Priority |
|---|---|---|
| [AMD Ryzen AI MAX+ 395](https://www.amd.com/en/products/processors/laptop/ryzen/ai-300-series/amd-ryzen-ai-max-plus-395.html) | CPU/GPU specification, memory design, nominal limits | Essential |
| [AMD ROCm GPU specifications](https://rocm.docs.amd.com/en/latest/reference/gpu-specs.html) | Confirm `gfx1151`, 40 CUs, wavefront characteristics | Essential |
| [AMD RDNA 3.5 / Strix Halo optimization](https://rocm.docs.amd.com/en/latest/reference/system-optimization/rdna3-5.html) | GPUVM, memory configuration, optimization caveats | Essential |
| [ROCm main documentation](https://rocm.docs.amd.com/) | HIP, install, compatibility matrices, profiling | Essential |
| [AMD Ryzen AI software](https://www.amd.com/en/products/software/ryzen-ai-software.html) | NPU tools and developer resources | High |
| [Strix Halo HomeLab Wiki](https://strixhalo.wiki/) | Community hardware, AI, clustering, monitoring, guides | High |
| [Gufo documentation](https://gufo.blog/docs) | Gufo releases, builds, models, serving, cache and troubleshooting | High |
| [ASUS Linux community](https://asus-linux.org/) | General ROG-specific Linux enablement and people to ask | High |

**Rule:** Before applying advice, note whether it refers to a desktop Strix Halo system, a specific GZ302 tablet, a different distro, a different Linux kernel, or a different ROCm release. Shared APU does not imply identical firmware behavior.

---

## 4. Linux support for the exact ASUS GZ302

### 4.1 z13ctl: device-specific control

**Project:** [dahui/z13ctl](https://github.com/dahui/z13ctl)  
**Documentation:** [z13ctl website](https://dahui.github.io/z13ctl/) / [installation](https://dahui.github.io/z13ctl/installation/)

A Linux service/CLI for the 2025 ASUS ROG Flow Z13. Functions documented by its maintainers include:

- ASUS-specific performance profiles and power/TDP control.
- Fan curves, power behavior, battery charge limits.
- Keyboard and light-bar RGB through HID.
- Display options and reapplication of volatile settings after suspend/resume.
- **Optional CPU undervolting**, using a compatible `ryzen_smu` fork, when installed and deliberately configured.

**What matters:** Fan curves and sustained TDP affect AI inference significantly. Changes should be conservative, especially in the thin GZ302 chassis.

**Cautions:**

- Do not run multiple competing controllers that write the same ASUS power, fan, or EC settings.
- Avoid untested undervolts as a route to speed: passing one benchmark does not establish stability.
- Do not assume a package aimed at a different ROG model controls the GZ302 correctly.

### 4.2 z13gui: graphical front end

**Project:** [dahui/z13gui](https://github.com/dahui/z13gui)  
**Documentation:** [z13gui website](https://dahui.github.io/z13gui/)

A GTK graphical interface to `z13ctl`, useful for a touch-screen Z13 and for Linux desktop users who would rather adjust profiles, fan curves and battery limits visually. It is a frontend to the same hardware controller, not an independent kernel driver.

### 4.3 Z13 setup collections: valuable but review before use

- [th3cavalry/strix-halo-linux-setup](https://github.com/th3cavalry/strix-halo-linux-setup) — **ARCHIVED / READ-ONLY since 2026-08-19**. Historical reference for GZ302 fixes and diagnostics; **not** a maintained one-click source of truth.
- [mantkiew/GZ302-Linux-Setup](https://github.com/mantkiew/GZ302-Linux-Setup) — community GZ302 setup toolkit based around hardware fixes and `z13ctl`; inspect supported distro, target kernels, and the exact scripts before executing anything as root.
- [ASUS Linux](https://asus-linux.org/) — broader ASUS ROG Linux ecosystem and community. Its projects are not automatically interchangeable with GZ302-specific controls.

**Recommended approach:** When an issue appears, first find the smallest driver/firmware/device fix relevant to it. Do not repeatedly run entire setup scripts over an otherwise working installation.

### 4.4 Things to verify on the GZ302

- Correct keyboard and detachable input behavior.
- Wi-Fi chipset/firmware, especially after kernel updates.
- Internal audio and speaker behavior.
- OLED/display brightness, suspend and wake.
- Power profiles, thermal limits, fan behavior and battery limit.
- `amdgpu` and ROCm visibility.
- `amdxdna` and XRT visibility if NPU usage is required.
- Reliable behavior with USB hubs, docks, external SSDs, Ethernet adapters and VR peripherals.

---

## 5. Strix Halo community toolboxes and setup references

### 5.1 AMD Strix Halo Toolboxes

**Project:** [kyuz0/amd-strix-halo-toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes)  
**Purpose:** Community-curated ROCm/Vulkan inference environments and practical Strix Halo deployment patterns.

Useful for comparing different inference backends without constantly rebuilding a global Linux installation. Follow its current compatibility notes for the exact container/runtime arrangement.

**Warning:** Reproducible containers can help isolate user-space dependencies, but they do **not** replace a functioning host kernel, GPU driver, firmware, or device permissions.

### 5.2 AI Toolbox Cockpit

**Project:** [kyuz0/ai-toolbox-cockpit](https://github.com/kyuz0/ai-toolbox-cockpit)

An orchestration/dashboard project for managing local AI toolboxes, model-serving environments, and related workflows. Useful to people comparing more than one backend. Check its current supported engines and package/repository health before adopting it as a permanent management layer.

### 5.3 Practical host-serving notes

**Project:** [dinesh-se/strix-halo-llm-stack](https://github.com/dinesh-se/strix-halo-llm-stack)

A community configuration/reference collection around local LLM serving on the Ryzen AI MAX+ 395: router configuration, host tuning, watchdogs, measurements and known gotchas. Treat its configuration as **evidence to study**, not universal settings for every firmware revision.

### 5.4 Strix Halo HomeLab Wiki

**Site:** [strixhalo.wiki](https://strixhalo.wiki/)

Especially useful sections include local AI, llama.cpp with ROCm, vLLM, hardware monitoring, RDMA, clustering, power modes and fine-tuning. The wiki is also a gateway into the hardware community.

---

## 6. Specialized inference engines

### 6.1 What to select for a specific use case

| Engine or project | Design focus | Best reason to study/use it | Caveat |
|---|---|---|---|
| [Gufo](https://github.com/gufo-org/gufo) | Native Strix Halo `gfx1151` performance | High-throughput selected models and persistent agent serving | Curated model list; extensions/version constraints |
| [Gemma 4 Gufo extension](https://github.com/franzmoca/gemma4-gufo-extension) | Gemma 4 26B-A4B and 31B on Gufo | Optimized Gemma 4 on the exact AMD architecture | Separate community extension, not bundled by default |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | Broad GGUF inference | Widest practical experimental comparison baseline | Speed varies by HIP/Vulkan backend and model |
| [Strix Halo llama.cpp fork](https://github.com/Strix-Halo/strix-llama.cpp) | Tuned Vulkan, adaptive speculation | Specific MoE/prefill optimization ideas | Fork maintenance and upstream divergence |
| [Strixite](https://github.com/shawnshekari/strixite) | From-scratch HIP inference for `gfx1151` | Independent architecture, long-context research | Experimental; check model scope and validation |
| [Strix Halo Engine Lab](https://github.com/hyukudan/strix-halo-engine-lab) | Native HIP inference, speculation, multi-node | Advanced code and reproducible research | Not automatically a turnkey general runner |
| [strix.cpp](https://github.com/ArtomYuan/strix.cpp) | ROCmFPX and vision-oriented llama.cpp derivative | Quantization and multimodal experimentation | Specialized fork; confirm correctness and upkeep |
| [Gufo TP](https://github.com/uv-genai/gufo-tp) | Multi-Strix-Halo GPU inference via RDMA | Distributed inference research | Requires two machines and network tuning |
| [Lemonade](https://github.com/lemonade-sdk/lemonade) | Local model/backend service | Easy integration across compatible accelerators | Actual Linux/backend compatibility is version-specific |
| [Ollama](https://github.com/ollama/ollama) | Friendly model management + API | Familiar compatibility and baseline | May not match highly specialized native kernels |
| [vLLM](https://github.com/vllm-project/vllm) | Multi-request LLM serving | Batch throughput, serving reference | Verify exact AMD APU and software-stack support |
| [LM Studio](https://lmstudio.ai/) | Desktop local model experience | Convenient human-facing baseline | **Not an open-source engine**; included as a comparison tool only |

**Licensing reminder:** Every project and extension has its own license, and model-weight licenses are independent of runner source-code licenses. Never infer compatibility from “it's on GitHub.”

### 6.2 A runner is more than a model loader

Meaningful engine differences include:

- Weight file formats and quantization kernels (Q4, Q6, Q8, FPX, BF16, etc.).
- Which operators genuinely execute on GPU, CPU, or NPU.
- Attention kernels and how KV cache is represented.
- Model-specialized fused operations.
- Prompt prefill, decode, speculative decoding, batching and cancellation.
- Shared-prefix reuse and persistent prompt cache.
- Correct model chat templates, tool-call formatting and reasoning outputs.
- Image/audio/video support, separate visual encoders, and their memory costs.
- Robustness after errors, many hours of inference, and process restarts.

**A synthetic kernel result is not an end-to-end chatbot result.** Always distinguish microbenchmarks from real request latency.

### 6.3 Why a specialized GPU runner can win

A generic runner has to support dozens of architectures, including devices with different GPU instruction sets and memory models. A `gfx1151`-focused runner can tune registers, lane scheduling, HIP launches, weight layouts, attention, prefill, and quantized operations to this particular GPU. That specialized focus can produce substantially better performance on carefully supported models, while leaving gaps in general compatibility.

---

## 7. Gufo in depth: the Strix Halo-native path

**Main repository:** https://github.com/gufo-org/gufo  
**Docs:** https://gufo.blog/docs  
**Install and host requirements:** https://github.com/gufo-org/gufo/blob/main/docs/install.md  
**Developer guide:** https://github.com/gufo-org/gufo/blob/main/docs/internal/development.md  
**Testing:** https://github.com/gufo-org/gufo/blob/main/docs/internal/testing.md  
**AI-agent contributor rules:** https://github.com/gufo-org/gufo/blob/main/AGENTS.md  
**GitHub Discussions:** https://github.com/gufo-org/gufo/discussions  
**Extension registry:** https://github.com/gufo-org/gufo-extension

### 7.1 Design philosophy

Gufo explicitly concentrates on **one hardware platform**, AMD Strix Halo `gfx1151`, rather than trying to implement an everything-for-everyone model runner. Its project principles include:

1. Native model-specific optimized kernels.
2. Correctness/quality gates before performance claims.
3. Real agent-serving workloads, including cancellation and persistent conversations.
4. Multiple modalities and a curated set of supported models.
5. Source extensions for additional model implementations.
6. Native Linux and Windows builds; few production runtime dependencies.

### 7.2 Programming languages and infrastructure

| Layer | Gufo technology | Role |
|---|---|---|
| Host | **C++20** | Serving, scheduling, model load, memory, cache, runtime |
| GPU | **HIP C++ / ROCm** | GPU kernels, attention, GEMV/GEMM, quantization |
| NPU | **Python IRON + MLIR-AIE + C++ kernels** | Compile NPU computation and deployment designs |
| Auxiliary | Rust | Selected components/tools; project toolchain documents specifics |
| Build / developer environment | CMake, Nix, Python tests | Reproducible builds, correctness and benchmarks |

**HIP is not a wholly unrelated language.** It extends C++ with device kernels such as `__global__`, thread indexing, GPU runtime APIs and memory operations. Gufo's C++/HIP code can be studied alongside source-level profiling and generated GPU instructions.

### 7.3 Supported models and modalities

Gufo's official model list evolves. At the time of this review its repository documents Qwen3.8 27B, Qwen3.8 Flash-Next, DeepSeek V4 Flash, EmbeddingGemma 2, Qwen3-ASR, Qwen3-TTS, Qwen-Image-2.1 and MiniMax H3. **Check the current [models directory](https://github.com/gufo-org/gufo/tree/main/docs/models) rather than treating this as permanent.**

Gemma 4 is handled separately through [Francesco Moca's extension](https://github.com/franzmoca/gemma4-gufo-extension), supporting 26B-A4B and 31B variations, model-dependent MTP, vision, tool calls and caching. The extension requires a compatible source-extension API. Use its published build instructions and pinned versions.

### 7.4 Benchmark interpretation: Gemma 4 26B-A4B

**Source:** [Gemma 4 Gufo extension benchmarks](https://github.com/franzmoca/gemma4-gufo-extension/blob/main/docs/models/gemma-4-26b-a4b/BENCHMARKS.md)

The extension author reported, on AMD Strix Halo with 128 GB unified memory:

| Workload / quant | Gufo | llama.cpp comparison | Interpretation |
|---|---:|---:|---|
| QAT 4-bit, native `tg128` microbenchmark | 81.4 tok/s | 69.4 tok/s | Same-quant kernel/engine benchmark, not whole-chat latency |
| UD-Q4_K_XL, HTTP AR single-user, context depth 0 | 53.52 tok/s | 43.96 tok/s | Same-file HTTP test without speculative drafting |
| UD-Q4_K_XL, HTTP sampled MTP, depth 0 | 73.84 ± 2.68 tok/s | 51.02 ± 3.74 tok/s | Specific sampled speculative-decoding setup |

**Do not conflate** these three rows; they differ in quantization, execution mode, or measurement method. They are **developer-reported measurements, not independent universal records**. Thermals, kernel/compiler, prompt type, context length, memory settings and different laptops can change the result.

For this model, the name is **Gemma 4 26B-A4B** (MoE). **Gemma 4 E4B is a different, smaller model**. Verify exact model IDs before downloading or comparing.

### 7.5 Gufo extension work and contribution path

1. Read the base project's development and testing conventions.
2. Decide whether an improvement belongs in the base engine or a model-owning extension.
3. Keep a clean, reproducible baseline: same model hash, quant, build flags, ROCm, kernel and power profile.
4. Implement one isolated optimization or correctness fix.
5. Validate against the project's expected output or numerical oracle.
6. Benchmark both before and after on the **same physical machine**.
7. Submit a focused PR with logs and measured evidence.

Gufo's repository documents rules specifically for **people and AI coding agents**. That is an unusually useful entry point for collaborative AI-assisted development. Respect author decisions, test requirements, code style, and other contributors' work.

### 7.6 Deployment considerations

Gufo's documented interfaces include locally served APIs suitable for compatible chat and agent clients. Verify the current authentication and network-bind behavior; do not assume that presenting an API key means the process actually enforces one. Bind local instances to loopback or place an authenticated reverse proxy in front of them before sharing access.

**Native builds versus containers:** Gufo supports several installation methods. Containers can reduce user-space conflicts but still depend on working host GPU/NPU drivers. For source extensions and kernel research, a clean native source or pinned Nix build can make it easier to compare compiler changes. Follow current project docs, not a generic copied install command.

---

## 8. AMD GPU programming: ROCm, HIP, Vulkan, and profiling

### 8.1 Primary resources

| Resource | Link | What it offers |
|---|---|---|
| ROCm documentation | https://rocm.docs.amd.com/ | Installation, GPU support, HIP, libraries and tuning |
| ROCm TheRock | https://github.com/ROCm/TheRock | Lightweight source build/release infrastructure for HIP + ROCm |
| HIP | https://github.com/ROCm/HIP | C++ GPU programming API and compiler/runtime integration |
| ROCm libraries | https://github.com/ROCm/rocm-libraries | Current umbrella repository for many AMD math/ML libraries |
| ROCm systems | https://github.com/ROCm/rocm-systems | Current umbrella repository for system/profiling components |
| GPU target specs | https://rocm.docs.amd.com/en/latest/reference/gpu-specs.html | Architecture names, CU count, wavefront and other features |
| Mesa 3D | https://gitlab.freedesktop.org/mesa/mesa | Vulkan RADV driver source and graphics/compute stack |
| Vulkan documentation | https://docs.vulkan.org/ | Vulkan compute concepts and APIs |

**Repository migration note (2026):** Some historical standalone ROCm repositories were merged or deprecated. For example, `ROCm/composable_kernel` points toward `ROCm/rocm-libraries`, and `ROCm/rocprofiler-sdk` points toward `ROCm/rocm-systems`. Prefer active upstream locations when making new contributions.

### 8.2 HIP vs Vulkan for inference

**HIP/ROCm** lets developers write GPU compute kernels with C++-style GPU execution semantics and access AMD-oriented math/tooling. It is well suited to direct `gfx1151` optimization and is central to Gufo.

**Vulkan compute** uses a cross-platform GPU API. On Linux, the Mesa RADV stack can provide an alternative inference path. Vulkan may be an easier baseline for certain engines or drivers, but it does not inherently beat or lose to HIP. Kernel implementation, resource lifetime and memory access dominate.

**Takeaway:** Maintain both a ROCm/HIP reference and a Vulkan reference for the same model when possible. A failure in one backend is evidence about that stack/version, not necessarily about the other.

### 8.3 Performance-engineering topics worth learning

- `gfx1151` code generation and ISA inspection.
- Wavefront 32/64 behavior, thread organization and instruction occupancy.
- BF16, FP16, FP32 and weight-only quantization.
- GEMM (many-row matrix multiplication) versus GEMV (one/few-vector matrix multiplication).
- Attention and KV-cache layouts.
- Fusing kernels and reducing dispatch / synchronization overhead.
- Host-device transfers, pinned memory and GPUVM mapping.
- AMD WMMA and vector operations where supported.
- GPU vs CPU timing; separate kernel time from full wall-clock latency.
- Thermal and power-state consistency across benchmark runs.

A model's *prefill* and *decode* use different computational shapes. A kernel that transforms prefill may have no effect on one-token decode.

---

## 9. XDNA 2 NPU development: IRON, MLIR-AIE, XRT

### 9.1 Projects and their roles

| Project | Link | Role |
|---|---|---|
| **AMD IRON** | https://github.com/amd/IRON | Python-based close-to-metal programming interface for Ryzen AI NPUs |
| **MLIR-AIE** | https://github.com/Xilinx/mlir-aie | MLIR-based compiler infrastructure and programming model |
| **AMD XDNA driver** | https://github.com/amd/xdna-driver | Linux `amdxdna` kernel driver and XRT SHIM infrastructure |
| **FastFlowLM** | https://github.com/ROCm/FastFlowLM | NPU-oriented local LLM software; assess its binary licensing carefully |
| **Gufo's NPU docs** | https://github.com/gufo-org/gufo/blob/main/docs/internal/npu.md | Concrete examples of compiled NPU designs and XRT integration |

### 9.2 How the pieces fit

```text
IRON (Python NPU design description)
               ↓
       MLIR-AIE compiler
               ↓
   Compiled NPU design / xclbin
               ↓
   XRT user-space runtime
               ↓
 Linux amdxdna driver + firmware
               ↓
          XDNA 2 NPU
```

The CPU host can orchestrate NPU execution, memory movement, and synchronization; the GPU may simultaneously handle other workloads where software and stability allow. **NPU availability does not mean a 26B or 70B LLM can run entirely on it with competitive speed.** Supported operations and compiler pipelines matter.

### 9.3 NPU use cases worth prototyping

- Small language-model inference with a supported quantization.
- Embedding generation or audio processing while the GPU serves a larger model.
- Prefill or GEMM work that benefits from the NPU's dataflow architecture.
- Repeatable operator microbenchmarks for Q8/BF16 designs.
- Safe CPU/GPU/NPU coordination when all devices are required by one application.

### 9.4 NPU-specific caveats

- Verify `/dev/accel/*` and `amdxdna` device presence before debugging a higher layer.
- Kernel, firmware and XRT versions may need to match.
- The NPU and GPU have different driver stacks; one working does not imply the other does.
- Many public examples use precompiled kernels, separate model support tables, or external tools.
- **FastFlowLM's source availability does not mean its entire accelerated kernel stack is open-source.** Its published project notes describe proprietary accelerated binaries; review terms for contributions and redistribution.
- Simultaneous high-load GPU/NPU operation deserves extended stability testing; power management and driver interactions can be nontrivial.

---

## 10. Image, video, audio, and multimodal AI

### 10.1 Projects

| Project | Link | Why it is relevant |
|---|---|---|
| ComfyUI | https://github.com/Comfy-Org/ComfyUI | Extensible visual workflow environment for diffusion/image/video models |
| ComfyUI-StrixHalo | https://github.com/wabibito/ComfyUI-StrixHalo | Example ROCm environment aimed at Ubuntu 26.04 and `gfx1151` |
| Gufo official model catalogue | https://github.com/gufo-org/gufo/tree/main/docs/models | Text, image, audio, embedding and experimental video implementations |
| Qwen model organization | https://huggingface.co/Qwen | Model cards, licenses and checkpoint metadata |
| AMD software resources | https://www.amd.com/en/products/software/ryzen-ai-software.html | Official NPU and developer ecosystem |

### 10.2 Practical observations

- Multimodal support requires **more than text-model GGUF compatibility**. Image encoders/projectors and input preprocessing must match.
- Image/video generation can stress memory and thermals very differently from autoregressive text decoding.
- ComfyUI ecosystems often depend on specific versions of PyTorch, ROCm and custom nodes. Isolation is valuable; a working LLM stack is not a reason to modify global Python packages.
- Verify each checkpoint's model license, especially non-commercial model weights.
- Separate full-pipeline latency from just denoiser/GPU-kernel throughput.

A model runner for text is not automatically the best image/video runner, and it is perfectly reasonable to use specialized engines for each modality.

---

## 11. Personal AI agents and higher-level development

The long-term point of an efficient local model runner is not the runner itself. It is enabling useful applications: persistent AI assistants, agentic coding, research, creative tools, and systems that can work with locally stored knowledge and user-authorized tools.

### 11.1 Agent-focused resources

| Resource | Link | Role |
|---|---|---|
| AMD GAIA | https://github.com/amd/gaia | AMD-oriented framework for building PC agents and tool-enabled workflows |
| AMD Agent Skills | https://github.com/amd/skills | Reusable agent skills for AMD software, local AI and development |
| OpenClaw | https://github.com/openclaw/openclaw | Personal agent tooling and integrations; audit permissions carefully |
| Open WebUI | https://github.com/open-webui/open-webui | Local/remote model chat interface with tools and extensibility |
| SillyTavern | https://github.com/SillyTavern/SillyTavern | Flexible chat/character front end compatible with supported APIs |
| llama.cpp server | https://github.com/ggml-org/llama.cpp | Reference HTTP-serving baseline for custom clients |
| Gufo API/docs | https://github.com/gufo-org/gufo/blob/main/docs/server.md | Local serving, endpoints and capabilities |

**Not every tool should get blanket computer access.** Agent autonomy should be paired with explicit permission scopes, isolated credentials, action logs, backups, and confirmation for irreversible operations.

### 11.2 “Smarter agent” versus “larger model”

A powerful personal system can improve through several mostly independent paths:

1. Better foundation models and quantized formats.
2. Better inference kernels and lower response latency.
3. Better memory and retrieval of relevant, reliable information.
4. Better tool interfaces and environment awareness.
5. Better task planning, verification and reusable skills.
6. Long-lived project state and transparent progress tracking.

More stored data is not automatically more intelligence; **retrieval quality, provenance, freshness, feedback, and the ability to act on knowledge** matter. These are excellent research domains for higher-level local-AI projects.

### 11.3 A modular serving philosophy

Keep the inference backend behind a stable API adapter. Then applications can use Gufo for a supported fast model, llama.cpp for wider GGUF compatibility, and a specialized audio/image engine for other modalities. Do not let the entire companion or agent architecture depend on one runner's internal structures.

---

## 12. Positive communities and places to collaborate

There is no guarantee that every participant shares the same philosophy about AI agency or vibe coding. These communities are listed because they visibly concentrate local-AI development, unusual hardware knowledge, or open-source collaboration.

| Community | Link | Best for |
|---|---|---|
| **Strix Halo HomeLab Discord** | https://discord.gg/pnPRyucNrG | Other Ryzen AI MAX owners, Linux, GPU/NPU, local-AI setups |
| **Strix Halo Wiki** | https://strixhalo.wiki/ | Guides and community-sourced hardware findings |
| **Gufo Discussions** | https://github.com/gufo-org/gufo/discussions | Model-specific ideas, Q&A, show-and-tell, optimization proposals |
| **Gufo Issues** | https://github.com/gufo-org/gufo/issues | Reproducible bugs and feature tracking |
| **Gufo Pull Requests** | https://github.com/gufo-org/gufo/pulls | Seeing how code is reviewed, measured, and integrated |
| **r/StrixHalo** | https://www.reddit.com/r/StrixHalo/ | Owners, real-world benchmarks and software stack reports |
| **r/LocalLLaMA** | https://www.reddit.com/r/LocalLLaMA/ | Broader local inference, model quants, tooling and experiments |
| **AMD Developer Discord** | https://discord.com/servers/1239631572886491286 | ROCm, GPU programming and AMD developer community |
| **ASUS Linux** | https://asus-linux.org/ | ROG hardware-specific Linux help and developer community |
| **Lemonade repository/community** | https://github.com/lemonade-sdk/lemonade | Serving/integration issues and AMD accelerator experimentation |

### 12.1 Good first contributions to a community

- Share exact hardware model, OS/kernel and driver versions.
- Post a *reproducible* model benchmark, not a vague speed claim.
- Submit a minimal fix to a known issue, with before/after evidence.
- Document a tested workaround and clearly label its limitations.
- Ask about existing roadmaps before implementing a large overlapping feature.
- Credit original authors and respect code/weight licenses.
- Be transparent about AI-assisted contributions and responsible for validating their outputs.

An effective question is: **“On GZ302EA, kernel X, ROCm Y and Gufo revision Z, why does model A at quant B show these repeatable timings?”** That invites useful engineering discussion.

---

## 13. A stability-first Linux checklist

> **Safety priority:** If the machine has recently suffered hard crashes related to memory/power settings, preserve the known-good configuration and a way to roll back before changing anything. A crash can corrupt user data even when hardware is unharmed.

### Phase A: Preserve what currently works

- [ ] Back up critical work and verify that the backup is readable.
- [ ] Record BIOS/UEFI version and key settings without changing them.
- [ ] Record Linux kernel and firmware package versions.
- [ ] Export the current list of APT packages/driver versions if useful.
- [ ] Document known-good fan and power profiles.
- [ ] Record the current GPU memory configuration and any custom kernel command-line parameters.
- [ ] Retain a working boot option, rescue medium, and safe rollback path.
- [ ] Keep a short incident log of previous memory-related failures and their successful resolution.

### Phase B: Isolate change categories

Only change **one major layer at a time**:

1. Kernel/firmware and device detection.
2. ROCm libraries and compiler/runtime.
3. NPU XRT or IRON toolchain.
4. Power/fan controls.
5. Inference engine/version and model-specific kernels.
6. Optional performance experiments.

Do **not** change kernel, firmware, BIOS memory carveout, GTT limits, ROCm, XRT and undervolt on the same afternoon, then try to infer which change helped.

### Phase C: Long-run verification

- [ ] Idle desktop and suspend/resume stable.
- [ ] CPU-only memory/compute workload stable.
- [ ] GPU-only workload stable over a meaningful sustained period.
- [ ] Model loads and unloads repeatedly without memory leakage.
- [ ] Long context does not lead to allocation failures or kernel faults.
- [ ] Inference under normal power profile stays thermally manageable.
- [ ] Concurrent agent requests do not freeze the desktop.
- [ ] NPU work tested separately before GPU+NPU combined stress.
- [ ] Logs reviewed for `amdgpu`, `amdxdna`, reset, OOM and firmware errors.

**Avoid as default advice:** arbitrary `amdgpu` GTT overrides, unchecked sysfs writes, disabling safety features, undocumented GRUB changes, experimental voltage settings, and running web-sourced root scripts without inspection.

---

## 14. Read-only diagnostics and baseline collection

These commands are illustrative and primarily **read-only**. Some packages may not be installed. They do **not** install drivers, alter GPU memory limits, or configure power.

```bash
# OS and kernel
cat /etc/os-release
uname -a
cat /proc/cmdline

# CPU and memory
lscpu | sed -n '1,45p'
free -h
cat /proc/meminfo | grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):'

# PCI hardware, kernel drivers and modules
lspci -nnk | grep -A4 -E 'VGA|Display|3D|Audio|Network'
lsmod | grep -E 'amdgpu|amdxdna|asus|hid'

# GPU and NPU device nodes, if present
ls -l /dev/kfd /dev/dri/ /dev/accel/ 2>&1

# Firmware and installed ROCm tools, if available
command -v rocminfo && rocminfo | grep -E 'Name:|gfx1151' | head -40
command -v hipcc && hipcc --version
command -v vulkaninfo && vulkaninfo --summary
command -v xrt-smi && xrt-smi examine

# Installed versions, relevant for Ubuntu/Kubuntu
apt list --installed 2>/dev/null | grep -Ei 'rocm|hip|linux-firmware|xrt|mesa-vulkan' | head -80

# Boot-time warnings and driver errors
journalctl -b -p warning --no-pager | tail -100
journalctl -k -b --no-pager | grep -Ei 'amdgpu|amdxdna|firmware|gpu reset|oom|mce' | tail -120
```

### 14.1 Interpret with care

- Missing `rocminfo` is not proof the GPU driver is absent; ROCm user-space tooling might simply be uninstalled.
- Missing `vulkaninfo` may mean the utility is absent, not that Vulkan itself is broken.
- `/dev/accel/accel0` is a common NPU path, not a universal numbering guarantee.
- `rocminfo` output can list CPU agents as well as GPU agents; confirm **`gfx1151`**, not merely “an agent exists.”
- `lspci` may describe integrated devices differently depending on firmware and tool versions.
- Some log output may contain personally identifying hostnames, usernames, MACs or other machine data: **sanitize before posting publicly**.

### 14.2 Baseline metadata to save with benchmark reports

```text
Machine model / SKU:
BIOS/UEFI version:
Kernel:
Distro:
linux-firmware version:
Mesa version:
ROCm/HIP version:
NPU XRT/IRON version (if used):
Inference engine / git commit:
GPU target reported:
Model repository / exact file / SHA-256:
Quantization:
Prompt tokens / generated tokens / cache state:
Context size and depth:
Prefill tok/s, decode tok/s, TTFT, p50/p95:
Power profile / charger / fan profile:
RAM and swap in use:
Temperature and clocks observed:
Concurrency:
Errors / deviations / notes:
```

---

## 15. How to benchmark runners fairly

### 15.1 Apples-to-apples methodology

For each comparison:

1. Use the **same exact model weights**, not merely the same nominal model name.
2. Record a checksum (`sha256sum model.gguf`) for locally available files.
3. Use compatible tokenizer/chat-template rendering and equivalent prompts.
4. Record quantization, context length, cache state, temperature and sampler.
5. Separate **cold model load**, **time to first token**, **prefill**, and **generated token speed**.
6. Separate one interactive user from concurrent users (aggregate throughput versus per-user latency).
7. Repeat runs after warmup; include medians and variability.
8. Stabilize power/thermal profiles, run on AC power, and avoid unrelated heavy workloads.
9. Observe memory allocation, GPU resets, errors, correctness and system responsiveness.
10. Publish all relevant failures, not just the fastest run.

### 15.2 Suggested repeatable workload matrix

| Case | Prompt size | Output | Concurrency | Reason |
|---|---:|---:|---:|---|
| Small interactive | 128 tokens | 128 | 1 | Ordinary chat responsiveness |
| Medium instruction | 2,048 | 256 | 1 | Realistic agent request |
| Long context | 16,384 | 512 | 1 | Retrieval or larger coding task |
| Deep conversation | 65,536 | 256 | 1 | Long-running companion/agent history |
| Concurrent agents | 2,048 each | 256 each | 4 | Scheduling and shared-model behavior |
| Agent burst | 2,048 each | 128 each | 8 | Aggregate throughput and tail latency |
| Repeated prefix | 16,384 cached | 256 | 1 | Prefix-cache benefits |
| Long soak | Actual target workload | Continuous | 1–4 | Stability, thermals and leaks |

Make the test set manageable. Not every model supports 65K context, eight sessions, or the same multimodal inputs. Record unsupported cases explicitly rather than silently skipping them.

### 15.3 Key metrics

| Metric | What it measures | Why it matters |
|---|---|---|
| Prefill tokens/s | Processing input context | Long documents, coding-agent history |
| Decode tokens/s | Producing generated text | Live conversation feel |
| TTFT | Time to first generated token | Perceived response latency |
| End-to-end latency | Total response time | Real task completion |
| Aggregate tok/s | Output across users | Multi-agent throughput |
| p95 latency | Slowest tail of typical requests | Reliability under concurrency |
| Resident RAM / GPU allocations | Runtime memory overhead | Headroom for OS and other agents |
| GPU utilization/thermals | Hardware behavior | Identify power/memory bottlenecks |
| Error/quality rate | Correctness, resets and failures | Speed without usable output is not a win |

### 15.4 A mini result table to copy into issues/PRs

| Runner | Version/commit | Exact model + quant | Context | Users | Prefill tok/s | Decode tok/s | TTFT | Peak memory | Errors |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| Gufo | TBD | TBD | TBD | 1 | TBD | TBD | TBD | TBD | TBD |
| llama.cpp ROCm | TBD | Same file | TBD | 1 | TBD | TBD | TBD | TBD | TBD |
| llama.cpp Vulkan | TBD | Same file | TBD | 1 | TBD | TBD | TBD | TBD | TBD |
| Ollama | TBD | Same weights if supported | TBD | 1 | TBD | TBD | TBD | TBD | TBD |

Do not call a benchmark “fair” if model format, prompt template, speculative decode settings or model source differs materially between engines. Report those comparisons as useful but **not fully matched**.

---

## 16. A practical adoption roadmap

### Stage 0: Stability and machine inventory

**Deliverable:** A known-good, reproducible Linux baseline and backup, with working CPU, GPU and desired peripherals. No new memory or undervolt tuning during initial runner comparisons.

### Stage 1: One reliable baseline runner

**Deliverable:** One verified GGUF model operating through standard llama.cpp on ROCm **or** Vulkan. Record exact performance and all version details. This creates a control group for later Gufo measurements.

### Stage 2: Gufo pilot

**Deliverable:** Gufo built/installed using its current documented method, with successful `diagnose`, one supported model, local API access and error-free basic workload. Confirm that model weights, toolchain and ROCm versions match the setup.

### Stage 3: Model-specific specialist evaluation

**Deliverable:** A table comparing Gufo and reference engines for one or two *important* models. Test real chat/coding-agent workloads, long contexts, repeated prefixes and modest concurrency. For Gemma 4, evaluate the separate extension and its compatibility constraints.

### Stage 4: Personal-agent service integration

**Deliverable:** An API adapter that lets higher-level agents select a runner without modifying their memory or orchestration architecture. Default to local-only serving and narrow credentials.

### Stage 5: NPU research, separately

**Deliverable:** A documented `amdxdna`/XRT/IRON operator or supported small-model experiment. Benchmark without destabilizing the primary GPU service. Expand to simultaneous GPU + NPU only after separate paths are reliable.

### Stage 6: Contribution to upstream

**Deliverable:** A modest correctness/performance improvement, issue reproduction, test, or documentation PR accepted by one of the hardware projects. Start with a bounded goal that fits upstream's review process.

### Stage 7: Sustained higher-level development

**Deliverable:** A reliable, replaceable inference foundation supporting agents, personal knowledge, tools, creative projects and research. Keep exploratory inference-engine research independent from production agent uptime.

---

## 17. A contribution playbook for human + AI teams

### 17.1 Working effectively with advanced AI coding agents

A productive model is **human-directed goals + AI-assisted investigation + controlled experiments + reproducible human-reviewed evidence**.

A suggested workflow:

1. **Scope:** Identify a specific bug or performance bottleneck already recognized by the upstream project.
2. **Read:** Review `README`, `AGENTS.md`, contribution rules, test instructions, code ownership and recent PRs.
3. **Reproduce:** Obtain the simplest failing test or measurable slow path on supported hardware.
4. **Hypothesize:** Record expected effect, tradeoffs and alternate explanations.
5. **Implement:** Isolate the change and avoid unrelated project reorganization.
6. **Validate:** Use independent oracles, reference outputs and numerical-quality tests.
7. **Measure:** Run paired performance tests on identical hardware/software profiles.
8. **Review:** Inspect security, memory safety, licensing, expected regressions and code style.
9. **Propose:** Open a focused PR with transparent method, test results and limitations.
10. **Maintain:** Respond to review feedback and help maintain the code after merge.

If agents generate code, the submitter still owns its accuracy, licensing, test quality and behavior. Do not outsource accountability to the model.

### 17.2 High-value beginner-to-intermediate contribution types

- Reproduce a Z13-specific GPU/NPU problem with minimal test cases.
- Fix a setup-guide ambiguity for one specific distro/kernel.
- Add repeatable benchmark scripts or fixtures.
- Improve error text for unsupported `gfx1151` or mismatched HIP runtimes.
- Document memory/driver configurations and their verified outcomes.
- Add one focused regression test for a previously observed crash.
- Improve benchmark reporting or plotting, while preserving raw samples.

### 17.3 Advanced kernel contribution types

- Reduce kernel launches or synchronization in hot decode loops.
- Better Q4/Q6/Q8 format-specific GEMV/GEMM.
- Attention layout and long-context performance improvements.
- Efficient expert routing for Mixture-of-Experts models.
- Prefix-cache placement and memory reuse.
- Compiler-generated ISA analysis and register occupancy improvements.
- Carefully measured CPU-GPU-NPU operation splitting.

Kernel speedups require numeric fidelity: a faster implementation that changes answers, tool calls, or safety behavior is a regression unless the project explicitly permits an accuracy/performance tradeoff.

### 17.4 Coordination with independent research projects

A large personal research engine and a focused community runner can coexist:

- Use a reliable community runner for production work.
- Continue independent research on architecture, memory, scheduling, and heterogenous compute.
- Contribute generalized performance insights to upstream where useful.
- Respect source licenses. **MIT code can often be reused under the MIT conditions, but AGPL-3.0-covered code cannot automatically be inserted into MIT-only upstream code without compatible permissions or authorization.**
- Keep separate commit histories, acknowledgments, test evidence and IP boundaries.

---

## 18. Security, privacy, and licenses

### 18.1 Basic secure-serving defaults

- Bind local inference servers to `127.0.0.1` unless remote access is explicitly needed.
- Don't expose unauthenticated inference, file access or agent tools directly to the internet.
- For remote clients, use a properly configured authentication gateway, VPN, or private network with least privilege.
- Keep model files and downloaded extensions from known sources; examine unexpected install scripts.
- Scope API keys and tokens to each agent; separate user-facing and agent-owned accounts appropriately.
- Disable automatic shell/system actions unless a workflow genuinely needs them.
- Keep searchable logs without leaking private conversations into public bug reports.

### 18.2 Licensing is layered

| Layer | Separate legal question |
|---|---|
| Inference engine | Is the engine MIT, Apache-2.0, AGPL, GPL, or proprietary? |
| Fork/extension | Does it add its own license or copied-source obligations? |
| Model weights | Is the model Apache/MIT/open-weight under custom terms/non-commercial? |
| Dataset | Can it be reused for testing/fine-tuning? |
| API/service | Are remote terms different from local inference? |
| Public repository | Do embedded source snippets preserve required notices? |

Gufo's original code is MIT-licensed, but adapted code/dependencies carry their own notices. Its supported model weights have varied licenses. Always check current `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES`, and model cards.

### 18.3 Privacy when publishing logs

Before posting configurations or results, remove usernames, full paths, serial numbers, public IPs, Wi-Fi network names, tokens, private repository URLs, emails, and personal prompt content. Public documentation should contain reproducible technical details without exposing private data.

---

## 19. Common failure patterns and troubleshooting questions

| Symptom | First questions | Do not immediately do this |
|---|---|---|
| GPU visible in `lspci` but not to HIP | Is `/dev/kfd` present? Is `gfx1151` recognized? Are user permissions and ROCm versions correct? | Replace the whole OS |
| Vulkan works, HIP fails | Is the HIP runtime/compiler compatible with this APU? Is the ROCm build correct? | Assume GPU hardware is defective |
| Inference crashes with large model | How much model/KV/host memory is allocated? OOM or GPU reset? Is a memory override active? | Raise memory limits randomly |
| Freeze after long GPU session | Check GPU/firmware errors, thermals, power profile and runtime versions | Overclock or undervolt more |
| NPU unavailable | Is `amdxdna` bound? `/dev/accel/*` present? XRT installed and compatible? | Assume `/dev/kfd` covers NPU |
| Strong prefill, weak decode | Are weights streamed every token? Too many dispatches? CPU fallback? Is quant kernel tuned? | Quote prefill speed as chat speed |
| Great one-user speed, poor multi-agent throughput | Batching, cache reuse, long contexts, power limits and memory headroom | Assume more agents give linear throughput |
| Slow after waking laptop | Power/runtime resume behavior, driver logs and relevant daemons | Run an unreviewed system tweak |
| Wrong tool-call or reasoning format | Chat template, tokenizer, model-specific serving API | Treat an API-compatible endpoint as semantically equivalent |
| Suddenly poor performance after update | Compare kernel, ROCm, compiler, weights and power profile against baseline | Change several packages at once |

Useful entrypoints: [Gufo troubleshooting](https://github.com/gufo-org/gufo/blob/main/docs/troubleshooting.md), [AMD Strix Halo guide](https://rocm.docs.amd.com/en/latest/reference/system-optimization/rdna3-5.html), [z13ctl docs](https://dahui.github.io/z13ctl/), [Strix Halo Wiki](https://strixhalo.wiki/).

---

## 20. Quick-reference resource directory

This directory intentionally includes **closely related but distinct** categories. A resource being linked here is not a declaration that its current build works on a particular Kubuntu point release.

### Hardware and OS

1. AMD Ryzen AI MAX+ 395 specifications — https://www.amd.com/en/products/processors/laptop/ryzen/ai-300-series/amd-ryzen-ai-max-plus-395.html
2. AMD RDNA 3.5 / Strix Halo optimization — https://rocm.docs.amd.com/en/latest/reference/system-optimization/rdna3-5.html
3. AMD ROCm GPU specifications — https://rocm.docs.amd.com/en/latest/reference/gpu-specs.html
4. Strix Halo Wiki — https://strixhalo.wiki/
5. z13ctl — https://github.com/dahui/z13ctl
6. z13gui — https://github.com/dahui/z13gui
7. GZ302 Linux Setup — https://github.com/mantkiew/GZ302-Linux-Setup
8. Archived Strix Halo Linux Setup (historical) — https://github.com/th3cavalry/strix-halo-linux-setup
9. ASUS Linux community — https://asus-linux.org/

### AI serving and inferencing

10. Gufo — https://github.com/gufo-org/gufo
11. Gufo docs — https://gufo.blog/docs
12. Gufo extensions — https://github.com/gufo-org/gufo-extension
13. Gemma 4 for Gufo extension — https://github.com/franzmoca/gemma4-gufo-extension
14. Gemma 4 extension benchmarks — https://github.com/franzmoca/gemma4-gufo-extension/blob/main/docs/models/gemma-4-26b-a4b/BENCHMARKS.md
15. llama.cpp — https://github.com/ggml-org/llama.cpp
16. Strix Halo llama.cpp fork — https://github.com/Strix-Halo/strix-llama.cpp
17. Strixite — https://github.com/shawnshekari/strixite
18. Strix Halo Engine Lab — https://github.com/hyukudan/strix-halo-engine-lab
19. strix.cpp — https://github.com/ArtomYuan/strix.cpp
20. Gufo TP/RDMA — https://github.com/uv-genai/gufo-tp
21. Ollama — https://github.com/ollama/ollama
22. vLLM — https://github.com/vllm-project/vllm
23. Lemonade — https://github.com/lemonade-sdk/lemonade
24. Strix Halo Toolboxes — https://github.com/kyuz0/amd-strix-halo-toolboxes
25. AI Toolbox Cockpit — https://github.com/kyuz0/ai-toolbox-cockpit
26. Strix Halo LLM Stack — https://github.com/dinesh-se/strix-halo-llm-stack

### ROCm, GPU and NPU

27. ROCm docs — https://rocm.docs.amd.com/
28. ROCm TheRock — https://github.com/ROCm/TheRock
29. HIP — https://github.com/ROCm/HIP
30. ROCm libraries — https://github.com/ROCm/rocm-libraries
31. ROCm systems — https://github.com/ROCm/rocm-systems
32. Mesa RADV — https://gitlab.freedesktop.org/mesa/mesa
33. Vulkan docs — https://docs.vulkan.org/
34. AMD IRON — https://github.com/amd/IRON
35. MLIR-AIE — https://github.com/Xilinx/mlir-aie
36. AMD XDNA driver — https://github.com/amd/xdna-driver
37. FastFlowLM (mixed open/proprietary components) — https://github.com/ROCm/FastFlowLM
38. Gufo NPU architecture notes — https://github.com/gufo-org/gufo/blob/main/docs/internal/npu.md

### Creative AI and agents

39. ComfyUI — https://github.com/Comfy-Org/ComfyUI
40. ComfyUI-StrixHalo — https://github.com/wabibito/ComfyUI-StrixHalo
41. AMD GAIA — https://github.com/amd/gaia
42. AMD Agent Skills — https://github.com/amd/skills
43. OpenClaw — https://github.com/openclaw/openclaw
44. Open WebUI — https://github.com/open-webui/open-webui
45. SillyTavern — https://github.com/SillyTavern/SillyTavern

### Communities

46. Strix Halo Discord — https://discord.gg/pnPRyucNrG
47. Gufo Discussions — https://github.com/gufo-org/gufo/discussions
48. Gufo PRs — https://github.com/gufo-org/gufo/pulls
49. r/StrixHalo — https://www.reddit.com/r/StrixHalo/
50. r/LocalLLaMA — https://www.reddit.com/r/LocalLLaMA/
51. AMD Developer Discord — https://discord.com/servers/1239631572886491286
52. ASUS Linux — https://asus-linux.org/

---

## 21. Templates: machine profile, benchmarks, and issue reports

### 21.1 Public machine profile template

```markdown
# Test platform

- Machine: ASUS ROG Flow Z13 GZ302EA (2025) / other Strix Halo model
- APU: AMD Ryzen AI MAX+ 395
- GPU: Radeon 8060S, gfx1151
- RAM: 128 GB LPDDR5X unified
- NPU: XDNA 2
- Distribution: [name + version]
- Kernel: [uname -r]
- linux-firmware package: [version]
- BIOS: [public version only]
- Mesa: [version]
- ROCm: [version]
- XRT/IRON: [version or not installed]
- Power mode: [quiet/balanced/performance/custom]
- GPU memory configuration: [documented, non-sensitive values]
- Known working features: [list]
- Known issues: [list]
- Notes: [sanitized]
```

### 21.2 Benchmark issue template

```markdown
## Objective
Explain the workload and why it matters.

## Hardware / software
Machine, distro, kernel, firmware, GPU target, ROCm, runner git SHA,
model SHA-256, quant, context, cache and power settings.

## Reproduction
Minimal reproducible commands. Remove secrets and private prompts.

## Expected result
Correct output and expected performance range.

## Observed result
Prefill, decode, TTFT, latency, memory, GPU/CPU/NPU activity.
Include individual runs and measurement method.

## Correctness validation
Reference output or numeric oracle. Mark unknown cases as unverified.

## Controls
Same-machine baseline and explanation of differing settings.

## Logs
Sanitized relevant errors, GPU resets and allocation failures.

## Proposed next step
One bounded hypothesis or change for review.
```

### 21.3 Suggested research reading order for AI coding collaborators

1. Read [Gufo's README](https://github.com/gufo-org/gufo) and [AGENTS.md](https://github.com/gufo-org/gufo/blob/main/AGENTS.md).
2. Read [Gufo development](https://github.com/gufo-org/gufo/blob/main/docs/internal/development.md) and [testing](https://github.com/gufo-org/gufo/blob/main/docs/internal/testing.md).
3. Read [AMD's optimization guide](https://rocm.docs.amd.com/en/latest/reference/system-optimization/rdna3-5.html).
4. Read the relevant [Gufo model documentation](https://github.com/gufo-org/gufo/tree/main/docs/models) and check the actual code paths.
5. Study the model's correctness oracles, tests, cache behavior, and benchmark harness.
6. Compare with [llama.cpp](https://github.com/ggml-org/llama.cpp) and at least one independent Strix Halo project.
7. Profile on real `gfx1151` hardware with pinned software.
8. Propose a narrowly scoped contribution with supporting evidence.

---

## 22. Glossary, curation rules, and maintenance

### 22.1 Glossary

- **APU:** CPU and GPU combined in a processor package, here with shared system RAM and an additional NPU.
- **Strix Halo:** AMD codename for Ryzen AI MAX-class processors.
- **`gfx1151`:** AMD GPU architecture target used by Strix Halo Radeon 8060S; relevant to ROCm/HIP code generation.
- **RDNA 3.5:** AMD Radeon GPU architecture generation.
- **XDNA 2:** AMD neural-processing architecture used in this APU.
- **ROCm:** AMD software platform for GPU compute.
- **HIP:** C++-based portable GPU programming runtime/interface.
- **RADV:** Mesa's open Vulkan driver for AMD GPUs.
- **XRT:** Runtime used to communicate with accelerator devices and deploy compiled workloads.
- **IRON:** Python-based framework for expressing AMD AI Engine/NPU programs.
- **MLIR-AIE:** Compiler infrastructure for AI Engine programs.
- **GGUF:** Widely used format for quantized model weights and metadata.
- **Quantization:** Representing weights/activations with reduced precision or specialized formats.
- **GEMM:** Matrix-matrix multiply, common in prefill and batched compute.
- **GEMV:** Matrix-vector multiply, common in autoregressive decode.
- **MoE:** Mixture-of-Experts model, activating a subset of experts per token.
- **Prefill:** Initial processing of prompt/context tokens.
- **Decode:** Iterative text generation after prefill.
- **KV cache:** Stored attention keys/values used to avoid recomputation.
- **TTFT:** Time to first generated token.
- **MTP:** Multi-token prediction, often paired with speculative verification.
- **GPUVM / GTT:** GPU virtual memory and associated mapped-memory infrastructure; not synonyms for physical dedicated VRAM.
- **OOM:** Out of memory, which can occur at different system/driver/application layers.
- **ABI:** Application binary interface. Changes can affect compiled extension compatibility.

### 22.2 Status labels used here

- **Official:** Published by the relevant manufacturer/project.
- **Exact-device:** Targets the 2025 ASUS ROG Flow Z13 GZ302 specifically.
- **Strix-Halo-specific:** Targets AMD Ryzen AI MAX and usually `gfx1151`.
- **Broader framework:** Supports/targets AMD accelerators more generally.
- **Experimental:** Research or specialist implementation, requiring independent testing.
- **Archived:** Historical/reference-only unless a maintained fork exists.
- **Mixed license:** Some open-source source code and some non-open components.

### 22.3 Maintaining this document in a public repository

At each review:

- [ ] Confirm all URLs resolve or document redirects.
- [ ] Check repository archive/maintenance status.
- [ ] Update Gufo model list and source extension API compatibility.
- [ ] Check ROCm supported GPU matrix, kernel/firmware constraints and Mesa versions.
- [ ] Validate Z13 controller project support against current firmware.
- [ ] Re-check whether a model extension was upstreamed or remains external.
- [ ] Re-check any benchmark numbers against dated, exact tests.
- [ ] Re-check hardware-specific cautions and known crash regressions.
- [ ] Preserve historical observations separately from current best practices.
- [ ] Credit upstream authors and link to their original measurements.
- [ ] Accept community pull requests with precise reports and reproducible evidence.

**Suggested maintenance cadence:** Quarterly, and whenever a major kernel/ROCm release or important Gufo change occurs.

### 22.4 Closing perspective

Strix Halo demonstrates how powerful local AI becomes when hardware, software, knowledgeable users, and an open-source community reinforce one another. A dedicated machine can host highly capable models, but its real value emerges when driver developers, compiler engineers, inference researchers, local-agent builders, and hardware owners share reproducible results.

**The guiding principle of this handbook:** Build on stable open foundations, optimize where the evidence says it matters, keep user data and choices under user control, and contribute fixes upstream whenever possible.

---

*Independent curated resource. All named software and model projects remain the property of their respective authors. Links are given for reference and do not imply endorsement, guaranteed compatibility, or permission to redistribute third-party code and weights. Last reviewed 2026-11-15.*
