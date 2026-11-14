# A-114 - The full matrix runner

**Machine:** purpleraider (ASUS ROG Flow Z13, Ryzen AI Max+ 395, Radeon 8060S gfx1151, XDNA 2, 128 GB unified LPDDR5X)
**Base:** 7e4f6402 (banked main, 111 of 216, A-111 closure)
**Gate question (roadmap):** "Quant x architecture x backend, one command. Acceptance: a full run completes on the Z13 and emits the matrix with a verdict per cell."

## The runner

`aesir_engine/core/matrix_runner.mojo` lays the banked oracle surfaces
out as the full matrix and files exactly one verdict per cell:

- Axes: 19 quants (the ten A-045 measured rows in filed order, derived
  from `a045_matrix()` in A-109's `core/teacher_forcing_harness.mojo`,
  plus the nine IQ rows A-045 filed fixture-limited) x 3 architectures
  (llama, gemma4, mistral3) x 4 backends (exactly A-109's
  `tf_harness_backends()`: cpu, vulkan, hip, npu) = **228 cells**.
- The verdict rule is pre-registered in the module header (R1-R4):
  - R1: backend != cpu -> NOT_GRADED (`BACKEND_NO_CPU_COMPARATOR`).
    Grading is CPU engine vs CPU comparator only (A-109's
    `tf_validate_run` pins both to cpu); no device-execution evidence
    is filed for vulkan/hip/npu cells, and accelerator-visible is not
    accelerator-run -- the cells are not graded, never passed or failed.
  - R2: arch != llama -> NOT_GRADED (`NO_FILED_RECORDS`). The only
    filed measured records are llama-arch; nothing is extrapolated.
  - R3: IQ family -> FIXTURE_LIMITED (`IQ_FIXTURE_LIMITED`). A-045's
    filed verdict: the stories260K fixture cannot satisfy the 256-value
    IQ super-block by construction. IQ is graded on coherence, never
    token-exactness (the per-family policy encoding is A-115).
  - R4: a measured row files its A-045 verdict under the A-111 gate
    codes (0..3 are value-for-value the gate's): filed
    "fixture-artifact" -> COMPARATOR_ARTIFACT (precedence, as the
    gate's G2); divergent positions > 0 -> DIVERGENT; near-tie
    positions > 0 -> FAITHFUL_NEAR_TIE; otherwise FAITHFUL. The cell
    keeps the row's position counts and worst rank as its witness;
    ungraded cells carry -1 witnesses, never a zero-filled fake row.
- Enumeration is the Cartesian product in one deterministic order
  (quant, then arch, then backend); empty or duplicate axes are
  refused before any cell is built, so a zero-cell run can never file
  as success. The report's per-verdict counts sum to the total by
  construction and by test, and the FNV-1a digest of the rendered
  matrix reproduces exactly across re-runs.

## Evidence

- Module: `aesir_engine/core/matrix_runner.mojo` (18,066 B as landed,
  sha256 0f2a48771d002c7f3a12dc8f74c1e0438ed2b4d7a39bd7da1c237fd65197a160
  after the two in-slice compile fixes filed in the ledger).
- Tests: 12 cases `matrix.runner_*` in
  `tests/test_matrix_runner_a114.mojo` (sha256
  03fee570233bdaf5f2d30010eb5f918df98b57ba16a4448a67f102f9b0f68509),
  all PASS: axes/product, unique ordered enumeration, the graded
  faithful / near-tie / divergent / artifact cells exactly as A-045
  filed them, IQ fixture-limited, backend and arch NOT_GRADED counts,
  summary sums, invalid axes refused, deterministic digest.
- Full matrix run on this Z13 (driver
  `tests/bench_matrix_a114.mojo`, `hidden_files/a114_matrix.log`,
  MOJO_EXIT=0): 228 MX_CELL lines emitted, summary
  `total=228 faithful=4 near_tie=2 divergent=2 artifact=2
  fixture_limited=9 not_graded=209`, digest 9653520459811539623.
  The graded cpu x llama row reads: F16 / BF16 / Q8_0 / Q5_K_M
  FAITHFUL; Q5_0 / Q4_K_M FAITHFUL_NEAR_TIE; Q4_0 / Q3_K_M DIVERGENT
  (filed quant-noise divergences, witnesses 2 positions each, worst
  ranks 3 and 5); Q2_K / Q6_K COMPARATOR_ARTIFACT (A-045 filed
  fixture-artifact); the nine IQ rows FIXTURE_LIMITED.
- Suite: E-MASTER solo run, `hidden_files/a114_run_all.log`:
  704 passed / 1 failed / 2 skipped / 707 total = baseline
  692 / 1 / 2 / 695 + 12 new cases. Sole failure is the pre-existing
  J-022 `gguf.tensor_directory_interface`; no named intermittent
  fired. GREEN-TO-BASELINE. run_all finish pin 695 -> 707.

## Honest scope

- A-112 (comparator-artifact checklist, team-25) and A-113 (golden
  corpus, team-26) were building in parallel and NOT banked at build
  time; this runner takes no dependency on either. Integration
  points are named in the module header: A-112's checklist refines
  the COMPARATOR_ARTIFACT cells when it banks; A-113's golden corpus
  is the record source that can retire NO_FILED_RECORDS for the
  architectures it covers. A-135 (Part V gate) re-verdicts this
  matrix; A-209 re-runs it on the final build.
- The runner executes no model and opens no device: it enumerates
  and grades banked, filed records (A-045 measurements carried by
  A-109, rows pinned per A-110, band per A-111). No speed and no
  accelerator execution is claimed. The 209 NOT_GRADED cells are
  the honest state of the evidence, filed with named reasons --
  zero unexplained cells, and zero cells passed on no evidence.

## Capability Ledger

Section 26 entry Z13-P5-114 added; E-MASTER registered count advanced
695 -> 707.

## Verdict

GO - the full matrix runs in one command on the Z13 and emits a
verdict per cell. Keeper banks after A-112 and A-113 in roadmap
order.
