# Optional small-score fused causal attention

This separate native Mojo primitive reduces the per-CTA static shared score array
from4096 F32 cells (16384 bytes) to1536 F32 cells (6144 bytes), a62.5% reduction.
It preserves the original24-query-head/8-KV-head/128-column GQA arithmetic,
lane-stride dot products/warp reductions/max/exp/normalization, chronological
four-value F32 accumulation and both barriers. There is no global score workspace.
Original `fused_causal_attention.mojo` remains unchanged. Normal model/service
selection remains unchanged; whole-model/runtime acceptance is a separate gate.

## Owned API and safe admission

`core/fused_small_attention.mojo` owns `admit_small_attention[batch]` and
`attend_small[batch]`. Batch capacities are1/4/32. Original checked F32 query/output
allocation and disjointness, positive stride, fixed head geometry and complete
F16 KV allocation admission run first. Actual KV capacity remains1..4096.
Then require visible `prefix+tokens <=1536` using subtracted bounded spans before
CUDA enqueue. Thus capacity4096 and visible1536 is valid; visible1537 refuses.
Caller owns the context/stream, prior causal K/V writes and finite inputs.
The wrapper requires compatible CUDA, grid24xactual_tokensx1/block128x1x1;
any admission/launch failure propagates to the caller's existing error policy.
Do not silently truncate history, auto-fallback or change precision budgets.

## Complete physical output and ownership gate

All33 deterministic cases cover capacities1/4/32, partial actual batches and visible
ends1/31/32/33/37/255/256/257/1070/1535/1536. The1536 endpoint uses actual KV
capacity4096. Modes0/1/2 are distinct dyadic patterns, zero and large stable-softmax
logits. Every original/small F32 output is retained, checked natively as UInt32
including signed zero, and checked against pinned NumPy2.4.4 Float64 causal GQA.
Budgets remain.002 maximum scaled/.0002 normalized RMS, established before capture.
All query and K/V cells are natively checked immutable, and every unowned activation/
KV cell is checked, including the original unused global score area.17 hostile
pure span refusals precede CUDA, including visible1537 and original16 boundaries.
These inputs are deterministic patterns; actual model Q/K/V remains to earn.

Per capture: **1142784 outputs per owner**, **906066 exact guards**,
**1142784 immutable query cells** and **47511552 immutable K/V cells**. Worst candidate
error: `1.32642949712e-06` scaled / `9.83809686184e-08` normalized RMS. Plain and profiled
complete vectors agree bit for bit; all cases/input/guard metadata agree too.

## Same-session plain primitive timings

