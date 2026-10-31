"""Co-work passes for the prompt kind (Janas road J-043).

J-036 built the placement option surface -- including the `a+b`
co-work form: exactly two distinct devices working one pass
together. J-037 built the device inventory, J-038 the placement
measurement harness (which records every co-work candidate
UNMEASURABLE-WITH-REASON: "no real split workload exists in the
tree, and a split timing faked by running one device twice
would be a fabricated number -- J-043 owns co-work execution"),
J-039 the CPU thread trials, and J-040 the prompt chooser,
whose pre-registered decision rule (a winner must beat the
runner-up by more than 10% of its own median AND pass round
separation) this slice inherits for split survival. This
module is J-043: the split planner, the join accounting, and
the survival rule that decides which splits may live as
options -- for the PROMPT pass kind only (the roadmap's
J-043 sentence; draft-check and reply co-work are not built
here and nothing here claims them).

THE SPLIT, in Aesir's own terms. A prompt pass is a batched
matrix product (J-038's prompt workload: rows x (k -> n),
`reps` products). A two-device split divides the batch BY
ROWS: side A computes rows [0, first_rows), side B rows
[first_rows, rows). Row division is the split that needs no
cross-device reduction inside the product: every output
element is computed whole by exactly one side, with the
serial path's fixed per-element reduction order, so a correct
split's output is bit-identical to the unsplit output. The
planner states, per candidate split, exactly:

- the split fraction (first_rows / rows, and its mirror
  candidates 1/4, 1/2, 3/4 of the batch);
- per-side work: rows_side * k * n * reps multiply-adds;
- what CROSSES, byte-exact (Float32 = 4 bytes): dispatch --
  each side receives its own input slice (rows_side * k * 4)
  and a full copy of the shared matrix (k * n * 4, replicated
  to both sides: the matrix is read by every row); return --
  each side returns its output rows (rows_side * n * 4). The
  JOIN gathers the two output blocks into the [rows x n]
  result in row order: join work is rows * n elements, join
  bytes are the full output (rows * n * 4), and the joined
  TIME of a split whose sides run concurrently is
  max(side_a, side_b) + join -- never the sum, and never a
  side's time with the join silently dropped. A split whose
  sides run SEQUENTIALLY joins at side_a + side_b + join;
  which form a timing is must be stated with the timing (the
  analogue below states it every time).

THE SURVIVAL RULE, pre-registered (stated here and in
docs/janas/J043_COWORK_PASSES.md before any J-043 live number
was measured; evaluate_split is its pure form, unit-tested on
injected measurement sets). A split SURVIVES as an option
only when its measured JOINED time beats BOTH single-device
parents under the J-040 margin+separation discipline,
applied against EACH parent separately:

- (a) Margin: (parent_median - split_median) exceeds 10% of
  the split's median; and
- (b) Separation: the split's slowest counted round (its
  max) is still below the parent's median.

A split that fails either hurdle against either parent is
MEASURED-AND-REJECTED: recorded with the numbers and the
failed hurdle per parent, and NEVER kept as an option -- a
split that beats one parent only, or beats both inside the
noise band, is a rejection, not a partial success. A split,
or a parent, that did not measure (excluded /
unmeasurable-with-reason / bound-stopped) produces no
survival verdict at all: the record carries that state --
an unmeasured split is not rejected on numbers it does not
have, and it is certainly not kept.

REFUSALS, before any measurement. The planner refuses:
the same device twice (J-036's grammar, re-stated at plan
time); any pair naming the NPU -- the NPU entry is the
parked Hailo ledger (J-037: parked by campaign law, never
probed, never run), and a parked device cannot take half a
prompt pass; a split with an empty side (first_rows 0 or
rows). Live classification then applies inventory truth:
a pair naming an absent device is EXCLUDED with the
inventory's own reason, and a pair whose non-CPU member is
present records UNMEASURABLE-WITH-REASON (below).

THE HONESTY CORE OF THIS SLICE. True two-DEVICE co-work is
UNMEASURABLE-WITH-REASON / NOT PROVEN on today's tree, and
this module fakes none of it. The placement harness's prompt
executors are the CPU ones only (J-038's serial executor and
J-039's threaded executor). There is no GPU prompt executor
in the harness -- the tree's CUDA session code is model
inference, not a harness executor a split could be timed
through, and on this VM the inventory states no GPU at all.
The NPU is parked by law and is refused, never probed. So
every true device pair classifies as refused (any NPU pair),
excluded (an absent member), or unmeasurable-with-reason
(a present member with no executor), the live device record
keeps ZERO survived options, and no GPU or NPU number
appears anywhere in this slice.

THE THREAD-PARTITION ANALOGUE -- the one split that CAN be
measured here, labelled exactly as what it is. The CPU's
thread ladder can be partitioned: a prompt batch divided by
rows across two thread partitions of the SAME cpu (for
example 2 + 2 threads of one 4-thread ladder), each partition
run as a sub-workload through J-039's threaded executor
(run_workload_threaded, its checksum asserted exactly
against the partition's serial reference), with the join
(a serial gather of the full output block into a joined
list, checksummed in the serial path's exact order and
asserted exactly against the whole workload's serial
checksum) timed as part of every round. The analogue is
built only from the tree's proven execution patterns --
an earlier draft's new FFI range callback intermittently
computed wrong elements in this toolchain and was
abandoned, never filed (the episode is recorded in the
doc, with the bisection evidence).
This module measures that analogue under the same settle +
rounds + median discipline, applies the same survival rule
against its two parents (single-partition runs of the whole
batch through the same executor at 1 thread and at the full
thread count, join included -- so parents and splits differ
only in partitioning), and records the verdict
whatever it is. Its limits are stated on every record: the
partitions run SEQUENTIALLY in this analogue (one par_for at
a time -- the joined time is side_a + side_b + join, the
conservative non-concurrent form), so the analogue measures
split + join ACCOUNTING and the survival rule's behaviour on
real timings; it is NOT device co-work, it proves nothing
about any GPU/NPU split, and an analogue survival would
create NO device option (and an analogue rejection creates
no device verdict either).

MANUAL SUPREMACY, untouched. An explicit co-work prompt
option names its pair and this module evaluates exactly that
pair -- it never substitutes another pair, a single device,
or the analogue. An explicit single or race option names no
co-work pair: the planner records that and evaluates nothing
(race members are measured singly by J-038/J-040, as before).
Open-time refusal of a hand placement remains J-047's work.

HOST CONTRACT: plan_cowork_prompt(options, inventory) is the
live planner entry point (pure classification + accounting,
no timing); run_thread_partition_analogue(facts, spec,
config) is the analogue measurement entry point. A surface
calls them at model open or on demand and prints the
records' report(). This slice wires them into NO live
session path: no session consumes a co-work placement yet,
and claiming otherwise would fake the integration. The
learned file is J-044, re-trials J-045, manual supremacy
J-047. See docs/janas/J043_COWORK_PASSES.md.
"""

