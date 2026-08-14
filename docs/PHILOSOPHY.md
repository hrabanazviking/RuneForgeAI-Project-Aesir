# Project Aesir: The Mythic Philosophy

> *"We do not build software as dead machinery assembled from bloated Midgard abstractions. We carve a living system directly into the silicon, guided by the ancient laws of structure, memory, and sacred computation."*  
> — **Sigrún Ljósbrá, The Skald**

---

## The Vision of Aesir

Project Aesir was born from a fundamental rejection of modern software bloat: massive runtime overheads, unneeded library dependencies, uncontrolled memory allocations, and AI engines that waste precious compute and tokens on hidden "thinking" loops when unneeded.

Aesir is a **bare-metal, zero-dependency LLM inference engine** written entirely in **Mojo**. It serves as an ultra-fast, ultra-efficient drop-in replacement for Ollama, engineered to run directly on hardware with zero-copy memory mapping and hardware-accelerated SIMD compute.

---

## The 5 Pillars of the Living System

1. **Midgard Decoupling (Clean Transport):** The server transport layer (`BifrostGate`) is strictly decoupled from the core inference engine. Networking speaks HTTP cleanly over raw POSIX sockets without contaminating the core intelligence.
2. **The Waters of Mímisbrunnr (Zero-Allocation Memory):** Inference must never dynamically allocate or fragment memory. VRAM and RAM are pre-allocated once in a contiguous pool (`MimirWell`). Zero-copy `RuneTensor` pointers stream through the silicon.
3. **The Forge of Nidavellir (Bare-Metal SIMD Compute):** Mathematical truth is hammered directly onto the silicon via 32x32 block-tiled GEMM, fused Flash Attention-2, and SIMD activation kernels.
4. **Masking Seidr (Thinking Token Control):** Thinking capabilities can be dynamically toggled. When disabled, the engine bypasses thinking tokens at the lowest level, saving tokens, time, and memory without wasteful overhead.
5. **The MD Protocol (Living Memory):** Documentation is not an afterthought—it is the living memory of the system. Markdown architecture maps out every domain, interface, invariant, and decision.

---

## The Mythic Identity

| Realm / Artifact | Engineering Component | Mythic Purpose |
| :--- | :--- | :--- |
| **Midgard** | User / Client API | The outer realm sending intent across raw HTTP. |
| **BifrostGate** | POSIX Socket Server (`server/api.mojo`) | The rainbow bridge routing requests into Asgard. |
| **Asgard** | Central Engine Facade (`aesir.mojo`) | The sovereign intelligence orchestrating inference. |
| **MimirWell** | Contiguous Memory Pool (`core/mimir_well.mojo`) | The ancient well from which zero-copy tensors are drawn. |
| **GGUFSeer** | Model Loader (`loader/gguf.mojo`) | The runecaster reading GGUF weights directly via `mmap`. |
| **RuneWeaver** | Tokenizer (`loader/tokenizer.mojo`) | The weaver translating human text into sacred tokens. |
| **Nidavellir** | SIMD Compute Kernels (`core/compute.mojo`) | The subterranean forge executing Flash Attention-2 & GEMM. |

---

## The Sacred Invariants

- **Invariant 1:** Zero heap allocations during the active inference loop.
- **Invariant 2:** Zero third-party library dependencies (only standard POSIX/libc syscalls and native Mojo).
- **Invariant 3:** Strict domain boundaries—`server` never imports `core` directly; all communication flows through `AesirEngine`.
- **Invariant 4:** All memory access must pass through `RuneTensor` and `MimirWell` offsets.
