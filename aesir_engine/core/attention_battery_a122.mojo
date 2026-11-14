"""A-122: Attention variants -- GQA and MLA-style
variants parity, per-variant rows judged (Wave 14,
Architecture breadth).

The roadmap text: "Attention variants. GQA and
MLA-style variants parity. Acceptance: per-variant
rows judged."

This battery lays the banked A-114 full matrix runner
(core/matrix_runner.mojo) across the ATTENTION VARIANT
axis -- the one axis the matrix itself does not carry.
Variants (4), in filed order: MHA (kv_heads ==
query_heads), GQA (1 < kv_heads < query_heads), MQA
(kv_heads == 1), MLA (multi-head latent attention,
DeepSeek-style latent-compressed KV). Crossed with the
19-quant axis (matrix_quants(), called, never
re-typed) and the 4 Z13 backends (exactly A-109's
tf_harness_backends: cpu, vulkan, hip, npu, called,
never re-typed) = 4 x 19 x 4 = 304 rows, every row
with a verdict and the A-115 policy obligation read
from the banked core/exactness_policy.mojo BY CALL
(policy_for_quant; unknown labels refused by the
canonical lookup, never defaulted), zero unexplained.

WHY GQA IS THE ONLY GRADED VARIANT (the filed
evidence, stated before any verdict): the banked
teacher-forcing records (A-045 / A-109, filed as data
in core/teacher_forcing_harness.mojo) were produced by
the pinned inference path whose attention IS the GQA
kernel -- core/compute.mojo flash_attention_gqa, which
maps query heads onto fewer KV heads (AES-CPU-004:
8 query heads to 4 KV heads, E-REAL oracle parity,
verified) and through which core/inference.mojo routes
every attention call, KV-head count taken from the
GGUF config (attention.head_count_kv). The A-114 llama
cells are therefore the GQA-variant rows of the
matrix, and this battery files exactly those verdicts
for GQA -- the battery and the matrix cannot drift
apart (the suite proves cell-for-cell agreement).

THE OTHER VARIANTS, HONESTLY:
  MHA -- a filed GEOMETRY exists (OLMoE 16/16 heads in
    docs/janas/J015_MOE_ANATOMY.md), but OLMoE's filed
    evidence is expert ROUTING (J-016, judged at
    A-121), not teacher-forcing rank / logit-gap
    records; no MHA-geometry TF record is filed.
  MQA -- no filed fixture, geometry, or TF record
    anywhere in the banked tree.
  MLA -- NO implementation and NO record anywhere in
    the banked tree: the string MLA / latent appears
    in no core module (grep-verified at build time);
    there is no latent-KV projection, no absorbed
    attention path, nothing to grade against.
Grading any of these from the GQA records would
extrapolate evidence across attention architectures
-- exactly what A-119 / A-120 refused across model
architectures. Their rows file NOT_GRADED with the
named reason instead. A variant's NOT_GRADED retires
only with filed teacher-forcing records on a real
sha-pinned fixture OF THAT VARIANT (A-110 pins,
A-113 corpus, A-109 harness), re-verdicted at A-135.

THE VERDICT RULE, PRE-REGISTERED (stated here before
any test in tests/test_attention_battery_a122.mojo
was run). For one row (variant, quant, backend), in
order:
  (V1) backend != cpu -> NOT_GRADED, reason
       BACKEND_NO_CPU_COMPARATOR, obligation still
       filed per the policy. Grading is CPU engine vs
       CPU comparator only; this battery files no
       device-execution evidence for vulkan / hip /
       npu, and accelerator-visible is NOT
       accelerator-run.
  (V2) variant != GQA -> NOT_GRADED, reason
       NO_FILED_RECORDS (cpu rows). No per-variant
       teacher-forcing records exist for MHA / MQA /
       MLA (see above); the variant check precedes
       the IQ family exactly as A-114's R2 (arch)
       precedes R3 (IQ), so an IQ row of an ungraded
       variant files NOT_GRADED, never FIXTURE_LIMITED
       -- FIXTURE_LIMITED is a GQA-fixture verdict.
  (V3) variant == GQA, backend == cpu -> the A-114
       cell verdict for (quant, llama, cpu), filed
       verbatim (verdict, reason, position counts).
Filed battery on the banked records: total 304;
GQA cpu 19 rows = FAITHFUL 4 (F16, BF16, Q8_0,
Q5_K_M), FAITHFUL_NEAR_TIE 2 (Q5_0, Q4_K_M),
DIVERGENT 2 (Q4_0, Q3_K_M -- the A-045 filed
divergence-quant-noise verdicts, carried by
delegation exactly as A-114 / A-118 file them, not
new divergences), COMPARATOR_ARTIFACT 2 (Q2_K, Q6_K
-- A-045 filed fixture-artifacts), FIXTURE_LIMITED 9
(the IQ family); NOT_GRADED 285 (228
BACKEND_NO_CPU_COMPARATOR + 57 NO_FILED_RECORDS);
policy: owed 160 rows (10 quants x 16), coherence
144 rows (9 x 16). Zero unexplained.

A-116 NOTE: A-116's acceptance requires its
divergence localiser be used in anger at least once
in Wave 14 or the slice re-opens. The two DIVERGENT
rows here are the banked A-045 verdicts themselves,
already classified in A-045 (divergence-quant-noise)
and filed identically by A-114 and A-118; this
battery discovers NO new divergence and manufactures
none. A-116 remains the named tool for any genuinely
new divergent row; the in-anger condition is not
claimed met by inherited rows.

RAW-ORACLE DISCIPLINE (standing): grading in this
tree rests on teacher-forcing rank + logit gap on RAW
prompts, CPU engine vs CPU comparator only, rows
pinned per A-110, band per A-111, artifacts per
A-112. The battery executes no model, opens no
device, and claims no speed and no accelerator
execution: pure enumeration over banked, filed
records. The bench driver
(tests/bench_attention_battery_a122.mojo) emits the
full battery on the Z13 in one command; its log is
the acceptance evidence.
"""

