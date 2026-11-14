# tests/test_sliding_window_battery_a123.mojo
# A-123: Sliding-window attention parity -- the rows
# judged at window-boundary lengths by executing the
# banked CPU kernel against an independent reference
# over the labelled SYNTHETIC fixture, and these cases
# cover: the axes and their product, duplicate-free
# enumeration, the A-115 policy obligation by call
# (Q4_K_M owed), every cpu row FAITHFUL at its
# boundary length with its filed witnesses, the
# attended-count boundary witnesses (min(L, W): the
# window first binds at W+1), NOT_GRADED on every
# non-cpu backend, the boundary probe discriminating
# (the seeded off-by-one and window-ignored defects
# measure DIVERGENT, the below-boundary full-attention
# case measures FAITHFUL), summary counts summing to
# the totals, degenerate axes refused, and a
# deterministic digest across re-runs.

from core.exactness_policy import POLICY_TOKEN_EXACTNESS_OWED
from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_NOT_GRADED,
)
from core.sliding_window_battery_a123 import (
    SW_BOUND_X10000,
    SW_FIXTURE_STATUS,
    SW_REF_FULL,
    SW_REF_OFF_BY_ONE,
    SW_REF_WINDOWED,
    BatteryReport,
    BatteryRow,
    sw_backends,
    battery_line,
    battery_render,
    battery_row_line,
    battery_row_verdict,
    build_battery,
    policy_obligation,
    run_battery,
    sw_attended,
    sw_execute,
    sw_first_included,
    sw_lengths,
    sw_windows,
    syn_cases,
)


def _row(
    read report: BatteryReport,
    window: Int,
    length: Int,
    backend: String,
) raises -> BatteryRow:
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if (
            r.window == window
            and r.length == length
            and r.backend == backend
        ):
            return r
    raise Error("sliding-window battery row not found")


def _raises_build(
    windows: List[Int], backends: List[String]
) -> Bool:
    try:
        _ = build_battery(windows, backends)
    except:
        return True
    return False


def test_sliding_axes_product() raises:
    var windows = sw_windows()
    var backends = sw_backends()
    if len(windows) != 3 or len(backends) != 4:
        raise Error("sliding axes must be 3 windows x 4 backends")
    if windows[0] != 16 or windows[1] != 512 or windows[2] != 4096:
        raise Error("windows must be 16 / 512 / 4096")
    if backends[0] != String("cpu") or backends[1] != String("vulkan"):
        raise Error("sliding backends must be A-109 harness order")
    if backends[2] != String("hip") or backends[3] != String("npu"):
        raise Error("sliding backends must be A-109 harness order")
    for wi in range(len(windows)):
        var lens = sw_lengths(windows[wi])
        if len(lens) != 6:
            raise Error("each window must file 6 boundary lengths")
    var report = run_battery()
    if report.total != 72 or len(report.rows) != 72:
        raise Error("sliding battery must file exactly 72 rows")


def test_sliding_enumeration_unique() raises:
    var report = run_battery()
    for i in range(len(report.rows)):
        for j in range(i + 1, len(report.rows)):
            var a = report.rows[i]
            var b = report.rows[j]
            if (
                a.window == b.window
                and a.length == b.length
                and a.backend == b.backend
            ):
                raise Error("duplicate sliding battery row")
    var first = report.rows[0]
    if first.window != 16 or first.length != 15:
        raise Error("enumeration must start at window 16 / length 15")
    if first.backend != String("cpu"):
        raise Error("enumeration must start on cpu")
    if String("A-123 Sliding-window attention parity") not in battery_line():
        raise Error("battery line must name the slice")
    if String("SYNTHETIC") not in battery_line():
        raise Error("battery line must label the synthetic fixture")


def test_sliding_policy_obligation() raises:
    var obligation = policy_obligation()
    if obligation != POLICY_TOKEN_EXACTNESS_OWED:
        raise Error("Q4_K_M must owe token-exactness per A-115")
    var report = run_battery()
    if report.owed != 72 or report.coherence != 0:
        raise Error("row policy counts must be 72 owed / 0 coherence")
    for i in range(len(report.rows)):
        if report.rows[i].obligation != POLICY_TOKEN_EXACTNESS_OWED:
            raise Error("every sliding row must file the owed obligation")


