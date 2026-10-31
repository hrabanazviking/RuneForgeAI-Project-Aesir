"""Placement measurement harness (Janas road J-038).

J-036 built the placement option surface (what a user asks for)
and J-037 built the device inventory (what the machine actually
offers). This module is the measurement step between them and the
auto choice J-040--J-042 will make: given one resolved placement
option, the inventory, and a pass kind, it enumerates the candidate
configurations that kind may be measured under, filters them
through inventory truth, and runs short bounded micro-runs per
surviving candidate.

BENCH DISCIPLINE, re-derived for Aesir's passes. The documented
Janas bench method (filed census, J-008 row) sweeps the
configurations the engine may choose with a settle (300 ms in the
published runs) and rounds, and writes the learned profile out.
Aesir's micro-runs are single passes far shorter than 300 ms, so a
fixed settle TIME would either dominate the run or never bite;
the settle is re-derived as ROUNDS: at least one settle round is
executed per candidate and its timing is DISCARDED (it absorbs
first-touch costs -- page faults, cold caches, first allocation --
that are properties of the process, not of the candidate). Then a
stated number of measured rounds runs (default 5; Janas's published
2 is too few for a median on a shared, noisy machine). The summary
statistic is the MEDIAN of the measured rounds, stated plainly:
the median is robust to the scheduling spikes a shared VM throws
into individual rounds, where the minimum would report the
luckiest round as the candidate's speed and the mean would let
one spike move the verdict. The minimum, maximum, and spread
(max - min) ride beside the median so the noise stays visible.

HARD TIME BOUNDS, stated and enforced. A harness that can hang at
model open is a defect, so two bounds are part of the config and
are checked between rounds and between candidates (a round in
flight always finishes -- the workloads are themselves bounded --
so a bound can be exceeded by at most one round's duration):

- per-candidate budget (default 2,000 ms): one candidate's settle
  + measured rounds stop at the bound; the rounds completed stand
  and the candidate is reported bound-stopped, never silently
  truncated;
- per-sweep budget (default 10,000 ms): when the sweep's elapsed
  time reaches the bound, every remaining measurable candidate is
  reported bound-stopped with zero rounds, with that reason.

CANDIDATE HONESTY. Enumeration never silently drops a candidate:

- a candidate naming a device the inventory refuses is EXCLUDED,
  recorded with the inventory entry's own reason (the filter calls
  core/device_inventory.require_device_present and keeps its
  refusal text -- J-037's feed point, consumed here for filtering;
  refusal of a hand placement at open remains J-047's work);
- a co-work (`a+b`) candidate whose devices are all present is
  UNMEASURABLE-WITH-REASON in this slice: no real split workload
  exists in the tree, and a split timing faked by running one
  device twice would be a fabricated number. J-043 owns co-work
  execution;
- a draft-check candidate is UNMEASURABLE-WITH-REASON, always:
  Aesir has no draft-check pass (J-035 gap G1; Part V J-071/J-072
  own building it), so there is no pass to measure and no synthetic
  proxy is invented and called draft-check;
- a present GPU/NPU single candidate is UNMEASURABLE-WITH-REASON
  in this slice: the harness's workload executor is the CPU one
  (the only device whose pass-shaped micro-workloads exist in the
  tree today); device executors ride with the slices that build
  device pass execution (J-043, Part IV). On a machine where the
  GPU is absent the inventory exclusion fires first, with its
  reason -- the two records never blur.

WORKLOADS. The caller supplies the pass-shaped micro-workload as a
WorkloadSpec: reply is a width-1 matrix-vector product (one row:
the decode shape), prompt is a batched matrix product (16 rows
against the same class of matrix: the prefill shape). The data is
prepared once per sweep from a deterministic integer generator, so
every candidate in a sweep runs bit-identical work and every
round's checksum must agree exactly -- a disagreement is a harness
defect and raises, it is never averaged away. These workloads are
harness mechanics: their timings say how the harness behaves on
this machine, and are NOT placement verdicts for any model
(J-040--J-042 own choices, on real passes).

HOST CONTRACT: the entry point is run_placement_measurement(),
a pure function of (resolved options, inventory, pass kind,
workload, config). A surface may call it at model open OR on
demand -- the same call, the same bounds -- and keeps the returned
SweepResult (report() renders it bench-style). This slice wires it
into NO live session path: no session consumes a measurement yet,
and claiming otherwise would fake the integration J-040+ own. See
docs/janas/J038_PLACEMENT_MEASUREMENT_HARNESS.md.
"""

