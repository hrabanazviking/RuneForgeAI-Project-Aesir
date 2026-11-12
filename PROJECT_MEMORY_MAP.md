# Project Memory Map — Aesir Z13 (Strix Halo) Campaign

Living map for the AMD/Strix Halo campaign on purpleraider. Updated in the
same session as any work it describes. (Mirrored from the campaign seat:
purpleraider `~/aesir-forge`.)

## The map

- **What:** Make Project Aesir work best / fastest / most robust / most
  efficient / most complete on the ASUS ROG Flow Z13 (purpleraider).
- **Roadmap:** `docs/AESIR_Z13_MASSIVE_ROADMAP.md` — 216 slices A-001…A-216,
  24 waves of 9, 9 parts: I Ground Truth & Bring-Up · II Engine Core ·
  III GPU via Vulkan · IV HIP & NPU · V Correctness · VI Performance ·
  VII Robustness · VIII Completeness · IX Packaging & Final Proving.
- **Standalone:** this is the AMD hardware roadmap only. The Hailo-10 line
  is a separate thread and is untouched by this campaign. Text generation
  on the Hailo chip was never achieved and is never claimed here.
- **Hardware truth (2026-11-11):** Zen 5 16c/32t · Radeon 8060S gfx1151 ·
  XDNA 2 NPU (`/dev/accel/accel0`, amdxdna healthy) · 128 GB unified LPDDR5X ·
  `/dev/kfd` present · RADV Vulkan present · ROCm userland absent ·
  XRT userland absent · Kubuntu 26.10, kernel 7.3.
- **Repo baseline (2026-11-11):** main @ 00a66e35 (roadmap commit) on top of
  d9f88b9a; 1,020 tracked files; engine `aesir_engine/` (Mojo + MAX, pixi);
  E-MASTER suite 250 named cases; `core/amd_gate.mojo` is a dlopen probe
  only — no AMD compute path exists yet.
- **Campaign seat:** purpleraider `~/aesir-forge` (main) + `~/aesir-team-01…09`.
- **Keeper:** `aesir-z13-forge-keeper`, 10-minute, goal
  `aesir-z13-strix-halo-forge`. Reports only at wave-of-9 completion,
  roadmap completion, or a genuine blocker.

## Slice ledger

