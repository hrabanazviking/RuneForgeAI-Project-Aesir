"""Within-tolerance proof: auto choice vs the full sweep
(Janas road J-046).

J-040/J-041 built the auto choosers for the prompt and reply
pass kinds, J-042 the draft-check chooser (which can only fall
back honestly: Aesir has no draft-check pass, J-035 gap G1),
J-044 the learned file keyed by machine + model shape, and
J-045 the re-trial cadence. This module is the proof those
slices point at: it runs the REAL choosers against the REAL
full configuration sweep, per model shape, and grades how far
the auto choice lands from the best configuration the sweep
measured -- the roadmap's J-046 sentence, tested against the
tolerance Janas publishes for its own auto choice.

THE TOLERANCE RULE, pre-registered (stated here and in
docs/janas/J046_WITHIN_TOLERANCE.md before any J-046 live
number was measured; grade_repetition and aggregate_verdict
are its pure forms, unit-tested on injected measurements):

- Per model shape, per pass kind (prompt = reading, reply =
  writing), per REPETITION:
  - FULL SWEEP = every candidate the kind's chooser can rank:
    every measured thread rung of the J-039 ladder on this
    machine (the thread axis, one threaded executor, medians
    comparable within the sweep). The device axis is NOT in
    the sweep and is named, never silently dropped: the J-038
    device sweep's CPU timing is a cross-check from a
    different executor and is never ranked (J-040's rule);
    GPU/NPU singles and co-work forms carry no executor today
    and stand EXCLUDED / UNMEASURABLE-WITH-REASON on every
    chooser record with their verbatim reasons.
  - BEST = the lowest median among the sweep's MEASURED
    candidates (full rounds only; bound-stopped candidates
    are recorded and never ranked, per J-040).
  - AUTO = the median, IN THE SAME REPETITION'S SWEEP, of
    the configuration the real chooser actually chose (its
    chosen device + thread count looked up among the sweep's
    measured candidates). Grading the choice against its own
    sweep is the only honest comparison: J-039/J-041 proved
    medians move between sweeps under contention, so a choice
    from one sweep graded against another sweep's best would
    grade the weather, not the chooser.
  - GAP % = (auto_median - best_median) / best_median * 100,
    carried in hundredths of a percent (gap_x100) so the
    arithmetic is exact integer work.
  - TARGETS (Janas's published claim for ITS auto choice on
    ITS machine, adopted here as a TARGET to test, never as
    Aesir's numbers): prompt <= 1.5%, reply <= 2.6%.
  - Per-repetition verdict: BEATEN when auto == best
    (gap 0 -- the chooser picked the sweep's fastest
    configuration); MET when 0 < gap <= target; MISSED when
    gap > target; NOT PROVEN, with the reason, when the
    repetition holds no gradeable pair (the chooser refused,
    no candidate measured, or the chosen configuration is
    not among the repetition's measured candidates -- e.g.
    it was bound-stopped in this sweep).
- REPETITIONS: exactly REPETITIONS (3) independent
  chooser-vs-sweep repetitions per shape per kind, run back
  to back, ALL of them reported. J-039/J-041 proved single
  sweeps flip under contention, so no verdict rests on one
  sweep, and no repetition is re-run, dropped, or replaced
  because its outcome is unwelcome.
- AGGREGATE verdict per shape per kind, from its 3
  repetitions: BEATEN when every repetition is BEATEN; MET
  when every repetition is BEATEN or MET and at least one
  is MET; MISSED when at least one repetition is MISSED and
  none is NOT PROVEN (a single over-target repetition means
  the claim "auto lands within tolerance" does not hold for
  that shape on this machine in this window); NOT PROVEN
  when at least one repetition is NOT PROVEN (the window
  did not produce three gradeable repetitions; a MISSED
  riding beside it is still reported per repetition).
- DRAFT-CHECK is not graded: no draft-check pass exists
  (J-035 G1), every draft-check candidate is
  UNMEASURABLE-WITH-REASON in the harness, and a tolerance
  grade needs a measured pair. It stands NOT PROVEN with
  that reason on every proof report; no proxy is faked.
  Part V (J-071/J-072) owns the pass that could change this.

WHAT A "MODEL" IS HERE, stated plainly. The choosers take no
model argument and the harness workloads are fixed shapes
(prompt: 16 rows x (512 -> 256), reps 2; reply: 1 row x
(1024 -> 512), reps 4 -- core/placement_harness.mojo). The
model shape therefore enters this proof ONLY as the J-044
learned-file key under which the repetition is filed: three
distinct shapes, each repetition keyed and reported under
its shape, measuring the same harness workloads. The
measurements are NOT expected to differ systematically by
shape, and no per-model placement claim is made beyond the
per-shape grading of the chooser's own behaviour. No model
inference runs in this slice, and no number here is a model
pass timing: every number is the harness micro-workload's,
on this machine, in this window.

HOST CONTRACT: run_within_tolerance_proof(options, inventory,
facts, config, shapes, shape_names) is the live entry point;
both the prompt and reply options must be auto (the proof
grades the AUTO choice; a manual option has no auto choice
to grade and the builder refuses it). A surface runs it on
demand and prints ToleranceProof.report(). This slice wires
it into NO live session path: no session consumes a tolerance
proof, and claiming otherwise would fake the integration.
See docs/janas/J046_WITHIN_TOLERANCE.md.
"""

