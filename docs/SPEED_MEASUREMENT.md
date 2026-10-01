# SPD-00 measurement and numerical contract

Owner: performance scripts and opt-in physical tests. Established 2026-10-01.
This first slice improves measurement; it does not implement a faster inference
kernel or complete every SPD-00 tracing/cache/residency gate.

## Independent numerical gate declared before comparison

The native measurement probe exports all 128256 final-prompt raw F32 logits in
four public cases, along with the exact committed input token IDs. Compare with
CPU llama-cpp-python 0.3.23, NumPy 2.4.4, context 4096, F16 K/V, no GPU layers,
no flash attention and no sampling transformation. The initial packed reference
uses identical GGUF bytes. The successful F32 reference uses a separate explicit
expansion of the same packed weight values; retain both comparisons and derivation.
Input IDs are evaluated directly, so chat-template/tokenizer differences cannot
explain discrepancies. Reset the independent context between cases.

Before examining numerical results, require each case to have maximum absolute
logit error at most 0.05, RMS error at most 0.005, and the same full-vocabulary
argmax. These are narrow F16-KV/F32-reduction regression tolerances, not a broad
model-quality promise or permission to tune tolerances after a failure. Record
full-vocabulary distribution divergence as an observation. Retain all failures.
These limits do not authorize Tensor-Core arithmetic or quantized-KV changes.

