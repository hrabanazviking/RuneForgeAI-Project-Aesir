# H170 — Threading: Multi-Core Dispatch Assessment

**Date:** 2026-10-10
**Verdict:** DEFERRED — implementation complexity exceeds slice budget; documented with technical rationale (H023 honest-shortfall precedent).

## Goal

Implement multi-core dispatch across the Pi 5's 4 Cortex-A76 cores for
embarrassingly parallel CPU work (batch GEMMs, prefill), targeting ≥2.5×
speedup on 4-thread batched prefill (B=4).

## Why Deferred

Mojo 1.1.0 has **no `parallelize`** (`max.algorithm` absent; `std.runtime`
async explicitly unsupported). The only parallelism primitive is
**fork-based** (precedent: `vordr/spawn.mojo`, H146), which provides:
- `fork()` / `waitpid()` via `external_call`
- Process spawning via `/bin/sh -c "exec ..."`

What fork-based parallelism **cannot** easily provide in Mojo 1.1:
1. **Shared memory.** `fork()` gives copy-on-write address spaces. For
   parallel GEMM, workers need shared access to the output matrix.
   POSIX `shm_open`/`mmap` via `external_call` is possible but requires
   manual pointer management across the fork boundary — Mojo 1.1's
   `Pointer` model makes this painful (non-nullable, origin-tracked).
2. **Synchronization.** No futex/mutex primitives in Mojo 1.1 stdlib.
   Would need `external_call` to pthread, with the same pointer issues.
3. **Work distribution.** The prefill's GEMMs have data dependencies
   (layer N's output is layer N+1's input). Parallelizing across layers
   is impossible; parallelizing within a GEMM requires the shared-memory
   infrastructure above.

## Measured Opportunity (roofline)

- Current prefill (H174): 3.362 tok/s single-core.
- The prefill is compute-bound (GEMM at 7.77 GFLOPS, 4 cores × 7.77 =
  31 GFLOPS theoretical).
- Realistic 4-core speedup: 2.5-3.0× (memory bandwidth shared, Amdahl
  from non-parallelizable attention softmax).
- Projected: 8.4-10.1 tok/s with threading.

## Path Forward

A proper implementation requires:
1. POSIX shared memory wrapper in Mojo (`shm_open`, `mmap`, `munmap`).
2. Fork-based worker pool with work queues in shared memory.
3. GEMM split by M-dimension across workers, with barrier sync.
4. Bit-identity verification (1,000 dispatches).

This is a 3-5 day systems programming effort, not a single-slice task.
Recommend scheduling as a dedicated campaign (e.g., "C10: Parallelism").

## Conclusion

H170 is **deferred**, not abandoned. The single-core optimizations
(H164: +12% GEMM, H173: 10.86× decode, H174: +61.6% prefill) deliver
the campaign's goals. Threading remains the largest untapped opportunity
(~3× prefill) for future work.
