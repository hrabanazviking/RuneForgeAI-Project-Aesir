# 18 - Autotuning and Deployment Profiles

**Research snapshot:** 2026-11-02

Project Aesir should not make users hand-tune dozens of low-level knobs for every Qwen3 model. The engine can benchmark a small calibration workload, learn the local hardware, and save a profile keyed to exact model/runtime identity.

---

# 1. Why autotuning is necessary

The optimum depends on:

- model size;
- quant;
- CPU microarchitecture;
- memory bandwidth;
- GPU/NPU model;
- context length;
- batch/concurrency;
- KV precision;
- prefill versus decode;
- thermal/power limits.

A hard-coded 'use 16 threads and this tile size' rule will be wrong on many machines.

---

# 2. Profile key

Persist tuning results under a strict key:

```text
Aesir build/commit
model SHA256
quant format
CPU model + ISA
GPU/NPU identity + runtime/driver
memory topology
```

If any material component changes, invalidate or re-check the profile.

---

# 3. Calibration workload

A short first-load calibration can test:

### CPU
- thread count;
- affinity strategy;
- decode quant kernel variant;
- prefill tile/chunk;
- attention tile;
- prefetch distance.

### GPU
- quant kernel variant;
- graph capture;
- prefill chunk size;
- attention kernel;
- batch crossover.

### KV
- f16 baseline;
- int8 if integrated;
- page size.

### Speculative
- candidate drafter pair;
- initial `k`.

Calibration must be bounded. Do not make model startup feel like a compiler benchmark suite.

---

# 4. Fast tune versus deep tune

Offer two levels:

## Fast tune
Seconds-scale microbenchmarks for obvious choices.

## Deep tune
Explicit user/developer action that runs a larger benchmark/quality campaign and records stable profiles.

Production can use fast tune automatically and deep tune for enthusiasts or release engineering.

---

# 5. CPU thread autotuning

For each phase:

```text
prefill
single-token decode
draft-check
batch decode
```

sweep a small candidate set around physical-core count.

Save separately because prefill may want more cores than decode.

---

# 6. Kernel autotuning

Aesir can register several implementations with semantic equivalence:

```text
q4_decode_scalar
q4_decode_avx2
q4_decode_avx512
q4_decode_vnni
```

Run tiny correctness check first, then benchmark. The fastest passing implementation becomes local default.

Same concept for CUDA tile variants.

---

# 7. Context-aware policy

A configuration that wins at 512 tokens may lose at 32K because attention/KV traffic grows.

Store context bands:

```text
short <= 2K
medium <= 8K
long <= 32K
extended > 32K
```

Potentially choose different attention/KV policies by band.

---

# 8. Memory-aware policy

Before choosing the fastest config, ensure it fits with headroom.

Aesir should reserve safety margin for:

- OS/application;
- activations;
- temporary buffers;
- concurrent sessions;
- GPU driver/runtime;
- draft model.

If a quality profile would force swapping, a lower-bit quant is usually the better real-world configuration.

---

# 9. Deployment profile: Tiny Control Plane

**Model:** Qwen3-0.6B  
**Goal:** always-on routing, classification, query rewrite, basic tools.

Starting policy:

```text
Q4_K_M or Q5_K_M
2K-8K default context
non-thinking default
CPU/NPU auto selection
int8 KV when proven
prefix cache for stable system/tool prompt
```

Optimization priority: latency and idle efficiency.

---

# 10. Deployment profile: Edge Worker

**Model:** Qwen3-1.7B  
**Goal:** routine agent work and local assistance.

```text
Q4_K_M default candidate
Q5 quality option
8K-16K default context
reasoning auto
CPU/GPU/NPU benchmark selection
int8 KV for longer sessions
```

Optimization priority: task success per joule and low latency.

---

# 11. Deployment profile: Balanced Assistant

**Model:** Qwen3-4B

```text
Q4_K_M balanced
Q5_K_M quality
native <=32K context
GPU/unified memory preferred if resident
reasoning auto
prefix caching enabled
```

Optimization priority: interactive quality/speed balance.

---

# 12. Deployment profile: Quality Local

**Model:** Qwen3-8B

```text
Q4_K_M balanced
Q5/Q6 quality
native <=32K by default
GPU/unified memory preferred
reasoning auto
smaller worker model available for cheap tasks
```

Optimization priority: quality with controlled memory bandwidth.

---

# 13. Deployment profile: Long Context

**Model:** Qwen3-4B or 8B

Required bundle:

```text
YaRN only when >32K
int8 KV
paged/lazy KV
chunked prefill
memory admission check
prefix cache
history compaction
```

Never enable '128K' as only a RoPE flag while leaving a giant f16 contiguous cache as the default.

---

# 14. Deployment profile: Speculative

Examples:

```text
1.7B -> 8B
0.6B -> 4B
```

Policy:

- drafter preferably on independent compute resource;
- start small `k`;
- measure rolling profitability;
- auto-disable when losing;
- keep both tokenizers/templates pinned identical.

---

# 15. Deployment profile: Multi-Agent Forge

Potential resident set on high-memory systems:

```text
0.6B router
1.7B worker pool
4B supervisor
8B quality judge
```

Scheduler chooses the cheapest model likely to solve each subtask and escalates based on validation.

---

# 16. Thermal-aware tuning

Laptop performance can change after sustained load.

Aesir should distinguish:

- burst benchmark;
- steady-state 5-10 minute behavior.

A kernel that wins cold but throttles badly may be inferior for long sessions.

Optional telemetry:

- clock;
- temperature;
- package/GPU power;
- sustained tokens/s.

---

# 17. Battery/power mode

On mobile systems, provide policies such as:

```text
performance
balanced
efficiency
```

Efficiency mode can:

- prefer 0.6/1.7B;
- reduce CPU thread count;
- use NPU;
- disable unnecessary thinking;
- cap context;
- queue background work.

---

# 18. Autotune database

Suggested record:

```text
hardware_key
model_sha
quant
phase
context_band
batch_band
kernel_id
threads
tile/chunk
measured_latency
measured_throughput
measured_memory
timestamp
Aesir_sha
```

Profiles should be inspectable and deletable, not a black box.

---

# 19. Confidence in tune results

Do not switch defaults based on a 1% noisy win.

Require:

- repeated samples;
- margin above noise threshold;
- correctness pass;
- no memory regression;
- optional fallback when telemetry later shows poor behavior.

---

# 20. Desired user experience

The ideal Aesir workflow:

```text
load model
Aesir recognizes hardware/model
quickly verifies cached tuning profile or runs a bounded calibration
runs the model with sane optimized defaults
shows advanced users exactly what was selected
```

The engine does the tedious hardware archaeology so users can actually use the model.
