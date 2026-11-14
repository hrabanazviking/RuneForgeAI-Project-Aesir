"""A-114: The full matrix runner -- quant x architecture x
backend, one command (Wave 13, Oracle infrastructure).

The roadmap text: "Quant x architecture x backend, one
command. Acceptance: a full run completes on the Z13 and
emits the matrix with a verdict per cell."

Before this slice the tree had the pieces and no matrix:
A-109 (core/teacher_forcing_harness.mojo) carries the
measured A-045 CPU parity matrix as data -- ten quant rows
on the llama architecture, graded by teacher-forcing rank
+ logit gap on RAW prompts, CPU engine vs CPU comparator
only -- plus the nine IQ rows A-045 filed fixture-limited.
A-110 (core/oracle_pins.mojo) pins every judged row's
model sha256, oracle backend, oracle build hash and raw
prompt hash. A-111 (core/near_tie_gate.mojo) encodes the
band ONCE: rank <= 2 AND gap_milli < 1000 = faithful. This
module is the runner that lays those banked surfaces out
as the full quant x architecture x backend matrix and
files exactly one verdict per cell. No caller assembles
the matrix by hand and no cell is left unexplained: a
cell this runner cannot grade carries a named NOT_GRADED
or FIXTURE_LIMITED verdict with its reason, never a pass
and never a silent omission.

AXES (all from banked surfaces, nothing invented):
  Quants (19): the ten A-045 measured rows in their filed
    order (F16, BF16, Q8_0, Q4_0, Q5_0, Q2_K, Q3_K_M,
    Q4_K_M, Q5_K_M, Q6_K) followed by the nine IQ rows
    A-045 filed fixture-limited (IQ1_S, IQ1_M, IQ2_XXS,
    IQ2_XS, IQ2_S, IQ3_XXS, IQ3_S, IQ4_NL, IQ4_XS) -- the
    list spelled out in a045_iq_fixture_limited_count.
  Architectures (3): llama (the A-045 fixture family:
    stories260K + Meta-Llama-3.1-8B), gemma4 and mistral3
    (both attested in the tree's filed evidence; neither
    has filed teacher-forcing records).
  Backends (4): exactly tf_harness_backends() from A-109
    (cpu, vulkan, hip, npu), called, never re-typed.
  The full matrix is 19 x 3 x 4 = 228 cells.

THE VERDICT RULE, PRE-REGISTERED (stated here before any
test in tests/test_matrix_runner_a114.mojo was run). For
one cell (quant, arch, backend), in this order:
  (R1) backend != cpu -> NOT_GRADED, reason
       BACKEND_NO_CPU_COMPARATOR. Grading in this tree is
       CPU engine vs CPU comparator only (A-109's
       tf_validate_run pins engine and oracle to cpu). A
       vulkan / hip / npu cell has no comparator and this
       runner files no device-execution evidence for it;
       accelerator-visible is NOT accelerator-run, so the
       cell is not graded -- never passed, never failed.
  (R2) arch != llama -> NOT_GRADED, reason
       NO_FILED_RECORDS. The only filed measured records
       are llama-arch; gemma4 / mistral3 rows are owed
       when records exist, not extrapolated from llama.
  (R3) quant in the IQ family -> FIXTURE_LIMITED, reason
       IQ_FIXTURE_LIMITED. A-045's filed verdict: the
       stories260K fixture cannot satisfy the 256-value
       IQ super-block by construction -- a fixture
       limitation, not an engine defect. IQ rows are
       graded on coherence, never token-exactness (the
       per-family policy encoding is A-115's slice); this
       runner files no coherence evidence, so the honest
       verdict is FIXTURE_LIMITED.
  (R4) a measured A-045 row -> the verdict its filed
       record states, mapped onto the A-111 gate's
       verdict codes: filed "fixture-artifact" ->
       COMPARATOR_ARTIFACT (the standing verdict class;
       precedence over the record pattern, exactly as
       the gate's G2); divergent position count > 0 ->
       DIVERGENT; near-tie count > 0 ->
       FAITHFUL_NEAR_TIE; otherwise FAITHFUL. The cell
       keeps the A-045 row's counts (faithful / near-tie
       / divergent positions and worst rank) as its
       witness. Mapping codes 0..3 ARE the gate's
       BAND_FAITHFUL / BAND_FAITHFUL_NEAR_TIE /
       BAND_DIVERGENT / BAND_COMPARATOR_ARTIFACT values;
       FIXTURE_LIMITED (4) and NOT_GRADED (5) are
       runner-level classes the gate does not mint (the
       gate's own NOT_GRADED is 4 there -- the two
       namespaces are filed separately and never mixed).

INTEGRATION POINTS (honest, named, not depended on):
  A-112 (comparator-artifact checklist, team-25) and
  A-113 (golden corpus, team-26) are building in parallel
  and have NOT banked. This runner takes NO dependency on
  either. When A-112 banks, its checklist refines R4's
  COMPARATOR_ARTIFACT cells (and may split NOT_GRADED
  cells whose comparison proves invalid) without changing
  this rule's shape; when A-113 banks, its golden corpus
  is the record source that can retire R2's NOT_GRADED
  for the architectures it covers. Until then both are
  owed, and A-135 (Part V gate) re-verdicts this matrix.

RAW-ORACLE DISCIPLINE (standing): every graded cell rests
on teacher-forcing rank + logit gap on RAW prompts, CPU
engine vs CPU comparator only, rows pinned per A-110.
The runner itself executes no model, opens no device,
and claims no speed and no accelerator execution: pure
enumeration and arithmetic on banked, filed records, in
the J-031/J-053 account style. The bench driver
(tests/bench_matrix_a114.mojo) emits the full matrix on
the Z13 in one command; its log is the acceptance
evidence, and it shows exactly the verdicts above --
the 19 graded / fixture-limited cpu x llama cells and
209 honestly NOT_GRADED cells, zero unexplained.
"""

