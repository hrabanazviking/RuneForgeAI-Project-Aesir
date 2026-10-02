# Project Aesir contributor orientation

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
