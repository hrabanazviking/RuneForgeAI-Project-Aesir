# tests/test_special_token_battery_a126.mojo
# A-126: Special-token handling -- the per-family
# EOS/BOS/pad rows judged across Z13 backends,
# with stop-reason correctness, and these cases
# cover: the axes and their product, duplicate-free
# enumeration, the A-115 policy obligation by call
# (Q4_K_M owed), the faithful cpu rows (qwen2,
# qwen3, gemma4), the llama cpu row DIVERGENT
# (STOP_SET_INCOMPLETE -- the CPU generate path
# stops on the single eos id only, while the
# family's filed stop set is {128001, 128009}),
# NOT_GRADED on every non-cpu backend and on the
# surfaceless mistral3 cpu row, the family specs
# agreeing with the banked dense profiles BY
# CALL, the BOS rule executed on the banked
# RuneWeaver, the engine stop transcription
# cross-verified against the REAL
# generation_stop_reason from aesir.mojo over
# the whole scenario grid (including the filed
# fact that it returns "" for the llama turn
# token), the scenario grid itself, the
# synthetic fixture labelled SYNTHETIC with its
# seeded defects, degenerate axes refused, and
# the summary sums with a deterministic digest.

from loader.tokenizer import RuneWeaver
from aesir import GenerationConfig, generation_stop_reason
from core.dense_gqa_profile import (
    llama3_2_3b_profile,
    llama3_8b_profile,
    qwen2_coder_7b_profile,
    qwen3_0_6b_profile,
)
from core.exactness_policy import POLICY_TOKEN_EXACTNESS_OWED
from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_NOT_GRADED,
)
from core.special_token_battery_a126 import (
    SB_FIXTURE_STATUS,
    SB_FROM_METADATA,
    SB_NO_PAD,
    SB_SCENARIOS,
    BatteryReport,
    BatteryRow,
    SpecialSpec,
    battery_backends,
    battery_line,
    battery_render,
    battery_row_line,
    battery_row_verdict,
    bos_rule_ok,
    build_battery,
    engine_stop_reason,
    family_indices,
    family_specs,
    policy_obligation,
    run_battery,
    scenario_agrees,
    scenario_engine_reason,
    scenario_spec_reason,
    spec_stop_reason,
    syn_cases,
)


def _row(
    read report: BatteryReport, family: Int, backend: String
) raises -> BatteryRow:
    for i in range(len(report.rows)):
        var r = report.rows[i]
        if r.family == family and r.backend == backend:
            return r
    raise Error("special token battery row not found")


def _raises_build(idxs: List[Int], backends: List[String]) -> Bool:
    try:
        _ = build_battery(idxs, backends)
    except:
        return True
    return False


def test_special_axes_product() raises:
    var idxs = family_indices()
    var backends = battery_backends()
    if len(idxs) != 5 or len(backends) != 4:
        raise Error("A126: axes must be 5 families x 4 backends")
    var report = run_battery()
    if report.total != 20 or len(report.rows) != 20:
        raise Error("A126: battery must file exactly 20 rows")
    if backends[0] != String("cpu") or backends[3] != String("npu"):
        raise Error("A126: backends must be the A-109 harness list")


def test_special_enumeration_unique() raises:
    var report = run_battery()
    for i in range(len(report.rows)):
        for j in range(i + 1, len(report.rows)):
            if (
                report.rows[i].family == report.rows[j].family
                and report.rows[i].backend == report.rows[j].backend
            ):
                raise Error("A126: duplicate row in enumeration")


def test_special_policy_obligation() raises:
    if policy_obligation() != POLICY_TOKEN_EXACTNESS_OWED:
        raise Error("A126: Q4_K_M obligation must be owed, by call")
    var report = run_battery()
    if report.owed != 20 or report.coherence != 0:
        raise Error("A126: every row carries the owed obligation")


