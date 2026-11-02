# Qwen3.8 Inference, Quantization, and Runtime Research

**Models:** Qwen3.8-27B and Qwen3.8-Flash-Next  
**Research snapshot:** 2026-11-02  
**Project:** Project Aesir

---

# 1. Purpose

This document studies how the two Qwen3.8 architectures behave as **local inference targets**, with particular attention to:

- weight formats and quantization;
- memory bandwidth versus dequantization cost;
- recurrent-state and KV-cache precision;
- MTP/draft packaging;
- multimodal projector handling;
- dense versus MoE memory behavior;
- QSA and PLE runtime implications;
- vLLM, SGLang, Transformers and llama.cpp/GGUF support;
- 128 GB unified-memory-class systems;
- Project Aesir benchmark and kernel priorities.

The goal is not to declare one universal best quant. The correct format depends on hardware, context length, concurrency, multimodality, speculative decoding and whether another large model must remain resident.

---

# 2. First principle: parameter count is not runtime cost

Qwen3.8-27B and Flash-Next demonstrate why a single parameter number is insufficient.

## Qwen3.8-27B

```text
~27.8B stored parameters
~27B active backbone parameters/token
```

It is dense. Most weight matrices are touched every token.

## Flash-Next

```text
125B main-network parameters
~6B active main-network parameters/token
+51B deterministic n-gram lookup memory
+~4B MTP/auxiliary capacity
```

Only selected experts execute for a token, while PLE/n-gram memory is accessed as sparse lookup rows.

For Aesir, memory planning must therefore classify **how a tensor is accessed**, not merely its size.

---

# 3. Runtime memory classes

A useful classification is:

| Memory class | Example | Access pattern | Latency sensitivity |
|---|---|---|---|
| Dense model weights | 27B dense FFN/projections | streamed repeatedly | high |
| Routed expert weights | Flash-Next MoE | selected subsets | high, irregular |
| Shared expert/projections | Flash-Next | every token | very high |
| KV cache | 27B global attention | grows with context | high |
| QSA history/index | Flash-Next | sparse block retrieval | high |
| GDN recurrent state | both | tiny/medium, every token | extremely high |
| GDN conv state | both | tiny, every token | extremely high |
| Gated Residual state | Flash-Next | read/write every layer | extremely high |
| PLE table | Flash-Next | deterministic sparse row lookup | prefetchable |
| Vision weights | both | only multimodal requests | conditional |
| MTP weights/state | both | speculative decode only | conditional/high |

Aesir should not apply one `--gpu-layers`-style policy to all of these.

---

# 4. Qwen3.8-27B official and upstream formats

## Original BF16

The original checkpoint is BF16-based.

Representative storage:

```text
original HF repository ≈ mid-50 GB range
upstream ggml-org BF16 GGUF ≈ 53.8 GB
```

BF16 is most useful for:

- reference logits;
- numerical validation;
- quantization comparison;
- accelerators with abundant bandwidth and memory.

On local unified-memory hardware, BF16 often wastes bandwidth if Q8/Q6 preserves enough quality.

## Official FP8

Qwen publishes `Qwen/Qwen3.8-27B-FP8`.

The model card describes:

- fine-grained FP8;
- block size 128;
- near-original evaluation quality.

FP8 can be excellent where the backend has efficient native FP8 matrix support. It is not automatically the best option on every CPU/APU/GPU because unpacking, scaling, kernel availability and memory layout matter.

---

# 5. Qwen3.8-27B GGUF examples

The upstream ggml-org conversion provides a useful concrete layout.

Approximate published sizes:

| Artifact | Size |
|---|---:|
| BF16 model | ~53.8 GB |
| Q8_0 model | ~28.6 GB |
| Q4_K_M model | ~19 GB |
| vision projector BF16 | ~931 MB |
| vision projector Q8 | ~629 MB |
| MTP BF16 | ~5.95 GB |
| MTP Q8 | ~3.16 GB |
| MTP Q4 | ~1.68 GB |

External speculative-draft artifacts can also be distributed separately.

This packaging is informative for Aesir because it demonstrates the value of **componentized model packages** rather than forcing language, vision and speculation into one residency unit.

---

# 6. Recommended Aesir package abstraction

Instead of assuming one file equals one model, represent:

```text
ModelPackage
├── core language weights
├── tokenizer/chat template
├── optional vision tower/projector
├── optional native MTP module
├── optional external draft model
├── quantization metadata
├── tensor placement hints
└── architecture config
```

The runtime can then load only what is needed.

Examples:

```text
coding agent → LM + MTP, vision unloaded
visual agent → LM + vision + MTP
benchmark reference → LM BF16, MTP off
low-memory mode → LM Q4, vision lazy, compact cache
```

---

# 7. Q8: why less dequantization does not guarantee more speed

Q8 stores roughly twice as many weight bits as a 4-bit quant.

Its advantages:

- small quantization error;
- simple scale/dequant path;
- excellent reference-like quality;
- easier high-throughput kernels on some hardware.

But autoregressive single-user decode is often **memory-bandwidth-bound**.

Very approximately:

```text
Q8 → more bytes moved, less dequant work
Q4 → fewer bytes moved, more dequant work
```

If memory bandwidth is the bottleneck, Q4/Q5/Q6 can beat Q8 even though their unpacking is more complicated.

This must be benchmarked on the actual Aesir backend.

---

# 8. Why Q6 deserves serious attention

Consumer-local discussions often jump directly from Q8 to Q4.

For a 128 GB unified-memory machine, memory capacity is not the primary constraint for Qwen3.8-27B. That creates room for Q6.

Potential Q6 benefits:

- much lower bandwidth than Q8;
- very small quality loss relative to high precision;
- simpler memory planning than BF16;
- enough room for large context and auxiliary models.

Aesir should benchmark Q6 as a first-class target rather than treating it as an obscure middle format.

---

# 9. Q5 and mixed-precision formats

Q5 often occupies a useful middle zone between Q4 speed/size and Q6 quality.

More importantly, an architecture-aware runtime need not quantize every tensor identically.

Potential policies:

```text
attention/GDN projections → Q6
large dense FFN weights → Q5/Q4
router/gates/norms → higher precision
embeddings → Q8/FP16 depending sensitivity
vision projector → Q8
MTP → Q4/Q5 if acceptance remains strong
```

Aesir should support per-tensor-group policies rather than only one whole-model bit depth.

---

# 10. Q4 as a bandwidth optimization

Q4 is valuable even when the model already fits easily.

Reducing weight bytes can provide:

- faster token generation on bandwidth-bound hardware;
- more room for caches;
- more room for Chroma/image models or other concurrent services;
- more concurrent agents;
- less memory pressure and page migration.

The cost is that kernel quality becomes decisive.

A poorly fused Q4 path can lose to a very clean Q8 path despite moving fewer bytes.

For Aesir, this makes quantized-kernel engineering a benchmark problem, not a slogan.

---

# 11. Weight quantization and cache quantization are separate decisions

Do not bind KV/cache precision to weight precision.

Valid combinations include:

```text
Q8 weights + FP16 KV
Q8 weights + Q8 KV
Q6 weights + Q8 KV
Q4 weights + Q8 KV
Q4 weights + Q4 experimental KV
```

Likewise, GDN and QSA state can have their own precision policies.

Aesir config should therefore separate:

```text
weight_dtype
kv_dtype
gdn_state_dtype
residual_state_dtype
qsa_index_dtype
ple_storage_dtype
```

---

# 12. GDN state precision

Both model configs contain an FP32 hint for the recurrent/SSM-style state.

That is an important correctness signal.

Aesir should begin with an FP32 reference implementation and only reduce state precision after measuring:

- long-sequence drift;
- perplexity/logit error;
- rollback correctness;
- numerical stability at 262K+ context;
- agent quality.

Weight quantization can be aggressive while recurrent mutable state remains higher precision.

---

# 13. KV cache in Qwen3.8-27B

Only 16 of the 64 language layers are global Gated Attention layers.

Therefore standard KV cache exists only for the direct-attention portion of the hybrid model.

This is materially different from a 64-layer all-attention model.

Aesir's memory estimator should calculate cache from the architecture metadata rather than a generic model-size heuristic.

It should also account for:

- grouped-query attention with 4 KV heads;
- head dimension 256;
- context length;
- cache dtype;
- batch/concurrency.

---

# 14. Flash-Next official high-precision memory