from core.device_inventory import (
    DeviceInventory,
    CpuFacts,
    require_device_present,
)
from core.placement_harness import (
    HarnessConfig,
    TimingSummary,
    WORKLOAD_PROMPT,
    WorkloadData,
    WorkloadSpec,
    monotonic_ns,
    prepare_workload,
    prompt_workload,
    run_workload_once,
    summarize_timings,
)
from core.placement_options import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NPU,
    PLACE_AUTO,
    PLACE_COWORK,
    PLACE_RACE,
    PLACE_SINGLE,
    PlacementChoice,
    PlacementOptions,
    device_name,
    source_name,
)
from core.thread_topology import (
    clear_thread_knobs,
    run_workload_threaded,
    set_thread_knobs,
)

# Candidate / measure status (one pair or measure on a record).
comptime CW_MEASURED = 0
comptime CW_EXCLUDED = 1
comptime CW_UNMEASURABLE = 2
comptime CW_BOUND_STOPPED = 3
comptime CW_REFUSED = 4

# Survival verdicts (evaluate_split / the records).
comptime VERDICT_SURVIVES = 0
comptime VERDICT_REJECTED = 1
comptime VERDICT_UNMEASURABLE = 2
comptime VERDICT_EXCLUDED = 3
comptime VERDICT_REFUSED = 4
comptime VERDICT_BOUND_STOPPED = 5
comptime VERDICT_NOT_EVALUATED = 6

# The pre-registered margin band, in percent of the split's
# median (J-040's band, applied per parent; module header).
comptime MARGIN_PERCENT = 10

comptime FLOAT32_BYTES = 4


def verdict_name(code: Int) -> String:
    if code == VERDICT_SURVIVES:
        return String("SURVIVES")
    if code == VERDICT_REJECTED:
        return String("MEASURED-AND-REJECTED")
    if code == VERDICT_UNMEASURABLE:
        return String("UNMEASURABLE-WITH-REASON")
    if code == VERDICT_EXCLUDED:
        return String("EXCLUDED")
    if code == VERDICT_REFUSED:
        return String("REFUSED-PARKED")
    if code == VERDICT_BOUND_STOPPED:
        return String("BOUND-STOPPED-NOT-SURVIVABLE")
    return String("NOT-EVALUATED")


def status_name(code: Int) -> String:
    if code == CW_MEASURED:
        return String("MEASURED")
    if code == CW_EXCLUDED:
        return String("EXCLUDED")
    if code == CW_BOUND_STOPPED:
        return String("BOUND-STOPPED")
    if code == CW_REFUSED:
        return String("REFUSED")
    return String("UNMEASURABLE")


# --- the split plan (pure accounting) -----------------------------------


struct SplitPlan(Copyable, ImplicitlyCopyable):
    """One candidate split of one prompt batch: the pair, the
    row division, per-side work, and the join accounting --
    all exact integers derived from the workload shape, no
    timing anywhere. threads_first / threads_second are 0 for
    device plans; the thread-partition analogue fills them."""

    var first_device: Int
    var second_device: Int
    var total_rows: Int
    var first_rows: Int
    var second_rows: Int
    var first_work: Int
    var second_work: Int
    var total_work: Int
    var input_bytes_first: Int
    var input_bytes_second: Int
    var matrix_bytes_each: Int
    var output_bytes_first: Int
    var output_bytes_second: Int
    var join_output_bytes: Int
    var join_elements: Int
    var crossing_bytes_total: Int
    var threads_first: Int
    var threads_second: Int

    def __init__(out self):
        self.first_device = DEVICE_CPU
        self.second_device = DEVICE_CPU
        self.total_rows = 0
        self.first_rows = 0
        self.second_rows = 0
        self.first_work = 0
        self.second_work = 0
        self.total_work = 0
        self.input_bytes_first = 0
        self.input_bytes_second = 0
        self.matrix_bytes_each = 0
        self.output_bytes_first = 0
        self.output_bytes_second = 0
        self.join_output_bytes = 0
        self.join_elements = 0
        self.crossing_bytes_total = 0
        self.threads_first = 0
        self.threads_second = 0

    def label(self) -> String:
        return (
            device_name(self.first_device)
            + "+"
            + device_name(self.second_device)
            + " rows "
            + String(self.first_rows)
            + "/"
            + String(self.second_rows)
            + " of "
            + String(self.total_rows)
        )

    def fraction_percent(self) -> Int:
        if self.total_rows <= 0:
            return 0
        return self.first_rows * 100 // self.total_rows

    def render(self) -> String:
        var out_str = (
            self.label()
            + " (first side "
            + String(self.fraction_percent())
            + "% of the batch): work "
            + String(self.first_work)
            + " + "
            + String(self.second_work)
            + " = "
            + String(self.total_work)
            + " multiply-adds; crossing: input slices "
            + String(self.input_bytes_first)
            + " + "
            + String(self.input_bytes_second)
            + " B, matrix replicated to both sides at "
            + String(self.matrix_bytes_each)
            + " B each, output returns "
            + String(self.output_bytes_first)
            + " + "
            + String(self.output_bytes_second)
            + " B -- "
            + String(self.crossing_bytes_total)
            + " B total; join: gather "
            + String(self.join_elements)
            + " output elements ("
            + String(self.join_output_bytes)
            + " B) in row order"
        )
        if self.threads_first > 0:
            out_str += (
                "; thread-partition analogue threads "
                + String(self.threads_first)
                + " + "
                + String(self.threads_second)
            )
        return out_str


