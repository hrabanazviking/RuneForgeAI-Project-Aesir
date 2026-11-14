"""A-119: Qwen-family battery -- the qwen architecture
rows of the full matrix, on all Z13 backends, judged per
the A-115 token-exactness policy (Wave 14, Architecture
breadth).

The roadmap text: "Qwen-family battery. Acceptance: rows
judged." (Wave 14's family batteries are judged per the
A-115 policy; A-118's entry states that rule for the wave
and this battery follows the A-118 pattern.)

This battery is the qwen slice of the banked A-114 full
matrix runner (core/matrix_runner.mojo): the 19 quant rows
of the banked quant axis laid across all four Z13
backends (exactly A-109's tf_harness_backends: cpu,
vulkan, hip, npu) = 76 rows, every row with a verdict and
a policy obligation, zero unexplained. Rows are NOT
re-derived here: each row files exactly the verdict the
A-114 runner files for its (quant, qwen, backend) cell,
so the battery and the matrix cannot drift apart.

THE A-115 POLICY, CANONICAL (banked, depended on):
Unlike A-118 -- built while A-115 was still in flight and
forced to mirror the policy as data -- A-115 HAS banked
(commit 0e97855f, "A-115: Token-exactness policy,
encoded"). This module therefore takes its obligations
from the canonical encoding, core/exactness_policy.mojo,
CALLED (policy_for_quant), never re-typed: the ten
measured quants (F16, BF16, Q8_0, Q4_0, Q5_0, Q2_K,
Q3_K_M, Q4_K_M, Q5_K_M, Q6_K) are TOKEN_EXACTNESS_OWED
under the A-111 near-tie gate, and the nine IQ quants
(IQ1_S, IQ1_M, IQ2_XXS, IQ2_XS, IQ2_S, IQ3_XXS, IQ3_S,
IQ4_NL, IQ4_XS) are COHERENCE_ONLY -- graded on coherence,
NEVER token-exactness. An unknown quant label is REFUSED
by the canonical lookup (its T1), never defaulted, and
that refusal propagates out of this battery unchanged.

WHY EVERY ROW FILES NOT_GRADED (the honest Qwen state):
the banked teacher-forcing records (A-045 / A-109) cover
the llama architecture ONLY. The A-114 runner carries
llama, gemma4 and mistral3 as arch axes and no qwen axis
at all, because no Qwen records exist to grade: A-048's
fixture inventory filed that NO real Qwen GGUF weight
fixture exists in the repo (the one real fixture is
stories260K, llama), and its Qwen rows are synthetic
stories-tensor smokes, explicitly NOT oracle-graded.
Llama records are another architecture's records: a
comparator must be the same architecture (A-048's
grading note), so extrapolating llama verdicts onto Qwen
rows would fabricate a comparison that never ran. The
judgment this battery files is therefore the named,
reasoned NOT_GRADED for every row -- a verdict, not an
omission -- with the obligation each row WILL be graded
under still filed per row, and the retiring condition
named below.

THE VERDICT RULE, PRE-REGISTERED (stated here before any
test in tests/test_qwen_battery_a119.mojo was run). For
one row (quant, backend), arch fixed to qwen, the row
files the A-114 cell verdict for (quant, qwen, backend),
whose rule order gives, in order:
  (Q1) backend != cpu -> NOT_GRADED, reason
       BACKEND_NO_CPU_COMPARATOR (A-114 R1), obligation
       still filed per the canonical policy. Grading is
       CPU engine vs CPU comparator only; this battery
       files no device-execution evidence for vulkan /
       hip / npu, and accelerator-visible is NOT
       accelerator-run, so the row is not graded -- never
       passed, never failed.
  (Q2) backend == cpu -> NOT_GRADED, reason
       NO_FILED_RECORDS (A-114 R2: arch != llama). No
       filed teacher-forcing records exist for the qwen
       architecture on any quant, measured or IQ.
  (Q3) IQ PRECEDENCE, pinned explicitly: A-114's R2 fires
       BEFORE its R3 (IQ fixture limitation), so a Qwen
       IQ cpu row files NOT_GRADED, never FIXTURE_LIMITED.
       FIXTURE_LIMITED is a llama-fixture verdict (the
       stories260K fixture cannot satisfy the 256-value
       IQ super-block by construction); filing it for
       Qwen would imply a measured Qwen fixture limit
       that does not exist. The accounts agree a second
       way: under the canonical A-115 gate an IQ row with
       no coherence evidence stated files NOT_GRADED
       (its T5) -- and no Qwen coherence evidence is
       filed either.
Filed battery on the banked records: total 76, faithful
0, near_tie 0, divergent 0, artifact 0, fixture_limited
0, not_graded 76 (57 BACKEND_NO_CPU_COMPARATOR + 19
NO_FILED_RECORDS); policy: owed 40 rows (10 quants x 4
backends), coherence 36 rows (9 x 4). Zero unexplained.

THE QWEN FAMILY, AS ATTESTED IN THE TREE (data, not
grading evidence): the family's GGUF architecture strings
are qwen2, qwen3 and qwen35 (loader / registry strings,
per A-048). A-048's filed smoke account over synthetic
stories-tensor fixtures: qwen2 SMOKE_PASS_SYNTHETIC and
qwen3 SMOKE_PASS_SYNTHETIC (load + forward + greedy
completion, all IDs in vocab; explicitly not
oracle-graded), qwen35 LOAD_FAIL_NAMED_CAUSE ("GGUF
qwen35 SSM metadata is incomplete" -- the hybrid
Gated-DeltaNet SSM validator needs metadata and tensors
no fixture in the repo can supply). Smoke is load
evidence, never grading evidence: no row verdict in this
battery rests on it, and it is filed here only so the
family's attested state travels with its battery.

WHAT RETIRES NO_FILED_RECORDS (named, owed): filed
teacher-forcing records for a Qwen architecture -- a real
sha-pinned Qwen GGUF fixture (A-110 pins), raw prompts
from the A-113 golden corpus, graded by the A-109 harness
under the canonical A-115 policy -- after which this
battery's cpu rows take the graded verdicts those records
state and A-135 (Part V gate) re-verdicts the matrix.
Until then every Qwen row is owed, not graded.

RAW-ORACLE DISCIPLINE (standing): grading, when records
exist, rests on teacher-forcing rank + logit gap on RAW
prompts, CPU engine vs CPU comparator only, near-tie band
rank <= 2 with sub-logit gap = faithful, IQ graded on
coherence never token-exactness, comparator artifacts are
a verdict class. The battery executes no model, opens no
device, and claims no speed and no accelerator execution:
pure enumeration over banked, filed records. The bench
driver (tests/bench_qwen_battery_a119.mojo) emits the
full battery on the Z13 in one command; its log is the
acceptance evidence.
"""

