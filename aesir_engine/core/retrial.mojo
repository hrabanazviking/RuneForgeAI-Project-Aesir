"""Re-trials of learned placement choices (Janas road J-045).

J-040/J-041/J-042 choose a placement per pass kind by
measurement and keep it for one session; J-044 persists the
chosen placement + thread choice in the learned file, keyed by
machine + model shape, with the provenance a re-trial needs
(the key it was measured under, the option it came from, the
decision that produced it, and the measured-at stamp). This
module is the re-measurement those slices named and did not
build: a learned choice is re-measured OCCASIONALLY -- the
machine warms, drivers change, the box is upgraded -- under a
bounded cadence, and a changed verdict is ADOPTED (stored
through J-044's own store path, replacing the entry) with the
change LOGGED (old choice -> new choice, the cadence trigger
that fired, in the append-only retrial log beside the learned
file). A re-trial that reproduces the learned choice keeps it
and refreshes its measured-at stamp to the re-trial instant:
the choice was re-measured at that instant and stood, and the
stamp says exactly that -- it is not left stale (which would
re-fire the cadence at once) and the choice is not rewritten
as if it were new.

WHY A DEDICATED MODULE (and not an extension of
learned_file.mojo): J-044's module is the persistence layer --
it imports the option surface and the inventory facts and
nothing else, and its format/parser strictness is its whole
contract. Re-trials are policy + orchestration: they import
the persistence layer AND all three choosers and drive them.
Every Part III slice is one dedicated core module importing
its predecessors (the choosers import the harness; the learned
file imports the options), so the re-trial lives here and
learned_file.mojo is untouched.

THE CADENCE, pre-registered (stated here and in
docs/janas/J045_RETRIALS.md before any J-045 number; the pure
plan_retrial is its unit-tested form). A learned entry is due
for re-trial when EITHER trigger fires:

- AGE: the entry's age (now - measured_at, both injected unix
  seconds) reaches RETRIAL_AGE_S (30 days). Machines drift on
  this scale -- drivers, firmware, thermals, a replaced fan --
  whether or not anyone opens a session.
- OPENS: the host has opened RETRIAL_OPENS (25) sessions
  against the entry since it was measured AND its age reaches
  RETRIAL_MIN_AGE_S (7 days). Heavy use earns an earlier
  second look, but the 7-day floor is absolute: no burst of
  opens, however large, re-trials a fresh entry, so the
  cadence is bounded below by one re-trial per entry per week
  and can never fire per-open, per-session, or per-token.

The clock and the counter are INJECTED (plan_retrial takes
now and opens_since_measure as parameters): the decision is
deterministic and unit-testable, and the host owns counting
its opens (the learned file's format holds no counter, and
J-044's versioned format is not revised by this slice -- the
counter is session bookkeeping, not learned state). A clock
that reads BEFORE measured_at (skew, a restored file) is
never due: a negative age is not evidence about the machine,
and the plan says so. Machine-key DRIFT is not a re-trial at
all: an entry whose key no longer matches is not applied in
the first place (J-044's lookup names the mismatched half and
the caller measures fresh); plan_retrial states KEY-DRIFT for
a host that asks, so the two roads are never confused.

WHAT IS RE-TRIALLED, per kind. A kind is re-triable when it
is present in the entry AND its decision is not MANUAL-FIXED.
A manual choice is a hand choice persisted (J-044 records its
provenance, it does not launder it into a measurement): manual
supremacy (J-047's contract, on the face of J-044's reports)
means a re-trial NEVER re-measures, replaces, or argues with
a manual kind -- it is carried into the adopted entry
verbatim, and an entry whose present kinds are all manual is
never due (PLAN_MANUAL_ONLY). An ABSENT kind has nothing
learned to re-trial; it stays absent. When an entry is due,
all of its re-triable kinds are re-measured in the one
re-trial, each under the entry's OWN stored option for that
kind (the provenance J-044 kept): the re-trial re-asks the
question that was originally asked, in the tri-device order
the choosers already enforce (the parked NPU excluded by
J-037/J-038, GPU before CPU spill in the ranked field the
harness presents -- this module adds no CPU-only assumption;
it drives J-040/J-041/J-042 exactly as a session open would).

ADOPTION AND THE LOG. The fresh records are converted through
J-044's own builder (learned_pass_from_choice) and compared
field by field with the learned choice:

- REPRODUCED: every field equal -- the kind keeps its choice.
- CHANGED: any field differs -- the fresh choice replaces it.
- REFUSED-NOW-ABSENT: the fresh chooser refused (no choice) --
  the kind becomes ABSENT in the adopted entry, per J-044's
  discipline that a refusal is not a choice and leaves no
  learned default. If EVERY kind of the entry ends absent,
  the entry itself is erased (erase_learned_entry) rather
  than stored as the nothing J-044 refuses at save.

Adoption stores through store_learned_entry (same key
replaced, all other keys preserved, corrupt file refused
untouched -- J-044's discipline, inherited whole), stamps the
entry with the re-trial instant, and appends the change
record to the retrial log at retrial_log_path(path) (the
learned path + ".retrials.log" -- answered-locally, recorded
in the J-045 doc: the log lives beside the state it audits).
The log record states the key, the trigger with the age and
opens that fired it, the measured-at move, and per kind the
outcome with old -> new choices rendered in J-044's own form.
A re-trial that does not run (not due, manual-only, drift,
missing/refused learned state, no entry) writes NOTHING: no
store, no log line -- the log records re-trials, not checks.
apply_retrial stores BEFORE appending the log: the learned
file is the authority, the log its audit trail; if the append
fails the error is raised after adoption and a host must
surface it, never swallow it.

HOST CONTRACT (binding; this slice wires the module into no
live session path, following the J-036--J-044 pattern): at
model open a surface (1) loads the learned file and looks up
its key exactly as J-044's contract states; (2) on APPLIED,
calls plan_retrial with the current time
(learned_now_seconds), the number of sessions it has opened
against this entry since the entry's stamp (its own count,
kept in its own session bookkeeping), and the current key;
(3) only on PLAN_DUE calls run_retrial (or drives the
choosers itself and calls apply_retrial with the converted
fresh choices), which re-measures the due kinds through the
J-038/J-039-bounded harness, adopts, stores, and logs;
(4) prints RetrialOutcome.log_text() wherever it prints the
learned report (J-050's explainability surface will cite
both). A surface must never call run_retrial unconditionally
at open: the plan is the gate, and the cadence's bound is
the plan's, not the caller's memory. See
docs/janas/J045_RETRIALS.md.
"""

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.device_inventory import CpuFacts, DeviceInventory
from core.draft_placement import choose_draft_placement
from core.learned_file import (
    LOAD_LOADED,
    LearnedEntry,
    LearnedPassChoice,
    MachineKey,
    ModelShape,
    erase_learned_entry,
    learned_pass_from_choice,
    load_learned_file,
    lookup_learned,
    store_learned_entry,
    LOOKUP_APPLIED,
)
from core.placement_harness import HarnessConfig
from core.placement_options import (
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    SOURCE_DEFAULT,
    PlacementOption,
    PlacementOptions,
    device_name,
    parse_placement_value,
    pass_name,
)
from core.prompt_placement import choose_prompt_placement
from core.reply_placement import choose_reply_placement