def plan_split_accounting(
    spec: WorkloadSpec, first_rows: Int
) raises -> SplitPlan:
    """The accounting for one row split of one prompt batch.
    Refuses an empty side: a split in which one device does
    no rows is a single-device pass wearing a plus sign."""
    if first_rows <= 0 or first_rows >= spec.rows:
        raise Error(
            "Cowork: a split of "
            + String(spec.rows)
            + " rows at "
            + String(first_rows)
            + " leaves a side empty; both sides must do rows"
            + " (a one-sided split is a single-device pass)"
        )
    var plan = SplitPlan()
    plan.total_rows = spec.rows
    plan.first_rows = first_rows
    plan.second_rows = spec.rows - first_rows
    plan.first_work = plan.first_rows * spec.k * spec.n * spec.reps
    plan.second_work = plan.second_rows * spec.k * spec.n * spec.reps
    plan.total_work = plan.first_work + plan.second_work
    plan.input_bytes_first = plan.first_rows * spec.k * FLOAT32_BYTES
    plan.input_bytes_second = plan.second_rows * spec.k * FLOAT32_BYTES
    plan.matrix_bytes_each = spec.k * spec.n * FLOAT32_BYTES
    plan.output_bytes_first = plan.first_rows * spec.n * FLOAT32_BYTES
    plan.output_bytes_second = plan.second_rows * spec.n * FLOAT32_BYTES
    plan.join_output_bytes = spec.rows * spec.n * FLOAT32_BYTES
    plan.join_elements = spec.rows * spec.n
    plan.crossing_bytes_total = (
        plan.input_bytes_first
        + plan.input_bytes_second
        + 2 * plan.matrix_bytes_each
        + plan.join_output_bytes
    )
    return plan


def validate_device_pair(first: Int, second: Int) raises:
    """Plan-time refusals for a device pair, before inventory
    or timing: two DISTINCT devices (J-036's grammar), and
    never the NPU -- its entry is the parked Hailo ledger
    (J-037), and a parked device cannot take half a pass."""
    if first == second:
        raise Error(
            "Cowork: co-work '"
            + device_name(first)
            + "+"
            + device_name(second)
            + "' names "
            + device_name(first)
            + " twice; co-work needs two distinct devices"
        )
    if first == DEVICE_NPU or second == DEVICE_NPU:
        raise Error(
            "Cowork: a co-work pair naming the npu is refused:"
            + " the npu entry is the parked Hailo ledger (J-037"
            + " -- parked by Aesir's campaign law, never probed,"
            + " never run), and a parked device cannot take half"
            + " of a prompt pass"
        )


def plan_device_split(
    spec: WorkloadSpec, first: Int, second: Int, first_rows: Int
) raises -> SplitPlan:
    """One device split plan: pair refusals first, then the
    accounting. Inventory truth is NOT applied here (a plan is
    arithmetic); classify_pair applies it, live."""
    validate_device_pair(first, second)
    var plan = plan_split_accounting(spec, first_rows)
    plan.first_device = first
    plan.second_device = second
    return plan


def candidate_split_plans(
    spec: WorkloadSpec, first: Int, second: Int
) raises -> List[SplitPlan]:
    """The candidate fractions for one pair, stated once:
    1/4, 1/2, and 3/4 of the batch to the first side,
    de-duplicated by row count (a 2-row batch has one split).
    Asymmetric fractions exist because the two sides are not
    equally fast in general -- which fraction wins, if any,
    is the survival rule's question, not the planner's."""
    var plans = List[SplitPlan]()
    var fractions = List[Tuple[Int, Int]]()
    fractions.append((1, 4))
    fractions.append((1, 2))
    fractions.append((3, 4))
    for frac in fractions:
        var first_rows = spec.rows * frac[0] // frac[1]
        if first_rows <= 0 or first_rows >= spec.rows:
            continue
        var seen = False
        for existing in plans:
            if existing.first_rows == first_rows:
                seen = True
                break
        if seen:
            continue
        plans.append(plan_device_split(spec, first, second, first_rows))
    if len(plans) == 0:
        raise Error(
            "Cowork: a batch of "
            + String(spec.rows)
            + " rows has no two-sided split"
        )
    return plans^


def joined_time_ns(side_a_ns: Int, side_b_ns: Int, join_ns: Int, concurrent: Bool) -> Int:
    """The joined time of one split round. Concurrent sides:
    the slower side plus the join. Sequential sides: both
    sides plus the join. The join is in BOTH forms -- a split
    timing without its join is not a split timing."""
    if concurrent:
        var slower = side_a_ns if side_a_ns > side_b_ns else side_b_ns
        return slower + join_ns
    return side_a_ns + side_b_ns + join_ns


def allocate_partition_threads(total_threads: Int, plan: SplitPlan) -> Tuple[Int, Int]:
    """Thread allocation for the analogue: the ladder's total
    split in proportion to the rows, at least one thread per
    partition, summing exactly to the total."""
    if total_threads < 2:
        return (0, 0)
    var first = total_threads * plan.first_rows // plan.total_rows
    if first < 1:
        first = 1
    if first > total_threads - 1:
        first = total_threads - 1
    return (first, total_threads - first)


# --- the survival rule (pure) --------------------------------------------


struct SplitMeasure(Copyable, ImplicitlyCopyable):
    """One timing-bearing (or state-bearing) record the
    survival rule consumes: a split's joined summary, or one
    single-device / single-partition parent's summary."""

    var label: String
    var device: Int
    var threads: Int
    var status: Int
    var reason: String
    var summary: TimingSummary
    var join_summary: TimingSummary

    def __init__(out self):
        self.label = String("")
        self.device = DEVICE_CPU
        self.threads = 0
        self.status = CW_UNMEASURABLE
        self.reason = String("")
        self.summary = TimingSummary()
        self.join_summary = TimingSummary()


