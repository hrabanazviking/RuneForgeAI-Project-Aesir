# Bounded token-partition packed Turing experiment

This optional native Mojo primitive partitions logical4/8/16/32 token rows across
CTAs with token tiles8/16 and row tiles64/128. It preserves original packed formats
12/13/14, width32 decoded high+residual weights, original F16 activation conversion,
chronological two-MMA F32 order, both shared-memory barriers and complete borrowed
span admission. One two-dimensional enqueue has gridY=ceil(actual tokens/token_tile),
disjoint per-CTA global token rows and gridX=ceil(weight rows/row_tile), block128/256.
Every shared input/weight cell is initialized before consumption, including inactive
token/row tails. No global workspace, dependency/precision change or runtime dispatch.

Read TASK_turing_token_partition.md, core/test/script ownership MD and the
[owned fused trace](../../NATIVE_FUSED_ATTENTION_TRACE.md) that measured FFN's57.1693%
share of summed long kernel durations. Fewer simultaneous accumulators are a
resource hypothesis; this primitive evidence does not measure actual occupancy,
register requirements, spills or GPU resource distributions. More CTAs repeat
weight decoding and may outweigh any live-state reduction.

## Build and admit before physical work

Use the locked prepared environment, finish all native edits, then current sm75/
sm89, original staged, original down128, master and normal build/check gates.
Retain source/binary/UTC/error receipts. Conflicting partition and legacy staged/
cached/large/narrow/loop/Turing template parameters must refuse at compilation;
the negative compilation log is evidence of refusal, not GPU execution. Preserve
initial builds and rebuild after admission changes before physical capture.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_token_partition.mojo \
  -o "$ARTIFACTS/aesir-token-partition"
"$ARTIFACTS/aesir-token-partition" "$MODEL" 64 8 > "$ARTIFACTS/rows64-tokens8.csv"
```

Run four configurations64/8,64/16,128/8,128/16 serially into new private files,
then run CPU validators serially. The shell example assumes new reserved paths;
production supervisor must open stdout/stderr exclusively, retain failed/partial
captures, impose a bounded child lifetime and terminate only its owned process group
on timeout/interruption. Unknown row/token flags refuse before model/CUDA. Never
compile/edit native source during capture or compare separate sessions as paired.
Hash original model, actual current binary and reviewed sources before/after.

## Three comparison owners and geometry

Each case retains full native four-reference, partition candidate and original
packed MMA outputs. The original MMA comparator is staged64 except canonical
down shape8192 columns/3072 rows/batch32, which uses original down128. This is the
packed MMA family comparison: actual model key/value still selects four-reference,
the separately retained first owner. Do not describe staged key/value as the model's
selected path. All original definitions remain unchanged.

CSV mode `turing_mma_token_partition_f16_f32` records row tile, token tile and
width32. Each case emits mandatory PARTITION/index/rows/tokens/gridX/gridY/blockX/
host-enqueues1 and SELECTED/index/original_rows/width32 before values. These are
source-bound wrapper dispatch records; they are not profiler-measured resources.
Missing/duplicate/late/foreign geometry/order/counters refuse. Default readers stay
closed to this new mode; old primitive schemas/defaults remain.

For each configuration require144 synthetic format/tail cases,12 bad borrowed-span
refusals,28 actual first-layer projection/batch cases/all1,658,880 values per owner,
complete guard/input/unowned tail checks, actual candidate-vs-original UInt32 bits
(signed zero included), and2100 independent selected Float64 real-weight dots.
Fixed .002 scaled/.0002 normalized RMS budgets apply independently to candidate,
native and original. Exact real-case guard/input/unowned coverage is1,622,640 cells per configuration; its source-derived count is mandatory. Dyadic input vectors do not replace non-dyadic activation/
full-model/causal state/control/replay acceptance.

## Validate and score atomically

```sh
"$ORACLE_PYTHON" scripts/check_packed_matrix.py "$ARTIFACTS/rows64-tokens8.csv" \
  --partition-tokens --binary "$ARTIFACTS/aesir-token-partition" \
  --binary-sha256 "$BINARY_SHA" --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --output "$ARTIFACTS/rows64-tokens8.json"
```

Use pinned NumPy2.4.4/gguf0.19.0 test oracle. Explicit partition mode requires actual
binary identity before/after; binary flags belong only to this opt-in. The model
and complete CSV are rehashed after CPU validation. Outputs are exclusive; retain
failed JSON/CSV/logs and retry into fresh paths. Duplicate/out-of-order/missing
values, geometry, mode, owner rotation, guards or completion refuse. Nonfinite/
nonexact F32 records, sample underflow, unsupported shapes and changed artifacts
refuse. KeyboardInterrupt produces an exclusive failed report.

All840 timing records/configuration rotate three owners, ten samples per owner/case,
three synchronized repeats after warming. Every finite-positive sample and complete
numeric/bit/guard/oracle/source hash gate must pass before any ratios are published.
Any numeric/bits/hash/nonfinite ratio failure atomically clears every case ratio
while retaining complete collected metrics; malformed/partial evidence retains raw
capture and explicit error. Ratios are original/native median divided by candidate
median: above1 favors candidate. Host-monotonic launch+synchronize timing covers one
physical session and warmed weights. Never call a primitive ratio a full-model or
provider speed lead or promote a candidate without subsequent acceptance.

## Verification scope

Seven portable hostile contracts cover four admitted geometries/default closure,
canonical down128 selection, strict marker/dispatch/stage order/counts, actual F32
signed-zero/numeric failure retention, exact guard coverage, sample underflow/rotation, all current binary/
model/CSV hashes, interruptions/exclusive output and atomic ratio overflow. Legacy
primitive/model/decode/replay/control/trace gates remain. Master190 passes/zero fails/
one skip. Hosted CI only compiles probes and tests portable evidence contracts.
Normal authenticated prefill4 service stays on its original binary. General models/
contexts/devices/production32/concurrency/soak/provider comparison stay open.

| Row tile | Token tile | Native/candidate gate32 | Original/candidate gate32 | Native/candidate up32 | Original/candidate up32 | Native/candidate down32 | Original/candidate down32 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 64 | 8 | 0.673733 | 0.368083 | 0.690221 | 0.369814 | 0.667211 | 0.406488 |
| 64 | 16 | 1.039725 | 0.558077 | 1.028922 | 0.557546 | 1.004756 | 0.623685 |
| 128 | 8 | 0.590017 | 0.318761 | 0.586412 | 0.319220 | 0.557912 | 0.347249 |
| 128 | 16 | 0.960661 | 0.513150 | 0.953349 | 0.516528 | 0.930429 | 0.578793 |

No canonical batch32 FFN candidate beats both comparison owners in this session. Keep selected kernels and retain this experiment; choose the next measured bottleneck experiment.

[Retained evidence](README.md).