from std.ffi import external_call
from std.collections import InlineArray
from std.memory import Pointer

from core.placement_options import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NPU,
    PASS_DRAFTS,
    PASS_PROMPT,
    PLACE_AUTO,
    PLACE_COWORK,
    PLACE_RACE,
    PLACE_SINGLE,
    PlacementChoice,
    PlacementOptions,
    device_name,
    pass_name,
)
from core.device_inventory import DeviceInventory, require_device_present

# Candidate classification (enumeration outcome, before any run).
comptime CAND_MEASURABLE = 0
comptime CAND_EXCLUDED = 1
comptime CAND_UNMEASURABLE = 2

# Candidate result status (after the sweep).
comptime RES_MEASURED = 0
comptime RES_EXCLUDED = 1
comptime RES_UNMEASURABLE = 2
comptime RES_BOUND_STOPPED = 3

# Workload shapes (pass-shaped micro-workloads, caller's choice).
comptime WORKLOAD_REPLY = 0
comptime WORKLOAD_PROMPT = 1


def monotonic_ns() raises -> Int:
    """CLOCK_MONOTONIC in nanoseconds (the tree's clock_gettime
    FFI shape, cf. core/generation_control.mojo at ms precision)."""
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("PlacementHarness: cannot observe monotonic clock")
    if ts[0] < 0 or ts[1] < 0 or ts[1] >= 1000000000:
        raise Error("PlacementHarness: invalid monotonic clock reading")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


struct HarnessConfig(Copyable, ImplicitlyCopyable):
    """The bench discipline and its hard bounds, stated once.

    settle_rounds >= 1 always (a sweep with no discarded round
    measures first-touch costs and calls them speed);
    measured_rounds >= 3 (a median over fewer is a coin flip).
    Both budgets are hard bounds, enforced between rounds and
    between candidates by run_placement_measurement.
    """

    var settle_rounds: Int
    var measured_rounds: Int
    var per_candidate_budget_ns: Int
    var per_sweep_budget_ns: Int

    def __init__(
        out self,
        settle_rounds: Int = 1,
        measured_rounds: Int = 5,
        per_candidate_budget_ns: Int = 2000000000,
        per_sweep_budget_ns: Int = 10000000000,
    ) raises:
        if settle_rounds < 1:
            raise Error(
                "PlacementHarness: settle_rounds must be at least 1"
                " (the settle round's timing is discarded; without"
                " one, first-touch costs are measured as speed)"
            )
        if measured_rounds < 3:
            raise Error(
                "PlacementHarness: measured_rounds must be at least"
                " 3 (the reported statistic is a median)"
            )
        if per_candidate_budget_ns <= 0 or per_sweep_budget_ns <= 0:
            raise Error("PlacementHarness: time budgets must be positive")
        if per_candidate_budget_ns > per_sweep_budget_ns:
            raise Error(
                "PlacementHarness: per-candidate budget exceeds the"
                " per-sweep budget; the sweep bound could never let"
                " one candidate finish"
            )
        self.settle_rounds = settle_rounds
        self.measured_rounds = measured_rounds
        self.per_candidate_budget_ns = per_candidate_budget_ns
        self.per_sweep_budget_ns = per_sweep_budget_ns


struct Candidate(Copyable, ImplicitlyCopyable):
    """One enumerated candidate configuration for one pass kind.

    status is CAND_MEASURABLE only when a real workload executor
    exists for the candidate's device AND the inventory states the
    device present. Every other candidate carries its status and
    the exact reason -- exclusion and unmeasurability are records,
    never silent drops.
    """

    var label: String
    var form: Int
    var first: Int
    var second: Int
    var status: Int
    var reason: String

    def __init__(out self):
        self.label = String("")
        self.form = PLACE_SINGLE
        self.first = DEVICE_CPU
        self.second = DEVICE_CPU
        self.status = CAND_UNMEASURABLE
        self.reason = String("not classified")


def _choice_for(options: PlacementOptions, pass_kind: Int) -> PlacementChoice:
    if pass_kind == PASS_PROMPT:
        return options.prompt.choice
    if pass_kind == PASS_DRAFTS:
        return options.drafts.choice
    return options.reply.choice


