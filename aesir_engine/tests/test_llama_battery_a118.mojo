# tests/test_llama_battery_a118.mojo
# A-118: Llama-family battery -- the battery is the llama
# rows of the A-114 matrix across all Z13 backends, judged
# per the A-115 policy mirror, and these cases cover: the
# axes and their product, duplicate-free enumeration, the
# policy split (10 TOKEN_EXACTNESS_OWED / 9 COHERENCE_ONLY,
# per quant and per row), the cpu rows exactly as A-114
# filed them (faithful / near-tie / divergent / fixture-
# artifact), IQ fixture-limited on cpu, NOT_GRADED on every
# non-cpu backend with the obligation still filed, summary
# counts summing to the total, degenerate axes refused,
# agreement with the A-114 runner cell-for-cell on cpu, and
# a deterministic digest across re-runs.

from core.llama_battery_a118 import (
    LB_COHERENCE_ONLY,
    LB_TOKEN_EXACTNESS_OWED,
    BatteryReport,
    BatteryRow,
    battery_backends,
    battery_line,
    battery_quants,
    battery_render,
    battery_row_line,
    battery_row_verdict,
    build_battery,
    policy_obligation,
    policy_obligation_name,
    run_battery,
)
from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_FAITHFUL_NEAR_TIE,
    MX_FIXTURE_LIMITED,
    MX_NOT_GRADED,
    cell_verdict,
)


def _row(
    read report: BatteryReport, quant: String, backend: String
) raises -> BatteryRow:
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.quant == quant and r.backend == backend:
            return r
    raise Error("battery row not found: " + quant + "/" + backend)


def _raises_build(quants: List[String], backends: List[String]) -> Bool:
    try:
        _ = build_battery(quants, backends)
    except:
        return True
    return False


def test_battery_axes_product() raises:
    var quants = battery_quants()
    var backends = battery_backends()
    if len(quants) != 19 or len(backends) != 4:
        raise Error("battery axes must be 19 quants x 4 backends")
    if backends[0] != String("cpu") or backends[1] != String("vulkan"):
        raise Error("battery backends must be A-109 harness order")
    if backends[2] != String("hip") or backends[3] != String("npu"):
        raise Error("battery backends must be A-109 harness order")
    var report = run_battery()
    if report.total != 76 or len(report.rows) != 76:
        raise Error("battery must file exactly 76 rows")


def test_battery_enumeration_unique() raises:
    var report = run_battery()
    for i in range(len(report.rows)):
        for j in range(i + 1, len(report.rows)):
            var a = report.rows[i]
            var b = report.rows[j]
            if a.quant == b.quant and a.backend == b.backend:
                raise Error("duplicate battery row")
    var first = report.rows[0]
    if first.quant != String("F16") or first.backend != String("cpu"):
        raise Error("enumeration must start at F16/cpu")
    if String("A-118 llama-family battery") not in battery_line():
        raise Error("battery line must name the slice")


def test_battery_policy_split() raises:
    var quants = battery_quants()
    var owed = 0
    var coherence = 0
    for i in range(len(quants)):
        if policy_obligation(quants[i]) == LB_TOKEN_EXACTNESS_OWED:
            owed += 1
        elif policy_obligation(quants[i]) == LB_COHERENCE_ONLY:
            coherence += 1
        else:
            raise Error("unknown obligation")
    if owed != 10 or coherence != 9:
        raise Error("policy split must be 10 owed / 9 coherence")
    if policy_obligation(String("IQ4_XS")) != LB_COHERENCE_ONLY:
        raise Error("IQ4_XS must be COHERENCE_ONLY")
    if policy_obligation(String("Q4_K_M")) != LB_TOKEN_EXACTNESS_OWED:
        raise Error("Q4_K_M must be TOKEN_EXACTNESS_OWED")
    if policy_obligation_name(LB_COHERENCE_ONLY) != String("COHERENCE_ONLY"):
        raise Error("obligation name mismatch")
    var report = run_battery()
    if report.owed != 40 or report.coherence != 36:
        raise Error("row policy counts must be 40 owed / 36 coherence")


def test_battery_cpu_faithful() raises:
    var report = run_battery()
    var names = List[String]()
    names.append(String("F16"))
    names.append(String("BF16"))
    names.append(String("Q8_0"))
    names.append(String("Q5_K_M"))
    for i in range(len(names)):
        var r = _row(report.copy(), names[i], String("cpu"))
        if r.verdict != MX_FAITHFUL:
            raise Error("cpu faithful row mismatch: " + names[i])
        if r.obligation != LB_TOKEN_EXACTNESS_OWED:
            raise Error("faithful rows owe token-exactness")


