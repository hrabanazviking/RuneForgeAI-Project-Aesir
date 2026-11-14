# tests/test_qwen_battery_a119.mojo
# A-119: Qwen-family battery -- the battery is the qwen
# rows of the A-114 matrix across all Z13 backends, judged
# per the canonical A-115 policy, and these cases cover:
# the axes and their product, duplicate-free enumeration,
# the policy split (10 TOKEN_EXACTNESS_OWED / 9
# COHERENCE_ONLY, per quant and per row), agreement with
# the canonical A-115 policy table value-for-value, every
# cpu row NOT_GRADED with NO_FILED_RECORDS (no qwen
# teacher-forcing records exist), the IQ precedence pin
# (R2 before R3: qwen IQ cpu rows are NOT_GRADED, never
# FIXTURE_LIMITED), NOT_GRADED on every non-cpu backend
# with its reason, summary counts summing to the total,
# degenerate axes and unknown quants refused, the A-048
# family attestation (arch strings + smoke account),
# agreement with the A-114 runner cell-for-cell on every
# row, and a deterministic digest across re-runs.

from core.exactness_policy import obligation_name, policy_for_quant
from core.matrix_runner import (
    MX_FIXTURE_LIMITED,
    MX_NOT_GRADED,
    cell_verdict,
)
from core.qwen_battery_a119 import (
    QB_COHERENCE_ONLY,
    QB_TOKEN_EXACTNESS_OWED,
    QwenBatteryReport,
    QwenBatteryRow,
    build_qwen_battery,
    qwen_arch_strings,
    qwen_battery_backends,
    qwen_battery_line,
    qwen_battery_quants,
    qwen_battery_render,
    qwen_battery_row_line,
    qwen_battery_row_verdict,
    qwen_policy_codes_match_a115,
    qwen_policy_obligation,
    qwen_policy_obligation_name,
    qwen_smoke_status,
    run_qwen_battery,
)


def _qrow(
    read report: QwenBatteryReport, quant: String, backend: String
) raises -> QwenBatteryRow:
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.quant == quant and r.backend == backend:
            return r
    raise Error("qwen battery row not found: " + quant + "/" + backend)


def _raises_build(quants: List[String], backends: List[String]) -> Bool:
    try:
        _ = build_qwen_battery(quants, backends)
    except:
        return True
    return False


def _raises_obligation(quant: String) -> Bool:
    try:
        _ = qwen_policy_obligation(quant)
    except:
        return True
    return False


def test_qbattery_axes_product() raises:
    var quants = qwen_battery_quants()
    var backends = qwen_battery_backends()
    if len(quants) != 19 or len(backends) != 4:
        raise Error("battery axes must be 19 quants x 4 backends")
    if backends[0] != String("cpu") or backends[1] != String("vulkan"):
        raise Error("battery backends must be A-109 harness order")
    if backends[2] != String("hip") or backends[3] != String("npu"):
        raise Error("battery backends must be A-109 harness order")
    var report = run_qwen_battery()
    if report.total != 76 or len(report.rows) != 76:
        raise Error("battery must file exactly 76 rows")


def test_qbattery_enumeration_unique() raises:
    var report = run_qwen_battery()
    for i in range(len(report.rows)):
        for j in range(i + 1, len(report.rows)):
            var a = report.rows[i]
            var b = report.rows[j]
            if a.quant == b.quant and a.backend == b.backend:
                raise Error("duplicate battery row")
    var first = report.rows[0]
    if first.quant != String("F16") or first.backend != String("cpu"):
        raise Error("enumeration must start at F16/cpu")
    if String("A-119 qwen-family battery") not in qwen_battery_line():
        raise Error("battery line must name the slice")


