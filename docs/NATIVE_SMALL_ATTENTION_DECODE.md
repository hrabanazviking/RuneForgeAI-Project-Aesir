# Causal generation after small-score prefill

Explicit strategy5 is a default-disabled native Mojo test fixture for the
exercised Llama3.2 3B/sm75/context1536/F16 KV/original activation precision0.
Read `TASK_small_attention_decode.md`, the test/script ownership interfaces and
[the accepted small-score model](NATIVE_SMALL_ATTENTION_MODEL.md) before changes.
Production inference remains native Mojo. Python/NumPy/llama.cpp validate tests.

## Native execution and state

The collector accepts explicit0..5; omission remains0 and6 refuses before model
loading/CUDA, including a nonexistent model. Strategy5 requires original fused4,
down128, batched rotary/cache and elementwise; controls/tracing stay disabled.
Actual four/32-token prefill uses small scores. Every generated single token uses
the original scalar attention. Neither new workspace nor precision changes enter
this slice. Existing0..4 interfaces remain available.

Public37/1070-token prefixes use greedy32 and seeded16 caps. The actual seeded
F32 policy is temperature.7/top_k40/top_p.9/min_p.05/repetition1.1/window64/
seed1234. Native chosen IDs teacher-force both owners. All vocabulary outputs,
selected IDs, committed history/positions, sampler history/draws and guards bind.
The final chosen ID remains uncommitted. Early EOS uses actual frames/reason.

Exactly two cap-sized pinned host snapshots (at most31.313MiB) retain first-round
vectors for fresh reset/replay. Replay compares every actual UInt32 F32 bit,
including signed zero, and exact choices/history/draws. All96 frames/12312576
values per owner and4352 guards pass in this session. Initial vectors equal
accepted model5 case1/3 bytes under both policies.

`DOWN_ROWS128` initial/replay stays28/924. `SMALL_ATTENTION` initial/replay stays
56/1008. `FUSED_ATTENTION` initial/replay must be0. Original scalar queries start
28/56 and replay adds `(frames-1)*28`. Each dispatch count binds the actual plan;
scalar generation cannot silently re-enter batched small/fused attention.

## Build, supervise and validate

Finish both targets, original collector, source-model collector, master, normal
build and normal check before physical capture. Preserve distinct binaries,
reviewed sources, build receipts and UTC process times. Never compile or edit
native sources during capture. Choose a new private destination; supervise stdout/
stderr with exclusive creation, bounded lifetime and owned process-group cleanup.
Retain every partial or failed attempt. Serial GPU collection precedes CPU oracle.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_decode_quality.mojo \
  -o "$ARTIFACTS/small-decode"
"$ARTIFACTS/small-decode" "$MODEL" 5 > "$ARTIFACTS/complete.csv"
"$ORACLE_PYTHON" scripts/check_turing_decode_quality.py "$ARTIFACTS/complete.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-model "$REFERENCE_MODEL" --reference-sha256 "$REFERENCE_SHA" \
  --reference-provenance "$REFERENCE_PROVENANCE" \
  --small-model-csv "$SOURCE_CSV" --small-model-report "$SOURCE_REPORT" \
  --small-model-binary "$SOURCE_BINARY" \
  --binary "$ARTIFACTS/small-decode" --binary-sha256 "$BINARY_SHA" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_small_attention_decode.py
```

Shell redirection can overwrite; use fresh files or the exclusive supervisor.
Use the actual accepted model5 executable, CSV and JSON, not a newly rebuilt
source binary. The small source triplet is mandatory together and exclusive with
down3/fused4 source arguments; current binary/SHA are mandatory. Defaults and
old source loaders reject5. Partial/exclusive arguments fail before GPU/CPU work.

`check_small_attention_source.accepted_model(...,small=True,binary=...)` reparses
all four source cases and recomputes complete summaries/score. It validates actual
CSV/report/binary identities, original precision, disabled controls, full vectors,
IDs/cache/rotary/elementwise/down/small/closed-fused/original counters and finite
paired timings. Fixed native and both independent CPU owner budgets, pinned CPU
scope/library identity and exact complete source4 byte/cache/ID predecessor proof
are required. Duplicate keys/nonfinite JSON and Boolean-as-integer totals/counters/
IDs refuse. A passed Boolean alone never establishes accepted source identity.

The independent pinned NumPy2.4.4/llama-cpp-python0.3.23 expanded-F32 oracle reruns
every actual native-forced causal frame with zero GPU layers/context4096/F16 KV/
batch128/four threads/no flash attention. Unchanged.05 maximum absolute/.005 RMS
and matching full-vocabulary argmax apply separately to both owners and the native
comparison. Greedy samples equal argmax; both policies require sample equality,
exact own replay and state. Numerical failure retains full collected metrics.

CSV admission streams one regular no-follow descriptor, bounded2GiB/UTF8 complete
lines<=1024 bytes/16 fields/256 bytes per field, exact order and descriptor SHA/stat.
Only the current vector pair is retained by the checker. Source CSV/JSON stay
bounded64MiB/5MiB. All eight artifacts (current CSV/binary, original/derived models,
derivation, source CSV/report/binary) rehash after oracle. Supervisor reviewed
source/binary/model/provenance preflight, after-GPU and postflight hashes agree.
Exclusive JSON retains complete/partial failed gates, KeyboardInterrupt and cleanup
failures. Exit0 requires the entire declared scope; retry into a fresh destination.

## Evidence and remaining gates

Taskdb33ba8 preceded code. Twelve portable hostile contracts and existing model/
fused/down/decode/replay/control contracts pass. All seven native builds precede
serial physical GPU/CPU; master190 passes/zero fails/one skip. An initial hostile
test exposed Python Boolean/integer equality in source admission. Explicit integer
checks fixed it before physical collection; the failed log/source remain retained.

`speed_scored` is false. Process/export/oracle times do not score inference.
This gate proves these public native-forced greedy/seeded trajectories and fresh
own replay. It does not establish free-running candidate distributions, sealed
checkpoint restoration, enabled controls/tracing, production32, broader contexts/
devices/concurrency/soak or provider/Ollama speed. The normal authenticated service
stays ready with prefill4/cpu_offload0. Next earn owning-context sealed replay5,
then separate control/trace and broader runtime/provider acceptance.
[Complete evidence](evidence/small-attention-decode-2026-10-03/README.md).
