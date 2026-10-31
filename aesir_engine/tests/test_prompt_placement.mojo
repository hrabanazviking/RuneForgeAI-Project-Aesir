"""Auto choice for prompt passes (J-040): the pre-registered
decision rule on injected measurement sets (a clear winner is
chosen; within-noise falls back to the session default with the
failed hurdle stated; the default fastest-but-unproven is kept
as the default, not claimed as a win; a sole measured candidate
is chosen as sole-measured; no measured candidate falls back
when the cpu is present and refuses when it is not), manual
forms fixing the choice against faster measured candidates, a
race ranking only its named members, session keeping (decide
once, refuse a second decision, byte-identical reports), and a
live run of the chooser over the real J-038 harness + J-039
thread trials on this machine.

The live group measures HARNESS MECHANICS only: the workloads
are the harness's own prompt-shaped micro-workload, not a model
pass, and no number here is a placement verdict for any model.
Under this VM's contention the honest live outcome may be a
default-by-noise record; that is a legitimate filed result
(J-039's flip finding), not a failure.
"""
from core.device_inventory import observe_device_inventory
from core.placement_harness import HarnessConfig, TimingSummary
from core.placement_options import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NPU,
    PASS_PROMPT,
    SOURCE_DEFAULT,
    PlacementChoice,
    PlacementOptions,
    RawPlacementInputs,
    parse_placement_value,
    resolve_placement_options,
)
from core.prompt_placement import (
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
    PromptMeasurement,
    PromptPlacementSession,
    choose_prompt_placement,
    decide_prompt_choice,
)
from core.thread_topology import observe_cpu_facts


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PromptPlacement "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("PromptPlacement " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "PromptPlacement "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


def _measured(
    label: String, device: Int, threads: Int, median: Int, max_ns: Int
) -> PromptMeasurement:
    var m = PromptMeasurement()
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
) -> PromptMeasurement:
    var m = PromptMeasurement()
    m.label = label
    m.device = device
    m.threads = 0
    m.status = status
    m.reason = reason
    return m


def _auto() raises -> PlacementChoice:
    return parse_placement_value("auto", PASS_PROMPT)


def test_clear_winner() raises:
    var measurements = List[PromptMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 1000, 1100)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 400, 450)
    )
    measurements.append(
        _measured("cpu threads=4", DEVICE_CPU, 4, 900, 990)
    )
    var record = decide_prompt_choice(
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
    var measurements = List[PromptMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 1000, 1100)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 960, 1050)
    )
    var record = decide_prompt_choice(
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
    var measurements = List[PromptMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 1000, 1090)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 800, 1200)
    )
    var record = decide_prompt_choice(
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
    var measurements = List[PromptMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 900, 990)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 950, 1040)
    )
    var record = decide_prompt_choice(
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
    var measurements = List[PromptMeasurement]()
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 700, 770)
    )
    measurements.append(
        _unmeasured(
            "gpu (auto)",
            DEVICE_GPU,
            PM_EXCLUDED,
            "DeviceInventory: gpu was requested, but ... (fixture)",
        )
    )
    var record = decide_prompt_choice(
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
        "EXCLUDED",
        "the exclusion rides on the report with its reason",
    )
    print("PASS: decision rule -- sole measured candidate chosen, no margin claimed")


def test_no_measured_fallback_and_refusal() raises:
    var measurements = List[PromptMeasurement]()
    measurements.append(
        _unmeasured(
            "gpu (auto)",
            DEVICE_GPU,
            PM_EXCLUDED,
            "DeviceInventory: gpu was requested, but ... (fixture)",
        )
    )
    measurements.append(
        _unmeasured(
            "cpu threads=1",
            DEVICE_CPU,
            PM_UNMEASURABLE,
            "fixture: no executor stood up",
        )
    )
    var fallback = decide_prompt_choice(
        measurements, _auto(), SOURCE_DEFAULT, True
    )
    expect_eq(
        fallback.decision_code,
        DEC_NO_MEASURED_FALLBACK,
        "no-measured fallback decision",
    )
    expect_true(fallback.has_choice, "the fallback is a choice")
    expect_eq(fallback.chosen_threads, 1, "the fallback is the default")
    var refusal = decide_prompt_choice(
        measurements, _auto(), SOURCE_DEFAULT, False
    )
    expect_eq(refusal.decision_code, DEC_REFUSAL, "all-excluded refusal")
    expect_true(not refusal.has_choice, "a refusal claims no choice")
    expect_contains(
        refusal.report(),
        "chosen: NONE",
        "the refusal report claims no placement",
    )
    print("PASS: decision rule -- no measured: fallback with cpu, refusal without")


