# A-056 — Vulkan Q8_0 GEMV

Dequant + single-row GEMV on the GPU, judged against the Z13 CPU
oracle (the A-054 gate declared the CPU path the campaign's
reference oracle). Roadmap acceptance: outputs vs CPU oracle
within filed tolerance across shapes; device-execution evidence
(timeline/counters) filed — law 6.

## What was built

- Shader: `aesir_engine/shaders/q8_0_gemv.comp` (GLSL 450).
  One workgroup of 256 invocations per output row; strided
  partial sums reduced through shared memory. The weights
  buffer is bound as uint words; byte extraction and the fp16
  scale decode run in-shader, so the full dequant (raw GGUF
  Q8_0 layout: 34-byte blocks of fp16 scale + 32 int8, the
  layout the CPU oracle consumes) executes on the GPU.
- SPIR-V: compiled on purpleraider with glslangValidator,
  6076 bytes, sha256
  af3a2f037eff04e192cb9477debbcab14bcebb9354874dcec8e8b337b47ce302,
  embedded verbatim in `aesir_engine/vulkan_buffer_shim.c`
  (regeneration: `glslangValidator -V
  aesir_engine/shaders/q8_0_gemv.comp -o q8_0_gemv.spv`).
  Toolchain check: recompiling the A-015 `vec_add.comp` on this
  host reproduces its filed sha256 exactly
  (b228710b1f464b3aa810a4d4cb73e67f2325fdf1eabaa2ceb6b2cf73309ce15b).
- Shim dispatch: `aesir_vk_buffer_q8_gemv` in the same shim, on
  the A-013/A-014 context, device, queue and buffer slots as
  A-015 (no second context). Pipeline objects are created per
  dispatch and destroyed before return; the call returns after
  vkQueueWaitIdle. A counter, `aesir_vk_q8_gemv_dispatch_count`,
  increments only after a submit + wait-idle completed on the
  device — the filed device-execution evidence.
- Mojo gateway: `aesir_engine/core/vulkan_gemv.mojo`
  (`VulkanGemv.q8_0_gemv`, `VulkanGemv.dispatch_count`),
  fail-closed exactly as A-014/A-015: positive row count,
  column count a positive multiple of the 32-wide Q8_0 block,
  full operand coverage — violations raise before dispatch;
  no host fallback exists.
- Tests: `aesir_engine/tests/test_vulkan_q8_gemv.mojo`, five
  cases registered in run_all as `gpu.vulkan_q8_gemv_*`
  (pin 445 -> 450).

## A-055 dependency

A-055 (SPIR-V build pipeline, team-04) was in flight in
parallel and not available when A-056 was built (verified: no
A-055 commit, file, or pipeline in any worktree or the seat).
A-056 therefore follows the banked A-015/A-013 precedent above
and does not claim any A-055 work. The shader source of record
lives in `aesir_engine/shaders/` where the A-055 pipeline will
pick it up; adopting that pipeline is recorded as follow-up
work in team-07's CAMPAIGN_STATE.md.

## Parity verdicts (device: AMD Radeon 8060S, RADV STRIX_HALO;
llvmpipe refused by the identity check)

Non-dyadic fixture (in-file LCG, seed 0xA056; activations in
[-1.5, 1.5], scales in [0.002, 0.02] with filed zero/negative
cases) vs a sequential Float32 CPU oracle consuming the
identical raw bytes with the engine CPU body's math:

| rows | cols | max abs delta |
|-----:|-----:|--------------:|
| 1 | 32 | 4.77e-07 |
| 4 | 64 | 3.81e-06 |
| 16 | 288 | 1.53e-05 |
| 37 | 320 | 2.67e-05 |
| 64 | 1024 | 6.87e-05 |
| 13 | 4096 | 9.83e-05 |

Filed tolerance bound: max_abs <= 1e-3 (asserted in the test).
The deltas are accumulation-order only (GPU tree reduction vs
CPU sequential summation, both Float32, identical dequant);
worst measured 9.83e-05 at K=4096 carries ~10x headroom under
the bound. Verdict: PASS.

Engine cross-check (dyadic fixture, A-038 discipline,
K=1024, N=96): the same bytes run through the engine's own CPU
GEMV (gemm_q8_0) and the GPU. Every Float32 partial sum is
exact in any order on dyadic data, so the GPU outputs are the
exact sums; the engine writes F16, and every GPU output lies
within half an F16 ULP of the engine output — the F16 rounding
distance (a comparator artifact bound, not a dequant
tolerance). Verdict: PASS. (An exact-equality assertion here
failed once during development at output magnitude ~308,
where the F16 ULP is 0.25; that failure class is the
comparator's output rounding, not a kernel divergence.)

Known value: one block, scale 0.25, q = i-16, x = 1 -> -4,
exact. Verdict: PASS.

Rejection: zero rows, cols=48 (not a block multiple), oversize
shape, bogus buffer id — all refused. Dispatch evidence:
counter advances by exactly the number of dispatches; buffer
accounting exact after the loop (no leak). Verdicts: PASS.
