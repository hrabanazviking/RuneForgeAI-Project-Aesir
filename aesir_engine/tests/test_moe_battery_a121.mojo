# tests/test_moe_battery_a121.mojo
# A-121: MoE battery -- the OLMoE routing rows judged
# from the banked J-016 measured trace, plus the
# SYNTHETIC fixture cases, and these cases cover: the
# axes and their product, duplicate-free enumeration,
# the A-115 policy obligation by call (Q4_K_M owed),
# every cpu layer FAITHFUL with its filed witnesses,
# NOT_GRADED on every non-cpu backend, the M2 routing
# checks discriminating on mutated records (integrity,
# collapse, entropy, concentration), the synthetic
# fixture labelled SYNTHETIC with its score tensor from
# the real hit counts, the engine raw-weight rule and
# its seeded defects (renormalisation, collapse,
# backend mismatch), summary counts summing to the
# totals, degenerate axes refused, and a deterministic
# digest across re-runs.

from core.exactness_policy import POLICY_TOKEN_EXACTNESS_OWED
from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_NOT_GRADED,
)
from core.moe_battery_a121 import (
    MB_FIXTURE_STATUS,
    MB_MODEL_SHA256,
    BatteryReport,
    BatteryRow,
    MoeLayerRecord,
    battery_backends,
    battery_line,
    battery_render,
    battery_row_line,
    battery_row_verdict,
    build_battery,
    moe_layer_records,
    moe_layer_verdict,
    moe_layers,
    policy_obligation,
    run_battery,
    syn_cases,
    syn_raw_mass_milli,
    syn_scores,
    syn_topk,
    syn_total_score,
)


def _row(
    read report: BatteryReport, layer: Int, backend: String
) raises -> BatteryRow:
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.layer == layer and r.backend == backend:
            return r
    raise Error("moe battery row not found")


def _raises_build(layers: List[Int], backends: List[String]) -> Bool:
    try:
        _ = build_battery(layers, backends)
    except:
        return True
    return False


def test_moe_axes_product() raises:
    var layers = moe_layers()
    var backends = battery_backends()
    if len(layers) != 16 or len(backends) != 4:
        raise Error("moe axes must be 16 layers x 4 backends")
    if backends[0] != String("cpu") or backends[1] != String("vulkan"):
        raise Error("moe backends must be A-109 harness order")
    if backends[2] != String("hip") or backends[3] != String("npu"):
        raise Error("moe backends must be A-109 harness order")
    var report = run_battery()
    if report.total != 64 or len(report.rows) != 64:
        raise Error("moe battery must file exactly 64 rows")


def test_moe_enumeration_unique() raises:
    var report = run_battery()
    for i in range(len(report.rows)):
        for j in range(i + 1, len(report.rows)):
            var a = report.rows[i]
            var b = report.rows[j]
            if a.layer == b.layer and a.backend == b.backend:
                raise Error("duplicate moe battery row")
    var first = report.rows[0]
    if first.layer != 0 or first.backend != String("cpu"):
        raise Error("enumeration must start at layer 0 / cpu")
    if String("A-121 MoE battery") not in battery_line():
        raise Error("battery line must name the slice")
    if String("SYNTHETIC") not in battery_line():
        raise Error("battery line must label the synthetic fixture")


def test_moe_policy_obligation() raises:
    var obligation = policy_obligation()
    if obligation != POLICY_TOKEN_EXACTNESS_OWED:
        raise Error("Q4_K_M must owe token-exactness per A-115")
    var report = run_battery()
    if report.owed != 64 or report.coherence != 0:
        raise Error("row policy counts must be 64 owed / 0 coherence")
    for i in range(len(report.rows)):
        if report.rows[i].obligation != POLICY_TOKEN_EXACTNESS_OWED:
            raise Error("every moe row must file the owed obligation")


