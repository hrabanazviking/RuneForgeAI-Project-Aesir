# Optional small-score full-model prefill

Explicit strategy5 is a default-disabled test fixture for the exercised strict
Llama3.2 3B/sm75/context1536/F16 KV/original activation precision0. It uses the
[accepted small-score primitive](NATIVE_SMALL_FUSED_ATTENTION.md) for actual four
and32-token attention tiles after existing rotary/cache writes. Scalar decode and
single-token tails keep original attention. Original4 remains available; no normal
model/service selector changes. Python, NumPy and llama.cpp are test-only oracles.

## Capability and mutation-free refusal

Final `TuringPrefillFixture(...,small_attention=False)` requires original fused4,
down128, batched rotary/cache and batched elementwise with precision0 when enabled.
It excludes fused control/trace capabilities. Constructor admission precedes model
loading; runtime flag admission precedes sampler/tile mutation. Existing0..4 default
interfaces and separate accepted control/trace/replay4 policies remain available.
`execution_strategy()` reports5 only for the small capability. Actual
small_attention_calls and fused_attention_calls are separate and reset together;
old batched fused calls must be0 under5. Original scalar query counts remain.

Enabled controls, tracing and sealed replay5 require separate acceptance. Restore
rejects small mode before reading/resetting owner/sampling state, even for a valid
native-owner replay plan. Native collector proves12 live feature refusals: configure/
start control; tracing, foreign control/trace flags; missing fused/down/rotary/
elementwise flags; and valid-plan replay. All preserve owner pointers, empty IDs,
positions/samplers/health/control state and zero actual counters. Eight existing
invalid tiles additionally preserve owning state and guards. Six hostile constructor
combinations and unsupported CLI refuse before model/CUDA; no silent fallback.

## Complete model and accepted source identity

Separate `test_small_attention_model.mojo MODEL.gguf` exports the explicit marker
`ATTENTION,rope_cache_elementwise_down128_small,1,32`, original META scope and
ADMISSION5,12,0. Every public30/37/31/1070 case retains128256 original native-four
and small-matrix F32 logits, exact committed input IDs, own fresh-repeat UInt32 bits
including signed zero,1088 guards, full176160832-byte guarded F16 cache SHA and
actual rope/elementwise/down/small/original/closed-fused counts. All513024 values
per owner and4352 guards pass.32 rotated records retain warm/export pair plus
three measured fresh pairs per case. No precision budget was tuned after capture.

The shared model reader requires explicit exclusive `allow_small=True`; CLI requires
--small-attention, actual current binary/SHA and accepted default4 source CSV/report/
binary. Existing readers, decode/control/replay consumers and source loaders reject5
by default. Source must prove all full four-case fixed native/independent CPU quality,
prior3 byte/cache/ID acceptance, exact current source binary identity, disabled
control scope and actual plan counts. An accepted Boolean alone cannot admit source.
Every current native/small F32 byte, full guarded cache and input ID equals the
complete source4; current small call counts equal source4 fused calls, scalar/down/
rotary/elementwise counts agree and old fused count0 is mandatory. Signed zero
or a single altered ID/cache byte/output/count withholds acceptance.

The pinned independently derived F32-expanded model is rerun on zero GPU layers
through llama-cpp-python0.3.23/NumPy2.4.4, context4096/F16 KV/batch128/four CPU threads.
All current native and small logits pass fixed.05 maximum absolute/.005 RMS and
matching full-vocabulary argmax. Current native comparison also passes these fixed
budgets; every own fresh repeat is bit-identical. Full source coverage carries
accepted original4 quality while the independent rerun checks current complete
outputs anew. This proves these prompts on this device; broader quality stays open.

## Same-capture original native-four versus small fixture

| Input tokens | Small calls | Old fused calls | Original scalar queries | Native-four seconds | Small fixture seconds | Native-four / small |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 30 | 196 | 0 | 56 | 0.328281 | 0.321391 | 1.021437 |
| 37 | 56 | 0 | 28 | 0.390034 | 0.215724 | 1.808019 |
| 31 | 196 | 0 | 84 | 0.351308 | 0.344461 | 1.019877 |
| 1070 | 1008 | 0 | 56 | 12.639716 | 5.948031 | 2.125025 |

