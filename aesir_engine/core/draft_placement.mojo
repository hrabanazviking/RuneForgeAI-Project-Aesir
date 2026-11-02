"""Auto choice for draft-check passes (Janas road J-042).

J-036 built the placement option surface (what a user asks for),
J-037 the device inventory (what the machine offers), J-038 the
measurement harness (bounded micro-runs per device candidate),
J-039 the thread topology trials (the thread-count ladder on
the CPU, measured through one threaded executor), J-040 the
prompt kind's chooser and J-041 the reply kind's. This module
is the draft-check kind's chooser, built to the same pattern
and answering J-042's own question: for the DRAFT-CHECK pass
kind -- the small-batch verification pass of speculative
decoding, token band 2..16 (J-035's taxonomy) -- how does the
engine turn measurements into one placement, keep it for the
session, and report what it chose and why?

WHY DRAFT-CHECK IS NOT PROMPT OR REPLY, stated from Aesir's
own architecture before any rule is fixed. A prompt pass is a
batched prefill (chunks of up to 256 tokens): placement fixed
costs amortise across the batch. A reply pass is one token:
fixed costs recur per token, but the work is the smallest in
the engine. A draft-check pass sits between them and is the
band where accelerators are least obvious: the batch (2..16
tokens) is too small to amortise a device launch the way a
prompt chunk does, yet each token's verification work is a
full-width forward over the batch, so the parallelisable
fraction is larger than reply's. Which side wins is a genuine
measurement question -- on hardware and passes that exist.

THE HONESTY CORE OF THIS MODULE, stated before the rule: on
today's tree there is nothing to measure. Aesir has NO
draft-check pass at all (J-035 gap G1): no proposer, no
verification batch, no KV rollback in any session;
core/speculative.mojo is acceptance arithmetic only, wired to
nothing. J-036 therefore fails draft-check USE closed, always
(require_draft_check_use() raises, naming G1 + Part V
J-071/J-072). J-038's harness classifies every draft-check
candidate UNMEASURABLE-WITH-REASON, always, before inventory
is even consulted (its classification order states the
absence is the strongest true reason), and J-039's thread
trials record every draft-check rung UNMEASURABLE-WITH-REASON
likewise. This module invents NO synthetic small-batch
workload and calls it a draft-check measurement: the prompt
and reply workloads exist, and timing either of them in
draft-check's name would be a fabricated number. The
workload spec the live builder passes to the sweep and the
trials is the reply-shaped placeholder J-039's own trials
test passes for this kind; it is INERT here -- both consumers
classify or return before any round runs for this kind, and
the spec's shape is never executed, timed, or reported. When
Part V builds the pass, defining the real draft-check
workload shape (a 2..16-row verification product) is part of
what it must provide.

THE COMPARED SET, stated before any number. As in J-040 and
J-041, two measurement axes exist:

- the DEVICE axis (J-038's sweep for the drafts kind): the
  field the resolved drafts option names. Every candidate on
  it records UNMEASURABLE-WITH-REASON (G1) today -- never
  EXCLUDED, because the harness's classification order puts
  the pass's absence before inventory truth, and never
  MEASURED, because there is no pass to time.
- the THREAD axis (J-039's trials for the drafts kind): the
  CPU ladder is still derived from the machine's facts (the
  counts exist), and every rung records
  UNMEASURABLE-WITH-REASON (G1). Nothing is timed.

The rankable set is therefore EMPTY BY CONSTRUCTION today.
That is not a defect of the chooser; it is the field's true
state, and the decision rule below is written so its honest
live outcomes are exactly the ones an empty measured set
produces.

THE DECISION RULE, pre-registered (stated here and in
docs/janas/J042_AUTO_DRAFT_PLACEMENT.md section 3 before any
J-042 live number was measured; decide_draft_choice is its
pure form, unit-tested on injected measurements). The rule
is J-040's rule as adopted unchanged by J-041, ADOPTED
UNCHANGED here too, for the same stated reasons: one rule
across kinds keeps choices comparable and keeps the learned
file (J-044) one shape, and no draft-check measurement
exists that could justify different numbers. The rule:

- The session DEFAULT is cpu at 1 thread (serial). It exists
  wherever the inventory states a CPU present. For this kind
  the default is a KEPT LABEL ONLY today: choosing it runs
  nothing, because no draft-check pass exists to run anywhere
  (the use gate above stands untouched by anything here).
- MANUAL forms first: a single-device or co-work drafts
  option FIXES the choice. The chooser never ranks against
  it and never substitutes (manual supremacy is J-047's
  slice; this slice's duty is the weaker, binding one: auto
  never overrides an explicit non-auto option). The named
  candidate's own state rides on the record -- for this kind
  that state is UNMEASURABLE-WITH-REASON (G1) -- and the
  record states in the open that choosing is not using: any
  actual USE of a drafts placement still fails closed
  through J-036's require_draft_check_use() until Part V
  builds the pass. An explicit drafts option naming the NPU
  never reaches this module at all (J-036 refuses it at
  parse, whole: the NPU never takes a draft-check pass).
- AUTO and RACE rank the measured set (a race ranks only its
  named members). With zero measured candidates -- the only
  live case today: the default is chosen as
  NO-MEASURED-FALLBACK when the CPU is present, with every
  candidate's reason on the record; when the CPU itself is
  absent the record is a REFUSAL -- no choice, reasons
  stated. A chooser that invents a placement on an empty
  field would be fabricating.
- With exactly one measured candidate it is chosen as
  SOLE-MEASURED: last candidate standing, not a victory --
  no margin exists and none is claimed.
- With two or more, let BEST be the lowest median and RUNNER
  the second lowest. BEST is a MEASURED WIN only when BOTH
  hurdles clear: (a) the relative margin
  (runner_median - best_median) exceeds 10% of best_median;
  and (b) separation: best's slowest counted round (its max)
  is still below runner's median, so the two candidates'
  rounds do not interleave. If either hurdle fails, the
  DEFAULT is kept: DEFAULT-BY-NOISE when a non-default
  candidate was fastest but did not clear the rule,
  DEFAULT-CONFIRMED when the default itself was fastest but
  the win is not claimed. The record states which hurdle
  failed, with the numbers.
- Bound-stopped candidates (partial rounds under a time
  bound) are recorded with the rounds that stand and are
  NEVER ranked: a partial sweep is not a measurement of the
  candidate.

The win / sole / noise / confirmed branches are unreachable
from the live builder today (no measured candidate can
exist); they are kept, and unit-tested on injected sets,
because they are the rule Part V's real measurements will
flow through -- deleting them would leave the future pass
with a chooser that can only fall back.

STABILITY, stated on every record: a draft-check choice
today rests on NO measurement at all -- it is the
pre-registered fallback for an unmeasurable kind, not a
measured verdict. When Part V makes the kind measurable,
single-sweep stability is NOT PROVEN (J-039: per-kind
verdicts flipped between sweeps under contention), exactly
as for the other kinds. Re-trials are J-045; the learned
file is J-044; neither is built here.

SESSION KEEPING. DraftPlacementSession decides ONCE:
decide_once stores the first record and refuses a second
decision for the same session (a new session is the road to
a new choice; the refusal names J-045). The report is a
stable rendering of the stored record -- two reports of one
session are byte-identical, which is what makes it testable
and what a CLI/server surface can print verbatim later.

WHAT PART V MUST PROVIDE for this chooser to become
measurable (the deferred-leg recipe, in full in the doc):
a real draft-check verify pass (J-071's design, J-072's
draft loop) AND a harness executor for it -- a WorkloadSpec
kind for the verification shape (rows 2..16) whose rounds
execute the actual verify arithmetic -- after which J-038's
classification for this kind stops returning unmeasurable,
J-039's trials time real rungs, and this module's ranked
branches receive their first honest inputs with no change
to the rule. Until then every number this module could
print would be a fabrication, so it prints none.

HOST CONTRACT: choose_draft_placement(options, inventory,
facts, config) is the live entry point -- a pure function of
the resolved J-036 options, the J-037 inventory, the J-037
CPU facts, and the J-038 harness config. A surface calls it
at model open, stores the record in a DraftPlacementSession,
and prints session.report() beside the placement and device
reports. This slice wires it into NO live session path: no
session consumes a drafts placement yet (and none may use
one -- the J-036 gate), and claiming otherwise would fake
the integration. Co-work execution is J-043. See
docs/janas/J042_AUTO_DRAFT_PLACEMENT.md.
"""

