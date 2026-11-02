# 07 - Quantization and Weight-Memory Strategy

**Research snapshot:** 2026-11-02

Quantization is the highest-leverage lever for local dense Qwen3 inference, but it must be treated as an end-to-end systems problem. A smaller file can be slower if its decoder is inefficient, and a very low-bit file can destroy the exact tool/reasoning behavior that made the model useful.

---

# 1. The three quantization goals

Aesir should score every quant on three independent axes:

```text
capacity: does it fit?
throughput: is the kernel actually faster?
quality: does the model retain the behavior we need?
```

A quant is not 'better' merely because its bits-per-weight number is lower.

---

# 2. Why Qwen's own speed data matters

Qwen's official H20 speed benchmark is a clean demonstration of kernel dependence.

In SGLang, FP8 and/or AWQ INT4 often outperform BF16 for 4B/8B. In Hugging Face Transformers, FP8 in the tested environment is frequently *slower* despite using less memory. Qwen explicitly notes that the Transformers FP8 path needs optimization.

Aesir lesson:

> Build the kernel first, then choose the default quant from measurements. Do not choose the quant first and assume the runtime will make it fast.

Source: https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/speed_benchmark.md

---

# 3. Existing Aesir quant footing

The current repository already has important advantages:

- fast GEMM paths for GGML K-quant kinds across Q2_K, Q3_K, Q4_K, Q5_K, Q6_K;
- rebuilt Q8_0 path with a recorded 2.88x improvement in a specific Qwen2.5-Coder probe over the prior Aesir implementation;
- IQ decoder support including several IQ1/IQ2/IQ3 forms;
- corrected IQ embedding handling;
- known-value decoder fixtures.

This means the small-Qwen3 campaign should focus not merely on 'supporting formats' but on **proving which format wins for each model and workload**.

---

# 4. Approximate GGUF weight-size ladder

Representative third-party GGUF sizes, useful only as scale examples:

| Quant | 0.6B | 1.7B | 4B | 8B |
|---|---:|---:|---:|---:|
| Q2_K | ~0.35 GB | ~0.88 GB | ~1.67 GB | ~3.28 GB |
| Q3_K_M | ~0.41 GB | ~1.07 GB | ~2.08 GB | ~4.12 GB |
| Q4_K_M | ~0.48 GB | ~1.28 GB | ~2.50 GB | ~5.03 GB |
| Q5_K_M | ~0.55 GB | ~1.47 GB | ~2.89 GB | ~5.85 GB |
| Q6_K | ~0.62 GB | varies | ~3.31 GB | ~6.73 GB |
| Q8_0 | ~0.80 GB | varies | ~4.28 GB | ~8.71 GB |

Actual files vary by producer and metadata. Aesir test records must pin the exact SHA256.

---

# 5. Suggested default candidates

These are starting hypotheses, not project claims.

| Model | Balanced candidate | Quality candidate | Constrained candidate |
|---|---|---|---|
| 0.6B | Q4_K_M / Q5_K_M | Q6_K | Q3_K_M |
| 1.7B | Q4_K_M | Q5_K_M / Q6_K | Q3_K_M |
| 4B | Q4_K_M | Q5_K_M / Q6_K | Q3_K_M |
| 8B | Q4_K_M | Q5_K_M / Q6_K | Q3_K_M |

Why 0.6B may deserve *more* bits than expected: once the whole model is under a gigabyte, another 100-200 MB saving can be less valuable than preserving instruction/tool reliability.

---

# 6. Mixed-precision tensor importance

If Aesir's model packer eventually supports tensor-specific quantization, do not distribute error uniformly.

Candidates for higher precision:

- token embedding;
- LM output head;
- Q/K normalization weights;
- RMSNorm weights;
- first/last layers in experiments;
- tensors empirically identified as high sensitivity by an importance matrix.

Bulk compression can focus on large MLP and attention projection matrices.

For 0.6B/1.7B/4B, embedding and LM head are tied, making that shared matrix doubly important.

For 8B, the untied output head can receive a different precision policy from the input embedding.

---

# 7. Fused quantized execution

The bad path:

```text
quantized layer
 -> allocate float buffer
 -> dequantize entire matrix
 -> run generic GEMM/GEMV
 -> free/reuse large buffer
```

The desired decode path:

```text
read quant block
 -> decode tiny block in registers/vector lanes
 -> immediately accumulate dot product
 -> discard decoded block
```

Benefits:

- less memory traffic;
- no huge temporary matrix;
- better cache behavior;
- avoids repeated full-layer expansion;
- lets compressed representation remain the bandwidth representation.

For prefill, tile-level dequant + GEMM may be preferable because several tokens reuse the same weight tile.

---

