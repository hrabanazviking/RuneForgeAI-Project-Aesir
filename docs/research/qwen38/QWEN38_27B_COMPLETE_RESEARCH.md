# Qwen3.8-27B — Complete Technical Research for Project Aesir

**Research snapshot:** 2026-11-02  
**Model:** `Qwen/Qwen3.8-27B`  
**Architecture identifier:** `qwen3_5` / `Qwen3_5ForConditionalGeneration`  
**Primary Aesir relevance:** high-quality dense local model, hybrid recurrent/full attention, multimodality, long context, MTP, agentic workflows.

---

# 1. Executive summary

Qwen3.8-27B is the compact dense member of the Qwen3.8 generation. Despite the simple `27B` label, it is not a conventional 64-layer full-attention transformer.

Its language model uses a **hybrid recurrent/attention topology**:

```text
16 repetitions of:

Gated DeltaNet → FFN
Gated DeltaNet → FFN
Gated DeltaNet → FFN
Gated Attention → FFN
```

That means:

- 64 language-model layers total;
- 48 layers use **Gated DeltaNet (GDN)** linear/recurrent attention;
- only 16 layers use conventional global Gated Attention;
- traditional KV-cache growth is therefore concentrated in the global-attention layers rather than every layer;
- GDN layers instead maintain compact recurrent/convolution state.

The checkpoint is also a **native multimodal model**, not a text model with a separate optional adapter trained later. It includes a vision encoder and supports text, images, and video as input while producing text output.

Qwen3.8-27B also includes:

- thinking mode by default;
- optional non-thinking/instruct mode;
- `reasoning_effort` control (`xhigh`, `medium`, `low`);
- preserved historical thinking context;
- a native MTP head for speculative decoding;
- 262,144-token native context;
- official YaRN extension guidance to 1,000,000 tokens;
- tool/function-call compatible chat formatting;
- broad agentic and coding tuning;
- official BF16 and FP8 weights;
- an active GGUF ecosystem including upstream ggml-org conversions.

For Project Aesir, this model is unusually attractive because it combines **large dense-model quality with a state architecture that is more memory-efficient than a pure full-attention 27B model**.

---

# 2. Identity, release, and licensing

## Official identity

- Hugging Face model: `Qwen/Qwen3.8-27B`
- Hugging Face task: `image-text-to-text`
- Transformers model class: `AutoModelForMultimodalLM`
- Config architecture: `Qwen3_5ForConditionalGeneration`
- Model type: `qwen3_5`
- Official license: **Apache-2.0**
- Official release date in the Qwen repository: **2026-08-14**

Hugging Face reports approximately **27.78B parameters** in repository metadata, while Qwen describes it as 27B.

The model is released as post-trained weights with configuration, tokenizer, image/video preprocessing configuration, chat template, and sharded Safetensors.

---

# 3. Exact language-model architecture

## Core dimensions

| Field | Value |
|---|---:|
| Parameters | ~27B |
| Hidden dimension | 5,120 |
| Language-model layers | 64 |
| Vocabulary / padded token embedding | 248,320 |
| FFN intermediate dimension | 17,408 |
| Native context | 262,144 tokens |
| Default weight dtype | BF16 |
| Full-attention interval | every 4th layer |
| RMSNorm epsilon | `1e-6` |
| Hidden activation | SiLU |
| Attention dropout | 0.0 |

The checkpoint does not tie input/output word embeddings.

## Layer schedule

The official layout is:

```text
16 × (
    3 × (Gated DeltaNet → FFN)
    1 × (Gated Attention → FFN)
)
```

Explicitly, the repeating attention types are:

```text
linear_attention
linear_attention
linear_attention
full_attention
```

repeated 16 times.

### Why this matters

A traditional 64-layer transformer normally stores K/V history for all full-attention layers. Qwen3.8-27B only has **16 global-attention layers**. The other 48 use GDN and carry recurrent state instead.

For Aesir this strongly suggests treating model state as a union of several structures rather than assuming that "context state = KV cache".

A better conceptual model is:

```text
RequestState
├── GDN recurrent matrix/state
├── GDN convolution history
├── global-attention KV cache
├── multimodal position metadata
├── prefix-cache metadata
└── speculative/MTP transaction state
```