from core.exactness_policy import (
    POLICY_COHERENCE_ONLY,
    POLICY_TOKEN_EXACTNESS_OWED,
    policy_for_quant,
)
from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_FAITHFUL_NEAR_TIE,
    MX_FIXTURE_LIMITED,
    MX_NOT_GRADED,
    cell_verdict,
    matrix_quants,
    matrix_verdict_name,
    mx_fnv1a64,
)
from core.teacher_forcing_harness import tf_harness_backends

comptime QB_ARCH = "qwen"
comptime QB_GRADED_BACKEND = "cpu"
comptime QB_TOKEN_EXACTNESS_OWED = 0
comptime QB_COHERENCE_ONLY = 1


def qwen_battery_quants() -> List[String]:
    return matrix_quants()


def qwen_battery_backends() -> List[String]:
    return tf_harness_backends()


def qwen_arch_strings() -> List[String]:
    """The Qwen family's GGUF architecture strings as
    attested in the tree (A-048: the Qwen strings in the
    loader and registry). Filed as data; the battery's
    arch axis is the family label QB_ARCH."""
    var a = List[String]()
    a.append(String("qwen2"))
    a.append(String("qwen3"))
    a.append(String("qwen35"))
    return a^


def qwen_smoke_status(arch: String) -> String:
    """A-048's filed smoke account for one Qwen arch
    string, over synthetic stories-tensor fixtures:
    load/smoke evidence only, never a grading verdict.
    An arch string A-048 did not row files
    NO_FILED_SMOKE_ROW, never a defaulted pass."""
    if arch == String("qwen2") or arch == String("qwen3"):
        return String("SMOKE_PASS_SYNTHETIC")
    if arch == String("qwen35"):
        return String("LOAD_FAIL_NAMED_CAUSE")
    return String("NO_FILED_SMOKE_ROW")


