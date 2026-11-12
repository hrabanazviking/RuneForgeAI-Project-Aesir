# A-023 Ledger — Memory budget governor (team-09)

## Slice

- **Slice:** A-023 — Memory budget governor (Wave 3, unified-memory architecture)
- **Roadmap text:** "A configurable cap keeps the engine from starving the desktop/other work on the shared 128 GB. Acceptance: under synthetic pressure the engine degrades (spills/refuses) instead of OOMing the machine; the cap is honoured in measurements."
- **Worktree:** /home/volmarr/aesir-team-09, branch yrsa/aesir-team-09
- **Base:** banked seat main 36d2c240 (A-019; 19 of 216). Previous team slice A-009 verified banked in seat log by subject (8bebf815) before reset --hard onto 36d2c240.
- **Team:** lead + 6 Mythic Engineering sub-agents, all mustered (no rate limit). Sub-agents did read-only recon (allocator audit, policy/config style, suite structure, test design, machine/roadmap recon, ledger format); the lead integrated and wrote all code.

## What was built

- aesir_engine/core/memory_budget.mojo (new, 300 lines):
  - MemoryBudgetConfig (cap_bytes, reserve_bytes; validate fail-closed; default 96 GiB cap / 16 GiB reserve for the shared 128 GB machine) with effective_cap_bytes(available) = min(cap, available - reserve), floored at 0, unknown availability (-1) leaves the configured cap.
  - MemoryBudgetGovernor: exact integer byte accounting (live, peak, spilled-live, alloc/free/refusal/spill counters, total reserved, utilisation ppm). reserve admits through core/checked_span BEFORE any backing allocation and raises the ERROR_TAXONOMY MEM-003 OUT_OF_MEMORY error naming request/live/cap; a refused reserve charges nothing and counts the refusal. admit_or_spill degrades spillable requests onto the spill ledger (DECISION_SPILL) instead of OOMing; decide() exposes ADMIT/SPILL/REFUSE verdicts in the A-017 policy style. release/release_spilled are checked - over-release raises, the ledger never underflows.
  - allocate_governed / free_governed bind the governor to the A-019 zero-copy allocator: reserve runs first (refusal = ZeroCopy.allocate never called), a backend failure rolls the reservation back, free returns the bytes.
  - parse_meminfo_available_bytes (pure, strict bounded_decimal parser) + mem_available_bytes() reading /proc/meminfo live at runtime; nothing hardcoded.
- aesir_engine/tests/test_memory_budget.mojo (new, 287 lines): six E-MASTER cases (below).
- aesir_engine/tests/run_all.mojo: import + six run_case registrations (memory.budget_*) placed after the zero-copy group; finish pin re-pinned 328 -> 334 with the A-023 comment in the pin history.
- No README touched. No Docker. No merge/push to main (keeper banks in roadmap order).

## Cases and measured evidence (rerun log, this machine)

1. memory.budget_cap_honoured_measured — real HIP managed allocations (1 MiB + 2 MiB + 512 KiB) through allocate_governed under a 4 MiB cap: MEASURED governor live 3670016 == zero-copy shim live-byte delta 3670016 under cap 4194304; accounts agree after a mid-case free and both return to baseline exactly. This is the cap honoured in measurements, against the shim independent counter (device execution via the A-019 HIP path on gfx1151, as proven by A-019; the governor itself claims no new accelerator execution).
2. memory.budget_refusal_fail_closed — beyond-remaining, over-cap, zero and negative reserves all raise MEM-003, charge nothing (refusal_count 4 in sequence); a governed over-cap allocate leaves shim alloc/live counters exactly unmoved (refusal before allocation).
3. memory.budget_spill_degradation — synthetic pressure: 12 x 256 KiB spillable requests against a 2 MiB cap admit exactly 8 (live == cap) and spill 4; a single 8 MiB spillable request spills whole; non-spillable under pressure raises; spill ledger returns to 0. The suite process completes normally — degrade, never OOM, never crash.
4. memory.budget_configurability — tight (1 MiB) vs roomy (8 MiB) caps give different verdicts on identical sequences; three invalid configs (cap 0, reserve >= cap, negative reserve) all refused at validate; effective-cap arithmetic proven at known figures.
5. memory.budget_accounting_baseline — mixed reserve/release/admit sequence: utilisation ppm exact, peak 3 MiB exact, over-release refused without changing the ledger, final live/spilled 0, alloc_count == free_count == 3, total reserved exact.
6. memory.budget_live_meminfo_pressure — fixture parse exact (123626384 KiB -> bytes), missing/malformed fields refused; MEASURED live MemAvailable 124787871744 bytes read from /proc/meminfo during the rerun; a governor built on the effective cap from that live figure admits 1 MiB and refuses a request of the whole effective cap on top.

## Suite counts (read from log files, never memory)

- Baseline (seat, banked A-019): 325 passed / 1 failed / 2 skipped / 328 total; sole failure the pre-existing gguf.tensor_directory_interface J-022 drift (tolerated; roads A-165/A-121); skips the 2 pre-declared.
- First A-023 run (hidden_files/a023_run_all.log, sha256 5742dadda9559f4b7256afd605318463201b75cac2b7ac972580bc7b1865b6ff): 330 passed / 2 failed / 2 skipped / 334 total. Second failure was resilience.state_vault_rejects_growth, observed while team-08 full suite and a 12-job Tensile build ran concurrently on the same machine.
- Rerun on a quiet machine (hidden_files/a023_run_all_rerun.log, sha256 1436f031ca3eea4c7cc07ba9b7424f3fef006e3f3a2534979a1582c5d6eb33a0): 331 passed / 1 failed / 2 skipped / 334 total — exactly baseline plus the six new cases, all PASS, sole failure the tolerated J-022 drift, zero regressions. Verdict on the extra first-run failure: contention flake in a timing-sensitive filesystem-growth test, unrelated to this slice (no shared code); passes on rerun. Recorded here, not hidden.
- MOJO_EXIT=1 in both logs is the suite normal signal for the one tolerated failure (same as seat gates).

## Bugs found / fixed

- My first runner draft (hidden_files/run_a023.sh as first written) lost its shell variables to heredoc expansion at creation time and staged shims into an empty path; that run was killed by PID and the script was rebuilt from the banked seat-gate script (run_seat_gate_a019.sh) with only path/log-name substitutions, then verified (staging path and all cc exits 0 in the log header). Fixed in-slice; the discarded first log was overwritten by the corrected run.
- No product-code bugs discovered. No unfixed bugs; no next-work items beyond keeper banking.

## Files

- aesir_engine/core/memory_budget.mojo sha256 1c49cbe7662a28a28542ddd6924529fa693a7d9e0aa42113bc542c7d0263d21f
- aesir_engine/tests/test_memory_budget.mojo sha256 148faffe81570fefc9a9dc0a396b0f0f52bf4d3682deda4c9fa89ad58c1d4fa1
- Logs: hidden_files/a023_run_all.log, hidden_files/a023_run_all_rerun.log; runners: hidden_files/run_a023.sh, hidden_files/run_a023_rerun.sh
