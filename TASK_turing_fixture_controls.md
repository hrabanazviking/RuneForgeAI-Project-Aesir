# SPD-01/02 — cooperative larger-tile controls and recovery

Established 2026-10-02 before implementation. Volmarr authorizes repeated scoped
slices and pushes. 329d5d5 publishes strict fixture workspace/device admission,
byte-identical previous mode0 vectors and independent gates preserving1.676x
long fixture prefill. Normal runtime stays one/four. Earn larger-tile control
and explicit reset semantics in the isolated fixture before production integration.

## Owned architecture and state

Reuse core GenerationControl for monotonic deadlines and caller-owned pollable
cancellation. Add a pure tests/turing_fixture_control.mojo policy for enabled/
started/reset-required/reason/completed-layer state. Validate configuration and
start before enabled use; disabled legacy fixture calls keep their existing
queue/synchronization policy. Reject busy/failed/reset-required configuration,
start and tiles. Core never consumes/closes the caller's cancellation descriptor.

An enabled fixture checks control before mutation, after each synchronized layer,
and after final synchronization before commit. Cooperative cancellation/timeout/
poll error drains only the owning stream, marks explicit reset required and leaves
position/committed IDs unchanged for the interrupted tile. Already queued sampler
history can be uncommitted; never reuse it. Successful drain preserves healthy
state solely to permit explicit reset. A drain/GPU/unexpected callback failure
leaves healthy=False and rejects reuse/reset until context recreation. No hard
real-time/preemption guarantee. Checked ownership/admission remains mandatory.

Explicit reset clears sampler/history/position/control deadline and abort state
after successful synchronization, preserving immutable weights/allocated buffers.
Stale KV beyond position is never visible: cache reuse remains disabled and new
causal prefill overwrites its required positions. A test-only thin layer observer
defaulting to no-op permits deterministic real SIGINT injection after8 completed
layers; it owns no production endpoint and runs only under enabled test control.

## Fixed acceptance

Register one portable master control-policy case: disabled behavior, required
start, invalid config, expired monotonic clock, abort reasons/reset requirement,
non-mutating invalid transitions and explicit reset. Sync master/ledger counts.
Compile master and sm75/sm89 probes, rebuild/check unchanged normal binary, and
finish all compilation before physical captures.

An owned strict3B/context1536 mode0 physical control probe creates ChatInterrupts
before CUDA workers. Exercise pre-expired deadline, real10ms mid-tile deadline,
real SIGINT after8 synced layers, and invalid poll descriptor. Require healthy
drain, no partial position/ID commit, refusal before explicit reset, unchanged
weight/buffer identity and complete post-reset reference/matrix logits for the
existing37-token public prompt. Compare every recovered F32 value/ID byte-for-byte
against the previous accepted case1 vectors. Guard every attempt, preserve failed
ones; do not alter a budget to force a pass. Owner consumes SIGINT after refusal.
Also inject one unexpected observer exception after1 synced layer: require
healthy=False, reset/config/start/tile refusal and guards; this proves exception
policy, not an actual GPU-fault repair. Verify restoration of owner signal mask.

Bounded ordered exclusive Python checker preserves complete failed control
reports, requires strict identities/counts/reasons/states/guard/mask/vector
regression and rejects missing/duplicate/mixed/late evidence. Add meaningful
portable adversarial contracts; CI compiles the new physical probe without
claiming execution. No control/recovery duration is a speed score.

Repeat complete disabled mode0 full-model collection and independent F32 oracle:
all513024 values per mode, exact repeats/commits,8 invalid tiles,4352 guards and
all32 warm/scored records under unchanged .05/.005/argmax gates. Compare previous
accepted complete vectors/IDs exactly. CPU oracles follow serialized GPU work.
Publish operators/owners/evidence/ledger/TODO/roadmap/DEVLOG and raw/source hashes;
verify authenticated active readiness, push and verify exact CI. Production
admission/generation/sampling/restore/concurrency, broader contexts and provider
lead remain separate gates. Rejected precision modes stay rejected.