def test_qbattery_policy_split() raises:
    var quants = qwen_battery_quants()
    var owed = 0
    var coherence = 0
    for i in range(len(quants)):
        var ob = qwen_policy_obligation(quants[i])
        if ob == QB_TOKEN_EXACTNESS_OWED:
            owed += 1
        elif ob == QB_COHERENCE_ONLY:
            coherence += 1
        else:
            raise Error("unknown obligation")
    if owed != 10 or coherence != 9:
        raise Error("policy split must be 10 owed / 9 coherence")
    if qwen_policy_obligation(String("IQ4_XS")) != QB_COHERENCE_ONLY:
        raise Error("IQ4_XS must be COHERENCE_ONLY")
    if qwen_policy_obligation(String("Q4_K_M")) != QB_TOKEN_EXACTNESS_OWED:
        raise Error("Q4_K_M must be TOKEN_EXACTNESS_OWED")
    if qwen_policy_obligation_name(QB_COHERENCE_ONLY) != String("COHERENCE_ONLY"):
        raise Error("obligation name mismatch")
    var report = run_qwen_battery()
    if report.owed != 40 or report.coherence != 36:
        raise Error("row policy counts must be 40 owed / 36 coherence")


def test_qbattery_policy_agrees_with_a115() raises:
    if not qwen_policy_codes_match_a115():
        raise Error("battery obligation codes must match canonical A-115")
    var quants = qwen_battery_quants()
    for i in range(len(quants)):
        var canonical = policy_for_quant(quants[i])
        if qwen_policy_obligation(quants[i]) != canonical.obligation:
            raise Error("battery obligation disagrees with A-115: " + quants[i])
        var name = qwen_policy_obligation_name(canonical.obligation)
        if name != obligation_name(canonical.obligation):
            raise Error("obligation name disagrees with A-115: " + quants[i])


def test_qbattery_cpu_no_filed_records() raises:
    var report = run_qwen_battery()
    var quants = qwen_battery_quants()
    if len(quants) != 19:
        raise Error("quant axis must hold 19 labels")
    for i in range(len(quants)):
        var r = _qrow(report.copy(), quants[i], String("cpu"))
        if r.verdict != MX_NOT_GRADED:
            raise Error("qwen cpu row must be NOT_GRADED: " + quants[i])
        if r.reason != String("NO_FILED_RECORDS"):
            raise Error("qwen cpu row must name NO_FILED_RECORDS: " + quants[i])
        if r.faithful != -1 or r.worst_rank != -1:
            raise Error("ungraded row must not zero-fill witnesses")
    if report.not_graded_no_records != 19:
        raise Error("exactly 19 cpu rows must file NO_FILED_RECORDS")


def test_qbattery_iq_cpu_not_fixture_limited() raises:
    # Precedence pin: A-114 R2 (arch) fires before R3 (IQ),
    # so qwen IQ cpu rows are NOT_GRADED with the coherence
    # obligation filed -- never FIXTURE_LIMITED, which is a
    # llama-fixture verdict qwen has no fixture to earn.
    var report = run_qwen_battery()
    var quants = qwen_battery_quants()
    var seen = 0
    for i in range(len(quants)):
        if qwen_policy_obligation(quants[i]) == QB_COHERENCE_ONLY:
            var r = _qrow(report.copy(), quants[i], String("cpu"))
            if r.verdict == MX_FIXTURE_LIMITED:
                raise Error("qwen IQ cpu row must not be FIXTURE_LIMITED")
            if r.verdict != MX_NOT_GRADED:
                raise Error("qwen IQ cpu row must be NOT_GRADED")
            if r.obligation != QB_COHERENCE_ONLY:
                raise Error("IQ row must still file COHERENCE_ONLY")
            seen += 1
    if seen != 9:
        raise Error("exactly 9 IQ rows must be checked on cpu")
    if report.fixture_limited != 0:
        raise Error("the qwen battery files no FIXTURE_LIMITED rows")


def test_qbattery_backend_not_graded() raises:
    var report = run_qwen_battery()
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
    if report.not_graded_backend != 57:
        raise Error("summary must count 57 backend-not-graded rows")