# The cadence (module header, pre-registered). Ages are unix
# seconds; opens are host-counted sessions against the entry.
comptime RETRIAL_MIN_AGE_S = 604800  # 7 days: the absolute floor
comptime RETRIAL_AGE_S = 2592000  # 30 days: age alone makes due
comptime RETRIAL_OPENS = 25  # opens alone (past the floor) make due

# Plan states (RetrialPlan.state).
comptime PLAN_KEEP = 0
comptime PLAN_DUE = 1
comptime PLAN_MANUAL_ONLY = 2
comptime PLAN_KEY_DRIFT = 3

# Cadence triggers (RetrialPlan.trigger).
comptime TRIGGER_NONE = 0
comptime TRIGGER_AGE = 1
comptime TRIGGER_OPENS = 2
comptime TRIGGER_AGE_OPENS = 3

# Retrial outcomes (RetrialOutcome.status).
comptime OUT_SKIPPED = 0
comptime OUT_KEPT = 1
comptime OUT_ADOPTED = 2
comptime OUT_ERASED = 3

# Per-kind outcomes (KindRetrial.outcome).
comptime KIND_NOT_PRESENT = 0
comptime KIND_CARRIED_MANUAL = 1
comptime KIND_REPRODUCED = 2
comptime KIND_CHANGED = 3
comptime KIND_REFUSED_ABSENT = 4
comptime KIND_CARRIED = 5


