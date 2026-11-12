# A-068 Ledger — GPU prefill GEMM (team-01)

- Date: 2026-11-12. Lead + 6 Mythic Engineering sub-agents
  (design notes only, device work by the lead). This ledger,
  the bench doc, and the commit were completed by a fresh
  lead finishing the stalled slice: the previous lead had
  built and tested everything below and stopped after the
  test suite without committing (verified from disk).
- Base: worktree HEAD 522fdbe7 (A-065 closure, 65 of 216
  banked at build base) on yrsa/aesir-team-01. Built ahead
  in parallel: A-066 (team-02) and A-067 were being built
  concurrently; A-068 banks only after A-067 in roadmap
  order. Keeper reconciles the run_all pin union at
  banking (A-065/A-066 precedent). Untracked
  aesir_engine/hip_bridge.c left untracked and out of the
  commit, per standing instruction.

## What was built

- aesir_engine/shaders/q8_0_gemm.comp — batched Q8_0 GEMM:
  Y[t, r] = sum_k dequant(W[r, k]) * X[t, k], W in the raw
  GGUF Q8_0 byte layout (34-byte blocks: one fp16 scale +
  32 int8); byte extraction and fp16 scale decode run
  in-shader. One 256-wide workgroup per (row, token) pair,
  dispatched as (rows, tokens, 1), A-056 shared-memory
  reduction, so tokens == 1 computes the A-056 GEMV sums.
- aesir_engine/shaders/gemm_f32.comp — dense Float32 GEMM,
  the batched generalisation of the A-055 gemv_f32 kernel,
  same workgroup shape and reduction.
- Pipeline registration (A-055 discipline): both kernels
  compiled through the shader pipeline and registered in
  aesir_engine/shaders/SHADER_MANIFEST.json +
  aesir_engine/shaders/generated/aesir_shaders_spv.h, and
  the four IQ GEMV kernels (iq1_s, iq2_xxs, iq3_xxs,
  iq4_nl — SPIR-V hand-embedded in the shim since A-059)
  were formally registered the same way: kernel_count
  13 -> 19, generated .spv files filed under
  shaders/generated/ (gemm_f32, q8_0_gemm, iq1_s_gemv,
  iq2_xxs_gemv, iq3_xxs_gemv, iq4_nl_gemv).
  aesir_engine/tests/test_spirv_pipeline_a055.mojo pins
  updated to 19 kernels / 19 header arrays.
- aesir_engine/vulkan_buffer_shim.c — one shared GEMM
  dispatch helper (aesir_vk_gemm_dispatch) + entry points
  aesir_vk_buffer_q8_gemm / aesir_vk_buffer_f32_gemm with
  per-kernel dispatch counters (the law-6 device-execution
  evidence; each increments only after submit + wait-idle).
  The four hand-embedded IQ SPIR-V arrays were removed
  from the shim (dedup): hidden_files/edit_a068.py first
  asserted every generated-header array was present and
  the generated words byte-identical to the hand-embedded
  arrays, then deleted them (shim diff: 152 insertions,
  1108 deletions, most of it this dedup). No host fallback:
  nothing in the shim computes a product on the CPU.
- aesir_engine/core/vulkan_gemm.mojo — VulkanGemm gateway
  (q8_0_gemm / f32_gemm), fail-closed, all shapes and
  buffer sizes validated before any dispatch (Q8_0 cols
  must be a positive multiple of 32).
- aesir_engine/tests/test_vulkan_gemm_a068.mojo — 6
  E-MASTER cases (gpu.vulkan_prefill_gemm_*) with an
  independent sequential Float32 CPU oracle consuming the
  identical raw Q8_0 bytes (raw-oracle discipline).
- aesir_engine/tests/run_all.mojo — import + 6 run_case
  lines; pin 501 -> 507.
- aesir_engine/a068_driver.mojo (+ identical copy at
  hidden_files/a068_driver.mojo) — standalone driver.
