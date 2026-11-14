# tests/test_attention_battery_a122.mojo
# A-122: Attention variants battery -- the attention
# variant axis (MHA, GQA, MQA, MLA) laid over the
# A-114 matrix, and these cases cover: the axes and
# their product, duplicate-free enumeration, the
# A-115 policy obligation by canonical call on every
# quant, GQA cpu rows delegating cell-for-cell to the
# A-114 llama cells, the filed GQA cpu verdict counts
# and witnesses, MHA/MQA/MLA cpu rows NOT_GRADED with
# the named reason, every non-cpu row NOT_GRADED, the
# MLA no-implementation attestation, summary counts
# summing to the totals, the IQ precedence (variant
# check before the IQ family), degenerate axes
# refused, and a deterministic digest across re-runs.

from core.attention_battery_a122 import (
    AttentionBatteryReport,
    AttentionBatteryRow,
    attention_battery_backends,
    attention_battery_line,
    attention_battery_quants,
    attention_battery_render,
    attention_battery_row_line,
    attention_policy_obligation,
    attention_row_verdict,
    attention_variants,
    build_attention_battery,
    run_attention_battery,
    variant_evidence,
    variant_geometry,
)
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
)


def _row(
    read report: AttentionBatteryReport,
    variant: String,
    quant: String,
    backend: String,
) raises -> AttentionBatteryRow:
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.variant == variant and r.quant == quant and r.backend == backend:
            return r
    raise Error("attention battery row not found")


def _raises_build(
    variants: List[String], quants: List[String], backends: List[String]
) -> Bool:
    try:
        _ = build_attention_battery(variants, quants, backends)
    except:
        return True
    return False


def _raises_obligation(quant: String) -> Bool:
    try:
        _ = attention_policy_obligation(quant)
    except:
        return True
    return False


def test_attn_axes_product() raises:
    var variants = attention_variants()
    var quants = attention_battery_quants()
    var backends = attention_battery_backends()
    if len(variants) != 4 or len(quants) != 19 or len(backends) != 4:
        raise Error("attn axes must be 4 variants x 19 quants x 4 backends")
    if variants[0] != String("MHA") or variants[1] != String("GQA"):
        raise Error("variant axis must start MHA, GQA")
    if variants[2] != String("MQA") or variants[3] != String("MLA"):
        raise Error("variant axis must end MQA, MLA")
    if backends[0] != String("cpu") or backends[3] != String("npu"):
        raise Error("backends must be A-109 harness order")
    var report = run_attention_battery()
    if report.total != 304 or len(report.rows) != 304:
        raise Error("attention battery must file exactly 304 rows")


def test_attn_enumeration_unique() raises:
    var report = run_attention_battery()
    for i in range(len(report.rows)):
        for j in range(i + 1, len(report.rows)):
            var a = report.rows[i]
            var b = report.rows[j]
            if (
                a.variant == b.variant
                and a.quant == b.quant
                and a.backend == b.backend
            ):
                raise Error("duplicate attention battery row")
    var first = report.rows[0]
    if first.variant != String("MHA") or first.quant != String("F16"):
        raise Error("enumeration must start at MHA / F16")
    if first.backend != String("cpu"):
        raise Error("enumeration must start on cpu")
    if String("A-122 attention variants battery") not in attention_battery_line():
        raise Error("battery line must name the slice")
    if String("latent") not in variant_geometry(String("MLA")):
        raise Error("MLA geometry must name the latent compression")


def test_attn_policy_obligation() raises:
    var quants = attention_battery_quants()
    for i in range(len(quants)):
        var mine = attention_policy_obligation(quants[i])
        var canon = policy_for_quant(quants[i])
        if mine != canon.obligation:
            raise Error("obligation must agree with canonical A-115 policy")
    if attention_policy_obligation(String("Q4_K_M")) != POLICY_TOKEN_EXACTNESS_OWED:
        raise Error("Q4_K_M must owe token-exactness per A-115")
    if attention_policy_obligation(String("IQ1_S")) != POLICY_COHERENCE_ONLY:
        raise Error("IQ1_S must be coherence-only per A-115")
    if not _raises_obligation(String("Q9_NOPE")):
        raise Error("unknown quant must be refused by the canonical lookup")
    var report = run_attention_battery()
    if report.owed != 160 or report.coherence != 144:
        raise Error("policy counts must be 160 owed / 144 coherence")


