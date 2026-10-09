# Small-score strategy5 cooperative controls and recovery

## Status

The strategy5 cooperative-controls fixture gate passed on 2026-10-09 for the
documented model/device/source scope. The implementation uses a default-false
`small_controls` capability. The source-bound full-model baseline, independent
CPU comparison, physical abort/reset/recovery collection and strict checker passed;
the receipt is in `evidence/small-attention-controls-2026-10-09/README.md`.

Normal model/service selection remains on the existing admitted path. Strategy5
controls do not imply strategy5 runtime readiness, tracing, production admission,
provider parity or a speed lead.

## Ownership and policy

`TuringPrefillFixture` owns control capability admission and tile state. Its final
`small_controls=False` parameter is valid only with explicitly admitted
`small_attention=True`. It is exclusive with fused4 controls/tracing. The existing
control machinery owns synchronized per-layer checks, timeout/cancel detection,
reset-required state and poisoning after observer failure. Replay continues to
refuse control-capable strategy5 owners.

The mode is explicit:

- `test_turing_fixture_controls MODEL.gguf 5` collects the strategy5 recovery
  fixture and emits an explicit `small_controls` strategy marker.
- `check_turing_fixture_controls.py ... --small-attention ...` requires the
  accepted disabled-controls strategy5 source CSV/report/binary plus actual
  current source/binary identities.
- The checker verifies all four complete recovery vectors against the accepted
  source, small/down/closed-fused/scalar dispatch counts, control state, reset,
  allocation identity, guard regions, caller signal mask and artifact hashes.

## Capable-but-disabled source baseline

The complete-model probe has an explicit `controls-disabled` mode. It enables
the sealed `small_controls` capability while leaving the request control object
disabled. Ordinary invocations do not receive that capability. Bind this mode to
the accepted strategy5 source triplet and the current probe binary:

```sh
"$ARTIFACTS/small-model" "$MODEL" controls-disabled > "$ARTIFACTS/disabled.csv"
python3 scripts/check_turing_model_prefill.py "$ARTIFACTS/disabled.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA256" \
  --reference-model "$REFERENCE_MODEL" --reference-sha256 "$REFERENCE_SHA256" \
  --reference-provenance "$REFERENCE_PROVENANCE" \
  --reference-csv "$SMALL_SOURCE_CSV" --reference-report "$SMALL_SOURCE_REPORT" \
  --reference-binary "$SMALL_SOURCE_BINARY" --small-controls \
  --binary "$ARTIFACTS/small-model" --binary-sha256 "$SMALL_MODEL_BINARY_SHA256" \
  --output "$ARTIFACTS/disabled.json"
```

The checker requires the capable-but-disabled marker, then compares all four
current cases against accepted strategy5 native/matrix bytes, cache digests, IDs
and dispatch counts before running the pinned zero-GPU CPU oracle. The accepted
strategy5 source itself must remain control-disabled.

## Required physical acceptance

Use the model, source evidence and derivation identities established by the
accepted strategy5 model/decode/checkpoint operations. Do not reconstruct or
substitute an unverified model. Build every target before capture, use a fresh
private output directory, serialize physical GPU work, then run the independent
zero-GPU CPU oracle. Preserve every failed/partial output and retry only to fresh
paths.

Required cases are pre-expired deadline, cooperative mid-tile timeout, owned
SIGINT cancellation after eight synchronized layers, invalid control descriptor,
and an unexpected observer exception. Known aborts leave the tile uncommitted,
retain allocations and require explicit reset before exact vector recovery. The
observer exception poisons the fixture and refuses reset/reuse. Enabled-control
timing is not scored.

Example command shape, with values taken only from the accepted evidence receipts:

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 \
  aesir_engine/tests/test_turing_fixture_controls.mojo \
  -o "$ARTIFACTS/small-controls"
"$ARTIFACTS/small-controls" "$MODEL" 5 > "$ARTIFACTS/controls.csv"
python3 scripts/check_turing_fixture_controls.py "$ARTIFACTS/controls.csv" \
  --small-attention \
  --reference-csv "$SMALL_MODEL_CSV" \
  --reference-report "$SMALL_MODEL_REPORT" \
  --reference-binary "$SMALL_MODEL_BINARY" \
  --binary "$ARTIFACTS/small-controls" \
  --binary-sha256 "$SMALL_CONTROLS_BINARY_SHA256" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA256" \
  --output "$ARTIFACTS/controls.json"
```

The native collector needs the exact real fixture model. The checker requires
the accepted model5 source to remain disabled-controls, and binds model, source
CSV/report/binary, current binary and capture before and after validation. The
accepted 2026-10-09 run is recorded in
[the physical evidence receipt](evidence/small-attention-controls-2026-10-09/README.md).
Hosted CI compilation is not physical control evidence.

## Completion boundary

Passing this gate establishes only cooperative recovery for this fixture, model
and device. Persisted restore, context recreation, broader concurrency/soak,
tracing, normal selection and provider speed remain separate gates.
