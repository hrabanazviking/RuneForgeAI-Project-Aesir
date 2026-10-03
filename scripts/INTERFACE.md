# Performance measurement tool contracts

Owner: Python supervision/measurement domain. Native inference stays in Mojo.
Other build/operator tools are indexed by [README_AI.md](README_AI.md) and their
linked manuals; this interface owns the new provider and numerical evidence tools.

## benchmark_second_brain.py

CLI `main` reserves one new UTF-8 JSON report before operational work. It accepts
explicit HTTP origins, a local native key file, model/context/output ceilings,
public suite, repeat count, deterministic provider order, residency mode, optional
same-weight blob/PID checks and timeout. Schemas and operations are described in
[the manual](../docs/SPEED_MEASUREMENT.md).

`request` allows credential transmission only to native 127.0.0.1, bounds timeout
and response bytes, rejects duplicate/nonfinite/malformed JSON, and always closes
its connection. `schedule` deterministically covers each provider/case/round.
`sample_reply` validates observed identity, counts/context, completion and provider
reported duration types, retaining redacted decoded responses on failure.
`summarize` refuses ratios on any failure or unequal required output counts;
no result establishes quality parity or a certified lead.

Exit 0 means the declared requests/protocol completed. Exit 1 means failed samples
or setup, with retained evidence. Ctrl-C exits 130 with collected samples. Existing
output paths are never overwritten. Native credentials and production corpus are
forbidden evidence inputs. Provider calls may load/retain the declared Ollama
model; they do not restart managed services, change native policy or write corpus.

## check_llama3_logits.py

`parse_probe` requires the complete strict-3B native CSV schema; `compare_case`
applies the fixed predeclared 0.05 maximum / 0.005 RMS / matching-argmax contract.
`summarize_physical` reports actual-call timing and a conditional logical-traffic
reference against observed D2D bandwidth, not a guaranteed decoder ceiling.

CLI accepts source GGUF plus expected byte hash, CSV, bounded CPU threads, and
one new JSON report. Optional test-only llama-cpp-python 0.3.23/NumPy 2.4.4 own
independent CPU inference on the exact exported input IDs, F16 KV, no flash
attention and zero GPU layers. The native runtime never imports this module.

Optional explicit F32 expansion owns one new derived artifact through the supplied
quantizer and records its hash/exit/logs. It never overwrites an existing destination
or the source. Verified reference reuse requires its own SHA-256 and retained
derivation provenance. Each real reference is closed even after comparison errors.
Exit 0 requires complete physical data and every independent numerical case to
pass unchanged budgets. Exit 1 preserves failure/error evidence and never certifies
numerical support or speed. Unsupported reference versions fail before evaluation.

## profile_native_cuda.py / check_cuda_trace.py

The optional capture wrapper owns a separate strict-3B CLI process, exclusive
private artifact directory, explicit prompt/policy and bounded child lifetime.
It checks the launcher/catalog/model digest, observed VRAM and installed tool
identity before GPU operations. Matching complete profiled/unprofiled replies
gate non-mutation. A matching installed importer handles split-package location
failure. No attach, unrelated service stop, installation or permission changes.

`analyze` owns read-only bounded Nsight 2023 SQLite admission. It accepts concrete
tables, one actual CUDA process/device and unique successful launch/kernel
correlations, validates timestamps and emits GPU interval unions and recorded
kernel/API/copy groups. Linux descriptor paths close final-file replacement
races; query-only/authorizer/VM limits prohibit mutable or input-supplied SQL.
API and GPU intervals overlap; uncovered time has no inferred cause. No automatic
prefill/decode or per-layer attribution. See [the operator manual](../docs/NATIVE_CUDA_TRACE.md)
for resource limits, exit codes, artifact privacy and exercised physical scope.

`analyze` optionally binds an expected native PID and one named completed
same-thread NVTX range. Every full-session CUDA row still passes original
ownership/timestamp/correlation admission before range selection. Selected launch
correlations, GPU work and groups explicitly belong to that range; crossing work
refuses and excluded kernel counts remain. Legacy callers retain complete scope.
`check_turing_prefill_trace.py` additionally binds plain/profiled complete source
F32/cache bytes, IDs/state/host counts/guards, exact binary/model/source/SQLite
hashes and matching strategy2 independent acceptance. All durations are unscored;
exclusive reports retain numerical, changed-artifact and interruption failures.
See [range operation](../docs/NATIVE_TURING_PREFILL_TRACE.md).

