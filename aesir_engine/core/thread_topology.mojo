"""Thread topology trials (Janas road J-039).

J-037 built the device inventory (what the machine offers, CPU
topology included) and J-038 built the placement measurement
harness (settle + rounds, median summary, hard time bounds) -- but
its CPU workload is single-threaded scalar arithmetic by design:
it grades placement mechanics, not threading, and it records
thread-topology candidates as J-039's to own. This module is that
step: per pass kind (J-035's taxonomy), it derives a thread-count
ladder from the inventory's CPU facts and measures every rung of
the ladder on Aesir's own pass-shaped micro-workloads, through
Aesir's own threading vehicle.

THE LADDER, derived -- never invented. The candidate counts come
from core/device_inventory.CpuFacts and nothing else:

- 1 thread (the serial rung; every scaling claim needs its base);
- half the physical cores (physical count when cpuinfo states
  one, else the logical count, with the basis stated in the
  ladder's note);
- all physical cores;
- all logical processors (a distinct rung only when it differs
  from the physical count -- SMT);
- performance-cores-only, ONLY when the machine itself states a
  hybrid split (J-037's rule: both Intel hybrid sysfs cpulists
  present and non-empty, counted verbatim). Where no split is
  stated, the ladder records performance/efficiency as
  NOT APPLICABLE-WITH-REASON -- a P/E candidate is never guessed
  from a model name, a core count, or another machine's shape.
  (A hybrid machine's perf+eff total is its all-logical rung,
  labelled as such; the distinct hybrid rung is perf-only.)

Counts are de-duplicated (a 2-core machine's half IS its serial
rung) and sorted ascending, so a trial always walks from fewest
threads to most.

THE THREADING VEHICLE is Aesir's own: core/parallel.par_for over
the pthread shim (aesir_engine/thread_par.c), controlled by the
engine's documented knobs AESIR_THREADS (the count) and
AESIR_PAR_MIN_WORK (set to 1 for trials, so the engagement
threshold the engine uses to protect small real work never
silently serialises a trial rung -- stated here, not hidden).
The workload product is partitioned by output columns, each
output element computed independently with a fixed per-element
reduction order (the GEMM kernels' own contract), and the
checksum is accumulated serially in the serial path's exact
order -- so a threaded round's checksum must equal the J-038
serial workload's checksum EXACTLY, at every thread count, or
the trial raises. A thread count that changed the arithmetic
would be a defect, never a timing.

THE I9 LESSON, as a hypothesis -- pre-registered verdict rule.
Janas's docs record that on a hybrid i9 more threads can be
slower (filed census, J-003/J-008 rows). This slice tests that
claim on Aesir's own hardware instead of assuming it, under a
rule stated before any number was measured: for one pass kind,
let BEST be the measured rung with the lowest median and ALL
the measured rung with the most threads. The lesson is
CONFIRMED for the kind when BEST uses fewer threads than ALL
and ALL's median exceeds BEST's median by more than 5% of
BEST's median (the noise band: a smaller median gap on a shared
machine is not evidence of anything). ALL is FASTEST when it
is BEST; WITHIN-NOISE when BEST uses fewer threads but the gap
is inside the band. The rule is a pure function of the filed
medians (grade_thread_results), unit-tested on injected values;
the raw medians and spreads are reported whatever the verdict.

DISCIPLINE is J-038's, reused not re-derived: >=1 settle round
per rung, timed and discarded; 5 measured rounds by default;
the reported statistic is the median with min/max/spread beside
it; per-candidate (2,000 ms) and per-sweep (10,000 ms) hard
bounds enforced between rounds/candidates, bound-stops reported
with the rounds that stand (HarnessConfig carries all of it).

DRAFT-CHECK rungs are UNMEASURABLE-WITH-REASON, always: Aesir
has no draft-check pass (J-035 gap G1; Part V J-071/J-072 own
building it), so there is no draft-check workload to thread,
and no prompt/reply proxy is timed in its name. The ladder is
still derived for the kind -- the counts exist; the pass does
not, yet.

HOST CONTRACT: run_thread_trials(facts, pass_kind, spec,
config) is a pure function of its inputs apart from the thread
knobs it sets per rung (and unsets when the sweep ends, success
or raise). A surface may call it at model open OR on demand --
the same call, the same bounds. This slice wires it into NO
live session path: no session consumes a thread verdict yet,
and claiming otherwise would fake the integration J-040--J-042
own. The workloads are J-038's harness shapes: their timings
grade thread scaling of harness mechanics on this machine, and
are NOT placement verdicts for any model. See
docs/janas/J039_THREAD_TOPOLOGY.md.
"""

