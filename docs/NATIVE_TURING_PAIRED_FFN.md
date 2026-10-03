# Optional paired FFN gate/up projection

This isolated native Mojo experiment shares one padded F16 input tile across
two same-kind packed matrices. Each CTA computes 64 rows from each matrix with
eight warps / 256 threads. Separate high/residual weight halves retain the
original compile-time 32-column quantization and chronological F32 MMA arithmetic.
Both barriers and every consumed shared cell remain initialized for row/token
tails. The maximum defined shared array size is 19,008 bytes at batch 32;
this source count does not establish captured occupancy or register use.

`core/packed_turing_pair.mojo` owns `admit_pair` and `project_turing_pair`.
Admission checks both original matrix spans, then rejects overlapping packed
weight spans and output spans before any GPU operation. Same-kind Q4/Q5/Q6
(`12/13/14`) and batches 4/8/16/32 only. The original kernels, normal dispatch,
workspace and authenticated prefill-4 service remain the established reference.

## Measured decision

Both complete outputs match the original staged kernels bit for bit, including
signed zero. All 983,040 F32 values per native/candidate/original owner pass fixed
0.002 maximum scaled error and 0.0002 normalized RMS gates. A separate pinned
GGUF/NumPy oracle checks 600 selected Float64 dots from original strict-3B Q4
gate/up weights. The input is a deterministic pattern checked natively at every
input cell; this experiment does not export actual model activations. The 144
synthetic same-kind Q4/Q5/Q6 tail pairs are distinct from the real Q4/Q4 pair.
All 12 hostile span refusals and 6,720 unowned real cells pass. Full input-cell
checks are additional to that guard count.

| Batch | Native pair median ms | Original staged pair median ms | Paired median ms | Native / paired | Original staged / paired |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 0.81062 | 3.07007 | 2.70184 | 0.300025 | 1.136289 |
| 8 | 1.04059 | 1.82810 | 1.89619 | 0.548782 | 0.964093 |
| 16 | 2.13310 | 1.94203 | 2.26234 | 0.942874 | 0.858415 |
| 32 | 4.38165 | 2.45131 | 3.14980 | 1.391089 | 0.778242 |

Ratios greater than one mean lower paired elapsed time. Each median retains ten
rotated samples, with three actual pair calls and synchronization per sample;
all 120 timing records remain. Allocation, warmup, export, build, process and
CPU-oracle durations are unscored. The batch-4 pair beats two staged launches,
but the native pair is faster there. At batch 32 the existing staged pair is
faster. No batch beats both available comparison owners, so this candidate earns
no selection or model/provider speed claim. Next work targets causal attention.

## Build and reproduce

Prepare the locked Mojo 1.0.0 / MAX 26.5.0 checkout and original strict-3B model.
Finish sm_75, sm_89, original/header probes, master, normal and launch checks
before serialized GPU work. Use a new private artifact directory; supervised
exclusive file creation owns acceptance because shell redirection can overwrite.
Record model, binary, source and CSV hashes plus UTC build/process receipts.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_paired_ffn.mojo \
  -o "$ARTIFACTS/paired-ffn"
"$ARTIFACTS/paired-ffn" "$MODEL" > "$ARTIFACTS/complete.csv"
"$ORACLE_PYTHON" scripts/check_turing_paired_ffn.py "$ARTIFACTS/complete.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --binary "$ARTIFACTS/paired-ffn" --binary-sha256 "$BINARY_SHA" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_turing_paired_ffn.py
```

The native CLI validates usage and twelve span defects before model/CUDA access.
The checker requires gguf 0.19.0 / NumPy 2.4.4, exact descriptors and disjoint
weights, finite exact F32 values, ordered complete output ownership, exact
guards/timing rotation/totals and model/binary/CSV identity before and after
validation. Bounded no-follow regular-file CSV admission rejects special files.
JSON uses exclusive creation; malformed, interrupted, changed-artifact or full
numerical failures retain a failed report and clear every ratio atomically.
Per-call underflow and nonfinite ratio overflow also withhold scores.

Ten portable adversarial contracts pass; hosted compile proves compilation only.
The physical master suite passes 190 cases, zero failures and one explicit skip.
All seven builds finished before the physical GPU capture. The first CPU checker
run rejected a mistaken guard formula (125 fixed cells instead of 112). The
failed report, checker/test sources and log remain. Corrected portable contracts
pass and the same unchanged GPU CSV was independently revalidated into a new
exclusive report. No failed evidence was overwritten or scored.

## Boundaries for human and AI operators

Keep this opt-in primitive separate from production selection. It proves neither
actual FFN activation inputs nor whole-model causal logits, generation, replay,
enabled controls, tracing, wider contexts/devices, concurrency or soak stability.
Python is a test oracle, never a production/provider fallback. Preserve complete
failures and both comparison owners; avoid comparing medians across captures.
Read [the prior runtime-loop rejection](NATIVE_TURING_LOOP_STAGING.md) and the
roadmap before proposing another kernel. Publication and exact CI receipts are
separate from numerical acceptance.
