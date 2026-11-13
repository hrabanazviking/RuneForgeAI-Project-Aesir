"""Accumulation policy (A-075): FP32 vs FP16/BF16 accumulate per
kernel, chosen by numerics evidence.

The policy table lives in core/accum_policy.mojo (25 Vulkan kernels
in SHADER_MANIFEST order + 5 CPU reduction sites). These cases pin
the table's shape and re-run the evidence battery that ratifies it,
against Float64 references over the exact stored inputs
(raw-oracle discipline: the reference is an independent scalar
Float64 loop in the module under test's own arithmetic, never a
path being graded; logit rows are graded with
core/parity_battery rank/gap, law-3 bands).

Filed measurements (tests/bench_accum_policy_a075.mojo,
hidden_files/a075_bench.log, docs/bench/A075_ACCUMULATION_POLICY.md):

  DOT   err at K=4096: fp32 8.7e-07, fp16 2.3e-02, bf16 4.8e-02;
        fp16 error grows ~47x from K=256 to K=4096 while fp32
        stays <= 7.3e-06 through K=14336.
  LOGIT 16 positions, vocab 1024 x K 4096: fp32 faithful 16/16,
        worst rank 1, top-1 agreement 16/16, max row deviation
        1.3e-05. fp16: rank/gap faithful 16/16 but worst rank 2 and
        top-1 agreement only 14/16 -- accumulation noise (max row
        deviation 0.11) is the size of real top-2 margins, so greedy
        trajectories flip. bf16: faithful 15/16, worst rank 3
        (divergence), max gap 0.72, agreement 13/16, deviation 0.87.
  NORM  sumsq rel err at n=14336: fp32 4.0e-06, fp16 0.34,
        bf16 0.84. On outlier-scale inputs (std ~3) fp16 sumsq is
        +inf at n=14336 (partial sums pass the 65504 ceiling).
  MASS  exp-mass rel err at T=4096: fp32 3.6e-06, fp16 0.099,
        bf16 0.81. ATTN weighted-V abs err: fp32 2.0e-08,
        fp16 7.3e-04, bf16 2.5e-02.

Verdict pinned here: every reduction accumulates in FP32;
ACCUM_NONE only for pure elementwise/copy kernels. These cases are
pure host and always run; no device or fixture is needed. The
shipped shaders already implement exactly this policy (A-075
survey, filed in the bench doc): the slice ratifies it with
evidence and forbids a future FP16/BF16-accumulate variant from
landing without overturning these numbers.
"""

from std.math import exp

from core.accum_policy import (
    ACCUM_FP32,
    ACCUM_NONE,
    CPU_SITE_COUNT,
    EV_NONE,
    KERNEL_COUNT,
    MODE_BF16,
    MODE_F64,
    MODE_FP16,
    MODE_FP32,
    POLICY_ROW_COUNT,
    AccumLcg,
    accum_dtype_name,
    cpu_site_accum_policy,
    cpu_site_evidence,
    cpu_site_name,
    dot_accum,
    gen_activation,
    gen_weights,
    kernel_accum_policy,
    kernel_evidence,
    kernel_name,
    mass_accum,
    round_accum,
    sumsq_accum,
)
from core.parity_battery import (
    parity_logit_gap,
    parity_logit_rank,
    parity_top_token,
    parity_verdict_code,
)


def _abs64(v: Float64) -> Float64:
    return v if v >= 0.0 else -v


def _rel64(err: Float64, refv: Float64) -> Float64:
    var d = _abs64(refv)
    if d < 1.0e-12:
        return err
    return err / d


def test_accum_policy_table_completeness() raises:
    print("--- Testing accumulation policy table completeness (A-075) ---")
    if KERNEL_COUNT != 25:
        raise Error("policy table must cover all 25 manifest kernels")
    if POLICY_ROW_COUNT != KERNEL_COUNT + CPU_SITE_COUNT:
        raise Error("policy row count mismatch")
    if CPU_SITE_COUNT != 5:
        raise Error("policy table must cover the 5 CPU reduction sites")
    var manifest = String("")
    try:
        var f = open("aesir_engine/shaders/SHADER_MANIFEST.json", "r")
        manifest = f.read()
        f.close()
    except:
        raise Error("SHADER_MANIFEST.json unreadable from repo root")
    for kid in range(KERNEL_COUNT):
        var name = kernel_name(kid)
        if name == String(""):
            raise Error("kernel id with no name in policy table")
        if name not in manifest:
            raise Error("policy kernel name absent from manifest: " + name)
        for other in range(kid + 1, KERNEL_COUNT):
            if kernel_name(other) == name:
                raise Error("duplicate kernel name in policy table: " + name)
    for sid in range(KERNEL_COUNT, KERNEL_COUNT + CPU_SITE_COUNT):
        if cpu_site_name(sid) == String(""):
            raise Error("cpu site id with no name in policy table")
    print("accum_policy table completeness: PASS")


