# Project Aesir - Z13 Mojo GPU Target Decision (A-029)

Question (roadmap A-029): what can Mojo/MAX 26.x target on gfx1151 -
native GPU kernels, or FFI-only? A-027 (Part I gate) recorded NO-GO for
Mojo-native GPU kernel claims until this slice's compiled probes decide.
This doc is that decision, backed by compiled probes run on purpleraider
(ASUS ROG Flow Z13, Ryzen AI Max+ 395 / Radeon 8060S gfx1151, 128 GB
unified LPDDR5X) on 2026-11-12. Full raw evidence: hidden_files/
A029_LEDGER.md and hidden_files/a029/*.log in the campaign seat /
team-05 worktree.

## Verdict

GO - Mojo-native GPU kernels on gfx1151 are real with the pinned
toolchain. The campaign kernel strategy is HYBRID, Mojo-native-first:

1. New Z13 GPU kernels of the proven shapes (elementwise; GEMM with
   one output cell per thread; f32) are written Mojo-native through
   MAX DeviceContext(api="hip") + enqueue_function. The A-027 NO-GO
   for Mojo-native claims is lifted by the evidence below.
2. The proven FFI roads keep their existing duties and are not
   displaced: Vulkan SPIR-V dispatch (A-015) where Vulkan interop is
   the point, HIP/HIPRTC (A-008/A-019/A-021) inside the zero-copy
   memory architecture, XRT for NPU buffer objects (A-016).
3. Anything outside the proven shapes - shared-memory tiling,
   barriers, subgroup/warp ops, f16 kernel performance, MAX graph
   execution on HIP - is UNPROVEN by this slice. The first Part III
   slice that needs one of them probes it first, with the same
   triangulation discipline, before any claim is made.

## Environment (pinned, from hidden_files/a029/a029_env.log)

- Toolchain under test: the campaign's pinned pixi env - Mojo 1.0.0
  (ed45d567), MAX 26.5.0, pixi 0.76.2. Every suite/build command in
  this campaign runs this toolchain (pixi run --frozen).
- ROCm userland: Ubuntu ROCm 10.0 packages (A-005); HIP runtime
  7.15.0 (api_version 71500000 as reported by MAX itself).
- rocminfo: GPU agent Name gfx1151, Marketing Name AMD Radeon 8060S
  Graphics; HSA_OVERRIDE_GFX_VERSION was NOT set for any probe run.
- Vendor position (corroboration only, retrieved 2026-11-12 during
  this investigation): Modular's MAX hardware-compatibility list
  names gfx1151 as a supported target. The verdict below rests on
  the on-device probes, not on the list.
- A second, bare Mojo 1.2.0 (2016d0cd) exists in the global pixi env
  on this machine. It has no MAX package installed (max.gpu.host is
  not importable there) and cannot express this probe at all; it is
  not the roadmap's "Mojo/MAX 26.x" and no claim is made about it.

## Probes (all compiled from spikes/a029_mojo_gpu_target/)

| Probe | Build | Result |
|---|---|---|
| vec_add, 1,048,576 f32 lanes, sentinel-prefilled output | mojo build --target-accelerator gfx1151 | VECADD_PASS, 0 mismatches vs CPU oracle (a029_run_vecadd_gfx1151.log) |
| vec_add, no-flag build | mojo build (auto-detect) | PASS; binary embeds arch gfx1151 - the compiler auto-detects amdgpu:gfx1151 on this host (a029_run_variants.log) |
| GEMM 128x128x128 f32, engine kernel shape (one cell/thread, K-loop; the shape of core/cuda_compute.mojo) | --target-accelerator gfx1151 | GEMM_PASS, 16,384/16,384 cells BIT-EXACT vs the CPU oracle, max_abs_diff 0.0 (a029_gemm.log) |
| Spin kernel (compute-bound, 100 launches x 1M threads x 200k FMA) | --target-accelerator gfx1151 | SPIN_DONE in 15.8 s wall; /sys/class/drm gpu_busy_percent: idle 0% before, median 99% / p90 100% / max 100% during (a029_spin_run.log, a029_spin_samples.csv) |
| vec_add built for gfx942 (wrong arch), run on gfx1151 | --target-accelerator gfx942 | FAILS at launch: hipErrorNoBinaryForGpu (no kernel image is available for execution on the device), exit 1 (a029_run_variants.log) |
| vec_add gfx1151 binary, GPU hidden | HIP_VISIBLE_DEVICES= , ROCR_VISIBLE_DEVICES= , HIP_VISIBLE_DEVICES=-1 | All three: hip_device_count 0, DeviceContext raises hipErrorNoDevice, exit 1 (a029_controls_hidden_device.log) |

## Why this is device execution, not visibility or fallback

Unified memory makes a correct result alone worthless as evidence -
a silent CPU fallback would also be byte-exact. Four independent
legs, any one of which a CPU fallback fails:

1. Code object: the gfx1151 binary embeds the kernel under the
   target triple amdgcn-amd-amdhsa with arch = "gfx1151" and
   stdlib_plugin = "hip" (strings in a029_run_vecadd_gfx1151.log).
2. Arch specificity: the gfx942 build of the identical source is
   rejected by the device at launch (hipErrorNoBinaryForGpu). A CPU
   path cannot distinguish gfx942 from gfx1151 binaries.
3. No-device = no-run: hiding the GPU from HIP/ROCm turns the pass
   into a hard hipErrorNoDevice failure. There is no fallback path
   in DeviceContext/enqueue_function to fall back to.
4. Device activity: the spin kernel saturates the GPU (gpu_busy_
   percent median 99%) for its full duration while producing its
   result - work a CPU fallback would have done on CPU cores with
   the GPU idle.

Correctness then carries its usual weight on top: both oracle
probes are byte-exact against the CPU oracle computed in the same
operation order (raw-oracle discipline; the GEMM is bit-exact, not
merely within tolerance).

## What this does NOT prove

- Shared-memory (LDS) tiling, barrier synchronisation, subgroup /
  warp-shuffle ops on gfx1151 from Mojo: not probed. (The engine's
  current GPU kernel shapes do not use them; Part III tiling work
  must probe first.)
- f16 / bf16 Mojo-native kernel correctness or ANY kernel
  performance: A-029 decides targetability, not speed. Performance
  claims wait for the Part III measurement slices against the
  A-030 CPU baseline and the A-081 bar.
- MAX graph / model execution on the HIP device: not probed. The
  DeviceContext kernel path proven here is the MAX runtime's Mojo
  path; graph execution is a separate surface.
- Mojo 1.2.0 / future MAX pairings: the bare 1.2.0 install on this
  machine lacks MAX entirely (see Environment). Re-probe when the
  campaign's pinned toolchain moves.
- NPU: untouched by this slice; the A-027 NO-GO for NPU kernel work
  stands (road A-092).

## Standing rules this decision sets for Part III

1. Kernel claims on the Z13 require the triangulation pattern:
   arch-correct code object + wrong-arch or hidden-device control +
   device-activity or profiler evidence + byte-exact CPU-oracle
   comparison. Presence is never execution (the A-027 rule, now
   with a worked example).
2. Mojo-native is the default authoring road for new gfx1151
   kernels of proven shapes; FFI SPIR-V/HIP remains the road where
   its existing, proven duties lie (A-015/A-019/A-021 surfaces).
3. The in-suite pin: tests/test_mojo_gpu_target.mojo re-runs the
   vec_add + GEMM oracles through core/mojo_gpu_target.mojo on
   every E-MASTER run on this machine (run_all pin 359 -> 362), so
   a future toolchain move that breaks Mojo-native targeting fails
   the suite instead of failing silently.

## Reproduce

From the repo root on purpleraider (pinned pixi env):

    pixi run --frozen mojo build --target-accelerator gfx1151 spikes/a029_mojo_gpu_target/vec_add_probe.mojo -o /tmp/vec_add_probe
    /tmp/vec_add_probe            # expect VECADD_PASS 1048576
    HIP_VISIBLE_DEVICES= /tmp/vec_add_probe   # expect hipErrorNoDevice, exit 1
    pixi run --frozen mojo build --target-accelerator gfx1151 spikes/a029_mojo_gpu_target/gemm_probe.mojo -o /tmp/gemm_probe
    /tmp/gemm_probe               # expect GEMM_PASS, max_abs_diff 0.0
