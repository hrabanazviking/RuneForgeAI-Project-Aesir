# Native kernel efficiency: operation and verification

The 2026-10-01 efficiency slice narrows packed byte arithmetic and improves RMS
load scheduling in admitted dense GQA CUDA sessions. It preserves the original
scalar reference kernels, quantization equations, lane accumulation order,
sampling and public HTTP contracts. It does not change model support, context
ceilings, CUDA dependencies, service concurrency or the second-brain corpus.

## Compute ownership and bounds

packed_quantization.mojo owns Q4_K/Q5_K/Q6_K equations. Only unpacked byte fields
and their small products use Int32: Q5's largest scale-times-quant product is
63*31=1953. Pointer arithmetic, offsets, tensor spans and indices remain Int.
The original packed_value reader remains the numerical reference. Projection
dispatch still requires admitted columns divisible by 256.

dense_normalization.mojo specializes admitted widths 128, 3072 and 4096. Each
lane loads four independent values before adding their squares in the original
order; a second four-value pass normalizes and applies admitted F32 weights.
It preserves the same final warp reduction and supports the same in-place or
disjoint spans. Small tiles avoid retaining an entire vector per lane. Other
widths use the original runtime-width norm_kernel. No additional device buffer
or KV capacity is allocated. Compilation alone proves no speed or support claim.

## Reproduce physical numerical checks

Stop the native GPU service before these owning processes run; serialize tests
and restore it afterward. Keep other GPU work idle during benchmarks.

```sh
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_packed_projection.mojo
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_dense_normalization.mojo > rms.csv
python3 scripts/check_dense_normalization.py rms.csv
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_llama3_quant_parity.mojo MODEL.gguf ORACLE.csv
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_cuda_prompt_prefix.mojo MODEL.gguf
```

The expanded projection probe exercises six widths (256 through 14336), three
row counts (1/7/33), three formats, signed scales, 738 exact reference rows and
1404 output-tail guards. RMS checks cover 48 cases and 233472 values: zero,
ordinary, tiny and large finite inputs, one/three groups, nonzero offsets and
in-place/disjoint writes. Its independent checker uses standard-library float32
rounding and math.fsum rather than native reduction code. Synthetic probes do
not establish full-model logits or broader architecture/device compatibility.
The independent real-weight oracle is still a separate required gate; see
[the performance manual](NATIVE_PERFORMANCE.md) for artifact provenance.

## Measure and compare safely

Archive the current binary and build manifest before rebuilding. Native reports
identify actual executable hashes and loaded model digests, rather than inferring
a source revision from the current checkout. Do not change source during a build;
the launcher refuses publication if its source fingerprint changes mid-build.

```sh
python3 scripts/launch.py --build --target sm_75
python3 scripts/launch.py --check
python3 scripts/benchmark_native.py --binary OLD_BINARY --model llama3.2:3b --no-prefix-cache --samples 2 --output before.json
python3 scripts/benchmark_native.py --binary .aesir/launch/aesir --model llama3.2:3b --no-prefix-cache --samples 2 --output after.json
python3 scripts/compare_native_benchmarks.py --before before.json --after after.json --output comparison.json
```

The comparator requires matching loaded health/policy, model digest, system,
sampling, context, request sequence, complete replies, token counts and finish
reasons. It recomputes medians from positive finite warm samples, excludes one
warmup per case and rejects reports containing failures or incomplete sequences.
On mismatch it writes a failure artifact, exits nonzero and publishes no ratios.
Output paths use exclusive creation. Choose a fresh name for every experiment.

Remove --no-prefix-cache from **both** benchmark commands to compare repeated
prefixes under equal policy. Cache-enabled and disabled reports cannot be paired
by this comparator. Their different work must remain clearly labeled.

For larger prompt and sustained-generation checks, use the same flags for both
binaries, with an explicit separate suite:

```sh
python3 scripts/benchmark_native.py --binary OLD_BINARY --model llama3.2:3b --suite extended --max-tokens 128 --no-prefix-cache --samples 1 --output extended-before.json
python3 scripts/benchmark_native.py --binary .aesir/launch/aesir --model llama3.2:3b --suite extended --max-tokens 128 --no-prefix-cache --samples 1 --output extended-after.json
python3 scripts/compare_native_benchmarks.py --before extended-before.json --after extended-after.json --output extended-comparison.json
```

This suite uses public reliability text and a sustained pipeline explanation.
The standard suite and its default 32-token ceiling are unchanged. The tool
admits 1..256 output tokens, 512..8192 context and 1..10 measured samples. Each
process owns an ephemeral authenticated loopback service and key, uses a 120 s
generation deadline and reaps its child process. It neither restarts the live
service nor edits the model catalog, data or credentials.

## Deployment and limits

Rebuild after final Mojo edits, then exercise deadline/reset, seeded sampling,
authenticated HTTP faults and all API fixtures. Run the counted master, negative
control and documentation/fixture checks. Hosted CI compiles GPU probes without
claiming GPU execution. After deployment verify native authenticated readiness,
an actual completion and second-brain database/embedding health.

Kernel traces identify where time was spent; profiled totals include profiler
overhead and are separate from unprofiled HTTP timings. nvprof hardware counters
are unsupported on sm_75. The local Nsight Compute counter attempt was refused
with ERR_NVGPUCTRPERM; no counter permission or driver settings were changed.
Fresh process readiness includes warm OS/driver caches. Small samples, clocks
and thermal variance limit general speed conclusions.

True batched matrix prefill, full independent model logits, broad models/devices,
very long contexts and in-process CUDA context recreation remain open. Preserve
process replacement for model switching and fail-closed poisoned-session behavior.
Keep the existing second-brain provider policy until representative paired
measurements justify a change. No universal optimality or broad Ollama advantage.

The subsequent bounded four-token prefill and compact scratch slice is documented
in [NATIVE_LONG_TOKENS.md](NATIVE_LONG_TOKENS.md). Earlier no-extra-buffer claims
above apply to the preceding arithmetic/RMS slice.
