# Owned inference-only Turing prefill tracing

This opt-in test operation delimits fresh precision0/strategy2 prefill for public
case1/3 (37/1070 input IDs), strict Llama3B/context1536/F16KV on sm75. Initialization,
logit exports and guarded-cache copies remain outside the synchronized NVTX range.
Production admission stays one/four. Trace durations never become speed scores.

## Build and capture

Use the locked toolchain. Finish all builds, including master and normal launcher,
before physical GPU collection; serialize probes. The native probe dynamically
requires installed `libnvToolsExt.so.1` and its actual push/pop symbols. Hosted CI
only compiles it; that does not claim GPU execution or installed NVTX at runtime.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_prefill_trace.mojo \
  -o "$ARTIFACTS/aesir-turing-prefill-trace"
"$ARTIFACTS/aesir-turing-prefill-trace" "$MODEL" 1 "$ARTIFACTS/unprofiled.csv"
NSYS_NVTX_PROFILER_REGISTER_ONLY=0 nsys profile --trace=cuda,nvtx \
  --capture-range=none --sample=none --cpuctxsw=none \
  --force-overwrite=false --stats=false --output="$ARTIFACTS/capture" \
  "$ARTIFACTS/aesir-turing-prefill-trace" "$MODEL" 1 "$ARTIFACTS/profiled.csv"
```

Set ARTIFACTS to a new private directory outside Git; MODEL is the original pinned
registered GGUF. The probe exclusively creates a0600 CSV with no-follow/nonblocking
flags and redirects its own stdout. Run the compiled binary directly so CUDA
process identity matches its actual PID. A Python exec/subprocess wrapper may
change recorded process metadata and does not meet this operation's ownership gate.
Only public built-in prompts are supported. Use3 for the declared long case.
The installed NVTX-triggered capture mode produced mismatched activity/analysis
time coordinates, including UTC export; those failures are retained. Full-session
capture preserves original coordinates and the explicit semantic range selects
fresh prefill after all rows have passed admission.
Supervisor must own/reap only its process group with bounded timeout (120s plain,
180s profile exercised). Never attach to or stop managed services.

The exercised profiler/exporter is Nsight2023.4.4.54. If split-package automatic
import cannot locate its importer, retain the .qdstrm and use the matching installed
QdstrmImporter with --input-file/--output-file. Retain importer version/hash/log.
Export a new SQLite with nsys export --type=sqlite --force-overwrite=false. Never
overwrite a report, change counters/permissions/drivers or install a new profiler
to make evidence pass. All raw profiler files and failed attempts stay private.

## Admission

```sh
python3 scripts/check_turing_prefill_trace.py \
  --unprofiled "$ARTIFACTS/unprofiled.csv" --profiled "$ARTIFACTS/profiled.csv" \
  --sqlite "$ARTIFACTS/capture.sqlite" \
  --binary "$ARTIFACTS/aesir-turing-prefill-trace" --binary-sha256 "$BINARY_SHA" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-csv "$ACCEPTED_STRATEGY2_CSV" \
  --reference-report "$ACCEPTED_STRATEGY2_JSON" \
  --case 1 --output "$ARTIFACTS/complete.json"
```

Reference must be the complete independently accepted original strategy2 model
CSV/report with matching model, fixed .05-max/.005-RMS/full-argmax budgets and all
four independent native/matrix cases. Both probes preserve actual F32 bytes,
signed zero, complete128256 vectors, input IDs/committed state, actual host counts,
full176160832-byte guarded-cache SHA and1088 guards. This reuses independent proof
through exact source bytes; it is not a new independent inference evaluation.

SQLite admission retains the original [trace limits](NATIVE_CUDA_TRACE.md): closed
regular bounded no-follow descriptor, immutable read-only access, concrete tables,
bounded rows/dictionary/query time, one actual CUDA PID/device and exact successful
launch/kernel correlations. Optional exact probe PID and unique completed NVTX
push/pop range additionally require same launch thread and synchronized selected GPU work
inside that range. Outside kernels remain counted and fully validated; operations
crossing the range boundary refuse. No clipping, inferred process owner or input-provided SQL.
All artifacts rehash after validation. Existing output refuses before work;
interrupt/error retains a failed JSON, complete numerical failures retain metrics.
Exit0 requires every ownership/numerical/state/identity gate; exit1 withholds it.

GPU interval unions and observed kernel/API groups guide later tuning. API and GPU
durations overlap; uncovered time has no proved cause. Shared projection kernel
names do not separate Q/K/V/FFN or certify per-layer semantic attribution. No speed
score, provider lead, production32, broader context/device/concurrency or soak
claim follows from this narrow timeline. Installed NVTX semantics and schema were
checked against [NVIDIA's analysis guide](https://docs.nvidia.com/nsight-systems/AnalysisGuide/index.html)
and the [pinned Mojo FFI source](https://raw.githubusercontent.com/modular/modular/mojo/v1.0.0/mojo/stdlib/std/ffi/__init__.mojo).
