# GAUNTLET gates — metric -> measurement -> threshold -> PASS/FAIL (H181).
#
# A Gate is the machine-checkable contract: which metric, which
# comparison operator, which threshold number, which slice produces the
# measurement, and a one-sentence justification. evaluate() is the only
# decision point in the framework — it reads, compares, and judges.
# It never repairs, retries, or mutates anything.

from gauntlet.metrics import Measurement


struct Gate:
    """A production gate: metric, operator, threshold, provenance."""
    var gate_id: String
    var metric: String
    var op: String  # one of: "le", "ge", "eq", "lt", "gt"
    var threshold: Float64
    var tolerance: Float64  # absolute tolerance for "eq"
    var source_slice: String
    var justification: String

    def __init__(
        out self,
        gate_id: String,
        metric: String,
        op: String,
        threshold: Float64,
        tolerance: Float64,
        source_slice: String,
        justification: String,
    ):
        self.gate_id = gate_id
        self.metric = metric
        self.op = op
        self.threshold = threshold
        self.tolerance = tolerance
        self.source_slice = source_slice
        self.justification = justification


def gate_holds(g: Gate, m: Measurement) raises -> Bool:
    """True when the measurement satisfies the gate's threshold.

    Raises when the measurement is for a different metric than the gate
    (a mismatched evaluation is a judgment error, not a pass).
    """
    if m.metric != g.metric:
        raise Error(
            "gauntlet: gate " + g.gate_id + " measures '" + g.metric
            + "' but got measurement of '" + m.metric + "'"
        )
    if g.op == "le":
        return m.value <= g.threshold
    if g.op == "lt":
        return m.value < g.threshold
    if g.op == "ge":
        return m.value >= g.threshold
    if g.op == "gt":
        return m.value > g.threshold
    if g.op == "eq":
        var d = m.value - g.threshold
        if d < Float64(0.0):
            d = -d
        return d <= g.tolerance
    raise Error("gauntlet: gate " + g.gate_id + " has unknown op '" + g.op + "'")


def gate_verdict_word(g: Gate, m: Measurement) raises -> String:
    """PASS/FAIL word for one measurement against one gate."""
    if gate_holds(g, m):
        return String("PASS")
    return String("FAIL")