def test_special_cpu_faithful() raises:
    var report = run_battery()
    for fam in range(1, 4):
        var r = _row(report, fam, String("cpu"))
        if r.verdict != MX_FAITHFUL:
            raise Error("A126: qwen2/qwen3/gemma4 cpu rows must be FAITHFUL")
        if r.reason != String("SPECIAL_TOKEN_CHECKS_PASS"):
            raise Error("A126: faithful cpu row reason mismatch")
        if r.scenarios != SB_SCENARIOS or r.scenarios_agree != SB_SCENARIOS:
            raise Error("A126: faithful cpu rows agree on all scenarios")


def test_special_llama_divergent_stop_set() raises:
    var report = run_battery()
    var r = _row(report, 0, String("cpu"))
    if r.verdict != MX_DIVERGENT:
        raise Error("A126: llama cpu row must be DIVERGENT")
    if r.reason != String("STOP_SET_INCOMPLETE"):
        raise Error("A126: llama cpu divergence reason mismatch")
    if r.eos_id != 128001 or r.turn_id != 128009 or r.bos_id != 128000:
        raise Error("A126: llama filed ids mismatch")
    if r.scenarios_agree != SB_SCENARIOS - 1:
        raise Error("A126: llama grid must disagree on exactly one scenario")
    if scenario_agrees(family_specs()[0], 1):
        raise Error("A126: llama TURN scenario must disagree")
    var cfg = GenerationConfig(max_new_tokens=16)
    if generation_stop_reason(128001, 128009, 1, cfg, 8, 128) != String(""):
        raise Error("A126: filed A-104 mirror -- eos metadata 128009 misses 128001")
    for s in range(SB_SCENARIOS):
        if s == 1:
            continue
        if not scenario_agrees(family_specs()[0], s):
            raise Error("A126: llama non-TURN scenarios must agree")


def test_special_backend_not_graded() raises:
    var report = run_battery()
    var non_cpu = List[String]()
    non_cpu.append(String("vulkan"))
    non_cpu.append(String("hip"))
    non_cpu.append(String("npu"))
    for fam in range(5):
        for bi in range(len(non_cpu)):
            var r = _row(report, fam, non_cpu[bi])
            if r.verdict != MX_NOT_GRADED:
                raise Error("A126: non-cpu rows must be NOT_GRADED")
            if r.reason != String("BACKEND_NO_CPU_COMPARATOR"):
                raise Error("A126: non-cpu reason mismatch")
    var m = _row(report, 4, String("cpu"))
    if m.verdict != MX_NOT_GRADED or m.reason != String("NO_FILED_SURFACE"):
        raise Error("A126: mistral3 cpu row must be NOT_GRADED/NO_FILED_SURFACE")
    if report.not_graded != 16:
        raise Error("A126: exactly 16 NOT_GRADED rows")


def test_special_spec_profiles_by_call() raises:
    var specs = family_specs()
    var llama = llama3_8b_profile()
    var llama32 = llama3_2_3b_profile()
    if specs[0].eos_id != llama.eos_token_id or specs[0].turn_id != llama.end_of_turn_token_id:
        raise Error("A126: llama spec must read the 8B profile by call")
    if llama32.eos_token_id != specs[0].eos_id or llama32.end_of_turn_token_id != specs[0].turn_id:
        raise Error("A126: llama 3.2 profile must agree on eos/turn")
    if specs[0].add_bos != llama.add_bos or not specs[0].add_bos:
        raise Error("A126: llama add_bos must be the profile's True")
    var q2 = qwen2_coder_7b_profile()
    var q3 = qwen3_0_6b_profile()
    if specs[1].eos_id != q2.eos_token_id or specs[1].turn_id != q2.end_of_turn_token_id:
        raise Error("A126: qwen2 spec must read its profile by call")
    if specs[2].eos_id != q3.eos_token_id or specs[2].turn_id != q3.end_of_turn_token_id:
        raise Error("A126: qwen3 spec must read its profile by call")
    if specs[1].add_bos or specs[2].add_bos:
        raise Error("A126: qwen add_bos must be False per the profiles")
    if specs[1].bos_id != SB_FROM_METADATA or specs[2].bos_id != SB_FROM_METADATA:
        raise Error("A126: qwen engine bos must file the metadata sentinel")
    if specs[3].eos_id != SB_FROM_METADATA or specs[3].bos_id != SB_FROM_METADATA:
        raise Error("A126: gemma4 ids must file the metadata sentinel")
    if specs[3].eos_spelling != String("<eos>") or specs[3].bos_spelling != String("<bos>"):
        raise Error("A126: gemma4 spellings mismatch")
    if specs[4].has_surface:
        raise Error("A126: mistral3 must file no surface")
    for i in range(5):
        if specs[i].pad_id != SB_NO_PAD:
            raise Error("A126: every family files NO_PAD_SURFACE")


