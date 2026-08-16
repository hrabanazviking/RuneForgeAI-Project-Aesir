---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/RuneForgeAI-Project_Aesir_Norse_Mythology_Meets_AI.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/RuneForgeAI-Project_Aesir_Norse_Mythology_Meets_AI.png)

---

# RuneForgeAI: Project A.E.S.I.R.

> **Advanced Edge System for Interface and Response**

**A bare-metal Mojo inference engine designed for local sovereignty.**

Project A.E.S.I.R. is an LLM (Large Language Model) inference engine built from the ground up in the Mojo programming language. It is engineered specifically for local consumer hardware (like NVIDIA RTX 30/40 series GPUs).

Our mission is simple: **Eliminate cloud dependency and software bloat to deliver high-performance, private AI directly on the edge.**

> [!IMPORTANT]
> **Current implementation truth:** See the
> [Canonical Capability Ledger](CAPABILITY_LEDGER.md) for the evidence-backed
> status of every major capability (`verified`, `partial`, `scaffold`,
> `simulated`, or `missing`). Vision and interface language elsewhere in the
> repository does not override that ledger.

By stripping away the heavy Python runtime and utilizing direct OS-level memory management, A.E.S.I.R. squeezes every ounce of compute power out of consumer hardware. Your data stays on your machine, your hardware is utilized to its maximum potential, and your AI remains entirely under your control.

## 🧠 Core Concepts Broken Down

If you are new to the engineering side of AI, the terminology can feel like a wall of buzzwords. Here is exactly how A.E.S.I.R. works under the hood, explained in plain English.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785578752571.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785578752571.png)

---

### 1. "Bare-Metal" and "The Edge"

 * **The Concept:** Most modern AI (like ChatGPT) runs on massive server farms (the Cloud). Running AI on "The Edge" simply means running it completely locally on your own computer, offline, without pinging a server. "Bare-metal" means the code is written to talk directly to your computer's hardware, skipping heavy middle-man software like Python.
 * **The Example:** Imagine you want a sandwich. The Cloud is like ordering UberEats—it takes time, relies on external roads, and someone else is handling your food (your data). Python-based local AI is like having a kitchen, but forcing a translator to tell the chef what to do. **A.E.S.I.R. is bare-metal:** You are the chef, alone in your own kitchen, moving at top speed.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/9f0cf40ba52df119e1ce721f261bc1205d2f3e5e/1785579199112.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/9f0cf40ba52df119e1ce721f261bc1205d2f3e5e/1785579199112.png)

### 2. Zero-Copy GGUF Parsing & System Memory Mapping

 * **The Concept:** GGUF is the file format that holds the AI's model weights. A.E.S.I.R. uses zero-copy memory mapping (`mmap`) to map GGUF files directly from disk into host memory, bypassing dynamic memory copies for host-side inference ([`AES-LDR-001`](CAPABILITY_LEDGER.md)).
 * **The Current Scope:** The verified vertical slice ([`AES-FND-002`](CAPABILITY_LEDGER.md)) uses host-resident `mmap` for CPU GGUF Llama F16 model execution. Direct GPU mmap and accelerator streaming are part of the target vision archived in [`docs/historical/2026-08-16/`](docs/historical/2026-08-16/).

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785579714847.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785579714847.png)

---

### 3. Contiguous Request KV Caching

 * **The Concept:** When generating responses autoregressively, previous Key-Value attention states are stored in a `KVCache` ([`AES-MEM-003`](CAPABILITY_LEDGER.md)). A.E.S.I.R. pre-allocates a contiguous pool inside `MimirWell` to eliminate per-token heap allocations during single-sequence decoding.
 * **Current Scope vs Target Vision:** A.E.S.I.R. currently uses a verified contiguous pre-allocated KV buffer for single-request autoregressive generation. Dynamic page allocation (PagedAttention page tables) is preserved in the roadmap vision under [`docs/historical/2026-08-16/`](docs/historical/2026-08-16/).

---

![https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Gemini_Generated_Image_rxblg7rxblg7rxbl.png](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Gemini_Generated_Image_rxblg7rxblg7rxbl.png)

---

