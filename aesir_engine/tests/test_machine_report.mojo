"""Machine report artefact (J-101): the filed per-model rows
under the evidence rule (each row's source + honesty class on
its line; the measured row's filed numbers; the NOT PROVEN rows
carrying their reasons), the model-table render, the device
refusal summary on fixture inventory (J-037's device line
verbatim, each entry's reason verbatim), the artefact render on
an injected report, the CLI's report-mode refusals (parse-level:
--report with --pass in either order, duplicate --report), and
one full artefact from the live sweep over fixture
inventory/facts on this machine.

The live group measures HARNESS MECHANICS only, exactly as
J-100's suite states for its own: no number here is a placement
verdict or a model speed. The artefact it prints is the slice's
FIXTURE example -- fixture inventory, live timings -- and is
labelled FIXTURE on its face.
"""
from core.placement_options import (
    PASS_PROMPT,
    RawPlacementInputs,
    resolve_placement_options,
)
from core.device_inventory import (
    DeviceInventory,
    NPU_LEDGER_PARKED,
    cpu_entry,
    gpu_absent_entry,
    npu_entry,
    parse_cpuinfo,
)
from core.bench_configurations import (
    BenchConfig,
    BenchReport,
    KindBench,
    run_bench_sweep,
)
from core.machine_report import (
    device_refusal_summary,
    filed_model_rows,
    model_table,
    report_artefact,
)
from core.thread_topology import derive_thread_ladder
from cli.bench import dispatch_bench


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "MachineReport "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("MachineReport " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "MachineReport "
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


def test_filed_rows() raises:
    var rows = filed_model_rows()
    expect_eq(len(rows), 3, "the filed table has exactly three rows")
    var olmoe = rows[0].render()
    expect_contains(olmoe, "OLMoE Q4_K_M", "first row is the measured model")
    expect_contains(olmoe, "read: 2.389 tok/s", "filed prefill rate (J-030)")
    expect_contains(olmoe, "write: 2.556 tok/s", "filed decode rate (J-030)")
    expect_contains(olmoe, "J-030", "measured row cites its source")
    expect_contains(olmoe, "MEASURED-INDICATIVE", "measured row's class")
    var coder = rows[1].render()
    expect_contains(coder, "Qwen2.5-Coder-7B", "second row is the ladder witness")
    expect_contains(coder, "NOT PROVEN", "ladder walls are not proven")
    expect_contains(coder, "58720256", "accounted KV frame at 1024 (J-091)")
    expect_contains(coder, "CAP_REFUSED", "ladder cap refusals named")
    expect_contains(coder, "J-091", "ladder row cites its source")
    var next80b = rows[2].render()
    expect_contains(next80b, "Qwen3-Next-80B", "third row is the refused file")
    expect_contains(next80b, "NOT PROVEN", "refused file has no rates")
    expect_contains(next80b, "blocker B2", "refusal reason named (J-032)")
    expect_contains(next80b, "J-032", "refused row cites its source")
    print("PASS: filed model rows (evidence rule: source + class on every line)")


def test_model_table_render() raises:
    var text = model_table(filed_model_rows())
    expect_contains(text, "== per-model read/write (filed evidence) ==", "table header")
    expect_contains(text, "nothing here is invented", "evidence rule on its face")
    expect_contains(text, "OLMoE Q4_K_M", "measured row rendered")
    expect_contains(text, "Qwen3-Next-80B", "refused row rendered")
    print("PASS: per-model table render (rule stated, all rows present)")


def test_device_refusal_summary() raises:
    var inv = _vm_inventory()
    var text = device_refusal_summary(inv)
    expect_contains(text, "== device lines with refusal reasons ==", "section header")
    expect_contains(text, inv.device_line(), "device line verbatim (J-037)")
    expect_contains(text, "cpu present", "cpu entry quantified")
    expect_contains(
        text, "gpu absent — no GPU probe answered: nvidia-smi failed (test fixture)",
        "gpu refusal reason verbatim",
    )
    expect_contains(text, "npu absent", "npu entry on its own line")
    expect_contains(text, "parked by Aesir's campaign law", "npu ledger reason verbatim")
    print("PASS: device refusal summary (device line + per-entry reasons verbatim)")


def test_artefact_render_injected() raises:
    var report = BenchReport(BenchConfig())
    report.inventory = _vm_inventory()
    var facts = parse_cpuinfo(_vm_cpuinfo())
    report.ladder = derive_thread_ladder(facts)
    var kind = KindBench(PASS_PROMPT)
    report.kinds.append(kind^)
    var text = report_artefact(
        report, filed_model_rows(), String("FIXTURE (test-injected report)")
    )
    expect_contains(text, "machine report artefact", "artefact header")
    expect_contains(text, "artefact: FIXTURE", "provenance label on its face")
    expect_contains(text, "aesir bench — machine report", "J-100 render verbatim inside")
    expect_contains(text, "devices: cpu present", "hardware inventory present")
    expect_contains(text, "== per-model read/write (filed evidence) ==", "model section")
    expect_contains(text, "== device lines with refusal reasons ==", "refusal section")
    expect_contains(text, "closing honesty:", "closing honesty line")
    print("PASS: artefact render on an injected report (label, J-100 core, sections)")


def _dispatch_refused(args: List[String]) -> Bool:
    try:
        dispatch_bench(args)
    except _:
        return True
    return False


def test_cli_report_refusals() raises:
    var refused = 0
    if _dispatch_refused(List[String](["bench", "--report", "--pass", "prompt"])):
        refused += 1
    if _dispatch_refused(List[String](["bench", "--pass", "prompt", "--report"])):
        refused += 1
    if _dispatch_refused(List[String](["bench", "--report", "--report"])):
        refused += 1
    expect_eq(refused, 3, "report-mode incoherent invocations are refused")
    print("PASS: CLI report refusals (--report+--pass either order; duplicate --report)")


def test_live_fixture_artefact() raises:
    var options = resolve_placement_options(
        RawPlacementInputs(), RawPlacementInputs()
    )
    var facts = parse_cpuinfo(_vm_cpuinfo())
    var report = run_bench_sweep(
        options, _vm_inventory(), facts, BenchConfig()
    )
    expect_eq(report.cells_total(), 27, "artefact sweep enumerates the full field")
    var text = report_artefact(
        report,
        filed_model_rows(),
        String(
            "FIXTURE example -- fixture inventory/facts, live"
            " timings on this VM; not a live machine observation"
        ),
    )
    expect_contains(text, "artefact: FIXTURE example", "fixture label on its face")
    expect_contains(text, "cells: 27 enumerated", "sweep footer inside the artefact")
    expect_contains(text, "OLMoE Q4_K_M", "model table inside the artefact")
    expect_contains(text, "gpu absent", "refusal reasons inside the artefact")
    print("PASS: live fixture artefact (27 cells, model table, refusal reasons)")
    print("--- machine report artefact (FIXTURE inventory/facts, live timings) ---")
    print(text, end="")
    print("--- end machine report artefact ---")


def main() raises:
    test_filed_rows()
    test_model_table_render()
    test_device_refusal_summary()
    test_artefact_render_injected()
    test_cli_report_refusals()
    test_live_fixture_artefact()
    print("ALL PASS: machine report (6 groups)")
