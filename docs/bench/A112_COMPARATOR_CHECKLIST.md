# A-112 - Comparator-artifact checklist, automated

**Machine:** purpleraider (ASUS ROG Flow Z13, Ryzen AI Max+ 395, Radeon 8060S gfx1151, XDNA 2, 128 GB unified LPDDR5X)
**Base:** 7e4f6402 (banked main, 111 of 216, A-111 closure)
**Gate question (roadmap):** "Template, BOS, backend-mismatch, and step-0 boundary checks run before any engine divergence is filed. Acceptance: seeded fake divergences of each class are caught by the checklist and verdicted as comparator artifacts."

## The checklist, encoded

Before this slice the checklist lived in prose: prefill_grade's host
contract ("the caller records which kind fired"), A-109's harness gate
(template and backend rejection inside tf_validate_run), and the standing
court discipline. It is now encoded ONCE in
`aesir_engine/core/comparator_checklist.mojo`: four checks over a stated
comparison account (prompt bytes, both sides' BOS handling, both backend
names, the per-step rank/gap records), run in pre-registered precedence
order, returning one summary.

- (K1) TEMPLATE: the prompt carries any marker from A-109's
  tf_template_markers list (consulted, not re-typed, so the two cannot
  drift). The rendered-BOS mark "<s>" is filed under K2, not here.
- (K2) BOS: engine_bos != comparator_bos, or the prompt carries a
  rendered "<s>" BOS mark neither side's stated handling accounts for.
- (K3) BACKEND_MISMATCH: either backend unnamed, the backends differ,
  or the pair is not CPU vs CPU (standing law; accelerator-visible is
  not a grading comparator).
- (K4) STEP0_BOUNDARY: the records diverge and every divergent record
  sits at step 0 (later steps exact or near-tie under A-111's gate
  classes). prefill_grade keeps its STEP0_BOUNDARY cell disposition
  for the same pattern; both accounts agree it is not an engine
  divergence.
- Verdicts: CLEAN (grading / divergence filing may proceed) or
  COMPARATOR_ARTIFACT with the kind named by precedence; every hit is
  recorded in the summary whichever kind takes precedence.
  may_file_divergence is true exactly for a CLEAN summary with at
  least one divergent record -- the checklist is the only road to a
  divergence filing. Records are validated by A-111's gate first:
  inconsistent records and length mismatches are refused, not
  verdicted.

## Evidence

- Module: `aesir_engine/core/comparator_checklist.mojo` (12,420 B, sha256 d816e28be01fb4078f0289c50250ffe22c5374de659f787cc61782b1cd14b2f6); tests 13,965 B, sha256 cd824e731d7ea2adb8a339316d17a76d47b1ebce4170557f3f3fee25da34dc8a.
- Tests: 12 cases `oracle.comparator_*` in
  `tests/test_comparator_checklist_a112.mojo`: constants/names, clean
  exact, clean genuine divergence (the protected control), seeded
  template caught (three marker families), template precedence over
  exact rows, seeded BOS caught (flag mismatch, both directions),
  seeded rendered-BOS caught (filed BOS, not TEMPLATE), seeded
  backend mismatch caught (cross pairs, accelerator pair, unnamed
  oracle), seeded step-0 caught, step-0 plus later divergence is
  genuine, combined precedence with all hits recorded, invalid
  records refused.
- Suite: E-MASTER solo run, `hidden_files/a112_run_all.log`:
  704 passed / 1 failed / 2 skipped / 707 total = baseline 692 / 1 / 2 / 695 + 12 new cases, all 12 oracle.comparator_* PASS. Sole failure is the pre-existing J-022 gguf.tensor_directory_interface; no named intermittent fired. GREEN-TO-BASELINE (the run's Status: FAIL is the baseline J-022 failure, present on the base commit's suite as well). run_all finish pin 695 -> 707.

## Honest scope

- Builds on banked A-109 (teacher-forcing harness v2), A-110 (oracle
  pin registry), and A-111 (near-tie band gate), all verified in the
  seat git log at build time; the checklist consults A-109's marker
  list and A-111's step classes directly, and grades nothing itself.
- Raw-oracle discipline stands: records come from teacher-forcing rank
  + logit gap on RAW prompts, CPU engine vs CPU comparator only. The
  checklist executes nothing, opens no device, and claims no speed.
  IQ rows are graded on coherence, never token-exactness (A-115
  policy).

## Capability Ledger

Section 26 (Z13-P5-112) entry added; E-MASTER registered count
advanced 695 -> 707.

## Verdict

GO - the comparator-artifact checklist is automated, with seeded fake
divergences of each class caught and verdicted as comparator
artifacts. Keeper banks in roadmap order after A-111.