def test_accum_policy_table_uniform_fp32() raises:
    print("--- Testing accumulation policy uniformity (A-075) ---")
    for kid in range(KERNEL_COUNT):
        var ev = kernel_evidence(kid)
        var pol = kernel_accum_policy(kid)
        if ev == EV_NONE:
            if pol != ACCUM_NONE:
                raise Error(
                    "non-reduction kernel must carry ACCUM_NONE: "
                    + kernel_name(kid)
                )
        else:
            if pol != ACCUM_FP32:
                raise Error(
                    "reduction kernel must accumulate in FP32: "
                    + kernel_name(kid)
                )
    for sid in range(KERNEL_COUNT, KERNEL_COUNT + CPU_SITE_COUNT):
        if cpu_site_accum_policy(sid) != ACCUM_FP32:
            raise Error(
                "cpu reduction site must accumulate in FP32: "
                + cpu_site_name(sid)
            )
        if cpu_site_evidence(sid) == EV_NONE:
            raise Error("cpu site misclassified as non-reduction")
    if accum_dtype_name(ACCUM_FP32) != String("fp32"):
        raise Error("dtype name drift")
    if accum_dtype_name(ACCUM_NONE) != String("none"):
        raise Error("dtype name drift")
    print("accum_policy uniform FP32: PASS")


def test_accum_policy_dot_error_k_scaling() raises:
    print("--- Testing accumulation dot error vs K (A-075) ---")
    var err16_256 = Float64(0.0)
    var err32_4096 = Float64(0.0)
    var err16_4096 = Float64(0.0)
    var errbf_4096 = Float64(0.0)
    var ks = List[Int]()
    ks.append(256)
    ks.append(4096)
    for k in ks:
        var lcg = AccumLcg(UInt64(0xA075) + UInt64(k))
        var w = gen_weights(lcg, k, 0.06)
        var x = gen_activation(lcg, k, 1.0)
        var refv = dot_accum(w, x, MODE_F64)
        var e32 = _abs64(dot_accum(w, x, MODE_FP32) - refv)
        var e16 = _abs64(dot_accum(w, x, MODE_FP16) - refv)
        var ebf = _abs64(dot_accum(w, x, MODE_BF16) - refv)
        if k == 256:
            err16_256 = e16
        else:
            err32_4096 = e32
            err16_4096 = e16
            errbf_4096 = ebf
    # Filed: fp32 8.7e-07, fp16 2.3e-02, bf16 4.8e-02 at K=4096.
    if not (err32_4096 < 1.0e-4):
        raise Error("fp32 dot error at K=4096 above filed bound")
    if not (err16_4096 > 0.005):
        raise Error("fp16 dot error at K=4096 below filed floor")
    if not (err16_4096 > 100.0 * err32_4096):
        raise Error("fp16 dot error not >= 100x fp32 at K=4096")
    if not (errbf_4096 > err16_4096):
        raise Error("bf16 dot error should exceed fp16 at K=4096")
    if not (err16_4096 > 10.0 * err16_256):
        raise Error("fp16 dot error does not grow with K")
    print("accum_policy dot error K-scaling: PASS")


