"""A-123: Sliding-window attention parity -- rows
judged at window-boundary lengths specifically
(Wave 14, Architecture breadth).

The roadmap text: "Sliding-window attention parity.
Acceptance: rows judged at window-boundary lengths
specifically."

THE ENGINE RULE UNDER TEST (banked, named): the
tree's CPU attention kernel, flash_attention_gqa in
core/compute.mojo, admits position p for a query at
query_pos iff sliding_window > 0 is false or
query_pos - position < sliding_window (Gemma2 local
layers; core/inference.mojo wires config
.sliding_window onto local layers, global layers get
0 = unbounded). A query at the last position of a
sequence of length L (query_pos = L - 1) therefore
attends exactly min(L, W) positions under window W:
the window first binds at L = W + 1 (position 0 falls
out), and at L = W nothing is yet excluded. This
battery judges the kernel against an INDEPENDENT
reference at exactly those boundary lengths.

THE FIXTURE (status: SYNTHETIC, never hidden): no
filed teacher-forcing record in the banked tree
exercises sliding-window attention at boundary
lengths, and no real Gemma weight fixture exists on
purpleraider (A-120's filed position), so the graded
evidence is a deterministic synthetic Q/K/V fixture
(labelled SYNTHETIC in the code, in every rendered
line, and in every filing of this slice) executed
through the REAL banked CPU kernel. The fixture is
built to make the boundary SHARP: the first excluded
position (query_pos - W, when it exists) and the
first included position (query_pos - W + 1) carry
boosted keys (key += 6 x the mapped query row) and
extreme values (+4.0 / -4.0 on every dimension), so
an off-by-one window moves the output by far more
than the parity bound -- the seeded-defect cases
below prove that discrimination on this very
fixture, they do not merely assert it.

AXES: windows (3: 16, 512, 4096 -- 4096 is the
Gemma2 local-layer window the engine config carries;
512 and 16 are reduced windows over the same kernel
rule, stated as such) x boundary lengths (6 per
window: W-1, W, W+1, 2W-1, 2W, 2W+1, query_pos =
L-1 throughout) x backends (4, exactly A-109's
tf_harness_backends: cpu, vulkan, hip, npu, called,
never re-typed) = 72 rows. Geometry: head_dim 32,
4 query heads, 2 kv heads (GQA group 2). Every row
carries a verdict and the A-115 policy obligation
of the Gemma witness quant (Q4_K_M ->
TOKEN_EXACTNESS_OWED, read from the banked
core/exactness_policy.mojo by call, not mirrored).

THE VERDICT RULE, PRE-REGISTERED (stated here before
any test in tests/test_sliding_window_battery_a123
.mojo was run). For one row (window, length,
backend), in order:
  (W1) backend != cpu -> NOT_GRADED, reason
       BACKEND_NO_CPU_COMPARATOR, obligation still
       filed. Grading is CPU engine vs CPU
       comparator only; this battery files no
       device-execution evidence for vulkan / hip /
       npu, and accelerator-visible is NOT
       accelerator-run.
  (W2) a cpu row -> EXECUTE the banked kernel
       (flash_attention_gqa, sliding_window = W,
       query_pos = L - 1) and the independent
       reference of this module (a two-pass scalar
       softmax over exactly the admitted positions,
       written from the rule's definition, sharing
       no code with the kernel's online-softmax
       SIMD body) over the same fixture tensors:
       (a) attended count: the reference's admitted
           count must equal min(L, W) exactly, else
           DIVERGENT / WINDOW_ATTENDED_COUNT;
       (b) parity: max abs output difference
           (filed x10000) must be <= 100 (0.01, the
           A-043 filed LCG bound for this kernel vs
           a scalar body), else DIVERGENT /
           WINDOW_PARITY_DIFF_EXCEEDS_BOUND;
       all pass -> FAITHFUL, reason
       WINDOW_BOUNDARY_PARITY, witnesses filed
       (attended count, max diff x10000).

  (W3) THE SEEDED CASES (labelled SYNTHETIC):
       judged by MEASURED differences against the
       same kernel outputs, never by construction:
       SYN_OFF_BY_ONE (a reference attending
       query_pos - p <= W, i.e. one position too
       many, at W=16 / L=17) must measure ABOVE the
       bound -> DIVERGENT /
       WINDOW_BOUNDARY_OFF_BY_ONE;
       SYN_WINDOW_IGNORED (a full-attention
       reference at W=16 / L=33) must measure ABOVE
       the bound -> DIVERGENT / WINDOW_NOT_APPLIED;
       SYN_WINDOW_FREE (the same full-attention
       reference at W=16 / L=16, where the window
       cannot bind) must measure WITHIN the bound
       -> FAITHFUL / WINDOW_CANNOT_BIND_AT_OR_BELOW;
       SYN_MISMATCH (comparator named vulkan
       against a cpu engine) -> COMPARATOR_ARTIFACT
       / BACKEND_MISMATCH (the A-109 / A-112
       verdict class). Seeded summary: total 4,
       faithful 1, divergent 2, artifact 1.

A-111 NOTE (honest): the near-tie band (rank <= 2,
sub-logit gap) is the gate for teacher-forcing
TOKEN rows; this battery files no token rows, so no
near-tie verdict is claimed -- numeric parity under
the pre-registered bound above is the graded
quantity, and the A-115 obligation is filed per row
so the matrix reads alike across Wave 14.

INTEGRATION POINTS (honest, named): A-115 is
BANKED and called (policy_for_quant); A-114's MX_*
verdict namespace and mx_fnv1a64 are called; A-109's
backend axis is called. A-122 (attention variants,
team-25) and A-124 (RoPE scaling, team-27) build in
parallel -- no dependency taken on either. A-116
(first-divergence localisation) is the named tool
for any genuinely DIVERGENT engine row; if a cpu
row files DIVERGENT under W2, the localiser is run
on it before this slice closes (see the ledger).
core/kv_window.mojo is NOT this slice's subject:
it is the J-097 editor context-retention service
and states so itself; the architecture's
sliding-window attention judged here lives in
core/compute.mojo.

RAW-ORACLE DISCIPLINE (standing): CPU engine vs
CPU comparator only, comparator artifacts are a
verdict class, and no accelerator claim is made
without device-execution evidence. The battery
executes the banked CPU kernel on this machine
over a labelled synthetic fixture; it executes no
real model, opens no device, and claims no speed.
"""

