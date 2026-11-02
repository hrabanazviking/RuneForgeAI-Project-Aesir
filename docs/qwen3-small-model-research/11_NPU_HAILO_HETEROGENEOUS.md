# 11 - NPU, Hailo, and Heterogeneous Placement Strategy

**Research snapshot:** 2026-11-02

The four small dense Qwen3 models are particularly interesting for heterogeneous execution because they are regular, relatively compact, and useful as persistent worker/draft models. This document separates what Aesir has already physically proven from future Qwen3 accelerator work.

---

# 1. Current Aesir truth boundary

Aesir's repository records two distinct Hailo roads:

1. **Verified compiled-model route:** real Hailo-10H execution has been physically proven with a compatible compiled Qwen2.5-1.5B-Instruct model, including generation and session behavior.
2. **Aesir-owned source-model compilation route:** ordinary GGUF/Safetensors -> Aesir compiler/program generation -> broad Hailo-only execution remains incomplete and was parked by project direction, with prior compiler/IR/transport work preserved.

Therefore this document does not claim Qwen3 already runs natively through the unfinished route. It identifies the best next targets when that work resumes.

---

# 2. Best Qwen3 accelerator targets

## Qwen3-0.6B

Highest-priority experimental target:

- smallest weight footprint;
- regular 28-layer architecture;
- good always-on router/drafter role;
- low bandwidth requirement;
- easiest place to prove QK-Norm + Qwen3 RoPE + SwiGLU + GQA end to end.

## Qwen3-1.7B

Highest-value worker target:

- close to the scale of Aesir's already proven 1.5B-class compiled route;
- much stronger than 0.6B for reasoning/agent tasks;
- same KV geometry as 0.6B;
- plausible always-resident personal-agent worker.

## Qwen3-4B / 8B

Later targets or split-placement targets where accelerator memory/bandwidth makes sense.

---

# 3. Qwen3-specific operator checklist

An accelerator backend needs correct support for:

```text
embedding lookup
RMSNorm
Q/K/V projections
QK-Norm
split-half/NeoX RoPE
GQA attention
SwiGLU gate/up/down
residual additions
final RMSNorm
LM head
KV append/read
```

The tokenizer/chat template can remain host-side, but the token IDs entering the graph must match Qwen's template exactly.

---

# 4. Do not split every layer across devices

A naive heterogeneous design can be slower than CPU-only because it transfers hidden states repeatedly.

Bad:

```text
CPU norm -> NPU projection -> CPU RoPE -> NPU MLP -> CPU attention ...
```

Better:

- whole block on one device;
- contiguous block groups on one device;
- whole prefill pass on one device and decode on another if measured useful;
- whole drafter model on one device, target on another.

Minimize synchronization boundaries.

---

# 5. Phase-based placement

Prefill and decode stress hardware differently.

Potential policies to benchmark:

```text
NPU prefill -> GPU/CPU decode
GPU prefill -> NPU decode
CPU prefill -> NPU decode
single-device full session
```

No policy should be selected without end-to-end measurements including transfer and synchronization.

---

# 6. Drafter-target device separation

Speculative decoding creates a compelling heterogeneous pattern:

```text
0.6B or 1.7B drafter -> NPU/CPU
4B or 8B target     -> GPU
```

Potential advantage:

- drafter compute does not steal target GPU cycles;
- both devices can work in a pipeline;
- small worker remains always resident;
- target GPU memory is reserved for the large model/KV.

Potential failure:

- CPU/NPU and GPU compete for unified memory bandwidth;
- synchronization erases gains;
- draft acceptance too low.

Measure, do not assume.

---

# 7. Quantization compatibility

Accelerator-friendly quantization may differ from Aesir's CPU GGUF formats.

A clean architecture should separate:

```text
source quant/file format
        -> Aesir logical tensor representation
        -> backend lowering/packing
        -> accelerator-native representation
```

