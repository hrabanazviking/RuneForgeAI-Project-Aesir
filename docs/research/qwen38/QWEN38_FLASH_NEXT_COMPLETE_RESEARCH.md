# Qwen3.8-Flash-Next — Complete Technical Research for Project Aesir

**Research snapshot:** 2026-11-02  
**Model:** `Qwen/Qwen3.8-Flash-Next`  
**Architecture identifier:** `qwen4_exp` / `Qwen4ExpForConditionalGeneration`  
**Primary Aesir relevance:** open Qwen4 architecture preview, sparse MoE, QSA, Gated Residual, n-gram/PLE memory, MTP, long context, multimodality, and tiered-memory inference.

---

# 1. Executive summary

Qwen3.8-Flash-Next is not simply a faster Qwen3.8 model. Qwen explicitly released it as an **early preview of the architecture intended to underpin Qwen4**.

It changes four major dimensions of the Qwen3.8/Qwen3.5 lineage:

1. **Attention** — replaces the global Gated Attention layer in the hybrid cycle with **Qwen Sparse Attention (QSA)** while retaining Gated DeltaNet for the other three layers.
2. **Residual path** — replaces the conventional residual design with **four-branch Gated Residual (GR)**.
3. **Capacity** — adds a **51B-parameter n-gram embedding memory** that is deterministically addressed and designed for host-memory offload/prefetch.
4. **Optimization/training** — co-designs the architecture with **Muon + AdamW**, refitted scaling laws, no batch-size warmup, and stability mechanisms.

The main language model is a **125B sparse Mixture-of-Experts network** with only about **6B parameters active per token**. In addition, the checkpoint includes approximately **51B n-gram embedding parameters** and about **4B MTP parameters**, which is why ecosystem metadata often describes the full checkpoint as roughly 176–180B parameters.

The architecture is:

```text
12 repetitions of:

Gated DeltaNet → MoE
Gated DeltaNet → MoE
Gated DeltaNet → MoE
Qwen Sparse Attention → MoE
```

Each sublayer reads from and writes back to a **four-branch Gated Residual state**.

For Project Aesir, Flash-Next is valuable even if the full checkpoint is not an everyday local model. It exposes the exact categories of machinery that Aesir can implement in advance for Qwen4:

- hybrid recurrent + sparse attention;
- block index selection;
- tiered memory;
- expert routing;
- host/SSD-backed lookup memory;
- multi-state speculative rollback;
- multimodal position handling;
- long-context scheduling.

---

# 2. Official status and role

Qwen describes Flash-Next as:

- open-weight;
- multimodal;
- ultra-sparse MoE;
- an experimental architecture preview;
- a precursor to Qwen4.

Release date in the official repository: **2026-08-26**.

Hugging Face architecture tag:

```text
qwen4_exp
```

Transformers class:

```text
Qwen4ExpForConditionalGeneration
```

The upstream llama.cpp conversion code also registers the architecture as Qwen4Exp and names `Qwen/Qwen3.8-Flash-Next` as its example model.

This matters because it confirms that the `qwen4_exp` naming is not a community nickname. It is the actual architecture identifier used by current model tooling.

---

# 3. Licensing

The Flash-Next repositories are not Apache-2.0 in the same way as Qwen3.8-27B.

The official FP8 model card identifies the license as **Qwen Community 1.0** / `qwen-community-1.0`, while Hugging Face metadata marks the license category as nonstandard/other.

Aesir documentation should therefore avoid assuming that licensing terms are interchangeable between the 27B and Flash-Next checkpoints.

---

# 4. Parameter accounting

Official Qwen description:

```text
Main model:             125B parameters
Active per token:         6B parameters
N-gram embeddings:       51B parameters
MTP module:              ~4B parameters
```

This creates several valid parameter counts depending on what is being discussed:

- **125B** — main model capacity;
- **6B active** — approximate per-token active backbone compute;
- **176B** — main + n-gram memory before separately counting some MTP accounting;
- **~180B** — whole repository metadata including MTP/extra capacity.

For Aesir, raw parameter count is therefore not enough to predict performance or memory traffic.

The important decomposition is:

```text
Dense/shared resident parameters
Routed expert parameters
Deterministic lookup-memory parameters
Speculative/MTP parameters
Vision parameters
Mutable request state
```

Each category wants a different placement strategy.

---

# 5. Core dimensions

Official model/config values:

| Field | Value |
|---|---:|
| Main parameters | 125B |
| Active parameters/token | ~6B |
| N-gram parameters | 51B |
| Hidden size | 2,560 |
| Layers | 48 |
| Vocabulary | 248,320 |
| Native context | 262,144 |
| Full/sparse attention interval | every 4th layer |
| Weight dtype in original config | BF16 |
| RMSNorm epsilon | `1e-6` |
| Hidden activation | SiLU |

The model's hidden width is much smaller than the 27B dense model's 5,120, because capacity is shifted into sparsity, expert count, residual branches, and n-gram memory.

---

# 6. Hybrid GDN + QSA layer schedule

The official schedule is:

```text
12 × (
    3 × (Gated DeltaNet → MoE)
    1 × (Qwen Sparse Attention → MoE)
)
```

That yields:

- 36 GDN layers;
- 12 QSA layers;
- 48 MoE blocks.

The design philosophy can be summarized as:

```text
GDN = continuously compress and remember history
QSA = selectively retrieve precise long-range details
```

This is a deliberate split between a fixed-size recurrent memory path and a sparse exact-retrieval path.

---

# 7. Gated DeltaNet in Flash-Next

Flash-Next retains the GDN geometry from the Qwen3.5/3.8 lineage.

Official config:

| Field | Value |
|---|---:|
| Q/K heads | 16 |
| Value heads | 48 |
| Q/K head dimension | 128 |
| Value head dimension | 128 |
| Convolution kernel | 4 |
| State dtype hint | FP32 |

This means the GDN kernel work done for Qwen3.8-27B can be heavily reused.

However, the surrounding execution environment changes because GDN is now embedded between:

- Gated Residual reads/writes;
- sparse MoE blocks;
- QSA layers;
- PLE/n-gram injection;
- MTP speculative state.

Aesir should therefore isolate GDN math from the model graph around it.

---

# 8. Qwen Sparse Attention (QSA)

QSA is the central new long-context technology.

Traditional full attention directly compares queries against every prior key. Sparse attention reduces that cost by selecting only important historical positions.

Qwen argues that token-level sparse-attention indexers can themselves become expensive at very long context lengths. QSA therefore performs **micro-block compression before selection**.

The broad process is:

```text
historical keys
    ↓
compress into micro-blocks
    ↓
lightweight indexer scores blocks
    ↓
select most relevant blocks
    ↓
expand selected blocks to token ranges
    ↓
run attention over selected context
```

This reduces both:

- attention work;
- index-search work.

---

# 9. QSA exact configuration

The official Flash-Next config exposes:

| QSA field | Value |
|---|---:|
| Query attention heads | 24 |
| KV heads | 2 |
| Attention head dimension | 256 |
| Rotary dimension | 64 |
| Indexer query heads | 4 |
| Indexer shared key heads | 1 |
| Indexer head dimension | 128 |
| Compression ratio | 4 |
| Selection budget | 2,048 tokens |
| Max selected complete blocks | 512 |

The technical description explains the budget relationship:

```text
micro-block size = 4 tokens
selection budget = 2048 tokens
maximum complete selected blocks ≈ 512
```

The incomplete current/trailing block is retained so the active local region does not disappear simply because it has not yet filled a complete compressed block.

---

# 10. QSA indexer architecture

The indexer is described as a lightweight MQA-like structure:

```text
4 query heads
1 shared key head
128-dimensional index heads
```

The indexer's job is not to produce the final attention output. Its job is to cheaply estimate which context blocks are worth retrieving.

That means Aesir should treat QSA as two separable kernels:

```text
qsa_index()
qsa_attention()
```

The index stage outputs a gather plan. The attention stage consumes only the chosen historical regions.

This separation also makes optimization much easier because Aesir can benchmark:

- index scoring;
- top-k/block selection;
- block deduplication;
- gather/coalescing;
- sparse attention itself.

---

# 11. Why block-level selection matters

