# 02 - Shared Qwen3 Architecture: What Aesir Should Exploit

**Research snapshot:** 2026-11-02  
**Scope:** dense Qwen3 0.6B / 1.7B / 4B / 8B

The four models are not four unrelated architectures. They are a highly regular dense family, which is excellent news for Aesir: one correct parameterized execution path can cover them while still allowing model-size-specific kernel selection.

---

# 1. Shared transformer skeleton

The dense Qwen3 family uses the familiar decoder-only transformer shape:

```text
token IDs
  -> token embedding
  -> N transformer blocks
       -> RMSNorm
       -> Q/K/V projection
       -> QK-Norm
       -> RoPE
       -> grouped-query causal attention
       -> output projection
       -> residual
       -> RMSNorm
       -> SwiGLU MLP
       -> residual
  -> final RMSNorm
  -> LM head
  -> logits
```

The practical Aesir consequence is that there should be one `qwen3_dense` architecture implementation parameterized by file-derived geometry, not four copy-pasted model classes.

---

# 2. Exact geometry

| Field | 0.6B | 1.7B | 4B | 8B |
|---|---:|---:|---:|---:|
| Layers | 28 | 28 | 36 | 36 |
| Hidden size | 1024 | 2048 | 2560 | 4096 |
| FFN intermediate | 3072 | 6144 | 9728 | 12288 |
| Q heads | 16 | 16 | 32 | 32 |
| KV heads | 8 | 8 | 8 | 8 |
| Head dimension | 128 | 128 | 128 | 128 |
| KV width | 1024 | 1024 | 1024 | 1024 |
| RoPE theta | 1,000,000 | 1,000,000 | 1,000,000 | 1,000,000 |
| RMSNorm eps | 1e-6 | 1e-6 | 1e-6 | 1e-6 |
| QKV bias | no | no | no | no |
| Embedding tied to LM head | yes | yes | yes | no |
| Config tensor vocab | 151,936 | 151,936 | 151,936 | 151,936 |

Sources: official Qwen model configs and Qwen3 technical report.

The identical KV width across all four is particularly useful. Attention-cache row width stays constant; layer count is what changes KV bytes/token between the 28-layer and 36-layer groups.

---

# 3. Grouped-query attention

All four use 8 KV heads while Q-head count grows with model size.

This means:

```text
0.6B / 1.7B: each KV head serves 2 Q heads
4B / 8B:     each KV head serves 4 Q heads
```

Aesir should avoid physically expanding K/V into Q-head count. Broadcasting/reusing KV heads in the attention kernel preserves memory bandwidth and cache efficiency.

## Kernel implication

The 4B/8B attention kernel has more Q work per KV row than 0.6B/1.7B. This makes tile choices that are optimal for 16/8 heads potentially suboptimal for 32/8. Autotuning should therefore key on both `q_heads` and `kv_heads`, not merely hidden dimension.

---

# 4. QK-Norm

Qwen3 adds normalization of Q and K heads before RoPE/attention. This is architecturally important, not optional polish.

Aesir opportunities:

- fuse Q projection output handling + QK-Norm + RoPE when the backend permits;
- avoid materializing an extra normalized Q/K tensor if a fused kernel can normalize directly into the RoPE destination;
- maintain a scalar/reference path for correctness testing;
- preserve accumulation precision even when storage is lower precision.

QK-Norm is also a reason to be conservative when aggressively quantizing tiny, high-leverage normalization tensors. They are negligible in memory size and should usually stay high precision.

---

# 5. RoPE details

Aesir's model-wave work already discovered a real Qwen3 correctness issue: the family requires the appropriate split-half/NeoX-style rotary treatment rather than blindly reusing an incompatible layout.

Recommended architecture rule:

```text
RoPE behavior belongs to the model architecture profile,
not to a generic 'all RoPE is the same' helper assumption.
```

The rotary base is 1,000,000 for these models. Extended context on 4B/8B introduces YaRN policy, covered separately in `12_CONTEXT_ROPE_YARN.md`.

---

# 6. SwiGLU MLP

The block feed-forward path is effectively:

```text
gate = W_gate * x
up   = W_up   * x
ff   = SiLU(gate) * up
out  = W_down * ff
```

At batch-1 decode, these large matrix-vector operations dominate weight traffic. This makes the MLP a prime target for:

- low-bit weight storage;
- fused dequantization + dot products;
- persistent decoded tiles where memory allows;
- vectorized SiLU/multiply;
- avoiding temporary allocations;
- per-format kernels rather than generic dequant-to-f32 buffers.

At prefill, the same matrices become GEMM-like and can profit from much larger tiles and tensor-core-friendly packing.

Aesir should explicitly maintain separate decode and prefill strategies instead of forcing one GEMM kernel to serve both poorly.

---

# 7. RMSNorm

RMSNorm is cheap relative to MLP matrices, but on the 0.6B model many 'cheap' kernels can collectively become dispatch overhead.

Recommended fusion candidates:

- residual add + RMSNorm;
- RMSNorm + quantized matmul input preparation;
- final RMSNorm + LM-head input staging.

Do not sacrifice numerical correctness for a microscopic memory saving. Norm weights are tiny compared with model weights.

---

# 8. Embedding and output-head tying

0.6B, 1.7B, and 4B tie the input embedding and LM head. The 8B does not.

This affects both memory and quantization risk.

For tied models, one shared matrix influences:

1. how token IDs enter the hidden state;
2. how hidden states are projected back to vocabulary logits.

Therefore an over-aggressive quantization of the tied matrix can damage both ends of inference simultaneously. Mixed-quant formats should preferentially protect this matrix.

For 8B, embedding and output head are independent. This costs more weight memory but allows different quantization policies if Aesir's format/compiler supports them.