def test_sliding_cpu_faithful() raises:
    var report = run_battery()
    var count = 0
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.backend == String("cpu"):
            if r.verdict != MX_FAITHFUL:
                raise Error("cpu boundary row must be FAITHFUL")
            if r.reason != String("WINDOW_BOUNDARY_PARITY"):
                raise Error("cpu row must name its parity reason")
            if r.attended != sw_attended(r.window, r.length):
                raise Error("cpu row attended must equal min(L, W)")
            if r.diff_x10000 < 0 or r.diff_x10000 > SW_BOUND_X10000:
                raise Error("cpu row diff must sit within the bound")
            count += 1
    if count != 18:
        raise Error("exactly 18 cpu rows must be graded")


def test_sliding_boundary_witnesses() raises:
    if sw_attended(512, 511) != 511:
        raise Error("below the window every position is attended")
    if sw_attended(512, 512) != 512:
        raise Error("at L == W nothing is yet excluded")
    if sw_attended(512, 513) != 512:
        raise Error("at L == W+1 exactly one position falls out")
    if sw_attended(512, 1025) != 512:
        raise Error("deep past the window the count stays W")
    if sw_first_included(512, 513) != 1:
        raise Error("first included at L == W+1 must be position 1")
    if sw_first_included(512, 512) != 0:
        raise Error("first included at L == W must be position 0")
    var report = run_battery()
    var at = _row(report.copy(), 512, 512, String("cpu"))
    if at.attended != 512 or at.verdict != MX_FAITHFUL:
        raise Error("the L == W row must attend 512 and be FAITHFUL")
    var past = _row(report.copy(), 512, 513, String("cpu"))
    if past.attended != 512 or past.verdict != MX_FAITHFUL:
        raise Error("the L == W+1 row must attend 512 and be FAITHFUL")
    var below = _row(report.copy(), 4096, 4095, String("cpu"))
    if below.attended != 4095 or below.verdict != MX_FAITHFUL:
        raise Error("the 4096 / 4095 row must attend all and pass")


def test_sliding_backend_not_graded() raises:
    var report = run_battery()
    var count = 0
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.backend != String("cpu"):
            if r.verdict != MX_NOT_GRADED:
                raise Error("non-cpu row must be NOT_GRADED")
            if r.reason != String("BACKEND_NO_CPU_COMPARATOR"):
                raise Error("non-cpu row must name its reason")
            if r.attended != -1 or r.diff_x10000 != -1:
                raise Error("ungraded row must not zero-fill witnesses")
            count += 1
    if count != 54:
        raise Error("exactly 54 non-cpu rows must be NOT_GRADED")


def test_sliding_summary_sums() raises:
    var report = run_battery()
    var s = report.faithful + report.near_tie + report.divergent
    s += report.artifact + report.fixture_limited + report.not_graded
    if s != report.total:
        raise Error("verdict counts must sum to the total")
    if report.owed + report.coherence != report.total:
        raise Error("policy counts must sum to the total")
    if report.faithful != 18 or report.not_graded != 54:
        raise Error("filed faithful/not-graded counts mismatch")
    if report.divergent != 0 or report.artifact != 0:
        raise Error("kernel rows must file no divergent/artifact verdicts")
    var text = battery_render(report.copy())
    if String("A123_BATTERY_SUMMARY total=72") not in text:
        raise Error("render must carry the summary line")
    var line = battery_row_line(report.rows[0])
    if String("policy=TOKEN_EXACTNESS_OWED") not in line:
        raise Error("row line must carry the policy obligation")


def test_sliding_checks_discriminate() raises:
    var obligation = policy_obligation()
    var good = battery_row_verdict(16, 17, String("cpu"), obligation)
    if good.verdict != MX_FAITHFUL:
        raise Error("the filed 16 / 17 cpu row must pass W2")
    var measured = sw_execute(16, 17, SW_REF_OFF_BY_ONE)
    if measured[0] <= SW_BOUND_X10000:
        raise Error("off-by-one reference must exceed the bound")
    if measured[1] != 17:
        raise Error("off-by-one reference must admit W + 1 positions")
    var windowed = sw_execute(16, 17, SW_REF_WINDOWED)
    if windowed[1] != 16:
        raise Error("windowed reference must admit exactly W positions")
    if windowed[0] > SW_BOUND_X10000:
        raise Error("windowed reference must sit within the bound")
    var row = battery_row_verdict(16, 17, String("vulkan"), obligation)
    if row.verdict != MX_NOT_GRADED:
        raise Error("row verdict must agree with the W1 rule")