from std.math import exp

from core.compute import flash_attention_gqa
from core.exactness_policy import (
    POLICY_COHERENCE_ONLY,
    POLICY_TOKEN_EXACTNESS_OWED,
    obligation_name,
    policy_for_quant,
)
from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_FAITHFUL_NEAR_TIE,
    MX_FIXTURE_LIMITED,
    MX_NOT_GRADED,
    matrix_verdict_name,
    mx_fnv1a64,
)
from core.mimir_well import MimirWell, RuneTensor, f16, f32
from core.teacher_forcing_harness import tf_harness_backends

comptime SW_FIXTURE_STATUS = "SYNTHETIC"
comptime SW_GRADED_BACKEND = "cpu"
comptime SW_MODEL_QUANT = "Q4_K_M"
comptime SW_HEAD_DIM = 32
comptime SW_Q_HEADS = 4
comptime SW_KV_HEADS = 2
comptime SW_BOUND_X10000 = 100
comptime SW_REF_WINDOWED = 0
comptime SW_REF_OFF_BY_ONE = 1
comptime SW_REF_FULL = 2


def sw_windows() -> List[Int]:
    var w = List[Int]()
    w.append(16)
    w.append(512)
    w.append(4096)
    return w^


def sw_lengths(window: Int) raises -> List[Int]:
    """The six window-boundary lengths for one
    window: W-1, W, W+1, 2W-1, 2W, 2W+1."""
    if window < 2:
        raise Error("SlidingWindow: window must be >= 2")
    var lens = List[Int]()
    lens.append(window - 1)
    lens.append(window)
    lens.append(window + 1)
    lens.append(2 * window - 1)
    lens.append(2 * window)
    lens.append(2 * window + 1)
    return lens^