---

# 9. Vocabulary and LM-head cost

The embedding table is large for tiny models because the vocabulary is fixed across the family. This is why Qwen lists 0.6B as roughly 0.44B non-embedding parameters: the vocabulary matrix is a substantial fraction of the smallest checkpoint.

This leads to a counterintuitive optimization rule:

> On 0.6B, optimizing the embedding/output matrix can matter proportionally more than on larger models.

Potential Aesir work:

- efficient quantized row lookup for token embedding;
- keep embedding lookup zero-allocation;
- fused/optimized final projection;
- vocabulary pruning only as an experimental derivative model, never as transparent execution of the original checkpoint;
- top-k logit algorithms that avoid expensive full sorting after the LM head.

The full LM-head matvec is still required for exact next-token probabilities. Sampling can avoid sorting the whole vocabulary, but it cannot skip computing arbitrary logits unless an approximate method is explicitly chosen.

---

# 10. Tokenizer and chat control semantics

Qwen3 uses byte-level BPE and its chat template uses control tokens such as:

```text
<|im_start|>
<|im_end|>
```

Thinking models also use `<think>` / `</think>` semantics in generated content/template behavior.

Aesir must treat the tokenizer and chat template as part of correctness. A model can produce grammatical text while still being incorrectly prompted.

Required template tests:

- one-turn system + user;
- one-turn user only;
- multi-turn conversation;
- thinking enabled;
- thinking disabled;
- `/think` soft switch;
- `/no_think` soft switch;
- tool definitions;
- assistant tool call;
- tool result followed by assistant continuation.

Always compare exact token IDs against an official/reference tokenizer.

---

# 11. Thinking and non-thinking modes

Qwen3's post-training unifies reasoning and ordinary dialogue. This should be surfaced in Aesir's request model as a first-class runtime option rather than requiring users to hand-edit prompt strings.

Proposed API concept:

```text
reasoning_mode = auto | thinking | non_thinking
reasoning_budget = optional token budget
```

`auto` can route based on task classification, latency target, or application policy.

For agents, the distinction is especially valuable:

- simple tool routing: non-thinking;
- difficult planning or coding: thinking;
- deterministic extraction: usually non-thinking;
- hard verification: thinking.

The engine should report reasoning tokens separately when the protocol exposes them, allowing callers to measure the actual cost of reasoning.

---

# 12. Strong-to-weak distillation and why the small models matter

The technical report describes strong-to-weak distillation as part of the strategy for smaller Qwen3 models. This helps explain why 1.7B and 4B can be useful beyond their raw parameter count.

Aesir should not assume a monotonic 'small model is only a toy' role. Instead, benchmark each model on narrow tasks. A distilled 1.7B may be entirely sufficient for a router/tool-selection workload while consuming far less weight bandwidth than 8B.

---

# 13. Shared-kernel strategy

A clean Aesir backend should expose generic primitives parameterized by geometry:

```text
qwen3_embed()
qwen3_norm_qkv_rope()
qwen3_gqa_attention_prefill()
qwen3_gqa_attention_decode()
qwen3_swiglu_prefill()
qwen3_swiglu_decode()
qwen3_final_norm()
qwen3_lm_head()
```

Model profiles should provide:

```text
layers
hidden
ffn
q_heads
kv_heads
head_dim
vocab
rope_theta
tied_embeddings
native_context
extended_context_policy
```

Avoid size-specific source forks. Size-specific behavior should come from parameters and autotuned kernel plans.

---

# 14. Shape-specialization opportunities

Although source should stay generic, the four known shapes justify compiled specializations:

```text
hidden 1024 / ffn 3072
hidden 2048 / ffn 6144
hidden 2560 / ffn 9728
hidden 4096 / ffn 12288
```

Mojo can potentially exploit compile-time constants for:

- vector width;
- unrolling;
- shared-memory tile shapes;
- warp grouping;
- packed quant block decoding;
- reduction tree sizes.

Aesir can select a specialized kernel at runtime by model geometry while preserving one semantic implementation.

---

# 15. Memory-traffic mental model

For batch-1 decode, a useful first approximation is:

```text
per-token time ~= bytes of weights read / sustainable memory bandwidth
                 + attention/KV traffic
                 + launch/scheduling overhead
                 + unavoidable arithmetic
```

As model size rises, weight traffic dominates more strongly. As context length rises, KV/attention traffic grows. As model size falls, scheduling overhead becomes a larger percentage.

This is why there is no single 'fastest Qwen3 kernel configuration.' The bottleneck moves with model size, context length, batch size, quant, and hardware.

---

# 16. Correctness gates before performance tuning

For every model size, Aesir should prove:

1. tensor mapping matches config geometry;
2. tokenizer IDs match reference;
3. chat rendering matches reference;
4. QK-Norm placement matches reference;
5. split-half RoPE matches reference;
6. attention scaling and GQA grouping match;
7. tied/untied output head handling matches;
8. first-token logits agree within precision expectations;
9. teacher-forced multi-token logits stay aligned;
10. greedy token trajectory matches a reference for an exact raw-token prompt.

Only then should performance tuning begin. Fast wrong inference is just a very efficient hallucination generator.

---

# 17. Sources

- https://qwenlm.github.io/blog/qwen3/
- https://arxiv.org/abs/2505.09388
- https://huggingface.co/Qwen/Qwen3-0.6B/blob/main/config.json
- https://huggingface.co/Qwen/Qwen3-1.7B/blob/main/config.json
- https://huggingface.co/Qwen/Qwen3-4B/blob/main/config.json
- https://huggingface.co/Qwen/Qwen3-8B/blob/main/config.json
- https://github.com/QwenLM/Qwen3
