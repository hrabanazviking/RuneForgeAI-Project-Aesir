"""Bench configurations (J-100): the bench discipline's config
refusals, the cross-product enumeration over fixtures (VM-shaped:
27 cells, exactly 6 pending-measured, GPU/NPU excluded with the
inventory's own reasons, draft-check unmeasurable at every rung;
GPU-present: the GPU cells turn unmeasurable-with-reason, never
excluded and never measured), the fastest-cell grading on
injected cells (measured only, ties keep table order, a kind
with no measured cell grades -1), the machine report's render on
an injected report, the CLI argument refusals (including
--report, which is J-101's), and one full bench sweep over
fixture inventory/facts on this machine.

The live group measures HARNESS MECHANICS only: the workloads
are J-038's pass-shaped micro-workloads, and no number here is
a placement verdict for any model.
"""
from core.placement_options import (
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
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
    parse_cpuinfo,
    parse_nvidia_smi_csv,
)
from core.bench_configurations import (
    CELL_BOUND_STOPPED,
    CELL_EXCLUDED,
    CELL_MEASURED,
    CELL_PENDING,
    CELL_UNMEASURABLE,
    BenchCell,
    BenchConfig,
    BenchReport,
    KindBench,
    bench_pass_kind,
    enumerate_bench_cells,
    fastest_cell_index,
    machine_report,
    run_bench_sweep,
)
from core.thread_topology import derive_thread_ladder
from cli.bench import dispatch_bench


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "BenchConfigurations "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("BenchConfigurations " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "BenchConfigurations "
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
    var inv = DeviceInventory()
    inv.cpu = cpu_entry(parse_cpuinfo(_vm_cpuinfo()))
    inv.gpu = gpu_absent_entry(
        "no GPU probe answered: nvidia-smi failed (test fixture)"
    )
    inv.npu = npu_entry(NPU_LEDGER_PARKED, String(""))
    return inv


def _full_inventory() raises -> DeviceInventory:
    var inv = _vm_inventory()
    inv.gpu = gpu_entry(parse_nvidia_smi_csv("Card A, 6144, 1024\n"))
    return inv


def _count_status(cells: List[BenchCell], status: Int) -> Int:
    var total = 0
    for cell in cells:
        if cell.status == status:
            total += 1
    return total


def test_config_refusals() raises:
    var default = BenchConfig()
    expect_contains(default.describe(), "settle 1 discarded", "default discipline")
    expect_contains(default.describe(), "5 measured rounds", "default rounds")
    var refused = 0
    try:
        _ = BenchConfig(0, 5)
    except _:
        refused += 1
    try:
        _ = BenchConfig(1, 2)
    except _:
        refused += 1
    expect_eq(refused, 2, "settle 0 and rounds < 3 are both refused")
    print("PASS: bench config (defaults stated; settle 0 / rounds < 3 refused)")


def test_kind_order() raises:
    expect_eq(bench_pass_kind(0), PASS_PROMPT, "first kind is prompt")
    expect_eq(bench_pass_kind(1), PASS_DRAFTS, "second kind is draft-check")
    expect_eq(bench_pass_kind(2), PASS_REPLY, "third kind is reply")
    print("PASS: pass-kind order is the J-035 taxonomy order")


def test_enumeration_cross_product() raises:
    var options = resolve_placement_options(
        RawPlacementInputs(), RawPlacementInputs()
    )
    var facts = parse_cpuinfo(_vm_cpuinfo())
    var cells = enumerate_bench_cells(options, _vm_inventory(), facts)
    expect_eq(len(cells), 27, "3 kinds x 3 devices x 3 rungs")
    expect_eq(_count_status(cells, CELL_PENDING), 6, "cpu cells of prompt+reply")
    expect_eq(_count_status(cells, CELL_EXCLUDED), 12, "gpu+npu of prompt+reply")
    expect_eq(_count_status(cells, CELL_UNMEASURABLE), 9, "all draft-check cells")
    for cell in cells:
        if cell.status == CELL_EXCLUDED and "gpu" in cell.device_label:
            expect_contains(
                cell.reason, "nvidia-smi failed (test fixture)",
                "gpu exclusion carries the inventory reason",
            )
        if cell.status == CELL_EXCLUDED and "npu" in cell.device_label:
            expect_contains(cell.reason, "parked", "npu exclusion is the ledger")
        if cell.pass_kind == PASS_DRAFTS:
            expect_contains(cell.reason, "G1", "draft-check reason names G1")
    print("PASS: enumeration cross product on VM fixtures (27 cells, 6 pending)")


def test_enumeration_gpu_present() raises:
    var options = resolve_placement_options(
        RawPlacementInputs(), RawPlacementInputs()
    )
    var facts = parse_cpuinfo(_vm_cpuinfo())
    var cells = enumerate_bench_cells(options, _full_inventory(), facts)
    expect_eq(len(cells), 27, "cross product is inventory-independent in size")
    expect_eq(_count_status(cells, CELL_PENDING), 6, "cpu cells still 6")
    expect_eq(
        _count_status(cells, CELL_EXCLUDED), 6, "only the parked npu excludes"
    )
    expect_eq(
        _count_status(cells, CELL_UNMEASURABLE), 15,
        "gpu executor cells (6) + draft-check cells (9)",
    )
    print("PASS: GPU-present fixtures (GPU cells unmeasurable-with-reason)")


def _injected_cell(
    kind: Int, status: Int, median: Int
) -> BenchCell:
    var cell = BenchCell()
    cell.pass_kind = kind
    cell.status = status
    cell.summary.median_ns = median
    cell.summary.count = 5
    return cell


def test_fastest_grading() raises:
    var cells = List[BenchCell]()
    cells.append(_injected_cell(PASS_PROMPT, CELL_MEASURED, 300))
    cells.append(_injected_cell(PASS_PROMPT, CELL_MEASURED, 100))
    cells.append(_injected_cell(PASS_PROMPT, CELL_MEASURED, 200))
    cells.append(_injected_cell(PASS_PROMPT, CELL_EXCLUDED, 1))
    cells.append(_injected_cell(PASS_REPLY, CELL_MEASURED, 50))
    expect_eq(fastest_cell_index(cells, PASS_PROMPT), 1, "lowest median wins")
    expect_eq(fastest_cell_index(cells, PASS_REPLY), 4, "kinds grade separately")
    expect_eq(
        fastest_cell_index(cells, PASS_DRAFTS), -1, "no measured cell grades -1"
    )
    var ties = List[BenchCell]()
    ties.append(_injected_cell(PASS_PROMPT, CELL_MEASURED, 100))
    ties.append(_injected_cell(PASS_PROMPT, CELL_MEASURED, 100))
    expect_eq(fastest_cell_index(ties, PASS_PROMPT), 0, "ties keep table order")
    print("PASS: fastest-cell grading (measured only, ties keep table order)")


def test_report_render() raises:
    var report = BenchReport(BenchConfig())
    report.inventory = _vm_inventory()
    var facts = parse_cpuinfo(_vm_cpuinfo())
    report.ladder = derive_thread_ladder(facts)
    var kind = KindBench(PASS_PROMPT)
    kind.cells.append(_injected_cell(PASS_PROMPT, CELL_MEASURED, 100))
    kind.cells.append(_injected_cell(PASS_PROMPT, CELL_EXCLUDED, 0))
    kind.fastest = fastest_cell_index(kind.cells, PASS_PROMPT)
    report.kinds.append(kind^)
    var text = machine_report(report)
    expect_contains(text, "aesir bench — machine report", "report header")
    expect_contains(text, "devices: cpu present", "device line verbatim")
    expect_contains(text, "thread ladder: 1 (serial)", "ladder line verbatim")
    expect_contains(text, "fastest measured cell (prompt):", "fastest line")
    expect_contains(text, "cells: 2 enumerated, 1 measured", "footer counts")
    expect_contains(text, "not placement verdicts", "honesty line")
    print("PASS: machine report render on an injected report")


def _dispatch_refused(args: List[String]) -> Bool:
    try:
        dispatch_bench(args)
    except _:
        return True
    return False


def test_cli_refusals() raises:
    var refused = 0
    if _dispatch_refused(List[String](["bench", "--report"])):
        refused += 1
    if _dispatch_refused(List[String](["bench", "--settle", "0"])):
        refused += 1
    if _dispatch_refused(List[String](["bench", "--rounds", "2"])):
        refused += 1
    if _dispatch_refused(List[String](["bench", "--pass", "bogus"])):
        refused += 1
    if _dispatch_refused(List[String](["bench", "--settle"])):
        refused += 1
    if _dispatch_refused(
        List[String](["bench", "--rounds", "3", "--rounds", "4"])
    ):
        refused += 1
    expect_eq(refused, 6, "every malformed bench invocation is refused")
    print("PASS: CLI refusals (--report is J-101's; bad counts/kinds refused)")


def test_live_bench_sweep() raises:
    var options = resolve_placement_options(
        RawPlacementInputs(), RawPlacementInputs()
    )
    var facts = parse_cpuinfo(_vm_cpuinfo())
    var report = run_bench_sweep(
        options, _vm_inventory(), facts, BenchConfig()
    )
    expect_eq(report.cells_total(), 27, "live sweep enumerates the full field")
    var resolved_cpu = 0
    for kind in report.kinds:
        for cell in kind.cells:
            expect_true(
                cell.status != CELL_PENDING,
                "no cell is left pending after the sweep",
            )
            if cell.device_label.startswith("cpu") and (
                kind.pass_kind == PASS_PROMPT or kind.pass_kind == PASS_REPLY
            ):
                if cell.status == CELL_MEASURED or (
                    cell.status == CELL_BOUND_STOPPED
                ):
                    resolved_cpu += 1
    expect_eq(resolved_cpu, 6, "all 6 cpu cells resolved by the thread sweep")
    var text = machine_report(report)
    expect_contains(text, "fastest measured cell (prompt):", "prompt graded")
    expect_contains(
        text, "fastest measured cell (drafts): none", "draft-check honest"
    )
    print("PASS: live bench sweep over fixtures (27 cells, cpu cells resolved)")
    print("--- machine report (fixture inventory/facts, live timings) ---")
    print(text, end="")
    print("--- end machine report ---")


def main() raises:
    test_config_refusals()
    test_kind_order()
    test_enumeration_cross_product()
    test_enumeration_gpu_present()
    test_fastest_grading()
    test_report_render()
    test_cli_refusals()
    test_live_bench_sweep()
    print("ALL PASS: bench configurations (8 groups)")
