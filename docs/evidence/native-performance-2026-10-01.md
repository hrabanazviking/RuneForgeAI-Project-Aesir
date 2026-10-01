# Physical native performance evidence — 2026-10-01

RTX 2060 with Max-Q Design, 6 GiB, driver 595.91.07; locked Mojo 1.0.0/MAX
26.5.0, sm_75, Llama 3.2 3B Q4_K_M, 4096 context, greedy sampling, 32-token
completion ceiling, same native prompt formatting and identical model bytes:
sha256:dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff.

## Native binary comparison

Each variant ran in a fresh owned authenticated native process while other GPU
inference/tests were idle. Each case includes one excluded warmup and two measured
samples. These are small local samples, not universal statistical speed estimates.
All 15 uncached and all 15 cached replies match the corresponding archived
baseline's complete text, model, token counts and finish reasons. Zero failures.
Arithmetic emits 2 tokens; code emits 29; other cases emit 32. Prompt counts are
30, 37, 237, 36 and 38 respectively. Cache-disabled execution recomputes every
prompt token. Cache-enabled warm medians use repeated exact prefixes; first
occurrences can share system/header tokens with the preceding case.

| Workload | Baseline seconds | New uncached seconds | Uncached speedup | New cached seconds | Cached speedup |
|---|---:|---:|---:|---:|---:|
| arithmetic | 3.434 | 1.156 | 2.97x | 0.163 | 21.11x |
| graph | 7.887 | 2.609 | 3.02x | 1.418 | 5.56x |
| long_prompt | 30.059 | 9.966 | 3.02x | 1.460 | 20.59x |
| code | 7.725 | 2.556 | 3.02x | 1.312 | 5.89x |
| unicode | 8.308 | 2.769 | 3.00x | 1.438 | 5.78x |

The longer prompt's first cached occurrence still costs 9.746 seconds. Its 1.460
second warm median requires a matching retained prefix. Do not present that as
the latency of an arbitrary new 237-token prompt. Fresh prompt acceleration is
2.97–3.02x. Cached repeats gain 5.56–21.11x over the old uncached engine.

Archived binary SHA256:
f0ba27b01cf0bc240e162df247b12deb3a4fa2320225a08c2fe4d39379e73c59.
Final binary SHA256:
d1ee3ba2e84f9b89923a32356e89dac262d44146c6a17316edcaa142d4e6f536.
The archived binary was preserved before source changes; its original launch
manifest is retained locally. Binary identity is the measurement authority.
Final code is the performance implementation e82b268 plus metadata correction
0980c88; the launch source fingerprint additionally hashes the checkout location.
Fresh process readiness was 3.421 seconds in both final runs with warm OS/driver
caches. Final observed process high-water RSS was about 3.35 GiB. Prefix reuse
adds no duplicate device KV allocation. No uncached disk-load or power claim.

## Physical profiling and numerical gates

Nvprof observed the same arithmetic CLI run: 24 token forwards, 4032 Q4 projection
calls and 675 Q6 calls. Packed projection GPU time fell from 1.984+0.462 = 2.446
seconds to 0.709+0.130 = 0.838 seconds (about 2.92x). Upload and norm time remained
similar. This explains the bottleneck and kernel gain; profiling is separate from
HTTP end-to-end timing. Nsight's installed importer was not on its expected path;
manual import succeeded and independently confirmed projection dominance.

Physical synthetic Q4/Q5/Q6 comparisons passed 63 rows and tail guards exactly
against scalar CUDA. The independent real GGUF/NumPy oracle passed all 35 sampled
rows, maximum absolute error 2.9802322e-7. Seven cached/fresh actual completions
matched, including divergent prompts, changed system instructions, sampled
seed/repetition settings and timeout/reset recovery. Native HTTP security/fault
probe passed; 29 authored API fixtures passed across native/OpenAI/Ollama modes.
The final master passed 186, failed 0, skipped one absent external F16 fixture,
total 187. Negative control deliberately failed and exited 1. Fixture policy,
checker self-tests and document drift passed after synchronizing the ledger count.
Existing legacy artifact warnings remain visible and no user artifacts were deleted.

## Failed experiments and limits

A harness that released and recreated CUDA contexts within one process stalled.
Its owned process was terminated. The final cache test uses one context and
recomputes all fresh tokens before comparison; it does not certify context
recreation. Process replacement remains the supported model-switch boundary.
An intermediate timing attempt overlapped a diagnostic GPU probe and was
intentionally stopped; its partial/failure report is retained locally and excluded
from performance claims. The published final timing runs were quiescent.
The first implementation push had a stale E-MASTER documentation count; the
following metadata commit repaired it, and final publication checks were repeated.

Only the installed model/device received this full-model physical gate. Shared
Llama/Qwen code does not establish other-model speed; Gemma dispatch is unchanged.
Full independent logits, batched matrix prefill, long-context attention,
context recreation, CPU speed and broad platform/device claims remain open.
The provider comparison and exact publication CI are recorded separately.

See [the technical manual](../NATIVE_PERFORMANCE.md) for commands and contracts.

## Paired providers after optimization

Equal GGUF bytes were rehashed locally in both stores. One excluded warmup plus
 two warm samples per provider/case completed without failure. Current supervised
Aesir (4096 context, prefix cache enabled) versus the configured local Ollama:

| Case | Aesir seconds | Ollama seconds |
|---|---:|---:|
| short | 0.154 | 0.320 |
| 32-token passage | 1.355 | 0.868 |
| longer prompt / 32 output tokens | 1.410 | 0.884 |

Native prompt counts remain 20 fewer than the Ollama template; the arithmetic
output also has different token counts. Native uses F16 KV versus the configured
Ollama KV/prefix policy. This is a local warm workload comparison, not equal
formatted token work, full logits or a general provider superiority claim.
Bifröst keeps its existing Ollama default. Native is explicitly selectable,
serves authenticated real CUDA, and now advertises exact_prefix_reuse=true.
Bifröst and ingestion remain active; source/embedding identity is unchanged.

Persistent chat independently completed both real turns after the profile-family
fix. The two new hosted CUDA probes initially omitted the explicit package search
root: the prefix probe could not resolve loader. The workflow now uses the same
-I aesir_engine as the documented local physical commands. Local sm_89 compilation
checks that workflow correction; it does not execute Ada hardware.
