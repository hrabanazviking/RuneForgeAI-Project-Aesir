# SPD-03 — smaller bounded fused attention score storage

Established 2026-10-03 before code under Volmarr's standing next-slice/push/repeat
authorization. Owned fused trace12dc782 exact36-step CI passes. Token partition
890ad08 passes complete four primitive bit/numeric/oracle/exact guard/finite timing
gates, is pushed and awaits exact CI; no canonical batch32 FFN variant beats both
comparison owners. Existing selected kernels remain. Long fused4 tracing attributes
13.4658% of summed kernel durations to attention and records46 registers/thread/
16384 static shared bytes. This is observed resource data, not occupancy/spill cause.

The original fused kernel reserves4096 F32 scores, while the accepted whole-model
profile's visible window never exceeds1536. Add a separate optional native Mojo
small-score module with exactly1536 F32 shared cells, preserving the original
module/API/kernel and model/control/replay/trace/runtime selection. Reuse original
24/8/128 GQA dot/warp reductions, max/exp/normalization and chronological four-value
F32 accumulation; both barriers and owned allocation/stride/KV guards remain.
Original checked capacity1..4096 stays; additionally require prefix+tokens<=1536
before enqueue, independently of actual KV capacity. Thus actual capacity4096 can
serve a bounded visible1536 window. No global workspace, precision/toolchain change,
backend fallback or automatic runtime selection. Over-window input refuses safely.

New direct primitive collector owns exclusive regular0600 CSV and actual PID, and
compares original16KiB fused kernel against new small-score kernel in the same
CUDA context/session. All33 deterministic cases cover batches1/4/32, visible ends
1/31/32/33/37/255/256/257/1070/1535/1536, zero/dyadic/large-logit modes and actual
KV capacity4096 at the1536 endpoint. Retain all complete original/candidate F32
values and actual UInt32 bits including signed zero, full immutable query/KV cells
and exact whole allocation guards (including unused old global score area).
Seventeen hostile pure refusals include original16 and visible1537 overflow.
New mode/PID/dispatch/count/state/completion metadata is strict/default-closed.
Independent NumPy2.4.4 Float64 causal attention covers every output under unchanged
.002 scaled/.0002 normalized RMS budgets. Every660 rotated warmed three-repeat
host-monotonic launch+synchronize record must be finite-positive. Any bit/numeric/
hash/nonfinite ratio failure retains complete metrics and atomically clears all
ratios. Bind actual current binary/code/CSV before/after; exclusive JSON retains
failed/partial/interrupted evidence. No model/provider ratio from a primitive gate.

Separately collect full unscored cuda Nsight capture from the identical binary into
new native-owned CSV, then matching2023.4 importer/export. Original logs/raw qdstrm/
SQLite survive. Extend full-session CUDA analyzer behind an explicit fused-primitive
resource flag exclusive with owned model projection/attention flags and requiring
recorded resources. Default schemas/admission stay. Validate all process/GPU/time/
successful launch/correlation/resource/copy rows before resource distributions.
Bind actual profiled PID, binary and full profiled vector/input/guard/case scope;
full profiled F32 bits must equal plain capture. Profile timings are unscored.
Source-derived complete kernel counts are1089 per wrapper (33 launches per case),
exact original/small prefixes, grid24xactual_tokensx1/block128x1x1, static shared
16384/6144 and dynamic0. Validate recorded integer resources over all rows, then
source token-count distribution and one-to-one successful correlations. Retain
all recorded fields/durations without an occupancy/spill/cause/speed claim.

Finish current sm75/sm89, original primitive, master and normal build/check before
serial plain/full-profile GPU work, then serial CPU/source/resource validation.
No native edits or compilation during physical work. Portable hostile source/mode/
PID/count/geometry/F32/guards/timing/hash/interrupt/exclusive/full-session resource/
correlation tests join CI; legacy trace/primitive/model/decode/replay/control gates
remain. Publish detailed MD/manual/owners/retained evidence/TODO/roadmap/ledger/
devlog, verify unchanged authenticated normal prefill4 readiness, commit/push/exact
CI. If bounded attention improves, next earn actual full-model source/cache/ID/
CPU/counters acceptance before selector integration. Broader context/device/control/
replay/concurrency/soak/provider leadership stays open.

## Capture refinement after the first complete vectors

Initial plain/profile captures and both complete NumPy validations pass. The full
trace validator rejects initial runtime calls at449ms preceding exporter analysis
start610ms. Every2178 kernel fits the interval; do not weaken full runtime bounds.
Retain original raw capture, rejected JSON, logs, source snapshots and all fences.
Repeat into a fresh private directory from unchanged native binaries after the
profiler starts an owned shell that waits one second then execs the exact native
collector. This delays CUDA initialization within the complete capture interval,
without partial-range triggers or changing math/native/runtime. The actual native
PID remains mandatory. Bind observed small wrapper prefix ending_sma explicitly.
All builds remain completed before fresh serial plain/profile GPU and CPU gates.

The shell-exec capture fixes interval containment but fails exact executable
identity because Nsight retains bash process naming. Retain that second capture
and refusal too. Final collector waits one second through checked native usleep
(after pure admissions/CSV reservation, before context), outside all warmed timing
samples. Keep argc2 and all mode/output/math contracts. Directly profile the actual
collector; rebuild all six gates before fresh serial plain/profile/CPU runs.