from core.device_inventory import CpuFacts, DeviceInventory
from core.learned_file import ModelShape
from core.placement_harness import HarnessConfig
from core.placement_options import (
    PASS_PROMPT,
    PASS_REPLY,
    PLACE_AUTO,
    PlacementOptions,
    pass_name,
)
from core.prompt_placement import (
    PromptChoiceRecord,
    choose_prompt_placement,
    decision_name,
)
from core.reply_placement import (
    ReplyChoiceRecord,
    choose_reply_placement,
)

# Candidate status, mirroring the choosers' PM_* codes (the
# values coincide in prompt_placement and reply_placement:
# measured 0, excluded 1, unmeasurable 2, bound-stopped 3).
comptime TC_MEASURED = 0
comptime TC_EXCLUDED = 1
comptime TC_UNMEASURABLE = 2
comptime TC_BOUND_STOPPED = 3

# Verdict codes (per repetition and aggregate alike).
comptime VERDICT_BEATEN = 0
comptime VERDICT_MET = 1
comptime VERDICT_MISSED = 2
comptime VERDICT_NOT_PROVEN = 3

# The pre-registered targets, in hundredths of a percent:
# prompt (reading) 1.50%, reply (writing) 2.60% -- Janas's
# published claim for its own auto choice, adopted as the
# target this proof tests (module header).
comptime PROMPT_TARGET_X100 = 150
comptime REPLY_TARGET_X100 = 260

# The pre-registered repetition count per shape per kind.
comptime REPETITIONS = 3


def verdict_name(code: Int) -> String:
    if code == VERDICT_BEATEN:
        return String("BEATEN")
    if code == VERDICT_MET:
        return String("MET")
    if code == VERDICT_MISSED:
        return String("MISSED")
    return String("NOT PROVEN")


def target_x100_for(kind: Int) -> Int:
    if kind == PASS_REPLY:
        return REPLY_TARGET_X100
    return PROMPT_TARGET_X100


def format_x100(value: Int) -> String:
    """Render hundredths-of-a-percent as a fixed 2-decimal
    string (150 -> '1.50', 5 -> '0.05', -260 -> '-2.60')."""
    var sign = String("")
    var v = value
    if v < 0:
        sign = String("-")
        v = -v
    var whole = v // 100
    var frac = v % 100
    var frac_text = String(frac)
    if frac < 10:
        frac_text = String("0") + frac_text
    return sign + String(whole) + "." + frac_text


struct ToleranceCandidate(Copyable, ImplicitlyCopyable):
    """One candidate of the full sweep as the proof records
    it: a thread rung of the CPU (the rankable axis), with its
    status and, when measured, its median. Device-axis
    candidates never enter this list -- they are named in the
    module header and ride on the chooser's own record."""

    var label: String
    var device: Int
    var threads: Int
    var status: Int
    var median_ns: Int

    def __init__(out self):
        self.label = String("")
        self.device = 0
        self.threads = 0
        self.status = TC_UNMEASURABLE
        self.median_ns = 0

    def render(self) -> String:
        if self.status == TC_MEASURED:
            return (
                self.label
                + ": median "
                + String(self.median_ns)
                + " ns"
            )
        if self.status == TC_EXCLUDED:
            return self.label + ": EXCLUDED (named on the chooser record)"
        if self.status == TC_BOUND_STOPPED:
            return (
                self.label
                + ": BOUND-STOPPED (recorded, never ranked)"
            )
        return self.label + ": UNMEASURABLE (named on the chooser record)"