def test_attn_gqa_delegates_matrix() raises:
    var quants = attention_battery_quants()
    var report = run_attention_battery()
    for i in range(len(quants)):
        var r = _row(report.copy(), String("GQA"), quants[i], String("cpu"))
        var cell = cell_verdict(quants[i], String("llama"), String("cpu"))
        if r.verdict != cell.verdict or r.reason != cell.reason:
            raise Error("GQA cpu row must file the A-114 llama cell verdict")
        if r.faithful != cell.faithful or r.near_tie != cell.near_tie:
            raise Error("GQA cpu row must carry the cell witnesses")
        if r.divergent != cell.divergent or r.worst_rank != cell.worst_rank:
            raise Error("GQA cpu row must carry the cell witnesses")


def test_attn_gqa_filed_counts() raises:
    var report = run_attention_battery()
    var faithful = 0
    var near_tie = 0
    var divergent = 0
    var artifact = 0
    var fixture_limited = 0
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.variant == String("GQA") and r.backend == String("cpu"):
            if r.verdict == MX_FAITHFUL:
                faithful += 1
            elif r.verdict == MX_FAITHFUL_NEAR_TIE:
                near_tie += 1
            elif r.verdict == MX_DIVERGENT:
                divergent += 1
            elif r.verdict == MX_COMPARATOR_ARTIFACT:
                artifact += 1
            elif r.verdict == MX_FIXTURE_LIMITED:
                fixture_limited += 1
    if faithful != 4 or near_tie != 2 or divergent != 2:
        raise Error("GQA cpu counts must be 4 faithful / 2 near-tie / 2 divergent")
    if artifact != 2 or fixture_limited != 9:
        raise Error("GQA cpu counts must be 2 artifact / 9 fixture-limited")
    var q40 = _row(report.copy(), String("GQA"), String("Q4_0"), String("cpu"))
    if q40.faithful != 27 or q40.near_tie != 3 or q40.divergent != 2:
        raise Error("Q4_0 GQA witnesses must be the A-045 filed 27/3/2")
    if q40.worst_rank != 3:
        raise Error("Q4_0 GQA worst rank must be the A-045 filed 3")
    var q4km = _row(report.copy(), String("GQA"), String("Q4_K_M"), String("cpu"))
    if q4km.verdict != MX_FAITHFUL_NEAR_TIE:
        raise Error("Q4_K_M GQA cpu row must be FAITHFUL_NEAR_TIE")


def test_attn_variant_cpu_not_graded() raises:
    var report = run_attention_battery()
    var count = 0
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.backend == String("cpu") and r.variant != String("GQA"):
            count += 1
            if r.verdict != MX_NOT_GRADED:
                raise Error("non-GQA cpu row must be NOT_GRADED")
            if r.reason != String("NO_FILED_RECORDS"):
                raise Error("non-GQA cpu row must name NO_FILED_RECORDS")
            if r.faithful != -1 or r.worst_rank != -1:
                raise Error("ungraded row witnesses must stay -1, never faked")
    if count != 57:
        raise Error("exactly 57 non-GQA cpu rows must file NOT_GRADED")


def test_attn_backend_not_graded() raises:
    var report = run_attention_battery()
    var count = 0
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.backend != String("cpu"):
            count += 1
            if r.verdict != MX_NOT_GRADED:
                raise Error("non-cpu row must be NOT_GRADED")
            if r.reason != String("BACKEND_NO_CPU_COMPARATOR"):
                raise Error("non-cpu row must name its comparator reason")
    if count != 228:
        raise Error("exactly 228 non-cpu rows must file NOT_GRADED")
    if report.backend_not_graded != 228 or report.variant_not_graded != 57:
        raise Error("report NOT_GRADED split must be 228 backend / 57 variant")


