# tests/test_gemma_battery_a120.mojo
# A-120: Gemma-family battery -- the battery is the
# gemma4 rows of the A-114 matrix across all Z13
# backends, judged per the banked A-115 policy, and
# these cases cover: the axes and their product,
# duplicate-free enumeration, the policy split (10
# TOKEN_EXACTNESS_OWED / 9 COHERENCE_ONLY, per quant
# and per row), agreement with the canonical banked
# A-115 policy_for_quant for every quant, every cpu
# row NOT_GRADED with reason NO_FILED_RECORDS (no
# filed gemma teacher-forcing records exist), IQ cpu
# rows NOT fixture-limited (the llama fixture verdict
# does not transfer across architectures), NOT_GRADED
# on every non-cpu backend with the obligation still
# filed, summary counts summing to the total, the
# filed zero divergent count (the A-116 in-anger
# condition is not triggered by this battery),
# degenerate axes refused, agreement with the A-114
# runner cell-for-cell on cpu, the CUDA Gemma
# comparator reference named and bounded, and a
# deterministic digest across re-runs.

from core.exactness_policy import (
    POLICY_COHERENCE_ONLY,
    POLICY_TOKEN_EXACTNESS_OWED,
    policy_for_quant,
)
from core.gemma_battery_a120 import (
    GB_COHERENCE_ONLY,
    GB_TOKEN_EXACTNESS_OWED,
    GemmaBatteryReport,
    GemmaBatteryRow,
    build_gemma_battery,
    gemma_battery_backends,
    gemma_battery_line,
    gemma_battery_quants,
    gemma_battery_render,
    gemma_battery_row_line,
    gemma_battery_row_verdict,
    gemma_comparator_reference,
    gemma_policy_obligation,
    gemma_policy_obligation_name,
    run_gemma_battery,
)
from core.matrix_runner import (
    MX_FIXTURE_LIMITED,
    MX_NOT_GRADED,
    cell_verdict,
)


def _grow(
    read report: GemmaBatteryReport, quant: String, backend: String
) raises -> GemmaBatteryRow:
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.quant == quant and r.backend == backend:
            return r
    raise Error("gemma battery row not found: " + quant + "/" + backend)


def _graises_build(quants: List[String], backends: List[String]) -> Bool:
    try:
        _ = build_gemma_battery(quants, backends)
    except:
        return True
    return False


def test_gemma_battery_axes_product() raises:
    var quants = gemma_battery_quants()
    var backends = gemma_battery_backends()
    if len(quants) != 19 or len(backends) != 4:
        raise Error("gemma battery axes must be 19 quants x 4 backends")
    if backends[0] != String("cpu") or backends[1] != String("vulkan"):
        raise Error("gemma battery backends must be A-109 harness order")
    if backends[2] != String("hip") or backends[3] != String("npu"):
        raise Error("gemma battery backends must be A-109 harness order")
    var report = run_gemma_battery()
    if report.total != 76 or len(report.rows) != 76:
        raise Error("gemma battery must file exactly 76 rows")


def test_gemma_battery_enumeration_unique() raises:
    var report = run_gemma_battery()
    for i in range(len(report.rows)):
        for j in range(i + 1, len(report.rows)):
            var a = report.rows[i]
            var b = report.rows[j]
            if a.quant == b.quant and a.backend == b.backend:
                raise Error("duplicate gemma battery row")
    var first = report.rows[0]
    if first.quant != String("F16") or first.backend != String("cpu"):
        raise Error("enumeration must start at F16/cpu")
    if String("A-120 gemma-family battery") not in gemma_battery_line():
        raise Error("battery line must name the slice")


