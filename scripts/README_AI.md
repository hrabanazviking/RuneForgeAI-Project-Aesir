# Aesir build, deployment and verification tooling

For owned synchronized strategy2 prefill traces, read
[range operation](../docs/NATIVE_TURING_PREFILL_TRACE.md). The native probe exports
complete source-bound vectors/cache/state and actual PID; the checker binds that
PID to a unique NVTX range after all full-session CUDA rows validate. Preserve
failed time-domain exports, excluded initialization/export counts and unscored
durations. Wrong source/strategy/owner/range or changed artifacts withhold admission.

Explicit --projection-ranges additionally requires both STAGES,1 markers and
complete source-derived disjoint child ranges with exact successful launch/kernel
attribution. See [projection operation](../docs/NATIVE_TURING_PROJECTION_TRACE.md).

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

Control validation now binds exact execution variant and complete independent
source scope/cases/hash before recovered-byte acceptance. Capture/source/model
hashes recheck; interruptions preserve unsuccessful reports without speed claims.
Read ../docs/NATIVE_TURING_BATCHED_CONTROLS.md; eleven portable contracts pass.

The explicit header-cache primitive schema binds three complete owners and840
rotating samples. Complete numerical failures retain every error but clear ratios;
model/CSV mutation and KeyboardInterrupt stay failed. Legacy schemas remain.
Read ../docs/NATIVE_TURING_BLOCK_HEADERS.md. The physically bit-exact candidate
loses target batch32 FFN speed and remains disabled.

Larger-row mode admits128/32 only after retained physical256 resource rejection.
paired_original proves exact original64 bits, original_to_candidate_ratio compares
paired owners and failure clears every ratio. Header-cache alias/legacy two-owner
schemas remain. Read ../docs/NATIVE_TURING_LARGE_ROWS.md; sixteen contracts pass.

The separate down-only128 activation checker binds every current actual source/
state/native/original F32 byte to accepted precision0 capture/report, requires
fixed numerical/totals/independent coverage and preserves all failures. Reports
never score speed or claim full-model quality. Read
../docs/NATIVE_TURING_DOWN_ACTIVATIONS.md; ten portable contracts pass.

Down128 metadata is explicit in complete model parse; default shared readers refuse3.
Require full accepted strategy2 numeric/zero-GPU F32 source plus exact vectors/
IDs/cache/counters before unchanged independent budgets and paired native/new
scores. Rehash derivation/model/current/accepted sources afterward; atomic scores
withhold every ratio on overflow/failure. Read ../docs/NATIVE_TURING_DOWN_MODEL.md.

Explicit strategy3 decode validation additionally requires paired accepted3 model
CSV/report and complete source numerical/counter/cache/ID/predecessor acceptance.
Initial native/matrix F32 vectors bind to that source including signed zero;
initial/replay actual down counts remain source-derived. Complete frame/independent/
causal/sample/bit replay and post-oracle all-artifact hashes gate acceptance.
Cleanup interrupts retain failed JSON. No elapsed score or production selection.
Read ../docs/NATIVE_TURING_DOWN_DECODE.md; default checkpoint/control/trace readers
refuse3.

Checkpoint --down128 is the explicit sealed owning-context3 validation gate.
Require SHA-bound accepted3 decode full96 numeric/sample/causal/replay/initial-
model/source counters and zero-GPU F32 identity. Current initial/restored down
counts28 and18 actual unchanged-state/owner refusals accompany all eight full-
vocabulary continuation frames/four owners/4352 guards. Rehash all artifacts and
retain interrupts/cleanup failures. Read ../docs/NATIVE_TURING_DOWN_CHECKPOINT.md;
no elapsed/persisted/crash/production promotion. Controls/tracing remain closed3.

Down128 cooperative controls require separate default-disabled capability and
explicit --down128 source validation. First collect optional control-capable
model mode and independently accept exact prior2/prior3 full vectors/cache/IDs.
Capability marker and report Boolean must match; old incapable3 source refuses.
Actual abort/recovery/poison down counts and unchanged control/state/guard/byte/
allocation/owned-signal/mask/hash contracts own acceptance. Six portable contracts
pass; keep all failed artifacts including the initial synthetic fixture typo.
Read ../docs/NATIVE_TURING_DOWN_CONTROLS.md; no GPU-fault repair, hard deadline,
production32/provider score. Projection tracing remains closed for3.

