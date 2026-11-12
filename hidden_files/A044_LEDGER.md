# A-044 Ledger -- Sampling cost proof (team-06)

- Base: d8c57f2a (seat main, A-042 banked, 42 of 216; verified at reset: seat HEAD == git ls-remote == d8c57f2aaba791217f78cf8e9afb55a15fdcfbe2). Previous team-06 work verified banked in the seat log before reset (A-035 among A-031/A-032 lines). Worktree reset --hard onto d8c57f2a; CAMPAIGN_STATE.md preserved via /tmp/t06bak044 and restored; tracked hidden_files of the new base kept (0 extras needed restoring); stray untracked aesir-residency-2LahNV left untouched (pre-existing, not identified as this slice's artifact).
- Slice: A-044 -- Sampling cost proof. Roadmap: "CPU sampling measured per token. Acceptance: either <1% of token time proven, or the hotspot is fixed and re-measured." Cites A-037 census row C-006 (sample_token_from_logits, 2.56% self-time).
- Filed table: docs/bench/A044_SAMPLING_COST_PROOF.md (full method, tables, fix description).

## Measurement (pre-fix)

- Real engine (A-036 phase bench, stories260K.F16.gguf sha256 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3, facade standard run, raw prompt, 32 greedy IDs oracle-exact, PASS): sample_ns 79,704 / 79,482 / 79,480 over 3 reps; share of generation time (sample / (prefill+decode+sample), disjoint A-036 accounting) 4.02% / 4.14% / 4.16%, median 4.14% -- NOT <1%, so the fix half of the acceptance was triggered. Log: hidden_files/a044_pre_phase.log sha256 84a38e6bddd64a7dd4db3655a29405df71f48ed0d1eb20703b981fb0df39a8d5.
- Direct microbench (tests/bench_sampling_a044.mojo, timer outside the loop, deterministic synthetic F16 logits, worst-case candidate window): greedy 2,420 ns/call at vocab 512 and 154,032 ns/call at vocab 32,000; stochastic (temp 0.8, top_k 40, top_p 0.95) 26,128 ns/call at 512 and 63,733,161 ns/call at 32,000; stochastic untruncated 6,100 / 374,643 ns/call. Log: hidden_files/a044_pre_micro.log sha256 ae6847668d3f0e852dc6c54ced87459ab04250580a0b20db6c1cf98e4c679800.

## Fixes (aesir_engine/core/sampler.mojo, sha256 35e827855466d07b270514ee92fd4260c1dae95e4a159be5cb37c9800be2da37)

1. Greedy argmax: width-16 SIMD sanitized max (_simd_logits_max) + first-index scan (_simd_argmax_first) on the no-suppress path. Exactness by construction: finite F16 iff |x| <= 65,504; the pass also reduces min and sum, so any non-finite lane (or NaN-poisoned sum) is detected and the maximum is recomputed with the original scalar sanitize loop, bit-identical for every input; lowest-id tie break preserved (first raw match on the all-finite path). Suppress path = original scalar loop unchanged. The stochastic max scan reuses the same helper.
2. sort_candidates_descending: stable merge sort O(n log n) (ties keep original order -- merge takes the left run on >=, matching the old insertion sort), O(n) already-descending fast path, original insertion sort kept for n <= 24.
3. apply_top_k: quickselect of the winning set in average O(n) under the exact stable total order (logit descending, original position ascending on ties), winners collected in original order, only the kept k sorted. Result is element-for-element the first k of the old full stable sort.

## Re-measurement (post-fix, identical harnesses)

- Real engine: sample_ns 5,549 / 4,849 / 4,394; share 0.29% / 0.26% / 0.24%, median 0.26% -- <1% PROVEN for the standard run. Sample time per run down 16.4x (median). A036_BENCH PASS, 32 greedy IDs oracle-exact (CPU vs CPU, raw prompt -- raw-oracle discipline; no template comparator). Log: hidden_files/a044_post_phase.log sha256 f32aa868ec12b773bce907d46ac759f00241d4bc65a02d1609b063d9f712f1ec. Post-fix sample_ns still includes A-036 hook overhead (two allocating clock reads per call); true greedy sampler work at this vocab is 59 ns/call per the microbench.
- Microbench medians: greedy 59 ns (512, 41.0x) / 3,315 ns (32k, 46.5x); stochastic top-k/top-p 9,455 ns (512, 2.8x) / 478,755 ns (32k, 133.1x); untruncated 3,838 ns (512, 1.6x) / 232,197 ns (32k, 1.6x). ALL bench sinks (returned-id sums) identical pre/post for all six configs: 740,000 / 74,000 / 74,000 / 185 / 131,007 / 2,677,916. Log: hidden_files/a044_post_micro.log sha256 e712e9565d707249598c72a279c1848cd01ddb4edca5dd0f543e54a010a3be6e. Bench driver sha256 4f22c4a3bdc63494979cac1f4d2829b7c8c3c080fe3823e3908cbff00eee9dee.
- Remaining honest cost: candidate collection + untruncated softmax walk stay scalar O(vocab) (232 us/call at 32k worst-case flat window) -- linear, not the charged hotspot; filed in the docs table, not hidden.

## E-MASTER suite (hidden_files/run_a044_suite.sh, gfx1151, run_all.mojo, pin 403 -> 408)

- Run 1 (hidden_files/a044_run_all_run1.log sha256 f99dc6986e85af020ac49ba6c29fac2a7cb74e403303e8662cf30c314f693f2e): 404 passed / 2 failed / 2 skipped / 408 total. Failures: tolerated gguf.tensor_directory_interface (J-022) PLUS gguf.weight_residency_gpu_visibility (MEM-004 USE_AFTER_FREE) -- the exact flake team-06 filed in A-035 (same HIP host-registered area as the open A-020 bug; this slice touches no HIP/residency code). Per the A-035 guidance, re-ran once.
- Run 2 (hidden_files/a044_run_all.log sha256 b51ac178d98af25b9a8227c2e20edf39d49b9a8dff51a6bcaf910fc3d96d3b01): 405 passed / 1 failed / 2 skipped / 408 total == baseline 400/1/2/403 + exactly the 5 new sampling_cost.* cases, all PASS. Sole failure = pre-existing J-022 gguf.tensor_directory_interface (roads A-165/A-121). Skips = the 2 pre-declared.
- New cases (tests/test_sampling_cost_a044.mojo): sampling_cost.simd_max_parity, sampling_cost.greedy_argmax_parity, sampling_cost.sort_stable_reference, sampling_cost.topk_reference, sampling_cost.stochastic_determinism_large -- each checks a changed routine against an independent in-test reference of the original algorithm (tails, NaN/+Inf/-Inf, lowest-id ties, suppressed maximum, dense tie cutoffs, vocab-5000 seeded determinism over 128 draws).

## Bugs / follow-ups

- No new bug discovered. The weight_residency_gpu_visibility flake recurred once (run 1) and passed on re-run -- already tracked as the open A-020 HIP follow-up in CAMPAIGN_STATE.md; not fixed here (outside A-044 scope, already owned).
- No README touched. No merge/push -- keeper banks in roadmap order.
