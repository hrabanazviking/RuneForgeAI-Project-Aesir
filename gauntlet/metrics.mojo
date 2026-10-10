# GAUNTLET metrics — measurement primitives and trend statistics (H181).
#
# A Metric is a named, unit-carrying quantity. A Measurement binds a value
# to a metric at a moment in time with an evidence path. Trend statistics
# (ordinary least-squares slope, mean) power the drift detection used by
# the soak analyzer (H185) — statistics, not eyeballing.

from std.math import sqrt


struct Metric:
    """A named measurable quantity with its unit and direction of goodness."""
    var name: String
    var unit: String
    var higher_is_better: Bool

    def __init__(out self, name: String, unit: String, higher_is_better: Bool):
        self.name = name
        self.unit = unit
        self.higher_is_better = higher_is_better


struct Measurement:
    """One observed value of a metric, with its evidence path."""
    var metric: String
    var value: Float64
    var ts_s: Float64
    var evidence_path: String

    def __init__(
        out self, metric: String, value: Float64, ts_s: Float64, evidence_path: String
    ):
        self.metric = metric
        self.value = value
        self.ts_s = ts_s
        self.evidence_path = evidence_path


def ols_slope(xs: List[Float64], ys: List[Float64]) -> Float64:
    """Ordinary least-squares slope of y on x. Raises on degenerate input."""
    if len(xs) != len(ys):
        raise Error("gauntlet: ols_slope length mismatch")
    var n = len(xs)
    if n < 2:
        raise Error("gauntlet: ols_slope needs >= 2 points")
    var sx = Float64(0.0)
    var sy = Float64(0.0)
    for i in range(n):
        sx += xs[i]
        sy += ys[i]
    var mx = sx / Float64(n)
    var my = sy / Float64(n)
    var num = Float64(0.0)
    var den = Float64(0.0)
    for i in range(n):
        var dx = xs[i] - mx
        num += dx * (ys[i] - my)
        den += dx * dx
    if den == Float64(0.0):
        raise Error("gauntlet: ols_slope degenerate x")
    return num / den


def mean(xs: List[Float64]) -> Float64:
    """Arithmetic mean. Raises on empty input."""
    if len(xs) == 0:
        raise Error("gauntlet: mean of empty list")
    var s = Float64(0.0)
    for i in range(len(xs)):
        s += xs[i]
    return s / Float64(len(xs))


def stddev(xs: List[Float64]) -> Float64:
    """Population standard deviation. Raises on empty input."""
    var m = mean(xs)
    var acc = Float64(0.0)
    for i in range(len(xs)):
        var d = xs[i] - m
        acc += d * d
    return sqrt(acc / Float64(len(xs)))


def slope_ci_halfwidth(xs: List[Float64], ys: List[Float64]) -> Float64:
    """Half-width of the ~95% confidence interval for the OLS slope.

    Uses the standard error of the slope times 1.96 (large-sample normal
    approximation). Returned alongside the slope so H185's analyzer can
    report slope WITH its confidence interval, per the slice criteria.
    """
    var n = len(xs)
    var b = ols_slope(xs, ys)
    var sx = Float64(0.0)
    for i in range(n):
        sx += xs[i]
    var mx = sx / Float64(n)
    var sxx = Float64(0.0)
    var rss = Float64(0.0)
    var my = mean(ys)
    var a = my - b * mx
    for i in range(n):
        sxx += (xs[i] - mx) * (xs[i] - mx)
        var r = ys[i] - (a + b * xs[i])
        rss += r * r
    if n < 3 or sxx == Float64(0.0):
        raise Error("gauntlet: slope_ci needs >= 3 points and non-degenerate x")
    var se2 = (rss / Float64(n - 2)) / sxx
    return Float64(1.96) * sqrt(se2)
