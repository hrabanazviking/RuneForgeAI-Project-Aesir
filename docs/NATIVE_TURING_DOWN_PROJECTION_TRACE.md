# Owned down128 projection tracing and resources

This is the explicit strategy3 extension of [projection tracing](NATIVE_TURING_PROJECTION_TRACE.md).
It covers the original packed strict3B model, context1536, F16 KV and observed
sm75, with public37/1070 input tokens. Profiler timings are diagnostic and always
unscored. The served native service stays at prefill4.

## Build and collect

Finish all Mojo changes and build/check/master gates before serial GPU work.
Use the locked prepared environment; retain sm75/sm89 build receipts, original
probe build and master190-pass/one-skip result. No upgrade or profiler privilege
change is required. Reserve a new private artifact directory and new CSV paths.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_prefill_trace.mojo \
  -o "$ARTIFACTS/aesir-turing-down-projection-trace"
"$ARTIFACTS/aesir-turing-down-projection-trace" "$MODEL" 1 "$ARTIFACTS/plain.csv" 1 3
NSYS_NVTX_PROFILER_REGISTER_ONLY=0 nsys profile --trace=cuda,nvtx \
  --capture-range=none --sample=none --cpuctxsw=none \
  --force-overwrite=false --stats=false --output="$ARTIFACTS/capture" \
  "$ARTIFACTS/aesir-turing-down-projection-trace" "$MODEL" 1 "$ARTIFACTS/profiled.csv" 1 3
```

Use case3 for1070 tokens. Omitted final strategy retains legacy2; explicitly3
requires STAGES1. Unknown strategy, explicit2 or stages0 with3 refuse before
NVTX/output/model work. The original trace export/import workflow applies;
the matching installed2023.4 QdstrmImporter handles the split-package report
location failure. Keep the original profile log/raw qdstrm and recovered report.
Never rebase timestamps, clip GPU intervals to CPU enqueue ranges, or overwrite
an existing artifact. Export a new closed SQLite with no active sidecars.

```sh
python3 scripts/check_turing_prefill_trace.py \
  --unprofiled "$ARTIFACTS/plain.csv" --profiled "$ARTIFACTS/profiled.csv" \
  --sqlite "$ARTIFACTS/capture.sqlite" \
  --binary "$ARTIFACTS/aesir-turing-down-projection-trace" --binary-sha256 "$BINARY_SHA" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-csv "$ACCEPTED_DOWN_MODEL_CSV" --reference-report "$ACCEPTED_DOWN_MODEL_REPORT" \
  --case 1 --projection-ranges --down128 --output "$ARTIFACTS/accepted.json"
```

The source must be complete accepted strategy3 model evidence, including numeric
owner/independent zero-GPU F32 versions and budgets, exact counters/cache/IDs and
accepted2 predecessor. An acceptance Boolean alone is insufficient. The earlier
ordinary down3 source is valid; control-capability True is not required for trace.
No independent CPU model is rerun here: exact source bytes carry its quality gate.

## Native ownership and admission

TuringPrefillFixture adds final down128_tracing=False. True requires down128
before model load; ordinary down128 still refuses tracing. Explicit owned probe
constructs down=True, control-capability=False, tracing-capability=True. Enabled
controls and projection tracing cannot combine. Pure flags gate step/replay before
state mutation. Tensor offset/kind/rows/columns bind every label to its actual
loaded owner. Down dispatch now shares the balanced try/pop cleanup of original
projections; successful launches/math/counters/buffers remain identical. Errors
propagate through existing owner poison policy, without a GPU repair claim.

Both plain/profiled CSVs must retain all128256 actual F32 logits (including signed
zero), exact input/committed positions/history, full176160832-byte guarded-cache
digest, actual enqueue counts and1088 guards. Strategy3 emits DOWN_ROWS128,28/924
and DOWN_TILE,128,32. Duplicate, missing, late or wrong metadata refuses.

Every full-session process/device/time/kernel/API/copy row and unique successful
launch correlation is admitted before scoped attribution. Resource records also
cover all full-session kernels, including excluded work. Explicit3 requires exact
source32/4/1 order, seven stages across28 layers per tile, final head once,
disjoint same-thread child ranges and unique contained successful API intervals.
The larger-row prefix belongs only to down.b32; other stages retain selected
original wrappers. Recorded grid/block must equal source wrapper geometry:
down32 grid24/block256; staged query/output grid48 and gate/up grid128/block128;
four/scalar gridceil(rows/4)/block128. Key/value32 retain eight four-token launches.
Asynchronous GPU intervals follow correlations and need not lie in child CPU ranges.

## Recorded resources and limits

The explicit path requires bounded integer registersPerThread, staticSharedMemory,
dynamicSharedMemory, localMemoryPerThread/localMemoryTotal and grid/block axes
from installed CUPTI kernel records. Complete unique correlation coverage is
mandatory. Per-stage/batch/kernel distributions retain counts and GPU durations.
Register/shared/local fields report recorded requirements or reserved bytes;
localMemoryTotal is a raw deprecated legacy field, not a spill count. See
[NVIDIA CUPTI field definitions](https://docs.nvidia.com/cupti/api/structCUpti__ActivityKernel8.html).
These values do not establish occupancy, spills, the cause of the earlier256-row
launch refusal, or a service speed lead. GPU/API durations overlap.

CLI exit0 requires complete numerical/cache/state/resource/ownership admission;
exit1 retains an exclusive failed JSON, including changed-artifact and interruption
errors. Every model/binary/source-report/source-CSV/plain/profiled/SQLite hash is
rechecked after validation. Keep all raw logs/process/build/source hashes. Hosted
CI only compiles native probes and tests portable adversarial schemas.
Production32, broader models/context/devices, concurrent control/trace, soak,
persisted/crash replay, free-running quality and refreshed provider comparison
remain separate acceptance gates.
