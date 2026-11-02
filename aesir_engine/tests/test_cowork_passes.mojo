"""Co-work passes for the prompt kind (J-043): the split
planner's accounting exactness (row fractions, per-side work,
crossing bytes, join bytes), the plan-time refusals (empty
side, same device twice, any pair naming the parked NPU),
the join-time forms (concurrent = slower side + join;
sequential = both sides + join), the pre-registered survival
rule on injected measurement sets (survives only when the
joined median beats BOTH parents beyond the 10% band with
round separation against each; beats-one-only, within-noise,
and interleaving splits are measured-and-rejected, never
kept; unmeasured inputs force state verdicts, never numeric
ones), pair classification against fixture inventories
(NPU refusal first, absent member excluded with the
inventory's reason, present non-CPU member
unmeasurable-with-reason -- no harness executor), manual
supremacy at the planner level (an explicit pair evaluated
as written, never substituted; a single names no pair), and
the live runs on this machine: the planner over the real
inventory (all device pairs refused/excluded -- zero
survived options) and the CPU thread-partition ANALOGUE
measured end to end (parents as single-partition runs through the same executor, splits
with timed joins, verdicts computed -- labelled an analogue
in every line that reports it, never device co-work).

No number in this suite is a GPU/NPU timing: no GPU prompt
executor exists in the harness and the NPU is parked. The
only timings are CPU harness mechanics and the analogue's.
"""
from core.cowork_passes import (
    CW_BOUND_STOPPED,
    CW_EXCLUDED,
    CW_MEASURED,
    CW_REFUSED,
    CW_UNMEASURABLE,
    VERDICT_BOUND_STOPPED,
    VERDICT_EXCLUDED,
    VERDICT_REJECTED,
    VERDICT_REFUSED,
    VERDICT_SURVIVES,
    VERDICT_UNMEASURABLE,
    SplitMeasure,
    allocate_partition_threads,
    candidate_split_plans,
    classify_pair,
    evaluate_split,
    joined_time_ns,
    plan_cowork_prompt,
    plan_device_split,
    plan_split_accounting,
    run_thread_partition_analogue,
)
from core.device_inventory import (
    NPU_LEDGER_PARKED,
    CpuFacts,
    DeviceInventory,
    GpuFacts,
    cpu_entry,
    gpu_absent_entry,
    gpu_entry,
    npu_entry,
    observe_device_inventory,
)
from core.placement_harness import HarnessConfig, prompt_workload, summarize_timings
from core.placement_options import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NPU,
    RawPlacementInputs,
    resolve_placement_options,
)
from core.thread_topology import observe_cpu_facts


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error("Cowork " + what + ": expected " + String(expected) + ", got " + String(actual))


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("Cowork " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error("Cowork " + what + ": expected to contain '" + needle + "', got '" + text + "'")


def _measured(label: String, device: Int, median: Int, max_ns: Int) -> SplitMeasure:
    var m = SplitMeasure()
    m.label = label
    m.device = device
    m.status = CW_MEASURED
    m.summary.count = 5
    m.summary.median_ns = median
    m.summary.min_ns = median - (max_ns - median)
    m.summary.max_ns = max_ns
    m.summary.spread_ns = max_ns - m.summary.min_ns
    return m


def _stated(label: String, device: Int, status: Int, reason: String) -> SplitMeasure:
    var m = SplitMeasure()
    m.label = label
    m.device = device
    m.status = status
    m.reason = reason
    return m


def _inventory(gpu_present: Bool) -> DeviceInventory:
    var inv = DeviceInventory()
    var cpu = CpuFacts()
    cpu.model = String("Fixture CPU")
    cpu.logical = 4
    cpu.physical_cores = 4
    cpu.packages = 1
    inv.cpu = cpu_entry(cpu)
    if gpu_present:
        var gpu = GpuFacts()
        gpu.name = String("Fixture GPU")
        gpu.vram_total_bytes = 6442450944
        gpu.vram_free_bytes = 6442450944
        gpu.count = 1
        inv.gpu = gpu_entry(gpu)
    else:
        inv.gpu = gpu_absent_entry(String("fixture: no gpu on this machine"))
    inv.npu = npu_entry(NPU_LEDGER_PARKED, String(""))
    return inv


def test_split_accounting() raises:
    var spec = prompt_workload()
    expect_eq(spec.rows, 16, "prompt workload rows")
    expect_eq(spec.k, 512, "prompt workload k")
    expect_eq(spec.n, 256, "prompt workload n")
    expect_eq(spec.reps, 2, "prompt workload reps")
    var half = plan_device_split(spec, DEVICE_CPU, DEVICE_GPU, 8)
    expect_eq(half.first_rows, 8, "half split first rows")
    expect_eq(half.second_rows, 8, "half split second rows")
    expect_eq(half.first_work, 2097152, "half split first work")
    expect_eq(half.second_work, 2097152, "half split second work")
    expect_eq(half.total_work, 4194304, "half split total work")
    expect_eq(half.input_bytes_first, 16384, "half split first input bytes")
    expect_eq(half.input_bytes_second, 16384, "half split second input bytes")
    expect_eq(half.matrix_bytes_each, 524288, "matrix bytes each side")
    expect_eq(half.output_bytes_first, 8192, "half split first output bytes")
    expect_eq(half.output_bytes_second, 8192, "half split second output bytes")
    expect_eq(half.join_output_bytes, 16384, "join output bytes")
    expect_eq(half.join_elements, 4096, "join elements")
    expect_eq(half.crossing_bytes_total, 1097728, "crossing bytes total")
    expect_eq(half.fraction_percent(), 50, "half fraction percent")
    var quarter = plan_device_split(spec, DEVICE_GPU, DEVICE_CPU, 4)
    expect_eq(quarter.first_work, 1048576, "quarter split first work")
    expect_eq(quarter.second_work, 3145728, "quarter split second work")
    expect_eq(quarter.total_work, 4194304, "quarter split total work is the whole batch")
    expect_eq(quarter.crossing_bytes_total, 1097728, "crossing bytes are fraction-independent")
    var plans = candidate_split_plans(spec, DEVICE_CPU, DEVICE_GPU)
    expect_eq(len(plans), 3, "three candidate fractions")
    expect_eq(plans[0].first_rows, 4, "first candidate is the quarter")
    expect_eq(plans[1].first_rows, 8, "second candidate is the half")
    expect_eq(plans[2].first_rows, 12, "third candidate is the three-quarter")
    print("PASS: split accounting -- fractions, per-side work, crossing and join bytes exact")


def test_split_refusals() raises:
    var spec = prompt_workload()
    var empty_refused = False
    try:
        _ = plan_split_accounting(spec, 0)
    except:
        empty_refused = True
    expect_true(empty_refused, "a split with an empty first side is refused")
    var full_refused = False
    try:
        _ = plan_split_accounting(spec, 16)
    except:
        full_refused = True
    expect_true(full_refused, "a split with an empty second side is refused")
    var same_refused = False
    var same_text = String("")
    try:
        _ = plan_device_split(spec, DEVICE_CPU, DEVICE_CPU, 8)
    except refusal:
        same_refused = True
        same_text = String(refusal)
    expect_true(same_refused, "the same device twice is refused at plan time")
    expect_contains(same_text, "distinct", "the same-device refusal states the reason")
    var npu_refused = False
    var npu_text = String("")
    try:
        _ = plan_device_split(spec, DEVICE_CPU, DEVICE_NPU, 8)
    except refusal:
        npu_refused = True
        npu_text = String(refusal)
    expect_true(npu_refused, "any pair naming the npu is refused at plan time")
    expect_contains(npu_text, "parked", "the npu refusal states the parked ledger")
    var npu_first_refused = False
    try:
        _ = plan_device_split(spec, DEVICE_NPU, DEVICE_GPU, 8)
    except:
        npu_first_refused = True
    expect_true(npu_first_refused, "an npu-first pair is refused at plan time")
    print("PASS: split refusals -- empty side, same device twice, any npu pair (parked)")


def test_join_accounting() raises:
    expect_eq(joined_time_ns(100, 250, 30, True), 280, "concurrent join is the slower side plus the join")
    expect_eq(joined_time_ns(250, 100, 30, True), 280, "concurrent join does not depend on side order")
    expect_eq(joined_time_ns(100, 250, 30, False), 380, "sequential join is both sides plus the join")
    var durations = List[Int]()
    durations.append(280)
    durations.append(300)
    durations.append(260)
    var summary = summarize_timings(durations)
    expect_eq(summary.median_ns, 280, "joined durations summarize by median")
    expect_eq(summary.spread_ns, 40, "joined durations keep their spread")
    print("PASS: join accounting -- concurrent and sequential forms, join always included")


def test_survival_survives() raises:
    var split = _measured("cpu+gpu rows 8/8", DEVICE_CPU, 400, 450)
    var parent_a = _measured("cpu", DEVICE_CPU, 1000, 1100)
    var parent_b = _measured("gpu", DEVICE_GPU, 900, 990)
    var record = evaluate_split(split, parent_a, parent_b)
    expect_eq(record.verdict_code, VERDICT_SURVIVES, "a split beating both parents survives")
    expect_eq(record.margin_a_percent, 150, "margin against parent a")
    expect_eq(record.margin_b_percent, 125, "margin against parent b")
    expect_true(record.separation_a_ok, "separation against parent a")
    expect_true(record.separation_b_ok, "separation against parent b")
    expect_contains(record.render(), "SURVIVES", "the survival renders")
    print("PASS: survival rule -- a split beating both parents by margin and separation survives")


def test_survival_beats_one_only() raises:
    var split = _measured("cpu+gpu rows 8/8", DEVICE_CPU, 400, 450)
    var parent_a = _measured("cpu", DEVICE_CPU, 1000, 1100)
    var parent_b = _measured("gpu", DEVICE_GPU, 380, 420)
    var record = evaluate_split(split, parent_a, parent_b)
    expect_eq(record.verdict_code, VERDICT_REJECTED, "beating one parent only is a rejection")
    expect_true(record.margin_b_percent < 0, "the losing comparison is negative")
    expect_contains(record.verdict_text, "gpu", "the rejection names the parent it failed against")
    expect_contains(record.verdict_text, "NOT kept as an option", "the rejection states it is not kept")
    print("PASS: survival rule -- beats one parent only: measured-and-rejected, never kept")


def test_survival_within_noise() raises:
    var split = _measured("cpu+gpu rows 8/8", DEVICE_CPU, 400, 410)
    var parent_a = _measured("cpu", DEVICE_CPU, 1000, 1100)
    var parent_b = _measured("gpu", DEVICE_GPU, 420, 460)
    var record = evaluate_split(split, parent_a, parent_b)
    expect_eq(record.verdict_code, VERDICT_REJECTED, "a within-noise beat is a rejection")
    expect_eq(record.margin_b_percent, 5, "the within-noise margin is recorded")
    expect_true(record.separation_b_ok, "separation held; the margin alone failed")
    expect_contains(record.verdict_text, "inside the 10% band", "the failed margin hurdle is stated")
    print("PASS: survival rule -- beating a parent inside the 10% band is a rejection")


def test_survival_separation_fails() raises:
    var split = _measured("cpu+gpu rows 8/8", DEVICE_CPU, 400, 1100)
    var parent_a = _measured("cpu", DEVICE_CPU, 1000, 1150)
    var parent_b = _measured("gpu", DEVICE_GPU, 2000, 2200)
    var record = evaluate_split(split, parent_a, parent_b)
    expect_eq(record.verdict_code, VERDICT_REJECTED, "an interleaving split is a rejection")
    expect_true(not record.separation_a_ok, "separation against parent a failed")
    expect_true(record.separation_b_ok, "separation against parent b held")
    expect_contains(record.verdict_text, "interleave", "the failed separation hurdle is stated")
    print("PASS: survival rule -- margin clears but rounds interleave: rejection")


def test_survival_unmeasured_inputs() raises:
    var split = _stated("cpu+gpu rows 8/8", DEVICE_CPU, CW_UNMEASURABLE, "no gpu executor")
    var parent_a = _measured("cpu", DEVICE_CPU, 1000, 1100)
    var parent_b = _measured("gpu", DEVICE_GPU, 900, 990)
    var unmeasured = evaluate_split(split, parent_a, parent_b)
    expect_eq(unmeasured.verdict_code, VERDICT_UNMEASURABLE, "an unmeasured split forces the unmeasurable verdict")
    var measured_split = _measured("cpu+gpu rows 8/8", DEVICE_CPU, 400, 450)
    var excluded_parent = _stated("gpu", DEVICE_GPU, CW_EXCLUDED, "inventory: gpu absent")
    var excluded = evaluate_split(measured_split, parent_a, excluded_parent)
    expect_eq(excluded.verdict_code, VERDICT_EXCLUDED, "an excluded parent forces the excluded verdict")
    var parked_parent = _stated("npu", DEVICE_NPU, CW_REFUSED, "parked ledger")
    var refused = evaluate_split(measured_split, parent_a, parked_parent)
    expect_eq(refused.verdict_code, VERDICT_REFUSED, "a parked parent forces the refused verdict")
    var bound_split = _stated("cpu+gpu rows 8/8", DEVICE_CPU, CW_BOUND_STOPPED, "budget reached")
    var bound = evaluate_split(bound_split, parent_a, parent_b)
    expect_eq(bound.verdict_code, VERDICT_BOUND_STOPPED, "a bound-stopped split is never ranked")
    expect_true(unmeasured.margin_a_percent < 0, "no margin is claimed on an unmeasured field")
    print("PASS: survival rule -- unmeasured inputs force state verdicts, never numeric ones")


def test_pair_classification() raises:
    var absent = _inventory(False)
    var gpu_absent = classify_pair(absent, DEVICE_CPU, DEVICE_GPU)
    expect_eq(gpu_absent[0], CW_EXCLUDED, "a pair with an absent member is excluded")
    expect_contains(gpu_absent[1], "fixture: no gpu", "the exclusion carries the inventory reason")
    var npu_pair = classify_pair(absent, DEVICE_CPU, DEVICE_NPU)
    expect_eq(npu_pair[0], CW_REFUSED, "an npu pair is refused before inventory is consulted")
    expect_contains(npu_pair[1], "parked", "the npu classification states the parked ledger")
    var npu_gpu = classify_pair(absent, DEVICE_GPU, DEVICE_NPU)
    expect_eq(npu_gpu[0], CW_REFUSED, "a gpu+npu pair is refused for its npu member")
    var present = _inventory(True)
    var gpu_present = classify_pair(present, DEVICE_CPU, DEVICE_GPU)
    expect_eq(gpu_present[0], CW_UNMEASURABLE, "a present gpu pair is unmeasurable: no harness executor")
    expect_contains(gpu_present[1], "no gpu prompt workload executor", "the unmeasurable reason names the missing executor")
    print("PASS: pair classification -- npu refused, absent excluded, present-but-executorless unmeasurable")


def test_thread_allocation_and_manual() raises:
    var spec = prompt_workload()
    var half = plan_split_accounting(spec, 8)
    var alloc_half = allocate_partition_threads(4, half)
    expect_eq(alloc_half[0], 2, "half split first partition threads")
    expect_eq(alloc_half[1], 2, "half split second partition threads")
    var quarter = plan_split_accounting(spec, 4)
    var alloc_quarter = allocate_partition_threads(4, quarter)
    expect_eq(alloc_quarter[0], 1, "quarter split first partition threads")
    expect_eq(alloc_quarter[1], 3, "quarter split second partition threads")
    expect_eq(alloc_quarter[0] + alloc_quarter[1], 4, "allocations sum to the ladder total")
    var present = _inventory(True)
    var cli = RawPlacementInputs()
    cli.prompt = "cpu+gpu"
    cli.prompt_set = True
    var options = resolve_placement_options(cli, RawPlacementInputs())
    var record = plan_cowork_prompt(options, present)
    expect_eq(len(record.pairs), 1, "an explicit pair is the only pair evaluated")
    expect_true(record.pairs[0].label() == "cpu+gpu", "the explicit pair stands as written")
    expect_eq(record.pairs[0].verdict.verdict_code, VERDICT_UNMEASURABLE, "the explicit pair's verdict is its state")
    expect_eq(record.survived_count(), 0, "no pair survives from an unmeasured field")
    var cli_single = RawPlacementInputs()
    cli_single.prompt = "cpu"
    cli_single.prompt_set = True
    var single_options = resolve_placement_options(cli_single, RawPlacementInputs())
    var single_record = plan_cowork_prompt(single_options, present)
    expect_eq(len(single_record.pairs), 0, "a single names no co-work pair")
    expect_contains(single_record.outcome_text, "stands untouched", "manual supremacy: the single stands untouched")
    print("PASS: thread allocation exact; explicit pair as written, single untouched (manual supremacy)")


def test_live_planner() raises:
    var inventory = observe_device_inventory()
    var options = resolve_placement_options(RawPlacementInputs(), RawPlacementInputs())
    var record = plan_cowork_prompt(options, inventory)
    print("LIVE PROMPT CO-WORK PLAN (auto):\n" + record.report())
    expect_eq(len(record.pairs), 3, "auto evaluates the field's three pairs")
    expect_eq(record.survived_count(), 0, "zero device co-work options survive live")
    var saw_excluded = False
    var saw_refused = False
    for pair in record.pairs:
        if pair.status == CW_EXCLUDED:
            saw_excluded = True
            expect_contains(pair.reason, "gpu was requested", "the excluded pair carries the inventory reason")
        if pair.status == CW_REFUSED:
            saw_refused = True
            expect_true(pair.verdict.verdict_code == VERDICT_REFUSED, "a refused pair's verdict is refused")
    expect_true(saw_excluded, "the cpu+gpu pair is excluded on this VM (gpu absent)")
    expect_true(saw_refused, "the npu pairs are refused on this machine")
    expect_contains(record.report(), "NOT PROVEN", "the live record states true co-work is not proven")
    var cli = RawPlacementInputs()
    cli.prompt = "cpu+gpu"
    cli.prompt_set = True
    var manual_options = resolve_placement_options(cli, RawPlacementInputs())
    var manual = plan_cowork_prompt(manual_options, inventory)
    print("LIVE PROMPT CO-WORK PLAN (manual cpu+gpu):\n" + manual.report())
    expect_eq(len(manual.pairs), 1, "the live manual pair is evaluated alone")
    expect_eq(manual.pairs[0].status, CW_EXCLUDED, "the live manual pair is excluded (gpu absent), never substituted")
    var cli_npu = RawPlacementInputs()
    cli_npu.prompt = "cpu+npu"
    cli_npu.prompt_set = True
    var npu_options = resolve_placement_options(cli_npu, RawPlacementInputs())
    var npu_record = plan_cowork_prompt(npu_options, inventory)
    expect_eq(npu_record.pairs[0].status, CW_REFUSED, "the live manual npu pair is refused-parked")
    print("PASS: live planner -- all device pairs refused/excluded, zero survived, manual never substituted")


def test_live_analogue() raises:
    var facts = observe_cpu_facts()
    var spec = prompt_workload()
    var record = run_thread_partition_analogue(facts, spec, HarnessConfig())
    print("LIVE THREAD-PARTITION ANALOGUE:\n" + record.report())
    expect_eq(record.parent_serial.status, CW_MEASURED, "the analogue's serial parent measured")
    expect_eq(record.parent_threaded.status, CW_MEASURED, "the analogue's threaded parent measured")
    expect_eq(len(record.splits), 3, "three analogue splits measured")
    for result in record.splits:
        expect_eq(result.measure.status, CW_MEASURED, "each analogue split measured with its join")
        expect_eq(result.measure.summary.count, 5, "each analogue split counted five rounds")
        expect_eq(result.measure.join_summary.count, 5, "the join was timed in every counted round")
        expect_true(result.measure.join_summary.median_ns > 0, "the join carries a real timing")
        expect_true(
            result.verdict.verdict_code == VERDICT_SURVIVES or result.verdict.verdict_code == VERDICT_REJECTED,
            "each analogue verdict is a numeric verdict against both parents",
        )
        if result.verdict.verdict_code == VERDICT_SURVIVES:
            expect_contains(result.verdict.verdict_text, "ANALOGUE ONLY", "an analogue survival is labelled analogue-only")
    expect_contains(record.report(), "NOT device co-work", "the analogue record labels itself on its face")
    print("PASS: live analogue -- parents and splits measured, joins timed, verdicts computed (analogue only)")


def main() raises:
    test_split_accounting()
    test_split_refusals()
    test_join_accounting()
    test_survival_survives()
    test_survival_beats_one_only()
    test_survival_within_noise()
    test_survival_separation_fails()
    test_survival_unmeasured_inputs()
    test_pair_classification()
    test_thread_allocation_and_manual()
    test_live_planner()
    test_live_analogue()
    print("ALL PASS: co-work passes (12 groups)")