Optional projection_tiles lets already-admitted outer-range kernels project
through exact successful API correlations into disjoint same-thread child ranges.
cuda_projection_ranges.attribute checks strict source-derived range/kernel counts,
complete launch containment and known projection prefixes, returning per-stage/
batch actual geometry/count/duration. No asynchronous GPU interval is clipped to
its CPU enqueue range. Checker --projection-ranges binds explicit STAGES,1 on both
plain/profiled inputs. Read [attribution operation](../docs/NATIVE_TURING_PROJECTION_TRACE.md).

## check_packed_matrix.py

Optional test-only primitive oracle. parse requires bounded regular ordered CSV,
actual CUDA marker, complete 28 cases/all values/guards/560 timings and final totals.
errors applies predeclared scaled 0.002/normalized-RMS 0.0002 budgets. independent
checks original model hash and independent GGUF descriptors/dequantized values
for five selected rows per tensor/batch through gguf 0.19.0/NumPy 2.4.4. Exclusive
JSON output retains failures. No production import, inference, model writes or
whole-model quality/speed certification. See ../docs/NATIVE_MATRIX_CANDIDATE.md.

Matrix CSV optionally begins TILE,rows,columns; omission retains original32/32.
Admission rejects duplicate, late, oversized or unsupported staging metadata and
reports observed tile identity. Actual descriptors/numerical budgets do not change.

## check_turing_mma.py

parse admits ordered regular UTF-8<=8MiB CSV with nonblocking/no-follow opening.
Every50688 output must match independent integer numerator/256 equations, with
108 cases,5400 guards,9 rejected spans and final completion. SHA hashes the
admitted text snapshot; exclusive JSON retains failure/exit1. Six adversarial
tests prove evidence/special-file admission only. Physical target/instruction/
hardware identities are separate; see ../docs/NATIVE_TURING_MMA.md.

Matrix parser MODE,turing_mma_split_weight_f16_f32 declares16x8 output geometry;
it cannot mix with staged-input TILE metadata. Unknown/duplicate/late modes reject.
Legacy SIMT defaults remain valid. Reports name the candidate and geometry meaning
and hash the admitted text snapshot. Eight portable tests pass. Precision budgets
are unchanged. Read ../docs/NATIVE_PACKED_TURING_MATRIX.md for complete native
versus selected-independent coverage and retained speed rejection.

MODE,turing_mma_staged_f16_f32,rows admits only16/32/64 with declared CTA/output/
staged-input geometry semantics. All prior complete/budget/model gates remain;
mixed/duplicate/late/unsupported mode metadata rejects. Nine portable tests pass.

MODE,turing_mma_staged_wide_f16_f32,rows,columns admits only rows32/64 and
columns64/128 with shared bytes<=49152. Ten portable contracts preserve legacy
32-column staging and reject unsupported/mixed/duplicate/late geometry. Reports
distinguish eight output-token columns from actual staged-input width. No budget,
model hash, complete-count or output-coverage gate is relaxed.

## check_turing_activations.py

parse requires ordered bounded regular/no-follow CSV with two exact replay
states, six complete four-token F32 sources,28 projection cases and every
output/whole guard/native metric/final count. Exact finite F32 text is mandatory.
Completion is distinct from numerical acceptance; summary never automatically
passes. independent validates original descriptors and selected Float64 dots from
exported original inputs using pinned test-only gguf/NumPy. main verifies the
original model digest before/after reading and exclusively preserves full failed
numeric reports/exit1. Nine adversarial contracts cover drift, source identity,
complete failures, special files and false metrics. No production inference or
full-model quality/timing claim. Read ../docs/NATIVE_TURING_ACTIVATIONS.md.

## check_turing_model_prefill.py

parse requires bounded regular/no-follow ordered actual-CUDA CSV, four exact
input streams and complete paired F32 logit vectors, all32 alternating samples,
committed positions, repeat checks, guards and totals. summarize never passes
collection automatically. provenance binds original/derived/converter identities.
independent uses pinned test-only CPU F32 inference for every final-prompt value;
main checks model hashes before/after and exclusively retains complete failures.
score withholds every ratio until all .05-max/.005-RMS/matching-argmax gates pass,
then excludes the one warm pair per prompt. Eight portable adversarial contracts
prove evidence/scoring only. No runtime inference/provider/decode promotion.
Read ../docs/NATIVE_TURING_MODEL_PREFILL.md.

