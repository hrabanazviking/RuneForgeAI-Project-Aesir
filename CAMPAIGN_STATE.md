# CAMPAIGN_STATE - team-18 (Aesir Z13 forge)

- Team: team-18 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-18, branch yrsa/aesir-team-18
- Base: 3822d595 (banked main, 85 of 216, A-085 closure)
- Assigned slice: A-088 - HIP zero-copy measurement. Managed-memory path vs the Vulkan residency path (A-064). Acceptance: numbers filed; residency design updated if HIP model is better.
- Context: A-085 verdict is BANKED - Vulkan is the PRIMARY GPU road; HIP is PARKED probe-only. A-088 is a measurement slice on the HIP path: measure honestly, file numbers, and propose a residency-design update only if the HIP model is measurably better. The verdict itself is not re-litigated in this slice.
- Status: MUSTERED 2026-11-13 by the keeper (expansion to 27 teams). Build and commit on the team branch only; the keeper banks at the seat in roadmap order after A-086 and A-087. Never merge or push from this worktree. Never touch README.md. No Docker, ever.
- Suite baseline on this base: 591 passed / 1 failed / 2 skipped / 594 total (seat gate A-085); sole failure pre-existing gguf.tensor_directory_interface (J-022 drift); skips the 2 pre-declared. Known intermittents (pre-existing, proven at base): resilience.state_vault_rejects_growth and gpu.amd_hip_stream_async_round_trip - a suite showing only those plus J-022 is green-to-baseline; re-run once before treating either as new.
- Machine note: defer full-suite runs while heavy shared work is live, and never run a suite concurrently with a seat gate.
- Raw-oracle discipline for all correctness work; accelerator-visible is not accelerator-run - every accelerator claim needs device-execution evidence (dispatch counters / device identity on the real gfx1151).

## A-088 result (team-18 lead, 2026-11-13)

- Status: COMPLETE, committed locally (not pushed; keeper
  banks in roadmap order after A-086/A-087).
- Verdict: A-064 residency STAYS for static weights - HIP
  managed is not better for the residency workload (GPU +
  CPU-write parity at 64 MiB, residency alloc ~400x
  cheaper). Sub-case rule adopted: no CPU-read buffer may
  use the A-064 residency type (flags-7 CPU read measured
  0.21-0.23 GB/s vs 33-42 GB/s managed/cached). A-085
  verdict untouched (Vulkan primary, HIP parked).
- Deliverable: docs/bench/A088_HIP_ZERO_COPY_RESIDENCY.md
  + aesir_engine/tests/bench_zero_copy_residency_a088.mojo
  (doc+bench only, +0 suite cases, pin stays 594) +
  hidden_files/A088_LEDGER.md + run_a088_*.sh.
- Bench: two PASS runs filed (a088_bench.log run 3 +
  a088_bench_run2.log), all oracles bad=0, GEMV worst
  2.48e-05 inside the A-064 bound, zero copy calls on
  every path, launch/dispatch deltas exact.
- Suite run 2 solo: 591 passed / 1 failed / 2 skipped /
  594 = exact base baseline; sole failure pre-existing
  J-022. Run 1 showed both named intermittents; both
  passed on the re-run (pre-existing, not new).
- Bugs: none in engine code; two ruler defects in this
  bench (modulo-bound write pattern, GEMV input scale)
  found, fixed, and re-measured before filing.
