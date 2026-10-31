"""Auto choice for draft-check passes (J-042): the
pre-registered decision rule on injected measurement sets (a
clear winner is chosen; within-noise falls back to the session
default with the failed hurdle stated; the default
fastest-but-unproven is kept as the default, not claimed as a
win; a sole measured candidate is chosen as sole-measured) --
the rule branches Part V's real measurements will one day flow
through -- and, as this slice's honesty core, the
all-unmeasurable field the tree actually produces today: every
candidate UNMEASURABLE-WITH-REASON (J-035 gap G1) flowing
through the decision to NO-MEASURED-FALLBACK with the cpu
present and REFUSAL without it, manual forms fixing the choice
with their unmeasurable state on the record (and the J-036 use
gate still closed), a race carried unranked to the same
fallback, session keeping (decide once, refuse a second
decision naming J-045, byte-identical reports), and live runs
of the chooser over the real J-038 harness + J-039 thread
trials on this machine.

The live groups measure NOTHING: draft-check has no pass and
no workload executor in this tree, so no timing exists to
report and none is claimed. No number in this suite is a
placement verdict for any model; the live outcome this slice
expects and pins is the fallback, with every candidate's G1
reason on the record.
"""
from core.device_inventory import observe_device_inventory
from core.placement_harness import HarnessConfig, TimingSummary
from core.placement_options import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NPU,
    PASS_DRAFTS,
    SOURCE_DEFAULT,
    PlacementChoice,
    PlacementOptions,
    RawPlacementInputs,
    parse_placement_value,
    require_draft_check_use,
    resolve_placement_options,
)
from core.draft_placement import (
    DEC_DEFAULT_BY_NOISE,
    DEC_DEFAULT_CONFIRMED,
    DEC_MANUAL_FIXED,
    DEC_MEASURED_WIN,
    DEC_NO_MEASURED_FALLBACK,
    DEC_REFUSAL,
    DEC_SOLE_MEASURED,
    PM_EXCLUDED,
    PM_MEASURED,
    PM_UNMEASURABLE,
    DraftMeasurement,
    DraftPlacementSession,
    choose_draft_placement,
    decide_draft_choice,
)
from core.thread_topology import observe_cpu_facts

# The harness's own G1 reason, verbatim in shape (J-038): the
# fixture text the synthetic groups inject, and the substring
# the live groups assert the real classification carries.
comptime G1_REASON = (
    "draft-check passes do not exist in Aesir yet (J-035"
    " gap G1; Part V J-071/J-072 own building the pass) --"
    " there is no draft-check pass to measure, and no"
    " synthetic proxy is measured in its name"
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "DraftPlacement "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("DraftPlacement " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "DraftPlacement "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


def _measured(
    label: String, device: Int, threads: Int, median: Int, max_ns: Int
) -> DraftMeasurement:
    var m = DraftMeasurement()
    m.label = label
    m.device = device
    m.threads = threads
    m.status = PM_MEASURED
    m.summary.count = 5
    m.summary.median_ns = median
    m.summary.min_ns = median - (max_ns - median)
    m.summary.max_ns = max_ns
    m.summary.spread_ns = max_ns - m.summary.min_ns
    return m


def _unmeasured(
    label: String, device: Int, status: Int, reason: String
) -> DraftMeasurement:
    var m = DraftMeasurement()
    m.label = label
    m.device = device
    m.threads = 0
    m.status = status
    m.reason = reason
    return m


def _auto() raises -> PlacementChoice:
    return parse_placement_value("auto", PASS_DRAFTS)


def test_clear_winner() raises:
    # Synthetic measured set: the ranked branches of the
    # adopted rule, pinned for the day Part V feeds them real
    # measurements. Nothing live measures in this slice.
    var measurements = List[DraftMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 1000, 1100)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 400, 450)
    )
    measurements.append(
        _measured("cpu threads=4", DEVICE_CPU, 4, 900, 990)
    )
    var record = decide_draft_choice(
        measurements, _auto(), SOURCE_DEFAULT, True
    )
    expect_eq(record.decision_code, DEC_MEASURED_WIN, "clear winner decision")
    expect_true(record.has_choice, "clear winner has a choice")
    expect_eq(record.chosen_threads, 2, "the winning rung is chosen")
    expect_eq(record.margin_percent, 125, "margin over the runner-up")
    expect_true(record.separation_ok, "separation holds for a clear winner")
    expect_contains(
        record.report(), "chosen: cpu threads=2", "report names the winner"
    )
    print("PASS: decision rule -- a clear winner is chosen (measured win)")