def sw_backends() -> List[String]:
    return tf_harness_backends()


def policy_obligation() raises -> Int:
    """The A-115 obligation of the Gemma witness
    quant, read from the banked policy table by
    call."""
    var row = policy_for_quant(String(SW_MODEL_QUANT))
    return row.obligation


# -- the deterministic SYNTHETIC fixture --------------------------------


struct _SwLcg(Copyable, ImplicitlyCopyable):
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next(mut self) -> UInt64:
        self.state = (
            self.state * 6364136223846793005 + 1442695040888963407
        )
        return self.state >> 11

    def unit(mut self) -> Float32:
        return Float32(self.next() & 0xFFFFFF) / Float32(16777216.0)


def _fixture_seed(window: Int, length: Int) -> UInt64:
    return UInt64(0xA123) ^ (
        UInt64(window) * 1000003 + UInt64(length)
    )


def sw_first_included(window: Int, length: Int) -> Int:
    """The first position a query at length - 1
    attends under `window`: max(0, length - window).
    """
    var first = length - window
    if first < 0:
        return 0
    return first


def sw_attended(window: Int, length: Int) -> Int:
    """Positions admitted at query_pos = length - 1:
    exactly min(length, window) when window > 0."""
    if length < window:
        return length
    return window


struct SwFixture(Movable):
    """One (window, length) cell's tensors: the
    query row, the key/value rows, and the kernel
    and reference outputs, all f16 over one well."""

    var well: MimirWell
    var query: RuneTensor[f16]
    var keys: RuneTensor[f16]
    var values: RuneTensor[f16]
    var out_kernel: RuneTensor[f16]
    var out_ref: RuneTensor[f16]

    def __init__(out self, window: Int, length: Int) raises:
        var qn = SW_Q_HEADS * SW_HEAD_DIM
        var kvn = SW_KV_HEADS * SW_HEAD_DIM
        self.well = MimirWell(64 * 1024 * 1024)
        self.query = RuneTensor[f16](
            1, qn, self.well.allocate(qn)
        )
        self.keys = RuneTensor[f16](
            length, kvn, self.well.allocate(length * kvn)
        )
        self.values = RuneTensor[f16](
            length, kvn, self.well.allocate(length * kvn)
        )
        self.out_kernel = RuneTensor[f16](
            1, qn, self.well.allocate(qn)
        )
        self.out_ref = RuneTensor[f16](
            1, qn, self.well.allocate(qn)
        )
        var lcg = _SwLcg(_fixture_seed(window, length))
        for i in range(self.query.size):
            self.query.data.unsafe_store(
                i, (lcg.unit() * 2.0 - 1.0).cast[f16]()
            )
        for i in range(self.keys.size):
            self.keys.data.unsafe_store(
                i, (lcg.unit() * 2.0 - 1.0).cast[f16]()
            )
        for i in range(self.values.size):
            self.values.data.unsafe_store(
                i, (lcg.unit() * 2.0 - 1.0).cast[f16]()
            )
        # The sharp boundary: boosted keys and extreme
        # values at the first included position, and
        # (when it exists) the first excluded one.
        var group = SW_Q_HEADS // SW_KV_HEADS
        var first_in = sw_first_included(window, length)
        for kvh in range(SW_KV_HEADS):
            var qbase = kvh * group * SW_HEAD_DIM
            var kin = first_in * kvn + kvh * SW_HEAD_DIM
            var kex = (first_in - 1) * kvn + kvh * SW_HEAD_DIM
            for d in range(SW_HEAD_DIM):
                var qv = self.query.data.unsafe_load(
                    qbase + d
                ).cast[f32]()
                var kin_old = self.keys.data.unsafe_load(
                    kin + d
                ).cast[f32]()
                self.keys.data.unsafe_store(
                    kin + d, (kin_old + 6.0 * qv).cast[f16]()
                )
                self.values.data.unsafe_store(
                    first_in * kvn + kvh * SW_HEAD_DIM + d,
                    Float32(-4.0).cast[f16](),
                )
                if first_in > 0:
                    var kex_old = self.keys.data.unsafe_load(
                        kex + d
                    ).cast[f32]()
                    self.keys.data.unsafe_store(
                        kex + d, (kex_old + 6.0 * qv).cast[f16]()
                    )
                    self.values.data.unsafe_store(
                        (first_in - 1) * kvn
                        + kvh * SW_HEAD_DIM + d,
                        Float32(4.0).cast[f16](),
                    )