def test_accum_policy_logit_gap_battery() raises:
    print("--- Testing accumulation logit-gap battery (A-075) ---")
    var vocab = 1024
    var dim = 4096
    var positions = 16
    var lcg = AccumLcg(0x10717)
    var weights = List[List[Float32]]()
    for _ in range(vocab):
        weights.append(gen_weights(lcg, dim, 0.06))
    var faith32 = 0
    var faithbf = 0
    var agree32 = 0
    var agree16 = 0
    var worst_rankbf = 0
    var max_gapbf = Float32(0.0)
    var maxdiff32 = Float32(0.0)
    var maxdiffbf = Float32(0.0)
    for _ in range(positions):
        var hidden = gen_activation(lcg, dim, 1.0)
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
        var rankbf = parity_logit_rank(rowsbf, target)
        var gapbf = parity_logit_gap(rowsbf, target)
        if parity_verdict_code(rankbf, gapbf) <= 1:
            faithbf += 1
        if rankbf > worst_rankbf:
            worst_rankbf = rankbf
        if gapbf > max_gapbf:
            max_gapbf = gapbf
        if parity_top_token(rows16) == target:
            agree16 += 1
        for i in range(vocab):
            var d32 = rows32[i] - rows64[i]
            if d32 < 0:
                d32 = -d32
            if d32 > maxdiff32:
                maxdiff32 = d32
            var dbf = rowsbf[i] - rows64[i]
            if dbf < 0:
                dbf = -dbf
            if dbf > maxdiffbf:
                maxdiffbf = dbf
    # Filed: fp32 faithful 16/16, agree 16/16, max dev 1.3e-05;
    # fp16 agree 14/16; bf16 faithful 15/16, worst rank 3,
    # max gap 0.72, max dev 0.87.
    if faith32 != positions:
        raise Error("fp32 accumulation must be faithful at every position")
    if agree32 != positions:
        raise Error("fp32 accumulation must keep top-1 at every position")
    if not (maxdiff32 < Float32(1.0e-4)):
        raise Error("fp32 logit row deviation above filed bound")
    if not (agree16 < positions):
        raise Error("fp16 accumulation kept every top-1: evidence changed")
    if not (faithbf < positions):
        raise Error("bf16 accumulation faithful everywhere: evidence changed")
    if not (worst_rankbf >= 3):
        raise Error("bf16 worst rank below filed divergence")
    if not (max_gapbf > Float32(0.5)):
        raise Error("bf16 max gap below filed divergence")
    if not (maxdiffbf > Float32(0.5)):
        raise Error("bf16 logit row deviation below filed floor")
    print("accum_policy logit-gap battery: PASS")


def test_accum_policy_norm_mass_attention() raises:
    print("--- Testing accumulation norm/mass/attention evidence (A-075) ---")
    var n = 14336
    var lcg = AccumLcg(UInt64(0xB075) + UInt64(n))
    var x = gen_activation(lcg, n, 2.0)
    var refv = sumsq_accum(x, MODE_F64)
    var rel32 = _rel64(_abs64(sumsq_accum(x, MODE_FP32) - refv), refv)
    var rel16 = _rel64(_abs64(sumsq_accum(x, MODE_FP16) - refv), refv)
    var relbf = _rel64(_abs64(sumsq_accum(x, MODE_BF16) - refv), refv)
    # Filed: fp32 4.0e-06, fp16 0.34, bf16 0.84.
    if not (rel32 < 1.0e-4):
        raise Error("fp32 sumsq rel error above filed bound")
    if not (rel16 > 0.2):
        raise Error("fp16 sumsq rel error below filed floor")
    if not (relbf > 0.5):
        raise Error("bf16 sumsq rel error below filed floor")
    var lcg_hi = AccumLcg(UInt64(0xB076) + UInt64(n))
    var x_hi = gen_activation(lcg_hi, n, 4.25)
    var s16_hi = sumsq_accum(x_hi, MODE_FP16)
    # Filed: fp16 sumsq overflows to +inf at n=14336, std ~3 inputs.
    if not (s16_hi > 1.0e307):
        raise Error("fp16 sumsq overflow (+inf) not reproduced")
    var t = 4096
    var lcg_m = AccumLcg(0xC075)
    var terms = List[Float32]()
    for _ in range(t):
        terms.append(Float32(exp(-3.0 * lcg_m.unit())))
    var mref = mass_accum(terms, MODE_F64)
    var mrel32 = _rel64(_abs64(mass_accum(terms, MODE_FP32) - mref), mref)
    var mrel16 = _rel64(_abs64(mass_accum(terms, MODE_FP16) - mref), mref)
    var mrelbf = _rel64(_abs64(mass_accum(terms, MODE_BF16) - mref), mref)
    # Filed: fp32 3.6e-06, fp16 0.099, bf16 0.81.
    if not (mrel32 < 1.0e-4):
        raise Error("fp32 exp-mass rel error above filed bound")
    if not (mrel16 > 0.05):
        raise Error("fp16 exp-mass rel error below filed floor")
    if not (mrelbf > 0.5):
        raise Error("bf16 exp-mass rel error below filed floor")
    # Weighted-V (attention PV) accumulation over the same context:
    # each mode accumulates w_i * v_i serially and divides by its own
    # in-mode accumulated mass, exactly as the shader divides by its
    # accumulated denom. Filed errs: fp32 2.0e-08, fp16 7.3e-04,
    # bf16 2.5e-02.
    var lcg_a = AccumLcg(0xD075)
    var aweights = List[Float32]()
    var vals = gen_activation(lcg_a, t, 1.0)
    var wsum = Float64(0.0)
    for _ in range(t):
        var wgt = Float32(exp(-3.0 * lcg_a.unit()))
        aweights.append(wgt)
        wsum += Float64(wgt)
    var pv_ref = Float64(0.0)
    var pv32 = Float32(0.0)
    var pv16 = Float32(0.0)
    var pvbf = Float32(0.0)
    for i in range(t):
        pv_ref += (Float64(aweights[i]) / wsum) * Float64(vals[i])
        var p = aweights[i] * vals[i]
        pv32 += p
        pv16 = round_accum(pv16 + p, MODE_FP16)
        pvbf = round_accum(pvbf + p, MODE_BF16)
    var err32 = _abs64(
        Float64(pv32) / mass_accum(aweights, MODE_FP32) - pv_ref
    )
    var err16 = _abs64(
        Float64(pv16) / mass_accum(aweights, MODE_FP16) - pv_ref
    )
    var errbf = _abs64(
        Float64(pvbf) / mass_accum(aweights, MODE_BF16) - pv_ref
    )
    if not (err32 < 1.0e-6):
        raise Error("fp32 PV error above filed bound")
    if not (err16 > 100.0 * err32):
        raise Error("fp16 PV error not >= 100x fp32")
    if not (errbf > 0.01):
        raise Error("bf16 PV error below filed floor")
    print("accum_policy norm/mass/attention evidence: PASS")