Both captured-input/model checkers preserve legacy precision0 metadata and admit
only explicit precision1/2/3/4 extensions. Unknown/mixed/duplicate/late identity
rejects. Nonzero model score additionally requires native-reference RMS<=.0005,
while all old budgets remain. Every rescoring attempt clears earlier medians/
ratios before acceptance, so a later failure cannot retain a stale speed claim.
Ten captured-input and nine model contracts cover these boundaries. Read
../docs/NATIVE_TURING_ACTIVATION_RESIDUAL.md for precision/cost acceptance.

Precision3/4 identify scaled residual candidates; legacy0/1/2 remain admitted.
Every original and tighter model gate still owns scoring, with every failed ratio
withheld. Read ../docs/NATIVE_TURING_SCALED_RESIDUAL.md before interpreting results.
## check_turing_fixture_controls.py

Bounded regular/no-follow ordered CSV admission requires actual CUDA identity,
four exact control states, caller-owned SIGINT, reset/refusal/poison/guard/mask
proofs and every recovered F32 value. Accepted independent original-mode0 JSON
must bind its reference CSV/model and fixed budgets. Recovered bytes must equal
case1, including signed zero. Numerical failures retain complete exclusive
reports; speed_claim is alwaysFalse. Nine adversarial contracts cover identity,
state, mask, vectors, signed zero and binding. Read
../docs/NATIVE_TURING_FIXTURE_CONTROLS.md; this is test-only control evidence.

## check_turing_decode_quality.py

Records owns O_NOFOLLOW/O_NONBLOCK regular admission,2GiB byte cap,1024-byte
lines, bounded fields, same-descriptor EOF stability and streamed SHA. parse
requires ordered CUDA/policies/exact public-ID hashes/frames/complete finite F32
vectors/replay/guards/actual finish/totals, at most96 first-round predictions.
Only a frame's vectors/numerical scratch survive during comparison. case retains
every native/matrix choice and fixed numerical metric, even on quality failure.
CPUReference owns pinned test-only CPU F32 inference, context4096/F16KV/zero
GPU/four threads and exact native-forced IDs. main verifies original/derived/
converter provenance and before/after hashes, closes the oracle and publishes an
exclusive complete/partial failure report. Exit0 requires every original .05/.005/
argmax gate plus actual sample equality and exact own replay. speed_scored=False
always. Nine portable contracts are synthetic evidence validation only. Read
../docs/NATIVE_TURING_DECODE_QUALITY.md; no runtime/provider/restore promotion.

## check_turing_checkpoint_replay.py

accepted owns bounded no-follow SHA-pinned/duplicate/nonfinite rejecting decode
JSON, requiring complete independent mode0 acceptance and unchanged budgets.
parse uses Records with a smaller256MiB allowance and exact ordered policies/
public checkpoint IDs/tile boundaries/pending/state/guards/12 refusals/eight
continuation frames/full vectors/totals. case binds source choices, counts actual
F32-bit differences including signed zero and retains every numeric/replay failure.
CPUReference reuses pinned zero-GPU F32 inference on recorded native causal IDs.
main hashes original/derived models and accepted report before/after, always closes
the reference and preserves exclusive complete/partial failure reports. Exit0
requires every unchanged independent/native budget, source/sample/state/exact own
replay gate; all outcomes speed_scored=False. Nine synthetic portable contracts
do not prove GPU work. Read ../docs/NATIVE_TURING_CHECKPOINT_REPLAY.md.

## Batched rotary/cache evidence

attention_variant admits only one explicit0/1 grid32 identity before META.
Model parse binds actual rotary/cache host calls and176160832-byte guarded-cache
hashes; score requires fixture_reference fixed independent report/model/CSV
identity, exact native/matrix F32 bytes/IDs and cache equivalence before any ratio.
New1 requires explicit accepted baseline0; baseline0 may bind prior legacy0.
CSV/report/model hashes recheck after CPU comparison; KeyboardInterrupt preserves
failure JSON. Streamed decode/checkpoint parse shares strict metadata without
changing fixed quality/replay/source gates. Six portable grid contracts include
complete streamed variant and duplicate/late rejection. Read
../docs/NATIVE_TURING_BATCHED_ROPE_CACHE.md.

## Elementwise strategy2 evidence

attention_variant additionally maps the distinct rope_cache_elementwise_grid,1,32
marker to internal2; old rotary/cache2 remains unsupported. Model parse requires
exact ELEMENTWISE counts from admitted causal boundaries plus final norm. New2
fixture_reference requires explicit independently accepted1 with complete exact
vector/ID/cache/model/report identity. Streamed decode/checkpoint share the strict
marker and every prior quality/replay/source gate. Seven portable grid contracts
include complete streamed2 and explicit source-chain/counter refusal. Read
../docs/NATIVE_TURING_BATCHED_ELEMENTWISE.md; no provider promotion.