def sw_reference(
    mut fixture: SwFixture,
    window: Int,
    length: Int,
    mode: Int,
) raises -> Int:
    """The independent reference: a two-pass scalar
    softmax over exactly the admitted positions,
    written from the engine rule's definition and
    sharing no code with the kernel's online-softmax
    SIMD body. Modes: SW_REF_WINDOWED admits
    query_pos - p < window; SW_REF_OFF_BY_ONE admits
    query_pos - p <= window; SW_REF_FULL admits
    every position. Writes fixture.out_ref and
    returns the admitted count for query head 0's
    kv group (the count is head-independent)."""
    var qpos = length - 1
    var scale = (1.0 / (Float64(SW_HEAD_DIM) ** 0.5)).cast[f32]()
    var group = SW_Q_HEADS // SW_KV_HEADS
    var admitted0 = 0
    for qh in range(SW_Q_HEADS):
        var kvh = qh // group
        var scores = List[Float32]()
        var admitted = List[Bool]()
        var top = Float32(-1e20)
        for p in range(length):
            var ok = False
            if mode == SW_REF_FULL:
                ok = True
            elif mode == SW_REF_OFF_BY_ONE:
                ok = qpos - p <= window
            else:
                ok = qpos - p < window
            admitted.append(ok)
            if not ok:
                scores.append(Float32(0.0))
                continue
            var s = Float32(0.0)
            for d in range(SW_HEAD_DIM):
                s += (
                    fixture.query.data.unsafe_load(
                        qh * SW_HEAD_DIM + d
                    ).cast[f32]()
                    * fixture.keys.data.unsafe_load(
                        p * SW_KV_HEADS * SW_HEAD_DIM
                        + kvh * SW_HEAD_DIM + d
                    ).cast[f32]()
                )
            s *= scale
            scores.append(s)
            if s > top:
                top = s
        var denom = Float32(0.0)
        for p in range(length):
            if admitted[p]:
                denom += exp(scores[p] - top)
        if qh == 0:
            admitted0 = 0
            for p in range(length):
                if admitted[p]:
                    admitted0 += 1
        for d in range(SW_HEAD_DIM):
            var acc = Float32(0.0)
            for p in range(length):
                if admitted[p]:
                    acc += (
                        exp(scores[p] - top)
                        * fixture.values.data.unsafe_load(
                            p * SW_KV_HEADS * SW_HEAD_DIM
                            + kvh * SW_HEAD_DIM + d
                        ).cast[f32]()
                    )
            fixture.out_ref.data.unsafe_store(
                qh * SW_HEAD_DIM + d, (acc / denom).cast[f16]()
            )
    return admitted0


def sw_execute(
    window: Int, length: Int, mode: Int
) raises -> List[Int]:
    """Build one cell's fixture, run the banked
    kernel and the reference in `mode`, and return
    [max_diff_x10000, attended_count]."""
    var fixture = SwFixture(window, length)
    flash_attention_gqa(
        fixture.query,
        fixture.keys,
        fixture.values,
        fixture.out_kernel,
        length,
        SW_HEAD_DIM,
        SW_Q_HEADS,
        SW_KV_HEADS,
        Scalar[f32](0.0),
        Scalar[f32](0.0),
        window,
        length - 1,
    )
    var attended = sw_reference(fixture, window, length, mode)
    var max_diff = Float32(0.0)
    var n = SW_Q_HEADS * SW_HEAD_DIM
    for i in range(n):
        var d = (
            fixture.out_kernel.data.unsafe_load(i).cast[f32]()
            - fixture.out_ref.data.unsafe_load(i).cast[f32]()
        )
        if d < 0:
            d = -d
        if d > max_diff:
            max_diff = d
    var out = List[Int]()
    out.append(Int(max_diff * 10000.0 + 0.5))
    out.append(attended)
    return out^


