# tests/test_rope_scaling_battery_a124.mojo
# A-124: RoPE scaling parity -- the NTK/YaRN-scaled
# long-context ladder rows judged against the filed
# independent reference records, plus the SYNTHETIC
# defect fixture cases, and these cases cover: the
# axes and their product, duplicate-free enumeration,
# the A-115 policy obligation by call (Q4_K_M owed),
# every cpu row FAITHFUL with its filed witnesses,
# NOT_GRADED on every non-cpu backend, the filed
# ladder witnesses (YaRN/NTK endpoint values, the
# YaRN attention factor, the pair-63 angle at
# 65536), the teacher-forcing account filed
# NOT_GRADED (NO_FILED_RECORDS), the R2 checks
# discriminating on mutated filed records, the
# synthetic fixture labelled SYNTHETIC with its
# seeded defects, degenerate axes and sub-32768
# positions refused, and a deterministic digest
# across re-runs.

from core.exactness_policy import POLICY_TOKEN_EXACTNESS_OWED
from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_NOT_GRADED,
)
from core.rope_scaling_battery_a124 import (
    RB_FIXTURE_STATUS,
    BatteryReport,
    BatteryRow,
    battery_backends,
    battery_line,
    battery_render,
    battery_row_line,
    battery_row_verdict,
    build_battery,
    config_indices,
    config_verdict,
    filed_angle63_micro,
    filed_attn_x10000,
    filed_freqs_x1e12,
    ladder_verdict,
    policy_obligation,
    rope_angle_micro,
    rope_configs,
    rope_freq_scaled,
    rope_positions,
    run_battery,
    sample_dims,
    syn_cases,
    yarn_attention_x10000,
)


def _row(
    read report: BatteryReport,
    config: Int,
    position: Int,
    backend: String,
) raises -> BatteryRow:
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.config == config and r.position == position:
            if r.backend == backend:
                return r
    raise Error("rope scaling battery row not found")


def _raises_build(
    idxs: List[Int], positions: List[Int], backends: List[String]
) -> Bool:
    try:
        _ = build_battery(idxs, positions, backends)
    except:
        return True
    return False


def test_rope_axes_product() raises:
    var idxs = config_indices()
    var positions = rope_positions()
    var backends = battery_backends()
    if len(idxs) != 4 or len(positions) != 3 or len(backends) != 4:
        raise Error("rope axes must be 4 configs x 3 positions x 4 backends")
    if backends[0] != String("cpu") or backends[1] != String("vulkan"):
        raise Error("rope backends must be A-109 harness order")
    if backends[2] != String("hip") or backends[3] != String("npu"):
        raise Error("rope backends must be A-109 harness order")
    for i in range(len(positions)):
        if positions[i] < 32768:
            raise Error("every judged position must be >= 32768")
    var report = run_battery()
    if report.total != 48 or len(report.rows) != 48:
        raise Error("rope battery must file exactly 48 rows")


def test_rope_enumeration_unique() raises:
    var report = run_battery()
    for i in range(len(report.rows)):
        for j in range(i + 1, len(report.rows)):
            var a = report.rows[i]
            var b = report.rows[j]
            if a.config == b.config and a.position == b.position:
                if a.backend == b.backend:
                    raise Error("duplicate rope battery row")
    var first = report.rows[0]
    if first.config != 0 or first.position != 32768:
        raise Error("enumeration must start at config 0 / 32768")
    if first.backend != String("cpu"):
        raise Error("enumeration must start on cpu")
    if String("A-124 RoPE scaling parity") not in battery_line():
        raise Error("battery line must name the slice")
    if String("SYNTHETIC") not in battery_line():
        raise Error("battery line must label the synthetic fixture")


def test_rope_policy_obligation() raises:
    var obligation = policy_obligation()
    if obligation != POLICY_TOKEN_EXACTNESS_OWED:
        raise Error("Q4_K_M must owe token-exactness per A-115")
    var report = run_battery()
    if report.owed != 48 or report.coherence != 0:
        raise Error("row policy counts must be 48 owed / 0 coherence")
    for i in range(len(report.rows)):
        if report.rows[i].obligation != POLICY_TOKEN_EXACTNESS_OWED:
            raise Error("every rope row must file the owed obligation")


def test_rope_cpu_faithful() raises:
    var report = run_battery()
    var count = 0
    for config in range(4):
        for pi in range(len(rope_positions())):
            var pos = rope_positions()[pi]
            var r = _row(report.copy(), config, pos, String("cpu"))
            if r.verdict != MX_FAITHFUL:
                raise Error("cpu rope row must be FAITHFUL")
            if r.reason != String("ROPE_LADDER_CHECKS_PASS"):
                raise Error("cpu rope row must name its pass reason")
            if r.samples != 9 or r.max_err_ppm < 0:
                raise Error("cpu rope row must file its witnesses")
            if r.max_err_ppm > 10:
                raise Error("cpu rope row error must be within 10 ppm")
            count += 1
    if count != 12:
        raise Error("exactly 12 cpu rows must be filed")


