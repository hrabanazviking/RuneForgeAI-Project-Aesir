# Enabled controls and recovery for the batched Turing fixture

Read [elementwise operation](NATIVE_TURING_BATCHED_ELEMENTWISE.md),
[original controls](NATIVE_TURING_FIXTURE_CONTROLS.md),
[workspace admission](NATIVE_TURING_FIXTURE_ADMISSION.md) and
[checkpoint replay](NATIVE_TURING_CHECKPOINT_REPLAY.md) first. This gate exercises
explicit strategy2 on the original strict3B/context1536/F16KV/sm75 profile.
Production runtime policy remains one/four.

## Strategy and signal ownership

test_turing_fixture_controls.mojo accepts optional final0/1/2. Omission retains
legacy original metadata/default behavior; explicit strategies emit the same
strict ATTENTION markers as the model/decode/checkpoint collectors. Flag validation
occurs before signal-mask ownership. Strategy2 uses the admitted rotary/cache plus
row-strided RMS/residual/SiLU path, with unchanged cooperative layer checkpoints.

The caller owns ChatInterrupts and exactly one delivered SIGINT. The physical
collector sends SIGINT to its own pthread after eight synchronized layers,
consumes it once, and verifies that its original signal mask restores after
scope exit. It does not signal the second-brain service or other processes.

## Actual abort and reset acceptance

Four declared operations exercise a pre-expired deadline, real10ms deadline,
owned SIGINT after eight layers and invalid descriptor before mutation. The first
and fourth abort before layer execution. The10ms case must complete at least one
but fewer than28 synchronized layers; it is cooperative, not hard real time.
Healthy aborts drain the owning stream and preserve uncommitted position/token
IDs while setting reset-required state. An uncommitted32-token sampler history
can exist after a started tile; explicit reset must clear it before reuse.

Three reuse operations must refuse before changing state. After explicit reset,
immutable weights and actual activation/cache allocations remain. Every recovered
complete native/matrix vector must equal the accepted37-ID graph case byte-for-
byte, including signed zero. Original shape/span/profile/control/commit gates
remain; no extra device workspace or fallback is introduced.

An unexpected observer exception after one synchronized layer separately proves
poison policy. step/configure/start/reset all refuse reuse of that poisoned owner.
This does not prove physical GPU-fault repair, cross-context restoration or
hard-deadline behavior. Guards are checked after abort, reset/recovery and poison;
all9792 physical guard cells/records are mandatory.

## Reference evidence cannot cross strategies

check_turing_fixture_controls.py admits a single known optional variant before
META and requires exact agreement with the accepted source CSV/report variant.
Legacy omitted metadata pairs with legacy sources. Explicit0/1/2 pair with the
same explicit source. Equal vectors from another strategy do not bypass identity.

The source must be original precision0, complete and independently passed with
fixed .05-max/.005-RMS/full-vocabulary-argmax budgets, all four owner/case results,
513024 values per owner, eight invalid tiles and4352 source guards. Strict bounded
no-follow JSON rejects duplicate/nonfinite fields. Source CSV/report hashes bind
actual parsed bytes; input/source/model hashes recheck after validation.

Complete recovered-vector failures retain all four cases in an exclusive JSON
report. Changed inputs/references, malformed records or KeyboardInterrupt preserve
an unsuccessful complete/partial report and raw evidence. Every outcome has
speed_claim=False. Eleven portable contracts establish parser/admission behavior;
actual hardware evidence remains the separate physical collector.

## Build, capture and validate

Use the prepared locked Pixi environment, with new artifact paths. Finish both
sm75/sm89, master and normal builds before the serialized owned GPU capture.
The validator reuses the newly accepted independent strategy2 prefill evidence;
exact recovered bytes preserve that numerical proof without new CPU inference.

```bash
pixi run --frozen --no-install --offline mojo build -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_turing_fixture_controls.mojo -o /tmp/aesir-batched-controls
pixi run --frozen --no-install --offline mojo build -I aesir_engine --target-accelerator sm_89 aesir_engine/tests/test_turing_fixture_controls.mojo -o /tmp/aesir-batched-controls-sm89
pixi run --frozen --no-install --offline mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo
python3 scripts/launch.py --build --target sm_75
python3 scripts/launch.py --check
/tmp/aesir-batched-controls MODEL.gguf 2 > controls.csv
python scripts/check_turing_fixture_controls.py controls.csv --reference-csv elementwise.csv --reference-report elementwise-report.json --model "$AESIR_MODEL" --model-sha256 "$AESIR_MODEL_SHA" --output controls-report.json
```

Use the original model identity variables and independently accepted strategy2
artifacts from the elementwise manual. Require exit0, passed=True and
collection_complete=True in the new report. Keep every failed attempt/log/report;
never replace existing outputs. sm89 compilation does not establish physical
sm89 execution. Process/copy/export/validation durations are unscored.

## Evidence and remaining gates

Read [physical evidence](evidence/turing-batched-controls-2026-10-02/README.md)
for exact actual layer boundaries, recovered vector hashes, guard/poison/mask
proofs, source identities, build/process order and publication receipts.
Only the stated original profile/device/context earns this control gate. Maximum
history/window wrap, disconnect/concurrency/soak, wider contexts/devices, persisted/
context recreation, actual GPU-fault repair and runtime32/provider admission remain
open. Next earn owned stage tracing before additional attention work.
