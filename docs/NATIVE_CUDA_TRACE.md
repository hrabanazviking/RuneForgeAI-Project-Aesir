# Owned native CUDA timeline operation

This optional SPD-00 tool captures the existing native Mojo CLI. It does not
attach to the live second-brain service. The exercised boundary is Linux x86-64,
Llama 3.2 3B Q4_K_M, context 4096/F16 KV, RTX 2060 Max-Q/sm_75 and installed Nsight
Systems 2023.4.4.54. The parser admits the observed Nsight 2023 SQLite schema.
Other tool versions require a separate schema/flag check before admission.

## Capture one public request

Prepare the checkout's offline launcher as documented in LOCAL_LAUNCH.md. Choose
a new artifact directory outside Git and a single-line public prompt. The original
registered model must already exist; nothing is downloaded or installed.

```sh
python3 scripts/profile_native_cuda.py \
  --prompt /your/public-prompt.txt --max-tokens 128 \
  --weights-sha256 YOUR_REGISTERED_MODEL_SHA256 \
  --output-dir /your/new-private-trace-directory
```

Only the exercised `llama3.2:3b` registration is admitted. The tool checks the
fresh/checksummed executable, catalog/blob identity, installed profiler version
and observed free VRAM for a separate weights/KV/staging allocation plus headroom.
It never stops other services to create space. A single GPU observation is not
a VRAM reservation: competing allocations can still fail, and that failure is
retained. Keep GPU experiments serialized. The default timeout is 180 seconds
per owned child, configurable within 10..300; output ceilings are 32/128/256.

Each process receives the same explicit system text, public prompt, greedy
sampling, repetition penalty 1 and fresh context. Complete reply and terminal
counts must match before any trace can pass. Wall time includes initialization,
loading, inference and profiler teardown; **profiled time is not a speed score**.

CPU sampling/context-switch tracing is disabled. CUDA trace alone needs no GPU
performance counters or privilege changes. For split Linux packages, Nsight can
capture `.qdstrm` yet fail to locate its installed host importer. The tool uses
the matching `/usr/lib/nsight-systems/host-linux-x64/QdstrmImporter` when present;
`--importer` provides an explicit installed path. Its version must match exactly.
No overwrite flag is used. Raw capture and the original importer failure remain.

## Artifacts and interpretation

The new directory is private (0700). Children inherit an environment allowlist
for runtime/home/cache/CUDA paths, not arbitrary credential variables. Full raw
`.qdstrm`, `.nsys-rep`, SQLite export, complete transcripts, importer/export logs
and `report.json` stay local. **Review metadata before sharing raw traces**: the
profiler records machine/process information. Public summaries contain only
selected CUDA rows, hashes, model/build identity, public completion and timings.
The report hashes each preceding artifact; it does not self-hash.

The analyzer opens a bounded regular file through its read-only descriptor,
rejects final symlinks/journal sidecars and never executes input SQL. Concrete
required tables, exporter identity, finite integer timestamps, one actual CUDA
PID/device, executable basename and every successful unique kernel/launch
correlation are checked. Limits: 512 MiB database, two million rows per queried
table, 16384 strings / 8 MiB dictionary, 30 seconds SQLite query budget. CPU
analysis/memory remain proportional to admitted rows. Linux `/proc` is required.

```sh
python3 scripts/check_cuda_trace.py /your/closed-export.sqlite \
  --output /your/new-summary.json
python3 scripts/test_check_cuda_trace.py
```

Summary groups are actual recorded kernel names; compiler mangling may truncate
semantic names. Shared projection kernels cannot distinguish Q/K/V/FFN without
additional instrumentation. GPU interval union excludes double counting overlaps.
The uncovered portion between first and last kernel is observable timeline time,
not proof of CPU launch delay. API durations (especially synchronization) overlap
GPU execution and must not be added to it. Initialization/upload and inference
are present; prefill/decode boundaries are not independently marked in this slice.
Nonzero non-launch API statuses are retained rather than silently erased: the
observed runtime probes unsupported `cuMemCreate` allocations and falls back.
Actual failed launch, missing trace rows or identity mismatch fails admission.

Exit 0 requires a complete matched capture/export/trace. Exit 1 retains failures
in the newly reserved directory. Ctrl-C kills/reaps only the owned process group
and writes evidence before exit 130. Existing artifact paths are refused. Raw
failures must not be removed to make a successful summary look cleaner.

These are profiler and evidence controls. They establish neither general CUDA
support, answer quality nor a lead over Ollama. Read SPEED_MEASUREMENT.md for the
independent numerical and provider gates that remain separate.
