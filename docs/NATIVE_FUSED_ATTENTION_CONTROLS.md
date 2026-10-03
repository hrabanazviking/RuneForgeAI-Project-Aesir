# Cooperative cancellation and reset after fused attention

Read `TASK_fused_attention_controls.md` and the test/script ownership MD. This is
optional native Mojo strict3B/context1536/F16 KV/precision0 strategy4 on the observed
sm_75 GPU. Python/NumPy/llama.cpp remain independent test oracles. The authenticated
production service retains the original normal binary and prefill4 setting.

## Capability and failure policy

Final `fused_controls=False` keeps ordinary4 configure/start refusal. True requires
admitted fused4/batched rotary/elementwise/down128 and original down128 control and
trace flags disabled. Missing/foreign capability, bad precision/flags or tracing
refuse before model load or tile mutation. The old0..3 control contract remains.

Cooperative control checks occur before a tile and after synchronized layers. A
known timeout/cancellation/control-descriptor failure drains queued work, preserves
health, leaves the tile uncommitted and marks explicit reset required. Step/configure/
start refuse until reset. Reset preserves weight/activation/cache allocation identities,
clears sampler/history/deadline/started/reason/counters, then disabled-control recovery
must reproduce accepted full vectors exactly. A failed observer exception poisons
health; step/configure/start/reset all refuse. This tests unexpected-exception policy,
not hardware fault repair.10ms is a cooperative budget, not hard real-time latency.

The test owns SIGINT delivery to its current thread after8 synchronized layers. Its
caller consumes exactly one event and restores its signal mask after scope exit.
It does not send signals to another process. Control-capable4 sealed replay stays
closed until separately accepted; default-capability4 replay retains its own gate.
Tracing remains closed regardless of control capability.

## Build before serial collection

Use the frozen environment for both probes and both targets:

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_fused_attention_model.mojo \
  -o /path/to/new-capable4-model-probe
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_fixture_controls.mojo \
  -o /path/to/new-fused-control-probe
```

Finish sm75/sm89 controls and model, original collector, master, normal build/check
before any capture. Preserve each source/binary/build/UTC/error receipt. Use private
fresh evidence paths, exclusive stdout/stderr, bounded child lifetime and actual
exit/binary/CSV hashes. Unsupported strategy5 and fused control capability without
fused attention reject with nonexistent model before CUDA/model loading.

## First accept disabled-control capable4 model

```sh
/path/to/new-capable4-model-probe /path/to/original.gguf control-capable
```

With no final argument, this model probe retains default4. The capable run keeps
controls disabled and records `CONTROL_CAPABLE,4,1`; missing/legacy capability drift
and tracing are refused without state/counter/allocation mutation. Validate against
[accepted default4](NATIVE_FUSED_ATTENTION_MODEL.md) and its actual original binary:

```sh
/path/to/pinned-oracle-python scripts/check_turing_model_prefill.py /path/to/model.csv \
  --fused-attention --fused-controls \
  --binary /path/to/new-capable4-model-probe --binary-sha256 CURRENT_MODEL_BINARY_SHA256 \
  --reference-binary /path/to/accepted-default4-model-probe \
  --model /path/to/original.gguf --model-sha256 ORIGINAL_SHA256 \
  --reference-model /path/to/expanded-f32.gguf --reference-sha256 DERIVED_SHA256 \
  --reference-provenance /path/to/derivation.json \
  --reference-csv /path/to/accepted-default4.csv \
  --reference-report /path/to/accepted-default4.json \
  --output /path/to/new-capable4-model.json
```

Use pinned NumPy2.4.4/llama-cpp-python0.3.23 zero-GPU expanded-F32 reference,
context4096/F16 KV/batch128/four threads. Require all four cases/513024 logits per
owner, complete default4 F32 bytes/IDs/full176160832-byte guarded cache per case,
fixed .05 max/.005 RMS/full argmax independent CPU, own repeat bits,4352 guards,
eight invalid tiles and32 finite paired timing records. Actual down/fused/original/
rotary/elementwise counters remain. Predecessor source must include complete
accepted3 byte/cache proof and fixed full numeric/CPU scope, with actual default4
binary SHA. Rehash current/source binary/capture/weights/derivation/source CSV/report
after oracle. Default readers reject capable4 metadata. Any failure clears ratios
while retaining complete collected metrics. No cross-capture or provider lead follows.

## Then collect enabled abort and recovery

```sh
/path/to/new-fused-control-probe /path/to/original.gguf 4
python3 scripts/check_turing_fixture_controls.py /path/to/controls.csv \
  --fused-attention \
  --binary /path/to/new-fused-control-probe --binary-sha256 CONTROL_BINARY_SHA256 \
  --reference-binary /path/to/new-capable4-model-probe \
  --model /path/to/original.gguf --model-sha256 ORIGINAL_SHA256 \
  --reference-csv /path/to/model.csv --reference-report /path/to/new-capable4-model.json \
  --output /path/to/new-controls.json
```

Fused opt-in is exclusive with down128. Require actual source/current binaries and
hashes. Source admission is `accepted_model(..., fused=True, fused_controls=True,
binary=...)`; ordinary fused source defaults keep requiring control capability false.
Validate exact strict model/case/CPU/counter/cache/ID/source4 predecessor proof and
binary identities, not acceptance Booleans alone. Decode and ordinary sealed replay
source gates retain their closed-control4 profile.

Pre-expired deadline and invalid descriptor stop before layer0; actual10ms deadline
stops at observed1..27 synchronized layers; owned SIGINT stops after8. The aborted
32-token tile remains position0/committed0/reset-required, with sampler32 only for
mid-tile aborts. Every completed layer has one actual down/fused enqueue and zero
original queries. Each reset recovery of the public37 prefix requires actual down28/
fused56/original28 and full source case1 F32 bytes including signed zero. All four
recovered cases total513024 values per owner;9792 guards include abort/recovery/
poison. Observer exception after1 records down1/fused1/original0 and four refusals.
Reset-required reuse refusals check actual allocation/counter/state identities too.

## Evidence bounds and operation

Model CSV is bounded64MiB, JSON5MiB; control CSV64MiB and strict newline termination.
Model/capability/order/complete-vector/counter/guard/mask records are mandatory.
Duplicate JSON keys/nonfinite values/wrong owner scope/source hash/missing binary/
incomplete capability arguments refuse. Current capture/model/source CSV/report/
current/source binary hashes are rechecked after validation; supervisor code/binary
pre/post hashes must agree. JSON outputs are exclusive. Retain partial/complete
failures and KeyboardInterrupt, retry into fresh paths and keep all failed artifacts.

Fifteen adversarial model/control contracts and legacy gates accompany both opt-in
target builds; master190 passes/zero fails/one skip. Hosted compilation and portable
contracts are distinct from physical GPU/CPU proof. Disabled-model paired timings
are exploratory model timings; enabled controls always keep speed_claim false.
Unexpected hardware faults, persistent restoration/context recreation, general
models/contexts/devices, production32, concurrency/soak and provider lead remain
separate. Next earn owned fused stage tracing before broader runtime selection.

[Retained evidence](evidence/fused-attention-controls-2026-10-03/README.md).

Exclusive fused_tracing capability now has a separate
[owned attention/projection trace gate](NATIVE_FUSED_ATTENTION_TRACE.md).
Ordinary4/control4 profiles stay separate; trace-capable4 control/replay remains closed.
