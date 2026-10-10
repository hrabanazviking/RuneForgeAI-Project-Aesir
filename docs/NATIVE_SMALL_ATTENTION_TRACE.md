# Owned small-score strategy5 CUDA tracing

This is an opt-in fixture operation for the accepted strict Llama 3.2 3B model,
context1536, F16 KV, precision0 and RTX 2060 Max-Q sm_75. It traces the separate
strategy5 small-score attention tile enqueues. It does not alter inference math,
normal runtime selection or provider policy. All durations are diagnostic and
unscored.

## Capability and range ownership

`TuringPrefillFixture.small_tracing` defaults false and is constructor-sealed.
It requires strategy5 and rejects small controls, replay, strategy4 controls and
strategy4 tracing. Enabled cooperative controls are refused before configuration.
The prefill collector keeps one synchronized `aesir.fixture.prefill` outer range.
The fixture invokes its `attention()` method once per layer, so each actual
`attend_small[4|32]` layer enqueue owns one nested same-thread
`aesir.attend.small.b4` or `.b32` NVTX range. The single-token path remains the
original attention implementation and has no small range.

Each owned child range contains exactly one successful API launch and one
complete asynchronous kernel interval. A full 4- or 32-row tile contributes 28
ordered child ranges, one per model layer; all b32 tiles precede the final b4
tile. Each kernel has the source-bound grid `(24,4|32,1)` and block `(128,1,1)`.
The analyzer admits the complete session, then selects the outer range and maps
child ranges only through successful API correlations. GPU intervals remain
whole if they extend beyond the CPU range.
The kernel's mangled prefix is checked against the compiled implementation. No
shape-only, timing-only or incomplete-capture attribution is admitted.

Strategy4's `aesir.attend.fused.*` labels and one-kernel-per-layer attribution
remain separate and unchanged. Projection-stage labels are not enabled in the
strategy5 collector.

## Build and capture

Build the trace collector and all owning targets plus the master suite and normal
launcher before physical collection. Use a fresh private directory outside Git;
retain failed output and never overwrite files.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_prefill_trace.mojo \
  -o "$ARTIFACTS/aesir-small-attention-trace"
"$ARTIFACTS/aesir-small-attention-trace" "$MODEL" 1 "$ARTIFACTS/plain.csv" 0 5
NSYS_NVTX_PROFILER_REGISTER_ONLY=0 nsys profile --trace=cuda,nvtx \
  --capture-range=none --sample=none --cpuctxsw=none \
  --force-overwrite=false --stats=false --output="$ARTIFACTS/capture" \
  "$ARTIFACTS/aesir-small-attention-trace" "$MODEL" 1 "$ARTIFACTS/profiled.csv" 0 5
nsys export --type=sqlite --force-overwrite=false \
  --output="$ARTIFACTS/capture.sqlite" "$ARTIFACTS/capture.nsys-rep"
```

Run the compiled probe directly so its CUDA process identity remains the actual
PID. The probe's CSV creation is exclusive and private. Use public case1 (37 IDs)
and case3 (1070 IDs). Keep raw `.qdstrm`, `.nsys-rep`, SQLite, stdout/stderr,
process receipts and every failed checker report. The locked exporter is Nsight
Systems2023.4.4.54. Profiler wall time is not application performance evidence.

## Admission

```sh
python3 scripts/check_turing_prefill_trace.py \
  --unprofiled "$ARTIFACTS/plain.csv" --profiled "$ARTIFACTS/profiled.csv" \
  --sqlite "$ARTIFACTS/capture.sqlite" \
  --binary "$ARTIFACTS/aesir-small-attention-trace" --binary-sha256 "$BINARY_SHA" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-csv "$SOURCE5_CSV" --reference-report "$SOURCE5_REPORT" \
  --reference-binary "$SOURCE5_BINARY" --case 1 --small-attention \
  --output "$ARTIFACTS/accepted.json"
```

The checker binds the accepted strategy5 source CSV/report/binary, current model
and trace binary, complete plain/profiled logits/cache/input/state/counters/guards,
full-session CUDA PID/device/API/kernel/resource identities, 28 unique
layer-owned child ranges and launch correlations per tile, exact geometry and
final hashes. Explicitly allowlisted CUDA context/stream/memory initialization
calls may precede Nsight's analysis interval only when they end before the owned
prefill range; this host initialization count is recorded separately. Kernels,
launches, and the owned session remain interval-checked. Source quality
reuses the accepted full-model strategy5 CPU/source gate; it is not recast as a
new oracle run. Run case3 with `--case 3` in a separate fresh output directory.

This narrow attribution does not establish occupancy, spills, root cause, speedup,
request latency, broader model/device behavior, controls-plus-tracing, runtime
selection, CUDA fault recovery, concurrency/soak or provider lead.
