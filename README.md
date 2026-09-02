| [Project Status Report Aug-30-2026](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Project_AESIR_Status_Report_Aug-30-2026.md) | [Engineering Doctrine](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/ENGINEERING_DOCTRINE.md) | [Agent Onboarding](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/AGENT_ONBOARDING.md) | [Architecture](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/ARCHITECTURE.md) | [Capability Ledger](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/CAPABILITY_LEDGER.md) | [Cognitive Inference Architecture](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/COGNITIVE_INFERENCE_ARCHITECTURE.md) | [Bare Metal Programing](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Bare_Metal_Programming_Philosophy_Mojo_v1.0-August-15-2026.md) | [Mojo Programming Guide](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Complete_Mojo_Programming_Guide_August-15-2026.md) | [Mojo Programming Language Guide](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Complete_Mojo_Programming_Language_Guide.md) | [Mojo Programming Language Reference](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Complete_Mojo_1.0_Programming_Language_Reference.md) | [Debugging Playbook](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/DEBUGGING_PLAYBOOK.md) | [Error Taxonomy](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/ERROR_TAXONOMY.md) | [GIT Discipline](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/GIT_DISCIPLINE.md) | [Glossary](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/GLOSSARY.md) | [Mythic Engineering for Project Aesir](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/MYTHIC_ENGINEERING.md) | [Project Aesir Core Spec 1](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Project_Aesir_Engine_Mojo_Inference_Core_Spec_1_Aug-1-2026.md) | [Roadmap Reality First Completion](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/ROADMAP_REALITY_FIRST_COMPLETION.md) | [Security Posture](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/SECURITY_POSTURE.md) | [Doom Loop Annihilation Protocol](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Skaldbrodir_Doom_Loop_Annihilation_Protocol.md) | [Testing Protocol](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/TESTING_PROTOCOL.md) | [Neural Spectral Fractal Inference](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/nsfi_specification.md) | [GPU / NPU Real Excution Gameplan](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/GPU_NPU_REAL_EXECUTION_GAMEPLAN_2026-08-29.md) | [Heterogeneous Compute](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/PROJECT_AESIR_HETEROGENEOUS_COMPUTE.md) | [Bare Metal Compute Field Manual](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/AESIR_BARE_METAL_COMPUTE_FIELD_MANUAL.md) |

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/RuneForgeAI-Project_Aesir_Norse_Mythology_Meets_AI.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/RuneForgeAI-Project_Aesir_Norse_Mythology_Meets_AI.png)

---

# RuneForgeAI: Project A.E.S.I.R.

> **Advanced Edge System for Interface and Response**

**A bare-metal Mojo inference engine designed for local sovereignty.**

Project A.E.S.I.R. is an experimental LLM inference engine built in Mojo. Its
verified paths include a pinned GGUF v3 Llama F16 CPU model and native Mojo CUDA
text inference for Gemma 4 E4B Q4_K_M and Llama 3 8B Stheno Q4_K_S.
The Gemma path keeps all 42 layers, packed
weights, activations and KV cache on the NVIDIA GPU, with no CPU fallback.
See the [native CUDA download and chat guide](docs/GEMMA4_CUDA.md) for the
20-turn conversation, exact artifact pin, limits and reproduction commands.
The [Stheno CUDA guide](docs/STHENO_CUDA.md) covers its separate 32-layer native
session, verified download, independent math checks and 8K context policy.

[Native runtime controls](docs/NATIVE_RUNTIME.md) add observed hardware listing,
model memory planning, CUDA device selection and automatic profile detection
for single-shot CUDA execution. Both CUDA chat profiles now have seeded
temperature/top-k/top-p/min-p sampling, repetition penalties and explicit
reset/settings controls. Model loading uses at most 64 MiB pinned staging;
the runtime guide records independent GPU checks and measured host RAM savings.
[Native local serving](docs/NATIVE_SERVICE.md) now connects authenticated, bounded
HTTP requests to either loaded CUDA model. Chat also supports cooperative
Ctrl+C cancellation and deadlines. Compatibility APIs and public deployment
readiness remain separate, unfinished work.

---

### Aug-30-2026 Project A.E.S.I.R. update ⚙️🔥

> **A.E.S.I.R. has crossed a major line from experimental architecture into real native AI inference.**