The reference library is an optional test dependency. It does not enter native
inference, install into the locked Mojo environment, supply production responses
or replace AESIR. The report records exact package and library/model hashes.
Source: [pinned reference API](https://github.com/abetlen/llama-cpp-python/blob/v0.3.23/llama_cpp/llama.py).

## Physical timing and traffic boundary

The probe uses the existing admitted native session in one owning CUDA context.
Host-monotonic begin-turn and generation-loop intervals include real synchronized
native GPU work. Full-logit export and console output are outside scored intervals.
The first case appearance is retained, then three export-free fresh repeats are
measured with native prefix reuse disabled. First visible chunk time includes
prefill plus native next-chunk work; it is not network time or isolated first-token
GPU timing. Decode-loop time includes token decoding and required closing work.
Individual Q/K/V, FFN, attention, sampler, CPU-enqueue and socket attribution remain
open; these stage measurements must not be relabeled as a full kernel trace.

Checked native tensor descriptors supply the logical minimum active projection,
norm, embedding-row and RoPE spans. KV bytes are a minimum unique-head/history
estimate, not measured DRAM counters. A guarded equal-size runtime D2D transfer
measures aggregate read-plus-write bandwidth beyond L2. Verify every copied word;
report 20 raw timing samples across two bounded spans. This is a conditional
roofline reference, not a guaranteed decoder speed or physical maximum bandwidth.
The exact packed decode access pattern can differ from D2D transfer performance.

## Reference precision investigation

The first complete packed CPU comparison failed the original error budgets in
all four cases, while all argmax IDs matched. Preserve that failure. Inspection
of the pinned CPU implementation shows K-quant dots use Q8_K activation operands,
where native AESIR computes packed-weight values against F32 activations. This is
a different arithmetic reference even with identical GGUF bytes.

Use a separately derived F32 reference using the installed authoritative
llama-quantize tool's explicit F32 expansion, preserving its version/binary hash,
source and derived hashes, command semantics, metadata and logs. This expands the
same packed weight values for independent CPU evaluation and avoids that packed
activation quantization path. It does not change the production model or native
weights. The actual four-case comparison passed the unchanged 0.05/0.005/argmax
budgets across 513024 logits: maximum error 0.0127416, maximum RMS error 0.0017844,
with all four argmax IDs matching. This is final-prompt coverage through 1070
input tokens, not every generation position, model or maximum context. The
derived model needs approximately
13 GB disk and sufficient host RAM; it is a test artifact excluded from Git.
[CPU type traits](https://github.com/ggml-org/llama.cpp/blob/7d442abf5c6244117fd5a1dc51a5d19f00792491/ggml/src/ggml-cpu/ggml-cpu.c),
[F32 expansion implementation](https://github.com/ggml-org/llama.cpp/blob/f8def7fe1/src/llama-quant.cpp).

## Provider comparator operation

Run from this checkout after GPU probes/compilation stop. Keep public synthetic
prompts separate from production corpus material. Defaults retain standard inputs,
32 output tokens, three scored repeats and greedy requests. Schema version 2 adds
full replies, explicit sequence ordering, observed cache/residency, provider-reported
stage durations, telemetry and failure-aware scoring. Old median fields remain.
Balanced ordering alternates provider order in each round. Randomized ordering
records its seed. Grouped ordering remains available for historical reproduction.

```sh
python3 scripts/launch.py --check
python3 scripts/benchmark_second_brain.py --ollama "$OLLAMA_ORIGIN" --key-file "$AESIR_KEY_FILE" --model llama3.2:3b --ollama-gguf "$OLLAMA_GGUF" --native-pid "$AESIR_PID" --suite extended --max-tokens 128 --samples 10 --order balanced --residency loaded --output paired-128.json
```

Use `--max-tokens 32|128|256`, `--suite standard|extended|stress|all`, and a
fresh output filename. The parser admits output ceilings 1..256 and samples
1..100. Loaded mode explicitly preloads Ollama, keeps it resident for ten minutes,
and verifies observed model/context. It does not restart either managed service.
As-is mode retains current residency; initial loading remains visible in replies.
This series is serial, not a concurrent throughput benchmark.

`--native-no-prefix-cache` requires an already prepared native service whose
health explicitly reports reuse disabled. The comparator does not change service
policy or pretend to disable Ollama caching. First appearances can still share
prefixes. Cache-disabled/residency-isolated engine comparison remains separate.
`--native-pid` hashes the observed process executable against the locally validated
build; independently verify that PID owns the intended API socket. Without it,
the build hash describes the local artifact, not an attested remote process.
No control claims identical chat templates, precision, logits or output text.

Duplicate/nonfinite JSON, oversized responses, malformed identities/counts,
context overflow and protocol failures invalidate samples. Retain their category
and any decoded reply. A failure anywhere disables all provider ratios. Cases
with early EOS/unequal requested output counts have null ratios; arithmetic is
always excluded. Useful completion/quality assessment stays a separate gate.
Medians/observed p95/bootstrap intervals are descriptive; fewer than ten repeats
or fewer than two independent sessions cannot certify a lead. Bootstrap inference
also assumes suitable independent samples; cached successive requests can correlate.
Provider stage durations are labeled observations, not independently isolated GPU
timings. Missing counters remain unavailable. No automatic retry hides slow/failing
requests. Ctrl-C retains collected evidence and exits 130; SIGKILL may leave an
incomplete artifact, which must never be accepted for scoring.

Native credentials go only to the loopback native endpoint and are recursively
redacted from artifacts. Do not use this public-evidence tool with private prompts.
Report reservation is exclusive and precedes model/key/network operations.

## Native and independent reference operation

Prepare the frozen Mojo environment and a compatible sm_75 device with sufficient
VRAM for the isolated model plus bounded probe buffers and existing desktop/services.
The probe refuses insufficient headroom. Test inference defaults do not alter the
managed deployment. D2D samples use nonuniform words and verify every output.

```sh
pixi run --frozen --no-install --offline --executable mojo build -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_cuda_measurement.mojo -o measurement-probe
./measurement-probe "$MODEL_GGUF" > native-measurement.csv
uv venv --python 3.13 oracle-env
uv pip install --python oracle-env/bin/python llama-cpp-python==0.3.23 numpy==2.4.4
oracle-env/bin/python scripts/check_llama3_logits.py --csv native-measurement.csv --model "$MODEL_GGUF" --expected-sha256 "$MODEL_SHA256" --reference-quantizer "$LLAMA_QUANTIZE" --reference-model reference-f32.gguf --output independent.json
```

The optional environment is external to the locked runtime. Linux x86-64 is the
exercised target. Use a new derived-model path and a new report. Conversion
records exact converter/model hashes and logs. Preserve the original source
model and failed reports. Conversion writes into a private staging directory and
publishes with an exclusive hard link; an existing or raced destination is preserved.
Destination and race contracts are exercised on Linux with synthetic conversion
fixtures. This is not a cross-platform or process-crash durability claim.
F32 weights are test artifacts, never tracked or loaded
into the 6 GiB native deployment. Approximately 12.86 GB disk and adequate host
RAM are required here. Verified reuse accepts `--reference-model` together with
`--reference-sha256` instead of the converter; retain the original derivation
record and require that exact hash. A changed hash fails before independent work.

The CSV parser requires all four complete input/logit vectors, 16 complete native
calls, all 20 bandwidth samples and both full-copy verifications. Missing, duplicate,
nonfinite or trailing records fail. The report remains non-passing on malformed
input, unavailable optional dependencies or numerical failure. It does not alter
its predeclared tolerances to match an observation.

## Observed feasibility and remaining work

The [evidence report](evidence/speed-measurement-2026-10-01/README.md) owns raw
reports, identities, checksums and the remaining SPD-00 acceptance boundaries.
Native fresh 1070-token prefill has a 12.687-second median, compared with 3.615
seconds in the 128-token generation loop. Prefill therefore dominates this
uncached workload. The verified nonuniform D2D copy observes 238.42 GB/s aggregate
read-plus-write bandwidth. About 2.011 GB of logical fixed packed-weight/norm/row
traffic implies an 8.44 ms conditional reference per decode step at that rate.
These are host/device observations, not profiler DRAM counters or guaranteed limits.

The next optimization candidate is real matrix prefill under SPD-01. First finish
SPD-00's cache/residency isolation, detailed launch/kernel/CPU/socket attribution,
second independent provider session and wider numerical/quality gates. Do not
promote a faster arithmetic path or change second-brain provider policy from this
measurement slice. All broader runtime capability statuses remain partial.