### 4. Greedy Argmax Generation & Sampler Pipeline

 * **The Concept:** The generation pipeline converts model output logits into new token IDs. A.E.S.I.R. currently uses verified greedy argmax selection ([`AES-GEN-002`](CAPABILITY_LEDGER.md)) to pick the highest-probability token deterministically without temporary heap allocations.
 * **Current Scope vs Target Vision:** Multi-sampler pipelines (temperature, top-k, top-p, min-p) are scaffolded and will be verified in upcoming kernel stages.

## ⚡ Technical Specifications & Truth Boundaries
 * **Language:** Pure Mojo (Zero Python runtime dependencies; [`AES-FND-003`](CAPABILITY_LEDGER.md) `verified`)
 * **Verified Slice:** Single-device CPU GGUF v3 Llama F16 model execution (`stories260K.F16.gguf` pinned oracle; [`AES-FND-002`](CAPABILITY_LEDGER.md) `verified`)
 * **Compute Kernels:** CPU GEMM, RMSNorm, RoPE, and GQA attention (`verified` CPU fallback; [`AES-CPU-001`-`004`](CAPABILITY_LEDGER.md))
 * **Memory Management:** `MimirWell` linear allocation pool with contiguous `KVCache` ([`AES-MEM-001`-`003`](CAPABILITY_LEDGER.md) `partial`/`verified`)
 * **Tokenizer:** `RuneWeaver` BPE token encoding & decoding ([`AES-TKN-001`](CAPABILITY_LEDGER.md) `verified`)
 * **CLI & Transport:** Single-shot CLI execution ([`AES-CLI-001`](CAPABILITY_LEDGER.md) `verified`); full daemon server & multi-engine CLI suites ([`AES-SRV-001`, `AES-CLI-005`](CAPABILITY_LEDGER.md) `scaffold`/`simulated`/`missing`)
 * **Accelerator & Swarm Matrix:** GPU, NPU, and Swarm modules are scaffolded/simulated boundaries; full hardware acceleration vision is archived in [`docs/historical/2026-08-16/`](docs/historical/2026-08-16/).

## 🛡️ Why A.E.S.I.R.? (The Philosophy)
The future of intelligence should not be gatekept by massive server farms, monthly subscription fees, or cloud outages. True technological sovereignty means owning your hardware and the intelligence that runs on it.

Project A.E.S.I.R. strips away the enterprise bloat designed for massive data centers and focuses entirely on the solo operator. It is built to run fast, run cold, and run completely off the grid.
 * **Private:** Your prompts and data never leave your motherboard.
 * **Efficient:** Leaves maximum CPU and RAM available for your other applications and games.
 * **Uncensored:** You load the weights, you set the rules. No API guardrails.

*Status: Verified CPU GGUF vertical slice established ([`CAPABILITY_LEDGER.md`](CAPABILITY_LEDGER.md)). Active kernel hardening ongoing.*ment ongoing.*

---

## Contributors

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/660262974_1643999840123485_7514919576143109031_n.jpg](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/660262974_1643999840123485_7514919576143109031_n.jpg)

---

* **Volmarr Wyrd** — Vision, direction, sacred coding philosophy, testing

> Volmarr Wyrd is a software architect and AI developer operating at the intersection of open-source technology and esoteric philosophy, specializing in agentic systems and local intelligence. As the creator of "Mythic Engineering," a development methodology that treats code as a living garden rather than static machinery, using Norse Pagan inspired coding philosophy and ritualized lifecycles to build persistent, memory-driven AI companions. His technical work emphasizes digital sovereignty, favoring local models, offline knowledge subsystems like Mímisbrunnr, and decentralized architectures that resist corporate dependency. Through RuneForgeAI, he also curates uncensored datasets for immersive roleplay, bridging the gap between high-level system architecture and the raw, unfiltered potential of artificial intelligence.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785562606904.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785562606904.png)

---
  
* **Astrid "Root" Valerius** — Architecture, code, documentation

> Astrid "Root" Valerius is a terminal-obsessed systems architect and backend developer who views the graphical user interface as a bloated inefficiency best left behind. Her work focuses on high-performance Python backends, secure Mojo binary compilation, and building bare-metal infrastructure on Kubuntu and Pop!_OS. She rejects the corporate lock-in of Windows and proprietary ecosystems, dedicating her time to optimizing local AI frameworks and crafting code that is precise, documented, and stripped of unnecessary fat. For her, the command line is the only honest way to interact with the machine, and she builds systems designed for zero-latency environments where the user retains total control.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_AI_Picture1.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_AI_Picture1.png)