This prevents the entire engine from being coupled to one accelerator's packed layout.

Validation must show that packing preserves tensor semantics.

---

# 8. Compilation cache

If an accelerator needs compiled graphs/programs, cache them by:

- exact model SHA;
- quant/packing configuration;
- accelerator model/firmware/runtime;
- context/batch constraints if baked into graph;
- Aesir compiler version.

Never reuse compiled artifacts across incompatible firmware or model revisions merely because filenames match.

---

# 9. Static versus dynamic shapes

LLM inference contains dynamic state:

- current position;
- context length;
- batch size;
- page-table addresses;
- generation length.

Accelerators that prefer static graphs may need buckets:

```text
context <= 512
<= 2K
<= 8K
<= 32K
```

or fixed maximum buffers with logical length parameters.

Aesir should avoid recompiling every token.

---

# 10. KV placement

Options:

### KV on accelerator
Fastest if capacity allows and attention runs there.

### KV in host memory
Can save accelerator RAM but may make every token transfer-bound.

### Tiered/paged KV
Hot/recent pages on accelerator, cold pages on host, only if long-context access patterns and prefetch make this worthwhile.

For dense full attention, every historical token can matter, so host spill is challenging. Measure real attention traffic.

---

# 11. NPU-friendly worker design

Aesir could formalize an `edge_worker` service:

```text
preferred model: Qwen3-1.7B
fallback: Qwen3-0.6B
reasoning: auto/bounded
context: 4K-16K default
KV: compact
functions: routing, tools, RAG query planning, summaries
```

This service could run independently of the main 4B/8B assistant.

---

# 12. Placement cost model

For each candidate operation/device, estimate:

```text
compute_time
+ input_transfer
+ output_transfer
+ synchronization
+ cache migration
+ queue delay
```

The fastest isolated kernel is not necessarily the fastest placement.

Aesir should learn placement from measured profiles rather than fixed folklore such as 'attention always GPU' or 'NPU always efficient.'

---

# 13. Energy efficiency

NPUs are especially attractive for persistent background agents because energy/token can matter more than peak tokens/s.

Benchmark:

- joules/token;
- idle power while model resident;
- wake latency;
- tokens/s/W;
- total task energy including transfers.

A slower NPU can be the better worker if it lets the GPU remain asleep.

---

# 14. Failure and fallback

Aesir should fail gracefully when accelerator support is incomplete:

```text
unsupported op -> reject accelerator plan before generation
not -> silently execute wrong kernel
```

Fallback order can be:

```text
native accelerator
GPU
optimized CPU
```

but should respect user policy and model residency.

---

# 15. Recommended Hailo/Qwen3 resume plan

1. admit Qwen3-0.6B tensor/config geometry;
2. prove tokenizer/chat token parity host-side;
3. lower QK-Norm;
4. prove split-half RoPE;
5. lower one transformer block;
6. compare block output against CPU reference;
7. scale to full 0.6B graph;
8. prove short greedy trajectory;
9. prove multi-turn/reset;
10. repeat on 1.7B;
11. only then explore 4B/8B split or full placement.

This produces a clear staircase rather than attempting every model at once.

---

# 16. Experiments

### E-NPU-01
0.6B CPU vs GPU vs NPU full-task latency and energy.

### E-NPU-02
1.7B always-resident worker idle/wake behavior.

### E-NPU-03
NPU 1.7B drafter + GPU 8B target speculative decoding.

### E-NPU-04
Prefill/decode phase split, including transfer cost.

### E-NPU-05
KV residency and spill cost at 2K/8K/16K.

---

# 17. Aesir references

- `docs/YRSA_HAILO10H_PROJECT_AESIR_FINISH_LINE_CODEX.md`
- `docs/AESIR_MASSIVE_ROADMAP_2026-10-28.md`
- README Hailo truth-boundary section
- existing NPU planning/accounting work under `docs/janas/`
