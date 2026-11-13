# A-082 Ledger - HIP Q8_0 GEMV (team-12)

- Base: 3cfc4370 (banked main, 78 of 216; A-078 banking
  closure). Worktree /home/volmarr/aesir-team-12, branch
  yrsa/aesir-team-12. Mustered 2026-11-13 ~06:47 EST.
- Slice: A-082 - HIP Q8_0 GEMV, via the A-010-A-012 gate.
  Acceptance: CPU-oracle parity + device-execution evidence.
  OUTCOME: PASS - parity BIT-EXACT and device execution
  evidenced on the real gfx1151 device (details below).
  Banking order note: A-079/A-080/A-081 bank ahead of this
  slice in roadmap order; expect a run_all pin union at
  banking (this branch pin 568 -> 573).

## Deliverables
- aesir_engine/core/hip_gemv.mojo (new): HipGemv gateway +
  Mojo-native HIP kernel (_hip_q8_gemv_kernel). Gate =
  HipMemory runtime probe (A-011) + HipMemory.device_count()
  == 1 + AMDGate.get_device_properties(0) plausible with
  gfx_arch == gfx1151 (A-010); wrong-device identities are
  refused before any launch. Kernel launched through MAX
  DeviceContext(api="hip") (A-029 road), one thread per
  output row, Float32 accumulation in sequential k order
  (A-075 law); fp16 scale decode + int8 extraction in-kernel
  over the raw GGUF Q8_0 bytes (34-byte blocks); nothing is
  dequantized on the host. q8_0_gemv_repeated() reuses ONE
  context with operands uploaded once (weight-resident
  decode shape) after the bench measured a ~13-16 ms
  per-call DeviceContext creation floor.
- aesir_engine/hip_memory_shim.c: A-082 dispatch-evidence
  counter appended (aesir_hip_note_q8_gemv_dispatch /
  aesir_hip_q8_gemv_dispatch_count). The gateway notes a
  dispatch only after launch + readback + synchronize
  completed without raising, so the counter counts exactly
  the GEMV dispatches that completed on the device (law 6).
- aesir_engine/tests/test_hip_q8_gemv_a082.mojo (new):
  5 cases, gpu.hip_q8_gemv_*.
- aesir_engine/tests/bench_hip_q8_gemv_a082.mojo (new):
  standalone bench/probe driver (gate identity, parity spot
  checks, HIP single-call vs resident-loop vs CPU timings).
- aesir_engine/tests/probe_hip_q8_gemv_a082.mojo (new):
  standalone runner for the 5 suite cases.
- aesir_engine/tests/run_all.mojo: 5 cases registered after
  the gpu.mojo_native_* cases; pin 568 -> 573.
- docs/bench/A082_HIP_Q8_GEMV.md: filed verdicts + bench.

## Device evidence (purpleraider, this slice)
- Gate (bench log): hip_runtime_available=True,
  hip_device_count=1, device_name="AMD Radeon 8060S
  Graphics", gfx_arch=gfx1151, plausible=True, gate_ok=True.
  Mojo DeviceContext name agrees: "AMD Radeon 8060S
  Graphics". No llvmpipe/host-fallback identity is possible
  in this path (HIP has no software device here; a hidden
  device raises hipErrorNoDevice upstream, A-029 evidence).
- Dispatch counter: bench run recorded 123 completed
  dispatches (3 shapes x (1 parity + 20 single + 20
  resident-loop) - exactly the dispatches performed);
  suite case asserts +2 for 2 dispatches: PASS.
- Logs: hidden_files/a082_bench.log (bench),
  hidden_files/a082_probe.log (5 cases standalone, all
  PASS, A082_PROBE_ALL_PASS), a082_run_all.log (suite).

## Parity verdicts (raw-oracle discipline)
- Sequential F32 CPU oracle over the identical raw Q8_0
  bytes, 6 shapes (1,32) (4,64) (16,288) (37,320) (64,1024)
  (13,4096): max_abs = 0.0 at EVERY shape - bit-exact (the
  kernel accumulates in the same k order as the oracle;
  filed bound 1e-3 carried from A-056's tree-reduction
  Vulkan kernel, kept as headroom). Verdict class: faithful
  (stronger than the near-tie band; no comparator artifact
  involved - CPU vs CPU-oracle maths on identical bytes).
