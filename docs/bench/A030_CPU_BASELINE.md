# A-030 — CPU performance baseline (Z13, purpleraider)

Slice A-030, team-07, branch yrsa/aesir-team-07, base 05f61cd6 (A-028 banked).
Roadmap: docs/AESIR_Z13_MASSIVE_ROADMAP.md — "Tokens/s (prefill + decode)
for the pinned fixtures on the Z13 CPU path." This table is the number
every later wave is judged against (A-068 files prefill vs this; A-081
gate requires GPU decode >= 2x this decode baseline on 8B-class Q4).

## Fixture and method
- Fixture: stories260K.F16.gguf, sha256
  57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3
  (exact match to the A-004 / Capability Ledger pin; verified before
  the run from the team-07 copy in hidden_files/fixtures/).
- Driver: aesir_engine/tests/bench_cpu_baseline_a030.mojo (standalone,
  not in run_all), sha256
  765978678a5bcc2cae6b67cd53cb75d56143ee0a69d90bfc185ac9da5dc3aac2.
- Timing: CLOCK_MONOTONIC nanoseconds around forward loops only
  (load/tokenize excluded). 1 settle run discarded + 5 measured
  trials per config; table reports the median of 5.
- Correctness (raw-oracle discipline, CPU vs CPU): canonical prompt
  "One day, Timmy went to" token IDs 1,385,328,432,405,263,377,267
  exact; prefill last output 265 exact; all 32 greedy decode IDs
  exact vs the pinned llama.cpp oracle (A-004 pattern); batched
  64-token prefill last token 416 == per-token last token 416.
- Execution: CPU path only. gfx1151 is the compile target; no
  accelerator execution is claimed.

## Machine conditions (quiet window, verified)
- purpleraider, kernel 7.3.0-10-generic, Mojo 1.2.0 (2016d0cd).
- Bench run 2026-11-12T05:48-05:49 EST. Load average at start
  0.59/0.93/1.44, at end 0.20/0.55/1.15; zero other teams' mojo or
  pytest processes running during the window (checked by ps before
  launch; an earlier contended window at 05:41-05:43 with another
  crew's suite + lifthrasir pytest was NOT used).
- Full conditions + per-trial lines: team-07 hidden_files/
  a030_bench.log (sha256 4bc87fd361e931e13ae5ba5a0319b249e0229505c08
  08977648ee61008e750aae6) and hidden_files/a030_conditions.log.

## Baseline table (median of 5 trials, tokens/s)

| Config | Tokens timed | Median tok/s | Trial range tok/s |
|---|---|---|---|
| Prefill, 8-token prompt, per-token forward_pass | 8 | 10,962.7 | 10,742.1 – 11,018.4 |
| Prefill, 64-token prompt, per-token forward_pass | 64 | 9,107.0 | 9,051.2 – 9,118.4 |
| Prefill, 64-token prompt, batched forward_pass_batched | 64 | 16,334.5 | 14,580.6 – 18,327.1 |
| Decode, 32 greedy steps (after 8-token prefill) | 32 | 8,745.9 | 8,403.5 – 8,785.1 |
| AesirEngine facade, generate_tokens end-to-end (8 in, 32 out) | 32 out | 8,236.6 | 8,197.1 – 8,261.4 |

Notes: batched prefill is ~1.8x per-token prefill at 64 tokens and
shows the widest trial spread; the facade row includes tokenize +
prefill + decode + detokenize, so it sits below the pure decode row
as expected. Verdict: A030_BENCH: PASS (MOJO_EXIT=0).