struct RepetitionGrade(Copyable, Movable):
    """One repetition's grade: the shape it is filed under,
    the kind, the repetition index, the best and auto medians
    when a gradeable pair exists, the exact gap, the verdict,
    and the reason whenever the verdict needs one. report()
    renders it in the stable form a surface prints."""

    var shape_name: String
    var kind: Int
    var repetition: Int
    var has_numbers: Bool
    var best_label: String
    var best_median_ns: Int
    var auto_label: String
    var auto_median_ns: Int
    var gap_x100: Int
    var verdict: Int
    var reason: String
    var chooser_decision: String
    var candidates: List[ToleranceCandidate]

    def __init__(out self):
        self.shape_name = String("")
        self.kind = PASS_PROMPT
        self.repetition = 0
        self.has_numbers = False
        self.best_label = String("")
        self.best_median_ns = -1
        self.auto_label = String("")
        self.auto_median_ns = -1
        self.gap_x100 = 0
        self.verdict = VERDICT_NOT_PROVEN
        self.reason = String("not graded")
        self.chooser_decision = String("")
        self.candidates = List[ToleranceCandidate]()

    def render(self) -> String:
        var out_str = (
            "  repetition "
            + String(self.repetition)
            + " ["
            + pass_name(self.kind)
            + "]"
        )
        if self.chooser_decision.byte_length() > 0:
            out_str += " chooser: " + self.chooser_decision
        out_str += "\n"
        for c in self.candidates:
            out_str += "    " + c.render() + "\n"
        if self.has_numbers:
            out_str += (
                "    best: "
                + self.best_label
                + " median "
                + String(self.best_median_ns)
                + " ns; auto: "
                + self.auto_label
                + " median "
                + String(self.auto_median_ns)
                + " ns; gap "
                + format_x100(self.gap_x100)
                + "% (target <= "
                + format_x100(target_x100_for(self.kind))
                + "%)\n"
            )
        out_str += (
            "    verdict: "
            + verdict_name(self.verdict)
            + " -- "
            + self.reason
            + "\n"
        )
        return out_str


def grade_repetition(
    shape_name: String,
    kind: Int,
    repetition: Int,
    candidates: List[ToleranceCandidate],
    auto_label: String,
    auto_device: Int,
    auto_threads: Int,
    auto_has_choice: Bool,
    chooser_decision: String,
) -> RepetitionGrade:
    """The pre-registered tolerance rule (module header) for
    ONE repetition, as a pure function of the repetition's own
    sweep candidates and the configuration the real chooser
    chose in that same repetition. The live builder builds
    the candidates from a chooser record; the tests inject
    synthetic sets."""
    var grade = RepetitionGrade()
    grade.shape_name = shape_name
    grade.kind = kind
    grade.repetition = repetition
    grade.auto_label = auto_label
    grade.chooser_decision = chooser_decision
    for c in candidates:
        grade.candidates.append(c)

    if not auto_has_choice:
        grade.verdict = VERDICT_NOT_PROVEN
        grade.reason = (
            "the chooser refused in this repetition, so no auto"
            " choice exists to grade"
        )
        return grade^

    var best_idx = -1
    var auto_idx = -1
    for i in range(len(candidates)):
        var c = candidates[i]
        if c.status != TC_MEASURED:
            continue
        if best_idx < 0 or c.median_ns < candidates[best_idx].median_ns:
            best_idx = i
        if c.device == auto_device and c.threads == auto_threads:
            auto_idx = i

    if best_idx < 0:
        grade.verdict = VERDICT_NOT_PROVEN
        grade.reason = (
            "no candidate measured in this repetition's sweep"
            " (every rung is excluded, unmeasurable, or"
            " bound-stopped), so no best exists to grade against"
        )
        return grade^
    if auto_idx < 0:
        grade.verdict = VERDICT_NOT_PROVEN
        grade.reason = (
            "the chosen configuration ("
            + auto_label
            + ") is not among this repetition's measured"
            " candidates -- it was bound-stopped, unmeasurable,"
            " or absent in this sweep -- so no auto median from"
            " the same sweep exists to grade"
        )
        return grade^

    var best = candidates[best_idx]
    var auto = candidates[auto_idx]
    grade.has_numbers = True
    grade.best_label = best.label
    grade.best_median_ns = best.median_ns
    grade.auto_median_ns = auto.median_ns
    grade.gap_x100 = (
        (auto.median_ns - best.median_ns) * 10000
    ) // best.median_ns
    var target = target_x100_for(kind)
    if auto.median_ns == best.median_ns:
        grade.verdict = VERDICT_BEATEN
        grade.reason = (
            "the auto choice IS the sweep's best configuration"
            " ("
            + best.label
            + "); gap 0.00%"
        )
    elif grade.gap_x100 <= target:
        grade.verdict = VERDICT_MET
        grade.reason = (
            "the auto choice lands "
            + format_x100(grade.gap_x100)
            + "% above the best ("
            + best.label
            + "), within the "
            + format_x100(target)
            + "% target"
        )
    else:
        grade.verdict = VERDICT_MISSED
        grade.reason = (
            "the auto choice lands "
            + format_x100(grade.gap_x100)
            + "% above the best ("
            + best.label
            + "), beyond the "
            + format_x100(target)
            + "% target"
        )
    return grade^


