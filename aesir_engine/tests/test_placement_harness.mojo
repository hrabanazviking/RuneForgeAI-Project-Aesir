"""Placement measurement harness (J-038): summary statistics on
injected timings, settle-round discard and round counting, the
per-candidate time bound, candidate enumeration filtered through
inventory truth (present vs excluded-with-reason), the draft-check
unmeasurable path (J-035 G1), the co-work unmeasurable path
(J-043), the present-but-no-executor path, and live bounded
micro-runs of the harness's own pass-shaped workloads on this
machine (CPU candidate only -- this VM's inventory states the GPU
absent and the NPU parked).

The live groups measure HARNESS MECHANICS only: the workloads are
the harness's own matvec/GEMM micro-workloads, not model passes,
and no number here is a placement verdict for any model.
"""
from core.placement_options import (
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    PlacementOptions,
    RawPlacementInputs,
    resolve_placement_options,
)
from core.device_inventory import (
    DeviceInventory,
    NPU_LEDGER_PARKED,
    cpu_entry,
    gpu_absent_entry,
    gpu_entry,
    npu_entry,
    observe_device_inventory,
    parse_cpuinfo,
    parse_nvidia_smi_csv,
)
from core.placement_harness import (
    CAND_EXCLUDED,
    CAND_MEASURABLE,
    CAND_UNMEASURABLE,
    RES_BOUND_STOPPED,
    RES_MEASURED,
    RES_UNMEASURABLE,
    HarnessConfig,
    WorkloadSpec,
    WORKLOAD_PROMPT,
    WORKLOAD_REPLY,
    account_rounds,
    enumerate_candidates,
    prepare_workload,
    prompt_workload,
    reply_workload,
    run_placement_measurement,
    run_workload_once,
    summarize_timings,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PlacementHarness "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("PlacementHarness " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "PlacementHarness "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


def _vm_cpuinfo() -> String:
    var text = String("")
    for i in range(4):
        text += "processor\t: " + String(i) + "\n"
        text += "model name\t: AMD EPYC 9D64 88-Core Processor\n"
        text += "physical id\t: 0\n"
        text += "core id\t\t: " + String(i) + "\n\n"
    return text


def _vm_inventory() raises -> DeviceInventory:
    """This VM's truth, as fixtures: cpu present, gpu absent with
    its reason, npu parked from the ledger."""
    var inv = DeviceInventory()
    inv.cpu = cpu_entry(parse_cpuinfo(_vm_cpuinfo()))
    inv.gpu = gpu_absent_entry(
        "no GPU probe answered: nvidia-smi failed (test fixture)"
    )
    inv.npu = npu_entry(NPU_LEDGER_PARKED, String(""))
    return inv


def _full_inventory() raises -> DeviceInventory:
    """A machine whose GPU answers the probe: cpu + gpu present,
    npu still parked (the ledger state is machine-independent on
    this road)."""
    var inv = _vm_inventory()
    inv.gpu = gpu_entry(parse_nvidia_smi_csv("Card A, 6144, 1024\n"))
    return inv


def _default_options() raises -> PlacementOptions:
    return resolve_placement_options(
        RawPlacementInputs(), RawPlacementInputs()
    )


def _options_with(field: String, value: String) raises -> PlacementOptions:
    var cli = RawPlacementInputs()
    if field == "prompt":
        cli.prompt = value
        cli.prompt_set = True
    elif field == "drafts":
        cli.drafts = value
        cli.drafts_set = True
    else:
        cli.reply = value
        cli.reply_set = True
    return resolve_placement_options(cli, RawPlacementInputs())


def test_summary_statistics() raises:
    var odd = summarize_timings([30, 10, 20])
    expect_eq(odd.count, 3, "odd count")
    expect_eq(odd.median_ns, 20, "odd median")
    expect_eq(odd.min_ns, 10, "min")
    expect_eq(odd.max_ns, 30, "max")
    expect_eq(odd.spread_ns, 20, "spread is max - min")
    var even = summarize_timings([40, 10, 30, 20])
    expect_eq(even.median_ns, 25, "even median is the middle pair's mean")
    var single = summarize_timings([7])
    expect_eq(single.median_ns, 7, "single-round median")
    expect_eq(single.spread_ns, 0, "single-round spread")
    var empty_refused = False
    try:
        _ = summarize_timings(List[Int]())
    except:
        empty_refused = True
    expect_true(empty_refused, "zero rounds are refused, never summarized")
    var negative_refused = False
    try:
        _ = summarize_timings([5, -1])
    except:
        negative_refused = True
    expect_true(negative_refused, "negative durations are refused")
    print("PASS: summary statistics on injected timings (median/min/max/spread)")


def test_settle_discarded_and_counting() raises:
    var config = HarnessConfig()
    var account = account_rounds(
        [999999999], [100, 110, 90, 105, 95], config
    )
    expect_eq(account.settle_run, 1, "one settle round ran")
    expect_eq(len(account.counted), 5, "all measured rounds counted")
    expect_true(not account.bound_stopped, "no bound stop under budget")
    var summary = summarize_timings(account.counted)
    expect_eq(summary.median_ns, 100, "median over the measured rounds")
    expect_eq(
        summary.max_ns,
        110,
        "the settle round's timing is discarded, not summarized",
    )
    print("PASS: settle round discarded, measured rounds counted")


def test_candidate_filtering() raises:
    var inv = _vm_inventory()
    var auto = enumerate_candidates(_default_options(), inv, PASS_PROMPT)
    expect_eq(len(auto), 3, "auto names the whole field")
    expect_eq(auto[0].status, CAND_MEASURABLE, "cpu candidate measurable")
    expect_eq(auto[1].status, CAND_EXCLUDED, "gpu candidate excluded")
    expect_contains(
        auto[1].reason,
        "no GPU probe answered",
        "gpu exclusion carries the inventory reason",
    )
    expect_eq(auto[2].status, CAND_EXCLUDED, "npu candidate excluded")
    expect_contains(
        auto[2].reason, "parked", "npu exclusion carries the ledger reason"
    )
    var single_gpu = enumerate_candidates(
        _options_with("prompt", "gpu"), inv, PASS_PROMPT
    )
    expect_eq(len(single_gpu), 1, "single names one candidate")
    expect_eq(
        single_gpu[0].status,
        CAND_EXCLUDED,
        "a hand-named absent device is excluded, never dropped silently",
    )
    var race = enumerate_candidates(
        _options_with("prompt", "cpu,gpu"), inv, PASS_PROMPT
    )
    expect_eq(len(race), 2, "race expands to one candidate per member")
    expect_eq(race[0].status, CAND_MEASURABLE, "race cpu member measurable")
    expect_eq(race[1].status, CAND_EXCLUDED, "race gpu member excluded")
    var single_cpu = enumerate_candidates(
        _options_with("reply", "cpu"), inv, PASS_REPLY
    )
    expect_eq(single_cpu[0].status, CAND_MEASURABLE, "reply cpu measurable")
    print("PASS: candidate filtering against inventory (present vs excluded-with-reason)")


def test_time_bound_accounting() raises:
    var config = HarnessConfig(
        settle_rounds=1,
        measured_rounds=5,
        per_candidate_budget_ns=1000,
        per_sweep_budget_ns=100000,
    )
    # Settle burns 400 of the budget; measured rounds of 400 each:
    # two are counted (elapsed 400 -> 800 -> 1200), the third check
    # sees the budget reached and stops the candidate.
    var account = account_rounds([400], [400, 400, 400, 400], config)
    expect_eq(account.settle_run, 1, "settle ran under the bound")
    expect_eq(len(account.counted), 2, "rounds stop at the budget")
    expect_true(account.bound_stopped, "bound stop is recorded")
    var room = account_rounds([10], [10, 10, 10], config)
    expect_eq(len(room.counted), 3, "rounds under the budget all count")
    expect_true(not room.bound_stopped, "no stop when the budget holds")
    var settle_refused = False
    try:
        _ = HarnessConfig(settle_rounds=0)
    except:
        settle_refused = True
    expect_true(settle_refused, "zero settle rounds are refused")
    var rounds_refused = False
    try:
        _ = HarnessConfig(measured_rounds=2)
    except:
        rounds_refused = True
    expect_true(rounds_refused, "fewer than 3 measured rounds are refused")
    var budget_refused = False
    try:
        _ = HarnessConfig(
            per_candidate_budget_ns=5000, per_sweep_budget_ns=1000
        )
    except:
        budget_refused = True
    expect_true(
        budget_refused, "candidate budget above the sweep budget is refused"
    )
    print("PASS: time bound enforced in the round accounting + config refusals")


def test_draft_check_unmeasurable() raises:
    var inv = _full_inventory()
    var candidates = enumerate_candidates(
        _options_with("drafts", "cpu"), inv, PASS_DRAFTS
    )
    expect_eq(len(candidates), 1, "drafts names one candidate")
    expect_eq(
        candidates[0].status,
        CAND_UNMEASURABLE,
        "draft-check is unmeasurable even on a present cpu",
    )
    expect_contains(
        candidates[0].reason, "G1", "the reason names J-035 gap G1"
    )
    expect_contains(
        candidates[0].reason, "Part V", "the reason names the owning part"
    )
    var sweep = run_placement_measurement(
        _options_with("drafts", "cpu"),
        inv,
        PASS_DRAFTS,
        reply_workload(),
        HarnessConfig(),
    )
    expect_eq(sweep.measured_count(), 0, "no draft-check timing exists")
    expect_eq(
        sweep.results[0].status,
        RES_UNMEASURABLE,
        "the sweep records the unmeasurable candidate, with its reason",
    )
    print("PASS: draft-check unmeasurable-with-reason (G1), never proxied")


def test_cowork_unmeasurable() raises:
    var both_present = enumerate_candidates(
        _options_with("prompt", "cpu+gpu"), _full_inventory(), PASS_PROMPT
    )
    expect_eq(
        both_present[0].status,
        CAND_UNMEASURABLE,
        "co-work with both devices present is unmeasurable in this slice",
    )
    expect_contains(
        both_present[0].reason, "J-043", "the reason names J-043 as owner"
    )
    var gpu_absent = enumerate_candidates(
        _options_with("prompt", "cpu+gpu"), _vm_inventory(), PASS_PROMPT
    )
    expect_eq(
        gpu_absent[0].status,
        CAND_EXCLUDED,
        "co-work naming an absent device is excluded with its reason first",
    )
    expect_contains(
        gpu_absent[0].reason,
        "no GPU probe answered",
        "the exclusion carries the inventory reason",
    )
    print("PASS: co-work unmeasurable-with-reason (J-043); absent member excluded first")


def test_present_device_no_executor() raises:
    var candidates = enumerate_candidates(
        _options_with("prompt", "gpu"), _full_inventory(), PASS_PROMPT
    )
    expect_eq(
        candidates[0].status,
        CAND_UNMEASURABLE,
        "a present gpu is unmeasurable until a gpu executor exists",
    )
    expect_contains(
        candidates[0].reason,
        "executor",
        "the reason names the missing executor, not a missing device",
    )
    print("PASS: present device without an executor is unmeasurable-with-reason")


def test_workload_shapes() raises:
    var reply = reply_workload()
    var data = prepare_workload(reply)
    var first = run_workload_once(data, reply)
    var second = run_workload_once(data, reply)
    expect_true(first == second, "workload checksum is deterministic")
    var bad_reply = False
    try:
        _ = WorkloadSpec(WORKLOAD_REPLY, 4, 64, 64, 1)
    except:
        bad_reply = True
    expect_true(bad_reply, "a reply workload wider than 1 is refused")
    var bad_prompt = False
    try:
        _ = WorkloadSpec(WORKLOAD_PROMPT, 1, 64, 64, 1)
    except:
        bad_prompt = True
    expect_true(bad_prompt, "a width-1 prompt workload is refused")
    print("PASS: workload shapes (reply width 1, prompt batched, deterministic)")


def test_live_micro_runs() raises:
    # The real inventory of this machine + the default (auto)
    # options: the cpu candidate measures, gpu/npu are excluded
    # with their live reasons. Harness mechanics only.
    var inv = observe_device_inventory()
    var options = _default_options()
    var config = HarnessConfig()
    var reply_sweep = run_placement_measurement(
        options, inv, PASS_REPLY, reply_workload(), config
    )
    print("LIVE REPLY SWEEP:\n" + reply_sweep.report())
    expect_eq(reply_sweep.measured_count(), 1, "reply: cpu measured")
    expect_eq(
        reply_sweep.results[0].status, RES_MEASURED, "reply cpu measured"
    )
    expect_eq(
        reply_sweep.results[0].summary.count, 5, "reply: 5 rounds counted"
    )
    expect_eq(reply_sweep.results[0].settle_run, 1, "reply: settle ran")
    expect_true(
        reply_sweep.results[0].summary.median_ns > 0,
        "reply median is a real timing",
    )
    var prompt_sweep = run_placement_measurement(
        options, inv, PASS_PROMPT, prompt_workload(), config
    )
    print("LIVE PROMPT SWEEP:\n" + prompt_sweep.report())
    expect_eq(prompt_sweep.measured_count(), 1, "prompt: cpu measured")
    expect_eq(
        prompt_sweep.results[0].summary.count, 5, "prompt: 5 rounds counted"
    )
    print("PASS: live micro-runs on this machine (cpu measured; gpu/npu excluded with reasons)")


def test_live_time_bound() raises:
    # A 1 ns per-candidate budget: the settle round burns past it,
    # so the candidate stops before any measured round is counted.
    # The harness cannot hang: the bound is the proof.
    var inv = observe_device_inventory()
    var config = HarnessConfig(
        settle_rounds=1,
        measured_rounds=5,
        per_candidate_budget_ns=1,
        per_sweep_budget_ns=10000000000,
    )
    var sweep = run_placement_measurement(
        _default_options(), inv, PASS_REPLY, reply_workload(), config
    )
    print("LIVE BOUND SWEEP:\n" + sweep.report())
    expect_eq(
        sweep.results[0].status,
        RES_BOUND_STOPPED,
        "the live candidate stops at its budget",
    )
    expect_eq(
        sweep.results[0].summary.count,
        0,
        "no measured round is counted past the bound",
    )
    expect_eq(sweep.results[0].settle_run, 1, "the settle round still ran")
    print("PASS: live time bound enforced (bound-stopped, zero counted rounds)")


def main() raises:
    test_summary_statistics()
    test_settle_discarded_and_counting()
    test_candidate_filtering()
    test_time_bound_accounting()
    test_draft_check_unmeasurable()
    test_cowork_unmeasurable()
    test_present_device_no_executor()
    test_workload_shapes()
    test_live_micro_runs()
    test_live_time_bound()
    print("ALL PASS: placement measurement harness (10 groups)")