from core.device_inventory import CpuFacts, DeviceInventory
from core.placement_harness import (
    RES_BOUND_STOPPED,
    RES_EXCLUDED,
    RES_MEASURED,
    RES_UNMEASURABLE,
    HarnessConfig,
    TimingSummary,
    enumerate_candidates,
    reply_workload,
    run_placement_measurement,
)
from core.placement_options import (
    DEVICE_CPU,
    PASS_DRAFTS,
    PLACE_AUTO,
    PLACE_COWORK,
    PLACE_RACE,
    PLACE_SINGLE,
    PlacementChoice,
    PlacementOptions,
    source_name,
)
from core.thread_topology import (
    TRES_BOUND_STOPPED,
    TRES_MEASURED,
    run_thread_trials,
)

# Measurement status (one candidate on the choice record).
comptime PM_MEASURED = 0
comptime PM_EXCLUDED = 1
comptime PM_UNMEASURABLE = 2
comptime PM_BOUND_STOPPED = 3

# Decision codes (DraftChoiceRecord.decision_code).
comptime DEC_MEASURED_WIN = 0
comptime DEC_DEFAULT_CONFIRMED = 1
comptime DEC_DEFAULT_BY_NOISE = 2
comptime DEC_SOLE_MEASURED = 3
comptime DEC_NO_MEASURED_FALLBACK = 4
comptime DEC_MANUAL_FIXED = 5
comptime DEC_REFUSAL = 6

