# A-028 Ledger -- Target-flag audit (Wave 4 opener)

Slice: A-028 -- Project Aesir Z13 Massive Roadmap
Host: purpleraider (AMD Ryzen AI Max+ 395 / Radeon 8060S gfx1151)
Worktree: /home/volmarr/aesir-team-04, branch yrsa/aesir-team-04
Base: 107711b0 (seat main, A-023 banked, 23 of 216; ls-remote == 107711b0)
Previous team-04 slices verified banked in seat main by subject:
  16c703af A-004, 61aec548 A-013, 3fe90a8d A-018.
Toolchain: pixi env Mojo 1.0.0 (ed45d567), MAX 26.5.0.

## Acceptance verdict: PASS
- Fast suite builds and runs on the Z13 with zero NVIDIA flags: BOTH
  flag-free (no --target-accelerator at all) and gfx1151 runs complete.
- Build matrix script scripts/build_matrix.sh (cpu / amd) exists and
  passes end-to-end on purpleraider: MATRIX RESULT: PASS (all), exit 0
  (hidden_files/a028_build_matrix.log sha256 f79fc6d3ecdfc13f8683e77857ba59467badc374d6db9275f3c02afcf1638224).

## Key evidence (counts read from logs, never memory)
- Baseline on this base (brief): 345 passed / 1 failed / 2 skipped / 348.
- CPU gate run (no accelerator flag): hidden_files/a028_run_all_cpu.log
  sha256 3135dc13cac930f05bed65a2f2116412646b65dcb8e7f2b778a978e1b97ce72f
  [SUMMARY] 345 / 1 / 2 / 348; wall 1:05.93.
- AMD gate run (--target-accelerator gfx1151): hidden_files/a028_run_all_amd.log
  sha256 49672f5f37dd8caa303b12208eadc416f4ea3efdf735832e31a0c920453bb4b7
  [SUMMARY] 345 / 1 / 2 / 348.
- Matrix logs: build_matrix_cpu.log sha256 cf0b8837de3ca5bd04923f868375a70ed26298ea0b81bfaaa1fdb794e8125244;
  build_matrix_amd.log sha256 3499c685b0f90fa1ac7571f029b62eb263f4d3e10c084294c8de1118912ed037.
- Sole failure in every run: gguf.tensor_directory_interface (pre-existing
  J-022 drift, tolerated; roads A-165/A-121). Skips: the 2 pre-declared
  (vision.cuda_session_image_chat, rag.real_engine_integration).
- run_all pin ledger.finish(348) unchanged -- comment-only header edit.

## Boundary finding (honest, evidence-first)
- A-002/A-003 recorded that flag-free builds fail on this host (MAX stdlib
  "Unknown GPU architecture" via the CUDA-gate instantiation chain). On the
  current base (A-023) that failure NO LONGER REPRODUCES: an AOT flag-free
  build of run_all produced /tmp/a028_run_all_noflag (6,485,272 bytes) and
  the flag-free JIT suite run passes the gate counts above. Which banked
  slice removed the constraint is not identified here and is not claimed.
  gfx1151 is in Mojo 1.0.0's --print-supported-accelerators list
  ("gfx1151 - RDNA3+ (Radeon 8060S)"), so the AMD path is a named,
  supported target -- not a workaround.
- gfx1151 remains a compile-time architecture only; all suite execution
  above is CPU execution. No accelerator execution is claimed.

## sm_89-style assumptions found (815 raw grep hits repo-wide; by class)
OPERATIVE -- fixed in this slice:
1. aesir_engine/tests/run_all.mojo header -- canonical E-MASTER command
   pinned sm_89. Now gfx1151 + backend note (sm_89 named as NVIDIA variant).
2. CAPABILITY_LEDGER.md -- E-MASTER, E-BUILD, E-BACKPRESSURE, E-AUTOSAVE
   commands pinned sm_89 (E-BUILD output name embedded "sm89"). Now
   gfx1151 + a backend note in section 2 naming both backends.
3. .github/workflows/ci.yml -- 39 literal `--target-accelerator sm_89`.
   Now one named env AESIR_ACCELERATOR_TARGET=sm_89 with a comment stating
   CI has no GPU and the value is compile-only/NVIDIA; YAML re-validated.
4. scripts/launch.py -- --target default sm_89 and sm_-only validation
   ("must be an sm_ CUDA target"). Now host-detected default (gfx1151 when
   /dev/kfd exists, else sm_89), valid_target() accepts sm_<n>/gfx<n>,
   error and help name both backends.
