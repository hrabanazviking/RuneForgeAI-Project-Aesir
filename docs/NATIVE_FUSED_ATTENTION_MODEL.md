# Explicit fused-attention full-model gate

The optional strict3B fixture now has a default-disabled `fused_attention`
capability and explicit execution strategy4. It requires precision0, batched
rotary/cache, elementwise and down128 before loading the model. Enabled control
or tracing capabilities refuse at construction. Each step validates those flags
before sampler, owner or GPU mutation. Existing strategies0..3 and the live
native one/four-token policy retain their established paths.

At count4/32, ordered batched RoPE and F16 cache writes precede the checked fused
wrapper using actual canonical query/attention spans and the owned layer cache.
Count1 uses original scores/softmax/value kernels. No additional buffers or global
score workspace are allocated. `fused_attention_calls` counts successful fused
enqueues; `original_attention_queries` counts actual original per-query dispatch.
Both reset with the existing fixture counters. Controls and tracing stay closed,
and sealed replay4 requires the separate explicit
[owning-context gate](NATIVE_FUSED_ATTENTION_CHECKPOINT.md).

## What has physically passed

Four public30/37/31/1070-token prompts export all513024 values per native and
matrix owner. Every current native/matrix F32 byte, input ID and full176160832-byte
guarded F16 cache hash matches independently accepted strategy3 exactly. Own
fresh repeats check UInt32 bits, including signed zero, outside timing. Committed
position/IDs/sampler history, eight invalid tiles and4352 guards pass. Three
control/start/trace refusals preserve healthy state, zero counters and actual
activation/cache/weight allocation pointers. Three invalid constructor flags
refuse before opening a nonexistent model or announcing CUDA.

The pinned original-weight-derived F32 CPU model reruns all full-vocabulary
outputs with zero GPU layers, F16 KV, context4096 and batch128. NumPy2.4.4 /
llama-cpp-python0.3.23 and the loaded library SHA own that independent scope.
Fixed .05 absolute / .005 RMS / equal full-vocabulary argmax budgets remain.
Worst matrix CPU error is `0.0215983390808` absolute / `0.00398676536648` RMS.

| Input tokens | Native prefill median s | Optional fixture median s | Native / fixture | Fused launches | Original attention queries |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 30 | 0.329376 | 0.322989 | 1.019773 | 196 | 56 |
| 37 | 0.392326 | 0.216815 | 1.809493 | 56 | 28 |
| 31 | 0.352122 | 0.346924 | 1.014981 | 196 | 84 |
| 1070 | 12.745564 | 6.212869 | 2.051478 | 1008 | 56 |

These exploratory medians compare the current native production-four reference
with the new optional fixture in the same capture. One unscored warm/export pair
precedes three alternating fresh pairs for each case; all32 records remain.
Allocation, export, cache hashing, GPU process and CPU oracle duration are
unscored. The previous strategy3 capture supplies exact state/quality evidence,
not a cross-capture speed comparator. This establishes neither production32 nor
an Ollama lead, decode speed, concurrency or sustained thermal superiority.

## Human and AI operator procedure

Use a prepared locked Mojo1.0.0 / MAX26.5.0 checkout with the original registered
strict3B GGUF, its SHA, a verified test-only F32-expanded GGUF and its derivation
receipt. The derivative serves only the CPU oracle and never replaces runtime
weights. Provide the complete independently accepted strategy3 CSV/report.
Finish both targets, baseline/legacy3 probes, master and normal build/check before
serialized GPU capture, then CPU validation. Use a fresh private directory and
exclusive creation; the shell redirection example can overwrite existing files.
Record source/binary/model/CSV/report/derivation identities before and afterward.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_fused_attention_model.mojo \
  -o "$ARTIFACTS/fused-model"
timeout 360 "$ARTIFACTS/fused-model" "$MODEL" > "$ARTIFACTS/complete.csv"
"$ORACLE_PYTHON" scripts/check_turing_model_prefill.py "$ARTIFACTS/complete.csv" \
  --fused-attention --binary "$ARTIFACTS/fused-model" --binary-sha256 "$BINARY_SHA" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-model "$REFERENCE_MODEL" --reference-sha256 "$REFERENCE_SHA" \
  --reference-provenance "$REFERENCE_PROVENANCE" \
  --reference-csv "$BASELINE_CSV" --reference-report "$BASELINE_REPORT" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_fused_attention_model.py
```

The marker `ATTENTION,rope_cache_elementwise_down128_fused,1,32`, original META,
`ADMISSION,4,3,0` and actual `FUSED_ATTENTION` counters are mandatory. Pure plan
counts produce fused196/56/196/1008 and original queries56/28/84/56. Original
RoPE/cache756/252/840/3192, elementwise1261/421/1401/5321 and down0/28/0/924 remain.
Only explicit model `--fused-attention` admits this capture. Default shared
model/metadata/decode/checkpoint/control/trace readers keep refusing4. The flag
requires actual strategy4 plus exact probe binary SHA before and after validation.

The predecessor must bind complete parsed CSV to strict duplicate-free JSON,
original model, fixed CPU scope and every independent/numerical metric, full
IDs, source byte/cache proof and actual counters. Older pre-capability strategy3
reports may omit `control_capable` only for a parsed disabled default; enabled
or mismatched declarations refuse. All current/source/model/derived-model/
derivation/binary hashes are checked after oracle work. Exclusive failed reports
retain full metrics and clear all medians/ratios atomically on source, numeric,
interrupt, hash or finite-score failure.

Seven new adversarial contracts and legacy model/grid/down/decode/replay/control/
trace contracts pass; master190 passes/zero failures/one explicit skip. The first
GPU/CPU run passed quality and source state. Final audit added mandatory binary
identity in the checker and a supervisor pre/postflight record, followed by a
fresh capture/oracle on the same unchanged compiled native source. The first
full report/timings remain preliminary. A portable mock initially changed a
binary digest to the same expected value; failed source/log remain, corrected
mutation now exercises rejection. No failed/preliminary artifact was overwritten.

## Remaining acceptance gates

This is optional full-model prefill, context1536/F16KV/one observed sm75 device.
Earn source-bound greedy/seeded causal decode, owning-context replay and enabled
cooperative controls for strategy4 before broader runtime selection. Tracing,
wider contexts/devices, persisted recovery, concurrency, memory/thermal soak and
refreshed equal-work provider comparisons remain separate. Keep the original
single-token attention path, avoid multiplying primitive ratios, and publish a
Task MD before the next change. Read [primitive ownership](NATIVE_FUSED_CAUSAL_ATTENTION.md)
and [prior model acceptance](NATIVE_TURING_DOWN_MODEL.md). The live authenticated
prefill4 service stays ready with unchanged f3442a1e binary. Exact CI/push receipts
are separate from physical numerical acceptance.

Explicit cooperative fused_controls capability now has a separate
[control and reset recovery gate](NATIVE_FUSED_ATTENTION_CONTROLS.md). Ordinary
source/default4 profiles and control-capable4 sealed replay remain separately gated.

Exclusive fused_tracing capability now has a separate
[owned attention/projection trace gate](NATIVE_FUSED_ATTENTION_TRACE.md).
Ordinary4/control4 profiles stay separate; trace-capable4 control/replay remains closed.
