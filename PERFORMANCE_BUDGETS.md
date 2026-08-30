# PERFORMANCE BUDGETS — Project Æsir

> **Status boundary — 2026-08-30:** The values below are proposed targets, not
> measured performance commitments. No throughput, latency, power, load, or
> multi-user budget in this document has current acceptance evidence. The
> CUDA telemetry in [docs/GEMMA4_CUDA.md](docs/GEMMA4_CUDA.md) establishes
> execution on one GPU, not performance.

## Authority

This document defines the numerical performance targets for Project Æsir. Every optimization decision is judged against these numbers. Every claim of "fast" or "efficient" is meaningless until measured against the budgets defined here.

The ENGINEERING_DOCTRINE.md states that Mojo exists for performance. This document defines what performance means in concrete, measurable, falsifiable terms.

If the system does not meet these budgets, the capability ledger must reflect that deficiency. If the system exceeds these budgets, the targets were too conservative and should be revised upward.

Guesses are not measurements. Vibes are not benchmarks. Numbers or nothing.

---

## Section One: Budget Philosophy

### Why Budgets Exist

Without defined targets, three failure modes emerge:

**Drift**: The system slowly degrades as features accrete. Nobody notices because there is no reference point. By the time someone measures, the regression is structural and expensive to fix.

**False Confidence**: An agent optimizes a function, measures a 15% local improvement, and declares victory. The end-to-end pipeline is unchanged because the bottleneck was elsewhere. Without system-level budgets, local optimization is theater.

**Scope Creep Disguised as Polish**: Agents spend days micro-optimizing a kernel that already meets budget while a critical path function bleeds latency unnoticed. Budgets redirect attention to where it matters.

### How Budgets Are Used

1. **Baseline Measurement**: Before optimization work begins, measure current performance against the relevant budget. Record the baseline.
2. **Target Identification**: If the baseline falls short, the gap defines the work. If the baseline exceeds the budget, redirect effort elsewhere.
3. **Regression Detection**: CI runs performance tests on every PR. A regression beyond the tolerance threshold blocks the merge.
4. **Capability Ledger Evidence**: Upgrading a performance-related feature to Verified requires budget compliance evidence in the test results.

### Budget Tolerance

Budgets include a tolerance band. Performance within tolerance is compliant. Performance outside tolerance triggers investigation.

- **Green**: At or better than budget target
- **Yellow**: Within 10% of budget target (investigate, do not block)
- **Red**: Worse than 110% of budget target (block merge, fix before proceeding)

---

## Section Two: Hardware Target Tiers

Project Æsir supports multiple hardware configurations. Budgets are defined per tier because a 7B model on a Jetson Nano cannot meet the same targets as a 7B model on an RTX 4090.

### Tier Definitions

| Tier | Label | GPU | VRAM | CPU | RAM | Use Case |
|------|-------|-----|------|-----|-----|----------|
| T1 | Desktop Enthusiast | RTX 4090 | 24 GB | Ryzen 9 7950X | 64 GB | Developer workstation, high-end local inference |
| T2 | Desktop Standard | RTX 3060 | 12 GB | Ryzen 5 5600X | 32 GB | Consumer local inference, moderate concurrency |
| T3 | Laptop | RTX 4060 Mobile | 8 GB | Intel i7-13700H | 32 GB | Portable local inference, single user |
| T4 | Edge GPU | Jetson Orin Nano | 8 GB | ARM Cortex-A78AE | 8 GB | Edge deployment, constrained power envelope |
| T5 | CPU Only | None | 0 GB | Ryzen 7 5800X | 32 GB | Fallback path, no GPU available |
| T6 | Mini Edge | None | 0 GB | Raspberry Pi 5 | 8 GB | Extreme edge, minimal inference capability |

### Tier Applicability

Not all model sizes run on all tiers. The matrix below defines which combinations are supported and measured.

