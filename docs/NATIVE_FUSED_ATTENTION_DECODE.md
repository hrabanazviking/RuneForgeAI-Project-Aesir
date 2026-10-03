# Generation quality after fused attention prefill

Owner: native Mojo test collector and Python evidence supervision. Read
`TASK_fused_attention_decode.md`, `aesir_engine/tests/INTERFACE.md` and
`scripts/INTERFACE.md` before changing the contract. Strategy4 is explicitly
optional, strict3B/context1536/F16 KV/precision0 on the observed sm_75 GPU.
Production inference uses native Mojo; Python/NumPy/llama.cpp only validate tests.

## Build and collect

Build from the frozen repository environment:

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_decode_quality.mojo \
  -o /path/to/new-fused-decode-probe
```

Finish both target builds, original collector, master, normal build and normal
check before serial GPU collection. Keep all source/binary/build/UTC receipts.
Use a fresh private directory, exclusive `open("x")` stdout/stderr files, a
bounded child lifetime and retained process exit status. Example invocation:

```sh
/path/to/new-fused-decode-probe /path/to/original.gguf 4
```

Omission keeps strategy0; explicit0/1/2/3 preserve their previous schema. Unsupported
strategy5 refuses before model loading/CUDA, including with a nonexistent model.
Strategy4 requires original precision0, batched rotary/elementwise/down128 and fused
capability with controls/tracing disabled. Count4/32 prefill uses the checked fused
path after cache writes. Count1 decode keeps original attention kernels.

## Inputs, state and bounded storage

The public37/1070-token prefixes use greedy32 and seeded16 caps. Seeded policy is
temperature .7/top_k40/top_p .9/min_p .05/repetition1.1/window64/seed1234 with
actual F32 configuration. Export every128256 native/matrix logit at every frame.
Native chosen IDs teacher-force both owners; the last choice stays uncommitted.
Actual committed histories, positions, sampler histories/draws, selected IDs and
4352 guards must agree. Early EOS is reported with actual frames and finish reason.

Exactly two cap-sized pinned host snapshots, at most31.313MiB, hold full first-
round vectors. Fresh reset/replay compares every actual UInt32 F32 bit, including
signed zero, plus choices/history/draws. No additional device workspace is created.
`DOWN_ROWS128`/`REPLAY_DOWN_ROWS128` remain28/924. `FUSED_ATTENTION` binds actual
fused56/1008 and original queries28/56 after prefill. `REPLAY_FUSED_ATTENTION`
requires unchanged fused count and initial original count plus `(frames-1)*28`.
Scalar decode cannot silently enter a slower fused path or alter the prefill plan.

## Validate against accepted source and independent CPU

Read [full-model operation](NATIVE_FUSED_ATTENTION_MODEL.md) and retain its exact
accepted strategy4 CSV/report and actual compiled model probe. Use the pinned
optional reference environment from `SPEED_MEASUREMENT.md` (NumPy2.4.4 and
llama-cpp-python0.3.23), original and derived-F32 weight SHA256 identities and
retained derivation receipt. Supply the actual current decode binary/hash too:

```sh
/path/to/oracle-python scripts/check_turing_decode_quality.py /path/to/capture.csv \
  --model /path/to/original.gguf --model-sha256 ORIGINAL_SHA256 \
  --reference-model /path/to/expanded-f32.gguf --reference-sha256 DERIVED_SHA256 \
  --reference-provenance /path/to/derivation.json \
  --fused-model-csv /path/to/accepted-model4.csv \
  --fused-model-report /path/to/accepted-model4.json \
  --fused-model-binary /path/to/accepted-model4-probe \
  --binary /path/to/new-fused-decode-probe --binary-sha256 CURRENT_BINARY_SHA256 \
  --output /path/to/new-decode-report.json
```

The source triplet is mandatory together and exclusive with down-model strategy3
arguments. Default readers still reject4. `accepted_model(..., fused=True,
binary=...)` requires actual source binary SHA before/after, complete four-case
parsed/declarative logits/IDs/cache/down/rotary/elementwise/fused/original counters,
fixed numerical budgets, pinned zero-GPU expanded-F32 CPU scope and complete
accepted strategy3 predecessor byte/cache proof with exact CSV/report identities.
Duplicate JSON keys/nonfinite values/incomplete owners/changed artifacts fail.
Initial native and matrix vectors must match source case1/3 F32 bytes for both
sampling policies. A signed-zero change fails even when numerical metrics pass.

The independent CPU evaluates every actual native-forced causal frame with zero
GPU layers/context4096/F16 KV/batch128/four threads/no flash attention. Unchanged
.05 maximum/.005 RMS/full-vocabulary matching argmax budgets apply independently
to both owners and native-versus-matrix. Greedy choices must equal argmax; both
policies require sample equality and exact own replay. Numerical failures retain
all collected frame metrics and cannot be scored successful.

Streaming admission uses one no-follow regular descriptor, bounded2GiB/newline-
terminated UTF8 lines<=1024 bytes/16 fields/256 bytes per field, exact record order
and same-descriptor SHA/stat checks. Accepted model CSV is bounded64MiB and JSON
5MiB. Only the current vector pair is retained by the streaming checker.

Rehash current capture/binary, original/derived models, derivation and source CSV/
report/binary after oracle. The measurement supervisor also rehashes reviewed
source files before/after capture. Output JSON is exclusive. Exit0 requires every
complete gate; exit1 retains partial/complete errors, KeyboardInterrupt and failed
reference cleanup. Retry into fresh destinations and preserve all failed artifacts.

## Acceptance boundary and next step

`speed_scored` remains false: process/export/oracle times do not score inference.
This gate proves these native-forced greedy/seeded trajectories and fresh own
replay. It does not certify arbitrary free-running candidate trajectories,
persisted checkpoint restore, enabled control recovery, production32, broader
context/device/concurrency/soak or provider speed. Strategy4 sealed replay plans require the separate explicit
[owning-context gate](NATIVE_FUSED_ATTENTION_CHECKPOINT.md); control/trace
capabilities stay closed for separate gates. The authenticated
normal service retains its original binary and prefill4. Hosted compilation and
portable adversarial tests are distinct from physical GPU/CPU evidence.

[Retained measurement](evidence/fused-attention-decode-2026-10-03/README.md).