---

# 4. Gated DeltaNet (GDN)

GDN is the dominant token-mixing mechanism in Qwen3.8-27B.

The model config exposes:

| GDN field | Value |
|---|---:|
| Q/K heads | 16 |
| Value heads | 48 |
| Q/K head dimension | 128 |
| Value head dimension | 128 |
| Convolution kernel dimension | 4 |
| SSM/recurrent-state dtype hint | FP32 |

GDN belongs to the family of linear/recurrent attention mechanisms that compress prior history into a fixed-size state instead of repeatedly attending over every historical token.

This has two important local-inference consequences:

1. **Decode cost does not scale with full sequence length in the same way as normal attention** for those layers.
2. Context memory for those layers is dominated by recurrent/convolution state rather than a linearly growing K/V tensor for every prior token.

The tradeoff is that recurrent state must be updated correctly at every token and must be handled carefully when:

- branching generations;
- speculative decoding;
- rolling back rejected draft tokens;
- copying sessions;
- prefix caching;
- prompt batching.

For Aesir, GDN support should therefore expose explicit state lifecycle operations:

```text
create_state
reset_state
clone_state
checkpoint_state
rollback_state
serialize_state
prefill
single-token decode
chunked decode/prefill
```

A fast matrix kernel alone is not enough. Correct state semantics are part of model compatibility.

---

# 5. Gated Attention layers

Every fourth language layer uses global Gated Attention.

Official dimensions:

| Field | Value |
|---|---:|
| Query heads | 24 |
| KV heads | 4 |
| Head dimension | 256 |
| Rotary dimension | 64 |
| Partial rotary factor | 0.25 |

The 24-query / 4-KV arrangement is grouped-query attention rather than classic equal-head MHA.

The config includes:

```text
attn_output_gate = true
output_gate_type = swish
```

Qwen's Gated Attention lineage adds an output gating mechanism that helps regulate information flow and was retained across the Qwen3.5–3.8 architecture line.

## Aesir implication

The global-attention path should not be treated as ordinary Llama-style attention with only tensor sizes changed. Aesir needs support for:

- GQA;
- partial rotary embedding;
- output gating;
- interleaved multimodal RoPE metadata;
- KV-cache precision independent of model-weight precision.

---

# 6. Position encoding and mRoPE

The model config specifies:

```text
rope_theta = 10,000,000
partial_rotary_factor = 0.25
mrope_interleaved = true
mrope_section = [11, 11, 10]
```

The model uses multimodal rotary-position behavior inherited from the Qwen3.x vision-language line.

For Aesir this means position handling should be isolated behind a position-encoding interface rather than baked into one attention kernel.

Suggested abstraction:

```text
PositionEncoder
├── text positions
├── image-grid positions
├── video temporal positions
├── mRoPE section mapping
└── YaRN scaling policy
```

This becomes especially important if Aesir wants one execution graph to support text-only and multimodal input efficiently.

---

# 7. Dense FFN structure

Unlike Flash-Next, Qwen3.8-27B is dense. Every token passes through the model's dense FFN path.

Official intermediate size:

```text
17,408
```

Activation:

```text
SiLU
```

This means all ~27B backbone parameters are computationally active rather than only a routed subset.

Consequences:

- simple routing semantics;
- predictable memory access;
- no expert dispatch/sorting overhead;
- high but regular bandwidth demand;
- generally easier local quantization than a massive expert pool;
- dense-model quality without MoE routing variance.

For the planned 128GB unified-memory class of hardware, the dense design is practical because Q8/Q6/Q5/Q4 quantizations fit comfortably while retaining large context headroom.

---

# 8. Multi-Token Prediction (MTP)

Qwen states that Qwen3.8-27B's MTP is trained with multiple prediction steps.

The config exposes:

```text
mtp_num_hidden_layers = 1
mtp_use_dedicated_embeddings = false
```

Current serving recipes use the in-checkpoint MTP head for speculative decoding, commonly with a small draft depth such as three tokens.

## Why MTP matters

Autoregressive decode normally performs one expensive full-model step per accepted token.

With model-native MTP:

```text
main state
   ↓
MTP drafts token t+1, t+2, t+3...
   ↓
main model verifies a group
   ↓
accepted prefix committed
rejected suffix rolled back
```

