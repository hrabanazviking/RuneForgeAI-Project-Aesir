# A-042 — CPU prefill batching audit (Z13 / Zen 5)

Roadmap acceptance: *numbers filed; the better path is the default.*
Measured on purpleraider (ASUS ROG Flow Z13, Strix Halo, Zen 5),
2026-11-12, base seat main 56d5606f (A-039 banked, 39 of 216).
Drivers: `aesir_engine/tests/bench_prefill_batching_a042.mojo`
(kernel level) and `aesir_engine/tests/bench_prefill_e2e_a042.mojo`
(end-to-end, pinned stories260K F16 fixture, sha256
57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3).
Full evidence: `hidden_files/A042_LEDGER.md`.

## The two paths

- **Batched**: one GEMM call per projection with A.rows == chunk
  length (production prefill: `forward_pass_batched`, facade chunk
  cap 256 via `AESIR_PREFILL_BATCH`).
- **Row-by-row**: A.rows == 1 calls, one per token (the decode
  shape; production fallback when the cap is 1).

## Kernel level (single-thread direct range calls, median of reps)

Speedup = row-by-row time / batched time (> 1 means batched wins).

### Dense F16 (`_gemm_f16_dense_range`) — a tie in the body itself

| K x N | rows 8 | rows 32 | rows 128 |
|---|---|---|---|
| 288 x 512 (260K scale) | 1.00 | 1.00 | 1.00 |
| 1024 x 1024 | 1.01 | 1.00 | 1.00 |
| 2048 x 2048 | — | 1.01 | 1.01 |

Parity: bitwise-identical outputs at every shape (the per-output
reduction order does not depend on row partitioning). The dense
body neither gains nor loses from batching: each output's weight
vector stays cache-hot across rows in both shapes.

### Q8_0 — the batched body was broken; fixed in this slice

Before the fix, `_gemm_q8_0_fast_range` (the multi-row path every
Q8_0 prefill takes) decoded scalar-ly and gathered its dot
vectors lane-by-lane from scalar loads. Measured batched
"speedups" of **0.11–0.19** — batched prefill was **5–9x slower**
than calling the A-038 GEMV range per row, at every shape.

The fix (this slice, `core/compute.mojo`): decode is now two
width-16 int8 loads widened to F32 and scaled per block; the dot
is the dense range's reduction (width-16 vector loads, per-chunk
`reduce_add`, scalar tail). After the fix:

| K x N | rows 8 | rows 32 | rows 128 |
|---|---|---|---|
| 288 x 512 | 0.88 | 0.95 | 0.96 |
| 1024 x 1024 | 1.06 | 1.15 | 1.17 |
| 2048 x 2048 | — | 1.35 | 1.38 |

The batched path itself got **7–9x faster** (e.g. 2048x2048
rows=128: 224.2 ms → 31.5 ms). What remains is honest: at the
small 260K geometry the decode-once scratch is not quite free
(~0.95x, a wash); from 1024-wide geometries up, decode
amortization wins and grows with shape. Parity after the fix
(non-dyadic bench fixture): >= 99.7% of outputs bitwise-equal to
the per-row GEMV path, max abs diff 0.0625 — the accepted
fast-path rounding class (A-038 filed the same class); on exact
(dyadic) data the suite case is bitwise.

### Q4_0 (legacy scalar exemplar) — there is no batched body

| K x N | rows 32 | rows 128 |
|---|---|---|
| 288 x 512 | 1.00 | 1.00 |
| 1024 x 1024 | 1.00 | — |

Bitwise parity. The legacy formats (Q4_0/Q4_1/Q5_0/Q5_1/Q8_1/FP8
and the GPTQ-family wrappers) implement multi-row GEMM as one
serial loop over rows with per-row weight re-decode — a batched
call and row-by-row calls execute identical inner work. Batching
cannot help them until they grow fast ranges; that is filed as
follow-on work in the team CAMPAIGN_STATE.md (it is a build
campaign of its own, not an audit fix).

## Public dispatch level (threaded `par_for`, production call shape)

| Path | K x N, rows | Speedup |
|---|---|---|
| dense F16 `gemm_f16` | 288 x 512, 128 | 2.34 |
| dense F16 `gemm_f16` | 1024 x 1024, 32 | 23.1 |
| Q8_0 `gemm_q8_0` (post-fix) | 288 x 512, 128 | 2.12 |
| Q8_0 `gemm_q8_0` (post-fix) | 1024 x 1024, 32 | 26.2 |

Through the real dispatch, batching wins big: per-call fixed
costs (par_for engagement, per-dispatch config reads — the A-037
census's grouped-row C-008 inefficiency) are paid once per chunk
instead of once per token.

## End-to-end (stories260K F16, forward_pass vs forward_pass_batched)

| Prompt | Per-token | Batched | Speedup |
|---|---|---|---|
| 64 tokens | 9,140 tok/s | 18,359 tok/s | 2.01 |
| 128 tokens (full fixture ctx) | 7,314 tok/s | 8,062 tok/s | 1.10 |

Last token identical on both paths at both lengths (416).
The 128-token gain dilutes because attention is per-row in both
paths and grows with position; the GEMM-side win is what this
audit controls. (The production chunk cap, 256, exceeds this
fixture's 128-token context; the 128 leg is one full chunk.)

## Verdict — the better path is the default, now with the numbers

1. **Batched is the better prefill path and it is the default.**
   `core/prefill_batching.mojo` pins the policy
   (`prefill_path_for_rows`: rows >= 2 → batched; 1 row → the
   decode shape), with `PREFILL_DEFAULT_CHUNK_CAP = 256` matching
   the facade's existing default in `aesir.mojo`
   (`_prefill_batch_cap`, AESIR_PREFILL_BATCH=1 remains the
   operator override). Five E-MASTER cases
   (`prefill.batching_*`) pin the policy and the batched-vs-rows
   parity so the default cannot silently change numbers.
2. **The wave lesson is confirmed for dense F16**: batching buys
   ~nothing inside the GEMM body (1.00x) — the end-to-end win
   (1.1–2.0x here, more at dispatch level) comes from paying
   fixed per-call costs once per chunk, not from the kernel.
3. **For Q8_0 the audit found and fixed a real defect**: the
   batched body was 5–9x slower than the row-by-row path it
   replaced. Post-fix it ties at small geometry and wins
   1.15–1.38x at prefill geometries, and the public dispatch
   wins 2.1–26x.
4. **Legacy scalar formats gain nothing from batching** (no
   batched body exists) — recorded as follow-on work, not
   silently left: see the team CAMPAIGN_STATE.md next-work item.
