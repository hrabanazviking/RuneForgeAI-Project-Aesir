For the bounded shared-score causal GQA primitive, read
docs/NATIVE_FUSED_CAUSAL_ATTENTION.md. Complete original bits/independent math
pass. Full4/32 improve, long single-query work loses. No selection; next prove
actual model/source-bound complete state before integration.

For the isolated paired FFN decision, read docs/NATIVE_TURING_PAIRED_FFN.md.
Complete original F32 bits and independent dots pass. Batch4 loses native and
batch32 loses staged; no selection. Next scope causal attention.

For rejected bounded runtime-group staging, read docs/NATIVE_TURING_LOOP_STAGING.md.
Both64/128 complete numeric gates pass but all56 original64 elapsed comparisons
lose. Keep original selection; next scope paired FFN gate/up staging reuse.

For the rejected16-column primitive speed experiment, read
docs/NATIVE_TURING_NARROW_STAGING.md. Both64/128 numerical gates pass, but all56
original64 elapsed comparisons lose; lower shared bytes alone earns no selection.
Preserve its evidence and use32-column width for the next loop-structure experiment.

For the explicit strategy3 resource/owned projection extension, read
docs/NATIVE_TURING_DOWN_PROJECTION_TRACE.md. Recordings guide experiments only;
complete source bits/cache/state and full-session correlation/resource gates
precede attribution. Default strategy2 and production4 stay unchanged.

# Project Aesir contributor orientation

For the optional accepted strategy2 inference-only CUDA timeline, read
docs/NATIVE_TURING_PREFILL_TRACE.md. Original full-session ownership/timestamp/
correlation gates precede named-range selection; complete actual F32/cache bytes
and committed state bind independent source acceptance. Trace time is unscored,
shared kernel names do not certify per-projection labels, and production remains
one/four. Retain all rejected profiler time-domain attempts.

For next matrix tuning use docs/NATIVE_TURING_PROJECTION_TRACE.md first. Default-
disabled projection labels bind actual tensors and source32/4/1 plans; complete
launch correlations give per-stage/batch attribution without synchronization or
speed scores. Missing/extra/overlapping/foreign-thread ranges withhold admission.

Read TODO.md, CAPABILITY_LEDGER.md, AI.rules.part2.md, RULES.AI.md and the owning
INTERFACE.md before changing code. The capability ledger owns present-tense truth;
historical roadmaps and attractive filenames are not evidence of runtime support.
Write and publish a task contract before substantial implementation. Preserve
reference code, user artifacts, model bytes and unrelated changes.

Native inference is Mojo. Python scripts only prepare, supervise, test or measure
it; no provider substitution belongs in compute. Loader owns validated GGUF
spans, core owns numerics/session state, CLI/server own configuration and socket
contracts. Current narrowly exercised second-brain native profile is Llama 3.2
3B Q4_K_M on an RTX 2060 Max-Q, sm_75. Do not infer broad models/devices from that.

For builds/readiness see docs/LOCAL_LAUNCH.md and docs/SECOND_BRAIN.md. For prefix
ownership, cancellation, reset and sampling see docs/NATIVE_PERFORMANCE.md. For
packed arithmetic, fixed RMS tiles and performance evidence gates see
docs/NATIVE_EFFICIENCY.md. The hosted workflow compiles opt-in CUDA probes while
local physical tests must prove their actual execution separately.

Rebuild after final Mojo edits. Serialize GPU probes and benchmarks. Preserve
all raw failures, compare identical model/control/request/reply work and verify
the exact pushed CI revision. For four-token 3B prefill and compact checked buffers read
docs/NATIVE_LONG_TOKENS.md. The first independent 3B logit gate is documented in
docs/SPEED_MEASUREMENT.md: four final-prompt vectors through 1070 input tokens,
against test-only F32 expansion of the same packed weight values. Keep broader
numerical coverage, broader-profile batched prefill, broader-device speeds and
locked-runtime context recreation open until their own acceptance gates pass.
Keep private API keys and source corpus out of
repository commits, reports and prompts.

The focused performance program is [ROADMAP_AESIR_SPEED_LEAD.md](ROADMAP_AESIR_SPEED_LEAD.md).
Start new speed work with SPD-00: fair provider modes, independent full-model
logits, stage timing and the actual device traffic ceiling. The installed baseline
shows new long input and sustained output still lag Ollama; near-parity cached
32-token cases do not certify a general lead. The per-case 2×/3× goals are future
acceptance targets. The first SPD-00 measurement slice is implemented; detailed
tracing, complete cache/residency controls and multi-session quality/lead gates
remain open. Read docs/SPEED_MEASUREMENT.md and its evidence before SPD-01 work.
The wider BEST_IN_CLASS_GAMEPLAN.md program and current ledger retain authority.

For actual owned CUDA timeline evidence, read docs/NATIVE_CUDA_TRACE.md. Preserve
raw traces privately; profiled wall time and overlapping API duration are not
service speed scores. The 2023 schema admission does not prove other versions.

The optional shared packed matrix experiment is documented in
docs/NATIVE_MATRIX_CANDIDATE.md. Do not connect the first slower batch-four
candidate to default inference. Primitive evidence does not meet full-model gates.

Matrix staging tuning preserves the original optional32/32 tile; no tested
four-token candidate earns promotion. Read docs/evidence/matrix-tile-tuning-2026-10-01/README.md.
Next large-gain prerequisite is actual locked-runtime sm_75 Tensor-Core math.

The optional Turing fixture now has separately documented primitive, full-model,
ownership, cooperative-control and post-prefill decode/replay gates. Read
docs/NATIVE_TURING_DECODE_QUALITY.md and current SPD-02 evidence for the latest
boundary. All96 declared native-forced greedy/seeded prediction frames pass;
normal production admission remains one/four. Preserve exact execution boundaries
for the next reset/restoration gate before runtime32 admission or provider claims.

Exact-boundary owning-context checkpoint replay now passes both declared policies;
read docs/NATIVE_TURING_CHECKPOINT_REPLAY.md. Persisted schema/context recreation/
long-history gates remain open. Next scope bounded batched causal attention and
launch reduction under exact existing vectors, before broader runtime admission.

For the next optional rotary/cache launch reduction, read
[batched operation](docs/NATIVE_TURING_BATCHED_ROPE_CACHE.md). Default fixture
strategy stays0; explicit1 must preserve complete vectors/cache hashes, existing
decode/replay/checkpoint gates and exact source/strategy binding before scoring.

The next optional independent normalization/residual/SiLU strategy2 is documented
in docs/NATIVE_TURING_BATCHED_ELEMENTWISE.md. Keep original entry definitions,
actual row/strategy admission, full source/vector/cache/continuation gates and
production policy intact. Physical fixture evidence does not promote providers.

Enabled-control evidence for optional strategy2 is documented in
docs/NATIVE_TURING_BATCHED_CONTROLS.md. Preserve actual layer/mask/state/byte
recovery and strict matching-source admission. Physical GPU-fault repair, broader
context/concurrency/runtime/provider support remain separate gates.
