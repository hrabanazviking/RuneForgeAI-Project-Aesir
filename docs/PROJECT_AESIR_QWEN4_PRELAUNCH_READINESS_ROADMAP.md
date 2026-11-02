# Project Aesir — Qwen 4 Pre-Launch Readiness Roadmap

**Status:** Pre-Qwen4 architecture preparation  
**Purpose:** Build the already-understood Qwen4-era inference technologies into Project Aesir **before** the final Qwen4 model family needs to be downloaded or run.  
**Primary reference architecture:** Qwen3.8-Flash-Next / `qwen4_exp`, released by Qwen as an experimental preview of the architecture that will underpin Qwen4.

---

## 1. Mission

Project Aesir should not wait for Qwen4 weights before becoming Qwen4-aware.

The goal of this roadmap is to implement the **architectural machinery, memory systems, kernel interfaces, cache structures, and test harnesses** that are already public and technically understood.

The result should be that when a production Qwen4 model arrives, Aesir is not beginning from zero. Instead, model support should mostly become:

1. parse the final configuration;
2. map tensor names;
3. validate dimensions and layer schedule;
4. load weights;
5. compare numerical output against a reference runtime;
6. optimize hardware-specific kernels.

This roadmap deliberately avoids requiring the actual Qwen3.8-Flash-Next or Qwen4 weights.

---

# 2. What Is Already Known

Qwen has publicly described Qwen3.8-Flash-Next as an **experimental preview of the architecture that will underpin Qwen4**.

The publicly exposed architecture contains several major technologies that Aesir can prepare for now:

- **Hybrid Gated DeltaNet + Qwen Sparse Attention (QSA)**
- **Gated Residual / multi-stream residual connections**
- **Per-Layer / n-gram Embedding (PLE)**
- **Mixture-of-Experts compatibility**
- **Multi-Token Prediction (MTP)**
- **Very long-context inference**
- **Multimodal model structure**
- **Asynchronous host/disk offload of large embedding memory**
- **Data-dependent sparse attention selection**
- **Persistent recurrent/cache state beyond a conventional KV cache**

The current preview uses a repeating hybrid layout where most layers use Gated DeltaNet and periodic layers use QSA. The exact dimensions, layer counts, expert counts, context lengths, and ratios in final Qwen4 models **must not be hard-coded**.

The engineering principle for Aesir should therefore be:

> **Implement the mechanism, parameterize the dimensions.**

---

# 3. Non-Goals for This Pre-Launch Work

Do **not** spend time on:

- downloading the giant preview checkpoint merely to say it runs;
- hard-coding Qwen3.8-Flash-Next dimensions;
- duplicating Qwen training infrastructure;
- implementing Muon optimizer support unless Aesir later becomes a training engine;
- chasing Qwen4 rumors that are not represented in public architecture or code;
- prematurely optimizing one exact GPU architecture before correctness exists;
- assuming every Qwen4 model will be MoE;
- assuming every Qwen4 model will use the exact same QSA budget or GDN/QSA layer ratio.

The target is a **Qwen4-capable inference architecture**, not a one-checkpoint hack.

---

# 4. Guiding Architecture for Aesir

Create a model execution layer where a transformer-like model is expressed as a graph of interchangeable blocks.

Suggested conceptual structure:

```text
Model
├── Token / multimodal embedding
├── Optional PLE / n-gram memory
├── Residual stream manager
├── Decoder layers
│   ├── Gated Residual read
│   ├── Attention block
│   │   ├── Dense attention
│   │   ├── Gated DeltaNet
│   │   └── Qwen Sparse Attention
│   ├── Gated Residual write
│   ├── Gated Residual read
│   ├── FFN / MoE
│   └── Gated Residual write
├── Optional MTP drafter
└── LM head
```

Aesir should treat these as **capabilities**, not as a monolithic `Qwen4` class.

---

# 5. Phase 0 — Qwen4-Ready Configuration Layer

## Goal

Make Aesir capable of describing Qwen4-style architectures even without weights.

## Build

Create a configuration structure supporting at minimum:

```text
model.hidden_size
model.num_layers
model.vocab_size
model.context_length

residual.stream_count
residual.mixer_rank
residual.read_gate
residual.write_gate

attention.layer_type[]
attention.full_attention_interval

gdn.qk_heads
gdn.v_heads
gdn.head_dim
gdn.conv_kernel
gdn.output_gate

qsa.query_heads
qsa.kv_heads
qsa.head_dim
qsa.indexer_heads
qsa.indexer_kv_heads
qsa.indexer_head_dim
qsa.block_size
qsa.selection_budget

ple.enabled
ple.layer_ids[]
ple.ngram_orders[]
ple.table_rows
ple.embedding_dim
ple.hash_parameters
ple.conv_kernel
ple.storage_backend

moe.num_experts
moe.experts_per_token
moe.shared_experts
moe.expert_hidden_size

mtp.enabled
mtp.num_draft_layers
mtp.max_draft_tokens

rope.type
rope.theta
rope.partial_rotary_factor
rope.multimodal_sections
```

## Important rule

Every value must come from metadata/configuration where possible.

Never write logic such as:

```text
if qwen4:
    experts = 512
    sparse_budget = 2048
    residual_streams = 4
```

Instead:

```text
experts = config.moe.num_experts
sparse_budget = config.qsa.selection_budget
residual_streams = config.residual.stream_count
```

## Deliverable

Aesir can instantiate a **zero-weight mock Qwen4 graph** from a JSON/TOML/YAML test configuration.

---

# 6. Phase 1 — Gated Residual / Multi-Stream Residual Engine

## Why first

This changes the topology of the entire model.

The Qwen4 preview does not merely use a normal single residual stream. It widens the residual path into multiple streams and dynamically controls how information is read from and written back to them.

The preview currently exposes **four streams**, but Aesir should support an arbitrary configurable count.

## Build

Create three primitives:

### `residual_expand()`

Converts the initial hidden state into the configured multi-stream representation.

Conceptually:

```text
[B, T, H]
    ↓
[B, T, R, H]
```

Where:

- `B` = batch
- `T` = tokens
- `R` = residual streams
- `H` = hidden size

### `residual_read()`

Mixes the residual branches into the hidden representation used by an attention or FFN/MoE block.

Include support for:

- learned low-rank mixing;
- element-wise data-dependent read gating;
- normalization;
- configurable mixer rank.

### `residual_write()`

Injects the block output back into the residual branches using per-branch learned gates.

## Pre-model tests

Use tiny random tensors:

```text
hidden_size = 32
streams = 4
mixer_rank = 8
sequence = 16
```

Validate:

- shapes;
- deterministic output;
- gating boundaries;
- numerical agreement between a simple reference implementation and optimized implementation;
- FP32, BF16 and FP16 paths;
- no unintended allocation inside token-by-token decode.

## Optimization target

Fuse:

```text
norm → low-rank mixer → gate
```

where profitable.

## Completion criterion

The residual engine should be usable independently of Qwen.

---

# 7. Phase 2 — Gated DeltaNet Core

## Goal

Implement the linear/recurrent attention path that handles most layers in the current Qwen4 preview architecture.

## Build a clean GDN operator

The implementation should expose:

```text
GatedDeltaNet.forward_prefill()
GatedDeltaNet.forward_decode()
GatedDeltaNet.create_state()
GatedDeltaNet.reset_state()
GatedDeltaNet.clone_state()
```

The state must be owned **per request**, not globally by the model.

## Components to support

Prepare for:

- separate Q/K/V projections;
- output gate;
- recurrent delta-rule state;
- causal depthwise convolution state;
- Q/K normalization;
- differing QK and V head counts;
- configurable head dimensions;
- sigmoid-style output gating;
- chunked prefill.

## Critical engineering distinction

Traditional attention primarily carries a growing KV cache.

Gated DeltaNet carries a **compact recurrent state** plus convolution history.

Aesir therefore needs a generalized request-state system:

```text
RequestState
├── KV cache
├── GDN recurrent state
├── GDN convolution state
├── QSA indexer state
├── PLE n-gram history
├── PLE convolution state
└── MTP temporary state
```