# The pre-registered margin band, in percent of the best
# median (module header: J-040's band, adopted unchanged by
# J-041 and here, for comparability across kinds).
comptime MARGIN_PERCENT = 10

# The session default: the CPU at the serial rung. threads == 1
# and device == DEVICE_CPU is what _is_default tests.
comptime DEFAULT_THREADS = 1


def decision_name(code: Int) -> String:
    if code == DEC_MEASURED_WIN:
        return String("MEASURED-WIN")
    if code == DEC_DEFAULT_CONFIRMED:
        return String("DEFAULT-CONFIRMED")
    if code == DEC_DEFAULT_BY_NOISE:
        return String("DEFAULT-BY-NOISE")
    if code == DEC_SOLE_MEASURED:
        return String("SOLE-MEASURED")
    if code == DEC_NO_MEASURED_FALLBACK:
        return String("NO-MEASURED-FALLBACK")
    if code == DEC_MANUAL_FIXED:
        return String("MANUAL-FIXED")
    return String("REFUSAL")


def default_label() -> String:
    return String("cpu threads=1")


struct DraftMeasurement(Copyable, ImplicitlyCopyable):
    """One candidate as the chooser records it: a thread rung of
    the CPU (device cpu, threads >= 1, from J-039's trials) or a
    device candidate (threads == 0, from J-038's sweep), with
    its status, its reason when it did not measure, and its
    timing summary when it did. For this kind every live
    candidate is unmeasurable-with-reason today (module
    header); the measured form exists for the rule's future
    inputs and its unit tests."""

    var label: String
    var device: Int
    var threads: Int
    var status: Int
    var reason: String
    var summary: TimingSummary

    def __init__(out self):
        self.label = String("")
        self.device = DEVICE_CPU
        self.threads = 0
        self.status = PM_UNMEASURABLE
        self.reason = String("")
        self.summary = TimingSummary()

    def render(self) -> String:
        if self.status == PM_MEASURED:
            return (
                self.label
                + ": median "
                + String(self.summary.median_ns)
                + " ns (min "
                + String(self.summary.min_ns)
                + ", max "
                + String(self.summary.max_ns)
                + ", spread "
                + String(self.summary.spread_ns)
                + "; rounds "
                + String(self.summary.count)
                + ")"
            )
        if self.status == PM_EXCLUDED:
            return self.label + ": EXCLUDED -- " + self.reason
        if self.status == PM_BOUND_STOPPED:
            var line = self.label + ": BOUND-STOPPED -- " + self.reason
            if self.summary.count > 0:
                line += (
                    " (rounds counted "
                    + String(self.summary.count)
                    + ", median "
                    + String(self.summary.median_ns)
                    + " ns over the counted rounds; not ranked)"
                )
            return line
        return self.label + ": UNMEASURABLE -- " + self.reason


def _is_default(m: DraftMeasurement) -> Bool:
    return m.device == DEVICE_CPU and m.threads == DEFAULT_THREADS


