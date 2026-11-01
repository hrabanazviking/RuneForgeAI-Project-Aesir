"""Placement explainability (Janas road J-050).

Part III built, per pass kind, every piece a user could ask
"why this placement?" about -- and each piece answers in its
own report, in its own vocabulary, on its own surface:

- J-036 the options (--prompt-on / --drafts-on / --reply-on,
  env equivalents, kill switches, the quality family) and
  their resolved form;
- J-037 the device inventory (what the machine actually
  offers, or why not -- GPU absent, NPU parked on this road);
- J-038 the measurement harness records and J-039 the thread
  topology trials (the candidates and their numbers);
- J-040 / J-041 / J-042 the choosers for prompt / reply /
  draft-check (the decision, the best and runner-up medians,
  the margin rule, every exclusion with its reason);
- J-043 co-work (which prompt splits were planned, and their
  survival verdicts);
- J-044 the learned file (load state, exact-key lookup, the
  stored choice per kind, its measured-at stamp);
- J-045 re-trials (whether the stored choice is due, and
  why);
- J-046 within-tolerance verdicts (auto vs the full sweep);
- J-047 precedence (hand > preset > learned > auto, per kind,
  with the governing layer and its provenance);
- J-048 placement under memory pressure (the contention plan
  that stands behind the choice, when one was made);
- J-049 server parity (where a request governed a kind, the
  request layer's outcome and provenance).

This module is the debugging surface the roadmap's J-050
sentence names -- a `--explain-placement` report -- made from
exactly those pieces and nothing else: ONE report, per pass
kind (prompt / draft-check / reply), stating

  1. the candidates considered, each with its measured
     numbers (median / min / max / spread / counted rounds)
     when it measured, and with its verbatim reason when it
     did not (EXCLUDED / UNMEASURABLE / BOUND-STOPPED);
  2. the choice (the chooser's chosen label, device and
     thread count, its decision, the best / runner-up medians
     and margin behind it) -- or an honest NONE when no
     chooser record was supplied for the kind: the kind was
     never measured in this explanation, and the report says
     so instead of inventing a field;
  3. the governing layer and provenance (J-047's resolution,
     or J-049's per-request outcome where a server request
     governed the kind);
  4. the learned-file state for the kind (file present /
     absent / refused, lookup applied or its named mismatch,
     the entry key, the stored choice, the measured-at stamp,
     and the J-045 re-trial due state for the kind);
  5. the standing context lines: the inventory device line,
     the J-048 pressure plan when one was supplied, the
     J-043 co-work outcome for the prompt kind, and the
     J-046 tolerance summary when grades were supplied.

THE REPORT SHAPE, pre-registered (stated here and in
docs/janas/J050_PLACEMENT_EXPLAINABILITY.md before any J-050
result): the header names the surface and the honesty rule;
then the inventory line; then the learned-file state in
full; then, per kind in prompt / draft-check / reply order,
a block with exactly the lines: option, governing, choice,
best/runner-up (when the record carries them), candidates
(one line per candidate, or the single never-measured line),
learned, re-trial; then the pressure / tolerance / server
context lines that were supplied; then the closing honesty
lines. A fact a supplied piece does not carry is rendered
as its absence with the reason, never filled in.

THE FLAG. `--explain-placement` is a boolean reporting flag
(scan_explain_placement_args / explain_placement_requested):
it asks for this report and changes no placement -- it is
not an option in J-036's grammar, takes no value, and a
surface that honours it prints PlacementExplanation.report()
for the state it resolved at open (plus, where it ran them,
the chooser records it kept). Stating it twice is refused,
exactly the argv discipline of the surfaces it joins.

HOST CONTRACT (binding; this module fakes no integration):
a surface at open (1) resolves its options / mode /
precedence and inventory exactly as J-036 / J-037 / J-047
state; (2) loads the learned file and looks its key up
exactly as J-044 states, and plans re-trials exactly as
J-045 states; (3) keeps the chooser records for any kind it
measured (J-040--J-043), the pressure plan if it made one
(J-048), the tolerance grades if it ran the proof (J-046),
and the per-request outcomes for a served request (J-049);
(4) when `--explain-placement` is stated, assembles a
PlacementExplainInputs from those kept pieces and prints
assemble_placement_explanation(inputs).report(). This slice
wires the module into NO live session or server path: no
session in the tree consumes a placement plan yet (the gap
every Part III slice records), so no session consumes an
explanation yet either -- the wiring recipe is filed for
the J-052 gate in the J-050 doc, named, not faked. See
docs/janas/J050_PLACEMENT_EXPLAINABILITY.md.
"""

