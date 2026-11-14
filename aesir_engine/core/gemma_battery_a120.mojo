"""A-120: Gemma-family battery -- the gemma4
architecture rows of the full matrix, on all Z13
backends, judged per the A-115 token-exactness policy
(Wave 14, Architecture breadth).

The roadmap text: "Gemma-family battery. Acceptance:
rows judged (the existing CUDA Gemma work is the
comparator reference where relevant -- CPU engine vs
CPU comparator rule still governs grading)."

This battery is the gemma4 slice of the banked A-114
full matrix runner (core/matrix_runner.mojo): the 19
quant rows of the A-045 / A-109 axis laid across the
gemma4 architecture and all four Z13 backends (exactly
A-109's tf_harness_backends: cpu, vulkan, hip, npu) =
76 rows, every row with a verdict and a policy
obligation, zero unexplained. Rows are NOT re-derived
here: each cpu row files exactly the verdict the A-114
runner files for its (quant, gemma4, cpu) cell, so the
battery and the matrix cannot drift apart.

THE HONEST GEMMA FACT (why every row is NOT_GRADED):
the only filed teacher-forcing records in the banked
tree are llama-arch (A-045 / A-109, stories260K +
Meta-Llama-3.1-8B). A-114's rule R2 files every non-
llama arch NOT_GRADED with reason NO_FILED_RECORDS:
gemma4 rows are owed when records exist, not
extrapolated from llama. A-048's load matrix confirms
the fixture position from the other side: NO real
Gemma GGUF weight fixture exists in the repo or on
purpleraider (only tokenizer-parity text fixtures and
synthetic metadata-rewritten rows, honestly labelled,
never oracle-graded), and the Modelfile-referenced
gemma-4-E2B-it-Q4_K_M.gguf is not present on the
machine. A battery that graded gemma rows from llama
records would forge the exact evidence it exists to
file, so this battery files the owed state instead.

THE CUDA GEMMA REFERENCE, NAMED AND BOUNDED: the
existing CUDA Gemma work (core/gemma4_cuda.mojo --
full dense text-only Gemma 4 E4B Q4_K_M on the CUDA
profile) is the comparator reference where relevant,
exactly as the roadmap states, and no further: it is
CUDA device work, not a CPU comparator, it files no
teacher-forcing rank / logit-gap records on RAW
prompts, and the standing rule (CPU engine vs CPU
comparator only) therefore grades NO row from it.
It executes on a different hardware line than this
Z13 campaign and this battery files no device-
execution evidence from it and claims no accelerator
execution of any kind.

THE A-115 POLICY (canonical, banked): unlike A-118,
which mirrored the policy as data while A-115 was
unbanked, A-115 HAS banked (core/
exactness_policy.mojo). This battery's obligation
split is the same split (10 measured quants
TOKEN_EXACTNESS_OWED under the A-111 near-tie gate,
9 IQ quants COHERENCE_ONLY), and the suite proves it
agrees with the canonical policy_for_quant for every
quant on the axis, value-for-value -- a disagreement
files loudly, never silently. Integration point:
exactness_policy.mojo is canonical; this module's
obligation helper is a filing convenience only.
  IQ NOTE: on llama, an IQ cpu row files
  FIXTURE_LIMITED (the A-045 fixture limitation). On
  gemma4 that verdict does NOT transfer: A-114 checks
  the architecture before the IQ family, so a gemma4
  IQ cpu row files NOT_GRADED / NO_FILED_RECORDS like
  every other gemma4 cpu row. The IQ obligation is
  still COHERENCE_ONLY on every row.

THE VERDICT RULE, PRE-REGISTERED (stated here before
any test in tests/test_gemma_battery_a120.mojo was
run). For one row (quant, backend), arch fixed to
gemma4, in order:
  (G1) backend != cpu -> NOT_GRADED, reason
       BACKEND_NO_CPU_COMPARATOR, obligation still
       filed per the policy. Grading is CPU engine vs
       CPU comparator only; this battery files no
       device-execution evidence for vulkan / hip /
       npu, and accelerator-visible is NOT
       accelerator-run, so the row is not graded --
       never passed, never failed.
  (G2) backend == cpu -> the A-114 cell verdict for
       (quant, gemma4, cpu), which is NOT_GRADED with
       reason NO_FILED_RECORDS for every quant on the
       axis today (measured and IQ alike), obligation
       per the policy.
Filed battery on the banked records: NOT_GRADED 76
(cpu 19 NO_FILED_RECORDS + non-cpu 57
BACKEND_NO_CPU_COMPARATOR); faithful 0, near_tie 0,
divergent 0, artifact 0, fixture_limited 0; policy:
owed 40 rows (10 quants x 4 backends), coherence 36
rows (9 x 4). Zero unexplained.

A-116 CARRIED CONDITION: A-116's acceptance requires
its divergence localiser be used in anger at least
once in Wave 14 or the slice re-opens. This battery
produces NO genuinely divergent row (every row is
honestly NOT_GRADED), so there is no row this slice
may legitimately file with A-116 -- filing the seeded
demonstration again would not be use in anger, and
no divergent verdict is manufactured here to create
one. The condition therefore remains carried and is
named in hidden_files/A120_LEDGER.md: the first Wave
14 battery that files a genuine DIVERGENT row owes
A-116 its first real filing.

A-119 INTEGRATION POINT (honest, named): A-119
(Qwen-family battery, team-25) is building in
parallel and has NOT banked. This battery takes NO
dependency on it. The two batteries share only banked
surfaces (A-114's runner, A-115's policy); when A-119
banks, the family batteries reconcile at the seat
union with no code change owed here.

RAW-ORACLE DISCIPLINE (standing): grading in this
tree rests on teacher-forcing rank + logit gap on RAW
prompts, CPU engine vs CPU comparator only, rows
pinned per A-110, band per A-111, artifacts per
A-112. The battery executes no model, opens no
device, and claims no speed and no accelerator
execution: pure enumeration over banked, filed
records. The bench driver
(tests/bench_gemma_battery_a120.mojo) emits the full
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

comptime GB_ARCH = "gemma4"
comptime GB_GRADED_BACKEND = "cpu"
comptime GB_TOKEN_EXACTNESS_OWED = 0
comptime GB_COHERENCE_ONLY = 1


def gemma_battery_quants() -> List[String]:
    return matrix_quants()


def gemma_battery_backends() -> List[String]:
    return tf_harness_backends()


def gemma_policy_obligation(quant: String) -> Int:
    if is_iq_quant(quant):
        return GB_COHERENCE_ONLY
    return GB_TOKEN_EXACTNESS_OWED


def gemma_policy_obligation_name(obligation: Int) -> String:
    if obligation == GB_COHERENCE_ONLY:
        return String("COHERENCE_ONLY")
    return String("TOKEN_EXACTNESS_OWED")


def gemma_comparator_reference() -> String:
    return String(
        "gemma4_cuda (CUDA Gemma 4 E4B Q4_K_M) -- reference"
        " only, not a CPU comparator, grades no row"
    )


struct GemmaBatteryRow(Copyable, ImplicitlyCopyable):
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


struct GemmaBatteryReport(Copyable, Movable):
    var rows: List[GemmaBatteryRow]
    var total: Int
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var artifact: Int
    var fixture_limited: Int
    var not_graded: Int
    var cpu_not_graded: Int
    var backend_not_graded: Int
    var owed: Int
    var coherence: Int
    var digest: UInt64

    def __init__(
        out self,
        rows: List[GemmaBatteryRow],
        total: Int,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        artifact: Int,
        fixture_limited: Int,
        not_graded: Int,
        cpu_not_graded: Int,
        backend_not_graded: Int,
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
        self.cpu_not_graded = cpu_not_graded
        self.backend_not_graded = backend_not_graded
        self.owed = owed
        self.coherence = coherence
        self.digest = digest


def _check_gemma_axis(axis: List[String], axis_name: String) raises:
    if len(axis) == 0:
        raise Error("GemmaBattery: " + axis_name + " axis is empty")
    for i in range(len(axis)):
        for j in range(i + 1, len(axis)):
            if axis[i] == axis[j]:
                raise Error(
                    "GemmaBattery: duplicate " + axis_name + " entry " + axis[i]
                )


def gemma_battery_row_verdict(quant: String, backend: String) -> GemmaBatteryRow:
    var obligation = gemma_policy_obligation(quant)
    if backend != String(GB_GRADED_BACKEND):
        return GemmaBatteryRow(
            quant, backend, MX_NOT_GRADED,
            String("BACKEND_NO_CPU_COMPARATOR"), obligation,
            -1, -1, -1, -1,
        )
    var cell = cell_verdict(quant, String(GB_ARCH), backend)
    return GemmaBatteryRow(
        quant, backend, cell.verdict, cell.reason, obligation,
        cell.faithful, cell.near_tie, cell.divergent, cell.worst_rank,
    )


def build_gemma_battery(
    quants: List[String], backends: List[String]
) raises -> List[GemmaBatteryRow]:
    _check_gemma_axis(quants, "quant")
    _check_gemma_axis(backends, "backend")
    var rows = List[GemmaBatteryRow]()
    for qi in range(len(quants)):
        for bi in range(len(backends)):
            rows.append(gemma_battery_row_verdict(quants[qi], backends[bi]))
    return rows^


def run_gemma_battery() raises -> GemmaBatteryReport:
    var rows = build_gemma_battery(gemma_battery_quants(), gemma_battery_backends())
    var faithful = 0
    var near_tie = 0
    var divergent = 0
    var artifact = 0
    var fixture_limited = 0
    var not_graded = 0
    var cpu_not_graded = 0
    var backend_not_graded = 0
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
            if rows[i].backend == String(GB_GRADED_BACKEND):
                cpu_not_graded += 1
            else:
                backend_not_graded += 1
        if rows[i].obligation == GB_COHERENCE_ONLY:
            coherence += 1
        else:
            owed += 1
    var report = GemmaBatteryReport(
        rows.copy(), len(rows), faithful, near_tie, divergent,
        artifact, fixture_limited, not_graded, cpu_not_graded,
        backend_not_graded, owed, coherence, UInt64(0),
    )
    report.digest = mx_fnv1a64(gemma_battery_render(report.copy()))
    return report^


def gemma_battery_row_line(row: GemmaBatteryRow) -> String:
    var s = String("GB_ROW quant=") + row.quant
    s += String(" arch=") + String(GB_ARCH)
    s += String(" backend=") + row.backend
    s += String(" verdict=") + matrix_verdict_name(row.verdict)
    s += String(" reason=") + row.reason
    s += String(" policy=") + gemma_policy_obligation_name(row.obligation)
    s += String(" faithful=") + String(row.faithful)
    s += String(" near_tie=") + String(row.near_tie)
    s += String(" divergent=") + String(row.divergent)
    s += String(" worst_rank=") + String(row.worst_rank)
    return s


def gemma_battery_render(read report: GemmaBatteryReport) -> String:
    var s = String("A120_BATTERY quants=")
    s += String(len(gemma_battery_quants()))
    s += String(" backends=") + String(len(gemma_battery_backends()))
    s += String(" total=") + String(report.total) + String("\n")
    for i in range(len(report.rows)):
        s += gemma_battery_row_line(report.rows[i]) + String("\n")
    s += String("A120_BATTERY_SUMMARY total=") + String(report.total)
    s += String(" faithful=") + String(report.faithful)
    s += String(" near_tie=") + String(report.near_tie)
    s += String(" divergent=") + String(report.divergent)
    s += String(" artifact=") + String(report.artifact)
    s += String(" fixture_limited=") + String(report.fixture_limited)
    s += String(" not_graded=") + String(report.not_graded)
    s += String(" cpu_not_graded=") + String(report.cpu_not_graded)
    s += String(" backend_not_graded=") + String(report.backend_not_graded)
    s += String(" owed=") + String(report.owed)
    s += String(" coherence=") + String(report.coherence)
    return s


def gemma_battery_line() -> String:
    return String(
        "A-120 gemma-family battery: 19 quants x 4 Z13"
        " backends on gemma4, rows judged per the banked"
        " A-115 policy (10 quants TOKEN_EXACTNESS_OWED"
        " under the A-111 near-tie gate, 9 IQ quants"
        " COHERENCE_ONLY); no filed gemma teacher-forcing"
        " records exist, so every row files NOT_GRADED"
        " with a named reason, zero unexplained"
    )
