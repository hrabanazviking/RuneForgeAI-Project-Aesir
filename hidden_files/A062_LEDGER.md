# A-062 Ledger — Vulkan decode attention (team-06)

- Slice: A-062 — Vulkan decode attention (docs/AESIR_Z13_MASSIVE_ROADMAP.md)
- Worktree: /home/volmarr/aesir-team-06, branch yrsa/aesir-team-06
- Base: 3d60e523 (Banking closure: A-058 banked, 58 of 216)
- Date: 2026-11-12 (America/New_York)
- Status: DONE — built, gate green, committed on team branch; awaiting
  keeper banking in roadmap order (banks only after A-060 and A-061).

## Deliverables

- aesir_engine/core/vulkan_attention.mojo — static VulkanAttention
  gateway: single-query decode attention over a unified KV cache via
  the A-014/A-015 Vulkan slots; FFI aesir_vk_buffer_attn_decode;
  fail-closed VAL-003/GPU-002/GPU-001 mapping, no host fallback.
- aesir_engine/tests/test_vulkan_attention_a062.mojo — 5 cases with an
  independent sequential Float32 CPU oracle (raw in-file oracle,
  1e-4 abs tolerance bound for exp/division rounding).
- aesir_engine/vulkan_buffer_shim.c — aesir_vk_buffer_attn_decode
  dispatch (per-dispatch pipeline discipline as A-056; counter
  increments only after submit + queue-wait-idle) + SPIR-V dedup fix
  below.
- aesir_engine/tests/run_all.mojo — 5 cases registered
  (gpu.vulkan_attn_decode_*), suite pin re-pinned 463 -> 468.
- Shader registration catch-up: SHADER_MANIFEST.json kernel_count
  8 -> 12 (q4k_gemv, q5_k_gemv, q6_k_gemv, q8_0_gemv registered with
  source/spv sha256); generated header regenerated
  (aesir_shaders_spv.h, +4 arrays + registry entries); 4 generated
  .spv artefacts added under shaders/generated/.

## Bug 1 (blocking, found by previous lead, fixed this run)

Gate failed compiling vulkan_buffer_shim.c: redefinition of
kQ4kGemvSpv (shim line 1887) and kQ4kGemvSpvBytes (line 2324) vs the
regenerated header (included at shim line 1227). The shim carried
hand-embedded SPIR-V blocks duplicating the generated header.
Audit found the same pattern for all four GEMV kernels: Q5K, Q6K and
Q8_0 were hand-embedded under divergent names (kQ5GemvSpv,
kQ6GemvSpv, kQ8GemvSpv vs header kQ5KGemvSpv, kQ6KGemvSpv,
kQ80GemvSpv), so only Q4K collided at compile time.
Word-for-word comparison (script /tmp/cmp_spv.py on device) proved
every hand-embedded array byte-identical to its header counterpart:
Q4K 1729, Q5K 2289, Q6K 1982, Q8_0 1519 words, IDENTICAL=true x4.
Fix (A-055 precedent in the same file: header is source of truth):
removed all four hand-embedded arrays + their Bytes lines from the
shim (~94 KB), repointed the Q8/Q6/Q5 call sites to the header
symbols (kQ80GemvSpv(B), kQ6KGemvSpv, kQ5KGemvSpv); Q4K call site
unchanged (same symbol). A-062 comment left at each removal site.
Shim pair then compiles clean (cc -std=c11 -O2 -fPIC -shared
vulkan_context_shim.c + vulkan_buffer_shim.c).

## Bug 2 (in-slice, found on gate run 1)

gpu.spirv_pipeline_manifest failed: the A-055 pin asserted manifest
kernel_count 8, stale after the A-062 registration moved it to 12.
Fixed in tests/test_spirv_pipeline_a055.mojo: pin 8 -> 12, kernel
name list extended with the 4 GEMV kernels, header-embedded pin
extended with kQ4kGemvSpv/kQ5KGemvSpv/kQ6KGemvSpv/kQ80GemvSpv.
No other A-055 case changed (recorded hashes still verify).

## Gate (E-MASTER, scripts/build_matrix.sh cpu, purpleraider)

- Run 1 (post-dedup, pre-pin-fix): 464 passed / 2 failed / 2 skipped /
  468 total — failures: tolerated J-022 + spirv_pipeline_manifest
  (Bug 2). Log: hidden_files/build_matrix_cpu.log (overwritten by
  run 2); summary in hidden_files/a062_gate.log run-1 section of
  CAMPAIGN_STATE.
- Run 2 (final): 465 passed / 1 failed / 2 skipped / 468 total.
  MATRIX RESULT: PASS (cpu). Sole failure = tolerated pre-existing
  gguf.tensor_directory_interface (J-022 drift, roads A-165/A-121);
  skips = 2 pre-declared.
  hidden_files/build_matrix_cpu.log sha256
  efb812b7237593d8b33698b5ec0fadb8dbf88f3386a97ecc06a024bb29ccca12
  hidden_files/a062_gate.log sha256
  27eb3acae66647a9df2fa006ecb185261224f055a1c17deba3f9eed611500f7c

## Device-execution evidence (RADV, no llvmpipe)

Suite log line: "Vulkan device: AMD Radeon 8060S Graphics
(RADV STRIX_HALO)"; test gate refuses llvmpipe (vendor 0x1002,
device_type != 4, device_name_is_radv). All 5 A-062 cases PASS:
oracle_parity max_abs <= 8.94e-08 across 6 shapes (incl. kv=1024,
MQA ratio 8) vs 1e-4 bound; known_value exact (0.0); gqa_fixture
PASS; rejection PASS (6 invalid calls raise); dispatch_evidence
PASS (counter +2 for 2 dispatches, no leak).

## Notes

- hidden_files/a006_trivial.spv is a pre-existing stray on this
  worktree, unrelated to A-062; deliberately NOT committed.
- No README.md touched. No merge/push (keeper banks).
