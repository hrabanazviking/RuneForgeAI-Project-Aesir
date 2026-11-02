# 01 - Source Ledger and Research Methodology

**Research snapshot:** 2026-11-02  
**Models:** Qwen3-0.6B, Qwen3-1.7B, Qwen3-4B, Qwen3-8B

This file defines how the rest of the research library should be interpreted. Its purpose is to prevent three common engineering mistakes: copying marketing shorthand into an implementation contract, treating third-party benchmark numbers as local Aesir performance, and confusing a plausible optimization with a proven one.

---

## Evidence labels

### UPSTREAM FACT

A statement directly supported by an official Qwen model card, official configuration file, official Qwen repository/documentation, or the Qwen3 technical report.

### AESIR FACT

A statement supported by code, tests, measurements, or filed evidence already in Project Aesir. An Aesir fact may still be narrow. For example, a speedup measured on one host and one quant is not automatically a speedup on every machine.

### ENGINEERING RECOMMENDATION

A design choice that follows from model structure or performance principles but has not yet been promoted by Aesir's own measurements.

### EXPERIMENT

A proposed test that should produce evidence before a recommendation becomes a default.

---

# A. Primary Qwen sources

## A.1 Qwen3 launch article

https://qwenlm.github.io/blog/qwen3/

Use for:

- official dense-model lineup;
- Apache-2.0 status of the dense Qwen3 family;
- layer/head/tied-embedding overview;
- approximately 36 trillion pretraining tokens;
- 119 languages and dialects;
- three-stage pretraining description;
- high-level thinking/non-thinking design.

Launch-table values:

| Model | Layers | Heads Q/KV | Tied embeddings | Launch-table context |
|---|---:|---:|---|---:|
| 0.6B | 28 | 16/8 | yes | 32K |
| 1.7B | 28 | 16/8 | yes | 32K |
| 4B | 36 | 32/8 | yes | 32K |
| 8B | 36 | 32/8 | no | 128K |

The 8B context value is best interpreted together with the model card, which distinguishes native context from YaRN extension.

## A.2 Qwen3 technical report

https://arxiv.org/abs/2505.09388

Use for:

- architecture lineage;
- QK-Norm and removal of QKV projection bias relative to Qwen2;
- training and post-training methodology;
- unified thinking/non-thinking model;
- thinking-budget behavior;
- strong-to-weak distillation used to improve smaller models;
- benchmark methodology and family scaling.

## A.3 Official model cards and configs

0.6B:
- https://huggingface.co/Qwen/Qwen3-0.6B
- https://huggingface.co/Qwen/Qwen3-0.6B/blob/main/config.json

1.7B:
- https://huggingface.co/Qwen/Qwen3-1.7B
- https://huggingface.co/Qwen/Qwen3-1.7B/blob/main/config.json

4B:
- https://huggingface.co/Qwen/Qwen3-4B
- https://huggingface.co/Qwen/Qwen3-4B/blob/main/config.json

8B:
- https://huggingface.co/Qwen/Qwen3-8B
- https://huggingface.co/Qwen/Qwen3-8B/blob/main/config.json

Use config files for exact architectural fields such as hidden size, FFN width, layers, Q/KV heads, head dimension, RoPE theta, RMSNorm epsilon, weight tying, and nominal `max_position_embeddings` metadata.

## A.4 Official speed benchmark

https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/speed_benchmark.md

Qwen measured BF16 and quantized variants using NVIDIA H20 GPUs with SGLang and Hugging Face Transformers. This is valuable because it demonstrates a general lesson that applies directly to Aesir:

> Quantization speed depends on kernel quality and serving architecture, not only bit width.

In Qwen's SGLang measurements, FP8 or AWQ frequently improves throughput. In generic Transformers paths, FP8 can consume less memory yet run slower. Aesir should therefore benchmark every quant kernel instead of ranking formats by bits-per-weight alone.

Do **not** quote these numbers as Aesir speed.

## A.5 Official llama.cpp guidance

https://github.com/QwenLM/Qwen3/blob/main/README.md

Useful reference settings include:

- `llama.cpp >= b5401` for the Qwen3 support level documented by Qwen;
- Jinja chat templates;
- full GPU offload where appropriate;
- flash attention in the example configuration;
- Qwen's thinking-mode sampler defaults;
- no-context-shift in the example.

The purpose of citing llama.cpp is not to make Aesir copy its architecture. It is a compatibility/oracle and a source of useful workload expectations.

## A.6 Function calling and agents

https://github.com/QwenLM/Qwen3/blob/main/docs/source/framework/function_call.md

Qwen specifically warns against stopword-driven ReAct-style tool templates for reasoning models because thought text can contain stop words and accidentally trigger control flow. Aesir should treat tool-call syntax as structured protocol data, not a substring detector.

---

# B. Important source interpretation notes

## B.1 32K, 40,960 metadata, and 128K are not the same thing

The post-trained config files commonly contain:

```text
max_position_embeddings = 40960
```

while model cards describe 32,768 native context. The extra metadata space should not be simplistically advertised as a 40,960-token quality guarantee. For Aesir policy, use:

- 0.6B / 1.7B: 32,768 as the documented context target;
- 4B / 8B: 32,768 native, with YaRN extension documented and validated by Qwen to 131,072.

## B.2 Tokenizer vocabulary numbers differ by what is counted

The Qwen3 technical material discusses the tokenizer vocabulary in terms of learned/tokenizer units while model configs expose an embedding-table `vocab_size` of 151,936. These are different accounting surfaces because model embedding rows can include special/reserved/control entries. Aesir loaders should trust file/config dimensions for tensor geometry and tokenizer metadata for token semantics.

## B.3 BOS metadata is not the same as chat-template behavior

Hugging Face configs expose a `bos_token_id`, but Qwen chat uses its own control-token template semantics. Aesir already found that treating Qwen3 as a conventional always-prepend-BOS family causes incorrect behavior. The tokenizer/template is the authority for rendered prompt tokens.

## B.4 Launch-table 128K is shorthand for some models

For 4B and 8B, current model cards provide the useful operational distinction:

```text
native: 32,768
extended with YaRN: up to 131,072 validated
```

That distinction matters to Aesir because static YaRN can alter short-context behavior.

---

# C. Current Aesir evidence inspected

This library was prepared against Aesir `main` before the research commit at:

```text
34b7c1bd1fe8ed0e2e4ea7b410f1ef331e118748
```

Relevant files found in the tree include:

- `scripts/verify_qwen3_k_quants.sh`
- `docs/MODEL_WAVE_CLOUD_HYPERVISOR_EPYC.md`
- `docs/janas/J087_KV_PRECISION_CENSUS.md`
- `docs/janas/J088_8BIT_KV.md`
- `docs/janas/J074_CROSS_MODEL_DRAFTS.md`
- `docs/janas/J078_ASSISTANT_MODEL_DRAFTS.md`
- `docs/janas/J072_DRAFT_LOOP.md`
- `aesir_engine/core/speculative.mojo`
- `aesir_engine/core/speculative_verify.mojo`
- `aesir_engine/core/kv_account.mojo`

The README also records Qwen3 RoPE/no-BOS correctness work, K-quant and IQ development, and Qwen3-4B wave evidence.

---

# D. Current Aesir truth boundary

The repository contains real Qwen3 groundwork, but this research library intentionally does **not** claim that all four requested sizes are already fully production-proven under every Aesir backend.

Evidence is strongest for:

- Qwen3 architecture support;
- 0.6B profile/verification work;
- Qwen3-4B/Zen correctness investigation;
- quantized execution infrastructure;
- KV accounting and int8-KV component work.

The 1.7B and 8B should receive explicit physical acceptance runs before Aesir advertises them as first-class proven profiles.

Likewise:

- `PagedKVCache` exists, but the J-087 census reported that production sessions did not consume it at that point;
- int8 KV has a tested component and exact accounting, while later Janas material describes the larger integration state as partial/advanced rather than universally complete;
- speculative verification/design infrastructure exists, but some real draft-model integration paths deliberately fail closed.

This is a strength of the project evidence discipline. The research roadmap can target these gaps without pretending they are already solved.

---

# E. Community data policy

Third-party GGUF repositories are useful for observed file-size examples and quant availability. They are **not** treated as canonical quality evidence. Different quantizers, importance matrices, calibration corpora, and GGUF revisions can create materially different behavior at the same nominal quant.

Accordingly, the quantization document uses third-party sizes as examples and requires Aesir's own task suite before declaring a default.

---

# F. Benchmark discipline

Every Aesir optimization comparison should pin:

1. exact model repository and file SHA256;
2. quant format and quantizer provenance;
3. Aesir commit SHA;
4. rendered input token IDs, not merely human-readable prompt text;
5. chat-template version;
6. thinking mode;
7. sampler settings;
8. context capacity and current cache length;
9. hardware and driver/runtime versions;
10. thread count / affinity / accelerator placement;
11. warm versus cold-cache status;
12. output token count;
13. peak RSS/VRAM and ideally energy.

The repository has already demonstrated why this matters: a prior Qwen3 oracle discrepancy was traced to `llama-cli --single-turn` rendering a different prompt. Raw-token trajectory and teacher-forcing checks closed the supposed engine defect. Future Qwen3 work should preserve this token-parity discipline.

---

# G. What counts as success

Aesir should optimize a vector, not a single number:

```text
correctness
quality after quantization
TTFT
prefill throughput
decode throughput
peak memory
KV growth
energy/token
agent/tool-call exactness
long-context retrieval
stability
```

A 10% faster kernel that raises tool-call corruption or causes long-context drift is not automatically an improvement. Likewise, a slightly slower quant can be the better default if it permits a much smaller memory footprint and avoids swapping.