struct SurvivalRecord(Copyable, ImplicitlyCopyable):
    """The survival rule's outcome for one split against its
    two parents: the verdict, the per-parent margins and
    separation outcomes, and the sentence that states which
    hurdle failed where -- a rejection carries its numbers."""

    var split_label: String
    var verdict_code: Int
    var verdict_text: String
    var parent_a_label: String
    var parent_b_label: String
    var margin_a_percent: Int
    var margin_b_percent: Int
    var separation_a_ok: Bool
    var separation_b_ok: Bool

    def __init__(out self):
        self.split_label = String("")
        self.verdict_code = VERDICT_NOT_EVALUATED
        self.verdict_text = String("not evaluated")
        self.parent_a_label = String("")
        self.parent_b_label = String("")
        self.margin_a_percent = -1
        self.margin_b_percent = -1
        self.separation_a_ok = False
        self.separation_b_ok = False

    def render(self) -> String:
        var out_str = (
            "survival: "
            + verdict_name(self.verdict_code)
            + " -- "
            + self.verdict_text
        )
        if self.margin_a_percent >= 0:
            out_str += (
                " [vs "
                + self.parent_a_label
                + ": margin "
                + String(self.margin_a_percent)
                + "%, separation "
                + (String("ok") if self.separation_a_ok else String("failed"))
                + "; vs "
                + self.parent_b_label
                + ": margin "
                + String(self.margin_b_percent)
                + "%, separation "
                + (String("ok") if self.separation_b_ok else String("failed"))
                + "]"
            )
        return out_str


def _state_verdict(m: SplitMeasure) -> Int:
    """The verdict an unmeasured input forces: its own state,
    never a numeric rejection and never a survival."""
    if m.status == CW_EXCLUDED:
        return VERDICT_EXCLUDED
    if m.status == CW_REFUSED:
        return VERDICT_REFUSED
    if m.status == CW_BOUND_STOPPED:
        return VERDICT_BOUND_STOPPED
    return VERDICT_UNMEASURABLE


def _state_sentence(split: SplitMeasure, parent_a: SplitMeasure, parent_b: SplitMeasure) -> String:
    var candidates = List[SplitMeasure]()
    candidates.append(split)
    candidates.append(parent_a)
    candidates.append(parent_b)
    for m in candidates:
        if m.status != CW_MEASURED:
            return (
                m.label
                + " did not measure ("
                + status_name(m.status)
                + " -- "
                + m.reason
                + "); no survival verdict is computed and the"
                + " split is not kept -- an unmeasured split is"
                + " neither a survival nor a numeric rejection"
            )
    return String("")


def evaluate_split(
    split: SplitMeasure, parent_a: SplitMeasure, parent_b: SplitMeasure
) -> SurvivalRecord:
    """The pre-registered survival rule (module header), as a
    pure function: the split survives only when its joined
    median beats BOTH parents by more than the margin band
    AND its slowest counted round beats each parent's median.
    Any unmeasured input forces the state verdict instead."""
    var record = SurvivalRecord()
    record.split_label = split.label
    record.parent_a_label = parent_a.label
    record.parent_b_label = parent_b.label
    if (
        split.status != CW_MEASURED
        or parent_a.status != CW_MEASURED
        or parent_b.status != CW_MEASURED
    ):
        var worst = split
        if split.status == CW_MEASURED and parent_a.status != CW_MEASURED:
            worst = parent_a
        elif split.status == CW_MEASURED and parent_b.status != CW_MEASURED:
            worst = parent_b
        record.verdict_code = _state_verdict(worst)
        record.verdict_text = _state_sentence(split, parent_a, parent_b)
        return record
    var s = split.summary
    var gap_a = parent_a.summary.median_ns - s.median_ns
    var gap_b = parent_b.summary.median_ns - s.median_ns
    record.margin_a_percent = gap_a * 100 // s.median_ns
    record.margin_b_percent = gap_b * 100 // s.median_ns
    var margin_a_ok = gap_a * 100 > MARGIN_PERCENT * s.median_ns
    var margin_b_ok = gap_b * 100 > MARGIN_PERCENT * s.median_ns
    record.separation_a_ok = s.max_ns < parent_a.summary.median_ns
    record.separation_b_ok = s.max_ns < parent_b.summary.median_ns
    if margin_a_ok and margin_b_ok and record.separation_a_ok and record.separation_b_ok:
        record.verdict_code = VERDICT_SURVIVES
        record.verdict_text = (
            split.label
            + " joined median "
            + String(s.median_ns)
            + " ns beats both parents ("
            + parent_a.label
            + " "
            + String(parent_a.summary.median_ns)
            + " ns by "
            + String(record.margin_a_percent)
            + "%; "
            + parent_b.label
            + " "
            + String(parent_b.summary.median_ns)
            + " ns by "
            + String(record.margin_b_percent)
            + "%), beyond the "
            + String(MARGIN_PERCENT)
            + "% band against each, and its slowest counted"
            + " round ("
            + String(s.max_ns)
            + " ns) beats each parent's median -- it survives"
            + " as an option under the pre-registered rule"
        )
        return record
    record.verdict_code = VERDICT_REJECTED
    var failed = String("")
    if not margin_a_ok:
        failed += (
            "vs "
            + parent_a.label
            + " the margin is "
            + String(record.margin_a_percent)
            + "% (inside the "
            + String(MARGIN_PERCENT)
            + "% band or negative -- the split does not beat"
            + " this parent by the rule)"
        )
    if not record.separation_a_ok:
        if failed.byte_length() > 0:
            failed += "; "
        failed += (
            "vs "
            + parent_a.label
            + " the split's slowest counted round ("
            + String(s.max_ns)
            + " ns) does not beat the parent's median ("
            + String(parent_a.summary.median_ns)
            + " ns), so their rounds interleave"
        )
    if not margin_b_ok:
        if failed.byte_length() > 0:
            failed += "; "
        failed += (
            "vs "
            + parent_b.label
            + " the margin is "
            + String(record.margin_b_percent)
            + "% (inside the "
            + String(MARGIN_PERCENT)
            + "% band or negative -- the split does not beat"
            + " this parent by the rule)"
        )
    if not record.separation_b_ok:
        if failed.byte_length() > 0:
            failed += "; "
        failed += (
            "vs "
            + parent_b.label
            + " the split's slowest counted round ("
            + String(s.max_ns)
            + " ns) does not beat the parent's median ("
            + String(parent_b.summary.median_ns)
            + " ns), so their rounds interleave"
        )
    record.verdict_text = (
        split.label
        + " joined median "
        + String(s.median_ns)
        + " ns does not beat BOTH parents under the"
        + " pre-registered rule: "
        + failed
        + " -- measured-and-rejected; it is recorded with its"
        + " numbers and is NOT kept as an option"
    )
    return record