def test_within_noise_margin() raises:
    var measurements = List[DraftMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 1000, 1100)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 960, 1050)
    )
    var record = decide_draft_choice(
        measurements, _auto(), SOURCE_DEFAULT, True
    )
    expect_eq(
        record.decision_code, DEC_DEFAULT_BY_NOISE, "within-noise decision"
    )
    expect_eq(record.chosen_threads, 1, "the default is kept")
    expect_contains(
        record.decision_text,
        "inside the 10% band",
        "the failed margin hurdle is stated with its band",
    )
    print("PASS: decision rule -- within the margin band, default kept with reason")


def test_within_noise_separation() raises:
    # The margin clears (25%) but the winner's slowest round does
    # not beat the runner-up's median: the rounds interleave.
    var measurements = List[DraftMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 1000, 1090)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 800, 1200)
    )
    var record = decide_draft_choice(
        measurements, _auto(), SOURCE_DEFAULT, True
    )
    expect_eq(
        record.decision_code,
        DEC_DEFAULT_BY_NOISE,
        "separation failure decision",
    )
    expect_true(not record.separation_ok, "separation is recorded failed")
    expect_contains(
        record.decision_text,
        "interleave",
        "the failed separation hurdle is stated",
    )
    print("PASS: decision rule -- margin clears but rounds interleave, default kept")


def test_default_fastest_unproven() raises:
    var measurements = List[DraftMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 900, 990)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 950, 1040)
    )
    var record = decide_draft_choice(
        measurements, _auto(), SOURCE_DEFAULT, True
    )
    expect_eq(
        record.decision_code,
        DEC_DEFAULT_CONFIRMED,
        "default-fastest decision",
    )
    expect_eq(record.chosen_threads, 1, "the default is chosen")
    expect_contains(
        record.decision_text,
        "kept as the default",
        "the win is withheld, the keeping is stated",
    )
    print("PASS: decision rule -- default fastest but unproven, kept as default")


def test_sole_measured() raises:
    var measurements = List[DraftMeasurement]()
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 700, 770)
    )
    measurements.append(
        _unmeasured(
            "gpu (auto)",
            DEVICE_GPU,
            PM_UNMEASURABLE,
            G1_REASON,
        )
    )
    var record = decide_draft_choice(
        measurements, _auto(), SOURCE_DEFAULT, True
    )
    expect_eq(record.decision_code, DEC_SOLE_MEASURED, "sole-measured decision")
    expect_eq(record.chosen_threads, 2, "the sole candidate is chosen")
    expect_contains(
        record.decision_text,
        "no margin is claimed",
        "sole-measured claims no victory",
    )
    expect_contains(
        record.report(),
        "UNMEASURABLE",
        "the unmeasurable candidate rides on the report with its reason",
    )
    print("PASS: decision rule -- sole measured candidate chosen, no margin claimed")


