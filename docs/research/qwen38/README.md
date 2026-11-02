# Project Aesir Qwen3.8 Research Dossier

**Research snapshot:** 2026-11-02  
**Scope:** Qwen3.8-27B and Qwen3.8-Flash-Next  
**Purpose:** engineering research for Project Aesir, with special attention to local inference, long context, multimodality, speculative decoding, memory architecture, quantization, and Qwen4-readiness.

---

## Why this dossier exists

Qwen3.8-27B and Qwen3.8-Flash-Next belong to the same broad generation but are not merely different sizes of the same model.

Qwen3.8-27B is a **27B dense native multimodal model** using the Qwen3.5-era hybrid architecture: three Gated DeltaNet layers followed by one Gated Attention layer, repeated across 64 language-model layers.

Qwen3.8-Flash-Next is an **experimental Qwen4 architecture preview**. Its main network is a 125B ultra-sparse MoE with about 6B active parameters per token, plus a 51B n-gram embedding memory and a roughly 4B MTP module. It replaces the ordinary full-attention member of the hybrid pattern with Qwen Sparse Attention, replaces dense FFNs with MoE blocks, widens the residual stream into four Gated Residual branches, and adds a large lookup-memory system designed for asynchronous host-memory offload.

For Aesir, the 27B model is an attractive practical local target while Flash-Next is both a runnable model and a **technology laboratory for the machinery expected to appear in Qwen4**.

---

## Documents

### 1. [QWEN38_27B_COMPLETE_RESEARCH.md](QWEN38_27B_COMPLETE_RESEARCH.md)

Deep technical research on the normal Qwen3.8-27B model:

- exact architecture and configuration
- dense hybrid GDN + Gated Attention layout
- recurrent-state versus KV-cache behavior
- MTP support
- native 262K context and 1M YaRN extension
- multimodal vision/video architecture
- thinking and non-thinking modes
- `reasoning_effort` and `preserve_thinking`
- agent/tool integration
- benchmark profile
- quantization and GGUF ecosystem
- local-inference implications
- Aesir implementation targets

### 2. [QWEN38_FLASH_NEXT_COMPLETE_RESEARCH.md](QWEN38_FLASH_NEXT_COMPLETE_RESEARCH.md)

Deep technical research on Qwen3.8-Flash-Next:

- Qwen4-Exp architecture
- 125B / 6B-active ultra-sparse MoE
- 51B n-gram embedding memory
- GDN + Qwen Sparse Attention
- QSA indexer and micro-block selection
- four-branch Gated Residual
- 512-expert MoE
- MTP speculative decoding
- PLE / n-gram offload
- Muon + AdamW training recipe
- stability mechanisms
- context scaling
- vision/video architecture
- runtime and memory requirements
- consumer-local possibilities and limitations

### 3. [QWEN38_ARCHITECTURE_COMPARISON.md](QWEN38_ARCHITECTURE_COMPARISON.md)

A feature-by-feature comparison of the two models, showing what Aesir can share between them and what requires a new execution path.

### 4. [QWEN38_LONG_CONTEXT_MULTIMODAL_AGENTIC_RESEARCH.md](QWEN38_LONG_CONTEXT_MULTIMODAL_AGENTIC_RESEARCH.md)

Cross-model research focused on:

- 262K native context
- 1M YaRN operation
- mRoPE / partial rotary behavior
- image and video processing
- hour-scale video support
- thinking controls
- preserved reasoning context
- function/tool calling
- prefix caching
- long-horizon agent design
- MTP interaction with agentic workloads

### 5. [QWEN38_INFERENCE_QUANTIZATION_RUNTIME_RESEARCH.md](QWEN38_INFERENCE_QUANTIZATION_RUNTIME_RESEARCH.md)

Local-serving and low-level runtime research:

- BF16, FP8, Q8, Q6, Q5, Q4 and lower-bit formats
- GGUF layouts and auxiliary files
- vision projector handling
- MTP/draft model packaging
- memory bandwidth versus dequantization
- KV/state memory
- vLLM, SGLang, TokenSpeed, Transformers and llama.cpp status
- Flash-Next PLE/offload complications
- test matrices for Project Aesir

### 6. [QWEN38_AESIR_ENGINEERING_IMPLICATIONS.md](QWEN38_AESIR_ENGINEERING_IMPLICATIONS.md)

Turns the research into a Project Aesir implementation map:

- reusable kernels
- state-management design
- config parsing
- long-context memory planning
- multimodal interfaces
- speculative decoding
- MoE routing
- QSA and PLE subsystems
- hardware-adaptive execution
- staged acceptance criteria

### 7. [SOURCES.md](SOURCES.md)

Source ledger with trust tiers. Primary claims are grounded first in official Qwen model cards/configs, Qwen/Alibaba technical material, the Qwen technical report, and first-party runtime recipes. Community material is explicitly separated and used mainly for local quantization/runtime evidence.

---

## Key architectural map

| Feature | Qwen3.8-27B | Qwen3.8-Flash-Next |
|---|---|---|
| Model family identifier | `qwen3_5` | `qwen4_exp` |
| Language-model type | Dense | Ultra-sparse MoE |
| Main parameters | 27B | 125B |
| Active parameters/token | 27B | ~6B |
| Extra n-gram memory | No | 51B |
| MTP | Yes | Yes, dedicated 1-layer module |
| LM layers | 64 | 48 |
| Hidden size | 5120 | 2560 |
| Hybrid cadence | 3 GDN + 1 Gated Attention | 3 GDN + 1 QSA |
| Dense FFN / MoE | Dense FFN | 512-expert MoE |
| Residual design | Qwen3.5-style residual path | 4-branch Gated Residual |
| Native context | 262,144 | 262,144 |
| Extended context | Up to 1,000,000 via YaRN | Up to 1,000,000 via YaRN |
| Vision encoder | Yes | Yes |
| Image input | Yes | Yes |
| Video input | Yes | Yes |
| Text output | Yes | Yes |
| Sparse-attention indexer | No | Yes |
| PLE / n-gram table offload | No | Yes |
| License | Apache-2.0 | Qwen Community 1.0 / model repo marked non-Apache |
| Main Aesir role | Practical dense local target | Qwen4 architecture laboratory |

---

## Research discipline

This dossier separates four kinds of statements:

1. **Model facts** directly present in official model cards/configuration files.
2. **Architecture/training claims** from Qwen/Alibaba technical material and the Qwen3.8-Next technical report.
3. **Runtime facts** from first-party or upstream runtime recipes such as vLLM and llama.cpp.
4. **Aesir analysis** which is explicitly labeled as engineering interpretation or recommendation rather than a Qwen claim.

Hosted-service features are not automatically treated as capabilities implemented inside the open-weight checkpoint. For example, QwenCloud can add built-in web search or code-interpreter tools around a model. The open model can support tool-call formatting and agent workflows without containing those external services internally.

Likewise, community GGUF file sizes and specialized consumer-hardware experiments are useful engineering evidence, but they are not treated as official Qwen performance guarantees.

---

## Relationship to the Qwen4 preparation roadmap

This dossier is companion research for:

[`docs/PROJECT_AESIR_QWEN4_PRELAUNCH_READINESS_ROADMAP.md`](../../PROJECT_AESIR_QWEN4_PRELAUNCH_READINESS_ROADMAP.md)

The roadmap describes what Aesir should build. These documents explain **why those subsystems exist, how the current Qwen3.8 models implement them, and what is already known well enough to test before Qwen4 ships**.