def test_moe_cpu_faithful() raises:
    var report = run_battery()
    var records = moe_layer_records()
    if len(records) != 16:
        raise Error("exactly 16 J-016 layer records must be filed")
    for layer in range(16):
        var r = _row(report.copy(), layer, String("cpu"))
        if r.verdict != MX_FAITHFUL:
            raise Error("cpu layer row must be FAITHFUL")
        if r.reason != String("J016_ROUTING_CHECKS_PASS"):
            raise Error("cpu layer row must name its pass reason")
        if r.accesses != 4616 or r.distinct_hit != 64 or r.dead != 0:
            raise Error("cpu layer witnesses must match J-016")


def test_moe_layer_witnesses() raises:
    var records = moe_layer_records()
    if records[0].top_expert != 6 or records[0].top_hits != 382:
        raise Error("layer 0 top expert must be 6 with 382 hits")
    if records[0].entropy_x10000 != 56772:
        raise Error("layer 0 entropy must be 56772 (x10000)")
    if records[2].entropy_x10000 != 58502:
        raise Error("layer 2 entropy must be the filed maximum 58502")
    if records[7].entropy_x10000 != 54349:
        raise Error("layer 7 entropy must be the filed minimum 54349")
    var total_accesses = 0
    for i in range(len(records)):
        total_accesses += records[i].accesses
    if total_accesses != 73856:
        raise Error("layer accesses must sum to the J-016 total 73856")


def test_moe_backend_not_graded() raises:
    var report = run_battery()
    var count = 0
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.backend != String("cpu"):
            if r.verdict != MX_NOT_GRADED:
                raise Error("non-cpu row must be NOT_GRADED")
            if r.reason != String("BACKEND_NO_CPU_COMPARATOR"):
                raise Error("non-cpu row must name its reason")
            if r.accesses != -1 or r.top_hits != -1:
                raise Error("ungraded row must not zero-fill witnesses")
            count += 1
    if count != 48:
        raise Error("exactly 48 non-cpu rows must be NOT_GRADED")


def test_moe_summary_sums() raises:
    var report = run_battery()
    var s = report.faithful + report.near_tie + report.divergent
    s += report.artifact + report.fixture_limited + report.not_graded
    if s != report.total:
        raise Error("verdict counts must sum to the total")
    if report.owed + report.coherence != report.total:
        raise Error("policy counts must sum to the total")
    if report.faithful != 16 or report.not_graded != 48:
        raise Error("filed faithful/not-graded counts mismatch")
    if report.divergent != 0 or report.artifact != 0:
        raise Error("real rows must file no divergent/artifact verdicts")
    var text = battery_render(report.copy())
    if String("A121_BATTERY_SUMMARY total=64") not in text:
        raise Error("render must carry the summary line")
    var line = battery_row_line(report.rows[0])
    if String("policy=TOKEN_EXACTNESS_OWED") not in line:
        raise Error("row line must carry the policy obligation")


def test_moe_checks_discriminate() raises:
    var good = MoeLayerRecord(0, 4616, 64, 0, 56772, 6, 382)
    var v = moe_layer_verdict(good)
    if v[0] != String("FAITHFUL"):
        raise Error("the filed layer 0 record must pass the M2 checks")
    var bad_access = MoeLayerRecord(0, 4615, 64, 0, 56772, 6, 382)
    v = moe_layer_verdict(bad_access)
    if v[0] != String("DIVERGENT"):
        raise Error("an access-count break must be DIVERGENT")
    if v[1] != String("ROUTING_INTEGRITY_ACCESSES"):
        raise Error("access break must name its reason")
    var collapsed = MoeLayerRecord(0, 4616, 2, 6, 12000, 6, 4000)
    v = moe_layer_verdict(collapsed)
    if v[1] != String("ROUTER_COLLAPSE_DEAD_EXPERTS"):
        raise Error("dead experts must file the collapse reason")
    var flat = MoeLayerRecord(0, 4616, 64, 0, 30000, 6, 382)
    v = moe_layer_verdict(flat)
    if v[1] != String("ROUTING_ENTROPY_OUT_OF_BAND"):
        raise Error("low entropy must file the entropy reason")
    var concentrated = MoeLayerRecord(0, 4616, 64, 0, 56772, 6, 600)
    v = moe_layer_verdict(concentrated)
    if v[1] != String("ROUTING_TOP_EXPERT_CONCENTRATION"):
        raise Error("a dominant expert must file the concentration reason")
    var obligation = policy_obligation()
    var row = battery_row_verdict(good, String("cpu"), obligation)
    if row.verdict != MX_FAITHFUL:
        raise Error("row verdict must agree with the layer checks")


