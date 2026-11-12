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

## Lessons carried in (standing law for this campaign)

- Raw-oracle discipline; near-tie band rank ≤2 + sub-logit gap = faithful;
  IQ graded on coherence, never token-exactness (AGENTS.md Aesir Part II).
- Comparator artifacts (template/BOS/backend/boundary) are checked before
  the engine is suspected.
- Scalar decode is the cost; decode is the lever.
- Accelerator-visible ≠ accelerator-run; a run at minimal device memory is
  a CPU run and is recorded as one.
- Bank incrementally; verify the push moved the remote, every time.