def test_gemma_battery_policy_split() raises:
    var quants = gemma_battery_quants()
    var owed = 0
    var coherence = 0
    for i in range(len(quants)):
        if gemma_policy_obligation(quants[i]) == GB_TOKEN_EXACTNESS_OWED:
            owed += 1
        elif gemma_policy_obligation(quants[i]) == GB_COHERENCE_ONLY:
            coherence += 1
        else:
            raise Error("unknown obligation")
    if owed != 10 or coherence != 9:
        raise Error("policy split must be 10 owed / 9 coherence")
    if gemma_policy_obligation(String("IQ4_XS")) != GB_COHERENCE_ONLY:
        raise Error("IQ4_XS must be COHERENCE_ONLY")
    if gemma_policy_obligation(String("Q4_K_M")) != GB_TOKEN_EXACTNESS_OWED:
        raise Error("Q4_K_M must be TOKEN_EXACTNESS_OWED")
    if gemma_policy_obligation_name(GB_COHERENCE_ONLY) != String("COHERENCE_ONLY"):
        raise Error("obligation name mismatch")
    var report = run_gemma_battery()
    if report.owed != 40 or report.coherence != 36:
        raise Error("row policy counts must be 40 owed / 36 coherence")


def test_gemma_battery_policy_canonical() raises:
    var quants = gemma_battery_quants()
    for i in range(len(quants)):
        var row = policy_for_quant(quants[i])
        var mine = gemma_policy_obligation(quants[i])
        if row.obligation == POLICY_TOKEN_EXACTNESS_OWED:
            if mine != GB_TOKEN_EXACTNESS_OWED:
                raise Error("canonical policy disagreement (owed): " + quants[i])
        elif row.obligation == POLICY_COHERENCE_ONLY:
            if mine != GB_COHERENCE_ONLY:
                raise Error("canonical policy disagreement (coherence): " + quants[i])
        else:
            raise Error("canonical policy filed an unknown obligation")
    if GB_TOKEN_EXACTNESS_OWED != POLICY_TOKEN_EXACTNESS_OWED:
        raise Error("owed codes must agree value-for-value with A-115")
    if GB_COHERENCE_ONLY != POLICY_COHERENCE_ONLY:
        raise Error("coherence codes must agree value-for-value with A-115")


def test_gemma_battery_cpu_not_graded() raises:
    var report = run_gemma_battery()
    var quants = gemma_battery_quants()
    var seen = 0
    for i in range(len(quants)):
        var r = _grow(report.copy(), quants[i], String("cpu"))
        if r.verdict != MX_NOT_GRADED:
            raise Error("gemma cpu row must be NOT_GRADED: " + quants[i])
        if r.reason != String("NO_FILED_RECORDS"):
            raise Error("gemma cpu row must name NO_FILED_RECORDS: " + quants[i])
        if r.faithful != -1 or r.worst_rank != -1:
            raise Error("ungraded row must not zero-fill witnesses")
        seen += 1
    if seen != 19:
        raise Error("exactly 19 gemma cpu rows must be NOT_GRADED")
    if report.cpu_not_graded != 19:
        raise Error("report must file cpu_not_graded == 19")


def test_gemma_battery_iq_cpu_not_fixture() raises:
    var report = run_gemma_battery()
    var quants = gemma_battery_quants()
    var seen = 0
    for i in range(len(quants)):
        if gemma_policy_obligation(quants[i]) == GB_COHERENCE_ONLY:
            var r = _grow(report.copy(), quants[i], String("cpu"))
            if r.verdict == MX_FIXTURE_LIMITED:
                raise Error("llama fixture verdict must not transfer to gemma4")
            if r.verdict != MX_NOT_GRADED:
                raise Error("IQ gemma cpu row must be NOT_GRADED")
            if r.obligation != GB_COHERENCE_ONLY:
                raise Error("IQ gemma cpu row must stay COHERENCE_ONLY")
            seen += 1
    if seen != 9:
        raise Error("exactly 9 IQ rows must be checked on cpu")
    if report.fixture_limited != 0:
        raise Error("gemma battery files no fixture-limited rows")


