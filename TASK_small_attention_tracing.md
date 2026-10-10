# Task: Optional Strategy5 Owned Attention Tracing

## Authorization and scope

This is AES500-011, the next contract slice after the accepted controls fixture
gate. Volmarr authorized continuing the AESIR 500-slice program. This task covers
owned, source-bound NVTX/CUDA attribution for the existing small-score strategy5
attention kernel. It authorizes no kernel arithmetic changes, provider comparison,
production selection, speed claim or change to strategies0–4.

## System statement

Strategy5 model, causal-generation, sealed replay and cooperative-control fixture
gates are independently accepted for narrow scopes. Existing projection tracing
and strategy4 attention tracing have their own owned library/range/checker paths.
Strategy5 currently has no separately admitted trace capability. Reusing
`fused_tracing` would cross an evidence boundary because small attention is a
distinct strategy and its trace ranges need exact strategy5 identity.

## Owning domain and files

- `aesir_engine/tests/turing_prefill_fixture.mojo` owns a new final
  `small_tracing=False` capability, immutable admission and the small-kernel range
  boundary. It must remain separate from `small_controls`, replay and strategy4
  tracing capabilities.
- `aesir_engine/tests/projection_trace.mojo` owns only the enabled NVTX push/pop
  wrapper for an explicitly named small-score attention batch.
- `aesir_engine/tests/test_turing_prefill_trace.mojo` owns plain/profiled strategy5
  complete-model output and state captures, preserving the existing probe modes.
- `scripts/check_turing_prefill_trace.py`, `scripts/check_cuda_trace.py` and
  `scripts/cuda_fused_attention_ranges.py` own bounded input admission, accepted
  strategy5 source binding, SQLite/Nsight correlation and resource attribution.
- Update fixture/script interfaces, operation docs, roadmap, TODO, ledger, README
  and DEVLOG only to the exact accepted trace scope.

## Desired outcome

1. `small_tracing=False` is default and admits no trace labels or profiling work.
2. Explicit tracing requires strategy5 and is mutually exclusive with controls,
   control-capable replay and borrowed strategy4 trace capabilities. Unsupported
   combinations reject before model load, state mutation, NVTX symbol lookup or
   GPU enqueue.
3. A fresh untraced capable-but-disabled strategy5 baseline remains bit/state/cache
   identical to the accepted strategy5 model evidence. Tracing does not alter
   logits, committed IDs, sampler state, cache contents, dispatch counts or guards.
4. For the public37 and1070 token sessions, each actual four/32-token small-score
   attention tile enqueue has exactly one owned `aesir.attend.small.b{batch}` child
   range, on the probe's owning thread and inside its complete source-bound parent
   session. That enqueue launches a single grid spanning all 28 model layers;
   therefore each child must own exactly 28 successful launch correlations and
   their complete kernel intervals. Single-token attention remains original and
   has no small-score range.
5. Full-session CUDA activity and successful API launch/runtime correlations map
   each range to its exact accepted strategy5 kernel, grid/block geometry and
   complete asynchronous GPU interval. Never clip a GPU interval to CPU enqueue
   time or infer attribution from shape alone.
6. Profiled and unprofiled runs pass all source5 complete logits, input IDs, cache
   hashes, state, real small/down/fused/scalar counts and guards. Current source,
   model, accepted source triplet, current binary, CSV, Nsight export, SQLite and
   reports are rehashed after validation.

## Evidence boundary

Range/GPU durations are diagnostic and unscored. This task establishes attribution
for the declared source/model/device and two public prompts only. It does not prove
occupancy, spills, root cause, speedup, request latency, general model/device
behavior, controls-plus-tracing, runtime selection, CUDA fault recovery,
concurrency/soak, persistence/context recreation or provider lead.

## Work order and acceptance

1. Confirm the pushed controls release commit and exact hosted CI result. Preserve
   the accepted controls evidence receipt and baseline source5 identities.
2. Map actual `attend_small` kernel names, launch counts, wrappers and resource
   geometry before adding labels; reuse the existing owned projection/fused trace
   machinery rather than creating an unbounded parallel analyzer.
3. Add the explicit default-false capability and mutation-free negative contracts;
   prove all legacy trace modes and unprofiled strategy5 remain unchanged.
4. Add a capable-but-disabled strategy5 source baseline and plain/profiled
   collectors for public37 and1070. Bind the accepted model5 CSV/report/binary.
5. Extend the bounded checker/analyzer with an explicit small-trace mode. Add
   adversarial tests for missing/duplicate/late ranges, wrong label/batch/kernel,
   PID/thread/source drift, incomplete/overlapping activity, geometry mismatch,
   tampering, interruption and output races. Older modes stay strict.
6. Finish all affected builds, master suite, normal build and docs checks before
   serial Nsight GPU capture. Preserve raw qdstrm, export failures, complete SQLite
   and each failed report in fresh directories; run CPU/source gates separately.
7. Reconcile exact diff/evidence independently; publish the narrow receipt, push
   the slice and verify exact hosted CI before starting AES500-021.

## Current status

Contract established after strategy5 controls acceptance. No implementation or
trace capability is claimed yet.

### Initial reconnaissance — AES500-012

- `TuringPrefillFixture.attention` dispatches `attend_small[4]` or `[32]` only
  inside the explicit `small_attention` branch. The enqueue receives the fixture's
  device context, activation/cache buffers, query/attention offsets, stride,
  per-layer cache offset, capacity1536, current position and token count.
- `attention_push` currently emits the strategy4-only label
  `aesir.attend.fused.b{count}`. The fixture wraps both strategy4 and strategy5
  through the fused tracing capability; the trace collector accepts only
  strategies2/3/4. Strategy5 therefore needs a distinct range owner and admission.
- Each `attend_small[4|32]` wrapper issues one launch with grid `(24,count)` and
  block `128`; the fixture calls it once per layer. Thus the expected trace is one
  tile child per small-attention host enqueue and 28 successful kernel
  correlations per child, each grid `(24,count,1)` and block `(128,1,1)`. Reusing
  strategy4's one-kernel-per-layer attribution would undercount/misclassify this
  dispatch topology.
- `scripts/check_cuda_trace.py` supplies the bounded SQL activity/correlation
  analyzer; `scripts/check_turing_prefill_trace.py` owns complete model vectors,
  accepted baseline binding and strategy admission. The existing trace path is a
  reuse point, not proof for strategy5.
- Remaining AES500-012 work: inspect exact kernel symbol and launch geometry;
  enumerate current source5 accepted CSV/report/binary and trace source exports;
  identify capture-tool availability/version and the exact full-session export
  schema before implementing a tracing capability.