def aggregate_verdict(
    grades: List[RepetitionGrade], shape_name: String, kind: Int
) -> Int:
    """The pre-registered aggregate rule (module header) over
    one shape + kind's repetitions: BEATEN when all are
    BEATEN; MET when all are BEATEN/MET with at least one
    MET; MISSED when at least one is MISSED and none is NOT
    PROVEN; NOT PROVEN when at least one is NOT PROVEN (or
    no repetition for the shape + kind exists at all)."""
    var seen = 0
    var beaten = 0
    var met = 0
    var missed = 0
    var not_proven = 0
    for g in grades:
        if g.shape_name != shape_name or g.kind != kind:
            continue
        seen += 1
        if g.verdict == VERDICT_BEATEN:
            beaten += 1
        elif g.verdict == VERDICT_MET:
            met += 1
        elif g.verdict == VERDICT_MISSED:
            missed += 1
        else:
            not_proven += 1
    if seen == 0 or not_proven > 0:
        return VERDICT_NOT_PROVEN
    if missed > 0:
        return VERDICT_MISSED
    if met > 0:
        return VERDICT_MET
    if beaten == seen:
        return VERDICT_BEATEN
    return VERDICT_NOT_PROVEN


struct ToleranceProof(Copyable, Movable):
    """The whole proof: every repetition grade for every
    shape, in run order, with the pre-registered rule and the
    per-shape aggregate verdicts rendered by report()."""

    var shape_names: List[String]
    var grades: List[RepetitionGrade]

    def __init__(out self):
        self.shape_names = List[String]()
        self.grades = List[RepetitionGrade]()

    def report(self) -> String:
        var out_str = String("within-tolerance proof (J-046)\n")
        out_str += (
            "rule: pre-registered (J-046): per shape, per kind,"
            " per repetition, best = the lowest median of the"
            " full thread-ladder sweep the chooser ranks; auto"
            " = the median, in the same sweep, of the"
            " configuration the real chooser chose; gap % ="
            " (auto - best) / best * 100; targets prompt <="
            " 1.50%, reply <= 2.60% (Janas's published claim,"
            " adopted as a target to test). "
            + String(REPETITIONS)
            + " repetitions per shape per kind, all reported;"
            " aggregate: BEATEN when all repetitions are"
            " BEATEN, MET when all are BEATEN/MET with at least"
            " one MET, MISSED when any is MISSED and none is"
            " NOT PROVEN, NOT PROVEN when any is NOT PROVEN."
            " Device-axis candidates are named on the chooser"
            " records (excluded / unmeasurable-with-reason)"
            " and are never ranked; the device sweep's cpu"
            " timing is a cross-check from a different"
            " executor, never ranked (J-040). Draft-check is"
            " NOT PROVEN by construction (no draft-check pass"
            " exists, J-035 gap G1; Part V owns it) and no"
            " proxy is graded.\n"
        )
        out_str += (
            "models: the shape enters as the J-044 learned-file"
            " key only -- the harness workloads are fixed"
            " shapes and the choosers take no model argument;"
            " no model inference ran and no number here is a"
            " model pass timing.\n"
        )
        for name in self.shape_names:
            out_str += "shape: " + name + "\n"
            for kind in [PASS_PROMPT, PASS_REPLY]:
                for g in self.grades:
                    if g.shape_name == name and g.kind == kind:
                        out_str += g.render()
                out_str += (
                    "  aggregate ["
                    + pass_name(kind)
                    + "]: "
                    + verdict_name(
                        aggregate_verdict(self.grades, name, kind)
                    )
                    + "\n"
                )
        out_str += (
            "draft-check: NOT PROVEN -- no draft-check pass"
            " exists (J-035 gap G1), so no measured pair"
            " exists to grade; Part V (J-071/J-072) owns the"
            " pass that could change this\n"
        )
        return out_str