def plan_state_name(code: Int) -> String:
    if code == PLAN_DUE:
        return String("DUE")
    if code == PLAN_MANUAL_ONLY:
        return String("MANUAL-ONLY")
    if code == PLAN_KEY_DRIFT:
        return String("KEY-DRIFT")
    return String("KEEP")


def trigger_name(code: Int) -> String:
    if code == TRIGGER_AGE:
        return String("AGE")
    if code == TRIGGER_OPENS:
        return String("OPENS")
    if code == TRIGGER_AGE_OPENS:
        return String("AGE+OPENS")
    return String("NONE")


def outcome_name(code: Int) -> String:
    if code == OUT_KEPT:
        return String("KEPT")
    if code == OUT_ADOPTED:
        return String("ADOPTED")
    if code == OUT_ERASED:
        return String("ERASED")
    return String("SKIPPED")


def kind_outcome_name(code: Int) -> String:
    if code == KIND_CARRIED_MANUAL:
        return String("CARRIED-MANUAL")
    if code == KIND_REPRODUCED:
        return String("REPRODUCED")
    if code == KIND_CHANGED:
        return String("CHANGED")
    if code == KIND_REFUSED_ABSENT:
        return String("REFUSED-NOW-ABSENT")
    if code == KIND_CARRIED:
        return String("CARRIED")
    return String("NOT-PRESENT")


def _decision_name(code: Int) -> String:
    """The J-040 decision names by code. J-041 and J-042 adopted
    J-040's rule and its codes unchanged (verified in the tree:
    DEC_* 0..6 carry identical names in all three choosers), so
    one table serves every record this module converts; the
    converted choice is then validated by J-044's own decision
    check when the adopted entry validates, so a drifted code
    table would fail closed there, not persist silently."""
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


# --- the plan ------------------------------------------------------------


def kind_retriable(choice: LearnedPassChoice) -> Bool:
    """A kind can be re-trialled when a choice was learned for
    it and the choice was measured, not fixed by hand. Manual
    supremacy: a MANUAL-FIXED kind is never re-trialled."""
    return choice.present and choice.decision != "MANUAL-FIXED"


struct RetrialPlan(Copyable, ImplicitlyCopyable):
    """The cadence's verdict for one entry at one instant:
    DUE (with the trigger and the per-kind due flags), KEEP
    (not due yet, reason stated with the numbers), MANUAL-ONLY
    (never due -- every present kind is a hand choice), or
    KEY-DRIFT (the supplied current key is not the entry's key;
    not a re-trial question at all). age_seconds is the
    injected age (negative under clock skew); opens is the
    injected counter, clamped at 0."""

    var state: Int
    var trigger: Int
    var reason: String
    var age_seconds: Int64
    var opens: Int
    var due_prompt: Bool
    var due_drafts: Bool
    var due_reply: Bool

    def __init__(out self):
        self.state = PLAN_KEEP
        self.trigger = TRIGGER_NONE
        self.reason = String("not planned")
        self.age_seconds = 0
        self.opens = 0
        self.due_prompt = False
        self.due_drafts = False
        self.due_reply = False

    def due_for(self, pass_kind: Int) -> Bool:
        if pass_kind == PASS_DRAFTS:
            return self.due_drafts
        if pass_kind == PASS_REPLY:
            return self.due_reply
        return self.due_prompt

    def render(self) -> String:
        var out_str = String("retrial plan: ") + plan_state_name(self.state)
        if self.state == PLAN_DUE:
            out_str += " (trigger " + trigger_name(self.trigger) + ")"
        out_str += (
            " -- age "
            + String(self.age_seconds)
            + " s, opens "
            + String(self.opens)
            + " since measure; "
            + self.reason
            + "\n"
        )
        return out_str