from core.cowork_passes import CoworkRecord
from core.device_inventory import DeviceInventory
from core.draft_placement import DraftChoiceRecord, DraftMeasurement
from core.learned_file import (
    LOAD_LOADED,
    LOAD_MISSING,
    LOOKUP_APPLIED,
    LearnedEntry,
    LearnedLoad,
    LearnedPassChoice,
    LookupResult,
    load_status_name,
    lookup_status_name,
)
from core.manual_override import (
    ModeOption,
    OverrideResolution,
    governing_name,
    mode_name,
)
from core.placement_options import (
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    PlacementOptions,
    device_name,
    pass_name,
)
from core.placement_pressure import PlacementPressurePlan
from core.prompt_placement import PromptChoiceRecord, PromptMeasurement
from core.reply_placement import ReplyChoiceRecord, ReplyMeasurement
from core.retrial import RetrialPlan, plan_state_name, trigger_name
from core.server_placement import (
    ServerRequestPlacement,
    provenance_name,
)
from core.within_tolerance import ToleranceProof

# Candidate status codes, mirroring the choosers' PM_* codes
# (the values coincide in prompt / reply / draft placement:
# measured 0, excluded 1, unmeasurable 2, bound-stopped 3 --
# the same mirroring J-046's module records).
comptime EX_MEASURED = 0
comptime EX_EXCLUDED = 1
comptime EX_UNMEASURABLE = 2
comptime EX_BOUND_STOPPED = 3

comptime EXPLAIN_FLAG = "--explain-placement"


def candidate_status_name(code: Int) -> String:
    if code == EX_MEASURED:
        return String("MEASURED")
    if code == EX_EXCLUDED:
        return String("EXCLUDED")
    if code == EX_BOUND_STOPPED:
        return String("BOUND-STOPPED")
    return String("UNMEASURABLE")


def explain_decision_name(code: Int) -> String:
    """The choosers' decision names (J-040--J-042 DEC_* codes,
    which coincide across the three choosers)."""
    if code == 0:
        return String("MEASURED-WIN")
    if code == 1:
        return String("DEFAULT-CONFIRMED")
    if code == 2:
        return String("DEFAULT-BY-NOISE")
    if code == 3:
        return String("SOLE-MEASURED")
    if code == 4:
        return String("NO-MEASURED-FALLBACK")
    if code == 5:
        return String("MANUAL-FIXED")
    return String("REFUSAL")


def tolerance_verdict_name(code: Int) -> String:
    """J-046's verdict names (BEATEN / MET / MISSED /
    NOT PROVEN), restated so this module imports no name
    another predecessor also exports."""
    if code == 0:
        return String("BEATEN")
    if code == 1:
        return String("MET")
    if code == 2:
        return String("MISSED")
    return String("NOT PROVEN")


# --- the flag --------------------------------------------------------------


def is_explain_placement_flag(arg: String) -> Bool:
    return arg == EXPLAIN_FLAG