def _raw_candidate_sets(
    options: PlacementOptions, choice: PlacementChoice
) -> List[Candidate]:
    """The candidate device sets a resolved choice names, before
    inventory classification: auto expands to one single-device
    candidate per device in the (kill-shrunk) auto field; a race
    list expands to one single-device candidate per member (race
    members are measured singly); single and co-work stay as
    written."""
    var sets = List[Candidate]()
    if choice.form == PLACE_AUTO:
        var field = List[Int]()
        field.append(DEVICE_CPU)
        if not options.kills.gpu_killed:
            field.append(DEVICE_GPU)
        if not options.kills.npu_killed:
            field.append(DEVICE_NPU)
        for code in field:
            var cand = Candidate()
            cand.form = PLACE_SINGLE
            cand.first = code
            cand.label = device_name(code) + " (auto)"
            sets.append(cand)
        return sets^
    if choice.form == PLACE_RACE:
        for i in range(choice.count):
            var cand = Candidate()
            cand.form = PLACE_SINGLE
            cand.first = choice.device_at(i)
            cand.label = device_name(cand.first) + " (race)"
            sets.append(cand)
        return sets^
    var cand = Candidate()
    cand.form = choice.form
    cand.first = choice.first
    cand.second = choice.second
    cand.label = choice.describe()
    sets.append(cand)
    return sets^


def _classify(
    cand: Candidate, inventory: DeviceInventory, pass_kind: Int
) -> Candidate:
    """Classify one raw candidate set against inventory truth and
    this slice's executor facts, in a fixed order: the draft-check
    absence first (there is no pass at all), then inventory truth
    per named device, then co-work execution, then the device
    executor. The order is stated so the recorded reason is always
    the strongest true one."""
    var out_cand = cand
    if pass_kind == PASS_DRAFTS:
        out_cand.status = CAND_UNMEASURABLE
        out_cand.reason = String(
            "draft-check passes do not exist in Aesir yet (J-035"
            " gap G1; Part V J-071/J-072 own building the pass) --"
            " there is no draft-check pass to measure, and no"
            " synthetic proxy is measured in its name"
        )
        return out_cand
    var devices = List[Int]()
    devices.append(cand.first)
    if cand.form == PLACE_COWORK:
        devices.append(cand.second)
    for code in devices:
        try:
            require_device_present(inventory, device_name(code))
        except refusal:
            out_cand.status = CAND_EXCLUDED
            out_cand.reason = String(refusal)
            return out_cand
    if cand.form == PLACE_COWORK:
        out_cand.status = CAND_UNMEASURABLE
        out_cand.reason = String(
            "co-work execution does not exist in the tree yet"
            " (J-043 owns the split pass); a split timing is never"
            " faked by running one device twice"
        )
        return out_cand
    if cand.first != DEVICE_CPU:
        out_cand.status = CAND_UNMEASURABLE
        out_cand.reason = (
            "no "
            + device_name(cand.first)
            + " workload executor exists in this harness yet (the"
            " CPU executor is the only one built; device executors"
            " ride with the device pass execution, J-043 / Part IV)"
            " -- the device is present, the measurement is not"
            " claimed"
        )
        return out_cand
    out_cand.status = CAND_MEASURABLE
    out_cand.reason = String("")
    return out_cand


def enumerate_candidates(
    options: PlacementOptions, inventory: DeviceInventory, pass_kind: Int
) -> List[Candidate]:
    """Every candidate a resolved option names for one pass kind,
    classified against the inventory. The list is complete by
    construction: excluded and unmeasurable candidates are entries
    with reasons, so a reader of the sweep sees the whole field the
    option named, not only the survivors."""
    var sets = _raw_candidate_sets(options, _choice_for(options, pass_kind))
    var out_list = List[Candidate]()
    for cand in sets:
        out_list.append(_classify(cand, inventory, pass_kind))
    return out_list^


# --- summary statistics --------------------------------------------


struct TimingSummary(Copyable, ImplicitlyCopyable):
    """The robust summary of one candidate's measured rounds.

    median_ns is the reported statistic (see the module header for
    why); min/max/spread ride beside it so the noise is visible.
    count == 0 means no round was counted (bound-stopped first);
    the numeric fields are then 0 and must not be read as timings.
    """

    var count: Int
    var median_ns: Int
    var min_ns: Int
    var max_ns: Int
    var spread_ns: Int

    def __init__(out self):
        self.count = 0
        self.median_ns = 0
        self.min_ns = 0
        self.max_ns = 0
        self.spread_ns = 0


