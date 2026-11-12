# A-038 Ledger — Wide-SIMD Q8_0 dequant GEMV (team-05)

- Team: 05 (lead + 6 Mythic Engineering sub-agents; a second
  6-agent recon wave corroborated code locations, suite shape, and
  the census status independently)
- Worktree: /home/volmarr/aesir-team-05, branch yrsa/aesir-team-05
- Base: seat main 1ac82dbb (A-035 banked; read fresh from git at
  the seat this run — A-034/A-035 had banked past the d98da7fb
  spawn-time note). A-036 may bank concurrently; not chased.
- Status: DONE 2026-11-12 — built, benched, suite-run, committed
  on yrsa/aesir-team-05. Awaiting keeper banking in roadmap order
  (A-036, A-037 bank first). Do NOT merge or push from this
  worktree.

## Census row attacked

A-037 (team-04) is in flight concurrently: its perf data is on
disk in team-04's hidden_files (a037_perf_report_nochildren.txt)
but no census table/ledger has been filed yet. The census fixture
is the F16 stories260K, so the census has no Q8_0 row — its top
row is the GEMM row (core::compute::_gemm_f16_dense_range,
22.21% self-time). A-038 attacks the Q8_0 analogue of that row:
the scalar dequant pocket inside gemm_q8_0, per the roadmap's
own assignment and the standing Part II lesson (scalar decode
was ~90% of the IQ single-row cost at S-030; the same pocket in
gemm_q8_0 is the proven Coder-7B Q8_0 speed defect). If A-037's
filed census names rows differently, this mapping is the one to
reconcile at banking.

## What was built (aesir_engine/core/compute.mojo)

- `_gemm_q8_0_gemv_range` — single-row GEMV range with fused
  width-16 SIMD dequant: per 32-lane block, two
  `unsafe_load[width=16]` int8 vector loads, widened to F32 and
  multiplied in registers ((a * Float32(q)) * scale, the serial
  body's exact per-lane product order). No scratch materialized —
  the decode-once F32 scratch of `_gemm_q8_0_fast_range` is pure
  overhead when each weight is used exactly once.
- `_gemm_q8_0_gemv_worker` — par_for FFI callback, same ctx
  layout as `_gemm_q8_0_worker`.
- `gemm_q8_0` dispatch: A.rows == 1 routes to the GEMV worker;
  multi-row calls keep the decode-once fast range untouched.
- Preserved as comparators: `_gemm_q8_0_range` (bit-exact serial
  body) and `dequantize_q8_0` — both untouched.
- Tests: aesir_engine/tests/test_q8_0_gemv_simd.mojo (3 cases),
  registered in run_all; pin 373 -> 376.
- Bench driver: aesir_engine/tests/bench_q8_0_gemv_a038.mojo
  (standalone, not in run_all; A-030/A-037 driver precedent).

## Parity verdict (vs the scalar path, direct kernel comparison)

Kernel-level slice: the oracle is `_gemm_q8_0_range` itself on
identical inputs — no prompt/template surface exists at this
level, so raw-oracle discipline reduces to exact input identity,
which the fixtures guarantee by construction.

1. Bit-identical where exactness is provable: the suite parity
   case uses dyadic data (activations on a 1/4 grid, scales in
   {0, +/-0.5, +/-0.25, +/-0.0625}, full-range int8 weights,
   K=1024, N=96) — every product and partial sum is exact in F32,
   so both summation orders agree bit-for-bit. Result: PASS,
   bitwise equal on all 96 outputs. The known-value case
   (scale 0.25, q=i-16, a=1 -> exactly -4 through the public
   gemm_q8_0) and the multi-row dispatch regression (rows=3,
   bitwise vs serial body) also PASS.
2. Non-dyadic filed tolerance (bench fixture, seed 0xA038 LCG,
   scales in [0.002, 0.02] with zero/negative blocks mixed in):
   - K=288,  N=512:   512/512 bit-identical, max 0 ULP
   - K=4096, N=4096:  4068/4096 bit-identical (99.32%),
     max 8 f16 ULP, max abs diff 0.03125
   - K=4096, N=11008: 10943/11008 bit-identical (99.41%),
     max 10 f16 ULP, max abs diff 0.03125
   Filed tolerance for the GEMV path on general data: <=10 f16
   ULP worst case at K=4096, >=99.3% of outputs bit-identical.
   Cause is summation order only (lane-grouped 16-partial
   reduction, ascending lane-order fold — the same accepted
   fast-path class as _gemm_q8_0_fast_range); per-lane products
   are bit-identical by construction ((a*q) is exact in F32 and
   the scale multiply keeps the serial order). Identical stats
   in both bench runs (fixture is deterministic).

## Speed delta (bench_q8_0_gemv_a038, single-thread range calls)

Medians after 3 warmups; reps 25/15/9 by shape. Two runs filed
(a038_bench.log, a038_bench_run2.log); ratios stable across
both windows on the shared box (load 2.4–4.4, other crews
active — absolute ns move with cache/load state, ratios do
not). Headline = run 2:

| Shape (K x N)     | Scalar median | SIMD median | Speedup |
|-------------------|---------------|-------------|---------|
| 288 x 512         | 328,354 ns    | 8,486 ns    | 38.7x   |
| 4096 x 4096       | 39,534,137 ns | 1,463,607 ns| 27.0x   |
| 4096 x 11008      | 106,318,173 ns| 4,017,555 ns| 26.5x   |

Run 1 ratios: 39.0x / 26.5x / 26.3x. The threaded public
gemm_q8_0 dispatch inherits the same range for A.rows == 1.
An end-to-end Q8_0-model decode delta is NOT claimed: the
A-037 census fixture is F16, so the kernel-level delta on this
filed-provenance fixture is the acceptance evidence.

Fixture provenance: all bench inputs generated in-file by a
fixed-seed LCG (seed 0xA038) — byte-reproducible from the
bench source alone. Bench source sha256:
9dbfd6dfd70b496a0c71212fe717d97b3ae93f7f7722738c0dde24cf26ef7ea3
compute.mojo sha256 at bench time:
04f65ce1b3ccbd10154199b832f1525ab086d7915d7e65db7e193878001b47d2

## Suite (E-MASTER run_all, team-05 worktree)

hidden_files/a038_run_all.log (runner hidden_files/run_a038.sh,
6 shims, --target-accelerator gfx1151):
**373 passed / 1 failed / 2 skipped / 376 total** = baseline
370/1/2/373 at the new base + the 3 new A-038 cases, all PASS:
quantization.q8_0_gemv_simd_known_value,
quantization.q8_0_gemv_simd_parity,
quantization.q8_0_gemv_multirow_regression.
Sole failure = pre-existing gguf.tensor_directory_interface
(J-022 drift, roads A-165 primary / A-121); skips = the 2
pre-declared. MOJO_EXIT=1 is the established raw-suite shape
(the ledger raises on the tolerated failure; gates judge the
log). Pin: ledger.finish 373 -> 376 (re-pin comment in
run_all.mojo).

## Discovered bugs / next work

- None discovered in scope; nothing left unfixed.
- Noted, not a bug: the multi-row fast range still fills its
  decode-once scratch scalar-ly. That cost is amortized across
  A rows there (the GEMV defect was specifically the
  single-row pay-full-decode-use-once shape). A future slice
  may vectorize the scratch fill with the same two-load
  pattern if a census shows it matters.
