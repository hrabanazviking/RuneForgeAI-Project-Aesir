# A-005 Ledger — ROCm userland, natively (team-05)

- Date: 2026-11-11 (EST, purpleraider local)
- Machine: purpleraider — AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 121 GiB
- OS: Ubuntu 26.10 (stonking), kernel 7.3.0-10-generic
- Worktree: /home/volmarr/aesir-team-05, branch yrsa/aesir-team-05, base ba0cf066
- Method: native Ubuntu packages only (apt). NO Docker. sudo -n worked non-interactively.

## Pre-install baseline (hidden_files/a005_preinstall_baseline.log)
- /opt/rocm absent; rocminfo and hipcc absent.
- libamdhip64-7 10.0-0ubuntu3 already installed: /usr/lib/x86_64-linux-gnu/libamdhip64.so.7 -> libamdhip64.so.7.15.0-0000000; dlopen of the versioned soname OK.
- Unversioned libamdhip64.so ABSENT: python3 ctypes CDLL('libamdhip64.so') -> OSError: cannot open shared object file.
- AMDGate probe at base (team-01 a001-run-all.log, same base): "AMD ROCm HIP: UNAVAILABLE on current host platform (Fail-Closed)".

## Install (hidden_files/a005_install.log, APT_EXIT=0)
Command: sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y rocminfo libamdhip64-dev
Newly installed (6, pinned Ubuntu ROCm 10.0 series for stonking):
- rocminfo 10.0-0ubuntu2
- libamdhip64-dev 10.0-0ubuntu3
- libamd-comgr-rocm-dev 10.0+dfsg-0ubuntu1 (dep)
- libhiprtc-builtins7 10.0-0ubuntu3 (dep)
- libhiprtc7 10.0-0ubuntu3 (dep)
- libhsa-runtime-dev 10.0+dfsg-0ubuntu2 (dep)
Pre-existing and pinned as the runtime base: libamdhip64-7 10.0-0ubuntu3, libhsa-runtime64-1 10.0+dfsg-0ubuntu2, libamd-comgr3-rocm 10.0+dfsg-0ubuntu1.
This is the smallest native set satisfying acceptance: the -dev package supplies the unversioned symlink + HIP headers; rocminfo supplies the agent probe. No full-stack ROCm install was used.

## Acceptance — all proven from filed logs
1. rocminfo reports a gfx1151 agent (hidden_files/a005_rocminfo.log, ROCMINFO_EXIT=0):
   Agent 2 — Name: gfx1151, Marketing Name: AMD Radeon 8060S Graphics, Vendor: AMD.
   (Agent 1 = CPU AMD RYZEN AI MAX+ 395; Agent 3 = aie2p NPU Strix Halo, also enumerated.)
2. libamdhip64.so (unversioned) loads (hidden_files/a005_versions.log):
   /usr/lib/x86_64-linux-gnu/libamdhip64.so -> libamdhip64.so.7 (from libamdhip64-dev);
   ldconfig -p resolves libamdhip64.so; ctypes CDLL('libamdhip64.so') OK.
   HIP headers present: /usr/include/hip/hip_runtime.h, hip_runtime_api.h.
3. AMDGate probe load (hidden_files/a005_run_all_canonical.log, E-MASTER run):
   "AMD HIP runtime library: LOADABLE; physical device count unverified"
   "AMDGate driver & runtime availability: PASS" / "[CASE PASS] gpu.amd_gate_availability"
   — flipped from UNAVAILABLE at base solely by this install; the probe code is untouched.
4. Versions filed: hidden_files/a005_versions.log + this ledger.

## Full suite (E-MASTER, canonical sm_89 compile-target, CPU execution)
- hidden_files/a005_run_all_canonical.log: Passed 277, Failed 1, Skipped 2, Total 280, MOJO_EXIT=1.
- Counts are IDENTICAL to the team-03 canonical baseline at the same base ba0cf066 (277/1/2/280): zero regressions from A-005.
- The 1 failure is PRE-EXISTING and unrelated to ROCm: gguf.tensor_directory_interface ("GGUF is missing required tensor: token_embd.weight") — the identical failure line appears in team-01 a001, team-02 a011 and team-03 a003 logs at this base. Recorded in CAMPAIGN_STATE.md as a known pre-existing failure for the keeper/owning slice; not caused by, and not fixable inside, A-005's install scope.
- The 2 skips are the suite's named opt-in cases: vision.cuda_session_image_chat (needs real Gemma 4 pair + CUDA device) and rag.real_engine_integration (needs validated external GGUF fixture).

## hipcc note (deliberate)
hipcc was NOT installed: it is not part of A-005 acceptance, and Ubuntu's candidate hipcc 7.2.4+dfsg-1~exp1 is an experimental lineage mismatched with the pinned ROCm 10.0 userland. Smallest-set rule applied. If a later HIP-compile slice needs a compiler driver, revisit there (and at A-087 reproducibility).

## Repo changes
None tracked. Install/evidence-only slice (same pattern as team-03 A-003): no source files changed, nothing to commit. Evidence lives in hidden_files/: a005_preinstall_baseline.log, a005_install.log, a005_rocminfo.log, a005_versions.log, a005_run_all_canonical.log, run_a005.sh, A005_LEDGER.md. CAMPAIGN_STATE.md updated.