def summarize_timings(durations: List[Int]) raises -> TimingSummary:
    """Median / min / max / spread of one candidate's counted
    rounds. The median of an even count is the mean of the two
    middle rounds (integer nanoseconds). An empty list is refused:
    a summary over no rounds would be a fabricated timing."""
    if len(durations) == 0:
        raise Error(
            "PlacementHarness: cannot summarize zero measured rounds"
        )
    var sorted = List[Int]()
    for d in durations:
        if d < 0:
            raise Error("PlacementHarness: negative round duration")
        sorted.append(d)
    # Insertion sort: round counts are single digits by config.
    for i in range(1, len(sorted)):
        var j = i
        while j > 0 and sorted[j] < sorted[j - 1]:
            var tmp = sorted[j - 1]
            sorted[j - 1] = sorted[j]
            sorted[j] = tmp
            j -= 1
    var summary = TimingSummary()
    summary.count = len(sorted)
    summary.min_ns = sorted[0]
    summary.max_ns = sorted[len(sorted) - 1]
    summary.spread_ns = summary.max_ns - summary.min_ns
    var mid = len(sorted) // 2
    if len(sorted) % 2 == 1:
        summary.median_ns = sorted[mid]
    else:
        summary.median_ns = (sorted[mid - 1] + sorted[mid]) // 2
    return summary


# --- round accounting (the discipline, as a pure function) ---------


struct RoundAccount(Copyable, Movable):
    """The outcome of applying the bench discipline to one
    candidate's round durations: settle rounds run and discarded,
    measured rounds counted, and whether the per-candidate budget
    stopped the candidate early. run_placement_measurement applies
    exactly this accounting to live durations (checking the same
    budget rule between rounds, against the live clock); the pure
    form exists so the discipline itself is unit-testable on
    injected timings."""

    var settle_run: Int
    var counted: List[Int]
    var bound_stopped: Bool

    def __init__(out self):
        self.settle_run = 0
        self.counted = List[Int]()
        self.bound_stopped = False


def account_rounds(
    settle_durations: List[Int],
    measured_durations: List[Int],
    config: HarnessConfig,
) -> RoundAccount:
    """Apply settle/rounds/budget accounting to injected durations.

    Settle durations are run-and-discarded: they count toward the
    candidate's elapsed time (the budget is a wall bound, and the
    settle burns wall) but never toward the summary. Measured
    rounds are then counted one by one; before each round after
    the first check, if the elapsed time has reached the
    per-candidate budget the candidate stops: that round and the
    rest are not counted, and bound_stopped is set. (The check is
    between rounds, so the elapsed total may pass the budget by
    the final counted round's duration -- the stated overshoot.)
    """
    var account = RoundAccount()
    var elapsed = 0
    for d in settle_durations:
        account.settle_run += 1
        elapsed += d
    for d in measured_durations:
        if elapsed >= config.per_candidate_budget_ns:
            account.bound_stopped = True
            break
        account.counted.append(d)
        elapsed += d
    return account^


# --- pass-shaped micro-workloads ------------------------------------


struct WorkloadSpec(Copyable, ImplicitlyCopyable):
    """One pass-shaped micro-workload, supplied by the caller.

    kind WORKLOAD_REPLY: a width-1 matrix-vector product (rows ==
    1) -- the reply/decode shape. kind WORKLOAD_PROMPT: a batched
    matrix product (rows > 1) -- the prompt/prefill shape. The
    matrix is [k x n]; each round runs `reps` full products. Sizes
    are the caller's: the defaults are the shapes this slice's own
    proof runs use (reply: 1 x (2048 -> 1024); prompt: 32 x
    (1024 -> 512)), chosen so one round is milliseconds on a CPU,
    far inside the per-candidate budget.
    """

    var kind: Int
    var rows: Int
    var k: Int
    var n: Int
    var reps: Int

    def __init__(
        out self, kind: Int, rows: Int, k: Int, n: Int, reps: Int
    ) raises:
        if kind == WORKLOAD_REPLY and rows != 1:
            raise Error(
                "PlacementHarness: a reply workload is width 1 by"
                " definition (J-035: reply passes are exactly 1)"
            )
        if kind == WORKLOAD_PROMPT and rows < 2:
            raise Error(
                "PlacementHarness: a prompt workload is a batched"
                " product (rows >= 2); a width-1 product is the"
                " reply workload"
            )
        if kind != WORKLOAD_REPLY and kind != WORKLOAD_PROMPT:
            raise Error("PlacementHarness: unknown workload kind")
        if k <= 0 or n <= 0 or reps <= 0:
            raise Error("PlacementHarness: workload shape must be positive")
        self.kind = kind
        self.rows = rows
        self.k = k
        self.n = n
        self.reps = reps

    def describe(self) -> String:
        var name = String("reply")
        if self.kind == WORKLOAD_PROMPT:
            name = String("prompt")
        return (
            name
            + " rows="
            + String(self.rows)
            + " k="
            + String(self.k)
            + " n="
            + String(self.n)
            + " reps="
            + String(self.reps)
        )


