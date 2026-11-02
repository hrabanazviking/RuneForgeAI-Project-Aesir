"""The machine report artefact (Janas road J-101).

J-099's census row T09 stated the gap exactly: J-037 built the
device inventory (device_line() with refusal reasons), J-100
built the bench sweep and its machine_report() render -- but no
`bench --report` artefact existed: one sendable file carrying
(a) the hardware inventory, (b) a per-model read/write table,
and (c) the device lines with their refusal reasons. This module
is that artefact, built by extension on J-100's render: the
artefact OPENS with machine_report()'s text verbatim and appends
the two sections J-100 did not own, so the artefact can never
drift from the bench's own report.

THE PER-MODEL TABLE'S EVIDENCE RULE (J-101 doc section 0.2,
stated before building): a cell may carry only (i) a number
already proven or filed in this tree, cited on the line with its
source slice and honesty class, (ii) an exact-arithmetic
ACCOUNTED quantity from a filed accounting slice, cited the same
way, or (iii) NOT PROVEN with the reason. No wall, rate, or
latency is invented, simulated, or extrapolated for this table.
filed_model_rows() is the whole table: three rows, each re-read
first-hand from its source doc at this slice -- OLMoE's measured
CPU streaming line (J-030), the Coder-7B ladder witness whose
walls are deferred and whose frame is accounted (J-091), and the
Qwen3-Next 80B file the tree refuses before stepping (J-032).

THE DEVICE REFUSAL SUMMARY renders J-037's device_line()
verbatim, then each entry's own render() on its own line:
present devices quantified, absent devices carrying their exact
inventory reason -- never paraphrased, because the reason is the
part a developer acts on.

HOST CONTRACT: report_artefact(report, rows, label) is a pure
render of a BenchReport (from core/bench_configurations) plus
the filed rows; the label states the artefact's provenance on
its face ("live machine observation" for a CLI run; a fixture
render carries FIXTURE in its label and is never a live
example). cli/bench.mojo's --report mode is its one surface in
this slice. See docs/janas/J101_MACHINE_REPORT.md.
"""

from core.bench_configurations import BenchReport, machine_report
from core.device_inventory import DeviceInventory


struct ModelRow(Copyable, ImplicitlyCopyable):
    """One row of the per-model read/write table. Every field is
    filed text: the read/write cells carry their number or their
    NOT PROVEN reason, and source + honesty name where the cell's
    truth lives and how strong it is."""

    var model: String
    var line: String
    var read_cell: String
    var write_cell: String
    var source: String
    var honesty: String

    def __init__(out self):
        self.model = String("")
        self.line = String("")
        self.read_cell = String("")
        self.write_cell = String("")
        self.source = String("")
        self.honesty = String("")

    def render(self) -> String:
        return (
            self.model
            + " | "
            + self.line
            + " | read: "
            + self.read_cell
            + " | write: "
            + self.write_cell
            + " | source: "
            + self.source
            + " | honesty: "
            + self.honesty
        )


def filed_model_rows() -> List[ModelRow]:
    """The per-model read/write table's rows, under the evidence
    rule in this module's header. Adding a row means filing its
    number in a slice first -- this function cites, it never
    measures and never estimates."""
    var rows = List[ModelRow]()

    var olmoe = ModelRow()
    olmoe.model = String("OLMoE Q4_K_M")
    olmoe.line = String(
        "cpu+disk expert streaming, purplelongship, 512 MiB expert"
        " cache, ctx 512, 67-token prompt + 24 generated"
    )
    olmoe.read_cell = String("2.389 tok/s (prefill 28.04 s)")
    olmoe.write_cell = String("2.556 tok/s (decode 9.39 s)")
    olmoe.source = String(
        "J-030 section 4 (the J-022/J-023 legs re-verified; token"
        " identity across those legs PROVEN)"
    )
    olmoe.honesty = String("MEASURED-INDICATIVE (single runs per leg)")
    rows.append(olmoe)

    var coder = ModelRow()
    coder.model = String(
        "Qwen2.5-Coder-7B-Instruct-heretic Q4_K_M (wave crown pin"
        " 8053aeda)"
    )
    coder.line = String("context ladder 1k-32k, cpu f16 / gpu f16 (J-091)")
    coder.read_cell = String(
        "NOT PROVEN -- wall deferred (J-091 section 7); frame"
        " ACCOUNTED: KV f16 58720256 B at 1024 tokens,"
        " 1879048192 B at 32768"
    )
    coder.write_cell = String(
        "NOT PROVEN -- wall deferred (J-091 section 7); cpu"
        " 16384/32768 CAP_REFUSED (host cap 16000), gpu write at"
        " 32768 CAP_REFUSED (profile cap 32768)"
    )
    coder.source = String("J-091 sections 5-6 (ACCOUNTED ladder frame)")
    coder.honesty = String("ACCOUNTED frame / NOT PROVEN walls")
    rows.append(coder)

    var next80b = ModelRow()
    next80b.model = String(
        "Qwen3-Next-80B-A3B-Instruct Q4_K_M (48506100512 B, pin"
        " f73551b5)"
    )
    next80b.line = String("attempted on purplelongship (J-022), re-verified J-032")
    next80b.read_cell = String(
        "NOT PROVEN -- refused before any stepping (no qwen3next"
        " loader/forward in the tree; J-032 blocker B2)"
    )
    next80b.write_cell = String(
        "NOT PROVEN -- refused before any stepping (same B2;"
        " roaded to J-123)"
    )
    next80b.source = String("J-032 (refusal re-verified 25/25 checks)")
    next80b.honesty = String("NOT PROVEN")
    rows.append(next80b)

    return rows^


def model_table(rows: List[ModelRow]) -> String:
    """The per-model read/write section: the evidence rule on its
    face, then one line per filed row."""
    var out_str = String("== per-model read/write (filed evidence) ==\n")
    out_str += (
        "rule: a cell carries only a number already proven or"
        " filed in this tree (source + honesty on the line), an"
        " ACCOUNTED exact-arithmetic quantity, or NOT PROVEN with"
        " its reason -- nothing here is invented, simulated, or"
        " extrapolated\n"
    )
    for row in rows:
        out_str += row.render() + "\n"
    return out_str


def device_refusal_summary(inventory: DeviceInventory) -> String:
    """The device lines with refusal reasons: J-037's device
    line verbatim, then each entry on its own line -- present
    quantified, absent with its exact reason."""
    var out_str = String("== device lines with refusal reasons ==\n")
    out_str += inventory.device_line() + "\n"
    out_str += inventory.cpu.render() + "\n"
    out_str += inventory.gpu.render() + "\n"
    out_str += inventory.npu.render() + "\n"
    return out_str


def report_artefact(
    report: BenchReport, rows: List[ModelRow], label: String
) -> String:
    """The `bench --report` artefact: one sendable text.

    Opens with the provenance label, then J-100's machine_report()
    verbatim (hardware inventory, sweeps, cell table), then the
    per-model read/write table and the device refusal summary,
    then the closing honesty line. Pure render: same results,
    same text."""
    var out_str = "aesir bench --report — machine report artefact\n"
    out_str += "artefact: " + label + "\n"
    out_str += machine_report(report)
    out_str += model_table(rows)
    out_str += device_refusal_summary(report.inventory)
    out_str += (
        "closing honesty: this artefact is a bench report plus"
        " filed evidence -- its sweep timings are harness"
        " mechanics, not placement verdicts for any model, and"
        " its per-model cells claim only what their cited sources"
        " filed, at the honesty class printed on each line\n"
    )
    return out_str
