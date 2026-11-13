# A-101 Ledger - Pipeline overlap (team-25)

- Date: 2026-11-13 (EST, purpleraider local)
- Machine: purpleraider - ASUS ROG Flow Z13, AMD Ryzen AI
  Max+ 395, XDNA 2 NPU, Radeon 8060S gfx1151, XRT 2.25.
- Worktree: /home/volmarr/aesir-team-25, branch
  yrsa/aesir-team-25, base 1a611172 (banked main, 99 of 216,
  A-099 closure). Previous slice A-098 banked (825b947a plus
  closure 6e059359, verified in the seat git log).
- Prior lead for this slice was cancelled with no commit and
  no A-101 files in the worktree (checked: no a101/A101 paths;
  only pre-existing untracked a095 and a098 spike leftovers,
  left untouched). This lead redid the slice cleanly.
- Verdict: POSITIVE, measured. Three-leg pipeline (GPU
  prefill, CPU sampling prep, NPU assist) overlapped wall
  10,015 to 10,079 us median vs serial 18,900 to 19,145 us;
  delta 8,881 to 9,129 us (46.8 to 47.7 percent), 3 runs x
  21 reps. Doc: docs/bench/A101_PIPELINE_OVERLAP.md.
  Logs: hidden_files/a101/run{1,2,3}.log.

## Method
- Harness spikes/a101_pipeline/pipeline_probe.cpp, derived
  from the banked A-096 overlap probe and extended: a CPU
  sampling-prep leg (vocab 32,768, 260 rounds, deterministic
  checksum) and a three-mode timeline. Device end timestamps
  come from waiter threads blocked on the Vulkan fence and
  the XRT run, not from the main thread after CPU work (an
  earlier draft timestamped wait-returns on the main thread
  and inflated every leg to the CPU end; caught in review of
  run 0 traces and fixed before the filed runs).
- NPU side: A-094 p128 xclbin plus insts copied from the
  team-26 A-096 spike dir (banked artifacts, uuid
  184c0a55-97ee-d107-bad0-060c59a9a278), 128x1024x1024
  i16 to i32 prefill projection GEMM.
- GPU side: gemv.comp from A-096, 1024x1024 fp32 GEMV x64
  reps per dispatch, RADV STRIX_HALO.
- Build: g++ -O2 -std=c++17 -I team-22 scratch/a092/overlay
  -I team-22 scratch/a092 pipeline_probe.cpp -o
  pipeline_probe libxrt_coreutil.so.2 -luuid -lpthread
  -lvulkan; glslc gemv.comp -o gemv.spv (recipe in
  hidden_files/run_a101.sh).
- Run: sudo -n ./pipeline_probe final_p128.xclbin
  insts_p128.bin gemv.spv 64 (sudo for NPU memlock, A-007;
  limit never changed). ps checked clear of other team
  suites and probes before every run.
- In-engine model: aesir_engine/core/pipeline_overlap.mojo
  (timeline arithmetic, acceptance predicate, plan gated on
  the A-095 dispatch with A-099 degradation) plus six cases
  in aesir_engine/tests/test_pipeline_overlap_a101.mojo,
  registered in run_all.mojo, finish re-pinned 610 to 616.

## Evidence
- NPU exact vs CPU oracle all 3 runs: 131,072 elements,
  0 mismatches, 0 sentinels, ert_cmd_state=4, checksum
  2848816214485251074 (matches A-095 and A-096).
- GPU GEMV max abs err 0.000035 vs CPU oracle, all runs;
  device named from VkPhysicalDevice properties.
- CPU prep checksum 3359139257229004943, repeat-equal
  in-process and identical across all 3 runs.
- Pairwise overlap medians positive for all three pairs in
  all 3 runs (see bench doc table).

## Dependency / coordination
- A-100 (placement planner, team-27) NOT landed at run
  time. No planner duplication: the plan model consumes the
  banked A-017/A-086 surfaces via the A-095 registry entry.
  When A-100 banks, the keeper reconciles the run_all union
  pin (A-100 cases plus these six) at banking in order.
- A-102 (team-26) builds in parallel in its own worktree;
  suites never run concurrently (ps-verified solo gate).

## Suite
- E-MASTER on this worktree: see hidden_files/a101/
  a101_run_all.log; counts in CAMPAIGN_STATE.md. Baseline
  on banked main: 607 passed / 1 failed / 2 skipped of 610,
  sole failure pre-existing gguf.tensor_directory_interface
  (J-022). Expected with this slice: 613 / 1 / 2 of 616 if
  the six new cases pass and nothing else moves.
