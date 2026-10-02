# Optional original packed-weight Turing matrix candidate

The physical public m16n8k8 prerequisite passes on locked Mojo1.0.0/MAX26.5.0
and RTX2060 Max-Q sm_75. This slice applies it to original Q4_K/Q5_K/Q6_K bytes,
with bounded spans and no full F16 model copy. It passes the fixed primitive
precision gate but loses every measured speed case, so inference is unchanged.

## Computation and precision

core/packed_turing_matrix.mojo owns the optional candidate. Each warp computes
16 weight rows by eight token columns; it zero-pads row/token tails and all
active lanes reach public MMA together. packed_quantization owns byte decoding.
Each decoded F32 weight becomes F16 high plus F16 residual(value-F32(high));
two public MMA calls per eight input columns accumulate in F32. Activations
convert once to F16. The actual test formula is exactly F16-representable;
arbitrary full-model activation-conversion quality is still unproved.

The initial single-component F16 candidate failed the fixed synthetic per-value
budget before real-shape timing. Preserve its source/binary/CSV and failure.
The task refinement was pushed before split-weight implementation. Budgets stay
scaled per-value<=0.002 and normalized RMS<=0.0002; they are primitive budgets,
not exact scalar parity or a full-model quality declaration.

The candidate reuses matrix span admission for actual weight/activation lengths,
columns256..14336 aligned256, rows1..128256, batch4/8/16/32, token count1..batch,
base/offset/stride bounds and disjoint input/output spans. Products are bounded
before enqueue. Only this optional DeviceFunction uses the proved sm_75/PTX6.5
target. No installed-library, driver, dependency or generated-PTX patch. No
additional device workspace is allocated by the candidate. Scalar/block/four
references and production prefill/control/recovery policy stay available.

## Reproduce complete evidence

Use the prepared frozen environment, physical sm_75 device and new private
artifact paths outside Git. Resolve the original model bytes/hash explicitly.
Finish all host compilation and other owned GPU work before scored capture:

```bash
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_packed_turing_matrix.mojo \
  -o "$ARTIFACTS/packed-turing-probe"
timeout 300 "$ARTIFACTS/packed-turing-probe" "$MODEL" \
  > "$ARTIFACTS/complete.csv" 2>&1
"$ORACLE_PYTHON" scripts/check_packed_matrix.py "$ARTIFACTS/complete.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_packed_matrix.py
```

The test reuses the existing physical harness through explicit turing=True;
existing SIMT defaults are unchanged. All 144 synthetic cases exercise three
formats, columns256/512/3072/8192, rows1/7/33 and batches4/8/16/32 with token
tails. Every input and unowned span remains unchanged. Twelve malformed spans
reject. Real layer-zero Q/K/V/output/FFN gate/up/down shapes produce all1,658,880
native-reference output pairs. The original strict3B model exercises Q4_K and
Q6_K real tensors; Q5_K coverage here is synthetic. The optional independent
gguf0.19.0/NumPy2.4.4 oracle checks five selected rows per tensor/batch, totaling
2100 Float64 dots. That selected independent coverage is distinct from complete
native coverage. No independent full-model execution belongs to this slice.

MODE,turing_mma_split_weight_f16_f32 identifies the candidate. The checker rejects
unknown/duplicate/late modes and mode/TILE mixtures; legacy SIMT CSV stays valid.
Reports distinguish16x8 MMA output geometry from SIMT staged-input columns and
hash the admitted CSV text snapshot. Complete ordered values/guards/560 timing
records/final totals and model hash are mandatory. Existing bounded regular
no-follow CSV input and exclusive failure-preserving JSON output remain. Eight
portable tests prove parser/budget contracts, not GPU support. Hosted CI compiles
the new probe and existing SIMT probes without claiming physical execution.

## Observed result and acceptance boundary

All native outputs, selected independent dots, synthetic tails and guards pass.
Worst selected independent scaled/RMS errors are approximately1.171e-5/5.077e-6.
All28 actual shape/batch cases lose. Ratios are existing four-token work divided
by this candidate; below1 means slower:

| Batch | Q | K | V | Output | FFN gate | FFN up | FFN down |
|---|---:|---:|---:|---:|---:|---:|---:|
| 4 | .178 | .094 | .077 | .172 | .193 | .196 | .147 |
| 8 | .339 | .186 | .151 | .333 | .374 | .371 | .275 |
| 16 | .373 | .274 | .230 | .375 | .404 | .414 | .377 |
| 32 | .405 | .386 | .377 | .425 | .409 | .411 | .413 |

Each case uses warmed resident weights, two warmup rounds and ten alternating
pairs with three actual calls per sample. Host-monotonic timing includes launch/
synchronize but excludes allocation/printing/export. Host compilation is idle.
All560 samples remain; no favorable subset or profiler time is scored. One
physical primitive session is not a second-session provider-lead certificate.

The kernel still decodes individual values in each warp's eight-column step.
Coalesced shared staging is the next design to measure; the current results do
not identify a hardware bottleneck without further evidence. No runtime promotion
or broader F16 quality claim follows from Tensor-Core instruction support alone.
Retain every failed attempt and complete raw CSV outside Git. Publish reviewed
hashes/summaries, rebuild launcher after Mojo edits and verify unchanged native
checksum/active readiness. Full-model logits, restore/sampling/cancellation,
context tails and paired service speed remain separate future gates.

Read [the physical MMA prerequisite](NATIVE_TURING_MMA.md),
[existing matrix gates](NATIVE_MATRIX_CANDIDATE.md) and this slice's evidence.
Exact pushed revision and CI are recorded in publication receipts.