def _option_allows(option: PlacementChoice, device: Int) -> Bool:
    """Whether a ranked candidate's device is in the option's
    field: auto allows the whole field; a race allows only its
    named members. (Single/co-work never reach ranking.)"""
    if option.form == PLACE_RACE:
        return option.names_device(device)
    return True


struct DraftChoiceRecord(Copyable, Movable):
    """The session-scoped choice record: what was chosen, the
    decision that produced it with the numbers behind it (when
    numbers exist -- for this kind today, none do), the whole
    field with every candidate's reason, and the axes note.
    report() renders it in the stable form a surface prints."""

    var option_text: String
    var option_form: Int
    var option_source: Int
    var decision_code: Int
    var decision_text: String
    var has_choice: Bool
    var chosen_label: String
    var chosen_device: Int
    var chosen_threads: Int
    var best_label: String
    var best_median_ns: Int
    var runner_label: String
    var runner_median_ns: Int
    var margin_percent: Int
    var separation_ok: Bool
    var measurements: List[DraftMeasurement]
    var axes_note: String

    def __init__(out self):
        self.option_text = String("auto")
        self.option_form = PLACE_AUTO
        self.option_source = 0
        self.decision_code = DEC_REFUSAL
        self.decision_text = String("not decided")
        self.has_choice = False
        self.chosen_label = String("")
        self.chosen_device = DEVICE_CPU
        self.chosen_threads = 0
        self.best_label = String("")
        self.best_median_ns = -1
        self.runner_label = String("")
        self.runner_median_ns = -1
        self.margin_percent = -1
        self.separation_ok = False
        self.measurements = List[DraftMeasurement]()
        self.axes_note = String("")

    def report(self) -> String:
        var out_str = String("draft-check placement report\n")
        out_str += (
            "option: "
            + self.option_text
            + " (source "
            + source_name(self.option_source)
            + ")\n"
        )
        out_str += (
            "decision: "
            + decision_name(self.decision_code)
            + " -- "
            + self.decision_text
            + "\n"
        )
        if self.has_choice:
            out_str += "chosen: " + self.chosen_label + "\n"
        else:
            out_str += "chosen: NONE (refusal -- no placement is claimed)\n"
        out_str += (
            "rule: pre-registered (J-042, adopting J-040/J-041 unchanged): a measured winner must"
            " beat the runner-up by more than "
            + String(MARGIN_PERCENT)
            + "% of its own median AND its slowest counted round"
            " must beat the runner-up's median; otherwise the"
            " session default (cpu threads=1) is kept. A sole"
            " measured candidate is chosen as sole-measured;"
            " no measured candidate falls back to the default"
            " when the cpu is present, else the record is a"
            " refusal. An explicit single/co-work option fixes"
            " the choice and is never ranked against.\n"
        )
        if self.best_median_ns >= 0:
            out_str += (
                "best: "
                + self.best_label
                + " median "
                + String(self.best_median_ns)
                + " ns"
            )
            if self.runner_median_ns >= 0:
                out_str += (
                    "; runner-up: "
                    + self.runner_label
                    + " median "
                    + String(self.runner_median_ns)
                    + " ns; margin "
                    + String(self.margin_percent)
                    + "%; separation "
                    + (String("ok") if self.separation_ok else String("failed"))
                )
            out_str += "\n"
        out_str += "candidates:\n"
        for m in self.measurements:
            out_str += "  " + m.render() + "\n"
        if self.axes_note.byte_length() > 0:
            out_str += "axes: " + self.axes_note + "\n"
        out_str += (
            "measurability: no draft-check pass exists in Aesir"
            " today (J-035 gap G1; Part V J-071/J-072 own building"
            " it), so no candidate above carries a timing and"
            " nothing was ranked; this record becomes measurable"
            " only when the harness gains a real draft-check"
            " verify-pass executor (Part V), and any actual use"
            " of a drafts placement fails closed through"
            " require_draft_check_use() (J-036) until then\n"
        )
        out_str += (
            "session: this choice is kept for the session; it is"
            " decided once and is not re-decided per pass"
            " (re-trials are J-045)\n"
        )
        out_str += (
            "stability: this choice rests on no measurement at"
            " all today -- it is the pre-registered fallback for"
            " an unmeasurable kind, not a measured verdict; when"
            " Part V makes the kind measurable, single-sweep"
            " stability is NOT PROVEN (J-039: per-kind verdicts"
            " flipped between sweeps under contention) -- the"
            " record states the field and its reasons, nothing"
            " more\n"
        )
        return out_str


