"""Bench that measures configurations (Janas road J-100).

J-099's census row T08 stated the gap exactly: J-038 built the
placement measurement harness as a core layer (device candidates
per pass kind, settle + rounds), and J-039 built the thread
topology trials as a core layer (a thread-count ladder per pass
kind, same discipline) -- but no user-facing `bench` command
sweeps the configurations the placement engine may choose. This
module is that sweep, and cli/bench.mojo is its command.

THE SWEEP SPACE. The bench sweeps the cross product the roadmap
names -- threads x devices x pass kinds -- over exactly the field
Parts II/III filed, with no axis invented here:

- pass kinds (J-035, role-primary): prompt, draft-check, reply;
- devices: per kind, the candidates J-038's
  enumerate_candidates() produces under the default resolved
  options (every kind `auto`, no kills) -- one single-device
  candidate per device in the auto field, each carrying J-038's
  classification verbatim (MEASURABLE / EXCLUDED with the
  inventory's own refusal text / UNMEASURABLE-WITH-REASON);
- threads: per kind, the rungs of J-039's ladder derived from the
  machine's own CpuFacts (serial, half, all cores, plus SMT and
  performance-only rungs only when the machine states them).

A CELL is one (kind, device candidate, thread rung) triple. Every
cell is enumerated and reported; none is silently dropped. A cell
is MEASURED only where a real executor exists for it: today the
CPU cells of prompt and reply, whose medians come from J-039's
threaded executor (every threaded round's checksum asserted
identical to the serial workload's by that module). Every other
cell carries its classification and reason per rung -- the reason
is the device's or the kind's (draft-check: J-035 gap G1, always),
stated identically at each rung it blocks.

SETTLE AND ROUNDS. The discipline is J-038's HarnessConfig,
reused whole: settle rounds are executed and timed, then
DISCARDED; measured rounds are counted and summarized by their
MEDIAN, with min / max / spread beside it; per-candidate and
per-sweep hard bounds are checked between rounds and between
candidates, and a bound-stopped candidate reports the rounds that
stand. The bounds apply per kind-sweep (one device sweep and one
thread sweep per kind); the report prints each sweep's total and
the bench total, so the whole run's wall is accounted.

THE MACHINE REPORT. machine_report() renders a BenchReport as
one stable text: header + discipline + honesty lines, J-037's
device line and J-039's ladder description verbatim, then per
kind the device sweep's own report, the thread sweep's own
report, the cell table, and the kind's fastest measured cell (or
"no measured cell" with the reason true for the whole kind),
then the footer counts and total. It is a pure render: same
results, same text. J-101 grows `bench --report` (the filed
artefact form, per-model tables, filed examples) on top of this
render; nothing of J-101's scope lives here.

WORKLOAD HONESTY. The workloads are J-038's pass-shaped
micro-workloads, unchanged. Their timings are harness mechanics
on this machine -- they are NOT placement verdicts for any model
(J-040--J-042 own choices, on real passes), and the report says
so on its face.

HOST CONTRACT: run_bench_sweep(options, inventory, facts,
config) is a pure function of its inputs; a surface calls it on
demand and prints machine_report() of the result. This slice
wires it into exactly one surface -- the `bench` command
(cli/bench.mojo). No session consumes a bench report yet:
consumption (choice, the learned file) remains J-040--J-044's.
See docs/janas/J100_BENCH_CONFIGURATIONS.md.
"""

from core.placement_options import (
    DEVICE_CPU,
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    PlacementOptions,
    pass_name,
)
from core.device_inventory import CpuFacts, DeviceInventory
from core.placement_harness import (
    CAND_EXCLUDED,
    CAND_MEASURABLE,
    CAND_UNMEASURABLE,
    HarnessConfig,
    SweepResult,
    TimingSummary,
    WorkloadSpec,
    enumerate_candidates,
    monotonic_ns,
    prompt_workload,
    reply_workload,
    run_placement_measurement,
)
from core.thread_topology import (
    TRES_BOUND_STOPPED,
    TRES_MEASURED,
    ThreadLadder,
    ThreadSweep,
    derive_thread_ladder,
    run_thread_trials,
)