def scan_explain_placement_args(args: List[String]) raises -> Bool:
    """Scan an argv for `--explain-placement`: True when it is
    stated once, False when it is absent. The flag takes no
    value (a `--explain-placement=<anything>` form is refused
    as a mistyped flag, not silently read as the flag), and
    stating it twice is refused -- state it once, exactly the
    argv discipline of J-036 / J-047. Foreign arguments are
    the host scanner's own business and are ignored here."""
    var seen = False
    for arg in args:
        if arg == EXPLAIN_FLAG:
            if seen:
                raise Error(
                    "PlacementExplain: '--explain-placement' is"
                    " stated twice; state it once"
                )
            seen = True
        elif arg.find(EXPLAIN_FLAG + "=") == 0:
            raise Error(
                "PlacementExplain: '--explain-placement' takes"
                " no value; state it bare"
            )
    return seen


# --- one candidate -----------------------------------------------------------


struct ExplainCandidate(Copyable, ImplicitlyCopyable):
    """One candidate as the explanation records it: its label,
    its status in the shared PM_* vocabulary, its measured
    numbers when it measured (median / min / max / spread in
    ns and the counted rounds), and its verbatim rendered
    line from the chooser record it came from -- the numbers
    and the reason are the chooser's own, never re-derived."""

    var label: String
    var status: Int
    var has_numbers: Bool
    var median_ns: Int
    var min_ns: Int
    var max_ns: Int
    var spread_ns: Int
    var rounds: Int
    var line: String

    def __init__(out self):
        self.label = String("")
        self.status = EX_UNMEASURABLE
        self.has_numbers = False
        self.median_ns = -1
        self.min_ns = -1
        self.max_ns = -1
        self.spread_ns = -1
        self.rounds = 0
        self.line = String("")

    def render(self) -> String:
        return self.line


def _candidate(
    label: String,
    status: Int,
    median_ns: Int,
    min_ns: Int,
    max_ns: Int,
    spread_ns: Int,
    rounds: Int,
    line: String,
) -> ExplainCandidate:
    var cand = ExplainCandidate()
    cand.label = label
    cand.status = status
    cand.has_numbers = status == EX_MEASURED
    cand.median_ns = median_ns
    cand.min_ns = min_ns
    cand.max_ns = max_ns
    cand.spread_ns = spread_ns
    cand.rounds = rounds
    cand.line = line
    return cand


def explain_candidate_from_prompt(m: PromptMeasurement) -> ExplainCandidate:
    return _candidate(
        m.label,
        m.status,
        m.summary.median_ns,
        m.summary.min_ns,
        m.summary.max_ns,
        m.summary.spread_ns,
        m.summary.count,
        m.render(),
    )


def explain_candidate_from_reply(m: ReplyMeasurement) -> ExplainCandidate:
    return _candidate(
        m.label,
        m.status,
        m.summary.median_ns,
        m.summary.min_ns,
        m.summary.max_ns,
        m.summary.spread_ns,
        m.summary.count,
        m.render(),
    )


def explain_candidate_from_draft(m: DraftMeasurement) -> ExplainCandidate:
    return _candidate(
        m.label,
        m.status,
        m.summary.median_ns,
        m.summary.min_ns,
        m.summary.max_ns,
        m.summary.spread_ns,
        m.summary.count,
        m.render(),
    )


# --- the learned-file state ---------------------------------------------------


