# A-058 — Vulkan Q6_K + Q5_K GEMV

Dequant + single-row GEMV on the GPU for the two remaining
K-quant formats of Wave 7, judged against the Z13 CPU oracle
with the A-056 discipline. Roadmap acceptance: same oracle
discipline as A-056.

## What was built

- Shaders: aesir_engine/shaders/q6_k_gemv.comp and
  q5_k_gemv.comp (GLSL 450). One workgroup of 256 invocations
  per output row; strided partial sums reduced through shared
  memory. Weights are bound as uint words; byte extraction and
  fp16 decode run in-shader, so the full dequant executes on
  the GPU over the raw GGUF layouts the CPU oracle consumes:
  Q6_K 210-byte blocks (ql[128] low nibbles, qh[64] high 2-bit
  fields, int8 scales[16], fp16 d at byte 208; value =
  d * scale * (q - 32)) and Q5_K 176-byte blocks (fp16 d, fp16
  dmin, 12 packed 6-bit scale/min bytes, qh[32] high bits,
  qs[128] low nibbles; value = d * scale * q - dmin * min).
  The per-element index math mirrors the engine CPU SIMD
  dequant (_dequantize_ggml_k_simd types 14 / 13) exactly.
- SPIR-V: compiled on purpleraider with glslangValidator
  16.4.0. q6_k_gemv.spv sha256
  bf97687308c7e654e68e79949c28af1a7577753e89516f40443f11e6b45af15b
  (source sha256 2a029dbf5fe6e94dc3b51bea5682e385c74ae2f53ffe20a138c2a108650a7a25);
  q5_k_gemv.spv sha256
  5385b81611037a52c85a62cb779744a5fdde4862ce7f0026b4420f6d8f2fff5e
  (source sha256 fcfa4ad4df123c53ac9329dc06a8ca9198e198580b9705eb153f4c5b15d6f52b).
  Words embedded verbatim in aesir_engine/vulkan_buffer_shim.c
  (regeneration: glslangValidator -V <shader> -o out.spv).
- Shim dispatch: aesir_vk_buffer_q6_gemv /
  aesir_vk_buffer_q5_gemv share one parameterized dispatch body
  (vk_kquant_gemv) mirroring the A-056 Q8_0 dispatch on the
  same context, device, queue and buffer slots; the A-056
  entry point is untouched. Counters
  aesir_vk_q6_gemv_dispatch_count /
  aesir_vk_q5_gemv_dispatch_count increment only after submit
  + queue-wait-idle — the filed device-execution evidence.
- Mojo gateway: VulkanGemv.q6_k_gemv / q5_k_gemv plus
  q6_dispatch_count / q5_dispatch_count in
  aesir_engine/core/vulkan_gemv.mojo, fail-closed: positive
  rows, cols a positive multiple of 256, full operand
  coverage; violations raise before dispatch; no host fallback.
- Tests: aesir_engine/tests/test_vulkan_q6k_q5k_gemv.mojo,
  five cases registered in run_all as gpu.vulkan_q6k_q5k_*
  (pin 450 -> 455).

## A-055 dependency

As with A-056, the SPIR-V pipeline slice (team-04) was in
flight in parallel; A-058 follows the banked A-015/A-056
precedent (glslang compile on purpleraider, hashes filed,
words embedded). Shader sources live in aesir_engine/shaders/
where the A-055 pipeline will pick them up; adopting that
pipeline is follow-up work, not claimed here.

## Results (hidden_files/a058_run_all.log)

Suite: 452 passed / 1 failed / 2 skipped / 455 total — the
A-056 base (447 / 1 / 2 of 450) plus exactly the five new
cases, all PASS. Sole failure is the tolerated pre-existing
gguf.tensor_directory_interface J-022 drift; skips are the
2 pre-declared.

Oracle parity (sequential Float32 CPU oracle over the
identical raw bytes, 5 shapes per format incl. K=2048):
worst max_abs Q6_K 6.10e-05, Q5_K 5.19e-04 — accumulation-order
only, far below the filed 0.05 bound. Known values exact:
Q6_K repo known block sums to -96, constructed Q5_K block to
192. Engine crosscheck (dyadic fixtures through gemm_q6_k /
gemm_q5_k_m): within half an F16 ULP at every output.
Dispatch evidence: counters advance by exactly 2 per format
for 2 dispatches; buffer accounting exact. Device: AMD
Radeon 8060S, RADV STRIX_HALO (llvmpipe refused by the
identity check in every case).