| Batch capacity | Actual queries | Visible end | KV capacity | Mode | Original fused ms | Small fused ms | Original / small |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 1 | 14 | 0 | 0.00628 | 0.00625 | 1.004530 |
| 1 | 1 | 31 | 44 | 1 | 0.01601 | 0.01601 | 0.999688 |
| 1 | 1 | 32 | 45 | 2 | 0.01349 | 0.01355 | 0.995681 |
| 1 | 1 | 33 | 46 | 0 | 0.01509 | 0.01510 | 0.999118 |
| 1 | 1 | 37 | 50 | 1 | 0.01858 | 0.01844 | 1.007592 |
| 1 | 1 | 255 | 268 | 2 | 0.07579 | 0.07588 | 0.998790 |
| 1 | 1 | 256 | 269 | 0 | 0.07471 | 0.07478 | 0.999060 |
| 1 | 1 | 257 | 270 | 1 | 0.08994 | 0.09007 | 0.998516 |
| 1 | 1 | 1070 | 1083 | 2 | 0.40197 | 0.40166 | 1.000773 |
| 1 | 1 | 1535 | 1548 | 0 | 0.57367 | 0.57394 | 0.999540 |
| 1 | 1 | 1536 | 4096 | 1 | 0.65570 | 0.65528 | 1.000650 |
| 4 | 1 | 1 | 14 | 2 | 0.00598 | 0.00605 | 0.988957 |
| 4 | 4 | 31 | 44 | 0 | 0.01509 | 0.01500 | 1.005577 |
| 4 | 4 | 32 | 45 | 1 | 0.01642 | 0.01650 | 0.995153 |
| 4 | 4 | 33 | 46 | 2 | 0.01561 | 0.01567 | 0.996266 |
| 4 | 4 | 37 | 50 | 0 | 0.01716 | 0.01737 | 0.987683 |
| 4 | 4 | 255 | 268 | 1 | 0.09558 | 0.09547 | 1.001119 |
| 4 | 4 | 256 | 269 | 2 | 0.08166 | 0.08161 | 1.000651 |
| 4 | 4 | 257 | 270 | 0 | 0.08240 | 0.08239 | 1.000063 |
| 4 | 4 | 1070 | 1083 | 1 | 0.45541 | 0.45530 | 1.000245 |
| 4 | 4 | 1535 | 1548 | 2 | 0.56925 | 0.56865 | 1.001045 |
| 4 | 4 | 1536 | 4096 | 0 | 0.56794 | 0.56792 | 1.000041 |
| 32 | 1 | 1 | 14 | 1 | 0.00606 | 0.00603 | 1.004420 |
| 32 | 31 | 31 | 44 | 2 | 0.04930 | 0.03461 | 1.424470 |
| 32 | 32 | 32 | 45 | 0 | 0.05049 | 0.03505 | 1.440567 |
| 32 | 32 | 33 | 46 | 1 | 0.06084 | 0.04200 | 1.448578 |
| 32 | 32 | 37 | 50 | 2 | 0.06087 | 0.04254 | 1.430990 |
| 32 | 32 | 255 | 268 | 0 | 0.48013 | 0.33404 | 1.437333 |
| 32 | 32 | 256 | 269 | 1 | 0.57417 | 0.38459 | 1.492949 |
| 32 | 32 | 257 | 270 | 2 | 0.51696 | 0.35901 | 1.439934 |
| 32 | 32 | 1070 | 1083 | 0 | 2.84251 | 1.80001 | 1.579161 |
| 32 | 32 | 1535 | 1548 | 1 | 3.20309 | 2.01329 | 1.590970 |
| 32 | 32 | 1536 | 4096 | 2 | 2.94544 | 1.86302 | 1.581004 |

Ratios above1 mean lower small-kernel elapsed in this capture. Every660 timing
record remains: ten rotated warmed samples per owner/case, three complete launches
plus synchronization each. Allocation, startup wait, data generation/export, builds,
process duration, CPU/reference work and profiler timing are unscored. This is one
exploratory sm75 session, not a model request, production recommendation or Ollama
comparison. Do not infer request speed by combining primitive ratios.

## Full-session resource acceptance

The identical current binary is directly profiled with full cuda capture. Actual
native PID/filename, full complete vectors and source-bound independent CPU receipt
are mandatory. All session metadata/runtime/kernel/resource/copy intervals, process/
device owners, successful one-to-one launch correlations and bounded integer fields
validate before grouping. Expected counts are1089 per wrapper,2178 total: each case
has initial1/warm2/timed30 launches per owner. Per wrapper token distributions are
1→429,4→330,31→33,32→297. No event is hidden by range selection or clipping.