| Slice | Status | Evidence / commit |
|---|---|---|
| — | Campaign stood up 2026-11-11; roadmap filed at 00a66e35 | ls-remote verified |
| A-001 | merged at seat, push blocked | e33b6f0d hardware census in doctor; suite 283/1/2 of 286; the 1 failure is pre-existing (gguf.tensor_directory_interface, J-022 drift; same failure as the A-003 baseline) |
| A-002 | merged at seat, push blocked | f3b1f23b pixi env + CPU build on Z13; BUILD_EXIT=0, --help smoke exit 0; ledger hidden_files/A002_LEDGER.md |
| A-003 | committed at seat, push blocked | E-MASTER baseline 277/1/2 of 280 at ba0cf066; evidence hidden_files/a003_baseline_summary.md (canonical log stays in team-03 worktree, sha256 in summary) |
| A-004 | banked at seat, push blocked | E-REAL exact oracle pass on Z13 CPU; fixture sha256 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3 pinned before run; tokenizer/first-token/32 greedy IDs exact; suite 277/1/2 of 280 = baseline; team-04 branch commit b0b33927 (state-file only, not merged - banking follows the A-003 evidence pattern); evidence hidden_files/A004_LEDGER.md |
| A-005 | banked at seat, push blocked | ROCm userland native (Ubuntu ROCm 10.0): rocminfo 10.0-0ubuntu2 + libamdhip64-dev 10.0-0ubuntu3; rocminfo Agent 2 = gfx1151 Radeon 8060S (aie2p NPU also enumerated); AMDGate probe LOADABLE, gpu.amd_gate_availability PASS (was UNAVAILABLE at base); suite 277/1/2 of 280 = baseline; evidence-only slice, evidence hidden_files/A005_LEDGER.md |
| A-006 | banked | Vulkan compute readiness: raw C probe PASS on AMD Radeon 8060S (RADV STRIX_HALO, vendor 0x1002 dev 0x1586, Vulkan 1.4.354, compute queue family 0 flags 0xf; llvmpipe explicitly rejected); SPIR-V toolchain native (glslangValidator 16.4.0, spirv-tools 2026.3) - trivial compute module compiled, spirv-val OK, vkCreateShaderModule rc=0 on RADV; suite 277/1/2 of 280 = baseline (sole failure pre-existing J-022 drift); team-06 commit 2af3a50b cherry-picked; evidence hidden_files/A006_LEDGER.md |
| A-007 | banked | XRT userland bring-up: Ubuntu 26.10 native XRT 2.25.0 NPU packages (libxrt-npu2 + libxrt-utils-npu, APT_EXIT=0, no DKMS, in-tree amdxdna reused); xrt-smi examine (xbutil successor) reports [0000:c5:00.1] NPU Strix Halo, aie2p 6x8, firmware 1.1.2.65; suite 277/1/2 of 280 = baseline (one earlier contention flake re-ran clean); caveat: unprivileged xrt-smi blocked by RLIMIT_MEMLOCK 8192 kB - sudo meanwhile, limit raise is Volmarr decision; team-07 commit db9f51d7 cherry-picked (state file excluded per banking pattern); evidence hidden_files/A007_LEDGER.md |
| A-008 | banked | Unified-memory semantics probe (spikes/a008_unified_memory/): HIP managed + Vulkan coherent probes with REAL device execution on Radeon 8060S gfx1151 (HIPRTC kernels checksum-verified on host; RADV STRIX_HALO selected, llvmpipe refused); 256 MiB rows: managed GPU fill 231.58 GB/s, pinned zero-copy GPU read 190.96 GB/s, pinned H2D 83.01 GB/s; suite 277/1/2 of 280 = baseline (sole failure pre-existing J-022 drift); team-08 commit 88b9aacf cherry-picked; evidence hidden_files/A008_LEDGER.md |
| A-009 | banked | Backend registry skeleton: core/backend_registry.mojo (typed HIP/Vulkan/XRT/CPU present/absent/degraded + version/device, injectable probe, pure parsers) surfaced in doctor text + JSON (backends object unioned with A-001 census at banking); live doctor on purpleraider: HIP 7.15.0 / AMD Radeon 8060S Graphics, Vulkan 1.4.354 RADV STRIX_HALO, XRT 2.25.0 presence-only via /dev/accel/accel0 (no NPU execution claimed), CPU AMD RYZEN AI MAX+ 395; suite 281/1/2 of 284 in team worktree (+4 cases); seat run_all pin unioned to 290; team-09 commit 1222a383 cherry-picked; evidence hidden_files/A009_LEDGER.md |
| A-010 | banked | HIP device gate: AMDGate reworked onto MAX DeviceContext(api=hip) (dlopen declaration conflict with sibling gates ruled out OwnedDLHandle); exactly one gfx1151 device - AMD Radeon 8060S Graphics, wavefront 32, 20 multiprocessors, runtime 71500000, cross-checked against direct hipGetDeviceProperties calls; soname fix: libamdhip64.so.7 tried FIRST (unversioned name never resolves on Ubuntu); gfx target + memory clock/bus from A-001 KFD census parsers; suite 285/1/2 of 288 in team worktree (+2 cases); seat run_all pin unioned to 292; team-01 commit 7bed5e27 cherry-picked; evidence hidden_files/run_a010.sh + team-01 hidden_files logs (no separate ledger filed) |
| A-011 | banked | HIP memory: core/hip_memory.mojo + hip_memory_shim.c (staged as libaesir_hip) over distro libamdhip64.so.7 - REAL device execution: hipMalloc/hipMallocManaged round trips byte-exact, zero leaked bytes across 1,000 iterations (one-time 148,971,520 B HIP context reserve accounted, not a leak); AMDGate soname probe bug found in-slice - its amd_gate hunk was subsumed at banking by A-010's versioned-first probe (see ledger banking note); suite 282/1/2 of 285 in team worktree (+5 cases); seat run_all pin unioned to 297; team-02 commit 83c9fdf9 cherry-picked; evidence hidden_files/A011_LEDGER.md |
| A-012 | banked | HIP transfer + streams: core/hip_transfer.mojo + hip_memory_shim.c extended (streams/events/memcpy-async/host-pinned, hipStreamNonBlocking, aesir_hip_transfer_available) - REAL device execution on Radeon 8060S: byte-exact H2D/D2H round trips vs CPU oracle, async overlap smoke, event timing filed; built on A-011 exactly as authored (banking took only 67aca2d0's own diff; team-03's cherry-pick twin fab684da of A-011 was NOT re-banked); suite 287/1/2 of 290 in team worktree (+5 cases); seat run_all pin unioned to 302; team-03 commit 67aca2d0 cherry-picked; evidence hidden_files/A012_LEDGER.md |
| A-013 | banked | Vulkan context wrapper: core/vulkan_context.mojo + vulkan_context_shim.c (staged as libaesir_vulkan) - REAL device execution: instance/device/queue/command-pool + vkDeviceWaitIdle on AMD Radeon 8060S Graphics (RADV STRIX_HALO), vendor 0x1002 dev 0x1586, Vulkan 1.4.354, queue family 0; llvmpipe enumerated but never selected (create case asserts RADV identity); forced failures at all 4 bring-up stages map to the error taxonomy, never crashes; suite 281/1/2 of 284 in team worktree (+4 cases); seat run_all pin unioned to 306, canonical header unioned (HIP + Vulkan staging); CAMPAIGN_STATE.md excluded from the seat commit per banking pattern; team-04 commit c72705e1 cherry-picked; evidence hidden_files/A013_LEDGER.md |
| A-014 | banked | Vulkan buffers: core/vulkan_buffers.mojo + vulkan_buffer_shim.c - REAL device execution on RADV STRIX_HALO (vendor 0x1002 dev 0x1586, Vulkan 1.4.354): host-visible coherent mapped buffers, byte-exact write/read oracle, alignment from device-read limits, live-byte accounting; BANKING CONVERGENCE: A-013/A-014 did NOT coexist as authored - both shims exported aesir_vk_available and aesir_vk_device_info, the latter with incompatible ABIs, under one libaesir_vulkan.so name; A-014's two symbols renamed aesir_vk_buffer_available / aesir_vk_buffer_device_info (definitions + 3 call sites, no logic rewritten) and the seat gate stages one merged libaesir_vulkan.so from both shims (nm-verified disjoint union); suite 281/1/2 of 284 in team worktree (+4 cases); seat run_all pin unioned to 310; team-05 commit 8ec21143 cherry-picked; evidence hidden_files/A014_LEDGER.md (incl. banking note) |

## Lessons carried in (standing law for this campaign)

- Raw-oracle discipline; near-tie band rank ≤2 + sub-logit gap = faithful;
  IQ graded on coherence, never token-exactness (AGENTS.md Aesir Part II).
- Comparator artifacts (template/BOS/backend/boundary) are checked before
  the engine is suspected.
- Scalar decode is the cost; decode is the lever.
- Accelerator-visible ≠ accelerator-run; a run at minimal device memory is
  a CPU run and is recorded as one.
- Bank incrementally; verify the push moved the remote, every time.