def test_manual_respected() raises:
    var measurements = List[PromptMeasurement]()
    measurements.append(
        _measured("cpu", DEVICE_CPU, 0, 300, 330)
    )
    measurements.append(
        _unmeasured(
            "gpu",
            DEVICE_GPU,
            PM_UNMEASURABLE,
            "no gpu workload executor exists in this harness yet (fixture)",
        )
    )
    var single = parse_placement_value("gpu", PASS_PROMPT)
    var record = decide_prompt_choice(
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
        "the manual candidate's executability is reported, not hidden",
    )
    var cowork_measurements = List[PromptMeasurement]()
    cowork_measurements.append(
        _measured("cpu", DEVICE_CPU, 0, 300, 330)
    )
    cowork_measurements.append(
        _unmeasured(
            "cpu+gpu",
            DEVICE_CPU,
            PM_UNMEASURABLE,
            "co-work execution does not exist in the tree yet (fixture)",
        )
    )
    var cowork = parse_placement_value("cpu+gpu", PASS_PROMPT)
    var cowork_record = decide_prompt_choice(
        cowork_measurements, cowork, SOURCE_DEFAULT, True
    )
    expect_eq(
        cowork_record.decision_code, DEC_MANUAL_FIXED, "co-work decision"
    )
    expect_true(
        cowork_record.chosen_label == "cpu+gpu",
        "the co-work choice stands as written",
    )
    print("PASS: manual single and co-work fix the choice against faster numbers")


def test_race_ranks_members_only() raises:
    # The race names cpu+gpu; an npu measurement (a device the
    # race did NOT name) is faster than every member and must
    # never win -- ranking is over the named members only.
    var race = parse_placement_value("cpu,gpu", PASS_PROMPT)
    var measurements = List[PromptMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 1000, 1100)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 400, 450)
    )
    measurements.append(
        _measured("npu threads=0", DEVICE_NPU, 0, 100, 110)
    )
    var record = decide_prompt_choice(
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
    print("PASS: race ranks only its named members (non-member speed ignored)")


def test_session_keeping() raises:
    var measurements = List[PromptMeasurement]()
    measurements.append(
        _measured("cpu threads=1", DEVICE_CPU, 1, 1000, 1100)
    )
    measurements.append(
        _measured("cpu threads=2", DEVICE_CPU, 2, 400, 450)
    )
    var record = decide_prompt_choice(
        measurements, _auto(), SOURCE_DEFAULT, True
    )
    var session = PromptPlacementSession()
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
    expect_contains(first, "chosen: cpu threads=2", "the kept choice reports")
    var refused = False
    try:
        session.decide_once(record)
    except:
        refused = True
    expect_true(refused, "a second decision for one session is refused")
    expect_eq(session.decisions_made, 1, "the refusal changed nothing")
    print("PASS: session keeping -- decided once, kept, reports identical")


def test_live_chooser() raises:
    var options = resolve_placement_options(
        RawPlacementInputs(), RawPlacementInputs()
    )
    var inventory = observe_device_inventory()
    var facts = observe_cpu_facts()
    var record = choose_prompt_placement(
        options, inventory, facts, HarnessConfig()
    )
    print("LIVE PROMPT CHOICE:\n" + record.report())
    expect_true(record.has_choice, "the live chooser produced a choice")
    expect_true(
        record.decision_code == DEC_MEASURED_WIN
        or record.decision_code == DEC_DEFAULT_CONFIRMED
        or record.decision_code == DEC_DEFAULT_BY_NOISE
        or record.decision_code == DEC_SOLE_MEASURED
        or record.decision_code == DEC_NO_MEASURED_FALLBACK,
        "the live decision is an auto decision",
    )
    expect_eq(
        record.chosen_device, DEVICE_CPU, "the live choice is on the cpu"
    )
    expect_contains(
        record.report(),
        "gpu (auto): EXCLUDED",
        "the gpu exclusion rides on the live record",
    )
    expect_contains(
        record.report(),
        "npu (auto): EXCLUDED",
        "the npu exclusion rides on the live record",
    )
    expect_contains(
        record.report(),
        "NOT ranked",
        "the device-sweep cross-check is labelled unranked",
    )
    var session = PromptPlacementSession()
    session.decide_once(record)
    expect_true(
        session.report() == record.report(),
        "the session keeps the live record verbatim",
    )
    print("PASS: live chooser over the real harness + thread trials on this VM")


def test_live_manual_cpu() raises:
    var cli = RawPlacementInputs()
    cli.prompt = "cpu"
    cli.prompt_set = True
    var options = resolve_placement_options(cli, RawPlacementInputs())
    var inventory = observe_device_inventory()
    var facts = observe_cpu_facts()
    var record = choose_prompt_placement(
        options, inventory, facts, HarnessConfig()
    )
    print("LIVE MANUAL PROMPT CHOICE:\n" + record.report())
    expect_eq(record.decision_code, DEC_MANUAL_FIXED, "live manual decision")
    expect_true(record.chosen_label == "cpu", "the manual cpu choice stands")
    print("PASS: live manual cpu option fixes the choice (no ranking ran)")


def main() raises:
    test_clear_winner()
    test_within_noise_margin()
    test_within_noise_separation()
    test_default_fastest_unproven()
    test_sole_measured()
    test_no_measured_fallback_and_refusal()
    test_manual_respected()
    test_race_ranks_members_only()
    test_session_keeping()
    test_live_chooser()
    test_live_manual_cpu()
    print("ALL PASS: prompt placement auto choice (11 groups)")