def test_unmeasurable_fallback_and_refusal() raises:
    # The honesty core, in pure form: the field this tree
    # actually produces -- every candidate unmeasurable with
    # the G1 reason -- flows to the fallback, never to a rank.
    var measurements = List[DraftMeasurement]()
    measurements.append(
        _unmeasured("cpu (auto)", DEVICE_CPU, PM_UNMEASURABLE, G1_REASON)
    )
    measurements.append(
        _unmeasured("gpu (auto)", DEVICE_GPU, PM_UNMEASURABLE, G1_REASON)
    )
    measurements.append(
        _unmeasured("npu (auto)", DEVICE_NPU, PM_UNMEASURABLE, G1_REASON)
    )
    var rung = _unmeasured(
        "cpu threads=1 (serial)", DEVICE_CPU, PM_UNMEASURABLE, G1_REASON
    )
    rung.threads = 1
    measurements.append(rung)
    var fallback = decide_draft_choice(
        measurements, _auto(), SOURCE_DEFAULT, True
    )
    expect_eq(
        fallback.decision_code,
        DEC_NO_MEASURED_FALLBACK,
        "all-unmeasurable fallback decision",
    )
    expect_true(fallback.has_choice, "the fallback is a choice")
    expect_eq(fallback.chosen_threads, 1, "the fallback is the default")
    expect_true(
        fallback.best_median_ns < 0, "no best exists on an unmeasured field"
    )
    expect_contains(
        fallback.decision_text,
        "gap G1",
        "the fallback states the absence it stands on",
    )
    expect_contains(
        fallback.decision_text,
        "a kept label only",
        "the fallback states the default runs nothing today",
    )
    expect_contains(
        fallback.report(),
        "no synthetic proxy is measured in its name",
        "every candidate's G1 reason rides on the report verbatim",
    )
    var refusal = decide_draft_choice(
        measurements, _auto(), SOURCE_DEFAULT, False
    )
    expect_eq(refusal.decision_code, DEC_REFUSAL, "no-cpu refusal decision")
    expect_true(not refusal.has_choice, "a refusal claims no choice")
    expect_contains(
        refusal.report(),
        "chosen: NONE",
        "the refusal report claims no placement",
    )
    print("PASS: unmeasurable field -- fallback with cpu, refusal without")


def test_manual_respected() raises:
    var measurements = List[DraftMeasurement]()
    measurements.append(
        _measured("cpu", DEVICE_CPU, 0, 300, 330)
    )
    measurements.append(
        _unmeasured("gpu", DEVICE_GPU, PM_UNMEASURABLE, G1_REASON)
    )
    var single = parse_placement_value("gpu", PASS_DRAFTS)
    var record = decide_draft_choice(
        measurements, single, SOURCE_DEFAULT, True
    )
    expect_eq(record.decision_code, DEC_MANUAL_FIXED, "manual decision")
    expect_eq(record.chosen_device, DEVICE_GPU, "the manual device stands")
    expect_contains(
        record.decision_text,
        "the auto rule was not applied",
        "the manual record states auto was not applied",
    )
    expect_contains(
        record.decision_text,
        "UNMEASURABLE",
        "the manual candidate's unmeasurable state is reported, not hidden",
    )
    expect_contains(
        record.decision_text,
        "require_draft_check_use()",
        "the manual record states the use gate still stands",
    )
    expect_contains(
        record.decision_text,
        "choosing is not using",
        "the manual record separates choosing from using",
    )
    var cowork_measurements = List[DraftMeasurement]()
    cowork_measurements.append(
        _measured("cpu", DEVICE_CPU, 0, 300, 330)
    )
    cowork_measurements.append(
        _unmeasured("cpu+gpu", DEVICE_CPU, PM_UNMEASURABLE, G1_REASON)
    )
    var cowork = parse_placement_value("cpu+gpu", PASS_DRAFTS)
    var cowork_record = decide_draft_choice(
        cowork_measurements, cowork, SOURCE_DEFAULT, True
    )
    expect_eq(
        cowork_record.decision_code, DEC_MANUAL_FIXED, "co-work decision"
    )
    expect_true(
        cowork_record.chosen_label == "cpu+gpu",
        "the co-work choice stands as written",
    )
    # An explicit drafts option naming the NPU is refused at
    # parse (J-036) and never reaches the chooser at all.
    var npu_refused = False
    try:
        _ = parse_placement_value("npu", PASS_DRAFTS)
    except:
        npu_refused = True
    expect_true(npu_refused, "an explicit npu drafts option is refused at parse")
    print("PASS: manual single and co-work fix the choice; npu refused at parse")


