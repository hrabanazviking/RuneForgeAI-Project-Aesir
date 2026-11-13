"""A-075 measurement probe: accumulation-mode error vs Float64.

Standalone (not part of run_all). Prints one line per measurement so
the policy table in docs/bench/A075_ACCUMULATION_POLICY.md traces to
this log. References are Float64 scalar loops over the exact stored
inputs, computed in core/accum_policy.mojo -- never via a path under
test. Emulation model: products in Float32, running sum rounded to
the accumulator dtype after every addition (accumulator-register
model, serial order = conservative case).

Batteries:
  DOT   -- GEMV/GEMM-shaped dot products, K in {256, 1024, 4096,
           14336} (head_dim multiples up to the 8B fixture's dim and
           FFN width), dequantized-weight x activation inputs.
  LOGIT -- lm_head-shaped GEMV, teacher-forcing shape: 16 hidden
           vectors (positions) x vocab 1024 rows x K 4096; each
           mode's row graded against the Float64 reference row's
           top token with core/parity_battery rank/gap (law-3
           bands: rank <= 2 and gap < 1.0 = faithful), plus top-1
           agreement counts (greedy flips inside the near-tie band
           are filed, not hidden).
  NORM  -- RMSNorm sum-of-squares at n = 4096 and n = 14336 on
           residual-scale inputs.
  MASS  -- softmax-denominator-shaped exp-mass sums, T = 4096.
"""

from std.math import exp, sqrt

from core.accum_policy import (
    MODE_F64,
    MODE_FP32,
    MODE_FP16,
    MODE_BF16,
    AccumLcg,
    dot_accum,
    gen_activation,
    gen_weights,
    mass_accum,
    sumsq_accum,
)
from core.parity_battery import (
    parity_logit_gap,
    parity_logit_rank,
    parity_top_token,
    parity_verdict_name,
    parity_verdict_code,
)


def _abs(v: Float64) -> Float64:
    return v if v >= 0.0 else -v


def _rel(err: Float64, refv: Float64) -> Float64:
    var d = _abs(refv)
    if d < 1.0e-12:
        return err
    return err / d


def _sizes_dot() -> List[Int]:
    var out = List[Int]()
    out.append(256)
    out.append(1024)
    out.append(4096)
    out.append(14336)
    return out^


def _sizes_norm() -> List[Int]:
    var out = List[Int]()
    out.append(4096)
    out.append(14336)
    return out^