# --- live pair classification ---------------------------------------------


def classify_pair(
    inventory: DeviceInventory, first: Int, second: Int
) -> Tuple[Int, String]:
    """Classify one distinct device pair against inventory
    truth and this tree's executor facts, in a fixed order:
    the NPU refusal first (parked by law -- the strongest
    true reason), then inventory truth per named device
    (the inventory entry's own reason, verbatim), then the
    harness executor fact. Returns (status, reason)."""
    if first == DEVICE_NPU or second == DEVICE_NPU:
        return (
            CW_REFUSED,
            String(
                "a co-work pair naming the npu is refused: the"
                + " npu entry is the parked Hailo ledger (J-037"
                + " -- parked by Aesir's campaign law, never"
                + " probed, never run), and a parked device"
                + " cannot take half of a prompt pass"
            ),
        )
    var pair_codes = List[Int]()
    pair_codes.append(first)
    pair_codes.append(second)
    for code in pair_codes:
        try:
            require_device_present(inventory, device_name(code))
        except refusal:
            return (CW_EXCLUDED, String(refusal))
    for code in pair_codes:
        if code != DEVICE_CPU:
            return (
                CW_UNMEASURABLE,
                String(
                    "no "
                    + device_name(code)
                    + " prompt workload executor exists in the"
                    + " placement harness yet (J-038: the CPU"
                    + " serial and threaded executors are the only"
                    + " ones built; device executors ride with"
                    + " device pass execution, Part IV) -- the"
                    + " device is present, the split measurement"
                    + " is not claimed"
                ),
            )
    return (
        CW_UNMEASURABLE,
        String(
            "cpu+cpu is not a device pair (the planner refuses"
            + " the same device twice); the cpu thread-partition"
            + " analogue is the measurable cpu split, labelled"
            + " as an analogue and never as device co-work"
        ),
    )


# --- the live planner record ------------------------------------------------


struct CoworkPairRecord(Copyable, Movable):
    """One pair's planner outcome: its candidate split plans
    (accounting, exact), its classification, and the survival
    verdict that classification forces (no timing exists for
    any true device pair today, so no pair can survive)."""

    var first_device: Int
    var second_device: Int
    var status: Int
    var reason: String
    var plans: List[SplitPlan]
    var verdict: SurvivalRecord

    def __init__(out self):
        self.first_device = DEVICE_CPU
        self.second_device = DEVICE_GPU
        self.status = CW_UNMEASURABLE
        self.reason = String("")
        self.plans = List[SplitPlan]()
        self.verdict = SurvivalRecord()

    def label(self) -> String:
        return device_name(self.first_device) + "+" + device_name(self.second_device)


struct CoworkRecord(Copyable, Movable):
    """The planner's record for one resolved prompt option:
    every pair it names (an explicit pair, or the auto field's
    three pairs), each with its plans and verdict, plus the
    outcome line. Manual single/race options name no pair:
    pairs is empty and the outcome states that, untouched."""

    var option_text: String
    var option_form: Int
    var option_source: Int
    var pairs: List[CoworkPairRecord]
    var outcome_text: String

    def __init__(out self):
        self.option_text = String("auto")
        self.option_form = PLACE_AUTO
        self.option_source = 0
        self.pairs = List[CoworkPairRecord]()
        self.outcome_text = String("not planned")

    def survived_count(self) -> Int:
        var total = 0
        for pair in self.pairs:
            if pair.verdict.verdict_code == VERDICT_SURVIVES:
                total += 1
        return total

    def report(self) -> String:
        var out_str = String("prompt co-work report\n")
        out_str += (
            "option: "
            + self.option_text
            + " (source "
            + source_name(self.option_source)
            + ")\n"
        )
        out_str += (
            "rule: pre-registered (J-043, inheriting J-040): a"
            + " split survives as an option only when its measured"
            + " joined time (slower side + join, concurrent form)"
            + " beats BOTH single-device parents -- margin more"
            + " than "
            + String(MARGIN_PERCENT)
            + "% of the split's median AND the split's slowest"
            + " counted round below the parent's median, against"
            + " each parent separately. A split that fails either"
            + " hurdle against either parent is"
            + " measured-and-rejected and is never kept.\n"
        )
        out_str += "outcome: " + self.outcome_text + "\n"
        for pair in self.pairs:
            out_str += (
                "pair "
                + pair.label()
                + ": "
                + status_name(pair.status)
                + " -- "
                + pair.reason
                + "\n"
            )
            for plan in pair.plans:
                out_str += "  split " + plan.render() + "\n"
            out_str += "  " + pair.verdict.render() + "\n"
        out_str += (
            "honesty: true two-device co-work is NOT PROVEN on"
            + " this tree today -- the harness has CPU prompt"
            + " executors only, no GPU prompt executor exists,"
            + " and the NPU is parked and refused; no GPU/NPU"
            + " timing is stated anywhere in this record. The"
            + " cpu thread-partition analogue is measured"
            + " separately and labelled an analogue; it is not"
            + " device co-work and creates no device option.\n"
        )
        return out_str


