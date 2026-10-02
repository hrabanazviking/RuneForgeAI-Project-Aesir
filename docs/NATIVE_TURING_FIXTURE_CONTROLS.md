# Cooperative control and explicit recovery for the optional matrix fixture

This slice earns control/reset invariants for the isolated strict3B/context1536
matrix fixture. Normal runtime admission remains one/four tokens. Read
[workspace admission](NATIVE_TURING_FIXTURE_ADMISSION.md) and
[whole-model operation](NATIVE_TURING_MODEL_PREFILL.md) before using it.

## Policy and ownership

tests/turing_fixture_control.mojo owns pure enabled/started/reset-required/reason/
completed-layer state while reusing core GenerationControl for monotonic deadlines
and caller-owned pollable cancellation. configure_control validates policy without
mutating an old policy on invalid input. Enabled use requires start_control.
Busy, failed or reset-required fixtures reject configuration/start/tile reuse.
Default disabled use preserves the original queue/synchronization policy.

```mojo
fixture.configure_control(45000, caller_owned_cancel_fd)
fixture.start_control()
fixture.step(tokens, start, 32)
```

Timeout0 disables the deadline, cancel descriptor-1 disables cancellation.
GenerationControl validates0..3600000ms and descriptor-1..2147483647. The caller
retains the descriptor throughout the request; the core never consumes/closes it.
Create ChatInterrupts before CUDA workers for the owned SIGINT path, as the
physical probe does. The owner consumes its signal after observing refusal.

Enabled control checks before tile mutation, after each synchronized layer, and
after final synchronization before committing IDs/position. Stops drain only the
owning stream. Timeout/cancellation/poll error with successful drain marks explicit
reset required and preserves healthy state solely to allow that reset. No partial
tile IDs or position commits. Sampler history can already contain uncommitted
tokens; reuse is refused. This is cooperative checking, with no hard real-time
deadline or preemption guarantee for an in-flight operation.

reset clears sampler/history/position/control deadline and abort state after
successful synchronization, retaining immutable weights and allocated buffers.
Cache reuse stays disabled; causal prefill overwrites every required position
before reading it, and stale future KV is never visible. A failed GPU/drain or
unexpected observer exception leaves healthy=False. Reset/config/start/tiles
then reject until context recreation. The optional thin layer observer is a
test-only hook, defaulting to no-op and called only under enabled control.

## Physical proof and exact evidence

test_turing_fixture_controls.mojo owns four cases: pre-expired deadline, actual
10ms mid-tile deadline, actual SIGINT after8 synced layers and invalid poll
descriptor. It requires healthy drain, no partial commit, three reuse refusals,
abort/recovery guards, unchanged weight/buffer identity and full post-reset
native/matrix vectors for the existing37-token public prompt. The owner consumes
exactly one SIGINT. A separate exception after1 synced layer must poison the
fixture and refuse four operations; it proves exception policy, not an actual
GPU-fault repair. Owner signal mask restoration is mandatory.

The bounded ordered checker binds an accepted independent original-mode0 report
to its CSV/model identity, then requires every recovered ID/F32 byte to match its
case1 vectors. Signed zero is compared by actual bytes. All513024 recovered
values per mode,9792 guard checks, abort/reset/poison states, counts and mask
records are mandatory. Numerical failures retain every complete case in exclusive
reports; unknown/mixed/duplicate/missing/late evidence rejects. No control/recovery
duration is a speed score. Nine portable contracts exercise these boundaries.

Use the model/artifact/reference variables from the two operation guides; create
a new file for every attempt. Finish all host compilation before serialized GPU
control/model captures, then run CPU checks. Hosted CI compiles without claiming
physical execution. For the control checker, REFERENCE_CSV/REFERENCE_REPORT must
be matching accepted original-mode0 evidence for the original model.

```bash
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_fixture_controls.mojo \
  -o "$ARTIFACTS/control-probe"
timeout 300 "$ARTIFACTS/control-probe" "$MODEL" > "$ARTIFACTS/control.csv" 2>&1
python3 scripts/check_turing_fixture_controls.py "$ARTIFACTS/control.csv" \
  --reference-csv "$REFERENCE_CSV" --reference-report "$REFERENCE_REPORT" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" --output "$ARTIFACTS/control.json"
```

Also repeat complete disabled mode0 model evidence under the original independent
.05/.005/matching-argmax gates and compare all prior complete vectors/IDs exactly.
Retain all32 alternating raw samples, excluding only the warm/export pair.
Production admission/generation/sampling/restore/concurrency, broader contexts
and paired provider lead remain separate gates; rejected precision modes stay
rejected. Preserve all attempts and publish reviewed hashes/receipts.

## Verified acceptance — 2026-10-02

The physical probe passes all four abort/recovery cases. The10ms deadline stops
after2 completed layers, real SIGINT after8, pre-expired deadline/poll error
before layers. No partial IDs/position commit; already recorded32-token sampler
history in mid-tile cases requires explicit reset. All513024 recovered values
per mode match prior accepted case1 bytes, allocations remain unchanged and9792
guard checks pass. Unexpected observer exception after1 layer poisons the
fixture, four reuse/reset operations refuse and owner signal mask restores.

Master189 cases pass/zero failures/one explicit fixture skip, total190. Nine
control and nine model contracts pass; sm75/sm89 probes compile. A separate
disabled-mode0 physical collection passes all original independent gates,
exact repeats/commits/4352 guards and previous complete-vector byte regression.
All32 timing records remain; long fresh-prefill medians12.7954s/7.6364s preserve
ratio1.676 in this isolated fixture. Control/recovery durations are unscored.
All compilation ends before serialized captures, CPU checks afterward.

Normal binary remains f3442a1e; authenticated active readiness/exact pushed CI
are separate receipts. [Reviewed evidence](evidence/turing-fixture-controls-2026-10-02/README.md).
Next earn generation/sampling and restoration quality before production32-token
admission or provider comparison. Broader contexts remain open.
