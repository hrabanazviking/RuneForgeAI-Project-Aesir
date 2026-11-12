# A-047 Ledger — Precision paths (team-05)

- Slice: A-047 — Precision paths. F32/F16/BF16 compute paths verified
  on Z13 CPU vs reference values. Acceptance: per-precision error
  bounds filed — docs/bench/A047_PRECISION_BOUNDS.md.
- Date: 2026-11-12
- Worktree: /home/volmarr/aesir-team-05, branch yrsa/aesir-team-05
- Base: 40ce2d88e643e6422c3ce9e19708db50af9e4f9b (seat main, A-044
  banked, 44 of 216). Worktree reset --hard onto this base at slice
  start (from 7de98ea1 / A-038 commit); CAMPAIGN_STATE.md and
  hidden_files/ backed up first to hidden_files/a047_backup/ and
  verified surviving the reset.
- Team: lead + 6 Mythic Engineering sub-agents (recon, codebase
  scout, test design, risk review, docs draft, ledger/QA). No spawn
  rate limits hit.

## Built

- aesir_engine/tests/test_precision_paths.mojo — 6 E-MASTER cases,
  every reference a Float64 scalar loop over the exact stored
  inputs (BF16 patterns decoded arithmetically in Float64; the
  retained engine oracle gemm_bf16_scalar is NOT used):
  precision.f32_accumulation_dyadic_exact,
  precision.f16_gemm_f64_reference,
  precision.bf16_gemm_f64_reference,
  precision.bf16_widening_exact (all 65536 patterns),
  precision.f16_roundtrip_bound,
  precision.rmsnorm_f32_f64_reference.
- aesir_engine/tests/bench_precision_a047.mojo — standalone
  measurement probe (not in run_all); prints the maxima filed in
  the bounds doc. Log: hidden_files/a047_probe.log.
- aesir_engine/tests/run_all.mojo — import + 6 run_case lines;
  finish pin 413 -> 419 with re-pin comment.
- docs/bench/A047_PRECISION_BOUNDS.md — filed per-precision error
  bounds (measured maxima + filed bounds + verdicts + method +
  reproduction + caveats).

## Measured (probe, deterministic; hidden_files/a047_probe.log)

- F16 GEMM K=1024: max_abs 0.007810, max_rel 4.151e-4
- BF16 GEMM K=1024: max_abs 0.031064, max_rel 4.336e-4
- BF16 widening exhaustive: 0 mismatches / 65280 normal patterns
- F16 roundtrip 1M (normals |v| >= 0.01): max_rel 0.00048733 vs
  half-ULP bound 0.00048828 (round-to-nearest-even, not truncation)
- RMSNorm F32 4x257: max_abs 0.000484, max_rel 0.000472
- F32 accumulation: bit-exact on dyadic K=256 by construction,
  asserted in the gate case.

Methodology notes (also in the bounds doc): the F16/BF16 GEMM
relative errors sit in the same band — evidence both accumulate in
F32; BF16's larger max_abs is output magnitude, not precision. The
roundtrip relative bound is a normal-range statement; the F16
subnormal band is filed as an absolute spacing bound (2^-24
spacing, max abs err <= 2^-25 under RNE) — an unguarded first probe
run showed max_rel 0.00798 driven entirely by subnormal samples,
which is what forced the guard.

## Gate

- Runner: hidden_files/run_a047.sh (canonical E-MASTER shape,
  all shims staged, --target-accelerator gfx1151), run in tmux on
  purpleraider (a detached nohup chain died with its invoke
  session; tmux is the surviving road).
- Log: hidden_files/a047_run_all.log
- Counts (read from the log): 416 passed / 1 failed / 2 skipped /
  419 total = baseline at 40ce2d88 (410/1/2/413) + 6 new precision
  cases, all PASS, zero regressions.
- Sole failure: gguf.tensor_directory_interface — pre-existing
  J-022 drift, the one tolerated failure (roads A-165/A-121).
- MOJO_EXIT=1 is the suite's fail-closed exit on that one
  pre-existing failure, as at baseline.

## Banking note for the keeper

- One commit on yrsa/aesir-team-05 on top of 40ce2d88, subject
  "A-047: Precision paths". Bank strictly after A-045 and A-046.
- Union at banking: run_all finish pin is 419 on this branch's
  base; reconcile against A-045/A-046 additions when they bank.
- No shim/link changes needed: the new cases use only the par shim
  already staged by the canonical gate.
- CPU-only verification: no accelerator execution is claimed for
  these paths (gfx1151 was the build target only, per gate shape).
