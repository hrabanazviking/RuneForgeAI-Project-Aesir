# Qwen3.8 Research Source Ledger

**Research snapshot:** 2026-11-02  
**Project:** Project Aesir  
**Coverage:** Qwen3.8-27B and Qwen3.8-Flash-Next

---

# 1. Purpose

This ledger records the sources used across the Project Aesir Qwen3.8 research dossier and separates them by evidentiary role.

The research follows this hierarchy:

1. **Tier 1 — Qwen/Alibaba primary material** for model facts, architecture, training claims, benchmark claims and official usage guidance.
2. **Tier 2 — upstream implementation/runtime material** for concrete integration behavior, tensor mapping, runtime flags, memory figures and implementation support.
3. **Tier 3 — community ecosystem evidence** for local quantization sizes, experimental hardware execution and emerging optimization work.

Tier 3 evidence is never used to silently override a Tier 1 architectural fact.

---

# 2. Tier 1 — Qwen3.8-27B official model card

**URL:** https://huggingface.co/Qwen/Qwen3.8-27B

Use for:

- official model identity;
- causal LM + vision encoder description;
- 27B size;
- dense architecture description;
- 16 × [3 Gated DeltaNet + 1 Gated Attention] layout;
- GDN and Gated Attention head dimensions;
- 262,144 native context;
- 1M YaRN guidance;
- thinking/non-thinking behavior;
- `reasoning_effort` values;
- `preserve_thinking` guidance;
- recommended sampling settings;
- image/video support;
- hour-scale video guidance;
- reported text/coding/agent/VL benchmark tables;
- vLLM/SGLang/TokenSpeed deployment examples.

This is the primary source for user-visible model behavior.

---

# 3. Tier 1 — Qwen3.8-27B official configuration

**URL:** https://huggingface.co/Qwen/Qwen3.8-27B/blob/main/config.json

Use for exact structural fields such as:

```text
architectures
model_type
hidden_size
num_hidden_layers
vocab_size
intermediate_size
full_attention_interval
linear_num_key_heads
linear_num_value_heads
linear_key_head_dim
linear_value_head_dim
linear_conv_kernel_dim
num_attention_heads
num_key_value_heads
head_dim
rope_parameters
mrope_section
mrope_interleaved
partial_rotary_factor
attn_output_gate
output_gate_type
mtp_num_hidden_layers
vision_config
```

When prose and config differ in granularity, config is preferred for exact dimensions.

---

# 4. Tier 1 — Qwen3.8-27B official FP8

**URL:** https://huggingface.co/Qwen/Qwen3.8-27B-FP8

Use for:

- official FP8 availability;
- fine-grained FP8 method;
- block-size information;
- Qwen's claim that evaluation is nearly identical to original precision.

Do not generalize the model's official FP8 performance to hardware that lacks an efficient matching FP8 kernel.

---

# 5. Tier 1 — Qwen3.8 official GitHub repository

**URL:** https://github.com/QwenLM/Qwen3.8

Use for:

- release chronology;
- family lineup;
- installation/deployment guidance;
- family-level capability claims;
- language-coverage claims;
- links to official serving paths and artifacts.

Family-level claims are not automatically rewritten as exact per-checkpoint benchmark guarantees.

---

# 6. Tier 1 — Qwen3.8 official blog

**URL:** https://qwen.ai/blog?id=qwen3.8

Use for:

- Qwen's intended positioning of the generation;
- high-level reasoning, coding, agentic and multimodal improvements;
- product/generation context.

Exact numeric architecture should still come from model config/model card.

---

# 7. Tier 1 — QwenCloud Qwen3.8-27B page

**URL:** https://www.qwencloud.com/models/qwen3.8-27b

Use for hosted-service facts such as:

- service context/output limits;
- prefix completion;
- hosted function calling;
- structured output;
- caching/service integrations;
- hosted built-in tools.

**Important caveat:** hosted tools such as web search or code interpreter are service capabilities around the model. They are not described in this dossier as if those external services were physically contained in the open-weight checkpoint.

---

# 8. Tier 1 — Alibaba Model Studio Qwen3.8 material

**URL:** https://www.alibabacloud.com/help/en/model-studio/qwen3-8-27b