from core.near_tie_gate import BAND_COMPARATOR_ARTIFACT
from core.teacher_forcing_harness import (
    a045_iq_fixture_limited_count,
    a045_matrix,
    tf_harness_backends,
)

# Cell verdict codes. 0..3 are value-for-value the A-111
# gate's verdict codes (see the header); 4 and 5 are
# runner-level classes.
comptime MX_FAITHFUL = 0
comptime MX_FAITHFUL_NEAR_TIE = 1
comptime MX_DIVERGENT = 2
comptime MX_COMPARATOR_ARTIFACT = 3
comptime MX_FIXTURE_LIMITED = 4
comptime MX_NOT_GRADED = 5

# The graded architecture and backend: the only pair the
# banked records cover (A-045 / A-109).
comptime MX_GRADED_ARCH = "llama"
comptime MX_GRADED_BACKEND = "cpu"


def mx_fnv1a64(text: String) -> UInt64:
    """FNV-1a 64 over the text bytes -- the tree's digest
    convention (same constants as tf_fnv1a64 in A-109)."""
    var hash: UInt64 = 14695981039346656037
    var prime: UInt64 = 1099511628211
    var bytes = text.as_bytes()
    for i in range(len(bytes)):
        hash = hash ^ UInt64(bytes[i])
        hash = hash * prime
    return hash


def matrix_quants() -> List[String]:
    """The 19 quant axis entries: the ten A-045 measured
    labels in filed order, then the nine IQ labels A-045
    filed fixture-limited, in the order A-109 spells
    them. Derived from a045_matrix() -- never re-typed
    for the measured half."""
    var q = List[String]()
    var rows = a045_matrix()
    for i in range(len(rows)):
        q.append(rows[i].label)
    q.append(String("IQ1_S"))
    q.append(String("IQ1_M"))
    q.append(String("IQ2_XXS"))
    q.append(String("IQ2_XS"))
    q.append(String("IQ2_S"))
    q.append(String("IQ3_XXS"))
    q.append(String("IQ3_S"))
    q.append(String("IQ4_NL"))
    q.append(String("IQ4_XS"))
    return q^


def matrix_archs() -> List[String]:
    """The 3 architecture axis entries. Only llama has
    filed teacher-forcing records; gemma4 and mistral3
    are attested in the tree's filed evidence and are
    carried as NOT_GRADED axes, not dropped."""
    var a = List[String]()
    a.append(String("llama"))
    a.append(String("gemma4"))
    a.append(String("mistral3"))
    return a^


def matrix_backends() -> List[String]:
    """The 4 backend axis entries: exactly A-109's
    tf_harness_backends(), called so the axis cannot
    drift from the harness."""
    return tf_harness_backends()


def is_iq_quant(quant: String) -> Bool:
    """True iff the quant label is in the IQ family (the
    A-045 fixture-limited family). IQ rows are graded on
    coherence, never token-exactness."""
    var bytes = quant.as_bytes()
    if len(bytes) < 2:
        return False
    return bytes[0] == 73 and bytes[1] == 81  # 'I', 'Q'