def qwen_policy_obligation(quant: String) raises -> Int:
    """The row's obligation from the CANONICAL A-115
    policy (policy_for_quant, called): its codes are
    value-for-value this module's QB_ codes (pinned by
    qwen_policy_codes_match_a115). An unknown label is
    refused by the canonical lookup, never defaulted."""
    var row = policy_for_quant(quant)
    return row.obligation


def qwen_policy_obligation_name(obligation: Int) -> String:
    if obligation == QB_COHERENCE_ONLY:
        return String("COHERENCE_ONLY")
    return String("TOKEN_EXACTNESS_OWED")


def qwen_policy_codes_match_a115() -> Bool:
    """True iff this module's obligation codes are
    value-for-value the canonical A-115 policy's, so
    filings from both accounts read alike."""
    return (
        QB_TOKEN_EXACTNESS_OWED == POLICY_TOKEN_EXACTNESS_OWED
        and QB_COHERENCE_ONLY == POLICY_COHERENCE_ONLY
    )


struct QwenBatteryRow(Copyable, ImplicitlyCopyable):
    var quant: String
    var backend: String
    var verdict: Int
    var reason: String
    var obligation: Int
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var worst_rank: Int

    def __init__(
        out self,
        quant: String,
        backend: String,
        verdict: Int,
        reason: String,
        obligation: Int,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        worst_rank: Int,
    ):
        self.quant = quant
        self.backend = backend
        self.verdict = verdict
        self.reason = reason
        self.obligation = obligation
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.worst_rank = worst_rank


struct QwenBatteryReport(Copyable, Movable):
    var rows: List[QwenBatteryRow]
    var total: Int
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var artifact: Int
    var fixture_limited: Int
    var not_graded: Int
    var not_graded_backend: Int
    var not_graded_no_records: Int
    var owed: Int
    var coherence: Int
    var digest: UInt64

    def __init__(
        out self,
        rows: List[QwenBatteryRow],
        total: Int,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        artifact: Int,
        fixture_limited: Int,
        not_graded: Int,
        not_graded_backend: Int,
        not_graded_no_records: Int,
        owed: Int,
        coherence: Int,
        digest: UInt64,
    ):
        self.rows = rows.copy()
        self.total = total
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.artifact = artifact
        self.fixture_limited = fixture_limited
        self.not_graded = not_graded
        self.not_graded_backend = not_graded_backend
        self.not_graded_no_records = not_graded_no_records
        self.owed = owed
        self.coherence = coherence
        self.digest = digest


def _check_qwen_battery_axis(axis: List[String], axis_name: String) raises:
    if len(axis) == 0:
        raise Error("QwenBattery: " + axis_name + " axis is empty")
    for i in range(len(axis)):
        for j in range(i + 1, len(axis)):
            if axis[i] == axis[j]:
                raise Error(
                    "QwenBattery: duplicate " + axis_name + " entry " + axis[i]
                )


def qwen_battery_row_verdict(
    quant: String, backend: String
) raises -> QwenBatteryRow:
    """One row: the obligation from the canonical A-115
    policy (an unknown quant is refused there, never
    defaulted here), and the verdict exactly as the
    A-114 runner files it for (quant, qwen, backend) --
    Q1/Q2/Q3 fall out of that runner's pre-registered
    rule order, so battery and matrix cannot drift."""
    var obligation = qwen_policy_obligation(quant)
    var cell = cell_verdict(quant, String(QB_ARCH), backend)
    return QwenBatteryRow(
        quant, backend, cell.verdict, cell.reason, obligation,
        cell.faithful, cell.near_tie, cell.divergent, cell.worst_rank,
    )