Use for:

- official hosted deployment/product context;
- service-side capability confirmation.

Again, service capabilities and checkpoint capabilities are kept distinct.

---

# 9. Tier 1 — Flash-Next official repository

**URL:** https://github.com/QwenLM/Qwen3.8-Flash-Next

Use for:

- official release status/date;
- explicit statement that Flash-Next previews architecture intended for Qwen4;
- high-level architecture overview;
- references to official model/config/runtime material.

This is the main source establishing Flash-Next's role as a Qwen4 precursor.

---

# 10. Tier 1 — Flash-Next official model

**URL:** https://huggingface.co/Qwen/Qwen3.8-Flash-Next

Use for:

- model identity;
- multimodal task classification;
- `qwen4_exp` architecture identifier;
- official repository structure;
- model-card behavior and deployment guidance.

Hugging Face repository metadata currently reports the model at approximately 180B parameters when auxiliary capacity is included.

---

# 11. Tier 1 — Flash-Next official FP8 model card

**URL:** https://huggingface.co/Qwen/Qwen3.8-Flash-Next-FP8

Use for:

- detailed architecture table;
- 125B main model;
- ~6B active parameters/token;
- 51B n-gram embeddings;
- 48-layer hybrid layout;
- GDN dimensions;
- QSA dimensions;
- 512 experts / 10 routed + 1 shared;
- four-branch Gated Residual;
- MTP;
- vision configuration;
- official FP8 availability;
- license metadata.

---

# 12. Tier 1 — Flash-Next official configuration

**URL:** https://huggingface.co/Qwen/Qwen3.8-Flash-Next/blob/main/config.json

Primary source for exact fields including:

```text
model_type = qwen4_exp
hidden_size = 2560
num_hidden_layers = 48
full_attention_interval = 4
hc_count = 4
hc_lowrank = 320
num_experts = 512
num_experts_per_tok = 10
num_shared_experts = 1
moe_intermediate_size = 640
indexer_num_heads = 4
indexer_num_key_value_heads = 1
indexer_head_dim = 128
indexer_budget = 2048
indexer_compress_ratio = 4
ngram_vocab_size_base = 20000000
ngram_size = 3
ple_layer_ids = [2]
ple_embed_dim = 2560
ple_conv_kernel_size = 4
heads_per_ngram = 8
split_ngram_parts = 128
mtp_num_hidden_layers = 1
```

This is preferred over secondary summaries for exact preview dimensions.

---

# 13. Tier 1 — Alibaba/Qwen Flash-Next architecture article

**URL:** https://www.alibabacloud.com/blog/qwen3-8-flash-next-a-new-architecture-towardsultimate-cost-efficiency_603501

Use for the conceptual and engineering rationale behind:

- Gated DeltaNet + Qwen Sparse Attention;
- micro-block QSA selection;
- QSA long-context kernel speed claims;
- Gated Residual design;
- four residual branches;
- read/write gating;
- activation-outlier suppression;
- FP8 Residual State storage;
- N-gram Embedding / PLE concept;
- deterministic host-memory offload and asynchronous prefetch;
- Muon + AdamW optimizer split;
- scaling-law refitting;
- removal of batch-size warmup;
- reported 18.8% optimizer-step overhead of the rejected warmup approach;
- stability mechanisms;
- MTP training and speculative acceptance;
- 1/9 training-FLOPs comparison to Qwen3.7-Plus.

Performance ratios are always treated as setup-specific reported measurements, not universal Aesir expectations.

---

# 14. Tier 1 — Qwen technical report

**URL:** https://arxiv.org/abs/2608.30320

Use for:

- formal architecture/training motivation;
- scaling-law research;
- QSA training methodology;
- optimizer work;
- sparse/lookup-memory analysis;
- efficiency comparisons;
- observation that language-model loss and downstream capability can diverge when selecting n-gram capacity.

Where a secondary summary provided a convenient implementation detail, the dossier labels it as supporting interpretation rather than elevating it above the report/config.

---

# 15. Tier 2 — Hugging Face Transformers Qwen4-Exp documentation

**URL:** https://github.com/huggingface/transformers/blob/main/docs/source/en/model_doc/qwen4_exp.md