## Strategy-bound control recovery admission

Control reference now requires matching source variant/scope/totals and every
independent owner/case, strict duplicate/nonfinite JSON and exact parsed CSV/report
hashes. parse admits only known optional variant before META and matching golden
identity. main rehashes capture/source/model afterward and retains KeyboardInterrupt
failures. All reports keep speed_claim=False. Eleven portable control contracts
include strategy/metadata/source-mutation/interrupt/exclusive failures. Read
../docs/NATIVE_TURING_BATCHED_CONTROLS.md before interpreting acceptance.

## Cached-header primitive admission

check_packed_matrix admits only explicit header-cache64/32 mode with seven-field
exact finite F32 VALUE records, ordered native/cached/original samples,30 rotating
TIME records per case/840 total and final newline. validate preserves complete
new numerical failures; main retains all original/native/independent errors and
clears every ratio on failure, source mutation or interruption. Every model/CSV
digest rechecks after the pinned oracle. Fourteen portable matrix contracts
include signed-zero, rotation, source mutation and exclusive report refusal.
Read ../docs/NATIVE_TURING_BLOCK_HEADERS.md; no full-model/provider proof.

## Paired larger-row primitive admission

Explicit staged_large_rows128/32 mode shares strict seven-field exact F32 values
and30 rotating records/840 total. paired_original binds exact original64 bits;
cached_headers stays False. Original_to_candidate_ratio compares same-capture
owners, while header legacy retains original_to_cached_ratio alias. Complete
failures/source mutation/interruption clear both aliases and native ratios.128
only;256 refuses metadata. Sixteen portable contracts pass. Read
../docs/NATIVE_TURING_LARGE_ROWS.md before interpreting primitive acceptance.

## Source-bound down-only128 activation admission

check_turing_down_activations parses bounded strict three-owner F32 sources and
all28 ordered cases, derives down128 only for13/27 and recomputes metrics/guards/
bits. reference requires fixed independently accepted precision0 scope/numerical
case/row totals/model/CSV/report/state identity, then exact current causal/source/
native/original F32 bytes/descriptors. independent reuses pinned real-weight
oracle for new/native/original; main rehashes model/current/source CSV/report
afterward, preserving complete/partial/mutation/interrupt failures exclusively.
All reports speed_claim/full_model_quality_claim False. Ten portable contracts
pass. Read ../docs/NATIVE_TURING_DOWN_ACTIVATIONS.md; no model/provider promotion.

## Model-only down128 strategy3 admission

attention_variant adds allow_down=False; only model parse opts True for distinct
strategy3. Default shared decode/checkpoint/control/trace consumers still refuse. Parse
requires new admission/final newline/down source count, original elementwise and
cache records. Fixture reference3 requires explicit2 with full fixed CPU metrics/
values/argmax and zero-GPU F32 scope plus native comparisons/IDs/counters/cache.
All current vectors/cache remain exact. Main additionally rehashes derivation
provenance and clears every ratio/median on exceptions. Score computes all finite
medians/ratios before publishing any, so an overflow rejects all cases atomically.
Eight portable down contracts and prior contracts pass. Read
../docs/NATIVE_TURING_DOWN_MODEL.md; no provider/runtime selection.

## Explicit source-bound down128 decode validation

check_turing_down_source.accepted_model returns complete strategy3 model data and
exact admitted CSV/report/model SHA proof. Strict JSON/complete case/counter/ID/
cache/numeric coverage, .05-max/.005-RMS/argmax metrics, pinned zero-GPU expanded-
F32 identity and accepted strategy2 predecessor are mandatory; acceptance Boolean
alone is insufficient. Source hashes recheck before returning, with64MiB CSV/
5MiB JSON bounds through existing readers.

check_turing_decode_quality.parse adds keyword-only down_source=None. Default
refuses3; explicit source requires3, exact public IDs, source-derived initial/
replay down counts and source case1/3 starting F32 bytes, including signed zero.
Numerical source mismatches retain all complete frame metrics and fail acceptance.
CLI requires paired --down-model-csv/--down-model-report arguments. Every frame
retains independent/native full-vector budgets, sample/greedy/state/causal/replay
contracts. After oracle, original/derived/current CSV/derivation/source CSV/report
hashes recheck for the opt-in. All reports stay exclusive/unscored; interrupted
reference cleanup now also publishes failure. Original0/1/2 evidence stays valid.
Read ../docs/NATIVE_TURING_DOWN_DECODE.md for schema, limits and separate gates.