If acceptance is high, the number of expensive synchronization points per generated token can fall significantly.

## Aesir requirement

Because the trunk contains GDN recurrent layers, speculative decoding cannot be implemented as "just truncate the KV cache."

Rollback must restore:

- GDN recurrent state;
- GDN convolution history;
- full-attention KV cache;
- token position state;
- multimodal position state where applicable;
- sampler state if deterministic replay is required.

Aesir should implement state transactions explicitly.

---

# 9. Native context: 262,144 tokens

Official open-weight native context:

```text
262,144 tokens
```

This is a first-class model configuration rather than an unofficial rope hack.

The Qwen repository and official serving examples launch the model with 262,144-token context in vLLM, SGLang, and TokenSpeed.

Because only one quarter of the language layers use full attention, this architecture is substantially friendlier to long contexts than a 64-layer all-attention dense transformer of comparable width.

Aesir should still treat 262K as a **memory-planning problem** rather than merely a configuration integer. The runtime should calculate:

- model weights;
- vision weights if loaded;
- MTP weights;
- full-attention KV cache;
- GDN recurrent state;
- GDN convolution state;
- prefill scratch;
- sampler/logit buffers;
- prefix-cache allocation;
- safety reserve for the operating system and other models.

---

# 10. Extension to 1,000,000 tokens with YaRN

Qwen provides official instructions for extending the open model to one million tokens with **static YaRN**.

The published override uses approximately:

```text
rope_type = yarn
factor = 4.0
original_max_position_embeddings = 262144
rope_theta = 10000000
partial_rotary_factor = 0.25
mrope_interleaved = true
mrope_section = [11, 11, 10]
max_model_len = 1000000
```

Qwen explicitly warns that common open-source implementations use **static YaRN**, meaning the scaling factor remains in effect even for short prompts. That can reduce short-context quality.

Their guidance is therefore:

- do not enable 1M scaling unless long-context work actually needs it;
- choose a smaller factor for smaller extended windows;
- for workloads around ~524K, factor 2.0 is more appropriate than factor 4.0.

## Aesir design recommendation

Aesir should not store a single "context length" switch.

Use a policy structure:

```text
ContextPolicy
├── native_limit
├── requested_limit
├── rope_mode
├── yarn_factor
├── kv_dtype
├── prefill_chunk
├── prefix_cache
└── memory_reserve
```

Then auto-select sensible values from requested workload and hardware.

---

# 11. Vision encoder

Qwen3.8-27B includes a native vision tower.

Official config:

| Vision field | Value |
|---|---:|
| Encoder depth | 27 |
| Hidden size | 1,152 |
| Intermediate size | 4,304 |
| Attention heads | 16 |
| Input channels | 3 |
| Patch size | 16 |
| Temporal patch size | 2 |
| Spatial merge size | 2 |
| Position embeddings | 2,304 |
| Output hidden size | 5,120 |
| Activation | GELU tanh approximation |

Special token IDs are provided for:

- vision start;
- vision end;
- image token;
- video token.

The vision tower projects visual representations directly into the 5,120-wide language-model hidden space.

## Aesir implication

The runtime should make the vision tower loadable independently.

For text-only local use, there is no reason to keep vision weights resident if the user wants maximum context memory or concurrency.

Recommended Aesir architecture:

```text
ModelPackage
├── language_model
├── optional vision_encoder
├── optional MTP module
└── tokenizer/processors
```

This also mirrors how GGUF ecosystems often package a separate `mmproj` file.

---

# 12. Image understanding

The model card explicitly targets broad visual reasoning, including:

- document understanding;
- charts;
- STEM diagrams;
- real-world images;
- computer-use screenshots;
- web interfaces;
- application recreation;
- visual software-engineering tasks.

Representative Qwen-reported results include:

| Benchmark | Qwen3.8-27B |
|---|---:|
| OSWorld-Verified | 84.3 |
| WebArena-Verified | 64.8 |
| AndroidWorld | 81.9 |
| RecreationBench | 47.1 |
| Vision2Web | 62.9 |
| MathVision | 90.0 without CI / 94.6 with CI |
| OmniDocBench 1.5 | 91.1 |
| RealWorldQA | 85.9 |