def test_special_bos_rule_execution() raises:
    var specs = family_specs()
    for i in range(5):
        if specs[i].has_surface and not bos_rule_ok(specs[i]):
            raise Error("A126: BOS rule must execute clean per family")
    var llama = specs[0]
    if not llama.add_bos:
        raise Error("A126: llama files add_bos True")
    var report = run_battery()
    var r = _row(report, 1, String("cpu"))
    if r.add_bos:
        raise Error("A126: qwen2 row must file add_bos false")


def test_special_engine_stop_transcription() raises:
    var cfg = GenerationConfig(max_new_tokens=16)
    var stops = List[Int]()
    stops.append(4242)
    var cfg_stop = GenerationConfig(max_new_tokens=16, stop_tokens=stops.copy())
    var specs = family_specs()
    for fam in range(3):
        var spec = specs[fam]
        var cases = List[Int]()
        cases.append(spec.eos_id)
        cases.append(spec.turn_id)
        cases.append(777)
        for ci in range(len(cases)):
            var t = cases[ci]
            var real = generation_stop_reason(t, spec.eos_id, 1, cfg, 8, 128)
            var mine = engine_stop_reason(spec.engine_eos, t, 1, 16, 8, 128, List[Int]())
            if real != mine:
                raise Error("A126: transcription must match the real rule")
        var real_stop = generation_stop_reason(4242, spec.eos_id, 1, cfg_stop, 8, 128)
        if real_stop != String("stop_token"):
            raise Error("A126: real rule must file stop_token")
        if generation_stop_reason(777, spec.eos_id, 16, cfg, 8, 128) != String("length"):
            raise Error("A126: real rule must file length")
        if generation_stop_reason(777, spec.eos_id, 1, cfg, 128, 128) != String("context_exhausted"):
            raise Error("A126: real rule must file context_exhausted")
    var filed = generation_stop_reason(128009, 128001, 1, cfg, 8, 128)
    if filed != String(""):
        raise Error("A126: filed fact -- the real CPU rule does not stop on <|eot_id|>")
    if generation_stop_reason(128001, 128001, 1, cfg, 8, 128) != String("eos"):
        raise Error("A126: real rule must stop on the eos id")


def test_special_scenario_grid() raises:
    var specs = family_specs()
    for fam in range(1, 4):
        for s in range(SB_SCENARIOS):
            if not scenario_agrees(specs[fam], s):
                raise Error("A126: faithful families agree on every scenario")
    if scenario_spec_reason(specs[0], 0) != String("eos"):
        raise Error("A126: EOS scenario must file eos")
    if scenario_spec_reason(specs[0], 1) != String("eos"):
        raise Error("A126: llama TURN scenario must file eos on the spec side")
    if scenario_engine_reason(specs[0], 1) != String(""):
        raise Error("A126: llama TURN scenario must file continue on the engine side")
    if scenario_spec_reason(specs[0], 2) != String("stop_token"):
        raise Error("A126: STOP scenario must file stop_token")
    if scenario_spec_reason(specs[0], 3) != String("length"):
        raise Error("A126: LENGTH scenario must file length")
    if scenario_spec_reason(specs[0], 4) != String("context_exhausted"):
        raise Error("A126: CONTEXT scenario must file context_exhausted")
    if scenario_spec_reason(specs[0], 5) != String(""):
        raise Error("A126: CONTINUE scenario must file continue")
    if scenario_spec_reason(specs[3], 0) != String("eos"):
        raise Error("A126: gemma4 EOS scenario must file eos (proxy id)")
    if scenario_engine_reason(specs[3], 0) != String("eos"):
        raise Error("A126: gemma4 EOS scenario must file eos on the engine side")


