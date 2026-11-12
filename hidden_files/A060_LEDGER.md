# A-060 Ledger — Vulkan RMSNorm + RoPE (team-05)

- Slice: A-060 — Vulkan RMSNorm + RoPE (docs/AESIR_Z13_MASSIVE_ROADMAP.md line 348; acceptance: reference parity per op, incl. adversarial shapes from the existing compute test patterns).
- Team: 05 (lead + 6 Mythic Engineering sub-agents; all 6 spawned clean, no 429).
- Date: 2026-11-12. Host: purpleraider. Worktree: /home/volmarr/aesir-team-05, branch yrsa/aesir-team-05.
- Base: 5b172516 (seat main, "Banking closure: A-055..A-057 banked (57 of 216)"). Worktree was at cae6b507 (A-047); A-047 verified banked by subject in the seat log (3f03be59 + closure 0cacfc61); untracked CAMPAIGN_STATE.md + hidden_files backed up to /home/volmarr/aesir-team05-backup-pre-a060/ before reset --hard onto 5b172516. (Keeper note: A-058 banking landed at the seat in parallel, 278199de; this branch stays based on 5b172516 per keeper instruction — banking reconciles.)
- Status: BUILT+GATED+COMMITTED — awaiting keeper banking in roadmap order (A-058, A-059 bank first). No merge/push from this worktree.

## Deliverables

| File | Change |
|---|---|
| aesir_engine/vulkan_buffer_shim.c | +aesir_vk_buffer_rmsnorm, +aesir_vk_buffer_rope, +2 dispatch counters/getters; SPIR-V from the A-055 generated header (kRmsnormSpv/kRopeSpv), per-call pipeline mirroring A-056, floats via IEEE-754 bit patterns |
| aesir_engine/core/vulkan_norm_rope.mojo | NEW — VulkanNormRope gateway (rmsnorm/rope + counters), fail-closed, A-056 error taxonomy |
| aesir_engine/tests/test_vulkan_rmsnorm_rope_a060.mojo | NEW — 6 cases, in-file sequential F32 oracles per op |
| aesir_engine/tests/run_all.mojo | +import, +6 run_case lines, pin 458 -> 464 with comment |
| docs/bench/A060_VULKAN_RMSNORM_ROPE.md | NEW — bench/parity note |
| hidden_files/A060_LEDGER.md, run_a060.sh, a060_run_all_run1.log, a060_run_all.log | this ledger, runner, both suite logs |

## Shader / SPIR-V

No new GLSL. Both kernels are A-055 foundation shaders written for A-060, compiled by the A-055 pipeline: rmsnorm.comp (source sha256 74a4c2e758f42b70076cc8e7f12d309520f0e1dd8f5370654a12918e99c8030c; SPIR-V 3984 B, sha256 b23cb30bc450a41d97e447c608063a7498b5df218ac95c4702a54c1187d3c7ae), rope.comp (source sha256 1f63e9790883396df28db0e8123957f826d52b79aca1e02ad7b04dc54121412f; SPIR-V 2880 B, sha256 5de79760b84c0ca6bbe0ce773241b5fc6a5e260c1a98e86f560e10665da50768). First Wave 7 slice to dispatch through the generated header rather than hand-embedded words.

Convention decisions (explicit, per worker-4 spec): RoPE pairing = rotate-half (i, i+head_dim/2), matching the shader of record and engine apply_rope with neox=True; the CPU default interleaved layout is a different op layout, NOT implemented here. RoPE position is one per dispatch for all rows (decode shape: rows = heads of one token). RMSNorm eps inside the root on the mean of squares, default 1e-5, weight after normalisation, no (1+g).

## Parity verdicts (device: AMD Radeon 8060S, RADV STRIX_HALO; llvmpipe refused by the _vk_present identity check)

Oracles: sequential Float32 references in the test file from the op definitions over identical inputs (raw-oracle discipline; never code under test, never the F16 engine path).

RMSNorm (eps 1e-5), max_abs per shape: 1x64 4.90e-07; 4x256 5.29e-07; 13x37 3.71e-07; 3x255 5.18e-07; 2x257 6.92e-07; 37x320 1.267e-06 (worst); 1x4096 1.121e-06; 2x512 @scale 1000 8.86e-07. Filed bound 1e-3 — PASS with ~800x headroom. Zero row -> exact zeros; constant row -2.5 -> -0.75*g within 1e-4. Known value x=[3,4], eps=3.5, g=[2,0.5] -> [1.5, 0.5] (dyadic-exact construction).

RoPE (base 10000), max_abs per shape: 64x4@p1 4.77e-07; 128x2@p7 8.42e-07; 32x13@p128 1.854e-05; 256x1@p3 5.96e-07; 64x1@p1000 6.765e-05 (worst); 128x3@p0 0.0 exact. Filed bound 1e-3 — PASS with ~15x headroom. Verdict class for the position growth: precision (fp32 angle argument reduction, RADV vs host libm), not layout — low positions pin the pairing exactly. Position 0 exact identity asserted; pair squared-norms preserved at p5.

Rejection: 11 bad calls all raise (rmsnorm n=0, rows=0, eps=0, oversize; rope head_dim 63 odd, 0, rows=0, position -1, oversize; bogus id for both ops). Dispatch evidence: counters +2/+2 for 2+2 dispatches, live bytes/count exact (no leak). Parity lines bit-identical between run 1 and the clean re-run (deterministic).

## Suite (counts read from logs)

- Base at 5b172516 (seat gate): 455 passed / 1 failed / 2 skipped / 458 total.
- Run 1 (hidden_files/a060_run_all_run1.log, pin still 458): 461 / 1 / 2 / 464.
- Clean re-run (hidden_files/a060_run_all.log, pin 464, no other suite running — team-01's A-059 run waited out first): 461 passed / 1 failed / 2 skipped / 464 total. Delta vs base = exactly the 6 new cases, all PASS. Sole failure: gguf.tensor_directory_interface (J-022 drift, tolerated pre-existing). Skips: the 2 pre-declared. Status FAIL in the summary is solely that tolerated failure, identical to base behaviour (MOJO_EXIT=1 at base too).

## Bugs / follow-ups

- Build fix inside slice scope: Mojo free-function bitcast needed `from std.memory import bitcast` (two compile iterations, fixed in vulkan_norm_rope.mojo; no other files affected).
- Pre-existing, NOT this slice: scripts/build_shaders.py --check fails identically on the pristine seat at 5b172516 (A-056/A-057 added q8_0_gemv/q4k_gemv .comp sources after the A-055 manifest; kernel_count 8 vs 10). Recorded as the A-056/A-057 manifest-regeneration follow-up; A-060 deliberately does not regenerate (would rewrite header/manifest beyond scope). The rmsnorm/rope manifest entries A-060 consumes are present and hash-correct, and the A-055 spirv_pipeline suite cases pass.
- Follow-up candidates (recorded, not blocking): RoPE large-position precision (fp32 angle reduction at p>=1000, worst 6.8e-05) could adopt the F64 phase reduction pattern from core/llama3_kernels.mojo if a future slice needs tighter large-context parity; interleaved-layout RoPE remains unimplemented on Vulkan (Llama-family layout) if a consumer slice requires it.

Committed on yrsa/aesir-team-05 only. No README touched. No Docker.