# 8. Decode versus prefill quant kernels

Aesir should stop treating 'quantized matmul' as one primitive.

### Decode

Typical batch=1 or small batch:

- matrix-vector / skinny GEMM;
- weight bandwidth dominant;
- tiny latency critical;
- register pressure matters;
- aggressive fusion valuable.

### Prefill

Many prompt tokens:

- GEMM-like;
- weight tile reuse across tokens;
- tensor cores / larger SIMD tiles valuable;
- dequant overhead amortized;
- chunk size becomes a tuning variable.

A quant may be excellent for decode but mediocre for prefill, or vice versa.

---

# 9. Quant metadata layout

Aesir should pack runtime metadata for sequential access:

```text
block scales
zero/secondary scales where format requires
quant payload
```

Avoid pointer-heavy per-block structures. The CPU/GPU kernel should be able to stream large contiguous ranges.

Important measurements:

- bytes fetched per effective weight;
- scale/cache hit behavior;
- alignment;
- vector load width;
- branch count per decoded block;
- conversion instruction count.

---

# 10. Q8_0 is not 'no quantization'

Q8_0 still uses block quantization and can be useful as:

- a high-quality GGUF reference;
- a correctness step between BF16/F16 and lower-bit K-quants;
- a useful format on hardware with strong int8 execution.

But on a bandwidth-limited 8B batch-1 decode, Q8 may move nearly twice the weight bytes of a Q4-class file. Aesir should never promote Q8 as the universal 'fast' choice just because its decoding math is simpler.

---

# 11. IQ formats

Aesir's IQ work is especially interesting for memory-constrained devices, but ultra-low-bit success must be judged by behavior, not whether prose remains grammatical.

Required IQ quality tests:

- exact tool selection;
- JSON/schema validity;
- code unit tests;
- math correctness;
- multilingual prompts;
- repetition rate;
- long-context retrieval;
- instruction hierarchy;
- tokenizer/template special-token handling;
- thinking-mode stability.

For a tiny 0.6B model, an IQ2 file may cross the line where capability damage outweighs its already-small memory saving. For 8B, IQ3 may retain more useful capability because the unquantized model starts with more redundancy. Only measurement can decide.

---

# 12. Quant-aware model routing

Aesir can expose multiple installed quants of the same model and route requests based on quality/latency goals.

Example:

```text
qwen3-8b-fast    -> Q4_K_M
qwen3-8b-quality -> Q6_K
qwen3-8b-memory  -> Q3_K_M
```

The engine should share tokenizer metadata and, where safe, other immutable structures between profiles.

---

# 13. Quantization and speculative decoding

Drafter quantization affects target acceptance. A very compressed drafter may be individually faster but generate worse proposals and reduce total speculative speedup.

Therefore speculative benchmark dimensions must include:

```text
drafter size
drafter quant
target quant
draft length k
acceptance rate
net wall time
```

It is entirely possible for 1.7B Q4 to beat 0.6B Q2 as a drafter because accepted-token yield matters more than drafter tokens/s alone.

---

# 14. Quality gates

Every proposed default quant should pass a compact but diverse Aesir suite:

- 200 ordinary instructions;
- 100 tool calls with exact schema scoring;
- 100 coding tasks with executable tests;
- 100 reasoning/math tasks;
- 50 multilingual tasks;
- long-context retrieval at several lengths;
- repetition stress tests;
- deterministic teacher-forcing/logit-divergence comparison against higher precision.

Store results by exact file hash.

---

# 15. Performance gates

Measure at minimum:

```text
model load time
peak RSS / VRAM
TTFT
prefill tok/s
decode tok/s at batch 1
throughput at concurrency 2/4/8
energy/token if available
```

Run at 128, 2K, 8K, and near-native-max context so attention/KV interactions appear.

---

# 16. Recommended Aesir feature work

1. tensor-importance metadata in loader/runtime;
2. mixed-quant model packing experiments;
3. dedicated prefill and decode kernels per major quant family;
4. auto-benchmark at first load;
5. quant quality database keyed by file SHA;
6. expose quant/kernel choice in performance telemetry;
7. use correctness fallbacks when a specialized kernel is unavailable;
8. never silently decode an unknown quant as another format.

The last point echoes a real Aesir lesson from the IQ embedding defect: fail closed rather than return plausible-looking wrong output.

---

# 17. Sources

- https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/speed_benchmark.md
- https://huggingface.co/Qwen/Qwen3-0.6B
- https://huggingface.co/Qwen/Qwen3-1.7B
- https://huggingface.co/Qwen/Qwen3-4B
- https://huggingface.co/Qwen/Qwen3-8B
- Aesir README/model-wave evidence
- Aesir IQ decoder and embedding regression work