from core.exactness_policy import (
    POLICY_COHERENCE_ONLY,
    POLICY_TOKEN_EXACTNESS_OWED,
    obligation_name,
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

comptime AV_GRADED_VARIANT = "GQA"
comptime AV_GRADED_ARCH = "llama"
comptime AV_GRADED_BACKEND = "cpu"


def attention_variants() -> List[String]:
    """The 4 attention-variant axis entries, in filed
    order: MHA, GQA, MQA, MLA (see the header for the
    geometry of each and the evidence filed for it)."""
    var v = List[String]()
    v.append(String("MHA"))
    v.append(String("GQA"))
    v.append(String("MQA"))
    v.append(String("MLA"))
    return v^


def attention_battery_quants() -> List[String]:
    return matrix_quants()


def attention_battery_backends() -> List[String]:
    return tf_harness_backends()


def variant_geometry(variant: String) -> String:
    if variant == String("MHA"):
        return String("kv_heads == query_heads (group 1)")
    if variant == String("GQA"):
        return String("1 < kv_heads < query_heads (grouped)")
    if variant == String("MQA"):
        return String("kv_heads == 1 (single shared KV head)")
    if variant == String("MLA"):
        return String("latent-compressed KV (DeepSeek-style)")
    return String("UNKNOWN_VARIANT")


def variant_evidence(variant: String) -> String:
    """The filed evidence position of one variant, as
    data: what the banked tree actually holds for it."""
    if variant == String("GQA"):
        return String(
            "GRADED: A-045/A-109 teacher-forcing records via"
            " flash_attention_gqa (AES-CPU-004 8Q/4KV E-REAL"
            " parity; A-043/A-084 GQA kernels 24Q/8KV filed)"
        )
    if variant == String("MHA"):
        return String(
            "NO_FILED_RECORDS: geometry filed (OLMoE 16/16,"
            " J-015) but its evidence is routing (J-016/A-121),"
            " not teacher-forcing rank/gap"
        )
    if variant == String("MQA"):
        return String(
            "NO_FILED_RECORDS: no MQA fixture, geometry, or"
            " teacher-forcing record filed in the tree"
        )
    if variant == String("MLA"):
        return String(
            "NO_FILED_RECORDS: no MLA implementation or record"
            " exists in the banked tree (no latent-KV path)"
        )
    return String("UNKNOWN_VARIANT")


def attention_policy_obligation(quant: String) raises -> Int:
    """The A-115 obligation of one quant, read from the
    banked canonical policy BY CALL (policy_for_quant).
    Unknown labels are refused by that lookup."""
    var row = policy_for_quant(quant)
    return row.obligation


struct AttentionBatteryRow(Copyable, ImplicitlyCopyable):
    var variant: String
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
        variant: String,
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
        self.variant = variant
        self.quant = quant
        self.backend = backend
        self.verdict = verdict
        self.reason = reason
        self.obligation = obligation
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.worst_rank = worst_rank


struct AttentionBatteryReport(Copyable, Movable):
    var rows: List[AttentionBatteryRow]
    var total: Int
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var artifact: Int
    var fixture_limited: Int
    var not_graded: Int
    var backend_not_graded: Int
    var variant_not_graded: Int
    var owed: Int
    var coherence: Int
    var digest: UInt64

    def __init__(
        out self,
        rows: List[AttentionBatteryRow],
        total: Int,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        artifact: Int,
        fixture_limited: Int,
        not_graded: Int,
        backend_not_graded: Int,
        variant_not_graded: Int,
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
        self.backend_not_graded = backend_not_graded
        self.variant_not_graded = variant_not_graded
        self.owed = owed
        self.coherence = coherence
        self.digest = digest


def _check_axis(axis: List[String], axis_name: String) raises:
    if len(axis) == 0:
        raise Error("AttentionBattery: " + axis_name + " axis is empty")
    for i in range(len(axis)):
        for j in range(i + 1, len(axis)):
            if axis[i] == axis[j]:
                raise Error(
                    "AttentionBattery: duplicate "
                    + axis_name
                    + " entry "
                    + axis[i]
                )


def _check_variants(variants: List[String]) raises:
    var canon = attention_variants()
    for i in range(len(variants)):
        var found = False
        for j in range(len(canon)):
            if variants[i] == canon[j]:
                found = True
        if not found:
            raise Error(
                "AttentionBattery: unknown variant refused: " + variants[i]
            )


def attention_row_verdict(
    variant: String, quant: String, backend: String
) raises -> AttentionBatteryRow:
    var obligation = attention_policy_obligation(quant)
    if backend != String(AV_GRADED_BACKEND):
        return AttentionBatteryRow(
            variant, quant, backend, MX_NOT_GRADED,
            String("BACKEND_NO_CPU_COMPARATOR"), obligation,
            -1, -1, -1, -1,
        )
    if variant != String(AV_GRADED_VARIANT):
        return AttentionBatteryRow(
            variant, quant, backend, MX_NOT_GRADED,
            String("NO_FILED_RECORDS"), obligation,
            -1, -1, -1, -1,
        )
    var cell = cell_verdict(quant, String(AV_GRADED_ARCH), backend)
    return AttentionBatteryRow(
        variant, quant, backend, cell.verdict, cell.reason, obligation,
        cell.faithful, cell.near_tie, cell.divergent, cell.worst_rank,
    )


def build_attention_battery(
    variants: List[String], quants: List[String], backends: List[String]
) raises -> List[AttentionBatteryRow]:
    _check_axis(variants, "variant")
    _check_axis(quants, "quant")
    _check_axis(backends, "backend")
    _check_variants(variants)
    var rows = List[AttentionBatteryRow]()
    for vi in range(len(variants)):
        for qi in range(len(quants)):
            for bi in range(len(backends)):
                rows.append(
                    attention_row_verdict(
                        variants[vi], quants[qi], backends[bi]
                    )
                )
    return rows^


def run_attention_battery() raises -> AttentionBatteryReport:
    var rows = build_attention_battery(
        attention_variants(),
        attention_battery_quants(),
        attention_battery_backends(),
    )
    var faithful = 0
    var near_tie = 0
    var divergent = 0
    var artifact = 0
    var fixture_limited = 0
    var not_graded = 0
    var backend_not_graded = 0
    var variant_not_graded = 0
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
            if rows[i].backend == String(AV_GRADED_BACKEND):
                variant_not_graded += 1
            else:
                backend_not_graded += 1
        if rows[i].obligation == POLICY_COHERENCE_ONLY:
            coherence += 1
        else:
            owed += 1
    var report = AttentionBatteryReport(
        rows.copy(), len(rows), faithful, near_tie, divergent,
        artifact, fixture_limited, not_graded, backend_not_graded,
        variant_not_graded, owed, coherence, UInt64(0),
    )
    report.digest = mx_fnv1a64(attention_battery_render(report.copy()))
    return report^


def attention_battery_row_line(row: AttentionBatteryRow) -> String:
    var s = String("AV_ROW variant=") + row.variant
    s += String(" quant=") + row.quant
    s += String(" arch=") + String(AV_GRADED_ARCH)
    s += String(" backend=") + row.backend
    s += String(" verdict=") + matrix_verdict_name(row.verdict)
    s += String(" reason=") + row.reason
    s += String(" policy=") + obligation_name(row.obligation)
    s += String(" faithful=") + String(row.faithful)
    s += String(" near_tie=") + String(row.near_tie)
    s += String(" divergent=") + String(row.divergent)
    s += String(" worst_rank=") + String(row.worst_rank)
    return s


def attention_battery_render(read report: AttentionBatteryReport) -> String:
    var s = String("A122_BATTERY variants=")
    s += String(len(attention_variants()))
    s += String(" quants=") + String(len(attention_battery_quants()))
    s += String(" backends=") + String(len(attention_battery_backends()))
    s += String(" total=") + String(report.total) + String("\n")
    for i in range(len(report.rows)):
        s += attention_battery_row_line(report.rows[i]) + String("\n")
    s += String("A122_BATTERY_SUMMARY total=") + String(report.total)
    s += String(" faithful=") + String(report.faithful)
    s += String(" near_tie=") + String(report.near_tie)
    s += String(" divergent=") + String(report.divergent)
    s += String(" artifact=") + String(report.artifact)
    s += String(" fixture_limited=") + String(report.fixture_limited)
    s += String(" not_graded=") + String(report.not_graded)
    s += String(" backend_not_graded=") + String(report.backend_not_graded)
    s += String(" variant_not_graded=") + String(report.variant_not_graded)
    s += String(" owed=") + String(report.owed)
    s += String(" coherence=") + String(report.coherence)
    return s


def attention_battery_line() -> String:
    return String(
        "A-122 attention variants battery: 4 variants"
        " (MHA, GQA, MQA, MLA) x 19 quants x 4 Z13"
        " backends, per-variant rows judged per the"
        " banked A-115 policy; GQA rows file the A-114"
        " llama cell verdicts (the A-045 records run"
        " through flash_attention_gqa), MHA/MQA/MLA"
        " rows file NOT_GRADED with named reasons,"
        " zero unexplained"
    )
