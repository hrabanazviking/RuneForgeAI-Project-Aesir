# Opt-in down128 cooperative cancellation and recovery

This is a test-owned strict3B/context1536/F16KV/sm_75 gate. It extends strategy3
[model](NATIVE_TURING_DOWN_MODEL.md), [decode](NATIVE_TURING_DOWN_DECODE.md) and
[sealed replay](NATIVE_TURING_DOWN_CHECKPOINT.md). Production inference remains
Mojo; Python/NumPy/llama.cpp are independent test oracles. Production defaults
and the original down128 default remain unchanged.

## Capability and admission

`TuringPrefillFixture` adds final `down128_controls=False`. True requires down128
before model loading, plus original precision0/batched/elementwise/strict geometry/
observed device/workspace gates. Pure execution-flag admission rechecks the
capability before step/configure/start/reset replay. Ordinary down128 still
refuses enabled controls; explicit capability True uses existing `FixtureControl`
deadlines, caller-owned cancellation descriptor and synchronized layer checkpoints.
Projection tracing remains closed. No additional device workspace or arithmetic.

Cooperative stop drains already enqueued work, keeps healthy ownership and leaves
the tile uncommitted/reset-required. Further step/configure/start operations
refuse until explicit reset. Reset clears uncommitted sampler/history/control
state and preserves weights/activation/cache identities. Unexpected observer,
GPU or drain failure poisons the owner; reuse/reset refuses. This is cooperative
recovery after a successful drain, not GPU-fault repair or hard real-time control.

## Build before serial hardware work

Read `TASK_turing_down_controls.md` and the tests/scripts interfaces. In the
frozen repository environment, compile both model and control collectors:

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_down_model.mojo \
  -o /path/to/new-down-model-probe
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_fixture_controls.mojo \
  -o /path/to/new-down-control-probe
```

Finish sm_75/sm_89 model/control, original control, master and normal build/check
before GPU capture. Use one new private directory, exclusively created stdout
CSVs, bounded child processes, retained stderr/exits/binary/model/capture hashes.
Never overwrite evidence or use service credentials/corpus as fixtures.

## First earn the disabled control-capable source

```sh
/path/to/new-down-model-probe /path/to/original.gguf control-capable > /path/to/new-model.csv
```

The capability is True but actual controls remain disabled. The distinct
`CONTROL_CAPABLE,3,1` marker follows original strategy3 admission. Negative control
settings and closed projection tracing refuse before mutation; ordinary model
mode keeps its prior two refusals and schema. `reject-controls` with nonexistent
model rejects invalid capability/down combination before loading/CUDA.

Use `check_turing_model_prefill.py` as described in the model manual, with accepted
strategy2 CSV/report, original/expanded-F32 identities/derivation, pinned zero-GPU
oracle and a new JSON output. All four public30/37/31/1070 cases,513024 values per
owner, full guarded-cache/IDs/state/own fresh bits,4352 guards/eight invalid tiles/
32 fresh paired timing records remain. Unchanged .05-max/.005-RMS/full-argmax
CPU/native/source gates must pass. Explicitly compare every native/matrix F32
byte/input ID/full cache SHA against prior accepted3 before control capture.

Model parse/report and `accepted_model` bind capability as an actual Boolean;
absence means original False. Duplicate/unknown/late markers or disagreement
between source CSV and report refuse. Only same-capture native/new timings may
score after complete gates; no historical control-capable/previous3 time ratio.

## Then collect and validate enabled recovery

```sh
/path/to/new-down-control-probe /path/to/original.gguf 3 > /path/to/new-control.csv
python3 scripts/check_turing_fixture_controls.py /path/to/new-control.csv \
  --down128 --model /path/to/original.gguf --model-sha256 ORIGINAL_SHA256 \
  --reference-csv /path/to/accepted-control-capable-model.csv \
  --reference-report /path/to/accepted-control-capable-model.json \
  --output /path/to/new-control-report.json
```

Shell redirection alone does not guarantee exclusive capture; use a supervisor
with `open("x")`. Explicit strategy3 constructs down128_controls=True. Flags0/1/2
and omission retain prior selection/schema; invalid4 refuses before signal/model
ownership. Default validators refuse3. `--down128` requires independently accepted
complete strategy3 source with control_capable=True, fixed complete numeric/
counter/cache/ID/predecessor/zero-GPU F32 proof. An old incapable3 source refuses.

The physical four cases are pre-expired deadline,10ms deadline, SIGINT delivered
to the owned test thread after eight synchronized layers, and invalid cancellation
descriptor. Actual `ABORT_DOWN_ROWS128` count must equal completed layers. Each
successful drain leaves position/committed IDs0, healthy/reset-required, with32
uncommitted sampler IDs only after partial work. Three reuse refusals preserve
state; caller consumes exactly one SIGINT and retains its signal mask/descriptor.

Explicit reset then disabled fresh prefill exports all513024 recovered values per
native/matrix owner across four cases. Every F32 byte, including signed zero,
must equal the accepted source case1. `RECOVERED_DOWN_ROWS128` requires28 calls.
Unexpected observer exception after one layer must poison the owner and cause
four reuse/reset refusals; `POISON_DOWN_ROWS128` requires1. All9792 guards and
caller mask restoration remain mandatory. Deadline elapsed time is not guaranteed.

Bounded64MiB no-follow regular UTF-8 capture/source reading, complete ordered
vectors/records, final newline and strict JSON source admission remain. Rehash
model/current capture/accepted source CSV/report after validation. New JSON is
exclusive. Exit0 requires all complete control/state/guard/source-byte gates;
exit1 retains partial/complete/numerical/structural/mutation/interruption failure
evidence. Keep failed sources/logs/raw artifacts; retries use new paths.

## Scope

Enabled recovery reports always have speed_claim=False. The separately accepted
disabled model's paired medians are exploratory prefill data. Portable tests
prove admission only; hosted compilation is not GPU execution. This gate does
not enable production32, broader contexts/devices, concurrent/soak workloads,
persisted/crash/context recreation, GPU-fault repair, free-running candidate
quality or provider speed leadership. Strategy3 projection tracing remains closed.
