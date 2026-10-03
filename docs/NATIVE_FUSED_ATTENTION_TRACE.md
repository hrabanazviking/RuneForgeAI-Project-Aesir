# Owned fused attention and projection trace

This diagnostic is explicit optional strategy4 for the original packed strict3B
model, precision0, context1536, F16 KV and observed sm75. It inherits complete
fixed numeric/zero-GPU F32 CPU/source3 byte/cache/ID acceptance from the original
[default4 model](NATIVE_FUSED_ATTENTION_MODEL.md) and its actual binary. Python,
NumPy and llama.cpp remain test oracles. Normal authenticated service uses its
original binary and prefill4 setting. Profiler durations are diagnostic/unscored.

## Capability and ownership

Final `fused_tracing=False` is exclusive with fused_controls and the legacy down
control/trace flags. True requires fused_attention, down128, batched rotary/cache,
batched elementwise and precision0. Missing/foreign/conflicting capability fails
before model loading or a tile enqueue. Ordinary4 tracing stays closed; explicit
trace-capable4 control and sealed replay stay closed pending separate acceptance.
Default0..3 and separately accepted default4/control4 policies remain available.

The direct native collector owns its actual process PID, globally loaded NVTX
library, exclusive regular0600 CSV, original committed IDs, sampler and guarded
buffers. It creates one synchronized `aesir.fixture.prefill` parent. Actual packed
tensor identity binds projection stage labels. Fused attention is enclosed by
`aesir.attend.fused.b4`/`.b32` immediately around checked owned-buffer enqueue.
Every successful push has a normal/exception pop. Existing poison policy applies
to unexpected execution errors; there is no claim of GPU hardware fault repair.

## Build before serial capture

Choose fresh private artifact paths and existing prepared frozen environment.
Finish current sm75/sm89, original collector, invalid-capability probe, master and
normal build/check gates before any serial GPU capture. Preserve source/binary/
UTC/error receipts. Never edit native sources during builds/captures or overlap
GPU inference/profiling. Set the following paths/hashes from your actual artifacts:
`ARTIFACTS`, `MODEL`, `MODEL_SHA`, `BINARY_SHA`, `SOURCE_CSV`, `SOURCE_REPORT`,
`SOURCE_BINARY`, and optionally the matching installed2023.4 `IMPORTER` executable.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_prefill_trace.mojo \
  -o "$ARTIFACTS/aesir-fused-attention-trace"
"$ARTIFACTS/aesir-fused-attention-trace" "$MODEL" 1 "$ARTIFACTS/plain.csv" 1 4
NSYS_NVTX_PROFILER_REGISTER_ONLY=0 nsys profile --trace=cuda,nvtx \
  --capture-range=none --sample=none --cpuctxsw=none \
  --force-overwrite=false --stats=false --output="$ARTIFACTS/capture" \
  "$ARTIFACTS/aesir-fused-attention-trace" "$MODEL" 1 "$ARTIFACTS/profiled.csv" 1 4
```

Use case3 for public1070 tokens; case1 has37. Omitted final strategy retains2,
explicit3 retains its down trace contract. Explicit4 requires stages1. Unsupported5,
explicit2 and missing stages for3/4 fail before library/output/model creation.
Do not use a range-triggered partial capture. Retain full cuda,nvtx events and all
failed exports. If the installed split package leaves only raw qdstrm, recover with
the matching version; keep the original error log and raw input:

```sh
"$IMPORTER" --input-file "$ARTIFACTS/capture.qdstrm" \
  --output-file "$ARTIFACTS/capture.nsys-rep"
nsys export --type=sqlite --force-overwrite=false \
  --output="$ARTIFACTS/capture.sqlite" "$ARTIFACTS/capture.nsys-rep"
python3 scripts/check_turing_prefill_trace.py \
  --unprofiled "$ARTIFACTS/plain.csv" --profiled "$ARTIFACTS/profiled.csv" \
  --sqlite "$ARTIFACTS/capture.sqlite" \
  --binary "$ARTIFACTS/aesir-fused-attention-trace" --binary-sha256 "$BINARY_SHA" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-csv "$SOURCE_CSV" --reference-report "$SOURCE_REPORT" \
  --reference-binary "$SOURCE_BINARY" --case 1 \
  --projection-ranges --fused-attention --output "$ARTIFACTS/accepted.json"
