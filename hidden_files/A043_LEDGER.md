# A-043 Ledger — CPU fused attention (team-02)

- Team: 02 (lead + 6 Mythic Engineering sub-agents, all mustered
  clean, no rate limit; lead executed the device work serially).
- Worktree: /home/volmarr/aesir-team-02, branch yrsa/aesir-team-02.
- Step 1 verified: A-034 banked in the seat log by subject
  (dfcee134 "A-034: Deterministic replay").
- Base: seat main d8c57f2a (A-042 banked, 42 of 216;
  git ls-remote at the seat == d8c57f2aaba791217f78cf8e9afb55a15fdcfbe2,
  verified this run). Worktree reset --hard onto that base;
  CAMPAIGN_STATE.md + team hidden_files extras (a016/,
  a034_battery_done.txt, a034_suite_done.txt, replay_a034)
  preserved via /tmp/t02_a043_preserve and restored; the new
  base's tracked hidden_files kept.
- Status: DONE 2026-11-12 — built, benched before/after,
  parity-proved, suite-run, committed on yrsa/aesir-team-02.
  NOT merged, NOT pushed — keeper banks in roadmap order.
- Roadmap text: "Current fused attention measured; SIMD/layout
  gaps fixed. Acceptance: before/after timings + reference
  parity." Census basis: A-037 row C-002, flash_attention_gqa
  17.93% of decode self-time.
- Filed numbers doc: docs/bench/A043_FUSED_ATTENTION.md
  (sha256 8bdaa6ab32e35e8bdbc61f50d58ab273cc53e94d5c5d980990cf9beb5772918e).

## Gaps found at base (all in flash_attention_gqa, compute.mojo)

The production fused-attention body was fully scalar, unlike
flash_attention_2 in the same file (width-16 SIMD + tails):
(1) QK^T dot per-element scalar, re-loading and re-casting the
query row from F16 for every key position; (2) P*V accumulate
per-element scalar through the heap accumulator; (3) acc
zeroing and final normalization per-element scalar; (4) the
online-softmax rescale exp(running_max - next_max) evaluated
every position although exactly 1.0 when the max did not move.

## What A-043 changed

- aesir_engine/core/compute.mojo — flash_attention_gqa only:
  query head preloaded once into an F32 scratch row (qbuf);
  QK^T dot, P*V accumulate, acc zeroing and final normalization
  run width-16 SIMD (simd_w_f32) with scalar tails; the rescale
  exp() is skipped when next_max == running_max (bit-exact,
  exp(0)==1). Signature, validation, defaults, and the
  online-softmax recurrence unchanged. Only numerics change:
  QK^T reduction order (per-chunk reduce_add) — the accepted
  fast-path class of A-038/A-042.
- aesir_engine/tests/bench_fused_attention_a043.mojo —
  standalone bench (NOT in run_all): production vs an in-file
  verbatim copy of the pre-A-043 scalar body, fixed-seed LCG
  fixtures (0xA043), CLOCK_MONOTONIC, median of 7 reps.
- aesir_engine/tests/test_fused_attention_a043.mojo — 5 cases
  registered in run_all (pin 403 -> 408).
- docs/bench/A043_FUSED_ATTENTION.md — filed numbers.
- Run scripts: hidden_files/run_a043_bench_before.sh,
  run_a043_bench_after.sh, run_a043_suite.sh (team-02's A-034
  gate shape, 6 shims, gfx1151).

## Before / after timings (bench, ns per call, decode shape)

| Shape | Before | After | Speedup |
|---|---|---|---|
| seq 128, hd 64, q8:kv2 | 79,833 | 12,728 | 6.27x |
| seq 512, hd 64, q8:kv2 | 318,992 | 50,595 | 6.30x |
| seq 1024, hd 64, q8:kv2 | 639,123 | 101,257 | 6.31x |
| seq 512, hd 128, q32:kv8 | 2,439,189 | 385,737 | 6.32x |
| seq 256, hd 40, q6:kv3 | 82,409 | 26,959 | 3.06x |
| seq 512, hd 64, q8:kv8 | 325,245 | 52,310 | 6.22x |

Logs: a043_bench_before.log (sha256 45aca11497edcb80...),
a043_bench_after.log (sha256 0694273620c53363...). Before the
fix the production leg matched the in-file scalar leg to ~0.1%
and was bitwise-identical to it on every element — the
reference is the same math, so the after comparison is honest.

## Parity evidence

- Bench (prod vs verbatim scalar body, identical buffers),
  after: 511/512, 511/512, 511/512, 4091/4096, 240/240,
  511/512 bitwise; max abs diff <= 1.53e-05 (<= 1 F16 ULP at
  these magnitudes).
- Suite cases (all PASS, a043_run_all.log): reference
  512/512 bitwise (max 0.0); dyadic 256/256 bitwise (exact by
  construction under any reduction order); tail40 240/240 and
  tail24 96/96 bitwise; modifiers (attn_scale 0.05, softcap
  8.0, sliding window 5 @ query_pos 12) 128/128 bitwise; long
  (seq 300, hd 128, q16:kv4) 2043/2048 bitwise, max abs diff
  6.10e-05 <= the filed 0.01 bound.
- End-to-end raw-oracle (CPU vs CPU, RAW prompt): the A-034
  replay battery rebuilt against the A-043 kernel reproduces
  the pinned A-004 oracle TOKEN-EXACTLY — GREEDY FNV-1a
  7bb54597001a24e0; seeded streams also unchanged (SEEDED
  cd2bc2d155dd6f3e, ALTSEED c55ae7749fd98274); A034_REPLAY:
  PASS, BUILD/RUN exits 0. Run-to-run file diff: 8 lines, all
  A-036 AESIR_TIMING_JSON wall-clock lines, 0 other lines
  (verified by filtered diff count).

## E-MASTER suite (run_a043_suite.sh, gfx1151, run_all.mojo)

- hidden_files/a043_run_all.log (sha256 29f668ec677effb2...):
  405 passed / 1 failed / 2 skipped / 408 total = baseline
  400/1/2/403 + exactly the 5 new cases, all passing
  (attention.gqa_simd_reference_parity,
  attention.gqa_simd_dyadic_bitwise,
  attention.gqa_simd_tail_parity,
  attention.gqa_simd_modifiers_parity,
  attention.gqa_simd_long_parity). Sole failure the tolerated
  pre-existing gguf.tensor_directory_interface (J-022 drift);
  skips the 2 pre-declared. Zero regressions.

## Bugs found / fixed in scope

- Bench/test harness bug (mine, not engine): first bench build
  failed — f32 not imported alongside f16 from core.mimir_well;
  fixed in the bench import line (the test file imports both).
- No engine bug found. Nothing left unfixed.
- Transfer note: two multi-chunk file.write attempts for the
  test file failed their sha256 guards (re-emission slips in
  plain base64, discarded cleanly both times); the file landed
  byte-exact via the gzip + per-piece sha256 route
  (final sha256 fd21bd951f8b449a... == local source).
