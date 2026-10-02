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