def test_moe_synthetic_labelled() raises:
    if String(MB_FIXTURE_STATUS) != String("SYNTHETIC"):
        raise Error("the fixture status must be SYNTHETIC")
    var report = run_battery()
    var text = battery_render(report.copy())
    if String("fixture_status=SYNTHETIC") not in text:
        raise Error("render must label the fixture SYNTHETIC")
    if String("status=SYNTHETIC") not in text:
        raise Error("synthetic lines must carry the SYNTHETIC label")
    if String(MB_MODEL_SHA256) not in text:
        raise Error("render must carry the real model sha pin (J-015)")
    var scores = syn_scores()
    if len(scores) != 8 or scores[0] != 1749 or scores[1] != 1607:
        raise Error("synthetic scores must be the real J-016 hit counts")
    if syn_total_score() != 11856:
        raise Error("synthetic score total must be 11856")


def test_moe_synthetic_raw_rule() raises:
    var picked = syn_topk()
    if len(picked) != 2 or picked[0] != 6 or picked[1] != 62:
        raise Error("synthetic top-2 must select experts 6 and 62")
    if syn_raw_mass_milli() != 283:
        raise Error("raw top-2 mass must be 283 milli, not renormalised")
    var cases = syn_cases()
    if cases[0].name != String("SYN_RAW"):
        raise Error("first synthetic case must be SYN_RAW")
    if cases[0].verdict != MX_FAITHFUL:
        raise Error("the engine raw-weight rule must file FAITHFUL")


def test_moe_synthetic_defects() raises:
    var cases = syn_cases()
    if len(cases) != 4:
        raise Error("exactly 4 synthetic cases must be filed")
    if cases[1].verdict != MX_DIVERGENT:
        raise Error("renormalisation must be DIVERGENT")
    if cases[1].reason != String("J022_B1_RENORMALISATION"):
        raise Error("renormalisation must name the J-022 B1 defect")
    if cases[2].verdict != MX_DIVERGENT:
        raise Error("router collapse must be DIVERGENT")
    if cases[2].reason != String("ROUTER_COLLAPSE_DEAD_EXPERTS"):
        raise Error("collapse must name its reason")
    if cases[3].verdict != MX_COMPARATOR_ARTIFACT:
        raise Error("backend mismatch must be COMPARATOR_ARTIFACT")
    if cases[3].reason != String("BACKEND_MISMATCH"):
        raise Error("mismatch must name its reason")
    var report = run_battery()
    if report.syn_total != 4 or report.syn_faithful != 1:
        raise Error("synthetic counts must be 4 total / 1 faithful")
    if report.syn_divergent != 2 or report.syn_artifact != 1:
        raise Error("synthetic counts must be 2 divergent / 1 artifact")


def test_moe_invalid_axes_refused() raises:
    var empty_layers = List[Int]()
    var backends = battery_backends()
    if not _raises_build(empty_layers, backends.copy()):
        raise Error("empty layer axis must be refused")
    var dup = moe_layers()
    dup.append(0)
    if not _raises_build(dup, backends.copy()):
        raise Error("duplicate layer axis must be refused")
    var layers = moe_layers()
    var empty_backends = List[String]()
    if not _raises_build(layers.copy(), empty_backends.copy()):
        raise Error("empty backend axis must be refused")


def test_moe_digest_deterministic() raises:
    var a = run_battery()
    var b = run_battery()
    if a.digest != b.digest or a.digest == UInt64(0):
        raise Error("moe digest must be deterministic and non-zero")
    if battery_render(a.copy()) != battery_render(b.copy()):
        raise Error("moe render must be deterministic")