Benchmark numbers should be treated as reported evaluation data, not as guaranteed application performance.

The important architectural conclusion for Aesir is that visual understanding is **native enough to support agent loops**, not merely captioning.

---

# 13. Video understanding

Qwen3.8-27B accepts video input.

The official model card specifically discusses **hour-scale video** and recommends changing the video preprocessor's maximum image-area budget when higher frame-rate sampling is required.

Qwen gives a `longest_edge` example corresponding to approximately **224K video tokens** for long-video work.

This creates an important resource-management issue: image/video tokens consume context just like other multimodal representations.

Aesir should therefore expose video-budget controls rather than hiding preprocessing decisions.

Suggested controls:

```text
video.max_frames
video.fps
video.max_visual_tokens
video.resize_policy
video.temporal_patch_size
video.context_budget_fraction
```

---

# 14. Thinking mode

Qwen3.8-27B thinks by default.

The chat format emits reasoning in:

```text
<think>
...
</think>
```

before the final response.

The model can also be run in direct instruct/non-thinking mode.

Official recommended sampling settings:

## Thinking

```text
temperature = 1.0
top_p = 0.95
top_k = 20
min_p = 0.0
presence_penalty = 0.0
repetition_penalty = 1.0
```

## Non-thinking

```text
temperature = 0.7
top_p = 0.80
top_k = 20
min_p = 0.0
presence_penalty = 1.5
repetition_penalty = 1.0
```

Aesir should expose thinking as a per-request behavior rather than requiring separate model files.

---

# 15. `reasoning_effort`

Qwen3.8 adds explicit reasoning-depth control:

```text
xhigh   default, deeper reasoning
medium  balance speed and accuracy
low     prioritize efficiency
```

Qwen cautions that lower reasoning effort does **not automatically mean lower end-to-end latency** in agentic workflows. Faster individual turns can cause more mistakes, retries, and repeated tool calls.

For Aesir, reasoning effort should therefore be benchmarked by **task completion cost**, not tokens/second alone.

Metrics should include:

```text
wall-clock task completion
number of turns
tool calls
failed attempts
reasoning tokens
final-output tokens
energy / compute
```

---

# 16. Preserved thinking

Qwen3.8 enables `preserve_thinking` by default.

Instead of discarding all prior reasoning blocks from conversation history, the system can retain them across turns.

Qwen describes two benefits:

- greater reasoning continuity for agents;
- reduced redundant reasoning and better cache reuse.

This is especially relevant to persistent local agents such as the kind Project Aesir is intended to support.

## Aesir opportunity

Treat preserved thinking as cacheable context with explicit lifecycle policies:

```text
keep all
keep last N turns
summarize old reasoning
pin system/project reasoning
expire by token budget
```

A local engine can potentially do better than a generic API by understanding which reasoning prefix remains byte-identical and can be reused directly.

---

# 17. Agentic and coding orientation

Qwen positions Qwen3.8 around:

- coding;
- repository-level work;
- professional work;
- research;
- long-horizon agents;
- environment feedback;
- computer-use / multimodal agents.

Reported text benchmarks include:

| Benchmark | Qwen3.8-27B |
|---|---:|
| Terminal Bench 2.1 | 73.0 |
| SWE-bench Pro | 61.7 |
| NL2Repo-Bench | 42.3 |
| DeepSWE 1.1 | 42.2 |
| QwenSWEBench | 79.0 |
| CoWorkBench | 70.7 |
| JobBench | 33.4 |
| Agents' Last Exam Pass@1 | 20.4 |
| IFBench | 79.5 |
| GPQA Diamond | 89.2 |
| LiveCodeBench v6 | 90.3 |

For Project Aesir, this makes the model attractive not only as a chat model but as a local **tool-using project agent**.

---

# 18. Function calling and tool use

Qwen's open-serving examples support automatic tool choice using the Qwen3 Coder-style parser.

Important distinction:

- the **checkpoint can produce/consume tool-call formatted conversations**;
- tools such as web search or code interpreter are external runtime services;
- QwenCloud provides additional hosted built-in tools that are not literally embedded in the open weights.

Aesir should implement the open-model side generically:

```text
ToolRegistry
ToolSchema → prompt/chat template
model tool-call output → parser
validation
execution
result message
resume model
```

