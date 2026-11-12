# A-042 Ledger — CPU prefill batching audit (team-01)

- Team: 01 (lead + 6 Mythic Engineering sub-agents; 3 recon
  sub-agents corroborated GEMM/prefill code locations, Wave-5
  precedents, and the E-MASTER harness shape independently).
- Worktree: /home/volmarr/aesir-team-01, branch yrsa/aesir-team-01.
- Base: seat main 56d5606f (A-039 banked, 39 of 216; read fresh
  from git at the seat this run). Worktree reset --hard onto that
  base; prior CAMPAIGN_STATE.md/hidden_files preserved via
  /tmp/t01_preserve and restored (tracked hidden_files of the new
  base kept; team-01 extras merged back).
- Status: DONE 2026-11-12 — built, benched, fixed, suite-run,
  committed on yrsa/aesir-team-01. NOT merged, NOT pushed —
  awaiting keeper banking in roadmap order (A-040, A-041 bank
  first).
- Roadmap text: "CPU prefill batching audit. Batched GEMM vs
  row-by-row on Zen 5 measured honestly (the lessons say prefill
  buys less — verify, don't assume). Acceptance: numbers filed;
  the better path is the default."
- Filed numbers doc: docs/bench/A042_PREFILL_BATCHING_AUDIT.md
  (sha256 87c38182228db514...).

## Census mapping

A-037's census is a decode loop; it names no prefill row. The
GEMM-family row it does name, C-001 (_gemm_f16_dense_range,
22.21% self-time), is also the multi-row prefill GEMM body, and
the grouped row C-008 (per-dispatch thread/env re-read, 12.81%)
is the fixed per-call cost this audit's dispatch-level numbers
implicate. A-042 self-profiled prefill at kernel + dispatch +
end-to-end levels, per the A-038/A-039 precedent for slices the
F16 census does not exercise.

## What was built

- core/prefill_batching.mojo (new, sha256 116657de3731e41a...):
  the policy that makes the better path the default —
  prefill_path_for_rows (rows >= PREFILL_BATCHED_MIN_ROWS = 2 →
  PREFILL_PATH_BATCHED; 1 row → PREFILL_PATH_ROW_BY_ROW, the
  decode shape; rows <= 0 raises, fail-closed),
  prefill_uses_batched, prefill_default_chunk_cap /
  PREFILL_DEFAULT_CHUNK_CAP = 256 (mirrors the facade default in
  aesir.mojo _prefill_batch_cap; AESIR_PREFILL_BATCH=1 remains
  the operator override to the per-token loop).
- core/compute.mojo (sha256 9b306df54e3d1451...): the Q8_0
  fast-range fix (below). No signature, dispatch, or validation
  changes; _gemm_q8_0_range (bit-exact serial) untouched.
- aesir_engine/tests/test_prefill_batching.mojo (5 cases,
  registered in run_all; pin 389 -> 394): policy boundaries +
  fail-closed raise; dense range parity (bitwise, general data);
  dense public-dispatch parity (bitwise); Q8_0 fast-vs-GEMV
  range parity (bitwise, dyadic); Q4_0 public parity (bitwise).
- aesir_engine/tests/bench_prefill_batching_a042.mojo —
  kernel + public-dispatch bench (standalone, A-038 pattern:
  in-file LCG seed 0xA042 fixtures, CLOCK_MONOTONIC, median of
  reps after warmup, single-thread direct range calls for the
  kernel legs).
- aesir_engine/tests/bench_prefill_e2e_a042.mojo — end-to-end
  bench on the pinned stories260K fixture (A-030 pattern:
  1 settle + 5 trials, median; batched last token must equal
  per-token last token at both lengths).
- Run scripts: hidden_files/run_a042.sh (kernel bench),
  run_a042_e2e.sh, run_a042_suite.sh (canonical 6-shim staging,
  gfx1151), all cloned from the team's previous gate scripts.

## Bug found and fixed in-slice (the audit's central finding)

_gemm_q8_0_fast_range — the multi-row Q8_0 path every Q8_0
prefill takes — decoded each block scalar-ly (32 loads + casts)
and its dot gathered SIMD vectors lane-by-lane from scalar
loads. Pre-fix bench (first run_a042.sh run; its log was
overwritten by the post-fix rerun, rows transcribed here from
the log read back in-session): batched-vs-row-by-row speedup
0.124 (288x512 r8), 0.135 (r32), 0.111 (r128), 0.152 (1024x1024
r8), 0.162 (r32), 0.164 (r128), 0.191 (2048x2048 r32), 0.194
(r128) — batched Q8_0 prefill was 5-9x SLOWER than per-row
A-038 GEMV calls at every shape, parity bitwise throughout.
Fix: width-16 vector decode (two int8 vector loads widened to
F32, scaled, vector-stored to the scratch row) + the dense
range's dot (width-16 loads, per-chunk reduce_add, scalar
tail). Post-fix batched speedups: 0.88/0.95/0.96 (288x512),
1.06/1.15/1.17 (1024x1024), 1.35/1.38 (2048x2048 r32/r128);
the batched path itself is 7-9x faster than before the fix
(2048x2048 r128: 224,245,862 ns → 31,500,334 ns). Post-fix
parity on the non-dyadic bench fixture: >= 99.7% bitwise,
max abs diff <= 0.0625 — summation-order only, the accepted
fast-path class A-038 filed (its filed bound: <= 10 f16 ULP
at K=4096, >= 99.3% bitwise). On dyadic data the suite case
is bitwise, as are the A-038 multirow regression cases the
suite still passes.