def test_attn_mla_attestation() raises:
    var mla = variant_evidence(String("MLA"))
    if String("no MLA implementation") not in mla:
        raise Error("MLA attestation must state no implementation exists")
    if String("NO_FILED_RECORDS") not in mla:
        raise Error("MLA attestation must file NO_FILED_RECORDS")
    var mha = variant_evidence(String("MHA"))
    if String("routing") not in mha:
        raise Error("MHA attestation must bound its evidence to routing")
    var gqa = variant_evidence(String("GQA"))
    if String("flash_attention_gqa") not in gqa:
        raise Error("GQA attestation must name the graded kernel path")
    if String("UNKNOWN") not in variant_evidence(String("XYZ")):
        raise Error("unknown variant attestation must be refused by name")


def test_attn_summary_sums() raises:
    var report = run_attention_battery()
    var parts = report.faithful + report.near_tie + report.divergent
    parts += report.artifact + report.fixture_limited + report.not_graded
    if parts != report.total or report.total != 304:
        raise Error("verdict counts must sum to the 304 total")
    if report.faithful != 4 or report.near_tie != 2 or report.divergent != 2:
        raise Error("summary must file 4/2/2 graded GQA verdicts")
    if report.artifact != 2 or report.fixture_limited != 9:
        raise Error("summary must file 2 artifact / 9 fixture-limited")
    if report.not_graded != 285:
        raise Error("summary must file 285 NOT_GRADED")
    if report.owed + report.coherence != report.total:
        raise Error("policy counts must cover every row")


def test_attn_iq_precedence() raises:
    var gqa_iq = _row(
        run_attention_battery().copy(), String("GQA"), String("IQ1_S"), String("cpu")
    )
    if gqa_iq.verdict != MX_FIXTURE_LIMITED:
        raise Error("GQA IQ cpu row must be FIXTURE_LIMITED (A-114 R3)")
    if gqa_iq.obligation != POLICY_COHERENCE_ONLY:
        raise Error("GQA IQ row obligation must stay COHERENCE_ONLY")
    var mla_iq = _row(
        run_attention_battery().copy(), String("MLA"), String("IQ1_S"), String("cpu")
    )
    if mla_iq.verdict != MX_NOT_GRADED:
        raise Error("MLA IQ cpu row must be NOT_GRADED, never FIXTURE_LIMITED")
    if mla_iq.obligation != POLICY_COHERENCE_ONLY:
        raise Error("MLA IQ row obligation must still file COHERENCE_ONLY")


def test_attn_invalid_axes_refused() raises:
    var variants = attention_variants()
    var quants = attention_battery_quants()
    var backends = attention_battery_backends()
    var empty = List[String]()
    if not _raises_build(empty, quants, backends):
        raise Error("empty variant axis must be refused")
    var dup = List[String]()
    dup.append(String("GQA"))
    dup.append(String("GQA"))
    if not _raises_build(dup, quants, backends):
        raise Error("duplicate variant axis must be refused")
    var unknown = List[String]()
    unknown.append(String("XYZ"))
    if not _raises_build(unknown, quants, backends):
        raise Error("unknown variant must be refused")
    if not _raises_build(variants, quants, empty):
        raise Error("empty backend axis must be refused")


def test_attn_row_line_render() raises:
    var row = attention_row_verdict(
        String("GQA"), String("Q4_K_M"), String("cpu")
    )
    var line = attention_battery_row_line(row)
    if String("FAITHFUL_NEAR_TIE") not in line:
        raise Error("GQA Q4_K_M line must file FAITHFUL_NEAR_TIE")
    if String("TOKEN_EXACTNESS_OWED") not in line:
        raise Error("GQA Q4_K_M line must file the owed policy")
    var mla = attention_row_verdict(
        String("MLA"), String("Q4_K_M"), String("cpu")
    )
    var mla_line = attention_battery_row_line(mla)
    if String("NOT_GRADED") not in mla_line:
        raise Error("MLA line must file NOT_GRADED")
    var render = attention_battery_render(run_attention_battery().copy())
    if String("A122_BATTERY_SUMMARY") not in render:
        raise Error("render must carry the filed summary")


def test_attn_digest_deterministic() raises:
    var a = run_attention_battery()
    var b = run_attention_battery()
    if a.digest != b.digest or a.digest == UInt64(0):
        raise Error("battery digest must be deterministic and nonzero")
    if a.total != b.total or a.not_graded != b.not_graded:
        raise Error("battery re-run must reproduce counts exactly")
