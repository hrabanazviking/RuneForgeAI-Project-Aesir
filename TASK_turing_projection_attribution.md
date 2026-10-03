# SPD-00/01/04 — source-bound projection attribution before matrix tuning

Established2026-10-02 before code. Volmarr authorizes successive scoped slices
and pushes. fe832a7 earns owned strategy2 prefill tracing with complete source
F32/cache/state identity. Its long observed staged matrix duration is65.43% of
kernel duration and attention21.47%; shared names do not identify the projection.
Production stays one/four. This slice earns the missing measurement boundary.

Add default-disabled test-fixture projection tracing. Each query/key/value/
attention-output/gate/up/down/head label binds its actual loaded tensor owner
and batch1/4/32. Dynamically loaded installed NVTX stays owned by the direct probe;
only enabled diagnostic calls use its already-global symbols. No new dependency,
device buffer, arithmetic, synchronization or runtime dispatch. Default collectors
and source strategy remain unchanged. On callback/label failure the existing step
poison boundary applies; never execute an unlabelled fallback.

Extend the direct trace probe with an explicit diagnostic flag; legacy omission
keeps original CSV. New STAGES marker binds both plain/profiled inputs. Preserve
all source F32/cache/ID/state/count/guard gates. Trace checker additionally admits
ordered disjoint completed same-thread child projection ranges inside outer
synchronized prefill, exact expected counts derived from actual source tile plan,
and successful launch-end containment. Each actual projection launch/kernel must
belong to exactly one matching child range; nonprojection work cannot masquerade
as projection. GPU duration is projected through the launch correlation, not
required inside the asynchronous child CPU range. No interval clipping, guessed
tensor identity, per-layer timing, additive API/GPU sums or speed ratio.

Publish per-stage/per-batch actual launch/kernel counts, GPU durations and byte-
bound input geometry; retain the outer full-session trace and all failures. Add
portable wrong/duplicate/missing/overlapping/thread/range/launch/source/marker and
exclusive/interrupt/mutation gates, with strict bounded read-only exporter access.
Wire into existing CI proofs/compile steps. Finish both target/master/normal/check
builds before serial public37/1070 plain/profiled captures. Verify unchanged normal
binary and authenticated readiness; update interfaces/manual/evidence/ledger/TODO/
roadmap/devlog, push and exact CI. Use the result to choose the next matrix slice.
All diagnostic durations remain unscored. Broader runtime/context/device,
concurrency/soak/persistence, production32 and refreshed provider lead remain open.
