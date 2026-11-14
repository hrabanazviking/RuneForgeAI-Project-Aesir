# A-115 - Token-exactness policy, encoded

**Machine:** purpleraider (ASUS ROG Flow Z13, Ryzen AI Max+ 395, Radeon 8060S gfx1151, XDNA 2, 128 GB unified LPDDR5X)
**Base:** 57f2e2da (banked main, 114 of 216, A-114 closure)
**Gate question (roadmap):** "Per quant family: where token-exactness is owed (most GEMV paths), where only coherence is owed (IQ family), the gates encode it. Acceptance: policy table + gate tests."

## The policy

`aesir_engine/core/exactness_policy.mojo` is the ONE encoding of the
per-family token-exactness policy that previously lived only as prose
repeated in the A-109 / A-111 / A-114 headers:

- The table is built over A-114's `matrix_quants()` axis, CALLED --
  never re-typed -- so it cannot drift from the matrix it governs:
  19 rows in axis order.
  - (P1) TOKEN_EXACTNESS_OWED -- the ten measured GEMV quant families
    (F16, BF16, Q8_0, Q4_0, Q5_0, Q2_K, Q3_K_M, Q4_K_M, Q5_K_M, Q6_K),
    graded value-for-value by A-111's near-tie gate (exact = FAITHFUL,
    inside the band = FAITHFUL_NEAR_TIE, divergent = DIVERGENT). A
    coherence claim never rescues a divergent owed row.
  - (P2) COHERENCE_ONLY -- the nine IQ families (IQ1_S, IQ1_M,
    IQ2_XXS, IQ2_XS, IQ2_S, IQ3_XXS, IQ3_S, IQ4_NL, IQ4_XS),
    recognised by A-114's `is_iq_quant`, called. Token-exactness is
    never owed and never demanded: a divergent token record can never
    mint an IQ failure. Stated passing coherence files COHERENCE_PASS,
    stated failing files COHERENCE_FAIL, unstated files NOT_GRADED --
    the honest state today (no coherence evidence is filed in the
    banked records, matching A-114's FIXTURE_LIMITED cells).
- The gate is pre-registered in the module header (T1-T5): unknown or
  empty labels are REFUSED, never defaulted to either obligation;
  records are validated by A-111's gate (inconsistent records refused,
  not graded, for both obligations); COMPARATOR_ARTIFACT precedes
  grading for both obligations; exactness-owed verdicts are A-111's
  codes 0..4 value-for-value; coherence-only rows compute the token
  grade as witness only and disregard it as a verdict source. A row
  passes iff FAITHFUL, FAITHFUL_NEAR_TIE, or COHERENCE_PASS.
- Families are filing labels only (FLOAT / GGML_QUANT / IQ), kept
  distinct from the obligation so a family rename can never smuggle
  an obligation change. The rendered table's FNV-1a digest reproduces
  exactly across re-renders.

## Evidence

- Module: `aesir_engine/core/exactness_policy.mojo` (14,561 B,
  sha256 706334dbd535cd5adb2be25a9157ea00dd111da9ec458787d70f997ae4e37164).
- Tests: 13 cases `policy.exactness_*` in
  `tests/test_exactness_policy_a115.mojo` (sha256
  8b8d4c36bafd6f6df6d1d0a70dfa401da8a3d24707c98f837c396d2b83a5e85d),
  covering: table completeness, measured-owed, IQ coherence-only,
  unknown refused, exact pass, near-tie band edges, divergent fails,
  IQ divergent never fails, IQ coherence fail + unstated, comparator
  precedence, coherence cannot rescue exactness, invalid records
  refused, render digest deterministic.
- Policy bench on this Z13 (driver `tests/bench_policy_a115.mojo`,
  `hidden_files/a115_policy.log`, MOJO_EXIT=0): 19 POL_ROW lines,
  summary `total=19 exactness_owed=10 coherence_only=9`, digest
  12048845139128415230. Filed gate verdicts: Q4_K_M
  FAITHFUL_NEAR_TIE; IQ2_XS COHERENCE_PASS; IQ2_XS unstated
  NOT_GRADED.
- Suite: E-MASTER solo run, `hidden_files/a115_run_all.log`:
  737 passed / 1 failed / 2 skipped / 740 total = baseline
  724 / 1 / 2 / 727 + 13 new cases, all 13 policy.exactness_* PASS;
  sole failure pre-existing J-022 gguf.tensor_directory_interface;
  no named intermittent fired. GREEN-TO-BASELINE. run_all finish
  pin 727 -> 740.

## Honest scope

- The policy executes no model, opens no device, and claims no speed
  and no accelerator execution: pure policy arithmetic on stated
  records, resting on banked A-045 records (teacher-forcing rank +
  logit gap on RAW prompts, CPU engine vs CPU comparator only, rows
  pinned per A-110, band per A-111, artifacts per A-112, corpus per
  A-113, matrix per A-114).
- No coherence evidence exists in the banked records yet, so every IQ
  row grades NOT_GRADED until such evidence is filed; the policy
  mints no pass from token records.

## Capability Ledger

Section 26 entry Z13-P5-115 added; E-MASTER registered count advanced
727 -> 740.

## Verdict

GO - the policy table is encoded once, the gates encode it, and the
gate tests pass. Keeper banks in roadmap order.
