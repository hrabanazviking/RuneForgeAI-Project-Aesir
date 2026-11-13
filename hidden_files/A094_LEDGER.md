# A-094 Ledger - NPU-shaped ops analysis (team-24)

- Date: 2026-11-13 (EST, purpleraider local)
- Machine: purpleraider - ASUS ROG Flow Z13, AMD Ryzen AI Max+ 395, XDNA 2 NPU, XRT 2.25.00
- Worktree: /home/volmarr/aesir-team-24, branch yrsa/aesir-team-24, base e20ab964 (banked main, 92 of 216)
- Verdict: PASS - candidate table with measured crossover points filed at docs/bench/A094_NPU_SHAPED_OPS.md. A-095 recommendation: prefill projection GEMM.

## Acceptance mapping
- Candidate table with measured crossover points: docs/bench/A094_NPU_SHAPED_OPS.md section 2, built on the section 1 sweep.
- Measurements are real device runs: 7 shapes, each with a dedicated xclbin compiled on this machine from the banked A-092 single-core IRON design (tile 32, i16->i32, one AIE tile), run via sudo -n through system XRT 2.25 (A-007 memlock caveat stands, limit never changed). Every run: device_name=NPU Strix Halo from the live handle, ert_cmd_state=4 COMPLETED, exact vs CPU oracle (0 mismatches, 0 sentinels) on the verification run. Logs hidden_files/a094/a094_run_{32,64,128,256,512,p32,p128}.log; build logs a094_build_*.log.
- Headline numbers (warm medians, 21 reps): dispatch floor ~93 us (32^3); cubic crossover vs oracle CPU bracketed 32^3 (0.29x LOSE) to 64^3 (1.88x); 512^3 37.7x; projection proxies 32x1024x1024 103x, 128x1024x1024 99x (oracle-CPU caveat filed in the doc). 64^3 checksum 16383547698108786409 reproduces A-092 exactly.
- Timing host: spikes/a094_npu_timing/npu_timing_probe.cpp (sha256 7694da6e311e5440c7afcc805b4684fc7ad319d8838acafc4fa5033a5024fbd9), derived on-device from the A-092 runner (shape args + chrono timing); host build: g++ -O2 -std=c++17 with the A-092 overlay + XRT-2.25 includes, libxrt_coreutil.so.2, -luuid.
- xclbin sha256: 32: 4ebd74ca921c23cee96407070b163f250866fe8555ce7ef719ae56a6a3b8a139; 128: 565733187f9efed62fa3eb9798a0c697bd186386ead33617afd13afbe8e24ee3; 256: 957a756c7624e1af13c35648fb007a84d2095c7135de9769e3a9b2b47155f0d9; 512: f128047206c8440f0dc01754c5ec1cc4e1c8a9ae25f84f27e2c1537429a4f744; p32: f4fd1c38d216b9305ded63d3ba0aa4caf0b55bd5bbebd3d19a937abe080d3a67; p128: c72243c8efe0a5c33f300340bf1ed78d558625b76ccd976bc28273332936fe52. (64 shape = banked A-092 xclbin 83e47803..., per its ledger.) Binaries stay in hidden_files/a094/shapes (uncommitted scratch), hashes here.
- Honest negatives filed: 32^3 loses; decode M=1 not expressible (M % 32 == 0); norm/elementwise class unmeasured and fusion-only; vendor TOPS figures never used.
- Coordination: ps checked before every NPU run (no other NPU tool live); team-23 leads were stopped at check time, team-25 in prep. Full suite deferred while another team's gate was live (ps evidence), run solo after it cleared.

## Suite (E-MASTER, solo, this worktree)
- hidden_files/a094_run_all.log (run 4) via hidden_files/run_a094.sh (seat-gate shape, target gfx1151), solo: 606 passed / 2 failed / 2 skipped / 610 total. Failures: pre-existing gguf.tensor_directory_interface (J-022) + the named pre-existing intermittent resilience.state_vault_rejects_growth.
- Runs 1-3 (logs preserved as a094_run_all_run1..3.log) were identically 606/2/2: run 1 J-022 + named intermittent gpu.amd_hip_stream_async_round_trip; runs 2-3 J-022 + state_vault. Four solo runs, no unnamed failure ever, intermittents rotating exactly as at base - green-to-baseline per the CAMPAIGN_STATE rule (a suite showing only those plus J-022 is green-to-baseline). No baseline-exact 607/1/2 run landed in 4 attempts; filed honestly rather than run until lucky. This slice touches no engine code (doc + spike tooling only), so the intermittents cannot be slice-caused.

## run_all cases
- This slice adds +0 run_all cases (doc + spike tooling only; the probe needs sudo plus the scratch toolchain, A-092 precedent). Pin stays 610.