def test_sliding_synthetic_labelled() raises:
    if String(SW_FIXTURE_STATUS) != String("SYNTHETIC"):
        raise Error("the fixture status must be SYNTHETIC")
    var report = run_battery()
    var text = battery_render(report.copy())
    if String("fixture_status=SYNTHETIC") not in text:
        raise Error("render must label the fixture SYNTHETIC")
    if String("status=SYNTHETIC") not in text:
        raise Error("synthetic lines must carry the SYNTHETIC label")
    if String("window=4096") not in text:
        raise Error("render must file the Gemma2 window rows")
    if String("length=8193") not in text:
        raise Error("render must file the deepest boundary length")


def test_sliding_boundary_probe() raises:
    var cases = syn_cases()
    if cases[0].name != String("SYN_OFF_BY_ONE"):
        raise Error("first seeded case must be SYN_OFF_BY_ONE")
    if cases[0].verdict != MX_DIVERGENT:
        raise Error("the off-by-one defect must be DIVERGENT")
    if cases[0].reason != String("WINDOW_BOUNDARY_OFF_BY_ONE"):
        raise Error("off-by-one must name its reason")
    if cases[0].diff_x10000 <= SW_BOUND_X10000:
        raise Error("off-by-one must be measured, above the bound")
    if cases[2].name != String("SYN_WINDOW_FREE"):
        raise Error("third seeded case must be SYN_WINDOW_FREE")
    if cases[2].verdict != MX_FAITHFUL:
        raise Error("below the boundary full attention must agree")
    if cases[2].reason != String("WINDOW_CANNOT_BIND_AT_OR_BELOW"):
        raise Error("the free case must name its reason")


def test_sliding_seeded_defects() raises:
    var cases = syn_cases()
    if len(cases) != 4:
        raise Error("exactly 4 seeded cases must be filed")
    if cases[1].verdict != MX_DIVERGENT:
        raise Error("an ignored window must be DIVERGENT")
    if cases[1].reason != String("WINDOW_NOT_APPLIED"):
        raise Error("ignored window must name its reason")
    if cases[1].diff_x10000 <= SW_BOUND_X10000:
        raise Error("ignored window must be measured, above the bound")
    if cases[3].verdict != MX_COMPARATOR_ARTIFACT:
        raise Error("backend mismatch must be COMPARATOR_ARTIFACT")
    if cases[3].reason != String("BACKEND_MISMATCH"):
        raise Error("mismatch must name its reason")
    var report = run_battery()
    if report.syn_total != 4 or report.syn_faithful != 1:
        raise Error("seeded counts must be 4 total / 1 faithful")
    if report.syn_divergent != 2 or report.syn_artifact != 1:
        raise Error("seeded counts must be 2 divergent / 1 artifact")


def test_sliding_invalid_axes_refused() raises:
    var empty_windows = List[Int]()
    var backends = sw_backends()
    if not _raises_build(empty_windows, backends.copy()):
        raise Error("empty window axis must be refused")
    var dup = sw_windows()
    dup.append(16)
    if not _raises_build(dup, backends.copy()):
        raise Error("duplicate window axis must be refused")
    var tiny = List[Int]()
    tiny.append(1)
    if not _raises_build(tiny, backends.copy()):
        raise Error("a window below 2 must be refused")
    var windows = sw_windows()
    var empty_backends = List[String]()
    if not _raises_build(windows.copy(), empty_backends.copy()):
        raise Error("empty backend axis must be refused")


def test_sliding_digest_deterministic() raises:
    var a = run_battery()
    var b = run_battery()
    if a.digest != b.digest or a.digest == UInt64(0):
        raise Error("sliding digest must be deterministic and non-zero")
    if battery_render(a.copy()) != battery_render(b.copy()):
        raise Error("sliding render must be deterministic")