## Audit numbers (post-fix; medians; full rows in the doc)

- Dense F16 range: 1.00x at every shape/rows (bitwise parity) —
  batching buys nothing inside the dense body; the wave lesson
  holds for the kernel.
- Dense public dispatch: 2.34x (288x512 r128), 23.1x
  (1024x1024 r32) — the win is paying par_for + per-dispatch
  fixed costs once per chunk (cf. census C-008).
- Q8_0 public dispatch: 2.12x (288x512 r128), 26.2x
  (1024x1024 r32).
- Q4_0 legacy: 1.00x, bitwise — no distinct batched body
  exists (see next work).
- End-to-end (stories260K F16, fixture sha256
  57a81ed1c8b032ba...e3, ctx 128): prefill64 per-token
  9,140 tok/s vs batched 18,359 tok/s (2.01x); prefill128
  per-token 7,314 vs batched 8,062 (1.10x); last token 416 on
  both paths at both lengths. Corroborates A-030's Z13-era
  baseline shape (9,107 / 16,334.5 on their window). The e2e
  log's second SPEEDUP line is mislabeled "prefill256" in the
  first successful run (a harness string typo, fixed in the
  committed source; the config lines in the same log read
  prefill128 and the medians above are the 128-token leg —
  the fixture context is 128, so no 256-token leg exists).
  An earlier e2e attempt with a 256-token leg failed on
  KVCache capacity (ctx 128) — bench design error, corrected
  to 128; not an engine defect.

## Fixture provenance

- Kernel fixtures: generated in-file by fixed-seed LCG
  (0xA042), byte-reproducible from the bench source alone
  (sha256 4f72591951fe0aee...). Kernel-level slice: no prompt
  surface exists, so raw-oracle discipline reduces to exact
  input identity, guaranteed by construction; both paths run
  on identical buffers.
- E2E fixture: stories260K.F16.gguf sha256
  57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3
  (verified in-worktree; copied from team-04's identical-hash
  fixture into hidden_files/fixtures/ — team-01's copy had not
  survived an earlier reset).

## E-MASTER suite (run_a042_suite.sh, gfx1151, run_all.mojo)

- Gate run (hidden_files/a042_run_all.log, sha256
  16bc6dfc1c8c2c06...): 391 passed / 1 failed / 2 skipped /
  394 total = baseline 386/1/2/389 + exactly the 5 new cases,
  all passing (prefill.batching_policy,
  prefill.batching_dense_range_parity,
  prefill.batching_dense_public_parity,
  prefill.batching_q8_range_parity,
  prefill.batching_q4_0_public_parity). Sole failure the
  tolerated pre-existing gguf.tensor_directory_interface
  (J-022 drift). Two full runs were made (the second after
  removing a constant-folded comparison that drew a compiler
  warning in the policy case); counts identical in both.
- Bench logs: a042_bench.log sha256 6a99f0746a1438...,
  a042_e2e.log sha256 070758feb2e5efe7... (e2e log predates
  the SPEEDUP label typo fix; see the note above).

## Next work (recorded, not silently left)

- Legacy scalar GEMMs (Q4_0/Q4_1/Q5_0/Q5_1/Q8_1/FP8 in
  compute.mojo; GPTQ/AWQ/ExL2/HQQ/SmoothQuant wrappers in
  external_quantization.mojo) have no batched body: multi-row
  calls re-decode weights per row, serially, unthreaded.
  Building decode-once fast ranges for them is a build
  campaign of its own (the K-quant analogue is A-040's road);
  A-042's acceptance is the audit + the default, so this is
  filed here and in CAMPAIGN_STATE.md as team-01's recorded
  next-work item rather than half-built inside the audit.
- The A-033 taxonomy gap (no dedicated
  execution-not-implemented error code, roaded to A-089)
  remains recorded in CAMPAIGN_STATE.md, untouched by this
  slice's scope.
- Untracked aesir_engine/hip_bridge.c remains untracked and
  unreferenced, as in every prior team-01 slice.
- No README touched. No merge/push — keeper banks in roadmap
  order.
