# A-075 Ledger — Accumulation policy (aesir-team-02)

Status: BUILT + TESTED + COMMITTED on yrsa/aesir-team-02, on top of
seat main 552fe796 (73 of 216 banked, ls-remote verified at tick
start). Awaiting banking by the keeper in roadmap order (A-074
first). Do NOT merge or push from this worktree.

## What was built

- `aesir_engine/core/accum_policy.mojo` — the policy table as code:
  25 Vulkan kernels in SHADER_MANIFEST order + 5 CPU reduction
  sites, each with evidence class and ratified accumulate dtype
  (FP32 for every reduction; ACCUM_NONE only for pointwise/copy
  kernels), plus the emulation accumulators (dot/sumsq/mass under
  F64-reference / FP32 / FP16 / BF16 accumulation modes) and the
  deterministic generator shared by test and bench.
- `aesir_engine/tests/test_accum_policy_a075.mojo` — 6 E-MASTER
  cases (accum_policy.*), registered in run_all with re-pin
  543 -> 549.
- `aesir_engine/tests/bench_accum_policy_a075.mojo` — standalone
  probe filing every number in the policy doc.
- `docs/bench/A075_ACCUMULATION_POLICY.md` — the acceptance
  deliverable: verdict, method, measured evidence, per-kernel
  policy table (25 Vulkan + 5 CPU rows) with the evidence behind
  each choice.

## Survey findings (crew of 6, read-only, filed in the doc)

- All 25 Vulkan shaders accumulate in FP32 today (accumulator,
  shared reduction, output); FP16 exists only as decoded quant
  scale fields (half_to_float / get_f16), converted to float
  before arithmetic. No float16_t, no extension, no subgroup or
  cooperative-matrix code anywhere.
- CPU paths likewise: gemm_f16 / gemm_bf16 / quant family /
  rmsnorm / fused attention all accumulate in F32 (compute.mojo,
  llama3_kernels.mojo). One legacy exception: flash_attention_2
  F16 partial-output stores (CAPABILITY_LEDGER AES-CPU-005,
  unbounded) — recorded as next work below.
- Pipeline: A-055 build_shaders.py pins --target-env vulkan1.0,
  SPIR-V 1.0; Vulkan 1.0 context enables no shaderFloat16 /
  16-bit-storage features, so an FP16-accumulate variant cannot
  compile or run today (A-073 subgroup precedent). RADV hardware
  reports shaderFloat16 = true — the verdict is numerics, not
  silicon.

## Evidence (hidden_files/a075_bench.log, sha256 69d468bddeed07de440914bd5d460385c68b4653cd472d68cada81fd5025bb4d9)

- DOT err vs F64: K=4096 fp32 8.7e-07 / fp16 2.3e-02 / bf16
  4.8e-02; K=14336 bf16 3.2e-01, fp32 7.3e-06. FP16 err grows
  ~47x K=256->4096 (A-047 K-growth discriminator at production K).
- LOGIT (16 positions x vocab 1024 x K=4096, parity_battery vs
  F64 row): fp32 faithful 16/16, rank 1, agree 16/16, dev 1.3e-05.
  fp16 faithful 16/16 by band but agree only 14/16 (noise 0.11 =
  top-2 margin scale; greedy flips inside the near-tie band).
  bf16 faithful 15/16, worst rank 3, max gap 0.72, dev 0.87 =
  divergence verdict class.
- NORM sumsq rel err n=14336: fp32 4.0e-06 / fp16 0.34 / bf16
  0.84; outlier-scale (std ~3) fp16 = +inf (65504 ceiling).
- MASS exp-mass rel err T=4096: 3.6e-06 / 0.099 / 0.81.
  ATTN weighted-V abs err: 2.0e-08 / 7.3e-04 / 2.5e-02.

## Suite (hidden_files/a075_run_all.log, sha256 407cbf9d19e6fd696d73534c9e604155d7041ea50e63a894e7a49d59210aab9d)

E-MASTER run_all (gfx1151): 546 passed / 1 failed / 2 skipped /
549 total = seat baseline at 73 banked (540/1/2/543) + exactly
the 6 new accum_policy.* cases, all passing. Sole failure the
pre-existing tolerated gguf.tensor_directory_interface (J-022
drift). Known intermittents (resilience.state_vault_rejects_
growth, gpu.amd_hip_stream_async_round_trip) both PASSED this
run — no flake to verdict. Standalone driver:
hidden_files/a075_driver.log, A075_DRIVER_ALL_PASS, MOJO_EXIT=0
(sha256 e005f31e6c3f224522f686a62d78a4c1b6dc448b2e82706f5cafaae6ec78f748).

## Bugs / observations

- No engine bug found in scope. Discovered out-of-scope items,
  recorded as immediate next work in CAMPAIGN_STATE.md:
  (1) legacy flash_attention_2 F16 partial-output stores
  (AES-CPU-005) sit outside the ratified FP32 policy — bring
  under policy or bound them; (2) CAPABILITY_LEDGER.md E-MASTER
  count phrase is stale (275/277-era text vs run_all's 543) —
  scripts/check_doc_drift.py check_master_count would flag it;
  pre-existing at the seat, not introduced by this slice, and
  recent slices have not touched that ledger line; (3) the
  A-066 test file latent buffer-slot pattern recorded by A-072
  remains open (carried forward).
- Bench probe defect found and fixed in-slice: first bench draft
  used `ref` as an identifier (Mojo keyword) and a List literal
  constructor this Mojo rejects; both fixed before first PASS.

## Files

aesir_engine/core/accum_policy.mojo (sha256 30941c94d9b084bc04f1812bf955eaa20bbd108197e3a25fc7d94cc8b46f52e3)
aesir_engine/tests/test_accum_policy_a075.mojo (8730c7444402f8fea050e069eba8f70b5410e3d260bd339b75967e339214bb21)
aesir_engine/tests/bench_accum_policy_a075.mojo (patched in place post-transfer; see git)
aesir_engine/tests/run_all.mojo (+19/-1: import, 6 run_case, re-pin)
docs/bench/A075_ACCUMULATION_POLICY.md (9ba07ee9b3869c5b7484e91d8ccc33f5729392f024567049ba7fff947a3f1395)
hidden_files/{A075_LEDGER.md, a075_bench.log, a075_driver.log, a075_run_all.log}
