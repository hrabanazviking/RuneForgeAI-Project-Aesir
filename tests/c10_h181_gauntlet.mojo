# tests/c10_h181_gauntlet.mojo
# H181 — GAUNTLET module skeleton acceptance (TEST-ONLY driver, not shipped).
#
# Exercises the judgment framework with 3 example gates against canned
# data, in both the PASS and FAIL directions:
#   G1 soak_error_rate      (le 0.0)
#   G2 decode_tps           (ge 1.5)
#   G3 determinism_match    (eq 1.0, tol 1e-9)
# Also exercises ols_slope / mean / stddev / slope_ci_halfwidth on canned
# series (a flat series has ~zero slope; a drifting series has the
# injected slope within the confidence interval).
#
# Usage: c10_h181_gauntlet   (exits non-zero on any failure)

from gauntlet.gates import Gate, gate_verdict_word
from gauntlet.metrics import (
    Measurement,
    mean,
    ols_slope,
    slope_ci_halfwidth,
    stddev,
)
from gauntlet.verdict import VerdictSet, judge, verdictset_to_json


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error("H181 FAIL: " + msg)
    print("H181 ok: " + msg)


def main() raises:
    # --- 3 example gates ---
    var g1 = Gate(
        "G1", "soak_error_rate", "le", Float64(0.0), Float64(0.0), "H183",
        "Any crash or hang during the soak is a release blocker.",
    )
    var g2 = Gate(
        "G2", "decode_tps", "ge", Float64(1.5), Float64(0.0), "H183",
        "Decode throughput must stay above the production floor of 1.5 tok/s.",
    )
    var g3 = Gate(
        "G3", "determinism_match", "eq", Float64(1.0), Float64(1e-9), "H188",
        "Greedy decoding must be bit-identical across runs.",
    )

    # --- canned PASS dataset ---
    var p1 = Measurement("soak_error_rate", Float64(0.0), Float64(0.0), "canned/pass")
    var p2 = Measurement("decode_tps", Float64(1.918), Float64(0.0), "canned/pass")
    var p3 = Measurement("determinism_match", Float64(1.0), Float64(0.0), "canned/pass")
    _check(gate_verdict_word(g1, p1) == "PASS", "G1 passes on clean soak")
    _check(gate_verdict_word(g2, p2) == "PASS", "G2 passes on 1.918 tok/s")
    _check(gate_verdict_word(g3, p3) == "PASS", "G3 passes on exact determinism")

    # --- canned FAIL dataset ---
    var f1 = Measurement("soak_error_rate", Float64(0.02), Float64(0.0), "canned/fail")
    var f2 = Measurement("decode_tps", Float64(1.2), Float64(0.0), "canned/fail")
    var f3 = Measurement("determinism_match", Float64(0.9), Float64(0.0), "canned/fail")
    _check(gate_verdict_word(g1, f1) == "FAIL", "G1 fails on 2% error rate")
    _check(gate_verdict_word(g2, f2) == "FAIL", "G2 fails on 1.2 tok/s")
    _check(gate_verdict_word(g3, f3) == "FAIL", "G3 fails on 90% match")

    # --- VerdictSet aggregation: one FAIL fails the set ---
    var vs = VerdictSet("H181 example gates")
    vs.add(judge(g1, p1))
    vs.add(judge(g2, p2))
    vs.add(judge(g3, f3))
    _check(vs.n_pass() == 2, "VerdictSet counts 2/3 passes")
    _check(vs.overall() == "FAIL", "VerdictSet overall FAIL on one failing gate")
    var js = verdictset_to_json(vs)
    _check(js.byte_length() > 100, "VerdictSet emits JSON")
    print("H181 verdict JSON: " + js)

    # --- metric mismatch raises (judgment error, not a pass) ---
    var wrong = Measurement("decode_tps", Float64(2.0), Float64(0.0), "canned/x")
    var raised = False
    try:
        _ = gate_verdict_word(g1, wrong)
    except:
        raised = True
    _check(raised, "metric mismatch raises instead of judging")

    # --- trend statistics on canned series ---
    var xs = List[Float64]()
    var flat = List[Float64]()
    for i in range(10):
        xs.append(Float64(i))
        flat.append(Float64(2.0))
    var s_flat = ols_slope(xs, flat)
    _check(s_flat > Float64(-1e-9) and s_flat < Float64(1e-9), "flat series slope ~ 0")
    _check(stddev(flat) < Float64(1e-9), "flat series stddev ~ 0")
    _check(mean(flat) == Float64(2.0), "mean of flat series is 2.0")

    var drift = List[Float64]()
    for i in range(20):
        # 15% linear slowdown over 20 points starting at 2.0 tok/s.
        drift.append(Float64(2.0) * (Float64(1.0) - Float64(0.15) * Float64(i) / Float64(19)))
    var xs2 = List[Float64]()
    for i in range(20):
        xs2.append(Float64(i))
    var s_drift = ols_slope(xs2, drift)
    var ci = slope_ci_halfwidth(xs2, drift)
    var expected = Float64(-2.0 * 0.15 / 19.0)
    var lo = s_drift - ci
    var hi = s_drift + ci
    _check(
        lo <= expected and expected <= hi,
        "injected drift slope inside 95% CI",
    )
    _check(s_drift < Float64(0.0), "drift slope is negative")
    print("H181-ALL-PASS")
