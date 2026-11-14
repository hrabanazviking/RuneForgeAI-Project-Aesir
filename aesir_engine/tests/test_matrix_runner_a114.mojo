# tests/test_matrix_runner_a114.mojo
# A-114: The full matrix runner -- the matrix is quant x
# architecture x backend with a verdict per cell, and
# these cases cover: the axes and their product, complete
# duplicate-free enumeration in the deterministic order,
# the graded cpu x llama cells exactly as A-045 filed
# them (faithful / near-tie / divergent / fixture-
# artifact), the IQ fixture-limited family, NOT_GRADED
# for every backend without a CPU comparator and every
# architecture without filed records, summary counts
# summing to the total, degenerate axes refused, and a
# deterministic digest across re-runs.

from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_FAITHFUL_NEAR_TIE,
    MX_FIXTURE_LIMITED,
    MX_NOT_GRADED,
    MatrixCell,
    MatrixReport,
    build_matrix,
    cell_verdict,
    is_iq_quant,
    matrix_archs,
    matrix_backends,
    matrix_cell_line,
    matrix_iq_fixture_limited_count,
    matrix_line,
    matrix_quants,
    matrix_render,
    matrix_verdict_name,
    run_matrix,
)


def _cell(
    read report: MatrixReport, quant: String, arch: String, backend: String
) raises -> MatrixCell:
    for i in range(len(report.cells)):
        var c = report.cells[i]
        if c.quant == quant and c.arch == arch and c.backend == backend:
            return c
    raise Error("matrix cell not found: " + quant + "/" + arch + "/" + backend)


def _raises_build(
    quants: List[String], archs: List[String], backends: List[String]
) -> Bool:
    try:
        _ = build_matrix(quants, archs, backends)
    except:
        return True
    return False


def test_matrix_axes_product() raises:
    var quants = matrix_quants()
    var archs = matrix_archs()
    var backends = matrix_backends()
    if len(quants) != 19:
        raise Error("quant axis is not 19 (10 measured + 9 IQ)")
    if len(archs) != 3:
        raise Error("arch axis is not 3")
    if len(backends) != 4:
        raise Error("backend axis is not 4 (tf_harness_backends)")
    if backends[0] != String("cpu") or backends[1] != String("vulkan"):
        raise Error("backend axis drifted from tf_harness_backends order")
    if quants[0] != String("F16") or quants[9] != String("Q6_K"):
        raise Error("measured quant axis drifted from a045_matrix order")
    if quants[10] != String("IQ1_S") or quants[18] != String("IQ4_XS"):
        raise Error("IQ quant axis drifted from the A-045 filed list")
    var report = run_matrix()
    if report.total != 228 or len(report.cells) != 228:
        raise Error("full matrix is not 19 x 3 x 4 = 228 cells")


def test_matrix_enumeration_unique_ordered() raises:
    var report = run_matrix()
    var first = report.cells[0]
    if first.quant != String("F16") or first.arch != String("llama"):
        raise Error("first cell is not F16/llama/cpu")
    if first.backend != String("cpu"):
        raise Error("first cell backend is not cpu")
    var last = report.cells[len(report.cells) - 1]
    if last.quant != String("IQ4_XS") or last.arch != String("mistral3"):
        raise Error("last cell is not IQ4_XS/mistral3/npu")
    if last.backend != String("npu"):
        raise Error("last cell backend is not npu")
    for i in range(len(report.cells)):
        for j in range(i + 1, len(report.cells)):
            var a = report.cells[i]
            var b = report.cells[j]
            if a.quant == b.quant and a.arch == b.arch:
                if a.backend == b.backend:
                    raise Error("duplicate cell in the matrix")


def test_matrix_faithful_cells() raises:
    var report = run_matrix()
    var labels = List[String]()
    labels.append(String("F16"))
    labels.append(String("BF16"))
    labels.append(String("Q8_0"))
    labels.append(String("Q5_K_M"))
    for k in range(len(labels)):
        var c = _cell(report, labels[k], "llama", "cpu")
        if c.verdict != MX_FAITHFUL:
            raise Error("A-045 faithful row not FAITHFUL: " + labels[k])
        if c.faithful != 32 or c.divergent != 0:
            raise Error("faithful cell lost its A-045 witness counts")


def test_matrix_near_tie_cells() raises:
    var report = run_matrix()
    var labels = List[String]()
    labels.append(String("Q5_0"))
    labels.append(String("Q4_K_M"))
    for k in range(len(labels)):
        var c = _cell(report, labels[k], "llama", "cpu")
        if c.verdict != MX_FAITHFUL_NEAR_TIE:
            raise Error("A-045 near-tie row not FAITHFUL_NEAR_TIE: " + labels[k])
        if c.near_tie != 1 or c.divergent != 0:
            raise Error("near-tie cell lost its A-045 witness counts")


def test_matrix_divergent_cells() raises:
    var report = run_matrix()
    var q4 = _cell(report, "Q4_0", "llama", "cpu")
    if q4.verdict != MX_DIVERGENT or q4.divergent != 2:
        raise Error("Q4_0 is not DIVERGENT with its 2 filed positions")
    if q4.worst_rank != 3:
        raise Error("Q4_0 worst rank drifted from the A-045 record")
    var q3 = _cell(report, "Q3_K_M", "llama", "cpu")
    if q3.verdict != MX_DIVERGENT or q3.divergent != 2:
        raise Error("Q3_K_M is not DIVERGENT with its 2 filed positions")
    if q3.worst_rank != 5:
        raise Error("Q3_K_M worst rank drifted from the A-045 record")


