# 17 - Benchmark and Validation Matrix

**Research snapshot:** 2026-11-02

This document defines the evidence campaign needed to turn the research recommendations into Aesir claims. It deliberately combines correctness, quality, performance, memory, and agent behavior because optimizing only tokens/second can produce a faster but less useful engine.

---

# 1. Four benchmark layers

A complete Aesir Qwen3 campaign should have four layers:

```text
L0 tensor/operator correctness
L1 model/oracle correctness
L2 behavioral quality
L3 systems performance
```

A result cannot skip L0/L1 and become trusted because L3 looks fast.

---

# 2. L0: operator correctness

Test independent reference vectors for:

- RMSNorm;
- QK-Norm;
- split-half RoPE;
- YaRN transform;
- GQA head mapping;
- causal softmax;
- SwiGLU;
- every quant decoder;
- quantized embedding lookup;
- LM-head matvec;
- f16 KV append/read;
- int8 KV quant/dequant;
- paged KV logical/physical mapping;
- sampler primitives.

For quant decoders, keep known-value fixtures so compiler changes cannot silently alter bit interpretation.

---

# 3. L1: model correctness

For each model size:

1. pin exact model file SHA256;
2. render exact token IDs with reference tokenizer;
3. compare first-token logits;
4. teacher-force 64-256 tokens;
5. compare greedy raw-token trajectory;
6. run thinking and non-thinking chat templates;
7. run reset/multi-turn behavior;
8. run quant paths against a higher-precision reference.

Important Aesir lesson: compare raw token inputs. The repository already discovered a false Qwen3 defect caused by `llama-cli --single-turn` re-rendering a different prompt. Do not repeat that trap.

---

# 4. Model acceptance matrix

Create a canonical table in evidence:

| Model | BF16/F16 ref | Q8 | Q6 | Q5 | Q4 | Q3 | IQ selected | CPU | CUDA | NPU |
|---|---|---|---|---|---|---|---|---|---|---|
| 0.6B | | | | | | | | | | |
| 1.7B | | | | | | | | | | |
| 4B | | | | | | | | | | |
| 8B | | | | | | | | | | |

Statuses should be evidence-backed:

```text
PROVEN
PARTIAL
NOT TESTED
REFUSED
KNOWN BAD FILE
```

Avoid a vague checkmark that hides context/quant/backend limitations.

---

# 5. L2: behavioral suite

## General instruction following

- concise answer;
- multi-constraint request;
- formatting requirements;
- refusal to invent missing facts;
- multi-turn reference resolution.

## Reasoning/math

- arithmetic;
- algebra;
- logic;
- multi-step word problems;
- planning.

## Coding

- small function;
- bug repair;
- code explanation;
- repository-style patch task;
- unit-test execution where harness permits.

## Multilingual

Sample languages from Qwen3's broad training coverage, including mixed-language prompts.

## Repetition stress

Long generation, repeated patterns, quantized models, thinking mode.

---

# 6. Agent/tool suite

Score exact outcomes:

- correct tool name;
- valid JSON;
- required arguments;
- no extra execution;
- correct multi-step order;
- recovery after tool error;
- no tool trigger from thought/quoted text.

Report:

```text
tool selection accuracy
schema-valid rate
fully successful task rate
average repair turns
```

This suite is especially important for 0.6B/1.7B quant selection.

---

# 7. Long-context suite

For 0.6B/1.7B:

```text
2K, 8K, 16K, 32K
```

For 4B/8B once backend supports it:

```text
2K, 8K, 16K, 32K, 64K, 96K, 128K
```

Tasks:

- single needle;
- multi-needle;
- order/chronology;
- long-document QA;
- long code/reference task;
- tool schema at beginning, call at end.

Test native and YaRN modes separately.

---

# 8. KV precision suite

Compare f16 versus int8 KV:

- logit divergence at fixed tokens;
- greedy token trajectory;
- sampled task quality;
- long-context retrieval;
- repetition;
- tool-call exactness;
- memory actually allocated.