def build_qwen_battery(
    quants: List[String], backends: List[String]
) raises -> List[QwenBatteryRow]:
    _check_qwen_battery_axis(quants, "quant")
    _check_qwen_battery_axis(backends, "backend")
    var rows = List[QwenBatteryRow]()
    for qi in range(len(quants)):
        for bi in range(len(backends)):
            rows.append(qwen_battery_row_verdict(quants[qi], backends[bi]))
    return rows^


def run_qwen_battery() raises -> QwenBatteryReport:
    var rows = build_qwen_battery(qwen_battery_quants(), qwen_battery_backends())
    var faithful = 0
    var near_tie = 0
    var divergent = 0
    var artifact = 0
    var fixture_limited = 0
    var not_graded = 0
    var not_graded_backend = 0
    var not_graded_no_records = 0
    var owed = 0
    var coherence = 0
    for i in range(len(rows)):
        var v = rows[i].verdict
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
            if rows[i].reason == String("BACKEND_NO_CPU_COMPARATOR"):
                not_graded_backend += 1
            elif rows[i].reason == String("NO_FILED_RECORDS"):
                not_graded_no_records += 1
        if rows[i].obligation == QB_COHERENCE_ONLY:
            coherence += 1
        else:
            owed += 1
    var report = QwenBatteryReport(
        rows.copy(), len(rows), faithful, near_tie, divergent,
        artifact, fixture_limited, not_graded, not_graded_backend,
        not_graded_no_records, owed, coherence, UInt64(0),
    )
    report.digest = mx_fnv1a64(qwen_battery_render(report.copy()))
    return report^


def qwen_battery_row_line(row: QwenBatteryRow) -> String:
    var s = String("QB_ROW quant=") + row.quant
    s += String(" arch=") + String(QB_ARCH)
    s += String(" backend=") + row.backend
    s += String(" verdict=") + matrix_verdict_name(row.verdict)
    s += String(" reason=") + row.reason
    s += String(" policy=") + qwen_policy_obligation_name(row.obligation)
    s += String(" faithful=") + String(row.faithful)
    s += String(" near_tie=") + String(row.near_tie)
    s += String(" divergent=") + String(row.divergent)
    s += String(" worst_rank=") + String(row.worst_rank)
    return s


def qwen_battery_render(read report: QwenBatteryReport) -> String:
    var s = String("A119_BATTERY quants=")
    s += String(len(qwen_battery_quants()))
    s += String(" backends=") + String(len(qwen_battery_backends()))
    s += String(" total=") + String(report.total) + String("\n")
    for i in range(len(report.rows)):
        s += qwen_battery_row_line(report.rows[i]) + String("\n")
    s += String("A119_BATTERY_SUMMARY total=") + String(report.total)
    s += String(" faithful=") + String(report.faithful)
    s += String(" near_tie=") + String(report.near_tie)
    s += String(" divergent=") + String(report.divergent)
    s += String(" artifact=") + String(report.artifact)
    s += String(" fixture_limited=") + String(report.fixture_limited)
    s += String(" not_graded=") + String(report.not_graded)
    s += String(" not_graded_backend=") + String(report.not_graded_backend)
    s += String(" not_graded_no_records=") + String(report.not_graded_no_records)
    s += String(" owed=") + String(report.owed)
    s += String(" coherence=") + String(report.coherence)
    return s


def qwen_battery_line() -> String:
    return String(
        "A-119 qwen-family battery: 19 quants x 4 Z13"
        " backends, rows judged per the canonical A-115"
        " policy (10 quants TOKEN_EXACTNESS_OWED under the"
        " A-111 near-tie gate, 9 IQ quants COHERENCE_ONLY);"
        " no qwen teacher-forcing records are filed, so"
        " every row files NOT_GRADED with a named reason,"
        " zero unexplained"
    )
