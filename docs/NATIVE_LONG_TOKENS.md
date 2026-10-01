# Long-token processing, memory traffic and buffers

This slice adds four-token layer-major prefill for the strictly admitted Llama
3.2 3B profile. Native Mojo CUDA executes it; Python only builds, supervises,
measures and independently tests. The physical whole-model fixture is the
installed Llama 3.2 3B Q4_K_M on an RTX 2060 Max-Q, sm_75. Other Llama/Qwen
profiles retain sequential prefill. Explicit four-token admission for those
profiles fails; Gemma retains its own session path.

## Operator controls

The exercised 3B session automatically selects four tokens. The service accepts
`--prefill-batch 1` to force sequential prefill or `--prefill-batch 4` to require
the exercised tile. Invalid/duplicate numeric flags fail before key/model access.
Authenticated `/health` reports the actual top-level `prefill_batch`. This is a
service startup policy, independent of sampling and exact-prefix retention;
HTTP clients do not need a new request field. Existing native, bounded OpenAI and
Ollama routes retain their response/token contracts.

Use the installed user service for normal operation. For an isolated comparison,
stop its GPU process, run from the prepared repository, and restore it afterwards:

```sh
python3 scripts/launch.py --build --target sm_75
python3 scripts/launch.py --check
python3 scripts/benchmark_native.py --binary .aesir/launch/aesir --model llama3.2:3b --prefill-batch 1 --suite extended --max-tokens 128 --samples 1 --no-prefix-cache --output sequential.json
python3 scripts/benchmark_native.py --binary .aesir/launch/aesir --model llama3.2:3b --prefill-batch 4 --suite extended --max-tokens 128 --samples 1 --no-prefix-cache --output tiled.json
python3 scripts/compare_native_benchmarks.py --before sequential.json --after tiled.json --allow-prefill-batch-change --output comparison.json
python3 scripts/benchmark_native.py --binary .aesir/launch/aesir --model llama3.2:3b --suite stress --max-tokens 128 --samples 1 --no-prefix-cache --output near-context.json
```

Reports use exclusive creation. Keep all warmups, samples, failures, loaded health,
complete replies/counts and binary identities. Explicit comparison intent permits
only the declared prefill-policy change; every other observed health control and
complete response must still match. Keep other GPU tests, inference and host
compilation idle while measuring. One measured sample is preliminary evidence;
repeat for broader confidence. The optional stress suite uses a public 3,150-token input with a 128-token
completion ceiling at context4096. It preserves the same bounded process/HTTP
measurement policy, including a120000ms generation deadline. The normal deployed
service retains45000ms; sufficiently large requests can hit that production
deadline and must not be retried in a flood. This exercises a larger prompt,
not the maximum context.
Longer prompts and generated outputs are distinct
workloads, and retained prefixes measure different work again.

## Buffer and memory design

`dense_buffers.mojo` owns checked offset/span arithmetic before CUDA allocation.
`DenseBufferLayout(profile, context, requested)` accepts automatic (0), one or
four internally, and bounds context to the profile ceiling. Its per-token stride
holds x, normalization, Q/K/V, attention output, projection temporary and FFN
gate/up intermediates. Each token has a disjoint live span. One logits region and
one scores region follow all token spans, consumed sequentially on the owning
CUDA stream. Invalid token-base access and integer/byte overflow raise.

For the 3B profile, the stride is 33,792 F32 elements. Four-token capacity costs
405,504 extra bytes (396 KiB) versus sequential allocation, independent of context
length. The shared logits/scores are not duplicated. F16 KV is unchanged:
469,762,048 bytes at context 4096. This optimizes memory traffic; it does not shrink
KV or guarantee lower total VRAM. Memory admission and service reporting use the
actual layout; automatic planning conservatively includes its extra capacity.

`four_matvec_kernel[kind]` reads and decodes each admitted 256-element Q4_K/Q5_K/
Q6_K block once for four independent dot products. Each accumulator preserves
its original lane order and warp reduction. No whole-model dequantized copy is
created. Unsupported kinds/alignment retain the existing projection dispatch.

`llama_attention_tiled` loads four chronological score/value products ahead of
accumulation, retains F16 input/F32 sums, handles the tail and preserves causal
head mapping. The original `llama_attention`, scalar packed readers and sequential
forward remain regression references. Numerical gates precede speed promotion.

## Session robustness and control

`prefill_four(tokens, start)` validates the entire tile before sampler/position
mutation. It enqueues all four embeddings, then each layer's projections and
individual causal attention. Position n reads only KV through n, including
inside a tile. Scores are consumed before the next token overwrites the shared
region. The final prompt token always executes fresh logits/sampling separately.
Exact-token conversation restore can also use complete tiles.

A tile marks the session unhealthy before CUDA work. Only a successful final
synchronization commits all four tokens and advances position. A CUDA failure
poisons reuse; catching an exception is not GPU recovery. Invalid input preserves
a healthy session unchanged. Deadlines/cancellation poll at boundaries of at most
four input tokens, then each generated token; they cannot preempt an in-flight
kernel. Interrupted prefill still requires explicit reset. Production model
switching remains process replacement because in-process CUDA context recreation
has not passed on this locked runtime. Logical prefix reset is not secure erasure.

## Physical verification

Run GPU probes sequentially, from the repository root, with other GPU work idle.
Use the installed pinned model and the separately generated real-weight oracle:

```sh
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_dense_buffers.mojo
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_four_projection.mojo
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_long_attention.mojo > attention.csv
uv run --with numpy==2.4.4 python scripts/check_long_attention.py attention.csv
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_cuda_prefill.mojo MODEL.gguf
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_cuda_prompt_prefix.mojo MODEL.gguf
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_llama3_quant_parity.mojo MODEL.gguf ORACLE.csv
```

The four-projection probe covers 2,952 exact scalar-reference rows and 5,616 guard
cells across six widths, three row tails and three formats. Long attention covers
24 original/tiled exact cases, 65,536 independent NumPy values and guarded outputs,
including synthetic histories 4096/8192. Real-model prefill covers 641,280 exact
sequential/tiled logits, five greedy/seeded completions, restored continuation and
invalid-tile non-mutation. This whole-model regression reference is native Aesir;
it is not an independent external full-model oracle. Synthetic attention at 8192
also does not prove maximum-context whole-model performance or reliability.

Hosted CI compiles physical probes and runs pure buffer/admission/evidence tests.
Physical CUDA execution, timing and recovery are recorded separately. Broad
model/device performance, independent full-model logits, quantized KV, multi-client
GPU batching and in-process context recreation remain open acceptance work.

Measured timings, numerical/recovery logs and raw reports are in
[evidence/native-long-tokens-2026-10-01.md](evidence/native-long-tokens-2026-10-01.md).