This should be designed now rather than bolted onto the KV cache later.

## Synthetic benchmark

Implement a microbenchmark that measures:

- prefill tokens/sec;
- decode tokens/sec;
- recurrent-state bandwidth;
- state initialization cost;
- chunk-size sensitivity.

No model weights required.

---

# 8. Phase 3 — Qwen Sparse Attention (QSA)

## Goal

Implement the most important new long-context feature independently from the full model.

QSA uses a lightweight indexer to identify important **micro-blocks** of context and performs expensive attention only over the selected regions.

This is different from ordinary token-level top-k sparse attention.

## Build in two layers

### Layer A — QSA Indexer

Input:

```text
query state
compressed/index keys
block metadata
selection budget
```

Output:

```text
selected block IDs
attention gather plan
```

Required abilities:

- block-level scoring;
- top-k / budgeted block selection;
- preserve causal ordering;
- retain the incomplete current/trailing block;
- deduplicate blocks;
- produce contiguous gather ranges when possible;
- deterministic tie handling.

### Layer B — Sparse Attention Executor

Input:

```text
Q
selected K/V blocks
mask / position metadata
```

Output:

```text
attention result
```

## Aesir-specific optimization opportunity

Build a **block gather planner** rather than materializing a giant sparse mask.

Suggested flow:

```text
Indexer
   ↓
Selected block IDs
   ↓
Sort / merge neighboring blocks
   ↓
Gather descriptor
   ↓
Sparse attention kernel
```

This should improve cache locality and reduce temporary memory.

## Synthetic long-context simulator

Generate fake sequences at:

```text
8K
32K
64K
128K
262K
1M
```

Do not run a model.

Feed randomized index keys and queries into the indexer and measure:

- index search latency;
- number of blocks touched;
- gather bandwidth;
- memory allocation;
- scaling curve;
- decode latency as context increases.

## Correctness mode

For short contexts, compare QSA output against dense attention when the selection budget is large enough to include the entire causal history.

This becomes a powerful unit test.

---

# 9. Phase 4 — PLE / N-Gram Embedding Memory

## Goal

Build the architecture that may be one of Aesir's biggest advantages on large unified-memory and SSD-backed systems.

The Qwen4 preview introduces a huge embedding memory indexed by hashed local token n-grams. This provides enormous parameter capacity without requiring all of that capacity to participate in matrix multiplication on every token.

The preview architecture also makes this memory suitable for host-memory or storage offload.

## Build a generic `NGramMemory` interface

```text
NGramMemory
├── hash(tokens)
├── lookup(indices)
├── prefetch(indices)
├── cache(indices)
└── inject(hidden_state)
```

## Storage backends

Implement the same logical table over multiple storage types:

```text
RAM
memory-mapped file
NVMe / SSD direct-read abstraction
future GPU/unified-memory backend
```

## Do not start with a gigantic table

Build a synthetic table:

```text
10K rows
100K rows
1M rows
```

Fill it with deterministic generated values.

This permits complete development without real model weights.

## Required features

- bigram/trigram hashing;
- configurable n-gram order;
- exact reproducible hash arithmetic;
- row sharding;
- batched row gathering;
- asynchronous prefetch;
- page-aware caching;
- hot-row cache;
- per-request token history;
- dilated depthwise convolution stage;
- gated injection into the hidden representation.

## Aesir experimental feature: SSD-backed PLE

This is especially worth developing.

Architecture:

```text
Token IDs
   ↓
n-gram hashes
   ↓
Prefetch planner
   ├── RAM row cache hit → immediate
   └── miss → async SSD read
                    ↓
              pinned/staging buffer
                    ↓
             embedding injection
```

Track:

```text
cache hit rate
SSD reads/token
average read size
prefetch accuracy
queue depth
latency hidden by compute
```

The PLE system should never assume the complete lookup table must reside in accelerator memory.

---

# 10. Phase 5 — Hybrid Layer Scheduler

## Goal

Allow one decoder to mix fundamentally different attention mechanisms.

The preview uses a repeating hybrid pattern containing GDN layers and periodic QSA layers.

