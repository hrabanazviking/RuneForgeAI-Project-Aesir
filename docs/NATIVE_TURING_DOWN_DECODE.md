# Decode and sampling after down-only128 prefill

Owner: native Mojo test fixture and Python evidence supervision. This operation
extends the opt-in [complete model gate](NATIVE_TURING_DOWN_MODEL.md), using the
same original strict3B weights, context1536, F16 KV, observed sm_75 and precision0.
Production inference remains native Mojo. Python/NumPy/llama.cpp are independent
test oracles and never a service backend.

## Build and collect

Read `TASK_turing_down_decode.md`, `aesir_engine/tests/INTERFACE.md` and
`scripts/INTERFACE.md`. From the repository, with its frozen environment:

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_decode_quality.mojo \
  -o /path/to/new-down-decode-probe
```

Finish sm_75/sm_89 builds, original collector, master and normal build/check before
serial GPU collection. Preserve failed binaries/source/logs and create a new
private evidence directory. Pass an explicit model path and strategy3:

```sh
/path/to/new-down-decode-probe /path/to/original.gguf 3 > /path/to/new-capture.csv
```

The supervisor must exclusively create the CSV (`open("x")`), bound the child
lifetime, retain stderr and record actual exit/binary/capture hashes. The shell
example alone does not ensure exclusive creation. Invalid strategy5 refuses
before model loading, including when the model path does not exist. Flags0/1/2
keep their prior schema and selection; omitted flag retains original0. New3 is
explicit and default-disabled. Strategy4 now has a separate explicit source/binary
gate documented in [fused decode](NATIVE_FUSED_ATTENTION_DECODE.md). No production settings, device workspace or GPU
arithmetic changes are introduced by the collector.

Public37/1070-token chat prefixes use greedy32 and seeded16 policies. Seeded
temperature .7/top_k40/top_p .9/min_p .05/repetition1.1/window64/seed1234 retain
their actual F32 representation. Export all128256 native/matrix logits at every
frame. Native selected IDs teacher-force both owners. The last sampled choice
is not committed; only preceding choices enter the exact causal history.

Exactly two cap-sized pinned host snapshots (at most31.313MiB) hold complete
first-round vectors for actual own fresh F32-bit replay, including signed zero.
Actual `DOWN_ROWS128` and `REPLAY_DOWN_ROWS128` records bind counters to28 calls
after the short prefix and924 after the long prefix. Scalar decode does not add
down128 calls. State records bind IDs, positions, sampler history/draws and replay
bit differences; causal checks compare actual committed IDs. EOS/caps,4352 guards
and complete totals remain mandatory.

## Validate with explicit accepted source

Use the pinned optional reference environment from `SPEED_MEASUREMENT.md`, with
NumPy2.4.4/llama-cpp-python0.3.23. Supply original and separately derived F32 model
SHA256 identities and its retained expansion receipt. Then:

```sh
/path/to/oracle-python scripts/check_turing_decode_quality.py /path/to/new-capture.csv \
  --model /path/to/original.gguf --model-sha256 ORIGINAL_SHA256 \
  --reference-model /path/to/expanded-f32.gguf --reference-sha256 DERIVED_SHA256 \
  --reference-provenance /path/to/derivation.json \
  --down-model-csv /path/to/accepted-strategy3-model.csv \
  --down-model-report /path/to/accepted-strategy3-model.json \
  --output /path/to/new-decode-report.json
```

Both down-model arguments are required together. Default decode validation and
default shared checkpoint/control/trace metadata readers continue refusing strategy3.
`check_turing_down_source.accepted_model` admits a complete accepted strategy3
model source, not a passed Boolean alone. It binds actual CSV/report/model hashes,
four complete cases, counters/IDs/cache/numeric coverage, unchanged fixed budgets,
pinned zero-GPU F32 oracle identity and exact accepted strategy2 predecessor proof.
Duplicate keys, nonfinite JSON, incomplete owner coverage and changed files fail.
Initial native/matrix vectors for both policies must exactly equal source case1/3
F32 bytes, including signed zero. Numerical disagreement retains complete metrics
and fails acceptance.

The independent CPU oracle evaluates every current frame on native causal IDs
with context4096/batch128/four threads/F16 KV/no flash attention/zero GPU layers.
Native-versus-matrix and each owner-versus-oracle retain .05 maximum/.005 RMS/full
vocabulary matching argmax budgets. Greedy choices must equal argmax; both policies
must have equal native/matrix samples and exact fresh replay/state/draws.

Streaming admission requires one no-follow nonblocking regular descriptor, at
most2GiB, newline-terminated strict UTF-8 lines<=1024 bytes,16 fields and256 bytes
per cell. Same-descriptor SHA/stat checks detect changes; only the current pair
of vectors is retained by the streaming checker. Accepted whole-model source is
bounded64MiB; its JSON receipt is bounded5MiB. These are evidence format limits.

After the oracle, rehash current CSV, original/derived models, derivation receipt
and accepted model CSV/report. New JSON output is exclusive and never overwritten.
Exit0 requires complete source/numerical/sample/causal/replay acceptance. Exit1
retains partial or complete failures, interruptions and cleanup failures; already
collected frame metrics remain. Incomplete evidence is never successful. Keep
all raw captures and failed receipts; retry into a new destination.

## Evidence boundary

This is a narrow teacher-forced trajectory and exact own fresh replay gate.
Process/export/oracle times are unscored; `speed_scored` is always false. It does
not prove free-running candidate generation, persisted checkpoint restoration,
enabled-control recovery, production32, other contexts/devices, concurrency/soak
or an Ollama/provider lead. Strategy3 [sealed owning-context replay](NATIVE_TURING_DOWN_CHECKPOINT.md) now has
an explicit source-bound gate. [Cooperative controls](NATIVE_TURING_DOWN_CONTROLS.md)
require separate default-disabled capability; tracing remains closed. Portable adversarial tests
prove evidence admission only; hosted target compilation is not GPU execution.