struct LearnedExplainState(Copyable, Movable):
    """The learned-file half of the explanation, stated once
    for the whole report and then cited per kind: whether a
    load was supplied at all, the load state (MISSING /
    LOADED / REFUSED, with its reason and path), whether a
    lookup was supplied and how it ended (APPLIED with its
    entry, or its named non-apply outcome), and -- when an
    entry applies -- the entry's key and measured-at stamp in
    J-044's own rendering."""

    var load_supplied: Bool
    var load_status: Int
    var load_reason: String
    var load_path: String
    var entry_count: Int
    var lookup_supplied: Bool
    var lookup_status: Int
    var lookup_reason: String
    var has_entry: Bool
    var entry: LearnedEntry

    def __init__(out self):
        self.load_supplied = False
        self.load_status = LOAD_MISSING
        self.load_reason = String("no learned load was supplied")
        self.load_path = String("")
        self.entry_count = 0
        self.lookup_supplied = False
        self.lookup_status = -1
        self.lookup_reason = String("no learned lookup was supplied")
        self.has_entry = False
        self.entry = LearnedEntry()

    def state_line(self) -> String:
        if not self.load_supplied:
            return String(
                "learned file: NOT STATED -- no learned load was"
                " supplied to this explanation, so no learned"
                " state is claimed (the file may or may not"
                " exist; this report does not guess)"
            )
        var line = (
            "learned file: "
            + load_status_name(self.load_status)
            + " at "
            + (self.load_path if self.load_path.byte_length() > 0 else String("(no path stated)"))
        )
        if self.load_status == LOAD_LOADED:
            line += " (" + String(self.entry_count) + " entries)"
        else:
            line += " -- " + self.load_reason
        return line

    def lookup_line(self) -> String:
        if not self.lookup_supplied:
            return String(
                "learned lookup: NOT STATED -- no lookup was"
                " supplied, so whether an entry applies to this"
                " machine + model shape is not claimed"
            )
        var line = (
            "learned lookup: "
            + lookup_status_name(self.lookup_status)
            + " -- "
            + self.lookup_reason
        )
        return line

    def choice_for(self, pass_kind: Int) -> LearnedPassChoice:
        if not self.has_entry:
            return LearnedPassChoice()
        return self.entry.pass_choice(pass_kind)

    def render(self) -> String:
        var out_str = self.state_line() + "\n"
        out_str += self.lookup_line() + "\n"
        if self.has_entry:
            out_str += "learned entry (the applied key):\n"
            out_str += self.entry.render()
        return out_str


def learned_state_from(
    load: LearnedLoad, lookup: LookupResult
) -> LearnedExplainState:
    """Build the learned state from J-044's real load and
    lookup results: the load's status / reason / path / entry
    count verbatim, and the lookup's entry exactly when it
    APPLIED (a non-apply lookup carries no applicable entry,
    and none is claimed)."""
    var state = LearnedExplainState()
    state.load_supplied = True
    state.load_status = load.status
    state.load_reason = load.reason
    state.load_path = load.path
    state.entry_count = len(load.entries)
    state.lookup_supplied = True
    state.lookup_status = lookup.status
    state.lookup_reason = lookup.reason
    if lookup.status == LOOKUP_APPLIED:
        state.has_entry = True
        state.entry = lookup.entry.copy()
    return state^


# --- one pass kind --------------------------------------------------------------


struct KindExplanation(Copyable, Movable):
    """One pass kind's whole explanation block: the resolved
    option, the governing layer with its provenance and
    reason, the chooser's choice and the numbers behind it
    (or the never-measured statement), every candidate, the
    kind's learned choice and re-trial due state, and the
    kind's co-work / server / tolerance lines when supplied."""

    var kind: Int
    var option_text: String
    var governing_text: String
    var has_record: Bool
    var decision_text: String
    var has_choice: Bool
    var chosen_text: String
    var best_text: String
    var candidates: List[ExplainCandidate]
    var learned_text: String
    var retrial_text: String
    var extra_text: String

    def __init__(out self):
        self.kind = PASS_PROMPT
        self.option_text = String("auto")
        self.governing_text = String("not resolved")
        self.has_record = False
        self.decision_text = String("not decided")
        self.has_choice = False
        self.chosen_text = String("")
        self.best_text = String("")
        self.candidates = List[ExplainCandidate]()
        self.learned_text = String("")
        self.retrial_text = String("")
        self.extra_text = String("")

    def measured_count(self) -> Int:
        var total = 0
        for cand in self.candidates:
            if cand.status == EX_MEASURED:
                total += 1
        return total

    def render(self) -> String:
        var out_str = "== " + pass_name(self.kind) + " ==\n"
        out_str += "option: " + self.option_text + "\n"
        out_str += "governing: " + self.governing_text + "\n"
        if self.has_record:
            out_str += "decision: " + self.decision_text + "\n"
            if self.has_choice:
                out_str += "choice: " + self.chosen_text + "\n"
            else:
                out_str += (
                    "choice: NONE (the chooser refused -- no"
                    " placement is claimed for this kind)\n"
                )
            if self.best_text.byte_length() > 0:
                out_str += self.best_text + "\n"
            out_str += (
                "candidates ("
                + String(len(self.candidates))
                + " considered, "
                + String(self.measured_count())
                + " measured):\n"
            )
            if len(self.candidates) == 0:
                out_str += (
                    "  (the chooser record carries no candidate"
                    " lines -- its field was empty, stated as"
                    " recorded)\n"
                )
            for cand in self.candidates:
                out_str += "  " + cand.render() + "\n"
        else:
            out_str += (
                "choice: NOT STATED -- no chooser record was"
                " supplied for the "
                + pass_name(self.kind)
                + " kind, so this kind was never measured in"
                " this explanation and no candidate numbers"
                " exist to show; the governing layer above is"
                " the whole statement for this kind\n"
            )
            out_str += "candidates: none recorded (never measured)\n"
        out_str += "learned: " + self.learned_text + "\n"
        out_str += "re-trial: " + self.retrial_text + "\n"
        if self.extra_text.byte_length() > 0:
            out_str += self.extra_text
        return out_str