Aesir should represent this with explicit per-layer metadata:

```text
layer[0]  = GDN
layer[1]  = GDN
layer[2]  = GDN
layer[3]  = QSA
...
```

Do not infer the schedule at runtime from a fixed modulo unless the configuration specifically requests that behavior.

## Build

```text
enum AttentionKind {
    Dense,
    GatedDeltaNet,
    QwenSparseAttention
}
```

Each decoder layer gets its own `AttentionKind`.

## Test configuration

Create fake models such as:

```text
8 layers:
GDN GDN GDN QSA
GDN GDN GDN QSA
```

and deliberately weird cases:

```text
GDN QSA GDN QSA
Dense GDN QSA Dense
```

If Aesir can execute the weird versions, the architecture is truly generic.

---

# 11. Phase 6 — Multi-Token Prediction and Speculative Decode Framework

## Goal

Prepare Aesir to use a model-native MTP head when one exists.

MTP can draft multiple future tokens and allow the primary model to verify them, reducing the number of expensive full decode steps.

## Build framework first

```text
Main Model
    ↓
MTP Drafter
    ↓
token A
token B
token C
    ↓
verification
    ↓
accept prefix / reject remainder
```

## Required engine capabilities

- draft-token buffer;
- verification pass;
- partial acceptance;
- rollback;
- state checkpointing;
- KV/GDN/QSA/PLE state rollback;
- acceptance statistics;
- adaptive draft length.

## Extremely important

Rollback must not only restore the normal KV cache.

It may need to restore:

```text
GDN recurrent state
GDN conv state
QSA indexer state
PLE token history
PLE conv state
KV cache
position counters
```

Designing this state-transaction layer early will save enormous pain later.

## Test without a model

Create a toy probability generator where the fake drafter proposes 1–8 tokens and a fake verifier accepts a controllable percentage.

Benchmark:

```text
acceptance rate
rollback cost
state snapshot cost
tokens/verification
```

---

# 12. Phase 7 — MoE Routing Without Qwen-Specific Assumptions

The Flash preview is highly sparse MoE, but Aesir should not assume every Qwen4 model uses the same MoE configuration.

## Build / verify

- configurable expert count;
- configurable top-k routed experts;
- optional shared expert;
- expert grouping abstraction;
- expert weight paging;
- expert prefetch;
- expert hot-cache statistics;
- dense-FFN fallback using the same layer interface.

## Synthetic expert benchmark

Build 64, 128, 256 and 512 fake-expert configurations using very small matrices.

Measure:

- routing cost;
- sorting/grouping cost;
- expert batching;
- expert cache behavior;
- dispatch overhead;
- load balance.

This lets Aesir optimize the **routing machinery** without needing a huge model.

---

# 13. Phase 8 — Unified Memory and Tiered Offload Manager

This is a major Aesir opportunity.

Qwen4-era models may contain several different classes of memory:

```text
frequently accessed dense weights
routed expert weights
KV cache
GDN recurrent state
QSA index keys
PLE lookup rows
vision weights
MTP weights
```

They should not all obey the same placement policy.

## Build a tiered residency system

Possible tiers:

```text
Tier 0 — accelerator / fastest unified region
Tier 1 — normal system/unified RAM
Tier 2 — memory-mapped SSD
Tier 3 — cold storage / unloaded
```

Each tensor group should declare:

```text
access frequency
latency sensitivity
sequential/random access pattern
prefetchability
size
mutability
```

Then Aesir can make intelligent placement decisions.

## Example

A huge PLE table:

```text
large
read-only
sparse/random row access
prefetchable
```

is fundamentally different from:

```text
GDN recurrent state
small
mutable every token
extremely latency-sensitive
```

Treating both as generic "weights" would waste the new architecture.

---

# 14. Phase 9 — Long-Context Runtime

## Goal

Make long context an architectural feature rather than a giant KV allocation.

Build support for:

- 64K;
- 128K;
- 262K;
- optional experimental 1M-class contexts.

## Components

### Chunked prefill

Never require the full prompt to be processed as one monolithic operation.

### Prefix cache

Allow reusable project/system context to remain cached.