def plan_retrial(
    entry: LearnedEntry,
    now: Int64,
    opens_since_measure: Int,
    current_machine: MachineKey,
    current_model: ModelShape,
) -> RetrialPlan:
    """The bounded cadence (module header), as a pure function
    of the entry, an injected clock reading, an injected opens
    counter, and the host's current key. Deterministic: the
    same inputs always plan the same, which is what makes the
    cadence unit-testable and its bound auditable."""
    var plan = RetrialPlan()
    var opens = opens_since_measure
    if opens < 0:
        opens = 0
    plan.opens = opens
    plan.age_seconds = now - entry.measured_at

    var machine_eq = entry.machine.equals(current_machine)
    var model_eq = entry.model.equals(current_model)
    if not (machine_eq and model_eq):
        plan.state = PLAN_KEY_DRIFT
        if not machine_eq and not model_eq:
            plan.reason = String(
                "the current machine and model shape both differ"
                " from this entry's key; the entry is not applied"
                " under a drifted key (J-044 lookup names the"
                " mismatch) and a fresh measure, not a re-trial,"
                " is the road"
            )
        elif not machine_eq:
            plan.reason = String(
                "the current machine differs from this entry's"
                " key; the entry is not applied under a drifted"
                " key (J-044 lookup names the mismatch) and a"
                " fresh measure, not a re-trial, is the road"
            )
        else:
            plan.reason = String(
                "the current model shape differs from this"
                " entry's key; the entry is not applied under a"
                " drifted key (J-044 lookup names the mismatch)"
                " and a fresh measure, not a re-trial, is the"
                " road"
            )
        return plan

    var any_retriable = (
        kind_retriable(entry.prompt)
        or kind_retriable(entry.drafts)
        or kind_retriable(entry.reply)
    )
    if not any_retriable:
        plan.state = PLAN_MANUAL_ONLY
        plan.reason = String(
            "every present kind in this entry is MANUAL-FIXED"
            " (or no kind is present); a hand choice is never"
            " re-trialled away (manual supremacy, J-047's"
            " contract on the face of J-044), so this entry is"
            " never due"
        )
        return plan

    if plan.age_seconds < 0:
        plan.state = PLAN_KEEP
        plan.reason = String(
            "the injected clock reads before the entry's"
            " measured-at stamp (clock skew or a restored file);"
            " a negative age is not evidence about the machine"
            " and never makes an entry due"
        )
        return plan

    var age_due = plan.age_seconds >= RETRIAL_AGE_S
    var opens_due = (
        opens >= RETRIAL_OPENS and plan.age_seconds >= RETRIAL_MIN_AGE_S
    )
    if age_due or opens_due:
        plan.state = PLAN_DUE
        if age_due and opens_due:
            plan.trigger = TRIGGER_AGE_OPENS
        elif age_due:
            plan.trigger = TRIGGER_AGE
        else:
            plan.trigger = TRIGGER_OPENS
        plan.due_prompt = kind_retriable(entry.prompt)
        plan.due_drafts = kind_retriable(entry.drafts)
        plan.due_reply = kind_retriable(entry.reply)
        plan.reason = (
            "the cadence fired (age "
            + String(plan.age_seconds)
            + " s against the "
            + String(RETRIAL_AGE_S)
            + " s age trigger; opens "
            + String(opens)
            + " against the "
            + String(RETRIAL_OPENS)
            + " opens trigger past the "
            + String(RETRIAL_MIN_AGE_S)
            + " s floor); the re-triable kinds are re-measured"
            " under their stored options"
        )
        return plan

    plan.state = PLAN_KEEP
    plan.reason = (
        "not due: age "
        + String(plan.age_seconds)
        + " s is below the "
        + String(RETRIAL_AGE_S)
        + " s age trigger, and the opens trigger needs "
        + String(RETRIAL_OPENS)
        + " opens past the "
        + String(RETRIAL_MIN_AGE_S)
        + " s floor (opens so far "
        + String(opens)
        + "); the learned choice stands unmeasured this open"
    )
    return plan


# --- adoption --------------------------------------------------------------


struct KindRetrial(Copyable, ImplicitlyCopyable):
    """One kind's re-trial record: its outcome and the old and
    new choices (new_choice is the ABSENT state for
    REFUSED-NOW-ABSENT and the old choice itself for the
    carried outcomes)."""

    var kind: Int
    var outcome: Int
    var old_choice: LearnedPassChoice
    var new_choice: LearnedPassChoice

    def __init__(out self):
        self.kind = PASS_PROMPT
        self.outcome = KIND_NOT_PRESENT
        self.old_choice = LearnedPassChoice()
        self.new_choice = LearnedPassChoice()


