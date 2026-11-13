# CAMPAIGN_STATE - team-19 (Aesir Z13 forge)

- Team: team-19 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-19, branch yrsa/aesir-team-19
- Base: 3822d595 (banked main, 85 of 216, A-085 closure)
- Assigned slice: A-089 - HIP error semantics. HIP error codes mapped into the taxonomy (extends A-033). Acceptance: fault-injection tests per mapped code.
- Context: A-085 verdict is BANKED - Vulkan is the PRIMARY GPU road; HIP is PARKED probe-only. A-089 maps HIP error codes into the existing error taxonomy regardless of that parking; the mapping serves diagnostics and any future HIP re-open.
- Status: MUSTERED 2026-11-13 by the keeper (expansion to 27 teams). Build and commit on the team branch only; the keeper banks at the seat in roadmap order after A-086, A-087 and A-088. Never merge or push from this worktree. Never touch README.md. No Docker, ever.
- Suite baseline on this base: 591 passed / 1 failed / 2 skipped / 594 total (seat gate A-085); sole failure pre-existing gguf.tensor_directory_interface (J-022 drift); skips the 2 pre-declared. Known intermittents (pre-existing, proven at base): resilience.state_vault_rejects_growth and gpu.amd_hip_stream_async_round_trip - a suite showing only those plus J-022 is green-to-baseline; re-run once before treating either as new.
- Machine note: defer full-suite runs while heavy shared work is live, and never run a suite concurrently with a seat gate.
- Raw-oracle discipline for all correctness work; accelerator-visible is not accelerator-run - every accelerator claim needs device-execution evidence (dispatch counters / device identity on the real gfx1151).

## A-089 result (team-19 lead, 2026-11-13)

- Status: COMPLETE, committed locally (not pushed; keeper banks
  in roadmap order after A-086, A-087 and A-088).
- Deliverable: NEW core/hip_errors.mojo - every HIP error code
  mapped into ERROR_TAXONOMY (33 mapped codes; VAL-003 invalid
  family, MEM-003 OOM, GPU-012 ROCm init, GPU-003 launch,
  GPU-004 timeout, GPU-002 no-device, GPU-005 illegal address,
  GPU-006 driver, INT-001 fail-closed fallback for unmapped).
  Both HIP gateways (hip_memory, hip_transfer) rewired from
  their blanket GPU-001/GPU-004 collapses to the per-code table;
  -1 absent and A-022 ownership sentinels unchanged and ahead
  of the mapping; stream-query 600 poll semantics unchanged.
  structured_errors gains the GPU-005 name. Post-review: zero_copy and weight_residency gateways rewired too (same defect), 8 more reachable codes mapped, 101 corrected to VAL-003. Tests:
  test_hip_errors_a089.mojo, 5 run_all cases (pin 594 -> 599),
  incl. one fault injection per mapped code and live-runtime
  1 EiB OOM injections on both gateways.
- Suite (hidden_files/a089_run_all.log, solo): 596 passed /
  1 failed / 2 skipped / 599 total = baseline 591/1/2/594 +
  exactly the 5 new cases; sole failure pre-existing J-022;
  both named intermittents passed.
- Full detail: hidden_files/A089_LEDGER.md.
- Next work: none blocking for A-089. Unmapped HIP codes fail
  closed to INT-001 by design; adding a code to the table is
  the standing next step if the driver ever surfaces one.
