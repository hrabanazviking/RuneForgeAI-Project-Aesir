# A-076 Ledger - GPU memory pressure (team-03)

## Status
- BUILT + TESTED + COMMITTED 2026-11-12 on yrsa/aesir-team-03, rebased onto seat main 552fe796 (73 of 216 banked; A-073 closure). Awaiting banking by the keeper after A-074/A-075 in roadmap order. NOT merged or pushed from this worktree.
- Crew: lead + 6 Mythic Engineering sub-agents (all returned, no rate limits).

## WIP judgement (previous lead, verified from disk)
- Found on old base 7e550b82: modified run_all.mojo (+7 cases, pin 537->544 on that base), untracked core/gpu_pressure.mojo (327 lines, complete - the header note about an earlier truncated partial refers to a still earlier attempt; THIS file is whole), tests/test_gpu_pressure_a076.mojo (7 cases), tests/bench_gpu_pressure_a076.mojo, balloon pressure harness. Judged SOUND and kept entire.
- Preserved before reset: hidden_files/a076_wip_full.patch (sha256 4b1c3779d437dbb41e4cc3eaab0381d9be3a6907d5a59545480c560eeda841cc) incl. intent-to-add new files; tracked-only patch a076_wip_tracked.patch.
- Re-applied onto 552fe796 by hand (run_all hunks re-anchored on the A-071 import/case blocks; pin reconciled to seat 543 + 7 = 550, NOT the WIP 544). Nothing discarded except the stale pin arithmetic.

## Deliverables
- core/gpu_pressure.mojo: GpuPressureGovernor - pre-dispatch routing contract between the A-064 residency gateway and the A-023 budget governor. classify_pressure by available fraction (>=1/2 NONE, >=1/4 MODERATE, >=1/8 HIGH, else CRITICAL; unknown figures stay UNKNOWN, never invented). route(): GPU only if the request fits BOTH the configured GPU cap and live effective room (MemAvailable - reserve); spillable overflow -> ROUTE_SPILL_CPU on a capped spill ledger; non-spillable overflow and spill-cap overflow -> ROUTE_REFUSE (MEM-003 class), decided BEFORE any GPU allocation exists, never raises. Every verdict logged (route, bytes, pressure, avail, both ledgers); log bounded at LOG_MAX=128 with log_dropped counter. Checked releases (over-release raises) return both ledgers to baseline exactly - degradation is a state, not a ratchet.
- tests/test_gpu_pressure_a076.mojo: 7 E-MASTER cases (classification boundaries; GPU baseline; squeeze spill/refuse; bounded degradation incl. bad sizes + over-release; recovery; live meminfo parse + log-storm bound; real RADV device buffer).
- tests/bench_gpu_pressure_a076.mojo: standalone real-pressure driver (not in run_all), driven by hidden_files/run_a076_pressure3.sh.
- run_all.mojo: +7 cases, pin 543 -> 550.

## Suite (counts READ FROM LOG)
- hidden_files/a076_run_all.log (sha256 37991af5b921db727eccac25827acf556c28e2aee10c9150581bc495d521fc3f): 547 passed / 1 failed / 2 skipped / 550 total = seat baseline 540/1/2/543 + 7 new gpu.gpu_pressure_* all PASS, zero regressions. Wall 2:42, max RSS ~15.6 GiB (shared box, teams 01/02 building concurrently).
- Sole failure: gguf.tensor_directory_interface - pre-existing J-022 drift (roads A-165/A-121), unchanged.
- Skips: the 2 pre-declared.
- Known intermittents verdict this run: resilience.state_vault_rejects_growth PASS, gpu.amd_hip_stream_async_round_trip PASS - clean, no re-run needed.
- Device case ran FOR REAL (not honest-absent): "PASS: real RADV STRIX_HALO buffer admitted, freed, both accounts at baseline"; live pool measured in-suite: total 130,454,048,768 B, available 114,448,437,248 B, level NONE.

## Real external pressure experiment (hidden_files/a076_pressure_v3.log, sha256 521ee833cae54d1e8afa8a805d4a750c6a7d450bde3a39fb4d71a955b09f5f65)
- Balloon = separate python process holding 25,769,803,776 B, every page memset-touched, BALLOON_READY rss_pages=6,294,509 verified before run B. Safety: refuses under 48 GiB MemAvailable; trap kills balloon on any exit; recovery of MemAvailable verified.
- Run A (no balloon, reserve anchored AFTER bench build at avail-128 MiB): eff_room 126,992,384 -> GPU/GPU, spills 0, refusals 0.
- Run B (balloon up): MemAvailable 127,427,665,920 -> 101,645,975,552 (real 25.8 GB squeeze), eff_room 0 -> spillable SPILL_CPU, non-spillable REFUSE, both logged, governor back at baseline, no crash (RUN_B_EXIT=0).
- Run C (balloon killed): MemAvailable recovered to 126,987,673,600; ambient drift 552,574,976 B logged and reserve re-anchored transparently (reserve_c_reanchored_bytes in log) -> GPU/GPU again. Recovery demonstrated end-to-end under real external pressure.
- Attempt history (filed, not hidden): v1 (a076_pressure.log) waited only for avail < reserve, so run B fired ~6 GB into the balloon ramp and run C missed its razor-thin 64 MiB margin; v2 (a076_pressure_v2.log) fixed the wait + run C but anchored the reserve BEFORE the bench build, so build drift (~96 MB) spoiled run A. v3 anchors after the build - clean A/B/C. Protocol lesson: anchor pressure margins after all build churn, and wait for the balloon READY line, never a threshold crossing.

## Honesty bounds (what is NOT claimed)
- Live classification stayed NONE in every real run (available fraction 78-98% of the pool): the balloon flips routing through the effective-room/reserve term, not the fraction classifier. MODERATE/HIGH/CRITICAL routing is proven at unit level on handed figures only; a live HIGH/CRITICAL pool state was NOT induced (doing so on the shared box would endanger other campaigns).
- The governor is a pre-dispatch routing/accounting contract: it is NOT yet wired into the A-064 residency gateway or AesirEngine, and a SPILL_CPU verdict does not yet execute a measured CPU GEMM of the spilled weight - it routes + accounts + logs, per the A-070 lawful-assist pattern of accounting before integration.
- No throughput/latency degradation numbers are claimed; boundedness is proven as caps (GPU cap, spill cap, log cap), not as a performance curve.

## Bugs found + fixed in-slice
- Pressure harness only (no engine bugs): balloon wait + reserve anchoring defects above, fixed across v1->v3 with all attempts filed.
- classify_pressure multiplies available by 2/4/8: safe for any real meminfo figure (pool << 2^60 B); synthetic callers passing near-Int.MAX figures could overflow - recorded here, not changed (changing boundary arithmetic mid-slice risks the proven boundaries; first hardening slice may switch to division-based comparison).

## Immediate next work
1. Wire GpuPressureGovernor into the A-064 Vulkan residency gateway + AesirEngine load path: first engine-integration slice routes real weight admissions through route() and executes SPILL_CPU weights on the CPU path, with the decision log surfaced in doctor output.
2. Live HIGH/CRITICAL pressure proof remains open: only on a quiesced box (no concurrent campaigns), with Volmarr present, may a balloon sized to push the available fraction under 1/4 be run.
3. Division-based classify_pressure hardening (note above).
