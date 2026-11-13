# A-098 Ledger - NPU power profile (team-25)

- Date: 2026-11-13 (EST, purpleraider local)
- Machine: purpleraider - ASUS ROG Flow Z13, AMD Ryzen AI
  Max+ 395 (Strix Halo), XDNA 2 NPU [0000:c5:00.1],
  Radeon 8060S gfx1151, system XRT 2.25.00
- Worktree: /home/volmarr/aesir-team-25, branch
  yrsa/aesir-team-25
- Base: 21044acf (banked main, 96 of 216, A-096 banking
  closure; A-095 verified banked by subject in git log:
  "A-095: NPU offload #1" under the 95-of-216 closure).
- Crew: team lead + 6 Mythic Engineering sub-agents
  (roadmap/scout, power telemetry, raw-oracle correctness,
  benchmark design, house style, risk/coordination - all
  mustered, no rate limit).
- Verdict: MEASURED, filed (acceptance = power table from
  A-018 sensors). GPU is the perf-per-watt winner for the
  offloaded op by ~10x; NPU ties optimized CPU on gross
  package J/op, beats it 1.5x net of idle, at 22.1 W vs
  79.4 W package. Full table: docs/bench/
  A098_NPU_POWER_PROFILE.md.

## What was built
1. spikes/a098_power/power_runner.cpp - the banked A-095
   host runner (aesir_engine/npu_prefill_offload.cpp)
   copied into the spike and patched with an in-process
   RAPL window: read_euj() reads intel-rapl:0 energy_uj
   immediately before/after the E2E dispatch loop on BOTH
   the CPU and AMD_XDNA paths and prints a POWER line
   (energy_uj_delta, wall_us, dispatches, rapl_ok). The
   shipping engine runner is untouched.
2. spikes/a098_power/gpu_power.cpp + gemm.comp (glslc ->
   gemm.spv) - Vulkan compute GEMM at the same shape on
   the Radeon 8060S; RAPL window around a single
   submission of N dispatches; output re-verified exact
   after the window.
3. hidden_files/run_a098.sh - phase driver: idle x2,
   CPU x3, GPU x3, NPU x3, sequential and solo, with a
   5 Hz amdgpu PPT/temp sampler (the A-018 sensor) for
   the whole run. Logs in hidden_files/a098/.

## Power sources (named; nothing invented)
- PRIMARY: RAPL package-0 energy_uj, in-process at window
  boundaries. Strix Halo package domain covers CPU+GPU+
  NPU (single APU) = whole-APU energy per op, the only
  like-for-like rail exposed. Root-only file: runners via
  sudo -n, rapl_ok=1 on every POWER line. Max range
  65,532,610,987 uJ (no wrap in ~1 kJ windows).
- SECONDARY / A-018 sensor: amdgpu hwmon13 power1_average
  (PPT) medians corroborate RAPL (idle 8.1-9.3 W, CPU
  72-82 W, NPU 21-22 W; GPU 53 W median is the smoothed
  sensor over a ~2 s window - RAPL integral governs).
- ABSENT, stated plainly: no NPU-only or GPU-only power
  rail is exposed on this machine (hwmon census: amdgpu
  PPT, k10temp; XRT offers no power telemetry here), so
  no per-engine watts are claimed anywhere in this slice.

## Measured (pooled 3 runs/path; per-run logs in
## hidden_files/a098/{cpu,gpu,npu}_r{1,2,3}.log)
Op = prefill projection GEMM 128x1024x1024 = 0.2684 GFLOP.
Idle package (2 x 10 s): 8.462 / 9.290 W, mean 8.876 W.
- GPU (Vulkan): 67.5 us/op, 3,976 GFLOP/s, 77.7 W gross,
  0.00524 J/op gross, 0.00464 net, 51.20 GF/s/W gross,
  57.81 net. 30,000 dispatches/run.
- CPU (opt 32-thread, A-095 path): 632.5 us/op,
  424 GFLOP/s, 79.4 W, 0.05023 J/op gross, 0.04462 net,
  5.34 GF/s/W gross, 6.02 net. 16,000 dispatches/run.
- NPU (XDNA 2, single tile): 2,258.2 us/op, 118.9 GFLOP/s,
  22.1 W, 0.04985 J/op gross, 0.02980 net, 5.39 GF/s/W
  gross, 9.01 net. 4,096 dispatches/run.
Run-to-run J/op spread <= 6% on every path.

## Correctness (raw-oracle discipline)
- NPU: exact vs naive int64 CPU oracle, 131,072 elements,
  0 mismatches on verify + final after 4,118 submitted
  dispatches per run; checksum 2848816214485251074 ==
  A-095 banked value. Device evidence per run:
  device_name=NPU Strix Halo (live XRT handle),
  ert_cmd_state=4 (COMPLETED), xclbin uuid
  184c0a55-97ee-d107-bad0-060c59a9a278.
- GPU: fp32-exact for this input range (values in [-8,8],
  partial sums integers < 2^24) - proven, not assumed:
  0 mismatches, max_abs_err 0.000000 vs the int64 oracle,
  final window output re-verified; gpu_device_name=
  AMD Radeon 8060S Graphics (RADV STRIX_HALO) from
  VkPhysicalDeviceProperties.
- CPU: runner memcmp vs oracle exact every run.
- Model-level teacher-forcing parity: NOT APPLICABLE /
  not claimed (same basis as A-095: host-runner op,
  flag OFF in the shipping engine, bit-identical).

## Coordination + rules
- ps checked before every phase: the A-097 seat gate
  (aesir-forge run_all) was live at muster and FINISHED
  before any A-098 phase ran; no other suite or NPU
  probe live at any point. NPU via sudo -n only;
  RLIMIT_MEMLOCK never changed. Suite run solo after
  the power phases.
- No README.md touched. No merge, no push - the keeper
  banks at the seat in roadmap order after A-097.
- Bugs: none discovered in slice scope. Note for the
  road: the GPU perf-per-watt row strengthens the A-100
  placement-planner input table (measured optima now
  include energy, not just latency).

## Suite (E-MASTER, solo, this worktree)
- hidden_files/a098_run_all.log via hidden_files/run_a098_suite.sh (seat-gate shape, target gfx1151), run solo after the power phases (ps-verified: A-097 seat gate finished, no other suite): 607 passed / 1 failed / 2 skipped / 610 total - baseline-EXACT on 21044acf. Sole failure: pre-existing gguf.tensor_directory_interface (J-022). No named intermittent fired; no re-run needed.
- run_all cases: +0 (pin stays 610). This slice adds no engine code: measurement spikes + bench doc only, per the A-092/A-094/A-095 precedent for sudo/toolchain-bound work.