# Cell status (after classification; measured cells are filled by
# the runner from the thread sweep).
comptime CELL_MEASURED = 0
comptime CELL_EXCLUDED = 1
comptime CELL_UNMEASURABLE = 2
comptime CELL_BOUND_STOPPED = 3
# Pre-run status for a cell whose device candidate is measurable:
# the runner replaces it with the rung's thread-sweep outcome.
comptime CELL_PENDING = 4

# The pass kinds the bench sweeps, in taxonomy order.
comptime BENCH_KINDS = 3


def bench_pass_kind(index: Int) -> Int:
    """The bench's kind order: prompt, draft-check, reply."""
    if index == 0:
        return PASS_PROMPT
    if index == 1:
        return PASS_DRAFTS
    return PASS_REPLY


struct BenchConfig(Copyable, ImplicitlyCopyable):
    """The bench discipline: J-038's HarnessConfig, stated once.

    settle_rounds >= 1 and measured_rounds >= 3 are enforced by
    HarnessConfig itself (its refusals are this config's); the
    budgets keep J-038's defaults (per-candidate 2,000 ms,
    per-sweep 10,000 ms, applied per kind-sweep).
    """

    var harness: HarnessConfig

    def __init__(
        out self, settle_rounds: Int = 1, measured_rounds: Int = 5
    ) raises:
        self.harness = HarnessConfig(settle_rounds, measured_rounds)

    def describe(self) -> String:
        return (
            "settle "
            + String(self.harness.settle_rounds)
            + " discarded, "
            + String(self.harness.measured_rounds)
            + " measured rounds, median; per-candidate bound "
            + String(self.harness.per_candidate_budget_ns)
            + " ns, per-sweep bound "
            + String(self.harness.per_sweep_budget_ns)
            + " ns (per kind-sweep)"
        )


struct BenchCell(Copyable, ImplicitlyCopyable):
    """One cell of the cross product: a pass kind, one device
    candidate, one thread rung. Measured cells carry the thread
    sweep's summary for their rung; every other cell carries its
    classification and the exact reason, per rung."""

    var pass_kind: Int
    var device_label: String
    var device_code: Int
    var threads: Int
    var rung_label: String
    var status: Int
    var reason: String
    var settle_run: Int
    var summary: TimingSummary

    def __init__(out self):
        self.pass_kind = PASS_REPLY
        self.device_label = String("")
        self.device_code = DEVICE_CPU
        self.threads = 0
        self.rung_label = String("")
        self.status = CELL_UNMEASURABLE
        self.reason = String("not classified")
        self.settle_run = 0
        self.summary = TimingSummary()

    def render(self) -> String:
        var head = (
            pass_name(self.pass_kind)
            + " "
            + self.device_label
            + " threads="
            + String(self.threads)
            + " ("
            + self.rung_label
            + "): "
        )
        if self.status == CELL_MEASURED:
            return (
                head
                + "median "
                + String(self.summary.median_ns)
                + " ns (min "
                + String(self.summary.min_ns)
                + ", max "
                + String(self.summary.max_ns)
                + ", spread "
                + String(self.summary.spread_ns)
                + "; rounds "
                + String(self.summary.count)
                + ", settle "
                + String(self.settle_run)
                + " discarded)"
            )
        if self.status == CELL_BOUND_STOPPED:
            var line = head + "BOUND-STOPPED -- " + self.reason
            if self.summary.count > 0:
                line += (
                    " (rounds counted "
                    + String(self.summary.count)
                    + ", median "
                    + String(self.summary.median_ns)
                    + " ns over the counted rounds)"
                )
            return line
        if self.status == CELL_EXCLUDED:
            return head + "EXCLUDED -- " + self.reason
        if self.status == CELL_PENDING:
            return head + "PENDING -- classified measurable, not run"
        return head + "UNMEASURABLE -- " + self.reason