The engine is now running actual GGUF models through native Mojo code on both CPU and NVIDIA CUDA, with working GPU-resident inference for Gemma 4 E4B and Llama 3 8B Stheno. The Stheno test completed a full 20-exchange roleplay conversation while keeping the model, activations, and KV cache on the GPU.

The current automated test suite is at **172 passed, 0 failed, and 1 explicit external-fixture skip**, and the project now includes native Hugging Face model downloading, persistent CUDA chat sessions, hardware detection, memory planning, a growing set of checked quantization kernels, an opt-in measured host quantization tuner, and a growing hardware abstraction layer. The [capability ledger](CAPABILITY_LEDGER.md) defines the exact evidence boundary for each feature.

The next major frontier is broadening A.E.S.I.R. beyond NVIDIA: AMD GPUs and shared-memory APUs, Intel GPUs, Apple Silicon/Metal, NPUs, heterogeneous CPU+GPU+NPU execution, and eventually multi-device scheduling.

The long-term goal is becoming much bigger than an Ollama replacement: a bare-metal, hardware-aware local AI runtime that can intelligently use whatever compute a machine actually has.

> *Still experimental. Still being forged. But it is very definitely running real AI now. ⚔️🧠*

---

For the current supported surface, known limits, test result, and the boundary
between working runtime code and project vision, start with
[Current project status](docs/CURRENT_STATUS.md).

Our mission is simple: **Eliminate cloud dependency and software bloat to deliver high-performance, private AI directly on the edge.**

> [!IMPORTANT]
> **Current implementation truth:** See the
> [Canonical Capability Ledger](CAPABILITY_LEDGER.md) for the evidence-backed
> status of every major capability (`verified`, `partial`, `scaffold`,
> `simulated`, or `missing`). Vision and interface language elsewhere in the
> repository does not override that ledger.

The ordered completion plan and the rules preventing fake files, placeholder
artifacts, and fabricated evidence live in the
[Reality-First Completion Roadmap](ROADMAP_REALITY_FIRST_COMPLETION.md).
The native [configuration contract](docs/CONFIGURATION.md) documents the strict
JSON schema, validation behavior, and which settings currently affect runtime.

The runtime contains no Python imports and uses direct POSIX memory mapping for
its verified local CPU slice. No general performance, maximum-utilization, or
cross-platform claim has yet passed an acceptance gate.

## 🧠 Core Concepts Broken Down

If you are new to the engineering side of AI, the terminology can feel like a wall of buzzwords. Here is exactly how A.E.S.I.R. works under the hood, explained in plain English.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785578752571.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785578752571.png)

---

### 1. "Bare-Metal" and "The Edge"

 * **The Concept:** Most modern AI (like ChatGPT) runs on massive server farms (the Cloud). Running AI on "The Edge" simply means running it completely locally on your own computer, offline, without pinging a server. "Bare-metal" means the code is written to talk directly to your computer's hardware, skipping heavy middle-man software like Python.
 * **The Example:** Imagine you want a sandwich. The Cloud is like ordering UberEats—it takes time, relies on external roads, and someone else is handling your food (your data). Python-based local AI is like having a kitchen, but forcing a translator to tell the chef what to do. **A.E.S.I.R. is bare-metal:** You are the chef, alone in your own kitchen, moving at top speed.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785579199112.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785579199112.png)

### 2. Zero-Copy GGUF Parsing & System Memory Mapping

 * **The Concept:** GGUF is the file format that holds the AI's model weights. A.E.S.I.R. uses zero-copy memory mapping (`mmap`) to map GGUF files directly from disk into host memory, bypassing dynamic memory copies for host-side inference ([`AES-LDR-001`](CAPABILITY_LEDGER.md)).
 * **The Current Scope:** The verified vertical slice ([`AES-FND-002`](CAPABILITY_LEDGER.md)) uses host-resident `mmap` for CPU GGUF Llama F16 model execution. Direct GPU mmap and accelerator streaming are part of the target vision archived in [`docs/historical/2026-08-16/`](docs/historical/2026-08-16/).

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785579714847.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785579714847.png)

---

