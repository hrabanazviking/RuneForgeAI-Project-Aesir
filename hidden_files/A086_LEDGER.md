# A-086 Ledger - Winner integration (team-16, PREPARATORY)

- Slice: A-086 Winner integration, Wave 10. Acceptance (roadmap):
  the bake-off winner is the registry's first-class GPU backend;
  the loser remains probe-only; registry + `doctor` reflect the
  verdict; tests cover both states.
- Base: de415271 (83 of 216 banked, A-083 closure).
- Worktree: /home/volmarr/aesir-team-16, branch yrsa/aesir-team-16.
- Banks only after A-084 and A-085, in roadmap order, by the keeper
  at the seat. Never merge/push from this worktree.

## HARD BLOCK (dependency)
- The winner verdict comes from A-085 (team-15, HIP vs Vulkan
  bake-off). As of this slice's work, A-085 is NOT banked: the
  forge main checkout is still at de415271 (A-083 closure) and
  team-15's A-085 suite was live on purpleraider during this work.
- Therefore NO winner is declared and NO primary-backend switch is
  made. Everything below is verdict-parametric scaffolding: it
  holds EITHER backend as first-class with the other probe-only,
  and the live default remains the pending state.
- Unblock: when the A-085 verdict banks, the keeper applies it via
  core/gpu_winner.apply_bakeoff_verdict() (one call) and re-runs
  the seat gate; registry, placement, selection and doctor then
  reflect the verdict with no further code changes.

## Survey (preparatory)
- Registry: aesir_engine/core/backend_registry.mojo (A-009) --
  BackendRegistry{HIP, Vulkan, XRT, CPU} of BackendCapability
  {runtime, status present/absent/degraded, version, device,
  detail}; build_backend_registry() from injectable RawBackendProbe;
  observe_backend_registry() live probes. No role concept existed.
- Placement: aesir_engine/core/device_policy.mojo (A-017) --
  GPU class hard-preferred HIP, then Vulkan.
- Selection: aesir_engine/core/backend_config.mojo (A-032) --
  auto followed the same HIP -> Vulkan GPU preference; explicit
  hip/vulkan resolved whenever present/degraded.
- Doctor: aesir_engine/cli/doctor.mojo -- renders registry lines
  + placement decisions in text, and a "backends" object in JSON;
  no verdict surface existed.
- Bake-off pair (A-085 roadmap text): HIP vs Vulkan on identical
  kernels and fixtures; one road declared primary, the other
  parked with written re-open criteria.

## Deliverables (all preparatory, verdict-parametric)
- core/backend_registry.mojo: GPU role on BackendCapability --
  GPU_ROLE_UNDECIDED / GPU_ROLE_FIRST_CLASS / GPU_ROLE_PROBE_ONLY,
  gpu_role_name() / is_first_class_gpu() / is_probe_only_gpu();
  line() appends "[gpu role: ...]" for HIP/Vulkan once decided
  (pending lines unchanged); registry_with_gpu_winner() /
  registry_without_gpu_winner() / gpu_first_class_runtime() /
  gpu_probe_only_runtime().
- core/gpu_winner.mojo (new): BakeoffVerdict (pending / decided
  with winner, loser, source); bakeoff_verdict_decided() fails
  closed (winner must be HIP or Vulkan, source non-empty);
  validate_gpu_roles() (lawful states only: both undecided, or
  one first-class + other probe-only; no GPU role on XRT/CPU);
  bakeoff_verdict_from_registry(); apply_bakeoff_verdict();
  preferred_gpu_runtime(); gpu_winner_lines() / gpu_winner_summary()
  for doctor.
- core/device_policy.mojo: GPU placement is verdict-aware --
  first-class winner is the only GPU placed; probe-only loser is
  never placed (spills to CPU with the reason logged); pending
  keeps the exact standing HIP -> Vulkan behaviour/strings.
- core/backend_config.mojo: explicit hip/vulkan selection of a
  probe-only backend raises the named probe-only error (no
  fallback); auto resolves only to the first-class winner when
  decided, logging the probe-only skip; pending unchanged.
- cli/doctor.mojo: derives the verdict from the live registry
  (pending today; fail-safe try/except so diagnosis never breaks)
  and renders it: text section "GPU bake-off winner (A-085 /
  A-086)" and a JSON "gpu_winner" object {state, winner, loser,
  summary}.
- tests/test_gpu_winner_a086.mojo (new): 6 E-MASTER cases --
  gpu_winner.pending_state, gpu_winner.hip_wins,
  gpu_winner.vulkan_wins, gpu_winner.invalid_verdicts_fail_closed,
  gpu_winner.probe_only_never_placed,
  gpu_winner.determinism_and_clear. Both decided states are
  covered symmetrically (registry roles, registry lines,
  placement, auto + explicit selection, doctor lines, round-trip).
- tests/run_all.mojo: registers the 6 cases; pin 589 -> 595.

## Verification
- PENDING at first write: full suite deferred while team-15's
  A-085 suite and team-14's A-084 suite were live on the shared
  machine (never run a suite concurrently with other heavy work;
  A-085 is a performance bake-off and contention would pollute
  its measurements). Suite result is appended below when run.

## Verification (full E-MASTER suite, purpleraider)
- Run AFTER the shared machine cleared (team-15 A-085 suite and
  team-14 A-084 suite finished first; launched via tmux session
  a086suite, hidden_files/run_a086_suite.sh, log
  hidden_files/a086_run_all.log).
- Result: 592 passed / 1 failed / 2 skipped / 595 total.
- All 6 new gpu_winner.* cases PASS (pending_state, hip_wins,
  vulkan_wins, invalid_verdicts_fail_closed,
  probe_only_never_placed, determinism_and_clear).
- Sole failure: gguf.tensor_directory_interface -- the
  pre-existing J-022 drift named in the base line, unchanged.
- Baseline arithmetic: 586/1/2/589 (base) + 6 new passes =
  592/1/2/595. Green-to-baseline; neither known intermittent
  (resilience.state_vault_rejects_growth,
  gpu.amd_hip_stream_async_round_trip) appeared.
- NOTE (not acted on): team-15 holds an UNCOMMITTED draft verdict
  (docs/bench/A085_BAKEOFF.md in their worktree). It is not
  banked, so per the slice law it changes nothing here; the
  scaffolding holds either outcome symmetrically regardless.
