# A-105 LEDGER - Two-model fairness (team-26)

- slice: A-105 (Wave 12, Heterogeneous scheduling)
- date: 2026-11-13 (EST), host: purpleraider (ASUS ROG Flow Z13, gfx1151 / XDNA 2)
- team: team-26 (1 lead + 6 Mythic Engineering sub-agents)
- worktree: /home/volmarr/aesir-team-26, branch yrsa/aesir-team-26
- base: a1b414fa (banked main, 102 of 216, A-102 closure)
- KEEPER NOTE: the team lead built, benched and suite-tested this slice,
  then went silent (~25 min, no process, no file movement after the
  suite finished at 17:59 EST). The keeper performed the closing
  coordination (this ledger, the CAMPAIGN_STATE outcome, and the team
  branch commit) from the on-disk logs, per the keeper stall-guard
  mandate. All numbers below are read from the team logs on disk.

## Claim under test
Two models served concurrently share devices without starvation
(roadmap A-105 acceptance: fairness test with per-model latency bounds).

## Built (on disk in this worktree)
- aesir_engine/core/fair_scheduler.mojo - fair scheduler over the
  banked placement/governor surfaces.
- aesir_engine/tests/test_fairness_a105.mojo - 8 cases (sched.fairness_*).
- aesir_engine/tests/bench_fairness_a105.mojo - device fairness bench.
- run_all.mojo: +8 cases registered, finish pin 629 -> 637 on this base
  (seat union reconciles at banking).

## Bench evidence (hidden_files/a105_bench.log, sha256 51219ffd783d5eb5ef0555c8c5f5202513548fac7a011b8b60b73194d84f20df)
- Fixture shas verified before/after (bench_done marker present):
  Llama-3.1-8B Q4_K_M 7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c,
  stories260K F16 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3.
- Device execution on the real gfx1151: A105_DEVICE vendor=4098 (0x1002)
  type=1 radv=True; both models resident concurrently.
- 1:1 fairness-summary: steps=601 served=8792,2464 max_wait=0,1
  wait_bound=1 jain_x1000=759; digest 5437198860298189202, reproduced
  exactly by the reproducibility leg (A105_REPRODUCIBLE).
- 2:1 weighted: jain_x1000=926; digest 7970112662622540070.
- Device interleave: first_service_steps=1,2 (neither model starved);
  solo controls: both models receive the full budget alone.
- Verdict line in the log: A105_FAIRNESS: PASS, RUN_EXIT=0.

## Suite (E-MASTER, solo; hidden_files/a105_run_all.log, sha256 95adce21304ac896a4f2083f372b3286c05a3d972f304085f63afa2dbb2c56be)
- Counts read from the log: 634 passed / 1 failed / 2 skipped / 637 total.
- Sole failure: gguf.tensor_directory_interface (pre-existing J-022).
  No named intermittent fired. All 8 sched.fairness_* cases PASS.
- Baseline on a1b414fa was 626/1/2 of 629 (seat A-102 gate);
  634 = 626 + 8 new. Verdict: GREEN-TO-BASELINE.

## Gaps filed honestly
- No docs/bench/A105 doc was written by the lead before it went
  silent; the bench log + this ledger are the filed evidence.
- Bench attempt 1 log preserved (a105_bench_attempt1.log).
