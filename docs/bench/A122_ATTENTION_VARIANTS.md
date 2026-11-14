# A-122 — Attention variants battery

Wave 14 (Architecture breadth). Roadmap text:
"Attention variants. GQA and MLA-style variants
parity. Acceptance: per-variant rows judged."

## What was built

- `aesir_engine/core/attention_battery_a122.mojo` —
  the battery: the attention-variant axis (MHA, GQA,
  MQA, MLA) laid over the banked A-114 matrix:
  4 variants x 19 quants x 4 Z13 backends = 304 rows,
  every row with a verdict and the A-115 policy
  obligation read from the canonical policy by call.
- `aesir_engine/tests/test_attention_battery_a122.mojo`
  — 13 E-MASTER cases (`attn.battery_*`).
- `aesir_engine/tests/bench_attention_battery_a122.mojo`
  — one-command driver; log
  `hidden_files/a122_battery.log`.

## Judging — pre-registered rule V1-V3 (module header)

- V1: backend != cpu -> NOT_GRADED
  (BACKEND_NO_CPU_COMPARATOR; CPU engine vs CPU
  comparator only, no device-execution evidence
  filed, accelerator-visible is not accelerator-run),
  policy obligation still filed.
- V2: variant != GQA (cpu) -> NOT_GRADED
  (NO_FILED_RECORDS). The variant check precedes the
  IQ family exactly as A-114's R2 precedes R3, so an
  IQ row of an ungraded variant files NOT_GRADED,
  never FIXTURE_LIMITED.
- V3: GQA cpu -> the A-114 cell verdict for
  (quant, llama, cpu), filed verbatim — the suite
  proves cell-for-cell agreement on every quant.

## Why GQA is the graded variant

The banked teacher-forcing records (A-045 / A-109)
were produced by the pinned inference path whose
attention is the GQA kernel: `flash_attention_gqa`
in `core/compute.mojo` (AES-CPU-004: 8 query heads
mapped to 4 KV heads, E-REAL oracle parity,
verified), and `core/inference.mojo` routes every
attention call through it with the KV-head count
taken from the GGUF config (`attention.head_count_kv`).
The A-114 llama cells are therefore the GQA-variant
rows of the matrix; this battery files exactly those
verdicts for GQA so the battery and the matrix
cannot drift apart. Filed GQA geometries elsewhere
in the tree agree: the fused attention kernels are
pinned at 24 query / 8 KV heads (A-043, A-084 HIP
GQA parity).

## The other variants, honestly

- MHA — a filed geometry exists (OLMoE 16/16 heads,
  `docs/janas/J015_MOE_ANATOMY.md`), but OLMoE's
  filed evidence is expert routing (J-016, judged
  at A-121), not teacher-forcing rank / logit-gap
  records. No MHA-geometry TF record is filed.
- MQA — no filed fixture, geometry, or TF record
  anywhere in the banked tree.
- MLA — no implementation and no record anywhere in
  the banked tree (grep-verified at build time: no
  core module names MLA or a latent-KV path). There
  is nothing to grade against.

Grading any of these from the GQA records would
extrapolate evidence across attention architectures
— the move A-119 / A-120 refused across model
architectures. A variant's NOT_GRADED retires only
with filed teacher-forcing records on a real
sha-pinned fixture of that variant (A-110 pins,
A-113 corpus, A-109 harness), re-verdicted at A-135.

## Filed battery (banked records)

- Total 304 rows. GQA cpu 19: FAITHFUL 4 (F16, BF16,
  Q8_0, Q5_K_M), FAITHFUL_NEAR_TIE 2 (Q5_0, Q4_K_M),
  DIVERGENT 2 (Q4_0, Q3_K_M — the A-045 filed
  divergence-quant-noise verdicts, carried by
  delegation exactly as A-114 / A-118 file them, not
  new divergences), COMPARATOR_ARTIFACT 2 (Q2_K,
  Q6_K — A-045 filed fixture-artifacts),
  FIXTURE_LIMITED 9 (the IQ family).
- NOT_GRADED 285: 228 BACKEND_NO_CPU_COMPARATOR +
  57 NO_FILED_RECORDS (MHA/MQA/MLA cpu).
- Policy rows: owed 160, coherence 144. Zero
  unexplained.
- Digest: 17757104162478147241
  (`hidden_files/a122_battery.log`, MOJO_EXIT=0).

A-116 note: the two DIVERGENT rows are the banked
A-045 verdicts themselves, already classified
(divergence-quant-noise); this battery discovers no
new divergence, so A-116's Wave-14 in-anger
condition is not claimed met by inherited rows.
A-116 remains the named tool for any genuinely new
divergent row. The battery executes no model on
this machine and claims no accelerator execution.