from std.ffi import external_call
from std.collections import InlineArray
from std.memory import Pointer
from std.memory.alloc import alloc

from core.device_inventory import CpuFacts, apply_hybrid_split, parse_cpuinfo
from core.parallel import par_for, par_thread_count
from core.placement_harness import (
    HarnessConfig,
    TimingSummary,
    WorkloadData,
    WorkloadSpec,
    monotonic_ns,
    prepare_workload,
    run_workload_once,
    summarize_timings,
)
from core.placement_options import PASS_DRAFTS, pass_name

# Thread candidate kinds (which ladder rung a count is).
comptime THREAD_SERIAL = 0
comptime THREAD_HALF = 1
comptime THREAD_ALL_PHYSICAL = 2
comptime THREAD_ALL_LOGICAL = 3
comptime THREAD_PERF_ONLY = 4

# Thread result status (after a trial sweep).
comptime TRES_MEASURED = 0
comptime TRES_UNMEASURABLE = 1
comptime TRES_BOUND_STOPPED = 2

# Verdict codes (grade_thread_results / ThreadSweep.verdict_code).
comptime VERDICT_ALL_FASTEST = 0
comptime VERDICT_WITHIN_NOISE = 1
comptime VERDICT_LESSON_CONFIRMED = 2
comptime VERDICT_NOT_GRADED = 3

# The pre-registered noise band, in percent of the best median:
# a wider all-cores median gap than this is the lesson; a
# narrower one is noise on a shared machine (module header).
comptime NOISE_BAND_PERCENT = 5


# --- the ladder ------------------------------------------------------


struct ThreadCandidate(Copyable, ImplicitlyCopyable):
    """One rung of the thread ladder: a count, which rung it is,
    and the label a report prints. Counts are unique within a
    ladder and sorted ascending."""

    var threads: Int
    var kind: Int
    var label: String

    def __init__(out self):
        self.threads = 0
        self.kind = THREAD_SERIAL
        self.label = String("")


struct ThreadLadder(Copyable, Movable):
    """The ladder derived from one machine's CPU facts, with the
    two honesty records the derivation owes: basis_note (which
    count the half/all-physical rungs stand on when cpuinfo
    states no physical count) and pe_status (the split the
    machine states, or NOT APPLICABLE-WITH-REASON)."""

    var candidates: List[ThreadCandidate]
    var basis_note: String
    var pe_status: String

    def __init__(out self):
        self.candidates = List[ThreadCandidate]()
        self.basis_note = String("")
        self.pe_status = String("")

    def describe(self) -> String:
        var out_str = String("thread ladder: ")
        for i in range(len(self.candidates)):
            if i > 0:
                out_str += ", "
            out_str += (
                String(self.candidates[i].threads)
                + " ("
                + self.candidates[i].label
                + ")"
            )
        out_str += " | basis: " + self.basis_note
        out_str += " | performance/efficiency: " + self.pe_status
        return out_str


def _append_rung(
    mut ladder: ThreadLadder, threads: Int, kind: Int, label: String
):
    """Append a rung unless its count is already on the ladder
    (de-duplication: on small or SMT-free machines several named
    rungs are the same count, and a count is trialled once)."""
    if threads < 1:
        return
    for cand in ladder.candidates:
        if cand.threads == threads:
            return
    var rung = ThreadCandidate()
    rung.threads = threads
    rung.kind = kind
    rung.label = label
    ladder.candidates.append(rung)