struct RetrialOutcome(Copyable, Movable):
    """One re-trial attempt's whole record: SKIPPED (it did not
    run; reason stated; nothing was stored or logged), KEPT
    (ran; every re-trialled kind reproduced; the entry was
    re-stored with its stamp refreshed), ADOPTED (ran; at
    least one kind changed or refused-absent; the adopted
    entry was stored), or ERASED (ran; every kind ended
    absent; the entry was erased). log_text() is the change
    log record for the outcomes that ran."""

    var status: Int
    var reason: String
    var plan: RetrialPlan
    var machine: MachineKey
    var model: ModelShape
    var old_measured_at: Int64
    var new_measured_at: Int64
    var kinds: List[KindRetrial]
    var has_new_entry: Bool
    var new_entry: LearnedEntry

    def __init__(out self):
        self.status = OUT_SKIPPED
        self.reason = String("not attempted")
        self.plan = RetrialPlan()
        self.machine = MachineKey()
        self.model = ModelShape()
        self.old_measured_at = 0
        self.new_measured_at = 0
        self.kinds = List[KindRetrial]()
        self.has_new_entry = False
        self.new_entry = LearnedEntry()

    def ran(self) -> Bool:
        return self.status != OUT_SKIPPED

    def log_text(self) -> String:
        """The change log record (module header): key, trigger
        with its numbers, the measured-at move, per-kind
        outcomes with old -> new in J-044's rendering, and the
        outcome. Defined for outcomes that ran; a SKIPPED
        outcome renders its skip reason instead and is never
        appended (apply/run append only ran outcomes)."""
        if not self.ran():
            return String("retrial: SKIPPED -- ") + self.reason + "\n"
        var out_str = String("retrial: at ") + String(self.new_measured_at)
        out_str += " (unix s)\n"
        out_str += "  " + self.machine.render() + "\n"
        out_str += "  " + self.model.render() + "\n"
        out_str += (
            "  trigger: "
            + trigger_name(self.plan.trigger)
            + " (age "
            + String(self.plan.age_seconds)
            + " s, opens "
            + String(self.plan.opens)
            + " since measure; cadence: age >= "
            + String(RETRIAL_AGE_S)
            + " s, or opens >= "
            + String(RETRIAL_OPENS)
            + " with age >= "
            + String(RETRIAL_MIN_AGE_S)
            + " s)\n"
        )
        out_str += (
            "  measured-at: "
            + String(self.old_measured_at)
            + " -> "
            + String(self.new_measured_at)
            + "\n"
        )
        for i in range(len(self.kinds)):
            var k = self.kinds[i]
            out_str += (
                "  "
                + pass_name(k.kind)
                + ": "
                + kind_outcome_name(k.outcome)
                + " -- "
            )
            if k.outcome == KIND_CHANGED:
                out_str += (
                    _choice_body(k.old_choice)
                    + " -> "
                    + _choice_body(k.new_choice)
                    + "\n"
                )
            elif k.outcome == KIND_REFUSED_ABSENT:
                out_str += (
                    _choice_body(k.old_choice)
                    + " -> absent (the re-trial's chooser refused;"
                    " a refusal leaves no learned default, J-044)\n"
                )
            elif k.outcome == KIND_REPRODUCED:
                out_str += (
                    _choice_body(k.new_choice)
                    + " (re-measured and reproduced; the choice is"
                    " kept and the stamp refreshed)\n"
                )
            elif k.outcome == KIND_CARRIED_MANUAL:
                out_str += (
                    _choice_body(k.old_choice)
                    + " (a hand choice, carried verbatim; never"
                    " re-trialled)\n"
                )
            elif k.outcome == KIND_CARRIED:
                out_str += (
                    _choice_body(k.old_choice)
                    + " (not due in this re-trial; carried)\n"
                )
            else:
                out_str += "absent (nothing learned for this kind)\n"
        out_str += (
            "  outcome: "
            + outcome_name(self.status)
            + " -- "
            + self.reason
            + "\n"
        )
        return out_str


def _choice_body(choice: LearnedPassChoice) -> String:
    """One choice rendered without its kind prefix (the log
    line carries the kind itself): J-044's per-choice form --
    the chooser's label with device / threads / decision /
    originating option, or the absent state."""
    if not choice.present:
        return String("absent (no learned choice)")
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
        + ")"
    )


