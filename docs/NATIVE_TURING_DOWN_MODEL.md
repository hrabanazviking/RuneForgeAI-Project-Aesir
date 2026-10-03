# Complete model gate for down-only128 staging

The new isolated strategy3 passes four complete public prefill cases through1070
input tokens. All native/matrix vocabulary outputs, committed IDs and full guarded
cache bytes match independently accepted elementwise strategy2. In the new paired
run, long native/fixture medians12.66775/6.80087 seconds give1.86267× exploratory
prefill speed. This compares native and new fixture in the same run; it does not
measure old2/new3 speed or an Ollama lead. [Physical evidence](evidence/turing-down-model-2026-10-02/README.md).

## What changes and what is admitted

`TuringPrefillFixture` adds `down128=False` and `down128_calls`. True requires
original precision0 plus batched rotary/cache and elementwise flags before model
load and every step. It identifies execution strategy3. Only matrix/count32/stage
FFN down can select128, binding a loaded down tensor's offset/kind/shape and
canonical up/temporary spans. The counter increments after successful enqueue and
resets with fresh fixture state. Gate/up/Q/output stay original64; K/V and four/
scalar tails retain native references. There is no additional device workspace or
production selection. The candidate shares at most19008 bytes across256 threads.

Ordinary strategy3 refuses enabled controls and projection tracing before GPU
or owner mutation. Explicit [control capability](NATIVE_TURING_DOWN_CONTROLS.md)
now has a separate cooperative recovery gate; tracing remains closed. [Decode/sample](NATIVE_TURING_DOWN_DECODE.md) and [sealed owning-context
replay](NATIVE_TURING_DOWN_CHECKPOINT.md) now have explicit source-bound gates.
Default shared metadata readers keep refusing3; explicit decode/checkpoint
validation requires its complete accepted source. Production defaults stay unchanged.

`test_turing_down_model.mojo MODEL` explicitly selects strategy3. It reuses the
original four public30/37/31/1070 prompts, full128256-value vectors per case/owner,
exact committed IDs/positions/history and all4352 guards/eight invalid tiles.
Fresh-repeat comparisons now use actual F32 bits, including signed zero, outside
timing. The collector exports full176160832-byte guarded-cache hashes, unchanged
rotary/cache/elementwise host counts and actual down counts0/28/0/924. Actual
pre-step control/trace refusals remain healthy and preserve empty owner state.
A test-only `reject-flags` argument exercises constructor rejection with a
nonexistent model path before opening the model or announcing CUDA.

## Reproduce

Use original registered GGUF bytes and explicit SHA256. A prepared test-only
F32-expanded model, its checksum and checked derivation receipt are required for
the independent CPU reference. This derivative never replaces runtime weights.
Provide the explicitly independently accepted strategy2 complete CSV/report.
Use pinned NumPy2.4.4/llama-cpp-python0.3.23 with zero GPU layers, context4096,
batch128 and F16 KV for the oracle.

Use new private artifact paths outside Git. Finish both target builds, baseline
collector, master and normal build/check before serial GPU capture; CPU work
follows. Preserve failed attempts and their source/binary/process/partial evidence.

```bash
: "${ARTIFACTS:?set new private directory outside Git}"
: "${MODEL:?set original registered GGUF path}"
: "${MODEL_SHA:?set original lowercase SHA256}"
: "${REFERENCE_MODEL:?set test-only F32-expanded GGUF}"
: "${REFERENCE_SHA:?set its verified SHA256}"
: "${REFERENCE_PROVENANCE:?set checked original-to-F32 derivation JSON}"
: "${BASELINE_CSV:?set independently accepted strategy2 CSV}"
: "${BASELINE_REPORT:?set its accepted JSON report}"
: "${ORACLE_PYTHON:?set prepared test-only interpreter}"
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_down_model.mojo \
  -o "$ARTIFACTS/down-model-probe"
# Finish the other builds before this serial capture.
timeout 360 "$ARTIFACTS/down-model-probe" "$MODEL" \
  > "$ARTIFACTS/complete.csv" 2> "$ARTIFACTS/stderr.txt"
"$ORACLE_PYTHON" scripts/check_turing_model_prefill.py \
  "$ARTIFACTS/complete.csv" --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-model "$REFERENCE_MODEL" --reference-sha256 "$REFERENCE_SHA" \
  --reference-provenance "$REFERENCE_PROVENANCE" \
  --reference-csv "$BASELINE_CSV" --reference-report "$BASELINE_REPORT" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_turing_down_model.py
```

## Admission and interpretation

The distinct marker is `ATTENTION,rope_cache_elementwise_down128,1,32`, followed
by original META and `ADMISSION,3,2,0`. New captures require final newline. Every
source-derived DOWN_ROWS128, ENQUEUE and ELEMENTWISE count, full vector, actual
state/input IDs, cache hash, repeat result, timing/guard/invalid-tile total remains
mandatory. Model parse admits3; other consumers keep default refusal unless their explicit
source-bound decode/checkpoint gate is selected.

The strategy2 source must have matching model/CSV/report identities, fixed full
CPU numerical scope/values/argmax/budget, exact zero-GPU F32 reference declaration,
all native comparisons/IDs/counters/cache and complete totals. The current native/
matrix F32 bytes and cache identity must match every source case. Independent
new native/matrix .05 maximum/.005 RMS and equal full-vocabulary argmax gates are
unchanged. Original/derived models, derivation receipt, current CSV and accepted
source CSV/report rehash after CPU validation.

Timing has one unscored warm/export pair and three alternating fresh pairs per
case. All32 records remain. Scores publish only after every full numerical/source/
state/cache/repeat gate. Ratio calculation is atomic: nonfinite ratios, numerical
or source failures clear all scores, including previously computed case medians.
Partial/structural/interrupted failures remain unsuccessful in exclusive JSON;
existing reports are never overwritten. Eight portable contracts cover metadata/
counters/source/failure/scoring behavior, without claiming GPU execution.

The passing narrow strategy remains opt-in. Decode/sample trajectories and sealed
owning-context replay now have their separate explicit gates; enabled control
recovery now has an explicit default-disabled capability gate. Owned strategy3
projection tracing is next. Broader contexts/devices/concurrency/soak and refreshed provider
comparisons remain separate. Original defaults and served policy remain available.
