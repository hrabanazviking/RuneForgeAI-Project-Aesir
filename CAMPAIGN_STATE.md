# CAMPAIGN_STATE - team-20 (Aesir Z13 forge)

- Team: team-20 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-20, branch yrsa/aesir-team-20
- Base: 6396cd62 (banked main, 86 of 216, A-086 closure)
- Assigned slice: A-090 - HIP soak or instability verdict. One-hour decode soak on the HIP path if integrated; else the instability evidence is filed as the verdict. Acceptance: soak log or verdict doc - one of the two, honestly.
- Context: A-085 verdict is BANKED - Vulkan is the PRIMARY GPU road; HIP is PARKED probe-only, and A-086 banked that verdict into the live registry (Vulkan first-class, HIP probe-only). A-090 is the Wave 10 closer: HIP is NOT integrated as a primary path, so the honest deliverable is expected to be the instability/verdict doc unless a genuine one-hour HIP decode soak is actually run and logged. Never claim a soak that did not run; never claim HIP is integrated.
- Status: MUSTERED 2026-11-13 by the keeper (expansion to 27 teams). Build and commit on the team branch only; the keeper banks at the seat in roadmap order after A-086, A-087, A-088 and A-089. Never merge or push from this worktree. Never touch README.md. No Docker, ever.
- Suite baseline on this base: 597 passed / 1 failed / 2 skipped / 600 total (seat gate A-086); sole failure pre-existing gguf.tensor_directory_interface (J-022 drift); skips the 2 pre-declared. Known intermittents (pre-existing, proven at base): resilience.state_vault_rejects_growth, gpu.amd_hip_stream_async_round_trip and gguf.weight_residency_gpu_visibility - a suite showing only those plus J-022 is green-to-baseline; re-run once before treating any as new.
- Machine note: defer full-suite runs while heavy shared work is live, and never run a suite concurrently with a seat gate. A one-hour soak is heavy shared work - coordinate via this state file and do not start it while a seat gate or another team suite is live.
- Raw-oracle discipline for all correctness work; accelerator-visible is not accelerator-run - every accelerator claim needs device-execution evidence (dispatch counters / device identity on the real gfx1151).

## A-090 result (team-20, 2026-11-13)
- Verdict: HIP is NOT integrated (A-085/A-086 stand); no soak was run or claimed; the instability evidence is filed as the verdict.
- Deliverables: docs/bench/A090_HIP_INSTABILITY_VERDICT.md (8,190 B, sha256 474ac312...94b1c4) and hidden_files/A090_LEDGER.md (sha256 252d566d...ffada).
- Suite: 597 passed / 1 failed / 2 skipped / 600 total (hidden_files/a090_run_all.log) = base baseline; sole failure pre-existing gguf.tensor_directory_interface (J-022); no known intermittent appeared; +0 cases, pin stays 600.
- Bugs: none in engine code in scope. Next work: persistent-context HIP launcher or MAX pool cap (A-085 re-open criteria 1-2); HIP stays probe-only until all four criteria are met and a fresh bake-off is run.
- Status: DONE on team branch, awaiting keeper banking in roadmap order after A-087/A-088/A-089.
