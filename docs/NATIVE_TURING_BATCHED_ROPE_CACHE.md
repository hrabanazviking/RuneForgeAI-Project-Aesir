# Batched rotary/cache writes in the optional Turing fixture

Read [whole-model prefill](NATIVE_TURING_MODEL_PREFILL.md),
[workspace admission](NATIVE_TURING_FIXTURE_ADMISSION.md),
[decode quality](NATIVE_TURING_DECODE_QUALITY.md) and
[checkpoint replay](NATIVE_TURING_CHECKPOINT_REPLAY.md) first. The opt-in fixture
accepts only the existing strict Llama3B/context1536/F16KV/sm75 geometry and
original precision0. The ordinary runtime remains one/four-token prefill.

## Device ownership and causality

TuringPrefillFixture(path, precision=0, batched=False) preserves the original
rotary/cache enqueue path by default. With batched=True, a four/32-token tile
queues one Q rotation, one K rotation and one KV write across grid-y token rows.
Scalar tiles use the original entry points. Grid x retains the original lane/head
arithmetic, and row offsets use the admitted33824-element token stride.

core.llama3_kernels exposes always-inline llama_rope_transform and
llama_cache_cell device operations for the test-owned grid wrappers. Rotation
reuses the existing F64 angle reduction/F32 trigonometry and supplied validated
GGUF F32 divisor. Stores use the original F16 cast and per-layer/cache-row formula.
The old production kernel entry bodies remain unchanged. Calling an enqueued
kernel entry from another entry hit a pinned compiler offload error; the public
inline operations avoid that entry-point reuse without patching installed code.

Every row writes disjoint Q/K/KV positions. Owning-stream order completes the
three writes before the existing per-token causal score/softmax/attention path.
Each query still reads only positions0..its own position, including inside a
four/32-token tile. Future rows can be populated but never become query-visible.
No added global device workspace or weight copy is introduced. Existing strict
layout/physical-span/free-memory/control/commit/poison gates remain mandatory.

rope_cache_calls counts successful host enqueue call sites, reset before each
fresh fixture run. It is not a profiler GPU-kernel counter. For the public
30/37/31/1070-ID cases, original counts are2520/3108/2604/89880; grouped counts
are756/252/840/3192. This covers rotary/cache calls only, not all model launches.

## State preservation

FixtureReplayPlan adds execution strategy0/1 to its copied state and retained
mutation seal. Legacy constructor/admit calls default0; native owner0 permits
only strategy0. Matrix owner1 binds the actual batched flag. restore also refuses
nonzero precision, foreign strategy/owner/window/span/control state before reset
or GPU work. Exact original tile boundaries remain part of replay acceptance.
Existing persisted v1 data and public provider/session schemas remain unchanged.

Decode and checkpoint collectors accept optional final BATCHED0/1; omission
preserves legacy metadata. An explicit argument emits exactly one
ATTENTION,rope_cache_grid,FLAG,32 record after CUDA identity and before META.
Unknown, duplicate, mixed, late or unsupported records refuse admission. All
existing policies, sample/state/bit/guard/independent CPU gates remain unchanged.

## Build and measure

Use the prepared locked Pixi environment. Build every GPU executable and finish
master/normal builds before any capture; serialize GPU jobs, and run the CPU-only
numerical references afterward. Example, from the repository root:

```bash
pixi run --frozen --no-install --offline mojo build -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_turing_batched_rope_cache.mojo -o /tmp/aesir-grid-prefill
pixi run --frozen --no-install --offline mojo build -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_turing_decode_quality.mojo -o /tmp/aesir-grid-decode
pixi run --frozen --no-install --offline mojo build -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_turing_checkpoint_replay.mojo -o /tmp/aesir-grid-checkpoint
pixi run --frozen --no-install --offline mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo
python3 scripts/launch.py --build --target sm_75
python3 scripts/launch.py --check
/tmp/aesir-grid-prefill MODEL.gguf 0 > baseline.csv
/tmp/aesir-grid-prefill MODEL.gguf 1 > batched.csv
/tmp/aesir-grid-decode MODEL.gguf 1 > decode.csv
/tmp/aesir-grid-checkpoint MODEL.gguf 1 > checkpoint.csv
```

