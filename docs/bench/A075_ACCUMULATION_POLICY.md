# A-075 — Accumulation policy

Roadmap acceptance: *"FP32 vs FP16/BF16 accumulate per kernel,
chosen by numerics evidence. Acceptance: policy table with the
logit-gap evidence behind each choice."*

## Verdict

**Every reduction in the engine accumulates in FP32.** FP16 and
BF16 accumulation are rejected at model scale by direct
measurement (below). FP16/BF16 remain lawful as *storage* — quant
block scale fields are FP16 and are decoded to Float32 before any
arithmetic, and CPU GEMM operand storage is F16/BF16 — because
A-047 proved storage rounding is flat in K while accumulation
rounding grows with K. The lever is the accumulator, and the
evidence pins it to FP32.

The shipped shaders already implement exactly this policy: the
A-075 survey (all 25 `.comp` sources read line by line) found
FP32 accumulators, FP32 shared-memory reductions, and FP32
outputs in every kernel, with FP16 appearing only as decoded
scale fields. This slice ratifies that state with evidence,
pins it in `core/accum_policy.mojo`, and guards it with six
E-MASTER cases (`accum_policy.*`) so a future FP16/BF16-
accumulate variant cannot land without overturning filed
numbers.

## Method

Emulation accumulators in `core/accum_policy.mojo` reproduce,
on the host, what a kernel *would* compute if its accumulator
register were the named dtype: products formed in Float32, the
running sum rounded to the accumulator dtype after every
addition (accumulator-register model, serial order — the
conservative case; the shipped kernels' blocked/tree FP32
reductions sit inside the FP32 envelope measured here).
References are independent Float64 scalar loops over the exact
stored inputs. Logit rows are graded with `core/parity_battery`
rank/gap under raw-oracle discipline (Float64 reference row,
never a template-rendered prompt; law-3 bands: rank ≤ 2 with
gap < 1.0 = faithful). Probe: `aesir_engine/tests/
bench_accum_policy_a075.mojo`, log `hidden_files/a075_bench.log`
(A075_BENCH: PASS). The same batteries run as E-MASTER cases in
`aesir_engine/tests/test_accum_policy_a075.mojo` (standalone
driver log `hidden_files/a075_driver.log`: A075_DRIVER_ALL_PASS).

## Evidence (measured, purpleraider host, deterministic seeds)

### DOT — dot-product error vs Float64, by K

| K | err FP32 | err FP16 | err BF16 |
|---|---|---|---|
| 256 | 1.3e-07 | 4.8e-04 | 9.0e-03 |
| 1024 | 3.3e-08 | 2.1e-03 | 9.5e-03 |
| 4096 | 8.7e-07 | 2.3e-02 | 4.8e-02 |
| 14336 | 7.3e-06 | 2.8e-02 | 3.2e-01 |

FP16 error grows ~47× from K=256 to K=4096 and BF16 reaches
0.32 absolute at FFN width; FP32 stays ≤ 7.3e-06 at every K.
This is the A-047 discriminator run at production K: with FP32
accumulation the F16/BF16 GEMM relative error was flat (4.2e-4 /
4.3e-4, dominated by the single output rounding); with 16-bit
accumulation the error is K-growing, as A-047 predicted.

### LOGIT — lm_head-shaped GEMV, teacher-forcing battery

16 hidden vectors (positions) × vocab 1024 rows × K=4096, each
mode's row graded against the Float64 reference row's top token:

| Mode | Faithful (rank/gap) | Worst rank | Max gap | Top-1 agree | Max row dev |
|---|---|---|---|---|---|
| FP32 | 16/16 | 1 | 0.0 | 16/16 | 1.3e-05 |
| FP16 | 16/16 | 2 | 0.035 | **14/16** | 0.11 |
| BF16 | 15/16 | **3** | **0.72** | 13/16 | 0.87 |

BF16 accumulation is a plain divergence: worst rank 3, gap
0.72, one position out of the faithful band. FP16 is subtler
and worse than it looks: it stays inside the rank/gap band yet
flips the greedy top-1 at 2 of 16 positions — its per-logit
noise (max deviation 0.11) is the size of real top-2 margins,
so generated trajectories diverge from the FP32 policy even
where a single-position grade reads "near-tie". A policy is
judged on the tokens it produces, not only on the band.

### NORM — RMSNorm sum-of-squares

| n | rel err FP32 | rel err FP16 | rel err BF16 |
|---|---|---|---|
| 4096 (std ~1.4 inputs) | 8.9e-07 | 0.067 | 0.53 |
| 14336 (std ~1.4 inputs) | 4.0e-06 | 0.34 | 0.84 |
| 14336 (std ~3, outlier-scale) | 2.6e-06 | **+inf** | 0.84 |

At FFN width the FP16 partial sum passes the 65504 ceiling on
residual streams with outlier channels (a documented property
of real LLM residual streams) and the norm becomes +inf —
a hard failure, not a precision loss. Below the ceiling, small
squares are rounded away once the partial sum is large (34%
under-count at n=14336).

### MASS / ATTN — softmax denominator and weighted-V, T=4096

| Battery | FP32 | FP16 | BF16 |
|---|---|---|---|
| exp-mass rel err | 3.6e-06 | 0.099 | 0.81 |
| weighted-V abs err | 2.0e-08 | 7.3e-04 | 2.5e-02 |