def _enumerate_kind_cells(
    options: PlacementOptions,
    inventory: DeviceInventory,
    ladder: ThreadLadder,
    pass_kind: Int,
) raises -> List[BenchCell]:
    """One kind's cells: its J-038 device candidates crossed with
    the ladder's rungs, classification carried verbatim."""
    var candidates = enumerate_candidates(options, inventory, pass_kind)
    var cells = List[BenchCell]()
    for cand in candidates:
        for rung in ladder.candidates:
            var cell = BenchCell()
            cell.pass_kind = pass_kind
            cell.device_label = cand.label
            cell.device_code = cand.first
            cell.threads = rung.threads
            cell.rung_label = rung.label
            if cand.status == CAND_MEASURABLE:
                cell.status = CELL_PENDING
                cell.reason = String("")
            elif cand.status == CAND_EXCLUDED:
                cell.status = CELL_EXCLUDED
                cell.reason = cand.reason
            else:
                cell.status = CELL_UNMEASURABLE
                cell.reason = cand.reason
            cells.append(cell)
    return cells^


def enumerate_bench_cells(
    options: PlacementOptions,
    inventory: DeviceInventory,
    facts: CpuFacts,
) raises -> List[BenchCell]:
    """The whole cross product, pre-run: every kind x device
    candidate x thread rung, classified. Measurable cells are
    CELL_PENDING here -- only run_bench_sweep may call a cell
    measured, and only from a real thread-sweep summary."""
    var ladder = derive_thread_ladder(facts)
    var cells = List[BenchCell]()
    for i in range(BENCH_KINDS):
        var kind_cells = _enumerate_kind_cells(
            options, inventory, ladder, bench_pass_kind(i)
        )
        for cell in kind_cells:
            cells.append(cell)
    return cells^


def fastest_cell_index(cells: List[BenchCell], pass_kind: Int) -> Int:
    """The index of one kind's fastest MEASURED cell: the lowest
    median; ties keep the first cell in table order. -1 when the
    kind has no measured cell -- a bound-stopped, excluded, or
    unmeasurable cell is never a "fastest" anything."""
    var best = -1
    for i in range(len(cells)):
        if cells[i].pass_kind != pass_kind:
            continue
        if cells[i].status != CELL_MEASURED:
            continue
        if best < 0 or cells[i].summary.median_ns < cells[best].summary.median_ns:
            best = i
    return best


struct KindBench(Copyable, Movable):
    """One kind's bench: the J-038 device sweep, the J-039 thread
    sweep, and the kind's cells with measured summaries filled."""

    var pass_kind: Int
    var device_sweep: SweepResult
    var thread_sweep: ThreadSweep
    var cells: List[BenchCell]
    var fastest: Int

    def __init__(out self, pass_kind: Int):
        self.pass_kind = pass_kind
        self.device_sweep = SweepResult(pass_kind)
        self.thread_sweep = ThreadSweep(pass_kind)
        self.cells = List[BenchCell]()
        self.fastest = -1

    def measured_count(self) -> Int:
        var total = 0
        for cell in self.cells:
            if cell.status == CELL_MEASURED:
                total += 1
        return total

    def render(self) -> String:
        var out_str = "== " + pass_name(self.pass_kind) + " ==\n"
        out_str += "-- device sweep --\n" + self.device_sweep.report()
        out_str += "-- thread sweep --\n" + self.thread_sweep.report()
        out_str += "-- cells (devices x threads) --\n"
        for cell in self.cells:
            out_str += cell.render() + "\n"
        if self.fastest >= 0:
            var cell = self.cells[self.fastest]
            out_str += (
                "fastest measured cell ("
                + pass_name(self.pass_kind)
                + "): "
                + cell.device_label
                + " threads="
                + String(cell.threads)
                + " ("
                + cell.rung_label
                + ") median "
                + String(cell.summary.median_ns)
                + " ns\n"
            )
        else:
            out_str += (
                "fastest measured cell ("
                + pass_name(self.pass_kind)
                + "): none -- no cell of this kind measured (see the"
                + " cell reasons above)\n"
            )
        return out_str