def _choices_equal(a: LearnedPassChoice, b: LearnedPassChoice) -> Bool:
    return (
        a.present == b.present
        and a.option_text == b.option_text
        and a.placement_text == b.placement_text
        and a.device == b.device
        and a.threads == b.threads
        and a.decision == b.decision
    )


def _skipped(
    reason: String,
    plan: RetrialPlan,
    machine: MachineKey,
    model: ModelShape,
) -> RetrialOutcome:
    var outcome = RetrialOutcome()
    outcome.status = OUT_SKIPPED
    outcome.reason = reason
    outcome.plan = plan
    outcome.machine = machine
    outcome.model = model
    return outcome^


def adopt_retrial(
    old_entry: LearnedEntry,
    plan: RetrialPlan,
    fresh_prompt: LearnedPassChoice,
    fresh_drafts: LearnedPassChoice,
    fresh_reply: LearnedPassChoice,
    now: Int64,
) raises -> RetrialOutcome:
    """Build the adopted entry from one entry, its DUE plan,
    and the fresh choices for the due kinds (converted from
    the choosers' records by the caller -- run_retrial does it
    through learned_pass_from_choice; the fresh arguments for
    kinds the plan does not mark due are ignored). Pure: no
    disk, no measurement. Raises when the plan is not DUE, or
    when a fresh choice is invalid in a way other than the
    all-absent erase case (which is an outcome, not an error).
    The caller persists the outcome (apply_retrial does)."""
    if plan.state != PLAN_DUE:
        raise Error(
            "Retrial: adoption requires a DUE plan, got "
            + plan_state_name(plan.state)
        )
    var outcome = RetrialOutcome()
    outcome.plan = plan
    outcome.machine = old_entry.machine
    outcome.model = old_entry.model
    outcome.old_measured_at = old_entry.measured_at
    outcome.new_measured_at = now

    var fresh = List[LearnedPassChoice]()
    fresh.append(fresh_prompt)
    fresh.append(fresh_drafts)
    fresh.append(fresh_reply)
    var kinds = List[Int]()
    kinds.append(PASS_PROMPT)
    kinds.append(PASS_DRAFTS)
    kinds.append(PASS_REPLY)
    var olds = List[LearnedPassChoice]()
    olds.append(old_entry.prompt)
    olds.append(old_entry.drafts)
    olds.append(old_entry.reply)

    var new_entry = old_entry.copy()
    new_entry.measured_at = now
    var any_change = False
    for i in range(3):
        var kind = kinds[i]
        var record = KindRetrial()
        record.kind = kind
        record.old_choice = olds[i]
        if plan.due_for(kind):
            record.new_choice = fresh[i]
            if not fresh[i].present:
                record.outcome = KIND_REFUSED_ABSENT
                any_change = True
            elif _choices_equal(olds[i], fresh[i]):
                record.outcome = KIND_REPRODUCED
            else:
                record.outcome = KIND_CHANGED
                any_change = True
            if kind == PASS_PROMPT:
                new_entry.prompt = fresh[i]
            elif kind == PASS_DRAFTS:
                new_entry.drafts = fresh[i]
            else:
                new_entry.reply = fresh[i]
        elif not olds[i].present:
            record.outcome = KIND_NOT_PRESENT
            record.new_choice = olds[i]
        elif olds[i].decision == "MANUAL-FIXED":
            record.outcome = KIND_CARRIED_MANUAL
            record.new_choice = olds[i]
        else:
            record.outcome = KIND_CARRIED
            record.new_choice = olds[i]
        outcome.kinds.append(record)

    if not new_entry.has_any():
        outcome.status = OUT_ERASED
        outcome.has_new_entry = False
        outcome.reason = String(
            "every kind of the entry ended absent in the"
            " re-trial (each due kind's chooser refused, and no"
            " carried kind remains); the entry is erased rather"
            " than stored as the nothing J-044 refuses at save"
        )
        return outcome^
    new_entry.validate()
    outcome.new_entry = new_entry.copy()
    outcome.has_new_entry = True
    if any_change:
        outcome.status = OUT_ADOPTED
        outcome.reason = String(
            "at least one re-trialled kind changed (or refused"
            " to absent); the adopted entry replaces the learned"
            " entry under the same key, stamped with the"
            " re-trial instant"
        )
    else:
        outcome.status = OUT_KEPT
        outcome.reason = String(
            "every re-trialled kind reproduced its learned"
            " choice; the choice is kept and the entry re-stored"
            " with its measured-at stamp refreshed to the"
            " re-trial instant (the choice was re-measured then"
            " and stood)"
        )
    return outcome^