def _fill_default_choice(mut record: DraftChoiceRecord):
    record.has_choice = True
    record.chosen_label = default_label()
    record.chosen_device = DEVICE_CPU
    record.chosen_threads = DEFAULT_THREADS


def decide_draft_choice(
    measurements: List[DraftMeasurement],
    option: PlacementChoice,
    option_source: Int,
    default_available: Bool,
) -> DraftChoiceRecord:
    """The pre-registered decision rule (module header), as a
    pure function of injected measurements. The live entry point
    builds the measurements from J-038's sweep and J-039's
    trials -- for this kind, today, an all-unmeasurable field;
    the tests also inject synthetic measured sets to pin the
    rule's ranked branches for the day Part V feeds it real
    ones. default_available states whether the inventory holds
    the default's device (the CPU) present -- the fact the
    no-measured branch and the refusal stand on."""
    var record = DraftChoiceRecord()
    record.option_text = option.describe()
    record.option_form = option.form
    record.option_source = option_source
    for m in measurements:
        record.measurements.append(m)

    # Manual forms fix the choice before any ranking.
    if option.form == PLACE_SINGLE or option.form == PLACE_COWORK:
        record.decision_code = DEC_MANUAL_FIXED
        record.has_choice = True
        record.chosen_label = option.describe()
        record.chosen_device = option.first
        record.chosen_threads = 0
        var state = String(
            "no measurement of the named candidate is on record"
        )
        for m in measurements:
            if m.device == option.first and m.threads == 0:
                if m.status == PM_MEASURED:
                    state = (
                        "the named candidate measured at median "
                        + String(m.summary.median_ns)
                        + " ns in the device sweep"
                    )
                elif m.status == PM_EXCLUDED:
                    state = (
                        "the named candidate is EXCLUDED on this"
                        " machine -- " + m.reason
                    )
                elif m.status == PM_BOUND_STOPPED:
                    state = (
                        "the named candidate was BOUND-STOPPED -- "
                        + m.reason
                    )
                else:
                    state = (
                        "the named candidate is UNMEASURABLE on"
                        " this tree today -- " + m.reason
                    )
                break
        record.decision_text = (
            "the explicit drafts option '"
            + option.describe()
            + "' fixes this choice; the auto rule was not applied"
            " and no measured candidate was substituted ("
            + state
            + "; a device option does not fix a thread count, so"
            " the thread axis stands where the session leaves it"
            " -- and for this kind that axis is unmeasured in any"
            " case, every rung unmeasurable-with-reason (G1);"
            " choosing is not using: any actual use of a drafts"
            " placement still fails closed through"
            " require_draft_check_use() (J-036) until Part V"
            " (J-071/J-072) builds the pass; open-time refusal of"
            " a hand placement is J-047)"
        )
        return record^

    # Ranked set: measured, option-allowed, full rounds only.
    # Empty by construction for this kind today (module header).
    var ranked = List[Int]()
    for i in range(len(measurements)):
        var m = measurements[i]
        if m.status != PM_MEASURED:
            continue
        if not _option_allows(option, m.device):
            continue
        ranked.append(i)

    if len(ranked) == 0:
        if default_available:
            record.decision_code = DEC_NO_MEASURED_FALLBACK
            _fill_default_choice(record)
            record.decision_text = (
                "no candidate measured (every candidate is"
                " unmeasurable-with-reason for this kind today --"
                " draft-check passes do not exist in Aesir yet"
                " (J-035 gap G1; Part V J-071/J-072 own building"
                " the pass) -- with its reason on this record);"
                " the session default is kept because the"
                " inventory states the cpu present -- a fallback,"
                " not a measurement result, and a kept label"
                " only: no draft-check pass runs anywhere until"
                " Part V builds it"
            )
        else:
            record.decision_code = DEC_REFUSAL
            record.has_choice = False
            record.decision_text = (
                "no candidate measured and the session default's"
                " device (cpu) is not present in the inventory,"
                " so no fallback exists; the choice is refused"
                " with every candidate's reason on this record"
                " rather than fabricated"
            )
        return record^

    # Best and runner-up by median (first index wins ties, so
    # the outcome is deterministic on the input order, which
    # the live builder fixes as ladder order).
    var best = ranked[0]
    var runner = -1
    for idx in ranked:
        if measurements[idx].summary.median_ns < measurements[best].summary.median_ns:
            runner = best
            best = idx
        elif idx != best and (
            runner < 0
            or measurements[idx].summary.median_ns
            < measurements[runner].summary.median_ns
        ):
            runner = idx
    var b = measurements[best]
    record.best_label = b.label
    record.best_median_ns = b.summary.median_ns

    if runner < 0:
        record.decision_code = DEC_SOLE_MEASURED
        record.has_choice = True
        record.chosen_label = b.label
        record.chosen_device = b.device
        record.chosen_threads = b.threads
        record.decision_text = (
            "exactly one candidate measured ("
            + b.label
            + ", median "
            + String(b.summary.median_ns)
            + " ns); it is chosen as the sole measured candidate"
            " -- last candidate standing, not a victory: no"
            " runner-up exists, so no margin is claimed"
        )
        return record^

    var r = measurements[runner]
    record.runner_label = r.label
    record.runner_median_ns = r.summary.median_ns
    var gap = r.summary.median_ns - b.summary.median_ns
    record.margin_percent = gap * 100 // b.summary.median_ns
    var margin_ok = gap * 100 > MARGIN_PERCENT * b.summary.median_ns
    record.separation_ok = b.summary.max_ns < r.summary.median_ns

    if margin_ok and record.separation_ok:
        record.decision_code = DEC_MEASURED_WIN
        record.has_choice = True
        record.chosen_label = b.label
        record.chosen_device = b.device
        record.chosen_threads = b.threads
        record.decision_text = (
            b.label
            + " beat "
            + r.label
            + " by "
            + String(record.margin_percent)
            + "% of its median ("
            + String(b.summary.median_ns)
            + " ns vs "
            + String(r.summary.median_ns)
            + " ns), beyond the "
            + String(MARGIN_PERCENT)
            + "% margin band, and its slowest counted round ("
            + String(b.summary.max_ns)
            + " ns) beats the runner-up's median -- a measured"
            " win under the pre-registered rule, from this one"
            " sweep"
        )
        return record^

    # A hurdle failed: the default is kept, the claim withheld.
    _fill_default_choice(record)
    var failed = String("")
    if not margin_ok:
        failed += (
            "the margin is "
            + String(record.margin_percent)
            + "%, inside the "
            + String(MARGIN_PERCENT)
            + "% band"
        )
    if not record.separation_ok:
        if failed.byte_length() > 0:
            failed += "; "
        failed += (
            "the best candidate's slowest counted round ("
            + String(b.summary.max_ns)
            + " ns) does not beat the runner-up's median ("
            + String(r.summary.median_ns)
            + " ns), so their rounds interleave"
        )
    if _is_default(b):
        record.decision_code = DEC_DEFAULT_CONFIRMED
        record.decision_text = (
            "the default itself was fastest ("
            + b.label
            + ", median "
            + String(b.summary.median_ns)
            + " ns vs runner-up "
            + r.label
            + " at "
            + String(r.summary.median_ns)
            + " ns) but the win is not claimed: "
            + failed
            + " -- the default is kept as the default"
        )
    else:
        record.decision_code = DEC_DEFAULT_BY_NOISE
        record.decision_text = (
            b.label
            + " was fastest (median "
            + String(b.summary.median_ns)
            + " ns vs runner-up "
            + r.label
            + " at "
            + String(r.summary.median_ns)
            + " ns) but did not clear the pre-registered rule: "
            + failed
            + " -- the session default is kept and the faster"
            " number is reported, not chosen"
        )
    return record^


