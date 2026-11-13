# CAMPAIGN_STATE - team-15 (Aesir Z13 forge)

- Team: team-15 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-15, branch yrsa/aesir-team-15
- Base: 82591e7c (banked main, 82 of 216, A-082 closure)
- Assigned slice: A-085 - The bake-off. HIP vs Vulkan on identical kernels and fixtures: speed, bandwidth, stability, code health. Acceptance: verdict doc with numbers; one road declared primary, the other parked with written re-open criteria (never silently dropped). Builds on banked A-082/A-083 HIP GEMV evidence once A-083 banks, plus the banked Vulkan GEMV line (A-056/A-057/A-058).
- Status: MUSTERED 2026-11-13 by the keeper (expansion to 27 teams, third muster). Build and commit on the team branch only; the keeper banks at the seat in roadmap order after A-084. Never merge or push from this worktree. Never touch README.md. No Docker, ever.
- Suite baseline on this base: 583 passed / 1 failed / 2 skipped / 586 total (seat gate A-082); sole failure pre-existing gguf.tensor_directory_interface (J-022 drift); skips the 2 pre-declared. Known intermittents (pre-existing, proven at base): resilience.state_vault_rejects_growth and gpu.amd_hip_stream_async_round_trip - a suite showing only those plus J-022 is green-to-baseline; re-run once before treating either as new.
- Machine note: the MimirAlloc Z-100 soak resumed late 2026-11-13 morning; defer full-suite runs while heavy shared work is live, and never run a suite concurrently with a seat gate.

## A-085 result (team-15 lead, 2026-11-13, continuation lead)

- Status: COMPLETE, committed locally (not pushed; keeper banks
  in roadmap order after A-084).
- Continuation: first lead cancelled mid-work left a draft
  verdict doc + fresh bench logs (08:06); this lead audited
  every number, corrected 3 draft defects (cross-road parity
  wording, the false load-0.19 idle claim, the filed Vulkan
  1x256 outlier), re-ran both benches with full provenance
  (08:29, seat tree de415271), and finished the slice.
- Deliverable: docs/bench/A085_BAKEOFF.md (doc-only slice,
  +0 suite cases). Verdict: Vulkan PRIMARY GPU road; HIP
  PARKED probe-only with 4 written re-open criteria. Scoped
  to the GPU-road choice; A-081 CPU-primary decode verdict
  untouched.
- Numbers (Q4_K GEMV per-call medians): fresh Vulkan
  0.175-0.454 ms vs HIP 1.76-6.92 ms (5.6-26x across the two
  paired runs); large-shape bandwidth ~20.8 vs ~0.34 GB/s.
  Parity: each road reproduces its own filed errors
  bit-identically; both in the filed band at every shape.
- Suite (hidden_files/a085_run_all.log, solo run): 583
  passed / 1 failed / 2 skipped / 586 total = exact base
  baseline; sole failure pre-existing J-022; both known
  intermittents PASSED.
- Full detail: hidden_files/A085_LEDGER.md.
- Next work: none blocking for A-085. HIP re-open criteria
  are the standing next-work record for the HIP road.
