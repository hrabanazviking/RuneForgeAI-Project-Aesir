# CAMPAIGN_STATE - team-17 (Aesir Z13 forge)

- Team: team-17 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-17, branch yrsa/aesir-team-17
- Base: de415271 (banked main, 83 of 216, A-083 closure)
- Assigned slice: A-087 - ROCm install reproducibility. The A-005 install becomes a scripted, pinned, native setup. Acceptance: script re-run on the Z13 converges to the same versions (idempotent). Native installs only - NO Docker, ever.
- Status: MUSTERED 2026-11-13 by the keeper (expansion to 27 teams, fourth muster). Build and commit on the team branch only; the keeper banks at the seat in roadmap order after A-086. Never merge or push from this worktree. Never touch README.md.
- Suite baseline on this base: 586 passed / 1 failed / 2 skipped / 589 total (seat gate A-083); sole failure pre-existing gguf.tensor_directory_interface (J-022 drift); skips the 2 pre-declared. Known intermittents (pre-existing, proven at base): resilience.state_vault_rejects_growth and gpu.amd_hip_stream_async_round_trip - a suite showing only those plus J-022 is green-to-baseline; re-run once before treating either as new.
- Machine note: defer full-suite runs while heavy shared work is live, and never run a suite concurrently with a seat gate. Do NOT re-run any system package install on the live machine without recording exactly what it changes here first; the deliverable is the script + a convergence proof that does not destabilize the shared box.

## A-087 work log (2026-11-13, team-17 lead)

- Design (from the A-005 ledger, hidden_files/A005_LEDGER.md): the pinned
  set is ALL NINE packages of the A-005 coherent install, not only the
  two direct ones - rocminfo 10.0-0ubuntu2, libamdhip64-dev
  10.0-0ubuntu3, libamd-comgr-rocm-dev 10.0+dfsg-0ubuntu1,
  libhiprtc-builtins7 10.0-0ubuntu3, libhiprtc7 10.0-0ubuntu3,
  libhsa-runtime-dev 10.0+dfsg-0ubuntu2, libamdhip64-7 10.0-0ubuntu3,
  libhsa-runtime64-1 10.0+dfsg-0ubuntu2, libamd-comgr3-rocm
  10.0+dfsg-0ubuntu1. hipcc stays deliberately excluded (A-005 note:
  its Ubuntu candidate is an experimental lineage mismatched with the
  pinned ROCm 10.0 userland).
- Deliverables: scripts/install_rocm_z13.sh (modes --check default /
  --dry-run / --apply), aesir_engine/core/rocm_pin.mojo (pin table +
  convergence predicate), aesir_engine/tests/test_rocm_repro_a087.mojo
  (5 cases, run_all pin 589 -> 594), hidden_files/A087_LEDGER.md.

- PRE-RUN RECORD - exactly what a live re-run would change (recorded
  BEFORE any proof run, per the machine note above):
  * The proof runs are READ-ONLY. `install_rocm_z13.sh --check` only
    runs dpkg-query, rocminfo, test -e and ldconfig -p probes; it
    changes NOTHING on the system. `--dry-run` runs
    `apt-get -s install <9 pinned pkg=version args>` (simulation
    only, no root, no dpkg lock writes, no package changes).
  * `--apply` is NOT part of the proof and will NOT be run by this
    team. For the record, what --apply WOULD do if a future operator
    ran it: `sudo apt-get install -y <the 9 pinned pkg=version args>`
    with --allow-downgrades - on the current converged machine apt
    resolves this to 0 installs / 0 upgrades / 0 removals (proven by
    the --dry-run simulation); on a drifted machine it would install,
    upgrade or downgrade exactly those nine packages to the pinned
    versions and nothing else. No other package, file or service is
    touched by any mode. Post-checks (rocminfo gfx1151, unversioned
    libamdhip64.so symlink, HIP headers) are probes in every mode.
  * Live probe before building (2026-11-13 ~08:26 EST): all nine
    packages already at the exact pinned versions (dpkg-query),
    rocminfo reports the gfx1151 agent (AMD Radeon 8060S Graphics),
    /usr/lib/x86_64-linux-gnu/libamdhip64.so -> libamdhip64.so.7
    present, /usr/include/hip/hip_runtime.h present, load average
    0.12, no other crew install logs in /tmp. The machine is already
    converged, so the honest idempotence proof is: --check twice
    (identical CONVERGED verdicts) + one --dry-run showing zero
    pending changes.

- A-087 OUTCOME (2026-11-13, team-17 lead): DONE, committed on the team
  branch, ready for the keeper to bank after A-086. Proof (all
  read-only, filed): --check twice, both ROCM_REPRO CONVERGED pins=9
  drift=0 exit 0 with identical script output; --dry-run PASS with apt
  simulation 0 upgraded, 0 newly installed, 0 to remove. --apply was
  NOT run. Full gate: gate_fast PASS (249s); suite 591 passed / 1
  failed / 2 skipped / 594 total (base 586/1/2 of 589 + 5 new cases,
  all PASS; sole failure the tolerated J-022; equivalence gate PASS).
  Ledger: hidden_files/A087_LEDGER.md.