| Model Size | Quantization | T1 | T2 | T3 | T4 | T5 | T6 |
|------------|-------------|----|----|----|----|----|----|
| 1B | Q4_K_M | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 1B | Q8_0 | ✓ | ✓ | ✓ | ✓ | ✓ | ◐ |
| 3B | Q4_K_M | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| 3B | Q8_0 | ✓ | ✓ | ✓ | ✓ | ◐ | ✗ |
| 7B | Q4_K_M | ✓ | ✓ | ✓ | ◐ | ◐ | ✗ |
| 7B | Q8_0 | ✓ | ✓ | ◐ | ✗ | ✗ | ✗ |
| 13B | Q4_K_M | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| 13B | Q8_0 | ✓ | ◐ | ✗ | ✗ | ✗ | ✗ |
| 70B | Q4_K_M | ✓^1^ | ✗ | ✗ | ✗ | ✗ | ✗ |

✓ = Fully supported, budgeted
◐ = Marginal (best-effort, no guaranteed budget)
✗ = Not supported
^1^ Requires tensor parallelism across 2+ GPUs

---

## Section Three: Inference Throughput Budgets

### Primary Metric: Tokens Per Second (TPS)

Generation throughput during the decode phase, measured as tokens generated per second for a single concurrent request.

| Model | Quant | T1 Target | T1 Min | T2 Target | T2 Min | T3 Target | T3 Min | T4 Target | T4 Min | T5 Target | T5 Min |
|-------|-------|-----------|--------|-----------|--------|-----------|--------|-----------|--------|-----------|--------|
| 1B | Q4_K_M | 120 | 100 | 80 | 65 | 60 | 50 | 40 | 30 | 25 | 18 |
| 1B | Q8_0 | 90 | 75 | 60 | 50 | 45 | 35 | 30 | 22 | 18 | 12 |
| 3B | Q4_K_M | 80 | 65 | 50 | 40 | 38 | 30 | 25 | 18 | 15 | 10 |
| 3B | Q8_0 | 55 | 45 | 38 | 28 | 28 | 20 | 18 | 12 | 10 | ✗ |
| 7B | Q4_K_M | 65 | 52 | 35 | 28 | 25 | 18 | 12 | 8 | 8 | ✗ |
| 7B | Q8_0 | 42 | 35 | 25 | 18 | 15 | 10 | ✗ | ✗ | ✗ | ✗ |
| 13B | Q4_K_M | 38 | 30 | 20 | 15 | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| 13B | Q8_0 | 25 | 18 | 12 | 8 | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| 70B | Q4_K_M | 18 | 14 | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |

**Target** = The performance level the system should achieve under normal conditions.
**Min** = The floor below which performance is considered unacceptable (Red zone).

### Measurement Conditions

All throughput budgets are measured under these conditions:
- Prompt length: 128 tokens (warmed up, not first-call)
- Generation length: 256 tokens
- Context window: 2048 tokens total
- Batch size: 1 (single concurrent request)
- Temperature: 0.0 (greedy decoding, deterministic)
- Top-k: 0 (disabled)
- Top-p: 1.0 (disabled)
- Model fully loaded in VRAM (no offloading)
- No other GPU workloads running
- Measurement excludes first-token latency (see TTFT budgets)

### Competitive Reference Points

For sanity-checking our budgets against the state of the art:

| Model | Quant | Hardware | llama.cpp | vLLM | Our T1 Target |
|-------|-------|----------|-----------|------|---------------|
| 7B | Q4_K_M | RTX 4090 | ~70 TPS | N/A² | 65 TPS |
| 7B | FP16 | A100 80GB | N/A | ~80 TPS³ | N/A⁴ |
| 13B | Q4_K_M | RTX 4090 | ~38 TPS | N/A | 38 TPS |
| 70B | Q4_K_M | 2× A100 | N/A | ~20 TPS | 18 TPS⁵ |