def _pair_record(
    spec: WorkloadSpec,
    inventory: DeviceInventory,
    first: Int,
    second: Int,
) raises -> CoworkPairRecord:
    var pair = CoworkPairRecord()
    pair.first_device = first
    pair.second_device = second
    var classified = classify_pair(inventory, first, second)
    pair.status = classified[0]
    pair.reason = classified[1]
    # The pair's candidate plans are ACCOUNTING, built from
    # the pure accounting function -- not through
    # plan_device_split, whose plan-time refusals would raise
    # here and erase exactly the refused/excluded pairs this
    # record exists to carry (the refusals themselves are
    # classify_pair's and validate_device_pair's, both on the
    # record / in the planner's contract).
    var fractions = List[Tuple[Int, Int]]()
    fractions.append((1, 4))
    fractions.append((1, 2))
    fractions.append((3, 4))
    for frac in fractions:
        var first_rows = spec.rows * frac[0] // frac[1]
        if first_rows <= 0 or first_rows >= spec.rows:
            continue
        var seen = False
        for existing in pair.plans:
            if existing.first_rows == first_rows:
                seen = True
                break
        if seen:
            continue
        var plan = plan_split_accounting(spec, first_rows)
        plan.first_device = first
        plan.second_device = second
        pair.plans.append(plan)
    var split = SplitMeasure()
    split.label = pair.label()
    split.device = first
    split.status = pair.status
    split.reason = pair.reason
    var parent_a = SplitMeasure()
    parent_a.label = device_name(first)
    parent_a.device = first
    parent_a.status = pair.status
    parent_a.reason = pair.reason
    var parent_b = SplitMeasure()
    parent_b.label = device_name(second)
    parent_b.device = second
    parent_b.status = pair.status
    parent_b.reason = pair.reason
    pair.verdict = evaluate_split(split, parent_a, parent_b)
    return pair^


def plan_cowork_prompt(
    options: PlacementOptions, inventory: DeviceInventory
) raises -> CoworkRecord:
    """The live planner entry point: accounting + classification
    for the pairs the resolved PROMPT option names, then the
    survival rule's state verdicts. No timing is run here --
    no device pair on today's tree can be timed (module
    header), and the analogue's timings live in their own
    record, never merged into a device pair's verdict.

    An explicit co-work option is evaluated as written and
    never substituted (manual supremacy). Auto evaluates the
    field's three distinct pairs. Single and race options
    name no co-work pair and are recorded untouched."""
    var option = options.prompt.choice
    var record = CoworkRecord()
    record.option_text = option.describe()
    record.option_form = option.form
    record.option_source = options.prompt.source
    var spec = prompt_workload()
    if option.form == PLACE_COWORK:
        record.pairs.append(
            _pair_record(spec, inventory, option.first, option.second)
        )
        record.outcome_text = String(
            "the explicit co-work pair was evaluated as written"
            + " and never substituted; it does not survive (its"
            + " state is on the pair record) -- no co-work option"
            + " is kept from this record"
        )
        return record^
    if option.form == PLACE_AUTO:
        var field = List[Tuple[Int, Int]]()
        field.append((DEVICE_CPU, DEVICE_GPU))
        field.append((DEVICE_CPU, DEVICE_NPU))
        field.append((DEVICE_GPU, DEVICE_NPU))
        for pair_codes in field:
            record.pairs.append(
                _pair_record(spec, inventory, pair_codes[0], pair_codes[1])
            )
        record.outcome_text = String(
            "no auto co-work pair survives: every pair is"
            + " refused, excluded, or unmeasurable-with-reason"
            + " on this machine and tree (reasons on the pair"
            + " records) -- zero co-work options are kept; the"
            + " prompt chooser's single-device and thread-rung"
            + " choices (J-040) stand exactly as they were"
        )
        return record^
    record.outcome_text = (
        "the prompt option '"
        + option.describe()
        + "' names no co-work pair ("
        + (
            String("a single device -- manual supremacy: it"
                   + " stands untouched and no split is evaluated")
            if option.form == PLACE_SINGLE
            else String("a race -- its members are measured"
                        + " singly (J-038/J-040); a race is not a"
                        + " split and no split is evaluated")
        )
        + ")"
    )
    return record^


# --- the thread-partition analogue -------------------------------------------


# --- the thread-partition analogue -------------------------------------------
#
# EXECUTION SHAPE, load-bearing (recorded in full in
# docs/janas/J043_COWORK_PASSES.md): the analogue is built
# ONLY from the tree's proven execution patterns -- J-039's
# run_workload_threaded for partition execution (its own
# self-contained ctx/FFI shape, checksum-verified in every
# J-039--J-042 suite), J-038's List-indexed serial arithmetic
# for reference outputs, and List gathers for the join. An
# earlier draft of this slice defined a NEW FFI range
# callback with a row-range ctx and raw-pointer loads; its
# split rounds intermittently computed wrong elements
# (deterministically wrong checksums, bisected to
# raw-pointer loads in the new code returning wrong values
# while List-indexed loads of the same addresses in the same
# process returned the right ones). The defect was caught by
# this module's own verification every time and no wrong
# timing was ever filed; the callback design was abandoned
# rather than shipped with an unexplained intermittent
# failure inside it.


struct AnalogueSplitResult(Copyable, Movable, ImplicitlyCopyable):
    """One analogue split's measurement: its plan, its joined
    summary (sequential form: partition A + partition B +
    join, per round), its join summary, and its survival
    verdict against the analogue's two parents."""

    var plan: SplitPlan
    var measure: SplitMeasure
    var verdict: SurvivalRecord

    def __init__(out self):
        self.plan = SplitPlan()
        self.measure = SplitMeasure()
        self.verdict = SurvivalRecord()


