# A-119 — Qwen-family battery

Wave 14 (Architecture breadth). Roadmap text: "Qwen-family
battery. Acceptance: rows judged." (Wave 14's family
batteries are judged per the A-115 policy; A-118's entry
states that rule for the wave, and this battery follows
the A-118 pattern.)

## What was built

- `aesir_engine/core/qwen_battery_a119.mojo` — the battery:
  the qwen rows of the banked A-114 full matrix runner,
  laid across all four Z13 backends. Each row files exactly
  the A-114 runner's verdict for its (quant, qwen, backend)
  cell (the suite proves agreement cell-for-cell on every
  row), so battery and matrix cannot drift.
- `aesir_engine/tests/test_qwen_battery_a119.mojo` — 13
  E-MASTER cases (`qwen.battery_*`).
- `aesir_engine/tests/bench_qwen_battery_a119.mojo` —
  one-command driver; log `hidden_files/a119_battery.log`.

## Axes

- Quants (19): the ten A-045 measured rows (F16, BF16,
  Q8_0, Q4_0, Q5_0, Q2_K, Q3_K_M, Q4_K_M, Q5_K_M, Q6_K)
  plus the nine IQ rows (IQ1_S, IQ1_M, IQ2_XXS, IQ2_XS,
  IQ2_S, IQ3_XXS, IQ3_S, IQ4_NL, IQ4_XS) — from
  `matrix_quants()`, never re-typed.
- Backends (4): exactly A-109's `tf_harness_backends()`
  (cpu, vulkan, hip, npu), called, never re-typed.
- Architecture: the Qwen family (GGUF strings qwen2,
  qwen3, qwen35, attested per A-048), filed as `qwen`.
- Total: 19 x 4 = 76 rows, one verdict per row.

## Judging — per the A-115 policy (canonical, banked)

A-115 HAS banked (`core/exactness_policy.mojo`), so unlike
A-118 — which mirrored the policy as data while A-115 was
in flight — this battery CALLS the canonical encoding
(`policy_for_quant`) for every row's obligation, and the
suite pins value-for-value agreement with it:

- TOKEN_EXACTNESS_OWED (10 quants, 40 rows): judged by
  teacher-forcing rank + logit gap on RAW prompts under
  the A-111 near-tie gate (rank <= 2, gap < 1 logit),
  CPU engine vs CPU comparator only.
- COHERENCE_ONLY (9 IQ quants, 36 rows): coherence only,
  never token-exactness.
- An unknown quant label is refused by the canonical
  lookup, never defaulted (suite-pinned).

Pre-registered row rule (module header, Q1–Q3), which is
the A-114 rule order applied to arch `qwen`: non-cpu ->
NOT_GRADED (BACKEND_NO_CPU_COMPARATOR; no device-execution
evidence filed, accelerator-visible is not
accelerator-run); cpu -> NOT_GRADED (NO_FILED_RECORDS —
the banked teacher-forcing records cover llama only, and
llama records are never extrapolated to another
architecture); IQ cpu rows file NOT_GRADED, never
FIXTURE_LIMITED, because A-114's arch rule (R2) fires
before its IQ rule (R3) and FIXTURE_LIMITED is a
llama-fixture verdict (the stories260K fixture cannot
satisfy the IQ super-block) that Qwen has no fixture to
earn. Under the canonical A-115 gate an IQ row with no
coherence evidence also files NOT_GRADED — the accounts
agree.

## Filed battery (banked records)

Run: `hidden_files/a119_battery.log`, MOJO_EXIT=0, digest
4851703893370190557.

- NOT_GRADED 76 — every row, each with a named reason:
  57 BACKEND_NO_CPU_COMPARATOR (all non-cpu rows) +
  19 NO_FILED_RECORDS (all cpu rows).
- FAITHFUL 0, FAITHFUL_NEAR_TIE 0, DIVERGENT 0,
  COMPARATOR_ARTIFACT 0, FIXTURE_LIMITED 0 — no graded
  verdict is claimed, because no Qwen teacher-forcing
  comparison has ever run: A-048 filed that no real Qwen
  GGUF weight fixture exists in the repo (the one real
  fixture is stories260K, llama), and its Qwen rows are
  synthetic stories-tensor smokes, explicitly not
  oracle-graded.
- Policy rows: owed 40, coherence 36. Zero unexplained.

## The family, as attested (A-048, data not grading)

- qwen2 — SMOKE_PASS (synthetic): load + forward + greedy
  completion on a synthetic stories-tensor fixture; the
  no-BOS Qwen branch and RoPE-NeoX modifier exercised.
- qwen3 — SMOKE_PASS (synthetic): same account as qwen2.
- qwen35 — LOAD_FAIL, named cause: "GGUF qwen35 SSM
  metadata is incomplete"; the hybrid Gated-DeltaNet SSM
  validator needs metadata and tensors no fixture in the
  repo can supply.

Smoke is load evidence, never grading evidence; no row
verdict above rests on it.

## What retires NO_FILED_RECORDS

Filed teacher-forcing records for a Qwen architecture — a
real sha-pinned Qwen GGUF fixture (A-110 pins), raw
prompts from the A-113 golden corpus, graded by the A-109
harness under the canonical A-115 policy. Until then every
Qwen row is owed, not graded, and A-135 (Part V gate)
re-verdicts the matrix. The battery executes no model,
opens no device, and claims no accelerator execution.

## Suite

E-MASTER solo (ps-checked; launched only after team-26's
A-120 suite finished). Run 1 (`hidden_files/a119_run_all.log`):
784 passed / 2 failed / 2 skipped / 788 total — failures:
pre-existing J-022 `gguf.tensor_directory_interface` +
named intermittent `resilience.state_vault_rejects_growth`.
Solo re-run (`hidden_files/a119_run_all_rerun.log`):
785 passed / 1 failed / 2 skipped / 788 total, sole failure
J-022 — the intermittent cleared solo. All 13
`qwen.battery_*` cases PASS in both runs. GREEN-TO-BASELINE
(baseline 772/1/2/775 + 13 new cases).
