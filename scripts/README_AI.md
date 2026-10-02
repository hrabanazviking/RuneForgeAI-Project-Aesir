# Aesir build, deployment and verification tooling

These Python programs prepare, launch or independently test the native Mojo
engine. They never supply production native inference or substitute Ollama answers
for native execution. Optional independent CPU inference is explicitly test-only.
launch.py owns the frozen offline build/checksum gate.
second_brain_service.py validates an explicit policy and registered model through
that gate and the native settings preview, then writes one new user-systemd unit.
It refuses overwrites, does not create or disclose keys, and does not enable the
service itself. second_brain_service.json owns this deployment's bounded policy.
Linux/systemd is the only exercised deployment target.

benchmark_second_brain.py is an opt-in actual-socket comparator. Run it after all
other GPU tests have ended. Preserve raw samples, include warmup and all failure
results, and distinguish KV cache formats/prefix reuse from full numerical parity.
Its output uses exclusive creation; choose a new filename for each experiment.
See ../docs/SECOND_BRAIN.md for commands and the exact measured support boundary.

benchmark_native.py measures an explicit binary in an owned authenticated
process. Reports retain its hash, actual capabilities, replies, all timings and
failures. --no-prefix-cache distinguishes fresh prefill from repeated prefixes.
Run measurements while other GPU tests are idle. It owns its temporary process
and key, not the supervised deployment. See ../docs/NATIVE_PERFORMANCE.md.

The optional extended suite and --max-tokens exercise larger public prompts and
sustained generation. compare_native_benchmarks.py requires complete identical
request/reply sequences and actual model/policy identity, recomputes warm medians
and refuses ratios on errors or mismatch. Its synthetic mutation tests prove only
evidence validation. check_dense_normalization.py is an independent standard-library
oracle for physical probe output. See ../docs/NATIVE_EFFICIENCY.md for commands.

benchmark_native.py --prefill-batch 1|4 requests and verifies observed startup
policy. compare_native_benchmarks.py --allow-prefill-batch-change allows only that
declared change while preserving all other policy and complete-response gates.
check_long_attention.py independently verifies the physical CSV with test-only
NumPy 2.4.4. See ../docs/NATIVE_LONG_TOKENS.md for buffer cost and recovery limits.

The optional stress benchmark suite exercises a 3150-token public prompt and
128-token output ceiling at context4096; preserve standard/extended defaults.

For the connected SPD-00 tools, schemas, optional independent CPU oracle, safe
F32 reference expansion and failure-aware provider modes, read [INTERFACE.md](INTERFACE.md)
and [the measurement manual](../docs/SPEED_MEASUREMENT.md). The optional reference
is exclusively test-side. It never supplies native production inference. Balanced
provider ordering is the new default; grouped mode reproduces historical ordering.
All broad speed/quality/controlled-cache gates remain explicitly scoped.

For optional owned-process CUDA tracing, use profile_native_cuda.py and the
read-only check_cuda_trace.py. Read ../docs/NATIVE_CUDA_TRACE.md first: raw traces
stay outside Git, profiler time is never a speed score, and only matching complete
native replies plus actual admitted kernel/launch rows can pass. No live service
attachment or privilege/dependency changes belong in this tool.

The experimental packed matrix CSV oracle is check_packed_matrix.py. Read
../docs/NATIVE_MATRIX_CANDIDATE.md for complete native-reference versus selected
independent real-weight coverage. Primitive timing never earns a service lead.

check_turing_mma.py checks every synthetic binary output with independent integer
equations and complete guard/count evidence. Do not loosen its zero-error budget
for formatter loss; export F32 values through Float64 text. Read
../docs/NATIVE_TURING_MMA.md for target correction, physical evidence boundaries
and the separate real-weight quality/speed prerequisite.

The packed Turing mode shares check_packed_matrix.py without loosening budgets.
Its original single-F16 attempt fails; split weights pass primitive precision
but every speed case loses. Read ../docs/NATIVE_PACKED_TURING_MATRIX.md. MODE and
TILE metadata cannot mix; original SIMT evidence remains accepted.

Staged Turing MODE additionally requires an admitted CTA row count. Keep fixed
budgets and distinguish larger-batch primitive gains from production speed.