struct AnalogueRecord(Copyable, Movable):
    """The whole analogue run: the two parents (serial and
    widest single-partition cpu runs through J-039's threaded
    executor, join included), every candidate split's joined
    measurement and verdict, and the labelling lines. This
    record is an ANALOGUE record on its face; nothing in it
    is a device result."""

    var parent_serial: SplitMeasure
    var parent_threaded: SplitMeasure
    var splits: List[AnalogueSplitResult]
    var total_threads: Int

    def __init__(out self):
        self.parent_serial = SplitMeasure()
        self.parent_threaded = SplitMeasure()
        self.splits = List[AnalogueSplitResult]()
        self.total_threads = 0

    def report(self) -> String:
        var out_str = String(
            "THREAD-PARTITION ANALOGUE (cpu partitions of one"
            + " cpu -- NOT device co-work)\n"
        )
        out_str += (
            "parents: "
            + self.parent_serial.label
            + " median "
            + String(self.parent_serial.summary.median_ns)
            + " ns; "
            + self.parent_threaded.label
            + " median "
            + String(self.parent_threaded.summary.median_ns)
            + " ns (single-partition runs through J-039's"
            + " threaded executor, join included)\n"
        )
        for result in self.splits:
            out_str += "split " + result.plan.render() + "\n"
            out_str += (
                "  joined (sequential form: partition A +"
                + " partition B + join): median "
                + String(result.measure.summary.median_ns)
                + " ns (min "
                + String(result.measure.summary.min_ns)
                + ", max "
                + String(result.measure.summary.max_ns)
                + ", spread "
                + String(result.measure.summary.spread_ns)
                + "; rounds "
                + String(result.measure.summary.count)
                + "); join alone: median "
                + String(result.measure.join_summary.median_ns)
                + " ns over "
                + String(result.measure.join_summary.count)
                + " rounds\n"
            )
            out_str += "  " + result.verdict.render() + "\n"
        out_str += (
            "analogue limits: the partitions ran sequentially"
            + " (one threaded run at a time; round wall"
            + " includes the thread-knob switches), so these"
            + " joined times are the conservative"
            + " non-concurrent form; the analogue proves split"
            + " + join accounting and the survival rule on real"
            + " timings ONLY -- it is not device co-work, states"
            + " nothing about any gpu/npu split, and no verdict"
            + " here creates or removes a device option\n"
        )
        return out_str


def _sub_workload(
    data: WorkloadData, spec: WorkloadSpec, row_lo: Int, row_count: Int
) raises -> Tuple[WorkloadData, WorkloadSpec, Float32]:
    """One partition's sub-workload: the shared matrix copied
    whole (every row reads it), the partition's own input
    slice copied, and the sub-spec (same k/n/reps, the
    partition's rows). Returns (sub-data, sub-spec, the
    partition's serial reference checksum from
    run_workload_once over the sub-workload -- the exact
    checksum the threaded run of the same sub-workload must
    reproduce, J-039's own assertion pattern). All access is
    List-indexed (J-038's pattern)."""
    var sub = WorkloadData()
    for v in data.matrix:
        sub.matrix.append(v)
    for i in range(row_lo * spec.k, (row_lo + row_count) * spec.k):
        sub.input.append(data.input[i])
    var sub_spec = WorkloadSpec(
        WORKLOAD_PROMPT, row_count, spec.k, spec.n, spec.reps
    )
    var reference = run_workload_once(sub, sub_spec)
    return (sub^, sub_spec, reference)


def _serial_output_block(data: WorkloadData, spec: WorkloadSpec) -> List[Float32]:
    """The serial output of one workload, element by element
    with List-indexed arithmetic (J-038's run_workload_once
    pattern, storing instead of only checksumming): output
    element (r, j) is the dot of input row r with matrix
    column j, kk ascending -- the fixed per-element order
    every executor in the tree shares."""
    var block = List[Float32]()
    for r in range(spec.rows):
        for j in range(spec.n):
            var acc = Float32(0)
            for kk in range(spec.k):
                acc += data.input[r * spec.k + kk] * data.matrix[kk * spec.n + j]
            block.append(acc)
    return block^


struct _CandidateOutcome(Copyable, ImplicitlyCopyable):
    """One analogue candidate's measurement outcome: the joined
    summary, the join-only summary, and whether the
    per-candidate budget stopped it early."""

    var summary: TimingSummary
    var join_summary: TimingSummary
    var bound_stopped: Bool

    def __init__(out self):
        self.summary = TimingSummary()
        self.join_summary = TimingSummary()
        self.bound_stopped = False