# --- the live builder ----------------------------------------------------


def _grade_from_prompt_record(
    shape_name: String,
    repetition: Int,
    record: PromptChoiceRecord,
) -> RepetitionGrade:
    var candidates = List[ToleranceCandidate]()
    for m in record.measurements:
        if m.threads < 1:
            continue
        var c = ToleranceCandidate()
        c.label = m.label
        c.device = m.device
        c.threads = m.threads
        c.status = m.status
        c.median_ns = m.summary.median_ns
        candidates.append(c)
    return grade_repetition(
        shape_name,
        PASS_PROMPT,
        repetition,
        candidates,
        record.chosen_label,
        record.chosen_device,
        record.chosen_threads,
        record.has_choice,
        decision_name(record.decision_code),
    )


def _grade_from_reply_record(
    shape_name: String,
    repetition: Int,
    record: ReplyChoiceRecord,
) -> RepetitionGrade:
    var candidates = List[ToleranceCandidate]()
    for m in record.measurements:
        if m.threads < 1:
            continue
        var c = ToleranceCandidate()
        c.label = m.label
        c.device = m.device
        c.threads = m.threads
        c.status = m.status
        c.median_ns = m.summary.median_ns
        candidates.append(c)
    return grade_repetition(
        shape_name,
        PASS_REPLY,
        repetition,
        candidates,
        record.chosen_label,
        record.chosen_device,
        record.chosen_threads,
        record.has_choice,
        decision_name(record.decision_code),
    )


def run_within_tolerance_proof(
    options: PlacementOptions,
    inventory: DeviceInventory,
    facts: CpuFacts,
    config: HarnessConfig,
    shapes: List[ModelShape],
    shape_names: List[String],
) raises -> ToleranceProof:
    """The live entry point: for each shape (in the given
    order), for each kind (prompt, then reply), run
    REPETITIONS independent repetitions of the real chooser
    and grade each against its own sweep. Both options must
    be auto -- the proof grades the auto choice, and a manual
    option has no auto choice to grade. The shapes key the
    repetitions (J-044); they do not alter the workloads
    (module header). Draft-check is never run: it is NOT
    PROVEN by construction and stands so on the report."""
    if options.prompt.choice.form != PLACE_AUTO:
        raise Error(
            "WithinTolerance: the prompt option is not auto ("
            + options.prompt.choice.describe()
            + "); the proof grades the auto choice only -- a"
            " manual option is never argued with and has no"
            " auto choice to grade"
        )
    if options.reply.choice.form != PLACE_AUTO:
        raise Error(
            "WithinTolerance: the reply option is not auto ("
            + options.reply.choice.describe()
            + "); the proof grades the auto choice only -- a"
            " manual option is never argued with and has no"
            " auto choice to grade"
        )
    if len(shapes) != len(shape_names):
        raise Error(
            "WithinTolerance: shapes and shape_names must pair"
            " one for one ("
            + String(len(shapes))
            + " shapes, "
            + String(len(shape_names))
            + " names)"
        )
    var proof = ToleranceProof()
    for i in range(len(shapes)):
        shapes[i].validate()
        proof.shape_names.append(shape_names[i])
        for rep in range(1, REPETITIONS + 1):
            var prompt_record = choose_prompt_placement(
                options, inventory, facts, config
            )
            proof.grades.append(
                _grade_from_prompt_record(
                    shape_names[i], rep, prompt_record
                )
            )
            var reply_record = choose_reply_placement(
                options, inventory, facts, config
            )
            proof.grades.append(
                _grade_from_reply_record(
                    shape_names[i], rep, reply_record
                )
            )
    return proof^
