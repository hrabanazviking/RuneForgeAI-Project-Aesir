"""Auto choice for reply passes (Janas road J-041).

J-036 built the placement option surface (what a user asks for),
J-037 the device inventory (what the machine offers), J-038 the
measurement harness (bounded micro-runs per device candidate),
J-039 the thread topology trials (the thread-count ladder on
the CPU, measured through one threaded executor), and J-040 the
first chooser (the prompt kind). This module is the reply
kind's chooser, built to J-040's pattern and answering J-041's
own question: for the REPLY pass kind -- single-token decode,
width exactly 1 (J-035's taxonomy) -- how does the engine turn
measurements into one placement, keep it for the session, and
report what it chose and why?

WHY REPLY IS NOT PROMPT, stated from Aesir's own architecture
before any rule is fixed. A prompt pass is a batched prefill:
its placement cost is paid once per chunk of up to 256 tokens
(J-035), so per-launch and per-synchronisation costs amortise
across the batch. A reply pass is ONE token: every fixed cost
of a placement -- a device launch, a transfer, a thread-pool
wake-up -- is paid again for every single token the session
generates, and the user waits on each one. The work per pass
is also the smallest of the three kinds (a width-1
matrix-vector product, J-038's reply workload shape), so the
parallelisable fraction is smallest exactly where the fixed
costs recur most often. Two consequences, both recorded in
the rule below: the serial CPU default stands for reply on
existence grounds AND on shape grounds (J-040's default stood
on existence alone), and no hurdle is LOWERED for reply -- a
chooser that made it easier to leave the serial default for
the kind where leaving costs the most per token would have
the incentives exactly backwards.

THE INTEGRATED-GPU QUESTION, answered honestly. The roadmap
asks whether single tokens should go to the GPU. On today's
tree the answer cannot be a measurement, because there is
nothing to measure with: J-038's harness has NO GPU workload
executor (its only executor is the CPU one), so a present GPU
single candidate records UNMEASURABLE-WITH-REASON and an
absent one EXCLUDED with the inventory's own verbatim reason.
This module therefore EXCLUDES GPU (and, where it appears in
the auto field, NPU) candidates from ranking with those
reasons on the record -- NOT PROVEN, never faked, and never
ranked from a different executor's numbers (J-039 section 6's
comparability law: medians from different executors are not
one ranking). A GPU reply candidate enters the rankable set
only when a measured GPU reply executor exists AND its
medians clear the same hurdles as every other candidate;
nothing in this module pre-judges that future measurement in
either direction. The NPU never takes a reply pass at all in
Aesir's option grammar (J-036: an explicit reply option
naming the NPU is refused at parse, whole); in the auto field
the harness still enumerates it and the inventory excludes it
(parked ledger, Hailo stays parked) -- both records ride on
every live record, verbatim.

THE COMPARED SET, stated before any number. As in J-040, two
measurement axes exist and they are not interchangeable:

- the DEVICE axis (J-038's sweep for the reply kind): which
  devices the resolved reply option names, filtered through
  inventory truth. Its only executor is the serial CPU one;
  GPU/NPU singles and co-work record as above. These records
  are the field and the exclusions of the choice -- they carry
  no rankable timing for any device except the CPU cross-check
  below.
- the THREAD axis (J-039's trials for the reply kind): the
  CPU ladder rungs, all measured through ONE threaded executor
  on the reply-shaped workload, so their medians are
  comparable WITHIN the sweep. This is the rankable set.

The J-038 device sweep's own CPU median is recorded on the
choice record as a cross-check and is NEVER ranked: its serial
executor differs from the threaded executor (J-039 section 6).

THE DECISION RULE, pre-registered (stated here and in
docs/janas/J041_AUTO_REPLY_PLACEMENT.md section 3 before any
J-041 live number was measured; decide_reply_choice is its
pure form, unit-tested on injected measurements). The rule is
J-040's rule, ADOPTED UNCHANGED in its numbers, with the
reasons for not changing it stated in the doc: one rule across
kinds keeps choices comparable and keeps the learned file
(J-044) one shape; J-039's reply sweeps flipped verdicts
beyond a 5% band exactly as its prompt sweeps did, so the
same 10% margin evidence applies; and the separation hurdle
already encodes the reply-specific caution (a winner whose
rounds interleave the runner-up's is not a per-token latency
any session should be switched to). The rule:

- The session DEFAULT is cpu at 1 thread (serial). It exists
  wherever the inventory states a CPU present, needs no
  co-scheduling and no topology assumption, and for reply it
  is also the shape the pass itself favours (header above);
  it is the fallback every non-win lands on.
- MANUAL forms first: a single-device or co-work reply option
  FIXES the choice. The chooser never ranks against it and
  never substitutes a faster measured candidate (manual
  supremacy is J-047's slice; this slice's duty is the
  weaker, binding one: auto never overrides an explicit
  non-auto option). The named candidate's own measured state
  (measured / excluded / unmeasurable, with its reason) rides
  on the record, so a manual choice that cannot execute today
  is reported as exactly that; open-time refusal of a hand
  placement remains J-047's work, as J-038 recorded.
- AUTO and RACE rank the measured set (a race ranks only its
  named members). With zero measured candidates: the default
  is chosen as NO-MEASURED-FALLBACK when the CPU is present,
  with every exclusion's reason on the record; when the CPU
  itself is absent the record is a REFUSAL -- no choice,
  reasons stated. A chooser that invents a placement on an
  empty field would be fabricating.
- With exactly one measured candidate it is chosen as
  SOLE-MEASURED: last candidate standing, not a victory --
  no margin exists and none is claimed.
- With two or more, let BEST be the lowest median and RUNNER
  the second lowest. BEST is a MEASURED WIN only when BOTH
  hurdles clear: (a) the relative margin
  (runner_median - best_median) exceeds 10% of best_median
  (the margin band, adopted from J-040 for the reasons
  above); and (b) separation: best's slowest counted round
  (its max) is still below runner's median, so the two
  candidates' rounds do not interleave. If either hurdle
  fails, the DEFAULT is kept: DEFAULT-BY-NOISE when a
  non-default candidate was fastest but did not clear the
  rule, DEFAULT-CONFIRMED when the default itself was
  fastest but the win is not claimed. The choice is the same
  CPU the session would have run anyway; what the rule
  withholds is the claim, and the record states which hurdle
  failed, with the numbers.
- Bound-stopped candidates (partial rounds under a time
  bound) are recorded with the rounds that stand and are
  NEVER ranked: a partial sweep is not a measurement of the
  candidate.

STABILITY, stated on every record: a choice rests on ONE
sweep. J-039's central finding is that per-kind verdicts flip
between sweeps under contention -- its reply sweeps flipped
exactly as its prompt sweeps did -- so no record from this
module claims the choice is stable, and the session keeping
below exists precisely so a wobbling measurement cannot
re-decide a running session token by token (for reply that
failure mode would tax every generated token). Re-trials
are J-045; the learned file is J-044; neither is built here.

SESSION KEEPING. ReplyPlacementSession decides ONCE:
decide_once stores the first record and refuses a second
decision for the same session (a new session is the road to
a new choice; the refusal names J-045). The report is a
stable rendering of the stored record -- two reports of one
session are byte-identical, which is what makes it testable
and what a CLI/server surface can print verbatim later.

HOST CONTRACT: choose_reply_placement(options, inventory,
facts, config) is the live entry point -- a pure function of
the resolved J-036 options, the J-037 inventory, the J-037
CPU facts, and the J-038 harness config. A surface calls it
at model open, stores the record in a ReplyPlacementSession,
and prints session.report() beside the placement and device
reports. This slice wires it into NO live session path: no
session consumes a reply placement yet (the reply passes
still run where their surfaces have always run them), and
claiming otherwise would fake the integration. Draft-check
choice is J-042, co-work execution J-043. See
docs/janas/J041_AUTO_REPLY_PLACEMENT.md.
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
    PASS_REPLY,
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

# Decision codes (ReplyChoiceRecord.decision_code).
comptime DEC_MEASURED_WIN = 0
comptime DEC_DEFAULT_CONFIRMED = 1
comptime DEC_DEFAULT_BY_NOISE = 2
comptime DEC_SOLE_MEASURED = 3
comptime DEC_NO_MEASURED_FALLBACK = 4
comptime DEC_MANUAL_FIXED = 5
comptime DEC_REFUSAL = 6

# The pre-registered margin band, in percent of the best
# median (module header: wider than J-039's 5% thread band,
# because J-039's verdicts flipped between sweeps even beyond
# 5% under contention).
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


struct ReplyMeasurement(Copyable, ImplicitlyCopyable):
    """One candidate as the chooser records it: a thread rung of
    the CPU (device cpu, threads >= 1, from J-039's trials) or a
    device candidate (threads == 0, from J-038's sweep), with
    its status, its reason when it did not measure, and its
    timing summary when it did."""

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


def _is_default(m: ReplyMeasurement) -> Bool:
    return m.device == DEVICE_CPU and m.threads == DEFAULT_THREADS


def _option_allows(option: PlacementChoice, device: Int) -> Bool:
    """Whether a ranked candidate's device is in the option's
    field: auto allows the whole field; a race allows only its
    named members. (Single/co-work never reach ranking.)"""
    if option.form == PLACE_RACE:
        return option.names_device(device)
    return True


struct ReplyChoiceRecord(Copyable, Movable):
    """The session-scoped choice record: what was chosen, the
    decision that produced it with the numbers behind it, the
    whole measured field, and every exclusion with its reason.
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
    var measurements: List[ReplyMeasurement]
    var device_sweep_note: String

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
        self.measurements = List[ReplyMeasurement]()
        self.device_sweep_note = String("")

    def report(self) -> String:
        var out_str = String("reply placement report\n")
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
            "rule: pre-registered (J-041, adopting J-040 unchanged): a measured winner must"
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
        if self.device_sweep_note.byte_length() > 0:
            out_str += "device sweep: " + self.device_sweep_note + "\n"
        out_str += (
            "session: this choice is kept for the session; it is"
            " decided once and is not re-decided per token"
            " (re-trials are J-045)\n"
        )
        out_str += (
            "stability: this choice rests on a single sweep;"
            " choice stability under contention is NOT PROVEN"
            " (J-039: per-kind verdicts flipped between sweeps"
            " on this class of machine) -- the record states"
            " what this sweep measured, nothing more\n"
        )
        return out_str


def _fill_default_choice(mut record: ReplyChoiceRecord):
    record.has_choice = True
    record.chosen_label = default_label()
    record.chosen_device = DEVICE_CPU
    record.chosen_threads = DEFAULT_THREADS


def decide_reply_choice(
    measurements: List[ReplyMeasurement],
    option: PlacementChoice,
    option_source: Int,
    default_available: Bool,
) -> ReplyChoiceRecord:
    """The pre-registered decision rule (module header), as a
    pure function of injected measurements. The live entry point
    builds the measurements from J-038's sweep and J-039's
    trials; the tests inject synthetic sets. default_available
    states whether the inventory holds the default's device
    (the CPU) present -- the fact the no-measured branch and
    the refusal stand on."""
    var record = ReplyChoiceRecord()
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
            "the explicit reply option '"
            + option.describe()
            + "' fixes this choice; the auto rule was not applied"
            " and no measured candidate was substituted ("
            + state
            + "; a device option does not fix a thread count, so"
            " the thread axis stands where the session leaves it;"
            " open-time refusal of a hand placement is J-047)"
        )
        return record^

    # Ranked set: measured, option-allowed, full rounds only.
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
                " excluded, unmeasurable, or bound-stopped, with"
                " its reason on this record); the session default"
                " is kept because the inventory states the cpu"
                " present -- a fallback, not a measurement result"
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


struct ReplyPlacementSession(Copyable, Movable):
    """The session holder: one reply choice per session,
    decided once and kept. decide_once refuses a second
    decision for the same session -- a running session's
    placement does not wobble with re-measurement; a new
    session (or J-045's re-trial road, when it exists) is the
    way to a new choice."""

    var decided: Bool
    var decisions_made: Int
    var record: ReplyChoiceRecord

    def __init__(out self):
        self.decided = False
        self.decisions_made = 0
        self.record = ReplyChoiceRecord()

    def decide_once(mut self, record: ReplyChoiceRecord) raises:
        if self.decided:
            raise Error(
                "ReplyPlacement: this session already holds a"
                " reply placement ("
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
                "reply placement: not decided for this session yet\n"
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


def choose_reply_placement(
    options: PlacementOptions,
    inventory: DeviceInventory,
    facts: CpuFacts,
    config: HarnessConfig,
) raises -> ReplyChoiceRecord:
    """The live entry point: measure, then decide.

    Runs J-038's device sweep for the reply kind (the field
    and its exclusions) and -- for auto/race options that allow
    the CPU -- J-039's thread trials for the reply kind (the
    rankable set), then applies decide_reply_choice. Manual
    single/co-work options skip the thread trials: no ranking
    will happen, and measuring rungs nobody may choose would
    spend the harness bounds for nothing. The device sweep's
    CPU result is carried as the record's cross-check note,
    never ranked (module header: different executor)."""
    var option = options.reply.choice
    var manual = option.form == PLACE_SINGLE or option.form == PLACE_COWORK
    var spec = reply_workload()
    var sweep = run_placement_measurement(
        options, inventory, PASS_REPLY, spec, config
    )
    var candidates = enumerate_candidates(options, inventory, PASS_REPLY)
    var measurements = List[ReplyMeasurement]()
    var note = String("")
    for i in range(len(sweep.results)):
        var result = sweep.results[i]
        var cand = candidates[i]
        if (
            not manual
            and cand.form != PLACE_COWORK
            and cand.first == DEVICE_CPU
            and result.status == RES_MEASURED
        ):
            note = (
                "cpu measured at median "
                + String(result.summary.median_ns)
                + " ns by the harness's serial executor -- a"
                " cross-check only, NOT ranked (the ranked CPU"
                " candidates are the thread rungs, measured"
                " through the threaded executor; the two"
                " executors' medians are not comparable, J-039)"
            )
            continue
        var m = ReplyMeasurement()
        m.label = result.label
        m.device = cand.first
        m.threads = 0
        m.status = _status_from_harness(result.status)
        m.reason = result.reason
        m.summary = result.summary
        measurements.append(m)
    if note.byte_length() == 0 and not manual:
        note = String(
            "no cpu device-sweep timing stands as a cross-check"
            " (the cpu candidate did not measure in the device"
            " sweep; its state is on this record)"
        )
    if not manual and _option_allows(option, DEVICE_CPU):
        var trials = run_thread_trials(facts, PASS_REPLY, spec, config)
        for result in trials.results:
            var m = ReplyMeasurement()
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
    var record = decide_reply_choice(
        measurements, option, options.reply.source, inventory.cpu.present
    )
    record.device_sweep_note = note
    return record^