def test_rope_ladder_witnesses() raises:
    var cfgs = rope_configs()
    var dims = sample_dims()
    if len(dims) != 9 or dims[0] != 0 or dims[8] != 63:
        raise Error("sample dims must be the 9 filed indices")
    var yarn = filed_freqs_x1e12(3)
    if yarn[8] != 76723 or yarn[6] != 429556797:
        raise Error("filed YaRN ladder witnesses mismatch")
    var ntk = filed_freqs_x1e12(2)
    var linear = filed_freqs_x1e12(1)
    if ntk[8] != 3608694 or linear[8] != 3608694:
        raise Error("NTK and LINEAR must agree at the lowest frequency")
    if ntk[0] != 1000000000000 or linear[0] != 31250000000:
        raise Error("pair 0: NTK unchanged, LINEAR fully scaled")
    if filed_attn_x10000(3) != 13466 or filed_attn_x10000(0) != 10000:
        raise Error("filed attention factors mismatch")
    if yarn_attention_x10000(32) != 13466:
        raise Error("module YaRN attention factor must be 13466")
    if yarn_attention_x10000(1) != 10000:
        raise Error("attention factor at factor 1 must be 10000")
    if rope_freq_scaled(cfgs[3], 0) != 1.0:
        raise Error("YaRN pair 0 frequency must be exactly 1.0")
    var angle = rope_angle_micro(cfgs[3], 63, 65536)
    var want = filed_angle63_micro(3)
    var diff = angle - want
    if diff < 0:
        diff = -diff
    if diff > want // 1000 + 2:
        raise Error("YaRN pair-63 angle at 65536 must match the filing")
    if filed_angle63_micro(0) != 7567979:
        raise Error("filed NONE angle witness mismatch")


def test_rope_backend_not_graded() raises:
    var report = run_battery()
    var count = 0
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.backend != String("cpu"):
            if r.verdict != MX_NOT_GRADED:
                raise Error("non-cpu row must be NOT_GRADED")
            if r.reason != String("BACKEND_NO_CPU_COMPARATOR"):
                raise Error("non-cpu row must name its reason")
            if r.max_err_ppm != -1 or r.samples != -1:
                raise Error("ungraded row must not zero-fill witnesses")
            count += 1
    if count != 36:
        raise Error("exactly 36 non-cpu rows must be NOT_GRADED")


def test_rope_summary_sums() raises:
    var report = run_battery()
    var s = report.faithful + report.near_tie + report.divergent
    s += report.artifact + report.fixture_limited + report.not_graded
    if s != report.total:
        raise Error("verdict counts must sum to the total")
    if report.owed + report.coherence != report.total:
        raise Error("policy counts must sum to the total")
    if report.faithful != 12 or report.not_graded != 36:
        raise Error("filed faithful/not-graded counts mismatch")
    if report.divergent != 0 or report.artifact != 0:
        raise Error("real rows must file no divergent/artifact verdicts")
    if report.tf_total != 48 or report.tf_graded != 0:
        raise Error("TF account must file 48 total / 0 graded")
    if report.tf_not_graded != 48:
        raise Error("TF account must file 48 NOT_GRADED rows")
    var text = battery_render(report.copy())
    if String("A124_BATTERY_SUMMARY total=48") not in text:
        raise Error("render must carry the summary line")
    if String("A124_TF_ACCOUNT total=48 graded=0 not_graded=48") not in text:
        raise Error("render must carry the TF account line")
    if String("reason=NO_FILED_RECORDS") not in text:
        raise Error("TF account must name NO_FILED_RECORDS")
    var line = battery_row_line(report.rows[0])
    if String("policy=TOKEN_EXACTNESS_OWED") not in line:
        raise Error("row line must carry the policy obligation")


def test_rope_checks_discriminate() raises:
    var cfgs = rope_configs()
    var good = config_verdict(3, 65536)
    if good[0] != String("FAITHFUL"):
        raise Error("the filed YaRN record must pass the R2 checks")
    var mutated = filed_freqs_x1e12(3)
    mutated[6] = mutated[6] * 2
    var v = ladder_verdict(
        cfgs[3], 65536, mutated.copy(), filed_attn_x10000(3),
        filed_angle63_micro(3),
    )
    if v[0] != String("DIVERGENT"):
        raise Error("a doubled ramp frequency must be DIVERGENT")
    if v[1] != String("FREQ_LADDER_MISMATCH"):
        raise Error("frequency break must name its reason")
    var v2 = ladder_verdict(
        cfgs[3], 65536, filed_freqs_x1e12(3), 10000,
        filed_angle63_micro(3),
    )
    if v2[0] != String("DIVERGENT"):
        raise Error("a missing attention factor must be DIVERGENT")
    if v2[1] != String("YARN_ATTENTION_FACTOR_MISMATCH"):
        raise Error("attention break must name its reason")
    var obligation = policy_obligation()
    var row = battery_row_verdict(
        3, cfgs[3], 65536, String("cpu"), obligation
    )
    if row.verdict != MX_FAITHFUL:
        raise Error("row verdict must agree with the ladder checks")


