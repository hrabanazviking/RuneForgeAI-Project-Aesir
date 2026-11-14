# A-118 — Llama-family battery

Wave 14 (Architecture breadth) opener. Roadmap text:
"Llama-family battery on all Z13 backends. Acceptance:
rows judged per A-115 policy."

## What was built

- `aesir_engine/core/llama_battery_a118.mojo` — the battery:
  the llama rows of the banked A-114 full matrix runner,
  laid across all four Z13 backends. Each cpu row files
  exactly the A-114 runner's verdict for its
  (quant, llama, cpu) cell (the suite proves agreement
  cell-for-cell), so battery and matrix cannot drift.
- `aesir_engine/tests/test_llama_battery_a118.mojo` — 13
  E-MASTER cases (`llama.battery_*`).
- `aesir_engine/tests/bench_llama_battery_a118.mojo` —
  one-command driver; log `hidden_files/a118_battery.log`.

## Axes

- Quants (19): the ten A-045 measured rows (F16, BF16,
  Q8_0, Q4_0, Q5_0, Q2_K, Q3_K_M, Q4_K_M, Q5_K_M, Q6_K)
  plus the nine IQ rows A-045 filed fixture-limited
  (IQ1_S, IQ1_M, IQ2_XXS, IQ2_XS, IQ2_S, IQ3_XXS, IQ3_S,
  IQ4_NL, IQ4_XS) — from `matrix_quants()`, never re-typed.
- Backends (4): exactly A-109's `tf_harness_backends()`
  (cpu, vulkan, hip, npu), called, never re-typed.
- Total: 19 x 4 = 76 rows, one verdict per row.

## Judging — per the A-115 policy (mirrored, dependency named)

A-115 (team-25) has NOT banked; no unbanked code is
depended on. The policy's on-disk WIP states the rule,
mirrored here as data; when A-115 banks,
`core/exactness_policy.mojo` is canonical and this mirror
must agree value-for-value (the suite pins the counts):

- TOKEN_EXACTNESS_OWED (10 quants, 40 rows): judged by
  teacher-forcing rank + logit gap on RAW prompts under
  the A-111 near-tie gate (rank <= 2, gap < 1 logit).
- COHERENCE_ONLY (9 IQ quants, 36 rows): coherence only,
  never token-exactness. No coherence evidence is filed
  here, so the honest cpu verdict is FIXTURE_LIMITED.

Pre-registered row rule (module header): non-cpu ->
NOT_GRADED (BACKEND_NO_CPU_COMPARATOR; CPU engine vs CPU
comparator only, no device-execution evidence filed,
accelerator-visible is not accelerator-run); IQ cpu ->
FIXTURE_LIMITED; measured cpu -> the A-114 verdict
(FAITHFUL / FAITHFUL_NEAR_TIE / DIVERGENT /
COMPARATOR_ARTIFACT, the standing verdict class).

## Filed battery (banked records)

- FAITHFUL 4 — F16, BF16, Q8_0, Q5_K_M (cpu)
- FAITHFUL_NEAR_TIE 2 — Q5_0, Q4_K_M (cpu)
- DIVERGENT 2 — Q4_0, Q3_K_M (cpu)
- COMPARATOR_ARTIFACT 2 — Q2_K, Q6_K (cpu)
- FIXTURE_LIMITED 9 — all IQ quants (cpu)
- NOT_GRADED 57 — every non-cpu row, reason named
- Policy rows: owed 40, coherence 36. Zero unexplained.

A-116 (first-divergence localisation, team-26, unbanked)
is the named tool for the two DIVERGENT rows once it
banks. The battery executes no model, opens no device,
and claims no accelerator execution.