Current upstream vLLM recipes provide useful order-of-magnitude memory figures for Flash-Next.

Approximate checkpoint memory cited there:

| Representation | Approx. memory |
|---|---:|
| BF16 | ~335.28 GiB |
| FP8 | ~172.78 GiB |
| AMD Quark MXFP4 package | ~169.8 GiB |

These numbers reveal that the checkpoint does not behave like a simple `180B × bits-per-weight` calculation. Different tensor classes and auxiliary memories use different representations.

---

# 15. Flash-Next low-bit GGUF ecosystem

Community conversions show that aggressive low-bit packaging can move the checkpoint into much lower capacity ranges.

One major community conversion reports approximate sizes such as:

| Quant | Approx. size |
|---|---:|
| BF16 | ~354 GB |
| Q8_0 | ~192 GB |
| Q6_K_XL | ~169 GB |
| Q5_K_XL | ~158 GB |
| Q4_K_XL | ~111 GB |
| IQ4_XS | ~93.7 GB |
| Q3-class | ~82–90 GB |
| Q2_K_XL | ~78.9 GB |
| IQ1-class | ~72–75 GB |

These are **community artifact sizes**, not official Qwen deployment recommendations.

They prove capacity feasibility only. They do not prove that a given 128 GB machine has enough headroom for context state, OS memory, vision, MTP, work buffers, or good performance.

---

# 16. Flash-Next quantization must be component-aware

Uniform low-bit quantization is especially questionable for Flash-Next because tensor roles differ radically.

Suggested categories to evaluate independently:

```text
shared projections
GDN projections
QSA projections
QSA indexer
MoE router
routed experts
shared expert
Gated Residual gates/low-rank matrices
PLE/n-gram table
vision tower
MTP module
```

For example:

- experts may tolerate lower precision while remaining compute-heavy;
- router errors can change which experts execute and may be disproportionately damaging;
- GR gates are small enough to retain higher precision;
- PLE is a lookup memory and may benefit from a storage-oriented quantization scheme;
- QSA indexer quantization can change which historical blocks are retrieved.

Aesir should benchmark *behavioral sensitivity by tensor class*.

---

# 17. QSA indexer precision matters differently from attention precision

If an ordinary attention projection has a small numerical error, output may degrade gradually.

If the QSA indexer changes the ordering around a top-k boundary, it can retrieve a completely different context block.

Therefore indexer quantization can create **discrete retrieval errors**.

Aesir tests should measure:

```text
selected-block overlap versus BF16 reference
rank correlation
retrieval recall
final-logit divergence
long-context task accuracy
```

Do not evaluate QSA indexer quantization only with matrix error norms.

---

# 18. MoE expert precision and routing precision

Flash-Next's 512 experts create two distinct quantization questions:

## Router

Small, latency-sensitive, controls expert selection.

Likely worth keeping relatively high precision.

## Experts

Huge total storage, only subsets used per token.

Strong candidate for aggressive quantization and caching.

Aesir can potentially use:

```text
router FP16/BF16
shared expert Q6/Q8
hot experts Q5/Q6
cold experts Q4 on RAM/NVMe
```

This is an engineering hypothesis to benchmark, not an official Qwen prescription.

---

# 19. PLE/n-gram storage precision

The 51B n-gram memory is fundamentally a lookup table.

Aesir should investigate storage formats optimized for:

- row-level random access;
- direct dequantization of one/few rows;
- page locality;
- batched gathers;
- memory mapping;
- asynchronous NVMe reads.

A generic block quant format designed around large GEMMs may not be optimal for PLE rows.

Potential research direction:

```text
row-wise int8
row-wise int6/int4
FP8 row blocks
mixed hot/cold row precision
```

Quality should be measured at the lookup-injection boundary.

---

# 20. Gated Residual state precision

Qwen's technical material explicitly notes FP8 storage for Flash-Next residual state.

That is a useful clue for Aesir because GR state is repeatedly read and written.

Benchmark:

```text
FP32 reference
BF16
FP16
FP8 storage + higher-precision compute
```

Measure not only memory but bandwidth and long-sequence numerical drift.

---

# 21. vLLM support

Current upstream vLLM recipes support both models and provide useful implementation evidence.

For Qwen3.8-27B, the recipe includes:

