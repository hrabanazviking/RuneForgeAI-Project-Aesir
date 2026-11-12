# A-052 Ledger — Long context on CPU (team-02)

- Team: 02 (lead + 6 Mythic Engineering sub-agents, read-only scouting)
- Worktree: /home/volmarr/aesir-team-02, branch yrsa/aesir-team-02
- Step-1 verification: A-043 verified banked in the seat log (c19f7a5a in /home/volmarr/aesir-forge); worktree reset --hard onto the seat tip before building.
- Base: 9167a21fca41faf9c46dfaa97f15818585ed6ae5 (main, A-001..A-051 banked, 51 of 216; git ls-remote verified at reset)
- Status: DONE 2026-11-12 — built, benched, suite-green, committed on the team branch. NOT merged, NOT pushed — keeper banks in roadmap order.
- Roadmap text: "Long context on CPU. 32k-token context run: KV growth, correctness spot-checks at depth. Acceptance: run completes; depth probes (needle-style) pass at filed rates."
- Filed numbers doc: docs/bench/A052_LONG_CONTEXT_CPU.md (sha256 b82b28e2721b9461f2fcf0187b8d40f745955ef2e29c90efe764cdc398aaa50e)

## What A-052 changed

- aesir_engine/core/long_context_cpu.mojo (new): the one shared implementation — KV growth composed from core/kv_account census arithmetic, session-cap verdict, filed needle depths/values, stateless dyadic distractor pattern, probe grading at the filed tolerance (max abs diff <= 0.010) and rate arithmetic.
- aesir_engine/tests/test_long_context_a052.mojo (new): six E-MASTER cases (below).
- aesir_engine/tests/bench_long_context_a052.mojo (new): the timed 2-layer form of the same run.
- aesir_engine/tests/run_all.mojo: imports + six run_case lines; pin re-marked 435 -> 441 in the finish comment (ledger.finish(441)).
- docs/bench/A052_LONG_CONTEXT_CPU.md (new): filed numbers + honest limits.
- hidden_files/: this ledger, a052_bench.log, a052_run_all.log, run_a052_bench.sh, run_a052_suite.sh.

## The boundary found at base (filed, not hidden)

- The engine session/generation path clamps context to 16,000 (HOST_RUNTIME_CONTEXT_CAP; aesir.mojo MAX_RUNTIME_CONTEXT in _run_generation, mirrored in core/inference.mojo). A 32,768-token session does not run end-to-end through AesirEngine today. A-052 proves the 32k run at the KV + attention layer the session path is built on and files the verdict in code (session_cap_verdict: 32768 -> exceeds-session-cap). Lifting the session cap is a session-policy change, recorded as immediate follow-on work in CAMPAIGN_STATE.md — not a KV/attention defect; no engine bug was found in this slice.

## Bench (tests/bench_long_context_a052.mojo, hidden_files/a052_bench.log sha256 b2631032fb7f00b9a568d9d31262e122b30edc06dd960b7ae06b0568d1c4ccf9)

- Growth (census-priced): 512 B/token at the bench shape (2 layers, 1 KV head, hd 64) -> 16,777,216 B at 32,768; headline shape (32 layers, 8 KV heads, hd 128) 131,072 B/token -> 4,294,967,296 B (4 GiB) at 32,768. Exactly linear.
- Fill: 65,536 KVCache.append calls (2 x 32,768) in 47.65 ms wall, 727 ns per append including pattern generation. Run completes.
- Readback: 3,072 exact checks (12 positions x 64 dims x K/V x 2 layers, all needle depths + both ends): 0 mismatches.
- Needle probes: 14/14 PASS (7 depths x 2 layers) through production flash_attention_gqa over the full 32,768 positions; every probe max abs diff 0.0 (filed tolerance 0.010); rate 10,000 bp; ~0.41 ms per full-32k decode-step probe.

## E-MASTER suite (hidden_files/run_a052_suite.sh, gfx1151, run_all.mojo)

- Gate run (run 2): 438 passed / 1 failed / 2 skipped / 441 total = baseline 432/1/2/435 + exactly the 6 new cases, all passing (long_context.growth_account, long_context.session_cap_verdict, long_context.depths_patterns, long_context.probe_grading, long_context.kv_growth_execution, long_context.needle_probes). Log hidden_files/a052_run_all.log (sha256 f3d08f5a498e47f3ecedcff066a02f67791c55a6141d6b4dfa57cf13534d0d75). Sole failure the tolerated pre-existing gguf.tensor_directory_interface (J-022 drift, roads A-165/A-121); skips the 2 pre-declared. Zero regressions.
- Run 1 (same tree except the test-expectation fix below): 436 passed / 3 failed / 2 skipped / 441 — the two extra failures were (a) my growth_account expectation error, fixed, and (b) resilience.state_vault_rejects_growth, a timing-sensitive case that passed in run 2 and in the a043/a049 gate logs on this machine; run 1 executed under heavy cross-team contention (a second full suite plus allocator probes on the same host). Verdict class: comparator/harness artifact (contention flake), evidenced by the clean re-run — not an A-052 regression (this slice touches no state-vault code).

## Bugs found / fixed in scope

- Bench/test harness bugs (mine, not engine): first bench build failed — f32 not imported alongside f16 from core.mimir_well (same slip class as A-043); fixed in both bench and test import lines.
- Test expectation bug (mine, not engine): growth_account expected kv_growth_bp(32767, 32768) == 9996; the correct floored value is 9999 (32767*10000//32768). Module arithmetic verified by hand and against the bench growth table; expectation fixed, case passes.
- No engine bug found. The session-cap boundary above is filed as follow-on work in CAMPAIGN_STATE.md, per the never-leave-a-bug rule.
