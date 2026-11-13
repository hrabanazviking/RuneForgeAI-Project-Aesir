# CAMPAIGN_STATE - team-14 (Aesir Z13 forge)

- Team: team-14 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-14, branch yrsa/aesir-team-14
- Base: 82591e7c (banked main, 82 of 216, A-082 closure)
- Assigned slice: A-084 - HIP attention + norms. Minimal set matching A-060/A-062 scope. Acceptance: parity per op, with device-execution evidence for every accelerator claim.
- Status: MUSTERED 2026-11-13 by the keeper (expansion to 27 teams, third muster). Build and commit on the team branch only; the keeper banks at the seat in roadmap order after A-083. Never merge or push from this worktree. Never touch README.md. No Docker, ever.
- Suite baseline on this base: 583 passed / 1 failed / 2 skipped / 586 total (seat gate A-082); sole failure pre-existing gguf.tensor_directory_interface (J-022 drift); skips the 2 pre-declared. Known intermittents (pre-existing, proven at base): resilience.state_vault_rejects_growth and gpu.amd_hip_stream_async_round_trip - a suite showing only those plus J-022 is green-to-baseline; re-run once before treating either as new.
- Machine note: the MimirAlloc Z-100 soak resumed late 2026-11-13 morning; defer full-suite runs while heavy shared work is live, and never run a suite concurrently with a seat gate.

## A-084 result (team-14, second lead continuing, 2026-11-13)
- Status: COMPLETE, committed locally on yrsa/aesir-team-14
  (not pushed; keeper banks in roadmap order after A-083,
  which has since banked at the seat, main de415271,
  83 of 216, pin 589 - expect a run_all pin union at
  banking: this branch 586 -> 591, seat union 594).
- First lead was cancelled mid-work; its uncommitted
  gateway, test, and shim counters were reviewed, kept,
  and finished by the second lead, who added the run_all
  registration + pin and one in-slice hardening (the
  rejection case now asserts no dispatch counter advances
  on a rejected call).
- Deliverables: core/hip_attention_norms.mojo (HipAttnNorms
  gateway + RMSNorm / RoPE rotate-half / GQA decode
  attention HIP kernels via the A-010-A-012 gate),
  hip_memory_shim.c (3 per-op dispatch-evidence counters,
  noted only after launch + readback + synchronize),
  tests/test_hip_attn_norms_a084.mojo (5 cases),
  tests/run_all.mojo pin 586 -> 591,
  hidden_files/A084_LEDGER.md.
- Parity (a084_run_all.log): RMSNorm BIT-EXACT max_abs 0.0
  (rows/n 1/64, 3/128, 8/37); RoPE worst 1.1920929e-06
  (dim 32/64/128, pos 0/1/17); attention worst
  1.7881393e-07 (MHA + GQA x2 + GQA x4); bound 1e-4.
- Device evidence: dispatch-evidence case PASS on
  " AMD Radeon 8060S Graphics " (gfx1151); each op
  counter +1 for exactly 1 dispatch per op.
- Suite (a084_run_all.log): 588 passed / 1 failed /
  2 skipped / 591 total; sole failure the pre-existing
  J-022 gguf.tensor_directory_interface; neither known
  intermittent fired. Run solo, machine idle, no seat
  gate live.
- Next work: none blocking for A-084. Filed in the
  ledger for later slices: honest-absent hardening for
  RoPE/attention/evidence cases if HIP-less CI ever
  becomes real; A-085 bake-off judges HIP vs Vulkan
  speed (no speed claimed here).
- Post-review fix (same session): attention sentinel
  -3.4028235e38, NaN/Inf eps+base rejection matching
  compute.mojo, header claim softened; re-run
  a084_run_all_fix.log identical 588/1/2 of 591.
