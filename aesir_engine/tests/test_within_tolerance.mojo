"""Within-tolerance proof (J-046): the pre-registered
tolerance rule on injected sweeps (auto == best is BEATEN;
gap at the target is MET and one hundredth beyond it is
MISSED, for both the prompt 1.50% and reply 2.60% targets,
with the gap arithmetic pinned exactly in hundredths of a
percent); the NOT PROVEN branches (chooser refusal, no
measured candidate, the chosen configuration absent from the
repetition's measured set); the aggregate rule over a shape's
repetitions (all-BEATEN, MET, one MISSED, one NOT PROVEN);
the percent formatter; the stable report; the live builder's
refusal of a manual option; and a live proof run -- the real
J-040/J-041 choosers, 3 repetitions per shape per kind, for
three J-044-keyed model shapes on this machine.

The live group measures HARNESS MECHANICS only: the workloads
are the harness's own fixed micro-workload shapes, the shape
enters as the J-044 key only, and no number here is a model
pass timing or a placement verdict for any model. Under this
VM's contention the honest live outcome may be MISSED or NOT
PROVEN repetitions; that is a legitimate filed result
(J-039/J-041's flip finding), not a failure.
"""
from core.device_inventory import observe_device_inventory
from core.learned_file import ModelShape, model_shape
from core.placement_harness import HarnessConfig
from core.placement_options import (
    DEVICE_CPU,
    PASS_PROMPT,
    PASS_REPLY,
    RawPlacementInputs,
    resolve_placement_options,
)
from core.thread_topology import observe_cpu_facts
from core.within_tolerance import (
    PROMPT_TARGET_X100,
    REPETITIONS,
    REPLY_TARGET_X100,
    RepetitionGrade,
    TC_BOUND_STOPPED,
    TC_MEASURED,
    ToleranceCandidate,
    ToleranceProof,
    aggregate_verdict,
    format_x100,
    grade_repetition,
    run_within_tolerance_proof,
    target_x100_for,
    verdict_name,
    VERDICT_BEATEN,
    VERDICT_MET,
    VERDICT_MISSED,
    VERDICT_NOT_PROVEN,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "WithinTolerance "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "WithinTolerance "
            + what
            + ": expected '"
            + expected
            + "', got '"
            + actual
            + "'"
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("WithinTolerance " + what + ": expected true")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "WithinTolerance "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


def _cand(threads: Int, median: Int) -> ToleranceCandidate:
    var c = ToleranceCandidate()
    c.label = "cpu threads=" + String(threads)
    c.device = DEVICE_CPU
    c.threads = threads
    c.status = TC_MEASURED
    c.median_ns = median
    return c


def _cand_stopped(threads: Int) -> ToleranceCandidate:
    var c = ToleranceCandidate()
    c.label = "cpu threads=" + String(threads)
    c.device = DEVICE_CPU
    c.threads = threads
    c.status = TC_BOUND_STOPPED
    c.median_ns = 0
    return c


def _sweep3(m1: Int, m2: Int, m4: Int) -> List[ToleranceCandidate]:
    var out = List[ToleranceCandidate]()
    out.append(_cand(1, m1))
    out.append(_cand(2, m2))
    out.append(_cand(4, m4))
    return out^


def test_beaten_when_auto_is_best() raises:
    var grade = grade_repetition(
        "shape-a",
        PASS_PROMPT,
        1,
        _sweep3(1000, 2000, 4000),
        "cpu threads=1",
        DEVICE_CPU,
        1,
        True,
        "DEFAULT-CONFIRMED",
    )
    expect_eq(grade.verdict, VERDICT_BEATEN, "auto==best verdict")
    expect_eq(grade.gap_x100, 0, "auto==best gap")
    expect_true(grade.has_numbers, "auto==best has numbers")
    expect_eq(grade.best_median_ns, 1000, "best median")
    expect_eq(grade.auto_median_ns, 1000, "auto median")
    print("PASS: tolerance -- auto is the best configuration (BEATEN, gap 0)")


def test_met_at_prompt_target_boundary() raises:
    var grade = grade_repetition(
        "shape-a",
        PASS_PROMPT,
        1,
        _sweep3(10150, 10000, 20000),
        "cpu threads=1",
        DEVICE_CPU,
        1,
        True,
        "DEFAULT-CONFIRMED",
    )
    expect_eq(grade.gap_x100, 150, "gap at the prompt target, exact")
    expect_eq(grade.verdict, VERDICT_MET, "gap at target is MET")
    expect_contains(grade.render(), "1.50%", "render shows the gap")
    print("PASS: tolerance -- gap exactly at the 1.50% prompt target is MET")


def test_missed_one_hundredth_beyond_prompt_target() raises:
    var grade = grade_repetition(
        "shape-a",
        PASS_PROMPT,
        1,
        _sweep3(10151, 10000, 20000),
        "cpu threads=1",
        DEVICE_CPU,
        1,
        True,
        "DEFAULT-CONFIRMED",
    )
    expect_eq(grade.gap_x100, 151, "gap one hundredth beyond, exact")
    expect_eq(grade.verdict, VERDICT_MISSED, "gap beyond target is MISSED")
    print("PASS: tolerance -- gap 1.51% on prompt is MISSED")


def test_reply_target_boundary_and_beyond() raises:
    var at = grade_repetition(
        "shape-a",
        PASS_REPLY,
        1,
        _sweep3(10260, 10000, 20000),
        "cpu threads=1",
        DEVICE_CPU,
        1,
        True,
        "DEFAULT-CONFIRMED",
    )
    expect_eq(at.gap_x100, 260, "gap at the reply target, exact")
    expect_eq(at.verdict, VERDICT_MET, "reply gap at target is MET")
    var beyond = grade_repetition(
        "shape-a",
        PASS_REPLY,
        1,
        _sweep3(10261, 10000, 20000),
        "cpu threads=1",
        DEVICE_CPU,
        1,
        True,
        "DEFAULT-CONFIRMED",
    )
    expect_eq(beyond.gap_x100, 261, "reply gap beyond, exact")
    expect_eq(beyond.verdict, VERDICT_MISSED, "reply gap beyond is MISSED")
    print("PASS: tolerance -- reply 2.60% target boundary MET, 2.61% MISSED")


def test_not_proven_when_chosen_not_measured() raises:
    var candidates = List[ToleranceCandidate]()
    candidates.append(_cand(1, 1000))
    candidates.append(_cand(2, 2000))
    candidates.append(_cand_stopped(4))
    var grade = grade_repetition(
        "shape-a",
        PASS_PROMPT,
        2,
        candidates,
        "cpu threads=4",
        DEVICE_CPU,
        4,
        True,
        "MEASURED-WIN",
    )
    expect_eq(grade.verdict, VERDICT_NOT_PROVEN, "unmeasured auto verdict")
    expect_true(not grade.has_numbers, "unmeasured auto has no numbers")
    expect_contains(
        grade.reason, "not among", "unmeasured auto reason is stated"
    )
    print("PASS: tolerance -- chosen rung bound-stopped in its sweep: NOT PROVEN")


def test_not_proven_when_nothing_measured_or_refused() raises:
    var empty = List[ToleranceCandidate]()
    empty.append(_cand_stopped(1))
    empty.append(_cand_stopped(2))
    var no_best = grade_repetition(
        "shape-a",
        PASS_REPLY,
        1,
        empty,
        "cpu threads=1",
        DEVICE_CPU,
        1,
        True,
        "NO-MEASURED-FALLBACK",
    )
    expect_eq(no_best.verdict, VERDICT_NOT_PROVEN, "no measured verdict")
    expect_contains(no_best.reason, "no candidate measured", "no-best reason")
    var refused = grade_repetition(
        "shape-a",
        PASS_REPLY,
        1,
        _sweep3(1000, 2000, 4000),
        "",
        DEVICE_CPU,
        0,
        False,
        "REFUSAL",
    )
    expect_eq(refused.verdict, VERDICT_NOT_PROVEN, "refusal verdict")
    expect_contains(refused.reason, "refused", "refusal reason")
    print("PASS: tolerance -- empty sweep and chooser refusal are NOT PROVEN")


def _beaten(shape: String, kind: Int, rep: Int) -> RepetitionGrade:
    return grade_repetition(
        shape, kind, rep, _sweep3(1000, 2000, 4000),
        "cpu threads=1", DEVICE_CPU, 1, True, "TEST",
    )


def _met(shape: String, kind: Int, rep: Int) -> RepetitionGrade:
    # Auto threads=1 at 10,100 vs best threads=2 at 10,000:
    # gap exactly 1.00% -- MET for prompt and reply alike.
    return grade_repetition(
        shape, kind, rep, _sweep3(10100, 10000, 20000),
        "cpu threads=1", DEVICE_CPU, 1, True, "TEST",
    )


def _missed(shape: String, kind: Int, rep: Int) -> RepetitionGrade:
    return grade_repetition(
        shape, kind, rep, _sweep3(20000, 10000, 30000),
        "cpu threads=1", DEVICE_CPU, 1, True, "TEST",
    )


def _not_proven(shape: String, kind: Int, rep: Int) -> RepetitionGrade:
    return grade_repetition(
        shape, kind, rep, _sweep3(1000, 2000, 4000),
        "", DEVICE_CPU, 0, False, "REFUSAL",
    )


def test_aggregate_rule() raises:
    var all_beaten = List[RepetitionGrade]()
    for rep in range(1, 4):
        all_beaten.append(_beaten("s", PASS_PROMPT, rep))
    expect_eq(
        aggregate_verdict(all_beaten, "s", PASS_PROMPT),
        VERDICT_BEATEN,
        "all-beaten aggregate",
    )
    var with_met = List[RepetitionGrade]()
    with_met.append(_beaten("s", PASS_PROMPT, 1))
    with_met.append(_met("s", PASS_PROMPT, 2))
    with_met.append(_beaten("s", PASS_PROMPT, 3))
    expect_eq(
        aggregate_verdict(with_met, "s", PASS_PROMPT),
        VERDICT_MET,
        "beaten+met aggregate",
    )
    var with_missed = List[RepetitionGrade]()
    with_missed.append(_beaten("s", PASS_PROMPT, 1))
    with_missed.append(_missed("s", PASS_PROMPT, 2))
    with_missed.append(_beaten("s", PASS_PROMPT, 3))
    expect_eq(
        aggregate_verdict(with_missed, "s", PASS_PROMPT),
        VERDICT_MISSED,
        "one missed repetition makes the aggregate MISSED",
    )
    var with_np = List[RepetitionGrade]()
    with_np.append(_missed("s", PASS_PROMPT, 1))
    with_np.append(_not_proven("s", PASS_PROMPT, 2))
    with_np.append(_beaten("s", PASS_PROMPT, 3))
    expect_eq(
        aggregate_verdict(with_np, "s", PASS_PROMPT),
        VERDICT_NOT_PROVEN,
        "a NOT PROVEN repetition makes the aggregate NOT PROVEN",
    )
    expect_eq(
        aggregate_verdict(with_np, "other-shape", PASS_PROMPT),
        VERDICT_NOT_PROVEN,
        "no repetitions for a shape is NOT PROVEN",
    )
    expect_eq(
        aggregate_verdict(with_np, "s", PASS_REPLY),
        VERDICT_NOT_PROVEN,
        "kinds aggregate separately",
    )
    print("PASS: tolerance -- aggregate rule (BEATEN/MET/MISSED/NOT PROVEN)")


def test_report_rendering() raises:
    var proof = ToleranceProof()
    proof.shape_names.append("shape-a")
    proof.grades.append(_beaten("shape-a", PASS_PROMPT, 1))
    proof.grades.append(_missed("shape-a", PASS_PROMPT, 2))
    proof.grades.append(_beaten("shape-a", PASS_PROMPT, 3))
    proof.grades.append(_met("shape-a", PASS_REPLY, 1))
    proof.grades.append(_met("shape-a", PASS_REPLY, 2))
    proof.grades.append(_met("shape-a", PASS_REPLY, 3))
    var report = proof.report()
    expect_contains(report, "shape: shape-a", "report names the shape")
    expect_contains(
        report, "aggregate [prompt]: MISSED", "report prompt aggregate"
    )
    expect_contains(report, "aggregate [reply]: MET", "report reply aggregate")
    expect_contains(
        report, "draft-check: NOT PROVEN", "report carries the drafts line"
    )
    expect_contains(report, "1.50%", "report states the prompt target")
    expect_contains(report, "2.60%", "report states the reply target")
    print("PASS: tolerance -- report renders aggregates and the drafts line")


def test_live_builder_refuses_manual() raises:
    var cli = RawPlacementInputs()
    cli.prompt = "cpu"
    cli.prompt_set = True
    var options = resolve_placement_options(cli, RawPlacementInputs())
    var inventory = observe_device_inventory()
    var facts = observe_cpu_facts()
    var shapes = List[ModelShape]()
    shapes.append(model_shape("olmoe", 2048, 16, 16, 16, 1024, 4096, 64, 8))
    var names = List[String]()
    names.append("shape-a")
    var refused = False
    try:
        var _proof = run_within_tolerance_proof(
            options, inventory, facts, HarnessConfig(), shapes, names
        )
    except:
        refused = True
    expect_true(refused, "a manual prompt option is refused by the builder")
    print("PASS: tolerance -- live builder refuses a manual option (auto only)")


def _live_shapes() -> List[ModelShape]:
    var shapes = List[ModelShape]()
    # OLMoE as measured from its sha-pinned file by J-015
    # (section 2 of its anatomy): ffn is the per-expert width.
    shapes.append(model_shape("olmoe", 2048, 16, 16, 16, 1024, 4096, 64, 8))
    # Granite MoE as measured by J-015 (section 2).
    shapes.append(
        model_shape("granitemoe", 1536, 32, 24, 8, 512, 131072, 40, 8)
    )
    # The dense shape the tree carries in the J-044/J-045
    # fixtures (Llama-3 class).
    shapes.append(
        model_shape("llama", 4096, 32, 32, 8, 14336, 131072, 0, 0)
    )
    return shapes^


def test_live_proof() raises:
    var options = resolve_placement_options(
        RawPlacementInputs(), RawPlacementInputs()
    )
    var inventory = observe_device_inventory()
    var facts = observe_cpu_facts()
    var names = List[String]()
    names.append("olmoe (J-015 measured shape)")
    names.append("granitemoe (J-015 measured shape)")
    names.append("llama dense (J-044/J-045 fixture shape)")
    var proof = run_within_tolerance_proof(
        options, inventory, facts, HarnessConfig(), _live_shapes(), names
    )
    print("LIVE WITHIN-TOLERANCE PROOF:\n" + proof.report())
    expect_eq(len(proof.shape_names), 3, "three shapes in the live proof")
    expect_eq(
        len(proof.grades),
        3 * 2 * REPETITIONS,
        "every shape x kind x repetition is graded and reported",
    )
    for g in proof.grades:
        expect_true(
            g.repetition >= 1 and g.repetition <= REPETITIONS,
            "repetition indices are the pre-registered ones",
        )
        if g.has_numbers:
            expect_true(
                g.gap_x100 >= 0,
                "a graded gap is never negative (auto is in the sweep)",
            )
            expect_true(g.best_median_ns > 0, "a graded best is positive")
    print("PASS: live within-tolerance proof over three shapes on this VM")


def test_format_and_targets() raises:
    expect_str(format_x100(0), "0.00", "format 0")
    expect_str(format_x100(5), "0.05", "format 5")
    expect_str(format_x100(150), "1.50", "format 150")
    expect_str(format_x100(260), "2.60", "format 260")
    expect_str(format_x100(12345), "123.45", "format 12345")
    expect_str(format_x100(-260), "-2.60", "format -260")
    expect_eq(target_x100_for(PASS_PROMPT), PROMPT_TARGET_X100, "prompt target")
    expect_eq(PROMPT_TARGET_X100, 150, "prompt target is 1.50%")
    expect_eq(target_x100_for(PASS_REPLY), REPLY_TARGET_X100, "reply target")
    expect_eq(REPLY_TARGET_X100, 260, "reply target is 2.60%")
    expect_eq(REPETITIONS, 3, "three repetitions are pre-registered")
    print("PASS: tolerance -- formatter and target pins exact")


def main() raises:
    test_beaten_when_auto_is_best()
    test_met_at_prompt_target_boundary()
    test_missed_one_hundredth_beyond_prompt_target()
    test_reply_target_boundary_and_beyond()
    test_not_proven_when_chosen_not_measured()
    test_not_proven_when_nothing_measured_or_refused()
    test_aggregate_rule()
    test_report_rendering()
    test_format_and_targets()
    test_live_builder_refuses_manual()
    test_live_proof()
    print("ALL PASS: within-tolerance proof (11 groups)")