# --- the inputs -------------------------------------------------------------------


struct PlacementExplainInputs(Copyable, Movable):
    """Everything an explanation is assembled from, each piece
    optional-by-flag and honest in its absence: the resolved
    options + mode + J-047 precedence (the governing truth),
    the inventory (the machine truth), the three chooser
    records, the prompt co-work record, the learned state,
    the re-trial plan, the pressure plan, the tolerance
    proof, and one request's server outcomes. A piece whose
    flag is False is rendered as its absence with the reason
    -- assemble never reaches for a piece it was not given."""

    var options: PlacementOptions
    var mode: ModeOption
    var resolution: OverrideResolution
    var inventory: DeviceInventory
    var has_prompt_record: Bool
    var prompt_record: PromptChoiceRecord
    var has_reply_record: Bool
    var reply_record: ReplyChoiceRecord
    var has_draft_record: Bool
    var draft_record: DraftChoiceRecord
    var has_cowork: Bool
    var cowork: CoworkRecord
    var learned: LearnedExplainState
    var has_retrial_plan: Bool
    var retrial_plan: RetrialPlan
    var has_pressure: Bool
    var pressure: PlacementPressurePlan
    var has_tolerance: Bool
    var tolerance: ToleranceProof
    var has_server: Bool
    var server: ServerRequestPlacement

    def __init__(out self):
        self.options = PlacementOptions()
        self.mode = ModeOption()
        self.resolution = OverrideResolution()
        self.inventory = DeviceInventory()
        self.has_prompt_record = False
        self.prompt_record = PromptChoiceRecord()
        self.has_reply_record = False
        self.reply_record = ReplyChoiceRecord()
        self.has_draft_record = False
        self.draft_record = DraftChoiceRecord()
        self.has_cowork = False
        self.cowork = CoworkRecord()
        self.learned = LearnedExplainState()
        self.has_retrial_plan = False
        self.retrial_plan = RetrialPlan()
        self.has_pressure = False
        self.pressure = PlacementPressurePlan(
            0, 0, 0, 0, False, 0, 0, 0, False, True, False
        )
        self.has_tolerance = False
        self.tolerance = ToleranceProof()
        self.has_server = False
        self.server = ServerRequestPlacement()


# --- the whole explanation ----------------------------------------------------------


