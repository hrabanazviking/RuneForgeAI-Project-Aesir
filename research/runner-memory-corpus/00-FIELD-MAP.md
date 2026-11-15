# OR-1 — Field Map: Model Runners, Inference Engines, Serving Systems

*Version 4, 2026-11-15 (v1, v2 and v3 same day; updated by OR-1 field-map sweep #3 — see
the sweep log at the end). Living document — the sweep keeps adding finds. "Essence" lines
are one-breath summaries in our own words. Licence/language/backend facts are as stated in
each project's own repository/docs as of the date noted; every entry is re-verified when
its full dossier (OR-2) is written. Status key: **mapped** = this line only; **dossier** =
full dossier banked (see `runners/`).*

*Entry count, stated honestly: **54 enumerated entries** as of this version. Version 3
enumerated **47**. Sweep #3 adds 7 verified entries (see sweep log), moving the true
count 47 → 54. No existing entry was removed; six existing entries were amended in place
for verified status changes (Ollama, TensorRT-LLM, NVIDIA Triton Inference Server,
NVIDIA Dynamo, llm-d, ExLlamaV2 — see sweep log).*

## The centre of our work

| Runner | Licence | Language | Backends | Essence | Status |
|---|---|---|---|---|---|
| Ollama | MIT | Go (runner layer over ggml/llama.cpp lineage; a native Go engine for some models arrived in 2025) | CUDA, ROCm, Vulkan, Metal, CPU, plus MLX on Apple Silicon | The friendliest local runner: one binary, a model library, an API — the patient our own campaign operates on. Currency-checked 2026-11-15 (sweep #3): Ollama's own blog previewed an **MLX engine on Apple Silicon in v0.19** (post testing dated 2026-03-29; "Ollama on Apple silicon is now built on top of … MLX"), augmenting — not replacing — the llama.cpp paths elsewhere | dossier |
| Project Aesir (ours) | ours | Mojo, bare metal, no libraries | CUDA, HIP/ROCm, Hailo NPU, CPU | Volmarr's own from-scratch universal runner; studied freely in `aesir/`, ideas translated to Go terms | mapped — see OR-4 |

## The ggml / llama.cpp constellation

| Runner | Licence | Language | Backends | Essence | Status |
|---|---|---|---|---|---|
| llama.cpp / ggml | MIT | C/C++ | CPU, CUDA, ROCm, Vulkan, Metal, SYCL | The gravity well of local inference: GGUF format, hand-tuned kernels, runs everywhere. Newer serving companion verified 2026-11-15: `llama-server` **router mode** (announced 2025-12-11, Hugging Face blog by the ggml-org team) — started with no model, it dynamically loads/unloads/switches multiple models, one process per model, Ollama-style model management inside llama.cpp itself | dossier |
| KoboldCpp | AGPL-3.0 | C++/Python (llama.cpp fork) | CUDA, Vulkan, CPU | Storyteller-focused llama.cpp fork with a full creative-writing UI stack | dossier |
| GPT4All | MIT | C++/Qt (llama.cpp-based) | CPU-first, Vulkan | Nomic's desktop local-chat app; proved CPU local chat for non-technical users. Currency-checked 2026-11-15: repository not archived, licence still MIT per its own repo — no verified change, entry otherwise untouched | mapped |
| LocalAI | MIT | Go | llama.cpp family + others | OpenAI-compatible local API server, multi-backend, Go — a close cousin to study for Ollama-in-Go design | mapped |
| Jan | Apache-2.0 (current, verified 2026-11-15); AGPL-3.0 historically (earlier era — exact relicensing point not verified; see dossier) | TypeScript/Rust (Tauri shell) | llama.cpp-based (+ experimental MLX engine) | Desktop chat app with local models; the AGPL era is historical — do not cite Jan as AGPL today. Currency-checked again in sweep #2 (2026-11-15): its own README still states "Apache 2.0", repository active and not archived — no verified change | dossier |
| LM Studio | Proprietary (closed) | — | llama.cpp-derived (llml) + MLX | Polished closed desktop runner; public docs/behaviour only | mapped |
| RamaLama | MIT | Python | OCI containers (Podman/Docker) wrapping llama.cpp / vLLM images — CUDA, ROCm, Vulkan, Intel GPU, MLX (macOS), CPU | Red Hat / containers project: models treated as container images; pulls an accelerator-matched image and runs it isolated (rootless, no network by default) | mapped (added 2026-11-15) |
| Docker Model Runner | Apache-2.0 (verified 2026-11-15, project repo `docker/model-runner` licence field; Docker Desktop itself, which bundles it, is separate closed software) | Go | llama.cpp (Vulkan / CUDA / ROCm variants per project README) + vLLM backend; models pulled as OCI artifacts from Docker Hub / any OCI registry (GGUF from Hugging Face packaged as OCI on the fly) | Docker's local runner: the `docker model` workflow applied to LLMs — pull, run and serve models as OCI artifacts, on the host rather than in a container; beta April 2025, **generally available 2025-09-18** per Docker's own GA announcement | mapped (added 2026-11-15, sweep #3) |
| llamafile | Apache-2.0 (its changes to llama.cpp remain MIT, as upstream) | C/C++ (Cosmopolitan Libc) | CPU across OS/arch from one file; llama.cpp GPU paths | Mozilla.ai: model weights + a llama.cpp runtime packaged as a single executable that runs anywhere — distribution as the feature | mapped (added 2026-11-15) |
| llama-swap | MIT (verified 2026-11-15, project repo `mostlygeek/llama-swap`) | Go | Any OpenAI/Anthropic-compatible upstream server — llama.cpp and forks, vLLM, others (per project README) | The llama.cpp ecosystem's model-swap proxy: one binary + one config, hot-swaps local servers on demand behind one endpoint — the external companion that router mode (above) now partly absorbs upstream | mapped (added 2026-11-15, sweep #2) |

## The datacentre serving engines

| Runner | Licence | Language | Backends | Essence | Status |
|---|---|---|---|---|---|
| vLLM | Apache-2.0 | Python + C++/CUDA kernels | CUDA, ROCm, TPU, others | PagedAttention's home; the throughput king that redefined serving economics | dossier |
| SGLang | Apache-2.0 | Python + kernels | CUDA, ROCm | RadixAttention prefix-tree serving; programs-as-prompts; extremely strong on shared-prefix workloads | dossier |
| TensorRT-LLM | Apache-2.0 | C++/Python | NVIDIA CUDA only (PyTorch execution backend) | NVIDIA's own serving library; peak NVIDIA performance at peak complexity. **Identity change verified 2026-11-15 (sweep #3):** it no longer compiles TensorRT engines — NVIDIA's own release notes for **Release 1.2** state "[BREAKING CHANGE] TensorRT backend removed. PyTorch is now the sole execution backend", with `trtllm-build` / `trtllm-refit` / `trtllm-prune` and the per-model `convert_checkpoint.py` scripts all removed; do not cite the old compiled-graph workflow as current | dossier |
| DeepInfer | Apache-2.0 (verified 2026-11-15, project repo `deepseek-ai/DeepInfer` licence field + README licence section) | Python + C++ kernels (`csrc` in project repo) | NVIDIA SM100 (CUDA 13), Huawei Ascend 950 NPU (CANN 9.2) | DeepSeek's own production inference framework, open-sourced 2026-10-20 (repo created 2026-10-16): offline inference for one model only (DeepSeek-V4.1-Flash), built primarily on vLLM per its README — and explicitly *not* a complete service: its README lists the KV cache system, VE/prefill/decode disaggregation and cross-replica load balancing as "not included in this release" | mapped (added 2026-11-15, sweep #3) |
| TokenSpeed | MIT (verified 2026-11-15, project repo `lightseekorg/tokenspeed` licence field) | C++ control plane + Python execution plane (per project README, quoting the PyTorch Foundation) | NVIDIA CUDA, AMD ROCm (project docs: CUDA hosts and ROCm 7.2 hosts) | LightSeek Foundation's 2026 engine for agentic workloads (repo created 2026-05-06; announced May 2026 per project README news): the first engine to separate the control plane (a C++ finite-state machine enforcing KV-cache ownership at compile time) from the execution plane, with a pluggable layered kernel system — its MLA kernel has been adopted by vLLM per the project's own blog | mapped (added 2026-11-15, sweep #3) |
| FasterTransformer | Apache-2.0 | C++/CUDA | NVIDIA | TRT-LLM's ancestor; historically important kernel/scheduling ideas | mapped |
| LMDeploy | Apache-2.0 | Python/C++ | CUDA | SenseTime/InternLM serving; TurboMind engine, persistent batch + blocked KV | dossier |
| Sonar (formerly Aphrodite Engine) | AGPL-3.0 | Python (vLLM lineage fork) | CUDA, ROCm | Community vLLM fork aimed at roleplay/consumer use — licence differs sharply from vLLM's; note it. Renamed Aphrodite Engine → **Sonar** on 2026-11-07/08; repository moved from PygmalionAI to the dphnAI organisation (same project, same AGPL-3.0) | dossier |
| LightLLM | Apache-2.0 | Python | CUDA | Lightweight token-wise serving design | mapped |
| DeepSpeed-FastGen / DeepSpeed-MII | Apache-2.0 | Python | CUDA | Microsoft's serving line; Dynamic SplitFuse scheduling idea | mapped |
| Hugging Face TGI (Text Generation Inference) | Apache-2.0 (verified 2026-11-15, project repo licence field) | Rust + Python + gRPC (as the project itself describes it) | CUDA, ROCm, plus Inferentia / Intel GPU / Gaudi / TPU variants listed in its own README | HF's production server, used at HF for Hugging Chat / Inference API / Inference Endpoints — **now in maintenance mode as of 2025-12-11** (HF's own TGI docs, dated): only minor bug-fix, documentation and lightweight-maintenance PRs accepted; its repo README says the downstream engines HF contributes to and recommends going forward are **vLLM and SGLang**, plus local engines llama.cpp / MLX, and HF's Inference Endpoints docs recommend vLLM or SGLang as alternatives; repository shown as **archived (public archive)** when checked 2026-11-15. Its flash-attention / transformers-architecture integration lessons remain, in a frozen codebase | mapped (expanded 2026-11-15, sweep #2) |
| FastChat | Apache-2.0 | Python | multi | The Vicuna-era serving controller; multi-model routing lineage | mapped |
| NVIDIA Dynamo-Triton (formerly Triton Inference Server) | BSD-3-Clause (verified 2026-11-15, project repo licence field — matches the v2 entry) | C++ | multi-backend (TensorRT, PyTorch, ONNX, OpenVINO, Python and more, per project README) | General inference serving chassis (not LLM-specific); ensemble/scheduling ideas. **Renamed — verified 2026-11-15 (sweep #3):** NVIDIA's own developer page now titles the product "NVIDIA Dynamo-Triton, formerly NVIDIA Triton Inference Server"; NVIDIA's own blog footnote dates the rename to 2025-03-18 ("now part of the NVIDIA Dynamo Platform and has been renamed to NVIDIA Dynamo Triton"). The open-source project and `tritonserver` container names are unchanged. Currency-checked 2026-11-15: active, not archived; README names current release 2.74.0 / 26.10 container | mapped |
| Ray Serve (LLM) | Apache-2.0 | Python | multi | Cluster-scale serving orchestration layer | mapped |
| Xinference | Apache-2.0 (verified 2026-11-15, project repo licence field) | Python | vLLM, SGLang, TensorRT-LLM, Transformers, llama.cpp, MLX engines (per project README) — CPU, GPU, Apple Silicon, MLU vary by engine | Model-serving platform with broad model-type coverage (300+ built-in models across language/vision/embedding/rerank/image/audio/video per its README). Currency-checked 2026-11-15: active, not archived | mapped |
| GPUStack | Apache-2.0 (verified 2026-11-15, project repo licence field + README licence section) | Python | Orchestrates vLLM, SGLang, TensorRT-LLM or custom engines; NVIDIA, AMD, Ascend NPU, Hygon DCU, Moore Threads, Iluvatar, MetaX, Cambricon MLU, T-Head PPU (per project README) | Open-source GPU cluster manager for AI model serving: pools heterogeneous GPUs/machines under one control plane and configures the engine for you — the cluster-manager layer Ollama never tries to be | mapped (added 2026-11-15, sweep #2) |
| OpenLLM (BentoML) | Apache-2.0 (verified 2026-11-15, project repo licence field + README licence badge) | Python | vLLM as production backend, served via BentoML (per project README acknowledgements) | Run any open-source LLM as an OpenAI-compatible API with one command (`openllm serve …`), with built-in chat UI and BentoCloud/Docker/Kubernetes deployment path | mapped (added 2026-11-15, sweep #2) |
| NVIDIA Dynamo | Apache-2.0 (verified 2026-11-15, project LICENSE file: "The rest of this codebase is licensed under the Apache License 2.0" — a bundled DeepSeek test-data subset is MIT, noted in the same file; GitHub's sidebar summarises this mixed file as NOASSERTION) | Rust + Python ("Built in Rust for performance, Python for extensibility" — project README) | Orchestration above vLLM, SGLang, TensorRT-LLM; NVIDIA datacentre GPUs / multi-node | NVIDIA's 2025 datacentre-scale distributed inference framework (repo created 2025-03-03): disaggregated prefill/decode, KV-aware routing, multi-tier KV cache and SLA-driven scaling — an orchestration layer, not an engine replacement. **Milestone verified 2026-11-15 (sweep #3): Dynamo 1.0** announced by NVIDIA at GTC on **2026-03-16** as a production-grade release ("NVIDIA Enters Production With Dynamo…", NVIDIA's own press release) | mapped (added 2026-11-15, sweep #2) |
| llm-d | Apache-2.0 (verified 2026-11-15, project repo licence field + README licence section) | Go (core router components; `llm-d-router` is a Go module per its own repo) on Kubernetes | Above vLLM / SGLang model servers; multi-accelerator, multi-cloud (per project README) | Kubernetes-native distributed inference stack founded 2025 by Red Hat, Google Cloud, IBM Research, CoreWeave and NVIDIA (repo created 2025-04-29; CNCF Sandbox per project README): prefix-cache/load-aware routing, tiered KV offloading and prefill/decode disaggregation as a cluster layer. **Milestone verified 2026-11-15 (sweep #3): llm-d 1.0** released **2026-10-20** (announcement by the project contributors, carried on IBM's newsroom): first stable v1 configuration API, multi-tenant quality-of-service flow control and zero-downtime operations; the announcement states the project is "now governed by the Cloud Native Computing Foundation (CNCF)" | mapped (added 2026-11-15, sweep #2) |

## The compiler / portable-runtime family

| Runner | Licence | Language | Backends | Essence | Status |
|---|---|---|---|---|---|
| MLC-LLM | Apache-2.0 | Python/C++ on Apache TVM | CUDA, Vulkan, Metal, WebGPU | Compile the model to the device: universal deployment via TVM. Currency-checked 2026-11-15: repository not archived, licence still Apache-2.0 per its own repo — no verified change, entry otherwise untouched | dossier |
| WebLLM | Apache-2.0 | TypeScript on MLC | WebGPU | In-browser LLM inference; proof of the compile-anywhere thesis. Covered inside the MLC dossier (`runners/mlc-llm.md`) — no separate WebLLM dossier | dossier (within mlc-llm) |
| ONNX Runtime GenAI | MIT | C++ | CUDA, DirectML, CPU | Microsoft's ONNX-native generative runtime | dossier |
| OpenVINO GenAI | Apache-2.0 | C++ | Intel CPU/GPU/NPU | Intel's stack; the NPU-serving reference point | dossier |
| ExecuTorch | **BSD-3-Clause** (verified 2026-11-15 — see note below) | C++ | mobile/edge | PyTorch's on-device runtime; edge deployment discipline | mapped |
| LiteRT-LM | Apache-2.0 (verified 2026-11-15, project repo `google-ai-edge/LiteRT-LM` licence field) | C++ core (stable APIs in C++, Python and Kotlin; Swift and JavaScript in preview, per project README) on LiteRT | CPU, GPU and NPU via LiteRT — Android, iOS, Web, desktop and IoT (e.g. Raspberry Pi), per project README | Google's production-ready on-device LLM runtime (repo created 2025-04-14): the LLM orchestration layer over LiteRT (the renamed TensorFlow Lite line), with constrained decoding, multimodal inputs and tool calling; per its README it powers on-device GenAI in Chrome, Chromebook Plus and Pixel Watch | mapped (added 2026-11-15, sweep #3) |
| Modular MAX (MAX Serve) | Mixed, exactly as the project states it (verified 2026-11-15, `modular/modular` README, License section): Mojo is Apache License v2.0 with LLVM Exceptions; "Portions of the MAX source code and its binary distribution are licensed under the MAX_LICENSE, with the remainder of the source under the Apache License v2.0 with LLVM Exceptions" — **not** a single-licence project, do not cite it as plain Apache-2.0 | Mojo + Python | GPU via the MAX graph compiler / kernels (a compatible GPU is required for its generate path, per project README) | Modular's graph-compiled inference platform with an OpenAI-compatible inference server (`max/python/max/serve`, open-sourced May 2025 per project README): one Mojo kernel codebase serving models across vendors — directly relevant to our own Mojo work | mapped (added 2026-11-15, sweep #2) |
| NVIDIA TensorRT Edge-LLM | Apache-2.0 (verified 2026-11-15, project repo licence field + README licence section) | C++ | NVIDIA Jetson, DRIVE and DGX Spark (TensorRT/CUDA), per project README/docs | NVIDIA's 2025 edge runtime (repo created 2025-10-02): lightweight C++ LLM/VLM inference for embedded automotive/robotics — TensorRT-LLM's ideas rebuilt for Thor-class edge hardware, with EAGLE speculative decoding and NVFP4 | mapped (added 2026-11-15, sweep #2) |

*ExecuTorch licence note (sweep #2, verified 2026-11-15): the project's own README states
"ExecuTorch is BSD licensed. See LICENSE." The LICENSE file in `pytorch/executorch` is a
three-clause BSD licence (redistribution conditions 1–2 plus the clause 3 bar on using the
name Meta or contributor names for endorsement), headed "BSD License — For 'ExecuTorch'
software", with copyright holders Meta Platforms, Inc. and affiliates, Arm, Qualcomm
Innovation Center, Apple, MediaTek, NXP, Samsung Electronics and Intel. GitHub's repo
sidebar summarises the licence as "Other (NOASSERTION)" — that is GitHub failing to match
the multi-holder file to a single SPDX template, not a different licence. The verified
fact replacing the old "[verify]" is therefore: **BSD-3-Clause**.*

## The Rust / Apple / specialist family

| Runner | Licence | Language | Backends | Essence | Status |
|---|---|---|---|---|---|
| mistral.rs | MIT | Rust | CUDA, Metal, CPU | Fast Rust runner with broad quant support and paged attention | dossier |
| Candle | Apache-2.0 / MIT | Rust | CUDA, Metal, CPU | Hugging Face's minimalist Rust framework underneath several runners | dossier |
| MLX + MLX-LM | MIT | C++/Python | Apple Silicon (unified memory) | Apple's array framework; the unified-memory design exemplar — directly relevant to our Z13 unified-memory work | dossier |
| ExLlamaV2 | MIT | Python + CUDA kernels | NVIDIA CUDA | GPTQ/EXL2 specialist; extremely fast single-user NVIDIA inference. **Superseded — verified 2026-11-15 (sweep #3):** its own README now opens with a note headed "This project is archived for now. Development continues on ExLlamaV3" (the GitHub repository itself is *not* flagged as a public archive — the archival is by README declaration, not by GitHub archive status) | dossier |
| ExLlamaV3 | MIT (verified 2026-11-15, project repo `turboderp-org/exllamav3` licence field) | Python + CUDA kernels | NVIDIA CUDA (CUDA 12.4+, per project README installation section) | ExLlamaV2's successor (repo created 2025-04-06): EXL3 quantization (based on QTIP), tensor/expert-parallel inference and CPU offloading for MoE models on consumer GPUs; served through TabbyAPI, which its README names the official and recommended backend server | mapped (added 2026-11-15, sweep #3) |
| Magnitude | Apache-2.0 (verified 2026-11-15, project repo `magnitudedev/magnitude` licence field) | Rust (inference engine, per project repo) + TypeScript control plane / desktop shell | Metal (Apple Silicon), CUDA (NVIDIA), Vulkan, CPU — Apple Silicon, NVIDIA, AMD and Intel GPUs or CPU-only, per project README | Self-optimising local inference engine for desktop agents (repo created 2026-06-12): instead of shipping one-size-fits-all kernels it compiles and tunes kernels on the user's own hardware at model-download time, then connects in one click to agent harnesses (Pi, OpenCode, Hermes, Codex, Claude Code and more, per project README) | mapped (added 2026-11-15, sweep #3) |
| PowerInfer | MIT (verified 2026-11-15, per dossier) | C++ | CPU+GPU hybrid | Exploits activation sparsity: hot neurons on GPU, cold on CPU — a memory-hierarchy idea worth its dossier | dossier |
| FlashInfer | Apache-2.0 | C++/CUDA kernels | NVIDIA (+AMD work) | **Infrastructure, not a runner** — a kernel library: the attention-kernel substrate others build on | dossier (papers/flashinfer.md) — infrastructure |

## The vendor stacks (NPU / platform runtimes)

| Runner | Licence | Language | Backends | Essence | Status |
|---|---|---|---|---|---|
| AMD Lemonade | Apache-2.0 | C++ | llama.cpp backends (CPU, CUDA, Vulkan, ROCm, Metal), FastFlowLM on AMD XDNA2 NPU, ONNX Runtime GenAI | AMD-sponsored local AI server (project started 2025): OpenAI/Anthropic/Ollama-compatible APIs on one port; the Ryzen AI NPU+GPU serving reference | mapped (added 2026-11-15) |
| Microsoft Foundry Local | Mixed, exactly as the project states it (verified 2026-11-15, `microsoft/foundry-local` README, License section): "Foundry Local SDK is licensed under the MIT license" and "Foundry Local CLI is licensed under the Microsoft Software License Terms" — GitHub's sidebar summarises the combined file as "Other (NOASSERTION)", the same pattern as Modular MAX above; do not cite it as plain MIT | C++ runtime (native SDKs for C, C++, C#, JavaScript, Python and Rust, per project README) | ONNX Runtime — NPU, GPU or CPU, auto-selected for the device (per project README); Windows, macOS (Apple silicon) and Linux | Microsoft's on-device runtime, announced at //Build 2025 (per Microsoft's own Tech Community material; repo created 2025-03-31): a ~20 MB runtime + curated, hardware-optimised model catalog designed to be shipped *inside* an app — model acquisition, hardware acceleration and inference in-process, with an optional OpenAI-compatible local server; explicitly single-user, and its own FAQ points multi-user serving at vLLM / Triton | mapped (added 2026-11-15, sweep #3) |
| Intel IPEX-LLM | Apache-2.0 | Python (PyTorch library) | Intel CPU, iGPU, Arc dGPU, NPU | BigDL-lineage PyTorch library for low-bit local LLM inference/fine-tuning on Intel XPU; integrates with llama.cpp, Ollama, vLLM. **ARCHIVED — verified 2026-11-15:** its own README now opens "THIS PROJECT IS ARCHIVED — Intel will not provide or guarantee development of or support for this project, including but not limited to, maintenance, bug fixes, new releases or updates. Patches to this project are no longer accepted by Intel." and the repository is a public archive; its last README news item is 2025/05 and its last release noted there is 2.2.0 (2025/04). Treat as a frozen reference, not a living stack | mapped (added 2026-11-15; archived status added 2026-11-15, sweep #2) |
| Qualcomm Genie | Proprietary (ships inside Qualcomm's QAIRT / AI Engine Direct SDK under Qualcomm SDK terms; no open-source licence) | C/C++ | Snapdragon Hexagon HTP NPU, Adreno GPU, CPU (QNN backends) | Qualcomm's GenAI inference engine: dialog-style LLM runtime for Snapdragon, models prepared via Qualcomm AI Hub | mapped (added 2026-11-15; public facts only — SDK-gated) |
| MediaTek NeuroPilot | Proprietary (MediaTek SDK; public-fact level only) | C/C++ (Neuron Runtime API) + TFLite-based tooling | MediaTek APU/NPU (MDLA), GPU, CPU | MediaTek's AI SDK stack for Dimensity: compiles models to proprietary .dla binaries for the APU; the current LLM path runs through the LiteRT NeuroPilot Accelerator | mapped (added 2026-11-15; public facts only — SDK-gated) |

## The minimal / educational lineage

| Runner | Licence | Language | Backends | Essence | Status |
|---|---|---|---|---|---|
| llama2.c | MIT | C (one file) | CPU | Karpathy's 700-line inference; the clearest possible statement of what a runner minimally is | mapped |
| llm.c | MIT | C/CUDA | CPU, CUDA | Karpathy's training twin; read for kernel-education value, not serving design | mapped |

## Sweep notes

- The map is deliberately wider than "things like Ollama": serving economics, kernel
  libraries, and compiler stacks all hold ideas our Go runner can steal.
- Gaps closed by the 2026-11-15 sweep update: Qualcomm Genie and MediaTek NeuroPilot
  (public-fact entries; both SDKs are licence-gated, so internals beyond public
  documentation stay out of reach), RamaLama, AMD Lemonade, Intel IPEX-LLM, and
  llamafile are now enumerated entries rather than named gaps.
- Gaps closed by sweep #2 (2026-11-15): the ExecuTorch licence "[verify]" is resolved
  (BSD-3-Clause, see the note in the compiler family); TGI's maintenance-mode status is
  recorded with HF's own date and recommendation; IPEX-LLM's archival is recorded;
  GPUStack, OpenLLM, NVIDIA Dynamo, llm-d, llama-swap, Modular MAX and TensorRT
  Edge-LLM are enumerated.
- Gaps closed by sweep #3 (2026-11-15): the 2026 newcomers DeepInfer and TokenSpeed,
  the 2025 local/platform entrants the earlier sweeps had not reached (Docker Model
  Runner, LiteRT-LM, Microsoft Foundry Local), ExLlamaV2's successor ExLlamaV3, and
  the self-tuning local engine Magnitude are enumerated; the TensorRT-LLM backend
  removal, the Triton → Dynamo-Triton rename, the Dynamo 1.0 and llm-d 1.0 milestones,
  Ollama's MLX engine and ExLlamaV2's archived-for-now status are recorded in place.
- Still named gaps: Genie/NeuroPilot behaviour beyond the public documentation
  (SDK-gated); any late-2026 newcomers the sweep has not yet reached (vllm.cpp is the
  named watch item — see the sweep #3 log's rejection entry).
- Licence discipline matters commercially and legally: AGPL entries (KoboldCpp,
  Sonar/Aphrodite) are studied for behaviour/ideas only — nothing of theirs is ever
  carried into code. Jan is **no longer** on that list: its AGPL-3.0 era is historical
  and its current licence is Apache-2.0 (verified 2026-11-15, per `runners/jan.md`).

*Next: dossiers in priority order — GPT4All and LM Studio (in flight), then the
vendor stacks (Lemonade first — it is the Strix Halo NPU reference), LocalAI,
and the remaining mapped serving engines.*

## Sweep log

- **2026-11-15 — OR-1 sweep update (v1 → v2).**
  - **Rename:** Aphrodite Engine → **Sonar** (renamed 2026-11-07/08; PygmalionAI →
    dphnAI organisation; AGPL-3.0 unchanged). Source: banked dossier
    `runners/aphrodite.md`.
  - **Licence correction:** Jan — AGPL-3.0 is historical; current licence is
    **Apache-2.0** (verified 2026-11-15 against Jan's own documentation; the exact
    relicensing point could not be verified and the entry says so). Source: banked
    dossier `runners/jan.md`. Jan removed from the AGPL behaviour-only list above.
  - **Count repair:** v1 recounted row by row = **34** entries (the
    MASTER-COMPENDIUM's figure; campaign reporting of 38 was wrong). With the 6
    additions below, this version enumerates **40**.
  - **Status updates:** every banked dossier in `runners/` is now marked
    **dossier** (17 dossiers: ollama, llamacpp-ggml, vllm, sglang, mlx, powerinfer,
    exllamav2, mistral-rs, tensorrt-llm, mlc-llm, lmdeploy, koboldcpp,
    onnx-runtime-genai, openvino-genai, candle, aphrodite/sonar, jan). GPT4All and
    LM Studio dossiers were still in flight when the tree was read — both stay
    **mapped**. PowerInfer's "[verify]" dropped: MIT verified per its dossier.
    WebLLM's entry now records that it is covered inside the MLC dossier.
    FlashInfer is explicitly tagged **infrastructure** (kernel library, dossier at
    `papers/flashinfer.md`).
  - **Entries added (6), each verified 2026-11-15:**
    - *RamaLama* — MIT, Python, container-wrapped llama.cpp/vLLM. Source: project
      repository `containers/ramalama` on GitHub, opened 2026-11-15 (licence field,
      README hardware/runtime tables).
    - *llamafile* — Apache-2.0. Source: llamafile licence/openness fact review
      (reviewed 2026-10-01; Mozilla.ai organisation, single-executable design,
      llama.cpp changes MIT).
    - *AMD Lemonade* — Apache-2.0, C++. Source: project repository
      `lemonade-sdk/lemonade` on GitHub, opened 2026-11-15 (licence field, README
      supported-configurations table: llama.cpp backends, FastFlowLM NPU, ONNX
      Runtime GenAI).
    - *Intel IPEX-LLM* — Apache-2.0, Python/PyTorch, BigDL lineage. Source: GitHub
      API licence field for the ipex-llm repository (SPDX Apache-2.0) and Intel's
      Open Edge Platform IPEX-LLM documentation, both read 2026-11-15.
    - *Qualcomm Genie* — proprietary, inside the QAIRT / AI Engine Direct SDK.
      Sources: Qualcomm's own AI developer-workflow documentation (docs.qualcomm.com,
      "Qualcomm GenAI Inference Engine (Genie)") and Qualcomm support-forum answers
      describing the Genie SDK for LLM work, read 2026-11-15. Public facts only.
    - *MediaTek NeuroPilot* — proprietary SDK, public-fact level. Sources:
      MediaTek Dimensity Developer Center NeuroPilot documentation (Neuron SDK /
      Neuron Runtime API, .dla compiled binaries) and the Google Developers Blog
      post on the LiteRT NeuroPilot Accelerator (2025-12-08), read 2026-11-15.
  - **Already present, confirmed not gaps:** DeepSpeed-FastGen (datacentre table),
    llama2.c / llm.c (minimal lineage), FlashInfer (specialist table, now tagged
    infrastructure), WebLLM (compiler family, MLC-dossier coverage noted).

- **2026-11-15 — OR-1 field-map sweep #2 (v2 → v3, 40 → 47 entries).**
  All facts below were checked 2026-11-15 against each project's own repository,
  LICENSE file, README or official docs — never listicles alone.
  - **ExecuTorch licence — "[verify]" RESOLVED:** **BSD-3-Clause.** Sources:
    `pytorch/executorch` README ("ExecuTorch is BSD licensed. See LICENSE.") and its
    LICENSE file (three-clause BSD text, multi-holder copyright list), both opened
    2026-11-15. GitHub's sidebar "Other (NOASSERTION)" summary is explained in the
    entry note. No "[verify]" remains anywhere in this map.
  - **Hugging Face TGI — already enumerated in v2, expanded in place (not a new
    entry):** Apache-2.0, Rust + Python + gRPC, CUDA/ROCm + other hardware variants
    per its README. Status, dated from HF's own sources: HF's TGI documentation
    states "Text Generation Inference is in maintenance mode as of 12/11/2025" and
    that only minor bug-fix / documentation / lightweight-maintenance PRs will be
    accepted; the repo README's caution banner names vLLM and SGLang as the engines
    HF contributes to and recommends going forward, plus llama.cpp / MLX locally;
    HF's Inference Endpoints docs recommend vLLM or SGLang as alternatives; the
    GitHub repository was shown as a public archive when checked 2026-11-15.
  - **Entries added (7), each verified 2026-11-15 from its own repo:**
    - *GPUStack* (`gpustack/gpustack`) — Apache-2.0, Python, orchestrates
      vLLM/SGLang/TensorRT-LLM/custom engines across nine accelerator families.
    - *OpenLLM* (`bentoml/OpenLLM`) — Apache-2.0, Python, vLLM backend via BentoML.
    - *NVIDIA Dynamo* (`ai-dynamo/dynamo`, repo created 2025-03-03) — Apache-2.0
      per its LICENSE file (with an MIT-licensed bundled test-data subset noted in
      that file), Rust + Python, orchestration above vLLM/SGLang/TensorRT-LLM.
    - *llm-d* (`llm-d/llm-d`, repo created 2025-04-29) — Apache-2.0, Go core
      components on Kubernetes, above vLLM/SGLang; CNCF Sandbox per its README.
    - *llama-swap* (`mostlygeek/llama-swap`) — MIT, Go, model-swap proxy for
      llama.cpp/vLLM-class local servers.
    - *Modular MAX* (`modular/modular`) — mixed licence exactly as its README
      states it (MAX_LICENSE portions + Apache-2.0 with LLVM Exceptions remainder;
      Mojo Apache-2.0 with LLVM Exceptions), Mojo + Python, MAX Serve
      OpenAI-compatible server open-sourced May 2025 per its README.
    - *NVIDIA TensorRT Edge-LLM* (`NVIDIA/TensorRT-Edge-LLM`, repo created
      2025-10-02) — Apache-2.0, C++, Jetson/DRIVE/DGX Spark edge runtime.
  - **Already present, verified and expanded (not re-added):** *NVIDIA Triton
    Inference Server* — BSD-3-Clause confirmed against its repo licence field,
    active, README current release 2.74.0; *Xinference* — Apache-2.0 confirmed,
    active, engine list (vLLM/SGLang/TensorRT-LLM/Transformers/llama.cpp/MLX) taken
    from its README.
  - **llama.cpp serving companions checked:** `llama-server` **router mode** —
    verified from the ggml-org team's Hugging Face blog post "New in llama.cpp:
    Model Management", published 2025-12-11 (dynamic load/unload/switch, multi-process,
    no restart) and recorded inside the existing llama.cpp entry, not as a separate
    entry; *llama-swap* — added as its own entry (above).
  - **Existing entries amended (verified changes only):**
    - *Intel IPEX-LLM* — **archived**: README banner "THIS PROJECT IS ARCHIVED"
      (Intel: no development/support, patches no longer accepted) + public-archive
      repository status, checked 2026-11-15; last README news 2025/05.
    - *Hugging Face TGI* — maintenance-mode status + HF recommendation + archive
      status (above).
    - *ExecuTorch* — licence "[verify]" → BSD-3-Clause (above).
    - *llama.cpp* — router-mode companion note (above).
  - **Currency pass — checked, no verified change, left untouched:** *Jan*
    (README still states Apache 2.0; repo active, not archived), *GPT4All*
    (MIT per repo licence field; not archived), *MLC-LLM* (Apache-2.0 per repo
    licence field; not archived). *Sonar/Aphrodite* rename was already recorded
    in v2 and was not re-litigated.
  - **Candidates checked and REJECTED (one line each, with reason):**
    - *KServe* (`kserve/kserve`, Apache-2.0 verified) — rejected: a Kubernetes
      orchestration platform, not an inference engine/runner itself; it delegates
      to vLLM/llm-d-class runtimes already mapped — duplicate of the orchestration
      layer this sweep already covers with llm-d/Dynamo/Ray Serve.
    - *Cloudflare Infire* — rejected: a real Rust LLM engine (Cloudflare's own
      blog, 2025-08-27) but internal to Workers AI with no public repository or
      licence found in Cloudflare's own material — no public presence /
      unverifiable licence.
    - *ik_llama.cpp* (`ikawrakow/ik_llama.cpp`) — rejected: a llama.cpp fork
      (extra quant types/kernels; it also ships inside llama-swap's unified
      image) — duplicate-of-entry, the fork pattern already covered by
      llama.cpp/KoboldCpp.
    - *Mooncake / LMCache* — rejected: KV-cache transfer/storage infrastructure
      surfaced in newcomer searches, not a runner or serving system.
    - *KAITO, SIE and similar Kubernetes wrappers* — rejected for this sweep:
      surfaced only in third-party listicles; not verified from their own
      repositories, so no licence/status fact could be stated honestly.

- **2026-11-15 — OR-1 field-map sweep #3 (v3 → v4, 47 → 54 entries).**
  All facts below were checked 2026-11-15 against each project's own repository,
  LICENSE file, README or official announcement — never search snippets or
  listicles alone. The field *has* moved since v3, in all three categories the
  sweep was charged with: new entrants, status changes, and milestones.
  - **Entries added (7), each verified 2026-11-15 from its own repo/announcement:**
    - *DeepInfer* (`deepseek-ai/DeepInfer`, repo created 2026-10-16) — Apache-2.0
      per repo licence field and README licence section; README: "the
      high-performance inference framework that powers DeepSeek's large-scale
      production services", offline inference, one supported model
      (DeepSeek-V4.1-Flash), hardware NVIDIA SM100 + Huawei Ascend 950, and an
      explicit "not included in this release" list (KV cache system,
      VE/prefill/decode disaggregation, load balancing). Secondary coverage dates
      the open-sourcing announcement to 2026-10-20; the repo creation date above
      is the primary-source date.
    - *TokenSpeed* (`lightseekorg/tokenspeed`, repo created 2026-05-06) — MIT per
      repo licence field; README core-components section (C++ control plane /
      Python execution plane, pluggable kernel system, Rust entrypoint via SMG
      and Dynamo) and README news section (announced May 2026; TokenSpeed MLA
      adopted by vLLM is stated on the project's own blog, linked from the repo).
      Project docs (lightseek.org, linked from the repo) give CUDA and
      ROCm 7.2 host paths.
    - *Docker Model Runner* (`docker/model-runner`, repo created 2025-03-28) —
      Apache-2.0 per repo licence field; Go per repo (`go.mod`, Go 1.25+ build
      prerequisite in README); README llama.cpp-integration and vLLM-integration
      sections give the backends and the Vulkan/CUDA/ROCm llama-server variants.
      GA date 2025-09-18 and beta date April 2025 are from Docker's own GA blog
      post ("Docker Model Runner: Now Generally Available", published
      2025-09-18). A 2025 entrant the v1–v3 sweeps missed, not a 2026 newcomer —
      recorded as such.
    - *LiteRT-LM* (`google-ai-edge/LiteRT-LM`, repo created 2025-04-14) —
      Apache-2.0 per repo licence field; README: "production-ready orchestration
      layer to run LLMs with LiteRT", cross-platform support list, GPU/NPU
      hardware acceleration, stable C++/Python/Kotlin APIs, and the
      Chrome/Chromebook Plus/Pixel Watch production claim. Also a 2025 entrant
      missed by earlier sweeps.
    - *Microsoft Foundry Local* (`microsoft/foundry-local`, repo created
      2025-03-31) — mixed licence exactly as its README's License section states
      it (SDK MIT; CLI under Microsoft Software License Terms; GitHub sidebar
      "Other (NOASSERTION)" noted in the entry, the Modular MAX pattern);
      README: C++ runtime, ONNX Runtime inference, NPU/GPU/CPU auto-selection,
      Windows/macOS (Apple silicon)/Linux, single-user by design. "Announced at
      //Build 2025" is from Microsoft's own Tech Community material.
    - *ExLlamaV3* (`turboderp-org/exllamav3`, repo created 2025-04-06) — MIT per
      repo licence field; README: EXL3 quantization based on QTIP, CUDA 12.4+
      installation requirement, TabbyAPI named its official/recommended server.
      Added as its own entry *and* as the succession half of the ExLlamaV2
      status change below — not counted twice.
    - *Magnitude* (`magnitudedev/magnitude`, repo created 2026-06-12) —
      Apache-2.0 per repo licence field; README: on-device kernel tuning at
      model-download time, hardware list (Apple Silicon, NVIDIA, AMD, Intel,
      CPU-only), agent-harness connections, Apache 2.0 stated in its own FAQ.
      Rust for the inference engine is the repo's own primary language
      classification / `inference/` tree.
  - **Existing entries amended (verified changes only):**
    - *Ollama* — MLX backend added: Ollama's own blog ("Ollama is now powered
      by MLX on Apple Silicon in preview", v0.19 download, testing dated
      2026-03-29 in the post) states Apple-silicon Ollama is now built on MLX;
      the same post's acknowledgements and Ollama 0.30 coverage in the project's
      own blog index show llama.cpp continuing elsewhere, so the entry records
      MLX as an addition, not a replacement.
    - *TensorRT-LLM* — essence rewritten: NVIDIA's own release notes (Release
      1.2 section, read 2026-11-15) state the TensorRT backend's removal and
      PyTorch as sole execution backend, with the engine-build CLIs removed.
      The v3 essence ("compiled-graph serving") described a workflow the
      maintainer has deleted, so leaving it would have been a stale claim.
    - *NVIDIA Triton Inference Server* — renamed in the entry heading to
      *NVIDIA Dynamo-Triton (formerly Triton Inference Server)*: NVIDIA's own
      developer product page carries exactly that "formerly" wording, and an
      NVIDIA developer-blog footnote dates the rename to 2025-03-18. Licence,
      language and backend facts are unchanged from sweep #2's verification.
    - *NVIDIA Dynamo* — 1.0 milestone added: NVIDIA's own press release of
      2026-03-16 (GTC, Globe Newswire) announces "NVIDIA Dynamo 1.0" as a
      production-grade release; NVIDIA's Dynamo documentation carries the
      matching v1.0.0 release page.
    - *llm-d* — 1.0 milestone added: the contributors' announcement of
      2026-10-20 (carried on IBM's newsroom, one of the founding organisations)
      announces llm-d 1.0, a stable v1 configuration API, and states the project
      is "now governed by the Cloud Native Computing Foundation (CNCF)" — the
      entry keeps the earlier CNCF Sandbox line as its historical note and adds
      the 1.0/governance statement as the current one.
    - *ExLlamaV2* — archived-for-now status added, quoted from its own README's
      opening note ("This project is archived for now. Development continues on
      ExLlamaV3"); the entry states explicitly that the GitHub repository flag
      is *not* a public archive, so the two archive mechanisms are not conflated
      (contrast TGI and IPEX-LLM, which are GitHub public archives).
  - **Currency pass — checked, no verified change, left untouched:**
    *Hugging Face TGI* (re-opened 2026-11-15: repository still a public archive,
    README caution banner unchanged in substance — the March-2026 archive date
    circulating in secondary comparisons was *not* confirmed from an HF primary
    source, so no date was added), *MLC-LLM* (no archival, maintenance-mode or
    licence-change announcement surfaced from the project's own sources),
    *LMDeploy* (active release line through 2026 per its own package index),
    *SGLang* (the RadixArk commercial spin-out was reported from January 2026
    onward, but the secondary sources conflict on its dates and no project
    rename, licence change or archival was verified from SGLang's own
    repository/docs — a company formation is not, by itself, an entry change),
    *GPUStack / Xinference / OpenLLM* (active release lines in 2026 per their
    own project channels; no status-class event found — ordinary version
    releases are not map amendments).
  - **Candidates checked and REJECTED (with reason):**
    - *vllm.cpp* (`localai-org/vllm.cpp`, Apache-2.0, C++20, repo created
      2026-07-02 — all verified from its own repo) — rejected *for this sweep*:
      its own README states it is "under heavy development" with breakage
      expected on `main`, and its latest release is v0.0.2 (August 2026). A real
      engine, but it has not yet reached the notable-maturity bar the other 2026
      additions (DeepInfer, TokenSpeed, Magnitude) clear. Named watch item for
      sweep #4; this is a maturity rejection, not an existence doubt.
    - *KServe* — re-checked after it surfaced again in 2026 Kubernetes-serving
      comparisons: the sweep #2 reason stands unchanged (orchestration platform
      delegating to already-mapped runtimes) and no new evidence overturns it;
      not re-proposed as an entry.
    - *Mooncake / LMCache* — surfaced again (named as integrations in NVIDIA's
      Dynamo 1.0 press release): still KV-cache transfer/storage infrastructure,
      not runners; the sweep #2 reason stands.
    - *vllm-metal* — rejected: a vLLM plugin bringing vLLM's scheduler to Apple
      Silicon via MLX (v0.30.0, September 2026, per secondary coverage) —
      duplicate-of-entry (vLLM, MLX), the plugin/fork pattern already covered.
    - *Aiport* (local LLM gateway, launched 2026-11-08 per secondary coverage)
      and *ModelDock* (Windows local runner, November 2026 secondary coverage) —
      rejected for this sweep: surfaced only in secondary/news coverage; no
      primary repository was verified, so no licence/language/backend fact
      could be stated honestly — the sweep #2 KAITO/SIE precedent.
    - *microkimi, tinyinfer and similar from-scratch engines* — rejected:
      small educational / single-author engines surfaced in newcomer searches;
      no notable maturity or adoption verified from primary sources — the
      minimal/educational lineage is already represented by llama2.c / llm.c.
