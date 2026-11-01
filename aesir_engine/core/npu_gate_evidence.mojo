"""NPU prompt: the gate-evidence account (Janas road J-062).

The roadmap text: "The exact evidence the Hailo
finish-line ledger would need to open this road (what
'text on the chip' proof implies for a prompt graph),
filed as a brief to that campaign; the slice closes
with the gate named, not crossed."

This module is the checkable half of that brief
(docs/janas/J062_NPU_PROMPT_GATE_BRIEF.md is its
normative text). It evaluates a stated evidence record
-- one Bool per checklist item, each item being an
artefact a named campaign must FILE, never a claim a
caller may merely assert in prose -- and returns the
gate verdict and the per-slice readiness verdicts for
the conditional slices J-063 / J-064 / J-065. It
executes nothing, opens no device, probes no chip, and
contains no speed. There is no path through this
account to an open gate with an item missing: the
verdicts are conjunctions over the record, and the
record's empty value (tonight's true state) evaluates
to closed at every level, with the first missing item
named at each level so a refusal states its reason.

THE GATE (brief section 2). The gate belongs to the
Hailo finish-line campaign and its ledger. It is
CLOSED tonight: J-037's inventory reports the NPU --
the Hailo-10H, the only NPU in Aesir's ledgers -- as
PARKED, reported from the ledger, not probed, never
run by this road. The gate opens only when the ledger
presents ALL FOUR gate items:

  G1 decision_recorded -- a decision to open this
     road, by Volmarr (the campaigns' owner) on the
     finish-line campaign's own record, filed where
     this road can cite it. No other hand opens it:
     not this road, not a keeper tick, not a passing
     test in this module.
  G2 chip_toolchain_identity -- the chip and the
     toolchain that ran on it, named with versions:
     silicon identity, compiler/driver/runtime
     versions, and the host the runs executed on.
     An unnamed chip proves nothing about any chip.
  G3 text_on_chip_evidence -- the finish-line
     campaign's own completion criterion, evidenced:
     text generating on the chip itself, filed as a
     run record (model file sha-pinned, prompt and
     generated ids filed), not as a summary claim.
  G4 prompt_graph_evidence -- what G3 does NOT by
     itself establish, and what a prompt pass
     additionally needs (brief section 3): a compiled
     prompt-shaped graph (a multi-token block read,
     not a one-token reply step) actually executing
     on the chip, with the host<->chip transfers
     stated, the output tensors returned to the host,
     and preparation completing for that graph. A
     generation proof exercises reply-shaped steps;
     a prompt graph is a different shape with its own
     compilation, transfer, and preparation facts.

THE J-063 START BLOCK (brief section 4). Even with
the gate open, J-063 (first light) may not start
until the start block is also complete. These items
are this road's own build/evidence list (J-061's
N-items and debts), each filed as an artefact:

  S1 executor_session_path (J-061 N1) -- a runnable
     NPU executor/session path exists in the tree and
     its smoke record is filed.
  S2 toolchain_binding_decision (J-061 N2) -- the
     graph/copy toolchain binding is DECIDED and
     recorded: which compiler stack the prompt graph
     and the 8-bit copies bind to, stated against the
     silicon G2 names. The census's stack (Intel Core
     Ultra NPU, self-written OpenVINO IR, Level Zero)
     and the ledger's stack (Hailo-10H, its own
     compiler road) are different silicon from
     different vendors; the account layer stays
     silicon-agnostic (J-061) and the binding names
     exactly one stack. An undecided binding is a
     missing item, not a detail.
  S3 copy_builder_graded (J-061 N3) -- the per-row
     8-bit copy builder exists and is graded
     standalone: copies dequantized back against the
     directory matrices with per-row error bounds
     filed (J-061 section 9's recipe order).
  S4 preparation_completes -- J-061's preparation
     account is consumed by a real open path:
     preparation completes cold and on a graph-cache
     hit, with its progress records filed (N4).
  S5 faithfulness_leg_ready -- the J-060 battery leg
     for the NPU cells is executable: the ggml CPU
     comparator oracle and its driver exist on the
     grading box (J-060's B-ORACLE / B-DRIVER), and
     the four-condition comparator check (CPU
     comparator only, raw prompt both sides, equal
     tokenization, identical BOS handling; never
     llama-cli --single-turn) is filed as the leg's
     pre-registered form. The grade itself is J-063's
     work, not a start item; readiness is.
  S6 contention_planner_run -- J-048's rule applied
     to the NPU copies on the LIVE stated pool
     through core/placement_pressure itself (not a
     paraphrase): the verdict for J-061's priced
     footprint is filed, and it is ADMITTED or the
     hand-named shapes are stated. J-061 priced the
     invariant on filed shapes; this item is the
     live-pool run. (J-065 owns the conditional
     contention leg proper; this item is its
     start-line evidence.)
  S7 thermal_power_machine_reporting -- the leg's
     filings carry machine state per run: load,
     temperature, power/thermal behaviour of the
     chip's host, and MemAvailable, recorded at
     start/end -- the road's standing machine
     discipline, applied to a chip whose thermal
     facts are otherwise unfiled anywhere.
  S8 reproducibility_pack -- every leg filing names
     its model file by full sha256, its hardware by
     G2's identity, and its machine state by S7, so
     any filed number can be re-run by another hand.

DOWNSTREAM ITEMS. J-064 (split-block) additionally
needs D1 dense_whole_graded (the dense-whole cell
graded FAITHFUL or NEAR_TIE through J-060's battery
-- ids first, then teacher-forcing rank + logit gap,
near-tie band rank <= 2 AND sub-logit gap, both
conjuncts binding) and D2 split_executor_exists
(J-061 N5). J-065 (contention rule, live) additionally
needs D3 live_copies_exist (real NPU copies occupying
a real pool beside a real expert cache -- the
abstract planner call of J-061 section 7 is not this
item). Resident-products call-site binding (N6) and
chooser measurability (N8) gate their own forms'
later legs, not these three slices' starts, and are
recorded in the brief, not in this account.

WHAT AN OPEN GATE NEVER PROVES (brief section 6):
no wall, no tok/s, no preparation time, and no
faithfulness for any NPU form follows from any
verdict this module returns. OPEN means the evidence
to START measuring exists. Every quantity remains
NOT PROVEN until its own measured leg runs and files.

HOST CONTRACT: a keeper or worker evaluating this
road's state (1) builds the evidence record ONLY
from filed artefacts it has read (a ledger entry, a
run record, a graded cell, a planner filing), never
from summaries or intentions; (2) calls
evaluate_npu_gate; (3) follows the verdicts exactly:
gate closed -> J-063/J-064/J-065 record themselves
DEFERRED-WITH-REASON and the road continues; (4)
files the record it evaluated beside its verdict, so
the evaluation is itself reproducible. Tonight's
record is the empty one (brief section 5).
"""

