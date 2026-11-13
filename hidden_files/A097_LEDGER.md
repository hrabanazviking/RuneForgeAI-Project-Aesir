# A-097 Ledger - NPU sampler experiment (team-27)

- Date: 2026-11-13 (EST, purpleraider local)
- Machine: purpleraider - ASUS ROG Flow Z13, AMD Ryzen AI Max+ 395, XDNA 2 NPU, XRT 2.25.00
- Worktree: /home/volmarr/aesir-team-27, branch yrsa/aesir-team-27, base ee1aa0a3 (banked main, 94 of 216)
- Verdict: NOT FIT for single-token decode sampling - a measured no, filed at docs/bench/A097_NPU_SAMPLER.md. A measured no is a completed slice per the assignment.

## Acceptance mapping
- Verdict with numbers either way: docs/bench/A097_NPU_SAMPLER.md HEADLINE and section 1.
- Measurements are real device runs: 2 vocab sizes, each with a dedicated xclbin compiled on this machine from spikes/a097_npu_argmax/design_argmax.py (single AIE tile, IRON argmax over 8192-bf16 tiles, host merge in tile order), run via sudo -n through system XRT 2.25 (A-007 memlock caveat stands, limit never changed). Every run: device_name=NPU Strix Halo, ert_cmd_state=4 COMPLETED, exact vs CPU oracle incl. planted three-way tie (3.5 at idx 100, T+37, V-123) resolving to lowest index 100, 0 sentinels remaining. Logs hidden_files/a097/a097_run_v32k.log, a097_run_v128k.log and _run2 twins.
- Headline numbers (warm medians, 21 reps): V=32768 NPU argmax 104.8 us vs CPU bf16 19.9 us (run2 80.1 vs 19.2); V=131072 NPU 165.2 us vs CPU 76.7 us (run2 160.2 vs 74.7). CPU topk40+softmax medians 186.4 us / 887.2 us filed in doc for context.
- Host runner: spikes/a097_npu_argmax/npu_argmax_probe.cpp (sha256 822b7e78eb1a164c65081a933814bb0b26aa8226e8e6c7f927e988f23fe1c1b6); design sha256 3419026b2c1b4bf67cd3d0989440c17e213e5291fda039f77b1c85aaf9a9ba33.
- xclbin sha256 (scratch/a097, uncommitted binaries): v32k 90ad9e912dc8af9e1ea7e6d41f5f523aca074683843bbd5d33a7455fdf569943; v128k c738177995144668a134f50c9ac1b7b143e00407dcea6ccec87eb55985e37c33.
- Honest negative is the result: dispatch floor (~93 us, A-094) dominates at 32k; marginal scan rate does not beat CPU; no crossover for a single row on one tile. Fusion-only remains the only plausible NPU sampler path, unmeasured here.
- WIP recovery: previous lead cancelled before committing; this lead verified doc numbers against all four probe logs (exact match), verified suite log, and committed without re-running NPU probes or the suite (no seat gate was live at final check; ps clean).

## Suite (E-MASTER, solo, this worktree)
- hidden_files/a097_run_all.log via hidden_files/run_a097.sh (target gfx1151), finished 2026-11-13T14:30:55-05:00: 607 passed / 1 failed / 2 skipped / 610 total. Sole failure: pre-existing gguf.tensor_directory_interface (J-022). Exactly baseline - green-to-baseline.

## run_all cases
- This slice adds +0 run_all cases (doc + spike tooling only; probe needs sudo plus scratch toolchain, A-092 precedent). Pin stays 610.
