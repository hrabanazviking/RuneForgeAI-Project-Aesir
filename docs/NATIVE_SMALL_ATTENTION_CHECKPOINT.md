# Small-score sealed owning-context replay

Explicit strategy5 is a default-disabled test fixture for Llama3.2 3B/sm75/
context1536/F16 KV/original activation precision0. Native Mojo owns inference;
Python/NumPy/llama.cpp supervise independent tests. Read Task MD, test/script
ownership interfaces and [accepted generation5](NATIVE_SMALL_ATTENTION_DECODE.md).
The normal authenticated service retains its original prefill4 binary.

## Explicit capability and mutation boundary

Final `TuringPrefillFixture(...,small_replay=False)` requires admitted small5.
The capability is admitted before model access and again before runtime mutation.
Normal model5 and generation5 leave it false. Default replay5 refuses even a valid
native-owner plan before owner reset or sampling configuration. Controls/tracing
stay closed. Existing0..4 capabilities and seal equations remain available.

Final `FixtureReplayPlan(...,small_capable=False)` requires mode1/strategy5 and
both original fused and small capabilities. Strategy4 retains its existing seal
bytes;0..3 retain theirs. Strategy5 seals both flags. A plan copies actual token IDs
and original tile boundaries plus allocation identities, pending chosen ID, sampler
configuration/window and actual draws. Its checksum detects local mutation; it is
not cryptographic authentication or a persisted format.

Restore admits actual live capability, complete seal/structure, actual weights/
activation/cache pointers, sampler window, flags/profile/physical spans, precision,
idle healthy owner and disabled controls before reset/configuration/enqueue.
Replay preserves native four/scalar and matrix32/four/scalar tile boundaries.
Sampling history and actual draw count restore; pending ID remains uncommitted
until continuation advances. Recheck owners after replay. Execution failure poisons
the affected owner; admission refusal preserves both healthy owners.

## Native collection and refusals

The collector accepts0..5/default0;6 refuses before model/CUDA. The dedicated
reject-small-replay constructor probe proves an unrelated replay capability refuses
before nonexistent-model access. Public37 plus eight native-forced scalar IDs gives
45-ID checkpoints for greedy and seeded policies. Each has four continuation frames.
Export every128256 F32 value for baseline native/matrix and restored native/matrix,
actual UInt32 bit comparisons including signed zero, exact IDs/samples/history/
positions/draws/pending ID and4352 guards. Two cap-sized pinned snapshots hold
baseline vectors; there is no new device workspace or speed score.

Eight damaged fields per native/matrix plan (tile count, weights, draws, strategy,
fused capability, activation pointer, small capability, cache pointer) plus four
live flag refusals (elementwise, fused, small, replay) give20 per policy/40 total.
Each checks both allocation identities, sampled/committed state, IDs, health and
actual counters before/after. Pure master also tests explicit small seals, changed
capabilities/checksum/cache and invalid native/legacy/missing-flag combinations.

Actual down28/small56/old-fused0 remain at checkpoint and restore. Original scalar
queries are252 at45 committed IDs and364 after four continuation IDs. Ordered
initial/restored/final records bind reset and actual dispatch, so counters cannot
silently accumulate earlier continuation work or change the prefill strategy.

## Build and validate

Finish both targets, original collector, source-model collector, master, normal
build/check before serial GPU then independent CPU. Retain distinct source/binary/
UTC receipts. No native edits or builds during physical work. Use a fresh private
directory, exclusive stdout/stderr/output, bounded child lifetime and owned process
group cleanup; preserve all failures. Shell redirection below can overwrite, so
choose fresh files or the exclusive supervisor.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_checkpoint_replay.mojo \
  -o "$ARTIFACTS/small-checkpoint"
"$ARTIFACTS/small-checkpoint" "$MODEL" 5 > "$ARTIFACTS/complete.csv"
"$ORACLE_PYTHON" scripts/check_turing_checkpoint_replay.py "$ARTIFACTS/complete.csv" \
  --small-attention \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-model "$REFERENCE_MODEL" --reference-sha256 "$REFERENCE_SHA" \
  --reference-provenance "$REFERENCE_PROVENANCE" \
  --accepted-report "$ACCEPTED_DECODE_REPORT" \
  --accepted-report-sha256 "$ACCEPTED_DECODE_REPORT_SHA" \
  --accepted-binary "$ACCEPTED_DECODE_BINARY" \
  --binary "$ARTIFACTS/small-checkpoint" --binary-sha256 "$BINARY_SHA" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_small_attention_checkpoint.py
```

Small opt-in is exclusive with down/fused. Default source/metadata readers reject5.
Require the exact accepted96-frame generation5 JSON SHA and actual generation
binary, current binary/SHA and original/derived models/derivation. Source admission
checks all four source cases/full totals/public IDs/policies/caps/frames, actual
native/matrix samples/greedy argmax, causal positions/history/draws, exact own
replay, dispatch counts, complete fixed native/independent CPU numerical budgets,
pinned zero-GPU F32 CPU scope and accepted model5/prior4 binary identities. Integer
totals/counters/state/IDs reject Boolean or float substitutions. Duplicate/nonfinite
JSON refuses. A passed flag alone cannot hide a failed metric or state.

Checkpoint IDs and choices and baseline continuation choices bind the short source
frames. All four current full vectors independently rerun through pinned
NumPy2.4.4/llama-cpp-python0.3.23, zero GPU layers/context4096/F16 KV/batch128/four
threads/no flash attention. Unchanged.05 maximum/.005 RMS/matching full argmax
budgets apply. Declared bit counts must match actual exported F32 bytes. All restored
bytes/state equal baseline; complete failures retain all measured frames.

Streaming CSV uses one no-follow regular descriptor bounded256MiB, complete UTF8
lines<=1024 bytes/16 fields/256 bytes per cell, exact order and descriptor SHA/stat.
Only four current vectors are retained by the checker. Accepted JSON is bounded
1MiB with explicit SHA. After oracle, rehash current CSV/binary, original/derived
models, derivation, source report/binary. Supervisor also fences source CSV and
reviewed source/binary/model/provenance preflight/after-GPU/postflight. Exclusive
JSON preserves partial/complete failures and interrupted evaluation/cleanup.
Exit0 requires complete acceptance; retry into a fresh destination.

## Retained result and next gate

All eight frames/1026048 F32 values per baseline/restored owner, exact own bits,
source samples/state, fixed CPU,4352 guards and40 mutation-free refusals pass.
Ten hostile contracts/legacy suites/master190 passes/zero fails/one skip and all
seven builds pass before serial physical work. Initial synthetic fixture insertion
matched suffixes and then emitted a blank record; exact newline anchors corrected
before physical capture, with both failed logs/test snapshots retained.

This proves same-process owning-context replay at these boundaries. Process/
export/oracle times remain unscored. Persisted/crash restore/context recreation,
free-running candidate trajectories, enabled controls/tracing, production32,
broader context/device/concurrency/soak and provider/Ollama speed remain open.
Next earn separate cooperative timeout/cancel/reset/recovery5 and tracing before
broader runtime/provider selection. Exact push/CI receipts are separate.
[Complete evidence](evidence/small-attention-checkpoint-2026-10-03/README.md).
