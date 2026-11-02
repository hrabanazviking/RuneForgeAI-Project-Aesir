# 16 - Prefill, Decode, Batching, Prefix Cache, and Scheduling

**Research snapshot:** 2026-11-02

Aesir should treat LLM inference as a scheduler problem in addition to a kernel problem. The same Qwen3 model can behave very differently under one interactive session, several agent workers, long prompt ingestion, or speculative verification.

---

# 1. Four execution bands

A useful Aesir taxonomy:

```text
PREFILL       many input tokens
DRAFT_CHECK   ~2-16 verification tokens
DECODE        one token/sequence
BATCH_DECODE  one token across many sequences
```

Each wants different kernels and scheduling.

---

# 2. Prefill

Goals:

- maximize matrix reuse;
- use large GEMM tiles;
- chunk long prompts;
- avoid giant attention temporaries;
- write KV efficiently;
- reuse cached prefixes;
- preserve responsive cancellation.

For long prompts, prefill can dominate total latency even when decode is extremely fast.

---

# 3. Chunked prefill

Instead of processing 32K/128K input as one monolithic allocation, process bounded chunks while maintaining exact causal state.

Tune chunk sizes such as:

```text
128, 256, 512, 1024, 2048, 4096
```

Tradeoffs:

- larger chunks improve GEMM efficiency;
- smaller chunks reduce scratch memory and scheduler blocking;
- page allocation grows incrementally;
- multi-request serving can interleave work.

---

# 4. Decode

Interactive decode prioritizes latency.

Goals:

- minimal launch/synchronization;
- low-bit bandwidth-efficient weight kernels;
- in-place/reused scratch;
- efficient attention over existing KV;
- token sampling with no unnecessary host sync.

For 0.6B, dispatch can be a first-order cost. For 8B, weight bandwidth dominates more often.

---

# 5. Continuous batching

A server can batch one next-token step from multiple active sequences.

Benefits:

- one weight tile serves several sequences;
- GPU/CPU SIMD utilization rises;
- tiny 0.6B/1.7B workers stop underutilizing accelerators.

Costs:

- queueing delay;
- variable sequence lengths;
- KV indirection;
- one slow session can complicate scheduling.

Use a tiny configurable batching window for interactive mode and a larger one for throughput mode.

---

# 6. Paged KV enables flexible batching

With monolithic contiguous caches, variable-length batching is awkward. Paged KV allows each sequence to own a logical page table while kernels gather the pages needed for the current step.

This enables:

- dynamic batch membership;
- sequences finishing independently;
- prefix-page sharing;
- no giant fixed per-session buffer.

---

# 7. Prefix caching

The highest-value prefix cache targets are stable, expensive prefixes:

- system prompts;
- large personas;
- tool schemas;
- coding project instructions;
- RAG boilerplate.

Cache exact tokenized prefix, not raw string.

Key:

```text
model SHA
quant/runtime semantic version
token ID hash
RoPE/YaRN policy
chat template version
KV dtype/layout
```

---

# 8. Radix/prefix tree cache

A server handling many related prompts can store cached prefixes in a token radix tree.

Example:

```text
system + tools
  + user A...
  + user B...
  + user C...
```

Shared root KV pages are reference-counted. Divergent suffixes allocate private pages.

This can greatly reduce memory and prefill for agent fleets.

---

# 9. Cache eviction

Prefix cache is optional performance state, so evict it before active session KV.

Potential eviction score:

```text
bytes * age / estimated_recompute_cost
```

Or simpler LRU initially.

Track:

- hit rate;
- tokens saved;
- milliseconds saved;
- bytes occupied.

---

# 10. Prompt deduplication

Before prefill, detect longest cached exact token prefix. Only run uncached suffix.

Do not use fuzzy text matching for KV reuse. One token difference changes all later hidden states.

---

# 11. Session scheduling by model size

Possible queues:

```text
0.6B worker queue
1.7B worker queue
4B assistant queue
8B quality queue
```

Each queue can have different batching latency targets.

Example:

- 0.6B background tasks: throughput batching;
- 8B chat: latency-first;
- 1.7B drafter: tightly coupled to target scheduler.

---

# 12. Model residency scheduler

If memory cannot hold every model simultaneously, choose which stay resident based on:

- recent request frequency;
- reload cost;
- active sessions;
- role importance;
- memory footprint;
- accelerator availability.

Likely policy on a roomy machine:

```text
keep 0.6B or 1.7B always resident
load 4B/8B as main models
```

On 128GB unified-memory systems, all four may fit, making role routing nearly free from reload latency.

---

# 13. Fairness

Long-prefill requests should not block all short decode requests.

Scheduler should interleave chunks:

```text
long prefill chunk
interactive decode step(s)
next prefill chunk
```

This preserves responsiveness while still making progress.

---

# 14. Priority classes

Possible request priorities:

```text
interactive
agent-critical
background
benchmark
```

Priority should affect queueing, not model correctness.

Background 0.6B jobs can yield to an interactive 8B chat without discarding their KV/session.

---

# 15. Admission control

Before accepting a session, estimate:

```text
model residency cost
expected KV growth
context cap
batch scratch
speculative drafter cost
```

If insufficient memory:

- reduce context if caller allows;
- use int8 KV;
- choose smaller model;
- queue until memory frees;
- unload an idle model/prefix cache.

Avoid OS/GPU OOM as the scheduling mechanism.

---

# 16. Decode batching and latency SLO

A configurable microbatch timer might wait a few hundred microseconds or low milliseconds for other requests, but the correct number is hardware-specific.

Autotune:

- zero wait;
- short wait;
- throughput mode.

Measure p50 and p95 token latency, not only aggregate tok/s.

---

# 17. Prompt-cache effect on TTFT

Benchmark same request prefix:

```text
cold
warm tokenizer only
warm model pages
warm exact KV prefix
```

This separates model-load/page-cache effects from true prefix reuse.

---

# 18. Speculative scheduling

Drafter and target need coordinated slots.

Scheduler should prevent:

- drafter running far ahead of target;
- two sessions starving target verification;
- GPU target waiting idle while CPU drafter is delayed by unrelated background jobs.

Drafter work can receive deadline/priority derived from target request.

---

# 19. Metrics

Expose:

```text
queue time
model-load time
prefix-cache hit tokens
new prefill tokens
TTFT
per-token latency
batch size over time
KV allocated bytes
KV shared bytes
model resident bytes
```

Without these, users cannot tell whether a slow response is compute, queueing, cache miss, or long prefill.

---

# 20. Implementation order

1. explicit prefill/decode phase dispatch;
2. chunked prefill;
3. paged KV production integration;
4. continuous batching;
5. exact prefix cache;
6. prefix page sharing;
7. memory admission control;
8. model residency scheduler;
9. workload priority/fairness;
10. speculative scheduling integration.