## Explicit down128 projection trace capability

Final down128_tracing=False requires down before model load when enabled. Default
down3 stays closed to tracing; explicit3 owned probe requires STAGES1 and refuses
enabled controls. Balanced project try/pop now includes down128 dispatch, preserving
math/counter order and poison behavior. TRACE3/DOWN_ROWS12828 or924/DOWN_TILE128,32
bind actual full F32/cache/IDs/state/counts/guards to accepted3 source. Default2
probe/checker remains. Complete full-session owner/correlation/resource validation
precedes ordered source child attribution; selected wrapper prefixes/grid/block
and per-kernel recorded resource distributions are explicit, never an occupancy/
spill/cause/speed claim. Read ../docs/NATIVE_TURING_DOWN_PROJECTION_TRACE.md; ten adversarial contracts plus physical
plain/profiled cases and master190/one skip pass.

## Optional16-column staging experiment

Separate narrow_turing_kernel/project_turing_narrow siblings retain all previous
packed Turing definitions verbatim. Rows64/128, columns16, original precision0 and
format12/13/14 share initialized guarded cells and original sequential F32 MMA;
half-group lane selection and extra barriers are explicit. Defined shared5440/
9792 bytes atbatch32 do not prove registers/occupancy/speed. Final narrow_rows=0
primitive harness extension stays exclusive with cached/large paths; default and
production dispatch remain. Native probe validates geometry before load. Explicit
MODE narrow metadata requires complete native/candidate/original64 F32 bits,
unchanged oracle/guard/840 rotated timing gates. Read ../docs/NATIVE_TURING_NARROW_STAGING.md;19 portable contracts
retain complete failures/hash drift/interrupt/exclusive reports.

## Optional bounded runtime-group32-column staging

Separate core/packed_turing_loop.mojo imports original accumulation/target/span
helpers and preserves original packed core/quantization modules verbatim. Internal
runtime-group0..7/lane0..31 decode matches original equations; kind12/13/14 and
rows64/128/batch4/8/16/32/precision0 remain static. Shared32 width/both barriers/
chronological F32 public MMA/guarded cells stay; no global workspace or production
selection. Final loop_rows=0 harness dispatch is exclusive with cached/large/narrow
flags. Explicit loop metadata requires full original64 F32 bits, unchanged native/
independent/guard/840 rotated finite timing gates. Both numeric configs pass; all56
original64 comparisons lose.22 portable contracts/master190/one skip. Read ../docs/NATIVE_TURING_LOOP_STAGING.md;
no register/occupancy/cause/provider claim follows.

## Optional paired FFN primitive

Separate packed_turing_pair owns pure two-matrix admission and an opt-in paired
64-row-per-tensor / 32-column kernel. Same-kind12/13/14 and batch4/8/16/32 only;
weight/output aliases refuse before enqueue. Original quant/MMA equations and
all initialized shared tails/barriers remain; no global workspace or selection.
Real Q4/Q4 gate/up passes 983040 complete values per owner, original F32 bits,
600 independent dots, 6720 guards, 144 synthetic pairs and 12 span refusals.
All120 rotated timings remain. Batch4 beats staged but loses native; batch32
loses staged, so no candidate selection. Ten adversarial contracts/master190
passes/one skip. Failed guard-formula checker report is retained; corrected
validation uses unchanged GPU data and a new exclusive report. Read ../docs/NATIVE_TURING_PAIRED_FFN.md.
Actual model activation/full-model/runtime/provider gates remain separate.

## Optional bounded fused causal GQA

core/fused_causal_attention owns strict24/8/128 shape and pure causal F32/F16
span/alias admission, followed by a compatible CUDA-context fence. Allocation
bounds admit fixture stride33824 safely. One128-thread CTA per head/query uses
4096 shared F32 scores and original dot/softmax/value arithmetic; no global
workspace or production selection. All39 cases/1370112 complete original F32
bits and independent Float64 outputs/364518 guards/full query and KV input
immutability pass. All780 rotated times remain; full4/32 improve but long single
queries lose. Nine contracts/master190/one skip. Retained parse failure and
preliminary accepted capture precede rebuilt final stride refinement. Read
../docs/NATIVE_FUSED_CAUSAL_ATTENTION.md. Actual model/full-model/state/runtime/provider gates remain separate.

