# Batched normalization, residual and SiLU in the optional Turing fixture

Read [batched rotary/cache](NATIVE_TURING_BATCHED_ROPE_CACHE.md),
[workspace admission](NATIVE_TURING_FIXTURE_ADMISSION.md),
[decode quality](NATIVE_TURING_DECODE_QUALITY.md) and
[checkpoint replay](NATIVE_TURING_CHECKPOINT_REPLAY.md) first. This explicit
strategy2 extends the already accepted optional strategy1. Ordinary production
session policy and kernel definitions remain unchanged.

## Arithmetic and row ownership

core.dense_normalization adds a separate dense_norm_strided_kernel[width,stride].
The existing dense_norm_kernel definition/entry remains the scalar reference.
The new sibling retains each lane's chronological F32 sum, warp reduction,
epsilon/weight multiplication and store order. Compile-time admission requires
width>0 divisible128 and stride>=width. Runtime caller owns validated extents.

The strict fixture uses width3072/stride33824 with groups equal to admitted tile
count. Four warps normalize four independent token rows per128-thread block;
inactive warp groups never read/store or enter another warp's reduction. The
ordinary one-row path retains its existing kernel. This improves warp occupancy
and reduces launches without allocating another activation buffer.

Public always-inline llama_residual_cell and llama_silu_cell retain the original
addition and gate/(1+exp(-gate))*up order. Test-owned grid-y wrappers offset
admitted disjoint rows by33824 elements, keeping original global-x bounds.
For four/32 tiles, residual, FFN norm and SiLU remain separate dependent enqueues
on the owning stream; no per-token arithmetic is fused or reordered. All Q/K/V,
attention, packed projection and scalar output-head policies remain in place.

TuringPrefillFixture(path,precision=0,batched=False,elementwise=False) defaults
to the previous path. elementwise=True requires batched=True and precision0
before model loading, and those execution flags recheck before every tile.
Existing profile/layout/actual-length/headroom/control/commit/poison gates remain.
No new global device workspace or immutable-weight copy is introduced.

## Explicit identity and replay

execution_strategy returns0/1/2 for original, rotary/cache, or additionally
batched elementwise behavior. FixtureReplayPlan seals this identity with exact
owning allocations/policy/IDs/tile boundaries; native owner0 always stays0.
restore binds actual strategy before any reset/GPU operation. A changed strategy,
foreign owner or damaged plan refuses safely. Existing persisted data stays v1.

The model/decode/checkpoint probes now accept final flag2. They emit the new
ATTENTION,rope_cache_elementwise_grid,1,32 record before META. Old omitted/0/1
behavior and old metadata stay unchanged; rope_cache_grid,2,32 stays unsupported.
Unknown, duplicate, mixed, late or incorrectly sized metadata refuses admission.

The model collector records actual successful host ELEMENTWISE enqueue calls.
The old path uses5*28*input_count+1: two norms, two residuals and SiLU per layer,
plus final scalar norm. The new path uses5*28*tile_count+1 with original admitted
32/four/scalar boundaries. For public30/37/31/1070 IDs, grouped calls are
1261/421/1401/5321, versus original4201/5181/4341/149801. Existing rotary/cache
counts remain756/252/840/3192. These are host calls, not profiler GPU counters.

## Build, capture and check

Use the prepared locked Pixi environment. The existing model collector is shared
by explicit strategies0/1/2. Compile sm75/sm89 plus master and normal builds before
GPU measurements. Serialize GPU captures, then run pinned CPU oracles afterward.
From the repository root, using new artifact paths:

```bash
pixi run --frozen --no-install --offline mojo build -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_turing_batched_rope_cache.mojo -o /tmp/aesir-elementwise-prefill
pixi run --frozen --no-install --offline mojo build -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_turing_decode_quality.mojo -o /tmp/aesir-elementwise-decode
pixi run --frozen --no-install --offline mojo build -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_turing_checkpoint_replay.mojo -o /tmp/aesir-elementwise-checkpoint
pixi run --frozen --no-install --offline mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo
python3 scripts/launch.py --build --target sm_75
python3 scripts/launch.py --check
/tmp/aesir-elementwise-prefill MODEL.gguf 2 > elementwise.csv
/tmp/aesir-elementwise-decode MODEL.gguf 2 > decode.csv
/tmp/aesir-elementwise-checkpoint MODEL.gguf 2 > checkpoint.csv
```

Set original/derived model identities as described by the preceding rotary/cache
manual. The model checker requires the explicit independently accepted strategy1
CSV and report as --reference-csv/--reference-report. Strategy0 cannot substitute
for that source. Require all513024 values per owner/public IDs to match its exact
F32 bytes, including signed zero, and all full guarded-F16-cache SHA hashes to
match. Host counters, eight invalid tiles,4352 guards, repeats/committed state and
original independent .05/.005/full-vocabulary-argmax gates all remain mandatory.
Input/model/reference CSV/report hashes recheck after the oracle. Any gate failure
retains the complete evidence and withholds every ratio.

All32 warm/alternating fresh timings remain. Only accepted reports calculate a
fresh native-to-fixture exploratory ratio. Older timing is not a controlled
old-to-new speed score. Synchronized full-cache host copy/anonymous memfd SHA,
CSV export and CPU reference durations remain unscored. Transient host copy uses
176160832bytes/168.000061MiB; no persisted cache dump is created.

The complete96-frame greedy32/seeded16 decode/own-bit replay gate and eight-frame
owning-context checkpoint gate repeat with explicit strategy2. Their fixed CPU/
native/source/sample/state/guard/bit requirements remain unchanged; their reports
always have speed_scored=False. Test-only CPU inference never enters production.

## Scope and evidence

Read [physical evidence](evidence/turing-batched-elementwise-2026-10-02/README.md)
for full report metrics/hashes/process ordering and preserved attempts. Only the
original strict3B/context1536/F16KV/sm75 profile earns physical evidence. Other
width/stride/model/device combinations, wider contexts, fused attention, maximum
history/window wrap, production32, persisted/context recreation, concurrency/soak
and refreshed Ollama comparisons remain separate gates. Never turn a fixture
ratio into a general provider lead.