struct MatrixCell(Copyable, ImplicitlyCopyable):
    """One matrix cell and its filed verdict. faithful /
    near_tie / divergent / worst_rank are the A-045 row's
    position counts for a graded cell and -1 for a cell
    no record witnesses (NOT_GRADED / FIXTURE_LIMITED):
    the absence is stated, never zero-filled into a
    fake perfect row."""

    var quant: String
    var arch: String
    var backend: String
    var verdict: Int
    var reason: String
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var worst_rank: Int

    def __init__(
        out self,
        quant: String,
        arch: String,
        backend: String,
        verdict: Int,
        reason: String,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        worst_rank: Int,
    ):
        self.quant = quant
        self.arch = arch
        self.backend = backend
        self.verdict = verdict
        self.reason = reason
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.worst_rank = worst_rank


struct MatrixReport(Copyable, Movable):
    """One full matrix run: every cell with its verdict,
    the per-verdict counts (which sum to total by
    construction and by test), and the FNV-1a digest of
    the rendered matrix -- a re-run on the same banked
    records reproduces the digest exactly."""

    var cells: List[MatrixCell]
    var total: Int
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var artifact: Int
    var fixture_limited: Int
    var not_graded: Int
    var digest: UInt64

    def __init__(
        out self,
        cells: List[MatrixCell],
        total: Int,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        artifact: Int,
        fixture_limited: Int,
        not_graded: Int,
        digest: UInt64,
    ):
        self.cells = cells.copy()
        self.total = total
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.artifact = artifact
        self.fixture_limited = fixture_limited
        self.not_graded = not_graded
        self.digest = digest


def _check_axis(axis: List[String], axis_name: String) raises:
    """One axis must be non-empty and duplicate-free: an
    empty axis would file a zero-cell run as success and
    a duplicate would double-count a cell. Both are
    refused before any cell is built."""
    if len(axis) == 0:
        raise Error("MatrixRunner: " + axis_name + " axis is empty")
    for i in range(len(axis)):
        for j in range(i + 1, len(axis)):
            if axis[i] == axis[j]:
                raise Error(
                    "MatrixRunner: duplicate "
                    + axis_name
                    + " entry "
                    + axis[i]
                )


def cell_verdict(
    quant: String, arch: String, backend: String
) -> MatrixCell:
    """The pre-registered verdict rule (R1-R4) for one
    cell, applied to the banked A-045 records only."""
    if backend != String(MX_GRADED_BACKEND):
        return MatrixCell(
            quant, arch, backend, MX_NOT_GRADED,
            String("BACKEND_NO_CPU_COMPARATOR"), -1, -1, -1, -1,
        )
    if arch != String(MX_GRADED_ARCH):
        return MatrixCell(
            quant, arch, backend, MX_NOT_GRADED,
            String("NO_FILED_RECORDS"), -1, -1, -1, -1,
        )
    if is_iq_quant(quant):
        return MatrixCell(
            quant, arch, backend, MX_FIXTURE_LIMITED,
            String("IQ_FIXTURE_LIMITED"), -1, -1, -1, -1,
        )
    var rows = a045_matrix()
    for i in range(len(rows)):
        if rows[i].label == quant:
            var row = rows[i]
            if row.verdict == String("fixture-artifact"):
                return MatrixCell(
                    quant, arch, backend, MX_COMPARATOR_ARTIFACT,
                    String("A045_FILED_FIXTURE_ARTIFACT"),
                    row.faithful, row.near_tie, row.divergent,
                    row.worst_rank,
                )
            if row.divergent > 0:
                return MatrixCell(
                    quant, arch, backend, MX_DIVERGENT,
                    String("A045_DIVERGENT_POSITIONS"),
                    row.faithful, row.near_tie, row.divergent,
                    row.worst_rank,
                )
            if row.near_tie > 0:
                return MatrixCell(
                    quant, arch, backend, MX_FAITHFUL_NEAR_TIE,
                    String("A045_NEAR_TIE_POSITIONS"),
                    row.faithful, row.near_tie, row.divergent,
                    row.worst_rank,
                )
            return MatrixCell(
                quant, arch, backend, MX_FAITHFUL,
                String("A045_ALL_POSITIONS_FAITHFUL"),
                row.faithful, row.near_tie, row.divergent,
                row.worst_rank,
            )
    return MatrixCell(
        quant, arch, backend, MX_NOT_GRADED,
        String("NO_FILED_RECORDS"), -1, -1, -1, -1,
    )


def build_matrix(
    quants: List[String], archs: List[String], backends: List[String]
) raises -> List[MatrixCell]:
    """Enumerate the full Cartesian matrix in the one
    deterministic order (quant outer, then arch, then
    backend -- each in axis order) with a verdict per
    cell. The cell count is exactly the axis product."""
    _check_axis(quants, "quant")
    _check_axis(archs, "arch")
    _check_axis(backends, "backend")
    var cells = List[MatrixCell]()
    for qi in range(len(quants)):
        for ai in range(len(archs)):
            for bi in range(len(backends)):
                cells.append(
                    cell_verdict(quants[qi], archs[ai], backends[bi])
                )
    return cells^