def test_qbattery_summary_sums() raises:
    var report = run_qwen_battery()
    var s = report.faithful + report.near_tie + report.divergent
    s += report.artifact + report.fixture_limited + report.not_graded
    if s != report.total:
        raise Error("verdict counts must sum to the total")
    if report.owed + report.coherence != report.total:
        raise Error("policy counts must sum to the total")
    if report.faithful != 0 or report.near_tie != 0:
        raise Error("no qwen row may file a graded faithful verdict")
    if report.divergent != 0 or report.artifact != 0:
        raise Error("no qwen row may file divergent/artifact")
    if report.fixture_limited != 0 or report.not_graded != 76:
        raise Error("all 76 rows must file NOT_GRADED, none limited")
    if report.not_graded_backend + report.not_graded_no_records != 76:
        raise Error("not-graded reasons must account for every row")
    var text = qwen_battery_render(report.copy())
    if String("A119_BATTERY_SUMMARY total=76") not in text:
        raise Error("render must carry the summary line")
    var line = qwen_battery_row_line(report.rows[0])
    if String("arch=qwen") not in line:
        raise Error("row line must carry the qwen arch")
    if String("policy=TOKEN_EXACTNESS_OWED") not in line:
        raise Error("row line must carry the policy obligation")


def test_qbattery_invalid_axes_refused() raises:
    var empty = List[String]()
    var backends = qwen_battery_backends()
    if not _raises_build(empty, backends.copy()):
        raise Error("empty quant axis must be refused")
    var dup = qwen_battery_quants()
    dup.append(String("F16"))
    if not _raises_build(dup, backends.copy()):
        raise Error("duplicate quant axis must be refused")
    var quants = qwen_battery_quants()
    if not _raises_build(quants.copy(), empty.copy()):
        raise Error("empty backend axis must be refused")


def test_qbattery_unknown_quant_refused() raises:
    # The canonical A-115 lookup refuses unknown labels
    # (its T1); the battery must inherit that refusal,
    # never default an obligation for an unlisted quant.
    if not _raises_obligation(String("Q9_ZZZ")):
        raise Error("unknown quant must be refused, not defaulted")
    if not _raises_obligation(String("")):
        raise Error("empty quant must be refused, not defaulted")
    var bad = List[String]()
    bad.append(String("Q9_ZZZ"))
    if not _raises_build(bad, qwen_battery_backends()):
        raise Error("a battery over an unknown quant must be refused")


def test_qbattery_arch_strings_and_smoke() raises:
    var archs = qwen_arch_strings()
    if len(archs) != 3:
        raise Error("qwen family must attest exactly 3 arch strings")
    if archs[0] != String("qwen2") or archs[1] != String("qwen3"):
        raise Error("arch strings must start qwen2, qwen3")
    if archs[2] != String("qwen35"):
        raise Error("arch strings must end qwen35")
    if qwen_smoke_status(String("qwen2")) != String("SMOKE_PASS_SYNTHETIC"):
        raise Error("qwen2 smoke must be A-048 SMOKE_PASS (synthetic)")
    if qwen_smoke_status(String("qwen3")) != String("SMOKE_PASS_SYNTHETIC"):
        raise Error("qwen3 smoke must be A-048 SMOKE_PASS (synthetic)")
    if qwen_smoke_status(String("qwen35")) != String("LOAD_FAIL_NAMED_CAUSE"):
        raise Error("qwen35 smoke must be A-048 LOAD_FAIL, named cause")
    if qwen_smoke_status(String("qwen9")) != String("NO_FILED_SMOKE_ROW"):
        raise Error("unrowed arch must file NO_FILED_SMOKE_ROW")


def test_qbattery_agrees_with_matrix() raises:
    var quants = qwen_battery_quants()
    var backends = qwen_battery_backends()
    for i in range(len(quants)):
        for j in range(len(backends)):
            var row = qwen_battery_row_verdict(quants[i], backends[j])
            var cell = cell_verdict(quants[i], String("qwen"), backends[j])
            if row.verdict != cell.verdict or row.reason != cell.reason:
                raise Error("battery row disagrees with A-114 cell")
            if row.faithful != cell.faithful or row.worst_rank != cell.worst_rank:
                raise Error("battery witness disagrees with A-114 cell")


def test_qbattery_digest_deterministic() raises:
    var a = run_qwen_battery()
    var b = run_qwen_battery()
    if a.digest != b.digest or a.digest == UInt64(0):
        raise Error("battery digest must be deterministic and non-zero")
    if qwen_battery_render(a.copy()) != qwen_battery_render(b.copy()):
        raise Error("battery render must be deterministic")