Once an FP16 partial sum passes ~1024, its ULP (0.5) swallows
typical exp terms whole; BF16 (ULP 8 at that scale) loses 81%
of the mass. The attention output error follows the same law.

### Why no carve-outs

The QK dot at head_dim 128 is the least-bad FP16 case (DOT
K=256 err 4.8e-04) — but the same attention kernels accumulate
the weighted-V sum and the softmax denominator over unbounded
context T, where the MASS/ATTN rows forbid 16-bit accumulation,
and splitting accumulator dtype inside one kernel buys nothing:
storage is already FP32 end-to-end, and on the A-055 pipeline
(vulkan1.0 / SPIR-V 1.0, no FP16 arithmetic extension declared;
Vulkan 1.0 context enables no `shaderFloat16` feature) an FP16
variant could not even compile or run today — the A-073
subgroup wall is the same class. The RADV hardware itself
reports `shaderFloat16 = true`; this is a numerics verdict,
not a silicon limit, and no measured speed case exists for
16-bit accumulation on this path (the GEMV/GEMM kernels are
bandwidth-shaped at FP32 storage already, A-068/A-073).

## Policy table — Vulkan kernels (SHADER_MANIFEST order)

All rows: inputs dequantized/decoded to Float32 before
arithmetic where quantized; outputs Float32 (sampling emits a
uint token id). "Accumulate" is the policy choice ratified by
this slice; the survey found the shipped code already in
compliance on every row.

| # | Kernel | Reduction | Accumulate | Evidence |
|---|---|---|---|---|
| 0 | attention_decode | QK dot, softmax denom, weighted-V | FP32 | ATTN + MASS |
| 1 | attention_decode_strided | QK dot, softmax denom, weighted-V | FP32 | ATTN + MASS |
| 2 | attention_prefill | QK dot, softmax denom, weighted-V | FP32 | ATTN + MASS |
| 3 | elementwise | none (pointwise) | — | — |
| 4 | embed_gather | none (copy) | — | — |
| 5 | gemm_f32 | dot over K | FP32 | DOT + LOGIT |
| 6 | gemv_f32 | dot over K | FP32 | DOT + LOGIT |
| 7 | iq1_s_gemv | dot over K (grid dequant) | FP32 | DOT |
| 8 | iq2_xxs_gemv | dot over K (grid dequant) | FP32 | DOT |
| 9 | iq3_xxs_gemv | dot over K (grid dequant) | FP32 | DOT |
| 10 | iq4_nl_gemv | dot over K (table dequant) | FP32 | DOT |
| 11 | kv_append | none (copy, bit-exact) | — | — |
| 12 | kv_append_chunk | none (copy, bit-exact) | — | — |
| 13 | q4k_gemv | dot over K (K-quant dequant) | FP32 | DOT + LOGIT |
| 14 | q5_k_gemv | dot over K (K-quant dequant) | FP32 | DOT |
| 15 | q6_k_gemv | dot over K (K-quant dequant; lm_head) | FP32 | DOT + LOGIT |
| 16 | q8_0_gemm | dot over K | FP32 | DOT + LOGIT |
| 17 | q8_0_gemv | dot over K | FP32 | DOT + LOGIT |
| 18 | rmsnorm | sum of squares | FP32 | NORM |
| 19 | rope | none (pointwise rotation) | — | — |
| 20 | rope_batched | none (pointwise rotation) | — | — |
| 21 | sampling_greedy | argmax over FP32 logits | FP32 (compare) | LOGIT bands |
| 22 | sampling_sample | exp-mass over ranked logits | FP32 | MASS |
| 23 | softmax | max + exp-sum | FP32 | MASS |
| 24 | vec_add | none (pointwise) | — | — |

## Policy table — CPU reduction sites (core/compute.mojo et al.)

| Site | Operands | Accumulate | Evidence |
|---|---|---|---|
| cpu.gemm_f16 | F16 storage | FP32 | A-047 bounds + DOT |
| cpu.gemm_bf16 | BF16 storage (exact widening) | FP32 | A-047 bounds + DOT |
| cpu.gemm_quant_family | Q8_0 / K-quant / IQ | FP32 | DOT |
| cpu.rmsnorm | F32 | FP32 | NORM |
| cpu.fused_attention | F32 online softmax | FP32 | ATTN + MASS |

One known legacy exception, recorded not hidden: the legacy
`flash_attention_2` path carries repeated F16 partial-output
stores with no filed numerical bound (Capability Ledger
AES-CPU-005). It is outside the Vulkan policy surface above;
bringing it under this policy is recorded as immediate next
work in the team CAMPAIGN_STATE.md.

## Suite

E-MASTER (run_all, gfx1151): 546 passed / 1 failed / 2 skipped
/ 549 total = seat baseline at 73 banked (540/1/2/543) + the 6
new `accum_policy.*` cases, all passing. Sole failure is the
pre-existing tolerated `gguf.tensor_directory_interface`
(J-022 drift). Log: `hidden_files/a075_run_all.log`
(sha256 407cbf9d19e6fd696d73534c9e604155d7041ea50e63a894e7a49d59210aab9d).