- native 262K context;
- MTP speculative decoding;
- text-only operation;
- multimodal serving;
- Qwen reasoning parser;
- Qwen3 Coder-style tool-call parser;
- static YaRN configuration for extended context.

For Flash-Next, the recipe includes:

- Qwen4-Exp architecture;
- QSA;
- MTP;
- multimodality;
- long context;
- PLE/n-gram host-memory offload notes;
- BF16/FP8/MXFP4 memory guidance.

Aesir can use these recipes as integration references while still implementing its own runtime.

---

# 22. SGLang support

Official Qwen examples include SGLang serving for these models.

The significance for Aesir is mainly compatibility evidence:

- chat templates;
- reasoning parsing;
- tool parsing;
- multimodal request shape;
- long-context serving.

Aesir should avoid copying framework architecture blindly. The goal is numerical and interface compatibility where useful, not dependence.

---

# 23. Transformers support

Transformers exposes:

```text
qwen3_5
qwen4_exp
```

model families/classes.

For Project Aesir, Transformers is especially useful as a **golden mathematical reference** on tiny synthetic configurations.

Recommended process:

1. create tiny config;
2. initialize deterministic random weights;
3. run Transformers FP32/BF16;
4. run Aesir reference path;
5. compare intermediate tensors and logits;
6. only then optimize.

This avoids debugging enormous checkpoints when a sign, gate, reshape, or state update is wrong.

---

# 24. llama.cpp / GGUF support

llama.cpp and ggml-org are valuable references for:

- GGUF metadata mapping;
- tensor names;
- quantization formats;
- multimodal projector packaging;
- MTP packaging;
- Qwen4Exp conversion.

The Qwen4Exp converter explicitly recognizes the Flash-Next architecture and maps its GDN, QSA, Hyper-Connection/Gated Residual and PLE-related tensors.

Aesir can use the converter as one source when designing its loader, while preserving its own internal graph.

---

# 25. Why loader compatibility is not execution compatibility

A runtime may successfully parse every tensor and still fail to support the model correctly.

Examples:

- treating GDN as ordinary attention;
- ignoring recurrent rollback;
- executing QSA densely;
- flattening Gated Residual into a normal residual add;
- loading PLE but not reproducing hash/address semantics;
- running MTP without restoring all mutable state on rejection.

Aesir should separate status labels:

```text
metadata parsed
weights mapped
reference forward correct
quantized forward correct
MTP correct
multimodal correct
long-context correct
optimized
```

---

# 26. Text-only residency mode

Both architectures benefit from an explicit text-only mode.

The vision tower can be:

```text
unloaded
lazy-loaded
resident
```

For a coding/agent server, lazy-loading can save memory and initialization time while preserving the ability to inspect screenshots later.

Aesir should expose this as a residency policy rather than a different model identity.

---

# 27. Vision projector quantization

The Qwen3.8-27B GGUF ecosystem demonstrates separate BF16 and Q8 vision-projector artifacts.

This suggests Aesir should benchmark vision precision independently from LM precision.

Possible combinations:

```text
LM Q6 + vision Q8
LM Q4 + vision Q8
LM Q8 + vision BF16
```

Visual benchmark quality should determine how far vision components can be quantized safely.

---

# 28. Native MTP packaging

MTP may be embedded in high-level checkpoints but appear as a separate artifact in some GGUF workflows.

Aesir should not care whether MTP tensors arrive:

- inside the main container;
- in a sidecar file;
- in a future standardized package.

The runtime API should simply resolve an optional `DraftProvider`.

---

# 29. External draft models

The ecosystem also experiments with draft approaches such as DFlash/DSpark-style systems.

Aesir should therefore make speculative decoding pluggable:

```text
DraftProvider
├── native MTP
├── external small model
├── architecture-specific drafter
└── none
```

The verifier and state-transaction machinery can remain common.

---

# 30. Speculative decoding quality is acceptance-dependent

More draft tokens do not automatically mean higher throughput.

Aesir should adapt draft depth using:

```text
acceptance rate
verification cost
rollback cost
batch size
current generation type
```

For JSON/tool calls, aggressive speculation may behave differently from prose or code.

A dynamic controller can outperform one fixed draft count.

---

# 31. Prefill and decode must be benchmarked separately

## Prefill

Characteristics:

- many tokens in parallel;
- compute throughput matters heavily;
- chunk size matters;
- QSA can radically alter long-context attention cost;
- prefix cache can make the entire operation disappear on a hit.

## Decode

Characteristics:

- one/few new tokens per sequence;
- weight bandwidth often dominates dense models;
- expert cache locality matters in MoE;
- GDN state latency matters;
- MTP acceptance matters;
- sparse retrieval and index lookup matter.

A single tok/s score is not enough.

---

# 32. 128 GB unified-memory target: Qwen3.8-27B

A 128 GB unified-memory-class machine is extremely comfortable for the 27B model at high-quality quantization.

Representative Q8 core weights are only about 28.6 GB in the upstream GGUF conversion.

This leaves substantial space for:

- MTP;
- vision;
- 262K state;
- OS/application reserve;
- another local model or image generator.

The real performance question becomes **memory bandwidth and kernel efficiency**, not whether the weights fit.

---

# 33. 128 GB unified-memory target: Flash-Next

Flash-Next is much more demanding.

Community low-bit packages show that some 4-bit-and-below representations can fit under 128 GB *as files*, but that does not mean the complete runtime comfortably fits.

Additional needs include:

- operating-system reserve;
- GDN/GR/QSA mutable state;
- context history;
- work buffers;
- MTP;
- optional vision;
- PLE handling;
- memory allocator overhead.

Therefore the correct Aesir strategy is likely architecture-aware tiering, not merely squeezing the whole file into RAM.

---

# 34. Coexistence with another model

Aesir should explicitly support workloads where the LLM is not the only resident model.

Example:

```text
Qwen3.8-27B
+ image-generation model
+ agent server
+ OS/UI
```

The memory manager should accept a reserve target rather than greedily consuming every available byte.

Suggested policy:

```text
system reserve
external-model reserve
Aesir cache budget
model weights
context state
```

This makes high-memory local machines much more useful than runtimes that allocate to the cliff edge.

---

# 35. Memory-map versus explicit load

For large models, Aesir should support both:

## Memory mapped

Advantages:

- fast startup;
- OS page cache;
- natural oversubscription;
- useful for cold experts/PLE.

Risks:

- unpredictable faults under pressure;
- page-granularity inefficiency;
- difficult latency control.

## Explicit residency

Advantages:

- predictable;
- pinned/hot memory;
- easier NUMA/device placement.

Risks:

- longer load;
- higher committed memory.

Hybrid policies will likely be best for Flash-Next.

---

# 36. NVMe as a model-memory tier

Flash-Next makes NVMe research especially relevant because two large structures are conditionally accessed:

- routed experts;
- PLE rows.

Aesir can investigate:

```text
mmap cold experts
explicit async expert reads
mmap PLE
row/page cache
io_uring/direct-I/O style backends where appropriate
read-ahead based on routing/hash predictions
```

The goal is to hide storage latency behind useful compute.

---

# 37. Expert streaming

Aesir already has Project Aesir research around expert streaming, making Flash-Next a natural future beneficiary.

A robust expert cache should track:

```text
expert ID
resident bytes
last used token
frequency
co-occurrence
fetch latency
quant format
storage tier
```

Eviction should be workload-aware rather than simple FIFO.

---

# 38. PLE prefetch differs from expert prefetch

Expert selection is learned and depends on hidden activations.

PLE addresses are deterministic from token n-grams.

Therefore PLE can often be predicted earlier and more reliably.

Aesir should maintain separate scheduling policies:

```text
ExpertPrefetcher
NGramPrefetcher
```

Trying to force both through one generic cache path may lose useful information.

---

# 39. Quantization correctness harness

For each quant format and tensor class, Aesir should record:

```text
max abs error
mean abs error
cosine similarity
logit KL divergence
selected-expert agreement
QSA selected-block agreement
MTP acceptance delta
perplexity delta
representative task delta
```

This is far more informative than "model still talks."

---

# 40. Performance benchmark matrix

## Qwen3.8-27B

Test:

```text
BF16 reference
FP8 where supported
Q8
Q6
Q5
Q4
```

Across:

```text
8K
32K
128K
262K
524K YaRN
1M YaRN
```

With:

```text
MTP off/on
vision off/on
prefix cache cold/warm
batch 1 / multi-sequence
```