These are synchronized isolated fresh-prefill medians after the first warm/export
pair, one physical exploratory session. They compare the current original native
four-token path with the current small-score matrix/rotary/elementwise/down fixture.
They do not compare historical4 to new5, certify an Ollama lead, request latency or
production policy. Keep all32 samples; export/allocation/build/process/CPU durations
are unscored. Do not combine this ratio with primitive speed ratios.

## Reproduce from prepared artifacts

Read [the original default4 source](NATIVE_FUSED_ATTENTION_MODEL.md). Choose a new
private output directory, actual MODEL/MODEL_SHA, derived REFERENCE_MODEL/REFERENCE_SHA/
REFERENCE_PROVENANCE, current BINARY_SHA and source SOURCE_CSV/SOURCE_REPORT/
SOURCE_BINARY. The source binary must be the actual accepted4 executable, not a
new binary compiled from changed sources. Preserve originals rather than rebuilding
into their paths. Finish current75/89/original model/primitive/master/normal/check
builds before GPU. Serialize GPU then independent CPU work; never edit native code
or compile during capture. Record all source/binary/model/CSV/provenance hashes and
UTC process receipts. Supervisor creates stdout/stderr exclusively, kills/reaps its
owned process group on timeout/interruption and keeps every partial failure.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine   --target-accelerator sm_75 aesir_engine/tests/test_small_attention_model.mojo   -o "$ARTIFACTS/small-attention-model"
"$ARTIFACTS/small-attention-model" "$MODEL" > "$ARTIFACTS/complete.csv"
"$ORACLE_PYTHON" scripts/check_turing_model_prefill.py "$ARTIFACTS/complete.csv"   --model "$MODEL" --model-sha256 "$MODEL_SHA"   --reference-model "$REFERENCE_MODEL" --reference-sha256 "$REFERENCE_SHA"   --reference-provenance "$REFERENCE_PROVENANCE"   --reference-csv "$SOURCE_CSV" --reference-report "$SOURCE_REPORT"   --reference-binary "$SOURCE_BINARY" --small-attention   --binary "$ARTIFACTS/small-attention-model" --binary-sha256 "$BINARY_SHA"   --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_small_attention_model.py
```

The native command takes exactly MODEL.gguf. Shell redirection can overwrite; use
fresh paths or the exclusive supervised collector. Unsupported extra arguments and
six reject-* constructor probes fail before model access. Checker requires bounded
regular no-follow CSV/JSON, strict mode/admission/complete ordered vectors/counters/
cache/timings, source fixed scope and duplicate/nonfinite JSON refusal. Current/source
binaries, original/derived models, current CSV, source CSV/report and expansion
provenance bind before/after. Complete numerical/byte/cache/source/hash/nonfinite
ratio failure retains full metrics and atomically removes all medians/ratios.
KeyboardInterrupt retains an exclusive failed JSON. Retry into a new path.
CLI exit0 establishes the declared fixture gate, not runtime readiness for strategy5.

## Review, evidence and next gate

Task541cb27 preceded code. Seven new portable adversarial contracts and existing
model/source/decode/replay/control/trace/primitive gates pass; master190/one skip,
all seven builds before serial physical GPU/CPU and complete artifact fences pass.
The first reduced hostile tests referred to absent value text; corrected exact
fixtures assert each mutation exists, with failed log/source preserved before
physical work. Full original/native kernel math and service binary remain. The
normal authenticated service stays ready/prefill4/cpu_offload0.

Next earn causal greedy/seeded full-vocabulary generation/state/native-forced IDs/
independent CPU quality, then owning-context sealed replay and enabled cooperative
controls/tracing separately. Before normal selection, earn bounded runtime/context/
device/concurrency/soak and refreshed fair provider comparisons. A planning roadmap
and narrower accepted fixture do not finish the speed objective. Publish Task MD
before code, retain failures and exact pushed-commit CI receipts.
[Complete evidence](evidence/small-attention-model-2026-10-03/README.md).

### Subsequent generation gate

[Explicit source-bound causal generation5](NATIVE_SMALL_ATTENTION_DECODE.md) now
passes all96 full frames/fixed CPU/own bits/state/source vectors/counts. Old readers
stay closed; the separate accepted-small helper requires explicit capability and
actual source binary. Next sealed replay5; all broader acceptance stays open.
