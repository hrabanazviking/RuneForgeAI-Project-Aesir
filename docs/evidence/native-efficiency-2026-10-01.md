# Native efficiency evidence — 2026-10-01

Measured on NVIDIA RTX 2060 Max-Q, 6 GiB, driver 595.91.07, locked Mojo 1.0.0 / MAX 26.5, sm_75. Model digest: sha256:dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff. Native CPU offload is zero. Context 4096 and temperature zero. The supervised native service was stopped while each owned GPU measurement ran. No corpus or embedding changes.

Previous executable: `d1ee3ba2e84f9b89923a32356e89dac262d44146c6a17316edcaa142d4e6f536`. Improved executable: `997a0c00defb75e1429702708609c56bf2ed15bb6782ac63917f679d168e02b3`. Reports identify actual binaries and loaded digests. Git publication identity and exact CI are separate gates.

## Controlled HTTP timings

Standard suite: one excluded warmup and two measured samples per case, 32-token ceiling. Actual output counts vary from 2 to 32. Extended suite: one excluded warmup and one measured sample per case, 128-token ceiling. Both binaries produce exactly the same complete replies, counts and finish reasons in all 34 paired requests. No sample or owned-process failure was observed.

| Workload | Prior uncached s | Improved uncached s | Ratio | Prior cached s | Improved cached s | Ratio |
|---|---:|---:|---:|---:|---:|---:|
| arithmetic | 1.163 | 0.716 | 1.62x | 0.156 | 0.095 | 1.64x |
| graph | 2.623 | 1.607 | 1.63x | 1.362 | 0.826 | 1.65x |
| long_prompt | 10.011 | 6.147 | 1.63x | 1.411 | 0.860 | 1.64x |
| code | 2.561 | 1.563 | 1.64x | 1.273 | 0.767 | 1.66x |
| unicode | 2.773 | 1.686 | 1.64x | 1.397 | 0.843 | 1.66x |

| Extended work | Prompt/output tokens | Prior uncached s | Improved uncached s | Ratio |
|---|---:|---:|---:|---:|
| long_context | 1070/128 | 48.255 | 30.170 | 1.60x |
| sustained_generation | 52/128 | 7.465 | 4.571 | 1.63x |

GPU memory at ready state was 2466 MiB for both binaries. Fresh process readiness was 3.420 s versus 3.426 s with warm OS/driver caches. Linux uncached VmHWM was 3510284 versus 3510364 kB (about 3.35 GiB each). No extra device workspace or KV allocation is introduced. Cached times mean matching retained prefixes; new large inputs still pay prefill cost.

## Kernel traces and numerical evidence

For the same 24 token forwards, 4032 Q4 projection launches cost 660.11 ms versus 430.58 ms; 675 Q6 launches cost 121.73 ms versus 75.093 ms. Combined projection time drops 781.84 to 505.673 ms. 1347 normalization launches drop 53.529 to 16.855 ms (3.18x). These nvprof totals include profiling overhead and are separate from HTTP timing. The intermediate whole-vector register candidate only reduced RMS time to 50.701 ms and was refined into four-value tiles. Hardware counters were not collected: nvprof does not support them on sm_75 and Nsight Compute refused counters with ERR_NVGPUCTRPERM. No driver/counter permission settings changed.

Physical synthetic Q4/Q5/Q6 probe: 738 exact scalar-reference rows, 1404 tail-guard cells, six widths and three row counts. RMS probe: 48 exact scalar/span cases and 233472 independently checked values; maximum absolute discrepancy against high-precision equations 3.31862988e-7. Zero/tiny/large values, nonzero offsets and in-place writes pass. The checker separately refuses truncated, duplicate, nonfinite and incorrect probe output. Real independent GGUF dot products: all 35 pass with maximum error 2.9802322e-7. Seven cached/fresh completions, sampling/repetition/system divergence and deadline/reset recovery pass. The evidence comparator has 19 explicit invalid-report mutations and recomputes medians rather than trusting report summaries.

## Limits and reproduction

These are narrowly exercised native model/device results. Full independent model logits, truly batched prefill, very long attention contexts, broad models/devices and locked-runtime in-process CUDA context recreation remain open. Prefix cache is ephemeral, not secure erasure. Small samples, thermal/clock variance and warm OS caches limit general claims. Do not infer general Ollama superiority or all-platform support.

See [operation and reproducible commands](../NATIVE_EFFICIENCY.md). Raw reports and traces are in [the evidence directory](native-efficiency-2026-10-01/). Failed profiling invocations and intermediate candidates are retained locally and excluded from performance claims.

## Final operational gates

The counted master completes with 186 passed, zero failed, one external-fixture skip, total 187. The named intentional negative control exits 1. Native service probes pass real authentication, framing/Unicode and slow-client rejection, seeded replay, deadline/reset, peer disconnect and clean shutdown. All 29 authored native/OpenAI/Ollama-mode API cases pass. Sampling/cache flag admission, evidence mutation tests, documentation drift and fixture policy checks pass. Logs are retained alongside raw reports. These exercised recovery gates do not claim GPU fault injection, full model logits or fixed in-process context recreation.

## Current paired provider observations

The final native binary and Ollama used hash-verified identical GGUF bytes, context 4096, greedy sampling and a 32-token ceiling. Both were resident at 4686 MiB total GPU use. Eighteen requests passed without failure. Warm medians: native/Ollama arithmetic 0.0957/0.3307 s, passage 0.8378/0.8737 s, longer prompt 0.8764/0.8922 s. Native now edges this small repeated-prefix subset. Native first passage 1.306 s and longer prompt 5.820 s remain slower than observed Ollama 0.918 s and 1.003 s. Ollama's first arithmetic 4.805 s includes loading; do not call that a controlled cold comparison.

Templates differ by 20 prompt tokens in these cases; arithmetic produces 2 versus 3 output tokens. Native F16 and configured Ollama KV formats/prefix policies differ. These observations are not full numerical parity or general provider superiority. Bifröst retains its existing Ollama policy and original nomic embeddings. The paired report truthfully records the pre-publication working tree as dirty and the actual final binary/source fingerprint; publication identity is recorded separately.

Final deployment verification: native model/context/prefix readiness and a real CUDA arithmetic completion pass. Native, Bifröst and watcher units are active. Database and original embeddings are ready; corpus remains 1237 documents / 49006 chunks, fingerprint v3_49006_49006. Skein reports 8586 entities and 26339 relations, built with no current build in progress. No corpus mutation was part of the probes.