^2^ vLLM does not support GGUF quantization natively
^3^ vLLM with FP16 on A100, batch size 1
^4^ We do not budget FP16 inference; Mojo GPU kernels are optimized for quantized paths
^5^ Our 70B target is conservative because we target consumer hardware (2× RTX 4090) not data center GPUs

Our targets aim for parity with llama.cpp on consumer hardware. Falling 10% short of llama.cpp is Yellow. Falling 20% short is Red and warrants investigation.

---

## Section Four: Time-To-First-Token (TTFT) Budgets

TTFT measures the latency from request receipt to first generated token. This includes prompt tokenization, prompt prefill, and initial sampling.

| Prompt Length | T1 Target | T1 Max | T2 Target | T2 Max | T3 Target | T3 Max | T4 Target | T4 Max | T5 Target | T5 Max |
|---------------|-----------|--------|-----------|--------|-----------|--------|-----------|--------|-----------|--------|
| 32 tokens | 15 ms | 25 ms | 25 ms | 40 ms | 40 ms | 60 ms | 80 ms | 120 ms | 200 ms | 350 ms |
| 128 tokens | 40 ms | 65 ms | 70 ms | 110 ms | 100 ms | 160 ms | 180 ms | 280 ms | 450 ms | 750 ms |
| 512 tokens | 120 ms | 190 ms | 220 ms | 350 ms | 320 ms | 520 ms | 550 ms | 900 ms | 1300 ms | 2100 ms |
| 2048 tokens | 420 ms | 650 ms | 750 ms | 1150 ms | 1050 ms | 1650 ms | 1700 ms | 2700 ms | 3800 ms | 5800 ms |

**Target** = Expected median TTFT.
**Max** = p99 TTFT. No request should exceed this under normal load.

### TTFT Measurement Conditions

- Model: 7B Q4_K_M (standard reference model for TTHT budgets)
- Cold start excluded (model already loaded)
- Timer starts when HTTP request body is fully received
- Timer stops when first token is yielded to the response stream
- Includes: tokenization, prefill forward pass, first sampling
- Excludes: model loading, HTTP connection establishment

### TTFT vs Throughput Tradeoff

TTHT and throughput compete for GPU resources. A system optimized purely for throughput may exhibit poor TTFT because it delays prefill to batch with other requests. Conversely, a system optimized purely for TTFT may sacrifice batching efficiency.

Project Æsir prioritizes TTFT for single-user scenarios and throughput for multi-user scenarios. The scheduler must adaptively balance these based on active request count:

- **1 active request**: Prioritize TTFT. Begin prefill immediately.
- **2-4 active requests**: Balanced. Small prefill batching delay acceptable (≤10 ms).
- **5+ active requests**: Prioritize throughput. Batch prefill aggressively.

---

## Section Five: Memory Budgets

### VRAM Utilization

Total VRAM consumed by the inference engine, including model weights, KV cache, and runtime overhead.

| Model | Quant | Weights | KV Cache (2048 ctx) | Runtime Overhead | Total Budget | T2 Feasible? |
|-------|-------|---------|--------------------|--------------------|---------------|--------------|
| 1B | Q4_K_M | ~0.7 GB | ~0.3 GB | ~0.2 GB | 1.2 GB | ✓ |
| 3B | Q4_K_M | ~2.0 GB | ~0.6 GB | ~0.3 GB | 2.9 GB | ✓ |
| 7B | Q4_K_M | ~4.4 GB | ~1.2 GB | ~0.4 GB | 6.0 GB | ✓ |
| 7B | Q8_0 | ~7.5 GB | ~1.2 GB | ~0.4 GB | 9.1 GB | ✓ |
| 13B | Q4_K_M | ~7.5 GB | ~2.0 GB | ~0.5 GB | 10.0 GB | ✓ |
| 13B | Q8_0 | ~13.5 GB | ~2.0 GB | ~0.5 GB | 16.0 GB | ◐ |
| 70B | Q4_K_M | ~40 GB | ~4.0 GB | ~0.8 GB | 44.8 GB | ✗ |