# -- rows -----------------------------------------------------------------


def _verdict_code(name: String) -> Int:
    if name == String("FAITHFUL"):
        return MX_FAITHFUL
    if name == String("FAITHFUL_NEAR_TIE"):
        return MX_FAITHFUL_NEAR_TIE
    if name == String("DIVERGENT"):
        return MX_DIVERGENT
    if name == String("COMPARATOR_ARTIFACT"):
        return MX_COMPARATOR_ARTIFACT
    if name == String("FIXTURE_LIMITED"):
        return MX_FIXTURE_LIMITED
    return MX_NOT_GRADED


struct BatteryRow(Copyable, ImplicitlyCopyable):
    var window: Int
    var length: Int
    var backend: String
    var verdict: Int
    var reason: String
    var obligation: Int
    var attended: Int
    var diff_x10000: Int

    def __init__(
        out self,
        window: Int,
        length: Int,
        backend: String,
        verdict: Int,
        reason: String,
        obligation: Int,
        attended: Int,
        diff_x10000: Int,
    ):
        self.window = window
        self.length = length
        self.backend = backend
        self.verdict = verdict
        self.reason = reason
        self.obligation = obligation
        self.attended = attended
        self.diff_x10000 = diff_x10000


def battery_row_verdict(
    window: Int, length: Int, backend: String, obligation: Int
) raises -> BatteryRow:
    if backend != String(SW_GRADED_BACKEND):
        return BatteryRow(
            window, length, backend, MX_NOT_GRADED,
            String("BACKEND_NO_CPU_COMPARATOR"), obligation,
            -1, -1,
        )
    var measured = sw_execute(window, length, SW_REF_WINDOWED)
    var diff = measured[0]
    var attended = measured[1]
    if attended != sw_attended(window, length):
        return BatteryRow(
            window, length, backend, MX_DIVERGENT,
            String("WINDOW_ATTENDED_COUNT"), obligation,
            attended, diff,
        )
    if diff > SW_BOUND_X10000:
        return BatteryRow(
            window, length, backend, MX_DIVERGENT,
            String("WINDOW_PARITY_DIFF_EXCEEDS_BOUND"),
            obligation, attended, diff,
        )
    return BatteryRow(
        window, length, backend, MX_FAITHFUL,
        String("WINDOW_BOUNDARY_PARITY"), obligation,
        attended, diff,
    )


def _check_windows(windows: List[Int]) raises:
    if len(windows) == 0:
        raise Error("SlidingWindow: window axis is empty")
    for i in range(len(windows)):
        if windows[i] < 2:
            raise Error("SlidingWindow: window must be >= 2")
        for j in range(i + 1, len(windows)):
            if windows[i] == windows[j]:
                raise Error(
                    "SlidingWindow: duplicate window entry "
                    + String(windows[i])
                )


def _check_backends(backends: List[String]) raises:
    if len(backends) == 0:
        raise Error("SlidingWindow: backend axis is empty")
    for i in range(len(backends)):
        for j in range(i + 1, len(backends)):
            if backends[i] == backends[j]:
                raise Error(
                    "SlidingWindow: duplicate backend entry "
                    + backends[i]
                )


def build_battery(
    windows: List[Int], backends: List[String]
) raises -> List[BatteryRow]:
    _check_windows(windows)
    _check_backends(backends)
    var obligation = policy_obligation()
    var rows = List[BatteryRow]()
    for wi in range(len(windows)):
        var lens = sw_lengths(windows[wi])
        for li in range(len(lens)):
            for bi in range(len(backends)):
                rows.append(
                    battery_row_verdict(
                        windows[wi], lens[li], backends[bi],
                        obligation,
                    )
                )
    return rows^


# --- The seeded cases (status: SYNTHETIC, never
# hidden), judged by measured differences. ---