# --- session keeping ---------------------------------------------------


struct DraftPlacementSession(Copyable, Movable):
    """The session holder: one draft-check choice per session,
    decided once and kept. decide_once refuses a second
    decision for the same session -- a running session's
    placement does not wobble with re-measurement; a new
    session (or J-045's re-trial road, when it exists) is the
    way to a new choice."""

    var decided: Bool
    var decisions_made: Int
    var record: DraftChoiceRecord

    def __init__(out self):
        self.decided = False
        self.decisions_made = 0
        self.record = DraftChoiceRecord()

    def decide_once(mut self, record: DraftChoiceRecord) raises:
        if self.decided:
            raise Error(
                "DraftPlacement: this session already holds a"
                " draft-check placement ("
                + self.record.chosen_label
                + "); a session decides once and keeps its choice"
                " -- a new session is required to re-decide"
                " (bounded re-trials are J-045)"
            )
        self.record = record.copy()
        self.decided = True
        self.decisions_made = 1

    def report(self) -> String:
        if not self.decided:
            return String(
                "draft-check placement: not decided for this session yet\n"
            )
        return self.record.report()


# --- the live builder ----------------------------------------------------


def _status_from_harness(status: Int) -> Int:
    if status == RES_MEASURED:
        return PM_MEASURED
    if status == RES_EXCLUDED:
        return PM_EXCLUDED
    if status == RES_BOUND_STOPPED:
        return PM_BOUND_STOPPED
    return PM_UNMEASURABLE


