# 06 - Qwen3-8B Deep Dive for Project A.E.S.I.R.

**Research snapshot:** 2026-11-02  
**Official model:** https://huggingface.co/Qwen/Qwen3-8B

Qwen3-8B is the quality-oriented end of this research set. It keeps the same 36-layer and 8-KV-head cache geometry as 4B, but expands hidden width to 4096 and FFN width to 12288. It is large enough that memory bandwidth, quantized kernel quality, and context-cache management become central engineering concerns.

---

# 1. Official architecture

| Field | Value |
|---|---:|
| Parameters | ~8B class |
| Layers | 36 |
| Hidden size | 4096 |
| FFN intermediate | 12288 |
| Q heads | 32 |
| KV heads | 8 |
| Head dimension | 128 |
| KV width | 1024 |
| Tied embedding / LM head | no |
| RMSNorm epsilon | 1e-6 |
| RoPE theta | 1,000,000 |
| Native context | 32,768 |
| Extended context | Qwen documents YaRN to 131,072 |
| Architecture | `qwen3` |

Official config: https://huggingface.co/Qwen/Qwen3-8B/blob/main/config.json

Unlike the three smaller models, 8B uses an untied output head. That increases model memory but gives Aesir the option, in formats that support tensor-specific precision, to treat embedding and output projection independently.

---

# 2. Intended Aesir role

8B should be viewed as an escalation/quality model rather than a mandatory default for every request.

Good roles:

- hard local reasoning;
- high-quality coding and review;
- complex tool planning;
- final synthesis after smaller workers gather evidence;
- long-form writing;
- multilingual tasks where smaller models fail validation;
- supervisor/judge for outputs from 0.6B/1.7B/4B;
- high-quality local chat.

The largest performance gain may come from **not invoking 8B when 1.7B or 4B can solve the request**.

---

# 3. KV cache

8B has the same KV geometry as 4B:

```text
36 layers * 2 * 8 heads * 128 dim * 2 bytes
= 147,456 bytes/token f16
```

Aesir int8-KV accounting shape:

```text
76,032 bytes/token
```

| Context | f16 KV | int8-KV accounting |
|---:|---:|---:|
| 4K | 576 MiB | ~297 MiB |
| 8K | 1.125 GiB | ~594 MiB |
| 16K | ~2.20 GiB | ~1.13 GiB |
| 32K | 4.50 GiB | ~2.32 GiB |
| 64K | 9.00 GiB | ~4.64 GiB |
| 128K | 18.00 GiB | ~9.28 GiB |

This is the defining long-context challenge. Even if weights are compressed to roughly 5 GB, full 128K f16 KV adds another 18 GiB before activations and runtime overhead.

Aesir should therefore make 8B a flagship target for:

- int8 KV;
- paged KV;
- lazy page allocation;
- prefix sharing;
- prompt-cache reuse;
- history compaction;
- request-specific context caps.

---

# 4. Weight quantization

Representative community GGUF sizes:

```text
Q2_K    ~3.28 GB
Q3_K_M  ~4.12 GB
Q4_K_M  ~5.03 GB
Q5_K_M  ~5.85 GB
Q6_K    ~6.73 GB
Q8_0    ~8.71 GB
```

Recommended test profiles:

- **Q4_K_M**: strong default candidate for consumer GPUs/unified-memory systems.
- **Q5_K_M**: quality-first profile when memory allows.
- **Q6_K**: high-quality/reference profile.
- **Q3_K_M**: constrained VRAM profile if validation remains strong.
- **Q2/IQ2**: specialized extreme-memory mode only.
- **Q8_0**: oracle/reference or high-bandwidth systems.

For batch-1 decode, reducing weight bytes can directly improve speed when the kernel remains efficient because each token streams a large fraction of model weights.

---

# 5. CPU strategy

8B is where high-quality CPU quant kernels matter enormously.

Core priorities:

1. one-pass fused quant decode + dot product;
2. SIMD-specialized blocks for every supported quant;
3. sequential streaming of weights;
4. software prefetch where measured useful;
5. NUMA locality;
6. huge-page experiments where appropriate;
7. tuned thread count at bandwidth saturation;
8. minimized cross-core reduction;
9. dedicated prefill GEMM kernels;
10. no per-token dynamic allocation.

Aesir should measure **effective memory bandwidth during decode**. If the kernel reads ~5 GB of weights per generated token for Q4-class 8B and achieves 10 tok/s, it is effectively moving on the order of 50 GB/s of weight data before other traffic. This kind of roofline reasoning helps reveal whether optimization should target arithmetic or memory.

---

# 6. CUDA/GPU strategy

A fully resident 8B Q4/Q5 model is an excellent target for consumer GPUs with sufficient VRAM or unified-memory APUs.

Priority features:

- resident weights;
- fused Q4/Q5 tensor-core-capable paths where possible;
- separate prefill/decode kernels;
- captured/graph decode loop;
- flash/tiled prefill attention;
- single-query optimized decode attention;
- quantized KV;
- paged allocation;
- prefix reuse;
- async host/device staging only if partial offload is unavoidable.

Avoid inter-layer PCIe ping-pong. If the model cannot fit, group contiguous layers and minimize transfer boundaries rather than alternating devices every block.