Do not declare int8 KV good based solely on short-context prose.

---

# 9. Performance workloads

## Interactive short

```text
prompt 128
output 256
batch 1
```

## Ordinary chat

```text
prompt 2K
output 512
```

## Long conversation

```text
prompt 8K / 16K / 32K
output 256
```

## Long-context extension

4B/8B only after YaRN:

```text
64K / 128K
output 128
```

## Throughput server

```text
concurrency 2 / 4 / 8 / 16
```

## Draft check

```text
2 / 4 / 8 / 16 verification tokens
```

---

# 10. Performance metrics

Always separate:

```text
model load time
queue time
prompt render/tokenize time
prefill time
TTFT
decode tok/s
inter-token latency p50/p95
total wall time
peak RSS
peak VRAM
KV bytes
energy/task or joules/token when available
```

A combined '(input+output)/time' score can obscure what users actually experience, so keep phase-specific metrics even when comparing with Qwen's official aggregate speed numbers.

---

# 11. Quant matrix

For each model:

```text
Q8_0
Q6_K
Q5_K_M
Q4_K_M
Q3_K_M
Q2_K
selected IQ1/IQ2/IQ3 formats Aesir supports
```

Not every ultra-low format needs every behavioral benchmark initially. Use a funnel:

1. correctness load/run;
2. small quality screen;
3. full suite for survivors.

---

# 12. CPU matrix

Record:

- instruction set;
- cores/threads;
- RAM channels/speed;
- NUMA;
- thread count;
- affinity;
- quant kernel;
- huge-page mode;
- cold/warm pages.

Thread sweep should be automated.

---

# 13. GPU matrix

Record:

- GPU model;
- VRAM/unified memory;
- driver/runtime;
- kernel variant;
- graph capture on/off;
- attention path;
- KV dtype;
- batch;
- device memory high-water mark;
- power if exposed.

---

# 14. NPU matrix

Record full-task end-to-end behavior, not only kernel time:

- compile/load time;
- resident memory;
- transfer time;
- tokens/s;
- energy;
- fallback events;
- unsupported operations.

---

# 15. Speculative matrix

For every viable pair:

```text
workload
reasoning mode
drafter quant
target quant
k
acceptance
net speedup
energy
memory
```

Also file losing cases. Knowing when speculation loses is part of a good auto-policy.

---

# 16. Statistical procedure

Performance:

- warmup runs;
- multiple measured iterations;
- median and p95 where relevant;
- capture system load/thermal state;
- no cherry-picked best single run.

Quality:

- fixed prompt suite version;
- deterministic seeds where possible;
- human-scored tasks blinded to quant when human judgment is used;
- executable validation for code/JSON whenever possible.

---

# 17. Regression thresholds

Aesir can define gates such as:

```text
correctness: zero unexpected oracle regressions
performance: no >5% loss on crown workloads unless justified
memory: no unexplained growth
agent exactness: no statistically meaningful drop for default quant
```

Thresholds can vary by experimental branch, but a release/default change should require explicit evidence.

---

# 18. Evidence directory layout

Suggested:

```text
docs/evidence/qwen3-small/
  0.6b/
  1.7b/
  4b/
  8b/
  quant/
  kv/
  speculative/
  long-context/
  hardware/
```

Every result bundle should include machine metadata and exact commands/config.

---

# 19. Comparison to external engines

Use llama.cpp/SGLang/vLLM as references where meaningful, but require:

- same model file where possible;
- same raw token IDs;
- same sampler;
- same context;
- same output count;
- same hardware;
- no hidden prompt re-rendering.

An external engine can be a correctness oracle and a performance competitor, but the comparison must be apples-to-apples.

---

# 20. Success criterion

The desired outcome is not 'Aesir runs Qwen3.' It is a populated evidence matrix that can answer:

> On this hardware, for this model, quant, context, and workload, what is the fastest configuration that still meets the required quality and memory target?
