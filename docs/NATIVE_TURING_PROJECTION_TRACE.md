# Source-bound projection attribution

This extends [owned prefill tracing](NATIVE_TURING_PREFILL_TRACE.md) for original
strict3B/context1536/F16KV/sm75 strategy2, public37/1070 cases. It measures which
actual loaded projection owns GPU work before choosing another matrix change.
All durations are profiler diagnostics, with speed_scored=False.

## Operation

Use the previous build/capture/export/check workflow and compiled native probe.
Append1 after NEW.csv to enable projection ranges on both plain and profiled runs:

```sh
"$ARTIFACTS/aesir-turing-prefill-trace" "$MODEL" 1 "$ARTIFACTS/unprofiled.csv" 1
NSYS_NVTX_PROFILER_REGISTER_ONLY=0 nsys profile --trace=cuda,nvtx \
  --capture-range=none --sample=none --cpuctxsw=none \
  --force-overwrite=false --stats=false --output="$ARTIFACTS/capture" \
  "$ARTIFACTS/aesir-turing-prefill-trace" "$MODEL" 1 "$ARTIFACTS/profiled.csv" 1
```

Pass --projection-ranges to scripts/check_turing_prefill_trace.py with every
previous required source/model/binary/SQLite argument. Use3 for long case. A new
STAGES,1 CSV marker is mandatory only for this explicit checker mode. Missing,
duplicate, unknown or late markers refuse. Omitted/0 probe flag preserves legacy
CSV and fixture tracing remains disabled by default. No default runtime requires
NVTX. Direct probe owns the actual installed globally loaded library; only enabled
diagnostic calls resolve its push/pop functions through pinned OwnedDLHandle.

Labels aesir.project.{stage}.b{batch} cover query/key/value/output/gate/up/down
and final head. Each label first checks actual loaded tensor offset/kind/rows/
columns against its owner, original precision0 and strategy2. No arithmetic,
device buffer, synchronization or dispatch changes are introduced. Callback or
label failure propagates through existing fixture poison behavior, without an
unlabelled fallback. Protected source corpus/keys/model bytes remain untouched.

## Attribution gate

Every original complete source F32 vector (signed zero included), full guarded
cache digest, committed IDs/state, host counts and guards must pass in both plain
and profiled runs. Full-session strict owner/timestamp/successful correlation
admission precedes synchronized outer-range selection. Complete disjoint child
push/pop ranges must lie inside that outer range on its actual thread. Expected
range counts come from source token count and exact32/4/1 tiling with28 layers;
head appears exactly once at batch1. No caller-supplied per-stage timing values.

Each projection kernel requires exactly one child range containing the complete
successful launch API interval on the owning thread. Nonprojection kernels inside
child ranges refuse. Batch32 key/value have eight actual four-token launches;
other declared shapes have one launch per range. Missing/extra/overlapping ranges
or kernels refuse. Bounds and read-only/no-follow/SQLite protections remain.

GPU intervals are asynchronous. Attribution follows their exact launch
correlations; a child CPU enqueue range does not need to contain the later GPU
interval and adds no synchronization. This follows NVIDIA's
[NVTX projection rule](https://docs.nvidia.com/nsight-systems/AnalysisGuide/index.html).
Report groups include actual range/kernel counts, batch/rows/columns and summed
GPU duration. Shared names are resolved through actual labels, not guessed from
shapes. GPU/API durations overlap and are never added or scored as service speed.
No per-layer timing, new independent inference, production32, broader model/device/
context/concurrency/soak/persistence or refreshed Ollama lead follows.

Retain every raw trace, rejected capture/export, source/binary/process/build hash
and exclusive failed report. Complete numerical and changed-artifact/interrupt
failures withhold attribution. Hosted CI compiles the probe and exercises portable
synthetic contracts; actual physical acceptance is separate evidence.