## Explicit fused-attention complete-model gate

Final fused_attention=False capability selects strategy4 only with original
precision0/batched rotary/elementwise/down128 and controls/tracing closed before
model loading or step mutation. Count4/32 use checked owned fused attention after
ordered cache writes; count1 keeps original kernels. Actual counters reset and
record fused196/56/196/1008, original queries56/28/84/56. All513024 current F32
values per owner/IDs/full F16 cache match accepted3, unchanged CPU budgets/own
bits/4352 guards/eight invalid tiles/32 timings pass. Seven contracts/master190
and one skip. Explicit CLI/source3/binary/after-hash gates preserve default
reader/strategy4 replay refusal. Read ../docs/NATIVE_FUSED_ATTENTION_MODEL.md; broader state/runtime/provider
gates remain separate.

## Explicit strategy4 causal decode quality

The opt-in collector accepts4 with closed controls/tracing and original scalar
attention. Full greedy/seeded native-forced causal frames, exact UInt32 fresh
replay/state/guards and actual initial/replay fused/original/down counters bind
the plan. Explicit accepted model4 CSV/report/binary triplet is exclusive with3;
source and current binary before/after hashes join full source scope/counter/cache/
ID/numeric/CPU/predecessor proof. Default readers and sealed replay4 stay closed.
Eleven portable contracts plus physical complete GPU/independent CPU gates;
no speed scoring or production selection. Read ../docs/NATIVE_FUSED_ATTENTION_DECODE.md. Next earn owning-context
sealed replay and enabled controls before broader runtime/provider acceptance.

## Explicit strategy4 sealed owning-context replay

FixtureReplayPlan final default-false fused capability preserves ordinary0..3
seal/default4 refusal. Explicit mode1/strategy4 plan and actual live capability
bind pre-reset/enqueue admission. Physical45-ID checkpoints/eight continuation
frames retain all four full vectors/UInt32 bytes/CPU/source choices/samples/state/
4352 guards;28 damaged-plan/flag refusals preserve actual owners/health/counters.
Actual down28/fused56 stay and original queries252/364 bind reset/tile plan.
Explicit source4 report/accepted decode binary/current binary SHA fences and strict
all-four source numeric/causal/counter scope remain default-closed/exclusive with3.
Nine adversarial contracts/master190/one skip; unscored same-process replay only.
Read ../docs/NATIVE_FUSED_ATTENTION_CHECKPOINT.md. Next earn enabled control recovery before runtime/provider breadth.

## Explicit strategy4 cooperative control recovery

Final fused_controls=False preserves ordinary4 configure/start refusal. True is
exclusive with legacy3 control/trace flags, requires admitted4 and keeps tracing/
control-capable4 sealed replay closed. Fresh disabled-but-capable4 model retains
all513024 source4 F32 bits/IDs/full cache/CPU/own bits/4352 guards/eight invalid/
32 timing records, actual counters and current/source binary SHA. Explicit marker/
CLI/source keywords stay default-closed. Enabled pre-expired/10ms/owned SIGINT/
invalid-fd aborts drain healthy/uncommitted/reset-required work; allocation-preserving
reset recovers full source vectors. Observer exception poisons/refuses all reuse.
Actual layer down/fused/original counters, caller mask and9792 guards bind recovery.
Fifteen model/control adversarial contracts/master190/one skip. Read ../docs/NATIVE_FUSED_ATTENTION_CONTROLS.md.
No enabled-control speed score or general fault repair/runtime/provider admission.

## Explicit fused attention owned tracing

Final fused_tracing=False requires exclusive original fused4/down128/rotary/elementwise
before model/step; default4 tracing and trace-capable4 control/replay remain closed.
Actual fused4/32 enqueue has balanced owned attention ranges beside existing actual
tensor projection ranges. Full source default4 CSV/report/actual binary and complete
F32/cache/ID/state/guard/count equality precede full-session process/runtime/kernel/
resource admission. Explicit source tile/stage/interleaved attention chronology,
one successful child correlation/kernel, exact wrapper/grid/block and full resources
are mandatory. Old trace schemas remain; all timings are diagnostic. Read ../docs/NATIVE_FUSED_ATTENTION_TRACE.md.
Nine hostile contracts, serial plain/profiled37/1070, both target/original builds
and master190 passes/one skip are separately recorded.

