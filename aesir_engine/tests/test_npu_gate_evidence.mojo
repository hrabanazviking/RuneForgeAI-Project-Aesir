"""NPU gate-evidence account (J-062): the gate is a
conjunction over a stated evidence record, refused by
construction when any required item is absent.

The cases pin, in order: tonight's true record (empty
-- the gate closed at every level, first missing items
named); text-on-chip ALONE does not open the gate (the
brief's central implication: a generation proof is not
a prompt-graph proof); the gate block complete through
G3 but missing G4 stays closed with G4 named; the gate
block complete opens the GATE and nothing else (J-063
still not ready, first start item named); gate + start
complete makes J-063 ready and neither downstream
slice; the downstream items each gate their own slice
and no other; a mid-block gap names the first missing
start item exactly; the full record opens every level;
and the item/state names render as the brief's exact
strings. No device, no run, no wall -- the account
evaluates stated records.
"""
from core.npu_gate_evidence import (
    GATE_ITEM_PROMPT_GRAPH,
    GATE_ITEM_TEXT_ON_CHIP,
    GATE_ITEMS_TOTAL,
    START_ITEM_COPY_BUILDER,
    START_ITEMS_TOTAL,
    GateEvidence,
    empty_gate_evidence,
    evaluate_npu_gate,
    gate_item_name,
    gate_state_name,
    start_item_name,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "NpuGateEvidence "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_bool(actual: Bool, expected: Bool, what: String) raises:
    if actual != expected:
        raise Error("NpuGateEvidence " + what + ": unexpected verdict")


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "NpuGateEvidence "
            + what
            + ": expected '"
            + expected
            + "', got '"
            + actual
            + "'"
        )


def record(
    g1: Bool, g2: Bool, g3: Bool, g4: Bool,
    s1: Bool, s2: Bool, s3: Bool, s4: Bool,
    s5: Bool, s6: Bool, s7: Bool, s8: Bool,
    d1: Bool, d2: Bool, d3: Bool,
) -> GateEvidence:
    return GateEvidence(
        g1, g2, g3, g4, s1, s2, s3, s4, s5, s6, s7, s8, d1, d2, d3
    )


def test_tonight_empty_record() raises:
    # Tonight's true state: no item filed anywhere.
    # The gate is closed at every level and both first
    # missing items are the blocks' first items.
    var v = evaluate_npu_gate(empty_gate_evidence())
    expect_bool(v.gate_open, False, "empty record gate")
    expect_bool(v.j063_ready, False, "empty record j063")
    expect_bool(v.j064_ready, False, "empty record j064")
    expect_bool(v.j065_ready, False, "empty record j065")
    expect_eq(v.gate_present, 0, "empty record gate present")
    expect_eq(v.gate_missing, GATE_ITEMS_TOTAL, "empty record gate missing")
    expect_eq(v.start_present, 0, "empty record start present")
    expect_eq(v.start_missing, START_ITEMS_TOTAL, "empty record start missing")
    expect_eq(v.first_missing_gate_item, 1, "empty record first gate gap")
    expect_eq(v.first_missing_start_item, 1, "empty record first start gap")
    print("PASS: tonight's empty record -- gate closed at every level, gaps named")


def test_text_on_chip_alone() raises:
    # The brief's central implication, pinned: the
    # finish-line criterion by itself (G3) opens
    # nothing -- no decision, no identity, and above
    # all no prompt-graph evidence.
    var ev = record(
        False, False, True, False,
        False, False, False, False,
        False, False, False, False,
        False, False, False,
    )
    var v = evaluate_npu_gate(ev)
    expect_bool(v.gate_open, False, "text-only gate")
    expect_eq(v.gate_present, 1, "text-only gate present")
    expect_eq(v.first_missing_gate_item, 1, "text-only first gap is the decision")
    print("PASS: text-on-chip alone -- gate stays closed (generation is not a prompt graph)")


def test_gate_block_missing_prompt_graph() raises:
    # Decision + identity + text-on-chip, but no
    # prompt-shaped graph has ever executed: closed,
    # and the missing item named is G4 exactly.
    var ev = record(
        True, True, True, False,
        False, False, False, False,
        False, False, False, False,
        False, False, False,
    )
    var v = evaluate_npu_gate(ev)
    expect_bool(v.gate_open, False, "no-prompt-graph gate")
    expect_eq(v.gate_present, 3, "no-prompt-graph present")
    expect_eq(
        v.first_missing_gate_item, GATE_ITEM_PROMPT_GRAPH,
        "no-prompt-graph first gap",
    )
    expect_str(
        gate_item_name(v.first_missing_gate_item),
        String("prompt_graph_evidence"), "G4 name",
    )
    print("PASS: gate block through G3 -- closed, first missing item is prompt_graph_evidence")


def test_gate_open_start_closed() raises:
    # The full gate block opens the GATE -- and only
    # the gate. J-063 readiness still needs the whole
    # start block; its first gap is the executor.
    var ev = record(
        True, True, True, True,
        False, False, False, False,
        False, False, False, False,
        False, False, False,
    )
    var v = evaluate_npu_gate(ev)
    expect_bool(v.gate_open, True, "full gate block opens the gate")
    expect_bool(v.j063_ready, False, "gate alone does not ready J-063")
    expect_eq(v.gate_missing, 0, "gate block complete")
    expect_eq(v.first_missing_gate_item, 0, "no gate gap")
    expect_eq(v.first_missing_start_item, 1, "first start gap is the executor")
    expect_str(
        start_item_name(v.first_missing_start_item),
        String("executor_session_path"), "S1 name",
    )
    print("PASS: gate block complete -- gate open, J-063 not ready, executor named")