def test_gemma_battery_backend_not_graded() raises:
    var report = run_gemma_battery()
    var count = 0
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.backend != String("cpu"):
            if r.verdict != MX_NOT_GRADED:
                raise Error("non-cpu row must be NOT_GRADED")
            if r.reason != String("BACKEND_NO_CPU_COMPARATOR"):
                raise Error("non-cpu row must name its reason")
            if r.faithful != -1 or r.worst_rank != -1:
                raise Error("ungraded row must not zero-fill witnesses")
            count += 1
    if count != 57:
        raise Error("exactly 57 non-cpu rows must be NOT_GRADED")
    if report.backend_not_graded != 57:
        raise Error("report must file backend_not_graded == 57")


def test_gemma_battery_summary_sums() raises:
    var report = run_gemma_battery()
    var s = report.faithful + report.near_tie + report.divergent
    s += report.artifact + report.fixture_limited + report.not_graded
    if s != report.total:
        raise Error("verdict counts must sum to the total")
    if report.owed + report.coherence != report.total:
        raise Error("policy counts must sum to the total")
    if report.not_graded != 76:
        raise Error("filed not-graded count must be 76")
    if report.cpu_not_graded + report.backend_not_graded != report.not_graded:
        raise Error("not-graded split must sum to the not-graded count")
    var text = gemma_battery_render(report.copy())
    if String("A120_BATTERY_SUMMARY total=76") not in text:
        raise Error("render must carry the summary line")
    var line = gemma_battery_row_line(report.rows[0])
    if String("arch=gemma4") not in line:
        raise Error("row line must carry the gemma4 architecture")
    if String("policy=TOKEN_EXACTNESS_OWED") not in line:
        raise Error("row line must carry the policy obligation")


def test_gemma_battery_no_divergent() raises:
    var report = run_gemma_battery()
    if report.divergent != 0 or report.artifact != 0:
        raise Error("gemma battery files no divergent or artifact rows")
    if report.faithful != 0 or report.near_tie != 0:
        raise Error("gemma battery files no faithful rows without records")
    for i in range(len(report.rows)):
        if report.rows[i].divergent > 0:
            raise Error("no row may carry divergent positions")


def test_gemma_battery_invalid_axes_refused() raises:
    var empty = List[String]()
    var backends = gemma_battery_backends()
    if not _graises_build(empty, backends.copy()):
        raise Error("empty quant axis must be refused")
    var dup = gemma_battery_quants()
    dup.append(String("F16"))
    if not _graises_build(dup, backends.copy()):
        raise Error("duplicate quant axis must be refused")
    var quants = gemma_battery_quants()
    if not _graises_build(quants.copy(), empty.copy()):
        raise Error("empty backend axis must be refused")


def test_gemma_battery_agrees_with_matrix() raises:
    var quants = gemma_battery_quants()
    for i in range(len(quants)):
        var row = gemma_battery_row_verdict(quants[i], String("cpu"))
        var cell = cell_verdict(quants[i], String("gemma4"), String("cpu"))
        if row.verdict != cell.verdict or row.reason != cell.reason:
            raise Error("battery cpu row disagrees with A-114 cell")
        if row.faithful != cell.faithful or row.worst_rank != cell.worst_rank:
            raise Error("battery cpu witness disagrees with A-114 cell")


def test_gemma_battery_comparator_reference() raises:
    var reference = gemma_comparator_reference()
    if String("gemma4_cuda") not in reference:
        raise Error("comparator reference must name the CUDA Gemma work")
    if String("not a CPU comparator") not in reference:
        raise Error("comparator reference must state its bound")
    if String("grades no row") not in reference:
        raise Error("comparator reference must file no graded row")


def test_gemma_battery_digest_deterministic() raises:
    var a = run_gemma_battery()
    var b = run_gemma_battery()
    if a.digest != b.digest or a.digest == UInt64(0):
        raise Error("battery digest must be deterministic and non-zero")
    if gemma_battery_render(a.copy()) != gemma_battery_render(b.copy()):
        raise Error("battery render must be deterministic")