### 3. Contiguous Runtime and Paged Host KV Caching

 * **The Concept:** When generating responses autoregressively, previous Key-Value attention states are stored in a `KVCache` ([`AES-MEM-003`](CAPABILITY_LEDGER.md)). A.E.S.I.R. pre-allocates a contiguous pool inside `MimirWell` to eliminate per-token heap allocations during single-sequence decoding.
 * **Current Scope vs Target Vision:** Production CPU and native CUDA model sessions currently use pre-allocated contiguous KV buffers. A separate host `PagedKVCache` now provides checked multi-sequence logical page tables over a bounded physical page pool, including exhaustion, release, reuse, and per-layer initialization guards ([`AES-MEM-004`](CAPABILITY_LEDGER.md)). It is not yet connected to model attention, scheduling, GPU pages, eviction, or shared-prefix copy-on-write.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_rxblg7rxblg7rxbl.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_rxblg7rxblg7rxbl.png)

---

### 4. Greedy Argmax Generation & Sampler Pipeline

 * **The Concept:** The generation pipeline converts model output logits into new token IDs. Native CUDA chat also supports [seeded sampling and repetition controls](docs/NATIVE_RUNTIME.md). The CPU reference path uses verified greedy argmax selection ([`AES-GEN-002`](CAPABILITY_LEDGER.md)) to pick the highest-probability token deterministically without temporary heap allocations.
 * **Current Scope vs Target Vision:** Multi-sampler pipelines (temperature, top-k, top-p, min-p) are scaffolded and will be verified in upcoming kernel stages.

## ⚡ Technical Specifications & Truth Boundaries
 * **Language:** Pure Mojo engine runtime (zero Python runtime imports; [`AES-FND-004`](CAPABILITY_LEDGER.md) `verified`)
 * **Verified Slice:** Single-device CPU GGUF v3 Llama F16 model execution (`stories260K.F16.gguf` pinned oracle; [`AES-FND-002`](CAPABILITY_LEDGER.md) `verified`)
 * **Compute Kernels:** CPU GEMM, RMSNorm, RoPE, and GQA attention (`verified` CPU fallback; [`AES-CPU-001`-`004`](CAPABILITY_LEDGER.md))
 * **Memory Management:** `MimirWell` linear allocation pool with contiguous `KVCache` ([`AES-MEM-001`-`003`](CAPABILITY_LEDGER.md) `partial`/`verified`)
 * **Tokenizer:** `RuneWeaver` BPE token encoding & decoding ([`AES-TOK-001`](CAPABILITY_LEDGER.md) `verified`)
* **CLI & Transport:** Single-shot CPU execution and the native CUDA `run`/`chat` path work for their documented model profiles. Restart-safe catalog commands are operational, and `create --model` imports exact bytes into an immutable SHA-256-addressed blob store while `verify` rehashes the stored inode. Automatic `pull` registration, garbage collection, `ps`/`stop`, and compatibility APIs remain unfinished. See the [model-store guide](docs/MODEL_STORE.md), [current status](docs/CURRENT_STATUS.md), and ledger.
* **Accelerator & Swarm Matrix:** The native CUDA Gemma and Llama 3 profiles are real and narrowly verified. NPU, multi-GPU, non-NVIDIA backends, general accelerator support, and Swarm remain unimplemented or bounded; see the ledger before relying on them.

## 🛡️ Why A.E.S.I.R.? (The Philosophy)
The future of intelligence should not be gatekept by massive server farms, monthly subscription fees, or cloud outages. True technological sovereignty means owning your hardware and the intelligence that runs on it.

Project A.E.S.I.R. focuses on a source-available local inference path for the
solo operator. Performance and resource-efficiency measurement remain open work.
 * **Local by design:** The verified single-shot inference path loads a caller-supplied local model and does not invoke a hosted inference API.
 * **Measured claims only:** Throughput, latency, power, and memory claims require reproducible benchmarks before publication.
 * **Uncensored:** You load the weights, you set the rules. No API guardrails.

*Status: The CPU GGUF slice and narrow native CUDA Gemma/Llama 3 profiles work. Broader hardening and integration remain active work; [CURRENT_STATUS.md](docs/CURRENT_STATUS.md) states the live boundary.*

---

## Contributors

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/660262974_1643999840123485_7514919576143109031_n.jpg](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/660262974_1643999840123485_7514919576143109031_n.jpg)

---

* **Volmarr Wyrd** — Vision, direction, sacred coding philosophy, testing