Use new exclusive artifact names; the shell examples assume no existing outputs.
CI compiles sm89 without claiming an sm89 physical measurement. No model weights,
private keys, input corpus or persisted cache bytes belong in Git.

## Full cache and numerical acceptance

After each complete model case, guarded_cache_digest copies all88080416 F16
cache elements to an owning synchronized host buffer. It writes176160832bytes to
an owned Linux anonymous memfd, hashes the exact descriptor through the existing
storage API and closes it on every path. It never writes a persistent cache dump.
The transient host copy costs168.000061MiB; hashing/export time is unscored and
outside model timings. A failed copy/write/hash/close aborts the collector.

check_turing_model_prefill.py accepts explicit variants only with both
--reference-csv and --reference-report. Baseline0 binds prior independently
accepted mode0 vector bytes/IDs. New1 requires an explicit independently accepted
baseline0 and exact IDs, native/matrix F32 bytes including signed zero, and all
four full guarded-cache hashes. Actual enqueue counts must match the admitted
causal plan. Reference CSV/report and input/model identities are hashed before/
after the CPU oracle. Incomplete, changed or failed references withhold all ratios.

Both variants retain all513024 values per owner, eight invalid-tile refusals,
4352 guards and32 raw warm/alternating timings. Unchanged independent CPU
.05-max/.005-RMS/matching-full-vocabulary-argmax gates and exact repetitions/
committed IDs remain mandatory. Only accepted reports calculate fresh native-to-
fixture prefill ratios. Older session timing is not a controlled old-to-new ratio.

Use the separately prepared pinned CPU-oracle Python environment. Define
AESIR_MODEL, AESIR_MODEL_SHA, AESIR_F32_REFERENCE, AESIR_F32_SHA and
AESIR_REFERENCE_PROVENANCE for the original model and documented F32 derivation.
accepted-mode0.csv/report.json are the prior independently passed complete fixture
artifacts. Each output must be a new path. For example:

```bash
python scripts/check_turing_model_prefill.py baseline.csv --model "$AESIR_MODEL" --model-sha256 "$AESIR_MODEL_SHA" --reference-model "$AESIR_F32_REFERENCE" --reference-sha256 "$AESIR_F32_SHA" --reference-provenance "$AESIR_REFERENCE_PROVENANCE" --reference-csv accepted-mode0.csv --reference-report accepted-mode0-report.json --output baseline-report.json
python scripts/check_turing_model_prefill.py batched.csv --model "$AESIR_MODEL" --model-sha256 "$AESIR_MODEL_SHA" --reference-model "$AESIR_F32_REFERENCE" --reference-sha256 "$AESIR_F32_SHA" --reference-provenance "$AESIR_REFERENCE_PROVENANCE" --reference-csv baseline.csv --reference-report baseline-report.json --output batched-report.json
```

Require exit0 and passed=True in both complete reports. Report identity includes
all four independent owner/case results, fixed scope/totals/budgets, and strict
duplicate/nonfinite JSON refusal. Keep failed reports and their raw capture files.

The complete96-frame greedy32/seeded16 decode/own-replay gate and eight-frame
owning-context checkpoint gate additionally run with explicit variant1. Each
retains its original fixed budgets, actual source/sample/state/bit/guard checks.
Those reports always have speed_scored=False. CPU F32 inference remains a
pinned optional numerical oracle, never AESIR's production provider.

## Scope and evidence

Read [the evidence directory](evidence/turing-batched-rope-cache-2026-10-02/README.md)
for full metrics, hashes, host counts, process/build ordering and preserved failed
attempts. Wider contexts/models/hardware, unscaled/NeoX families, actual GPU-fault
repair, persisted recovery, production32, concurrency/soak and refreshed provider
comparison remain separate gates. A fixture gain does not establish an Ollama lead.