struct PlacementExplanation(Copyable, Movable):
    """The assembled `--explain-placement` report: the
    inventory line, the learned-file state, one block per
    pass kind, and the supplied context lines, rendered by
    report() in the pre-registered shape (module header)."""

    var inventory_line: String
    var options_text: String
    var learned: LearnedExplainState
    var prompt: KindExplanation
    var drafts: KindExplanation
    var reply: KindExplanation
    var context_text: String

    def __init__(out self):
        self.inventory_line = String("")
        self.options_text = String("")
        self.learned = LearnedExplainState()
        self.prompt = KindExplanation()
        self.drafts = KindExplanation()
        self.reply = KindExplanation()
        self.context_text = String("")

    def for_kind(self, pass_kind: Int) -> KindExplanation:
        if pass_kind == PASS_DRAFTS:
            return self.drafts.copy()
        if pass_kind == PASS_REPLY:
            return self.reply.copy()
        return self.prompt.copy()

    def report(self) -> String:
        var out_str = String("placement explanation (J-050)\n")
        out_str += (
            "per pass kind: the candidates measured and their"
            " numbers (or why a candidate never measured), the"
            " choice, the governing layer and its provenance,"
            " and the learned-file state -- assembled from the"
            " Part III pieces (J-036--J-049) and nothing else;"
            " a fact no supplied piece carries is stated as"
            " its absence, never filled in\n"
        )
        out_str += self.inventory_line + "\n"
        out_str += "options: " + self.options_text + "\n"
        out_str += self.learned.render()
        out_str += self.prompt.render()
        out_str += self.drafts.render()
        out_str += self.reply.render()
        out_str += self.context_text
        out_str += (
            "honesty: candidate numbers are the supplying"
            " choosers' own harness numbers on the machine"
            " that measured them, in that window -- they are"
            " not model pass timings and no placement verdict"
            " for any model is made by this report; a kind"
            " with no chooser record was never measured here"
            " and says so; the NPU stands as the inventory"
            " states it (parked on this road, never probed,"
            " never run)\n"
        )
        return out_str


def _learned_kind_text(
    learned: LearnedExplainState, pass_kind: Int
) -> String:
    if not learned.load_supplied:
        return String(
            "not stated (no learned load supplied to this"
            " explanation)"
        )
    if not learned.has_entry:
        if learned.lookup_supplied:
            return (
                "no stored choice applies ("
                + lookup_status_name(learned.lookup_status)
                + " -- "
                + learned.lookup_reason
                + ")"
            )
        return String(
            "no stored choice stated (no lookup supplied)"
        )
    var choice = learned.choice_for(pass_kind)
    if not choice.present:
        return String(
            "absent in the applied entry (no learned choice"
            " stored for this kind; measured-at "
            + String(learned.entry.measured_at)
            + " unix s)"
        )
    return (
        choice.placement_text
        + " (device "
        + device_name(choice.device)
        + ", threads "
        + String(choice.threads)
        + ", decision "
        + choice.decision
        + ", from option "
        + choice.option_text
        + "; entry measured-at "
        + String(learned.entry.measured_at)
        + " unix s)"
    )


def _retrial_kind_text(
    inputs: PlacementExplainInputs, pass_kind: Int
) -> String:
    if not inputs.has_retrial_plan:
        return String(
            "not planned in this explanation (no re-trial plan"
            " supplied; the cadence is J-045's and is not"
            " guessed here)"
        )
    var plan = inputs.retrial_plan
    var line = (
        plan_state_name(plan.state)
        + " (age "
        + String(plan.age_seconds)
        + " s, opens "
        + String(plan.opens)
        + " since measure)"
    )
    if plan.due_for(pass_kind):
        line += (
            " -- DUE for this kind (trigger "
            + trigger_name(plan.trigger)
            + ")"
        )
    else:
        line += " -- not due for this kind"
    line += " -- " + plan.reason
    return line


