# SPD-03/04 — opt-in batched rotary/KV launch reduction with exact state

Established2026-10-02 before implementation. Volmarr authorizes scoped repeated
slices/pushes. fb0db2a publishes passing owning-context exact-boundary replay;
95fe51d exact CI passes all36 checks. Normal runtime remains one/four tokens.
Next reduce independent per-token rotary/cache launches without changing arithmetic.

## Owned architecture

Add test-owned native Mojo grid-y wrappers that delegate to existing llama_rope,
llama_scaled_rope and llama_cache with token-stride/source-position offsets. Keep
global x/lane/head arithmetic and original F64-angle/F32-trig/F16-KV operations.
For admitted four/32-token fixture tiles enqueue Q rotation, K rotation and cache
write once each over disjoint token rows. Owning-stream order completes those
writes before unchanged per-token causal scores/softmax/attention. Each query
still sees only positions0..its own position. Scalar tiles retain original path.

Default opt-in flag is false, original counts/buffers/kernels preserved. Reuse
strict existing profile/workspace/span/control gates, no added global device
workspace or weight copy. Explicitly bind replay-plan execution strategy and
original precision0 before reset; refuse variant drift before mutation. Preserve
legacy constructor/schema behavior, add portable strategy-mutation coverage.
Count successful host enqueue call sites directly, labeling them host calls
rather than profiler-derived GPU counters. Reset counts per fresh fixture run.

## Fixed whole-model acceptance

Compile all variants/probes before owned GPU work. Collect explicit baseline0 and
batched1 full-model runs with the same four public30/37/31/1070-ID prompts and all
513024 logits per owner, eight invalid tiles, exact repeats/commits/4352 guards,
one warm pair plus three alternating fresh native/fixture pairs. Record actual
fixture rotary/cache host enqueue calls and full guarded F16-KV SHA-256 after
each case. Hash an actual synchronized host copy using an owned Linux anonymous
memfd and existing exact-descriptor digest API; close descriptors on every path,
no persisted KV dump or source-corpus access. Hash/export time is unscored.

Both baseline/new complete vectors and full cache hashes must equal each other
and original accepted mode0 IDs/vector bytes. All independent CPU/native fixed
.05-max/.005-RMS/matching-argmax gates remain. No speed ratio on any quality,
identity/byte/cache/count/guard/repeat failure. Preserve all32 timings per variant;
report native-to-candidate exploratory ratios only, not cross-session old-to-new
speed or provider lead. Actual host call counts must match admitted causal tile
plans: original3 per token per layer; batched3 per four/32 group and3 per scalar.

Also repeat the complete96-frame greedy32/seeded16 decode/replay gate and bounded
owning-context checkpoint gate with explicit batched metadata. Every original
sample/state/own-vector bit/CPU/source/guard condition remains. Numerical failures
retain complete reports; unknown/mixed/late/unsupported variant metadata fails
closed and never expands rejected precision refinements. Portable tests cover
legacy admission, metadata/count/cache/reference identity and strategy refusal.

Finish sm75/sm89/master/normal builds before serialized captures, independent
CPU checks afterward. Preserve every attempt. Verify unchanged normal binary and
authenticated readiness. Update owning interfaces/instructions/operation/evidence,
ledger/TODO/roadmap/DEVLOG; push and verify exact CI. Physical scope stays original
strict3B/context1536/F16KV/sm75. Broader unscaled/NeoX families, contexts/models,
persisted formats, context recreation, production32, concurrency/soak and refreshed
provider lead remain separate. No driver/dependency/counter-permission changes.
