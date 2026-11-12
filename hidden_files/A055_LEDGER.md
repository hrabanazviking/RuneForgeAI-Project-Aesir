# A-055 LEDGER - SPIR-V build pipeline
Team: team-04 (lead + 6 Mythic Engineering sub-agents, no 429) | Date: 2026-11-12 | Host: purpleraider
Worktree: /home/volmarr/aesir-team-04 | Branch: yrsa/aesir-team-04 | Base: b62b1481 (54 of 216 banked, Wave 6 COMPLETE)
Status: BUILT + GATED + COMMITTED by team-04 - awaiting keeper banking in roadmap order. No merge/push from this worktree.

## Scope (roadmap docs/AESIR_Z13_MASSIVE_ROADMAP.md line 336, verbatim title)
A-055 - SPIR-V build pipeline. glslang-compiled kernels embedded and versioned in-repo, compiled at build time (never fetched at runtime). Acceptance: pipeline builds all wave kernels from a clean checkout; shader hashes recorded.

## What was built
- scripts/build_shaders.py: compiles every aesir_engine/shaders/*.comp with glslangValidator (target env vulkan1.0, SPIR-V 1.0), validates output, emits aesir_engine/shaders/generated/*.spv + aesir_shaders_spv.h (embedded words) and SHADER_MANIFEST.json with per-kernel source sha256, spv sha256, bytes, words. Deterministic: manifest records deterministic=true.
- 8 kernels: attention_decode, elementwise, gemv_f32, rmsnorm, rope, sampling_greedy, softmax, vec_add.
- scripts/build_matrix.sh: stage_shims now runs build_shaders.py first (log hidden_files/build_shaders.log); shader pipeline failure fails the matrix entry.
- aesir_engine/vulkan_buffer_shim.c: hardcoded vec_add SPIR-V word array replaced by the generated header include (words identical - vec_add spv sha256 b228710b... unchanged); comment updated to cite A-055 generation + manifest.
- aesir_engine/tests/test_spirv_pipeline_a055.mojo: 5 cases (gpu.spirv_pipeline_manifest, hashes_recorded, header_embedded, no_runtime_fetch, toolchain_recorded) registered in run_all.mojo; ledger pin re-based 445 -> 450.
- docs/bench/A055_SPIRV_PIPELINE.md: slice design/evidence note.

## Shader evidence (read from logs/manifest, 2026-11-12)
- hidden_files/build_shaders.log: 8 BUILT lines; every spv sha256 in the log matches SHADER_MANIFEST.json exactly (spot-verified all 8: attention_decode 53e44cae, elementwise 80458308, gemv_f32 65806166, rmsnorm b23cb30b, rope 5de79760, sampling_greedy a381ed5a, softmax 706162ba, vec_add b228710b).
- generated/ holds all 8 .spv files with byte sizes matching the manifest (5348/2868/2224/3984/2880/3788/4552/1608) plus aesir_shaders_spv.h (98949 bytes).
- Toolchain recorded in manifest: Glslang Version 11:16.4.0; SPIRV-Tools v2026.3.

## Gate runs (E-MASTER via scripts/build_matrix.sh cpu; counts read from logs)
1. hidden_files/a055_gate.log (prior lead): 447 passed / 1 failed / 2 skipped / 450 total - PASS. Sole failure = tolerated gguf.tensor_directory_interface (J-022 drift). This is the acceptance result on the exact committed tree.
2. hidden_files/a055_gate2.log (prior lead, 3 suites concurrent on host): 445/3/2 - FAIL. Extra failures: gguf.weight_residency_gpu_visibility (VAL-003 / MEM-004 USE_AFTER_FREE) + resilience.state_vault_rejects_growth.
3. hidden_files/a055_gate_clean.log (this lead, solo - ps verified empty before launch): 446/2/2 - residency failure persists solo.
4. hidden_files/a055_gate_clean2.log (this lead, solo repeat): 446/2/2 - residency failure persists solo.
5. BISECT hidden_files/a055_gate_base.log (this lead, solo, A-055 tracked WIP stashed = pure seat base b62b1481, 445 total): 440/3/2 - BOTH extra failures present at base (residency AND state_vault), plus J-022.

## Verdict on the extra failures - PROVEN pre-existing, NOT A-055
- The bisect (run 5) is decisive: with every A-055 tracked change removed, both suspect cases fail at the banked seat base; with A-055 applied, run 1 passed 447/1/2 and runs 3-4 failed fewer cases than base. A-055 neither introduces nor worsens them.
- Independence also shown structurally: gguf.weight_residency_gpu_visibility is registered and runs BEFORE all five A-055 cases in run_all.mojo, and the A-055 test file references no HipMemory/HIP state; the shim change touches only the Vulkan vec_add word source (identical bytes).
- Class: intermittent host-state-dependent failures in pre-existing A-020/A-022 (residency + HipMemory ownership ledger) and A-053 (StateVault) machinery - green at 12:04, failing from 12:06 onward on base and WIP alike. NOT waived as contention: my solo runs were verified uncontended (ps empty; team-06 suite log timestamp 11:28 predates them). Recorded below as named next work - not fixed inside A-055 because the defect lives in the A-022/A-053 machinery, outside this slice scope.
- Acceptance: met by run 1 (447/1/2 of 450, sole failure J-022) on the committed tree, with runs 2-5 as the fully explained equivalent evidence.
- Side observation: every suite run leaves an aesir-residency-* temp file in the worktree root (mkstemp debris from test_weight_residency); cleaned before commit; part of bug B1 below.

## Discovered bugs - named homes (never left unfixed/silent)
- B1 (pre-existing at b62b1481): gguf.weight_residency_gpu_visibility intermittently fails VAL-003 / MEM-004 USE_AFTER_FREE in HipMemory.memcpy_device_to_host (A-022 ownership-ledger machinery vs A-020 residency registration; address-reuse class suspect) + leaks aesir-residency-* temp files. IMMEDIATE NEXT WORK for team-04 (see CAMPAIGN_STATE.md) - reproduce standalone, fix in the residency/ledger line, do not re-pin the suite until characterized.
- B2 (pre-existing at b62b1481): resilience.state_vault_rejects_growth intermittently fails (StateVault accepted a checkpoint that grew during read) - same next-work block, A-053 StateVault line.
- Carried from A-046 state: Bug A-046:B1 (IQ4_NL GEMM shape gate) still open, home A-059 line; scripts/test_check_doc_drift.py ledger-count mismatch, home A-208.

## Files in this commit
Modified: aesir_engine/tests/run_all.mojo, aesir_engine/vulkan_buffer_shim.c, scripts/build_matrix.sh.
New: scripts/build_shaders.py, aesir_engine/tests/test_spirv_pipeline_a055.mojo, docs/bench/A055_SPIRV_PIPELINE.md, aesir_engine/shaders/SHADER_MANIFEST.json, aesir_engine/shaders/{attention_decode,elementwise,gemv_f32,rmsnorm,rope,sampling_greedy,softmax}.comp, aesir_engine/shaders/generated/{8 .spv + aesir_shaders_spv.h}, hidden_files/A055_LEDGER.md, CAMPAIGN_STATE.md.
NOT committed: pre-existing untracked debris from earlier slices (hidden_files/a004*/a028*/a037*/a046* leftovers, vk_probe.c) - left untouched for the keeper.
CPU/build-time only for the pipeline itself; no new accelerator execution claimed. No README touched. No Docker used.
