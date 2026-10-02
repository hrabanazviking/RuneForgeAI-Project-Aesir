# Exact-state batched elementwise evidence — 2026-10-02

Optional original precision0/strict3B/context1536/F16KV on RTX2060 Max-Q sm75.
A separate3072/33824 strided RMS sibling uses four independent warp groups per
CTA. Grid-y residual/SiLU wrappers retain original per-cell arithmetic and stream
dependencies. Scalar/default kernel definitions stay unchanged. No new global
workspace/weight copy. Explicit2 requires accepted rotary/cache strategy1 and
precision0; actual flags and sealed owner/strategy refuse drift before tile/reset.

All513024 complete model values per owner/public IDs equal accepted strategy1
F32 bytes, including signed zero; every176160832-byte full guarded-F16-cache hash
matches. Eight invalid-tile refusals,4352 guards, repeats/committed state and
actual host counters pass. Every unchanged independent CPU/native .05-max/.005-
RMS/full-vocabulary-argmax gate passes. All32 raw warm/alternating timings remain.

| Input IDs | Prior elementwise plan calls | Actual grouped host calls | Native seconds | New fixture seconds | Native/fixture ratio |
|---:|---:|---:|---:|---:|---:|
| 30 | 4201 | 1261 | 0.331649 | 0.328234 | 1.010406 |
| 37 | 5181 | 421 | 0.394398 | 0.225331 | 1.750302 |
| 31 | 4341 | 1401 | 0.356589 | 0.355615 | 1.002740 |
| 1070 | 149801 | 5321 | 12.826068 | 6.942053 | 1.847590 |

Prior counts describe original5*28*input_count+1 plan calls; new counts are actual
successful enqueues5*28*tile_count+1. Existing rotary/cache actual calls remain
756/252/840/3192. These counters are host calls, not GPU profiler data. Medians
exclude the warm/export pair and use three alternating fresh pairs. Only fresh
native-to-fixture exploratory ratios are scored, never cross-session/provider
comparisons. Full cache host copy/digest/export and process time remain unscored;
transient synchronized host copy is168.000061MiB and no cache dump persists.

Explicit2 additionally passes all96 greedy32/seeded16 decode predictions after
public37/1070 prefixes,12312576 values per owner, unchanged CPU/native/sample/
state/draw/own-bit/4352-guard gates. Eight checkpoint continuations before/after
same-context exact-boundary reset/replay pass1026048 values per mode and every
original source/sample/state/bit/12 damaged-plan refusal/4352-guard gate. Those
reports have speed_scored=False. provenance.json separately records whether all
exported continuation records after variant metadata equal prior strategy1 bytes.

Master190 passes/zero failures/one explicit skip. Seven portable grid contracts
include explicit strategy2, source1-only chaining, unknown old mode2 refusal,
correct/missing counters and complete streamed duplicate/late rejection. All nine
legacy model/decode/checkpoint contracts pass. Every sm75/sm89/master/normal build
finishes before the three serial GPU captures; CPU references run afterward.
Normal binary remains f3442a1e, authenticated ready/prefill4/cpuoffload0. Hashes/
portable paths/process ordering/raw receipt identities remain in provenance.
Exact push/CI are separate receipts. No code/compile failure was hidden or deleted.

Broader width/stride/profile/context/device, enabled controls on this new strategy,
maximum history/window wrap, fused attention, runtime32, persisted/context
recreation, GPU-fault repair, concurrency/soak and refreshed Ollama lead remain
separate gates. Next earn controlled-strategy recovery and owned stage tracing
before additional attention work or production admission.

[Operation](../../NATIVE_TURING_BATCHED_ELEMENTWISE.md).