def derive_thread_ladder(facts: CpuFacts) raises -> ThreadLadder:
    """The thread-count ladder one machine's stated topology
    supports. Every count comes from the facts; a performance
    rung exists only when the facts carry a machine-stated
    hybrid split (J-037's rule). Raises on a fact set with no
    logical processors -- a ladder over nothing would be a
    fabricated candidate list."""
    if facts.logical <= 0:
        raise Error(
            "ThreadTopology: cpu facts state no logical processors;"
            " no ladder can be derived"
        )
    var ladder = ThreadLadder()
    var physical_basis = facts.physical_cores
    if physical_basis > 0:
        ladder.basis_note = (
            "physical core count stated by cpuinfo ("
            + String(physical_basis)
            + ")"
        )
    else:
        physical_basis = facts.logical
        ladder.basis_note = (
            "cpuinfo states no physical core count; the physical"
            " rungs stand on the logical count ("
            + String(facts.logical)
            + "), stated not derived (J-037)"
        )
    var half = physical_basis // 2
    if half < 1:
        half = 1
    _append_rung(ladder, 1, THREAD_SERIAL, String("serial"))
    _append_rung(ladder, half, THREAD_HALF, String("half the cores"))
    if physical_basis == facts.logical:
        _append_rung(
            ladder,
            physical_basis,
            THREAD_ALL_PHYSICAL,
            String("all cores (physical == logical)"),
        )
    else:
        _append_rung(
            ladder, physical_basis, THREAD_ALL_PHYSICAL, String("all physical cores")
        )
        _append_rung(
            ladder, facts.logical, THREAD_ALL_LOGICAL, String("all logical (SMT)")
        )
    if facts.has_hybrid_split():
        _append_rung(
            ladder,
            facts.perf_cores,
            THREAD_PERF_ONLY,
            String("performance cores only"),
        )
        ladder.pe_status = (
            "split stated by the machine: "
            + String(facts.perf_cores)
            + " performance / "
            + String(facts.eff_cores)
            + " efficiency; the hybrid (perf+eff) count is the"
            + " all-logical rung"
        )
    else:
        ladder.pe_status = String(
            "NOT APPLICABLE-WITH-REASON: this machine states no"
            " performance/efficiency split (J-037: the split is"
            " reported only when the machine's own hybrid sysfs"
            " cpulists state it), so no performance-only or hybrid"
            " candidate exists to trial -- never invented"
        )
    # Sort ascending by count (insertion sort; ladders are short).
    for i in range(1, len(ladder.candidates)):
        var j = i
        while j > 0 and ladder.candidates[j].threads < ladder.candidates[j - 1].threads:
            var tmp = ladder.candidates[j - 1]
            ladder.candidates[j - 1] = ladder.candidates[j]
            ladder.candidates[j] = tmp
            j -= 1
    return ladder^


def observe_cpu_facts() raises -> CpuFacts:
    """This machine's CPU facts, read exactly as J-037's live
    observer reads them (cpuinfo + the hybrid sysfs cpulists
    where they exist). Raises when cpuinfo cannot be read --
    a trials caller needs the facts, not a bench line."""
    var text: String
    with open("/proc/cpuinfo", "r") as source:
        text = source.read()
    var facts = parse_cpuinfo(text)
    try:
        var core_list: String
        var atom_list: String
        with open("/sys/devices/cpu_core/cpulist", "r") as source:
            core_list = source.read()
        with open("/sys/devices/cpu_atom/cpulist", "r") as source:
            atom_list = source.read()
        apply_hybrid_split(facts, core_list, atom_list)
    except:
        pass
    return facts


# --- the threading vehicle --------------------------------------------


def _set_env(name: String, value: String):
    """setenv(3) through FFI, overwrite. Best-effort by design:
    the trial verifies the knob took by reading par_thread_count
    back (the live proof in the test suite), so a silent setenv
    failure would surface as a wrong chunk count, never as a
    quietly serial 'threaded' timing."""
    var name_buf = InlineArray[Int8, 32](fill=0)
    var name_bytes = name.as_bytes()
    for i in range(len(name_bytes)):
        if i < 31:
            name_buf[i] = Int8(name_bytes[i])
    var value_buf = InlineArray[Int8, 32](fill=0)
    var value_bytes = value.as_bytes()
    for i in range(len(value_bytes)):
        if i < 31:
            value_buf[i] = Int8(value_bytes[i])
    _ = external_call["setenv", Int32](
        name_buf.unsafe_ptr(), value_buf.unsafe_ptr(), Int32(1)
    )


def _unset_env(name: String):
    var name_buf = InlineArray[Int8, 32](fill=0)
    var name_bytes = name.as_bytes()
    for i in range(len(name_bytes)):
        if i < 31:
            name_buf[i] = Int8(name_bytes[i])
    _ = external_call["unsetenv", Int32](name_buf.unsafe_ptr())


def set_thread_knobs(threads: Int):
    """Point Aesir's own thread layer at one ladder rung:
    AESIR_THREADS=<threads> (par_for's chunk count) and
    AESIR_PAR_MIN_WORK=1 (the trial measures the count, so the
    small-work engagement threshold must not serialise it)."""
    _set_env("AESIR_THREADS", String(threads))
    _set_env("AESIR_PAR_MIN_WORK", String("1"))