# --- the log file ----------------------------------------------------------


def retrial_log_path(learned_path: String) -> String:
    """The retrial log lives beside the learned file it audits:
    the learned path with '.retrials.log' appended (answered-
    locally; the J-045 doc records the rule)."""
    return learned_path + ".retrials.log"


def _retrial_cstring(value: String) raises -> List[Int8]:
    if len(value.bytes()) == 0 or len(value.bytes()) >= 4096:
        raise Error("Retrial: path must contain 1..4095 bytes")
    var result = List[Int8]()
    for byte in value.as_bytes():
        if byte == 0:
            raise Error("Retrial: path contains NUL")
        result.append(Int8(byte))
    result.append(0)
    return result^


def append_retrial_log(learned_path: String, outcome: RetrialOutcome) raises:
    """Append one ran outcome's log record to the retrial log,
    creating the log if needed, and fsync before close: a
    logged change must survive the process that made it. A
    SKIPPED outcome raises -- the log records re-trials that
    ran, never checks that did not."""
    if not outcome.ran():
        raise Error(
            "Retrial: a skipped re-trial writes no log record"
            " (the log records re-trials that ran)"
        )
    var path = _retrial_cstring(retrial_log_path(learned_path))
    var fd = external_call["open64", Int32](
        path.unsafe_ptr(), Int32(524353), Int32(420)
    )
    if fd < 0:
        raise Error("Retrial: cannot open the retrial log to append")
    # Append by position, in the tree's proven pwrite discipline
    # (state_vault / learned_file): the end offset comes from
    # fstat, and each chunk is written at its absolute offset.
    # The log's writer is the one surface running the re-trial
    # (host contract); no concurrent-append interleave is
    # claimed.
    var stat = InlineArray[UInt64, 18](fill=0)
    if external_call["fstat", Int32](fd, stat.unsafe_ptr()) != 0:
        _ = external_call["close", Int32](fd)
        raise Error("Retrial: cannot inspect the retrial log")
    var base = Int64(stat[6])
    var text = outcome.log_text()
    var source = text.as_bytes()
    var offset = 0
    try:
        while offset < len(source):
            var written = external_call["pwrite", Int](
                fd, source.unsafe_ptr().unsafe_offset(offset),
                len(source) - offset, base + Int64(offset),
            )
            if written < 0:
                var errno_ptr = external_call[
                    "__errno_location", Pointer[Int32, MutUntrackedOrigin]
                ]()
                if errno_ptr.unsafe_load() == 4:
                    continue
                raise Error("Retrial: retrial log write failed")
            if written == 0:
                raise Error("Retrial: retrial log write made no progress")
            offset += written
        if external_call["fsync", Int32](fd) != 0:
            raise Error("Retrial: cannot synchronise the retrial log")
    except error:
        _ = external_call["close", Int32](fd)
        raise error
    if external_call["close", Int32](fd) != 0:
        raise Error("Retrial: cannot close the retrial log")


def apply_retrial(
    path: String,
    old_entry: LearnedEntry,
    plan: RetrialPlan,
    fresh_prompt: LearnedPassChoice,
    fresh_drafts: LearnedPassChoice,
    fresh_reply: LearnedPassChoice,
    now: Int64,
) raises -> RetrialOutcome:
    """Adopt + persist: build the adopted entry (adopt_retrial),
    then store it through J-044's store path (same key
    replaced, other keys preserved, a corrupt file refused
    untouched) -- or erase the entry when the re-trial left
    nothing -- and append the change record to the retrial
    log. The store lands BEFORE the log append (module
    header): if the append raises, the adoption stands and
    the error surfaces; it is never swallowed."""
    var outcome = adopt_retrial(
        old_entry, plan, fresh_prompt, fresh_drafts, fresh_reply, now
    )
    if outcome.status == OUT_ERASED:
        var removed = erase_learned_entry(
            path, old_entry.machine, old_entry.model
        )
        if not removed:
            raise Error(
                "Retrial: the re-trialled entry vanished before"
                " its erasure could land"
            )
    else:
        _ = store_learned_entry(path, outcome.new_entry)
    append_retrial_log(path, outcome)
    return outcome^


