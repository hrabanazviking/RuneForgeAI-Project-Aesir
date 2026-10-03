# Sealed owning-context replay with down-only128

This operation extends [strategy3 decode](NATIVE_TURING_DOWN_DECODE.md). It owns
a test-only strict3B/context1536/F16KV/sm_75 fixture using original precision0,
batched rotary/cache/elementwise and down128. Production inference remains Mojo.
Defaults and production one/four-token admission remain unchanged.

## Checkpoint ownership

`FixtureReplayPlan` copies committed IDs/tile boundaries and seals mode, execution
strategy, context/vocabulary, weights/activation/cache identities, pending token,
sampling configuration and draw count. Its FNV seal detects accidental mutation;
it is not authentication or a persisted file format. Native mode0 requires
strategy0; matrix mode1 admits the matching0/1/2/3 owner only. Strategy4 refuses.

`restore` checks the seal, exact allocation/configuration ownership, pure execution
flags, healthy/idle/control state and geometry before sampling configuration or
reset changes. Shared pure `admit_execution_strategy` checks flags without GPU or
state mutation; a changed down128/batched/elementwise/precision/trace/control
combination refuses. Replay uses exact original tile boundaries and committed IDs,
then restores RNG draw count and verifies buffer identity/history. GPU or replay
failures poison the actual owner and propagate a clear error. This does not
repair GPU faults or recreate a context.

## Build and capture

Read `TASK_turing_down_checkpoint.md` and the tests/scripts interfaces. Build the
opt-in collector in the frozen environment:

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_checkpoint_replay.mojo \
  -o /path/to/new-down-checkpoint-probe
/path/to/new-down-checkpoint-probe /path/to/original.gguf 3 > /path/to/new-checkpoint.csv
```

Use an exclusive private capture (`open("x")`) and a bounded supervisor retaining
stderr/exit/binary/model/CSV hashes. Shell redirection alone does not enforce new
destinations. Finish both target/original/master/normal/check builds before serial
GPU collection, then run the independent CPU oracle. Invalid strategy5 refuses
before model loading/CUDA, including with a nonexistent model path. Flags0/1/2
and omitted0 preserve their prior schemas and behavior.

Greedy and seeded policies use the public37-token prefix plus eight native-chosen
scalar additions, making45 committed IDs. Plans retain original native4/scalar
and matrix32/4/scalar boundaries. Four continuations per policy export all128256
baseline-native/matrix and restored-native/matrix logits. The pending sampled ID
is replayed at the exact boundary; each final sample remains uncommitted.

New3 exports actual `DOWN_ROWS128` and `RESTORED_DOWN_ROWS128` counts28. For each
policy, four damaged fields per native/matrix plan (tile, owner, draws, strategy)
plus matrix execution-flag drift produce nine pre-reset refusals,18 total. Healthy
sampled/committed state, actual history, counters and buffer ownership must remain
unchanged. Existing guard/mismatch/sample/state checks remain; complete totals
require1026048 values per owner/eight frames/4352 guards/18 refusals. The two
four-frame pinned host snapshots add no device workspace.

## Source-bound independent validation

Use the accepted complete strategy3 decode JSON, its explicit SHA256 and the
original/expanded-F32 model identities/derivation receipt:

```sh
/path/to/oracle-python scripts/check_turing_checkpoint_replay.py /path/to/new-checkpoint.csv \
  --down128 --model /path/to/original.gguf --model-sha256 ORIGINAL_SHA256 \
  --reference-model /path/to/expanded-f32.gguf --reference-sha256 DERIVED_SHA256 \
  --reference-provenance /path/to/derivation.json \
  --accepted-report /path/to/accepted-strategy3-decode.json \
  --accepted-report-sha256 DECODE_REPORT_SHA256 \
  --output /path/to/new-checkpoint-report.json
```

Default validation refuses3. Explicit `--down128` requires matching strategy3
metadata and source, complete96-frame quality/sample/causal/replay metrics,
accepted model proof/initial source vectors, public input identities, actual
initial/replay down counts, fixed numeric values/argmax and pinned zero-GPU F32
CPU scope. A passed Boolean cannot hide failed or incomplete owner metrics.
Source reports are strict duplicate/nonfinite JSON, bounded1MiB and SHA-bound.

Checkpoint IDs and pending/continuation native/matrix choices bind to the accepted
decode source. The CPU oracle evaluates all four owners at each current frame on
actual native causal IDs. Keep .05-max/.005-RMS/full-vocabulary matching-argmax
budgets, sample equality, exact causal positions/history/draws and actual F32-bit
replay, including signed zero. Reported mismatch counts must equal recomputed
complete-vector bits. No error budget or vocabulary is relaxed.

Current CSV is bounded256MiB, with the original one-descriptor regular/no-follow/
nonblocking streaming limits (1024-byte newline UTF-8 lines,16 fields,256-byte
cells). Only current vectors remain in checker RAM. Rehash original/derived
models/current CSV/derivation and re-admit the SHA-bound source after oracle.
New JSON output is exclusive. Exit0 requires every complete gate; exit1 preserves
partial/complete/structural/numerical/changed-source/interruption/cleanup failures.
Keep every raw artifact and failed receipt; retries require new destinations.

## Evidence boundary

The operation proves same-process owning-context reset/replay for these two
public policies and boundaries. It does not prove a persisted format, process-
crash recovery, context recreation, broader histories/devices, free-running
candidate quality, enabled controls, production32/concurrency/soak or provider
speed. `speed_scored` is always false; process/export/oracle timings are unscored.
Checkpoint replay requires idle uncontrolled ownership. Strategy3 [cooperative
controls](NATIVE_TURING_DOWN_CONTROLS.md) have a separate default-disabled capability;
projection tracing remains closed. Portable tests prove
admission only; hosted compilation never counts as physical GPU execution.

Strategy4 has a separate explicit plan/live/source/binary gate documented in
[NATIVE_FUSED_ATTENTION_CHECKPOINT.md](NATIVE_FUSED_ATTENTION_CHECKPOINT.md).