# Gate items (the finish-line ledger presents these).
comptime GATE_ITEM_DECISION = 1
comptime GATE_ITEM_CHIP_TOOLCHAIN = 2
comptime GATE_ITEM_TEXT_ON_CHIP = 3
comptime GATE_ITEM_PROMPT_GRAPH = 4
comptime GATE_ITEMS_TOTAL = 4

# J-063 start items (this road's own list).
comptime START_ITEM_EXECUTOR = 1
comptime START_ITEM_TOOLCHAIN_BINDING = 2
comptime START_ITEM_COPY_BUILDER = 3
comptime START_ITEM_PREPARATION = 4
comptime START_ITEM_FAITHFULNESS_LEG = 5
comptime START_ITEM_CONTENTION = 6
comptime START_ITEM_THERMAL_MACHINE = 7
comptime START_ITEM_REPRODUCIBILITY = 8
comptime START_ITEMS_TOTAL = 8


def gate_item_name(item: Int) -> String:
    if item == GATE_ITEM_DECISION:
        return String("decision_recorded")
    if item == GATE_ITEM_CHIP_TOOLCHAIN:
        return String("chip_toolchain_identity")
    if item == GATE_ITEM_TEXT_ON_CHIP:
        return String("text_on_chip_evidence")
    if item == GATE_ITEM_PROMPT_GRAPH:
        return String("prompt_graph_evidence")
    return String("unknown_gate_item")


def start_item_name(item: Int) -> String:
    if item == START_ITEM_EXECUTOR:
        return String("executor_session_path")
    if item == START_ITEM_TOOLCHAIN_BINDING:
        return String("toolchain_binding_decision")
    if item == START_ITEM_COPY_BUILDER:
        return String("copy_builder_graded")
    if item == START_ITEM_PREPARATION:
        return String("preparation_completes")
    if item == START_ITEM_FAITHFULNESS_LEG:
        return String("faithfulness_leg_ready")
    if item == START_ITEM_CONTENTION:
        return String("contention_planner_run")
    if item == START_ITEM_THERMAL_MACHINE:
        return String("thermal_power_machine_reporting")
    if item == START_ITEM_REPRODUCIBILITY:
        return String("reproducibility_pack")
    return String("unknown_start_item")


