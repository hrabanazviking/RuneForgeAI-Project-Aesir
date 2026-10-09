# Small-score strategy5 cooperative controls and recovery

## Status

The implementation contract is active. A default-false `small_controls` fixture
capability and strategy5 collector/checker path are being added under
`TASK_small_attention_controls.md`. Portable checker and owning Mojo build gates
have passed locally. Physical model-bound timeout, cancellation and recovery has
not been collected or accepted. This page is an operation contract, not evidence
that the capability is complete.

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
CSV/report/binary, current binary and capture before and after validation. Hosted
CI compilation is not physical control evidence.

## Completion boundary

Only after the source-bound CPU and physical gates pass may this page record
accepted counts, hashes, vectors, run conditions and limitations. Passing these
tests establishes only cooperative recovery for this fixture, model and device.
Persisted restore, context recreation, broader concurrency/soak, tracing, normal
selection and provider speed remain separate gates.