Use for:

- upstream `qwen4_exp` implementation terminology;
- Qwen4Exp configuration/model interface;
- Gated Residual, QSA and PLE implementation framing;
- golden-reference planning for tiny synthetic models.

For Aesir, Transformers is primarily a numerical reference, not a runtime architecture to copy wholesale.

---

# 16. Tier 2 — llama.cpp Qwen4Exp converter

**URL:** https://github.com/ggml-org/llama.cpp/blob/master/conversion/qwen4exp.py

Use for:

- upstream confirmation of Qwen4Exp/Flash-Next tensor mapping;
- relationship to existing Qwen3.5 GDN/mRoPE machinery;
- additional QSA, Hyper-Connection/Gated Residual and PLE tensors;
- MTP conversion structure;
- GGUF metadata design clues.

A converter proving that a tensor can be stored does not by itself prove optimized runtime support.

---

# 17. Tier 2 — vLLM Qwen3.8-27B recipe

**URL:** https://github.com/vllm-project/recipes/blob/main/models/Qwen/Qwen3.8-27B.yaml

Use for runtime evidence such as:

- 262K native serving;
- 1M YaRN configuration;
- MTP speculative setup;
- text-only mode;
- multimodal serving;
- reasoning parser;
- tool-call parser;
- practical high-precision model memory guidance.

---

# 18. Tier 2 — vLLM Flash-Next recipe

**URL:** https://github.com/vllm-project/recipes/blob/main/models/Qwen/Qwen3.8-Flash-Next.yaml

Use for:

- current Qwen4-Exp serving support;
- QSA/MTP runtime notes;
- BF16/FP8/MXFP4 memory figures;
- n-gram host-memory offload requirements;
- current backend limitations;
- text-only/multimodal serving;
- context-extension configuration.

Backend-specific limitations are not described as fundamental architecture limitations.

---

# 19. Tier 2 — ggml-org Qwen3.8-27B GGUF

**URL:** https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF

Use for concrete upstream GGUF artifact examples:

```text
BF16 ≈ 53.8 GB
Q8_0 ≈ 28.6 GB
Q4_K_M ≈ 19 GB
```

and separate auxiliary artifacts for:

- vision projector;
- MTP;
- speculative draft mechanisms.

These file sizes are useful for local planning but may change as conversion layouts evolve.

---

# 20. Tier 2 — llama.cpp project

**URL:** https://github.com/ggml-org/llama.cpp

Use for broader GGUF/runtime context:

- quantization formats;
- model metadata conventions;
- multimodal sidecar patterns;
- local inference reference behavior.

Project Aesir remains an independent engine and should validate behavior rather than importing design assumptions uncritically.

---

# 21. Tier 3 — community Qwen3.8-27B quant repositories

Examples include community GGUF publishers that provide Q6/Q5/Q4/IQ variants beyond the upstream minimal set.

Use only for:

- real artifact-size observations;
- available quant-format diversity;
- emerging llama.cpp compatibility evidence.

Do not use community quant metadata as the authoritative model architecture.

---

# 22. Tier 3 — community Flash-Next GGUF conversions

Large community conversions currently expose many low-bit `qwen4exp` formats.

Use for:

- observed package sizes;
- proof that sub-128GB low-bit artifacts can be constructed;
- practical quantization experimentation.

Do **not** interpret "file fits in 128 GB" as "complete model plus state will run comfortably in 128 GB."

Runtime headroom still includes:

- OS memory;
- workspaces;
- context state;
- vision;
- MTP;
- PLE handling;
- allocator overhead.

---

# 23. Tier 3 — specialized consumer Flash-Next runtimes

Independent projects have explored Flash-Next on large unified-memory consumer systems and split APU/eGPU systems.

Use for hypothesis generation around:

- recurrent-state rollback cost;
- expert streaming;
- sparse-attention bandwidth;
- boundary transfers;
- consumer unified-memory feasibility.

These measurements are not treated as official Qwen benchmarks.

---

# 24. Source handling rules used in this dossier

## Rule A — exact architecture comes from config/model card first

Example:

```text
Flash-Next experts = 512
```

comes from official configuration, not a blog repost.