## Flash-Next

Test component-wise:

```text
expert quant
router precision
QSA indexer precision
PLE precision/tier
GR-state precision
MTP on/off
QSA budget variations only for research, not compatibility mode
```

---

# 41. Metrics Aesir should publish

At minimum:

```text
model load time
memory committed
memory resident
peak memory
first-token latency
prefill tok/s
decode tok/s
accepted speculative tokens/s
MTP acceptance rate
GDN time
attention/QSA time
MoE routing time
expert cache hit rate
PLE cache hit rate
NVMe bytes/token
vision-encode latency
context-state bytes
```

For high-quality engineering, also publish the exact model file, quant, context and backend revision.

---

# 42. Runtime correctness before optimization

Every optimized kernel should have a reference path.

Recommended order:

```text
FP32 tiny synthetic graph
→ BF16 real architecture
→ quantized tiny graph
→ real model short context
→ MTP
→ multimodal
→ long context
→ hardware tuning
```

Do not debug quantization, recurrent state, sparse attention and 262K context simultaneously.

---

# 43. Suggested Aesir backend interfaces

```text
MatmulBackend
QuantBackend
StateBackend
AttentionBackend
SparseAttentionBackend
MoEBackend
StorageBackend
VisionBackend
SpeculationBackend
```

This keeps Qwen support from becoming one enormous architecture-specific function.

---

# 44. Model loading should emit a placement plan

Example:

```text
Qwen3.8-27B Q8
Core weights            28.6 GiB → unified/GPU-hot
Vision                    0.6 GiB → lazy
MTP                       3.2 GiB → hot
KV budget                 8.0 GiB → Q8
GDN state                 ...     → FP32 hot
Work buffers              ...
Reserved for system      16.0 GiB
Reserved external model  32.0 GiB
```

For Flash-Next:

```text
shared weights           → hot
router                    → hot/high precision
expert cache              → bounded hot tier
cold experts              → RAM/NVMe
PLE hot rows              → RAM cache
PLE backing               → RAM/NVMe
GR/GDN state              → hot
```

This makes the runtime understandable and debuggable.

---

# 45. Aesir optimization hypotheses worth testing

These are research hypotheses, not established Qwen facts:

1. Q6 may be the quality/speed sweet spot for 27B on high-bandwidth unified memory.
2. Q4 may win decode if the kernel is fused enough to overcome dequant overhead.
3. GDN recurrent state should remain higher precision than most weights.
4. Flash router and QSA indexer should remain higher precision than cold experts.
5. GR FP8 state can reduce bandwidth without meaningful quality loss if implemented like the reference design.
6. PLE rows may benefit from a custom row-oriented quant format rather than a GEMM-oriented block format.
7. Separate hot/cold expert quantization may outperform uniform quantization at the same memory budget.
8. Native MTP draft depth should adapt to workload and acceptance rate.

---

# 46. Sources

Primary/upstream:

- https://huggingface.co/Qwen/Qwen3.8-27B
- https://huggingface.co/Qwen/Qwen3.8-27B-FP8
- https://huggingface.co/Qwen/Qwen3.8-Flash-Next
- https://huggingface.co/Qwen/Qwen3.8-Flash-Next-FP8
- https://github.com/QwenLM/Qwen3.8
- https://github.com/QwenLM/Qwen3.8-Flash-Next
- https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF
- https://github.com/ggml-org/llama.cpp/blob/master/conversion/qwen4exp.py
- https://github.com/vllm-project/recipes/blob/main/models/Qwen/Qwen3.8-27B.yaml
- https://github.com/vllm-project/recipes/blob/main/models/Qwen/Qwen3.8-Flash-Next.yaml
- https://arxiv.org/abs/2608.30320

Community low-bit artifact sizes are used only as explicitly labeled ecosystem evidence.

---

# 47. Bottom line

The right Aesir question is not:

> "What quant can make the file fit?"

It is:

> **"Which parts of this architecture deserve bandwidth, precision and residency, and which parts can be compressed, cached, prefetched or streamed?"**

Qwen3.8-27B rewards excellent dense quant kernels and hybrid-state handling. Flash-Next rewards a much richer memory hierarchy. Supporting both well would push Project Aesir beyond a generic model loader into an architecture-aware inference system.