The parser should be modular so future Qwen chat-template changes do not require changes to the inference core.

---

# 19. Structured output

Hosted Qwen services expose structured-output support. Locally, Aesir can implement constrained decoding independently of the checkpoint using:

- JSON grammar;
- regex/finite-state constraints;
- schema-guided token masks;
- tool-schema constraints.

This is a runtime feature that pairs naturally with Qwen's agentic tuning.

It should be considered an Aesir engine feature, not a weight-format dependency.

---

# 20. Prefix caching

Qwen's long-horizon agent behavior and preserved-thinking design make prefix caching especially valuable.

Common stable prefixes include:

- system prompt;
- tool definitions;
- repository description;
- persistent agent identity;
- project documentation;
- prior preserved reasoning.

Aesir should support immutable prefix segments and cache them at the state level.

With hybrid GDN/full attention, a reusable prefix cache may need to store:

- GDN recurrent state after the prefix;
- GDN convolution state;
- global-attention KV tensors;
- positional state;
- tokenizer boundary metadata.

This can be dramatically smaller than replaying a 100K+ project context every turn.

---

# 21. Training and post-training characteristics

The model card lists both pretraining and post-training.

The broader Qwen3.8 family claims improvements in:

- coding;
- professional work;
- research;
- long-horizon agent execution;
- multimodal performance;
- global linguistic coverage.

The official Qwen3.8 repository states expanded support for **201 languages and dialects** at the family level.

This should be treated as a Qwen3.8-series training claim rather than a guarantee that every language is equally strong in the 27B checkpoint.

---

# 22. Official weight formats

## BF16

The original Hugging Face repository is roughly **55.6 GB on disk**, with the core GGUF BF16 conversion around **53.8 GB**.

BF16 is useful for:

- reference validation;
- quantization calibration;
- golden-logit testing;
- high-memory accelerators.

It is unnecessary for most consumer-local inference when high-quality Q6/Q8 is available.

## Official FP8

Qwen also publishes `Qwen/Qwen3.8-27B-FP8`.

Qwen describes it as:

- fine-grained FP8;
- block size 128;
- performance metrics nearly identical to original BF16.

The repository is around the low-30GB range depending on exact accounting.

FP8 is especially relevant to accelerator backends with native block-scaled FP8 kernels.

---

# 23. GGUF ecosystem

The upstream ggml-org repository contains:

| File | Approx. size |
|---|---:|
| BF16 | 53.8 GB |
| Q8_0 | 28.6 GB |
| Q4_K_M | 19 GB |
| vision `mmproj` BF16 | ~931 MB |
| vision `mmproj` Q8 | ~629 MB |
| MTP BF16 | ~5.95 GB |
| MTP Q8 | ~3.16 GB |
| MTP Q4 | ~1.68 GB |
| DFlash draft files | separate optional files |

Community quant repositories add many Q6/Q5/Q4/IQ variants.

Important: file-size differences between repositories can arise from tensor-layout choices and which tensors are preserved at higher precision. Therefore "Q4" is not always a single exact size or quality level.

---

# 24. Q8 versus Q6/Q5/Q4 on local hardware

Quantization is a bandwidth/compute tradeoff.

## Q8

Advantages:

- extremely low quantization error;
- simpler dequantization;
- useful reference-like local quality;
- still far smaller than BF16.

Cost:

- roughly twice the weight traffic of a 4-bit representation;
- on bandwidth-limited unified-memory systems, decode can be slower than good Q4/Q5/Q6 despite simpler unpacking.

## Q6

Likely strong quality/performance compromise when memory is plentiful.

Aesir should treat Q6 as a serious first-class target rather than a forgotten middle quant.

## Q4

Advantages:

- dramatically less memory bandwidth;
- smaller footprint;
- more room for context, Chroma/image models, cache, and concurrency.

Cost:

- more dequantization work;
- more quality loss;
- kernel quality matters enormously.

## Aesir policy

Benchmark rather than assume:

```text
Q8 weight bandwidth
Q6 weight bandwidth
Q5 weight bandwidth
Q4 weight bandwidth
kernel occupancy
dequant cost
prompt-processing speed
decode speed
quality/KLD/perplexity
```

