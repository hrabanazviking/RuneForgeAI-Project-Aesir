# A-124 — RoPE scaling parity

Wave 14 (Architecture breadth). Roadmap text:
"RoPE scaling parity. NTK/YaRN-scaled long-context
rows. Acceptance: rows judged at >=32k context."

## What was built

- `aesir_engine/core/rope_scaling_battery_a124.mojo`
  — the battery: 4 stated scaling configs (NONE,
  LINEAR, NTK-aware, YaRN) x 3 long-context
  positions (32768, 65536, 131072) x 4 Z13 backends
  = 48 ladder rows judged against independently
  computed filed reference values, the teacher-
  forcing account, plus the labelled SYNTHETIC
  defect fixture's 5 judged cases.
- `aesir_engine/tests/test_rope_scaling_battery_
  a124.mojo` — 13 E-MASTER cases (`rope.scaling_*`).
- `aesir_engine/tests/bench_rope_scaling_battery_
  a124.mojo` — one-command driver; log
  `hidden_files/a124_battery.log`.
- `hidden_files/rope_ref_a124.py` — the independent
  reference computation (float64 Python / numpy):
  the comparator. It shares no code with the Mojo
  module; its outputs at the 9 filed sample pair
  indices are transcribed value-for-value into the
  module's filed records.

## The surface — what exists to judge, honestly

No NTK or YaRN mathematics existed in this tree:
the engine CPU RoPE (compute.apply_rope), the
Vulkan gateway and the HIP kernel are unscaled
only; the GGUF loader does not parse
*.rope.scaling.*; the native CUDA dense-GQA path
rejects scaled RoPE outright; and the session
path clamps context to 16000 (A-052), so no >=32k
session runs end-to-end today. This slice builds
the scaling surface as a pure closed-form float64
module (the tree's own CUDA RoPE comment records
F32 phase error near 8k; at >=32k a float32 ladder
is not a parity surface) and judges the ladders.
Formulas (pre-registered in the module header):
NONE identity; LINEAR f/factor; NTK-aware base
shift theta' = theta * factor^(d/(d-2)); YaRN
NTK-by-parts over wavelengths (low 1, high 4)
with attention factor 1 + 0.1*ln(factor).

## Judging — pre-registered rule R1-R3 (module header)

- R1: non-cpu -> NOT_GRADED (BACKEND_NO_CPU_
  COMPARATOR; CPU vs CPU only, no device-execution
  evidence filed, accelerator-visible is not
  accelerator-run), policy obligation still filed.
  The obligation is read from the BANKED A-115
  policy by call: Q4_K_M -> TOKEN_EXACTNESS_OWED
  (all 48 rows).
- R2: cpu rows judged by ladder checks over the
  config's filed reference record: sampled parity
  at 9 pair indices within 10 ppm, the pair-63
  angle witness at the row's position, the
  attention factor, and the structural checks
  (mode pair-0 value; ladder non-increasing).
  All pass -> FAITHFUL (ROPE_LADDER_CHECKS_PASS).
- R3: synthetic defect cases judged against the
  YARN record by the same checks: SYN_YARN_OK ->
  FAITHFUL; SYN_UNSCALED -> DIVERGENT
  (ROPE_UNSCALED_AT_LONG_CONTEXT); SYN_NTK_ALL ->
  DIVERGENT (YARN_RAMP_IGNORED); SYN_NO_ATTENTION
  -> DIVERGENT (YARN_ATTENTION_FACTOR_MISSING);
  SYN_MISMATCH -> COMPARATOR_ARTIFACT
  (BACKEND_MISMATCH).

## Filed battery (filed reference records)

- FAITHFUL 12 — every config on cpu at 32768,
  65536 and 131072 (max sampled error 0 ppm at
  x1e12 rounding on every row; YaRN attention
  factor 13466 x10000 filed on its rows).
- NOT_GRADED 36 — every non-cpu row, reason named.
- Policy rows: owed 48, coherence 0. Zero
  unexplained.
- Teacher-forcing account: total 48, graded 0,
  not_graded 48, reason NO_FILED_RECORDS. Zero
  filed TF records exist at >=32768 with any
  scaling (A-045's records are a 40-token unscaled
  llama sequence; A-052's 32k probes produce no
  logits; the one YaRN model in any record was
  graded only at ~174-230 template-rendered
  tokens). The account retires only with a
  sha-pinned NTK/YaRN fixture, a RAW >=32k corpus
  prompt, the 16000 session cap lifted, and
  CPU-vs-CPU tf_grade_rows at >=32768 —
  re-verdicted at A-135.
- Synthetic: total 5, faithful 1, divergent 3,
  artifact 1 — status SYNTHETIC, never hidden.
- Digest: filed in hidden_files/a124_battery.log
  and hidden_files/A124_LEDGER.md.

Integration points (named, honest): the engine-
side follow-on is plain — parse *.rope.scaling.*
in the GGUF loader, thread a scaling parameter
through apply_rope and the device RoPE paths, and
replace the dense_gqa_profile rejection with
admission; that is engine work for a later slice,
not this battery. A-116 remains the tool for
divergent ENGINE rows; this battery files none
(its divergent cases are the synthetic fixture's
seeded defects, and A-116's probes are rank/gap
records, not frequency ladders), so A-116's
Wave-14 in-anger condition is not claimed met
here. A-122 / A-123 build in parallel; no
dependency taken on either. The battery executes
no model on this machine and claims no
accelerator execution.