def test_accum_policy_emulation_invariants() raises:
    print("--- Testing accumulation emulation invariants (A-075) ---")
    # Rounding is idempotent and exact on representable values.
    var exact16 = Float32(1.0009765625)  # 1 + 2^-10, exact in fp16
    if round_accum(exact16, MODE_FP16) != exact16:
        raise Error("fp16 rounding moved a representable value")
    if round_accum(round_accum(Float32(0.1), MODE_FP16), MODE_FP16) != round_accum(
        Float32(0.1), MODE_FP16
    ):
        raise Error("fp16 rounding not idempotent")
    if round_accum(round_accum(Float32(0.1), MODE_BF16), MODE_BF16) != round_accum(
        Float32(0.1), MODE_BF16
    ):
        raise Error("bf16 rounding not idempotent")
    if round_accum(Float32(0.1), MODE_FP32) != Float32(0.1):
        raise Error("fp32 rounding must be identity")
    # FP32 mode == a manual serial Float32 dot, bit-exact.
    var lcg = AccumLcg(0xE075)
    var w = gen_weights(lcg, 512, 0.06)
    var x = gen_activation(lcg, 512, 1.0)
    var manual = Float32(0.0)
    for i in range(512):
        manual += w[i] * x[i]
    if dot_accum(w, x, MODE_FP32) != Float64(manual):
        raise Error("fp32 emulation diverges from serial fp32 dot")
    # Float64 reference is exact on dyadic inputs.
    var dw = List[Float32]()
    var dx = List[Float32]()
    dw.append(Float32(0.5))
    dw.append(Float32(0.25))
    dx.append(Float32(2.0))
    dx.append(Float32(4.0))
    if dot_accum(dw, dx, MODE_F64) != Float64(2.0):
        raise Error("f64 reference not exact on dyadic inputs")
    # Empty reductions are zero in every mode.
    var empty = List[Float32]()
    if dot_accum(empty, empty, MODE_FP16) != Float64(0.0):
        raise Error("empty dot must be zero")
    if sumsq_accum(empty, MODE_BF16) != Float64(0.0):
        raise Error("empty sumsq must be zero")
    # Fail-closed: length mismatch and unknown modes raise.
    var short = List[Float32]()
    short.append(Float32(1.0))
    var raised = False
    try:
        _ = dot_accum(w, short, MODE_FP32)
    except:
        raised = True
    if not raised:
        raise Error("dot_accum accepted a length mismatch")
    raised = False
    try:
        _ = dot_accum(w, x, 99)
    except:
        raised = True
    if not raised:
        raise Error("dot_accum accepted an unknown mode")
    print("accum_policy emulation invariants: PASS")