def _governing_text(
    inputs: PlacementExplainInputs, pass_kind: Int
) -> String:
    """The governing statement for one kind: J-049's
    per-request outcome where a server request was supplied
    (it carries the request layer on top of the session
    stack), else J-047's precedence resolution verbatim."""
    if inputs.has_server:
        var outcome = inputs.server.for_kind(pass_kind)
        var line = (
            governing_name(outcome.governing)
            + " (server "
            + provenance_name(outcome.provenance)
            + " layer, J-049)"
        )
        if outcome.has_fixed_choice:
            line += " -- fixed: " + outcome.fixed_choice.describe()
        elif outcome.measure_field.byte_length() > 0:
            line += " -- measure: field [" + outcome.measure_field + "]"
        else:
            line += " -- effective: " + outcome.effective_text
        line += " -- " + outcome.reason
        return line
    var resolution = inputs.resolution.for_kind(pass_kind)
    var line = (
        governing_name(resolution.governing)
        + " ("
        + resolution.provenance
        + ", J-047)"
    )
    if resolution.has_fixed:
        line += " -- fixed: " + resolution.effective_text
    else:
        line += " -- measure: field [" + resolution.measure_field + "]"
    line += " -- " + resolution.reason
    return line


def _best_text(
    best_label: String,
    best_median_ns: Int,
    runner_label: String,
    runner_median_ns: Int,
    margin_percent: Int,
    separation_ok: Bool,
) -> String:
    if best_median_ns < 0:
        return String("")
    var line = (
        "best: "
        + best_label
        + " median "
        + String(best_median_ns)
        + " ns"
    )
    if runner_median_ns >= 0:
        line += (
            "; runner-up: "
            + runner_label
            + " median "
            + String(runner_median_ns)
            + " ns; margin "
            + String(margin_percent)
            + "%; separation "
            + (String("ok") if separation_ok else String("failed"))
        )
    return line


def _tolerance_kind_text(
    inputs: PlacementExplainInputs, pass_kind: Int
) -> String:
    if not inputs.has_tolerance:
        return String("")
    if pass_kind == PASS_DRAFTS:
        return String(
            "tolerance: draft-check NOT PROVEN -- no"
            " draft-check pass exists (J-035 gap G1), so no"
            " measured pair exists to grade (J-046)\n"
        )
    var beaten = 0
    var met = 0
    var missed = 0
    var not_proven = 0
    var seen = 0
    for grade in inputs.tolerance.grades:
        if grade.kind != pass_kind:
            continue
        seen += 1
        if grade.verdict == 0:
            beaten += 1
        elif grade.verdict == 1:
            met += 1
        elif grade.verdict == 2:
            missed += 1
        else:
            not_proven += 1
    if seen == 0:
        return String(
            "tolerance: no J-046 grades supplied for this kind"
            " (the proof was supplied, this kind was not"
            " graded in it)\n"
        )
    return (
        "tolerance: J-046 grades for this kind -- "
        + String(seen)
        + " repetition(s): BEATEN "
        + String(beaten)
        + ", MET "
        + String(met)
        + ", MISSED "
        + String(missed)
        + ", NOT PROVEN "
        + String(not_proven)
        + " (targets: prompt <= 1.50%, reply <= 2.60% of"
        " best, per repetition)\n"
    )