struct BenchReport(Copyable, Movable):
    """The whole bench: the machine's inventory and ladder, the
    discipline it ran under, one KindBench per kind, and the
    totals. machine_report() is its stable text render."""

    var config: BenchConfig
    var inventory: DeviceInventory
    var ladder: ThreadLadder
    var kinds: List[KindBench]
    var total_ns: Int

    def __init__(out self, config: BenchConfig):
        self.config = config
        self.inventory = DeviceInventory()
        self.ladder = ThreadLadder()
        self.kinds = List[KindBench]()
        self.total_ns = 0

    def cells_total(self) -> Int:
        var total = 0
        for kind in self.kinds:
            total += len(kind.cells)
        return total

    def cells_measured(self) -> Int:
        var total = 0
        for kind in self.kinds:
            total += kind.measured_count()
        return total

    def machine_report(self) -> String:
        var out_str = String("aesir bench — machine report\n")
        out_str += "discipline: " + self.config.describe() + "\n"
        out_str += (
            "honesty: pass-shaped micro-workload timings (harness"
            " mechanics on this machine) -- not placement verdicts"
            " for any model\n"
        )
        out_str += self.inventory.device_line() + "\n"
        out_str += self.ladder.describe() + "\n"
        for kind in self.kinds:
            out_str += kind.render()
        out_str += (
            "cells: "
            + String(self.cells_total())
            + " enumerated, "
            + String(self.cells_measured())
            + " measured\n"
        )
        out_str += "bench total " + String(self.total_ns) + " ns\n"
        out_str += (
            "not measured: every cell whose line above states"
            " EXCLUDED or UNMEASURABLE, with its reason -- an absent"
            " device, a device with no executor yet, or a pass kind"
            " that does not exist yet; nothing was timed in their"
            " names\n"
        )
        return out_str


def machine_report(report: BenchReport) -> String:
    """The report as a free function of the results (the module's
    stated render entry point): same results, same text."""
    return report.machine_report()


def _workload_for(pass_kind: Int) raises -> WorkloadSpec:
    if pass_kind == PASS_PROMPT:
        return prompt_workload()
    return reply_workload()


def run_bench_sweep(
    options: PlacementOptions,
    inventory: DeviceInventory,
    facts: CpuFacts,
    config: BenchConfig,
) raises -> BenchReport:
    """The bench entry point: per kind, the J-038 device sweep and
    the J-039 thread sweep under the one discipline, then the
    cell table with the CPU cells' summaries filled from the
    thread sweep (a rung that bound-stopped fills as
    BOUND-STOPPED with the rounds that stand; a draft-check kind
    fills nothing -- its thread sweep measures nothing, by G1).

    Pure function of its inputs, callable on demand; the hard
    bounds in `config` (per kind-sweep) are what keep the whole
    bench bounded. Raises only where a composed sweep raises
    (a workload checksum disagreement is a harness defect and is
    never averaged away).
    """
    var report = BenchReport(config)
    report.inventory = inventory
    report.ladder = derive_thread_ladder(facts)
    var bench_start = monotonic_ns()
    for i in range(BENCH_KINDS):
        var kind = bench_pass_kind(i)
        var spec = _workload_for(kind)
        var kind_bench = KindBench(kind)
        kind_bench.device_sweep = run_placement_measurement(
            options, inventory, kind, spec, config.harness
        )
        kind_bench.thread_sweep = run_thread_trials(
            facts, kind, spec, config.harness
        )
        kind_bench.cells = _enumerate_kind_cells(
            options, inventory, report.ladder, kind
        )
        # Fill the pending (CPU, measurable) cells from this kind's
        # thread sweep, rung by rung.
        for ci in range(len(kind_bench.cells)):
            if kind_bench.cells[ci].status != CELL_PENDING:
                continue
            for result in kind_bench.thread_sweep.results:
                if result.threads != kind_bench.cells[ci].threads:
                    continue
                if result.status == TRES_MEASURED:
                    kind_bench.cells[ci].status = CELL_MEASURED
                    kind_bench.cells[ci].reason = String("")
                    kind_bench.cells[ci].settle_run = result.settle_run
                    kind_bench.cells[ci].summary = result.summary
                elif result.status == TRES_BOUND_STOPPED:
                    kind_bench.cells[ci].status = CELL_BOUND_STOPPED
                    kind_bench.cells[ci].reason = result.reason
                    kind_bench.cells[ci].settle_run = result.settle_run
                    kind_bench.cells[ci].summary = result.summary
                else:
                    kind_bench.cells[ci].status = CELL_UNMEASURABLE
                    kind_bench.cells[ci].reason = result.reason
        kind_bench.fastest = fastest_cell_index(kind_bench.cells, kind)
        report.kinds.append(kind_bench^)
    report.total_ns = monotonic_ns() - bench_start
    return report^
