# Native long-token evidence — 2026-10-01

Physical host: RTX 2060 Max-Q, 6 GiB, driver595.91.07, Linux x86-64,
locked Mojo1.0.0/MAX26.5, sm_75. Model Llama3.2 3B Q4_K_M,
SHA256 dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff.
No CPU model offload, provider substitution or corpus/embedding change.

Archived working binary: 997a0c00defb75e1429702708609c56bf2ed15bb6782ac63917f679d168e02b3.
Final binary: f3442a1e5915cb43ec4da8a0f885ff38710a02b6ef795515dbe1f72c36ceda2b.
The final facade-import cleanup rebuild preserves that exact measured checksum.
Source publication and remote CI are separately verified by exact Git revision.

## Controlled HTTP evidence

One excluded warmup per case; three measured samples for standard/cached suites,
one for extended/stress. Same context4096, model digest, system, greedy sampling,
limits, prefix policy and complete response/count/finish sequences. Benchmark
generation deadline is120000ms; the deployed service remains45000ms, so the
3150-token test is an isolated measurement rather than a production-timeout claim. The comparator
requires explicit intent for batch1 to batch4 and rejects every other policy or
reply mismatch. No failures in the measurements. Times below are entire HTTP
requests, not isolated decode throughput or first-token latency.

| Fresh work | Input/output tokens | Before s | After s | Ratio |
|---|---:|---:|---:|---:|
| arithmetic | 30/2 | 0.734 | 0.425 | 1.73x |
| graph | 37/32 | 1.642 | 1.264 | 1.30x |
| long_prompt | 237/32 | 6.354 | 3.500 | 1.82x |
| code | 36/29 | 1.607 | 1.219 | 1.32x |
| unicode | 38/32 | 1.729 | 1.293 | 1.34x |
| long_context | 1070/128 | 29.565 | 16.261 | 1.82x |
| sustained_generation | 52/128 | 4.540 | 3.942 | 1.15x |
| near_context | 3150/128 | 96.501 | 52.037 | 1.85x |

All 26 fresh and 20 cache-enabled paired replies/counts match. A further four
forced-sequential extended replies match the baseline. Forced batch1 is near
flat (29.779 versus29.565 seconds long input; 4.570 versus4.540 sustained),
showing the fresh-prompt gain comes mainly from four-token prefill. Repeated
cached medians are 0.976–0.999x relative to baseline (about0.1–2.4% slower in this
small series); no cached/decode speed improvement is claimed. First appearances
with caching enabled perform different work from retained exact prefixes.

The 3150-input/128-output stress request uses3279 context positions; it is below
the maximum4096. Neither synthetic8192 attention nor this request certifies
maximum-context whole-model correctness/performance. Small samples and thermal/
clock variance limit broad or statistical claims. No new paired Ollama benchmark
was run; Bifröst retains its ordinary Ollama default.

## Memory and independent physical checks

Compact scratch adds405504 bytes (396KiB) for four disjoint token intermediates;
logits/scores are shared. KV stays469762048 bytes at context4096. Ready GPU
observation is2468MiB versus2466MiB (allocator/coarse observation). Host HWM is
about3.35GiB and readiness around3.3–3.4seconds with warm OS/driver caches. No
secure erasure, total-VRAM reduction, quantized KV or cold-load improvement claim.

Four projection:2952 exact scalar-reference rows and5616 guards, six widths,
three row tails, Q4/Q5/Q6. Long attention:24 original/tiled exact cases, guarded
outputs and65536 independent NumPy values, maximum absolute error3.0896622e-7.
Histories1,7,31,32,33,1024,4096,8192; query heads8/24/32, KV8, dim128. Real 3B
prefill:641280 exact native sequential/tiled logits, five greedy/seeded replies,
exact-token restored continuation and invalid-tile non-mutation. Native logits
are a regression reference, not an independent external whole-model oracle.
The existing35 independent real-weight dot products still pass, max2.9802322e-7.

## Attention kernel trace

nvprof sums24 original launches at4.8890ms versus24 tiled launches at2.0455ms,
about2.39x for this synthetic mixed-history set. The separate chronological trace
identifies the original kernel as the first launch in each case (hash3c8bf4d90fb53fc3)
and tiled second (a6bf5d922a2cbd18), matching the probe source. At history4096,
three head shapes sum1515.31us original /627.17us tiled (2.42x); at8192,
3042.94/1241.43us (2.45x). Small histories1/7 cost about3–4% more in the tiled
kernel. Its register count is53 versus28, a measured latency/occupancy tradeoff.
These profiled kernel timings are separate from end-to-end wall times. No GPU
hardware counters, power-efficiency or all-device optimality claim.

## Recovery and evidence gates

Counted master187pass/0fail/1skip,total188; named negative control exits1.
Seven cached/fresh cases cover divergence, system isolation, sampled replay and
1ms timeout/reset recovery with the tiled default. The final measured binary
passes real authenticated HTTP, framing/Unicode/oversize/slow-client refusal,
seeded replay, deadline recovery, peer disconnect and shutdown. All29 API fixtures
pass. Flag admission rejects invalid/duplicate tiles before keys, and unsupported
profiles reject explicit four before session allocation. Evidence validation
checks19 prior mutations plus explicit policy-change/reply gates and six malformed
or ignored prefill-intent cases. Documentation/fixture gates run separately.

Development checks caught an incorrect hand-derived buffer expectation (33792,
not34816 elements) and an import preceding a module docstring. Both were corrected
before candidate measurements. The initial build failure log is retained; failed
build publication preserved the old working executable. A comparator invocation
with positional arguments rejected before comparison and was rerun with named
--before/--after inputs. No failed observation was used to publish a speed ratio.

Only synchronized tiles commit; GPU failure still poisons reuse. Deadline checks
are cooperative at at most four input tokens and each generated token. This is
not injected GPU-fault recovery. Broad profiles/devices, maximum-context whole-
model inference, independent external logits, concurrent GPU batching, quantized
KV and locked-runtime in-process context recreation remain open.

[Operation and reproduction](../NATIVE_LONG_TOKENS.md).
[Raw reports and physical logs](native-long-tokens-2026-10-01/).