5. scripts/offline.py -- --target default sm_89; manifest validation
   rejected non-sm_ targets. Now host-detected default matching launch.py;
   manifest validation accepts gfx<n> as well.
6. scripts/launch.ps1 + scripts/launch_windows.psm1 -- default 'sm_89',
   sm_-only regex validation. Now gfx<n> accepted with a backend-naming
   error; the ps1 default carries an explicit NVIDIA-backend comment.
7. docs/LOCAL_LAUNCH.md -- documented the sm_89 default as the default.
   Now documents host detection and both named backends.
TEST FIXTURES -- sample data for target-agnostic parsers:
8. scripts/test_check_doc_drift.py -- sm_89 example command strings for a
   regex that accepts any target. Left as valid NVIDIA examples.
9. scripts/test_offline_preparation.py -- fake launch hard-coded manifest
   target sm_89 (a baked-in silent default). FIXED: the stub now records
   the --target it was given, mirroring the real launch.py.
10. scripts/test_windows_launch.ps1 -- explicit -Target sm_89 transport
    assertion. Still valid; left.
HISTORICAL RECORDS -- left untouched deliberately (rewriting them would
falsify evidence of what was run on NVIDIA hosts at the time):
11. docs/evidence/*/provenance.json, docs/NATIVE_*.md, docs/janas/*,
    DEVLOG.md, BEST_IN_CLASS_GAMEPLAN.md, 06_/08_*.md and the CUDA
    reference guides (Complete_CUDA_Programming_Reference_Guide.md,
    docs/GEMMA4_CUDA.md -- CUDA-specific by subject, backend-explicit by
    name already).

## Regression checks (Python side, final tree)
- pytest scripts/test_launch.py test_offline_preparation.py
  test_platform_launch.py test_native_launch.py: 17 passed.
- pytest scripts/test_check_doc_drift.py: 17 passed + 1 failure that is
  PRE-EXISTING on the pristine base (verified by stash):
  test_todo_repository_integration_against_canonical_ledger expects 329
  ledger statuses; the parser yields 503 on base and on this tree alike
  (my ledger edit is status-neutral, proven by parser diff). NOT fixed in
  this slice: reconciling the pin vs the grown ledger is the A-208
  count/ledger reconciliation road (same class A-003 flagged). Recorded
  in CAMPAIGN_STATE.md as immediate next work for the campaign.

## Files in the A-028 commit
scripts/build_matrix.sh (new), scripts/launch.py, scripts/offline.py,
scripts/launch.ps1, scripts/launch_windows.psm1,
scripts/test_offline_preparation.py, aesir_engine/tests/run_all.mojo,
CAPABILITY_LEDGER.md, docs/LOCAL_LAUNCH.md, .github/workflows/ci.yml.
No README.md touched. No merge/push from this worktree (keeper banks).

## Addendum -- sub-agent corroboration (folded in before banking)
- Build-system agent (empirical, /tmp builds on this host): Mojo 1.0.0
  --print-effective-target with NO flag auto-detects the host accelerator:
  amdgpu:gfx1151 on purpleraider. "cpu" and "amd" are NOT valid
  --target-accelerator values (stdlib std/gpu/host/info.mojo rejects them
  when GPU code is instantiated); they are matrix ENTRY names only, and
  scripts/build_matrix.sh now says so in its header. gfx1151 and
  amdgpu:gfx1151 both compile the real engine; --help exits 0.
- docs/NATIVE_RUNTIME.md (live recipes at lines 83/116/339 pinning sm_89)
  was given the same backend note treatment as the ledger in the amended
  commit. docs/HOW_TO_USE_PROJECT_AESIR_RIGHT_NOW_2026-09-16.md is a
  dated snapshot (historical by title) and docs/GEMMA4_CUDA.md is
  CUDA-by-subject; both left as records.
- hidden_files/run_a*.sh and run_seat_gate_*.sh runners (29 scripts,
  untracked working scripts) and llvm-crash-checkpoint/*.sh (2 scripts)
  also pin sm_89: they are per-slice historical run records / crash
  checkpoint evidence, not repo build infrastructure; left untouched.
  aesir_engine/tests/README.md documents a flag-free plain invocation --
  a README, never touched under the standing law.
- Test-runner agent confirms: the CUDA/NVIDIA volume in test code is
  feature tests for the CUDA backend itself, not target-flag assumptions;
  the flag risk was concentrated exactly in the surfaces fixed above.
  It also notes the ledger E-MASTER links 2 shims vs the run_all header's
  5 -- a pre-existing divergence; all A-028 runs used the header's 5-shim
  shape (the superset, matching A-019..A-023 practice).