def clear_thread_knobs():
    _unset_env("AESIR_THREADS")
    _unset_env("AESIR_PAR_MIN_WORK")


def _thread_product_range(
    input_addr: Int64,
    matrix_addr: Int64,
    output_addr: Int64,
    rows: Int,
    k: Int,
    n: Int,
    col_lo: Int,
    col_hi: Int,
):
    """Compute output columns [col_lo, col_hi) of input x matrix.
    Each output element is independent, with the serial path's
    fixed per-element reduction order (kk ascending) -- the
    GEMM kernels' bit-identity contract."""
    var input = Pointer[Float32, MutUntrackedOrigin](
        unsafe_from_address=Int(input_addr)
    )
    var matrix = Pointer[Float32, MutUntrackedOrigin](
        unsafe_from_address=Int(matrix_addr)
    )
    var output = Pointer[Float32, MutUntrackedOrigin](
        unsafe_from_address=Int(output_addr)
    )
    for j in range(col_lo, col_hi):
        for r in range(rows):
            var acc = Float32(0)
            for kk in range(k):
                acc += (
                    input.unsafe_load(r * k + kk)
                    * matrix.unsafe_load(kk * n + j)
                )
            output.unsafe_store(r * n + j, acc)


def _thread_product_worker(ctx_addr: Int64, start: Int64, end: Int64):
    """FFI range callback for par_for; ctx slots: [input.data,
    matrix.data, output.data, rows, k, n]."""
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    _thread_product_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(ctx.unsafe_load(5)),
        Int(start),
        Int(end),
    )


def run_workload_threaded(
    data: WorkloadData, spec: WorkloadSpec, threads: Int
) raises -> Tuple[Float32, Int]:
    """One round of the J-038 workload on `threads` OS threads:
    `reps` full products, each partitioned by output columns via
    par_for, with the checksum accumulated serially in the
    serial path's exact order. Returns (checksum, chunks used by
    the last rep's par_for). The checksum must equal the serial
    run_workload_once checksum exactly; the caller asserts it.
    The caller sets the thread knobs (set_thread_knobs) -- this
    function only runs."""
    var out_len = spec.rows * spec.n
    var output = alloc[Float32](out_len)
    var ctx = alloc[Int64](6)
    ctx.unsafe_store(0, Int64(Int(data.input.unsafe_ptr())))
    ctx.unsafe_store(1, Int64(Int(data.matrix.unsafe_ptr())))
    ctx.unsafe_store(2, Int64(Int(output)))
    ctx.unsafe_store(3, Int64(spec.rows))
    ctx.unsafe_store(4, Int64(spec.k))
    ctx.unsafe_store(5, Int64(spec.n))
    var checksum = Float32(0)
    var chunks = 0
    for _ in range(spec.reps):
        chunks = par_for[_thread_product_worker](
            Int64(Int(ctx)),
            spec.n,
            Int64(spec.rows) * Int64(spec.k) * Int64(spec.n),
        )
        for r in range(spec.rows):
            for j in range(spec.n):
                checksum += output.unsafe_load(r * spec.n + j)
    ctx.unsafe_free()
    output.unsafe_free()
    return (checksum, chunks)


# --- the verdict (pre-registered rule, pure) ---------------------------


def grade_thread_results(
    best_threads: Int, best_median_ns: Int, all_threads: Int, all_median_ns: Int
) -> Int:
    """The i9-lesson rule of the module header, as a pure
    function of the two medians it grades. ALL fastest when the
    widest rung is the best; lesson CONFIRMED when a narrower
    rung wins by more than the noise band; WITHIN-NOISE
    otherwise."""
    if best_threads >= all_threads:
        return VERDICT_ALL_FASTEST
    if all_median_ns * 100 > best_median_ns * (100 + NOISE_BAND_PERCENT):
        return VERDICT_LESSON_CONFIRMED
    return VERDICT_WITHIN_NOISE


def verdict_name(code: Int) -> String:
    if code == VERDICT_ALL_FASTEST:
        return String("ALL-CORES FASTEST")
    if code == VERDICT_LESSON_CONFIRMED:
        return String("I9 LESSON CONFIRMED (more threads slower)")
    if code == VERDICT_WITHIN_NOISE:
        return String("WITHIN NOISE (5% band)")
    return String("NOT GRADED")


# --- the trial sweep ----------------------------------------------------