# --- the live re-trial -------------------------------------------------------


def _options_for_kind(
    pass_kind: Int, option_text: String
) raises -> PlacementOptions:
    """The options a re-trial measures one kind under: the
    entry's stored option for that kind (its provenance), the
    other kinds left at their defaults (their records are not
    read), source default -- the option text is the learned
    provenance, not a fresh user input."""
    var options = PlacementOptions()
    var option = PlacementOption()
    option.choice = parse_placement_value(option_text, pass_kind)
    option.source = SOURCE_DEFAULT
    option.was_set = False
    if pass_kind == PASS_PROMPT:
        options.prompt = option
    elif pass_kind == PASS_DRAFTS:
        options.drafts = option
    else:
        options.reply = option
    return options


def run_retrial(
    path: String,
    machine: MachineKey,
    model: ModelShape,
    now: Int64,
    opens_since_measure: Int,
    inventory: DeviceInventory,
    facts: CpuFacts,
    config: HarnessConfig,
) raises -> RetrialOutcome:
    """The live re-trial for one key: load, look up, plan, and
    -- only on DUE -- re-measure each due kind through its own
    chooser (J-040 prompt / J-041 reply / J-042 drafts) under
    the kind's stored option, then adopt, store, and log via
    apply_retrial. Every non-due state returns SKIPPED with
    its reason and writes nothing. A chooser or IO failure
    raises BEFORE any store lands (measurement precedes
    adoption), so a failed re-trial leaves the learned entry
    exactly as it stood."""
    var load = load_learned_file(path)
    if load.status != LOAD_LOADED:
        var plan = RetrialPlan()
        plan.reason = load.reason
        return _skipped(
            "the learned state is not LOADED ("
            + load.reason
            + "); no re-trial runs and nothing is written",
            plan,
            machine,
            model,
        )
    var lookup = lookup_learned(load, machine, model)
    if lookup.status != LOOKUP_APPLIED:
        var plan = RetrialPlan()
        plan.reason = lookup.reason
        return _skipped(
            "no learned entry applies to this key ("
            + lookup.reason
            + "); a fresh measure is the caller's road, not a"
            " re-trial, and nothing is written",
            plan,
            machine,
            model,
        )
    var entry = lookup.entry.copy()
    var plan = plan_retrial(entry, now, opens_since_measure, machine, model)
    if plan.state != PLAN_DUE:
        return _skipped(
            "the cadence does not fire for this entry: "
            + plan_state_name(plan.state)
            + " -- "
            + plan.reason,
            plan,
            machine,
            model,
        )
    var fresh_prompt = entry.prompt
    var fresh_drafts = entry.drafts
    var fresh_reply = entry.reply
    if plan.due_prompt:
        var record = choose_prompt_placement(
            _options_for_kind(PASS_PROMPT, entry.prompt.option_text),
            inventory,
            facts,
            config,
        )
        fresh_prompt = learned_pass_from_choice(
            record.option_text,
            record.chosen_label,
            record.chosen_device,
            record.chosen_threads,
            _decision_name(record.decision_code),
            record.has_choice,
        )
    if plan.due_drafts:
        var record = choose_draft_placement(
            _options_for_kind(PASS_DRAFTS, entry.drafts.option_text),
            inventory,
            facts,
            config,
        )
        fresh_drafts = learned_pass_from_choice(
            record.option_text,
            record.chosen_label,
            record.chosen_device,
            record.chosen_threads,
            _decision_name(record.decision_code),
            record.has_choice,
        )
    if plan.due_reply:
        var record = choose_reply_placement(
            _options_for_kind(PASS_REPLY, entry.reply.option_text),
            inventory,
            facts,
            config,
        )
        fresh_reply = learned_pass_from_choice(
            record.option_text,
            record.chosen_label,
            record.chosen_device,
            record.chosen_threads,
            _decision_name(record.decision_code),
            record.has_choice,
        )
    return apply_retrial(
        path, entry, plan, fresh_prompt, fresh_drafts, fresh_reply, now
    )
