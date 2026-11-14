"""A-118: Llama-family battery -- the llama architecture
rows of the full matrix, on all Z13 backends, judged per
the A-115 token-exactness policy (Wave 14 opener,
Architecture breadth).

The roadmap text: "Llama-family battery on all Z13
backends. Acceptance: rows judged per A-115 policy."

This battery is the llama slice of the banked A-114 full
matrix runner (core/matrix_runner.mojo): the 19 quant rows
of the A-045 / A-109 llama records (stories260K +
Meta-Llama-3.1-8B fixture family) laid across all four Z13
backends (exactly A-109's tf_harness_backends: cpu,
vulkan, hip, npu) = 76 rows, every row with a verdict and
a policy obligation, zero unexplained. Rows are NOT
re-derived here: each cpu row files exactly the verdict
the A-114 runner files for its (quant, llama, cpu) cell,
so the battery and the matrix cannot drift apart.

THE A-115 POLICY, MIRRORED AS DATA (dependency named):
A-115 (token-exactness policy, team-25) is being finished
in parallel and has NOT banked. This module takes NO
dependency on unbanked code. The policy's on-disk WIP in
team-25 (core/exactness_policy.mojo) states the rule this
battery mirrors as data, and the integration point is
explicit: when A-115 banks, core/exactness_policy.mojo
becomes the canonical encoding and this mirror must agree
with it value-for-value (the suite pins the counts below
so a disagreement files loudly, never silently):
  (P1) TOKEN_EXACTNESS_OWED -- the ten measured quants
       (F16, BF16, Q8_0, Q4_0, Q5_0, Q2_K, Q3_K_M, Q4_K_M,
       Q5_K_M, Q6_K): judged by teacher-forcing rank +
       logit gap on RAW prompts under the A-111 near-tie
       gate (rank <= 2 AND gap < 1 logit = faithful).
  (P2) COHERENCE_ONLY -- the nine IQ quants (IQ1_S,
       IQ1_M, IQ2_XXS, IQ2_XS, IQ2_S, IQ3_XXS, IQ3_S,
       IQ4_NL, IQ4_XS): graded on coherence, NEVER
       token-exactness. This battery files no coherence
       evidence, so the honest verdict is FIXTURE_LIMITED
       (the A-045 fixture cannot satisfy the 256-value IQ
       super-block by construction), exactly as A-114.
A-116 (first-divergence localisation, team-26) is likewise
unbanked and not depended on; when it banks it is the tool
the keeper runs on this battery's DIVERGENT rows.

THE VERDICT RULE, PRE-REGISTERED (stated here before any
test in tests/test_llama_battery_a118.mojo was run). For
one row (quant, backend), arch fixed to llama, in order:
  (B1) backend != cpu -> NOT_GRADED, reason
       BACKEND_NO_CPU_COMPARATOR, obligation still filed
       per P1/P2. Grading is CPU engine vs CPU comparator
       only; this battery files no device-execution
       evidence for vulkan / hip / npu, and accelerator-
       visible is NOT accelerator-run, so the row is not
       graded -- never passed, never failed.
  (B2) quant in the IQ family -> FIXTURE_LIMITED, reason
       IQ_FIXTURE_LIMITED, obligation COHERENCE_ONLY.
  (B3) a measured row -> the A-114 cell verdict for
       (quant, llama, cpu), obligation
       TOKEN_EXACTNESS_OWED: FAITHFUL /
       FAITHFUL_NEAR_TIE / DIVERGENT /
       COMPARATOR_ARTIFACT (the standing verdict class,
       precedence as in the A-111 gate).
Filed battery on the banked records: cpu rows FAITHFUL 4
(F16, BF16, Q8_0, Q5_K_M), FAITHFUL_NEAR_TIE 2 (Q5_0,
Q4_K_M), DIVERGENT 2 (Q4_0, Q3_K_M), COMPARATOR_ARTIFACT 2
(Q2_K, Q6_K), FIXTURE_LIMITED 9 (IQ); non-cpu 57 rows
NOT_GRADED. Summary: total 76, faithful 4, near_tie 2,
divergent 2, artifact 2, fixture_limited 9, not_graded 57;
policy: owed 40 rows (10 quants x 4 backends), coherence
36 rows (9 x 4).

RAW-ORACLE DISCIPLINE (standing): every graded row rests
on teacher-forcing rank + logit gap on RAW prompts, CPU
engine vs CPU comparator only, rows pinned per A-110.
The battery executes no model, opens no device, and
claims no speed and no accelerator execution: pure
enumeration over banked, filed records. The bench driver
(tests/bench_llama_battery_a118.mojo) emits the full
battery on the Z13 in one command; its log is the
acceptance evidence.
"""

from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_FAITHFUL_NEAR_TIE,
    MX_FIXTURE_LIMITED,
    MX_NOT_GRADED,
    cell_verdict,
    is_iq_quant,
    matrix_quants,
    matrix_verdict_name,
    mx_fnv1a64,
)
from core.teacher_forcing_harness import tf_harness_backends

comptime LB_ARCH = "llama"
comptime LB_GRADED_BACKEND = "cpu"
comptime LB_TOKEN_EXACTNESS_OWED = 0
comptime LB_COHERENCE_ONLY = 1