def test_special_synthetic_labelled() raises:
    if String(SB_FIXTURE_STATUS) != String("SYNTHETIC"):
        raise Error("A126: fixture status must be SYNTHETIC")
    var report = run_battery()
    var render = battery_render(report.copy())
    if String("SYNTHETIC") not in render:
        raise Error("A126: render must carry the SYNTHETIC label")
    if String("ST_SYN case=SYN_OK status=SYNTHETIC") not in render:
        raise Error("A126: every syn line must be labelled SYNTHETIC")


def test_special_synthetic_defects() raises:
    var syn = syn_cases()
    if len(syn) != 5:
        raise Error("A126: synthetic fixture must file 5 cases")
    if syn[0].verdict != MX_FAITHFUL or syn[0].reason != String("SYNTHETIC_SPEC_GRID_MATCH"):
        raise Error("A126: SYN_OK must be FAITHFUL")
    if syn[1].verdict != MX_DIVERGENT or syn[1].reason != String("STOP_SET_INCOMPLETE"):
        raise Error("A126: SYN_EOS_ONLY must be DIVERGENT/STOP_SET_INCOMPLETE")
    if syn[2].verdict != MX_DIVERGENT or syn[2].reason != String("TURN_TOKEN_NOT_A_STOP"):
        raise Error("A126: SYN_TURN_AS_TEXT must be DIVERGENT")
    if syn[3].verdict != MX_DIVERGENT or syn[3].reason != String("PAD_TOKEN_AS_STOP"):
        raise Error("A126: SYN_PAD_AS_EOS must be DIVERGENT")
    if syn[4].verdict != MX_COMPARATOR_ARTIFACT or syn[4].reason != String("BACKEND_MISMATCH"):
        raise Error("A126: SYN_MISMATCH must be COMPARATOR_ARTIFACT")
    var report = run_battery()
    if report.syn_faithful != 1 or report.syn_divergent != 3 or report.syn_artifact != 1:
        raise Error("A126: synthetic summary must be 1/3/1")


def test_special_summary_sums() raises:
    var report = run_battery()
    if report.total != 20 or report.faithful != 3 or report.divergent != 1:
        raise Error("A126: summary must be 20 total, 3 faithful, 1 divergent")
    if report.near_tie != 0 or report.artifact != 0 or report.fixture_limited != 0:
        raise Error("A126: no near-tie/artifact/fixture rows are filed")
    if report.tf_total != 20 or report.tf_graded != 0 or report.tf_not_graded != 20:
        raise Error("A126: TF account must file 20/0/20 NOT_GRADED")
    var again = run_battery()
    if again.digest != report.digest:
        raise Error("A126: digest must be deterministic across re-runs")
    if battery_render(report.copy()) != battery_render(again.copy()):
        raise Error("A126: render must be deterministic")
    if battery_line().byte_length() == 0 or battery_row_line(report.rows[0]).byte_length() == 0:
        raise Error("A126: line renderers must produce output")
    var bad_families = List[Int]()
    bad_families.append(9)
    if not _raises_build(bad_families, battery_backends()):
        raise Error("A126: out-of-range family axis must be refused")
    var dup_backends = List[String]()
    dup_backends.append(String("cpu"))
    dup_backends.append(String("cpu"))
    if not _raises_build(family_indices(), dup_backends):
        raise Error("A126: duplicate backend axis must be refused")
    var empty = List[Int]()
    if not _raises_build(empty, battery_backends()):
        raise Error("A126: empty family axis must be refused")
    var obligation_row = battery_row_verdict(
        0, family_specs()[0], String("vulkan"), policy_obligation()
    )
    if obligation_row.verdict != MX_NOT_GRADED:
        raise Error("A126: row verdict helper must file NOT_GRADED off-cpu")
    _ = obligation_row
