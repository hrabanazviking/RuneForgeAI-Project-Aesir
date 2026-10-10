# C2 REVIEW — MÍMISBRUNNR Campaign 2 (H021–H040): ARMVEGR core verdict

Date: 2026-10-10. All measurements on Mimir (Raspberry Pi 5, aarch64),
Mojo 1.1.0 via pixi shim. Branch `c2-armvegr-wip`, merged to main.

## Per-kernel evidence table

"Bound claimed" is the slice's documented contract (see the SÓLRÚN re-scopes
in MIMISBRUNNR_PROGRESS.md and code headers). "Worst measured" is the largest
error observed across the H037 oracle corpus and the c2_verify suite.
"Perf" is the median-of-11 from `data/armvegr/kernel_perf.json`.

| Kernel | Slice | Bound claimed | Worst measured | Perf | Evidence |
|---|---|---|---|---|---|
| gemm_micro_8x8 | H022 | fp16 tile vs fp16 ref, 1e-3 | 2.5e-07 | — (driver-level) | `prof/armvegr/test_kernel_oracles.py` 26/26 PASS |
| gemm_fp16 | H022/H023 | ulp envelope, base 1e-3 | 3.9e-03, excess 0 | 7.16 GFLOPS (1024³) | oracle + `data/armvegr/kernel_perf.json` |
| gemv_fp16 | H024 | ulp envelope, base 1e-3 | 1.95e-03, excess 0 | 4.77 GB/s, 73% of STREAM | oracle + perf |
| elem_add | H025 | 1e-4 abs | 0 | 6.54 GB/s | oracle + perf |
| elem_mul | H025 | 1e-4 abs | 0 | 6.28 GB/s | oracle + perf |
| elem_scale | H025 | 1e-4 abs | 0 | 7.31 GB/s | oracle + perf |
| elem_axpy | H025 | 1e-4 abs | 0 | 5.93 GB/s | oracle + perf |
| layernorm_fp16 | H026 | ulp envelope, base 1e-3 | 4.8e-07, excess 0 | 5.00 GB/s | oracle + perf |
| rmsnorm_fp16 | H027 | ulp envelope, base 1e-3 | 0 | 6.30 GB/s | oracle + perf |
| softmax_fp16 (+masked) | H028 | ulp envelope, base 1e-3 | 0 | 1.29 GB/s | oracle + perf |
| silu_fp16 | H029 | ulp envelope, base 2e-3 | 0 | 1.65 GB/s | oracle + perf |
| gelu_fp16 | H029 | ulp envelope, base 2e-3 | 3.1e-05, excess 0 | 0.24 GB/s | oracle + perf |
| rope_fp16 | H030 | ulp envelope, base 1e-3 | 0 | 0.31 GB/s (1658 ns/call) | oracle + perf |
| fp32_to_fp16 | H031 | exact | 0 | 7.35 GB/s | oracle + perf |
| fp16_to_q80 / q80_to_fp16 | H031 | max 0.024, rms 0.014 | 0.0234 / 0.0131 | 0.66 / 2.08 GB/s | oracle + perf |
| fp16_to_q40 / q40_to_fp16 | H032 | max 0.43, rms 0.25 | 0.424 / 0.237 | 0.53 / 1.73 GB/s | oracle + perf |
| q80_gemm | H033 | max err ≤ 0.05·rms(fp16 ref) | 0.063 (contract 0.19) | 2.54 GB/s, 53% of GEMV | oracle + perf |
| attn_sdpa_causal_fp16 | H034 | ulp envelope, base 2e-3 | 2.4e-07, excess 0 | 4.87 GFLOPS | oracle + perf |
| mha_forward_seq | H035 | ulp envelope, base 2e-3 | 2.4e-04, excess 0 | 6.43 GFLOPS | oracle + perf |
| mha_forward_par | H035 | bit-identical to seq | identical | — | `tests/c2_verify.mojo` |
| select_backend | H036 | all 20 shape combos → CPU; no NPU path | 20/20 CPU, stub never ready | — | c2_verify |
| toy forward (H039) | H039 | ≤5e-3 vs naive scalar, finite, shape [1, vocab] | h=128: 1.95e-03; h=512: 3.91e-03; finite | — | c2_verify |

