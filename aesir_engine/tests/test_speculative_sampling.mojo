"""Speculative sampling correctness (J-082): the shaped
distributions exact against hand-computed values; the
rejection correction's mechanics exact under scripted
draws (acceptance prefix, residual emission, bonus
emission, refusals); and the distributional honesty proof
-- chi-square over seeded runs (the module header's
pre-registered verdict rule: N = 60,000 per case, seed
20261101, alpha = 0.001) -- with the naive uncorrected
sampler as the control that must FAIL the same test in
every case. Fixtures are stated logits, never a model's:
no live pair is graded here.
"""
from core.sampler import RuneRNG
from core.speculative_sampling import (
    CHI_SQUARE_ZERO_BIN,
    acceptance_probability,
    chi_square_critical_001,
    chi_square_statistic,
    draw_from_distribution,
    residual_distribution,
    run_sampled_round,
    sample_position,
    shape_distribution,
    support_df,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "SpeculativeSampling "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("SpeculativeSampling " + what + ": expected true")


def expect_close(
    actual: Float64, expected: Float64, tol: Float64, what: String
) raises:
    var d = actual - expected
    if d < 0.0:
        d = -d
    if d > tol:
        raise Error(
            "SpeculativeSampling "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_dist(
    actual: List[Float64], expected: List[Float64], what: String
) raises:
    expect_eq(len(actual), len(expected), what + " length")
    for i in range(len(expected)):
        expect_close(actual[i], expected[i], 1e-6, what + " bin " + String(i))


def target_logits() -> List[Float64]:
    var l = List[Float64]()
    l.append(2.0)
    l.append(1.0)
    l.append(0.5)
    l.append(0.0)
    l.append(-0.5)
    l.append(-1.0)
    l.append(-1.5)
    l.append(-2.0)
    return l^


def draft_logits() -> List[Float64]:
    var l = List[Float64]()
    l.append(1.2)
    l.append(0.2)
    l.append(1.6)
    l.append(-0.8)
    l.append(0.6)
    l.append(-1.4)
    l.append(-0.2)
    l.append(-2.2)
    return l^


def dist_of(vals: List[Float64]) -> List[Float64]:
    var out = List[Float64]()
    for i in range(len(vals)):
        out.append(vals[i])
    return out^


def test_shaping_plain_exact() raises:
    var p = shape_distribution(target_logits(), 1.0, 0, 1.0)
    expect_dist(
        p,
        dist_of(
            [
                0.5244581109,
                0.1929373567,
                0.1170224223,
                0.0709776870,
                0.0430501433,
                0.0261112318,
                0.0158372627,
                0.0096057854,
            ]
        ),
        "case A target",
    )
    var q = shape_distribution(draft_logits(), 1.0, 0, 1.0)
    expect_dist(
        q,
        dist_of(
            [
                0.2565355727,
                0.0943741631,
                0.3827061032,
                0.0347183144,
                0.1407897074,
                0.0190538149,
                0.0632608934,
                0.0085614309,
            ]
        ),
        "case A draft",
    )
    print("PASS: shaping plain -- case A target/draft softmax exact (1e-6)")


def test_shaping_temperature_exact() raises:
    var p = shape_distribution(target_logits(), 0.7, 0, 1.0)
    expect_dist(
        p,
        dist_of(
            [
                0.6819799718,
                0.1634372071,
                0.0800093216,
                0.0391678961,
                0.0191743168,
                0.0093866269,
                0.0045951449,
                0.0022495149,
            ]
        ),
        "case B target",
    )
    var q = shape_distribution(draft_logits(), 0.7, 0, 1.0)
    expect_close(q[2], 0.4838591558, 1e-6, "case B draft peak")
    expect_close(q[0], 0.2732440338, 1e-6, "case B draft token 0")
    print("PASS: shaping temperature -- case B (T=0.7) exact; sharpening binds both models")


def test_shaping_greedy_one_hot() raises:
    var p = shape_distribution(target_logits(), 0.0, 0, 1.0)
    expect_dist(p, dist_of([1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]), "greedy target")
    # Tie at the max: the lowest id wins (the sampler's rule).
    var tie = dist_of([1.0, 3.0, 3.0, 0.0])
    var t = shape_distribution(tie, 0.0, 0, 1.0)
    expect_dist(t, dist_of([0.0, 1.0, 0.0, 0.0]), "greedy tie")
    print("PASS: shaping greedy -- T=0 one-hot at argmax; tie goes to the lowest id")


def test_shaping_top_k_exact() raises:
    var p = shape_distribution(target_logits(), 1.0, 3, 1.0)
    expect_dist(
        p,
        dist_of([0.6285317192, 0.2312238976, 0.1402443832, 0.0, 0.0, 0.0, 0.0, 0.0]),
        "case C target",
    )
    var q = shape_distribution(draft_logits(), 1.0, 3, 1.0)
    expect_dist(
        q,
        dist_of([0.3288785275, 0.0, 0.4906291098, 0.0, 0.1804923627, 0.0, 0.0, 0.0]),
        "case C draft",
    )
    expect_eq(support_df(p), 2, "case C target df")
    print("PASS: shaping top-k -- case C supports exact (target {0,1,2}, draft {0,2,4}), renormalised")


def test_shaping_top_p_and_combined_exact() raises:
    var p = shape_distribution(target_logits(), 1.0, 0, 0.8)
    expect_dist(
        p,
        dist_of([0.6285317192, 0.2312238976, 0.1402443832, 0.0, 0.0, 0.0, 0.0, 0.0]),
        "case D target",
    )
    var q = shape_distribution(draft_logits(), 1.0, 0, 0.8)
    expect_dist(
        q,
        dist_of([0.2933828288, 0.1079295111, 0.4376757498, 0.0, 0.1610119103, 0.0, 0.0, 0.0]),
        "case D draft",
    )
    var pe = shape_distribution(target_logits(), 1.4, 4, 0.9)
    expect_dist(
        pe,
        dist_of([0.4826926796, 0.2362981754, 0.1653313440, 0.1156778010, 0.0, 0.0, 0.0, 0.0]),
        "case E target",
    )
    var qe = shape_distribution(draft_logits(), 1.4, 4, 0.9)
    expect_close(qe[2], 0.3833035439, 1e-6, "case E draft peak")
    expect_eq(support_df(pe), 3, "case E target df")
    print("PASS: shaping top-p + combined -- cases D and E exact (nucleus after top-k, renormalised)")


def test_shaping_refusals() raises:
    var refused = 0
    try:
        _ = shape_distribution(List[Float64](), 1.0, 0, 1.0)
    except:
        refused += 1
    try:
        var bad = List[Float64]()
        bad.append(1.0)
        bad.append(Float64(1e308) * Float64(10.0))  # +inf at runtime
        _ = shape_distribution(bad, 1.0, 0, 1.0)
    except:
        refused += 1
    try:
        _ = shape_distribution(target_logits(), -0.5, 0, 1.0)
    except:
        refused += 1
    try:
        _ = shape_distribution(target_logits(), 1.0, 0, 0.0)
    except:
        refused += 1
    expect_eq(refused, 4, "empty / non-finite / negative temperature / top_p=0 refused")
    print("PASS: shaping refusals -- empty, non-finite logit, bad temperature, bad top-p (4/4)")


def test_acceptance_probability_exact() raises:
    expect_close(acceptance_probability(0.3, 0.6), 0.5, 1e-12, "p<q halves")
    expect_close(acceptance_probability(0.6, 0.3), 1.0, 1e-12, "p>q caps at 1")
    expect_close(acceptance_probability(0.0, 0.4), 0.0, 1e-12, "p=0 never accepts")
    expect_close(acceptance_probability(0.25, 0.25), 1.0, 1e-12, "p=q always accepts")
    var refused = 0
    try:
        _ = acceptance_probability(0.5, 0.0)
    except:
        refused += 1
    expect_eq(refused, 1, "q=0 refused by name")
    print("PASS: acceptance probability -- min(1, p/q) exact incl. cap and p=0; q=0 refused")


def test_residual_exact() raises:
    var r = residual_distribution(
        dist_of([0.4, 0.4, 0.2]), dist_of([0.2, 0.3, 0.5])
    )
    expect_dist(r, dist_of([0.6666666667, 0.3333333333, 0.0]), "residual fixture")
    var r2 = residual_distribution(
        dist_of([0.5, 0.25, 0.125, 0.125]), dist_of([0.25, 0.25, 0.25, 0.25])
    )
    expect_dist(r2, dist_of([1.0, 0.0, 0.0, 0.0]), "residual single-mass")
    var refused = 0
    try:
        _ = residual_distribution(dist_of([0.5, 0.5]), dist_of([0.5, 0.5]))
    except:
        refused += 1
    try:
        _ = residual_distribution(dist_of([0.5, 0.5]), dist_of([0.25, 0.25, 0.5]))
    except:
        refused += 1
    expect_eq(refused, 2, "identical distributions / length mismatch refused")
    print("PASS: residual -- norm(max(0, p-q)) exact; identical p=q refused as undefined")


def test_draw_boundaries() raises:
    var probs = dist_of([0.25, 0.25, 0.5])
    expect_eq(draw_from_distribution(probs, 0.0), 0, "u=0 takes bin 0")
    expect_eq(draw_from_distribution(probs, 0.25), 1, "u at boundary takes next bin")
    expect_eq(draw_from_distribution(probs, 0.4999), 1, "u inside bin 1")
    expect_eq(draw_from_distribution(probs, 0.5), 2, "u at second boundary")
    expect_eq(draw_from_distribution(probs, 0.9999), 2, "u at tail")
    var sparse = dist_of([0.0, 0.5, 0.0, 0.5])
    expect_eq(draw_from_distribution(sparse, 0.0), 1, "zero bins are never drawn")
    expect_eq(draw_from_distribution(sparse, 0.5), 3, "second positive bin")
    print("PASS: draw -- inverse-CDF boundaries exact; zero-probability tokens unreachable")


def test_position_scripted() raises:
    var p = dist_of([0.5, 0.3, 0.2])
    var q = dist_of([0.25, 0.5, 0.25])
    var acc = sample_position(p, q, 0.1, 0.999, 0.0)
    expect_eq(acc.draft_token, 0, "accept case draft token")
    expect_eq(acc.emitted_token, 0, "accept case emits the draft")
    expect_true(acc.accepted, "accept case accepted")
    var rej = sample_position(p, q, 0.5, 0.9, 0.0)
    expect_eq(rej.draft_token, 1, "reject case draft token")
    expect_eq(rej.emitted_token, 0, "reject case emits the residual draw")
    expect_true(not rej.accepted, "reject case not accepted")
    var p0 = dist_of([0.6, 0.4, 0.0])
    var q0 = dist_of([0.3, 0.3, 0.4])
    var zero = sample_position(p0, q0, 0.8, 0.0, 0.8)
    expect_eq(zero.draft_token, 2, "p=0 case draft token")
    expect_true(not zero.accepted, "p=0 draft never accepts, even at u=0")
    expect_eq(zero.emitted_token, 1, "p=0 case residual draw")
    print("PASS: position scripted -- accept emits draft; reject emits residual; p=0 never accepts")


def _round_p_flat() -> List[Float64]:
    var p_flat = List[Float64]()
    var a = dist_of([0.5, 0.25, 0.125, 0.125])
    var b = dist_of([0.25, 0.5, 0.125, 0.125])
    var c = dist_of([0.1, 0.2, 0.3, 0.4])
    for i in range(4):
        p_flat.append(a[i])
    for i in range(4):
        p_flat.append(b[i])
    for i in range(4):
        p_flat.append(c[i])
    return p_flat^


def _round_q_flat() -> List[Float64]:
    var q_flat = List[Float64]()
    var a = dist_of([0.25, 0.25, 0.25, 0.25])
    var b = dist_of([0.4, 0.2, 0.2, 0.2])
    for i in range(4):
        q_flat.append(a[i])
    for i in range(4):
        q_flat.append(b[i])
    return q_flat^


def test_round_full_accept_bonus() raises:
    var p_flat_r = _round_p_flat()
    var q_flat_r = _round_q_flat()
    var dd = List[Float64]()
    dd.append(0.1)
    dd.append(0.5)
    var ad = List[Float64]()
    ad.append(0.99)
    ad.append(0.99)
    var r = run_sampled_round(4, 2, p_flat_r, q_flat_r, dd, ad, 0.65)
    expect_eq(r.accepted_count, 2, "full-accept accepted count")
    expect_eq(r.rejected_index, -1, "full-accept has no rejection")
    expect_true(r.used_bonus, "full-accept uses the bonus")
    expect_eq(len(r.emitted_tokens), 3, "full-accept emits k+1")
    expect_eq(r.emitted_tokens[0], 0, "full-accept token 0")
    expect_eq(r.emitted_tokens[1], 1, "full-accept token 1")
    expect_eq(r.emitted_tokens[2], 3, "bonus token from position-k target")
    print("PASS: round full-accept -- drafts emitted, bonus drawn from the target at position k")


def test_round_rejections() raises:
    var p_flat_r = _round_p_flat()
    var q_flat_r = _round_q_flat()
    var dd0 = List[Float64]()
    dd0.append(0.6)
    dd0.append(0.5)
    var ad0 = List[Float64]()
    ad0.append(0.7)
    ad0.append(0.99)
    var r0 = run_sampled_round(4, 2, p_flat_r, q_flat_r, dd0, ad0, 0.3)
    expect_eq(r0.accepted_count, 0, "reject-at-0 accepted count")
    expect_eq(r0.rejected_index, 0, "reject-at-0 index")
    expect_true(not r0.used_bonus, "reject-at-0 has no bonus")
    expect_eq(len(r0.emitted_tokens), 1, "reject-at-0 emits exactly the correction")
    expect_eq(r0.emitted_tokens[0], 0, "reject-at-0 correction is the residual draw")
    expect_eq(r0.draft_tokens[0], 2, "reject-at-0 draft was token 2")
    var dd1 = List[Float64]()
    dd1.append(0.1)
    dd1.append(0.7)
    var ad1 = List[Float64]()
    ad1.append(0.99)
    ad1.append(0.9)
    var r1 = run_sampled_round(4, 2, p_flat_r, q_flat_r, dd1, ad1, 0.5)
    expect_eq(r1.accepted_count, 1, "reject-at-1 accepted count")
    expect_eq(r1.rejected_index, 1, "reject-at-1 index")
    expect_eq(len(r1.emitted_tokens), 2, "reject-at-1 emits prefix + correction")
    expect_eq(r1.emitted_tokens[0], 0, "reject-at-1 prefix token")
    expect_eq(r1.emitted_tokens[1], 1, "reject-at-1 correction is the residual draw")
    print("PASS: round rejections -- prefix kept, residual correction emitted, round ends (no bonus)")


def test_round_refusals() raises:
    var p_flat_r = _round_p_flat()
    var q_flat_r = _round_q_flat()
    var dd = List[Float64]()
    dd.append(0.1)
    dd.append(0.5)
    var ad = List[Float64]()
    ad.append(0.99)
    ad.append(0.99)
    var refused = 0
    try:
        _ = run_sampled_round(4, 0, p_flat_r, q_flat_r, dd, ad, 0.5)
    except:
        refused += 1
    try:
        _ = run_sampled_round(4, 16, p_flat_r, q_flat_r, dd, ad, 0.5)
    except:
        refused += 1
    try:
        var short_p = List[Float64]()
        short_p.append(0.5)
        _ = run_sampled_round(4, 2, short_p, q_flat_r, dd, ad, 0.5)
    except:
        refused += 1
    try:
        var short_q = List[Float64]()
        short_q.append(0.25)
        _ = run_sampled_round(4, 2, p_flat_r, short_q, dd, ad, 0.5)
    except:
        refused += 1
    try:
        var short_d = List[Float64]()
        short_d.append(0.1)
        _ = run_sampled_round(4, 2, p_flat_r, q_flat_r, short_d, ad, 0.5)
    except:
        refused += 1
    try:
        _ = run_sampled_round(4, 2, p_flat_r, q_flat_r, dd, ad, 1.0)
    except:
        refused += 1
    expect_eq(refused, 6, "k band / flat lengths / draw lengths / final draw refused")
    print("PASS: round refusals -- k outside 1..15, flat/draw length mismatches, draw = 1 (6/6)")


def test_chi_square_helper() raises:
    var probs = dist_of([0.5, 0.3, 0.2])
    var obs_exact = List[Int]()
    obs_exact.append(50)
    obs_exact.append(30)
    obs_exact.append(20)
    expect_close(chi_square_statistic(obs_exact, probs), 0.0, 1e-9, "exact-fit statistic")
    var obs_off = List[Int]()
    obs_off.append(60)
    obs_off.append(25)
    obs_off.append(15)
    expect_close(
        chi_square_statistic(obs_off, probs), 4.0833333333, 1e-6, "hand-computed statistic"
    )
    var obs_zero = List[Int]()
    obs_zero.append(10)
    obs_zero.append(5)
    var stat_zero = chi_square_statistic(obs_zero, dist_of([1.0, 0.0]))
    expect_close(stat_zero, CHI_SQUARE_ZERO_BIN, 0.0, "zero-bin sentinel")
    expect_close(chi_square_critical_001(2), 13.816, 1e-9, "critical df=2")
    expect_close(chi_square_critical_001(7), 24.322, 1e-9, "critical df=7")
    print("PASS: chi-square helper -- exact/hand-computed statistics, zero-bin sentinel, critical table")


def _run_case(
    name: String,
    temperature: Float64,
    top_k: Int,
    top_p: Float64,
) raises:
    """One registered case: asserts the corrected statistic
    PASSes and the naive control FAILs (the naive statistic
    is CHI_SQUARE_ZERO_BIN when the control emitted into a
    zero-probability bin)."""
    var p = shape_distribution(target_logits(), temperature, top_k, top_p)
    var q = shape_distribution(draft_logits(), temperature, top_k, top_p)
    var n = 60000
    var obs = List[Int]()
    for _ in range(8):
        obs.append(0)
    var rng = RuneRNG(UInt64(20261101))
    for _ in range(n):
        var u_d = Float64(rng.next_float32())
        var u_a = Float64(rng.next_float32())
        var u_r = Float64(rng.next_float32())
        var pos = sample_position(p, q, u_d, u_a, u_r)
        obs[pos.emitted_token] += 1
    var stat = chi_square_statistic(obs, p)
    var obs_n = List[Int]()
    for _ in range(8):
        obs_n.append(0)
    var rng_n = RuneRNG(UInt64(20261101))
    for _ in range(n):
        var u = Float64(rng_n.next_float32())
        obs_n[draw_from_distribution(q, u)] += 1
    var stat_n = chi_square_statistic(obs_n, p)
    var df = support_df(p)
    var crit = chi_square_critical_001(df)
    expect_true(stat >= 0.0 and stat < crit, name + " corrected sampler must PASS")
    expect_true(
        stat_n == CHI_SQUARE_ZERO_BIN or stat_n > crit,
        name + " naive control must FAIL",
    )
    print(
        "PASS: distribution "
        + name
        + " -- corrected chi2="
        + String(stat)
        + " < crit "
        + String(crit)
        + " (df "
        + String(df)
        + ", N=60000, seed 20261101); naive chi2="
        + String(stat_n)
        + " FAILS as required"
    )


def test_distribution_case_a() raises:
    _run_case("A (T=1, no truncation)", 1.0, 0, 1.0)


def test_distribution_cases_b_to_e() raises:
    _run_case("B (T=0.7)", 0.7, 0, 1.0)
    _run_case("C (top-k 3)", 1.0, 3, 1.0)
    _run_case("D (top-p 0.8)", 1.0, 0, 0.8)
    _run_case("E (T=1.4, top-k 4, top-p 0.9)", 1.4, 4, 0.9)


def test_bonus_distribution() raises:
    var p = shape_distribution(target_logits(), 1.0, 0, 1.0)
    var q = shape_distribution(draft_logits(), 1.0, 0, 1.0)
    var p_flat = List[Float64]()
    var q_flat = List[Float64]()
    for rep in range(3):
        _ = rep
        for i in range(8):
            p_flat.append(p[i])
    for rep in range(2):
        _ = rep
        for i in range(8):
            q_flat.append(q[i])
    var obs = List[Int]()
    for _ in range(8):
        obs.append(0)
    var rng = RuneRNG(UInt64(424242))
    var collected = 0
    var rounds = 0
    while collected < 12000 and rounds < 200000:
        var dd = List[Float64]()
        var ad = List[Float64]()
        for _ in range(2):
            dd.append(Float64(rng.next_float32()))
        for _ in range(2):
            ad.append(Float64(rng.next_float32()))
        var fin = Float64(rng.next_float32())
        var r = run_sampled_round(8, 2, p_flat, q_flat, dd, ad, fin)
        rounds += 1
        if r.used_bonus:
            obs[r.emitted_tokens[2]] += 1
            collected += 1
    expect_eq(collected, 12000, "bonus collection target reached")
    expect_true(rounds > 20000 and rounds < 60000, "bonus rounds in the registered band")
    var stat = chi_square_statistic(obs, p)
    var crit = chi_square_critical_001(7)
    expect_true(stat >= 0.0 and stat < crit, "bonus tokens must follow the target")
    print(
        "PASS: bonus distribution -- chi2="
        + String(stat)
        + " < crit "
        + String(crit)
        + " (df 7, 12000 bonus tokens from "
        + String(rounds)
        + " rounds, seed 424242)"
    )


def main() raises:
    test_shaping_plain_exact()
    test_shaping_temperature_exact()
    test_shaping_greedy_one_hot()
    test_shaping_top_k_exact()
    test_shaping_top_p_and_combined_exact()
    test_shaping_refusals()
    test_acceptance_probability_exact()
    test_residual_exact()
    test_draw_boundaries()
    test_position_scripted()
    test_round_full_accept_bonus()
    test_round_rejections()
    test_round_refusals()
    test_chi_square_helper()
    test_distribution_case_a()
    test_distribution_cases_b_to_e()
    test_bonus_distribution()
    print("ALL PASS: speculative sampling correctness (17 groups)")