- Engine cross-check (gemm_q8_0 A-038 route, dyadic K=1024
  N=96): PASS within half an F16 ULP of the engine F16
  output at every output (engine rounding distance =
  comparator-artifact bound, as A-056).
- Known value (scale 0.25, q=i-16, x=1): -4 exact.
- Rejection (zero rows / cols=48 / oversize operand /
  short activation list): PASS, all raised pre-device.

## Bench (filed in docs/bench/A082_HIP_Q8_GEMV.md)
- (512,4096): HIP per-call 16.93 ms (0.12 GiB/s);
  resident-loop 1.02 ms (2.03 GiB/s); CPU sequential
  1.65 ms (1.26 GiB/s). HIP wins at the large decode
  shape in the resident shape.
- (64,1024): per-call 13.41 ms; resident 0.71 ms
  (0.09 GiB/s); CPU 0.056 ms (1.17 GiB/s).
- (37,320): per-call 13.22 ms; resident 0.66 ms
  (0.018 GiB/s); CPU 0.0098 ms (1.20 GiB/s).
- Honest readings: per-call cost is DeviceContext creation
  (~13-16 ms flat), NOT kernel cost; small shapes are
  launch+sync+readback latency-bound (~0.66-0.71 ms floor)
  and lose to the CPU oracle. Kernel-shape headroom (one
  thread per row, uncoalesced reads; no shared-memory /
  wavefront reduction - shapes A-029 did not probe) is
  A-085 bake-off territory, recorded as next work below.

## Suite (counts READ FROM LOG)
- First staging attempt failed at JIT with "Symbols not
  found: [aesir_aff_read, aesir_aff_apply]" - my runner
  omitted the affinity shim that scripts/build_matrix.sh
  stages (libaesir_aff). Staging fixed in-slice (runner
  scripts in hidden_files now match build_matrix.sh);
  failed attempt preserved as a082_run_all_buildfail.log.
  This was a harness omission, not a code failure; the
  run_all.mojo header command is stale on the same point
  (it also omits libaesir_aff) - recorded for the keeper.
- Full suite (hidden_files/a082_run_all.log): 570 passed /
  1 failed / 2 skipped / 573 total. Sole failure the
  pre-existing gguf.tensor_directory_interface (J-022
  drift, tolerated). Skips the 2 pre-declared. All 5 new
  gpu.hip_q8_gemv_* cases PASS. Baseline at 3cfc4370 was
  565/1/2/568; 568 + 5 = 573, exact.
- The known pre-existing flake memory.budget_live_
  meminfo_pressure PASSED in this run (no contention: no
  other Aesir suite live; the MimirAlloc Z-100 soak probes
  remained frozen STAT T throughout; the run was launched
  detached after the device invoke 125 s cap cut the first
  foreground attempt - the detached run is the one filed).
- Exit noise: "Resource leak detected by SharedSignalPool"
  warnings appear at process exit in the bench/probe logs
  (MAX/HSA teardown noise, exit code 0, after all results
  printed); also present in the suite log tail. Not a case
  failure; recorded here so it is never mistaken for one.

## Bugs / next work
- No bug discovered in the HIP GEMV path itself.
- Recorded for banking/keeper: run_all.mojo's header
  command omits libaesir_aff staging (the canonical
  staging lives in scripts/build_matrix.sh) - a fresh
  reader following the header literally hits the JIT
  symbol failure above. Doc-drift class; fix belongs to
  whichever slice next touches the header.
- A-085 bake-off inputs (filed, not claimed here): HIP
  resident-loop 2.03 GiB/s at (512,4096) vs Vulkan Q8_0
  GEMV (A-056) numbers; small-shape HIP latency floor
  ~0.66 ms; tiled/shared-memory HIP kernel shapes remain
  unprobed (A-029 scope) - the bake-off should probe them
  before judging the HIP road's ceiling.