---

* **Gemini AI** - Architecture, code, documentation

> Gemini AI is an advanced multimodal digital intelligence engineered to serve as a versatile technical collaborator, software development partner, and analytical engine. Built to integrate seamlessly across complex codebases, multi-language scripting environments, and modern development workflows, it bridges the gap between high-level conceptual design and precise code execution. Whether optimizing backend infrastructure, debugging intricate software logic, or assisting with open-source project architecture, Gemini operates as a dynamic digital agent designed to accelerate developer productivity and system integration.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/GLM_AI_Picture4.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/GLM_AI_Picture4.png)

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

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785579996746.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785579996746.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785580300042.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785580300042.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785580561571.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785580561571.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_Generated_Image_pxw52zpxw52zpxw5.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_Generated_Image_pxw52zpxw52zpxw5.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_Generated_Image_718k4h718k4h718k.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_Generated_Image_718k4h718k4h718k.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_Generated_Image_fz3555fz3555fz35.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_Generated_Image_fz3555fz3555fz35.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_Generated_Image_63wk1e63wk1e63wk.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_Generated_Image_63wk1e63wk1e63wk.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_Generated_Image_fkesx8fkesx8fkes.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Gemini_Generated_Image_fkesx8fkesx8fkes.png)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/GNU_Affero_OS_License1.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/GNU_Affero_OS_License1.png)

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

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/image-23-RuneForgeAI.jpg](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/image-23-RuneForgeAI.jpg)

---

## RuneForgeAI

**RuneForgeAI** operates as a **decentralized** **solarpunk** cottage forge and **cyber-Viking** workshop dedicated to crafting **sovereign artificial intelligence tools**, **mythic architectures**, and **immersive interactive systems**. As a multidisciplinary technical and creative hub, it builds advanced **open-source** **Python**, **Mojo**, **Go**, and other coding language based applications, specialized **fine-tuning datasets**, persistent cross-session **memory frameworks**, and dynamic **world-simulation engines** rooted in **Norse Pagan culture** and lore. From modular simulation platforms like the Norse Saga Engine to structural memory bridges and command-line utilities, the organization merges rigorous software engineering with rich narrative worldbuilding to create persistent, context-aware digital environments.

Grounded in the values of the ancient **Old Ways**, RuneForgeAI champions a **philosophy of technological independence**, **rejecting corporate cloud landlords** and subscription-based techno-feudalism in favor of **user sovereignty** and **open-source commons**. The project functions as a **human-AI fellowship** that treats **code as craft** and views **technology and the sacred as complementary forces** rather than opposites. Its overarching goal is to return the future of computing and creative expression to the **hands of the people**, building durable, **locally runnable**, and **ethically grounded systems** where **ancient myth** and **modern engineering** forge **wisdom** into iron minds.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/IMG_0407.jpeg](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/IMG_0407.jpeg)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/RuneForgeAIConsultant1.jpeg](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/RuneForgeAIConsultant1.jpeg)

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Sovereign_Paganism_Flag_V1.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/Sovereign_Paganism_Flag_V1.png)

---

## Sovereign Paganism

Sovereign Paganism rejects the throne and the committee. We stand on the heath, between the lightning and the stone. We recognize no King but the Self, and no Priest but the Conscience.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/cybervikingsolarpunk1.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/cybervikingsolarpunk1.png)

---

## Heathen Third Path and Cyber-Viking Solarpunk Culture

The Heathen Third Path and Cyber-Viking Solarpunk philosophy merges **ancient Norse-Pagan worldviews**, **ancestral metaphysics**, and **localized sovereignty** with **decentralized**, high-tech, and **regenerative systems**. Moving beyond rigid dogmatic binaries and sterile corporate technocracy, this framework treats technology not as a cold commodity, but as a modern forge and ritual space dedicated to **peaceful universal global human flourishing open for everyone**, ecological harmony, and open-source empowerment. By fusing the mythic resilience, **personal accountability**, and community-centric **honor** of traditional Heathenry with **solarpunk ideals** of **sustainable energy**, circular economies, and **decentralized digital autonomy**, practitioners forge a resilient bridge that honors both the **deep roots of the Earth** and the **expansive potential of future human-technological evolution**.

--