At extreme contexts, a token-level selector can still scan too much metadata.

QSA's micro-block approach provides several engineering advantages:

- fewer index entries;
- better memory locality;
- contiguous gathers;
- simpler cache-line use;
- easier prefetching;
- fewer tiny random memory operations.

For Aesir, the correct internal representation should likely be a **block gather descriptor**, not a giant sparse boolean mask.

Example:

```text
SelectedBlockPlan
[
  {start: 4096, length: 4},
  {start: 8152, length: 12},
  {start: 29184, length: 8},
  ...
]
```

Neighboring blocks should be merged where possible.

---

# 12. QSA scaling claims

Qwen reports major long-context attention-kernel gains.

The official Alibaba write-up reports at 1M tokens roughly:

- **up to 7.6× prefill attention-kernel speedup**;
- **up to 4.9× decode attention-kernel speedup** relative to dense GQA in its cited setup.

The current vLLM recipe cites later/implementation-specific figures up to approximately:

- **10.2× prefill**;
- **6.6× decode**.

These numbers are context-, implementation-, and hardware-dependent. They should not be treated as universal model-level speed multipliers.

The robust conclusion is simpler:

> QSA is specifically designed so attention cost grows much more gently at very long sequence lengths.

---

# 13. QSA training strategy

The technical report describes QSA as trainable rather than a post-hoc inference mask.

The reported continued-pretraining strategy uses a staged process:

1. train/distill the lightweight indexer against signals from dense/full attention;
2. transition to joint sparse training.

This matters because QSA is not merely an inference heuristic that guesses which tokens are important. The model is trained with the retrieval mechanism in the loop.

For Aesir, inference only needs to reproduce the trained selector math and block semantics. It does not need QSA training support unless Aesir later grows into a training engine.

---

# 14. Gated Residual (GR)

Flash-Next changes the residual architecture substantially.

Instead of one residual stream, the hidden state is widened to **four parallel residual branches**.

Official config:

```text
hc_count = 4
hc_lowrank = 320
```

Qwen describes GR as combining ideas from:

- Hyper-Connections;
- GatedNorm-style dynamic gating.

The model performs a data-dependent read from the parallel residual state and controlled writes back into the branches.

---

# 15. Gated Residual read and write behavior

Conceptually:

```text
Residual state:
R0 ──────────────┐
R1 ──────────────┤
R2 ──────────────┤ → gated read → sublayer input
R3 ──────────────┘

sublayer output
      ↓
per-branch controlled write
      ↓
R0 R1 R2 R3 updated
```

Qwen emphasizes two different forms of control:

- **element-wise, data-dependent read gating**;
- **per-branch write control**.

The widened path gives the model multiple channels through which information can survive across depth.

Qwen reports that one branch naturally develops behavior resembling a longer-range pathway connecting early attention information with deeper layers.

---

# 16. GR and training stability

Qwen reports several reasons GR helps beyond representational capacity:

- reduces destructive mixing of early and late features;
- suppresses activation outliers through gating;
- improves training stability;
- allows removal of extra branch-mixing machinery that did not provide enough benefit;
- adds little arithmetic overhead relative to the model's matrix work.

The official write-up also states that **Residual State can be stored in FP8**, reducing memory traffic.

This is highly relevant to Aesir. Residual state is read/written constantly, so reducing its bandwidth can matter even when its total capacity is modest compared with model weights.

---

# 17. Aesir GR implementation strategy

Implement GR independently from attention or MoE.

Suggested primitives:

```text
gr_expand(initial_hidden)
gr_read(residual_state, lowrank_params, gate_params)
gr_write(residual_state, block_output, write_gate)
```

Required tests:

- branch count parameterization;
- low-rank mixer correctness;
- elementwise gate correctness;
- write-gate correctness;
- FP32 reference;
- BF16/FP16 implementation;
- FP8 state-storage experiment;
- no hidden allocation during decode.

Do not hard-code `4` branches into kernel signatures even though the preview uses four.

---

# 18. Sparse Mixture-of-Experts design

Flash-Next replaces dense FFNs with a huge expert pool.

Official configuration:

| MoE field | Value |
|---|---:|
| Routed experts | 512 |
| Routed experts selected/token | 10 |
| Shared experts | 1 |
| Expert intermediate size | 640 |
| Shared expert intermediate size | 640 |
| Router auxiliary loss coefficient | 0.001 |

So each token activates:

```text
10 routed experts + 1 shared expert
```

rather than all 512 experts.

This is a primary reason the main model can contain 125B parameters while using only roughly 6B active parameters per token.

---

# 19. MoE local-inference implications

MoE changes the bottleneck from "read every weight every token" to a combination of:

- router compute;
- expert selection;
- dispatch/grouping;
- selected expert weight access;
- expert cache locality;
- shared expert work.

On a single high-memory system, the ideal strategy may differ depending on whether all expert weights fit in fast memory.

Aesir should support:

```text
all experts resident
hot-expert cache
expert prefetch
RAM expert store
SSD expert store
hybrid residency
```

The router result for token N can potentially inform prefetch scheduling for expert weights before their GEMMs begin.

---

# 20. Global expert load balancing

Qwen's training recipe retains global load-balancing work from the Qwen3-Next lineage.

The important inference implication is that expert usage is not expected to be perfectly uniform over short workloads.

Aesir should collect real expert-frequency telemetry:

```text
expert hit count
expert bytes fetched
cache hit ratio
routing entropy
shared expert utilization
expert co-occurrence
```

This enables adaptive residency rather than static guesses.

---

# 21. N-gram Embedding / PLE

One of the most unusual Flash-Next features is a massive lookup-memory layer.

Official description:

- 51B additional n-gram embedding parameters;
- one n-gram embedding layer near the beginning of the network;
- indexed from local token context;
- built from bigram/trigram-style local patterns;
- deterministic lookup addresses;
- very little matrix computation per lookup;
- designed for host-memory offload and asynchronous prefetch.

The config identifies the mechanism as PLE-related fields.

---

# 22. Exact n-gram/PLE configuration

Official config fields include:

```text
ngram_vocab_size_base = 20,000,000
ngram_size = 3
ple_layer_ids = [2]
ple_embed_dim = 2560
ple_conv_kernel_size = 4
heads_per_ngram = 8
split_ngram_parts = 128
make_ngram_vocab_size_divisible_by = 128
```

The model card describes:

```text
N-gram Embedding: 20,000,000
bigrams/trigrams at layer 2
```

The 51B parameter figure comes from the scale of the lookup representations, not from a dense matrix multiplied in full every token.

---

# 23. Why n-gram memory is different from MoE

Both MoE and n-gram embedding add conditional capacity, but they behave differently.

## MoE

```text
router computes expert choice
selected expert matrices are multiplied
```

## N-gram memory

```text
local token IDs determine address
selected rows are gathered
```

The n-gram table therefore has properties that are very attractive for tiered storage:

- read-only during inference;
- deterministic future addresses once token IDs are known;
- sparse row access;
- no need to multiply the entire table;
- lookup can be prefetched.

This makes it one of the most promising areas for Aesir-specific innovation.

---

# 24. Host-memory offload and asynchronous prefetch

Qwen explicitly designed the n-gram table so it can be held **outside accelerator memory**.

Because the token sequence determines upcoming n-gram addresses, the runtime can issue lookups early and overlap them with model compute.

Conceptual pipeline:

```text
known token IDs
    ↓
calculate n-gram hashes
    ↓
prefetch required rows from host memory
    ↓
continue GDN / other compute
    ↓
rows arrive
    ↓
inject PLE representation at target layer
```

The current vLLM recipe notes that its n-gram offload path is presently hardware/backend dependent, but the architectural concept is general.

---

# 25. SSD-backed PLE opportunity for Aesir

Qwen's official architecture discusses host-memory offload. Aesir can push the same principle further by experimenting with fast NVMe.

Possible hierarchy:

```text
L0: small accelerator/unified-memory hot-row cache
L1: system/unified RAM row cache
L2: memory-mapped NVMe table
```

Aesir can predict row addresses early, batch nearby pages, and maintain statistics.

Key metrics:

```text
row-cache hit rate
NVMe reads/token
pages/read
prefetch lead time
prefetch accuracy
queue depth
bytes/token
stall time at PLE layer
```

This should be treated as an Aesir experiment, not as an official Qwen requirement.

---

# 26. N-gram lookup quality behavior

The Qwen technical report makes an interesting methodological observation: increasing n-gram vocabulary size can continue lowering language-model loss even after downstream benchmark quality begins to saturate.

This is a warning against optimizing architecture solely on loss.

For Aesir, the inference lesson is different but useful: do not assume every parameter category contributes equally to perceived quality or latency.

PLE quantization/offload can be evaluated separately with task-level benchmarks.

---

# 27. Multi-Token Prediction (MTP)

Flash-Next includes a dedicated MTP module.

Official configuration:

```text
mtp_num_hidden_layers = 1
mtp_use_dedicated_embeddings = false
mtp.hybrid = true
mtp.layer_types = [full_attention]
mtp.rope_theta = 10000000
```

The model card says the MTP module is trained with multiple steps.

Qwen states that this improves speculative-decoding acceptance in realistic scenarios and can also improve the backbone during training.

The MTP full-attention path is itself replaced with QSA in the Flash-Next architecture lineage.

---

# 28. QSA index reuse with MTP

The technical architecture describes reuse of QSA indexing information across speculative steps.

That is important because a naive speculative implementation could pay the sparse-indexing overhead repeatedly for every draft token.

Aesir should architect QSA selection metadata so it can be:

- cached;
- versioned;
- extended for draft positions;
- invalidated on rollback;
- reused when legal.

This is another reason QSA state should not be hidden inside one opaque attention kernel.

---

# 29. Speculative rollback complexity

Flash-Next makes rollback much more complex than classic transformer speculation.

A rejected draft may require restoration of:

```text
GDN recurrent state
GDN convolution history
QSA KV blocks
QSA indexer state
QSA index-selection metadata
Gated Residual state
PLE token/n-gram history
PLE convolution state
MoE/router temporary state if cached
position counters
MTP temporary state
```

Aesir should use **transactional request state**.

Suggested concept:

```text
checkpoint = request_state.begin_speculation()
run drafts
verify
if accepted:
    commit(prefix_length)
else:
    rollback(checkpoint, accepted_prefix)
```

---

# 30. Native context and 1M extension

Like Qwen3.8-27B, Flash-Next natively supports:

```text
262,144 tokens
```

Qwen provides YaRN guidance extending to:

```text
1,000,000 tokens
```

The same static-YaRN caveat applies: an always-on factor optimized for 1M can hurt shorter-context behavior.

Because QSA is specifically designed for extreme long context, Flash-Next is a stronger architectural demonstration of why Qwen is moving toward sparse retrieval rather than simply enlarging KV caches.

---

# 31. Position encoding

Official config:

```text
rope_theta = 10,000,000
partial_rotary_factor = 0.25
mrope_interleaved = true
mrope_section = [11, 11, 10]
```

The QSA and multimodal paths therefore share the broader Qwen mRoPE/partial-RoPE design.

Aesir should keep position computation independent from:

- dense attention;
- QSA;
- GDN;
- MTP;
- vision preprocessing.

---

# 32. Vision encoder

Flash-Next includes a native vision tower.

Official config:

| Field | Value |
|---|---:|
| Depth | 27 |
| Hidden size | 1,152 |
| Intermediate size | 4,304 |
| Heads | 16 |
| Patch size | 16 |
| Spatial merge | 2 |
| Temporal patch | 2 |
| Position embeddings | 2,304 |
| Output hidden size | 2,560 |

This is geometrically very similar to the Qwen3.8-27B vision tower, but projects into Flash-Next's 2,560-wide language hidden state rather than 5,120.

The commonality strongly suggests Aesir can reuse most vision preprocessing and encoder machinery between the two models.

---

# 33. Multimodal capabilities

Official evaluations cover:

- screenshot/computer use;
- mobile use;
- application recreation;
- visual web development;
- embodied/spatial understanding;
- long-video understanding;
- visual math;
- scientific charts;
- real-world perception;
- multimodal tool use.

Representative Qwen-reported Flash-Next results include:

| Benchmark | Flash-Next |
|---|---:|
| ClawEval-MM Pass@3 | 64.4 |
| RecreationBench | 49.9 |
| AndroidWorld | 84.5 |
| Vision2Web | 64.0 |
| ERQA | 72.3 |
| LVBench | 76.6 |
| RealWorldQA | 88.5 |
| MathVision | 90.6 without CI / 95.7 with CI |

These are benchmark results, not guaranteed application behavior.

---

# 34. Thinking controls

Flash-Next follows the Qwen3.8 post-training interface:

- thinking on by default;
- optional non-thinking mode;
- `<think>...</think>` reasoning blocks;
- Qwen3 reasoning parser support in serving frameworks;
- recommended thinking and non-thinking sampling settings.

Current Qwen3.8 interfaces also expose reasoning-depth control and preserved-thinking behavior in the model family/chat-template layer.

Aesir should keep these as chat/runtime controls, not architecture constants.

---

# 35. Tool and agent orientation

Qwen describes Flash-Next as suitable for:

- high-volume applications;
- tool-driven workflows;
- coding assistants;
- coworking/office agents;
- long-horizon tasks.

Reported benchmark examples:

| Benchmark | Flash-Next |
|---|---:|
| DeepSWE 1.1 | 58.7 |
| SWE-bench Pro | 62.5 |
| SWE-bench Multilingual | 81.0 |
| NL2Repo-Bench | 48.1 |
| CoWorkBench | 73.9 |
| JobBench | 55.7 |
| Toolathlon Verified | 73.5 |
| IFBench | 81.3 |
| GPQA Diamond | 91.7 |
| LiveCodeBench v6 | 91.9 |

The key point for Aesir is that efficiency work should preserve the model's long-horizon/tool-loop strengths rather than measuring only short prompt benchmarks.

---

# 36. Training efficiency claim

Qwen reports that compared with Qwen3.7-Plus, Flash-Next training uses roughly **1/9 the training FLOPs** while achieving superior results on a number of coding and office tasks.

The technical report frames this as a co-design outcome rather than a single trick.

Contributors include:

- lower active parameter count;
- hybrid GDN/full retrieval;
- sparse QSA;
- sparse MoE;
- lookup memory;
- optimizer changes;
- batch/learning-rate scaling.

---

# 37. Muon + AdamW optimizer split

Qwen does not apply one optimizer uniformly to all parameters.

The official description says Muon is used for parameters that act as true two-dimensional linear maps, including major weights in:

- attention;
- GDN;
- MoE experts.

AdamW remains used for categories such as:

- embeddings;
- MoE router;
- low-rank GR parameters.

For fused parameter matrices representing multiple conceptual linear maps, Qwen splits them into their logical components before orthogonalization.

This is training research, but it matters for future Aesir finetuning ambitions because naive optimizer application would not reproduce the original recipe.

---

# 38. Refitted scaling law

Qwen reports refitting scaling relationships for the new architecture/optimizer combination.

The result allows:

- larger stable learning rates;
- larger batch sizes;
- improved large-scale training throughput.

This reinforces a broader lesson: architecture and optimizer cannot always be tuned independently.

---

# 39. No batch-size warmup

The technical work reports that conventional batch-size warmup was unnecessary for the final recipe.

Qwen states that gradually growing from a smaller batch to target batch did not improve the result and required **18.8% more optimizer steps**.

The final recipe therefore starts directly at target batch size.

This is a training optimization, not an inference requirement.

---

# 40. Other training-stability mechanisms

Qwen retains several stability techniques from earlier generations:

- zero-centered RMSNorm;
- weight decay on norm weights;
- attention output gating;
- normalized MoE router initialization;
- Gated Residual outlier suppression.

These mechanisms help explain why a faithful implementation should not casually remove gates/norm behavior even if a simplified kernel appears numerically close on a tiny test.

---

# 41. Official FP8 checkpoint

Qwen publishes `Qwen/Qwen3.8-Flash-Next-FP8`.

Official description:

- fine-grained FP8 quantization;
- block size 128;
- performance metrics nearly identical to the original model.

Current vLLM recipe memory figures:

| Format | Approx. checkpoint memory |
|---|---:|
| BF16 | ~335.28 GiB |
| FP8 | ~172.78 GiB |
| AMD Quark MXFP4 | ~169.8 GiB |

The unusual FP8-vs-MXFP4 relationship reflects the fact that this is not a simple uniform "bits per every parameter" model. Large auxiliary structures and quantization policies matter.

---

# 42. PLE host-memory requirement in current runtimes

The current vLLM recipe calls out approximately **51 GB plus runtime headroom** when using host-memory n-gram offload.

That maps directly to the n-gram table's scale.

For consumer systems, this is one of the reasons Flash-Next is interesting on 128GB-class unified memory even though the model is far too large for ordinary consumer discrete VRAM.

---

# 43. GGUF ecosystem and local quantization

Community GGUF conversions exist using the `qwen4exp` architecture.

One large community repository currently exposes approximate file sizes such as:

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

These sizes are **community packaging evidence**, not official Qwen recommendations.

They demonstrate that low-bit versions can enter the capacity range of 128GB systems, but real runtime headroom, context state, PLE strategy, vision weights, MTP, and OS memory must still be considered.

---

# 44. Why Flash-Next is difficult for generic GGUF runtimes

The challenge is not just file size.

A runtime needs to handle:

- GDN state;
- QSA sparse blocks;
- QSA indexer;
- four-branch residual state;
- 512-expert MoE;
- n-gram/PLE table;
- multimodal vision tower;
- MTP;
- long context;
- quantized expert layouts.

A generic "map the whole GGUF and run transformer layers" strategy leaves performance on the floor.

This is exactly why Flash-Next is a compelling Aesir research target.

---

# 45. Consumer-local experimental evidence

Independent community projects have demonstrated specialized Flash-Next execution on consumer/high-memory systems, including 128GB Ryzen AI Max+ 395-class unified-memory machines and split APU/eGPU configurations.

Those projects report large gains from architecture-aware work such as:

- avoiding unnecessary speculative-state copies;
- correct recurrent rollback;
- sparse-attention-aware bandwidth use;
- expert/cache placement;
- boundary tensor handling.

These results are useful evidence that architecture-aware runtimes matter, but they should be treated as **community experiments, not official Qwen performance guarantees**.

For Aesir, they are a signal to benchmark each subsystem independently.

---

# 46. Tiered-memory classification

Flash-Next should not be loaded using one global residency rule.

Suggested Aesir classification:

## Always-hot mutable state

```text
GDN recurrent state
GDN conv state
Gated Residual state
position counters
sampler state
```

## Hot immutable weights

```text
shared projections
router
shared expert
frequently selected experts
attention/QSA projections
```

## Conditionally hot weights

```text
routed experts
vision tower
MTP module
```

## Offload-friendly memory

```text
n-gram/PLE table
cold routed experts
possibly long-context sparse KV blocks
```

This is much richer than traditional CPU/GPU "layer offload."

---

# 47. Aesir hardware-adaptive scheduling opportunity

At model load, Aesir could benchmark:

```text
unified-memory bandwidth
GPU compute throughput
CPU vector throughput
NVMe random read
NVMe sequential read
PCIe bandwidth if discrete GPU present
```

Then select:

```text
expert cache size
PLE cache size
PLE storage tier
QSA gather strategy
residual-state dtype
KV dtype
MTP draft length
prefill chunk size
vision residency
```

Flash-Next is almost a perfect test case for an engine that wants to become hardware-adaptive rather than static.

---

# 48. Qwen4 implications

Qwen explicitly frames Flash-Next as the preview of Qwen4's architecture.

Therefore, the safest technologies for Aesir to pre-build are the **mechanisms**, not the exact preview dimensions:

- Gated Residual interface;
- GDN state engine;
- sparse block indexer;
- sparse attention executor;
- n-gram lookup abstraction;
- tiered storage/prefetch;
- generic MoE router;
- MTP state transaction system;
- hybrid layer scheduler.

Do not assume final Qwen4 models must retain:

- 48 layers;
- 512 experts;
- 4 residual branches;
- 2048-token QSA budget;
- layer-2 PLE;
- exactly 3:1 GDN/QSA.