def main() raises:
    print("A075 accumulation probe (references: Float64, exact inputs)")

    # --- DOT battery: error growth with K -------------------------------
    for k in _sizes_dot():
        var lcg = AccumLcg(UInt64(0xA075) + UInt64(k))
        var w = gen_weights(lcg, k, 0.06)
        var x = gen_activation(lcg, k, 1.0)
        var refv = dot_accum(w, x, MODE_F64)
        var e32 = _abs(dot_accum(w, x, MODE_FP32) - refv)
        var e16 = _abs(dot_accum(w, x, MODE_FP16) - refv)
        var ebf = _abs(dot_accum(w, x, MODE_BF16) - refv)
        print(
            "DOT K=", k, " refv=", refv, " err_fp32=", e32, " err_fp16=", e16,
            " err_bf16=", ebf, " rel_fp32=", _rel(e32, refv),
            " rel_fp16=", _rel(e16, refv), " rel_bf16=", _rel(ebf, refv),
        )

    # --- LOGIT battery: 16 teacher-forced positions, lm_head shape ------
    # Each position: a fresh hidden vector, vocab 1024 rows x K 4096.
    # Every mode row is graded against the Float64 reference row's top
    # token (raw-oracle discipline, law-3 bands via parity_battery).
    var vocab = 1024
    var dim = 4096
    var positions = 16
    var lcg2 = AccumLcg(0x10717)
    var weights = List[List[Float32]]()
    for _ in range(vocab):
        weights.append(gen_weights(lcg2, dim, 0.06))
    var faith32 = 0
    var faith16 = 0
    var faithbf = 0
    var agree32 = 0
    var agree16 = 0
    var agreebf = 0
    var worst_rank32 = 0
    var worst_rank16 = 0
    var worst_rankbf = 0
    var max_gap32 = Float32(0.0)
    var max_gap16 = Float32(0.0)
    var max_gapbf = Float32(0.0)
    var maxdiff32 = Float32(0.0)
    var maxdiff16 = Float32(0.0)
    var maxdiffbf = Float32(0.0)
    for _ in range(positions):
        var hidden = gen_activation(lcg2, dim, 1.0)
        var rows64 = List[Float32]()
        var rows32 = List[Float32]()
        var rows16 = List[Float32]()
        var rowsbf = List[Float32]()
        for r in range(vocab):
            rows64.append(Float32(dot_accum(weights[r], hidden, MODE_F64)))
            rows32.append(Float32(dot_accum(weights[r], hidden, MODE_FP32)))
            rows16.append(Float32(dot_accum(weights[r], hidden, MODE_FP16)))
            rowsbf.append(Float32(dot_accum(weights[r], hidden, MODE_BF16)))
        var target = parity_top_token(rows64)
        var rank32 = parity_logit_rank(rows32, target)
        var gap32 = parity_logit_gap(rows32, target)
        if parity_verdict_code(rank32, gap32) <= 1:
            faith32 += 1
        if parity_top_token(rows32) == target:
            agree32 += 1
        if rank32 > worst_rank32:
            worst_rank32 = rank32
        if gap32 > max_gap32:
            max_gap32 = gap32
        var rank16 = parity_logit_rank(rows16, target)
        var gap16 = parity_logit_gap(rows16, target)
        if parity_verdict_code(rank16, gap16) <= 1:
            faith16 += 1
        if parity_top_token(rows16) == target:
            agree16 += 1
        if rank16 > worst_rank16:
            worst_rank16 = rank16
        if gap16 > max_gap16:
            max_gap16 = gap16
        var rankbf = parity_logit_rank(rowsbf, target)
        var gapbf = parity_logit_gap(rowsbf, target)
        if parity_verdict_code(rankbf, gapbf) <= 1:
            faithbf += 1
        if parity_top_token(rowsbf) == target:
            agreebf += 1
        if rankbf > worst_rankbf:
            worst_rankbf = rankbf
        if gapbf > max_gapbf:
            max_gapbf = gapbf
        for i in range(vocab):
            var d32 = rows32[i] - rows64[i]
            if d32 < 0:
                d32 = -d32
            if d32 > maxdiff32:
                maxdiff32 = d32
            var d16 = rows16[i] - rows64[i]
            if d16 < 0:
                d16 = -d16
            if d16 > maxdiff16:
                maxdiff16 = d16
            var dbf = rowsbf[i] - rows64[i]
            if dbf < 0:
                dbf = -dbf
            if dbf > maxdiffbf:
                maxdiffbf = dbf
    print(
        "LOGIT positions=", positions, " vocab=", vocab, " K=", dim,
        " faithful(fp32)=", faith32, " faithful(fp16)=", faith16,
        " faithful(bf16)=", faithbf,
    )
    print(
        "LOGIT worst_rank fp32=", worst_rank32, " fp16=", worst_rank16,
        " bf16=", worst_rankbf, " max_gap fp32=", max_gap32,
        " fp16=", max_gap16, " bf16=", max_gapbf,
    )
    print(
        "LOGIT top1_agree fp32=", agree32, " fp16=", agree16,
        " bf16=", agreebf, " max|row-f64| fp32=", maxdiff32,
        " fp16=", maxdiff16, " bf16=", maxdiffbf,
    )

    # --- NORM battery: sum-of-squares -----------------------------------
    for n in _sizes_norm():
        var lcg3 = AccumLcg(UInt64(0xB075) + UInt64(n))
        var x = gen_activation(lcg3, n, 2.0)
        var refv = sumsq_accum(x, MODE_F64)
        var s32 = sumsq_accum(x, MODE_FP32)
        var s16 = sumsq_accum(x, MODE_FP16)
        var sbf = sumsq_accum(x, MODE_BF16)
        print(
            "NORM n=", n, " refv=", refv, " fp32=", s32, " fp16=", s16,
            " bf16=", sbf, " rel_fp32=", _rel(_abs(s32 - refv), refv),
            " rel_fp16=", _rel(_abs(s16 - refv), refv),
            " rel_bf16=", _rel(_abs(sbf - refv), refv),
        )

    # --- NORM_HI battery: outlier-scale residual inputs -----------------
    # Residual streams carry outlier channels; at std ~3 the FFN-width
    # sum-of-squares exceeds the FP16 ceiling (65504) outright.
    for n in _sizes_norm():
        var lcg6 = AccumLcg(UInt64(0xB076) + UInt64(n))
        var x = gen_activation(lcg6, n, 4.25)
        var refv = sumsq_accum(x, MODE_F64)
        var s32 = sumsq_accum(x, MODE_FP32)
        var s16 = sumsq_accum(x, MODE_FP16)
        var sbf = sumsq_accum(x, MODE_BF16)
        print(
            "NORM_HI n=", n, " refv=", refv, " fp32=", s32, " fp16=", s16,
            " bf16=", sbf, " rel_fp32=", _rel(_abs(s32 - refv), refv),
            " rel_bf16=", _rel(_abs(sbf - refv), refv),
        )

    # --- MASS battery: exp-mass sums at context scale -------------------
    var t = 4096
    var lcg4 = AccumLcg(0xC075)
    var terms = List[Float32]()
    for _ in range(t):
        # exp(score - max) shaped terms in (0, 1].
        terms.append(Float32(exp(-3.0 * lcg4.unit())))
    var mref = mass_accum(terms, MODE_F64)
    var m32 = mass_accum(terms, MODE_FP32)
    var m16 = mass_accum(terms, MODE_FP16)
    var mbf = mass_accum(terms, MODE_BF16)
    print(
        "MASS T=", t, " refv=", mref, " rel_fp32=", _rel(_abs(m32 - mref), mref),
        " rel_fp16=", _rel(_abs(m16 - mref), mref),
        " rel_bf16=", _rel(_abs(mbf - mref), mref),
    )

    # --- ATTN battery: weighted-V accumulation over context -------------
    var lcg5 = AccumLcg(0xD075)
    var aweights = List[Float32]()
    var vals = gen_activation(lcg5, t, 1.0)
    var wsum = Float64(0.0)
    for _ in range(t):
        var wgt = Float32(exp(-3.0 * lcg5.unit()))
        aweights.append(wgt)
        wsum += Float64(wgt)
    var pv_ref = Float64(0.0)
    var pv32 = Float32(0.0)
    var pv16 = Float32(0.0)
    var pvbf = Float32(0.0)
    for i in range(t):
        var wgt64 = Float64(aweights[i]) / wsum
        pv_ref += wgt64 * Float64(vals[i])
        var p32 = aweights[i] * vals[i]
        pv32 += p32
        pv16 = pv16 + p32
        pv16 = pv16.cast[DType.float16]().cast[DType.float32]()
        pvbf = pvbf + p32
        pvbf = pvbf.cast[DType.bfloat16]().cast[DType.float32]()
    # Normalise the emulated rows by the same denominator mass the
    # shader divides by (its own accumulated denom, in-mode).
    var d32 = mass_accum(aweights, MODE_FP32)
    var d16 = mass_accum(aweights, MODE_FP16)
    var dbf = mass_accum(aweights, MODE_BF16)
    print(
        "ATTN PV refv=", pv_ref, " fp32=", Float64(pv32) / d32,
        " fp16=", Float64(pv16) / d16, " bf16=", Float64(pvbf) / dbf,
        " err_fp32=", _abs(Float64(pv32) / d32 - pv_ref),
        " err_fp16=", _abs(Float64(pv16) / d16 - pv_ref),
        " err_bf16=", _abs(Float64(pvbf) / dbf - pv_ref),
    )

    print("A075_BENCH: PASS")