Wide staged MODE additionally records explicit64/128 input columns and admits
only32/64 CTA rows. Preserve legacy defaults and rejection semantics; ten portable
contracts cover configuration identity. Wider physical timings do not beat the
prior32-column result. Arbitrary full-model activation quality remains open.

check_turing_activations.py checks captured ordinary native F32 inputs without
rounding them to F16 or regenerating a test recipe. COMPLETE means collection,
not success; preserve every numeric failure and fixed budget. Read
../docs/NATIVE_TURING_ACTIVATIONS.md for actual-versus-representative operands,
selected independent coverage and broader full-model/control acceptance.

check_turing_model_prefill.py gates every complete matrix/reference final-prompt
logit against the independently derived test-only F32 CPU model. Preserve fixed
budgets, exact original/derived hashes and derivation proof; withhold all speed
ratios on any numerical/identity/repeat/guard failure. Read
../docs/NATIVE_TURING_MODEL_PREFILL.md. A fixture pass does not expand normal
batch admission or establish generation, cancellation, restore or provider speed.

Explicit input-residual metadata preserves legacy precision0 and admits1/2 only.
Ten captured-input/nine model contracts cover it and stricter .0005 native-model
RMS acceptance. Both nonzero physical modes miss that extra gate; preserve full
failed reports and withheld ratios, including clearing stale scores on rescoring.
Read ../docs/NATIVE_TURING_ACTIVATION_RESIDUAL.md before the next refinement.
## Scaled residual evidence

The bounded captured/model checkers admit explicit precision3/4 metadata while
preserving legacy0/1/2. Complete gates remain unchanged, including nonzero
native-model RMS<=.0005 and removal of every score on failure. Read
../docs/NATIVE_TURING_SCALED_RESIDUAL.md before claiming acceptance or speed.
## Matrix fixture control evidence

The bounded control checker binds original accepted independent evidence to its
CSV/model and compares every recovered F32 byte, including signed zero. State,
guard, refusal, ownership, poison and mask records are mandatory. Complete
numerical failures remain exclusive reports, with no control speed score. Read
../docs/NATIVE_TURING_FIXTURE_CONTROLS.md before changing gates or interpreting
control/recovery acceptance as production behavior.

## Complete decode quality

check_turing_decode_quality.py streams regular/no-follow CSV<=2GiB, one bounded
line/frame at a time. Every policy/public-ID digest/state/vector/replay/guard and
actual EOS/cap total is required. Fixed independent/native .05/.005/argmax and
actual sampled-choice equality plus own exact replay own acceptance. Exclusive
reports retain every complete numerical failure; speed_scored staysFalse. Pinned
CPU oracle runs only after GPU captures and hashes original/derived models before/
after. Read ../docs/NATIVE_TURING_DECODE_QUALITY.md; production is never imported.

## Checkpoint continuation evidence

check_turing_checkpoint_replay.py streams ordered no-follow CSV<=256MiB and
verifies actual before/after F32 bytes, printed bit counts, every state/tile/ID/
refusal/guard and prior accepted public trajectory binding. Every unchanged
CPU/native budget and sample/own replay gate remains mandatory; complete failures
retain all metrics, with speed_scored=False. Read ../docs/NATIVE_TURING_CHECKPOINT_REPLAY.md.
Nine portable contracts prove parser behavior only. Records additionally accepts
a smaller explicit byte allowance; default decode2GiB semantics stay unchanged.

## Batched rotary/cache validation

Explicit attention variant0/1 requires a matching independently accepted source
CSV/report and exact vector/ID/cache identity before model speed scoring. Hashes
recheck after the oracle and failed rescoring clears all old ratios. Decode and
checkpoint streams admit only a single known marker before META. Six portable
contracts include complete-stream duplicate/late refusal. Read
../docs/NATIVE_TURING_BATCHED_ROPE_CACHE.md; no provider-speed promotion follows.

Explicit elementwise strategy2 requires its distinct metadata, exact actual host
counts and independently accepted strategy1 source; original0/1 behavior stays.
Every model/CSV/report/byte/cache/state/numerical gate remains before scoring.
Read ../docs/NATIVE_TURING_BATCHED_ELEMENTWISE.md. Seven grid contracts pass.