struct SynCase(Copyable, ImplicitlyCopyable):
    var name: String
    var verdict: Int
    var reason: String
    var diff_x10000: Int

    def __init__(
        out self,
        name: String,
        verdict: Int,
        reason: String,
        diff_x10000: Int,
    ):
        self.name = name
        self.verdict = verdict
        self.reason = reason
        self.diff_x10000 = diff_x10000


def syn_cases() raises -> List[SynCase]:
    var cases = List[SynCase]()
    var off = sw_execute(16, 17, SW_REF_OFF_BY_ONE)
    if off[0] > SW_BOUND_X10000:
        cases.append(
            SynCase(
                String("SYN_OFF_BY_ONE"), MX_DIVERGENT,
                String("WINDOW_BOUNDARY_OFF_BY_ONE"), off[0],
            )
        )
    else:
        cases.append(
            SynCase(
                String("SYN_OFF_BY_ONE"), MX_FAITHFUL,
                String("BOUNDARY_PROBE_BLIND"), off[0],
            )
        )
    var ignored = sw_execute(16, 33, SW_REF_FULL)
    if ignored[0] > SW_BOUND_X10000:
        cases.append(
            SynCase(
                String("SYN_WINDOW_IGNORED"), MX_DIVERGENT,
                String("WINDOW_NOT_APPLIED"), ignored[0],
            )
        )
    else:
        cases.append(
            SynCase(
                String("SYN_WINDOW_IGNORED"), MX_FAITHFUL,
                String("BOUNDARY_PROBE_BLIND"), ignored[0],
            )
        )
    var free = sw_execute(16, 16, SW_REF_FULL)
    if free[0] <= SW_BOUND_X10000:
        cases.append(
            SynCase(
                String("SYN_WINDOW_FREE"), MX_FAITHFUL,
                String("WINDOW_CANNOT_BIND_AT_OR_BELOW"),
                free[0],
            )
        )
    else:
        cases.append(
            SynCase(
                String("SYN_WINDOW_FREE"), MX_DIVERGENT,
                String("WINDOW_BINDS_BELOW_BOUNDARY"), free[0],
            )
        )
    cases.append(
        SynCase(
            String("SYN_MISMATCH"), MX_COMPARATOR_ARTIFACT,
            String("BACKEND_MISMATCH"), -1,
        )
    )
    return cases^


struct BatteryReport(Copyable, Movable):
    var rows: List[BatteryRow]
    var syn: List[SynCase]
    var total: Int
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var artifact: Int
    var fixture_limited: Int
    var not_graded: Int
    var owed: Int
    var coherence: Int
    var syn_total: Int
    var syn_faithful: Int
    var syn_divergent: Int
    var syn_artifact: Int
    var digest: UInt64

    def __init__(
        out self,
        rows: List[BatteryRow],
        syn: List[SynCase],
        total: Int,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        artifact: Int,
        fixture_limited: Int,
        not_graded: Int,
        owed: Int,
        coherence: Int,
        syn_total: Int,
        syn_faithful: Int,
        syn_divergent: Int,
        syn_artifact: Int,
        digest: UInt64,
    ):
        self.rows = rows.copy()
        self.syn = syn.copy()
        self.total = total
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.artifact = artifact
        self.fixture_limited = fixture_limited
        self.not_graded = not_graded
        self.owed = owed
        self.coherence = coherence
        self.syn_total = syn_total
        self.syn_faithful = syn_faithful
        self.syn_divergent = syn_divergent
        self.syn_artifact = syn_artifact
        self.digest = digest