def reply_workload() raises -> WorkloadSpec:
    return WorkloadSpec(WORKLOAD_REPLY, 1, 1024, 512, 4)


def prompt_workload() raises -> WorkloadSpec:
    return WorkloadSpec(WORKLOAD_PROMPT, 16, 512, 256, 2)


struct WorkloadData(Copyable, Movable):
    """The prepared workload: one [k x n] matrix and one [rows x k]
    input, generated deterministically (a 32-bit LCG over integers,
    so the data is bit-identical on every machine and every run --
    candidates in a sweep differ only in placement, never in work).
    """

    var matrix: List[Float32]
    var input: List[Float32]

    def __init__(out self):
        self.matrix = List[Float32]()
        self.input = List[Float32]()


def _lcg_value(mut state: UInt32) -> Float32:
    state = state * UInt32(1664525) + UInt32(1013904223)
    var bits = Int(state >> 8)  # 24-bit value in [0, 2^24)
    return Float32(bits) / Float32(16777216) - Float32(0.5)


def prepare_workload(spec: WorkloadSpec) -> WorkloadData:
    var data = WorkloadData()
    var state = UInt32(123456789)
    for _ in range(spec.k * spec.n):
        data.matrix.append(_lcg_value(state))
    for _ in range(spec.rows * spec.k):
        data.input.append(_lcg_value(state))
    return data^


def run_workload_once(data: WorkloadData, spec: WorkloadSpec) -> Float32:
    """One round of the workload: `reps` full products, returned
    as a checksum over every output element. Pure Float32
    arithmetic in a fixed order -- the same data gives the same
    checksum on every round, which the runner asserts."""
    var checksum = Float32(0)
    for _ in range(spec.reps):
        for r in range(spec.rows):
            for j in range(spec.n):
                var acc = Float32(0)
                for kk in range(spec.k):
                    acc += (
                        data.input[r * spec.k + kk]
                        * data.matrix[kk * spec.n + j]
                    )
                checksum += acc
    return checksum


# --- the sweep -------------------------------------------------------


struct CandidateResult(Copyable, ImplicitlyCopyable):
    """One candidate's sweep outcome: measured with its summary,
    excluded/unmeasurable with its reason, or bound-stopped with
    the rounds that stand (summary over the counted rounds when at
    least one was counted)."""

    var label: String
    var status: Int
    var reason: String
    var settle_run: Int
    var summary: TimingSummary
    var checksum: Float32

    def __init__(out self):
        self.label = String("")
        self.status = RES_UNMEASURABLE
        self.reason = String("")
        self.settle_run = 0
        self.summary = TimingSummary()
        self.checksum = Float32(0)

    def render(self, pass_kind: Int) -> String:
        var head = pass_name(pass_kind) + " " + self.label + ": "
        if self.status == RES_MEASURED:
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
        if self.status == RES_BOUND_STOPPED:
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
        if self.status == RES_EXCLUDED:
            return head + "EXCLUDED -- " + self.reason
        return head + "UNMEASURABLE -- " + self.reason


struct SweepResult(Copyable, Movable):
    """The whole sweep for one pass kind: one result per enumerated
    candidate (the full field, reasons included), plus the sweep's
    total wall time."""

    var pass_kind: Int
    var results: List[CandidateResult]
    var total_ns: Int

    def __init__(out self, pass_kind: Int):
        self.pass_kind = pass_kind
        self.results = List[CandidateResult]()
        self.total_ns = 0

    def measured_count(self) -> Int:
        var total = 0
        for result in self.results:
            if result.status == RES_MEASURED:
                total += 1
        return total

    def report(self) -> String:
        var out_str = String("")
        for result in self.results:
            out_str += result.render(self.pass_kind) + "\n"
        out_str += (
            "sweep total " + String(self.total_ns) + " ns\n"
        )
        return out_str


