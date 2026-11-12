# A-036 Ledger — Phase timing hooks (team-03)

- Slice: A-036 — Phase timing hooks. Load/prefill/decode/sample timings
  emitted as JSON by the engine. Acceptance: a standard run's JSON
  accounts for >=95% of wall time across phases. -> MET, MEASURED
  (see below; worst rep 99.75% against an independent external wall).
- Base: c9f0047ecd117d623bf72d22d38421ae853532eb (A-031 banked, 31/216)
- Branch: yrsa/aesir-team-03, worktree /home/volmarr/aesir-team-03
- Host: purpleraider (Ryzen AI Max+ 395 / Radeon 8060S gfx1151).
  CPU execution only; gfx1151 is compile target only, no accelerator
  execution claimed by any number here.

## What was built
- aesir_engine/core/phase_timing.mojo (new): PhaseTimings (disjoint
  load/prefill/decode/sample ns + wall + token counts), accounted /
  residual / coverage arithmetic, the >=95% gate predicate, and
  to_json() — the engine's emission. Clock: CLOCK_MONOTONIC via
  clock_gettime (same source as armvegr.util.now_ns, A-030/A-031).
- Disjointness: sampling is fused inside the forward passes, so every
  sample_token_from_logits call site in core/inference.mojo (6 sites:
  forward_pass x2, forward_pass_batched, gemma4, gemma4_batched,
  qwen35, qwen35_batched) is timed and accumulated into the
  per-request sink KVCache.sample_ns_total (new field in
  core/mimir_well.mojo, all constructors + copy). AesirEngine
  subtracts the sink deltas from the prefill/decode spans
  (disjoint_pure_ns), so accounted = load+prefill+decode+sample has
  no double counting by construction.
- AesirEngine (aesir_engine/aesir.mojo): __init__ times itself into
  load_ns (created_ns = construction start); _run_generation times
  the prefill span (prompt prep + tokenize + KV alloc + prefill
  forwards) and the decode span (generation loop), builds
  PhaseTimings with wall = now - created_ns, stores it on
  GenerationResult.timings, and prints one line per run:
  AESIR_TIMING_JSON: { ... } (3 emissions in the bench log).
- Tests: aesir_engine/tests/test_phase_timing.mojo, 4 E-MASTER cases
  (timing.phase_coverage_arithmetic, timing.phase_disjoint_pure,
  timing.phase_json_schema, timing.phase_kvcache_sink) — synthetic
  numbers, labelled synthetic; run_all pin 362 -> 366.
- Driver: aesir_engine/tests/bench_phase_timing_a036.mojo (opt-in,
  NOT in run_all), script hidden_files/run_a036_bench.sh.

## Fixture
stories260K.F16.gguf, sha256 verified in team-03:
57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3
— exact match to the pinned hash (copied from team-04's verified
fixture into hidden_files/fixtures/).

## Measured standard run (hidden_files/a036_bench.log, sha256
## 793405f5e931c84cbbc0166c3d302a7de8235fbfa6ddd44a22af7706700dcc24)
Standard run = AesirEngine facade on the fixture, greedy
generate_tokens("One day, Timmy went to", 32) — the A-030 facade
configuration; 3 reps, fresh engine per rep. Correctness: prompt 8
tokens, all 32 generated IDs equal the A-030/A-004 oracle (driver
raises on any difference; A036_BENCH: PASS, MOJO_EXIT=0).
Conditions: loadavg ~1.0-2.7, team-06's suite was finishing as the
bench started. Coverage is a ratio of same-run quantities and is
contention-robust; absolute times are NOT baselines.

| rep | load ms | prefill ms | decode ms | sample ms | accounted ms | wall (engine) ms | wall (external) ms | coverage vs engine wall | coverage vs external wall |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 7.387 | 0.366 | 3.367 | 0.080 | 11.200 | 11.202 | 11.228 | 99.98% | 99.75% |
| 1 | 6.994 | 0.326 | 3.328 | 0.080 | 10.727 | 10.728 | 10.742 | 99.99% | 99.86% |
| 2 | 7.137 | 0.320 | 3.289 | 0.080 | 10.826 | 10.827 | 10.839 | 99.98% | 99.87% |

External wall = driver's own CLOCK_MONOTONIC span around engine
construction + generation — it covers MORE than the JSON wall claim
(the JSON wall starts at construction entry; the external span also
includes the AesirEngine call setup), so coverage vs external wall
is the conservative figure. Residual (engine wall - accounted) is
0.000-0.001 ms per rep: in this facade run essentially all time
between construction start and generation end sits inside one of
the four phases; the gaps are result assembly and the timing
print itself. Verdict: acceptance MET with ~4.75 points of margin
on the worst (external, rep 0) figure.

Emitted JSON (rep 0, verbatim from the log):
{"timing_version":1,"load_ms":7.387,"prefill_ms":0.365,"decode_ms":3.367,"sample_ms":0.079,"accounted_ms":11.200,"wall_ms":11.202,"residual_ms":0.001,"coverage_pct":99.98,"prompt_tokens":8,"generated_tokens":32,"clock":"CLOCK_MONOTONIC","sample_scope":"sample_token_from_logits calls in the forward paths"}

## Suite gate (hidden_files/run_a036.sh; log a036_run_all.log,
## sha256 dc789382fe7ffb68ad40698b1f2fe0dcbd88d5efbeeabdc864c0781bbd8c7941)
E-MASTER run_all, --target-accelerator gfx1151, all 6 shims staged:
363 passed / 1 failed / 2 skipped / 366 total = base 359/1/2/362 +
4 new A-036 cases, all PASS, zero regressions. Sole failure =
gguf.tensor_directory_interface (pre-existing J-022 drift, roads
A-165/A-121, tolerated). Skips = the 2 pre-declared. MOJO_EXIT=1 is
the suite's normal exit with that one known failure (cf. A-030).
New pin: 366.

## Bugs / scope notes
- No engine bug discovered. Driver defect found and fixed in-slice
  before the measured run: result.timings needs an explicit .copy()
  (PhaseTimings is Copyable, not ImplicitlyCopyable) — first build
  failed on that line only.
- A first build attempt via `mojo build` failed to link
  (aesir_par_* undefined): the bench must stage the 6 shims and run
  via `mojo run` like A-030 — fixed in run_a036_bench.sh.
- Scope honesty: sample_ns covers the sampler calls in the six
  forward paths above. The speculative-decoding path
  (core/speculative_sampling.mojo) samples through its own calls
  and is NOT part of the standard run; if a future slice routes the
  standard run through it, its sites need the same sink treatment.
  generate_image_chat / generate_session also produce
  GenerationResults through _run_generation (timed identically);
  their extra vision/session work sits outside the generation
  spans and would land in residual — no claim is made for them here.