def run_battery() raises -> BatteryReport:
    var rows = build_battery(sw_windows(), sw_backends())
    var faithful = 0
    var near_tie = 0
    var divergent = 0
    var artifact = 0
    var fixture_limited = 0
    var not_graded = 0
    var owed = 0
    var coherence = 0
    for i in range(len(rows)):
        var v = rows[i].verdict
        if v == MX_FAITHFUL:
            faithful += 1
        elif v == MX_FAITHFUL_NEAR_TIE:
            near_tie += 1
        elif v == MX_DIVERGENT:
            divergent += 1
        elif v == MX_COMPARATOR_ARTIFACT:
            artifact += 1
        elif v == MX_FIXTURE_LIMITED:
            fixture_limited += 1
        else:
            not_graded += 1
        if rows[i].obligation == POLICY_COHERENCE_ONLY:
            coherence += 1
        else:
            owed += 1
    var syn = syn_cases()
    var syn_faithful = 0
    var syn_divergent = 0
    var syn_artifact = 0
    for i in range(len(syn)):
        if syn[i].verdict == MX_FAITHFUL:
            syn_faithful += 1
        elif syn[i].verdict == MX_DIVERGENT:
            syn_divergent += 1
        elif syn[i].verdict == MX_COMPARATOR_ARTIFACT:
            syn_artifact += 1
    var report = BatteryReport(
        rows.copy(), syn.copy(), len(rows), faithful, near_tie,
        divergent, artifact, fixture_limited, not_graded, owed,
        coherence, len(syn), syn_faithful, syn_divergent,
        syn_artifact, UInt64(0),
    )
    report.digest = mx_fnv1a64(battery_render(report.copy()))
    return report^


def battery_row_line(row: BatteryRow) -> String:
    var s = String("SW_ROW window=") + String(row.window)
    s += String(" length=") + String(row.length)
    s += String(" qpos=") + String(row.length - 1)
    s += String(" backend=") + row.backend
    s += String(" verdict=") + matrix_verdict_name(row.verdict)
    s += String(" reason=") + row.reason
    s += String(" policy=") + obligation_name(row.obligation)
    s += String(" attended=") + String(row.attended)
    s += String(" max_diff_x10000=") + String(row.diff_x10000)
    return s


def syn_case_line(scase: SynCase) -> String:
    var s = String("SW_SYN case=") + scase.name
    s += String(" status=") + String(SW_FIXTURE_STATUS)
    s += String(" verdict=") + matrix_verdict_name(scase.verdict)
    s += String(" reason=") + scase.reason
    s += String(" max_diff_x10000=") + String(scase.diff_x10000)
    return s


def battery_render(read report: BatteryReport) -> String:
    var s = String("A123_BATTERY windows=")
    s += String(len(sw_windows()))
    s += String(" backends=") + String(len(sw_backends()))
    s += String(" total=") + String(report.total)
    s += String(" fixture_status=") + String(SW_FIXTURE_STATUS)
    s += String("\n")
    for i in range(len(report.rows)):
        s += battery_row_line(report.rows[i]) + String("\n")
    for i in range(len(report.syn)):
        s += syn_case_line(report.syn[i]) + String("\n")
    s += String("A123_BATTERY_SUMMARY total=") + String(report.total)
    s += String(" faithful=") + String(report.faithful)
    s += String(" near_tie=") + String(report.near_tie)
    s += String(" divergent=") + String(report.divergent)
    s += String(" artifact=") + String(report.artifact)
    s += String(" fixture_limited=") + String(report.fixture_limited)
    s += String(" not_graded=") + String(report.not_graded)
    s += String(" owed=") + String(report.owed)
    s += String(" coherence=") + String(report.coherence)
    s += String("\n")
    s += String("A123_SYNTHETIC_SUMMARY status=")
    s += String(SW_FIXTURE_STATUS)
    s += String(" total=") + String(report.syn_total)
    s += String(" faithful=") + String(report.syn_faithful)
    s += String(" divergent=") + String(report.syn_divergent)
    s += String(" artifact=") + String(report.syn_artifact)
    return s


def battery_line() -> String:
    return String(
        "A-123 Sliding-window attention parity: 3 windows"
        " x 6 window-boundary lengths x 4 Z13 backends"
        " judged by executing the banked CPU kernel"
        " (core/compute flash_attention_gqa) against an"
        " independent reference over a SYNTHETIC fixture"
        " with a sharp boundary probe; non-cpu rows"
        " NOT_GRADED with a named reason, zero unexplained"
    )