Evidence paths:
- Oracle: `prof/armvegr/test_kernel_oracles.py` + `data/armvegr/oracle_corpus.json`
  (v1, 26 cases) — **26/26 PASS** on Mimir 2026-10-10 (independent float64
  pure-Python references; exits non-zero on any violation).
- Unit suite: `tests/c2_verify.mojo` — **241/241 PASS, exit 0** on Mimir
  2026-10-10 (branch with all C2 fixes).
- Perf: `data/armvegr/kernel_perf.json` (v1, 22 entries) + method in
  `data/armvegr/BENCHMARK_METHOD.md`; benchmark source
  `armvegr/perf_bench.mojo`.

### Bugs found and fixed during C2 (all verified fixed by the suites above)

1. `mha.mojo`: per-head attention read strided `[seq, d_model]` offsets as
   contiguous `[seq, head_dim]` — gather into per-head buffers added
   (was maxerr 2.15 vs naive; now 2.4e-04).
2. `q80_gemm_bytes` omitted the N term, undercounting B-matrix traffic
   N-fold — signature fixed to `(M, N, K)` (perf accounting only; kernel
   untouched).
3. H031/H032 tests: `n=10000` not a multiple of 32 left a 16-element
   uninitialized tail — fixed to `n=10016`; wrong expected constant
   `0x0400` for 2^-10 corrected to `0x1400`.
4. Mojo 1.1.0 API port of the inherited code (pointer subscript syntax,
   `unsafe_store(offset, val)`, reserved words, no scalar `.sqrt()`).

### SÓLRÚN re-scopes applied (mathematically justified, recorded)

- H029: SiLU monotonicity re-scoped (SiLU has a global minimum at
  x≈−1.2785; non-decreasing only on [0,10] + dip check).
- H022/H023/H024/H026/H027/H029: per-element ulp envelope
  `|got−ref| ≤ base + 2^-10·|ref|` — strict absolute bounds are infeasible
  when kernel and reference round independently to fp16 (double rounding
  gives exactly 1 ulp at output magnitude).
- H023: ≥32 GFLOPS target missed honestly — 7.16 GFLOPS measured; DEVLOG
  shortfall analysis recorded (H007's 16 GFLOPS used fp16 accumulation;
  the shipped kernel widens to fp32, trading speed for accuracy).
- H032: contract recorded as max ≤ 0.43, rms ≤ 0.25 (derivation max_abs/14,
  scale/√12); measured 0.424/0.237 — inside with margin.

## C2 VERDICT: READY

The ARMVEGR compute core is **READY** to serve as the CPU reference for the
Phase-D wall, **under the documented comparison standard**: the Phase-D
wall must compare against this reference using the per-kernel error
contracts in the table above (ulp envelopes / quantization contracts),
**not** bitwise equality.

Why READY and why the condition:
- **Deterministic.** Fixed seeds reproduce bit-identical outputs
  (oracle re-runs; c2_verify). A reference that wobbles cannot anchor a
  wall — this one does not wobble.
- **Correct within contract.** 26/26 independent-oracle cases and 241/241
  unit checks pass with zero failures; every kernel is inside its
  documented bound with margin on the worst observed input.
- **Not bit-exact by construction.** fp16 kernels round independently of
  any float64 reference; the SÓLRÚN re-scopes prove strict absolute
  bit-equality bounds are mathematically infeasible (double rounding).
  Demanding bit-equality at the wall would fail a correct implementation —
  the envelope is the honest standard, and it is written down per kernel.
- **Perf is a separate axis.** The 7.16-vs-32 GFLOPS shortfall is real and
  documented, but the verdict concerns trustworthiness as a reference, and
  a slower-correct reference is still a correct reference. Speed is
  Campaign 9's problem.

**No remediation slices (H201+) are required.** Every kernel met its
contract; no kernel is NOT-READY. If Phase-D later needs a kernel the C2
set does not cover, that is new work, not remediation.