Observed original prefix `core_fused_causal_attention_fu` and small prefix
`core_fused_small_attention_sma` record static16384/6144, dynamic0 and exact
source grid24xactual_tokensx1/block128x1x1 over all2178 kernels. Full recorded
register/local/grid/block resources and durations remain in resources.json.
These records establish the static score footprint, not occupancy, spills, a
performance cause or aggregate model VRAM reduction. Deprecated legacy local total
is retained raw. [NVIDIA CUPTI fields](https://docs.nvidia.com/cupti/api/structCUpti__ActivityKernel8.html).
Profiled timing ratios are always null; resource checker `speed_scored` is false.

## Reproduce safely from a prepared checkout

Use locked Mojo1.0.0/MAX26.5.0, a new private artifact directory, actual executable
and SHA variables. Finish sm75/sm89/original/master/normal/check builds before GPU
work. Preserve source/binary fences, all errors and UTC receipts; serialize plain,
full-profile capture/import/export, then pinned CPU validation and resource checks.
Never edit native code or run compilation during GPU capture. Prepare both target
builds and the unchanged original primitive, then run190-case master and normal
build/check. The collector takes exactly NEW.csv; invalid argc refuses before
file/CUDA. It reserves a no-follow exclusive regular0600 CSV and refuses existing
files/symlinks. Startup waits one checked second before context creation, outside
all warmed timings, to place initialization APIs inside this exporter's full interval.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine   --target-accelerator sm_75 aesir_engine/tests/test_small_fused_attention.mojo   -o "$ARTIFACTS/small-fused-attention"
"$ARTIFACTS/small-fused-attention" "$ARTIFACTS/plain.csv"
nsys profile --trace=cuda --capture-range=none --sample=none --cpuctxsw=none   --force-overwrite=false --stats=false --output="$ARTIFACTS/capture"   "$ARTIFACTS/small-fused-attention" "$ARTIFACTS/profiled.csv"
```

If the split Nsight2023.4 package leaves raw qdstrm, preserve its error/raw capture
and use the matching installed importer to create a new report. Keep complete
capture; never trigger partial ranges or adjust SQLite timestamps/name data.

```sh
"$IMPORTER" --input-file "$ARTIFACTS/capture.qdstrm"   --output-file "$ARTIFACTS/capture.nsys-rep"
nsys export --type=sqlite --force-overwrite=false   --output="$ARTIFACTS/capture.sqlite" "$ARTIFACTS/capture.nsys-rep"
"$ORACLE_PYTHON" scripts/check_small_fused_attention.py "$ARTIFACTS/plain.csv"   --binary "$ARTIFACTS/small-fused-attention" --binary-sha256 "$BINARY_SHA"   --output "$ARTIFACTS/plain.json"
"$ORACLE_PYTHON" scripts/check_small_fused_attention.py "$ARTIFACTS/profiled.csv"   --binary "$ARTIFACTS/small-fused-attention" --binary-sha256 "$BINARY_SHA"   --unscored --output "$ARTIFACTS/profiled.json"
python3 scripts/check_small_attention_resources.py   --unprofiled "$ARTIFACTS/plain.csv" --profiled "$ARTIFACTS/profiled.csv"   --reference-report "$ARTIFACTS/plain.json" --sqlite "$ARTIFACTS/capture.sqlite"   --binary "$ARTIFACTS/small-fused-attention" --binary-sha256 "$BINARY_SHA"   --output "$ARTIFACTS/resources.json"
python3 scripts/test_check_small_fused_attention.py
python3 scripts/test_check_small_attention_resources.py
```

Plain/profiler CSV admits strict mode/PID/case/value/input/guard/order/completion and
finite-positive timings; binary/CSV hashes bind before/after. Complete bit/numeric/
nonfinite ratio/changed-artifact failures atomically clear every speed ratio while
retaining metrics. Resource tool admits bounded no-follow regular source files,
duplicate/nonfinite JSON refusal, strict full CPU identities/fixed budgets, complete
profile bits and actual binary/PID. All five binary/plain/profile/CPU-report/SQLite
hashes bind before/after. Any failure/interruption retains exclusive failed JSON;
retry into fresh paths. CLI exit0 means the declared evidence gate passed, not a
service/provider promotion. Existing CUDA analyzer modes remain unchanged; new
`fused_primitive=True` requires resources and is exclusive with model/range flags.

## Retained failures, review and next gate

First plain/profile/CPU outputs passed, but full trace refused initialization APIs
preceding exported analysis.startTime. An owned delayed shell-exec capture fixed
intervals but retained bash executable identity, so the exact native-name gate
refused again. Both full rejected captures/reports/logs and source snapshots remain.
Final native collector adds only checked pre-CUDA startup wait; all six final builds
finish before fresh serial direct captures/CPU checks. No timestamp/name editing,
validator weakening, inference change or kernel math change. Normal authenticated
original service remains ready/prefill4/cpu_offload0.10 source and8 resource hostile
contracts, existing legacy gates and190-case master pass; CI compiles optional probes
and separately proves portable contracts. Physical proof is the retained capture.

Next earn default-disabled whole-model small-score selection with original4 actual
source binary/full logits/IDs/cache/counters/own bits and unchanged independent
zero-GPU CPU budgets before any runtime integration. Keep scalar decode on original
attention, and earn generation/replay/controls/tracing separately. Broader context,
device/concurrency/soak/production32/provider lead remains open. Task MD precedes
implementation. [Complete evidence](README.md).
