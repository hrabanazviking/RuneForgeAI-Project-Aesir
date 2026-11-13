# A-095 PREP - NPU offload #1 (team-25) - PREPARATORY ONLY, awaiting A-094

- Date: 2026-11-13 (EST). Worktree /home/volmarr/aesir-team-25, branch
  yrsa/aesir-team-25, base e20ab964 (banked main, 92 of 216).
- Status at prep time: A-094 (team-24) NOT landed. Verified on-device:
  team-24 worktree still at e20ab964, its CAMPAIGN_STATE.md shows only
  MUSTERED status with no outcome appended, and no A094 ledger exists in
  team-24 hidden_files. Per the slice brief, NO candidate is picked here.
  This file is the review-ready prep; implementation starts only when
  A-094 files its candidate table with measured crossover points.

## 1. Registry integration shape (verified in this worktree)

- aesir_engine/core/mimir_well.mojo: struct NPUBackendType (line ~46) with
  comptime discriminants HAILO_10=0, QUALCOMM_HEXAGON=1, ARM_NEON=2,
  JETSON_NVIDIA=3, APPLE_NEURAL_ENGINE=4, GENERIC_NPU=5 (per
  aesir_engine/INTERFACE.md, Reserved NPU Backend Discriminants).
  NONE currently dispatches physical NPU work; all are config values.
  There is NO AMD XDNA discriminant yet. MimirWell holds npu_backends
  lists and require_npu_backend(backend) (line ~1835).
- aesir_engine/config.mojo: hardware.acceleration_backend already allows
  "npu" (allowed: auto/cpu/cuda/metal/intel/amd/npu/hailo10h/max/vulkan/
  hip). hardware.target_npu allows only auto/hailo10/hailo8/hexagon/ane/
  intel_npu/arm_neon - NO xDNA value yet.
- aesir_engine/aesir.mojo: AesirEngine is the sole configuration owner
  (GPU realm law in INTERFACE.md is the pattern to mirror for NPU):
  config state lives only in the facade, never in server/loader domains.
- Implementation shape when the table lands (no code written yet):
  1. Add NPUBackendType.AMD_XDNA = 6 in core/mimir_well.mojo + name map.
  2. Allow target_npu = "xdna" in config.mojo validation.
  3. Registry entry for the A-094 winning op only: dispatch keyed by
     (op, dtype, shape band from A-094 crossover table); every other
     shape/dtype falls back to the existing CPU path unchanged.
  4. Feature flag default OFF (config-gated, mirroring enable_gpu_realm
     law); enabling requires the parity gate in section 3 to pass.
  5. Dispatch logging: op, shape, backend chosen, fallback reason,
     device identity - so NPU-run is proven, never inferred.

## 2. Probe scaffolding (reuses banked A-092 recipe, A092_LEDGER.md)

- Proven pattern: aesir_engine/npu_matmul_probe.cpp - XRT C++ host
  runner: xrt::device(0), device name from live handle, xclbin uuid,
  hw_context by uuid, kernel "MLIR_AIE", BOs per group_id, output
  pre-filled with sentinel 0x7fffffff, run.wait() ert_cmd_state checked
  (4 = COMPLETED), exact compare vs in-program CPU oracle (int64 accum).
- A-092 proven instance: 64x64x64 i16->i32, one AIE tile 32x32x32,
  checksum 16383547698108786409, 3/3 PASS on XDNA 2 [0000:c5:00.1],
  aie2p 6x8, XRT 2.25.00, IRON/mlir-aie 1.4.5 + Peano (no Chess).
- Toolchain: /home/volmarr/aesir-team-22/scratch/a092 (mlir-aie wheel,
  llvm-aie/Peano, pydeps, XRT-2.25 branch headers; host links
  /usr/lib/x86_64-linux-gnu/libxrt_coreutil.so.2 directly).
- For A-095: generalize the probe ONLY after A-094 names the op/shape:
  parameterize M/K/N + dtype to the candidate, keep sentinel + exact
  oracle + device-name/uuid/ert evidence lines verbatim in structure.
- NPU runs via sudo -n only; RLIMIT_MEMLOCK caveat stands (8192 kB vs
  64 MiB) - limit NEVER changed. Coordinate sudo NPU use with teams
  23/24 (check their CAMPAIGN_STATE.md + ps) so probes never collide.
- Vendor xrt-smi validate figures (3.7 TOPS etc.) are DOCUMENTED vendor
  numbers, never Aesir benchmarks.

## 3. Parity + end-to-end measurement plan (raw-oracle discipline)

- Op-level: NPU result vs CPU oracle exact (integer ops) or within the
  A-094 table tolerance; sentinel + ert state + device name required.
- Model-level: teacher-forcing rank + logit gap on RAW prompts, CPU
  engine vs CPU comparator only; near-tie band rank <=2 with sub-logit
  gap = faithful; quantized ops graded on coherence, never token-exact.
- End-to-end: fixed raw-prompt set, NPU flag OFF vs ON, uncontended box
  (ps checked, no seat gate / no other suite): tokens/s, time-to-first-
  token, total latency, fallback rate from dispatch log.
- Verdict per acceptance: positive (faster + parity), neutral-with-value
  (parity + e.g. CPU offload/power value, numbers filed), or removed
  with numbers (dispatch entry reverted, measurements in the ledger).
  An honest neutral/removed verdict completes the slice.

## 4. Suite gate (when implementation lands)

- Solo full suite in this worktree only, never concurrent with a seat
  gate or other heavy work. Baseline on this base: 607 passed / 1 failed
  / 2 skipped / 610 total; sole failure pre-existing
  gguf.tensor_directory_interface (J-022). Named intermittents
  resilience.state_vault_rejects_growth,
  gpu.amd_hip_stream_async_round_trip,
  gguf.weight_residency_gpu_visibility: re-run once before treating
  any as new. Counts read from the log file, never memory.

## 5. Next action

- Poll team-24 CAMPAIGN_STATE.md outcome + hidden_files A094 ledger;
  when the candidate table lands, implement section 1 steps 1-5 for the
  winning candidate only, run sections 2-4, file A095_LEDGER.md, append
  outcome to CAMPAIGN_STATE.md, commit "A-095: NPU offload #1".