### Runtime Overhead Budget

Runtime overhead is the VRAM consumed by the engine itself beyond weights and KV cache. This includes:
- Workspace buffers for intermediate computations
- Sampling state
- HTTP connection buffers
- MoJo runtime allocations
- Profiling and metric buffers

**Budget**: Runtime overhead must not exceed 5% of model weight size, with a floor of 200 MB and a ceiling of 1 GB.

Formula:
```
overhead_budget = clamp(weights_size * 0.05, 200_MB, 1_GB)
```

### KV Cache Efficiency

PagedAttention should achieve at least 90% utilization of allocated KV cache blocks. Fragmentation (free blocks that cannot be allocated due to page table constraints) must not exceed 10%.

Metric:
```
kv_efficiency = allocated_blocks / total_blocks
```

**Target**: kv_efficiency ≥ 0.90
**Minimum**: kv_efficiency ≥ 0.80

### System RAM Budget (CPU Path)

When running on CPU-only tiers (T5, T6), model weights reside in system RAM. The engine must not consume more system RAM than:

```
ram_budget = weights_size * 1.3 + kv_cache_size + 512_MB
```

The 1.3 multiplier accounts for mmap overhead and workspace buffers. The 512 MB floor covers runtime overhead.

---

## Section Six: Startup and Loading Budgets

### Cold Start Time

Time from process launch to "ready to accept requests," including model loading.

| Model | Quant | T1 Target | T1 Max | T2 Target | T2 Max | T5 Target | T5 Max |
|-------|-------|-----------|--------|-----------|--------|-----------|--------|
| 1B | Q4_K_M | 0.8 s | 1.5 s | 1.2 s | 2.0 s | 2.0 s | 3.5 s |
| 3B | Q4_K_M | 1.5 s | 2.5 s | 2.5 s | 4.0 s | 4.0 s | 7.0 s |
| 7B | Q4_K_M | 3.0 s | 5.0 s | 5.0 s | 8.0 s | 8.0 s | 14.0 s |
| 13B | Q4_K_M | 5.0 s | 8.0 s | 8.0 s | 13.0 s | 13.0 s | 22.0 s |
| 70B | Q4_K_M | 15.0 s | 25.0 s | ✗ | ✗ | 40.0 s | 60.0 s |

### Warm Restart Time

Time to unload one model and load another (hot-swap):

**Budget**: 1.5× the cold start time for the incoming model.

### Model Loading Efficiency

The loader must use zero-copy or mmap for weight loading. Copying weights through an intermediate buffer is prohibited.

Metric:
```
load_throughput = weights_size / load_time
```

**Target**: load_throughput ≥ 2 GB/s on NVMe storage
**Minimum**: load_throughput ≥ 1 GB/s on SATA SSD

If load throughput falls below 1 GB/s on NVMe, investigate the loading path for unnecessary copies or synchronous I/O.

---

## Section Seven: Concurrent Request Budgets

### Maximum Concurrent Sequences

The maximum number of simultaneous inference requests the engine can serve without degradation.

| Tier | VRAM | Max Seqs (7B Q4) | Max Seqs (3B Q4) | Max Seqs (1B Q4) |
|------|------|-------------------|-------------------|-------------------|
| T1 | 24 GB | 16 | 32 | 64 |
| T2 | 12 GB | 6 | 12 | 24 |
| T3 | 8 GB | 3 | 6 | 12 |
| T4 | 8 GB | 2 | 4 | 8 |
| T5 | 0 GB | 2 | 4 | 8 |

These limits assume 2048-token context per sequence. Longer contexts reduce the maximum proportionally.

### Degradation Threshold

Throughput per request must not degrade by more than 15% at maximum concurrency compared to single-request throughput.

Measurement:
```
degradation = 1 - (tps_at_max_concurrency / tps_single_request)
```