def run_placement_measurement(
    options: PlacementOptions,
    inventory: DeviceInventory,
    pass_kind: Int,
    spec: WorkloadSpec,
    config: HarnessConfig,
) raises -> SweepResult:
    """The harness entry point: enumerate, filter, and measure.

    Callable at model open OR on demand -- the same call either
    way; the hard bounds in `config` are what make the at-open
    call safe. Only CAND_MEASURABLE candidates run; every other
    candidate's result is its classification and reason. A measured
    candidate runs settle rounds (timed, discarded) then measured
    rounds, checking the per-candidate budget between rounds
    against the live clock and the per-sweep budget between
    candidates; every round's workload checksum must equal the
    first settle round's, or the sweep raises (a workload that
    changes its answer between rounds is a harness defect, never
    a timing to report).
    """
    var candidates = enumerate_candidates(options, inventory, pass_kind)
    var sweep = SweepResult(pass_kind)
    var any_measurable = False
    for cand in candidates:
        if cand.status == CAND_MEASURABLE:
            any_measurable = True
    var data = WorkloadData()
    if any_measurable:
        data = prepare_workload(spec)
    var sweep_start = monotonic_ns()
    var sweep_bound_hit = False
    for cand in candidates:
        var result = CandidateResult()
        result.label = cand.label
        if cand.status == CAND_EXCLUDED:
            result.status = RES_EXCLUDED
            result.reason = cand.reason
            sweep.results.append(result)
            continue
        if cand.status == CAND_UNMEASURABLE:
            result.status = RES_UNMEASURABLE
            result.reason = cand.reason
            sweep.results.append(result)
            continue
        if sweep_bound_hit or (
            monotonic_ns() - sweep_start >= config.per_sweep_budget_ns
        ):
            sweep_bound_hit = True
            result.status = RES_BOUND_STOPPED
            result.reason = String(
                "per-sweep budget of "
                + String(config.per_sweep_budget_ns)
                + " ns reached before this candidate ran; no rounds"
                " were run for it"
            )
            sweep.results.append(result)
            continue
        var candidate_start = monotonic_ns()
        var expected_checksum = Float32(0)
        var have_checksum = False
        var settle_durations = List[Int]()
        for _ in range(config.settle_rounds):
            var round_start = monotonic_ns()
            var checksum = run_workload_once(data, spec)
            settle_durations.append(monotonic_ns() - round_start)
            if not have_checksum:
                expected_checksum = checksum
                have_checksum = True
            elif checksum != expected_checksum:
                raise Error(
                    "PlacementHarness: workload checksum changed"
                    " between rounds for candidate '"
                    + cand.label
                    + "' -- the workload is not deterministic and"
                    " its timings must not be reported"
                )
        # Run the measured rounds live, applying account_rounds'
        # budget rule between rounds against the live clock: the
        # elapsed figure is settle wall + counted rounds' wall.
        var counted = List[Int]()
        var bound_stopped = False
        for _ in range(config.measured_rounds):
            var elapsed = monotonic_ns() - candidate_start
            if elapsed >= config.per_candidate_budget_ns:
                bound_stopped = True
                break
            var round_start = monotonic_ns()
            var checksum = run_workload_once(data, spec)
            var duration = monotonic_ns() - round_start
            if checksum != expected_checksum:
                raise Error(
                    "PlacementHarness: workload checksum changed"
                    " between rounds for candidate '"
                    + cand.label
                    + "' -- the workload is not deterministic and"
                    " its timings must not be reported"
                )
            counted.append(duration)
        result.settle_run = len(settle_durations)
        if len(counted) > 0:
            result.summary = summarize_timings(counted)
        result.checksum = expected_checksum
        if bound_stopped:
            result.status = RES_BOUND_STOPPED
            result.reason = (
                "per-candidate budget of "
                + String(config.per_candidate_budget_ns)
                + " ns reached after "
                + String(len(counted))
                + " measured round(s); the counted rounds stand"
            )
        else:
            result.status = RES_MEASURED
        sweep.results.append(result)
    sweep.total_ns = monotonic_ns() - sweep_start
    return sweep^
