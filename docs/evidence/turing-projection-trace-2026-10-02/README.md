# Source-bound projection attribution — 2026-10-02

Both public37/1070 plain/profiled cases pass all513024 source F32 values (signed
zero included), complete guarded-cache hashes, actual committed IDs/state/host
counts and4352 guards. Each stage binds actual loaded tensor offset/kind/rows/
columns. Strict full-session CUDA owner/timestamps/successful correlations precede
outer synchronized NVTX selection and disjoint same-thread child range projection.

Short37:589 child ranges attribute981 actual projection kernels inside4837 total
kernels. Long1070:7449 ranges attribute20385 actual projection kernels inside120919.
Source-derived tile counts are32:1/4:1/1:1 and32:33/4:3/1:2 respectively. Every
stage has28 layers per tile; head appears once. Each batch32 key/value child owns
eight original four-token launches, while other shapes own one. No launch/kernel
or range is inferred or missing, and no asynchronous GPU interval is clipped to
its CPU enqueue range. No new synchronization is introduced.

Long batch32 attribution, observed GPU duration:

| Projection | Seconds | Share of all recorded kernel duration |
| --- | ---: | ---: |
| query | 0.447513 | 6.71% |
| key | 0.308748 | 4.63% |
| value | 0.293497 | 4.40% |
| output | 0.446307 | 6.69% |
| gate | 1.100836 | 16.51% |
| up | 1.102354 | 16.53% |
| down | 1.266542 | 18.99% |

Batch32 FFN gate/up/down total3.469732s (52.04% of recorded kernel
duration). Down is the largest individual staged projection, while gate/up each
also exceed1s. These are profiler diagnostics, not benchmark ratios. The next
matrix candidate should target bounded packed-block decoding/staging in FFN,
preserving original accumulation and complete source bytes before speed scoring.
Shared projection names no longer require guessing; no per-layer timing is earned.

Eight portable attribution contracts and nine probe/source/report contracts pass,
including counts/missing/duplicate/overlap/thread/boundary/async/API containment,
registered labels, exact batch32 key/value launches, wrong/missing/late markers,
source mutation/interruption/exclusive and signed-zero cases. Thirty original
trace contracts and existing model/control/grid/decode/checkpoint gates remain.
Both targets/master/normal/check finish before serial physical captures. Master190
passes/zero fails/one explicit skip. Production remains active/authenticated ready/
prefill4/cpuoffload0 with unchanged f3442a1e binary. All default fixture projection
tracing remains disabled; no new dependency/device buffer/arithmetic/dispatch.

No new independent inference, service/provider speed score, per-layer timing,
production32, broader profile/device/context/concurrency/soak/persistence or refreshed
Ollama lead follows. Exact push/CI receipts are separate.
[Operation](../../NATIVE_TURING_PROJECTION_TRACE.md).
