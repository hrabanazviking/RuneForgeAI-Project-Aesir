# SPD-03 — explicit fused attention cooperative control and reset recovery

Established 2026-10-03 before code. Model4 d075ede exact36-step CI passes.
Causal decode4 c78d713 and owning-context replay4 d6990ff pass complete physical/
CPU/source/bits/sample/state/counter gates; both pushed, exact CI pending.
Volmarr authorizes the next scoped implementation/push/repeat.

Add final fused_controls=False capability to native test fixture, exclusively with
admitted fused4/original precision0/rotary/elementwise/down128 and original3 control/
trace capabilities disabled. Pure constructor/flag admission precedes model load
or tile/reset/configuration/enqueue. Default4 configure/start still refuse. Explicit
capability enables existing cooperative layer checkpoint/drain/reset behavior;
tracing remains closed, no kernel arithmetic/workspace/production change. Keep
control-capable4 owning-context sealed replay closed for separate source acceptance.

Extend explicit control collector0..4, unsupported5 refuses pre-model/CUDA. Exercise
pre-expired deadline, actual10ms deadline at observed1..27 synced layers, caller-
owned SIGINT after8 synced layers, invalid cancel descriptor before0, and observer
exception after1. Healthy control abort stays uncommitted/reset-required; step/
configure/start refuse until reset; allocation-preserving reset recovers actual
complete source vectors. Unexpected exception poisons and refuses all reuse/reset.
Preserve caller signal mask and exactly-one signal ownership. Record down/fused/
original counters at abort/recovery/poison: one32 tile adds one fused/down call per
completed layer, original0; public37 recovery down28/fused56/original28.9792 guards,
all513024 recovered F32 values per owner and actual state/counters remain mandatory.

First collect a fresh disabled-control but capable4 whole-model run, all four public
cases/513024 values per owner/IDs/full guarded cache/own bits/fixed independent CPU/
4352 guards/eight invalid tiles/32 paired timings. Existing default4 model keeps
closed features; capable4 checks missing capability/legacy-control drift/tracing
mutation-free refusals before step. New explicit CONTROL_CAPABLE4 marker/CLI/reader
keyword stays default-closed. Bind fresh disabled model to accepted default4 CSV/
report/actual source binary before/after, complete prior3 byte/cache proof, full
numeric/CPU/counter scope and current actual binary SHA. Compare full source4 bytes/
cache/IDs; retain exploratory native/new timings without cross-capture/Ollama claims.

Controls validator requires explicit fused opt-in exclusive with down3, accepted
capable4 disabled model CSV/report/actual binary and current control binary hashes
before/after, complete strict JSON/numeric/public-ID/cache/counter/CPU/source4 proof.
Shared model/source defaults continue refusing controlled4; current decode/replay
source acceptance keeps its original closed-control4 profile. Full recovered UInt32
bytes including signed zero must match fresh accepted capable4 source1. Preserve
all complete numeric failures, interrupts/exclusive reports and capture/model/source/
current binary rehash. No control speed score or unexpected GPU-fault repair claim.

Portable hostile capability/counter/source/scope/bit/hash/interrupt/exclusive tests,
legacy controls/model/decode/replay/grid/trace gates and both opt-in targets join CI.
Finish all8 target/model/original/master/normal/check builds before serial disabled
GPU then CPU oracle, enabled GPU then validation. Retain every attempt/source/
binary/hash/UTC evidence and unchanged authenticated normal prefill4 service.
Publish detailed operation/evidence/owner/ledger/TODO/roadmap/devlog MD, push/exact
CI. Next earn owned fused stage tracing and broader context/device/concurrency/
soak/runtime/refreshed provider gates; SPD-03 and speed objective remain open.