def test_rope_synthetic_labelled() raises:
    if String(RB_FIXTURE_STATUS) != String("SYNTHETIC"):
        raise Error("the fixture status must be SYNTHETIC")
    var report = run_battery()
    var text = battery_render(report.copy())
    if String("fixture_status=SYNTHETIC") not in text:
        raise Error("render must label the fixture SYNTHETIC")
    if String("status=SYNTHETIC") not in text:
        raise Error("synthetic lines must carry the SYNTHETIC label")
    if String("A124_SYNTHETIC_SUMMARY status=SYNTHETIC") not in text:
        raise Error("synthetic summary must carry the SYNTHETIC label")


def test_rope_synthetic_yarn_rule() raises:
    var cases = syn_cases()
    if cases[0].name != String("SYN_YARN_OK"):
        raise Error("first synthetic case must be SYN_YARN_OK")
    if cases[0].verdict != MX_FAITHFUL:
        raise Error("the correct YaRN ladder must file FAITHFUL")
    if cases[0].reason != String("SYNTHETIC_YARN_LADDER_MATCH"):
        raise Error("YaRN pass must name its reason")
    var cfgs = rope_configs()
    var f63 = rope_freq_scaled(cfgs[3], 63)
    var filed63 = Float64(filed_freqs_x1e12(3)[8]) / 1000000000000.0
    var rel = f63 - filed63
    if rel < 0.0:
        rel = -rel
    if rel > filed63 / 100000.0:
        raise Error("module YaRN pair-63 freq must match the filing")


def test_rope_synthetic_defects() raises:
    var cases = syn_cases()
    if len(cases) != 5:
        raise Error("exactly 5 synthetic cases must be filed")
    if cases[1].verdict != MX_DIVERGENT:
        raise Error("unscaled at long context must be DIVERGENT")
    if cases[1].reason != String("ROPE_UNSCALED_AT_LONG_CONTEXT"):
        raise Error("unscaled case must name its reason")
    if cases[2].verdict != MX_DIVERGENT:
        raise Error("NTK-for-YaRN must be DIVERGENT")
    if cases[2].reason != String("YARN_RAMP_IGNORED"):
        raise Error("ramp-ignored case must name its reason")
    if cases[3].verdict != MX_DIVERGENT:
        raise Error("missing attention factor must be DIVERGENT")
    if cases[3].reason != String("YARN_ATTENTION_FACTOR_MISSING"):
        raise Error("attention case must name its reason")
    if cases[4].verdict != MX_COMPARATOR_ARTIFACT:
        raise Error("backend mismatch must be COMPARATOR_ARTIFACT")
    if cases[4].reason != String("BACKEND_MISMATCH"):
        raise Error("mismatch must name its reason")
    var report = run_battery()
    if report.syn_total != 5 or report.syn_faithful != 1:
        raise Error("synthetic counts must be 5 total / 1 faithful")
    if report.syn_divergent != 3 or report.syn_artifact != 1:
        raise Error("synthetic counts must be 3 divergent / 1 artifact")


def test_rope_invalid_axes_refused() raises:
    var backends = battery_backends()
    var positions = rope_positions()
    var empty_configs = List[Int]()
    if not _raises_build(empty_configs, positions.copy(), backends.copy()):
        raise Error("empty config axis must be refused")
    var dup = config_indices()
    dup.append(0)
    if not _raises_build(dup, positions.copy(), backends.copy()):
        raise Error("duplicate config axis must be refused")
    var idxs = config_indices()
    var low_positions = List[Int]()
    low_positions.append(16384)
    if not _raises_build(idxs.copy(), low_positions, backends.copy()):
        raise Error("a sub-32768 position must be refused")
    var empty_backends = List[String]()
    if not _raises_build(idxs.copy(), positions.copy(), empty_backends):
        raise Error("empty backend axis must be refused")


def test_rope_digest_deterministic() raises:
    var a = run_battery()
    var b = run_battery()
    if a.digest != b.digest or a.digest == UInt64(0):
        raise Error("rope digest must be deterministic and non-zero")
    if battery_render(a.copy()) != battery_render(b.copy()):
        raise Error("rope render must be deterministic")
