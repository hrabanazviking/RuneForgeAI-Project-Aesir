# A-045 Ledger -- CPU parity battery (team-03, Wave 5 closer)

- Base: 40ce2d88e643e6422c3ce9e19708db50af9e4f9b (banked main, 44 of 216, A-001..A-044). Restart: previous lead cancelled mid-build; fresh lead + 6 Mythic Engineering sub-agents (all returned, no rate limits) verified the uncommitted sink diff + 19 fixtures from disk and continued -- nothing reset.
- Deliverables: (1) logit-row sink completed (core/mimir_well.mojo KVCache.capture_logit_row/last_logit_row + core/inference.mojo capture in forward_pass, by previous lead, verified in diff); (2) AesirEngine.teacher_forcing_logit_rows (aesir.mojo) -- per-token teacher-forcing through the standard forward path, reusable by every later backend; (3) core/parity_battery.mojo -- shared rank/gap/verdict arithmetic; (4) tests/bench_parity_battery_a045.mojo (sha256 829f60c23b877d8ec6748f10ff8561851151d342e995be5115a5367911060136) -- reusable battery driver; (5) tests/test_parity_battery_a045.mojo -- 5 E-MASTER cases; run_all pin 413 -> 418; (6) filed table docs/bench/A045_CPU_PARITY_BATTERY.md.
- Oracle pin verified before runs: stories260K.F16.gguf sha256 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3. CPU engine vs CPU comparator only; RAW prompt, no template; oracle backend recorded per run (oracle_rank1 32/32 in every run = comparator stable).

## Battery rows (every row judged; log hidden_files/a045_battery.log sha256 216684ced747f50ee77ec0bc604ac19d7904fd0085c4724341e0d6e90d4d2268; probe hidden_files/a045_probe.log sha256 606a0109ade071f4003816170be3351f6557b94ad6ba8bfdc0c83808022f4b0b)

- F16: faithful 32/32, greedy 32/32 -- FAITHFUL (oracle self-check, exact).
- BF16: faithful 32/32, greedy 32/32 -- FAITHFUL (tensors genuinely BF16 type 30, distinct data).
- Q8_0: faithful 32/32, greedy 32/32 -- FAITHFUL.
- Q4_0: 27 faithful / 3 near-tie / 2 divergent (pos19 rank3 gap0.539 cand_top432; pos22 rank2 gap1.570 cand_top373) -- DIVERGENCE, verdict class QUANT NOISE: single-position, small-gap, 4-bit quant on a 260K model; free-run stays coherent story text. No engine defect indicated (same positions are rank1/gap0 in F16 oracle rows).
- Q5_0: 31/1/0, worst rank 2, max gap 0.0156 -- FAITHFUL + NEAR-TIE. Greedy 16/32 is the near-tie flip at gen pos15 compounding in free-run, then partially re-converging; TF verdict governs.
- Q2_K: numbers identical to Q4_0 in every digit -- FIXTURE ARTIFACT: tensor-data hash e10223f79391 identical to Q4_0 file, tensors type 2 (Q4_0). True Q2_K NOT measured. Road: A-046 quant census must produce a true Q2_K fixture (converter fell back on 64-wide tensors).
- Q3_K_M: 29/1/2 (pos19 rank3 gap0.430; pos22 rank5 gap1.383) -- DIVERGENCE, verdict class QUANT NOISE (as Q4_0; K-mix fixture: Q4_0/Q5_0/Q5_1 tensors, no Q3_K blocks at this size -- converter behaviour, filed).
- Q4_K_M: 31/1/0 -- FAITHFUL + NEAR-TIE (K-mix fixture, mostly Q5_0 tensors).
- Q5_K_M: 32/0/0 -- FAITHFUL (K-mix fixture, mostly Q5_1 tensors).
- Q6_K: 32/0/0 -- FIXTURE ARTIFACT: tensor-data hash 8507f7a4d155 identical to Q8_0 file, tensors type 8 (Q8_0). True Q6_K NOT measured (its dequant/GEMV parity is already proven at block level by A-040 E-MASTER cases). Road: A-046.
- IQ1_S, IQ1_M, IQ2_XXS, IQ2_XS, IQ2_S, IQ3_XXS, IQ3_S, IQ4_NL, IQ4_XS (9 rows): every run exits 1 with "gemm_iq4_nl: invalid shape or incomplete quantization block" before any logit row -- DIVERGENCE, verdict class FIXTURE LIMITATION: (a) files collapse to 2 distinct payloads (97467401a9c2 / 20eb8c11f9ee) of IQ4_NL-typed (type 20) fallback tensors, not the labelled formats; (b) stories260K inner dims 64/32 cannot satisfy gemm_iq's 256-value super-block requirement (core/compute.mojo:2370) -- end-to-end IQ on this fixture is impossible by construction. NOT an engine dequant defect: E-MASTER quantization.iq* known-value + iq_simd parity cases pass in the A-045 suite below. Immediate next work recorded in CAMPAIGN_STATE.md: A-046 must add a >=256-wide IQ fixture set and re-run this battery driver for true IQ rows (graded on rank/gap/coherence, never token-exactness).
- Prompt-internal positions (informational, excluded): 5/7 faithful+near-tie even for F16 -- prompt-boundary comparator class, per standing law.

## E-MASTER suite (hidden_files/run_a045_suite.sh, gfx1151, run_all.mojo, pin 413 -> 418)

- hidden_files/a045_run_all.log sha256 de88058910309ddc9200453c02899ce6a0e6d7996a8c487415f8db3a521c5dbc -- 415 passed / 1 failed / 2 skipped / 418 total = baseline 410/1/2/413 + exactly the 5 new parity.* cases, all PASS (parity.top_token_ties, parity.rank_arithmetic, parity.gap_arithmetic, parity.verdict_bands, parity.logit_sink_defaults). Sole failure = pre-existing gguf.tensor_directory_interface J-022 drift (roads A-165/A-121). Skips = the 2 pre-declared.

## Bugs / follow-ups

- Fixture-generation defects discovered (previous lead's 08:55 fixtures): Q2_K and Q6_K files contain fallback-type tensor bytes identical to Q4_0/Q8_0; all IQ files contain IQ4_NL fallback payloads in 2 groups. Not fixed in this slice -- regenerating true fixtures needs a >=256-wide source model, which does not exist on this machine; recorded as immediate next work for A-046 (quant census) in CAMPAIGN_STATE.md, with the battery driver ready to re-run.
- No README touched. No merge/push -- keeper banks in roadmap order.