### Mixed cache types

A request may simultaneously contain:

```text
GDN recurrent state
QSA sparse KV blocks
QSA index keys
PLE history
traditional KV regions
```

### Quantized cache

Keep KV/index cache dtype independent from weight dtype.

Examples:

```text
Q8 weights + Q8 KV
Q8 weights + Q4 KV
Q6 weights + Q8 KV
```

### Memory budgeter

Before launching a request:

```text
estimate required state
reserve safety headroom
choose cache dtype
choose prefill chunk
choose offload policy
```

This should eventually be especially useful on the planned 128 GB unified-memory target system.

---

# 15. Phase 10 — Multimodal Plumbing Without a Vision Model

The Qwen4 preview is multimodal and contains a vision encoder architecture.

Aesir can prepare the language-model side now without implementing every vision kernel.

## Build

A generic modality interface:

```text
ModalityEncoder
    ↓
embedding sequence
    ↓
position metadata
    ↓
language model
```

Prepare for:

- image token ranges;
- video token ranges;
- multimodal rotary position metadata;
- interleaved text/vision embeddings;
- text-only mode that skips loading vision components.

## Mock test

Create a fake vision encoder that simply produces deterministic vectors.

The language runtime should not care whether those vectors came from:

```text
an actual ViT
a test fixture
an image model
another Aesir module
```

This clean separation will make real vision support easier later.

---

# 16. Phase 11 — Kernel Interface and Hardware Backends

Do not make Qwen4 functionality dependent on one accelerator API.

Define architecture-level kernels first:

```text
gated_residual_read
gated_residual_write
gdn_prefill
gdn_decode
qsa_index
qsa_attention
ngram_hash
ngram_gather
ngram_conv
moe_route
moe_dispatch
mtp_verify
```

Then provide backends:

```text
reference CPU
optimized CPU
Mojo/SIMD
CUDA
ROCm
future NPU
```

For Project Aesir, the **reference implementation is sacred**.

Every optimized kernel should have a tiny deterministic numerical test against the reference path.

---

# 17. Phase 12 — Qwen4 Compatibility Harness

Create a test suite before the model arrives.

Suggested directory:

```text
tests/qwen4/
├── configs/
│   ├── tiny_dense.json
│   ├── tiny_hybrid.json
│   ├── tiny_moe.json
│   └── tiny_multimodal.json
├── residual/
├── gdn/
├── qsa/
├── ple/
├── mtp/
├── moe/
├── cache/
└── integration/
```

## Tiny synthetic Qwen4

Make an intentionally tiny model:

```text
hidden size: 32
layers: 8
residual streams: 4
GDN layers: 6
QSA layers: 2
QSA block size: 4
QSA budget: 16
experts: 8
active experts: 2
PLE rows: 4096
MTP draft: 3
vocabulary: 256
```

Randomly initialize the weights from a fixed seed.

This model is not meant to be intelligent.

It exists purely to prove that the complete Aesir execution graph works.

---

# 18. Phase 13 — Golden Reference Testing

When possible, use the public Transformers `Qwen4Exp` implementation as a mathematical reference.

For tiny hand-created configurations:

1. initialize identical small tensors;
2. run the reference implementation;
3. run Aesir;
4. compare:
   - intermediate residual states;
   - GDN output;
   - QSA selected blocks;
   - QSA output;
   - PLE output;
   - router decisions;
   - MTP logits;
   - final logits.

This is far more useful during development than trying to debug a 100B+ checkpoint.

## Numerical tolerances

Maintain separate expected tolerances for:

```text
FP32
BF16
FP16
FP8
Q8
Q6
Q4
```

---

# 19. Phase 14 — Instrumentation

Qwen4-era inference has too many moving pieces to optimize blindly.

Aesir should expose counters for:

```text
prefill tok/s
decode tok/s
attention time
GDN time
QSA index time
QSA gather time
MoE routing time
expert compute time
PLE lookup time
PLE cache hit rate
SSD bytes read
KV memory
recurrent-state memory
QSA index memory
expert residency
MTP acceptance rate
MTP rollback count
memory high-water mark
```