## Rule B — architecture rationale comes from Qwen/Alibaba technical material

Example:

```text
QSA uses compressed micro-block selection to lower indexing cost
```

comes from the official architecture write-up/report.

## Rule C — runtime memory comes from the runtime implementing that representation

Example:

```text
vLLM FP8 Flash-Next checkpoint memory
```

is cited as a vLLM recipe figure, not a universal theoretical minimum.

## Rule D — community artifact sizes are labeled community

No community quant is presented as an official Qwen release unless Qwen published it.

## Rule E — analysis is labeled as Aesir analysis

Examples:

- SSD-backed PLE;
- hot/cold expert precision;
- Q6 sweet-spot hypothesis;
- adaptive MTP drafting;
- component-aware residency.

These are engineering proposals derived from the architecture, not claims that Qwen officially recommends those exact strategies.

---

# 25. Known ambiguity: total Flash-Next parameter count

Different sources can display different headline counts because the architecture contains multiple capacity pools.

Use these meanings:

```text
125B = main model parameters
~6B = active main-model parameters/token
51B = n-gram embedding capacity
~4B = MTP/auxiliary module
~180B = approximate total repository metadata/accounting
```

Do not compare Flash-Next to a dense 180B transformer by raw total count alone.

---

# 26. Known ambiguity: QSA speedup numbers

Official/implementation material reports different QSA speedups depending on kernel revision, hardware and benchmark setup.

Examples in current material range from approximately:

```text
7.6× prefill / 4.9× decode
```

to implementation-specific later figures around:

```text
10.2× prefill / 6.6× decode
```

The dossier therefore uses the qualitative conclusion confidently and the ratios only with context:

> QSA dramatically reduces long-context attention work in the tested configurations.

---

# 27. Known ambiguity: 1M context

Both models are **native 262,144-token models**.

The 1M configuration is an officially documented YaRN extension.

Therefore the dossier consistently distinguishes:

```text
native context = 262,144
extended context = up to ~1,000,000 with YaRN
```

Hosted Qwen services may expose 1M as a service context limit, but that does not rewrite the open checkpoint's native position configuration.

---

# 28. Known ambiguity: image generation

Both models are `image-text-to-text` / native multimodal understanding models.

They accept images and video and produce text.

They are **not themselves diffusion/flow image generators**.

A tool-enabled product may call an external image-generation system. That is separate from the Qwen3.8 language checkpoint decoding pixels.

---

# 29. Known ambiguity: hosted tools

Hosted Qwen services may expose:

- web search;
- code interpreter;
- structured outputs;
- batches;
- other tools.

The research documents distinguish:

```text
model capability to reason about/call tools
```

from:

```text
hosted external service actually executing those tools
```

Project Aesir must supply its own local tool executor where needed.

---

# 30. Recommended refresh procedure

Because Qwen3.8 and Qwen4-era runtimes are evolving quickly, future maintainers should periodically re-check:

1. official Qwen model cards;
2. official config files;
3. Qwen3.8/Flash-Next repositories;
4. Transformers `qwen3_5` / `qwen4_exp` implementation;
5. llama.cpp architecture mapping;
6. vLLM recipes;
7. official Qwen4 release material once available.

When a final Qwen4 checkpoint is released, do not silently overwrite this research. Preserve Flash-Next as a historical architectural preview and add a separate final-Qwen4 comparison.

---

# 31. Research dossier files using this ledger

- `README.md`
- `QWEN38_27B_COMPLETE_RESEARCH.md`
- `QWEN38_FLASH_NEXT_COMPLETE_RESEARCH.md`
- `QWEN38_ARCHITECTURE_COMPARISON.md`
- `QWEN38_LONG_CONTEXT_MULTIMODAL_AGENTIC_RESEARCH.md`
- `QWEN38_INFERENCE_QUANTIZATION_RUNTIME_RESEARCH.md`
- `QWEN38_AESIR_ENGINEERING_IMPLICATIONS.md`
- `SOURCES.md`

---

# 32. Final source principle

The dossier is intentionally conservative about provenance:

> **Official Qwen material defines what the models are. Upstream runtimes show how current software implements them. Community work shows what adventurous local hardware can attempt. Project Aesir research then asks what can be built better.**
