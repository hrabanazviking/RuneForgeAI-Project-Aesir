# A-087 Ledger — ROCm install reproducibility (team-17)

- Date: 2026-11-13 (EST, purpleraider local)
- Machine: purpleraider — AMD RYZEN AI MAX+ 395 w/ Radeon 8060S (gfx1151), Ubuntu 26.10, kernel 7.3.0-10-generic
- Worktree: /home/volmarr/aesir-team-17, branch yrsa/aesir-team-17, base de415271 (83 of 216 banked)
- Method: native Ubuntu packages only (apt). NO Docker. The proof runs are read-only; no package was installed, upgraded or removed by this slice (see the pre-run record in CAMPAIGN_STATE.md).

## What was built

The A-005 install (hidden_files/A005_LEDGER.md) as a scripted, pinned, native setup:

1. `scripts/install_rocm_z13.sh` — the setup script, three modes:
   - `--check` (default): read-only convergence probe — dpkg-query for every pin, rocminfo for the gfx1151 agent, the unversioned libamdhip64.so symlink, ldconfig resolution, HIP headers. Exit 0 iff CONVERGED.
   - `--dry-run`: --check plus `apt-get -s install <pins>` simulation; passes only when the simulation shows zero pending changes.
   - `--apply`: the real pinned install (`apt-get install -y --allow-downgrades <9 pkg=version args>`, then --check again). Deliberately NOT run by this team — it is the operator's convergence tool for a drifted machine; on this converged machine the dry-run proves it would be a no-op.
2. `aesir_engine/core/rocm_pin.mojo` — the pin table + pure convergence predicate (exact version-string equality; missing = drift; wrong-length snapshot = total drift, fail-closed).
3. `aesir_engine/tests/test_rocm_repro_a087.mojo` — 5 cases registered in run_all (pin 589 -> 594): pin_table_exact, convergence_accepts, convergence_rejects_drift (negative controls: bump / missing / fully-wrong / short snapshots all blocked with exact drift counts), script_contract (script read from disk), script_core_sync (every core pin argument verbatim in the script).

## The pinned set (all nine, verbatim from A-005)

rocminfo=10.0-0ubuntu2, libamdhip64-dev=10.0-0ubuntu3 (direct);
libamd-comgr-rocm-dev=10.0+dfsg-0ubuntu1, libhiprtc-builtins7=10.0-0ubuntu3,
libhiprtc7=10.0-0ubuntu3, libhsa-runtime-dev=10.0+dfsg-0ubuntu2 (dependencies);
libamdhip64-7=10.0-0ubuntu3, libhsa-runtime64-1=10.0+dfsg-0ubuntu2,
libamd-comgr3-rocm=10.0+dfsg-0ubuntu1 (runtime base).
Pinning only the two direct packages would not be reproducibility: apt would
re-resolve the other seven to whatever the archive holds on re-run day.
hipcc stays excluded (A-005: experimental lineage, mismatched with this userland).

## Acceptance — convergence proof (all read-only, filed)

1. `hidden_files/a087_check_run1.log`: 9/9 PIN OK at the exact pinned versions,
   4/4 PROBE OK (rocminfo gfx1151 agent, libamdhip64.so symlink, ldconfig,
   HIP headers), verdict `ROCM_REPRO CONVERGED pins=9 drift=0`, exit 0.
2. `hidden_files/a087_check_run2.log`: the re-run — identical script output,
   identical CONVERGED verdict, exit 0. (The two logs differ only in the
   harness header timestamp and the CHECKn_EXIT label line.)
3. `hidden_files/a087_dry_run.log`: apt simulation of the pinned install:
   `0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.` +
   `ROCM_REPRO DRY-RUN: PASS (re-run would change nothing)`, exit 0.
   A re-run of the setup therefore converges to the same versions —
   it is already at the fixed point, and the apply path's only inputs
   are the nine exact `pkg=version` arguments.
4. `hidden_files/a087_versions.log`: dpkg snapshot of all nine (install ok
   installed), rocminfo gfx1151 agent lines, libamdhip64.so symlink,
   `ctypes CDLL libamdhip64.so OK` (the A-005 load surface).

Honesty bounds: no real reinstall was performed or claimed; the claim is
exactly the roadmap's — a re-run converges to the same versions, proven by
two identical read-only verdicts plus a zero-change apt simulation.
Residual risk, recorded not hidden: if Ubuntu's archive ever drops a pinned
version, --apply fails closed at apt (no fallback to unpinned resolution);
the remedy then is a new slice re-pinning on evidence, as A-005 -> A-087 did.

## Full suite (gate_fast.sh = E-MASTER CPU entry + A-080 equivalence gate)

- Run solo after team-14's A-084 suite finished (shared-machine discipline;
  never concurrent with another suite or a seat gate).
- hidden_files/a087_gate_fast.log: GATE_FAST RESULT: PASS (249s, budget 600s).
- Suite (hidden_files/build_matrix_cpu.log): 591 passed / 1 failed / 2 skipped
  / 594 total = the base shape (586/1/2 of 589) + the 5 new A-087 cases, all
  five [CASE PASS]. Sole failure is the pre-existing tolerated
  gguf.tensor_directory_interface (J-022). Skips are the 2 pre-declared.
  Neither known intermittent (resilience.state_vault_rejects_growth,
  gpu.amd_hip_stream_async_round_trip) appeared. Equivalence gate PASS
  (real=0, invalid=0).
- One compile warning (test_rocm_repro_a087.mojo:70): the pin-count guard
  compares a comptime constant, so the compiler notes the branch is
  unreachable at the current value — the guard is intentional (it fires
  if the table size ever changes without updating the case).

## Repo changes

scripts/install_rocm_z13.sh (new), aesir_engine/core/rocm_pin.mojo (new),
aesir_engine/tests/test_rocm_repro_a087.mojo (new),
aesir_engine/tests/run_all.mojo (+import, +5 cases, finish 589 -> 594),
CAMPAIGN_STATE.md, hidden_files/ evidence (this ledger, a087_check_run1.log,
a087_check_run2.log, a087_dry_run.log, a087_versions.log, a087_gate_fast.log,
build_matrix_cpu.log). One commit on the team branch,
subject "A-087: ROCm install reproducibility". Never merged or pushed
from this worktree; the keeper banks at the seat after A-086.
