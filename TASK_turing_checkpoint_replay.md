# SPD-01/02 — owning-context checkpoint replay with exact tile boundaries

Established2026-10-02 before implementation. Volmarr authorizes sequential slices
and pushes. f10f386 publishes passing96-frame native-forced decode/seeded fresh
replay under unchanged independent budgets. Normal admission remains one/four.
Earn a bounded reset/replay invariant before persisted-format/production32 work.

## Architecture and owned boundary

Existing native restore reblocks a flat saved token stream into four-token groups.
An optional32 prefix followed by scalar generated history cannot assume this
reblocking preserves its own exact arithmetic. Create a test-only pure replay
plan retaining copied committed IDs, exact original tile counts, policy/draws,
pending native token and owner weight/activation/KV identity. Validate all fields,
context1536/vocab128256/batch4-or32/counts/totals/tokens/policy/draw bounds and a
retained mutation checksum before any reset/reconfiguration/GPU operation. Refuse
wrong owner, busy/failed/controlled state and any damaged plan without mutation.
Recheck each plan at replay entry. No supplied code/command/filename in the plan.

Replay each owner with its recorded tile boundaries and sampling disabled; restore
the validated draw count only after owning-stream synchronization and exact
committed IDs/history/positions agree. Keep owner allocations and immutable
weights. Unexpected replay failure poisons that owner and requires context
recreation; no automatic reuse. Reuse existing kernels and sampler APIs. This is
same-process/owning-context in-memory reset/replay, not a new persisted format,
process-crash recovery or portable cross-device snapshot. Production v1 snapshots
and normal core/CLI/service policy remain unchanged.

## Physical acceptance fixed before code

Use the existing public37-token prefix, mode0 strict3B/context1536/F16KV and the
two policies already admitted in f10f386: greedy and seed1234/.7/40/.9/.05/1.1/
window64. Build eight causal scalar additions from the native choices, capturing
checkpoint45 committed IDs and the ninth pending choice. Preserve exact native
four-token and matrix32/four/scalar plans. Compare four subsequent native-forced
prediction frames before and after explicit reset/replay. All128256 logits per
frame/owner must match original own-owner F32 bits, including signed zero; actual
sample choices/history/draws/pending/IDs must agree. Old independent/native
.05/.005/matching-argmax budgets and native/matrix sample equality remain. Bind
checkpoint and continuation choices to accepted f10f386 public evidence, then run
pinned zero-GPU F32 CPU oracle on the complete exact causal IDs.

Preserve actual EOS/EOT: an unexpected terminal checkpoint/continuation is a
retained failed case, never hidden by prompt/seed/count changes. Export ordered
bounded regular/no-follow complete CSV<=256MiB, each full vector admitted one
frame at a time. Retain every numeric/replay failure without any speed score.
Guard both baseline/restored fixture states,4352 checks total. Record unchanged
allocation identities and explicit invalid-plan refusal before reset. Portable
master tests cover plan mutations/geometry/owner/policy/token/count/draw admission;
portable checker tests cover ordered complete state/causal/policy/vector/bitwise/
reference binding and failure retention. Add compile-only sm89 CI coverage.

All builds/master/normal rebuild finish before serialized GPU capture, pinned CPU
oracle afterward. Preserve failed attempts. Verify unchanged normal binary and
authenticated active readiness; update owning instructions, operation/evidence,
ledger/TODO/roadmap/DEVLOG; push and verify exact CI. No latency/provider ratio,
production32 admission, persisted v2 schema, context recreation, concurrency or
broader model/context/hardware claim follows from this slice.