- aesir_engine/tests/bench_prefill_gemm_a068.mojo —
  prefill GEMM bench (single GEMM + 7-projection layer
  stack vs the CPU stack).
- docs/bench/A068_GPU_PREFILL_GEMM.md — composition +
  measured numbers.

## Acceptance: GPU vs CPU oracle parity (raw-oracle)

Standalone driver (hidden_files/a068_driver.log):
A068_DRIVER_ALL_PASS, MOJO_EXIT=0. All 6 cases PASS:

- Q8_0 oracle parity, 5 batched shapes (tokens 1..64,
  incl. K=288 stories scale and K=1024): worst
  max_abs 7.247925e-05 (rows=64, cols=1024, tokens=32).
- Q8_0 known value (tokens=4, scale 0.25, q=i-16,
  x=t+1 -> -4*(t+1)): exact, PASS.
- F32 oracle parity, 3 batched shapes: worst max_abs
  4.9591064e-05 (rows=64, cols=1024, tokens=32).
- Batch independence: tokens=8 joint == 8x tokens=1
  bitwise; tokens=1 == A-056 GEMV bitwise, PASS.
- Rejection: zero tokens, zero rows, cols=48, oversize
  batch, bogus id, f32 zero tokens — all raise before
  dispatch, PASS.
- Dispatch evidence: q8 counter +2, f32 counter +1,
  accounting exact, PASS.

Device-execution evidence (law 6): AMD Radeon 8060S
(RADV STRIX_HALO), llvmpipe refused by identity check.

Bench (hidden_files/a068_bench.log, ends A068_BENCH:
PASS, MOJO_EXIT=0): Q8_0 GEMM 1024x1024 — 3,683 tok/s
at tokens=1 (7.72 GFLOPS), 24,501 at 8, 59,512 at 32,
73,660 at 64, 88,463 at 128 (185.5 GFLOPS); 256x256 at
tokens=64: 212,518 tok/s. Layer-projection stack
(7 GEMMs per token): 4,595 tok/s at 8 tokens, 16,778
at 32, 30,073 at 64, 51,155 at 128 — vs the CPU stack
at 2,081 tok/s (32 tokens) and 2,118 tok/s (64 tokens),
i.e. ~14x the CPU stack at 64 tokens. Bench parity
checks at the benched shapes: max_abs <= 1.53e-04.

## Gate

Full E-MASTER suite (hidden_files/a068_run_all.log,
sha256 414c26f58eecfcde0e46fdec11ae2435fd3f992d8ca17ab34c3b1e8a98d23b44): 504 passed / 1 failed / 2 skipped
/ 507 total = A-065 seat baseline 498/1/2/501 + exactly
the 6 new gpu.vulkan_prefill_gemm_* cases, all PASS.
Sole failure: pre-existing tolerated J-022 drift
(gguf.tensor_directory_interface). Skips: the 2
pre-declared.

## Bugs / gaps found

- No new defect is evidenced by the driver, bench, or
  suite logs for this slice: every A-068 case passed on
  the recorded runs and no in-slice fix was needed.
  Recorded honestly rather than inventing one.
- The IQ SPIR-V dedup above is a cleanup, not a bug
  fix: the hand-embedded arrays and the generated
  header carried identical words (asserted byte-equal
  by edit_a068.py before removal).
- Scope boundary (from the gateway header, honest):
  this is the GEMM layer of prefill only. Batched
  causal attention, per-position RoPE, and incremental
  KV writes for a full prefill layer are A-069's road
  (chunked prefill), not claimed here.
- A-046:B1 CPU remainder still open (from A-059):
  core/compute.mojo gemm_iq demands cols % 256 for
  IQ4_NL (GPU path proven at K=288); fix home
  unchanged — not this slice's scope.

## Banking

Committed on yrsa/aesir-team-01, subject "A-068: GPU
prefill GEMM". NOT merged, NOT pushed — keeper banks
after A-067 in roadmap order.