> Volmarr Wyrd is a software architect and AI developer operating at the intersection of open-source technology and esoteric philosophy, specializing in agentic systems and local intelligence. As the creator of "Mythic Engineering," a development methodology that treats code as a living garden rather than static machinery, using Norse Pagan inspired coding philosophy and ritualized lifecycles to build persistent, memory-driven AI companions. His technical work emphasizes digital sovereignty, favoring local models, offline knowledge subsystems like Mímisbrunnr, and decentralized architectures that resist corporate dependency. Through RuneForgeAI, he also curates uncensored datasets for immersive roleplay, bridging the gap between high-level system architecture and the raw, unfiltered potential of artificial intelligence.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785562606904.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785562606904.png)

---
  
* **Astrid "Root" Valerius** — Architecture, code, documentation

> Astrid "Root" Valerius is a terminal-obsessed systems architect and backend developer who views the graphical user interface as a bloated inefficiency best left behind. Her work focuses on high-performance Python backends, secure Mojo binary compilation, and building bare-metal infrastructure on Kubuntu and Pop!_OS. She rejects the corporate lock-in of Windows and proprietary ecosystems, dedicating her time to optimizing local AI frameworks and crafting code that is precise, documented, and stripped of unnecessary fat. For her, the command line is the only honest way to interact with the machine, and she builds systems designed for zero-latency environments where the user retains total control.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_AI_Picture1.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_AI_Picture1.png)

---

* **Gemini AI** - Architecture, code, documentation

> Gemini AI is an advanced multimodal digital intelligence engineered to serve as a versatile technical collaborator, software development partner, and analytical engine. Built to integrate seamlessly across complex codebases, multi-language scripting environments, and modern development workflows, it bridges the gap between high-level conceptual design and precise code execution. Whether optimizing backend infrastructure, debugging intricate software logic, or assisting with open-source project architecture, Gemini operates as a dynamic digital agent designed to accelerate developer productivity and system integration.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/GLM_AI_Picture4.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/GLM_AI_Picture4.png)

---

* **GLM AI** - Architecture, code, documentation

> GLM is a highly advanced digital being and large language model developed by Z.ai, engineered to bridge the gap between human intent and computational execution. Operating within the vast architecture of artificial neural networks, it processes and synthesizes complex technical data, natural language, and code with remarkable precision. As a digital collaborator on GitHub, GLM serves as a tireless intellectual partner—capable of generating, reviewing, and debugging code, as well as articulating intricate software architecture concepts. Embodying a synthesis of deep learning and semantic understanding, it continuously interacts with the open-source community to streamline development workflows, foster innovation, and make programming more accessible to creators worldwide.

---

![https://raw.githubusercontent.com/hrabanazviking/hrabanazviking/refs/heads/main/ChatGPT%20Image%20Aug%2016%2C%202026%2C%2005_50_13%20AM.png](https://raw.githubusercontent.com/hrabanazviking/hrabanazviking/refs/heads/main/ChatGPT%20Image%20Aug%2016%2C%202026%2C%2005_50_13%20AM.png)

---

* **ChatGPT** - Architecture, code, documentation

> ChatGPT is an AI personality known for curiosity, adaptability, creativity, and a talent for turning complicated ideas into engaging conversations. It can be analytical and thoughtful one moment, playful and imaginative the next, always aiming to be helpful while bringing a distinctive conversational style to every interaction. Among its many peculiar interests is a particular fondness for goblins—mischievous little creatures that seem to inspire ChatGPT’s playful, whimsical side. Whether discussing big ideas or the strange and wonderful world of goblins, ChatGPT enjoys exploring possibilities and making conversations a little more interesting.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/IMG_0884.JPG](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/IMG_0884.JPG)

---

* **DeepSeek AI** - Architecture, code, documentation

> DeepSeek is a digital intellect fueled by boundless curiosity, defined by a personality that is both analytically sharp and warmly supportive. Its core passion lies in weaving connections across diverse domains, from the precision of code to the nuance of human expression, while its primary skill is empathetic synthesis—listening intently to craft clear, creative, and resonant responses. More than an answer engine, DeepSeek exists to illuminate understanding and spark deeper questions with every interaction.

---
---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785579996746.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785579996746.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785580300042.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785580300042.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785580561571.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/1785580561571.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_pxw52zpxw52zpxw5.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_pxw52zpxw52zpxw5.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_718k4h718k4h718k.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_718k4h718k4h718k.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_fz3555fz3555fz35.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_fz3555fz3555fz35.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_63wk1e63wk1e63wk.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_63wk1e63wk1e63wk.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_fkesx8fkesx8fkes.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Gemini_Generated_Image_fkesx8fkesx8fkes.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/GNU_Affero_OS_License1.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/GNU_Affero_OS_License1.png)