def battery_quants() -> List[String]:
    return matrix_quants()


def battery_backends() -> List[String]:
    return tf_harness_backends()


def policy_obligation(quant: String) -> Int:
    if is_iq_quant(quant):
        return LB_COHERENCE_ONLY
    return LB_TOKEN_EXACTNESS_OWED


def policy_obligation_name(obligation: Int) -> String:
    if obligation == LB_COHERENCE_ONLY:
        return String("COHERENCE_ONLY")
    return String("TOKEN_EXACTNESS_OWED")


struct BatteryRow(Copyable, ImplicitlyCopyable):
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


struct BatteryReport(Copyable, Movable):
    var rows: List[BatteryRow]
    var total: Int
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var artifact: Int
    var fixture_limited: Int
    var not_graded: Int
    var owed: Int
    var coherence: Int
    var digest: UInt64

    def __init__(
        out self,
        rows: List[BatteryRow],
        total: Int,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        artifact: Int,
        fixture_limited: Int,
        not_graded: Int,
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
        self.owed = owed
        self.coherence = coherence
        self.digest = digest


def _check_battery_axis(axis: List[String], axis_name: String) raises:
    if len(axis) == 0:
        raise Error("LlamaBattery: " + axis_name + " axis is empty")
    for i in range(len(axis)):
        for j in range(i + 1, len(axis)):
            if axis[i] == axis[j]:
                raise Error(
                    "LlamaBattery: duplicate " + axis_name + " entry " + axis[i]
                )


def battery_row_verdict(quant: String, backend: String) -> BatteryRow:
    var obligation = policy_obligation(quant)
    if backend != String(LB_GRADED_BACKEND):
        return BatteryRow(
            quant, backend, MX_NOT_GRADED,
            String("BACKEND_NO_CPU_COMPARATOR"), obligation,
            -1, -1, -1, -1,
        )
    var cell = cell_verdict(quant, String(LB_ARCH), backend)
    return BatteryRow(
        quant, backend, cell.verdict, cell.reason, obligation,
        cell.faithful, cell.near_tie, cell.divergent, cell.worst_rank,
    )


def build_battery(
    quants: List[String], backends: List[String]
) raises -> List[BatteryRow]:
    _check_battery_axis(quants, "quant")
    _check_battery_axis(backends, "backend")
    var rows = List[BatteryRow]()
    for qi in range(len(quants)):
        for bi in range(len(backends)):
            rows.append(battery_row_verdict(quants[qi], backends[bi]))
    return rows^


def run_battery() raises -> BatteryReport:
    var rows = build_battery(battery_quants(), battery_backends())
    var faithful = 0
    var near_tie = 0
    var divergent = 0
    var artifact = 0
    var fixture_limited = 0
    var not_graded = 0
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
        if rows[i].obligation == LB_COHERENCE_ONLY:
            coherence += 1
        else:
            owed += 1
    var report = BatteryReport(
        rows.copy(), len(rows), faithful, near_tie, divergent,
        artifact, fixture_limited, not_graded, owed, coherence,
        UInt64(0),
    )
    report.digest = mx_fnv1a64(battery_render(report.copy()))
    return report^


def battery_row_line(row: BatteryRow) -> String:
    var s = String("LB_ROW quant=") + row.quant
    s += String(" arch=") + String(LB_ARCH)
    s += String(" backend=") + row.backend
    s += String(" verdict=") + matrix_verdict_name(row.verdict)
    s += String(" reason=") + row.reason
    s += String(" policy=") + policy_obligation_name(row.obligation)
    s += String(" faithful=") + String(row.faithful)
    s += String(" near_tie=") + String(row.near_tie)
    s += String(" divergent=") + String(row.divergent)
    s += String(" worst_rank=") + String(row.worst_rank)
    return s


def battery_render(read report: BatteryReport) -> String:
    var s = String("A118_BATTERY quants=")
    s += String(len(battery_quants()))
    s += String(" backends=") + String(len(battery_backends()))
    s += String(" total=") + String(report.total) + String("\n")
    for i in range(len(report.rows)):
        s += battery_row_line(report.rows[i]) + String("\n")
    s += String("A118_BATTERY_SUMMARY total=") + String(report.total)
    s += String(" faithful=") + String(report.faithful)
    s += String(" near_tie=") + String(report.near_tie)
    s += String(" divergent=") + String(report.divergent)
    s += String(" artifact=") + String(report.artifact)
    s += String(" fixture_limited=") + String(report.fixture_limited)
    s += String(" not_graded=") + String(report.not_graded)
    s += String(" owed=") + String(report.owed)
    s += String(" coherence=") + String(report.coherence)
    return s


def battery_line() -> String:
    return String(
        "A-118 llama-family battery: 19 quants x 4 Z13"
        " backends, rows judged per the A-115 policy mirror"
        " (10 quants TOKEN_EXACTNESS_OWED under the A-111"
        " near-tie gate, 9 IQ quants COHERENCE_ONLY);"
        " non-cpu rows NOT_GRADED with a named reason, IQ"
        " rows FIXTURE_LIMITED, zero unexplained"
    )