def test_race_carried_unranked() raises:
    # Synthetic: the pure rule ranks a race's named members
    # only -- an unnamed device's faster number never wins.
    var race = parse_placement_value("cpu,gpu", PASS_DRAFTS)
    var measurements = List[DraftMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 1000, 1100)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 400, 450)
    )
    measurements.append(
        _measured("npu threads=0", DEVICE_NPU, 0, 100, 110)
    )
    var record = decide_draft_choice(
        measurements, race, SOURCE_DEFAULT, True
    )
    expect_eq(record.decision_code, DEC_MEASURED_WIN, "race decision")
    expect_eq(
        record.chosen_threads, 2, "the race winner is a named member"
    )
    expect_true(
        record.best_label == "cpu threads=2",
        "a non-member's faster number never becomes best",
    )
    # The live shape of a race today: every member unmeasurable,
    # so the race is carried unranked to the same fallback.
    var unmeasured = List[DraftMeasurement]()
    unmeasured.append(
        _unmeasured("cpu (race)", DEVICE_CPU, PM_UNMEASURABLE, G1_REASON)
    )
    unmeasured.append(
        _unmeasured("gpu (race)", DEVICE_GPU, PM_UNMEASURABLE, G1_REASON)
    )
    var carried = decide_draft_choice(
        unmeasured, race, SOURCE_DEFAULT, True
    )
    expect_eq(
        carried.decision_code,
        DEC_NO_MEASURED_FALLBACK,
        "an all-unmeasurable race falls back, unranked",
    )
    expect_eq(carried.chosen_threads, 1, "the race fallback is the default")
    print("PASS: race ranks members only; unmeasurable race carried unranked")


def test_session_keeping() raises:
    var measurements = List[DraftMeasurement]()
    measurements.append(
        _unmeasured("cpu (auto)", DEVICE_CPU, PM_UNMEASURABLE, G1_REASON)
    )
    var record = decide_draft_choice(
        measurements, _auto(), SOURCE_DEFAULT, True
    )
    var session = DraftPlacementSession()
    expect_contains(
        session.report(),
        "not decided",
        "an undecided session reports exactly that",
    )
    session.decide_once(record)
    expect_eq(session.decisions_made, 1, "one decision was made")
    var first = session.report()
    var second = session.report()
    expect_true(first == second, "session reports are byte-identical")
    expect_contains(first, "chosen: cpu threads=1", "the kept choice reports")
    var refused = False
    var refusal_text = String("")
    try:
        session.decide_once(record)
    except refusal:
        refused = True
        refusal_text = String(refusal)
    expect_true(refused, "a second decision for one session is refused")
    expect_contains(
        refusal_text,
        "J-045",
        "the second-decision refusal names the re-trial road",
    )
    expect_eq(session.decisions_made, 1, "the refusal changed nothing")
    expect_true(
        session.report() == first, "the kept record is unchanged by the refusal"
    )
    print("PASS: session keeping -- decided once, kept, reports identical")


def test_live_chooser() raises:
    var options = resolve_placement_options(
        RawPlacementInputs(), RawPlacementInputs()
    )
    var inventory = observe_device_inventory()
    var facts = observe_cpu_facts()
    var record = choose_draft_placement(
        options, inventory, facts, HarnessConfig()
    )
    print("LIVE DRAFT-CHECK CHOICE:\n" + record.report())
    expect_eq(
        record.decision_code,
        DEC_NO_MEASURED_FALLBACK,
        "the live decision is the pre-registered fallback",
    )
    expect_true(record.has_choice, "the live chooser produced the fallback")
    expect_eq(
        record.chosen_device, DEVICE_CPU, "the live choice is the cpu default"
    )
    expect_eq(record.chosen_threads, 1, "the live choice is the serial rung")
    expect_true(
        record.best_median_ns < 0, "the live record claims no best"
    )
    var saw_device = False
    var saw_rung = False
    for m in record.measurements:
        expect_eq(
            m.status,
            PM_UNMEASURABLE,
            "every live candidate is unmeasurable-with-reason",
        )
        expect_contains(
            m.reason, "gap G1", "every live candidate names gap G1"
        )
        if m.threads == 0:
            saw_device = True
        else:
            saw_rung = True
    expect_true(saw_device, "the device axis is on the live record")
    expect_true(saw_rung, "the thread ladder is on the live record")
    expect_contains(
        record.report(),
        "UNMEASURABLE",
        "the live report states unmeasurability in the open",
    )
    expect_contains(
        record.report(),
        "no timing stands for this kind on either axis",
        "the live record states no timing stands",
    )
    var session = DraftPlacementSession()
    session.decide_once(record)
    expect_true(
        session.report() == record.report(),
        "the session keeps the live record verbatim",
    )
    print("PASS: live chooser -- all-unmeasurable field, fallback outcome")


