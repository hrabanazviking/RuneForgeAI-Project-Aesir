# A-029 Ledger - Mojo GPU target investigation (team-05)

Slice: A-029 (docs/AESIR_Z13_MASSIVE_ROADMAP.md, Wave 4). Acceptance:
a decision doc backed by compiled probes; the campaign kernel
strategy (Mojo-native, FFI SPIR-V/HIP, or hybrid) chosen from
evidence. Base: seat main 05f61cd6 (A-028; 28 of 216 banked).
Decision doc: docs/AESIR_Z13_MOJO_GPU_DECISION.md.

## Verdict (plain words)

Mojo-native GPU kernels DO compile for gfx1151 and DO execute on
the Radeon 8060S with the pinned toolchain (Mojo 1.0.0 / MAX
26.5.0), through MAX DeviceContext(api="hip") + enqueue_function.
A-027's NO-GO for Mojo-native claims is lifted for the probed
shapes. Strategy chosen: HYBRID, Mojo-native-first for new kernels
of proven shapes; FFI SPIR-V/HIP keeps its proven duties; unprobed
features (shared memory, barriers, subgroups, f16 perf, MAX graph
on HIP) stay unclaimed until probed.

## Environment

- purpleraider, 2026-11-12. Other-crew install logs: /tmp/toolstage*.log
  and /tmp/pkginstall.log absent this tick; no apt/dpkg/mojo processes
  were running at probe time (checked before starting).
- Pinned toolchain: Mojo 1.0.0 (ed45d567), MAX 26.5.0, pixi 0.76.2
  (pixi.toml: mojo >=1.0.0,<2; max >=26.5.0,<27).
- rocminfo GPU agent: gfx1151 / AMD Radeon 8060S Graphics;
  amdgcn-amd-amdhsa--gfx1151 present. HIP runtime 7.15.0
  (api_version 71500000 reported by MAX). Ubuntu ROCm 10.0 userland.
- HSA_OVERRIDE_GFX_VERSION: unset for every run (no masking).
- Bare Mojo 1.2.0 (2016d0cd) in the global pixi env has NO MAX
  package: building the probe there fails at parse - "unable to
  locate module 'gpu'" (std.gpu moved) and "unable to locate
  module 'max'". Not the roadmap's Mojo/MAX 26.x; no claim made
  (a029_mojo12.log).

## Probes (sources in spikes/a029_mojo_gpu_target/)

1. vec_add_probe.mojo, build --target-accelerator gfx1151: BUILD_EXIT=0
   (a029_build_gfx1151.log). Run: has_accelerator True,
   hip_device_count 1, device_name "AMD Radeon 8060S Graphics",
   api_version 71500000, mismatches 0, VECADD_PASS 1048576,
   RUN_EXIT=0 (a029_run_vecadd_gfx1151.log). Output buffer was
   sentinel-prefilled (-9999) so a no-op kernel cannot pass.
   Binary strings: kernel embedded under triple amdgcn-amd-amdhsa,
   arch = "gfx1151", stdlib_plugin = "hip" (same log).
2. No-flag build (auto-detect): builds, embeds arch gfx1151, run
   VECADD_PASS (a029_build_variants.log, a029_run_variants.log).
3. gfx942 build (wrong arch): builds; run FAILS at kernel launch -
   hipErrorNoBinaryForGpu (no kernel image is available for
   execution on the device), EXIT=1 (a029_run_variants.log).
4. Hidden-device controls on the gfx1151 binary: HIP_VISIBLE_
   DEVICES= / ROCR_VISIBLE_DEVICES= / HIP_VISIBLE_DEVICES=-1 all
   give hip_device_count 0 + hipErrorNoDevice raise, EXIT=1
   (a029_controls_hidden_device.log). No silent CPU fallback.
5. gemm_probe.mojo (engine shape: one output cell per thread,
   K-loop, B as [N,K] - the core/cuda_compute.mojo shape), f32
   128x128x128: GEMM_PASS, 16384 exact / 16384, max_abs_diff 0.0 -
   bit-exact vs the in-program CPU oracle (a029_gemm.log).
6. Spin mode (100 launches x 1,048,576 threads x 200,000 FMA):
   SPIN_DONE, 15.80 s wall (a029_spin_run.log). Sampler:
   /sys/class/drm/card*/device/gpu_busy_percent every 0.25 s -
   idle 0% before the run; during: 61 samples, min 0, median 99,
   p90 100, max 100; 50/61 samples >= 50% (a029_spin_samples.csv).
7. rocprof/rocprofv3: not installed on this machine (no binary in
   /usr/bin or /opt/rocm/bin) - profiler dispatch trace therefore
   not filed; legs 1+3+4+6 carry the execution proof instead.

## Engine surface added

- aesir_engine/core/mojo_gpu_target.mojo - MojoNative gateway
  (vec_add + gemm launchers, present/absent discipline per
  A-011/A-019; scope limits stated in the module header).
- aesir_engine/tests/test_mojo_gpu_target.mojo - 3 cases:
  gpu.mojo_native_vec_add_oracle (65,537 lanes, bounds guard),
  gpu.mojo_native_gemm_oracle (64^3, bit-exact),
  gpu.mojo_native_rejection (shape errors raise; device 99 never
  yields a context). run_all pin 359 -> 362.
- run_all.mojo header note + scripts/build_matrix.sh comment:
  the A-028-era sentence "the suite executes on CPU" corrected -
  host code is CPU; the gpu.mojo_native_* cases execute on the
  GPU when a HIP device is present.

## Suite

Seat-gate shape (hidden_files/run_a029.sh; all 6 shims incl.
libaesir_aff, --target-accelerator gfx1151): RESULT
359 passed / 1 failed / 2 skipped / 362 total
(hidden_files/a029_run_all.log) = baseline 356/1/2/359 + the 3
new gpu.mojo_native_* cases, all CASE PASS; sole failure the
pre-existing gguf.tensor_directory_interface J-022 drift; skips
the 2 pre-declared. No rotating-flake extra failure appeared,
so no re-run was needed.

## Bugs found / fixed

- No engine bug found. One stale-doc defect fixed in-slice: the
  A-028 "suite executes on CPU, no accelerator execution claimed"
  wording in run_all.mojo and scripts/build_matrix.sh became
  false the moment the mojo_native cases landed; corrected in
  both places (see above).
- Known non-blocking noise in every probe run, pre-existing MAX
  runtime behaviour, recorded so it is never mistaken for an
  A-029 defect: "Secondary CUID not available: AMDCUID support
  not enabled" at context creation and "Resource leak detected
  by SharedSignalPool, 89 Signals leaked" at exit. Exit codes
  are 0 and results are oracle-verified in spite of both.

## Unprobed / roaded (recorded in the decision doc + CAMPAIGN_STATE)

- Shared-memory tiling, barriers, subgroup ops from Mojo on
  gfx1151 - first Part III slice needing them probes first.
- f16/bf16 Mojo-native kernel correctness + all kernel perf.
- MAX graph execution on the HIP device.
- Mojo 1.2.0 + its MAX pairing (bare install lacks MAX).