def test_matrix_artifact_cells() raises:
    var report = run_matrix()
    var labels = List[String]()
    labels.append(String("Q2_K"))
    labels.append(String("Q6_K"))
    for k in range(len(labels)):
        var c = _cell(report, labels[k], "llama", "cpu")
        if c.verdict != MX_COMPARATOR_ARTIFACT:
            raise Error("filed fixture-artifact row not an artifact: " + labels[k])
        if c.reason != String("A045_FILED_FIXTURE_ARTIFACT"):
            raise Error("artifact cell lost its filed reason")


def test_matrix_iq_fixture_limited() raises:
    if matrix_iq_fixture_limited_count() != 9:
        raise Error("A-109 IQ fixture-limited count is not 9")
    if not is_iq_quant("IQ2_XS") or is_iq_quant("Q4_K_M"):
        raise Error("IQ family predicate is wrong")
    var report = run_matrix()
    var quants = matrix_quants()
    var iq_seen = 0
    for k in range(len(quants)):
        if is_iq_quant(quants[k]):
            iq_seen += 1
            var c = _cell(report, quants[k], "llama", "cpu")
            if c.verdict != MX_FIXTURE_LIMITED:
                raise Error("IQ cell not FIXTURE_LIMITED: " + quants[k])
            if c.faithful != -1:
                raise Error("IQ cell carries fake witness counts")
    if iq_seen != 9:
        raise Error("IQ axis does not carry 9 cells on cpu/llama")
    if report.fixture_limited != 9:
        raise Error("report fixture_limited count is not 9")


def test_matrix_backend_not_graded() raises:
    var report = run_matrix()
    var checked = 0
    for i in range(len(report.cells)):
        var c = report.cells[i]
        if c.backend != String("cpu"):
            checked += 1
            if c.verdict != MX_NOT_GRADED:
                raise Error("non-cpu cell graded without a comparator")
            if c.reason != String("BACKEND_NO_CPU_COMPARATOR"):
                raise Error("non-cpu cell lost its named reason")
    if checked != 171:
        raise Error("non-cpu cell count is not 19 x 3 x 3 = 171")


def test_matrix_arch_not_graded() raises:
    var report = run_matrix()
    var checked = 0
    for i in range(len(report.cells)):
        var c = report.cells[i]
        if c.backend == String("cpu") and c.arch != String("llama"):
            checked += 1
            if c.verdict != MX_NOT_GRADED:
                raise Error("recordless arch cell graded by extrapolation")
            if c.reason != String("NO_FILED_RECORDS"):
                raise Error("recordless arch cell lost its named reason")
    if checked != 38:
        raise Error("cpu recordless-arch cell count is not 19 x 2 = 38")


def test_matrix_summary_sums() raises:
    var report = run_matrix()
    var summed = (
        report.faithful
        + report.near_tie
        + report.divergent
        + report.artifact
        + report.fixture_limited
        + report.not_graded
    )
    if summed != report.total:
        raise Error("verdict counts do not sum to the matrix total")
    if report.faithful != 4 or report.near_tie != 2:
        raise Error("graded faithful counts drifted from the A-045 rows")
    if report.divergent != 2 or report.artifact != 2:
        raise Error("graded divergent/artifact counts drifted")
    if report.not_graded != 209:
        raise Error("not_graded count is not 171 + 38 = 209")
    var recount = 0
    for i in range(len(report.cells)):
        if report.cells[i].verdict == MX_NOT_GRADED:
            recount += 1
    if recount != report.not_graded:
        raise Error("report counts disagree with a recount of the cells")


def test_matrix_invalid_axes_refused() raises:
    var one_q = List[String]()
    one_q.append(String("F16"))
    var dup_q = List[String]()
    dup_q.append(String("F16"))
    dup_q.append(String("F16"))
    var archs = matrix_archs()
    var backends = matrix_backends()
    var empty = List[String]()
    if not _raises_build(empty, archs, backends):
        raise Error("empty quant axis was not refused")
    if not _raises_build(one_q, empty, backends):
        raise Error("empty arch axis was not refused")
    if not _raises_build(one_q, archs, empty):
        raise Error("empty backend axis was not refused")
    if not _raises_build(dup_q, archs, backends):
        raise Error("duplicate quant entry was not refused")


def test_matrix_digest_deterministic() raises:
    var a = run_matrix()
    var b = run_matrix()
    if a.digest == UInt64(0):
        raise Error("matrix digest is zero")
    if a.digest != b.digest:
        raise Error("two runs of the matrix disagree in digest")
    if matrix_render(a) != matrix_render(b):
        raise Error("two runs of the matrix disagree in rendering")
    if matrix_verdict_name(MX_FAITHFUL) != String("FAITHFUL"):
        raise Error("verdict name drifted: FAITHFUL")
    if matrix_verdict_name(MX_FIXTURE_LIMITED) != String("FIXTURE_LIMITED"):
        raise Error("verdict name drifted: FIXTURE_LIMITED")
    if matrix_verdict_name(MX_NOT_GRADED) != String("NOT_GRADED"):
        raise Error("verdict name drifted: NOT_GRADED")
    var line = matrix_cell_line(a.cells[0])
    if line.byte_length() == 0:
        raise Error("cell line renders empty")
    if matrix_line().byte_length() == 0:
        raise Error("matrix line renders empty")
    var single = cell_verdict("Q4_K_M", "llama", "cpu")
    if single.verdict != MX_FAITHFUL_NEAR_TIE:
        raise Error("single-cell verdict disagrees with the full run")