```

Fused CLI flags are exclusive with down128. The actual source binary is mandatory
and belongs only to this explicit source gate. Source must be default-control4,
not control-capable4. Full four-case513024-value numeric/CPU scope, independent
fixed .05 max/.005 RMS/full vocabulary argmax, source3 exact byte/cache/ID proof,
actual fused/original/down/rotary/elementwise counts and binary identity are checked
before either trace is parsed. An acceptance Boolean alone cannot admit a source.
No CPU model rerun occurs here; exact complete source bytes carry its quality gate.

## Complete vectors, state and dispatch

Both CSVs contain all128256 actual F32 values including signed zero; original
source IDs and all committed/sampler/position counts; full176160832-byte guarded
cache digest;1088 guards each; actual rotary/elementwise/down enqueues and canonical
DOWN_TILE128,32. Explicit4 emits FUSED_ATTENTION56,28 for37 tokens and1008,56 for1070:
first number is actual fused calls, second actual original scalar attention queries.
Full source bits/cache equality is required, independently for plain and profiled.
Missing/duplicate/late/foreign/partial metadata refuses. Legacy CSV schemas remain.

## Full-session admission before attribution

The read-only, descriptor-backed immutable SQLite export must be bounded, regular,
closed and free of active journal sidecars. One actual process/GPU owner, all time
intervals, successful runtime calls and one-to-one actual kernel correlations are
validated over the entire session before selection. Every kernel resource row,
including excluded initialization/export work, must have bounded integer fields,
valid launch geometry and exact unique correlation coverage. Foreign/malformed
excluded rows cannot be hidden by prefill selection. Copy/memset ownership also
precedes publishing any stage attribution. No export data executes SQL extensions.

Projection attribution keeps exact selected down128 wrappers, canonical geometry,
ordered32/4/1 tiles and seven stages per28 layers, followed by one scalar head.
Fused attribution requires ordered disjoint same-thread type59 children interleaved
after actual value and before output projection for each4/32 tile/layer. There must
be exactly one successful contained launch and one actual fused kernel per child,
the observed `core_fused_causal_attention_fu` wrapper prefix, grid24x4/32x1 and
block128x1x1. Original scalar attention remains outside fused children. Unknown
attention labels, wrong/missing/duplicate ranges, ordering/thread/geometry/prefix/
correlation/resource disagreements refuse. Asynchronous GPU intervals are attributed
by CUDA launch correlation and retained whole, never clipped to child CPU bounds.

Grouped kernel counts/durations and full recorded resources are diagnostic. The
observed fused wrapper records46 registers/thread and16384 static shared bytes;
dynamic shared/per-thread local fields record0. Deprecated legacy local total is
retained raw. These values do not imply occupancy, spills, an earlier failure cause,
uncovered CPU delay or a service speed lead. See the exact
[NVIDIA CUPTI resource field definitions](https://docs.nvidia.com/cupti/api/structCUpti__ActivityKernel8.html).
GPU/API intervals overlap; never sum them into service latency.

## Failure handling and evidence

CLI exit0 requires complete vector/cache/state/source/owner/correlation/resource
admission. Exit1 retains an exclusive failed JSON, including KeyboardInterrupt;
retry into a fresh path and preserve partial/complete failures. Never overwrite
existing CSV/JSON/profile exports. Rehash original model, current/source binary,
source CSV/report, plain/profiled CSV and SQLite after validation. Supervisor code/
binary/source pre/post hashes must agree. Hosted CI compiles probes and runs portable
hostile contracts; physical GPU proof is recorded separately.

Nine new contracts cover explicit flags, actual counts/state/IDs, signed-zero/cache/
numeric failure retention, complete pinned source CPU/prior/binary scope, every
after-artifact hash, interruptions/exclusive output, unknown/foreign/overlap/order
range metadata, exact one-launch geometry/prefix/correlation and malformed/foreign
excluded full-session records before both attributions. Legacy gates and master190
passes/zero failures/one skip accompany seven builds before serial physical capture.

[Retained evidence](evidence/fused-attention-trace-2026-10-03/README.md) covers one
strict profile. Next measure reduced per-CTA token accumulation for FFN projection
under unchanged original math and complete primitive/model acceptance; larger row/
narrower staging/pairing attempts remain retained. Production32, general contexts/
models/devices, trace/control-capable sealed replay, concurrency/soak/persistence,
refreshed provider comparison and an overall Ollama lead remain separate gates.