def assemble_placement_explanation(
    inputs: PlacementExplainInputs,
) -> PlacementExplanation:
    """Assemble the whole explanation from the supplied
    pieces. Pure assembly: nothing is measured, resolved, or
    looked up here -- every number and reason in the report
    is a supplied piece's own, and every absent piece renders
    as its stated absence."""
    var explanation = PlacementExplanation()
    explanation.inventory_line = inputs.inventory.device_line()
    explanation.options_text = (
        inputs.options.describe()
        + " | mode: "
        + mode_name(inputs.mode.mode)
    )
    explanation.learned = inputs.learned.copy()

    var kinds = List[Int]()
    kinds.append(PASS_PROMPT)
    kinds.append(PASS_DRAFTS)
    kinds.append(PASS_REPLY)
    for kind in kinds:
        var block = KindExplanation()
        block.kind = kind
        var resolution = inputs.resolution.for_kind(kind)
        block.governing_text = _governing_text(inputs, kind)
        block.learned_text = _learned_kind_text(inputs.learned, kind)
        block.retrial_text = _retrial_kind_text(inputs, kind)
        var extra = String("")
        if kind == PASS_PROMPT and inputs.has_cowork:
            extra += (
                "co-work: "
                + inputs.cowork.outcome_text
                + " ("
                + String(len(inputs.cowork.pairs))
                + " pair(s) planned, "
                + String(inputs.cowork.survived_count())
                + " survived; J-043)\n"
            )
        elif kind == PASS_PROMPT:
            extra += (
                "co-work: not stated (no J-043 record supplied)\n"
            )
        var tolerance_line = _tolerance_kind_text(inputs, kind)
        if tolerance_line.byte_length() > 0:
            extra += tolerance_line
        block.extra_text = extra

        if kind == PASS_PROMPT and inputs.has_prompt_record:
            var record = inputs.prompt_record.copy()
            block.has_record = True
            block.option_text = (
                record.option_text
                + " (chooser record, J-040)"
            )
            block.decision_text = (
                explain_decision_name(record.decision_code)
                + " -- "
                + record.decision_text
            )
            block.has_choice = record.has_choice
            block.chosen_text = record.chosen_label
            block.best_text = _best_text(
                record.best_label,
                record.best_median_ns,
                record.runner_label,
                record.runner_median_ns,
                record.margin_percent,
                record.separation_ok,
            )
            for m in record.measurements:
                block.candidates.append(explain_candidate_from_prompt(m))
            if record.device_sweep_note.byte_length() > 0:
                block.extra_text += (
                    "device sweep: " + record.device_sweep_note + "\n"
                )
        elif kind == PASS_REPLY and inputs.has_reply_record:
            var record = inputs.reply_record.copy()
            block.has_record = True
            block.option_text = (
                record.option_text + " (chooser record, J-041)"
            )
            block.decision_text = (
                explain_decision_name(record.decision_code)
                + " -- "
                + record.decision_text
            )
            block.has_choice = record.has_choice
            block.chosen_text = record.chosen_label
            block.best_text = _best_text(
                record.best_label,
                record.best_median_ns,
                record.runner_label,
                record.runner_median_ns,
                record.margin_percent,
                record.separation_ok,
            )
            for m in record.measurements:
                block.candidates.append(explain_candidate_from_reply(m))
            if record.device_sweep_note.byte_length() > 0:
                block.extra_text += (
                    "device sweep: " + record.device_sweep_note + "\n"
                )
        elif kind == PASS_DRAFTS and inputs.has_draft_record:
            var record = inputs.draft_record.copy()
            block.has_record = True
            block.option_text = (
                record.option_text + " (chooser record, J-042)"
            )
            block.decision_text = (
                explain_decision_name(record.decision_code)
                + " -- "
                + record.decision_text
            )
            block.has_choice = record.has_choice
            block.chosen_text = record.chosen_label
            block.best_text = _best_text(
                record.best_label,
                record.best_median_ns,
                record.runner_label,
                record.runner_median_ns,
                record.margin_percent,
                record.separation_ok,
            )
            for m in record.measurements:
                block.candidates.append(explain_candidate_from_draft(m))
            if record.axes_note.byte_length() > 0:
                block.extra_text += "axes: " + record.axes_note + "\n"
        else:
            # No chooser record for this kind: the option line
            # falls back to the precedence resolution's own
            # statement for the kind, and the block renders
            # the never-measured honesty (KindExplanation).
            block.option_text = resolution.effective_text

        if kind == PASS_PROMPT:
            explanation.prompt = block^
        elif kind == PASS_DRAFTS:
            explanation.drafts = block^
        else:
            explanation.reply = block^

    var context = String("")
    if inputs.has_pressure:
        context += (
            "pressure: "
            + inputs.pressure.describe()
            + " (J-048 contention plan, supplied)\n"
        )
    else:
        context += (
            "pressure: not stated (no J-048 contention plan"
            " supplied; no contention verdict is claimed)\n"
        )
    if inputs.has_server:
        context += (
            "server: per-request outcomes supplied (J-049) --"
            " the governing lines above are the request's"
            " outcomes, with their provenance; session"
            " defaults are stated by the J-047 lines this"
            " report's options carry\n"
        )
    explanation.context_text = context
    return explanation^
