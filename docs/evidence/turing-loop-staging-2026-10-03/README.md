# Bounded runtime-group32-column staging

The new optional core/packed_turing_loop.mojo retains the proven32-column padded
shared width and loops over exactly eight groups per256-value packed block.
Original packed_turing_matrix and packed_quantization definitions remain verbatim.
The private compute path's runtime-group helper mechanically preserves original
Q4/Q5 scale*q and Q6 d*scale*q arithmetic, machine-width addressing and bounded
Int32 quant fields. kind12/13/14 is compile-time; group0..7/lane0..31 come from
internal kernel loops, not untrusted user inputs. Both barriers/all warps, high/
residual F16 conversion and chronological F32 public MMA remain. Rows64/128,
batches4/8/16/32 and precision0 only; threads128/256 and defined maximum shared
10560/19008 bytes stay. No new global workspace or service import/selection.

This tests an instruction replication/loop hypothesis, not a claim of lower
register use, occupancy, resource cause or speed. Dynamic addressing/branches can
cost more; physical timing owns the decision. Its final loop_rows=0 primitive
harness extension is exclusive with cached/large/narrow paths and keeps defaults.
New mode metadata is turing_mma_staged_loop_f16_f32,rows64|128,32. Every original
native/candidate/original64 F32-bit/guard/independent/840 timing gate still applies.
The original comparison owner is64/32 even for128 candidates; do not score a
cross-capture comparison against an earlier128/32 kernel.

## Build and operate

Use a locked prepared checkout with the original packed model and enough VRAM
headroom; finish all final target/original/header/master/normal/check builds first.
Use an exclusive private artifact directory and serialized GPU probes. Both GPU
captures finish before pinned test-only GGUF/NumPy selected-dot oracles. Keep all
binary/model/CSV/source/UTC process/build hashes, stderr and failed evidence.
The live authenticated prefill4 service stays unchanged.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_loop_staging.mojo \
  -o "$ARTIFACTS/aesir-turing-loop-staging"
"$ARTIFACTS/aesir-turing-loop-staging" "$MODEL" 64 > "$ARTIFACTS/rows64.csv"
"$ARTIFACTS/aesir-turing-loop-staging" "$MODEL" 128 > "$ARTIFACTS/rows128.csv"
"$ORACLE_PYTHON" scripts/check_packed_matrix.py "$ARTIFACTS/rows64.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" --output "$ARTIFACTS/rows64.json"
"$ORACLE_PYTHON" scripts/check_packed_matrix.py "$ARTIFACTS/rows128.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" --output "$ARTIFACTS/rows128.json"
```

Redirection can overwrite existing paths; supervised exclusive creation and a new
private directory own actual acceptance. The native CLI rejects unsupported rows
before model/CUDA; the validator owns exclusive JSON creation and bounded/no-follow
regular CSV/model hashes. Python supplies no production inference; pinned gguf0.19/
NumPy2.4.4 only decode original real weights and compute selected Float64 dots.

Each configuration passes144 synthetic Q4/Q5/Q6 tail cases/12 span refusals,
all1658880 real native/candidate/original outputs,2100 independent dots and1622640
guards under unchanged .002 scaled/.0002 normalized RMS. Actual candidate/original
UInt32 F32 bits must match including signed zero. Full ten rotated samples per
28 case retain three actual calls per native/candidate/original owner plus sync;
allocation/export/process/oracle are unscored. original_to_candidate_ratio >1
means lower elapsed than original64. Every source/complete numeric/bit failure,
interrupt, per-call underflow and nonfinite ratio withholds all scores atomically.
Twenty-two portable contracts preserve previous schemas; hosted compile never
proves GPU execution. Full raw evidence is retained.

## Measured result

Both numerical gates pass, but all56 measured original64 timing comparisons lose.
The loop candidate earns no selection. Keep original width/loop implementation;
no observed register/occupancy cause or hypothetical fix is inferred. Next scope
paired FFN gate/up input staging reuse under complete byte/span/timing gates.
Actual F32/full-model/decode/replay/control/context/device/concurrency/soak/
production32/refreshed-provider gates remain separate. Read the retained evidence
and [prior narrower rejection](../../NATIVE_TURING_NARROW_STAGING.md) before new work.

## Complete same-capture primitive timings

| Candidate rows | Batch | Q | K | V | Output | Gate | Up | Down |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 64 | 4 | 0.7661 | 0.7725 | 0.7183 | 0.7759 | 0.8105 | 0.8050 | 0.7483 |
| 64 | 8 | 0.7027 | 0.6456 | 0.7753 | 0.6994 | 0.6560 | 0.6558 | 0.7698 |
| 64 | 16 | 0.6975 | 0.5638 | 0.6989 | 0.6921 | 0.5526 | 0.5607 | 0.7124 |
| 64 | 32 | 0.6097 | 0.5236 | 0.7192 | 0.6498 | 0.4695 | 0.4693 | 0.7293 |
| 128 | 4 | 0.7405 | 0.6371 | 0.5563 | 0.7622 | 0.7285 | 0.7280 | 0.7656 |
| 128 | 8 | 0.6995 | 0.5461 | 0.6388 | 0.6969 | 0.5992 | 0.6026 | 0.8061 |
| 128 | 16 | 0.6706 | 0.4867 | 0.5996 | 0.6592 | 0.5529 | 0.5600 | 0.7776 |
| 128 | 32 | 0.6703 | 0.5156 | 0.6748 | 0.6248 | 0.5196 | 0.5178 | 0.8262 |

Best original64/candidate ratio0.826220 atrows128/batch32/blk.0.ffn_down.weight; 0 of56 cases exceed1. All56 lose; no promotion. All samples remain. Exact push/CI receipts are separate.
