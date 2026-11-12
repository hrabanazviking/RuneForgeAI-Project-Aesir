# A-059 - Vulkan IQ GEMV (filed results)

Host: purpleraider, AMD Radeon 8060S / RADV STRIX_HALO (gfx1151);
llvmpipe refused by the device identity check in every case.

## Scope
IQ2_XXS first (roadmap order), then IQ1_S, IQ3_XXS and IQ4_NL -
the IQ formats with fast CPU paths in the A-046 census (GEMM
kind registry 16/19/18/20). One GLSL kernel per format
(aesir_engine/shaders/iq2_xxs_gemv.comp, iq1_s_gemv.comp,
iq3_xxs_gemv.comp, iq4_nl_gemv.comp), SPIR-V embedded in
aesir_engine/vulkan_buffer_shim.c, gateway methods on
core/vulkan_gemv.mojo VulkanGemv (iq2_xxs_gemv / iq1_s_gemv /
iq3_xxs_gemv / iq4_nl_gemv + per-format dispatch counters).
The grid formats take the GGML grid table (a format constant)
as a fourth SSBO binding uploaded from core.iq_codebooks via
iq_grid_materialize; dequant (byte extraction, fp16 scale
decode, grid decode, sign expansion) runs entirely in-shader.

## Results (hidden_files/a059_run_all.log)
- Suite: 460 passed / 1 failed / 2 skipped / 463 total; sole
  failure gguf.tensor_directory_interface (tolerated J-022
  drift); delta vs the 5b172516 baseline (455/1/2/458) is
  exactly the 5 new gpu.vulkan_iq_gemv_* cases, all PASS.
- Oracle parity (sequential in-test Float32 oracle over the
  identical raw bytes, 4 formats x 5 shapes incl. K=2048):
  worst max_abs 5.72e-05 against the filed bound 0.05.
- Known values exact: IQ2_XXS 256, IQ1_S -224, IQ3_XXS 256,
  IQ4_NL 128 at K=256 and 144 at K=288 (all-zero / 0x88 blocks).
- Engine crosscheck: GPU vs gemm_iq2_xxs / gemm_iq1_s /
  gemm_iq3_xxs / gemm_iq4_nl on dyadic fixtures, within half an
  F16 ULP for all four formats.
- Dispatch evidence: shim counters advance by exactly the
  number of dispatches per format; buffer accounting exact.
- Rejection: zero rows, non-block-multiple cols (256-family and
  IQ4_NL's 32), oversize shapes, bogus buffer id, bogus grid id.

## Bug A-046:B1 landing
IQ4_NL is a 32-value-block format. This slice's GPU gateway
accepts any positive multiple of 32 columns (parity-proven at
K=288 and K=32), so the shape question is answered on the GPU
path. The CPU wrapper gemm_iq (core/compute.mojo) still
requires cols % 256 == 0 for every IQ type including kind 20 -
that CPU-side fix remains B1's open home, recorded in
CAMPAIGN_STATE.md; it is not silently closed by this slice.

## Verdict
Faithful: GPU dequant+GEMV matches the independent CPU oracle
and the engine CPU GEMV under the filed bounds on real device
execution; residual deltas are accumulation-order comparator
artifacts within the bound. Coherence-grade per law 3 - no
token-exactness claimed.
