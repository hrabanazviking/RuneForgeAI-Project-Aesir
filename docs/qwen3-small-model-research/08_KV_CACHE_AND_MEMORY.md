# 08 - KV Cache, Paging, Memory, and Long-Context Economics

**Research snapshot:** 2026-11-02

For these four dense Qwen3 models, KV-cache engineering is as important as weight quantization. At long context the cache can exceed model weights by several times, so Aesir should treat KV precision, allocation, and sharing as first-class runtime policy.

---

# 1. Exact per-token geometry

All four models use:

```text
KV heads = 8
head_dim = 128
KV width = 1024
```

The only difference relevant to cache growth is layer count:

```text
0.6B / 1.7B: 28 layers
4B / 8B:     36 layers
```

For separate K and V in f16:

```text
bytes/token = layers * 2 * kv_heads * head_dim * 2 bytes
```

Therefore:

| Family | f16 bytes/token | f16 KiB/token |
|---|---:|---:|
| 0.6B / 1.7B | 114,688 | 112 |
| 4B / 8B | 147,456 | 144 |

These figures match the arithmetic used by Aesir's J-087 KV precision census for the established Qwen3-0.6B profile and extend the same file-derived geometry to the sibling models.

---

# 2. Aesir's int8-KV accounting

J-088 builds an int8 store shape with per-row scales. That means the real footprint is slightly above exactly half of f16.

For the 28-layer Qwen3 geometry:

```text
59,136 bytes/token
ratio to f16 = 0.515625
```

For the 36-layer geometry:

```text
76,032 bytes/token
ratio to f16 = 0.515625
```

The ratio stays the same because row-scale overhead scales with layer/head rows.

---

# 3. Memory ladder

## 0.6B / 1.7B

| Tokens | f16 | int8-accounted |
|---:|---:|---:|
| 512 | 56 MiB | ~28.9 MiB |
| 4,096 | 448 MiB | ~231 MiB |
| 8,192 | 896 MiB | ~462 MiB |
| 16,000 | ~1.71 GiB | ~0.88 GiB |
| 32,768 | 3.50 GiB | ~1.80 GiB |

## 4B / 8B

| Tokens | f16 | int8-accounted |
|---:|---:|---:|
| 512 | 72 MiB | ~37.1 MiB |
| 4,096 | 576 MiB | ~297 MiB |
| 8,192 | 1.125 GiB | ~594 MiB |
| 16,000 | ~2.15 GiB | ~1.11 GiB |
| 32,768 | 4.50 GiB | ~2.32 GiB |
| 65,536 | 9.00 GiB | ~4.64 GiB |
| 131,072 | 18.00 GiB | ~9.28 GiB |

This makes 128K Qwen3-8B a different systems problem from 8K Qwen3-8B even though weights are identical.

---

# 4. Current Aesir boundary

J-087 documents the generic host engine allocating a fixed-capacity f16 cache, with the main engine runtime capped by `MAX_RUNTIME_CONTEXT` around 16,000 tokens in that filed state. It also reports that `PagedKVCache` exists but no production session consumed it at that point.

J-088 and later Janas work advance 8-bit KV as a tested component, but the integration status should remain evidence-led rather than described as universally complete.

Therefore this research document recommends future work without rewriting the current truth boundary.

---

# 5. Lazy allocation

Aesir should not reserve the full model context at session creation unless the caller explicitly asks for it.

Bad default:

```text
load Qwen3-8B
reserve 32K f16 KV
=> immediately reserve 4.5 GiB
```

Better:

```text
allocate pages/chunks as positions are actually appended
```

Benefits:

- short chats stay small;
- more concurrent sessions fit;
- a 128K-capable configuration does not pay 128K memory up front;
- memory pressure can be predicted incrementally.

---

# 6. Paged KV

A production paged cache should separate logical sequence positions from physical storage pages.

Concept:

```text
logical token positions
     |
     v
page table -> physical KV pages
```

Desired properties:

- fixed-size physical pages;
- allocation on demand;
- pages can be shared for immutable prefixes;
- rollback can release tail pages cheaply;
- no giant contiguous reallocation as context grows;
- multiple sessions can coexist without worst-case preallocation.

Aesir already has a page-table structure to build on. The next step is integration into real Qwen3 sessions with unchanged logit correctness.

---

# 7. Prefix sharing

Agent systems often send the same large prefix:

```text
system prompt
+ persona
+ tool schemas
+ policy text
```

If ten sessions share 5,000 tokens of prefix, copying ten complete KV prefixes wastes memory and prefill compute.

Aesir should support immutable reference-counted prefix pages.

A cache key must include:

- exact model file SHA;
- model/quant interpretation;
- exact token IDs;
- RoPE/YaRN settings;
- architecture/kernel semantics that affect KV;
- template revision.

