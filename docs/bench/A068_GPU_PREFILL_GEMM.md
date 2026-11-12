# A-068 — GPU prefill GEMM (Vulkan batched matrix kernels)

Batched matrix kernels for prompt processing: where the Wave 7
GEMV gateways (A-056..A-059) multiply one weight matrix by ONE
activation vector (the decode shape), A-068 multiplies one
weight matrix by a BATCH of activation rows — the prompt's
tokens — in a single dispatch:

    Y[t, r] = sum_k W[r, k] * X[t, k]

The weight bytes serve every token in the batch, which is the
reuse that makes prefill compute-shaped instead of
tokens × bandwidth-shaped.

| Kernel | Source | Weights | Generalises |
|---|---|---|---|
| q8_0_gemm | aesir_engine/shaders/q8_0_gemm.comp | raw GGUF Q8_0 bytes (34-byte blocks: fp16 scale + 32 int8; dequant in-shader) | A-056 Q8_0 GEMV |
| gemm_f32 | aesir_engine/shaders/gemm_f32.comp | dense Float32 | A-055 gemv_f32 |

Both dispatch one workgroup of 256 invocations per (row, token)
pair as (rows, tokens, 1), with strided partial sums reduced
through shared memory (the A-056 reduction), so a tokens == 1
dispatch computes the same per-row sums as the matching GEMV
kernel. Module: `aesir_engine/core/vulkan_gemm.mojo`
(`VulkanGemm.q8_0_gemm` / `f32_gemm`), fail-closed with all
shapes validated before dispatch; shim entries
`aesir_vk_buffer_q8_gemm` / `aesir_vk_buffer_f32_gemm` in
`aesir_engine/vulkan_buffer_shim.c` over one shared dispatch
helper. Tests: `aesir_engine/tests/test_vulkan_gemm_a068.mojo`
(6 E-MASTER cases, gpu.vulkan_prefill_gemm_*); bench:
`aesir_engine/tests/bench_prefill_gemm_a068.mojo`.

Pipeline registration: both kernels were compiled through the
A-055 SPIR-V pipeline and registered in
`aesir_engine/shaders/SHADER_MANIFEST.json` and the generated
header `aesir_engine/shaders/generated/aesir_shaders_spv.h`;
the four IQ GEMV kernels hand-embedded in the shim since A-059
were formally registered at the same time and their duplicate
hand-embedded arrays removed from the shim (byte-identical,
asserted before removal): manifest kernel_count 13 -> 19.

## Parity vs CPU oracle (raw-oracle discipline)

Independent sequential Float32 CPU oracle in the test file
consuming the identical raw Q8_0 bytes. Source:
hidden_files/a068_driver.log (A068_DRIVER_ALL_PASS).

| Case | Result |
|---|---|
| Q8_0 parity, 5 shapes (tokens 1..64, K=288 + K=1024) | worst max_abs 7.247925e-05 |
| Q8_0 known value (scale 0.25, q=i-16, x=t+1) | -4*(t+1) exact |
| F32 parity, 3 shapes | worst max_abs 4.9591064e-05 |
| Batch independence (tokens=8 joint vs 8× tokens=1) | bitwise |
| tokens=1 Q8 vs A-056 GEMV | bitwise |
| Rejection (zero tokens/rows, cols=48, oversize, bogus id) | all raise pre-dispatch |

## Measured performance (hidden_files/a068_bench.log)

Device: AMD Radeon 8060S (RADV STRIX_HALO). Q8_0 GEMM,
rows=cols=1024:

| Tokens | tok/s | GFLOPS |
|---|---|---|
| 1 | 3,683 | 7.7 |
| 8 | 24,501 | 51.4 |
| 32 | 59,512 | 124.8 |
| 64 | 73,660 | 154.5 |
| 128 | 88,463 | 185.5 |

256×256 Q8_0 GEMM at 64 tokens: 212,518 tok/s (27.9 GFLOPS).
Layer-projection stack (the 7 per-layer projections as GEMMs):

| Tokens | GPU stack tok/s | CPU stack tok/s |
|---|---|---|
| 8 | 4,595 | — |
| 32 | 16,778 | 2,081 |
| 64 | 30,073 | 2,118 |
| 128 | 51,155 | — |

The GPU stack at 64 tokens runs ~14× the CPU stack. Bench
parity checks at the benched shapes: max_abs <= 1.53e-04.
A068_BENCH: PASS.

## Device-execution evidence (law 6)

Device: AMD Radeon 8060S (RADV STRIX_HALO); llvmpipe refused
by identity check. Shim dispatch counters asserted exact in
the dispatch-evidence case (q8 +2, f32 +1 for the calls made);
counters increment only after a submit + queue-wait-idle
completed on the device. No host fallback exists in the
gateway or the shim.

## Scope note (honest)

This is the GEMM layer of prefill only. Batched causal
attention, per-position RoPE, and incremental KV writes for
a full prefill layer are A-069's road (chunked prefill), not
claimed here.