struct GateEvidence(Copyable, ImplicitlyCopyable):
    """One stated evidence record: one Bool per
    checklist item, True only where the item's
    artefact has been filed and read by the
    evaluator. The all-False value is tonight's true
    record (the brief's section 5)."""

    var decision_recorded: Bool
    var chip_toolchain_identity: Bool
    var text_on_chip_evidence: Bool
    var prompt_graph_evidence: Bool
    var executor_session_path: Bool
    var toolchain_binding_decision: Bool
    var copy_builder_graded: Bool
    var preparation_completes: Bool
    var faithfulness_leg_ready: Bool
    var contention_planner_run: Bool
    var thermal_power_machine_reporting: Bool
    var reproducibility_pack: Bool
    var dense_whole_graded: Bool
    var split_executor_exists: Bool
    var live_copies_exist: Bool

    def __init__(
        out self,
        decision_recorded: Bool,
        chip_toolchain_identity: Bool,
        text_on_chip_evidence: Bool,
        prompt_graph_evidence: Bool,
        executor_session_path: Bool,
        toolchain_binding_decision: Bool,
        copy_builder_graded: Bool,
        preparation_completes: Bool,
        faithfulness_leg_ready: Bool,
        contention_planner_run: Bool,
        thermal_power_machine_reporting: Bool,
        reproducibility_pack: Bool,
        dense_whole_graded: Bool,
        split_executor_exists: Bool,
        live_copies_exist: Bool,
    ):
        self.decision_recorded = decision_recorded
        self.chip_toolchain_identity = chip_toolchain_identity
        self.text_on_chip_evidence = text_on_chip_evidence
        self.prompt_graph_evidence = prompt_graph_evidence
        self.executor_session_path = executor_session_path
        self.toolchain_binding_decision = toolchain_binding_decision
        self.copy_builder_graded = copy_builder_graded
        self.preparation_completes = preparation_completes
        self.faithfulness_leg_ready = faithfulness_leg_ready
        self.contention_planner_run = contention_planner_run
        self.thermal_power_machine_reporting = (
            thermal_power_machine_reporting
        )
        self.reproducibility_pack = reproducibility_pack
        self.dense_whole_graded = dense_whole_graded
        self.split_executor_exists = split_executor_exists
        self.live_copies_exist = live_copies_exist


def empty_gate_evidence() -> GateEvidence:
    """The record with no item filed -- tonight's
    true state, and the fail-closed default any
    evaluator starts from before reading artefacts."""
    return GateEvidence(
        False, False, False, False,
        False, False, False, False,
        False, False, False, False,
        False, False, False,
    )


struct GateVerdict(Copyable, ImplicitlyCopyable):
    """The evaluation of one evidence record: the
    gate verdict, the three conditional slices'
    readiness verdicts, the present/missing counts
    for the gate and start blocks, and the first
    missing item at each level (0 = none missing) so
    every refusal names its reason."""

    var gate_open: Bool
    var j063_ready: Bool
    var j064_ready: Bool
    var j065_ready: Bool
    var gate_present: Int
    var gate_missing: Int
    var start_present: Int
    var start_missing: Int
    var first_missing_gate_item: Int
    var first_missing_start_item: Int

    def __init__(
        out self,
        gate_open: Bool,
        j063_ready: Bool,
        j064_ready: Bool,
        j065_ready: Bool,
        gate_present: Int,
        gate_missing: Int,
        start_present: Int,
        start_missing: Int,
        first_missing_gate_item: Int,
        first_missing_start_item: Int,
    ):
        self.gate_open = gate_open
        self.j063_ready = j063_ready
        self.j064_ready = j064_ready
        self.j065_ready = j065_ready
        self.gate_present = gate_present
        self.gate_missing = gate_missing
        self.start_present = start_present
        self.start_missing = start_missing
        self.first_missing_gate_item = first_missing_gate_item
        self.first_missing_start_item = first_missing_start_item


def gate_state_name(open: Bool) -> String:
    if open:
        return String("open")
    return String("closed")


def evaluate_npu_gate(ev: GateEvidence) -> GateVerdict:
    """Evaluate one stated evidence record. Every
    verdict is a conjunction over the record: the
    gate needs all four gate items; J-063 needs the
    gate plus all eight start items; J-064 needs
    J-063's readiness plus the dense-whole grade and
    the split executor; J-065 needs J-063's readiness
    plus live copies in a live pool. No item
    substitutes for another, and no partial record
    opens anything."""
    var gate_flags = List[Bool]()
    gate_flags.append(ev.decision_recorded)
    gate_flags.append(ev.chip_toolchain_identity)
    gate_flags.append(ev.text_on_chip_evidence)
    gate_flags.append(ev.prompt_graph_evidence)
    var gate_present = 0
    var first_missing_gate = 0
    for i in range(len(gate_flags)):
        if gate_flags[i]:
            gate_present += 1
        elif first_missing_gate == 0:
            first_missing_gate = i + 1
    var start_flags = List[Bool]()
    start_flags.append(ev.executor_session_path)
    start_flags.append(ev.toolchain_binding_decision)
    start_flags.append(ev.copy_builder_graded)
    start_flags.append(ev.preparation_completes)
    start_flags.append(ev.faithfulness_leg_ready)
    start_flags.append(ev.contention_planner_run)
    start_flags.append(ev.thermal_power_machine_reporting)
    start_flags.append(ev.reproducibility_pack)
    var start_present = 0
    var first_missing_start = 0
    for i in range(len(start_flags)):
        if start_flags[i]:
            start_present += 1
        elif first_missing_start == 0:
            first_missing_start = i + 1
    var gate_open = gate_present == GATE_ITEMS_TOTAL
    var j063_ready = gate_open and start_present == START_ITEMS_TOTAL
    var j064_ready = (
        j063_ready and ev.dense_whole_graded and ev.split_executor_exists
    )
    var j065_ready = j063_ready and ev.live_copies_exist
    return GateVerdict(
        gate_open,
        j063_ready,
        j064_ready,
        j065_ready,
        gate_present,
        GATE_ITEMS_TOTAL - gate_present,
        start_present,
        START_ITEMS_TOTAL - start_present,
        first_missing_gate,
        first_missing_start,
    )
