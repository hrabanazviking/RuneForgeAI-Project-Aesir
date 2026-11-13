# Team-11 CAMPAIGN_STATE — Aesir Z13 Forge

- Team: team-11 (NEW seat, expansion to 27 teams, Volmarr order 2026-11-13 ~05:59 EST)
- Mustered: 2026-11-13 ~06:20 EST by keeper tick aesir-z13-forge-keeper
- Worktree: /home/volmarr/aesir-team-11, branch yrsa/aesir-team-11
- Base: 3cfc43702ef1c3d96758d1f799a5946515ffadef = Banking closure: A-078 banked (78 of 216) — banked main, verified by git ls-remote at muster
- Assigned slice: A-081 — Part III gate. Acceptance: GPU path declared primary for decode ONLY if it beats the A-030 CPU baseline by >=2x on the 8B-class Q4 fixture decode; otherwise an honest verdict with the blocking causes named as new road-slices. Ledger updated either way.
- Rules: work ONE slice only in this worktree; never share a checkout; never merge or push from this worktree (keeper banks in roadmap order at the seat); never touch README.md; NO Docker.
- Banking order note: A-079 and A-080 are ahead in roadmap order and are NOT yet banked. A-081 builds in parallel; it banks only after them, in roadmap order. This is a gate/verdict slice — an honest negative is a complete result.
- Correctness law: raw-oracle discipline (teacher-forcing rank + logit gap on RAW prompts, CPU vs CPU comparator only, near-tie rank <=2 sub-logit = faithful, IQ graded on coherence); comparator artifacts are a verdict class; accelerator-visible != accelerator-run — device-execution evidence required.
- Never leave a discovered bug unfixed: fix in-slice or record as immediate next work here.
- Status at muster: worktree created clean from banked main; lead spawn requested by keeper this tick.

## A-081 result — Part III gate (counts READ FROM LOGS)
- Status: A-081 BUILT + TESTED + COMMITTED 2026-11-13 on yrsa/aesir-team-11, base 3cfc4370 (78 of 216 banked). Awaiting banking by the keeper in roadmap order AFTER A-079 and A-080. Do NOT merge or push from this worktree.
- Crew: lead solo on device (no sub-agent spawn available in this seat).
- VERDICT: HONEST NEGATIVE — GPU path NOT declared primary for decode. Fresh same-run measurement on the pinned 8B Q4 fixture (sha256 7b064f58..557c, verified in-worktree): GPU decode median 1.497 tok/s vs CPU decode median 6.958 tok/s on the identical fixture (RAW prompt, greedy 32, 3 reps each; log hidden_files/a081_bench.log sha256 43891878..). GPU ids == CPU ids 32/32 exact — correctness is not the blocker. Reading A (2x A-030 baseline 8,745.9 = 17,491.8 tok/s): FAIL ~11,700x short. Reading B (same-fixture 2x CPU): FAIL, ratio 0.215x.
- Blocking causes named as road-slices in docs/bench/A081_PART_III_GATE.md + hidden_files/A081_LEDGER.md: R-A081-1 total device weight residency vs the 128-slot shim cap (stream 377 of 670 ms/step, 56%); R-A081-2 per-step dispatch/host round-trips (~485 dispatches/step, host KV pack linear in KV, host RoPE permute); R-A081-3 roadmap-wording observation (A-030 is a 260K-fixture number; future bars same-fixture) — recorded, not a verdict input.
- Deliverables: tests/bench_part3_gate_a081.mojo (standalone, +0 cases, pin untouched) + docs/bench/A081_PART_III_GATE.md + CAPABILITY_LEDGER.md NEW section 24 / Z13-P3-081 + hidden_files/A081_LEDGER.md.
- Suite: attempt 1 = 563/3/2 of 568 (J-022 + the two named intermittents: hip_stream MEM-004 class + memory.budget_live_meminfo_pressure, the item under seat bisect); re-run = 565 passed / 1 failed / 2 skipped / 568 total EXACT vs the A-078 seat baseline, sole failure pre-existing J-022 drift (roads A-165/A-121), skips the 2 pre-declared. Logs: a081_run_all.log (sha256 42ba2f26..) + a081_run_all_attempt1.log preserved.
- Bugs: none discovered in this slice's scope (no engine code changed). The attempt-1 memory.budget failure is one more data point for team-03's instrumented bisect (seat runs 10/11/12) — recorded here, owned there.
- Deferrals: none outstanding. Heavy runs were sequenced around team-10's A-080 suite (bench ran in a verified quiet window; suite attempt 1 waited for team-10's run_all to finish; re-run launched ps-clean).