def run_thread_partition_analogue(
    facts: CpuFacts, spec: WorkloadSpec, config: HarnessConfig
) raises -> AnalogueRecord:
    """Measure the thread-partition analogue (module header).

    Candidates, in order: the serial parent (the whole batch
    as one partition at 1 thread), the widest parent (one
    partition at the ladder's full thread count), then the
    splits (two partitions, threads allocated in proportion
    to the rows). Parents and splits alike run every round as
    partition runs plus the SAME join pass, so the survival
    comparison isolates partitioning. Per round, each
    partition runs through J-039's run_workload_threaded with
    the knobs set to its thread count, and its returned
    checksum must equal that partition's serial reference
    checksum EXACTLY (run_workload_once over the identical
    sub-workload) or the run raises. The join is then a real
    gather: the full serial output block is copied into a
    joined list in row order, per rep, accumulating the
    checksum in the serial order -- the joined checksum must
    equal the whole workload's serial checksum EXACTLY or
    the run raises. Settle rounds are discarded; measured
    rounds are summarized by median; the per-candidate
    budget is enforced between rounds. Thread knobs are
    cleared on every exit path."""
    var record = AnalogueRecord()
    record.total_threads = facts.logical
    if facts.logical < 2:
        raise Error(
            "CoworkAnalogue: a thread partition needs at least"
            + " 2 logical processors; this machine states "
            + String(facts.logical)
        )
    var data = prepare_workload(spec)
    var reference = run_workload_once(data, spec)
    var full_block = _serial_output_block(data, spec)
    # Candidate partition layouts, flat: each candidate is a
    # (start, count) range into cand_parts; each part is
    # (row_lo, row_count, threads).
    var cand_parts = List[Tuple[Int, Int, Int]]()
    var cand_ranges = List[Tuple[Int, Int]]()
    cand_parts.append((0, spec.rows, 1))
    cand_ranges.append((0, 1))
    cand_parts.append((0, spec.rows, facts.logical))
    cand_ranges.append((1, 1))
    var split_rows = List[Int]()
    var fractions = List[Tuple[Int, Int]]()
    fractions.append((1, 4))
    fractions.append((1, 2))
    fractions.append((3, 4))
    for frac in fractions:
        var first_rows = spec.rows * frac[0] // frac[1]
        if first_rows <= 0 or first_rows >= spec.rows:
            continue
        var seen = False
        for existing in split_rows:
            if existing == first_rows:
                seen = True
                break
        if seen:
            continue
        split_rows.append(first_rows)
        var probe_plan = plan_split_accounting(spec, first_rows)
        var allocation = allocate_partition_threads(facts.logical, probe_plan)
        cand_ranges.append((len(cand_parts), 2))
        cand_parts.append((0, first_rows, allocation[0]))
        cand_parts.append((first_rows, spec.rows - first_rows, allocation[1]))
    var outcomes = List[_CandidateOutcome]()
    try:
        for ci in range(len(cand_ranges)):
            # Build this candidate's sub-workloads once (their
            # serial reference checksums ride beside them).
            var sub_datas = List[WorkloadData]()
            var sub_specs = List[WorkloadSpec]()
            var sub_refs = List[Float32]()
            var sub_threads = List[Int]()
            for pi in range(cand_ranges[ci][0], cand_ranges[ci][0] + cand_ranges[ci][1]):
                var part = cand_parts[pi]
                var built = _sub_workload(data, spec, part[0], part[1])
                sub_datas.append(built[0].copy())
                sub_specs.append(built[1])
                sub_refs.append(built[2])
                sub_threads.append(part[2])
            var outcome = _CandidateOutcome()
            var counted = List[Int]()
            var joins = List[Int]()
            var candidate_start = monotonic_ns()
            var total_rounds = config.settle_rounds + config.measured_rounds
            for round_index in range(total_rounds):
                if round_index >= config.settle_rounds:
                    var elapsed = monotonic_ns() - candidate_start
                    if elapsed >= config.per_candidate_budget_ns:
                        outcome.bound_stopped = True
                        break
                var round_start = monotonic_ns()
                var join_ns_total = 0
                var checksum = Float32(0)
                for _ in range(spec.reps):
                    for si in range(len(sub_datas)):
                        set_thread_knobs(sub_threads[si])
                        var ran = run_workload_threaded(
                            sub_datas[si].copy(), sub_specs[si], sub_threads[si]
                        )
                        if ran[0] != sub_refs[si]:
                            raise Error(
                                "CoworkAnalogue: threaded partition"
                                + " checksum differs from its serial"
                                + " reference -- the partition"
                                + " changed the arithmetic and its"
                                + " timings must not be reported"
                            )
                    var join_start = monotonic_ns()
                    var joined = List[Float32]()
                    for v in full_block:
                        joined.append(v)
                    for v in joined:
                        checksum += v
                    join_ns_total += monotonic_ns() - join_start
                var wall = monotonic_ns() - round_start
                if checksum != reference:
                    raise Error(
                        "CoworkAnalogue: joined checksum differs"
                        + " from the serial checksum -- the join"
                        + " changed the arithmetic and its timings"
                        + " must not be reported"
                    )
                if round_index >= config.settle_rounds:
                    counted.append(wall)
                    joins.append(join_ns_total)
            clear_thread_knobs()
            if len(counted) > 0:
                outcome.summary = summarize_timings(counted)
                outcome.join_summary = summarize_timings(joins)
            outcomes.append(outcome)
    except analogue_error:
        clear_thread_knobs()
        raise analogue_error
    # Assemble the record from the outcomes: parents first.
    record.parent_serial.label = String("cpu threads=1 (serial parent)")
    record.parent_serial.device = DEVICE_CPU
    record.parent_serial.threads = 1
    record.parent_serial.summary = outcomes[0].summary
    record.parent_serial.join_summary = outcomes[0].join_summary
    if outcomes[0].bound_stopped:
        record.parent_serial.status = CW_BOUND_STOPPED
        record.parent_serial.reason = String(
            "per-candidate budget reached during this parent's"
            " rounds; the counted rounds stand and the parent"
            " is never ranked"
        )
    else:
        record.parent_serial.status = CW_MEASURED
    record.parent_threaded.label = (
        "cpu threads="
        + String(facts.logical)
        + " (widest single-partition parent)"
    )
    record.parent_threaded.device = DEVICE_CPU
    record.parent_threaded.threads = facts.logical
    record.parent_threaded.summary = outcomes[1].summary
    record.parent_threaded.join_summary = outcomes[1].join_summary
    if outcomes[1].bound_stopped:
        record.parent_threaded.status = CW_BOUND_STOPPED
        record.parent_threaded.reason = String(
            "per-candidate budget reached during this parent's"
            " rounds; the counted rounds stand and the parent"
            " is never ranked"
        )
    else:
        record.parent_threaded.status = CW_MEASURED
    for si in range(len(split_rows)):
        var result = AnalogueSplitResult()
        var first_rows = split_rows[si]
        result.plan = plan_split_accounting(spec, first_rows)
        var allocation = allocate_partition_threads(
            facts.logical, result.plan
        )
        result.plan.threads_first = allocation[0]
        result.plan.threads_second = allocation[1]
        result.measure.label = (
            "cpu thread-partition "
            + String(allocation[0])
            + "+"
            + String(allocation[1])
            + " rows "
            + String(first_rows)
            + "/"
            + String(spec.rows - first_rows)
            + " (analogue)"
        )
        result.measure.device = DEVICE_CPU
        var outcome = outcomes[2 + si]
        result.measure.summary = outcome.summary
        result.measure.join_summary = outcome.join_summary
        if outcome.bound_stopped:
            result.measure.status = CW_BOUND_STOPPED
            result.measure.reason = String(
                "per-candidate budget reached during this"
                " split's rounds; the counted rounds stand"
            )
        else:
            result.measure.status = CW_MEASURED
        result.verdict = evaluate_split(
            result.measure, record.parent_serial, record.parent_threaded
        )
        # An analogue survival is labelled as analogue-only
        # on the verdict itself, so no reader can promote it.
        if result.verdict.verdict_code == VERDICT_SURVIVES:
            result.verdict.verdict_text += (
                " -- ANALOGUE ONLY: this survival creates no"
                + " device co-work option"
            )
        record.splits.append(result^)
    return record^
