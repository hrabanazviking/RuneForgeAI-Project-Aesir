# A-111 - Near-tie band, encoded

**Machine:** purpleraider (ASUS ROG Flow Z13, Ryzen AI Max+ 395, Radeon 8060S gfx1151, XDNA 2, 128 GB unified LPDDR5X)
**Base:** 24d9f13c (banked main, 108 of 216, A-108 closure)
**Gate question (roadmap):** "Rank <=2 with sub-logit gap = faithful, as a gate rule (not a human judgement call per row). Acceptance: gate unit tests cover band edges."

## The rule, encoded

Before this slice the band lived as prose and as separate re-statements
inside individual graders (prefill_grade per-step rule, gpu_fuzz
classifier, parity_battery header, kv_faith milli-logit rule). It is now
encoded ONCE in `aesir_engine/core/near_tie_gate.mojo`:

- Constants: `BAND_MAX_RANK = 2` (INCLUSIVE), `BAND_MAX_GAP_MILLI = 1000`
  (EXCLUSIVE - gap_milli == 1000 is a full logit and is OUT).
- Per record (S1-S3): EXACT iff rank == 0; NEAR_TIE iff rank <= 2 AND
  gap_milli < 1000 - BOTH conjuncts bind (rank 2 with a 1.138 gap is NOT
  a near-tie: the J-022 pre-fix step 17 witness; rank 3 with a 0.010 gap
  is NOT a near-tie either); DIVERGENT otherwise. A record is FAITHFUL
  iff EXACT or NEAR_TIE. Inconsistent records (rank 0 with nonzero gap,
  positive rank with zero gap, negatives) are refused, not graded.
- Per row / sequence (G1-G5): NOT_GRADED (no records);
  COMPARATOR_ARTIFACT (comparator_valid == False - precedence over
  every record pattern); DIVERGENT (any record divergent);
  FAITHFUL_NEAR_TIE (none divergent, at least one near-tie - a PASS);
  FAITHFUL (every record exact). No averaged gap and no agreement
  percentage: exact steps cannot buy out a divergent one.
- The gate is the band only: prefill_grade's STEP0_BOUNDARY refinement
  stays a cell disposition in prefill_grade (such a sequence is not
  faithful under either account); the comparator-artifact KINDS and
  their automated checklist are A-112, not this gate.

## Evidence

- Module: `aesir_engine/core/near_tie_gate.mojo` (11,516 B, sha256
  d4fef85124e76722ac5c670a160848849db24331751b10a392dd3fe520e35fbc). Its
  first 4,350 B are the previous lead's pre-registered docstring,
  salvaged verbatim from the interrupted partial
  `core/.near_tie_gate.mojo.musegadget-partial`.
- Tests: 11 cases `gate.near_tie_*` in
  `tests/test_near_tie_gate_a111.mojo` (10,481 B, sha256
  6d06f5ee3546067426e1b00ae5b8ee3d2b74a146b3eb95b32ad1e2723ae7c5), all
  PASS: band constants, exact step, band interior, rank edge, gap edge
  (1000 milli OUT, J-022 witness), invalid records refused, comparator
  precedence, row verdicts, sequence verdicts, grid agreement with
  `prefill_grade.step_class` (ranks 1..6 x gaps 1/10/500/999/1000/1138/
  2500 plus the exact record), band line.
- Suite: E-MASTER solo run, `hidden_files/a111_run_all.log`:
  678 passed / 1 failed / 2 skipped / 681 total = baseline
  667 / 1 / 2 / 670 + 11 new cases. Sole failure is the pre-existing
  J-022 `gguf.tensor_directory_interface`; no named intermittent
  fired. GREEN-TO-BASELINE. run_all finish pin 670 -> 681.

## Honest scope

- A-109 (teacher-forcing harness v2) and A-110 (oracle pin registry)
  were building in parallel and NOT banked at build time; filed
  IN_FLIGHT, no result claimed. This gate takes no dependency on
  either: it grades stated records, and its docstring names the A-110
  registry only as the records' source.
- Raw-oracle discipline stands: records come from teacher-forcing rank
  + logit gap on RAW prompts, CPU engine vs CPU comparator only. The
  gate executes nothing, opens no device, and claims no speed. IQ rows
  are graded on coherence, never token-exactness (A-115 policy).

## Capability Ledger

Section 26 (Z13-P5-111) added; E-MASTER registered count advanced
670 -> 681.

## Verdict

GO - the near-tie band is a gate rule in code, with band edges covered
by unit tests. Keeper banks after A-109 and A-110 in roadmap order.
