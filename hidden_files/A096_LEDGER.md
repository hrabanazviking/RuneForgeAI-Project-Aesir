# A-096 Ledger - NPU prefill-assist experiment (team-26)

- Date: 2026-11-13 (EST, purpleraider local)
- Machine: purpleraider - ASUS ROG Flow Z13, AMD Ryzen AI
  Max+ 395, XDNA 2 NPU, Radeon 8060S gfx1151, XRT 2.25.
- Worktree: /home/volmarr/aesir-team-26, branch
  yrsa/aesir-team-26, base ee1aa0a3 (banked main, 94 of 216).
- Verdict: POSITIVE, measured. Overlap benefit 3,819-4,289 us
  median per mixed step (3 runs x 21 reps); overlapped wall
  (4,000-4,111 us) tracks GPU-alone instead of the serial
  wall (7,916-8,310 us). Full table: docs/bench/
  A096_NPU_PREFILL_ASSIST.md. Logs: hidden_files/a096/
  a096_run{1,2,3}.log.

## Method
- Harness spikes/a096_prefill_assist/overlap_probe.cpp:
  banked A-092 host-runner pattern (XRT, run.start() is the
  async launch; run.wait() collects) + Vulkan compute GEMV.
- NPU side: A-094 p128 xclbin+insts (copied from team-24
  hidden_files/a094/shapes/, untracked there as here;
  xclbin uuid 184c0a55-97ee-d107-bad0-060c59a9a278),
  128x1024x1024 i16->i32 prefill projection GEMM.
- GPU side: gemv.comp, 1024x1024 fp32 GEMV x64 reps per
  dispatch = decode-shaped previous-token work, RADV.
- Build: g++ -O2 -std=c++17 -I<team-22 scratch/a092/overlay>
  -I<team-22 scratch/a092> overlap_probe.cpp -o overlap_probe
  /usr/lib/x86_64-linux-gnu/libxrt_coreutil.so.2 -luuid
  -lpthread -lvulkan ; glslc gemv.comp -o gemv.spv
- Run: sudo -n ./overlap_probe final_p128.xclbin
  insts_p128.bin gemv.spv 64 (sudo for NPU memlock, A-007;
  limit never changed). NPU window checked clear of teams
  25/27 probes before each run.

## Evidence
- NPU exact vs CPU oracle all 3 runs: 131,072 elements,
  0 mismatches, 0 sentinels, ert_cmd_state=4, checksum
  2848816214485251074 (== team-25 A-095 p128 checksum).
- GPU GEMV max abs err 0.000035 vs CPU oracle, all runs;
  device named from VkPhysicalDevice properties.
- Raw-oracle note: correctness here is tensor-level exact
  (integer GEMM) / fp-tolerance (GEMV); no logit claims.

## Dependency / coordination
- A-095 NOT landed at run time (team-25 on 92-base, prep +
  measurements in flight, uncommitted). No duplication: this
  slice measured the concurrency premise only; registry
  offload remains A-095's. Re-check end-to-end when it banks.
- A-095 (team-25) is implementing the offload in parallel --
  coordinated per above; its landed pieces were not yet
  available, so preparatory + measurement work was done and
  the dependency filed honestly (this section).

## Suite
- E-MASTER on this worktree: see hidden_files/a096/
  a096_suite.log; counts appended to CAMPAIGN_STATE.md.
  Baseline 607/1/2 of 610 (J-022 sole failure).