Add a per-token execution trace mode for debugging.

Example:

```text
Token 16384
  GDN       1.7 ms
  QSA index 0.3 ms
  QSA attn  0.8 ms
  PLE       0.2 ms
  MoE       2.1 ms
  MTP       0.4 ms
```

Optimization becomes dramatically easier when the engine can explain itself.

---

# 20. Suggested Development Order

## Priority A — Begin immediately

1. **Generalized request-state system**
2. **Gated Residual / multi-stream residual**
3. **Gated DeltaNet reference implementation**
4. **QSA indexer**
5. **QSA sparse gather/execution**
6. **Hybrid layer scheduler**

These form the architectural skeleton.

## Priority B — Next

7. **PLE / n-gram hashing**
8. **RAM-backed PLE table**
9. **memory-mapped / SSD-backed PLE**
10. **asynchronous row prefetch**
11. **MTP transactional state**
12. **speculative verification loop**

These are where Aesir can become unusually good on consumer hardware.

## Priority C — Integration

13. **generic MoE routing improvements**
14. **tiered memory manager**
15. **long-context memory budgeter**
16. **multimodal adapter**
17. **quantized KV/index state**
18. **prefix-cache integration**

## Priority D — When Qwen4 weights actually ship

19. add final architecture identifier;
20. parse official configuration;
21. add tensor-name mapping;
22. validate tokenizer;
23. validate RoPE/mRoPE behavior;
24. load a small or suitable Qwen4 model;
25. compare logits against Transformers/llama.cpp/vLLM;
26. tune kernels for the target AMD unified-memory hardware;
27. benchmark Q8/Q6/Q4;
28. benchmark 64K/128K/262K context;
29. benchmark coexistence with Chroma-HD;
30. make the best configuration an official Aesir hardware profile.

---

# 21. Recommended Aesir Internal Milestones

## Milestone `AESIR-Q4-PRE-0`
**Architecture accepted**

- Qwen4-style config schema
- hybrid layer graph
- generalized request state

## Milestone `AESIR-Q4-PRE-1`
**Residual + GDN functional**

- multi-stream residual
- GDN prefill
- GDN decode
- recurrent-state tests

## Milestone `AESIR-Q4-PRE-2`
**QSA functional**

- block indexer
- selection budget
- sparse gather
- short-context dense equivalence test

## Milestone `AESIR-Q4-PRE-3`
**PLE functional**

- n-gram hash
- table lookup
- convolution/injection
- RAM and mmap storage

## Milestone `AESIR-Q4-PRE-4`
**Aesir PLE streaming**

- asynchronous SSD prefetch
- hot-row cache
- telemetry
- synthetic billion-row-capable address space

## Milestone `AESIR-Q4-PRE-5`
**MTP functional**

- drafter interface
- verifier
- state checkpoint/rollback
- adaptive draft length

## Milestone `AESIR-Q4-PRE-6`
**Tiny Qwen4 synthetic model executes end-to-end**

This is the key pre-release victory condition.

At this point Aesir has implemented the known Qwen4-era mechanisms without needing Qwen4 itself.

---

# 22. Project Aesir Opportunity: Do More Than Compatibility

The goal should not merely be:

> "Aesir can run Qwen4."

The stronger goal is:

> **"Aesir understands why Qwen4 is structured this way and exploits that structure for local hardware."**

Three areas are especially promising.

## 22.1 SSD-backed n-gram memory

PLE is unusually friendly to tiered memory because it performs sparse row lookups rather than full dense matrix multiplication.

Aesir can experiment with treating fast NVMe as an extension of model memory.

## 22.2 Unified-state scheduler

Qwen4-style models contain multiple forms of context state.

Aesir can schedule:

```text
KV blocks
QSA index blocks
GDN recurrent state
PLE history
MTP speculative state
```

as one coordinated memory system.

## 22.3 Hardware-adaptive execution

At startup, Aesir can benchmark:

```text
RAM bandwidth
GPU/unified-memory bandwidth
SSD random-read latency
SSD queue-depth behavior
matrix throughput
quantized kernel throughput
```

Then choose:

```text
quantization
KV precision
PLE residency
expert residency
prefill chunk size
QSA gather strategy
MTP draft length
```

automatically.

That is much more interesting than a static model runner.

---

# 23. Things to Keep Parameterized Until Qwen4 Ships

Treat all of these as **preview values, not eternal Qwen4 constants**:

- number of residual streams;
- GDN/QSA layer ratio;
- QSA block size;
- QSA selection budget;
- QSA indexer dimensions;
- number of experts;
- number of active experts;
- shared-expert layout;
- PLE layer location;
- PLE n-gram orders;
- PLE table size;
- MTP depth;
- MTP draft count;
- native context length;
- RoPE/mRoPE configuration;
- vision encoder dimensions;
- quantization format.

If Aesir is properly parameterized, changes in the final Qwen4 family should require **configuration changes instead of architectural rewrites**.

---

# 24. Definition of Done Before Qwen4 Release

Project Aesir is considered **Qwen4-prepared** when all of the following are true:

- [ ] Multi-stream Gated Residual works with synthetic tensors.
- [ ] Gated DeltaNet prefill and decode both work.
- [ ] GDN state is request-local and serializable/checkpointable.
- [ ] QSA block indexing works.
- [ ] QSA sparse attention agrees with dense attention in full-budget tests.
- [ ] Hybrid GDN/QSA layer schedules work.
- [ ] PLE n-gram hashing works deterministically.
- [ ] PLE can use RAM-backed tables.
- [ ] PLE can use mmap/SSD-backed tables.
- [ ] PLE supports asynchronous prefetch.
- [ ] MoE dimensions are configuration-driven.
- [ ] MTP speculative decoding supports rollback of every state type.
- [ ] Quantized cache types are independent from weight quantization.
- [ ] Long-context state can be budgeted before allocation.
- [ ] A fake multimodal embedding source can enter the language graph.
- [ ] Tiny synthetic Qwen4-style model runs end-to-end.
- [ ] Every optimized kernel has a reference correctness path.
- [ ] Telemetry identifies where every millisecond and major memory allocation goes.

At that point, the actual Qwen4 release becomes a **model-integration task**, not a research emergency.

---

# 25. Immediate First Sprint

If development begins immediately, this is the recommended first sprint:

### Task 1
Create `Qwen4ExpConfig`-style generic architecture metadata.

### Task 2
Implement `RequestState` as a container for multiple cache/state types.

### Task 3
Implement four-stream Gated Residual using tiny tensors.

### Task 4
Create reference Gated DeltaNet prefill/decode.

### Task 5
Create a standalone QSA indexer with synthetic block keys.

### Task 6
Build dense-equivalence QSA unit tests.

### Task 7
Create a tiny fake hybrid decoder:

```text
GDN → GDN → GDN → QSA
```

### Task 8
Run it for 1, 16, 256 and 4096 fake tokens.

No actual language model is required.

That gives Aesir the first genuine piece of **Qwen4-ready machinery** immediately.

---

# 26. Reference Sources

Primary public references used to prepare this roadmap:

1. **Qwen3.8-Flash-Next official repository**  
   https://github.com/QwenLM/Qwen3.8-Flash-Next

2. **Qwen3.8-Flash-Next official model card**  
   https://huggingface.co/Qwen/Qwen3.8-Flash-Next

3. **Hugging Face Transformers — Qwen4-Exp architecture documentation**  
   https://github.com/huggingface/transformers/blob/main/docs/source/en/model_doc/qwen4_exp.md

4. **llama.cpp Qwen4Exp conversion support**  
   https://github.com/ggml-org/llama.cpp/blob/master/conversion/qwen4exp.py

5. **vLLM Qwen3.8-Flash-Next recipe**  
   https://github.com/vllm-project/vllm/blob/main/recipes/models/Qwen/Qwen3.8-Flash-Next.yaml

---

## Final Principle

**Do not wait for the giant to arrive before forging the gate.**

Project Aesir can build the Qwen4-era execution machinery now using tiny deterministic test systems. When the real Qwen4 models arrive, the work should shift from architectural invention to validation, mapping, optimization, and benchmarking.