def run_matrix() raises -> MatrixReport:
    """The full run, one command: build the default
    19 x 3 x 4 matrix, count the verdicts, digest the
    rendering. Pure over the banked records -- a re-run
    reproduces counts and digest exactly."""
    var cells = build_matrix(
        matrix_quants(), matrix_archs(), matrix_backends()
    )
    var faithful = 0
    var near_tie = 0
    var divergent = 0
    var artifact = 0
    var fixture_limited = 0
    var not_graded = 0
    for i in range(len(cells)):
        var v = cells[i].verdict
        if v == MX_FAITHFUL:
            faithful += 1
        elif v == MX_FAITHFUL_NEAR_TIE:
            near_tie += 1
        elif v == MX_DIVERGENT:
            divergent += 1
        elif v == MX_COMPARATOR_ARTIFACT:
            artifact += 1
        elif v == MX_FIXTURE_LIMITED:
            fixture_limited += 1
        else:
            not_graded += 1
    var report = MatrixReport(
        cells.copy(),
        len(cells),
        faithful,
        near_tie,
        divergent,
        artifact,
        fixture_limited,
        not_graded,
        UInt64(0),
    )
    report.digest = mx_fnv1a64(matrix_render(report.copy()))
    return report^


def matrix_verdict_name(verdict: Int) -> String:
    """The filed name of a cell verdict code -- the only
    strings a matrix filing may use for a cell."""
    if verdict == MX_FAITHFUL:
        return String("FAITHFUL")
    if verdict == MX_FAITHFUL_NEAR_TIE:
        return String("FAITHFUL_NEAR_TIE")
    if verdict == MX_DIVERGENT:
        return String("DIVERGENT")
    if verdict == MX_COMPARATOR_ARTIFACT:
        return String("COMPARATOR_ARTIFACT")
    if verdict == MX_FIXTURE_LIMITED:
        return String("FIXTURE_LIMITED")
    return String("NOT_GRADED")


def matrix_cell_line(cell: MatrixCell) -> String:
    """One cell as one filed line."""
    var s = String("MX_CELL quant=") + cell.quant
    s += String(" arch=") + cell.arch
    s += String(" backend=") + cell.backend
    s += String(" verdict=") + matrix_verdict_name(cell.verdict)
    s += String(" reason=") + cell.reason
    s += String(" faithful=") + String(cell.faithful)
    s += String(" near_tie=") + String(cell.near_tie)
    s += String(" divergent=") + String(cell.divergent)
    s += String(" worst_rank=") + String(cell.worst_rank)
    return s


def matrix_render(read report: MatrixReport) -> String:
    """The full matrix as filed text: header, one line
    per cell in enumeration order, summary. This is the
    text the digest covers and the bench emits."""
    var s = String("A114_MATRIX quants=")
    s += String(len(matrix_quants()))
    s += String(" archs=") + String(len(matrix_archs()))
    s += String(" backends=") + String(len(matrix_backends()))
    s += String(" total=") + String(report.total) + String("\n")
    for i in range(len(report.cells)):
        s += matrix_cell_line(report.cells[i]) + String("\n")
    s += String("A114_MATRIX_SUMMARY total=") + String(report.total)
    s += String(" faithful=") + String(report.faithful)
    s += String(" near_tie=") + String(report.near_tie)
    s += String(" divergent=") + String(report.divergent)
    s += String(" artifact=") + String(report.artifact)
    s += String(" fixture_limited=") + String(report.fixture_limited)
    s += String(" not_graded=") + String(report.not_graded)
    return s


def matrix_line() -> String:
    """The runner's one-line statement, for doctor /
    filing surfaces that quote what the matrix is."""
    return String(
        "A-114 full matrix runner: quant x architecture x"
        " backend, one command; verdict per cell from the"
        " banked A-045/A-109 records under the A-111 gate;"
        " ungraded cells filed NOT_GRADED with a named"
        " reason, IQ cells FIXTURE_LIMITED, zero unexplained"
    )


def matrix_iq_fixture_limited_count() -> Int:
    """The IQ axis size, cross-checked against A-109's
    filed fixture-limitation count (9)."""
    return a045_iq_fixture_limited_count()


def matrix_artifact_code_is_gate_code() -> Bool:
    """True iff the runner's comparator-artifact code is
    the A-111 gate's code, so filings read alike."""
    return MX_COMPARATOR_ARTIFACT == BAND_COMPARATOR_ARTIFACT
