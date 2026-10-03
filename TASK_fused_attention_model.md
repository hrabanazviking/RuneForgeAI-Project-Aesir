# SPD-03 — explicit fused attention complete-model gate

Established 2026-10-03 before code. Primitive implementation d350f5b is pushed,
exact CI pending. All39 cases/1370112 exact original F32 and independent outputs
pass. Full batches4/32 improve; long single-query histories lose. Preserve the
original single-token path. Volmarr authorizes scoped implementation/push/repeat.

Add final default-disabled fused_attention capability to the isolated fixture.
It requires original precision0, batched rotary/cache, elementwise and down128
strategy; controls and tracing capabilities remain closed before model loading.
Strategy4 is explicit; strategy0..3 and production one/four keep their existing
dispatch. At count4/32 after ordered batched RoPE/cache writes, enqueue the checked
native fused wrapper with actual query/attention spans, full F16 layer capacity,
current prefix, owned buffers/context and count. Count1 retains original attention.
No global buffers or workspace increase, no Python provider substitution.

Own an actual fused host-enqueue counter reset with the existing fixture counters.
Pure flags/strategy/control/trace checks run before step/configure/start mutation.
Three prohibited feature attempts preserve position, sampler IDs, allocations,
healthy state and every host counter; hostile constructor flags/capabilities
refuse before a nonexistent model is opened. Ordinary checkpoint plan strategy4
stays closed until its own source-bound replay gate; generation/controls/tracing
remain separate. Direct fixture state mutation is never a supported repair.

New opt-in full-model collector emits explicit attention4 marker, pure refusal
counts and actual fused/rope/elementwise/down counts. Reuse four public prompts
30/37/31/1070, all513024 values per native/matrix owner, own fresh UInt32 repeats,
input IDs, committed causal/sampler state, full guarded F16 cache SHA,4352 guards,
eight invalid tiles and all32 rotated timing records. Bind every current native/
matrix actual F32 value and cache hash to independently accepted prior down3.
Independently rerun the pinned dequantized-F32 CPU model oracle with unchanged
.05 absolute/.005 RMS/full-vocabulary argmax budgets and original model hashes.

Default shared parser/reference helpers keep strategy4 closed. Explicit CLI
admission enables only this full-model collector; ordinary decode/checkpoint/
controls/trace helpers continue refusing4. Before scoring require strict prior3
complete report/parsed CSV agreement for CPU scope, all independent/numerical
metrics, IDs, actual counters, cache and bit identities; source/model/CSV/report/
derivation hashes before/after and exclusive failed/interrupted JSON. Finite
atomic ratios and all original failure-retention rules remain. No cross-capture
previous3/new4 timing score; only same-capture native production4/new4 exploratory
ratios. Actual per-batch enqueue count derives from full admitted tile plan.

Portable adversarial scope/marker/counter/source/bit/cache/independent/hash/
interrupt/finite/exclusive contracts and opt-in native compile join existing CI.
Finish allsm75/sm89/original/master/normal/check builds before GPU then CPU oracle.
Retain every attempt, source/binary/model/CSV/UTC hash and unchanged authenticated
normal readiness. Publish technical MD/owners/ledger/TODO/roadmap/devlog/evidence,
push/exact CI, then earn causal generation/replay/controls/context/device/
concurrency/soak/runtime/provider gates separately.