Never reuse KV across different models simply because token IDs happen to match.

---

# 8. Prompt cache versus KV persistence

Two related but distinct features:

### In-memory prefix KV
Fastest reuse within a running service.

### Persistent prompt cache
Serialized cache across process restarts.

Persistent KV is much harder because file format must encode:

- model identity;
- architecture/version;
- dtype/quant format;
- context position;
- RoPE policy;
- endianness/layout;
- integrity checks.

Aesir should prioritize in-memory prefix sharing first.

---

# 9. KV precision policy

Potential modes:

```text
f16  = correctness/reference baseline
int8 = default memory-saving candidate
mixed = early/recent tokens or selected layers in higher precision
```

Aesir should test whether some layers are more sensitive to KV quantization. If so, a mixed layer policy could retain most memory savings with improved quality.

Experiments:

- quantize all layers;
- first/last N layers f16;
- attention layers selected by measured divergence;
- K and V different precision;
- recent token window f16, older pages int8.

Do not add complexity unless measurement proves it helps.

---

# 10. Quantization scale granularity

J-088's current component/accounting uses per-row scales. Alternatives worth benchmarking include:

- per-head scale;
- per-channel scale;
- blockwise scale;
- asymmetric representations if hardware supports them.

Tradeoff:

```text
finer scales -> better fidelity, more metadata and work
coarser scales -> cheaper, potentially more error
```

The right choice may differ between CPU and GPU kernels.

---

# 11. Context eviction and sliding strategies

Dense Qwen3 does not become a sliding-window model just because an application wants bounded memory. Arbitrarily discarding KV changes model behavior.

Safe application-level alternatives:

- summarize older conversation;
- start a new context with preserved facts;
- RAG important old material back in;
- explicit context-shift policy with quality tests;
- maintain pinned system/tool prefix plus recent window.

Aesir should label any context-shift/eviction mode as a semantic policy, not transparent exact inference.

---

# 12. Speculative rollback

Speculative decoding needs cache checkpoints.

Efficient page-based approach:

```text
checkpoint = logical length + tail-page fill
propose tokens
verify
accept prefix
rollback rejected tail positions without copying whole cache
```

A page allocator makes rollback and branch-like draft exploration much cheaper than rebuilding a monolithic contiguous cache.

---

# 13. Multi-session server memory planner

Aesir should estimate memory before admitting a request.

For each session:

```text
resident weights shareable globally
+ private/shared KV pages
+ activations/scratch
+ sampler state
+ draft-model state if speculative
```

Admission control can choose:

- lower KV precision;
- lower context cap;
- smaller model;
- queue request;
- evict reusable prompt cache;
- move cache pages to a slower tier only if supported and measured.

This is preferable to allowing the OS/GPU driver to discover overcommit via catastrophic swapping.

---

# 14. CPU/GPU cache placement

When the target executes on GPU, keeping KV on GPU generally avoids per-token transfers. If memory pressure forces spill:

- spill old pages in large contiguous chunks;
- prefetch before attention needs them;
- use pinned host memory if transfer path benefits;
- avoid token-by-token PCIe reads.

For long-context attention, host-spilled KV can erase the speed advantage of GPU compute. Aesir must measure full attention latency, not merely available capacity.

---

# 15. Long-context prefill

Large context is not only a storage problem. Prefill must process tens of thousands of tokens.

Needed features:

- chunked prefill;
- bounded scratch buffers;
- optimized causal attention;
- no O(n^2) temporary materialization;
- progress/cancellation support;
- prompt-prefix reuse;
- memory planner that accounts for KV growth during prefill.

For 128K, first-token latency can dominate the user experience even if decode is fast.

---

# 16. Required validation

For every KV format:

1. exact append/index behavior;
2. no layer/head misalignment;
3. reset semantics;
4. rollback semantics;
5. cache capacity boundary;
6. f16 reference logits;
7. int8 token divergence at increasing context;
8. long-context retrieval accuracy;
9. repeated multi-turn chat;
10. speculative accept/reject rollback;
11. paged vs contiguous equivalence.

---

# 17. Recommended implementation order

**P0:** integrate int8 KV into a full Qwen3 session behind explicit flag.  
**P1:** integrate paged allocation into production Qwen3.  
**P2:** lazy page growth and hard memory accounting.  
**P3:** prefix-page sharing.  
**P4:** speculative rollback on page checkpoints.  
**P5:** mixed-precision experiments.  
**P6:** optional persistent prompt cache only after in-memory correctness is mature.

---

# 18. Sources

- Aesir `docs/janas/J087_KV_PRECISION_CENSUS.md`
- Aesir `docs/janas/J088_8BIT_KV.md`
- Aesir `aesir_engine/core/kv_account.mojo`
- Qwen model configs listed in `01_SOURCE_LEDGER_AND_METHODOLOGY.md`