def test_live_manual() raises:
    var cli = RawPlacementInputs()
    cli.drafts = "cpu"
    cli.drafts_set = True
    var options = resolve_placement_options(cli, RawPlacementInputs())
    var inventory = observe_device_inventory()
    var facts = observe_cpu_facts()
    var record = choose_draft_placement(
        options, inventory, facts, HarnessConfig()
    )
    print("LIVE MANUAL DRAFT-CHECK CHOICE:\n" + record.report())
    expect_eq(record.decision_code, DEC_MANUAL_FIXED, "live manual decision")
    expect_true(record.chosen_label == "cpu", "the manual cpu choice stands")
    expect_contains(
        record.decision_text,
        "UNMEASURABLE",
        "the live manual record carries the unmeasurable state",
    )
    expect_contains(
        record.decision_text,
        "require_draft_check_use()",
        "the live manual record states the use gate",
    )
    var cli2 = RawPlacementInputs()
    cli2.drafts = "cpu+gpu"
    cli2.drafts_set = True
    var options2 = resolve_placement_options(cli2, RawPlacementInputs())
    var cowork = choose_draft_placement(
        options2, inventory, facts, HarnessConfig()
    )
    print("LIVE MANUAL DRAFT-CHECK CO-WORK CHOICE:\n" + cowork.report())
    expect_eq(
        cowork.decision_code, DEC_MANUAL_FIXED, "live co-work decision"
    )
    expect_true(
        cowork.chosen_label == "cpu+gpu", "the co-work choice stands as written"
    )
    print("PASS: live manual single and co-work fix the choice, unranked")


def test_live_race_and_use_gate() raises:
    var cli = RawPlacementInputs()
    cli.drafts = "cpu,gpu"
    cli.drafts_set = True
    var options = resolve_placement_options(cli, RawPlacementInputs())
    var inventory = observe_device_inventory()
    var facts = observe_cpu_facts()
    var record = choose_draft_placement(
        options, inventory, facts, HarnessConfig()
    )
    print("LIVE DRAFT-CHECK RACE CHOICE:\n" + record.report())
    expect_eq(
        record.decision_code,
        DEC_NO_MEASURED_FALLBACK,
        "the live race is carried unranked to the fallback",
    )
    expect_eq(record.chosen_threads, 1, "the race fallback is the default")
    # The chooser never weakens J-036's gate: using a drafts
    # placement -- any value, including the ones just chosen --
    # still raises, naming G1 and Part V.
    var gate_text = String("")
    var gate_raised = False
    try:
        require_draft_check_use()
    except gate:
        gate_raised = True
        gate_text = String(gate)
    expect_true(gate_raised, "draft-check use still fails closed (J-036)")
    expect_contains(gate_text, "gap G1", "the use gate names gap G1")
    expect_contains(
        gate_text, "J-071/J-072", "the use gate names Part V as its owner"
    )
    print("PASS: live race unranked; the J-036 use gate still fails closed")


def main() raises:
    test_clear_winner()
    test_within_noise_margin()
    test_within_noise_separation()
    test_default_fastest_unproven()
    test_sole_measured()
    test_unmeasurable_fallback_and_refusal()
    test_manual_respected()
    test_race_carried_unranked()
    test_session_keeping()
    test_live_chooser()
    test_live_manual()
    test_live_race_and_use_gate()
    print("ALL PASS: draft-check placement auto choice (12 groups)")