Parameterize all of it.

---

# 49. Tiny synthetic Flash-Next model for Aesir development

Aesir can test the architecture without loading the real checkpoint.

Suggested test config:

```text
hidden_size = 32
layers = 8
pattern = GDN,GDN,GDN,QSA × 2
residual_branches = 4
residual_lowrank = 8
qsa_block = 4
qsa_budget_tokens = 16
experts = 8
experts_per_token = 2
shared_experts = 1
expert_hidden = 16
ngram_vocab = 4096
ngram_order = 3
ple_layer = 2
mtp_layers = 1
vocab = 256
```

Random fixed-seed weights are enough.

The goal is architectural correctness, not language ability.

---

# 50. Suggested Aesir kernel inventory

Flash-Next motivates explicit kernels/interfaces for:

```text
gdn_prefill
gdn_decode
gdn_state_update
qsa_index
qsa_topk_blocks
qsa_gather
qsa_attention
gr_read
gr_write
moe_route
moe_group
moe_expert_matmul
ngram_hash
ngram_prefetch
ngram_gather
ple_conv
mtp_draft
mtp_verify
state_checkpoint
state_rollback
```

Every optimized path should have a small reference implementation.

---

# 51. Instrumentation requirements

Aesir should expose at least:

```text
GDN ms/token
QSA index ms/token
QSA gather ms/token
QSA attention ms/token
selected blocks/token
MoE routing ms/token
expert cache hit rate
expert bytes/token
PLE lookup ms/token
PLE cache hit rate
SSD/RAM bytes for PLE
GR read/write bandwidth
MTP acceptance
rollback count
KV bytes
GDN state bytes
GR state bytes
memory high-water mark
```

Without this, architecture-aware tuning becomes guesswork.

---

# 52. What Flash-Next teaches Project Aesir

The deepest lesson is that future LLM inference is becoming a **memory-systems problem as much as a matrix-multiplication problem**.

Flash-Next contains several memory types simultaneously:

- recurrent compressed history;
- sparse exact history;
- multiple residual streams;
- routed expert weights;
- deterministic lookup memory;
- speculative state;
- visual embeddings.

A high-performance engine must understand what each memory class is for and place it accordingly.

---

# 53. Sources

Primary/upstream sources:

- Official Qwen Flash-Next repository: https://github.com/QwenLM/Qwen3.8-Flash-Next
- Official model: https://huggingface.co/Qwen/Qwen3.8-Flash-Next
- Official FP8 model card: https://huggingface.co/Qwen/Qwen3.8-Flash-Next-FP8
- Official configuration: https://huggingface.co/Qwen/Qwen3.8-Flash-Next/blob/main/config.json
- Official Alibaba/Qwen architecture article: https://www.alibabacloud.com/blog/qwen3-8-flash-next-a-new-architecture-towardsultimate-cost-efficiency_603501
- Qwen technical report: https://arxiv.org/abs/2608.30320
- Transformers Qwen4-Exp documentation: https://github.com/huggingface/transformers/blob/main/docs/source/en/model_doc/qwen4_exp.md
- llama.cpp Qwen4Exp converter: https://github.com/ggml-org/llama.cpp/blob/master/conversion/qwen4exp.py
- vLLM Flash-Next recipe: https://github.com/vllm-project/recipes/blob/main/models/Qwen/Qwen3.8-Flash-Next.yaml

Community/runtime evidence is intentionally separated from official architectural claims.

---

# 54. Bottom line for Project Aesir

Qwen3.8-Flash-Next is valuable to Aesir for two reasons at once:

1. it is a real open-weight model that can be experimentally run with sufficiently aggressive quantization/offload;
2. it exposes the **future-facing Qwen4 execution model before Qwen4 itself is the dependency**.

The best Aesir strategy is therefore not merely to chase the full Flash-Next checkpoint.

It is to use Flash-Next as an architectural specification:

> **Implement the state machines, sparse retrieval, expert scheduling, Gated Residual, n-gram memory, and speculative transaction model now. Then let the final Qwen4 weights become a mapping and optimization problem instead of an architectural surprise.**
