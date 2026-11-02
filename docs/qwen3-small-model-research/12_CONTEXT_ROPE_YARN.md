# 12 - Context, RoPE, and YaRN Strategy

**Research snapshot:** 2026-11-02

Context length is not simply a number in a config file. It changes positional encoding, KV memory, prefill cost, attention traffic, and often quality. Aesir should treat context as a policy bundle.

---

# 1. Native context targets

Operational interpretation of current Qwen documentation:

| Model | Native target | Documented extension |
|---|---:|---:|
| Qwen3-0.6B | 32,768 | no 128K claim should be assumed |
| Qwen3-1.7B | 32,768 | no 128K claim should be assumed |
| Qwen3-4B | 32,768 | YaRN validated to 131,072 |
| Qwen3-8B | 32,768 | YaRN validated to 131,072 |

The Qwen launch table uses 128K shorthand for 8B, while current model cards provide the more useful native-versus-YaRN distinction.

---

# 2. RoPE basics relevant to Aesir

All four configs use:

```text
rope_theta = 1,000,000
head_dim = 128
```

Aesir already corrected Qwen3 to the appropriate split-half/NeoX-style rotary behavior. That should remain covered by regression tests because a wrong RoPE layout can still produce fluent text while diverging materially from the model.

Tests should include positions:

```text
0, 1, 2, 127, 1024, 8191, 32767
```

and extended positions when YaRN is enabled.

---

# 3. YaRN should be demand-activated

Qwen's 4B/8B guidance warns that static YaRN can hurt performance/quality on shorter sequences. Therefore:

```text
if requested_context <= native_context:
    use native positional policy
else:
    enable YaRN with minimum sufficient factor
```

Qwen's example uses factor 4 to reach ~131K and notes that a smaller factor, such as 2 for ~65K needs, can be preferable when the maximum extension is unnecessary.

---

# 4. Do not conflate logical maximum and allocated cache

A session can be *capable* of 128K without allocating 128K KV at startup.

Desired Aesir design:

```text
logical max context = 131072
physical KV pages allocated = only what has been used
```

This requires paged/lazy KV rather than a monolithic maximum-size allocation.

---

# 5. Memory consequence

For 4B/8B:

```text
32K f16 KV  = 4.5 GiB
64K f16 KV  = 9.0 GiB
128K f16 KV = 18.0 GiB
```

Even int8 KV remains ~9.28 GiB at 128K under Aesir's current accounting shape.

Thus a 128K context option should trigger a memory feasibility check before generation.

---

# 6. Prefill consequence

Long context also makes first-token latency huge if the entire prefix must be recomputed.

Aesir needs:

- prefix cache;
- chunked prefill;
- efficient tiled attention;
- cancellation/progress reporting;
- reuse of stable system/tool prefix;
- optional document preprocessing/summarization.

For many applications, intelligent retrieval is better than feeding 100K irrelevant tokens.

---

# 7. Dynamic factor selection

Possible policy for 4B/8B:

```text
<= 32768: native
32769..65536: factor approximately 2
65537..131072: factor approximately 4
```

The exact mapping should follow the implementation's YaRN formula and Qwen-compatible parameters rather than this conceptual pseudocode.

Aesir should expose the chosen factor in telemetry.

---

# 8. Context-quality validation

Long-context support should be tested with more than 'model generated something.'

Required tasks:

- needle retrieval at multiple positions;
- multiple needles;
- distractor-heavy retrieval;
- long document question answering;
- codebase cross-reference;
- chronology/order tasks;
- instruction at beginning versus end;
- multilingual long context;
- tool schema at beginning, call near end.

Measure accuracy at:

```text
8K, 16K, 32K, 48K, 64K, 96K, 128K
```

for 4B/8B.

---

# 9. Short-context regression test

Because YaRN can change short-text behavior, run the same short benchmark under:

```text
native
factor 2
factor 4
```

If factor 4 hurts ordinary tasks, that is direct evidence for dynamic activation.

---

# 10. Context budgeting for agents

Agent systems often waste context on verbose tool schemas and old transcripts.

Aesir/application policy can reduce this through:

- compact tool descriptions;
- stable prefix cache;
- exclude old thinking content;
- summarize completed tool results;
- keep only relevant retrieved chunks;
- pin critical facts separately;
- truncate redundant logs.

More context is not automatically more intelligence.

---

# 11. Thinking-token interaction

Thinking mode consumes output tokens. A request near the context limit must leave enough room for generation.

Admission logic:

```text
input_tokens + reserved_output_tokens <= logical_context_limit
```

If thinking is enabled, output reservation may need to be larger than for non-thinking chat.

Aesir should never discover the context limit halfway through a reasoning answer if it could predict the limit before generation.

---

# 12. Current Aesir host cap

The filed J-087 census records a generic host runtime cap near 16,000 tokens in that implementation state. Therefore Aesir should not advertise full 32K/128K generic-host support simply from model metadata until runtime/session integration is proven.

Roadmap to remove the practical cap:

1. production paged KV;
2. int8 KV integration;
3. lazy growth;
4. 32K acceptance test;
5. YaRN implementation;
6. 64K/128K acceptance for 4B/8B;
7. memory admission planner.

---

# 13. RoPE cache optimization

For repeated positions, precomputing sin/cos tables can reduce per-token math, but tables should not become giant unnecessary allocations.

Options:

- precompute to native context;
- lazily extend in chunks;
- compute on the fly for rare extreme positions;
- store in sufficient precision to avoid drift.

Benchmark memory versus speed. On 0.6B, RoPE overhead may be more visible proportionally than on 8B.

---

# 14. YaRN implementation testing

Aesir needs independent reference vectors for:

- frequency scaling;
- correction range;
- position-dependent transform;
- factor 2;
- factor 4;
- boundary around native context.

Then compare full-model logits against a trusted implementation using exact raw token IDs.

---

# 15. Context presets

Suggested user/runtime presets:

### `short`
4K-8K cap, low memory, fastest admission.

### `standard`
16K or native practical cap, depending on backend.

### `native-max`
32K for all four when backend proves it.

### `long-64k`
4B/8B only, YaRN + compact KV.

### `long-128k`
4B/8B only, explicit memory check, YaRN + compact/paged KV.

Preset names should never hide the actual token cap shown in telemetry.

---

# 16. Sources

- https://huggingface.co/Qwen/Qwen3-4B
- https://huggingface.co/Qwen/Qwen3-8B
- https://qwenlm.github.io/blog/qwen3/
- Aesir `docs/janas/J087_KV_PRECISION_CENSUS.md`
- Aesir Qwen3 RoPE model-wave evidence
