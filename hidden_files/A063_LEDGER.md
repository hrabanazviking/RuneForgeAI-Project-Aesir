# A-063 Ledger — Vulkan sampling (team-03)

- Slice: A-063 — Vulkan sampling (docs/AESIR_Z13_MASSIVE_ROADMAP.md, Wave 7 closer)
- Worktree: /home/volmarr/aesir-team-03, branch yrsa/aesir-team-03
- Base: 3d89b1e8 (Banking closure: A-062 banked, 62 of 216)
- Date: 2026-11-12 (America/New_York)
- Status: DONE — built, gate green, committed on team branch; awaiting
  keeper banking in roadmap order (A-063 is the next unbanked slice).
- Crew: lead + 6 Mythic Engineering sub-agents (all returned, no rate limits).
- Previous lead check: worktree HEAD was exactly the seat 3d89b1e8 with a
  clean tree apart from untracked CAMPAIGN_STATE.md/hidden_files — the
  cancelled previous lead produced NO A-063 work; this slice started clean.

## Deliverables

- aesir_engine/shaders/sampling_sample.comp — NEW temperature/top-k
  kernel: parallel (value, index) argmax reductions enumerate the ranked
  kept set under the stable total order (scaled logit desc, id asc on
  ties); thread 0 then accumulates exp mass in ranked Float32 order and
  applies the CPU draw rule (first kept token with u * total <= acc).
- SPIR-V registration via the A-055 pipeline (scripts/build_shaders.py,
  glslang 16.4.0, deterministic double-compile): sampling_sample.spv
  6996 bytes, sha256 b979830ca31206c743a36dc9a433e81348b45140b80b7eb90b156c1c8ca44648;
  generated header gains kSamplingSampleSpv + registry entry; manifest
  kernel_count 12 -> 13. All 12 pre-existing kernel hashes byte-identical
  after regeneration. NOTE: the pipeline was run with the four IQ .comp
  sources temporarily held aside (restored immediately after) — see
  Bug/drift 2 below. Greedy uses the pre-existing A-055 sampling_greedy
  kernel (kSamplingGreedySpv) — no hand-embedded SPIR-V anywhere in A-063.
- aesir_engine/vulkan_buffer_shim.c — vk_sampling_dispatch helper +
  aesir_vk_buffer_sampling_greedy / aesir_vk_buffer_sampling_sample
  (per-dispatch pipeline discipline as A-056/A-062; counters
  aesir_vk_sampling_{greedy,sample}_dispatch_count increment only after
  submit + queue-wait-idle).
- aesir_engine/core/vulkan_sampling.mojo — static VulkanSampling gateway:
  greedy(logits, out, n) + sample(logits, out, n, top_k, temperature, u);
  fail-closed VAL-003/GPU-002/GPU-001 mapping, no host fallback; stochastic
  bounds n <= 16384, effective kept <= 1024 (kernel design bounds).
- aesir_engine/tests/test_vulkan_sampling_a063.mojo — 6 cases with
  independent in-file CPU references (greedy argmax; ranked temperature/
  top-k draw mirroring core/sampler.mojo semantics).
- aesir_engine/tests/test_spirv_pipeline_a055.mojo — pins 12 -> 13 kernels
  (+ sampling_sample name, + kSamplingSampleSpv header const).
- aesir_engine/tests/run_all.mojo — 6 cases registered
  (gpu.vulkan_sampling_*), suite pin re-pinned 485 -> 491.

## Gate (E-MASTER, hidden_files/run_a063.sh, purpleraider)

- Final: 488 passed / 1 failed / 2 skipped / 491 total = seat baseline
  482/1/2/485 + 6 new A-063 cases, all PASS, zero regressions.
  Sole failure = tolerated pre-existing gguf.tensor_directory_interface
  (J-022 drift, roads A-165/A-121); skips = 2 pre-declared.
- hidden_files/a063_run_all.log sha256
  b8bce33f10e3142b5550a48d0295476a905691ae2e00652a2a060d4eb3193602
  (wall 1:46.31 for the timed mojo run).
- Two earlier gate attempts failed at Mojo parse time only (Array-vs-List
  literals, Tuple element moves, `out` parameter-convention keyword in
  the gateway) — all fixed in the test/gateway sources; no engine or
  shim defect was involved.

## Device-execution evidence (RADV, no llvmpipe)

Suite log line: "Vulkan device: AMD Radeon 8060S Graphics
(RADV STRIX_HALO)"; test gate refuses llvmpipe (vendor 0x1002,
device_type != 4, device_name_is_radv). All 6 A-063 cases PASS:
- greedy_oracle_parity: token-exact vs CPU greedy at n = 1, 7, 255, 256,
  257, 1024, 4096, 32768 (LCG fixtures).
- greedy_tie_policy: 5 crafted cases (all-equal -> 0, duplicated maxima ->
  lowest index incl. n=5000 tie at 123/4999, negative-only, n=2).
- sample_oracle_exact: token-exact vs the CPU draw for the SAME u across
  7 fixtures (hand n=8 at k=all/3/5/1 x T=1/0.5/2/0.7; LCG n=64 k=10/64;
  LCG n=1000 k=40 T=1.3) x u grids of 8/8/8/8/8/8/5 values.
- temperature_distribution: 800 deterministic-u draws (u = (j+0.5)/M);
  k=3 T=1 frequencies within 0.02 of oracle probs, truncated tokens
  drawn exactly 0 times; T=0.4 vs T=2.5 (k=all) each within 0.03 and
  argmax frequency strictly falls as T rises (flattening).
- rejection: 9 invalid calls raise pre-dispatch (n=0, undersized logits,
  T=0, T<0, top_k<0, u<0, u=1, kept-cap 2048, n bound 16385); counters
  unchanged.
- dispatch_evidence: greedy counter +3, sample counter +2, live
  bytes/count accounting exact (no leaks).

## Scope notes / next work (recorded, none hidden)

1. Non-finite logits: the CPU sampler sanitizes NaN/Inf lanes to -1e9
   before sampling; the A-063 kernels consume raw Float32 and do not
   sanitize. First slice that feeds un-sanitized engine logits to
   VulkanSampling must add sanitization (host-side pre-pass or kernel
   lane clamp) — recorded in team-03 CAMPAIGN_STATE.md as immediate
   next work for the engine-integration wave (A-064+).
2. PRE-EXISTING pipeline drift (not A-063): scripts/build_shaders.py
   globs ALL shaders/*.comp, including the four IQ kernels A-059
   hand-embedded in the shim, so a bare pipeline run (or
   build_matrix.sh stage_shims, or build_shaders.py --check, which
   FAILS at the seat) would register 16 kernels and collide with the
   hand-embedded IQ arrays. A-063 registered sampling_sample by running
   the pipeline with the IQ sources held aside and restored, leaving
   every pre-existing hash unchanged. ROAD: the slice that next
   regenerates the pipeline should dedup the IQ kernels into the
   generated header exactly as A-062 did for the GEMV kernels.
3. Stochastic kernel bounds (n <= 16384, kept <= 1024) are gateway
   enforced; full-vocab stochastic sampling (32k vocab, kept = vocab)
   needs a multi-pass or sort-based kernel — future slice, not claimed.

- No README.md touched. No merge/push (keeper banks).
