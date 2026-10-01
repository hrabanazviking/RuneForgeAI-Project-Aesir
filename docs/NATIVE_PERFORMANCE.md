# Native performance and exact prefix reuse

The subsequent kernel-efficiency slice and fail-closed evidence comparator are
documented in [Native kernel efficiency](NATIVE_EFFICIENCY.md). The original
measurements below remain historical evidence for the earlier release.

The 2026-10-01 optimization executes inside native Mojo CUDA. Python tools only
supervise and measure the binary. Physical evidence applies to Llama 3.2 3B
Q4_K_M on the installed 6 GiB RTX 2060 (sm_75).

## Compute ownership

packed_projection.mojo processes validated 256-element Q4_K/Q5_K/Q6_K blocks as
eight compile-time groups. packed_quantization.mojo owns scales/bit decoding.
Projection hoists addressing and half scales, keeping the original lane sequence
and final warp sum. No dequantized model copy or GPU workspace is added. Dense
GQA dispatch selects this path for admitted aligned K matrices; other types keep
the generic reader. Scalar kernels remain correctness references. Gemma's
production projection path is unchanged.

dense_gqa_execution.mojo prepares tensor descriptors after strict validation and
before allocation. Forward execution borrows descriptors instead of constructing
layer names and looking up tensors at each token. Model/weight ownership stays
with the session. This path is shared by admitted Llama and Qwen profiles; the
current full-model physical gate exercised the installed Llama 3B only.

## Cache semantics and recovery

Llama/Qwen sessions retain one context-bounded exact-token prefix across logical
reset. Reuse requires identical tokens at identical positions in the same owning
model/session, with fixed tokenizer and RoPE. A mismatch ends reuse immediately.
The final prompt token always recomputes activations/logits. Reset clears sampler
counts/draws, decoder, conversation and deadlines; reuse rebuilds repetition
history using current settings. Changing system text can reuse its common framing
but cannot reuse differing content. Sampling settings do not change cached KV.

The cache uses existing KV and at most one additional context-sized token list,
with no duplicate KV allocation, disk persistence or cross-model sharing. Calls
remain serialized and sessions are not thread-safe. Reused history records
synchronize before token commitment. Device failure poisons the session and
prevents reuse. Interrupted prefill still requires reset. Cancellation remains
cooperative at token boundaries and cannot preempt an in-flight kernel. Logical
reset is not secure memory erasure, as before.

Native persistent Llama chat now stores the native llama3 conversation family
instead of the GGUF llama key. This repairs post-answer profile rejection for
both admitted Llama sizes. Existing llama3 snapshots retain compatibility checks.

A physical harness that unloaded and recreated CUDA contexts inside one Mojo
process stalled on the locked runtime. The replacement physical test uses one
context and explicitly recomputes every prompt token with caching disabled before
comparing cache-enabled execution. This does not certify context recreation.
Model switching already uses process replacement; keep that boundary until a
minimal reproducer and runtime fix pass. Normal service ownership is one context
per process, with shutdown/restart tested separately.

## Operator instructions

Prefix reuse defaults on for dense GQA. Add serve --no-prefix-cache for full
fresh-prefill measurement or policy. Duplicate flags fail before keys/allocation.
Sampling-settings preview describes model settings, not transport/cache policy.
Authenticated /health reports capabilities.exact_prefix_reuse; Gemma reports false.
HTTP response schemas, token counts and outside-AI authorization stay compatible.

Run from a prepared checkout with the registered model and private key:

```sh
python3 scripts/launch.py --build --target sm_75
python3 scripts/launch.py --check
python3 scripts/launch.py -- serve llama3.2:3b --accel cuda --api-key-file .aesir/second-brain/service.key --context 4096 --max-tokens 256 --timeout-ms 45000 --temperature 0
```

Use the supervised deployment in SECOND_BRAIN.md for normal operation. Keep keys
owner-only and the native listener on loopback. Stop the supervised native unit
before starting another full GPU model test on a small device; restart afterwards.
Rebuild after any Mojo source/test edit to refresh the launcher's fingerprint.

## Reproducible benchmarks

Run while other GPU inference/tests are idle. Output files must not exist:

```sh
python3 scripts/benchmark_native.py --binary .aesir/launch/aesir --model llama3.2:3b --samples 3 --no-prefix-cache --output native-fresh.json
python3 scripts/benchmark_native.py --binary .aesir/launch/aesir --model llama3.2:3b --samples 3 --output native-cached.json
```

Each command owns one temporary authenticated loopback process, private random
key and cleanup. Exclusive reports retain public prompts, actual replies/counts,
all warmups/samples/failures, medians, binary hash, loaded health, GPU observation
and process readiness. Readiness includes warm OS/driver caches, not uncached disk
load. Repeated-prefix timings differ from new prompts; first occurrences following
another case can share system/header tokens. Generation is capped at 32 tokens;
arithmetic/code may stop early. Compare equal actual counts and finish reasons.
Reports identify binaries, not guessed source revisions. Clock/thermal variance
and small sample counts limit statistical/general performance claims.

The earlier paired-provider tool remains available:

```sh
python3 scripts/benchmark_second_brain.py --ollama http://gungnir:11434 --key-file .aesir/second-brain/service.key --model llama3.2:3b --samples 3 --output paired-providers.json
```

Native/Ollama templates can differ despite identical user/system text. Equal GGUF
bytes require its optional --ollama-gguf hash gate. Report actual counts, residency,
KV formats and prefix policy. An older-Aesir speedup alone proves no Ollama win.

## Numerical and operational gates

```sh
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_packed_projection.mojo
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_cuda_prompt_prefix.mojo MODEL.gguf
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_llama3_quant_parity.mojo MODEL.gguf ORACLE.csv
```

The first probe compares 63 synthetic Q4/Q5/Q6 rows and tail guards exactly to
scalar CUDA; synthetic blocks prove algorithms, not external model compatibility.
Generate ORACLE.csv independently with the documented GGUF/NumPy oracle tool.
The 35 real sampled rows do not prove every full-model logit. Prefix checks cover
seven completions, divergent input/system text, seeded sampling/repetition policy
and timeout/reset recovery. Native-service and API probes separately cover actual
authenticated sockets, seeded replay, rejection, deadlines, disconnects, shutdown
and streaming. Hosted CI compiles physical probes without claiming GPU execution.

Further acceptance work includes batched matrix prefill, representative long-context
attention, full independent logits, broader models/devices and context recreation.
No universal optimality, CPU speed, Gemma-on-Turing or all-model/device claim.