## Optional bounded token-partition primitive

Separate packed_turing_partition owns original format12/13/14, row64/128, token8/16,
logical4/8/16/32 and width32; one 2D enqueue owns disjoint token rows, original
ordered high/residual MMA and both barriers. Checked complete spans precede launch.
Harness final parameters default0 and refuse conflicting legacy candidates. Full
native/candidate/selected-original MMA vectors, UInt32 bits, guards, pinned independent
dots and840 rotated records gate any primitive ratio. Original MMA down128 applies
only to canonical down batch32; staged64 elsewhere. Model key/value four-reference
is the separate native owner. New marker/dispatch parser is default-closed, requires
explicit CLI and actual binary hash before/after; complete failures retain metrics
and atomically clear ratios. Seven hostile contracts plus physical gates remain
separate from hosted compile/master190/one skip. No runtime/model selection change.
Read ../docs/NATIVE_TURING_TOKEN_PARTITION.md.

## Optional bounded small-score attention primitive

Separate `fused_small_attention.mojo` reuses original complete span admission,
then visible<=1536 independently of actual KV capacity<=4096. `attend_small[batch]`
keeps original24/8/128 GQA math/barriers/128-thread grid and no global workspace;
16384→6144 static shared bytes are observed over all2178 profiled kernels.
No model/runtime selector change. `test_small_fused_attention.mojo` owns exclusive
0600 CSV/actual PID/33 cases/17 pure refusals/full F32 bits/immutable inputs/exact
guards/660 warmed rotated samples. Startup wait precedes CUDA and is unscored.
`check_small_fused_attention.py` covers every output with pinned Float64 CPU and
fixed budgets; profiled mode clears scores. `check_small_attention_resources.py`
binds all full plain/profile bits and CPU source identity to complete launch/resource
counts/PID/binary/five artifact hashes. New analyzer fused_primitive flag requires
resources and excludes all model/range flags; old schemas stay.10+8 hostile contracts
join CI. Read project-root operation at project-root docs/NATIVE_SMALL_FUSED_ATTENTION.md before
changing bounds/math; whole-model/state/production/provider gates remain separate.

## Explicit small-score whole-model prefill

Final small_attention=False is an exclusive test-only strategy5 requiring original
fused/down128/rotary/elementwise precision0 and no control/trace capabilities.
Count4/32 enqueue attend_small; singles remain original. Separate small/fused/scalar
counters reset.12 state/allocation-preserving refusals include a valid native replay
plan; restore rejects5 before owner mutation. No original0..4 or normal selection
change. New probe exports all513024 F32 per owner/IDs/full cache/4352 guards/32
records and own exact bits. Explicit reader allow_small/CLI--small-attention require
actual current binary and accepted default4 source CSV/report/binary/full fixed CPU/
prior3 byte/cache/ID/counter proof. Every current value/cache/ID and tile count binds;
unchanged independent zero-GPU F32-expanded oracle reruns. Every after-hash/numeric/
source/nonfinite failure clears all scores, retains exclusive reports. Seven hostile
contracts join CI; read project-root docs/NATIVE_SMALL_ATTENTION_MODEL.md. New mode
controls/replay/tracing/generation/runtime/context/device/provider gates stay open.

## Explicit small-score causal generation

Optional5 now retains full96 native-forced greedy/seeded frames/12312576 values
per owner, source5 initial F32 bytes, independent fixed CPU budgets, exact own
UInt32 replay/sample/history/draws/state/4352 guards. Actual small56/1008 and
down28/924 stay; fused0 is mandatory and scalar original queries advance28 per
generated token. Strict accepted-small helper requires actual model5 CSV/report/
binary, full parsed/recomputed four-case vectors/cache/IDs/counts/timings/fixed
CPU and complete source4 predecessor proof; typed integer totals/counters/IDs.
Explicit exclusive small source triplet plus current binary/SHA and all eight
after-fences bind. Defaults/old loaders reject5. Twelve hostile contracts/master190/
one skip/all seven builds pass before serial GPU/CPU. Read project-root
docs/NATIVE_SMALL_ATTENTION_DECODE.md. No speed score or normal selection.
Next sealed owning-context replay5, then separate controls/tracing and broader
runtime/context/device/concurrency/soak/provider gates.