On a unified-memory APU, decode is often weight-bandwidth bound, which can make smaller quants faster even when their arithmetic path is more complex.

---

# 25. Text-only mode

Current serving frameworks expose a text-only option that skips loading the vision encoder.

This matters because the vision encoder consumes:

- weight memory;
- initialization time;
- runtime metadata;
- possibly graph-capture memory.

Aesir should expose:

```text
--text-only
--multimodal
```

or an automatic lazy-load policy.

For an agent that spends most of its life writing code and only occasionally views an image, lazy-loading the vision tower may be preferable to permanent residency.

---

# 26. Separate vision projector in GGUF workflows

llama.cpp/GGUF packaging often uses an auxiliary multimodal projector (`mmproj`).

This is useful to Aesir conceptually even if Aesir uses a different on-disk layout:

```text
language weights
vision weights/projector
MTP weights
optional external draft weights
```

Separating components allows hardware-specific residency policies.

Example:

```text
LM → unified RAM / GPU
MTP → resident if speculative enabled
vision → load on demand
external draft → optional
```

---

# 27. Speculative decoding beyond native MTP

The ecosystem also experiments with external draft systems such as DFlash2 and DSpark.

This is not required for model correctness, but it demonstrates why Aesir should define a generic drafting API rather than hard-code MTP.

Suggested interface:

```text
DraftProvider
├── NativeMTP
├── ExternalSmallModel
├── DFlash-like drafter
├── DSpark-like drafter
└── disabled
```

Verification and rollback can then be shared.

---

# 28. Model state versus context length

A common mistake is to estimate Qwen3.8-27B as though every one of its 64 layers owns a standard KV cache.

That overstates the classic KV component because only 16 layers are global attention.

But the opposite mistake is also dangerous: GDN is not free.

The runtime still needs:

- recurrent matrices;
- short convolution history;
- persistent state per sequence;
- scratch buffers;
- cache metadata.

Aesir should produce a transparent memory report, for example:

```text
weights                  28.6 GiB
vision tower              0.6 GiB
MTP                       3.2 GiB
full-attention KV          X GiB
GDN recurrent state        Y MiB
GDN conv state             Z MiB
prefill workspace          ...
OS reserve                 ...
--------------------------------
available                 ...
```

No mystery allocations.

---

# 29. Concurrency implications

GDN's fixed-size recurrent state helps long single contexts, but multi-user concurrency still multiplies request-local state.

Aesir needs to distinguish:

```text
shared immutable model memory
shared prefix state
per-request mutable state
per-sequence sampler state
per-batch scratch
```

Prefix sharing can be unusually powerful for local agent farms where many agents share the same repository/system prompt.

---

# 30. Prompt processing versus decode

Qwen3.8-27B should be benchmarked in two separate regimes.

## Prefill

Dominated by processing many prompt tokens in parallel.

Important variables:

- chunk size;
- attention implementation;
- matrix throughput;
- vision preprocessing;
- prefix-cache hit rate.

## Decode

Often much more memory-bandwidth-sensitive because one or a few tokens are generated per step.

Important variables:

- quantized weight traffic;
- recurrent-state update latency;
- KV reads in global-attention layers;
- MTP acceptance;
- batch size.

A single headline tokens/sec number hides these differences.

---

# 31. Recommended Aesir benchmark matrix

For the planned high-memory local target, benchmark at minimum:

## Weight precision

```text
Q4_K_M-like
Q5
Q6
Q8
BF16 reference
```

## Cache precision

```text
FP16/BF16
Q8/FP8 equivalent
Q4 experimental if supported
```

## Context

```text
8K
32K
64K
128K
262K
524K YaRN
1M YaRN
```

## Modes

```text
text-only
multimodal
thinking
non-thinking
MTP off
MTP on
prefix cache cold
prefix cache warm
```

## Metrics

```text
load time
first-token latency
prefill tok/s
decode tok/s
MTP acceptance
memory high-water mark
bandwidth
temperature/power if available
quality regression
```

---

# 32. Why Qwen3.8-27B is a strong Aesir target

It is large enough to be genuinely capable but small enough to fit on high-memory consumer hardware at very high quantization quality.

It gives Aesir a chance to implement and optimize:

- GDN state;
- hybrid attention scheduling;
- GQA;
- gated attention output;
- mRoPE;
- long context;
- multimodal encoding;
- MTP;
- tool-oriented chat formatting;
- preserved context;
- aggressive quantization;
- unified-memory residency.

Those capabilities overlap heavily with the Qwen4 preparation path without requiring the enormous Flash-Next checkpoint.

---

# 33. What Qwen3.8-27B does NOT contain

It is important not to attribute Flash-Next features to the normal 27B model.

Qwen3.8-27B does **not** use:

- Qwen Sparse Attention (QSA);
- a QSA block-selection indexer;
- 512 routed experts;
- sparse MoE FFNs;
- four-branch Qwen4 Gated Residual;
- the 51B n-gram embedding table;
- PLE host-memory lookup offload.

Those are Flash-Next / Qwen4-Exp features.

The normal 27B uses the older Qwen3.5-derived hybrid:

```text
GDN + Gated Attention + dense FFN
```

This distinction should remain explicit inside Aesir's model registry.

---

# 34. Suggested Aesir architecture identifier

Do not name the backend merely `qwen38`.

A useful internal description could be:

```text
family: qwen
architecture: qwen3_5
variant: qwen3.8-27b
modalities: text,image,video
ffn: dense
attention:
  linear: gated_deltanet
  global: gated_gqa
  cadence: [gdn,gdn,gdn,global]
mtp: true
native_context: 262144
```

This keeps architectural behavior separate from marketing generation names.

---

# 35. Project Aesir immediate implementation priorities

For this model specifically:

1. parse `qwen3_5` metadata completely;
2. support exact 64-layer hybrid scheduling;
3. implement GDN reference prefill/decode;
4. implement request-local GDN recurrent/conv state;
5. implement Gated Attention output gating;
6. implement GQA 24Q/4KV;
7. implement partial rotary + mRoPE;
8. implement dense FFN 17,408 path;
9. implement MTP state transactions;
10. support 262K context planning;
11. support optional YaRN context extension;
12. support lazy vision tower;
13. add image/video position metadata;
14. build text-only Q8/Q6/Q4 benchmark suite;
15. validate logits against a reference runtime.

---

# 36. Definition of high-quality Aesir support

Aesir should not claim full Qwen3.8-27B support merely because it emits readable text.

A strong compatibility gate should require:

- correct tokenizer/chat template;
- correct GDN state evolution;
- correct global attention;
- correct output gating;
- correct mRoPE;
- deterministic short-sequence reference agreement;
- 262K allocation correctness;
- MTP rollback correctness;
- text-only operation;
- multimodal image operation;
- video tokenization/position path;
- quantized execution;
- prefix-cache correctness;
- tool-call formatting compatibility;
- thinking/non-thinking switching.

---

# 37. Sources

Primary and upstream sources used for this document:

- Qwen official model card: https://huggingface.co/Qwen/Qwen3.8-27B
- Qwen official config: https://huggingface.co/Qwen/Qwen3.8-27B/blob/main/config.json
- Qwen official FP8 model: https://huggingface.co/Qwen/Qwen3.8-27B-FP8
- Qwen3.8 official repository: https://github.com/QwenLM/Qwen3.8
- Qwen3.8 official blog: https://qwen.ai/blog?id=qwen3.8
- QwenCloud 27B page: https://www.qwencloud.com/models/qwen3.8-27b
- Alibaba Model Studio 27B information: https://www.alibabacloud.com/help/en/model-studio/qwen3-8-27b
- vLLM Qwen3.8-27B recipe: https://github.com/vllm-project/recipes/blob/main/models/Qwen/Qwen3.8-27B.yaml
- ggml-org GGUF conversion: https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF
- llama.cpp project: https://github.com/ggml-org/llama.cpp

Community quantization measurements are discussed only where explicitly identified as ecosystem evidence.

---

# 38. Bottom line for Project Aesir

Qwen3.8-27B is not simply a smaller dense transformer. It is a **hybrid recurrent-attention multimodal agent model** whose architecture rewards an inference engine that understands state, cache topology, long context, multimodal positions, and speculative execution.

That makes it an excellent practical proving ground for Aesir:

> **Run the useful 27B model now, while building the exact classes of runtime machinery that the Qwen4 generation is pushing even further.**