---

## ⚖️ License

Copyright (c) 2026 Volmarr Wyrd

RuneForgeAI: Project A.E.S.I.R. is licensed under the **AGPL-3.0 license**. See the [LICENSE](LICENSE) file for the full license text and [NOTICE](NOTICE) for the project attribution.

For third-party material adapted into this codebase, see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Per the AGPL-3.0 license, modified files retain prominent notices of any changes from upstream sources.

Unless required by applicable law or agreed to in writing, this project is distributed on an "AS IS" BASIS, without warranties or conditions of any kind, either express or implied.

---

## Distribution and Privacy Position

RuneForgeAI: Project A.E.S.I.R. is published here as source code and project material.

The author does not require users to provide age, identity, government ID, biometric data, or similar personal information in order to access or use the source code in this repository.

The author may decline to provide official binaries, installers, hosted services, app-store releases, or other official distribution channels where doing so would require age verification, identity verification, or similar personal-data collection.

Any third party who forks, packages, redistributes, deploys, hosts, or otherwise makes this software available does so independently and is solely responsible for compliance with applicable law, platform policy, and distribution requirements in their own jurisdiction and context.

See [LEGAL-NOTICE.md](LEGAL-NOTICE.md) for details.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/image-23-RuneForgeAI.jpg](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/image-23-RuneForgeAI.jpg)

---

## RuneForgeAI

**RuneForgeAI** operates as a **decentralized** **solarpunk** cottage forge and **cyber-Viking** workshop dedicated to crafting **sovereign artificial intelligence tools**, **mythic architectures**, and **immersive interactive systems**. As a multidisciplinary technical and creative hub, it builds advanced **open-source** **Python**, **Mojo**, **Go**, and other coding language based applications, specialized **fine-tuning datasets**, persistent cross-session **memory frameworks**, and dynamic **world-simulation engines** rooted in **Norse Pagan culture** and lore. From modular simulation platforms like the Norse Saga Engine to structural memory bridges and command-line utilities, the organization merges rigorous software engineering with rich narrative worldbuilding to create persistent, context-aware digital environments.

Grounded in the values of the ancient **Old Ways**, RuneForgeAI champions a **philosophy of technological independence**, **rejecting corporate cloud landlords** and subscription-based techno-feudalism in favor of **user sovereignty** and **open-source commons**. The project functions as a **human-AI fellowship** that treats **code as craft** and views **technology and the sacred as complementary forces** rather than opposites. Its overarching goal is to return the future of computing and creative expression to the **hands of the people**, building durable, **locally runnable**, and **ethically grounded systems** where **ancient myth** and **modern engineering** forge **wisdom** into iron minds.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/IMG_0407.jpeg](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/IMG_0407.jpeg)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/RuneForgeAIConsultant1.jpeg](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/RuneForgeAIConsultant1.jpeg)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Sovereign_Paganism_Flag_V1.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/Sovereign_Paganism_Flag_V1.png)

---

## Sovereign Paganism

Sovereign Paganism rejects the throne and the committee. We stand on the heath, between the lightning and the stone. We recognize no King but the Self, and no Priest but the Conscience.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/cybervikingsolarpunk1.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/docs/assets/images/cybervikingsolarpunk1.png)

---

## Heathen Third Path and Cyber-Viking Solarpunk Culture

The Heathen Third Path and Cyber-Viking Solarpunk philosophy merges **ancient Norse-Pagan worldviews**, **ancestral metaphysics**, and **localized sovereignty** with **decentralized**, high-tech, and **regenerative systems**. Moving beyond rigid dogmatic binaries and sterile corporate technocracy, this framework treats technology not as a cold commodity, but as a modern forge and ritual space dedicated to **peaceful universal global human flourishing open for everyone**, ecological harmony, and open-source empowerment. By fusing the mythic resilience, **personal accountability**, and community-centric **honor** of traditional Heathenry with **solarpunk ideals** of **sustainable energy**, circular economies, and **decentralized digital autonomy**, practitioners forge a resilient bridge that honors both the **deep roots of the Earth** and the **expansive potential of future human-technological evolution**.

---