def _status_from_thread(status: Int) -> Int:
    if status == TRES_MEASURED:
        return PM_MEASURED
    if status == TRES_BOUND_STOPPED:
        return PM_BOUND_STOPPED
    return PM_UNMEASURABLE


def choose_draft_placement(
    options: PlacementOptions,
    inventory: DeviceInventory,
    facts: CpuFacts,
    config: HarnessConfig,
) raises -> DraftChoiceRecord:
    """The live entry point: enumerate both axes, then decide.

    Runs J-038's device sweep for the drafts kind (the field)
    and -- for auto/race options that allow the CPU -- J-039's
    thread trials for the drafts kind (the ladder), then
    applies decide_draft_choice. Today both axes return every
    candidate UNMEASURABLE-WITH-REASON (G1) and time nothing:
    the workload spec passed to both is the inert placeholder
    of the module header (the reply shape J-039's own trials
    test passes for this kind), never executed for this kind
    by either consumer. Manual single/co-work options skip the
    thread trials, exactly as in J-040/J-041: no ranking will
    happen, and the named candidate's device-axis record is
    the state that rides on the choice. The record's axes note
    states plainly that no timing stands on either axis --
    there is no cross-check for this kind, and none is
    dressed up as one."""
    var option = options.drafts.choice
    var manual = option.form == PLACE_SINGLE or option.form == PLACE_COWORK
    var spec = reply_workload()
    var sweep = run_placement_measurement(
        options, inventory, PASS_DRAFTS, spec, config
    )
    var candidates = enumerate_candidates(options, inventory, PASS_DRAFTS)
    var measurements = List[DraftMeasurement]()
    for i in range(len(sweep.results)):
        var result = sweep.results[i]
        var cand = candidates[i]
        var m = DraftMeasurement()
        m.label = result.label
        m.device = cand.first
        m.threads = 0
        m.status = _status_from_harness(result.status)
        m.reason = result.reason
        m.summary = result.summary
        measurements.append(m)
    if not manual and _option_allows(option, DEVICE_CPU):
        var trials = run_thread_trials(facts, PASS_DRAFTS, spec, config)
        for result in trials.results:
            var m = DraftMeasurement()
            m.label = (
                "cpu threads="
                + String(result.threads)
                + " ("
                + result.label
                + ")"
            )
            m.device = DEVICE_CPU
            m.threads = result.threads
            m.status = _status_from_thread(result.status)
            m.reason = result.reason
            m.summary = result.summary
            measurements.append(m)
    var record = decide_draft_choice(
        measurements, option, options.drafts.source, inventory.cpu.present
    )
    if manual:
        record.axes_note = String(
            "no timing stands for this kind: the device sweep"
            " measured nothing (the named candidate is"
            " unmeasurable-with-reason, G1); the thread trials"
            " were not run -- a manual option fixes the choice"
            " and no ranking follows -- and every rung would"
            " record unmeasurable-with-reason (G1) in any case;"
            " both axes become measurable only when Part V"
            " (J-071/J-072) provides a real draft-check"
            " verify-pass executor for the harness"
        )
    else:
        record.axes_note = String(
            "no timing stands for this kind on either axis: the"
            " device sweep measured nothing (every candidate"
            " unmeasurable-with-reason, G1) and the thread trials"
            " timed nothing (every rung unmeasurable-with-reason,"
            " G1) -- there is no cross-check and no ranked set"
            " today; both axes become measurable only when Part V"
            " (J-071/J-072) provides a real draft-check verify-pass"
            " executor for the harness"
        )
    return record^