def test_battery_cpu_near_tie() raises:
    var report = run_battery()
    var a = _row(report.copy(), String("Q5_0"), String("cpu"))
    var b = _row(report.copy(), String("Q4_K_M"), String("cpu"))
    if a.verdict != MX_FAITHFUL_NEAR_TIE or b.verdict != MX_FAITHFUL_NEAR_TIE:
        raise Error("cpu near-tie rows must be Q5_0 and Q4_K_M")


def test_battery_cpu_divergent() raises:
    var report = run_battery()
    var a = _row(report.copy(), String("Q4_0"), String("cpu"))
    var b = _row(report.copy(), String("Q3_K_M"), String("cpu"))
    if a.verdict != MX_DIVERGENT or b.verdict != MX_DIVERGENT:
        raise Error("cpu divergent rows must be Q4_0 and Q3_K_M")
    if a.divergent <= 0 or b.divergent <= 0:
        raise Error("divergent rows must carry divergent positions")


def test_battery_cpu_artifact() raises:
    var report = run_battery()
    var a = _row(report.copy(), String("Q2_K"), String("cpu"))
    var b = _row(report.copy(), String("Q6_K"), String("cpu"))
    if a.verdict != MX_COMPARATOR_ARTIFACT:
        raise Error("Q2_K cpu must be COMPARATOR_ARTIFACT")
    if b.verdict != MX_COMPARATOR_ARTIFACT:
        raise Error("Q6_K cpu must be COMPARATOR_ARTIFACT")


def test_battery_iq_fixture_limited() raises:
    var report = run_battery()
    var quants = battery_quants()
    var seen = 0
    for i in range(len(quants)):
        if policy_obligation(quants[i]) == LB_COHERENCE_ONLY:
            var r = _row(report.copy(), quants[i], String("cpu"))
            if r.verdict != MX_FIXTURE_LIMITED:
                raise Error("IQ cpu row must be FIXTURE_LIMITED")
            seen += 1
    if seen != 9:
        raise Error("exactly 9 IQ rows must be fixture-limited on cpu")


def test_battery_backend_not_graded() raises:
    var report = run_battery()
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


def test_battery_summary_sums() raises:
    var report = run_battery()
    var s = report.faithful + report.near_tie + report.divergent
    s += report.artifact + report.fixture_limited + report.not_graded
    if s != report.total:
        raise Error("verdict counts must sum to the total")
    if report.owed + report.coherence != report.total:
        raise Error("policy counts must sum to the total")
    if report.faithful != 4 or report.near_tie != 2:
        raise Error("filed faithful counts mismatch")
    if report.divergent != 2 or report.artifact != 2:
        raise Error("filed divergent/artifact counts mismatch")
    if report.fixture_limited != 9 or report.not_graded != 57:
        raise Error("filed limited/not-graded counts mismatch")
    var text = battery_render(report.copy())
    if String("A118_BATTERY_SUMMARY total=76") not in text:
        raise Error("render must carry the summary line")
    var line = battery_row_line(report.rows[0])
    if String("policy=TOKEN_EXACTNESS_OWED") not in line:
        raise Error("row line must carry the policy obligation")


def test_battery_invalid_axes_refused() raises:
    var empty = List[String]()
    var backends = battery_backends()
    if not _raises_build(empty, backends.copy()):
        raise Error("empty quant axis must be refused")
    var dup = battery_quants()
    dup.append(String("F16"))
    if not _raises_build(dup, backends.copy()):
        raise Error("duplicate quant axis must be refused")
    var quants = battery_quants()
    if not _raises_build(quants.copy(), empty.copy()):
        raise Error("empty backend axis must be refused")


def test_battery_agrees_with_matrix() raises:
    var quants = battery_quants()
    for i in range(len(quants)):
        var row = battery_row_verdict(quants[i], String("cpu"))
        var cell = cell_verdict(quants[i], String("llama"), String("cpu"))
        if row.verdict != cell.verdict or row.reason != cell.reason:
            raise Error("battery cpu row disagrees with A-114 cell")
        if row.faithful != cell.faithful or row.worst_rank != cell.worst_rank:
            raise Error("battery cpu witness disagrees with A-114 cell")


def test_battery_digest_deterministic() raises:
    var a = run_battery()
    var b = run_battery()
    if a.digest != b.digest or a.digest == UInt64(0):
        raise Error("battery digest must be deterministic and non-zero")
    if battery_render(a.copy()) != battery_render(b.copy()):
        raise Error("battery render must be deterministic")