---

# 7. Unified-memory machines

On systems with large unified memory, such as modern high-memory APUs, 8B can fit easily even at high precision, but bandwidth and placement still matter.

Aesir should distinguish:

```text
capacity: can the bytes fit?
bandwidth: how fast can weights/KV move?
locality: which compute unit owns the hottest pages?
```

Unified memory removes explicit VRAM capacity walls but does not remove memory traffic. Q4/Q5 can still be faster than Q8/BF16 if the low-bit kernel is good.

---

# 8. YaRN / 128K mode

Qwen's model card documents native 32K and YaRN extension to 131,072. It also warns static YaRN can reduce performance on shorter contexts.

Aesir policy should be dynamic:

- native RoPE under 32K;
- factor chosen to meet, not wildly exceed, requested context;
- explicit user/application long-context flag;
- measured quality gate before enabling extreme context in production;
- cache precision/paging plan selected together with YaRN.

Long-context mode is a **bundle**, not one switch:

```text
YaRN
+ larger logical context
+ paged KV
+ int8 KV
+ chunked prefill
+ memory planner
+ long-context quality tests
```

---

# 9. Output head and sampling cost

Because 8B has an untied LM head, the output projection is its own large matrix. At every generated token it must project hidden=4096 to the vocabulary.

Optimization areas:

- quantize the output head carefully;
- fuse or optimize final norm -> LM head staging;
- keep accumulation precision stable;
- perform efficient top-k/top-p selection without sorting all logits;
- test whether preserving the output head at one precision rung higher improves quality disproportionately.

A mixed-quant scheme might choose, for example, Q5/Q6 output head with Q4 bulk MLP weights if the format and loader permit. This should be measured, not assumed.

---

# 10. Multi-model collaboration

An efficient Aesir system should rarely ask 8B to do clerical work.

Possible pipeline:

```text
0.6B: classify + rewrite request
1.7B: gather/structure intermediate work
4B: draft answer
8B: only verify/synthesize difficult cases
```

Or for coding:

```text
1.7B: locate likely files / summarize diffs
4B: propose patch
8B: review difficult logic or architecture
```

This can produce a higher effective quality-per-joule than leaving 8B active for every microtask.

---

# 11. Speculative decoding

Best candidate drafters:

```text
1.7B -> 8B
4B   -> 8B
```

0.6B may still win on easy text because its draft cost is tiny. Aesir should benchmark all three.

The key metric is target work avoided per unit of drafter work. Track:

- proposed tokens;
- accepted tokens;
- acceptance run length;
- verification batch time;
- target decode time without speculation;
- net latency;
- net energy;
- extra memory footprint.

If the target GPU is already highly efficient and the drafter competes for the same bandwidth, speculation may lose. Heterogeneous placement, such as drafter on CPU/NPU and 8B on GPU, may improve the economics.

---

# 12. Agent and tool mode

8B is the best of these four candidates for complex tool orchestration, but the same structured-protocol rules apply:

- tool calls must be parsed structurally;
- thought text must never trigger a tool;
- validate argument schema;
- preserve exact template semantics;
- retain final responses, not old hidden reasoning, in long conversation history;
- use non-thinking mode for simple calls to cut latency.

---

# 13. Aesir profile proposal

```text
name: qwen3_8b
layers: 36
hidden: 4096
ffn: 12288
q_heads: 32
kv_heads: 8
head_dim: 128
rope_theta: 1000000
tied_embeddings: false
native_context: 32768
yarn_max_validated: 131072
```

Suggested initial modes:

### Balanced
```text
weights Q4_K_M
native context
f16 or integrated int8 KV
GPU/unified memory preferred
reasoning auto
```

### Quality
```text
weights Q5_K_M or Q6_K
native context
reasoning available
```

### Long-context
```text
Q4/Q5 weights
YaRN on demand
int8 KV
paged/lazy allocation
chunked prefill
```

---

# 14. Experiments

### E-8B-01: quant roofline
Measure bytes read/token, tokens/s, and achieved memory bandwidth for Q3/Q4/Q5/Q6/Q8.

### E-8B-02: output-head precision
Keep output head one quant rung higher than bulk weights and test quality/latency.

### E-8B-03: 128K memory stack
Combine YaRN + int8 KV + paging + chunked prefill and prove actual memory rather than arithmetic alone.

### E-8B-04: drafter placement
Compare drafter on same GPU vs CPU vs NPU for 1.7B/4B -> 8B.

### E-8B-05: reasoning router
Measure quality and latency when `auto` turns thinking on only for selected tasks.

### E-8B-06: prefix sharing
Simulate several agent sessions sharing a large system/tool prefix and measure memory saved.

---

# 15. Sources

- https://huggingface.co/Qwen/Qwen3-8B
- https://huggingface.co/Qwen/Qwen3-8B/blob/main/config.json
- https://qwenlm.github.io/blog/qwen3/
- https://arxiv.org/abs/2505.09388
- https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/speed_benchmark.md
- Aesir: `docs/janas/J087_KV_PRECISION_CENSUS.md`
- Aesir: `docs/janas/J088_8BIT_KV.md`