def test_j063_ready_downstream_closed() raises:
    var ev = record(
        True, True, True, True,
        True, True, True, True,
        True, True, True, True,
        False, False, False,
    )
    var v = evaluate_npu_gate(ev)
    expect_bool(v.gate_open, True, "j063 case gate")
    expect_bool(v.j063_ready, True, "gate + start readies J-063")
    expect_bool(v.j064_ready, False, "no downstream items, no J-064")
    expect_bool(v.j065_ready, False, "no live copies, no J-065")
    expect_eq(v.start_missing, 0, "start block complete")
    expect_eq(v.first_missing_start_item, 0, "no start gap")
    print("PASS: gate + start complete -- J-063 ready, J-064/J-065 still closed")


def test_downstream_items_gate_their_own_slices() raises:
    # Dense-whole grade + split executor ready J-064
    # and say nothing about J-065; live copies ready
    # J-065 and say nothing about J-064.
    var ev64 = record(
        True, True, True, True,
        True, True, True, True,
        True, True, True, True,
        True, True, False,
    )
    var v64 = evaluate_npu_gate(ev64)
    expect_bool(v64.j064_ready, True, "grade + split executor readies J-064")
    expect_bool(v64.j065_ready, False, "J-064 items do not ready J-065")
    var ev65 = record(
        True, True, True, True,
        True, True, True, True,
        True, True, True, True,
        False, False, True,
    )
    var v65 = evaluate_npu_gate(ev65)
    expect_bool(v65.j065_ready, True, "live copies ready J-065")
    expect_bool(v65.j064_ready, False, "live copies do not ready J-064")
    print("PASS: downstream items -- each gates its own slice and no other")


def test_mid_block_gap_named() raises:
    # Start block present through S2, missing S3: the
    # first missing start item is the copy builder,
    # named exactly -- a refusal states its reason.
    var ev = record(
        True, True, True, True,
        True, True, False, True,
        True, True, True, True,
        False, False, False,
    )
    var v = evaluate_npu_gate(ev)
    expect_bool(v.j063_ready, False, "mid-block gap keeps J-063 closed")
    expect_eq(v.start_present, 7, "mid-block present count")
    expect_eq(
        v.first_missing_start_item, START_ITEM_COPY_BUILDER,
        "mid-block first gap",
    )
    expect_str(
        start_item_name(v.first_missing_start_item),
        String("copy_builder_graded"), "S3 name",
    )
    print("PASS: mid-block gap -- first missing start item is copy_builder_graded")


def test_start_without_gate() raises:
    # Every start and downstream item filed but the
    # gate block empty: nothing is ready at any
    # level. This road cannot open its own gate by
    # completing its own homework.
    var ev = record(
        False, False, False, False,
        True, True, True, True,
        True, True, True, True,
        True, True, True,
    )
    var v = evaluate_npu_gate(ev)
    expect_bool(v.gate_open, False, "start-only gate")
    expect_bool(v.j063_ready, False, "start-only j063")
    expect_bool(v.j064_ready, False, "start-only j064")
    expect_bool(v.j065_ready, False, "start-only j065")
    expect_eq(v.start_present, 8, "start-only start present")
    print("PASS: start block without the gate -- nothing ready at any level")


def test_full_record() raises:
    var ev = record(
        True, True, True, True,
        True, True, True, True,
        True, True, True, True,
        True, True, True,
    )
    var v = evaluate_npu_gate(ev)
    expect_bool(v.gate_open, True, "full record gate")
    expect_bool(v.j063_ready, True, "full record j063")
    expect_bool(v.j064_ready, True, "full record j064")
    expect_bool(v.j065_ready, True, "full record j065")
    expect_eq(v.gate_present, GATE_ITEMS_TOTAL, "full record gate present")
    expect_eq(v.start_present, START_ITEMS_TOTAL, "full record start present")
    print("PASS: full record -- gate open, all three slices ready (readiness only, no quantity)")


def test_names() raises:
    expect_str(gate_item_name(1), String("decision_recorded"), "G1 name")
    expect_str(
        gate_item_name(2), String("chip_toolchain_identity"), "G2 name"
    )
    expect_str(
        gate_item_name(GATE_ITEM_TEXT_ON_CHIP),
        String("text_on_chip_evidence"), "G3 name",
    )
    expect_str(gate_item_name(99), String("unknown_gate_item"), "gate fallback")
    expect_str(start_item_name(5), String("faithfulness_leg_ready"), "S5 name")
    expect_str(
        start_item_name(8), String("reproducibility_pack"), "S8 name"
    )
    expect_str(
        start_item_name(99), String("unknown_start_item"), "start fallback"
    )
    expect_str(gate_state_name(False), String("closed"), "closed name")
    expect_str(gate_state_name(True), String("open"), "open name")
    print("PASS: names -- gate/start item and state strings exact")


def main() raises:
    test_tonight_empty_record()
    test_text_on_chip_alone()
    test_gate_block_missing_prompt_graph()
    test_gate_open_start_closed()
    test_j063_ready_downstream_closed()
    test_downstream_items_gate_their_own_slices()
    test_mid_block_gap_named()
    test_start_without_gate()
    test_full_record()
    test_names()
    print("ALL PASS: NPU gate-evidence account (10 groups)")