**Target**: degradation ≤ 0.10 (10%)
**Minimum**: degradation ≤ 0.15 (15%)

If degradation exceeds 15%, the scheduler is not batching efficiently. Investigate prefill-decode interleaving and KV cache contention.

### Fairness Guarantee

No request should wait more than 2× the median request latency for its turn to begin prefill. Starvation of any request is a defect.

---

## Section Eight: Tokenizer Performance Budgets

### Encoding Throughput

BPE encoding speed for raw text to token IDs.

**Target**: ≥ 500,000 tokens/second on T1 CPU
**Minimum**: ≥ 200,000 tokens/second on T1 CPU

### Decoding Throughput

Token ID to text decoding speed.

**Target**: ≥ 1,000,000 tokens/second on T1 CPU
**Minimum**: ≥ 500,000 tokens/second on T1 CPU

### Vocabulary Load Time

Loading a BPE vocabulary from file.

**Target**: ≤ 50 ms for a 50,000-token vocabulary
**Minimum**: ≤ 150 ms for a 50,000-token vocabulary

### Cache Hit Ratio

When token caching is enabled, repeated prompts should achieve:

**Target**: ≥ 80% cache hit ratio for prompts sharing a ≥ 64-token prefix
**Minimum**: ≥ 60% cache hit ratio for prompts sharing a ≥ 64-token prefix

---

## Section Nine: HTTP API Performance Budgets

### Request Parsing Overhead

Parsing an incoming HTTP request body into an internal inference request.

**Target**: ≤ 0.5 ms for requests under 4 KB
**Minimum**: ≤ 2.0 ms for requests under 4 KB

### Response Marshalling Overhead

Formatting generated tokens into an HTTP response (including SSE streaming format).

**Target**: ≤ 0.1 ms per token in streaming mode
**Minimum**: ≤ 0.3 ms per token in streaming mode

### Connection Handling

The HTTP server must support:
- **Target**: ≥ 100 concurrent connections without degradation
- **Minimum**: ≥ 50 concurrent connections without degradation
- Connection teardown must complete within 5 ms of client disconnect

---

## Section Ten: Measurement Methodology

### Benchmark Harness

All performance measurements are conducted using the benchmark harness located at `tests/performance/bench_runner.mojo`.

The harness:
1. Warms up the model with 3 inference calls (results discarded)
2. Runs the measured operation N times (default N=20)
3. Records all timings
4. Computes median, p90, p99, and standard deviation
5. Reports results in machine-readable JSON

### Benchmark Output Format

```json
{
  "benchmark": "decode_throughput",
  "model": "tiny_test_model.gguf",
  "hardware_tier": "T1_emulator",
  "configuration": {
    "prompt_length": 128,
    "generation_length": 256,
    "context_window": 2048,
    "batch_size": 1,
    "temperature": 0.0
  },
  "iterations": 20,
  "warmup_iterations": 3,
  "median_tps": 67.3,
  "p90_tps": 64.1,
  "p99_tps": 58.7,
  "mean_tps": 66.8,
  "stddev_tps": 2.4,
  "budget_target": 65.0,
  "budget_min": 52.0,
  "compliance": "green",
  "date": "2026-08-15T14:32:00Z",
  "git_commit": "a3f7b2c"
}
```

### CI Performance Gate

CI runs a subset of performance benchmarks on every PR to development:

1. Tiny model decode throughput (proxy for kernel efficiency)
2. Tiny model TTFT at 128 tokens (proxy for prefill path)
3. Tokenizer encoding throughput (proxy for BPE implementation)
4. KV cache allocation/deallocation cycle (proxy for memory management)

These benchmarks run on CI hardware which may not match any defined tier. Results are compared against a CI-specific baseline established on the first successful CI run. Regression beyond 15% from baseline blocks the PR.

### Manual Full Benchmark

Full benchmark suites against all defined budgets are run manually on qualifying hardware. Results are recorded in `docs/performance/results/YYYY-MM-DD-tier-results.md`.

