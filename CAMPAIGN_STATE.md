# CAMPAIGN_STATE - team-21 (Aesir Z13 forge)

- Team: team-21 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-21, branch yrsa/aesir-team-21
- Base: 6396cd62 (banked main, 86 of 216, A-086 closure)
- Assigned slice: A-091 - XDNA 2 capability census. AIE tile count, supported data types and ops, memory model - from XRT tooling + AMD documentation, distinguished as observed vs documented. Acceptance: census doc with the source of every claim marked.
- Context: Wave 11 opener (NPU first light). The NPU earns its place by measurement or not at all. A-007 caveat stands: unprivileged xrt-smi is blocked by RLIMIT_MEMLOCK (8192 kB vs the 64 MiB locked map XRT wants) - NPU tools run via sudo until Volmarr rules on raising the user memlock limit; mark every claim OBSERVED (tooling on this Z13) or DOCUMENTED (AMD docs) - never merge the two.
- Status: MUSTERED 2026-11-13 by the keeper (expansion to 27 teams). Build and commit on the team branch only; the keeper banks at the seat in roadmap order after A-090. Never merge or push from this worktree. Never touch README.md. No Docker, ever.
- Suite baseline on this base: 597 passed / 1 failed / 2 skipped / 600 total (seat gate A-086); sole failure pre-existing gguf.tensor_directory_interface (J-022 drift); skips the 2 pre-declared. Known intermittents (pre-existing, proven at base): resilience.state_vault_rejects_growth, gpu.amd_hip_stream_async_round_trip and gguf.weight_residency_gpu_visibility - a suite showing only those plus J-022 is green-to-baseline; re-run once before treating any as new.
- Machine note: defer full-suite runs while heavy shared work is live, and never run a suite concurrently with a seat gate.
- Raw-oracle discipline for all correctness work; accelerator-visible is not accelerator-run - every accelerator claim needs device-execution evidence (dispatch counters / device identity on the real XDNA 2).

## Outcome - A-091 DONE (2026-11-13, team-21 lead)
- Census filed: docs/bench/A091_XDNA2_CENSUS.md. Headline: OBSERVED aie2p topology 6x8, Total Columns 8 (sudo xrt-smi, fresh); DOCUMENTED 32 compute tiles (8x4, AMD); 48 total tiles DERIVED only. No NPU compute run or claimed.
- Fresh re-verifications: memlock wall (8192 kB vs 64 MiB map, unprivileged xrt-smi fails EAGAIN); validate blocked (VTD archive absent = A-092 first step); stacks absent (MLIR-AIE/IRON, pyxrt, Python onnxruntime, Vitis AI EP); FastFlowLM xclbins now present under /opt (third-party; corrects A-016 record).
- Suite: hidden_files/a091_run_all.log = 597/1/2 of 600, baseline-exact, sole failure pre-existing J-022. Evidence: hidden_files/A091_LEDGER.md + a091_probe1-4.log + a091_xrtsmi.log.
- Next work (for A-092, not this team): VTD archive fetch, kernel toolchain stand-up, memlock ruling is Volmarr's.
- Status: committed on yrsa/aesir-team-21, ready for keeper banking after A-090. Never merged/pushed from this worktree.