struct ThreadResult(Copyable, ImplicitlyCopyable):
    """One rung's trial outcome: measured with its summary,
    bound-stopped with the rounds that stand, or unmeasurable
    with its reason. chunks is the par_for chunk count the last
    counted round reported (the proof the rung's threads really
    ran); checksum is the threaded rounds' checksum, asserted
    equal to the serial reference before any timing is kept."""

    var threads: Int
    var label: String
    var status: Int
    var reason: String
    var settle_run: Int
    var summary: TimingSummary
    var chunks: Int
    var checksum: Float32

    def __init__(out self):
        self.threads = 0
        self.label = String("")
        self.status = TRES_UNMEASURABLE
        self.reason = String("")
        self.settle_run = 0
        self.summary = TimingSummary()
        self.chunks = 0
        self.checksum = Float32(0)

    def render(self, pass_kind: Int) -> String:
        var head = (
            pass_name(pass_kind)
            + " threads="
            + String(self.threads)
            + " ("
            + self.label
            + "): "
        )
        if self.status == TRES_MEASURED:
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
                + " discarded, chunks "
                + String(self.chunks)
                + ", checksum identical)"
            )
        if self.status == TRES_BOUND_STOPPED:
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
        return head + "UNMEASURABLE -- " + self.reason


struct ThreadSweep(Copyable, Movable):
    """One pass kind's whole trial: the ladder, one result per
    rung, the sweep's total wall, and the graded verdict."""

    var pass_kind: Int
    var ladder: ThreadLadder
    var results: List[ThreadResult]
    var total_ns: Int
    var verdict_code: Int
    var verdict_text: String

    def __init__(out self, pass_kind: Int):
        self.pass_kind = pass_kind
        self.ladder = ThreadLadder()
        self.results = List[ThreadResult]()
        self.total_ns = 0
        self.verdict_code = VERDICT_NOT_GRADED
        self.verdict_text = String("not graded")

    def measured_count(self) -> Int:
        var total = 0
        for result in self.results:
            if result.status == TRES_MEASURED:
                total += 1
        return total

    def report(self) -> String:
        var out_str = self.ladder.describe() + "\n"
        for result in self.results:
            out_str += result.render(self.pass_kind) + "\n"
        out_str += (
            "verdict: "
            + self.verdict_text
            + "\nsweep total "
            + String(self.total_ns)
            + " ns\n"
        )
        return out_str


def _grade_sweep(mut sweep: ThreadSweep):
    """Apply grade_thread_results to a finished sweep's measured
    rungs and write the verdict (code + one-line text with the
    numbers it rests on). Sweeps with fewer than two measured
    rungs, or whose widest rung did not measure, are NOT GRADED
    with the reason in the text."""
    var best: Int = -1
    var widest: Int = -1
    for i in range(len(sweep.results)):
        if sweep.results[i].status != TRES_MEASURED:
            continue
        if best < 0 or sweep.results[i].summary.median_ns < sweep.results[best].summary.median_ns:
            best = i
        if widest < 0 or sweep.results[i].threads > sweep.results[widest].threads:
            widest = i
    if best < 0 or widest < 0:
        sweep.verdict_code = VERDICT_NOT_GRADED
        sweep.verdict_text = String("not graded: no measured rung")
        return
    if sweep.results[widest].status != TRES_MEASURED:
        sweep.verdict_code = VERDICT_NOT_GRADED
        sweep.verdict_text = String("not graded: the widest rung did not measure")
        return
    var b = sweep.results[best]
    var a = sweep.results[widest]
    sweep.verdict_code = grade_thread_results(
        b.threads, b.summary.median_ns, a.threads, a.summary.median_ns
    )
    if sweep.verdict_code == VERDICT_ALL_FASTEST:
        sweep.verdict_text = (
            verdict_name(sweep.verdict_code)
            + " -- the widest rung ("
            + String(a.threads)
            + " threads) holds the lowest median ("
            + String(a.summary.median_ns)
            + " ns)"
        )
    elif sweep.verdict_code == VERDICT_LESSON_CONFIRMED:
        var pct = (a.summary.median_ns - b.summary.median_ns) * 100 // b.summary.median_ns
        sweep.verdict_text = (
            verdict_name(sweep.verdict_code)
            + " -- best is "
            + String(b.threads)
            + " threads at median "
            + String(b.summary.median_ns)
            + " ns; all-cores ("
            + String(a.threads)
            + ") is slower by "
            + String(pct)
            + "% (median "
            + String(a.summary.median_ns)
            + " ns), beyond the 5% noise band"
        )
    else:
        sweep.verdict_text = (
            verdict_name(sweep.verdict_code)
            + " -- best is "
            + String(b.threads)
            + " threads at median "
            + String(b.summary.median_ns)
            + " ns; all-cores ("
            + String(a.threads)
            + ") median "
            + String(a.summary.median_ns)
            + " ns is inside the 5% noise band"
        )