Format:
```markdown
# Performance Results — 2026-08-15 — T1

## Hardware
GPU: NVIDIA RTX 4090 (24 GB)
CPU: AMD Ryzen 9 7950X
RAM: 64 GB DDR5
Storage: Samsung 990 Pro 2TB NVMe

## Results

### Decode Throughput

| Model | Quant | Budget | Median | p99 | Compliance |
|-------|-------|--------|--------|-----|------------|
| 7B | Q4_K_M | 65 TPS | 68.2 | 61.4 | Green |
| 13B | Q4_K_M | 38 TPS | 39.1 | 34.7 | Green |

### TTFT

| Prompt Len | Budget Med | Median | p99 | Compliance |
|------------|-----------|--------|-----|------------|
| 128 | 40 ms | 37.2 | 52.1 | Green |
| 512 | 120 ms | 118.7 | 162.3 | Yellow |

### Notes
TTFT at 512 tokens is borderline yellow. Investigation suggests prefill
chunking threshold is too high. Recommend tuning CHUNK_THRESHOLD from
512 to 256 in AesirEngine config.
```

---

## Section Eleven: Budget Revision Process

### When to Revise

Budgets are revised when:
1. The system consistently exceeds targets by >20% (targets too conservative)
2. The system consistently fails to meet minimums (targets unrealistic for current architecture)
3. Hardware tiers are added or removed
4. New model architectures require different performance characteristics
5. Competitive landscape shifts (llama.cpp or vLLM release major optimizations)

### Revision Procedure

1. **Proposal**: Any contributor proposes a revision in a DECISIONS entry with rationale and measurement evidence.
2. **Impact Analysis**: The Architect role analyzes which capabilities and tests are affected.
3. **Approval**: The human coordinator approves or rejects the revision.
4. **Implementation**: The Scribe updates this document. The Forge Worker updates benchmark configurations. The Auditor verifies that tests still produce meaningful results.
5. **Notification**: All active agents are notified of the new budget regime.

### Versioning

This document is versioned. Each revision increments the version and records the change in a changelog at the bottom of this file.

---

## Section Twelve: Known Performance Gaps

This section tracks acknowledged deficiencies where the system does not meet budget. Items here are not surprises—they are documented debts with plans to resolve.

| Gap | Affected Budget | Current Status | Planned Resolution | Target Date |
|-----|----------------|-----------------|-------------------|-------------|
| (none currently) | — | — | — | — |

When a gap is discovered, add it here. When a gap is resolved, remove it and record the resolution in the DEVLOG.

---

## Section Thirteen: Quick Reference

```
CHECKING PERFORMANCE BEFORE CLAIMING DONE:
□ Ran bench_runner.mojo for the relevant benchmark?
□ Results meet or exceed budget target (Green)?
□ If Yellow, investigated and documented?
□ If Red, stopped and planned remediation?
□ Recorded results in docs/performance/results/?
□ Compared against previous results for regression?
□ Updated capability ledger with performance evidence?

CLAIMING AN OPTIMIZATION:
□ Measured before optimization (baseline)?
□ Measured after optimization (result)?
□ Improvement is real and outside stddev?
□ No other benchmark regressed?
□ Results recorded with git commit hash?
```

---

## Closing Principle

Performance budgets are not aspirations. They are contracts between the system and its users.

A user who installs Project Æsir on an RTX 4090 expects 7B Q4 inference at 65 tokens per second. If the system delivers 40, the user is not experiencing a "minimum viable product." They are experiencing a broken promise.

Measure against the budgets. Meet them or revise them honestly. Never claim performance you have not verified.

The machine does not lie. The benchmark harness is how you ask it the truth.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-15 | Initial performance budget definition |

---

*Last updated: 2026-08-15. Maintained by the Architect role. Performance measurements maintained by the Auditor role. Revisions require coordinator approval.*

---
