# Real F32 activation gate for the narrow FFN down candidate

The 128-row primitive improves batch32 FFN down in a paired run, while gate/up
lose. This gate checks precision with captured operands from two real prompts.
Only batch32 final-layer FFN down uses 128 rows. Every other selected projection
uses original 64-row staging. Runtime and model fixture selection remain governed
by their later acceptance gates. [Physical evidence](evidence/turing-down-activations-2026-10-02/README.md).

## Native collection and source identity

`test_turing_down_activations.mojo MODEL` reuses the existing normal four-token
capture routine for two public prompts, strict Llama 3.2 3B, context512, original
GGUF, no prefix cache and zero CPU offload. It captures actual replayed token IDs
and all114688 final-layer source F32 values. Each batch32 repeats four captured
vectors. Q/K/V use representative FFN-normalized operands; output, FFN gate/up/
down use their actual final-layer operands. This is a projection precision gate,
not a complete independent model execution.

The collector reuses two output spans plus a bounded host native snapshot. It
exports native/new/original F32 via Float64 text for all1990656 outputs per owner,
28 ordered cases,12 invalid spans and all input/unowned guards. No extra device
buffer or speed timing is introduced. The explicit marker is
`META,1,turing_native_f32_down_rows,128,32,12`. Only cases13/27 (batch32 down in
each state) select the admitted 128-row sibling. Its maximum shared19008 bytes/
256 threads and original packed/MMA order remain as previously gated.

## Reproduce the complete gate

Use the locked Mojo1.0.0/MAX26.5.0 environment, physical sm75 and a new private
artifact directory outside Git. Resolve original model bytes and their SHA256.
Provide an existing accepted precision0 activation CSV/report; do not rewrite its
fields to make it acceptable. The admitted source must have passed all native and
selected independent gates with the same model and full28-case coverage.

The checker uses a prepared test-only interpreter with exact gguf0.19.0/NumPy2.4.4.
It never supplies runtime inference. Finish both target builds, legacy activation
collector, master, normal build/check and other owned GPU work before capture;
run the CPU oracle afterward. Keep stdout CSV and stderr separately, with hashes
and process/build order receipts. Preserve failed captures under distinct names.

```bash
: "${ARTIFACTS:?set a new private directory outside Git}"
: "${MODEL:?set original registered GGUF path}"
: "${MODEL_SHA:?set verified lowercase SHA256}"
: "${REFERENCE_CSV:?set accepted precision0 activation CSV}"
: "${REFERENCE_REPORT:?set its accepted independent JSON report}"
: "${ORACLE_PYTHON:?set prepared test-only interpreter}"
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_down_activations.mojo \
  -o "$ARTIFACTS/down-activation-probe"
# Finish the other builds before this serial physical capture.
timeout 300 "$ARTIFACTS/down-activation-probe" "$MODEL" \
  > "$ARTIFACTS/complete.csv" 2> "$ARTIFACTS/stderr.txt"
"$ORACLE_PYTHON" scripts/check_turing_down_activations.py \
  "$ARTIFACTS/complete.csv" --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-csv "$REFERENCE_CSV" --reference-report "$REFERENCE_REPORT" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_turing_down_activations.py
```

## Acceptance and failures

The new checker admits a bounded no-follow regular CSV up to256MiB with exact
finite F32 values, final newline, ordered complete sources/values/guards/metrics/
totals and known down-only mode. It recomputes every printed metric and compares
all new/original bits, including signed zero. Every native/new/original value must
meet unchanged .002-scaled/.0002-normalized RMS budgets. Selected independent
Float64 dots cover five real rows per tensor/batch/state, totaling2520 per owner;
Q4/Q6 real tensor descriptor/offset/shape identity is checked against the model.

The accepted precision0 source report must bind the model and parsed CSV hash,
fixed totals, all28 native/independent case budgets and explicit zero precision.
Duplicate/nonfinite JSON, missing coverage or widened numerical budgets refuse.
The new capture must exactly match every prior causal state, actual F32 operand,
native output, original64 output and descriptor. Original model/current capture/
accepted CSV/report hashes recheck after validation and CPU work.

Reports always have `speed_claim=False` and `full_model_quality_claim=False`.
Complete numerical failures retain all case/original/independent metrics;
structural/partial/source-mutation/interruption failures stay unsuccessful in an
exclusive JSON. Existing reports are never replaced. Ten portable contracts prove
admission and failure handling, not GPU execution. Hosted CI compiles the opt-in collector for sm89; physical evidence owns sm75
proof.

Passing this gate earns ordinary captured-F32 projection precision. Complete
model/cache/state, decode/sample/replay/control, broader context/device/concurrency/
soak and refreshed provider comparisons remain separate before selection or a
speed-lead claim. Read the evidence for the measured outcome and publication/CI
receipts for the exact pushed revision.