def run_thread_trials(
    facts: CpuFacts,
    pass_kind: Int,
    spec: WorkloadSpec,
    config: HarnessConfig,
) raises -> ThreadSweep:
    """The trial entry point: derive the ladder from the facts,
    then measure every rung under J-038's discipline. Draft-check
    rungs record UNMEASURABLE-WITH-REASON (gap G1) and nothing is
    timed. Every threaded round's checksum must equal the serial
    workload's checksum exactly, or the sweep raises. The thread
    knobs are unset when the sweep ends, on every path."""
    var sweep = ThreadSweep(pass_kind)
    sweep.ladder = derive_thread_ladder(facts)
    var rungs = sweep.ladder.candidates.copy()
    if pass_kind == PASS_DRAFTS:
        for cand in rungs:
            var result = ThreadResult()
            result.threads = cand.threads
            result.label = cand.label
            result.status = TRES_UNMEASURABLE
            result.reason = String(
                "draft-check passes do not exist in Aesir yet (J-035"
                " gap G1; Part V J-071/J-072 own building the pass) --"
                " there is no draft-check workload to thread, and no"
                " prompt/reply proxy is timed in its name"
            )
            sweep.results.append(result)
        sweep.verdict_code = VERDICT_NOT_GRADED
        sweep.verdict_text = String(
            "not graded: draft-check is unmeasurable-with-reason (G1)"
        )
        return sweep^
    var data = prepare_workload(spec)
    var reference = run_workload_once(data, spec)
    var sweep_start = monotonic_ns()
    var sweep_bound_hit = False
    try:
        for cand in rungs:
            var result = ThreadResult()
            result.threads = cand.threads
            result.label = cand.label
            if sweep_bound_hit or (
                monotonic_ns() - sweep_start >= config.per_sweep_budget_ns
            ):
                sweep_bound_hit = True
                result.status = TRES_BOUND_STOPPED
                result.reason = (
                    "per-sweep budget of "
                    + String(config.per_sweep_budget_ns)
                    + " ns reached before this rung ran; no rounds"
                    + " were run for it"
                )
                sweep.results.append(result)
                continue
            set_thread_knobs(cand.threads)
            var candidate_start = monotonic_ns()
            var settle_run = 0
            for _ in range(config.settle_rounds):
                var round = run_workload_threaded(data, spec, cand.threads)
                settle_run += 1
                if round[0] != reference:
                    raise Error(
                        "ThreadTopology: threaded checksum differs from"
                        " the serial checksum at "
                        + String(cand.threads)
                        + " thread(s) in a settle round -- threading"
                        " changed the arithmetic and its timings must"
                        " not be reported"
                    )
                result.chunks = round[1]
            var counted = List[Int]()
            var bound_stopped = False
            for _ in range(config.measured_rounds):
                var elapsed = monotonic_ns() - candidate_start
                if elapsed >= config.per_candidate_budget_ns:
                    bound_stopped = True
                    break
                var round_start = monotonic_ns()
                var round = run_workload_threaded(data, spec, cand.threads)
                var duration = monotonic_ns() - round_start
                if round[0] != reference:
                    raise Error(
                        "ThreadTopology: threaded checksum differs from"
                        " the serial checksum at "
                        + String(cand.threads)
                        + " thread(s) -- threading changed the"
                        " arithmetic and its timings must not be"
                        " reported"
                    )
                result.chunks = round[1]
                result.checksum = round[0]
                counted.append(duration)
            result.settle_run = settle_run
            if len(counted) > 0:
                result.summary = summarize_timings(counted)
            if bound_stopped:
                result.status = TRES_BOUND_STOPPED
                result.reason = (
                    "per-candidate budget of "
                    + String(config.per_candidate_budget_ns)
                    + " ns reached after "
                    + String(len(counted))
                    + " measured round(s); the counted rounds stand"
                )
            else:
                result.status = TRES_MEASURED
            sweep.results.append(result)
    except trial_error:
        clear_thread_knobs()
        raise trial_error
    clear_thread_knobs()
    sweep.total_ns = monotonic_ns() - sweep_start
    _grade_sweep(sweep)
    return sweep^
