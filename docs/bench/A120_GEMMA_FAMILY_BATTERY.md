# A-120 — Gemma-family battery

Wave 14 (Architecture breadth). Roadmap text:
"Gemma-family battery. Acceptance: rows judged (the
existing CUDA Gemma work is the comparator reference
where relevant — CPU engine vs CPU comparator rule
still governs grading)."

## What was built

- `aesir_engine/core/gemma_battery_a120.mojo` — the
  battery: the gemma4 rows of the banked A-114 full
  matrix runner, laid across all four Z13 backends.
  Each cpu row files exactly the A-114 runner's
  verdict for its (quant, gemma4, cpu) cell (the suite
  proves agreement cell-for-cell), so battery and
  matrix cannot drift.
- `aesir_engine/tests/test_gemma_battery_a120.mojo` —
  13 E-MASTER cases (`gemma.battery_*`).
- `aesir_engine/tests/bench_gemma_battery_a120.mojo` —
  one-command driver; log `hidden_files/a120_battery.log`.

## Axes

- Quants (19): the ten A-045 measured rows (F16, BF16,
  Q8_0, Q4_0, Q5_0, Q2_K, Q3_K_M, Q4_K_M, Q5_K_M, Q6_K)
  plus the nine IQ rows (IQ1_S, IQ1_M, IQ2_XXS, IQ2_XS,
  IQ2_S, IQ3_XXS, IQ3_S, IQ4_NL, IQ4_XS) — from
  `matrix_quants()`, never re-typed.
- Architecture: gemma4 (A-114's matrix name), fixed.
- Backends (4): exactly A-109's `tf_harness_backends()`
  (cpu, vulkan, hip, npu), called, never re-typed.
- Total: 19 x 4 = 76 rows, one verdict per row.

## Judging — per the A-115 policy (canonical, banked)

Unlike A-118, which mirrored the policy while A-115
was unbanked, A-115 has banked: `core/
exactness_policy.mojo` is canonical, and the suite
proves this battery's obligation split agrees with
its `policy_for_quant` for every quant, value-for-
value:

- TOKEN_EXACTNESS_OWED (10 quants, 40 rows): judged by
  teacher-forcing rank + logit gap on RAW prompts
  under the A-111 near-tie gate (rank <= 2, gap < 1
  logit) — when records exist.
- COHERENCE_ONLY (9 IQ quants, 36 rows): coherence
  only, never token-exactness.

## Filed battery (banked records) — the honest result

No filed teacher-forcing records exist for gemma4:
the only measured records in the banked tree are
llama-arch (A-045 / A-109), and A-048 confirmed no
real Gemma GGUF weight fixture exists in the repo or
on purpleraider. A-114's rule therefore files every
gemma4 cell NOT_GRADED, and this battery files:

- NOT_GRADED 76 — every row, zero unexplained:
  - cpu 19 — reason NO_FILED_RECORDS
  - vulkan / hip / npu 57 — reason
    BACKEND_NO_CPU_COMPARATOR (CPU engine vs CPU
    comparator only; no device-execution evidence
    filed; accelerator-visible is not accelerator-run)
- FAITHFUL 0, FAITHFUL_NEAR_TIE 0, DIVERGENT 0,
  COMPARATOR_ARTIFACT 0, FIXTURE_LIMITED 0.
- Policy rows: owed 40, coherence 36.
- Digest: 1945040473473724965
  (`hidden_files/a120_battery.log`, MOJO_EXIT=0).

Two traps this battery refuses, both pinned by cases:

- The llama IQ verdict does not transfer: on llama an
  IQ cpu row is FIXTURE_LIMITED, but A-114 checks the
  architecture before the IQ family, so a gemma4 IQ
  cpu row is NOT_GRADED / NO_FILED_RECORDS (its
  obligation stays COHERENCE_ONLY).
- The existing CUDA Gemma work (`core/gemma4_cuda.mojo`,
  Gemma 4 E4B Q4_K_M) is the comparator reference
  where relevant, exactly as the roadmap states — and
  it grades no row here: it is CUDA device work, not
  a CPU comparator, and it files no RAW-prompt
  teacher-forcing records. No accelerator execution
  is claimed anywhere in this battery.

## A-116 carried condition — not triggered here

A-116's acceptance requires its divergence localiser
be used in anger at least once in Wave 14 or the
slice re-opens. This battery files NO genuinely
divergent row, so there is no row to file with A-116
in anger; the seeded demonstration would not count,
and no divergent verdict is manufactured. The
condition remains carried: the first Wave 14 battery
with a genuine DIVERGENT row owes A-116 its first
real filing.

A-119 (Qwen-family battery, team-25) builds in
parallel and has not banked; no dependency is taken
on it. The battery executes no model, opens no
device, and claims no accelerator execution.
