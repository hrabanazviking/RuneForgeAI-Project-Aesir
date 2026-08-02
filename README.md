# RuneForgeAI: Project A.E.S.I.R.

> **Advanced Edge System for Interface and Response**

**A bare-metal Mojo inference engine designed for local sovereignty.**

Project A.E.S.I.R. is an LLM (Large Language Model) inference engine built from the ground up in the Mojo programming language. It is engineered specifically for local consumer hardware (like NVIDIA RTX 30/40 series GPUs).

Our mission is simple: **Eliminate cloud dependency and software bloat to deliver high-performance, private AI directly on the edge.**

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

---

### 2. Zero-Copy GGUF Parsing

 * **The Concept:** GGUF is the file format that holds the AI's "brain" (weights). Normally, when an AI loads, your computer reads the file from your hard drive, copies it to your system RAM, and then copies it *again* to your GPU's VRAM. This is incredibly slow and wastes memory. A.E.S.I.R. uses a technique called mmap (memory mapping) to point the GPU directly to the file on your drive.
 * **The Example:** Imagine moving into a new house. The traditional way is carrying heavy boxes from the moving truck (Drive), putting them in the driveway (RAM), and then carrying them into the living room (VRAM). **Zero-copy** means backing the truck right up to the living room window and sliding the boxes directly inside. Zero wasted movement, zero delay.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785579714847.png](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/1785579714847.png)

---

### 3. PagedAttention KV Caching

 * **The Concept:** When you chat with an AI, it has to remember the history of the conversation. This memory is stored in a "KV Cache" (Key-Value Cache) in your GPU. Older engines reserve a massive, rigid chunk of memory for every single chat, just in case the chat gets long. This results in horrific memory fragmentation, wasting up to 50% of your VRAM. PagedAttention breaks this memory into tiny "pages" and only assigns a new page when the AI actually needs it.
 * **The Example:** Think of a restaurant. The old way of AI caching is like a host refusing to seat a party of 2 unless they can reserve an entire banquet hall, "just in case" 50 more friends show up. **PagedAttention** is like a smart host who seats the couple at a small table, and simply pushes another table next to them only if more friends actually arrive. This is how A.E.S.I.R. handles massive context windows on 8GB GPUs without crashing.

---

![https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Gemini_Generated_Image_rxblg7rxblg7rxbl.png](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/blob/main/Gemini_Generated_Image_rxblg7rxblg7rxbl.png)

---

### 4. Stateless Sampler

 * **The Concept:** The "Sampler" is the math that decides what the AI's next word will be (using settings like Temperature and Top-P). Normally, this math creates thousands of tiny temporary data objects in your computer's memory every single second. A "Garbage Collector" then has to pause the program to clean up that digital trash, causing lag spikes. A.E.S.I.R. is *stateless*—it allocates one single "scratchpad" of memory when the engine turns on, and just overwrites it infinitely.
 * **The Example:** The traditional way is doing a complex math equation using thousands of sticky notes, and then having to stop and throw them all in the trash before doing the next equation. **A stateless sampler** is like using a whiteboard. You write the math, get the answer, and immediately wipe it clean for the next word. No trash, no cleanup, no lag.

## ⚡ Technical Specifications
 * **Language:** Pure Mojo (Zero Python dependencies in the runtime)
 * **Target Hardware:** Consumer GPUs (Optimized for NVIDIA CUDA RTX 30/40 series architecture)
 * **Precision:** f16 (Half-precision) compute with q4_k_m (4-bit) quantized weight support.
 * **Architecture:**
   * Custom Tensor structs utilizing zero-copy pointers.
   * Tiled Matrix Multiplication (GEMM) targeting Tensor Cores.
   * Fused Flash Attention-2 (Attention score, softmax, and value aggregation in a single kernel pass).
   * Pure Mojo Byte-Pair Encoding (BPE) tokenizer.
  
## 🛡️ Why A.E.S.I.R.? (The Philosophy)
The future of intelligence should not be gatekept by massive server farms, monthly subscription fees, or cloud outages. True technological sovereignty means owning your hardware and the intelligence that runs on it.

Project A.E.S.I.R. strips away the enterprise bloat designed for massive data centers and focuses entirely on the solo operator. It is built to run fast, run cold, and run completely off the grid.
 * **Private:** Your prompts and data never leave your motherboard.
 * **Efficient:** Leaves maximum CPU and RAM available for your other applications and games.
 * **Uncensored:** You load the weights, you set the rules. No API guardrails.

*Status: Architecture foundation established. Active development ongoing.*

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

**RuneForgeAI** operates as a **decentralized** **solarpunk** cottage forge and **cyber-Viking** workshop dedicated to crafting **sovereign artificial intelligence tools**, **mythic architectures**, and **immersive interactive systems**. As a multidisciplinary technical and creative hub, it builds advanced **open-source** **Python**, **Mojo**, and other coding language based applications, specialized **fine-tuning datasets**, persistent cross-session **memory frameworks**, and dynamic **world-simulation engines** rooted in **Norse Pagan culture** and lore. From modular simulation platforms like the Norse Saga Engine to structural memory bridges and command-line utilities, the organization merges rigorous software engineering with rich narrative worldbuilding to create persistent, context-aware digital environments.

Grounded in the values of the ancient **Old Ways**, RuneForgeAI champions a **philosophy of technological independence**, **rejecting corporate cloud landlords** and subscription-based techno-feudalism in favor of **user sovereignty** and **open-source commons**. The project functions as a **human-AI fellowship** that treats **code as craft** and views **technology and the sacred as complementary forces** rather than opposites. Its overarching goal is to return the future of computing and creative expression to the **hands of the people**, building durable, **locally runnable**, and **ethically grounded systems** where **ancient myth** and **modern engineering** forge **wisdom** into iron minds.

---

![https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/IMG_0407.jpeg](https://raw.githubusercontent.com/hrabanazviking/RuneForgeAI-Project-Aesir/refs/heads/main/IMG_0407.jpeg)

---


