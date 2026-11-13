# CAMPAIGN_STATE - team-25 (Aesir Z13 forge)

- Team: team-25 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-25, branch yrsa/aesir-team-25
- Base: 21044acf (banked main, 96 of 216, A-096 closure)
- Assigned slice: A-098 - NPU power profile. Perf-per-watt of the offloaded op on NPU vs GPU vs CPU. Acceptance: power table from A-018 sensors, filed.
- Status: A-098 DONE 2026-11-13 (see outcome below). Committed on team branch only; keeper banks at the seat in roadmap order after A-097. Never merge or push from this worktree. Never touch README.md. No Docker, ever.
- Suite baseline on this base: 607 passed / 1 failed / 2 skipped / 610 total; sole failure pre-existing gguf.tensor_directory_interface (J-022); known intermittents: resilience.state_vault_rejects_growth, gpu.amd_hip_stream_async_round_trip, gguf.weight_residency_gpu_visibility, memory.budget_live_meminfo_pressure.
- Raw-oracle discipline for all correctness work; accelerator-visible is not accelerator-run - every accelerator claim needs device-execution evidence on the real XDNA 2 / gfx1151.

## Team-25 outcome 2026-11-13 - A-098 DONE (MEASURED, filed)
- 6 Mythic Engineering sub-agents mustered, no rate limit.
- Power table (RAPL package-0 = A-018 road, in-process windows, pooled 3 runs/path; op = A-095 prefill projection GEMM 128x1024x1024): GPU 67.5 us/op, 77.7 W, 0.00524 J/op, 51.20 GF/s/W gross - the perf-per-watt winner by ~10x. CPU-opt 632.5 us/op, 79.4 W, 0.05023 J/op, 5.34 GF/s/W. NPU (single tile) 2,258.2 us/op, 22.1 W, 0.04985 J/op gross (tie with CPU), 0.02980 net of idle (1.5x better than CPU net), 5.39 gross / 9.01 net GF/s/W. Idle package 8.876 W.
- No per-engine power rail exists on this machine (stated plainly in doc + ledger); package energy is the like-for-like table, corroborated by the A-018 amdgpu PPT sensor.
- Correctness exact vs int64 oracle on all 3 paths (NPU checksum 2848816214485251074 == A-095; GPU fp32-exact proven 0 mismatches max err 0). Device evidence in every run log (device_name=NPU Strix Halo, ert_cmd_state=4 COMPLETED; gpu_device_name=AMD Radeon 8060S Graphics (RADV STRIX_HALO)).
- Doc: docs/bench/A098_NPU_POWER_PROFILE.md; ledger hidden_files/A098_LEDGER.md; logs hidden_files/a098/.
- Coordination: A-097 seat gate finished before any phase ran (ps-verified); NPU via sudo -n only; RLIMIT_MEMLOCK untouched; suite solo.
- Next-work note (not a bug): A-100 placement planner should consume this energy table alongside the latency tables.
